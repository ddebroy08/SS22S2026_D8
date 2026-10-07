select
    fecha_corte,
    id_producto,
    id_sucursal,
    fecha_vencimiento
from {{ ref('stg_inventario_bodega') }}
where fecha_vencimiento < fecha_corte
