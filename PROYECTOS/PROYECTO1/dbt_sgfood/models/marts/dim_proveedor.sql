{{ config(post_hook='alter table {{ this }} add primary key (id_proveedor)') }}

select distinct
    id_proveedor,
    nombre_proveedor
from {{ ref('stg_proveedores_precios') }}
