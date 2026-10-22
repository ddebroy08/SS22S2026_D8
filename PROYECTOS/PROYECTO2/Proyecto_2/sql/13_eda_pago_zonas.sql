-- =====================================================================
-- 13_eda_pago_zonas.sql
-- Proyecto 2 - SS22S2026 Grupo 8 | Responsable: Diego
-- Finalidad: análisis de variables CATEGÓRICAS y GEOGRÁFICAS:
--            tipo de pago, código de tarifa, zonas de origen/destino,
--            rutas más frecuentes y viajes a aeropuertos.
-- Fuente: trips_opt (clustering por pickup/dropoff_location_id: las
-- consultas por zona leen menos bloques) + catálogo público de zonas
-- bigquery-public-data.new_york_taxi_trips.taxi_zone_geom.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 13.1 Distribución por TIPO DE PAGO (diccionario TLC)
-- 1 = tarjeta, 2 = efectivo, 3 = sin cargo, 4 = disputa, 5 = desconocido,
-- 0 = sin dato (viajes de proveedores que no reportan el campo).
-- -> captura 45_eda_tipo_pago.png
-- ---------------------------------------------------------------------
SELECT
  payment_type,
  CASE payment_type
    WHEN '1' THEN 'Tarjeta'
    WHEN '2' THEN 'Efectivo'
    WHEN '3' THEN 'Sin cargo'
    WHEN '4' THEN 'Disputa'
    WHEN '5' THEN 'Desconocido'
    ELSE          'Sin dato (0)'
  END                                                                   AS tipo_pago,
  COUNT(*)                                                              AS viajes,
  ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 2)                      AS pct_viajes,
  ROUND(AVG(CAST(fare_amount AS FLOAT64)), 2)                           AS tarifa_prom,
  ROUND(AVG(CAST(trip_distance AS FLOAT64)), 2)                         AS distancia_prom,
  ROUND(AVG(CAST(tip_amount AS FLOAT64)), 2)                            AS propina_prom,
  ROUND(100 * COUNTIF(tip_amount = 0) / COUNT(*), 2)                    AS pct_sin_propina
FROM `ss22s2026-g8-proyecto2.nyc_taxi_p2.trips_opt`
WHERE pickup_datetime >= TIMESTAMP('2022-01-01')
  AND pickup_datetime <  TIMESTAMP('2022-12-01')
GROUP BY payment_type, tipo_pago
ORDER BY viajes DESC;


-- ---------------------------------------------------------------------
-- 13.2 Evolución mensual de la participación tarjeta vs. efectivo
-- PIVOT de la proporción por mes.
-- -> captura 46_eda_pago_mensual.png
-- ---------------------------------------------------------------------
SELECT *
FROM (
  SELECT
    FORMAT_TIMESTAMP('%Y-%m', pickup_datetime)                 AS mes,
    CASE payment_type WHEN '1' THEN 'tarjeta' WHEN '2' THEN 'efectivo' ELSE 'otro' END AS tipo
  FROM `ss22s2026-g8-proyecto2.nyc_taxi_p2.trips_opt`
  WHERE pickup_datetime >= TIMESTAMP('2022-01-01')
    AND pickup_datetime <  TIMESTAMP('2022-12-01')
)
PIVOT (COUNT(*) FOR tipo IN ('tarjeta', 'efectivo', 'otro'))
ORDER BY mes;


-- ---------------------------------------------------------------------
-- 13.3 Código de tarifa (rate_code): estándar, aeropuertos, negociada
-- -> captura 47_eda_rate_code.png
-- ---------------------------------------------------------------------
SELECT
  rate_code,
  CASE rate_code
    WHEN '1.0'  THEN 'Estándar'
    WHEN '2.0'  THEN 'JFK (tarifa plana)'
    WHEN '3.0'  THEN 'Newark'
    WHEN '4.0'  THEN 'Nassau/Westchester'
    WHEN '5.0'  THEN 'Negociada'
    WHEN '6.0'  THEN 'Viaje grupal'
    WHEN '99.0' THEN 'Desconocido'
    ELSE             'Sin dato'
  END                                                                   AS tarifa,
  COUNT(*)                                                              AS viajes,
  ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 2)                      AS pct_viajes,
  ROUND(AVG(CAST(fare_amount AS FLOAT64)), 2)                           AS tarifa_prom,
  ROUND(AVG(CAST(trip_distance AS FLOAT64)), 2)                         AS distancia_prom,
  ROUND(AVG(IF(payment_type = '1', CAST(tip_amount AS FLOAT64), NULL)), 2) AS propina_prom_tarjeta
FROM `ss22s2026-g8-proyecto2.nyc_taxi_p2.trips_opt`
WHERE pickup_datetime >= TIMESTAMP('2022-01-01')
  AND pickup_datetime <  TIMESTAMP('2022-12-01')
GROUP BY rate_code, tarifa
ORDER BY viajes DESC;


-- ---------------------------------------------------------------------
-- 13.4 Top 15 ZONAS DE ORIGEN con nombre y borough (JOIN con catálogo)
-- -> captura 48_eda_top_zonas_origen.png
-- ---------------------------------------------------------------------
SELECT
  t.pickup_location_id                                                  AS zona_id,
  z.zone_name                                                           AS zona,
  z.borough,
  COUNT(*)                                                              AS viajes,
  ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 2)                      AS pct_viajes,
  ROUND(AVG(CAST(t.fare_amount AS FLOAT64)), 2)                         AS tarifa_prom,
  ROUND(AVG(CAST(t.trip_distance AS FLOAT64)), 2)                       AS distancia_prom,
  ROUND(AVG(IF(t.payment_type = '1', CAST(t.tip_amount AS FLOAT64), NULL)), 2) AS propina_prom_tarjeta
FROM `ss22s2026-g8-proyecto2.nyc_taxi_p2.trips_opt` t
LEFT JOIN `bigquery-public-data.new_york_taxi_trips.taxi_zone_geom` z
       ON z.zone_id = t.pickup_location_id
WHERE t.pickup_datetime >= TIMESTAMP('2022-01-01')
  AND t.pickup_datetime <  TIMESTAMP('2022-12-01')
  AND t.fare_amount BETWEEN 2.5 AND 200
GROUP BY zona_id, zona, z.borough
QUALIFY RANK() OVER (ORDER BY viajes DESC) <= 15
ORDER BY viajes DESC;


-- ---------------------------------------------------------------------
-- 13.5 Viajes por BOROUGH de origen -> destino (matriz)
-- ---------------------------------------------------------------------
SELECT
  IFNULL(zo.borough, 'Desconocido')                                     AS borough_origen,
  IFNULL(zd.borough, 'Desconocido')                                     AS borough_destino,
  COUNT(*)                                                              AS viajes,
  ROUND(AVG(CAST(t.fare_amount AS FLOAT64)), 2)                         AS tarifa_prom
FROM `ss22s2026-g8-proyecto2.nyc_taxi_p2.trips_opt` t
LEFT JOIN `bigquery-public-data.new_york_taxi_trips.taxi_zone_geom` zo ON zo.zone_id = t.pickup_location_id
LEFT JOIN `bigquery-public-data.new_york_taxi_trips.taxi_zone_geom` zd ON zd.zone_id = t.dropoff_location_id
WHERE t.pickup_datetime >= TIMESTAMP('2022-01-01')
  AND t.pickup_datetime <  TIMESTAMP('2022-12-01')
  AND t.fare_amount BETWEEN 2.5 AND 200
GROUP BY borough_origen, borough_destino
ORDER BY viajes DESC;


-- ---------------------------------------------------------------------
-- 13.6 Top 10 RUTAS (origen -> destino distintos)
-- -> captura 49_eda_top_rutas.png
-- ---------------------------------------------------------------------
SELECT
  CONCAT(IFNULL(zo.zone_name, t.pickup_location_id), ' -> ',
         IFNULL(zd.zone_name, t.dropoff_location_id))                  AS ruta,
  COUNT(*)                                                              AS viajes,
  ROUND(AVG(CAST(t.trip_distance AS FLOAT64)), 2)                       AS distancia_prom,
  ROUND(AVG(TIMESTAMP_DIFF(t.dropoff_datetime, t.pickup_datetime, SECOND)) / 60, 1) AS duracion_prom_min,
  ROUND(AVG(CAST(t.fare_amount AS FLOAT64)), 2)                         AS tarifa_prom
FROM `ss22s2026-g8-proyecto2.nyc_taxi_p2.trips_opt` t
LEFT JOIN `bigquery-public-data.new_york_taxi_trips.taxi_zone_geom` zo ON zo.zone_id = t.pickup_location_id
LEFT JOIN `bigquery-public-data.new_york_taxi_trips.taxi_zone_geom` zd ON zd.zone_id = t.dropoff_location_id
WHERE t.pickup_datetime >= TIMESTAMP('2022-01-01')
  AND t.pickup_datetime <  TIMESTAMP('2022-12-01')
  AND t.fare_amount BETWEEN 2.5 AND 200
  AND t.pickup_location_id <> t.dropoff_location_id
  AND t.pickup_location_id  NOT IN ('264', '265')
  AND t.dropoff_location_id NOT IN ('264', '265')
GROUP BY ruta
ORDER BY viajes DESC
LIMIT 10;


-- ---------------------------------------------------------------------
-- 13.7 AEROPUERTOS vs. resto de la ciudad (EWR = 1, JFK = 132, LGA = 138)
-- Aprovecha el clustering: filtra por zona de origen.
-- -> captura 50_eda_aeropuertos.png
-- ---------------------------------------------------------------------
SELECT
  CASE pickup_location_id
    WHEN '132' THEN 'JFK'
    WHEN '138' THEN 'LaGuardia'
    WHEN '1'   THEN 'Newark'
    ELSE            'Resto de la ciudad'
  END                                                                   AS origen,
  COUNT(*)                                                              AS viajes,
  ROUND(AVG(CAST(trip_distance AS FLOAT64)), 2)                         AS distancia_prom,
  ROUND(AVG(CAST(fare_amount AS FLOAT64)), 2)                           AS tarifa_prom,
  ROUND(AVG(CAST(tolls_amount AS FLOAT64)), 2)                          AS peaje_prom,
  ROUND(AVG(IF(payment_type = '1', CAST(tip_amount AS FLOAT64), NULL)), 2) AS propina_prom_tarjeta,
  ROUND(100 * AVG(IF(payment_type = '1',
        SAFE_DIVIDE(CAST(tip_amount AS FLOAT64), CAST(fare_amount AS FLOAT64)), NULL)), 1) AS propina_pct_tarjeta,
  ROUND(100 * COUNTIF(payment_type = '2') / COUNT(*), 1)                AS pct_efectivo
FROM `ss22s2026-g8-proyecto2.nyc_taxi_p2.trips_opt`
WHERE pickup_datetime >= TIMESTAMP('2022-01-01')
  AND pickup_datetime <  TIMESTAMP('2022-12-01')
  AND fare_amount BETWEEN 2.5 AND 200
  AND trip_distance BETWEEN 0.1 AND 100
GROUP BY origen
ORDER BY viajes DESC;
