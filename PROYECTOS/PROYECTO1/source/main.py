import os
from datetime import datetime, timezone
from pathlib import Path

import pandas as pd
from sqlalchemy import create_engine

DW_URL = os.getenv("DW_URL", "postgresql://sgfood:sgfood123@localhost:5433/sgfood_dw")
BASE_DIR = Path(__file__).resolve().parent.parent
DATA_DIR = BASE_DIR / "Data-20260929"

CSV_FILES = {
    "inventario_bodega": "inventario_bodega.csv",
    "metas_ventas": "metas_ventas.csv",
    "promociones": "promociones.csv",
    "proveedores_precios": "proveedores_precios.csv",
    "devoluciones": "devoluciones.csv",
}

def extraer_csv(nombre_archivo: str) -> pd.DataFrame:
    ruta = DATA_DIR / nombre_archivo
    df = pd.read_csv(ruta, dtype=str, encoding="utf-8-sig")
    df.columns = [c.strip().lower() for c in df.columns]
    return df

def cargar_raw(df: pd.DataFrame, tabla: str, origen: str, engine) -> None:
    df = df.copy()
    df["_loaded_at"] = datetime.now(timezone.utc).isoformat()
    df["_source"] = origen
    df.to_sql(tabla, engine, schema="raw", if_exists="replace", index=False)
    print(f"raw.{tabla}: {len(df)} filas cargadas")

if __name__ == "__main__":
    engine = create_engine(DW_URL)
    for tabla, archivo in CSV_FILES.items():
        df = extraer_csv(archivo)
        cargar_raw(df, tabla, f"csv:{archivo}", engine)