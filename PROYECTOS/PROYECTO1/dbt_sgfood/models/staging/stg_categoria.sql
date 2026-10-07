with origen as (

    select * from {{ source('raw', 'categoria') }}

)

select 
    cast(id_categoria as integer) as id_categoria,
    trim(nombre) as nombre_categoria,
    cast(_loaded_at as timestamptz) as _loaded_at
from origen

