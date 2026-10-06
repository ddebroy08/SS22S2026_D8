import os
from datetime import datetime, timezone
from pathlib import Path

import pandas as pd
from dotenv import load_dotenv
from sqlalchemy import create_engine, text


load_dotenv()


BASE_DIR = Path(__file__).resolve().parent.parent
DATA_DIR = BASE_DIR / "Data-20260929"


CSV_FILES = {
    "inventario_bodega": "inventario_bodega.csv",
    "metas_ventas": "metas_ventas.csv",
    "promociones": "promociones.csv",
    "proveedores_precios": "proveedores_precios.csv",
    "devoluciones": "devoluciones.csv",
}

OLTP_URL = (
    f"postgresql+psycopg://"
    f"{os.getenv('OLTP_USER')}:"
    f"{os.getenv('OLTP_PASSWORD')}@"
    f"{os.getenv('OLTP_HOST')}:"
    f"{os.getenv('OLTP_PORT')}/"
    f"{os.getenv('OLTP_DB')}"
)

OLTP_SCHEMA = "oltp_sgfood"

OLTP_TABLES = [
    "sucursal",
    "categoria",
    "marca",
    "producto",
    "cliente",
    "venta",
    "venta_detalle",
]

DW_URL = (
    f"postgresql+psycopg://"
    f"{os.getenv('DW_USER')}:"
    f"{os.getenv('DW_PASSWORD')}@"
    f"{os.getenv('DW_HOST')}:"
    f"{os.getenv('DW_PORT')}/"
    f"{os.getenv('DW_DB')}"
)


def extraer_csv(nombre_archivo: str) -> pd.DataFrame:
    ruta = DATA_DIR / nombre_archivo

    df = pd.read_csv(
        ruta,
        dtype=str,
        encoding="utf-8-sig"
    )

    df.columns = [c.strip().lower() for c in df.columns]

    return df

def extraer_oltp(tabla: str, engine) -> pd.DataFrame:

    columnas = pd.read_sql(
        text("""
            SELECT column_name
            FROM information_schema.columns
            WHERE table_schema = :esquema
                AND table_name = :tabla
            ORDER BY ordinal_position
        """),
        engine,
        params={"esquema": OLTP_SCHEMA, "tabla": tabla},
    )["column_name"]

    select_cols = ", ".join(f'"{c}"::text AS "{c}"' for c in columnas)
    consulta = f'SELECT {select_cols} FROM {OLTP_SCHEMA}."{tabla}"'
    return pd.read_sql(text(consulta), engine)


def cargar_raw(df: pd.DataFrame, tabla: str, origen: str, engine) -> None:

    df = df.copy()

    df["_loaded_at"] = datetime.now(timezone.utc).isoformat()
    df["_source"] = origen

    df.to_sql(
        tabla,
        engine,
        schema="raw",
        if_exists="replace",
        index=False
    )

    print(f"raw.{tabla}: {len(df)} filas cargadas")


if __name__ == "__main__":

    dw_engine = create_engine(DW_URL)
    oltp_engine = create_engine(OLTP_URL)

    for tabla in OLTP_TABLES:
        df = extraer_oltp(tabla, oltp_engine)
        cargar_raw(df, tabla, f"oltp:{OLTP_SCHEMA}.{tabla}", dw_engine)

    for tabla, archivo in CSV_FILES.items():
        df = extraer_csv(archivo)
        cargar_raw(df, tabla, f"csv:{archivo}", dw_engine)

    oltp_engine.dispose()
    dw_engine.dispose()