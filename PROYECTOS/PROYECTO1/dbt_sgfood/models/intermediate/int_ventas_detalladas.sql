with detalle as (
    select * from {{ ref('stg_venta_detalle') }}
),

venta as (
    select * from {{ ref('stg_venta') }}
),

producto as (
    select * from {{ ref('int_productos') }}
),

promociones as (
    select * from {{ ref('stg_promociones') }}
)

select
    d.id_detalle,
    d.id_venta,
    v.fecha,
    d.id_producto,
    v.id_cliente,
    v.id_sucursal,
    v.canal,
    v.metodo_pago,
    v.estado,
    exists (
        select 1
        from promociones pr
        where pr.id_categoria = p.id_categoria
          and v.fecha between pr.fecha_inicio and pr.fecha_fin
    ) as en_promocion,
    d.cantidad,
    d.precio_unitario,
    d.descuento,
    d.subtotal as monto_venta,
    cast(d.cantidad * p.costo_base as numeric(14, 2)) as costo_venta
from detalle d
inner join venta v on v.id_venta = d.id_venta
inner join producto p on p.id_producto = d.id_producto
