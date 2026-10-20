-- =====================================================================
-- 08_evaluacion_modelos.sql
-- Proyecto 2 - SS22S2026 Grupo 8 | Responsable: Pablo
-- Finalidad: evaluar y comparar los modelos entrenados en 06_modelos_bqml.sql
--            con ML.EVALUATE, ML.CONFUSION_MATRIX y ML.ROC_CURVE.
--
-- Criterio de comparación JUSTA:
--   * Todos los modelos se evalúan sobre el MISMO conjunto: octubre 2022
--     (split_set = 'eval'), que ningún modelo usó para entrenar.
--     - M1 y M2 entrenaron solo con ene-sep (split CUSTOM con is_eval).
--     - M3 (SEQ, 80/20 sobre ene-oct) entrenó con el 80 % más antiguo
--       (~ene a inicio de sep); octubre cae completo en su 20 % de evaluación.
--   * Se repite la evaluación sobre noviembre (new_records) para medir la
--     generalización a datos nunca vistos.
--   * Se compara contra un BASELINE ingenuo (predecir siempre la propina
--     media de train) para saber si el modelo realmente aporta.
--
-- Requiere: 05_tabla_ml.sql y 06_modelos_bqml.sql ejecutados.
-- Reemplazar ss22s2026-g8-proyecto2 por el ID real del proyecto GCP.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 8.0 Vista de features: aplica EXACTAMENTE las mismas transformaciones
-- que se usaron al entrenar (CAST a STRING de hora, día y rate_code).
-- Evita repetir la lista de columnas en cada ML.EVALUATE / ML.PREDICT.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW `ss22s2026-g8-proyecto2.nyc_taxi_p2.v_ml_features`
OPTIONS (description = 'Features de ml_trips_clean con los mismos tipos usados en el entrenamiento')
AS
SELECT
  -- columnas de control (no son features)
  pickup_datetime,
  pickup_date,
  split_set,
  is_eval,
  -- features
  CAST(pickup_hour AS STRING)   AS pickup_hour,
  CAST(pickup_dow  AS STRING)   AS pickup_dow,
  is_weekend,
  is_rush_hour,
  pickup_location_id,
  dropoff_location_id,
  passenger_count,
  CAST(rate_code_id AS STRING)  AS rate_code_id,
  is_airport,
  trip_distance,
  trip_duration_min,
  avg_speed_mph,
  fare_amount,
  fare_per_mile,
  tolls_amount,
  has_tolls,
  -- etiquetas
  tip_amount,
  high_tip
FROM `ss22s2026-g8-proyecto2.nyc_taxi_p2.ml_trips_clean`;


-- #####################################################################
-- PARTE A: MODELOS DE REGRESIÓN (M1 lineal vs M3 boosted) -> tip_amount
-- Métricas: RMSE (= raíz de mean_squared_error), MAE, R².
-- RMSE penaliza más los errores grandes; MAE se interpreta en USD.
-- #####################################################################

-- 8.1 Evaluación con el conjunto de evaluación reservado en el entrenamiento
--     (sin parámetro de datos: BigQuery usa el split definido en el modelo)
SELECT 'M1 model_tip_linear (split propio)' AS modelo,
       mean_absolute_error, mean_squared_error,
       SQRT(mean_squared_error) AS rmse, median_absolute_error, r2_score, explained_variance
FROM ML.EVALUATE(MODEL `ss22s2026-g8-proyecto2.nyc_taxi_p2.model_tip_linear`)
UNION ALL
SELECT 'M3 model_tip_boosted (split propio)',
       mean_absolute_error, mean_squared_error,
       SQRT(mean_squared_error), median_absolute_error, r2_score, explained_variance
FROM ML.EVALUATE(MODEL `ss22s2026-g8-proyecto2.nyc_taxi_p2.model_tip_boosted`);


-- 8.2 Tabla de comparación (regresión) sobre el MISMO conjunto: octubre y noviembre
--     + baseline ingenuo. Se guarda como tabla para el tablero de Looker Studio.
CREATE OR REPLACE TABLE `ss22s2026-g8-proyecto2.nyc_taxi_p2.eval_regresion`
OPTIONS (description = 'ML.EVALUATE de los modelos de regresión de propina (oct y nov 2022)')
AS
WITH baseline AS (
  -- propina media de entrenamiento: el "modelo" más simple posible
  SELECT AVG(tip_amount) AS tip_media
  FROM `ss22s2026-g8-proyecto2.nyc_taxi_p2.ml_trips_clean`
  WHERE split_set = 'train'
),
baseline_eval AS (
  SELECT
    c.split_set,
    AVG(ABS(c.tip_amount - b.tip_media))  AS mae,
    AVG(POW(c.tip_amount - b.tip_media, 2)) AS mse,
    1 - AVG(POW(c.tip_amount - b.tip_media, 2)) / VAR_POP(c.tip_amount) AS r2  -- ≈ 0 (o negativo)
  FROM `ss22s2026-g8-proyecto2.nyc_taxi_p2.ml_trips_clean` c CROSS JOIN baseline b
  WHERE c.split_set IN ('eval', 'new_records')
  GROUP BY c.split_set
)
SELECT 'M1 LINEAR_REG' AS modelo, 'eval (oct)' AS conjunto,
       mean_absolute_error AS mae, mean_squared_error AS mse,
       SQRT(mean_squared_error) AS rmse, r2_score AS r2
FROM ML.EVALUATE(MODEL `ss22s2026-g8-proyecto2.nyc_taxi_p2.model_tip_linear`,
  (SELECT * FROM `ss22s2026-g8-proyecto2.nyc_taxi_p2.v_ml_features` WHERE split_set = 'eval'))
UNION ALL
SELECT 'M3 BOOSTED_TREE', 'eval (oct)',
       mean_absolute_error, mean_squared_error, SQRT(mean_squared_error), r2_score
FROM ML.EVALUATE(MODEL `ss22s2026-g8-proyecto2.nyc_taxi_p2.model_tip_boosted`,
  (SELECT * FROM `ss22s2026-g8-proyecto2.nyc_taxi_p2.v_ml_features` WHERE split_set = 'eval'))
UNION ALL
SELECT 'M1 LINEAR_REG', 'new_records (nov)',
       mean_absolute_error, mean_squared_error, SQRT(mean_squared_error), r2_score
FROM ML.EVALUATE(MODEL `ss22s2026-g8-proyecto2.nyc_taxi_p2.model_tip_linear`,
  (SELECT * FROM `ss22s2026-g8-proyecto2.nyc_taxi_p2.v_ml_features` WHERE split_set = 'new_records'))
UNION ALL
SELECT 'M3 BOOSTED_TREE', 'new_records (nov)',
       mean_absolute_error, mean_squared_error, SQRT(mean_squared_error), r2_score
FROM ML.EVALUATE(MODEL `ss22s2026-g8-proyecto2.nyc_taxi_p2.model_tip_boosted`,
  (SELECT * FROM `ss22s2026-g8-proyecto2.nyc_taxi_p2.v_ml_features` WHERE split_set = 'new_records'))
UNION ALL
SELECT 'BASELINE (media train)',
       IF(split_set = 'eval', 'eval (oct)', 'new_records (nov)'),
       mae, mse, SQRT(mse), r2
FROM baseline_eval;

-- Resultado para la captura 26_eval_regresion.png
SELECT modelo, conjunto,
       ROUND(mae, 4) AS mae, ROUND(rmse, 4) AS rmse, ROUND(r2, 4) AS r2
FROM `ss22s2026-g8-proyecto2.nyc_taxi_p2.eval_regresion`
ORDER BY conjunto, rmse;


-- #####################################################################
-- PARTE B: MODELO DE CLASIFICACIÓN (M2 logístico) -> high_tip
-- Métricas: ROC-AUC (independiente del umbral), precision, recall,
-- F1, accuracy, log_loss y matriz de confusión.
-- #####################################################################

-- 8.3 Métricas generales con umbral por defecto (0.5) sobre octubre y noviembre
CREATE OR REPLACE TABLE `ss22s2026-g8-proyecto2.nyc_taxi_p2.eval_clasificacion`
OPTIONS (description = 'ML.EVALUATE del modelo logístico high_tip (oct y nov 2022)')
AS
SELECT 'M2 LOGISTIC_REG' AS modelo, 'eval (oct)' AS conjunto, *
FROM ML.EVALUATE(MODEL `ss22s2026-g8-proyecto2.nyc_taxi_p2.model_tip_logistic`,
  (SELECT * FROM `ss22s2026-g8-proyecto2.nyc_taxi_p2.v_ml_features` WHERE split_set = 'eval'))
UNION ALL
SELECT 'M2 LOGISTIC_REG', 'new_records (nov)', *
FROM ML.EVALUATE(MODEL `ss22s2026-g8-proyecto2.nyc_taxi_p2.model_tip_logistic`,
  (SELECT * FROM `ss22s2026-g8-proyecto2.nyc_taxi_p2.v_ml_features` WHERE split_set = 'new_records'));

-- Resultado para la captura 27_eval_clasificacion.png
SELECT modelo, conjunto,
       ROUND(roc_auc, 4) AS roc_auc, ROUND(precision, 4) AS precision_, ROUND(recall, 4) AS recall,
       ROUND(f1_score, 4) AS f1, ROUND(accuracy, 4) AS accuracy, ROUND(log_loss, 4) AS log_loss
FROM `ss22s2026-g8-proyecto2.nyc_taxi_p2.eval_clasificacion`
ORDER BY conjunto;


-- 8.4 Matriz de confusión (umbral 0.5) sobre octubre -> captura 28_matriz_confusion.png
--     Filas = clase real, columnas = clase predicha.
SELECT *
FROM ML.CONFUSION_MATRIX(MODEL `ss22s2026-g8-proyecto2.nyc_taxi_p2.model_tip_logistic`,
  (SELECT * FROM `ss22s2026-g8-proyecto2.nyc_taxi_p2.v_ml_features` WHERE split_set = 'eval'));


-- 8.5 Curva ROC: TPR/FPR por umbral. Se guarda para graficarla en el tablero
--     y para elegir el umbral óptimo (máximo F1).
CREATE OR REPLACE TABLE `ss22s2026-g8-proyecto2.nyc_taxi_p2.eval_roc_logistic`
OPTIONS (description = 'ML.ROC_CURVE del modelo logístico sobre octubre 2022')
AS
SELECT
  threshold,
  recall,
  false_positive_rate,
  true_positives, false_positives, true_negatives, false_negatives,
  SAFE_DIVIDE(true_positives, true_positives + false_positives) AS precision_,
  SAFE_DIVIDE(2 * true_positives, 2 * true_positives + false_positives + false_negatives) AS f1
FROM ML.ROC_CURVE(MODEL `ss22s2026-g8-proyecto2.nyc_taxi_p2.model_tip_logistic`,
  (SELECT * FROM `ss22s2026-g8-proyecto2.nyc_taxi_p2.v_ml_features` WHERE split_set = 'eval'),
  GENERATE_ARRAY(0.05, 0.95, 0.05));

-- Umbral con mejor F1 -> captura 29_umbral_optimo.png
SELECT ROUND(threshold, 2) AS umbral, ROUND(precision_, 4) AS precision_,
       ROUND(recall, 4) AS recall, ROUND(f1, 4) AS f1, ROUND(false_positive_rate, 4) AS fpr
FROM `ss22s2026-g8-proyecto2.nyc_taxi_p2.eval_roc_logistic`
ORDER BY f1 DESC
LIMIT 5;

-- Matriz de confusión con el umbral óptimo (reemplazar 0.45 por el umbral de la consulta anterior)
SELECT *
FROM ML.CONFUSION_MATRIX(MODEL `ss22s2026-g8-proyecto2.nyc_taxi_p2.model_tip_logistic`,
  (SELECT * FROM `ss22s2026-g8-proyecto2.nyc_taxi_p2.v_ml_features` WHERE split_set = 'eval'),
  STRUCT(0.45 AS threshold));


-- #####################################################################
-- PARTE C: interpretación - qué variables pesan más en cada modelo
-- (los modelos se entrenaron con enable_global_explain = TRUE)
-- #####################################################################

-- 8.6 Importancia global de variables -> captura 30_global_explain.png
SELECT 'M1 LINEAR_REG' AS modelo, feature, ROUND(attribution, 4) AS attribution
FROM ML.GLOBAL_EXPLAIN(MODEL `ss22s2026-g8-proyecto2.nyc_taxi_p2.model_tip_linear`)
UNION ALL
SELECT 'M3 BOOSTED_TREE', feature, ROUND(attribution, 4)
FROM ML.GLOBAL_EXPLAIN(MODEL `ss22s2026-g8-proyecto2.nyc_taxi_p2.model_tip_boosted`)
UNION ALL
SELECT 'M2 LOGISTIC_REG', feature, ROUND(attribution, 4)
FROM ML.GLOBAL_EXPLAIN(MODEL `ss22s2026-g8-proyecto2.nyc_taxi_p2.model_tip_logistic`)
ORDER BY modelo, attribution DESC;


-- 8.7 Error por segmento (M3 en octubre): ¿dónde se equivoca más el modelo?
--     Útil para la discusión de resultados (aeropuerto vs. ciudad, hora).
SELECT
  is_airport,
  pickup_hour,
  COUNT(*)                                                        AS viajes,
  ROUND(AVG(tip_amount), 3)                                       AS propina_real_prom,
  ROUND(AVG(predicted_tip_amount), 3)                             AS propina_pred_prom,
  ROUND(SQRT(AVG(POW(predicted_tip_amount - tip_amount, 2))), 3)  AS rmse
FROM ML.PREDICT(MODEL `ss22s2026-g8-proyecto2.nyc_taxi_p2.model_tip_boosted`,
  (SELECT * FROM `ss22s2026-g8-proyecto2.nyc_taxi_p2.v_ml_features` WHERE split_set = 'eval'))
GROUP BY is_airport, pickup_hour
ORDER BY is_airport, CAST(pickup_hour AS INT64);
