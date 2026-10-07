import sys

from sqlalchemy import text

from connectiondb import get_dw_engine, get_oltp_engine


def main():
    fallos = 0
    for nombre, get_engine in (("OLTP", get_oltp_engine), ("DW", get_dw_engine)):
        engine = get_engine()
        try:
            with engine.connect() as conn:
                version = conn.execute(text("SELECT version();")).scalar()

            print(f"Conexión exitosa a {nombre}")
            print(f"PostgreSQL: {version}")

        except Exception as e:
            print(f"Error de conexión a {nombre}:")
            print(e)
            fallos += 1

        finally:
            engine.dispose()

    return fallos


if __name__ == "__main__":
    sys.exit(1 if main() else 0)
