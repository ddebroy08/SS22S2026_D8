import pandas as pd

from connectiondb import get_oltp_engine, get_dw_engine


def extraer_productos():
    engine = get_oltp_engine()

    query = """
        SELECT *
        FROM oltp_sgfood.producto;
    """

    df = pd.read_sql(query, engine)

    engine.dispose()

    return df

def extraer_promociones():
    engine = get_dw_engine()
    query = """
        SELECT * FROM raw.promociones;
    """

    df = pd.read_sql(query, engine)

    engine.dispose()

    return df



if __name__ == "__main__":
    df = extraer_productos()

    print("Datos extraídos correctamente")
    print(f"Cantidad de registros: {len(df)}")
    print("\nPrimeros registros:")
    print(df.head())

    df_promociones = extraer_promociones()
    print("\n ================================= ")
    print("Datos de promociones extraídos correctamente")
    print(f"Cantidad de registros: {len(df_promociones)}")
    print("\nPrimeros registros:")
    print(df_promociones.head())