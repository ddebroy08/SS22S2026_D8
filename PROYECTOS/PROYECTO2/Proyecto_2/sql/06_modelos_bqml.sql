-- =====================================================================
-- 06_modelos_bqml.sql
-- Proyecto 2 - SS22S2026 Grupo 8 | Responsable: Estuardo (entrenamiento)
--                                   Pablo (evaluación / hiperparámetros)
-- Finalidad: entrenar los modelos en BigQuery ML sobre ml_trips_clean.
--
-- Modelos:
--   M1  model_tip_linear   LINEAR_REG        -> tip_amount   (regresión)      split CUSTOM
--   M2  model_tip_logistic LOGISTIC_REG      -> high_tip     (clasificación)  split CUSTOM
--   M3  model_tip_boosted  BOOSTED_TREE_REG  -> tip_amount   (variante M1)     split SEQ + data_split_eval_fraction
--
-- PREVENCIÓN DE DATA LEAKAGE:
--   * Nunca se incluyen como features: tip_amount, tip_pct, high_tip,
--     total_amount (contiene la propina) ni dropoff_datetime.
--   * pickup_month se excluye: con split temporal el mes de eval (oct) no
--     existe en train, y el mes no generaliza a "futuro".
--   * El split es TEMPORAL (train ene-sep / eval oct / new_records nov).
--     Un split aleatorio mezclaría días futuros en entrenamiento.
--   * M1 y M2 usan data_split_method='CUSTOM' con la columna booleana is_eval
--     (TRUE = evaluación) -> mismo conjunto de evaluación para compararlos.
--   * M3 usa data_split_method='SEQ' + data_split_eval_fraction=0.2 sobre
--     pickup_datetime: el 80% más antiguo entrena y el 20% más reciente evalúa.
--
-- COSTO: entrenar con ~30M filas puede tardar. M3 usa muestra determinística
-- del 25% (hash) para acotar tiempo y costo.
-- =====================================================================


-- ---------------------------------------------------------------------
-- M1: Regresión lineal regularizada - predice tip_amount (USD)
-- ---------------------------------------------------------------------
CREATE OR REPLACE MODEL `ss22s2026-g8-proyecto2.nyc_taxi_p2.model_tip_linear`
OPTIONS (
  model_type           = 'LINEAR_REG',
  input_label_cols     = ['tip_amount'],
  data_split_method    = 'CUSTOM',
  data_split_col       = 'is_eval',
  optimize_strategy    = 'AUTO_STRATEGY',
  l2_reg               = 0.1,
  max_iterations       = 20,
  enable_global_explain = TRUE
) AS
SELECT
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
  is_eval,                      -- columna de split (CUSTOM): TRUE = evaluación
  tip_amount                    -- LABEL
FROM `ss22s2026-g8-proyecto2.nyc_taxi_p2.ml_trips_clean`
WHERE split_set IN ('train', 'eval');   -- noviembre queda fuera (registros nuevos)


-- ---------------------------------------------------------------------
-- M2: Regresión logística - predice high_tip (1 = propina >= 20% de la tarifa)
-- auto_class_weights compensa el desbalance entre clases.
-- ---------------------------------------------------------------------
CREATE OR REPLACE MODEL `ss22s2026-g8-proyecto2.nyc_taxi_p2.model_tip_logistic`
OPTIONS (
  model_type           = 'LOGISTIC_REG',
  input_label_cols     = ['high_tip'],
  data_split_method    = 'CUSTOM',
  data_split_col       = 'is_eval',
  auto_class_weights   = TRUE,
  l2_reg               = 0.1,
  max_iterations       = 20,
  enable_global_explain = TRUE
) AS
SELECT
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
  is_eval,
  high_tip                      -- LABEL
FROM `ss22s2026-g8-proyecto2.nyc_taxi_p2.ml_trips_clean`
WHERE split_set IN ('train', 'eval');


-- ---------------------------------------------------------------------
-- M3 (variante de hiperparámetros / split): árboles potenciados para tip_amount
-- Split SEQ con data_split_eval_fraction: ordena por pickup_datetime y reserva
-- el 20% más reciente para evaluación.
-- ---------------------------------------------------------------------
CREATE OR REPLACE MODEL `ss22s2026-g8-proyecto2.nyc_taxi_p2.model_tip_boosted`
OPTIONS (
  model_type             = 'BOOSTED_TREE_REGRESSOR',
  input_label_cols       = ['tip_amount'],
  data_split_method      = 'SEQ',
  data_split_col         = 'pickup_datetime',
  data_split_eval_fraction = 0.2,
  max_iterations         = 50,
  max_tree_depth         = 6,
  learn_rate             = 0.1,
  subsample              = 0.8,
  early_stop             = TRUE,
  enable_global_explain  = TRUE
) AS
SELECT
  pickup_datetime,              -- columna de split (SEQ)
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
  tip_amount                    -- LABEL
FROM `ss22s2026-g8-proyecto2.nyc_taxi_p2.ml_trips_clean`
WHERE split_set IN ('train', 'eval')
  AND MOD(ABS(FARM_FINGERPRINT(CAST(pickup_datetime AS STRING))), 4) = 0;  -- muestra 25% determinística
