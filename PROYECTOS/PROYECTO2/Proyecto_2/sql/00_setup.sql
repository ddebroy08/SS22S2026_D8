-- =====================================================================
-- 00_setup.sql
-- Proyecto 2 - SS22S2026 Grupo 8 | Responsable: Estuardo
-- Finalidad: crear el dataset (esquema) propio donde vivirán las tablas
--            derivadas y los modelos de BigQuery ML.
-- IMPORTANTE: la ubicación debe ser 'US' (misma del dataset público
--             bigquery-public-data.new_york_taxi_trips). Si se crea en otra
--             región, las consultas contra la tabla pública fallan.
-- Reemplazar ss22s2026-g8-proyecto2 por el ID real del proyecto GCP.
-- =====================================================================

CREATE SCHEMA IF NOT EXISTS `ss22s2026-g8-proyecto2.nyc_taxi_p2`
OPTIONS (
  location    = 'US',
  description = 'Proyecto 2 SS22S2026 G8 - tablas derivadas y modelos BigQuery ML sobre NYC Yellow Taxi 2022'
);
