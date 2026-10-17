#!/usr/bin/env bash
# Ejecuta un script .sql completo en BigQuery con la CLI `bq`.
# Uso: ./scripts/run_sql.sh sql/00_setup.sql [--nocache]
# Requisitos: gcloud/bq instalados y autenticados (ver docs/SETUP_GCP.md).
set -euo pipefail

FILE="${1:?Uso: $0 archivo.sql [--nocache]}"
CACHE_FLAG="--use_cache=true"
[[ "${2:-}" == "--nocache" ]] && CACHE_FLAG="--use_cache=false"

if grep -q "TU_PROJECT_ID" "$FILE"; then
  echo "ERROR: $FILE aún contiene TU_PROJECT_ID. Reemplázalo con el ID real del proyecto." >&2
  exit 1
fi

bq query --use_legacy_sql=false --location=US "$CACHE_FLAG" < "$FILE"
