with producto as (
    select * from {{ ref('stg_producto') }}
),

categoria as (
    select * from {{ ref('stg_categoria') }}
),

marca as (
    select * from {{ ref('stg_marca') }}
)

select
    p.id_producto,
    p.sku,
    p.nombre_producto,
    p.unidad_medida,
    p.costo_base,
    p.precio_lista,
    p.activo,
    p.id_categoria,
    c.nombre_categoria,
    p.id_marca,
    m.nombre_marca
from producto p
left join categoria c on c.id_categoria = p.id_categoria
left join marca m on m.id_marca = p.id_marca
