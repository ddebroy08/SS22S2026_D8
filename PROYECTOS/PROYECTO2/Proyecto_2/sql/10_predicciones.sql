-- =====================================================================
-- 10_predicciones.sql
-- Proyecto 2 - SS22S2026 Grupo 8 | Responsable: Pablo
-- Finalidad: ejecutar ML.PREDICT sobre REGISTROS NUEVOS y guardar las
--            tablas de resultados con predicciones.
--
--   * ml_new_records (noviembre 2022): ningún modelo lo vio al entrenar,
--     evaluar ni ajustar hiperparámetros -> es el conjunto de prueba real.
--   * Viajes hipotéticos escritos a mano (sección 10.4): demuestran el uso
--     del modelo "en producción" con datos que no existen en el dataset.
--
-- Se predice con los dos regresores (M1 lineal y M3 boosted) y con el
-- clasificador (M2 logístico) en una sola tabla para poder comparar las
-- predicciones fila por fila. Si en 09_ajuste_hiperparametros.sql ganó una
-- variante _v2, basta reemplazar el nombre del modelo.
--
-- Requiere 08_evaluacion_modelos.sql (vista v_ml_features).
-- =====================================================================


-- ---------------------------------------------------------------------
-- 10.1 Tabla de predicciones por viaje (noviembre 2022).
-- ML.PREDICT devuelve todas las columnas de entrada + predicted_<label>;
-- se encadenan las tres predicciones renombrando cada salida.
-- ---------------------------------------------------------------------
CREATE OR REPLACE TABLE `ss22s2026-g8-proyecto2.nyc_taxi_p2.pred_nuevos_registros`
PARTITION BY pickup_date
CLUSTER BY pickup_location_id, dropoff_location_id
OPTIONS (description = 'ML.PREDICT de M1, M3 y M2 sobre noviembre 2022 (registros nuevos)')
AS
WITH p_linear AS (
  SELECT * EXCEPT (predicted_tip_amount),
         predicted_tip_amount AS pred_tip_linear
  FROM ML.PREDICT(MODEL `ss22s2026-g8-proyecto2.nyc_taxi_p2.model_tip_linear`,
    (SELECT * FROM `ss22s2026-g8-proyecto2.nyc_taxi_p2.v_ml_features` WHERE split_set = 'new_records'))
),
p_boosted AS (
  SELECT * EXCEPT (predicted_tip_amount),
         predicted_tip_amount AS pred_tip_boosted
  FROM ML.PREDICT(MODEL `ss22s2026-g8-proyecto2.nyc_taxi_p2.model_tip_boosted`,
    (SELECT * FROM p_linear))
),
p_logistic AS (
  SELECT * EXCEPT (predicted_high_tip, predicted_high_tip_probs),
         predicted_high_tip AS pred_high_tip,
         (SELECT p.prob FROM UNNEST(predicted_high_tip_probs) p WHERE p.label) AS prob_high_tip
  FROM ML.PREDICT(MODEL `ss22s2026-g8-proyecto2.nyc_taxi_p2.model_tip_logistic`,
    (SELECT * FROM p_boosted))
)
SELECT
  pickup_datetime,
  pickup_date,
  pickup_hour,
  pickup_dow,
  pickup_location_id,
  dropoff_location_id,
  is_airport,
  trip_distance,
  trip_duration_min,
  fare_amount,
  -- valores reales
  tip_amount                                AS tip_real,
  high_tip                                  AS high_tip_real,
  -- predicciones
  ROUND(GREATEST(pred_tip_linear, 0), 2)    AS pred_tip_linear,   -- una propina no puede ser negativa
  ROUND(GREATEST(pred_tip_boosted, 0), 2)   AS pred_tip_boosted,
  pred_high_tip,
  ROUND(prob_high_tip, 4)                   AS prob_high_tip,
  -- errores (positivo = el modelo sobreestima)
  ROUND(GREATEST(pred_tip_linear, 0)  - tip_amount, 2) AS error_linear,
  ROUND(GREATEST(pred_tip_boosted, 0) - tip_amount, 2) AS error_boosted
FROM p_logistic;


-- ---------------------------------------------------------------------
-- 10.2 Muestra de la tabla de resultados -> captura 34_tabla_predicciones.png
-- ---------------------------------------------------------------------
SELECT pickup_datetime, pickup_location_id, dropoff_location_id, trip_distance, fare_amount,
       tip_real, pred_tip_linear, pred_tip_boosted, high_tip_real, pred_high_tip, prob_high_tip
FROM `ss22s2026-g8-proyecto2.nyc_taxi_p2.pred_nuevos_registros`
WHERE pickup_date = DATE '2022-11-15'          -- poda de partición: solo lee un día
ORDER BY pickup_datetime
LIMIT 25;


-- ---------------------------------------------------------------------
-- 10.3 Resumen de desempeño sobre los registros nuevos
-- -> captura 35_resumen_predicciones.png
-- ---------------------------------------------------------------------
SELECT
  COUNT(*)                                                         AS viajes_predichos,
  ROUND(AVG(tip_real), 3)                                          AS propina_real_prom,
  ROUND(AVG(pred_tip_linear), 3)                                   AS propina_pred_linear_prom,
  ROUND(AVG(pred_tip_boosted), 3)                                  AS propina_pred_boosted_prom,
  ROUND(SQRT(AVG(POW(error_linear, 2))), 4)                        AS rmse_linear,
  ROUND(SQRT(AVG(POW(error_boosted, 2))), 4)                       AS rmse_boosted,
  ROUND(AVG(ABS(error_linear)), 4)                                 AS mae_linear,
  ROUND(AVG(ABS(error_boosted)), 4)                                AS mae_boosted,
  ROUND(100 * COUNTIF(ABS(error_boosted) <= 1) / COUNT(*), 2)      AS pct_boosted_error_menor_1usd,
  ROUND(100 * COUNTIF(pred_high_tip = high_tip_real) / COUNT(*), 2) AS accuracy_logistic_pct
FROM `ss22s2026-g8-proyecto2.nyc_taxi_p2.pred_nuevos_registros`;


-- ---------------------------------------------------------------------
-- 10.4 Predicción sobre viajes HIPOTÉTICOS (no existen en el dataset).
-- Las columnas deben tener los mismos nombres y tipos usados al entrenar.
-- Zonas: 132 = JFK, 138 = LaGuardia, 161 = Midtown Center, 237 = Upper East Side South,
--        79 = East Village, 230 = Times Sq/Theatre District.
-- -> captura 36_prediccion_viajes_hipoteticos.png
-- ---------------------------------------------------------------------
CREATE OR REPLACE TABLE `ss22s2026-g8-proyecto2.nyc_taxi_p2.pred_viajes_hipoteticos`
OPTIONS (description = 'Predicciones sobre viajes hipotéticos creados a mano')
AS
WITH viajes AS (
  SELECT * FROM UNNEST([
    STRUCT('JFK -> Midtown, viernes 18 h' AS escenario,
           '18' AS pickup_hour, '6' AS pickup_dow, FALSE AS is_weekend, TRUE  AS is_rush_hour,
           '132' AS pickup_location_id, '161' AS dropoff_location_id, 1 AS passenger_count,
           '2' AS rate_code_id, TRUE AS is_airport, 17.5 AS trip_distance, 55.0 AS trip_duration_min,
           19.1 AS avg_speed_mph, 52.0 AS fare_amount, 2.97 AS fare_per_mile, 6.55 AS tolls_amount, TRUE AS has_tolls),
    STRUCT('Midtown -> Upper East Side, martes 9 h',
           '9', '3', FALSE, TRUE,
           '161', '237', 1,
           '1', FALSE, 1.8, 14.0,
           7.7, 11.5, 6.39, 0.0, FALSE),
    STRUCT('East Village -> Times Sq, sábado 1 h',
           '1', '7', TRUE, FALSE,
           '79', '230', 3,
           '1', FALSE, 2.6, 12.0,
           13.0, 12.5, 4.81, 0.0, FALSE),
    STRUCT('LaGuardia -> East Village, domingo 15 h',
           '15', '1', TRUE, FALSE,
           '138', '79', 2,
           '1', TRUE, 10.2, 28.0,
           21.9, 31.0, 3.04, 6.55, TRUE),
    STRUCT('Viaje corto Midtown, miércoles 13 h',
           '13', '4', FALSE, FALSE,
           '161', '230', 1,
           '1', FALSE, 0.7, 6.0,
           7.0, 5.5, 7.86, 0.0, FALSE)
  ])
),
p_linear AS (
  SELECT * EXCEPT (predicted_tip_amount), predicted_tip_amount AS pred_tip_linear
  FROM ML.PREDICT(MODEL `ss22s2026-g8-proyecto2.nyc_taxi_p2.model_tip_linear`, (SELECT * FROM viajes))
),
p_boosted AS (
  SELECT * EXCEPT (predicted_tip_amount), predicted_tip_amount AS pred_tip_boosted
  FROM ML.PREDICT(MODEL `ss22s2026-g8-proyecto2.nyc_taxi_p2.model_tip_boosted`, (SELECT * FROM p_linear))
)
SELECT
  escenario,
  fare_amount,
  ROUND(GREATEST(pred_tip_linear, 0), 2)                                   AS pred_tip_linear,
  ROUND(GREATEST(pred_tip_boosted, 0), 2)                                  AS pred_tip_boosted,
  ROUND(100 * GREATEST(pred_tip_boosted, 0) / fare_amount, 1)              AS pred_tip_pct_boosted,
  predicted_high_tip                                                       AS pred_high_tip,
  ROUND((SELECT p.prob FROM UNNEST(predicted_high_tip_probs) p WHERE p.label), 4) AS prob_high_tip
FROM ML.PREDICT(MODEL `ss22s2026-g8-proyecto2.nyc_taxi_p2.model_tip_logistic`, (SELECT * FROM p_boosted));

SELECT * FROM `ss22s2026-g8-proyecto2.nyc_taxi_p2.pred_viajes_hipoteticos`;


-- ---------------------------------------------------------------------
-- 10.5 Agregado diario real vs. predicho (fuente del gráfico de
-- predicciones en Looker Studio).
-- ---------------------------------------------------------------------
CREATE OR REPLACE TABLE `ss22s2026-g8-proyecto2.nyc_taxi_p2.pred_diaria_nov`
OPTIONS (description = 'Propina diaria real vs predicha (M1, M3) y % de propina alta real vs predicho - nov 2022')
AS
SELECT
  pickup_date                                              AS fecha,
  COUNT(*)                                                 AS viajes,
  ROUND(SUM(tip_real), 2)                                  AS propina_total_real,
  ROUND(SUM(pred_tip_linear), 2)                           AS propina_total_pred_linear,
  ROUND(SUM(pred_tip_boosted), 2)                          AS propina_total_pred_boosted,
  ROUND(AVG(tip_real), 3)                                  AS propina_prom_real,
  ROUND(AVG(pred_tip_linear), 3)                           AS propina_prom_pred_linear,
  ROUND(AVG(pred_tip_boosted), 3)                          AS propina_prom_pred_boosted,
  ROUND(100 * AVG(CAST(high_tip_real AS INT64)), 2)        AS pct_high_tip_real,
  ROUND(100 * AVG(prob_high_tip), 2)                       AS pct_high_tip_pred
FROM `ss22s2026-g8-proyecto2.nyc_taxi_p2.pred_nuevos_registros`
GROUP BY fecha;

SELECT * FROM `ss22s2026-g8-proyecto2.nyc_taxi_p2.pred_diaria_nov` ORDER BY fecha;
