import pandas as pd
import pyodbc
from connection import get_db_connection

pd.set_option('display.max_columns', None)
pd.set_option('display.width', None)
pd.set_option('display.max_colwidth', None)

# EXTRACT
file = pd.read_csv('dataset_vuelos_crudo.csv', sep=',')

print("--------- DIMENSIONES ---------")
print(file.shape)

print("--------- COLUMNAS ---------")
print(file.columns.tolist())

print("--------- TIPOS DE DATOS ---------")
print(file.dtypes)
print(file['flight_number'].head(5))

print("--------- VALORES NULOS ---------")
print(file.isnull().sum())

print("--------- VALORES DUPLICADOS ---------")
print(file.duplicated().sum())

# TRANSFORM

file['passenger_age'] = file['passenger_age'].fillna(file['passenger_age'].median())

file['passenger_nationality'] = file['passenger_nationality'].fillna('DESCONOCIDO')

file['sales_channel'] = file['sales_channel'].fillna('DESCONOCIDO')

file.loc[~file['passenger_gender'].isin(['M', 'F']), 'passenger_gender'] = 'X'

file['origin_airport'] = file['origin_airport'].str.upper()
file['destination_airport'] = file['destination_airport'].str.upper()

print("--------- CODIGOS DE AEROPUERTO UNICOS DESPUES DE NORMALIZAR ---------")
print(pd.concat([file['origin_airport'], file['destination_airport']]).nunique())

nombre_canonico = (
    file.groupby('airline_code')['airline_name']
    .agg(lambda x: x.value_counts().idxmax())
)

file['airline_name'] = file['airline_code'].map(nombre_canonico)

print("--------- AIRLINE_NAME UNICOS DESPUES DE NORMALIZAR ---------")
print(file['airline_name'].nunique())

print("--------- VUELOS CANCELADOS (nulos estructurales esperados) ---------")
print(
    file.loc[
        file['status'] == 'CANCELLED',
        ['arrival_datetime', 'duration_min', 'delay_min', 'seat']
    ].isnull().sum()
)

def parse_fecha_flex(serie):
    f1 = pd.to_datetime(
        serie,
        format='%d/%m/%Y %H:%M',
        errors='coerce'
    )

    f2 = pd.to_datetime(
        serie,
        format='%m-%d-%Y %I:%M %p',
        errors='coerce'
    )

    return f1.fillna(f2)

file['departure_datetime'] = parse_fecha_flex(file['departure_datetime'])
file['arrival_datetime'] = parse_fecha_flex(file['arrival_datetime'])
file['booking_datetime'] = parse_fecha_flex(file['booking_datetime'])

print("--------- FECHAS SIN PARSEAR DESPUES DE APLICAR AMBOS FORMATOS ---------")
print("departure_datetime:", file['departure_datetime'].isnull().sum())
print("arrival_datetime:", file['arrival_datetime'].isnull().sum())
print("booking_datetime:", file['booking_datetime'].isnull().sum())

calc_dur = (
    file['arrival_datetime'] - file['departure_datetime']
).dt.total_seconds() / 60

duracion_valida = (
    calc_dur.notna()
    & (calc_dur > 0)
    & (calc_dur <= 1440)
)

filas_inconsistentes = (
    file['arrival_datetime'].notna()
    & ~duracion_valida
)

print("--------- FECHAS INCONSISTENTES DETECTADAS ---------")
print(filas_inconsistentes.sum())

file['fecha_valida'] = None

file.loc[
    file['arrival_datetime'].notna(),
    'fecha_valida'
] = duracion_valida[file['arrival_datetime'].notna()]

file.loc[
    duracion_valida,
    'duration_min'
] = calc_dur[duracion_valida]

file.loc[
    filas_inconsistentes,
    'duration_min'
] = None

print("--------- DISTRIBUCION DE fecha_valida ---------")
print(file['fecha_valida'].value_counts(dropna=False))

file['ticket_price'] = (
    file['ticket_price']
    .astype(str)
    .str.replace(',', '.', regex=False)
    .astype(float)
)

precios_invalidos = (file['ticket_price'] <= 0).sum()

print("--------- TICKETS CON PRECIO <= 0 ---------")
print(precios_invalidos)

assert precios_invalidos == 0, "Hay tickets con precio <= 0"

cols_no_negativas = [
    'duration_min',
    'delay_min',
    'passenger_age',
    'bags_total',
    'bags_checked'
]

print("--------- VALORES NEGATIVOS POR COLUMNA ---------")

for col in cols_no_negativas:
    negativos = (file[col] < 0).sum()
    print(f"{col}: {negativos}")

    if negativos > 0:
        file.loc[file[col] < 0, col] = None

bags_invalidas = (
    file['bags_checked'] > file['bags_total']
).sum()

print("--------- FILAS CON bags_checked > bags_total ---------")
print(bags_invalidas)

assert bags_invalidas == 0, "Hay filas con bags_checked mayor a bags_total"

print("--------- VALORES NULOS DESPUES DE TRANSFORMAR ---------")
print(file.isnull().sum())

print("--------- RESUMEN DE ticket_price DESPUES DE NORMALIZAR ---------")
print(file['ticket_price'].describe())

# LOAD

conn = get_db_connection()
cursor = conn.cursor()

print("--------- LIMPIANDO TABLAS ANTES DE RECARGAR ---------")

cursor.execute("DELETE FROM Hechos_Vuelo")
cursor.execute("DELETE FROM Dim_Pasajero")
cursor.execute("DELETE FROM Dim_Fecha")
cursor.execute("DELETE FROM Dim_Avion")
cursor.execute("DELETE FROM Dim_Aeropuerto")
cursor.execute("DELETE FROM Dim_Aerolinea")

cursor.execute("DBCC CHECKIDENT ('Dim_Aerolinea', RESEED, 0)")
cursor.execute("DBCC CHECKIDENT ('Dim_Aeropuerto', RESEED, 0)")
cursor.execute("DBCC CHECKIDENT ('Dim_Avion', RESEED, 0)")
cursor.execute("DBCC CHECKIDENT ('Dim_Pasajero', RESEED, 0)")
cursor.execute("DBCC CHECKIDENT ('Hechos_Vuelo', RESEED, 0)")

conn.commit()

file['passenger_age'] = file['passenger_age'].round().astype(int)

# ============ DIM_AEROLINEA ============

aerolineas = (
    file[['airline_code', 'airline_name']]
    .drop_duplicates()
)

aerolineas_data = list(
    aerolineas.itertuples(index=False, name=None)
)

cursor.executemany(
    """
    INSERT INTO Dim_Aerolinea
    (airline_code, airline_name)
    VALUES (?, ?)
    """,
    aerolineas_data
)

conn.commit()

cursor.execute(
    "SELECT aerolinea_key, airline_code FROM Dim_Aerolinea"
)

map_aerolinea = {
    row.airline_code: row.aerolinea_key
    for row in cursor.fetchall()
}

# ============ DIM_AEROPUERTO ============

aeropuertos = (
    pd.concat([
        file['origin_airport'],
        file['destination_airport']
    ])
    .drop_duplicates()
)

aeropuertos_data = [
    (codigo,)
    for codigo in aeropuertos
]

cursor.executemany(
    """
    INSERT INTO Dim_Aeropuerto
    (codigo_aeropuerto)
    VALUES (?)
    """,
    aeropuertos_data
)

conn.commit()

cursor.execute(
    "SELECT aeropuerto_key, codigo_aeropuerto FROM Dim_Aeropuerto"
)

map_aeropuerto = {
    row.codigo_aeropuerto: row.aeropuerto_key
    for row in cursor.fetchall()
}

# ============ DIM_AVION ============

aviones = (
    file['aircraft_type']
    .drop_duplicates()
)

aviones_data = [
    (tipo,)
    for tipo in aviones
]

cursor.executemany(
    """
    INSERT INTO Dim_Avion
    (aircraft_type)
    VALUES (?)
    """,
    aviones_data
)

conn.commit()

cursor.execute(
    "SELECT avion_key, aircraft_type FROM Dim_Avion"
)

map_avion = {
    row.aircraft_type: row.avion_key
    for row in cursor.fetchall()
}

# ============ DIM_FECHA ============

dias_semana_es = [
    'Lunes',
    'Martes',
    'Miercoles',
    'Jueves',
    'Viernes',
    'Sabado',
    'Domingo'
]

meses_es = [
    'Enero',
    'Febrero',
    'Marzo',
    'Abril',
    'Mayo',
    'Junio',
    'Julio',
    'Agosto',
    'Septiembre',
    'Octubre',
    'Noviembre',
    'Diciembre'
]

fechas_unicas = pd.concat([
    file['departure_datetime'].dt.normalize(),
    file['booking_datetime'].dt.normalize(),
    file['arrival_datetime'].dt.normalize()
]).dropna().drop_duplicates()

dim_fecha = pd.DataFrame({
    'fecha': fechas_unicas
})

dim_fecha['fecha_key'] = (
    dim_fecha['fecha']
    .dt.strftime('%Y%m%d')
    .astype(int)
)

dim_fecha['anio'] = dim_fecha['fecha'].dt.year
dim_fecha['mes'] = dim_fecha['fecha'].dt.month

dim_fecha['nombre_mes'] = (
    dim_fecha['fecha']
    .dt.month
    .apply(lambda m: meses_es[m - 1])
)

dim_fecha['dia'] = dim_fecha['fecha'].dt.day
dim_fecha['trimestre'] = dim_fecha['fecha'].dt.quarter

dim_fecha['dia_semana'] = (
    dim_fecha['fecha']
    .dt.dayofweek
    .apply(lambda d: dias_semana_es[d])
)

fecha_data = list(
    dim_fecha[
        [
            'fecha_key',
            'fecha',
            'anio',
            'mes',
            'nombre_mes',
            'dia',
            'trimestre',
            'dia_semana'
        ]
    ].itertuples(index=False, name=None)
)

cursor.executemany(
    """
    INSERT INTO Dim_Fecha
    (
        fecha_key,
        fecha,
        anio,
        mes,
        nombre_mes,
        dia,
        trimestre,
        dia_semana
    )
    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    """,
    fecha_data
)

conn.commit()

# ============ DIM_PASAJERO ============

df_pasajero = (
    file
    .sort_values('booking_datetime')
    .drop_duplicates('passenger_id', keep='first')
    [
        [
            'passenger_id',
            'passenger_gender',
            'passenger_age',
            'passenger_nationality',
            'booking_datetime'
        ]
    ]
    .copy()
)

df_pasajero['fecha_inicio'] = (
    df_pasajero['booking_datetime']
    .dt.date
)

df_pasajero['fecha_fin'] = None
df_pasajero['es_vigente'] = 1

pasajero_data = list(
    df_pasajero[
        [
            'passenger_id',
            'passenger_gender',
            'passenger_age',
            'passenger_nationality',
            'fecha_inicio',
            'fecha_fin',
            'es_vigente'
        ]
    ].itertuples(index=False, name=None)
)

cursor.executemany(
    """
    INSERT INTO Dim_Pasajero
    (
        passenger_id,
        passenger_gender,
        passenger_age,
        passenger_nationality,
        fecha_inicio,
        fecha_fin,
        es_vigente
    )
    VALUES (?, ?, ?, ?, ?, ?, ?)
    """,
    pasajero_data
)

conn.commit()

cursor.execute(
    """
    SELECT pasajero_key, passenger_id
    FROM Dim_Pasajero
    WHERE es_vigente = 1
    """
)

map_pasajero = {
    row.passenger_id: row.pasajero_key
    for row in cursor.fetchall()
}

print("--------- DIMENSIONES CARGADAS ---------")
print("Aerolineas:", len(map_aerolinea))
print("Aeropuertos:", len(map_aeropuerto))
print("Aviones:", len(map_avion))
print("Fechas:", len(dim_fecha))
print("Pasajeros:", len(map_pasajero))

# ============ HECHOS_VUELO ============

hechos = file.copy()

hechos['aerolinea_key'] = (
    hechos['airline_code']
    .map(map_aerolinea)
)

hechos['avion_key'] = (
    hechos['aircraft_type']
    .map(map_avion)
)

hechos['aeropuerto_origen_key'] = (
    hechos['origin_airport']
    .map(map_aeropuerto)
)

hechos['aeropuerto_destino_key'] = (
    hechos['destination_airport']
    .map(map_aeropuerto)
)

hechos['pasajero_key'] = (
    hechos['passenger_id']
    .map(map_pasajero)
)

hechos['fecha_salida_key'] = (
    hechos['departure_datetime']
    .dt.strftime('%Y%m%d')
    .astype(int)
)

hechos['fecha_reserva_key'] = (
    hechos['booking_datetime']
    .dt.strftime('%Y%m%d')
    .astype(int)
)

hechos['fecha_valida'] = hechos['fecha_valida'].map({
    True: 1,
    False: 0
})

columnas_hechos = [
    'record_id',
    'aerolinea_key',
    'avion_key',
    'aeropuerto_origen_key',
    'aeropuerto_destino_key',
    'pasajero_key',
    'fecha_salida_key',
    'fecha_reserva_key',
    'flight_number',
    'departure_datetime',
    'arrival_datetime',
    'booking_datetime',
    'status',
    'duration_min',
    'delay_min',
    'fecha_valida',
    'cabin_class',
    'seat',
    'sales_channel',
    'payment_method',
    'ticket_price',
    'currency',
    'ticket_price_usd_est',
    'bags_total',
    'bags_checked'
]

hechos_final = hechos[columnas_hechos].copy()

hechos_final = hechos_final.astype(object)

hechos_final = hechos_final.where(
    pd.notna(hechos_final),
    None
)

hechos_data = list(
    hechos_final.itertuples(index=False, name=None)
)

placeholders = ", ".join(
    ["?"] * len(columnas_hechos)
)

insert_sql = (
    f"INSERT INTO Hechos_Vuelo "
    f"({', '.join(columnas_hechos)}) "
    f"VALUES ({placeholders})"
)

cursor.fast_executemany = False

insertadas = 0

for i, fila in enumerate(hechos_data):
    try:
        cursor.execute(
            insert_sql,
            fila
        )

        insertadas += 1

    except pyodbc.Error as e:
        print("--------- ERROR EN FILA ---------")
        print("indice:", i)
        print("record_id:", fila[0])
        print("valores:", fila)
        print("error:", e)
        break

conn.commit()

print("--------- HECHOS CARGADOS ---------")
print(insertadas, "filas insertadas en Hechos_Vuelo")

cursor.close()
conn.close()