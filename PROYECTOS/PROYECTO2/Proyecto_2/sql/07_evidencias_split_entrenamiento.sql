-- =====================================================================
-- 07_evidencias_split_entrenamiento.sql
-- Proyecto 2 - SS22S2026 Grupo 8 | Responsable: Estuardo
-- Finalidad: generar evidencia de (a) split temporal sin solapamiento y
--            (b) entrenamiento de los modelos (iteraciones y features usadas).
-- Ejecutar después de 06_modelos_bqml.sql.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 7.1 Tamaño y rango de fechas por conjunto (no deben solaparse)
-- ---------------------------------------------------------------------
SELECT
  split_set,
  COUNT(*)                                       AS filas,
  MIN(pickup_date)                               AS fecha_min,
  MAX(pickup_date)                               AS fecha_max,
  ROUND(AVG(tip_amount), 3)                      AS propina_promedio,
  ROUND(100 * AVG(CAST(high_tip AS INT64)), 2)   AS pct_high_tip
FROM `ss22s2026-g8-proyecto2.nyc_taxi_p2.ml_trips_clean`
GROUP BY split_set
ORDER BY fecha_min;


-- ---------------------------------------------------------------------
-- 7.2 Comprobación de no-solapamiento: debe devolver TRUE
-- (la última fecha de train es anterior a la primera de eval, y así con new_records)
-- ---------------------------------------------------------------------
SELECT
  MAX(IF(split_set = 'train', pickup_date, NULL)) <  MIN(IF(split_set = 'eval', pickup_date, NULL))
  AND MAX(IF(split_set = 'eval', pickup_date, NULL)) < MIN(IF(split_set = 'new_records', pickup_date, NULL))
  AS split_temporal_sin_solapamiento
FROM `ss22s2026-g8-proyecto2.nyc_taxi_p2.ml_trips_clean`;


-- ---------------------------------------------------------------------
-- 7.3 Features realmente usadas por cada modelo
-- Verificar que NO aparecen tip_amount / tip_pct / total_amount / columnas de split.
-- ---------------------------------------------------------------------
SELECT 'model_tip_linear'   AS modelo, * FROM ML.FEATURE_INFO(MODEL `ss22s2026-g8-proyecto2.nyc_taxi_p2.model_tip_linear`)
UNION ALL
SELECT 'model_tip_logistic' AS modelo, * FROM ML.FEATURE_INFO(MODEL `ss22s2026-g8-proyecto2.nyc_taxi_p2.model_tip_logistic`)
ORDER BY modelo, input;

SELECT * FROM ML.FEATURE_INFO(MODEL `ss22s2026-g8-proyecto2.nyc_taxi_p2.model_tip_boosted`) ORDER BY input;


-- ---------------------------------------------------------------------
-- 7.4 Historial de entrenamiento (pérdida por iteración, duración)
-- ---------------------------------------------------------------------
SELECT 'model_tip_linear' AS modelo, iteration, loss, eval_loss, learning_rate, duration_ms
FROM ML.TRAINING_INFO(MODEL `ss22s2026-g8-proyecto2.nyc_taxi_p2.model_tip_linear`)
ORDER BY iteration;

SELECT 'model_tip_logistic' AS modelo, iteration, loss, eval_loss, learning_rate, duration_ms
FROM ML.TRAINING_INFO(MODEL `ss22s2026-g8-proyecto2.nyc_taxi_p2.model_tip_logistic`)
ORDER BY iteration;

SELECT 'model_tip_boosted' AS modelo, iteration, loss, eval_loss, learning_rate, duration_ms
FROM ML.TRAINING_INFO(MODEL `ss22s2026-g8-proyecto2.nyc_taxi_p2.model_tip_boosted`)
ORDER BY iteration;


-- ---------------------------------------------------------------------
-- 7.5 Importancia global de variables (explicabilidad)
-- ---------------------------------------------------------------------
SELECT * FROM ML.GLOBAL_EXPLAIN(MODEL `ss22s2026-g8-proyecto2.nyc_taxi_p2.model_tip_linear`)
ORDER BY attribution DESC;
