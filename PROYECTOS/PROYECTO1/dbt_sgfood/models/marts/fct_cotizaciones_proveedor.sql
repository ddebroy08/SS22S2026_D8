{{ config(post_hook=[
    'alter table {{ this }} add primary key (id_proveedor, id_producto)',
    'alter table {{ this }} add foreign key (fecha_vigencia) references {{ ref("dim_fecha") }} (fecha)',
    'alter table {{ this }} add foreign key (id_proveedor) references {{ ref("dim_proveedor") }} (id_proveedor)',
    'alter table {{ this }} add foreign key (id_producto) references {{ ref("dim_producto") }} (id_producto)'
]) }}

-- depends_on: {{ ref('dim_fecha') }}, {{ ref('dim_proveedor') }}, {{ ref('dim_producto') }}

select
    id_proveedor,
    id_producto,
    fecha_vigencia,
    costo_proveedor,
    plazo_dias
from {{ ref('stg_proveedores_precios') }}
