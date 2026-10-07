with origen as (
    select * from {{ source('raw', 'sucursal')}}
)

select 
    cast(id_sucursal as integer) as id_sucursal,
    trim(nombre) as nombre_sucursal,
    trim(ciudad) as ciudad,
    trim(departamento) as departamento,
    cast(_loaded_at as timestamptz) as _loaded_at

from origen