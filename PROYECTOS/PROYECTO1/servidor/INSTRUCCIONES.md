# Instrucciones de despliegue – Proyecto 1 SG-Food en el servidor

Este archivo está pensado para que **Claude Code (o una persona) lo ejecute en el servidor Linux** `homelab-hp`. Hay que seguir los pasos en orden y comprobar cada verificación antes de avanzar. Si algo falla, revisar la sección *Solución de problemas* al final.

Al terminar quedan corriendo:

| Servicio | Puerto en el servidor | Uso |
|---|---|---|
| PostgreSQL SG-Food (`sgfood_oltp` + `sgfood_dw`) | 5434 | fuente OLTP y Data Warehouse |
| Airflow (webserver) | 8090 | ver y ejecutar el DAG `sgfood_elt` |
| Documentación dbt | 8091 | lineage y documentación de modelos |

## Reglas importantes

- En el servidor corren **otros proyectos** (dspace, moodle `eps`/`eps45`, keycloak, grafana, portainer, my_secret_place, etc.). **No detener, borrar ni modificar ningún contenedor, volumen o red que no pertenezca al proyecto `sgfood`.**
- Prohibido usar `docker system prune`, `docker volume prune`, `docker rm` o `docker stop` sobre contenedores ajenos.
- Todos los comandos `docker compose` se ejecutan desde `~/SS22S2026_D8/PROYECTOS/PROYECTO1/servidor`. El proyecto Compose se llama `sgfood`, así que sus contenedores empiezan con `sgfood-`.
- No subir el archivo `.env` al repositorio (ya está en `.gitignore`).

---

## Paso 0. Comprobaciones previas

```bash
docker compose version          # debe existir Docker Compose v2
free -h                         # Airflow necesita unos 3 GB de RAM libres
df -h ~                         # al menos 5 GB libres
ss -tlnp | grep -E ':(5434|8090|8091)\b' || echo "Puertos libres"
```

Si alguno de los puertos 5434, 8090 u 8091 está ocupado, se elige otro libre y se cambia en `.env` durante el paso 2 (`SGFOOD_DB_PORT`, `AIRFLOW_PORT`, `DBT_DOCS_PORT`).

## Paso 1. Obtener el repositorio

```bash
cd ~
if [ -d SS22S2026_D8/.git ]; then
  git -C SS22S2026_D8 pull
else
  git clone https://github.com/ddebroy08/SS22S2026_D8.git
fi
cd ~/SS22S2026_D8/PROYECTOS/PROYECTO1/servidor
```

**Verificar:** existen `docker-compose.yml`, `initdb/01_sgfood.sh` y `../Data-20260929/sgfood_oltp.sql`.

## Paso 2. Configurar variables de entorno

Crear `.env` con contraseñas aleatorias y el UID del usuario actual:

```bash
cp .env.example .env
sed -i "s/^AIRFLOW_UID=.*/AIRFLOW_UID=$(id -u)/" .env
sed -i "s/^SGFOOD_DB_PASSWORD=.*/SGFOOD_DB_PASSWORD=$(openssl rand -hex 16)/" .env
sed -i "s/^AIRFLOW_DB_PASSWORD=.*/AIRFLOW_DB_PASSWORD=$(openssl rand -hex 16)/" .env
sed -i "s/^AIRFLOW_ADMIN_PASSWORD=.*/AIRFLOW_ADMIN_PASSWORD=$(openssl rand -hex 8)/" .env
chmod 600 .env
cat .env
```

**Mostrarle al usuario** `AIRFLOW_ADMIN_USER` y `AIRFLOW_ADMIN_PASSWORD` (para entrar a Airflow), además de `SGFOOD_DB_USER` y `SGFOOD_DB_PASSWORD` (para conectarse a PostgreSQL).

## Paso 3. Preparar carpetas con los permisos correctos

Airflow corre con el UID del usuario y escribe logs y la carpeta `target/` de dbt. Las carpetas tienen que existir **antes** de levantar los contenedores; si no, Docker las crea como root y dbt no puede escribir:

```bash
mkdir -p logs ../dbt_sgfood/target ../dbt_sgfood/logs ../evidencias/salidas
chmod +x initdb/01_sgfood.sh
ls -ld logs ../dbt_sgfood/target     # dueño: el usuario actual, no root
```

## Paso 4. Construir y levantar

```bash
docker compose up -d --build
```

La primera vez tarda varios minutos porque construye la imagen de Airflow con pandas y dbt. Después:

```bash
docker compose ps
```

**Verificar:**
- `sgfood-sgfood-db-1` y `sgfood-airflow-db-1` aparecen como `healthy`.
- `sgfood-airflow-init-1` terminó con `Exited (0)`.
- `sgfood-airflow-webserver-1` (puede tardar 1–2 min en quedar `healthy`), `sgfood-airflow-scheduler-1` y `sgfood-dbt-docs-1` están `Up`.

Si `airflow-init` terminó con un código distinto de 0: `docker compose logs airflow-init`.

## Paso 5. Verificar las bases de datos

```bash
set -a; . ./.env; set +a
docker compose exec -T sgfood-db psql -U "$SGFOOD_DB_USER" -d sgfood_oltp -c "\dt oltp_sgfood.*"
docker compose exec -T sgfood-db psql -U "$SGFOOD_DB_USER" -d sgfood_dw -c "\dn"
```

**Verificar:**
- `oltp_sgfood` tiene 7 tablas: sucursal, categoria, marca, producto, cliente, venta, venta_detalle.
- `sgfood_dw` tiene los schemas raw, staging, intermediate y marts.

Si `sgfood_oltp` no existe, el script de inicialización no corrió (ver *Solución de problemas*).

## Paso 6. Ejecutar el DAG `sgfood_elt`

```bash
docker compose exec airflow-scheduler airflow dags list-import-errors
docker compose exec airflow-scheduler airflow dags unpause sgfood_elt
docker compose exec airflow-scheduler airflow dags trigger sgfood_elt
```

Al despausarlo, Airflow puede crear también una corrida programada. Las corridas no se pisan porque el DAG tiene `max_active_runs=1`.

Revisar el estado cada 30–60 s hasta que la corrida quede `success` o `failed` (tarda unos 3–6 minutos):

```bash
docker compose exec airflow-scheduler airflow dags list-runs -d sgfood_elt -o plain
```

Para ver el estado de cada tarea de una corrida (tomar el `run_id` de la salida anterior):

```bash
docker compose exec airflow-scheduler airflow tasks states-for-dag-run sgfood_elt "<run_id>"
```

**Verificar:** las 9 tareas en `success`: verificar_conexiones, cargar_oltp_raw, cargar_csv_raw, inyectar_casos_calidad, dbt_run_staging, dbt_test_staging, dbt_run_marts, dbt_test_marts y dbt_docs_generate.

Si una tarea falla, su log está en `logs/dag_id=sgfood_elt/run_id=<run_id>/task_id=<tarea>/attempt=*.log`. Hay que leerlo, corregir la causa y volver a lanzar el DAG.

## Paso 7. Validaciones y evidencias

Una vez que el DAG terminó en `success`, guardar las salidas para el informe:

```bash
set -a; . ./.env; set +a

docker compose exec -T sgfood-db psql -U "$SGFOOD_DB_USER" -d sgfood_dw \
  < ../sql/03_validacion.sql | tee ../evidencias/salidas/03_validacion.txt

docker compose exec -T sgfood-db psql -U "$SGFOOD_DB_USER" -d sgfood_dw \
  < ../sql/04_consultas_analiticas.sql | tee ../evidencias/salidas/04_consultas_analiticas.txt

docker compose exec airflow-scheduler bash -c \
  "cd /opt/sgfood/dbt_sgfood && /opt/pipeline_venv/bin/dbt build" \
  | tee ../evidencias/salidas/dbt_build.txt

docker compose exec airflow-scheduler airflow dags list-runs -d sgfood_elt -o plain \
  | tee ../evidencias/salidas/airflow_dag_runs.txt
```

**Verificar contra el README:**
- Conteos raw = staging = marts: venta_detalle 3,209; devoluciones 80; inventario 3,840; metas 48; proveedores_precios 103; producto 80; cliente 250; sucursal 6; proveedores 12.
- Suma del subtotal = suma de monto_venta = 838,452.07; unidades 19,174.
- Ventas por estado: COMPLETADA 1,129, ANULADA 48, PENDIENTE 23.
- `dbt build` termina con `ERROR=0` (25 modelos y 147 pruebas en PASS).

Si algún número no coincide, avisarle al usuario con la diferencia exacta.

## Paso 8 (opcional). Demostración de casos de calidad

```bash
docker compose exec airflow-scheduler airflow dags trigger sgfood_elt --conf '{"casos_calidad": true}'
```

**Resultado esperado:** `inyectar_casos_calidad` en success, **`dbt_test_staging` en failed**, y `dbt_run_marts` en adelante en `upstream_failed` (marts conserva los datos válidos). Guardar el log de `dbt_test_staging` en `../evidencias/salidas/dbt_test_casos_calidad.txt`.

Después lanzar una corrida normal para dejar raw limpio de nuevo:

```bash
docker compose exec airflow-scheduler airflow dags trigger sgfood_elt
```

## Paso 9. Reporte final al usuario

Decirle al usuario:

1. Si todo quedó en verde y los números coinciden.
2. Las URLs, para abrirlas desde su compu Windows (Tailscale, IP `100.65.109.0`):
   - Airflow: `http://100.65.109.0:8090` (usuario y contraseña del `.env`)
   - Documentación dbt: `http://100.65.109.0:8091`
   - PostgreSQL: host `100.65.109.0`, puerto `5434`, bases `sgfood_dw` y `sgfood_oltp`. Se puede registrar en el pgAdmin que ya existe en `http://100.65.109.0:8085`.
3. Qué archivos de evidencia quedaron en `PROYECTOS/PROYECTO1/evidencias/salidas/`.

No hacer commit ni push sin que el usuario lo pida.

---

## Comandos útiles

```bash
docker compose ps                         # estado
docker compose logs -f airflow-scheduler  # logs en vivo
docker compose stop                       # detener sin borrar datos
docker compose start                      # volver a iniciar
docker compose down                       # quitar contenedores (los datos quedan en los volúmenes)
```

Después de un `git pull` con cambios en DAGs, scripts o modelos dbt no hace falta reconstruir, porque están montados como volúmenes. Solo hay que reconstruir (`docker compose up -d --build`) si cambia `../airflow/Dockerfile` o `../airflow/requirements-pipeline.txt`.

## Solución de problemas

| Síntoma | Causa | Solución |
|---|---|---|
| `port is already allocated` | puerto ocupado por otro proyecto | cambiar el puerto en `.env` y `docker compose up -d` |
| No existe `sgfood_oltp` | el volumen ya existía, así que el init no se ejecutó | `docker compose down`, luego `docker volume rm sgfood_sgfood_pgdata` (**solo ese volumen**) y `docker compose up -d` |
| `Permission denied` en logs o en `target/` | carpetas creadas como root | `sudo chown -R $(id -u):$(id -g) logs ../dbt_sgfood/target ../dbt_sgfood/logs` y reiniciar |
| `initdb/01_sgfood.sh: bad interpreter` | finales de línea CRLF | `sed -i 's/\r$//' initdb/01_sgfood.sh` y recrear el volumen como arriba |
| Webserver reinicia en bucle | poca memoria | `free -h`; revisar `docker compose logs airflow-webserver` |
| `verificar_conexiones` falla | credenciales o la base no está lista | `docker compose ps` (sgfood-db healthy) y revisar `.env` |
| La página de dbt docs muestra 403/404 | todavía no corre `dbt_docs_generate` | ejecutar el DAG (paso 6) y recargar |
