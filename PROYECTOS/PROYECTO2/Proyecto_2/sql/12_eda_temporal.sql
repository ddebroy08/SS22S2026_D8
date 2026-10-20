-- =====================================================================
-- 12_eda_temporal.sql
-- Proyecto 2 - SS22S2026 Grupo 8 | Responsable: Diego
-- Finalidad: análisis exploratorio de PATRONES TEMPORALES (hora, día de la
--            semana, mes y fecha) sobre la tabla optimizada trips_opt.
--
-- Convenciones de todos los scripts EDA (12-14):
--   * Se consulta trips_opt (partición por DATE(pickup_datetime) + clustering
--     por zonas). Cuando el análisis lo permite se filtra por fecha para que
--     BigQuery lea solo las particiones necesarias.
--   * Se excluyen registros inválidos con los mismos umbrales de
--     02_calidad_datos.sql (tarifa 2.5-200 USD, distancia 0.1-100 mi,
--     duración 1-180 min) y diciembre (solo 57 filas de un día).
--   * Columnas NUMERIC se convierten a FLOAT64 para promedios/percentiles.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 12.1 Viajes, tarifa y propina por MES (tendencia anual)
-- Funciones temporales: DATE_TRUNC, FORMAT_DATE. Ventana: LAG para la
-- variación porcentual mes a mes.
-- -> captura 40_eda_mensual.png
-- ---------------------------------------------------------------------
WITH validos AS (
  SELECT
    DATE(pickup_datetime)                      AS fecha,
    CAST(fare_amount  AS FLOAT64)              AS fare,
    CAST(tip_amount   AS FLOAT64)              AS tip,
    CAST(total_amount AS FLOAT64)              AS total,
    CAST(trip_distance AS FLOAT64)             AS distancia
  FROM `ss22s2026-g8-proyecto2.nyc_taxi_p2.trips_opt`
  WHERE pickup_datetime >= TIMESTAMP('2022-01-01')
    AND pickup_datetime <  TIMESTAMP('2022-12-01')
    AND fare_amount BETWEEN 2.5 AND 200
    AND trip_distance BETWEEN 0.1 AND 100
    AND TIMESTAMP_DIFF(dropoff_datetime, pickup_datetime, SECOND) BETWEEN 60 AND 10800
),
mensual AS (
  SELECT
    DATE_TRUNC(fecha, MONTH)                   AS mes,
    COUNT(*)                                   AS viajes,
    ROUND(COUNT(*) / COUNT(DISTINCT fecha), 0) AS viajes_por_dia,
    ROUND(AVG(fare), 2)                        AS tarifa_prom,
    ROUND(AVG(tip), 2)                         AS propina_prom,
    ROUND(SUM(total) / 1e6, 2)                 AS ingreso_total_musd,
    ROUND(AVG(distancia), 2)                   AS distancia_prom
  FROM validos
  GROUP BY mes
)
SELECT
  FORMAT_DATE('%Y-%m', mes) AS mes,
  viajes,
  viajes_por_dia,
  ROUND(100 * (viajes - LAG(viajes) OVER (ORDER BY mes)) / LAG(viajes) OVER (ORDER BY mes), 1) AS var_viajes_pct,
  tarifa_prom,
  propina_prom,
  ingreso_total_musd,
  distancia_prom
FROM mensual
ORDER BY mes;


-- ---------------------------------------------------------------------
-- 12.2 Patrón por HORA del día (todo 2022)
-- Velocidad promedio como indicador de congestión.
-- -> captura 41_eda_por_hora.png
-- ---------------------------------------------------------------------
SELECT
  EXTRACT(HOUR FROM pickup_datetime)                                     AS hora,
  COUNT(*)                                                               AS viajes,
  ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 2)                       AS pct_viajes,
  ROUND(AVG(CAST(fare_amount AS FLOAT64)), 2)                            AS tarifa_prom,
  ROUND(AVG(CAST(trip_distance AS FLOAT64)), 2)                          AS distancia_prom,
  ROUND(AVG(TIMESTAMP_DIFF(dropoff_datetime, pickup_datetime, SECOND)) / 60, 1) AS duracion_prom_min,
  ROUND(AVG(SAFE_DIVIDE(CAST(trip_distance AS FLOAT64),
            TIMESTAMP_DIFF(dropoff_datetime, pickup_datetime, SECOND) / 3600)), 1) AS velocidad_prom_mph,
  -- propina solo en tarjeta: en efectivo no se registra (ver 02_calidad_datos.sql)
  ROUND(AVG(IF(payment_type = '1', CAST(tip_amount AS FLOAT64), NULL)), 2) AS propina_prom_tarjeta,
  ROUND(100 * AVG(IF(payment_type = '1',
            SAFE_DIVIDE(CAST(tip_amount AS FLOAT64), CAST(fare_amount AS FLOAT64)), NULL)), 1) AS propina_pct_tarjeta
FROM `ss22s2026-g8-proyecto2.nyc_taxi_p2.trips_opt`
WHERE pickup_datetime >= TIMESTAMP('2022-01-01')
  AND pickup_datetime <  TIMESTAMP('2022-12-01')
  AND fare_amount BETWEEN 2.5 AND 200
  AND trip_distance BETWEEN 0.1 AND 100
  AND TIMESTAMP_DIFF(dropoff_datetime, pickup_datetime, SECOND) BETWEEN 60 AND 10800
GROUP BY hora
ORDER BY hora;


-- ---------------------------------------------------------------------
-- 12.3 Patrón por DÍA DE LA SEMANA
-- FORMAT_TIMESTAMP('%A') da el nombre del día; DAYOFWEEK: 1 = domingo.
-- Se normaliza por número de días de cada tipo (no todos los días de la
-- semana aparecen la misma cantidad de veces en el año).
-- -> captura 42_eda_dia_semana.png
-- ---------------------------------------------------------------------
SELECT
  EXTRACT(DAYOFWEEK FROM pickup_datetime)                                AS dow,
  FORMAT_TIMESTAMP('%A', pickup_datetime)                                AS dia,
  COUNT(*)                                                               AS viajes,
  COUNT(DISTINCT DATE(pickup_datetime))                                  AS dias_en_el_periodo,
  ROUND(COUNT(*) / COUNT(DISTINCT DATE(pickup_datetime)), 0)             AS viajes_por_dia,
  ROUND(AVG(CAST(fare_amount AS FLOAT64)), 2)                            AS tarifa_prom,
  ROUND(AVG(CAST(trip_distance AS FLOAT64)), 2)                          AS distancia_prom,
  ROUND(AVG(IF(payment_type = '1', CAST(tip_amount AS FLOAT64), NULL)), 2) AS propina_prom_tarjeta
FROM `ss22s2026-g8-proyecto2.nyc_taxi_p2.trips_opt`
WHERE pickup_datetime >= TIMESTAMP('2022-01-01')
  AND pickup_datetime <  TIMESTAMP('2022-12-01')
  AND fare_amount BETWEEN 2.5 AND 200
  AND trip_distance BETWEEN 0.1 AND 100
  AND TIMESTAMP_DIFF(dropoff_datetime, pickup_datetime, SECOND) BETWEEN 60 AND 10800
GROUP BY dow, dia
ORDER BY dow;


-- ---------------------------------------------------------------------
-- 12.4 Mapa de calor HORA x DÍA (viajes promedio por día).
-- Muestra el desplazamiento del pico: tarde/noche entre semana,
-- madrugada los fines de semana.
-- -> captura 43_eda_heatmap_hora_dia.png
-- ---------------------------------------------------------------------
SELECT
  FORMAT_TIMESTAMP('%u-%a', pickup_datetime)          AS dia,      -- 1-Mon ... 7-Sun
  EXTRACT(HOUR FROM pickup_datetime)                  AS hora,
  ROUND(COUNT(*) / COUNT(DISTINCT DATE(pickup_datetime)), 0) AS viajes_por_dia
FROM `ss22s2026-g8-proyecto2.nyc_taxi_p2.trips_opt`
WHERE pickup_datetime >= TIMESTAMP('2022-01-01')
  AND pickup_datetime <  TIMESTAMP('2022-12-01')
  AND fare_amount BETWEEN 2.5 AND 200
GROUP BY dia, hora
ORDER BY dia, hora;


-- ---------------------------------------------------------------------
-- 12.5 Días con MÁS y MENOS viajes del año (efecto de feriados y clima)
-- Ranking con funciones de ventana sobre una agregación diaria.
-- -> captura 44_eda_dias_extremos.png
-- ---------------------------------------------------------------------
WITH diario AS (
  SELECT
    DATE(pickup_datetime)          AS fecha,
    FORMAT_DATE('%A', DATE(pickup_datetime)) AS dia,
    COUNT(*)                       AS viajes
  FROM `ss22s2026-g8-proyecto2.nyc_taxi_p2.trips_opt`
  WHERE pickup_datetime >= TIMESTAMP('2022-01-01')
    AND pickup_datetime <  TIMESTAMP('2022-12-01')
  GROUP BY fecha, dia
)
SELECT *
FROM (
  SELECT fecha, dia, viajes,
         RANK() OVER (ORDER BY viajes DESC) AS rank_mas,
         RANK() OVER (ORDER BY viajes ASC)  AS rank_menos,
         ROUND(AVG(viajes) OVER (ORDER BY fecha ROWS BETWEEN 6 PRECEDING AND CURRENT ROW), 0) AS media_movil_7d
  FROM diario
)
WHERE rank_mas <= 5 OR rank_menos <= 5
ORDER BY viajes DESC;


-- ---------------------------------------------------------------------
-- 12.6 Franjas del día: comparación de comportamiento
-- CASE para construir la categoría a partir de la hora.
-- ---------------------------------------------------------------------
SELECT
  CASE
    WHEN EXTRACT(HOUR FROM pickup_datetime) BETWEEN 0  AND 5  THEN '1 Madrugada (0-5)'
    WHEN EXTRACT(HOUR FROM pickup_datetime) BETWEEN 6  AND 11 THEN '2 Mañana (6-11)'
    WHEN EXTRACT(HOUR FROM pickup_datetime) BETWEEN 12 AND 17 THEN '3 Tarde (12-17)'
    ELSE                                                          '4 Noche (18-23)'
  END                                                            AS franja,
  EXTRACT(DAYOFWEEK FROM pickup_datetime) IN (1, 7)              AS fin_de_semana,
  COUNT(*)                                                       AS viajes,
  ROUND(AVG(CAST(trip_distance AS FLOAT64)), 2)                  AS distancia_prom,
  ROUND(AVG(CAST(fare_amount AS FLOAT64)), 2)                    AS tarifa_prom,
  ROUND(100 * AVG(IF(payment_type = '1',
        SAFE_DIVIDE(CAST(tip_amount AS FLOAT64), CAST(fare_amount AS FLOAT64)), NULL)), 1) AS propina_pct_tarjeta
FROM `ss22s2026-g8-proyecto2.nyc_taxi_p2.trips_opt`
WHERE pickup_datetime >= TIMESTAMP('2022-01-01')
  AND pickup_datetime <  TIMESTAMP('2022-12-01')
  AND fare_amount BETWEEN 2.5 AND 200
  AND trip_distance BETWEEN 0.1 AND 100
GROUP BY franja, fin_de_semana
ORDER BY franja, fin_de_semana;
