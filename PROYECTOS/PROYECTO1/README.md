# Proyecto 1 – Pipeline ELT SG-Food

Seminario de Sistemas 2 – Grupo 8

Flujo moderno de datos con **Python**, **Apache Airflow**, **dbt** y **PostgreSQL**: extracción desde la base transaccional y archivos CSV, carga cruda en un Data Warehouse, transformación por capas con dbt, pruebas de calidad y consultas analíticas.
## Integrantes

| Nombre | Carné |
|---|---|
| Diego Debroy | 202101923 |
| Pablo Alejandro Marroquin Cutz | 202200214 |
| Carlos Monterroso | 201903767 |

---

## 1. Arquitectura y descripción del pipeline

```
 sgfood_oltp (PostgreSQL)          Data-20260929/*.csv
   schema oltp_sgfood                     |
          |                               |
          +------------ Python -----------+         Airflow (DAG sgfood_elt)
                    source/main.py                  orquesta todas las etapas
                          |
                          v
 sgfood_dw (PostgreSQL) ──────────────────────────────────────────────
   raw            12 tablas, todas las columnas como texto + _loaded_at, _source
     |  dbt
   staging        12 vistas: tipos, trim, renombres
     |
   intermediate   3 vistas: uniones y cálculos de negocio
     |
   marts          5 dimensiones + 5 hechos (tablas con PK y FK)
```

Es un enfoque **ELT**: Python solo extrae y carga sin transformar; toda la lógica de negocio vive en dbt, versionada, probada y documentada.

## 2. Estructura del repositorio

```
PROYECTO1/
├── airflow/
│   ├── dags/sgfood_elt.py          DAG del pipeline
│   ├── dbt_profiles/profiles.yml   perfil dbt que lee credenciales de variables de entorno
│   ├── Dockerfile                  imagen de Airflow + venv con pandas, psycopg y dbt
│   ├── docker-compose.yml          Airflow (webserver, scheduler, metadatos)
│   ├── requirements-pipeline.txt
│   └── .env.example
├── Data-20260929/                  archivos fuente (CSV, dump OLTP, diccionario)
├── dbt_sgfood/
│   ├── macros/                     generate_schema_name
│   ├── models/staging/             sources.yml, schema.yml, stg_*.sql
│   ├── models/intermediate/        schema.yml, int_*.sql
│   ├── models/marts/               schema.yml, dim_*.sql, fct_*.sql
│   └── tests/                      pruebas singulares y genéricas
├── docs/
│   ├── img/                        diagrama ER y modelo estrella
│   └── dbt_docs/index.html         documentación y lineage de dbt (estático)
├── source/
│   ├── connectiondb.py             motores SQLAlchemy OLTP y DW
│   ├── main.py                     extracción y carga a raw
│   ├── casos_calidad.py            inyección de datos inválidos para probar la calidad
│   ├── test_connection.py          verificación de conexiones
│   └── .env.example
├── sql/
│   ├── 01_schemas.sql              base OLTP y schemas del DW
│   ├── 02_ddl_data_warehouse.sql   DDL completo: raw, dimensiones, hechos, PK y FK
│   ├── 03_validacion.sql           conteos, cuadres, integridad y reglas
│   └── 04_consultas_analiticas.sql preguntas de negocio
└── requirements.txt
```

## 3. Fuentes de datos

| Fuente | Tipo | Tablas / archivos | Destino raw |
|---|---|---|---|
| `sgfood_oltp.oltp_sgfood` | PostgreSQL | sucursal, categoria, marca, producto, cliente, venta, venta_detalle | `raw.<tabla>` |
| `inventario_bodega.csv` | CSV | inventario mensual por sucursal y producto | `raw.inventario_bodega` |
| `proveedores_precios.csv` | CSV | costos y plazos de proveedores | `raw.proveedores_precios` |
| `promociones.csv` | CSV | campañas por categoría | `raw.promociones` |
| `metas_ventas.csv` | CSV | metas mensuales por sucursal | `raw.metas_ventas` |
| `devoluciones.csv` | CSV | devoluciones | `raw.devoluciones` |
| `casos_calidad_opcionales.csv` | CSV | datos inválidos intencionales | no se carga en la corrida normal |

## 4. Extracción y carga (Python)

`source/main.py`:

- **OLTP**: lee las columnas desde `information_schema` y extrae cada tabla con `columna::text`, para que raw sea una copia fiel sin conversiones.
- **CSV**: `pandas.read_csv(dtype=str, encoding="utf-8-sig")`, normalizando nombres de columna.
- **Auditoría**: cada fila recibe `_loaded_at` (UTC) y `_source` (`oltp:...` o `csv:...`).
- **Carga idempotente**: si la tabla existe se hace `TRUNCATE` + `append` dentro de una transacción; si no existe se crea. No se usa `DROP` porque las vistas de staging dependen de raw y la carga sería imposible de repetir.
- **Errores y registros**: logging con fecha y nivel; ante cualquier excepción termina con código 1 para que Airflow marque la tarea como fallida.
- Acepta un argumento para cargar por separado: `python main.py [todo|oltp|csv]`.

## 5. Data Warehouse

### Schemas

| Schema | Contenido | Materialización |
|---|---|---|
| `raw` | Datos crudos como texto | tablas (Python) |
| `staging` | Limpieza y tipado 1:1 con raw | vistas |
| `intermediate` | Uniones y reglas de negocio | vistas |
| `marts` | Modelo estrella | tablas con PK y FK |

### Modelo estrella

![Modelo estrella](docs/img/Modelo%20estrella.jpeg)

**Dimensiones** (llaves naturales):

| Dimensión | PK | Atributos |
|---|---|---|
| `dim_fecha` | fecha | anio, trimestre, mes, nombre_mes, semana_anio, dia, dia_semana (1 = lunes), nombre_dia, es_fin_de_semana |
| `dim_producto` | id_producto | sku, nombre_producto, unidad_medida, costo_base, precio_lista, activo, id_categoria, nombre_categoria, nombre_marca |
| `dim_cliente` | id_cliente | nit, nombre_cliente, tipo_cliente, municipio, departamento, fecha_alta |
| `dim_sucursal` | id_sucursal | nombre_sucursal, ciudad, departamento |
| `dim_proveedor` | id_proveedor | nombre_proveedor |

**Hechos**:

| Hecho | Grano | Medidas | Filas |
|---|---|---|---|
| `fct_ventas` | un producto dentro de una venta | cantidad, precio_unitario, descuento, monto_venta, costo_venta | 3,209 |
| `fct_devoluciones` | una devolución | cantidad_devuelta, monto_devuelto | 80 |
| `fct_inventario` | producto × sucursal × fecha de corte | stock_disponible (semiaditiva), stock_minimo, stock_maximo, dias_para_vencer | 3,840 |
| `fct_metas` | sucursal × mes | meta_ventas, meta_unidades | 48 |
| `fct_cotizaciones_proveedor` | producto ofrecido por proveedor | costo_proveedor, plazo_dias (no aditivas) | 103 |

### Matriz de bus

| Proceso de negocio | dim_fecha | dim_producto | dim_cliente | dim_sucursal | dim_proveedor |
|---|:-:|:-:|:-:|:-:|:-:|
| Ventas (`fct_ventas`) | ✔ | ✔ | ✔ | ✔ | |
| Devoluciones (`fct_devoluciones`) | ✔ | ✔ | ✔ | ✔ | |
| Inventario (`fct_inventario`) | ✔ | ✔ | | ✔ | |
| Metas (`fct_metas`) | ✔ | | | ✔ | |
| Cotizaciones (`fct_cotizaciones_proveedor`) | ✔ | ✔ | | | ✔ |

El DDL completo, con tipos, llaves primarias y foráneas, está en [`sql/02_ddl_data_warehouse.sql`](sql/02_ddl_data_warehouse.sql). En dbt las mismas llaves se crean con `post_hook` en cada modelo de marts.

## 6. Proyecto dbt

| Capa | Modelos |
|---|---|
| Staging | `stg_sucursal`, `stg_categoria`, `stg_marca`, `stg_producto`, `stg_cliente`, `stg_venta`, `stg_venta_detalle`, `stg_inventario_bodega`, `stg_metas_ventas`, `stg_promociones`, `stg_proveedores_precios`, `stg_devoluciones` |
| Intermediate | `int_productos`, `int_ventas_detalladas`, `int_devoluciones_con_venta` |
| Marts | `dim_fecha`, `dim_producto`, `dim_cliente`, `dim_sucursal`, `dim_proveedor`, `fct_ventas`, `fct_devoluciones`, `fct_inventario`, `fct_metas`, `fct_cotizaciones_proveedor` |

- **sources**: `models/staging/sources.yml` declara las 12 tablas de `raw`.
- **refs**: cada capa referencia solo a la anterior; los hechos declaran dependencia de sus dimensiones para que dbt las construya primero y las FK sean válidas.
- **Macro** `generate_schema_name`: usa el schema configurado tal cual (`staging`, `intermediate`, `marts`) en lugar de `public_staging`.
- **Lineage**: abrir `docs/dbt_docs/index.html` o ejecutar `dbt docs serve`.

### Pruebas de calidad (147)

| Tipo | Dónde | Qué valida |
|---|---|---|
| `unique`, `not_null` | PK de staging, intermediate y marts | unicidad y llaves completas |
| `relationships` | FK de staging y de hechos hacia dimensiones | integridad referencial |
| `accepted_values` | estado, estado_stock, canal, metodo_pago, tipo_cliente, dia_semana | dominios válidos |
| `valor_en_rango` (genérica propia) | precios, cantidad, descuento, stock, metas, costos | rangos de negocio |
| `unique_combinacion` (genérica propia) | llaves compuestas de inventario, metas y cotizaciones | unicidad del grano |
| Singulares | `tests/` | devolución no supera lo vendido, devolución posterior a la venta, vencimiento posterior al corte, monto de venta cuadra, conteos marts = staging, llaves únicas de staging |

### Demostración con `casos_calidad_opcionales.csv`

`source/casos_calidad.py inyectar` copia una fila válida de raw por cada caso y le asigna el valor inválido. Resultado de `dbt test`:

| Caso | Prueba que lo detecta |
|---|---|
| NULL en id_cliente | `not_null_stg_cliente_id_cliente` |
| Precio negativo | `valor_en_rango_stg_producto_precio_lista` |
| FK huérfana en venta | `relationships_stg_venta_id_cliente` |
| Cantidad cero | `valor_en_rango_stg_venta_detalle_cantidad` |
| Descuento mayor a 100 % | `valor_en_rango_stg_venta_detalle_descuento` |
| Stock negativo | `valor_en_rango_stg_inventario_bodega_stock_disponible` |
| Vencimiento anterior al corte | `assert_vencimiento_posterior_al_corte` |
| Costo de proveedor nulo | `not_null_stg_proveedores_precios_costo_proveedor` |
| Meta cero | `valor_en_rango_stg_metas_ventas_meta_ventas` |
| Devolución superior a la venta | `assert_devolucion_no_supera_vendido` (marts) |

`python casos_calidad.py limpiar` elimina las filas de prueba (se identifican por `_source`).

## 7. DAG de Airflow

DAG `sgfood_elt` (`airflow/dags/sgfood_elt.py`), programado diario a las 06:00 (`0 6 * * *`), sin catchup, una corrida activa a la vez y un reintento por tarea de carga.

```
verificar_conexiones
   ├── cargar_oltp_raw ─┐
   └── cargar_csv_raw ──┴── inyectar_casos_calidad ── dbt_run_staging ── dbt_test_staging
                                                         ── dbt_run_marts ── dbt_test_marts ── dbt_docs_generate
```

| Tarea | Acción |
|---|---|
| `verificar_conexiones` | `test_connection.py`; falla si OLTP o DW no responden |
| `cargar_oltp_raw` / `cargar_csv_raw` | `main.py oltp` / `main.py csv`, en paralelo |
| `inyectar_casos_calidad` | solo si el parámetro `casos_calidad` es verdadero |
| `dbt_run_staging` | `dbt run --select staging intermediate` |
| `dbt_test_staging` | pruebas de staging e intermediate; si fallan, marts **no** se actualiza |
| `dbt_run_marts` | `dbt run --select marts` |
| `dbt_test_marts` | pruebas de marts |
| `dbt_docs_generate` | regenera la documentación |

Las credenciales no están en el código: el contenedor lee `source/.env`, `airflow/.env` y el perfil `airflow/dbt_profiles/profiles.yml` usa `env_var()`. Dentro de Docker el DW se alcanza en `host.docker.internal:5433`.

## 8. Justificación de diseño

- **Raw como texto**: la carga nunca falla por un tipo inesperado; el tipado y la detección de errores ocurren en dbt, donde son visibles y probados.
- **Staging e intermediate como vistas**: no duplican datos y reflejan raw al instante, por eso las pruebas detectan datos malos inmediatamente después de la carga.
- **Marts como tablas con PK/FK**: consultas rápidas y la base de datos refuerza la integridad además de las pruebas dbt.
- **Llaves naturales**: las fuentes tienen identificadores estables y no hay historia de cambios (SCD) que gestionar; una llave sustituta agregaría complejidad sin beneficio.
- **Categoría y marca dentro de `dim_producto`**: esquema estrella (no copo de nieve), menos uniones al consultar.
- **`fct_ventas` guarda todos los estados**: permite analizar anulaciones y pendientes; los ingresos filtran `estado = 'COMPLETADA'`.
- **Promociones como bandera `en_promocion`**: hay promociones traslapadas en la misma categoría; una FK a una sola promoción sería ambigua.
- **`monto_devuelto` desde la línea vendida**: el CSV de devoluciones no trae precio; se usa el precio y descuento realmente cobrados.
- **Pruebas en dos niveles**: reglas de calidad en staging (detección temprana) y llaves, relaciones y reglas de negocio en marts.
- **Venv separado en la imagen de Airflow**: Airflow fija versiones de SQLAlchemy incompatibles con pandas 3, psycopg 3 y dbt.

## 9. Manual de implementación

### Prerrequisitos

- Docker Desktop
- Python 3.12
- Git

### 1. PostgreSQL

```powershell
docker run --name sgfood_postgres `
  -e POSTGRES_USER=<usuario> -e POSTGRES_PASSWORD=<password> -e POSTGRES_DB=sgfood_dw `
  -p 5433:5432 -v sgfood_pgdata:/var/lib/postgresql/data -d postgres:16
```

Se usa el puerto 5433 del host porque 5432 puede estar ocupado por un PostgreSQL local.

Crear la base OLTP, cargar la fuente y crear los schemas del DW:

```powershell
docker exec -i sgfood_postgres psql -U <usuario> -d sgfood_dw -c "CREATE DATABASE sgfood_oltp;"
Get-Content Data-20260929\sgfood_oltp.sql | docker exec -i sgfood_postgres psql -U <usuario> -d sgfood_oltp
Get-Content sql\01_schemas.sql | Select-Object -Skip 1 | docker exec -i sgfood_postgres psql -U <usuario> -d sgfood_dw
```

### 2. Entorno Python y credenciales

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
Copy-Item source\.env.example source\.env      # completar usuario y contraseña
python source\test_connection.py
```

Perfil de dbt en `~/.dbt/profiles.yml`:

```yaml
dbt_sgfood:
  target: dev
  outputs:
    dev:
      type: postgres
      host: localhost
      port: 5433
      user: <usuario>
      password: <password>
      dbname: sgfood_dw
      schema: public
      threads: 4
```

### 3. Ejecución manual

```powershell
cd source
python main.py
cd ..\dbt_sgfood
dbt debug
dbt build
dbt docs generate
dbt docs serve
```

### 4. Ejecución con Airflow

```powershell
cd airflow
Copy-Item .env.example .env                    # definir contraseñas de Airflow
docker compose up -d --build
```

1. Abrir http://localhost:8080 e ingresar con `AIRFLOW_ADMIN_USER` / `AIRFLOW_ADMIN_PASSWORD`.
2. Activar el DAG `sgfood_elt` y ejecutarlo con **Trigger DAG**.
3. Para la demostración de calidad: **Trigger DAG w/ config** con `{"casos_calidad": true}`. La tarea `dbt_test_staging` falla y marts conserva los últimos datos válidos. La siguiente corrida normal recarga raw y deja todo limpio.

Detener: `docker compose down`.

### 5. Validación

```powershell
Get-Content sql\03_validacion.sql | docker exec -i sgfood_postgres psql -U <usuario> -d sgfood_dw
Get-Content sql\04_consultas_analiticas.sql | docker exec -i sgfood_postgres psql -U <usuario> -d sgfood_dw
```

## 10. Resultados de validación

| Entidad | raw | staging | marts |
|---|---:|---:|---:|
| venta_detalle → fct_ventas | 3,209 | 3,209 | 3,209 |
| devoluciones → fct_devoluciones | 80 | 80 | 80 |
| inventario_bodega → fct_inventario | 3,840 | 3,840 | 3,840 |
| metas_ventas → fct_metas | 48 | 48 | 48 |
| proveedores_precios → fct_cotizaciones_proveedor | 103 | 103 | 103 |
| producto → dim_producto | 80 | 80 | 80 |
| cliente → dim_cliente | 250 | 250 | 250 |
| sucursal → dim_sucursal | 6 | 6 | 6 |
| proveedores distintos → dim_proveedor | 12 | 12 | 12 |

- Suma de `subtotal` en raw = suma de `monto_venta` en marts = **838,452.07**; unidades **19,174** en ambas capas.
- Ventas por estado: COMPLETADA 1,129, ANULADA 48, PENDIENTE 23.
- 0 huérfanos, 0 duplicados y 0 violaciones de reglas de negocio.
- `dbt build`: 25 modelos y 147 pruebas, todas en PASS.
- DAG `sgfood_elt`: corridas completas en estado *success*.
