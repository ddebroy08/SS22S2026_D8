{{ config(post_hook='alter table {{ this }} add primary key (id_producto)') }}

select
    id_producto,
    sku,
    nombre_producto,
    unidad_medida,
    costo_base,
    precio_lista,
    activo,
    id_categoria,
    nombre_categoria,
    nombre_marca
from {{ ref('int_productos') }}
