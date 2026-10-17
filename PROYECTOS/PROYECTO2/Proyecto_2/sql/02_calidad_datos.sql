-- =====================================================================
-- 02_calidad_datos.sql
-- Proyecto 2 - SS22S2026 Grupo 8 | Responsable: Estuardo
-- Finalidad: evaluar la calidad de los datos (nulos, outliers, fechas
--            inválidas, valores imposibles). Los umbrales hallados aquí
--            justifican los filtros de 05_tabla_ml.sql.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 2.1 Nulos por columna clave
-- ---------------------------------------------------------------------
SELECT
  COUNT(*)                                     AS total,
  COUNTIF(vendor_id IS NULL)                   AS nulos_vendor_id,
  COUNTIF(pickup_datetime IS NULL)             AS nulos_pickup_datetime,
  COUNTIF(dropoff_datetime IS NULL)            AS nulos_dropoff_datetime,
  COUNTIF(passenger_count IS NULL)             AS nulos_passenger_count,
  COUNTIF(trip_distance IS NULL)               AS nulos_trip_distance,
  COUNTIF(rate_code IS NULL)                   AS nulos_rate_code,
  COUNTIF(payment_type IS NULL)                AS nulos_payment_type,
  COUNTIF(fare_amount IS NULL)                 AS nulos_fare_amount,
  COUNTIF(tip_amount IS NULL)                  AS nulos_tip_amount,
  COUNTIF(total_amount IS NULL)                AS nulos_total_amount,
  COUNTIF(pickup_location_id IS NULL)          AS nulos_pickup_location,
  COUNTIF(dropoff_location_id IS NULL)         AS nulos_dropoff_location
FROM `bigquery-public-data.new_york_taxi_trips.tlc_yellow_trips_2022`;


-- ---------------------------------------------------------------------
-- 2.2 Fechas inválidas y valores imposibles
-- ---------------------------------------------------------------------
SELECT
  COUNT(*)                                                                    AS total,
  COUNTIF(pickup_datetime < TIMESTAMP('2022-01-01')
          OR pickup_datetime >= TIMESTAMP('2023-01-01'))                      AS fuera_de_2022,
  COUNTIF(dropoff_datetime < pickup_datetime)                                 AS dropoff_antes_de_pickup,
  COUNTIF(TIMESTAMP_DIFF(dropoff_datetime, pickup_datetime, MINUTE) > 180)    AS duracion_mayor_3h,
  COUNTIF(TIMESTAMP_DIFF(dropoff_datetime, pickup_datetime, SECOND) < 60)     AS duracion_menor_1min,
  COUNTIF(trip_distance <= 0)                                                 AS distancia_cero_o_negativa,
  COUNTIF(trip_distance > 100)                                                AS distancia_mayor_100mi,
  COUNTIF(fare_amount <= 0)                                                   AS tarifa_cero_o_negativa,
  COUNTIF(fare_amount > 200)                                                  AS tarifa_mayor_200,
  COUNTIF(tip_amount < 0)                                                     AS propina_negativa,
  COUNTIF(tip_amount > fare_amount AND fare_amount > 0)                       AS propina_mayor_que_tarifa,
  COUNTIF(passenger_count = 0)                                                AS pasajeros_cero,
  COUNTIF(passenger_count > 6)                                                AS pasajeros_mas_de_6
FROM `bigquery-public-data.new_york_taxi_trips.tlc_yellow_trips_2022`;


-- ---------------------------------------------------------------------
-- 2.3 Percentiles para detectar outliers (p1, p50, p99 y máximo)
-- ---------------------------------------------------------------------
WITH v AS (
  SELECT
    CAST(trip_distance AS FLOAT64) AS trip_distance,
    CAST(fare_amount AS FLOAT64)   AS fare_amount,
    CAST(tip_amount AS FLOAT64)    AS tip_amount,
    CAST(total_amount AS FLOAT64)  AS total_amount,
    TIMESTAMP_DIFF(dropoff_datetime, pickup_datetime, SECOND) / 60.0 AS duracion_min
  FROM `bigquery-public-data.new_york_taxi_trips.tlc_yellow_trips_2022`
)
SELECT 'trip_distance' AS variable,
       APPROX_QUANTILES(trip_distance, 100)[OFFSET(1)]  AS p01,
       APPROX_QUANTILES(trip_distance, 100)[OFFSET(50)] AS p50,
       APPROX_QUANTILES(trip_distance, 100)[OFFSET(99)] AS p99,
       MAX(trip_distance) AS maximo
FROM v
UNION ALL
SELECT 'fare_amount',
       APPROX_QUANTILES(fare_amount, 100)[OFFSET(1)],
       APPROX_QUANTILES(fare_amount, 100)[OFFSET(50)],
       APPROX_QUANTILES(fare_amount, 100)[OFFSET(99)],
       MAX(fare_amount)
FROM v
UNION ALL
SELECT 'tip_amount',
       APPROX_QUANTILES(tip_amount, 100)[OFFSET(1)],
       APPROX_QUANTILES(tip_amount, 100)[OFFSET(50)],
       APPROX_QUANTILES(tip_amount, 100)[OFFSET(99)],
       MAX(tip_amount)
FROM v
UNION ALL
SELECT 'total_amount',
       APPROX_QUANTILES(total_amount, 100)[OFFSET(1)],
       APPROX_QUANTILES(total_amount, 100)[OFFSET(50)],
       APPROX_QUANTILES(total_amount, 100)[OFFSET(99)],
       MAX(total_amount)
FROM v
UNION ALL
SELECT 'duracion_min',
       APPROX_QUANTILES(duracion_min, 100)[OFFSET(1)],
       APPROX_QUANTILES(duracion_min, 100)[OFFSET(50)],
       APPROX_QUANTILES(duracion_min, 100)[OFFSET(99)],
       MAX(duracion_min)
FROM v;


-- ---------------------------------------------------------------------
-- 2.4 Hallazgo clave para ML: la propina en EFECTIVO no se registra
-- (payment_type 2 -> tip_amount casi siempre 0). Por eso el modelo de
-- propinas se entrena solo con pagos con tarjeta (payment_type = 1).
-- ---------------------------------------------------------------------
SELECT
  payment_type,
  COUNT(*)                                  AS viajes,
  ROUND(100 * COUNTIF(tip_amount = 0) / COUNT(*), 2) AS pct_propina_cero,
  ROUND(AVG(tip_amount), 2)                 AS propina_promedio
FROM `bigquery-public-data.new_york_taxi_trips.tlc_yellow_trips_2022`
GROUP BY payment_type
ORDER BY viajes DESC;
