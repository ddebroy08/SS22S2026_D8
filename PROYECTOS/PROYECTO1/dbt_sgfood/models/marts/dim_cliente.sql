{{ config(post_hook='alter table {{ this }} add primary key (id_cliente)') }}

select
    id_cliente,
    nit,
    nombre_cliente,
    tipo_cliente,
    municipio,
    departamento,
    fecha_alta
from {{ ref('stg_cliente') }}
