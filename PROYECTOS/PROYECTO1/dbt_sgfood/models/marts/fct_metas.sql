{{ config(post_hook=[
    'alter table {{ this }} add primary key (fecha_periodo, id_sucursal)',
    'alter table {{ this }} add foreign key (fecha_periodo) references {{ ref("dim_fecha") }} (fecha)',
    'alter table {{ this }} add foreign key (id_sucursal) references {{ ref("dim_sucursal") }} (id_sucursal)'
]) }}

-- depends_on: {{ ref('dim_fecha') }}, {{ ref('dim_sucursal') }}

select
    fecha_periodo,
    id_sucursal,
    meta_ventas,
    meta_unidades
from {{ ref('stg_metas_ventas') }}
