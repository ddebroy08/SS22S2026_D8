from connectiondb import get_oltp_connection


def main():
    try:
        conn = get_oltp_connection()

        with conn.cursor() as cursor:
            cursor.execute("SELECT version();")
            version = cursor.fetchone()

            print("Conexión exitosa")
            print(f"PostgreSQL: {version[0]}")

        conn.close()

    except Exception as e:
        print("Error de conexión:")
        print(e)


if __name__ == "__main__":
    main()