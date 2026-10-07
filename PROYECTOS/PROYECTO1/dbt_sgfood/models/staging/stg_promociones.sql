with origen as (
    select * from {{ source('raw', 'promociones') }}
)

select 
    cast(id_promocion as integer) as id_promocion, 
    trim(nombre) as nombre_promocion,
    cast(fecha_inicio as date) as fecha_inicio,
    cast(fecha_fin as date) as fecha_fin,
    cast(id_categoria as integer) as id_categoria,
    cast(porcentaje_descuento as numeric(5, 2)) as porcentaje_descuento,
    cast(_loaded_at as timestamptz) as _loaded_at
from origen
