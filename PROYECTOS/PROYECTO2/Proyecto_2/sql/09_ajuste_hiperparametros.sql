-- =====================================================================
-- 09_ajuste_hiperparametros.sql
-- Proyecto 2 - SS22S2026 Grupo 8 | Responsable: Pablo
-- Finalidad: ajuste de hiperparámetros. Se entrena una variante "v2" de
--            cada modelo cambiando SOLO sus hiperparámetros (mismas
--            features, mismo split, mismos datos) y se compara contra la
--            versión base de 06_modelos_bqml.sql sobre octubre 2022.
--
--  Modelo base (06)          Variante (09)              Cambio
--  ------------------------  -------------------------  -----------------------------------------
--  M1  model_tip_linear      model_tip_linear_v2        l2_reg 0.1 -> 1.0 y l1_reg 0 -> 0.5
--  M2  model_tip_logistic    model_tip_logistic_v2      l2_reg 0.1 -> 1.0, sin auto_class_weights
--  M3  model_tip_boosted     model_tip_boosted_v2       árboles más profundos y learn_rate menor
--
-- La regla para elegir: menor RMSE en octubre (regresión) y mayor ROC-AUC
-- (clasificación). Noviembre NO se usa para elegir (sería data leakage hacia
-- el conjunto de prueba); solo se reporta al final como confirmación.
--
-- Requiere 08_evaluacion_modelos.sql (vista v_ml_features).
-- =====================================================================


-- ---------------------------------------------------------------------
-- 9.1 M1 v2: regresión lineal con regularización elástica (L1 + L2).
-- L1 lleva a cero los coeficientes de zonas poco frecuentes (hay ~260
-- categorías en pickup/dropoff_location_id) y reduce sobreajuste.
-- ---------------------------------------------------------------------
CREATE OR REPLACE MODEL `ss22s2026-g8-proyecto2.nyc_taxi_p2.model_tip_linear_v2`
OPTIONS (
  model_type            = 'LINEAR_REG',
  input_label_cols      = ['tip_amount'],
  data_split_method     = 'CUSTOM',
  data_split_col        = 'is_eval',
  optimize_strategy     = 'BATCH_GRADIENT_DESCENT',  -- L1 requiere descenso de gradiente
  l1_reg                = 0.5,
  l2_reg                = 1.0,
  max_iterations        = 20,
  early_stop            = TRUE,
  enable_global_explain = TRUE
) AS
SELECT * EXCEPT (pickup_datetime, pickup_date, split_set, high_tip)
FROM `ss22s2026-g8-proyecto2.nyc_taxi_p2.v_ml_features`
WHERE split_set IN ('train', 'eval');


-- ---------------------------------------------------------------------
-- 9.2 M2 v2: logística con más regularización y SIN pesos de clase.
-- Sirve para medir el efecto de auto_class_weights: sin pesos el modelo
-- tiende a favorecer la clase mayoritaria (mejor accuracy, peor recall).
-- ---------------------------------------------------------------------
CREATE OR REPLACE MODEL `ss22s2026-g8-proyecto2.nyc_taxi_p2.model_tip_logistic_v2`
OPTIONS (
  model_type            = 'LOGISTIC_REG',
  input_label_cols      = ['high_tip'],
  data_split_method     = 'CUSTOM',
  data_split_col        = 'is_eval',
  auto_class_weights    = FALSE,
  l2_reg                = 1.0,
  max_iterations        = 30,
  enable_global_explain = TRUE
) AS
SELECT * EXCEPT (pickup_datetime, pickup_date, split_set, tip_amount)
FROM `ss22s2026-g8-proyecto2.nyc_taxi_p2.v_ml_features`
WHERE split_set IN ('train', 'eval');


-- ---------------------------------------------------------------------
-- 9.3 M3 v2: boosted trees con árboles más profundos (6 -> 10), tasa de
-- aprendizaje menor (0.1 -> 0.05) compensada con más iteraciones (50 -> 100),
-- regularización L2 en las hojas y muestreo de columnas.
-- Mismo split SEQ (80/20) y misma muestra determinística del 25 % que M3.
-- ---------------------------------------------------------------------
CREATE OR REPLACE MODEL `ss22s2026-g8-proyecto2.nyc_taxi_p2.model_tip_boosted_v2`
OPTIONS (
  model_type               = 'BOOSTED_TREE_REGRESSOR',
  input_label_cols         = ['tip_amount'],
  data_split_method        = 'SEQ',
  data_split_col           = 'pickup_datetime',
  data_split_eval_fraction = 0.2,
  max_iterations           = 100,
  max_tree_depth           = 10,
  learn_rate               = 0.05,
  subsample                = 0.8,
  colsample_bytree         = 0.8,
  l2_reg                   = 1.0,
  early_stop               = TRUE,
  min_rel_progress         = 0.001,
  enable_global_explain    = TRUE
) AS
SELECT * EXCEPT (pickup_date, split_set, is_eval, high_tip)
FROM `ss22s2026-g8-proyecto2.nyc_taxi_p2.v_ml_features`
WHERE split_set IN ('train', 'eval')
  AND MOD(ABS(FARM_FINGERPRINT(CAST(pickup_datetime AS STRING))), 4) = 0;  -- misma muestra 25 % que M3


-- ---------------------------------------------------------------------
-- 9.4 Historial de entrenamiento de las variantes (iteraciones, loss, eval_loss)
-- -> captura 31_training_info_v2.png
-- ---------------------------------------------------------------------
SELECT 'model_tip_linear_v2' AS modelo, iteration, ROUND(loss, 4) AS loss, ROUND(eval_loss, 4) AS eval_loss, duration_ms
FROM ML.TRAINING_INFO(MODEL `ss22s2026-g8-proyecto2.nyc_taxi_p2.model_tip_linear_v2`)
UNION ALL
SELECT 'model_tip_logistic_v2', iteration, ROUND(loss, 4), ROUND(eval_loss, 4), duration_ms
FROM ML.TRAINING_INFO(MODEL `ss22s2026-g8-proyecto2.nyc_taxi_p2.model_tip_logistic_v2`)
UNION ALL
SELECT 'model_tip_boosted_v2', iteration, ROUND(loss, 4), ROUND(eval_loss, 4), duration_ms
FROM ML.TRAINING_INFO(MODEL `ss22s2026-g8-proyecto2.nyc_taxi_p2.model_tip_boosted_v2`)
ORDER BY modelo, iteration;


-- ---------------------------------------------------------------------
-- 9.5 Comparación base vs. v2 sobre octubre (conjunto de selección).
-- Se guarda como tabla para el tablero -> captura 32_comparacion_hiperparametros.png
-- ---------------------------------------------------------------------
CREATE OR REPLACE TABLE `ss22s2026-g8-proyecto2.nyc_taxi_p2.eval_hiperparametros`
OPTIONS (description = 'Comparación de hiperparámetros: modelos base vs v2 sobre octubre 2022')
AS
-- Regresión
SELECT 'regresion' AS tarea, 'M1 LINEAR_REG base'  AS modelo, 'l2=0.1'                          AS hiperparametros,
       SQRT(mean_squared_error) AS rmse, mean_absolute_error AS mae, r2_score AS r2,
       CAST(NULL AS FLOAT64) AS roc_auc, CAST(NULL AS FLOAT64) AS f1, CAST(NULL AS FLOAT64) AS recall, CAST(NULL AS FLOAT64) AS accuracy
FROM ML.EVALUATE(MODEL `ss22s2026-g8-proyecto2.nyc_taxi_p2.model_tip_linear`,
  (SELECT * FROM `ss22s2026-g8-proyecto2.nyc_taxi_p2.v_ml_features` WHERE split_set = 'eval'))
UNION ALL
SELECT 'regresion', 'M1 LINEAR_REG v2', 'l1=0.5, l2=1.0',
       SQRT(mean_squared_error), mean_absolute_error, r2_score, NULL, NULL, NULL, NULL
FROM ML.EVALUATE(MODEL `ss22s2026-g8-proyecto2.nyc_taxi_p2.model_tip_linear_v2`,
  (SELECT * FROM `ss22s2026-g8-proyecto2.nyc_taxi_p2.v_ml_features` WHERE split_set = 'eval'))
UNION ALL
SELECT 'regresion', 'M3 BOOSTED_TREE base', 'depth=6, lr=0.1, iter<=50',
       SQRT(mean_squared_error), mean_absolute_error, r2_score, NULL, NULL, NULL, NULL
FROM ML.EVALUATE(MODEL `ss22s2026-g8-proyecto2.nyc_taxi_p2.model_tip_boosted`,
  (SELECT * FROM `ss22s2026-g8-proyecto2.nyc_taxi_p2.v_ml_features` WHERE split_set = 'eval'))
UNION ALL
SELECT 'regresion', 'M3 BOOSTED_TREE v2', 'depth=10, lr=0.05, iter<=100, l2=1, colsample=0.8',
       SQRT(mean_squared_error), mean_absolute_error, r2_score, NULL, NULL, NULL, NULL
FROM ML.EVALUATE(MODEL `ss22s2026-g8-proyecto2.nyc_taxi_p2.model_tip_boosted_v2`,
  (SELECT * FROM `ss22s2026-g8-proyecto2.nyc_taxi_p2.v_ml_features` WHERE split_set = 'eval'))
-- Clasificación
UNION ALL
SELECT 'clasificacion', 'M2 LOGISTIC_REG base', 'l2=0.1, auto_class_weights=TRUE',
       NULL, NULL, NULL, roc_auc, f1_score, recall, accuracy
FROM ML.EVALUATE(MODEL `ss22s2026-g8-proyecto2.nyc_taxi_p2.model_tip_logistic`,
  (SELECT * FROM `ss22s2026-g8-proyecto2.nyc_taxi_p2.v_ml_features` WHERE split_set = 'eval'))
UNION ALL
SELECT 'clasificacion', 'M2 LOGISTIC_REG v2', 'l2=1.0, auto_class_weights=FALSE',
       NULL, NULL, NULL, roc_auc, f1_score, recall, accuracy
FROM ML.EVALUATE(MODEL `ss22s2026-g8-proyecto2.nyc_taxi_p2.model_tip_logistic_v2`,
  (SELECT * FROM `ss22s2026-g8-proyecto2.nyc_taxi_p2.v_ml_features` WHERE split_set = 'eval'));

SELECT tarea, modelo, hiperparametros,
       ROUND(rmse, 4) AS rmse, ROUND(mae, 4) AS mae, ROUND(r2, 4) AS r2,
       ROUND(roc_auc, 4) AS roc_auc, ROUND(f1, 4) AS f1, ROUND(recall, 4) AS recall, ROUND(accuracy, 4) AS accuracy
FROM `ss22s2026-g8-proyecto2.nyc_taxi_p2.eval_hiperparametros`
ORDER BY tarea, rmse, roc_auc DESC;


-- ---------------------------------------------------------------------
-- 9.6 Modelo elegido por tarea (regla: menor RMSE / mayor ROC-AUC en octubre)
-- -> captura 33_modelo_elegido.png
-- ---------------------------------------------------------------------
SELECT tarea, modelo, hiperparametros, ROUND(rmse, 4) AS rmse, ROUND(roc_auc, 4) AS roc_auc
FROM `ss22s2026-g8-proyecto2.nyc_taxi_p2.eval_hiperparametros`
WHERE TRUE   -- BigQuery exige WHERE/GROUP BY/HAVING junto a QUALIFY
QUALIFY ROW_NUMBER() OVER (
  PARTITION BY tarea
  ORDER BY IF(tarea = 'regresion', rmse, -roc_auc)
) = 1;
