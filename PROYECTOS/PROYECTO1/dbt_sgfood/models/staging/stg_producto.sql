with origen as (

    select * from {{ source('raw', 'producto') }}

)

select
    cast(id_producto as integer)              as id_producto,
    cast(id_categoria as integer)             as id_categoria,
    cast(id_marca as integer)                 as id_marca,
    upper(trim(sku))                          as sku,
    trim(nombre)                              as nombre_producto,
    trim(unidad_medida)                       as unidad_medida,
    cast(costo_base as numeric(12, 2))        as costo_base,
    cast(precio_lista as numeric(12, 2))      as precio_lista,
    cast(activo as boolean)                   as activo,
    cast(_loaded_at as timestamptz)           as _loaded_at
from origen