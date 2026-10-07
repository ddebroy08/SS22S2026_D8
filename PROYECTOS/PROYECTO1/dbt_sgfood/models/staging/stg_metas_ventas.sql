with origen as (

    select * from {{ source('raw', 'metas_ventas') }}

)

select 
    trim (periodo) as periodo,
    cast(trim(periodo) || '-01' as date)         as fecha_periodo,
    cast(id_sucursal as integer) as id_sucursal,
    cast(meta_ventas as numeric(14, 2)) as meta_ventas,
    cast(meta_unidades as integer) as meta_unidades,
    cast(_loaded_at as timestamptz) as _loaded_at
from origen