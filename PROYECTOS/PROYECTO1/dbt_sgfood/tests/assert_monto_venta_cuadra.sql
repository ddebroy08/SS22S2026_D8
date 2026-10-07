select
    id_detalle,
    cantidad,
    precio_unitario,
    descuento,
    monto_venta
from {{ ref('fct_ventas') }}
where abs(monto_venta - round(cantidad * precio_unitario * (1 - descuento), 2)) > 0.01
