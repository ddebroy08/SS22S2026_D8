import pyodbc


def get_db_connection():
    server = r"DESKTOP-91F9CRE\SQLEXPRESS"
    database = "SS22S2026_G8"
    driver = "{ODBC Driver 18 for SQL Server}"

    conn_str = (
        f"DRIVER={driver};"
        f"SERVER={server};"
        f"DATABASE={database};"
        f"Trusted_Connection=yes;"
        f"TrustServerCertificate=yes;"
    )

    try:
        conn = pyodbc.connect(conn_str)
    except pyodbc.Error as e:
        raise Exception(f"Error al abrir conexión: {e}")

    print("Conexión exitosa a SQL Server!")
    return conn