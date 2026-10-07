with origen as (
    select * from {{ source('raw', 'venta_detalle')}}
)

select 
    cast(id_detalle as bigint) as id_detalle,
    cast(id_venta as bigint) as id_venta,
    cast(id_producto as integer) as id_producto,
    cast(cantidad as integer) as cantidad,
    cast(precio_unitario as numeric(12, 2)) as precio_unitario,
    cast(descuento as numeric(5, 4)) as descuento,
    cast(subtotal as numeric(14, 2)) as subtotal,
    cast(_loaded_at as timestamptz) as _loaded_at
from origen
