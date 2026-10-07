{{ config(post_hook=[
    'alter table {{ this }} add primary key (fecha_corte, id_producto, id_sucursal)',
    'alter table {{ this }} add foreign key (fecha_corte) references {{ ref("dim_fecha") }} (fecha)',
    'alter table {{ this }} add foreign key (id_producto) references {{ ref("dim_producto") }} (id_producto)',
    'alter table {{ this }} add foreign key (id_sucursal) references {{ ref("dim_sucursal") }} (id_sucursal)'
]) }}

-- depends_on: {{ ref('dim_fecha') }}, {{ ref('dim_producto') }}, {{ ref('dim_sucursal') }}

select
    fecha_corte,
    id_producto,
    id_sucursal,
    lote,
    fecha_vencimiento,
    fecha_vencimiento - fecha_corte as dias_para_vencer,
    case
        when stock_disponible < stock_minimo then 'BAJO'
        when stock_disponible > stock_maximo then 'EXCEDENTE'
        else 'OPTIMO'
    end as estado_stock,
    stock_disponible,
    stock_minimo,
    stock_maximo
from {{ ref('stg_inventario_bodega') }}
