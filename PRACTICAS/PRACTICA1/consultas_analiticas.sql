USE SS22S2026_G8;
GO

-- ============================================================
-- 1. VALIDACION DE CARGA
-- ============================================================

-- 1.1 Conteo de filas por tabla (confirma que la carga se ejecuto)
SELECT 'Dim_Aerolinea' AS tabla, COUNT(*) AS filas FROM Dim_Aerolinea
UNION ALL
SELECT 'Dim_Aeropuerto', COUNT(*) FROM Dim_Aeropuerto
UNION ALL
SELECT 'Dim_Avion', COUNT(*) FROM Dim_Avion
UNION ALL
SELECT 'Dim_Fecha', COUNT(*) FROM Dim_Fecha
UNION ALL
SELECT 'Dim_Pasajero', COUNT(*) FROM Dim_Pasajero
UNION ALL
SELECT 'Hechos_Vuelo', COUNT(*) FROM Hechos_Vuelo;
GO

-- 1.2 Integridad referencial: hechos sin llave valida en alguna dimension
SELECT h.hecho_key, h.record_id
FROM Hechos_Vuelo h
LEFT JOIN Dim_Aerolinea al ON h.aerolinea_key = al.aerolinea_key
LEFT JOIN Dim_Avion av ON h.avion_key = av.avion_key
LEFT JOIN Dim_Aeropuerto ao ON h.aeropuerto_origen_key = ao.aeropuerto_key
LEFT JOIN Dim_Aeropuerto ad ON h.aeropuerto_destino_key = ad.aeropuerto_key
LEFT JOIN Dim_Pasajero p ON h.pasajero_key = p.pasajero_key
LEFT JOIN Dim_Fecha fs ON h.fecha_salida_key = fs.fecha_key
LEFT JOIN Dim_Fecha fr ON h.fecha_reserva_key = fr.fecha_key
WHERE al.aerolinea_key IS NULL
   OR av.avion_key IS NULL
   OR ao.aeropuerto_key IS NULL
   OR ad.aeropuerto_key IS NULL
   OR p.pasajero_key IS NULL
   OR fs.fecha_key IS NULL
   OR fr.fecha_key IS NULL;
GO

-- 1.3 Pasajeros con mas de una version vigente (no deberia devolver filas)
SELECT passenger_id, COUNT(*) AS versiones_vigentes
FROM Dim_Pasajero
WHERE es_vigente = 1
GROUP BY passenger_id
HAVING COUNT(*) > 1;
GO

-- ============================================================
-- 2. INDICADORES ANALITICOS
-- ============================================================

-- 2.1 Numero total de vuelos registrados y por estado
SELECT status, COUNT(*) AS total_vuelos
FROM Hechos_Vuelo
GROUP BY status
ORDER BY total_vuelos DESC;
GO

-- 2.2 Top 5 destinos mas frecuentes
SELECT TOP 5
    ad.codigo_aeropuerto AS destino,
    COUNT(*) AS total_vuelos
FROM Hechos_Vuelo h
JOIN Dim_Aeropuerto ad ON h.aeropuerto_destino_key = ad.aeropuerto_key
GROUP BY ad.codigo_aeropuerto
ORDER BY total_vuelos DESC;
GO

-- 2.3 Top 5 rutas (origen -> destino) mas frecuentes
SELECT TOP 5
    ao.codigo_aeropuerto AS origen,
    ad.codigo_aeropuerto AS destino,
    COUNT(*) AS total_vuelos
FROM Hechos_Vuelo h
JOIN Dim_Aeropuerto ao ON h.aeropuerto_origen_key = ao.aeropuerto_key
JOIN Dim_Aeropuerto ad ON h.aeropuerto_destino_key = ad.aeropuerto_key
GROUP BY ao.codigo_aeropuerto, ad.codigo_aeropuerto
ORDER BY total_vuelos DESC;
GO

-- 2.4 Distribucion de pasajeros por genero
SELECT
    passenger_gender AS genero,
    COUNT(*) AS total_pasajeros,
    CAST(100.0 * COUNT(*) / SUM(COUNT(*)) OVER () AS DECIMAL(5,2)) AS porcentaje
FROM Dim_Pasajero
WHERE es_vigente = 1
GROUP BY passenger_gender
ORDER BY total_pasajeros DESC;
GO

-- 2.5 Top 5 nacionalidades de pasajeros
SELECT TOP 5
    passenger_nationality AS nacionalidad,
    COUNT(*) AS total_pasajeros
FROM Dim_Pasajero
WHERE es_vigente = 1
GROUP BY passenger_nationality
ORDER BY total_pasajeros DESC;
GO

-- 2.6 Vuelos y precio promedio por aerolinea
SELECT
    al.airline_name AS aerolinea,
    COUNT(*) AS total_vuelos,
    CAST(AVG(h.ticket_price_usd_est) AS DECIMAL(10,2)) AS precio_promedio_usd
FROM Hechos_Vuelo h
JOIN Dim_Aerolinea al ON h.aerolinea_key = al.aerolinea_key
GROUP BY al.airline_name
ORDER BY total_vuelos DESC;
GO

-- 2.7 Retraso promedio por aerolinea (solo vuelos con retraso registrado)
SELECT
    al.airline_name AS aerolinea,
    COUNT(*) AS vuelos_con_dato_retraso,
    CAST(AVG(h.delay_min) AS DECIMAL(10,2)) AS retraso_promedio_min
FROM Hechos_Vuelo h
JOIN Dim_Aerolinea al ON h.aerolinea_key = al.aerolinea_key
WHERE h.delay_min IS NOT NULL
GROUP BY al.airline_name
ORDER BY retraso_promedio_min DESC;
GO

-- 2.8 Vuelos por mes y trimestre (usando Dim_Fecha de salida)
SELECT
    f.anio,
    f.trimestre,
    f.nombre_mes,
    COUNT(*) AS total_vuelos
FROM Hechos_Vuelo h
JOIN Dim_Fecha f ON h.fecha_salida_key = f.fecha_key
GROUP BY f.anio, f.trimestre, f.nombre_mes, f.mes
ORDER BY f.anio, f.mes;
GO

-- 2.9 Canal de venta y metodo de pago mas usados
SELECT
    sales_channel AS canal_venta,
    payment_method AS metodo_pago,
    COUNT(*) AS total_transacciones
FROM Hechos_Vuelo
GROUP BY sales_channel, payment_method
ORDER BY total_transacciones DESC;
GO

-- 2.10 Ingreso total estimado (USD) por clase de cabina
SELECT
    cabin_class AS clase_cabina,
    COUNT(*) AS total_tickets,
    CAST(SUM(ticket_price_usd_est) AS DECIMAL(12,2)) AS ingreso_total_usd
FROM Hechos_Vuelo
GROUP BY cabin_class
ORDER BY ingreso_total_usd DESC;
GO
