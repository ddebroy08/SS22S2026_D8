-- =====================================================================
-- 01_exploracion_dataset.sql
-- Proyecto 2 - SS22S2026 Grupo 8 | Responsable: Estuardo
-- Finalidad: conexión y comprensión del dataset público
--            bigquery-public-data.new_york_taxi_trips.tlc_yellow_trips_2022
-- Ejecutar cada bloque por separado y capturar el resultado (evidencias/).
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1.1 Esquema: nombres y tipos de columna
-- Nota: en esta tabla las columnas se llaman pickup_location_id /
-- dropoff_location_id (NO PULocationID / DOLocationID del TLC original).
-- ---------------------------------------------------------------------
SELECT ordinal_position, column_name, data_type
FROM `bigquery-public-data.new_york_taxi_trips.INFORMATION_SCHEMA.COLUMNS`
WHERE table_name = 'tlc_yellow_trips_2022'
ORDER BY ordinal_position;


-- ---------------------------------------------------------------------
-- 1.2 Tamaño de la tabla según metadatos (no escanea datos, costo ~0)
-- ---------------------------------------------------------------------
SELECT
  table_id,
  row_count,
  ROUND(size_bytes / POW(1024, 3), 2) AS size_gb
FROM `bigquery-public-data.new_york_taxi_trips.__TABLES__`
WHERE table_id = 'tlc_yellow_trips_2022';


-- ---------------------------------------------------------------------
-- 1.3 Conteo de registros y rango de fechas (requisito: > 1 millón)
-- ---------------------------------------------------------------------
SELECT
  COUNT(*)                                 AS total_registros,
  MIN(pickup_datetime)                     AS primera_recogida,
  MAX(pickup_datetime)                     AS ultima_recogida,
  COUNT(DISTINCT pickup_location_id)       AS zonas_origen_distintas,
  COUNT(DISTINCT dropoff_location_id)      AS zonas_destino_distintas
FROM `bigquery-public-data.new_york_taxi_trips.tlc_yellow_trips_2022`;


-- ---------------------------------------------------------------------
-- 1.4 Distribución de viajes por mes (detecta meses vacíos o fechas fuera de 2022)
-- ---------------------------------------------------------------------
SELECT
  FORMAT_TIMESTAMP('%Y-%m', pickup_datetime) AS mes,
  COUNT(*)                                   AS viajes
FROM `bigquery-public-data.new_york_taxi_trips.tlc_yellow_trips_2022`
GROUP BY mes
ORDER BY mes;


-- ---------------------------------------------------------------------
-- 1.5 Distribución por tipo de pago y código de tarifa
-- (payment_type: 1=tarjeta, 2=efectivo, 3=sin cargo, 4=disputa, ...)
-- ---------------------------------------------------------------------
SELECT payment_type, COUNT(*) AS viajes, ROUND(AVG(tip_amount), 2) AS propina_promedio
FROM `bigquery-public-data.new_york_taxi_trips.tlc_yellow_trips_2022`
GROUP BY payment_type
ORDER BY viajes DESC;

SELECT rate_code, COUNT(*) AS viajes
FROM `bigquery-public-data.new_york_taxi_trips.tlc_yellow_trips_2022`
GROUP BY rate_code
ORDER BY viajes DESC;


-- ---------------------------------------------------------------------
-- 1.6 Muestra de filas para inspección visual
-- ---------------------------------------------------------------------
SELECT *
FROM `bigquery-public-data.new_york_taxi_trips.tlc_yellow_trips_2022`
LIMIT 20;
