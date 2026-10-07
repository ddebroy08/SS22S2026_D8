{{ config(post_hook=[
    'alter table {{ this }} add primary key (id_detalle)',
    'alter table {{ this }} add foreign key (fecha) references {{ ref("dim_fecha") }} (fecha)',
    'alter table {{ this }} add foreign key (id_producto) references {{ ref("dim_producto") }} (id_producto)',
    'alter table {{ this }} add foreign key (id_cliente) references {{ ref("dim_cliente") }} (id_cliente)',
    'alter table {{ this }} add foreign key (id_sucursal) references {{ ref("dim_sucursal") }} (id_sucursal)'
]) }}

-- depends_on: {{ ref('dim_fecha') }}, {{ ref('dim_producto') }}, {{ ref('dim_cliente') }}, {{ ref('dim_sucursal') }}

select
    id_detalle,
    id_venta,
    fecha,
    id_producto,
    id_cliente,
    id_sucursal,
    canal,
    metodo_pago,
    estado,
    en_promocion,
    cantidad,
    precio_unitario,
    descuento,
    monto_venta,
    costo_venta
from {{ ref('int_ventas_detalladas') }}
