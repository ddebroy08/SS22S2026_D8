-- =====================================================================
-- 05_tabla_ml.sql
-- Proyecto 2 - SS22S2026 Grupo 8 | Responsable: Estuardo
-- Finalidad: construir la tabla LIMPIA para ML con ingeniería de
--            características y la partición TEMPORAL train / eval / new_records.
--
-- Contexto del problema: predecir la propina de un viaje en taxi pagado con
-- tarjeta (regresión: tip_amount) y si será una propina alta (clasificación:
-- high_tip = propina >= 20% de la tarifa).
--
-- Origen: trips_opt (ya particionada y clusterizada).
-- =====================================================================

CREATE OR REPLACE TABLE `ss22s2026-g8-proyecto2.nyc_taxi_p2.ml_trips_clean`
PARTITION BY pickup_date
CLUSTER BY pickup_location_id, dropoff_location_id
OPTIONS (description = 'Tabla limpia para ML: viajes con tarjeta, features derivadas y split temporal')
AS
WITH tipados AS (
  -- Paso 1: normalizar tipos (STRING -> INT/FLOAT) y calcular duración
  SELECT
    pickup_datetime,
    dropoff_datetime,
    DATE(pickup_datetime)                                         AS pickup_date,
    CAST(pickup_location_id  AS STRING)                           AS pickup_location_id,
    CAST(dropoff_location_id AS STRING)                           AS dropoff_location_id,
    SAFE_CAST(SAFE_CAST(payment_type AS FLOAT64) AS INT64)        AS payment_type_id,
    SAFE_CAST(SAFE_CAST(rate_code    AS FLOAT64) AS INT64)        AS rate_code_id,
    CAST(passenger_count AS INT64)                                AS passenger_count,
    CAST(trip_distance   AS FLOAT64)                              AS trip_distance,
    CAST(fare_amount     AS FLOAT64)                              AS fare_amount,
    CAST(tip_amount      AS FLOAT64)                              AS tip_amount,
    CAST(tolls_amount    AS FLOAT64)                              AS tolls_amount,
    TIMESTAMP_DIFF(dropoff_datetime, pickup_datetime, SECOND) / 60.0 AS trip_duration_min
  FROM `ss22s2026-g8-proyecto2.nyc_taxi_p2.trips_opt`
  WHERE pickup_datetime >= TIMESTAMP('2022-01-01')
    AND pickup_datetime <  TIMESTAMP('2022-12-01')   -- diciembre solo trae 57 filas (1 día): se descarta
),
con_velocidad AS (
  -- Paso 2: velocidad promedio (requiere duración > 0)
  SELECT *,
         SAFE_DIVIDE(trip_distance, trip_duration_min / 60.0) AS avg_speed_mph
  FROM tipados
),
filtrados AS (
  -- Paso 3: LIMPIEZA (umbrales justificados en 02_calidad_datos.sql)
  SELECT *
  FROM con_velocidad
  WHERE payment_type_id = 1                                -- solo tarjeta: la propina en efectivo no se registra
    AND rate_code_id BETWEEN 1 AND 6                       -- códigos de tarifa válidos
    AND passenger_count BETWEEN 1 AND 6                    -- 0 y >6 son errores de captura
    AND trip_distance   BETWEEN 0.1 AND 100                -- elimina distancia 0 y outliers extremos
    AND trip_duration_min BETWEEN 1 AND 180                -- elimina dropoff<pickup y viajes > 3 h
    AND avg_speed_mph   BETWEEN 1 AND 80                   -- velocidades físicamente plausibles
    AND fare_amount     BETWEEN 2.5 AND 200                -- tarifa mínima de NYC = 2.5 USD
    AND tip_amount >= 0 AND tip_amount <= fare_amount      -- propinas negativas o mayores a la tarifa = ruido
    AND tolls_amount >= 0
    AND pickup_location_id  NOT IN ('264', '265')          -- zonas "desconocidas"
    AND dropoff_location_id NOT IN ('264', '265')
)
SELECT
  -- Identificadores / tiempo (NO son features, se usan para split y análisis)
  pickup_datetime,
  pickup_date,

  -- Features categóricas geográficas
  pickup_location_id,
  dropoff_location_id,

  -- Features temporales derivadas
  EXTRACT(HOUR      FROM pickup_datetime)                           AS pickup_hour,
  EXTRACT(DAYOFWEEK FROM pickup_datetime)                           AS pickup_dow,     -- 1=domingo ... 7=sábado
  EXTRACT(MONTH     FROM pickup_datetime)                           AS pickup_month,   -- solo análisis (ver README)
  EXTRACT(DAYOFWEEK FROM pickup_datetime) IN (1, 7)                 AS is_weekend,
  (EXTRACT(DAYOFWEEK FROM pickup_datetime) BETWEEN 2 AND 6
     AND (EXTRACT(HOUR FROM pickup_datetime) BETWEEN 7 AND 9
          OR EXTRACT(HOUR FROM pickup_datetime) BETWEEN 16 AND 19)) AS is_rush_hour,

  -- Features del viaje
  passenger_count,
  rate_code_id,
  (rate_code_id IN (2, 3)
     OR pickup_location_id  IN ('1', '132', '138')
     OR dropoff_location_id IN ('1', '132', '138'))                 AS is_airport,     -- EWR=1, JFK=132, LGA=138
  trip_distance,
  trip_duration_min,
  avg_speed_mph,
  fare_amount,
  SAFE_DIVIDE(fare_amount, trip_distance)                           AS fare_per_mile,
  tolls_amount,
  tolls_amount > 0                                                  AS has_tolls,

  -- Variables OBJETIVO (nunca deben usarse como features)
  tip_amount,                                                                     -- regresión
  SAFE_DIVIDE(tip_amount, fare_amount)                              AS tip_pct,   -- solo análisis
  SAFE_DIVIDE(tip_amount, fare_amount) >= 0.20                      AS high_tip,  -- clasificación

  -- SPLIT TEMPORAL (evita data leakage: el modelo nunca ve el futuro)
  --   train       : ene - sep 2022
  --   eval        : oct 2022            (is_eval = TRUE -> data_split_col CUSTOM)
  --   new_records : nov 2022            (reservado para ML.PREDICT, jamás visto)
  -- (el dataset público solo contiene datos hasta nov 2022)
  pickup_date BETWEEN DATE '2022-10-01' AND DATE '2022-10-31'       AS is_eval,
  CASE
    WHEN pickup_date <  DATE '2022-10-01' THEN 'train'
    WHEN pickup_date <  DATE '2022-11-01' THEN 'eval'
    ELSE 'new_records'
  END                                                               AS split_set
FROM filtrados;


-- ---------------------------------------------------------------------
-- Registros nuevos (noviembre) para predicciones: tabla separada
-- ---------------------------------------------------------------------
CREATE OR REPLACE TABLE `ss22s2026-g8-proyecto2.nyc_taxi_p2.ml_new_records`
PARTITION BY pickup_date
CLUSTER BY pickup_location_id, dropoff_location_id
OPTIONS (description = 'Noviembre 2022: registros nuevos, no usados en entrenamiento ni evaluación')
AS
SELECT *
FROM `ss22s2026-g8-proyecto2.nyc_taxi_p2.ml_trips_clean`
WHERE split_set = 'new_records';


-- ---------------------------------------------------------------------
-- Verificación: filas retenidas tras la limpieza (con respecto a trips_opt)
-- ---------------------------------------------------------------------
SELECT
  (SELECT COUNT(*) FROM `ss22s2026-g8-proyecto2.nyc_taxi_p2.trips_opt`)      AS filas_origen,
  (SELECT COUNT(*) FROM `ss22s2026-g8-proyecto2.nyc_taxi_p2.ml_trips_clean`) AS filas_limpias,
  ROUND(100 * (SELECT COUNT(*) FROM `ss22s2026-g8-proyecto2.nyc_taxi_p2.ml_trips_clean`)
            / (SELECT COUNT(*) FROM `ss22s2026-g8-proyecto2.nyc_taxi_p2.trips_opt`), 2) AS pct_retenido;
