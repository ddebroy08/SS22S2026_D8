with devoluciones as (
    select * from {{ ref('stg_devoluciones') }}
),

venta as (
    select * from {{ ref('stg_venta') }}
),

detalle as (
    select * from {{ ref('stg_venta_detalle') }}
)

select
    dv.id_devolucion,
    dv.id_venta,
    dv.fecha_devolucion,
    dv.id_producto,
    v.id_cliente,
    v.id_sucursal,
    v.fecha as fecha_venta,
    dv.motivo,
    dv.cantidad_devuelta,
    d.cantidad as cantidad_vendida,
    d.precio_unitario,
    d.descuento,
    cast(d.precio_unitario * (1 - d.descuento) * dv.cantidad_devuelta as numeric(14, 2)) as monto_devuelto
from devoluciones dv
inner join venta v on v.id_venta = dv.id_venta
left join detalle d
    on d.id_venta = dv.id_venta
   and d.id_producto = dv.id_producto
