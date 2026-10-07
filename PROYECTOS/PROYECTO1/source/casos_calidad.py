import sys
from datetime import datetime, timezone

import pandas as pd
from sqlalchemy import text

from connectiondb import get_dw_engine
from main import DATA_DIR


ARCHIVO = "casos_calidad_opcionales.csv"

TABLA_RAW = {
    "cliente": "cliente",
    "producto": "producto",
    "venta": "venta",
    "venta_detalle": "venta_detalle",
    "inventario": "inventario_bodega",
    "proveedores_precios": "proveedores_precios",
    "metas_ventas": "metas_ventas",
    "devoluciones": "devoluciones",
}

CAMPO_RAW = {
    ("devoluciones", "cantidad"): "cantidad",
}

LLAVE_NUEVA = [
    {},
    {"id_producto": "9001", "sku": "PRUEBA-9001"},
    {"id_venta": "9000001"},
    {"id_detalle": "9000001", "id_venta": "9000001"},
    {"id_detalle": "9000002", "id_venta": "9000001"},
    {"fecha_corte": "2026-09-30"},
    {"fecha_corte": "2026-10-31"},
    {"id_proveedor": "99"},
    {"periodo": "2026-09"},
    {"id_devolucion": "9001"},
]


def inyectar(engine) -> None:
    casos = pd.read_csv(DATA_DIR / ARCHIVO, dtype=str, encoding="utf-8-sig")

    for i, caso in casos.iterrows():
        tabla = TABLA_RAW[caso["entidad"]]
        campo = CAMPO_RAW.get((caso["entidad"], caso["campo"]), caso["campo"])
        valor = None if pd.isna(caso["valor_prueba"]) else caso["valor_prueba"]

        fila = pd.read_sql(text(f'SELECT * FROM raw."{tabla}" LIMIT 1'), engine)
        for columna, nuevo in LLAVE_NUEVA[i].items():
            fila[columna] = nuevo
        fila[campo] = valor
        fila["_loaded_at"] = datetime.now(timezone.utc).isoformat()
        fila["_source"] = f"prueba:{ARCHIVO}"

        fila.to_sql(tabla, engine, schema="raw", if_exists="append", index=False)
        print(f"raw.{tabla}.{campo} = {valor!r} -> {caso['tipo_incidencia']}")


def limpiar(engine) -> None:
    with engine.begin() as conn:
        for tabla in sorted(set(TABLA_RAW.values())):
            borradas = conn.execute(
                text(f'DELETE FROM raw."{tabla}" WHERE _source = :origen'),
                {"origen": f"prueba:{ARCHIVO}"},
            ).rowcount
            print(f"raw.{tabla}: {borradas} filas de prueba eliminadas")


if __name__ == "__main__":
    accion = sys.argv[1] if len(sys.argv) > 1 else ""
    if accion not in ("inyectar", "limpiar"):
        sys.exit("Uso: python casos_calidad.py [inyectar|limpiar]")

    engine = get_dw_engine()
    try:
        inyectar(engine) if accion == "inyectar" else limpiar(engine)
    finally:
        engine.dispose()
