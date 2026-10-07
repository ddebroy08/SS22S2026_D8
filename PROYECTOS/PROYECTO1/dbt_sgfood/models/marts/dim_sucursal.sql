{{ config(post_hook='alter table {{ this }} add primary key (id_sucursal)') }}

select
    id_sucursal,
    nombre_sucursal,
    ciudad,
    departamento
from {{ ref('stg_sucursal') }}
