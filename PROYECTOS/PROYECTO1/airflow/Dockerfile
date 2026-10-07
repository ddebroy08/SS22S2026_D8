FROM apache/airflow:2.10.5-python3.12

USER root
RUN python -m venv /opt/pipeline_venv \
    && chown -R airflow: /opt/pipeline_venv

USER airflow
COPY requirements-pipeline.txt /tmp/requirements-pipeline.txt
RUN /opt/pipeline_venv/bin/pip install --no-cache-dir -r /tmp/requirements-pipeline.txt
