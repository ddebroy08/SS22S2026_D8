select
    fecha_corte,
    id_sucursal,
    id_producto,
    count(*) as repeticiones
from {{ ref('stg_inventario_bodega') }}
group by fecha_corte, id_sucursal, id_producto
having count(*) > 1