with origen as (
    select * from {{ source('raw', 'marca')}}
)

select 
    cast (id_marca as integer) as id_marca,
    trim(nombre) as nombre_marca,
    cast(_loaded_at as timestamptz) as _loaded_at
from origen