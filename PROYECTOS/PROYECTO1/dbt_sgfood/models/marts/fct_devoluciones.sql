{{ config(post_hook=[
    'alter table {{ this }} add primary key (id_devolucion)',
    'alter table {{ this }} add foreign key (fecha_devolucion) references {{ ref("dim_fecha") }} (fecha)',
    'alter table {{ this }} add foreign key (id_producto) references {{ ref("dim_producto") }} (id_producto)',
    'alter table {{ this }} add foreign key (id_cliente) references {{ ref("dim_cliente") }} (id_cliente)',
    'alter table {{ this }} add foreign key (id_sucursal) references {{ ref("dim_sucursal") }} (id_sucursal)'
]) }}

-- depends_on: {{ ref('dim_fecha') }}, {{ ref('dim_producto') }}, {{ ref('dim_cliente') }}, {{ ref('dim_sucursal') }}

select
    id_devolucion,
    id_venta,
    fecha_devolucion,
    id_producto,
    id_cliente,
    id_sucursal,
    motivo,
    cantidad_devuelta,
    monto_devuelto
from {{ ref('int_devoluciones_con_venta') }}
