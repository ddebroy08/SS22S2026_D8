with conteos as (
    select 'fct_ventas' as modelo,
           (select count(*) from {{ ref('fct_ventas') }}) as marts,
           (select count(*) from {{ ref('stg_venta_detalle') }}) as origen
    union all
    select 'fct_devoluciones',
           (select count(*) from {{ ref('fct_devoluciones') }}),
           (select count(*) from {{ ref('stg_devoluciones') }})
    union all
    select 'fct_inventario',
           (select count(*) from {{ ref('fct_inventario') }}),
           (select count(*) from {{ ref('stg_inventario_bodega') }})
    union all
    select 'fct_metas',
           (select count(*) from {{ ref('fct_metas') }}),
           (select count(*) from {{ ref('stg_metas_ventas') }})
    union all
    select 'fct_cotizaciones_proveedor',
           (select count(*) from {{ ref('fct_cotizaciones_proveedor') }}),
           (select count(*) from {{ ref('stg_proveedores_precios') }})
    union all
    select 'dim_producto',
           (select count(*) from {{ ref('dim_producto') }}),
           (select count(*) from {{ ref('stg_producto') }})
    union all
    select 'dim_cliente',
           (select count(*) from {{ ref('dim_cliente') }}),
           (select count(*) from {{ ref('stg_cliente') }})
    union all
    select 'dim_sucursal',
           (select count(*) from {{ ref('dim_sucursal') }}),
           (select count(*) from {{ ref('stg_sucursal') }})
)

select *
from conteos
where marts <> origen
