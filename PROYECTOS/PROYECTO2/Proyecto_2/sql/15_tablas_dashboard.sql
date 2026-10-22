-- =====================================================================
-- 15_tablas_dashboard.sql
-- Proyecto 2 - SS22S2026 Grupo 8 | Responsable: Diego
-- Finalidad: crear tablas AGREGADAS (pequeñas) que alimentan el tablero de
--            Looker Studio. Conectar Looker directamente a trips_opt
--            (36 M filas) haría que cada filtro del tablero escanee GB;
--            con estas tablas cada gráfico lee unos pocos KB/MB.
--
-- Fuentes del tablero (ver README, sección 11):
--   Exploratorias (este script) : dash_diario, dash_hora_dia, dash_pago_mensual,
--                                 dash_zonas, dash_distancia_propina
--   Predicciones (Pablo, 08-11) : pred_diaria_nov, rolling_forecast_diario,
--                                 rolling_forecast_resumen, eval_hiperparametros,
--                                 eval_roc_logistic, pred_viajes_hipoteticos
-- =====================================================================


-- ---------------------------------------------------------------------
-- 15.1 Serie diaria (gráfico de serie de tiempo + controles de fecha)
-- ---------------------------------------------------------------------
CREATE OR REPLACE TABLE `ss22s2026-g8-proyecto2.nyc_taxi_p2.dash_diario`
PARTITION BY fecha
OPTIONS (description = 'Dashboard: métricas diarias 2022 (registros válidos)')
AS
SELECT
  DATE(pickup_datetime)                                                  AS fecha,
  FORMAT_DATE('%Y-%m', DATE(pickup_datetime))                            AS mes,
  FORMAT_DATE('%u-%a', DATE(pickup_datetime))                            AS dia_semana,
  COUNT(*)                                                               AS viajes,
  ROUND(SUM(CAST(total_amount AS FLOAT64)), 2)                           AS ingreso_total,
  ROUND(AVG(CAST(fare_amount AS FLOAT64)), 2)                            AS tarifa_prom,
  ROUND(AVG(CAST(trip_distance AS FLOAT64)), 2)                          AS distancia_prom,
  ROUND(AVG(IF(payment_type = '1', CAST(tip_amount AS FLOAT64), NULL)), 2) AS propina_prom_tarjeta,
  ROUND(100 * COUNTIF(payment_type = '1') / COUNT(*), 2)                 AS pct_tarjeta
FROM `ss22s2026-g8-proyecto2.nyc_taxi_p2.trips_opt`
WHERE pickup_datetime >= TIMESTAMP('2022-01-01')
  AND pickup_datetime <  TIMESTAMP('2022-12-01')
  AND fare_amount BETWEEN 2.5 AND 200
  AND trip_distance BETWEEN 0.1 AND 100
  AND TIMESTAMP_DIFF(dropoff_datetime, pickup_datetime, SECOND) BETWEEN 60 AND 10800
GROUP BY fecha, mes, dia_semana;


-- ---------------------------------------------------------------------
-- 15.2 Hora x día de la semana (mapa de calor / tabla dinámica)
-- ---------------------------------------------------------------------
CREATE OR REPLACE TABLE `ss22s2026-g8-proyecto2.nyc_taxi_p2.dash_hora_dia`
OPTIONS (description = 'Dashboard: viajes promedio por día y % de propina por hora y día de la semana')
AS
SELECT
  FORMAT_TIMESTAMP('%u-%a', pickup_datetime)                             AS dia_semana,
  EXTRACT(HOUR FROM pickup_datetime)                                     AS hora,
  COUNT(*)                                                               AS viajes,
  ROUND(COUNT(*) / COUNT(DISTINCT DATE(pickup_datetime)), 0)             AS viajes_por_dia,
  ROUND(AVG(CAST(fare_amount AS FLOAT64)), 2)                            AS tarifa_prom,
  ROUND(100 * AVG(IF(payment_type = '1',
        SAFE_DIVIDE(CAST(tip_amount AS FLOAT64), CAST(fare_amount AS FLOAT64)), NULL)), 2) AS propina_pct_tarjeta
FROM `ss22s2026-g8-proyecto2.nyc_taxi_p2.trips_opt`
WHERE pickup_datetime >= TIMESTAMP('2022-01-01')
  AND pickup_datetime <  TIMESTAMP('2022-12-01')
  AND fare_amount BETWEEN 2.5 AND 200
  AND trip_distance BETWEEN 0.1 AND 100
GROUP BY dia_semana, hora;


-- ---------------------------------------------------------------------
-- 15.3 Tipo de pago por mes (barras apiladas)
-- ---------------------------------------------------------------------
CREATE OR REPLACE TABLE `ss22s2026-g8-proyecto2.nyc_taxi_p2.dash_pago_mensual`
OPTIONS (description = 'Dashboard: viajes y propina por tipo de pago y mes')
AS
SELECT
  FORMAT_TIMESTAMP('%Y-%m', pickup_datetime)                             AS mes,
  CASE payment_type
    WHEN '1' THEN 'Tarjeta' WHEN '2' THEN 'Efectivo' WHEN '3' THEN 'Sin cargo'
    WHEN '4' THEN 'Disputa' WHEN '0' THEN 'Sin dato' ELSE 'Otro'
  END                                                                    AS tipo_pago,
  COUNT(*)                                                               AS viajes,
  ROUND(AVG(CAST(fare_amount AS FLOAT64)), 2)                            AS tarifa_prom,
  ROUND(AVG(CAST(tip_amount AS FLOAT64)), 2)                             AS propina_prom
FROM `ss22s2026-g8-proyecto2.nyc_taxi_p2.trips_opt`
WHERE pickup_datetime >= TIMESTAMP('2022-01-01')
  AND pickup_datetime <  TIMESTAMP('2022-12-01')
GROUP BY mes, tipo_pago;


-- ---------------------------------------------------------------------
-- 15.4 Zonas de origen con geometría (mapa coroplético en Looker Studio:
-- tipo de gráfico "Mapa de Google" > área rellena, campo zone_geom).
-- ---------------------------------------------------------------------
CREATE OR REPLACE TABLE `ss22s2026-g8-proyecto2.nyc_taxi_p2.dash_zonas`
OPTIONS (description = 'Dashboard: métricas por zona de origen con geometría GEOGRAPHY')
AS
WITH por_zona AS (
  SELECT
    pickup_location_id                                                   AS zona_id,
    COUNT(*)                                                             AS viajes,
    ROUND(AVG(CAST(fare_amount AS FLOAT64)), 2)                          AS tarifa_prom,
    ROUND(AVG(CAST(trip_distance AS FLOAT64)), 2)                        AS distancia_prom,
    ROUND(AVG(IF(payment_type = '1', CAST(tip_amount AS FLOAT64), NULL)), 2) AS propina_prom_tarjeta,
    ROUND(100 * AVG(IF(payment_type = '1',
          SAFE_DIVIDE(CAST(tip_amount AS FLOAT64), CAST(fare_amount AS FLOAT64)), NULL)), 2) AS propina_pct_tarjeta
  FROM `ss22s2026-g8-proyecto2.nyc_taxi_p2.trips_opt`
  WHERE pickup_datetime >= TIMESTAMP('2022-01-01')
    AND pickup_datetime <  TIMESTAMP('2022-12-01')
    AND fare_amount BETWEEN 2.5 AND 200
    AND trip_distance BETWEEN 0.1 AND 100
  GROUP BY zona_id
)
SELECT
  p.*,
  z.zone_name AS zona,
  z.borough,
  z.zone_geom,
  -- centroide "lat,lon": Looker Studio lo reconoce como tipo Geo > Latitud, longitud
  -- y es el campo que exige "Ubicación" en el mapa de Google
  CONCAT(CAST(ST_Y(ST_CENTROID(z.zone_geom)) AS STRING), ',',
         CAST(ST_X(ST_CENTROID(z.zone_geom)) AS STRING)) AS lat_lon
FROM por_zona p
JOIN `bigquery-public-data.new_york_taxi_trips.taxi_zone_geom` z
  ON z.zone_id = p.zona_id;


-- ---------------------------------------------------------------------
-- 15.5 Propina por rango de distancia (tabla limpia de ML)
-- ---------------------------------------------------------------------
CREATE OR REPLACE TABLE `ss22s2026-g8-proyecto2.nyc_taxi_p2.dash_distancia_propina`
OPTIONS (description = 'Dashboard: tarifa y propina por rango de distancia (viajes con tarjeta)')
AS
SELECT
  CASE
    WHEN trip_distance < 1  THEN '1 < 1 mi'
    WHEN trip_distance < 2  THEN '2 1-2 mi'
    WHEN trip_distance < 5  THEN '3 2-5 mi'
    WHEN trip_distance < 10 THEN '4 5-10 mi'
    WHEN trip_distance < 20 THEN '5 10-20 mi'
    ELSE                         '6 20+ mi'
  END                                                AS rango_distancia,
  is_airport,
  COUNT(*)                                           AS viajes,
  ROUND(AVG(fare_amount), 2)                         AS tarifa_prom,
  ROUND(AVG(tip_amount), 2)                          AS propina_prom,
  ROUND(100 * AVG(tip_pct), 2)                       AS propina_pct_prom,
  ROUND(100 * AVG(CAST(high_tip AS INT64)), 2)       AS pct_propina_alta
FROM `ss22s2026-g8-proyecto2.nyc_taxi_p2.ml_trips_clean`
GROUP BY rango_distancia, is_airport;


-- ---------------------------------------------------------------------
-- 15.6 Verificación: tamaño de las tablas del tablero
-- (deben ser de KB/MB, frente a ~7 GB de la tabla original)
-- -> captura 57_tablas_dashboard.png
-- ---------------------------------------------------------------------
SELECT
  table_id,
  row_count,
  ROUND(size_bytes / POW(1024, 2), 3) AS size_mb
FROM `ss22s2026-g8-proyecto2.nyc_taxi_p2.__TABLES__`
WHERE STARTS_WITH(table_id, 'dash_')
   OR STARTS_WITH(table_id, 'pred_')
   OR STARTS_WITH(table_id, 'rolling_')
   OR STARTS_WITH(table_id, 'eval_')
ORDER BY table_id;
