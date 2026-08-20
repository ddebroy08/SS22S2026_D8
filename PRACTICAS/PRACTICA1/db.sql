CREATE DATABASE SS22S2026_G8;
GO

USE SS22S2026_G8;
GO

CREATE TABLE Dim_Aerolinea (
    aerolinea_key INT IDENTITY(1,1) PRIMARY KEY,
    airline_code VARCHAR(10) NOT NULL,
    airline_name VARCHAR(100) NOT NULL
);

CREATE TABLE Dim_Aeropuerto (
    aeropuerto_key INT IDENTITY(1,1) PRIMARY KEY,
    codigo_aeropuerto VARCHAR(10) NOT NULL UNIQUE
);

CREATE TABLE Dim_Avion (
    avion_key INT IDENTITY(1,1) PRIMARY KEY,
    aircraft_type VARCHAR(50) NOT NULL
);

CREATE TABLE Dim_Fecha (
    fecha_key INT PRIMARY KEY,
    fecha DATE NOT NULL,
    anio INT NOT NULL,
    mes INT NOT NULL,
    nombre_mes VARCHAR(20) NOT NULL,
    dia INT NOT NULL,
    trimestre INT NOT NULL,
    dia_semana VARCHAR(20) NOT NULL
);

CREATE TABLE Dim_Pasajero (
    pasajero_key INT IDENTITY(1,1) PRIMARY KEY,
    passenger_id VARCHAR(50) NOT NULL,
    passenger_gender CHAR(1) NOT NULL,
    passenger_age INT NOT NULL,
    passenger_nationality VARCHAR(20) NOT NULL,
    fecha_inicio DATE NOT NULL,
    fecha_fin DATE NULL,
    es_vigente BIT NOT NULL DEFAULT 1
);

CREATE TABLE Hechos_Vuelo (
    hecho_key BIGINT IDENTITY(1,1) PRIMARY KEY,
    record_id INT NOT NULL,
    aerolinea_key INT NOT NULL,
    avion_key INT NOT NULL,
    aeropuerto_origen_key INT NOT NULL,
    aeropuerto_destino_key INT NOT NULL,
    pasajero_key INT NOT NULL,
    fecha_salida_key INT NOT NULL,
    fecha_reserva_key INT NOT NULL,
    flight_number VARCHAR(20) NOT NULL,
    departure_datetime DATETIME2 NOT NULL,
    arrival_datetime DATETIME2 NULL,
    booking_datetime DATETIME2 NOT NULL,
    status VARCHAR(20) NOT NULL,
    duration_min FLOAT NULL,
    delay_min FLOAT NULL,
    fecha_valida BIT NULL,
    cabin_class VARCHAR(20) NOT NULL,
    seat VARCHAR(10) NULL,
    sales_channel VARCHAR(30) NOT NULL,
    payment_method VARCHAR(30) NOT NULL,
    ticket_price FLOAT NOT NULL,
    currency VARCHAR(10) NOT NULL,
    ticket_price_usd_est FLOAT NOT NULL,
    bags_total INT NOT NULL,
    bags_checked INT NOT NULL,
    CONSTRAINT FK_Hechos_Aerolinea FOREIGN KEY (aerolinea_key) REFERENCES Dim_Aerolinea(aerolinea_key),
    CONSTRAINT FK_Hechos_Avion FOREIGN KEY (avion_key) REFERENCES Dim_Avion(avion_key),
    CONSTRAINT FK_Hechos_AeropuertoOrigen FOREIGN KEY (aeropuerto_origen_key) REFERENCES Dim_Aeropuerto(aeropuerto_key),
    CONSTRAINT FK_Hechos_AeropuertoDestino FOREIGN KEY (aeropuerto_destino_key) REFERENCES Dim_Aeropuerto(aeropuerto_key),
    CONSTRAINT FK_Hechos_Pasajero FOREIGN KEY (pasajero_key) REFERENCES Dim_Pasajero(pasajero_key),
    CONSTRAINT FK_Hechos_FechaSalida FOREIGN KEY (fecha_salida_key) REFERENCES Dim_Fecha(fecha_key),
    CONSTRAINT FK_Hechos_FechaReserva FOREIGN KEY (fecha_reserva_key) REFERENCES Dim_Fecha(fecha_key)
);


SELECT TABLE_NAME, COLUMN_NAME, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH
FROM INFORMATION_SCHEMA.COLUMNS
WHERE DATA_TYPE IN ('varchar', 'char', 'nvarchar')
ORDER BY TABLE_NAME, ORDINAL_POSITION;