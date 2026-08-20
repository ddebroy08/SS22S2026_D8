
USE SS22S2026_G8;
GO

-- ============================================================================
-- SECCIÓN 1: VALIDACIÓN DE CARGA E INTEGRIDAD DE DATOS
-- ============================================================================

-- 1.1 Conteo total de registros en la tabla de hechos y tablas de dimensiones
SELECT 'Hechos_Vuelo' AS Tabla, COUNT(*) AS Total_Registros FROM Hechos_Vuelo
UNION ALL
SELECT 'Dim_Aerolinea', COUNT(*) FROM Dim_Aerolinea
UNION ALL
SELECT 'Dim_Aeropuerto', COUNT(*) FROM Dim_Aeropuerto
UNION ALL
SELECT 'Dim_Avion', COUNT(*) FROM Dim_Avion
UNION ALL
SELECT 'Dim_Fecha', COUNT(*) FROM Dim_Fecha
UNION ALL
SELECT 'Dim_Pasajero', COUNT(*) FROM Dim_Pasajero;

-- 1.2 Validación de la regla de trazabilidad de fechas (fecha_valida)
-- 1 = Fechas y duración consistentes, 0 = Fechas inconsistentes descartadas, NULL = Cancelados
SELECT 
    CASE 
        WHEN fecha_valida = 1 THEN 'Vuelo Válido (Fechas Confiables)'
        WHEN fecha_valida = 0 THEN 'Vuelo Inconsistente (Fechas Descartadas)'
        ELSE 'Vuelo Cancelado (Sin Fecha Llegada)'
    END AS Categoria_Consistencia,
    COUNT(*) AS Cantidad_Vuelos,
    CAST(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM Hechos_Vuelo) AS DECIMAL(5,2)) AS Porcentaje
FROM Hechos_Vuelo
GROUP BY fecha_valida;

-- 1.3 Verificación de integridad referencial (búsqueda de llaves foráneas huérfanas)
SELECT COUNT(*) AS Registros_Huerfanos_Aerolinea
FROM Hechos_Vuelo h
LEFT JOIN Dim_Aerolinea a ON h.aerolinea_key = a.aerolinea_key
WHERE a.aerolinea_key IS NULL;

-- 1.4 Verificación de vuelos cancelados (deben tener arrival_datetime NULL y duration_min NULL)
SELECT status, 
       COUNT(*) AS Total_Vuelos,
       SUM(CASE WHEN arrival_datetime IS NULL THEN 1 ELSE 0 END) AS Con_Llegada_Null,
       SUM(CASE WHEN seat IS NULL THEN 1 ELSE 0 END) AS Con_Asiento_Null
FROM Hechos_Vuelo
GROUP BY status;

-- ============================================================================
-- SECCIÓN 2: INDICADORES CLAVE DE RENDIMIENTO (KPIs GENERALES DE VUELOS)
-- ============================================================================

-- 2.1 Distribución general de vuelos por estado
SELECT 
    status AS Estado_Vuelo,
    COUNT(*) AS Cantidad_Vuelos,
    CAST(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM Hechos_Vuelo) AS DECIMAL(5,2)) AS Porcentaje,
    AVG(delay_min) AS Promedio_Retraso_Minutos
FROM Hechos_Vuelo
GROUP BY status
ORDER BY Cantidad_Vuelos DESC;

-- 2.2 Ingresos totales generados en USD estimado y precio promedio por boleto
SELECT 
    SUM(ticket_price_usd_est) AS Ingreso_Total_USD,
    AVG(ticket_price_usd_est) AS Precio_Promedio_USD,
    MIN(ticket_price_usd_est) AS Precio_Minimo_USD,
    MAX(ticket_price_usd_est) AS Precio_Maximo_USD
FROM Hechos_Vuelo;

-- 2.3 Métricas de tiempo de vuelo y retrasos por tipo de aeronave
SELECT 
    a.aircraft_type AS Tipo_Avion,
    COUNT(h.hecho_key) AS Total_Vuelos,
    AVG(h.duration_min) AS Duracion_Promedio_Min,
    AVG(h.delay_min) AS Retraso_Promedio_Min
FROM Hechos_Vuelo h
INNER JOIN Dim_Avion a ON h.avion_key = a.avion_key
WHERE h.fecha_valida = 1
GROUP BY a.aircraft_type
ORDER BY Total_Vuelos DESC;

-- ============================================================================
-- SECCIÓN 3: ANÁLISIS DE DESTINOS Y AEROLÍNEAS (TOP N ANÁLISIS)
-- ============================================================================

-- 3.1 TOP 5 Aeropuertos de Destino más frecuentes y su volumen de ingresos
SELECT TOP 5
    ap.codigo_aeropuerto AS Aeropuerto_Destino,
    COUNT(h.hecho_key) AS Total_Vuelos_Recibidos,
    SUM(h.ticket_price_usd_est) AS Ingresos_Generados_USD,
    AVG(h.ticket_price_usd_est) AS Tarifa_Promedio_USD
FROM Hechos_Vuelo h
INNER JOIN Dim_Aeropuerto ap ON h.aeropuerto_destino_key = ap.aeropuerto_key
GROUP BY ap.codigo_aeropuerto
ORDER BY Total_Vuelos_Recibidos DESC;

-- 3.2 TOP 5 Aerolíneas con mayor volumen de pasajeros transportados
SELECT TOP 5
    al.airline_code AS Codigo_Aerolinea,
    al.airline_name AS Nombre_Aerolinea,
    COUNT(h.hecho_key) AS Total_Vuelos,
    SUM(h.ticket_price_usd_est) AS Total_Facturado_USD
FROM Hechos_Vuelo h
INNER JOIN Dim_Aerolinea al ON h.aerolinea_key = al.aerolinea_key
GROUP BY al.airline_code, al.airline_name
ORDER BY Total_Vuelos DESC;

-- 3.3 Rutas más populares (Origen -> Destino) ordenadas por demanda
SELECT TOP 10
    orig.codigo_aeropuerto AS Origen,
    dest.codigo_aeropuerto AS Destino,
    orig.codigo_aeropuerto + ' -> ' + dest.codigo_aeropuerto AS Ruta,
    COUNT(h.hecho_key) AS Cantidad_Vuelos,
    SUM(h.ticket_price_usd_est) AS Recaudacion_Total_USD
FROM Hechos_Vuelo h
INNER JOIN Dim_Aeropuerto orig ON h.aeropuerto_origen_key = orig.aeropuerto_key
INNER JOIN Dim_Aeropuerto dest ON h.aeropuerto_destino_key = dest.aeropuerto_key
GROUP BY orig.codigo_aeropuerto, dest.codigo_aeropuerto
ORDER BY Cantidad_Vuelos DESC;

-- ============================================================================
-- SECCIÓN 4: ANÁLISIS DEMOGRÁFICO Y COMPORTAMIENTO DEL PASAJERO
-- ============================================================================

-- 4.1 Distribución de pasajeros por género (M, F, X)
SELECT 
    p.passenger_gender AS Genero,
    COUNT(h.hecho_key) AS Total_Pasajeros_Vuelos,
    CAST(COUNT(h.hecho_key) * 100.0 / (SELECT COUNT(*) FROM Hechos_Vuelo) AS DECIMAL(5,2)) AS Porcentaje
FROM Hechos_Vuelo h
INNER JOIN Dim_Pasajero p ON h.pasajero_key = p.pasajero_key
GROUP BY p.passenger_gender
ORDER BY Total_Pasajeros_Vuelos DESC;

-- 4.2 Promedio de edad de los pasajeros según la clase de cabina reservada
SELECT 
    h.cabin_class AS Clase_Cabina,
    COUNT(h.hecho_key) AS Total_Reservas,
    AVG(p.passenger_age) AS Edad_Promedio_Pasajero,
    MIN(p.passenger_age) AS Edad_Minima,
    MAX(p.passenger_age) AS Edad_Maxima
FROM Hechos_Vuelo h
INNER JOIN Dim_Pasajero p ON h.pasajero_key = p.pasajero_key
GROUP BY h.cabin_class
ORDER BY Total_Reservas DESC;

-- 4.3 TOP 5 Nacionalidades con mayor volumen de reservas
SELECT TOP 5
    p.passenger_nationality AS Nacionalidad,
    COUNT(h.hecho_key) AS Total_Vuelos_Reservados,
    SUM(h.ticket_price_usd_est) AS Gasto_Total_USD
FROM Hechos_Vuelo h
INNER JOIN Dim_Pasajero p ON h.pasajero_key = p.pasajero_key
GROUP BY p.passenger_nationality
ORDER BY Total_Vuelos_Reservados DESC;

-- 4.4 Verificación de registros vigentes en dimensión de dimensión SCD Tipo 2
SELECT 
    es_vigente,
    COUNT(*) AS Total_Pasajeros
FROM Dim_Pasajero
GROUP BY es_vigente;

-- ============================================================================
-- SECCIÓN 5: CANALES DE VENTA Y MÉTODOS DE PAGO (ANÁLISIS COMERCIAL)
-- ============================================================================

-- 5.1 Distribución de ventas e ingresos por canal de venta
SELECT 
    sales_channel AS Canal_Venta,
    COUNT(*) AS Cantidad_Transacciones,
    SUM(ticket_price_usd_est) AS Ingresos_Totales_USD,
    AVG(ticket_price_usd_est) AS Ticket_Promedio_USD
FROM Hechos_Vuelo
GROUP BY sales_channel
ORDER BY Ingresos_Totales_USD DESC;

-- 5.2 Método de pago preferido según la moneda de origen de la transacción
SELECT 
    currency AS Moneda_Original,
    payment_method AS Método_Pago,
    COUNT(*) AS Total_Transacciones,
    SUM(ticket_price) AS Monto_Total_Moneda_Origen,
    SUM(ticket_price_usd_est) AS Monto_Equivalente_USD
FROM Hechos_Vuelo
GROUP BY currency, payment_method
ORDER BY currency, Total_Transacciones DESC;

-- 5.3 Análisis de equipaje (promedio de maletas y maletas facturadas) por clase de cabina
SELECT 
    cabin_class AS Clase_Cabina,
    COUNT(*) AS Total_Vuelos,
    AVG(CAST(bags_total AS FLOAT)) AS Promedio_Maletas_Totales,
    AVG(CAST(bags_checked AS FLOAT)) AS Promedio_Maletas_Facturadas,
    SUM(bags_checked) AS Total_Maletas_Facturadas
FROM Hechos_Vuelo
GROUP BY cabin_class
ORDER BY Total_Vuelos DESC;

-- ============================================================================
-- SECCIÓN 6: ANÁLISIS TEMPORAL (DIMENSIÓN FECHA)
-- ============================================================================

-- 6.1 Tendencia de vuelos y facturación por trimestre y mes (usando Dim_Fecha)
SELECT 
    f.anio AS Anio,
    f.trimestre AS Trimestre,
    f.nombre_mes AS Mes,
    COUNT(h.hecho_key) AS Cantidad_Vuelos,
    SUM(h.ticket_price_usd_est) AS Ingresos_USD
FROM Hechos_Vuelo h
INNER JOIN Dim_Fecha f ON h.fecha_salida_key = f.fecha_key
GROUP BY f.anio, f.trimestre, f.mes, f.nombre_mes
ORDER BY f.anio, f.mes;

-- 6.2 Comportamiento de retrasos según el día de la semana
SELECT 
    f.dia_semana AS Dia_Semana,
    COUNT(h.hecho_key) AS Total_Vuelos,
    SUM(CASE WHEN h.status = 'DELAYED' THEN 1 ELSE 0 END) AS Vuelos_Retrasados,
    AVG(h.delay_min) AS Promedio_Retraso_Minutos
FROM Hechos_Vuelo h
INNER JOIN Dim_Fecha f ON h.fecha_salida_key = f.fecha_key
GROUP BY f.dia_semana
ORDER BY Total_Vuelos DESC;
