with origen as (
    select * from {{ source('raw', 'devoluciones')}}
)

select 
    cast(id_devolucion as integer) as id_devolucion,
    cast(fecha as date) as fecha_devolucion,
    cast(id_venta as bigint) as id_venta,
    cast(id_producto as integer) as id_producto,
    cast(cantidad as integer) as cantidad_devuelta,
    trim(motivo) as motivo,
    cast(_loaded_at as timestamptz) as _loaded_at
from origen