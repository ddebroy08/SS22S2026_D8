import os
from datetime import datetime, timedelta

from airflow import DAG
from airflow.models.param import Param
from airflow.operators.bash import BashOperator


SGFOOD_HOME = os.getenv("SGFOOD_HOME", "/opt/sgfood")
SOURCE_DIR = f"{SGFOOD_HOME}/source"
DBT_DIR = f"{SGFOOD_HOME}/dbt_sgfood"
PYTHON = "/opt/pipeline_venv/bin/python"
DBT = "/opt/pipeline_venv/bin/dbt"

default_args = {
    "owner": "grupo8",
    "retries": 1,
    "retry_delay": timedelta(minutes=2),
}


with DAG(
    dag_id="sgfood_elt",
    description="Carga OLTP y CSV a raw, transformación con dbt y pruebas de calidad",
    start_date=datetime(2026, 10, 1),
    schedule="0 6 * * *",
    catchup=False,
    max_active_runs=1,
    default_args=default_args,
    tags=["sgfood", "elt", "dbt"],
    params={
        "casos_calidad": Param(
            False,
            type="boolean",
            description="Inyecta casos_calidad_opcionales.csv en raw para comprobar que las pruebas los detectan",
        ),
    },
) as dag:

    verificar_conexiones = BashOperator(
        task_id="verificar_conexiones",
        bash_command=f"cd {SOURCE_DIR} && {PYTHON} test_connection.py",
        retries=0,
    )

    cargar_oltp_raw = BashOperator(
        task_id="cargar_oltp_raw",
        bash_command=f"cd {SOURCE_DIR} && {PYTHON} main.py oltp",
    )

    cargar_csv_raw = BashOperator(
        task_id="cargar_csv_raw",
        bash_command=f"cd {SOURCE_DIR} && {PYTHON} main.py csv",
    )

    inyectar_casos_calidad = BashOperator(
        task_id="inyectar_casos_calidad",
        bash_command=(
            "{% if params.casos_calidad %}"
            f"cd {SOURCE_DIR} && {PYTHON} casos_calidad.py inyectar"
            "{% else %}"
            "echo 'Corrida normal: no se inyectan casos de calidad'"
            "{% endif %}"
        ),
        retries=0,
    )

    dbt_run_staging = BashOperator(
        task_id="dbt_run_staging",
        bash_command=f"cd {DBT_DIR} && {DBT} run --select staging intermediate",
    )

    dbt_test_staging = BashOperator(
        task_id="dbt_test_staging",
        bash_command=(
            f"cd {DBT_DIR} && {DBT} test --select staging intermediate "
            "--indirect-selection cautious"
        ),
        retries=0,
    )

    dbt_run_marts = BashOperator(
        task_id="dbt_run_marts",
        bash_command=f"cd {DBT_DIR} && {DBT} run --select marts",
    )

    dbt_test_marts = BashOperator(
        task_id="dbt_test_marts",
        bash_command=f"cd {DBT_DIR} && {DBT} test --select marts",
        retries=0,
    )

    dbt_docs_generate = BashOperator(
        task_id="dbt_docs_generate",
        bash_command=f"cd {DBT_DIR} && {DBT} docs generate",
    )

    (
        verificar_conexiones
        >> [cargar_oltp_raw, cargar_csv_raw]
        >> inyectar_casos_calidad
        >> dbt_run_staging
        >> dbt_test_staging
        >> dbt_run_marts
        >> dbt_test_marts
        >> dbt_docs_generate
    )
