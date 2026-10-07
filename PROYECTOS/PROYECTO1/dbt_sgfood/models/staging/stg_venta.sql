with origen as (
    select * from {{ source('raw', 'venta')}}
)


select 
    cast(id_venta as bigint) as id_venta, 
    cast(fecha as date) as fecha,
    cast(id_cliente as integer) as id_cliente, 
    cast(id_sucursal as integer) as id_sucursal,
    trim(canal) as canal,
    trim(metodo_pago) as metodo_pago,
    trim(estado) as estado,
    cast(_loaded_at as timestamptz) as _loaded_at
from origen