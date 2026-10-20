-- =====================================================================
-- 11_rolling_forecast.sql
-- Proyecto 2 - SS22S2026 Grupo 8 | Responsable: Pablo
-- Finalidad: comparación de 2 predicciones con ROLLING FORECAST
--            (validación con origen móvil / ventana expansiva).
--
-- Idea: en lugar de una sola partición train/test, se "avanza en el tiempo"
-- y en cada origen se reentrena SOLO con el pasado y se predice el mes
-- siguiente. Así se simula cómo se usaría el modelo en la realidad.
--
--   Ventana   Entrena con     Predice    Origen
--   -------   -------------   --------   ----------
--   W1        ene - sep 2022  oct 2022   2022-09-30
--   W2        ene - oct 2022  nov 2022   2022-10-31
--
-- Se hacen DOS tipos de pronóstico y se comparan entre sí:
--   (A) Regresor por viaje (BOOSTED_TREE, mismos hiperparámetros que M3):
--       predice la propina de cada viaje y luego se agrega por día.
--   (B) Serie de tiempo ARIMA_PLUS: pronostica directamente la propina
--       total diaria (solo con el historial de la serie, sin features).
-- Las dos se comparan contra la propina real de cada día del mes predicho.
--
-- No hay data leakage: en cada ventana el modelo solo ve fechas anteriores
-- al origen; el mes predicho nunca se usa para entrenar esa ventana.
-- Requiere 08_evaluacion_modelos.sql (vista v_ml_features).
-- =====================================================================


-- #####################################################################
-- (A) REGRESOR POR VIAJE - una versión por ventana
-- Muestra determinística del 25 % (igual que M3) para acotar costo.
-- data_split_method = 'NO_SPLIT': la evaluación es el mes siguiente,
-- que queda fuera del entrenamiento por el filtro de fechas.
-- #####################################################################

-- W1: entrena ene-sep -> predecirá octubre
CREATE OR REPLACE MODEL `ss22s2026-g8-proyecto2.nyc_taxi_p2.rf_boosted_w1`
OPTIONS (
  model_type        = 'BOOSTED_TREE_REGRESSOR',
  input_label_cols  = ['tip_amount'],
  data_split_method = 'NO_SPLIT',
  early_stop        = FALSE,       -- sin conjunto de evaluación no hay criterio de parada
  max_iterations    = 20,          -- M3 se detuvo en 20 iteraciones (early stop)
  max_tree_depth    = 6,
  learn_rate        = 0.1,
  subsample         = 0.8
) AS
SELECT * EXCEPT (pickup_datetime, pickup_date, split_set, is_eval, high_tip)
FROM `ss22s2026-g8-proyecto2.nyc_taxi_p2.v_ml_features`
WHERE pickup_date < DATE '2022-10-01'
  AND MOD(ABS(FARM_FINGERPRINT(CAST(pickup_datetime AS STRING))), 4) = 0;

-- W2: entrena ene-oct -> predecirá noviembre (la ventana "rueda" un mes)
CREATE OR REPLACE MODEL `ss22s2026-g8-proyecto2.nyc_taxi_p2.rf_boosted_w2`
OPTIONS (
  model_type        = 'BOOSTED_TREE_REGRESSOR',
  input_label_cols  = ['tip_amount'],
  data_split_method = 'NO_SPLIT',
  early_stop        = FALSE,       -- sin conjunto de evaluación no hay criterio de parada
  max_iterations    = 20,
  max_tree_depth    = 6,
  learn_rate        = 0.1,
  subsample         = 0.8
) AS
SELECT * EXCEPT (pickup_datetime, pickup_date, split_set, is_eval, high_tip)
FROM `ss22s2026-g8-proyecto2.nyc_taxi_p2.v_ml_features`
WHERE pickup_date < DATE '2022-11-01'
  AND MOD(ABS(FARM_FINGERPRINT(CAST(pickup_datetime AS STRING))), 4) = 0;


-- #####################################################################
-- (B) ARIMA_PLUS sobre la serie diaria de propina total - una por ventana
-- holiday_region = 'US' modela feriados (Thanksgiving cae en noviembre).
-- #####################################################################

-- Serie diaria (todo el periodo; se filtra por ventana al entrenar)
CREATE OR REPLACE TABLE `ss22s2026-g8-proyecto2.nyc_taxi_p2.serie_propina_diaria`
OPTIONS (description = 'Serie de tiempo diaria: viajes y propina total (viajes con tarjeta, tabla limpia)')
AS
SELECT
  pickup_date              AS fecha,
  COUNT(*)                 AS viajes,
  SUM(tip_amount)          AS propina_total,
  AVG(tip_amount)          AS propina_prom
FROM `ss22s2026-g8-proyecto2.nyc_taxi_p2.ml_trips_clean`
GROUP BY fecha;

CREATE OR REPLACE MODEL `ss22s2026-g8-proyecto2.nyc_taxi_p2.rf_arima_w1`
OPTIONS (
  model_type                = 'ARIMA_PLUS',
  time_series_timestamp_col = 'fecha',
  time_series_data_col      = 'propina_total',
  auto_arima                = TRUE,
  data_frequency            = 'DAILY',
  holiday_region            = 'US'
) AS
SELECT fecha, propina_total
FROM `ss22s2026-g8-proyecto2.nyc_taxi_p2.serie_propina_diaria`
WHERE fecha < DATE '2022-10-01';

CREATE OR REPLACE MODEL `ss22s2026-g8-proyecto2.nyc_taxi_p2.rf_arima_w2`
OPTIONS (
  model_type                = 'ARIMA_PLUS',
  time_series_timestamp_col = 'fecha',
  time_series_data_col      = 'propina_total',
  auto_arima                = TRUE,
  data_frequency            = 'DAILY',
  holiday_region            = 'US'
) AS
SELECT fecha, propina_total
FROM `ss22s2026-g8-proyecto2.nyc_taxi_p2.serie_propina_diaria`
WHERE fecha < DATE '2022-11-01';


-- #####################################################################
-- RESULTADOS: real vs. pronóstico por día y ventana
-- #####################################################################
CREATE OR REPLACE TABLE `ss22s2026-g8-proyecto2.nyc_taxi_p2.rolling_forecast_diario`
OPTIONS (description = 'Rolling forecast: propina total diaria real vs boosted (agregado) vs ARIMA_PLUS, ventanas W1 (oct) y W2 (nov)')
AS
WITH
-- (A) predicción por viaje con el modelo de cada ventana, agregada por día.
-- El regresor se entrenó con 25 % de los viajes, pero predice TODOS los
-- viajes del mes, así que la suma es comparable con el total real.
boosted AS (
  SELECT 'W1 (origen 30-sep, predice oct)' AS ventana, pickup_date AS fecha,
         SUM(GREATEST(predicted_tip_amount, 0)) AS pred_boosted
  FROM ML.PREDICT(MODEL `ss22s2026-g8-proyecto2.nyc_taxi_p2.rf_boosted_w1`,
    (SELECT * FROM `ss22s2026-g8-proyecto2.nyc_taxi_p2.v_ml_features`
     WHERE pickup_date BETWEEN DATE '2022-10-01' AND DATE '2022-10-31'))
  GROUP BY fecha
  UNION ALL
  SELECT 'W2 (origen 31-oct, predice nov)', pickup_date,
         SUM(GREATEST(predicted_tip_amount, 0))
  FROM ML.PREDICT(MODEL `ss22s2026-g8-proyecto2.nyc_taxi_p2.rf_boosted_w2`,
    (SELECT * FROM `ss22s2026-g8-proyecto2.nyc_taxi_p2.v_ml_features`
     WHERE pickup_date BETWEEN DATE '2022-11-01' AND DATE '2022-11-30'))
  GROUP BY pickup_date
),
-- (B) pronóstico de la serie (31 días de octubre, 30 de noviembre)
arima AS (
  SELECT 'W1 (origen 30-sep, predice oct)' AS ventana, DATE(forecast_timestamp) AS fecha,
         forecast_value AS pred_arima,
         prediction_interval_lower_bound AS arima_li, prediction_interval_upper_bound AS arima_ls
  FROM ML.FORECAST(MODEL `ss22s2026-g8-proyecto2.nyc_taxi_p2.rf_arima_w1`,
                   STRUCT(31 AS horizon, 0.9 AS confidence_level))
  UNION ALL
  SELECT 'W2 (origen 31-oct, predice nov)', DATE(forecast_timestamp),
         forecast_value, prediction_interval_lower_bound, prediction_interval_upper_bound
  FROM ML.FORECAST(MODEL `ss22s2026-g8-proyecto2.nyc_taxi_p2.rf_arima_w2`,
                   STRUCT(30 AS horizon, 0.9 AS confidence_level))
)
SELECT
  b.ventana,
  b.fecha,
  r.viajes,
  ROUND(r.propina_total, 2)                AS propina_real,
  ROUND(b.pred_boosted, 2)                 AS pred_boosted,
  ROUND(a.pred_arima, 2)                   AS pred_arima,
  ROUND(a.arima_li, 2)                     AS arima_limite_inf_90,
  ROUND(a.arima_ls, 2)                     AS arima_limite_sup_90,
  ROUND(b.pred_boosted - r.propina_total, 2) AS error_boosted,
  ROUND(a.pred_arima   - r.propina_total, 2) AS error_arima
FROM boosted b
JOIN arima a USING (ventana, fecha)
JOIN `ss22s2026-g8-proyecto2.nyc_taxi_p2.serie_propina_diaria` r USING (fecha);


-- Detalle por día -> captura 37_rolling_forecast_diario.png
SELECT * FROM `ss22s2026-g8-proyecto2.nyc_taxi_p2.rolling_forecast_diario`
ORDER BY ventana, fecha;


-- ---------------------------------------------------------------------
-- Resumen de error por ventana y método (comparación de las 2 predicciones)
-- MAPE = error porcentual absoluto medio sobre la propina total diaria.
-- -> captura 38_rolling_forecast_resumen.png
-- ---------------------------------------------------------------------
CREATE OR REPLACE TABLE `ss22s2026-g8-proyecto2.nyc_taxi_p2.rolling_forecast_resumen`
OPTIONS (description = 'Error del rolling forecast por ventana y método')
AS
SELECT
  ventana,
  COUNT(*)                                                       AS dias,
  ROUND(SUM(propina_real), 0)                                    AS propina_real_mes,
  ROUND(SUM(pred_boosted), 0)                                    AS pred_boosted_mes,
  ROUND(SUM(pred_arima), 0)                                      AS pred_arima_mes,
  ROUND(AVG(ABS(error_boosted)), 0)                              AS mae_diario_boosted,
  ROUND(AVG(ABS(error_arima)), 0)                                AS mae_diario_arima,
  ROUND(100 * AVG(ABS(error_boosted) / propina_real), 2)         AS mape_boosted_pct,
  ROUND(100 * AVG(ABS(error_arima)   / propina_real), 2)         AS mape_arima_pct,
  ROUND(100 * COUNTIF(propina_real BETWEEN arima_limite_inf_90 AND arima_limite_sup_90) / COUNT(*), 1)
                                                                 AS pct_dias_dentro_ic90_arima
FROM `ss22s2026-g8-proyecto2.nyc_taxi_p2.rolling_forecast_diario`
GROUP BY ventana;

SELECT * FROM `ss22s2026-g8-proyecto2.nyc_taxi_p2.rolling_forecast_resumen` ORDER BY ventana;


-- ---------------------------------------------------------------------
-- Error por viaje de cada ventana (RMSE / MAE de propina individual):
-- permite ver si el modelo mejora al reentrenar con un mes más de datos.
-- ---------------------------------------------------------------------
SELECT 'W1 -> oct' AS ventana, SQRT(mean_squared_error) AS rmse, mean_absolute_error AS mae, r2_score AS r2
FROM ML.EVALUATE(MODEL `ss22s2026-g8-proyecto2.nyc_taxi_p2.rf_boosted_w1`,
  (SELECT * FROM `ss22s2026-g8-proyecto2.nyc_taxi_p2.v_ml_features`
   WHERE pickup_date BETWEEN DATE '2022-10-01' AND DATE '2022-10-31'))
UNION ALL
SELECT 'W2 -> nov', SQRT(mean_squared_error), mean_absolute_error, r2_score
FROM ML.EVALUATE(MODEL `ss22s2026-g8-proyecto2.nyc_taxi_p2.rf_boosted_w2`,
  (SELECT * FROM `ss22s2026-g8-proyecto2.nyc_taxi_p2.v_ml_features`
   WHERE pickup_date BETWEEN DATE '2022-11-01' AND DATE '2022-11-30'));
