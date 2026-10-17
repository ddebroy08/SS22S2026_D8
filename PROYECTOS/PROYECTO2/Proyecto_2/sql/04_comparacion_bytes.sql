-- =====================================================================
-- 04_comparacion_bytes.sql
-- Proyecto 2 - SS22S2026 Grupo 8 | Responsable: Estuardo
-- Finalidad: comparar la MISMA consulta sobre tres tablas:
--     (A) pública  bigquery-public-data...tlc_yellow_trips_2022
--     (B) base     trips_base  (copia sin optimizar)
--     (C) opt      trips_opt   (partición por fecha + clustering por zonas)
--
-- PROCEDIMIENTO (para resultados válidos):
--  1. En la consola: Más > Configuración de consulta > DESACTIVAR
--     "Usar resultados almacenados en caché" (si no, bytes = 0).
--  2. Ejecutar cada consulta una vez. Anotar en "Información del trabajo":
--     Bytes procesados, Bytes facturados y Tiempo transcurrido.
--  3. Ejecutar el bloque final (INFORMATION_SCHEMA.JOBS) para obtener todas
--     las métricas en una sola tabla -> captura de evidencia.
--  Nota: la estimación previa de bytes en tablas con clustering es un límite
--  superior; el valor real es el de "Información del trabajo" tras ejecutar.
--
-- Las etiquetas "COMPARACION_x" en los comentarios permiten identificar los
-- trabajos en el bloque final.
-- =====================================================================


-- #####################################################################
-- ESCENARIO 1: filtro por FECHA (junio 2022) + ZONA de origen (JFK=132, LaGuardia=138)
-- Aprovecha partición (fecha) y clustering (zona).
-- #####################################################################

-- COMPARACION_1A_PUBLICA
SELECT pickup_location_id,
       COUNT(*)                       AS viajes,
       ROUND(AVG(tip_amount), 2)      AS propina_prom,
       ROUND(AVG(fare_amount), 2)     AS tarifa_prom
FROM `bigquery-public-data.new_york_taxi_trips.tlc_yellow_trips_2022`
WHERE pickup_datetime >= TIMESTAMP('2022-06-01')
  AND pickup_datetime <  TIMESTAMP('2022-07-01')
  AND pickup_location_id IN ('132', '138')
GROUP BY pickup_location_id;

-- COMPARACION_1B_BASE
SELECT pickup_location_id,
       COUNT(*)                       AS viajes,
       ROUND(AVG(tip_amount), 2)      AS propina_prom,
       ROUND(AVG(fare_amount), 2)     AS tarifa_prom
FROM `ss22s2026-g8-proyecto2.nyc_taxi_p2.trips_base`
WHERE pickup_datetime >= TIMESTAMP('2022-06-01')
  AND pickup_datetime <  TIMESTAMP('2022-07-01')
  AND pickup_location_id IN ('132', '138')
GROUP BY pickup_location_id;

-- COMPARACION_1C_OPT
SELECT pickup_location_id,
       COUNT(*)                       AS viajes,
       ROUND(AVG(tip_amount), 2)      AS propina_prom,
       ROUND(AVG(fare_amount), 2)     AS tarifa_prom
FROM `ss22s2026-g8-proyecto2.nyc_taxi_p2.trips_opt`
WHERE pickup_datetime >= TIMESTAMP('2022-06-01')
  AND pickup_datetime <  TIMESTAMP('2022-07-01')
  AND pickup_location_id IN ('132', '138')
GROUP BY pickup_location_id;


-- #####################################################################
-- ESCENARIO 2: SOLO filtro por ZONA (todo el año)
-- Aislar el efecto del clustering (sin ayuda de la partición).
-- #####################################################################

-- COMPARACION_2A_PUBLICA
SELECT FORMAT_TIMESTAMP('%Y-%m', pickup_datetime) AS mes,
       COUNT(*)                   AS viajes,
       ROUND(AVG(total_amount), 2) AS total_prom
FROM `bigquery-public-data.new_york_taxi_trips.tlc_yellow_trips_2022`
WHERE pickup_location_id = '161'
GROUP BY mes ORDER BY mes;

-- COMPARACION_2B_BASE
SELECT FORMAT_TIMESTAMP('%Y-%m', pickup_datetime) AS mes,
       COUNT(*)                   AS viajes,
       ROUND(AVG(total_amount), 2) AS total_prom
FROM `ss22s2026-g8-proyecto2.nyc_taxi_p2.trips_base`
WHERE pickup_location_id = '161'
GROUP BY mes ORDER BY mes;

-- COMPARACION_2C_OPT
SELECT FORMAT_TIMESTAMP('%Y-%m', pickup_datetime) AS mes,
       COUNT(*)                   AS viajes,
       ROUND(AVG(total_amount), 2) AS total_prom
FROM `ss22s2026-g8-proyecto2.nyc_taxi_p2.trips_opt`
WHERE pickup_location_id = '161'
GROUP BY mes ORDER BY mes;


-- #####################################################################
-- RESUMEN DE EVIDENCIA: bytes y tiempo de las consultas anteriores
-- (ejecutar DESPUÉS de las 6 consultas; región 'US')
-- #####################################################################
SELECT
  REGEXP_EXTRACT(query, r'COMPARACION_\w+')                 AS consulta,
  ROUND(total_bytes_processed / POW(1024, 2), 1)            AS mb_procesados,
  ROUND(total_bytes_billed    / POW(1024, 2), 1)            AS mb_facturados,
  TIMESTAMP_DIFF(end_time, start_time, MILLISECOND)         AS ms,
  total_slot_ms                                             AS slot_ms,
  cache_hit
FROM `region-us`.INFORMATION_SCHEMA.JOBS_BY_PROJECT
WHERE creation_time > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 3 HOUR)
  AND job_type = 'QUERY'
  AND state = 'DONE'
  AND error_result IS NULL
  AND REGEXP_CONTAINS(query, r'-- COMPARACION_\w+')
  AND NOT REGEXP_CONTAINS(query, r'INFORMATION_SCHEMA')
ORDER BY consulta, creation_time DESC;
