with origen as (
    select * from {{ source('raw', 'proveedores_precios')}}
)

select
    cast(id_proveedor as integer) as id_proveedor,
    trim(proveedor) as nombre_proveedor,
    cast(id_producto as integer) as id_producto,
    cast(costo_proveedor as numeric(12, 2)) as costo_proveedor,
    cast(plazo_dias as integer) as plazo_dias,
    cast(fecha_vigencia as date) as fecha_vigencia,
    cast(_loaded_at as timestamptz) as _loaded_at
from origen