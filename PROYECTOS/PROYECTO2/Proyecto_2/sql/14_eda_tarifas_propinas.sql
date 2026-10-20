-- =====================================================================
-- 14_eda_tarifas_propinas.sql
-- Proyecto 2 - SS22S2026 Grupo 8 | Responsable: Diego
-- Finalidad: análisis de variables ECONÓMICAS: distribución de tarifas,
--            relación distancia-tarifa, comportamiento de la propina
--            (solo pagos con tarjeta, donde la propina sí se registra).
-- Fuente: trips_opt y ml_trips_clean (tabla limpia de Estuardo).
-- =====================================================================


-- ---------------------------------------------------------------------
-- 14.1 Estadísticas descriptivas de tarifa, propina, total y distancia
-- (registros válidos). APPROX_QUANTILES para percentiles.
-- -> captura 51_eda_descriptivas.png
-- ---------------------------------------------------------------------
WITH v AS (
  SELECT
    CAST(fare_amount   AS FLOAT64) AS tarifa,
    CAST(tip_amount    AS FLOAT64) AS propina,
    CAST(total_amount  AS FLOAT64) AS total,
    CAST(trip_distance AS FLOAT64) AS distancia
  FROM `ss22s2026-g8-proyecto2.nyc_taxi_p2.trips_opt`
  WHERE pickup_datetime >= TIMESTAMP('2022-01-01')
    AND pickup_datetime <  TIMESTAMP('2022-12-01')
    AND fare_amount BETWEEN 2.5 AND 200
    AND trip_distance BETWEEN 0.1 AND 100
    AND payment_type = '1'
)
SELECT 'tarifa' AS variable, ROUND(AVG(tarifa), 2) AS media, ROUND(STDDEV(tarifa), 2) AS desv,
       APPROX_QUANTILES(tarifa, 4) AS cuartiles FROM v
UNION ALL
SELECT 'propina', ROUND(AVG(propina), 2), ROUND(STDDEV(propina), 2), APPROX_QUANTILES(propina, 4) FROM v
UNION ALL
SELECT 'total',   ROUND(AVG(total), 2),   ROUND(STDDEV(total), 2),   APPROX_QUANTILES(total, 4)   FROM v
UNION ALL
SELECT 'distancia', ROUND(AVG(distancia), 2), ROUND(STDDEV(distancia), 2), APPROX_QUANTILES(distancia, 4) FROM v;


-- ---------------------------------------------------------------------
-- 14.2 Distribución del PORCENTAJE DE PROPINA (tarjeta)
-- Los taxis de NYC muestran botones de 20 %, 25 % y 30 %; se espera ver
-- picos en esos valores y un grupo importante en 0 %.
-- Nota: los botones se calculan sobre la tarifa más recargos, por lo que el
-- pico puede aparecer algo por encima de 20 % respecto a fare_amount.
-- -> captura 52_eda_distribucion_tip_pct.png
-- ---------------------------------------------------------------------
SELECT
  CASE
    WHEN tip_pct = 0     THEN '00 0 %'
    WHEN tip_pct < 0.10  THEN '01 (0-10 %)'
    WHEN tip_pct < 0.15  THEN '02 [10-15 %)'
    WHEN tip_pct < 0.20  THEN '03 [15-20 %)'
    WHEN tip_pct < 0.25  THEN '04 [20-25 %)'
    WHEN tip_pct < 0.30  THEN '05 [25-30 %)'
    WHEN tip_pct < 0.35  THEN '06 [30-35 %)'
    ELSE                      '07 35 % o más'
  END                                                AS rango_propina,
  COUNT(*)                                           AS viajes,
  ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 2)   AS pct_viajes
FROM `ss22s2026-g8-proyecto2.nyc_taxi_p2.ml_trips_clean`
GROUP BY rango_propina
ORDER BY rango_propina;


-- ---------------------------------------------------------------------
-- 14.3 Tarifa y propina por RANGO DE DISTANCIA
-- Muestra la relación (casi lineal) distancia-tarifa y cómo el % de propina
-- baja en viajes largos aunque el monto suba.
-- -> captura 53_eda_distancia_tarifa.png
-- ---------------------------------------------------------------------
SELECT
  CASE
    WHEN trip_distance < 1  THEN '1 < 1 mi'
    WHEN trip_distance < 2  THEN '2 1-2 mi'
    WHEN trip_distance < 5  THEN '3 2-5 mi'
    WHEN trip_distance < 10 THEN '4 5-10 mi'
    WHEN trip_distance < 20 THEN '5 10-20 mi'
    ELSE                         '6 20+ mi'
  END                                                AS rango_distancia,
  COUNT(*)                                           AS viajes,
  ROUND(AVG(fare_amount), 2)                         AS tarifa_prom,
  ROUND(AVG(fare_per_mile), 2)                       AS tarifa_por_milla,
  ROUND(AVG(trip_duration_min), 1)                   AS duracion_prom_min,
  ROUND(AVG(tip_amount), 2)                          AS propina_prom,
  ROUND(100 * AVG(tip_pct), 1)                       AS propina_pct_prom,
  ROUND(100 * AVG(CAST(high_tip AS INT64)), 1)       AS pct_propina_alta
FROM `ss22s2026-g8-proyecto2.nyc_taxi_p2.ml_trips_clean`
GROUP BY rango_distancia
ORDER BY rango_distancia;


-- ---------------------------------------------------------------------
-- 14.4 Correlaciones (Pearson) entre variables numéricas y la propina
-- Sustenta la selección de features de los modelos de Pablo/Estuardo.
-- -> captura 54_eda_correlaciones.png
-- ---------------------------------------------------------------------
SELECT
  ROUND(CORR(tip_amount, fare_amount), 3)        AS corr_tip_tarifa,
  ROUND(CORR(tip_amount, trip_distance), 3)      AS corr_tip_distancia,
  ROUND(CORR(tip_amount, trip_duration_min), 3)  AS corr_tip_duracion,
  ROUND(CORR(tip_amount, tolls_amount), 3)       AS corr_tip_peajes,
  ROUND(CORR(tip_amount, avg_speed_mph), 3)      AS corr_tip_velocidad,
  ROUND(CORR(tip_amount, passenger_count), 3)    AS corr_tip_pasajeros,
  ROUND(CORR(tip_pct, fare_amount), 3)           AS corr_tippct_tarifa,
  ROUND(CORR(tip_pct, trip_distance), 3)         AS corr_tippct_distancia,
  ROUND(CORR(fare_amount, trip_distance), 3)     AS corr_tarifa_distancia
FROM `ss22s2026-g8-proyecto2.nyc_taxi_p2.ml_trips_clean`
WHERE split_set = 'train';


-- ---------------------------------------------------------------------
-- 14.5 Propina por HORA y tipo de día (tarjeta)
-- -> captura 55_eda_propina_hora.png
-- ---------------------------------------------------------------------
SELECT
  pickup_hour                                        AS hora,
  is_weekend                                         AS fin_de_semana,
  COUNT(*)                                           AS viajes,
  ROUND(AVG(tip_amount), 2)                          AS propina_prom,
  ROUND(100 * AVG(tip_pct), 1)                       AS propina_pct_prom,
  ROUND(100 * AVG(CAST(high_tip AS INT64)), 1)       AS pct_propina_alta
FROM `ss22s2026-g8-proyecto2.nyc_taxi_p2.ml_trips_clean`
GROUP BY hora, fin_de_semana
ORDER BY fin_de_semana, hora;


-- ---------------------------------------------------------------------
-- 14.6 Número de pasajeros: ¿cambia la propina?
-- ---------------------------------------------------------------------
SELECT
  passenger_count                                    AS pasajeros,
  COUNT(*)                                           AS viajes,
  ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 2)   AS pct_viajes,
  ROUND(AVG(fare_amount), 2)                         AS tarifa_prom,
  ROUND(AVG(tip_amount), 2)                          AS propina_prom,
  ROUND(100 * AVG(tip_pct), 1)                       AS propina_pct_prom
FROM `ss22s2026-g8-proyecto2.nyc_taxi_p2.ml_trips_clean`
GROUP BY pasajeros
ORDER BY pasajeros;


-- ---------------------------------------------------------------------
-- 14.7 Zonas con MAYOR % de propina (mínimo 20,000 viajes para que el
-- promedio sea estable). JOIN con el catálogo de zonas.
-- -> captura 56_eda_zonas_propina.png
-- ---------------------------------------------------------------------
SELECT
  c.pickup_location_id                               AS zona_id,
  z.zone_name                                        AS zona,
  z.borough,
  COUNT(*)                                           AS viajes,
  ROUND(AVG(c.tip_amount), 2)                        AS propina_prom,
  ROUND(100 * AVG(c.tip_pct), 1)                     AS propina_pct_prom,
  ROUND(100 * AVG(CAST(c.high_tip AS INT64)), 1)     AS pct_propina_alta
FROM `ss22s2026-g8-proyecto2.nyc_taxi_p2.ml_trips_clean` c
LEFT JOIN `bigquery-public-data.new_york_taxi_trips.taxi_zone_geom` z
       ON z.zone_id = c.pickup_location_id
GROUP BY zona_id, zona, z.borough
HAVING COUNT(*) >= 20000
ORDER BY propina_pct_prom DESC
LIMIT 15;
