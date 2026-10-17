-- =====================================================================
-- 03_tablas_optimizadas.sql
-- Proyecto 2 - SS22S2026 Grupo 8 | Responsable: Estuardo
-- Finalidad: crear tablas derivadas en el proyecto propio:
--   * trips_base : copia SIN optimizar (control de comparación justa)
--   * trips_opt  : PARTICIONADA por fecha de recogida y con CLUSTERING
--                  por ubicación (pickup_location_id, dropoff_location_id)
-- Ambas se limitan a viajes con pickup en 2022 (se descartan fechas inválidas).
-- Requiere haber ejecutado 00_setup.sql.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 3.1 Tabla base (sin partición ni clustering)
-- ---------------------------------------------------------------------
CREATE OR REPLACE TABLE `ss22s2026-g8-proyecto2.nyc_taxi_p2.trips_base`
OPTIONS (description = 'Copia sin optimizar de tlc_yellow_trips_2022 (solo pickup en 2022)')
AS
SELECT *
FROM `bigquery-public-data.new_york_taxi_trips.tlc_yellow_trips_2022`
WHERE pickup_datetime >= TIMESTAMP('2022-01-01')
  AND pickup_datetime <  TIMESTAMP('2023-01-01');


-- ---------------------------------------------------------------------
-- 3.2 Tabla optimizada: partición diaria por fecha + clustering por zonas
-- Justificación:
--  - Partición por DATE(pickup_datetime): el análisis temporal filtra por
--    día/mes casi siempre; BigQuery solo lee las particiones necesarias.
--  - Clustering por (pickup_location_id, dropoff_location_id): los filtros y
--    agrupaciones geográficos son frecuentes; ordena físicamente los datos
--    y permite saltar bloques que no coinciden con el filtro.
--    El orden importa: se filtra primero por zona de origen.
-- ---------------------------------------------------------------------
CREATE OR REPLACE TABLE `ss22s2026-g8-proyecto2.nyc_taxi_p2.trips_opt`
PARTITION BY DATE(pickup_datetime)
CLUSTER BY pickup_location_id, dropoff_location_id
OPTIONS (description = 'NYC Yellow Taxi 2022 particionada por DATE(pickup_datetime) y clusterizada por zonas')
AS
SELECT *
FROM `ss22s2026-g8-proyecto2.nyc_taxi_p2.trips_base`;


-- ---------------------------------------------------------------------
-- 3.3 Verificación: conteo de filas igual en ambas tablas
-- ---------------------------------------------------------------------
SELECT 'trips_base' AS tabla, COUNT(*) AS filas FROM `ss22s2026-g8-proyecto2.nyc_taxi_p2.trips_base`
UNION ALL
SELECT 'trips_opt',            COUNT(*)         FROM `ss22s2026-g8-proyecto2.nyc_taxi_p2.trips_opt`;


-- ---------------------------------------------------------------------
-- 3.4 Evidencia de particiones (número de particiones, filas y tamaño)
-- ---------------------------------------------------------------------
SELECT
  table_name,
  COUNT(*)                                          AS particiones,
  SUM(total_rows)                                   AS filas,
  ROUND(SUM(total_logical_bytes) / POW(1024, 3), 2) AS tamano_gb,
  MIN(partition_id)                                 AS primera_particion,
  MAX(partition_id)                                 AS ultima_particion
FROM `ss22s2026-g8-proyecto2.nyc_taxi_p2.INFORMATION_SCHEMA.PARTITIONS`
WHERE table_name IN ('trips_base', 'trips_opt')
GROUP BY table_name;


-- ---------------------------------------------------------------------
-- 3.5 Evidencia de clustering y columna de partición
-- ---------------------------------------------------------------------
SELECT
  table_name,
  column_name,
  is_partitioning_column,
  clustering_ordinal_position
FROM `ss22s2026-g8-proyecto2.nyc_taxi_p2.INFORMATION_SCHEMA.COLUMNS`
WHERE table_name IN ('trips_base', 'trips_opt')
  AND (is_partitioning_column = 'YES' OR clustering_ordinal_position IS NOT NULL)
ORDER BY table_name, clustering_ordinal_position;
