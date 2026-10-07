import logging
import os
import sys
from datetime import datetime, timezone
from pathlib import Path

import pandas as pd
from sqlalchemy import inspect, text

from connectiondb import get_dw_engine, get_oltp_engine


logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
)
log = logging.getLogger("carga_raw")


BASE_DIR = Path(__file__).resolve().parent.parent
DATA_DIR = Path(os.getenv("DATA_DIR", BASE_DIR / "Data-20260929"))


CSV_FILES = {
    "inventario_bodega": "inventario_bodega.csv",
    "metas_ventas": "metas_ventas.csv",
    "promociones": "promociones.csv",
    "proveedores_precios": "proveedores_precios.csv",
    "devoluciones": "devoluciones.csv",
}

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

    if columnas.empty:
        raise ValueError(f"La tabla {OLTP_SCHEMA}.{tabla} no existe en la fuente")

    select_cols = ", ".join(f'"{c}"::text AS "{c}"' for c in columnas)
    consulta = f'SELECT {select_cols} FROM {OLTP_SCHEMA}."{tabla}"'
    return pd.read_sql(text(consulta), engine)


def cargar_raw(df: pd.DataFrame, tabla: str, origen: str, engine) -> None:

    df = df.copy()

    df["_loaded_at"] = datetime.now(timezone.utc).isoformat()
    df["_source"] = origen

    with engine.begin() as conn:
        if inspect(conn).has_table(tabla, schema="raw"):
            conn.execute(text(f'TRUNCATE TABLE raw."{tabla}"'))
            modo = "append"
        else:
            modo = "fail"

        df.to_sql(
            tabla,
            conn,
            schema="raw",
            if_exists=modo,
            index=False
        )

    log.info("raw.%s: %s filas cargadas", tabla, len(df))


def cargar_oltp(dw_engine) -> None:
    oltp_engine = get_oltp_engine()
    try:
        for tabla in OLTP_TABLES:
            df = extraer_oltp(tabla, oltp_engine)
            cargar_raw(df, tabla, f"oltp:{OLTP_SCHEMA}.{tabla}", dw_engine)
    finally:
        oltp_engine.dispose()


def cargar_csv(dw_engine) -> None:
    for tabla, archivo in CSV_FILES.items():
        df = extraer_csv(archivo)
        cargar_raw(df, tabla, f"csv:{archivo}", dw_engine)


def main(fuente: str = "todo") -> None:
    dw_engine = get_dw_engine()
    try:
        with dw_engine.begin() as conn:
            conn.execute(text("CREATE SCHEMA IF NOT EXISTS raw"))

        if fuente in ("todo", "oltp"):
            cargar_oltp(dw_engine)
        if fuente in ("todo", "csv"):
            cargar_csv(dw_engine)
    finally:
        dw_engine.dispose()


if __name__ == "__main__":
    fuente = sys.argv[1] if len(sys.argv) > 1 else "todo"
    if fuente not in ("todo", "oltp", "csv"):
        sys.exit("Uso: python main.py [todo|oltp|csv]")

    try:
        main(fuente)
    except Exception:
        log.exception("La carga a raw falló")
        sys.exit(1)
