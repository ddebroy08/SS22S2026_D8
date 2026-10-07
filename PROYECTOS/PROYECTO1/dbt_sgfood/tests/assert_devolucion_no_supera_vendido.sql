select
    d.id_devolucion,
    d.id_venta,
    d.id_producto,
    d.cantidad_devuelta,
    coalesce(v.cantidad, 0) as cantidad_vendida
from {{ ref('fct_devoluciones') }} d
left join {{ ref('fct_ventas') }} v
    on v.id_venta = d.id_venta
   and v.id_producto = d.id_producto
where d.cantidad_devuelta > coalesce(v.cantidad, 0)
