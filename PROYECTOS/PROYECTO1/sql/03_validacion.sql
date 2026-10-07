-- Base: sgfood_dw

-- 1. Conteo de registros por capa: raw vs staging vs marts
select 'venta_detalle' as entidad,
       (select count(*) from raw.venta_detalle) as raw,
       (select count(*) from staging.stg_venta_detalle) as staging,
       (select count(*) from marts.fct_ventas) as marts
union all
select 'devoluciones',
       (select count(*) from raw.devoluciones),
       (select count(*) from staging.stg_devoluciones),
       (select count(*) from marts.fct_devoluciones)
union all
select 'inventario_bodega',
       (select count(*) from raw.inventario_bodega),
       (select count(*) from staging.stg_inventario_bodega),
       (select count(*) from marts.fct_inventario)
union all
select 'metas_ventas',
       (select count(*) from raw.metas_ventas),
       (select count(*) from staging.stg_metas_ventas),
       (select count(*) from marts.fct_metas)
union all
select 'proveedores_precios',
       (select count(*) from raw.proveedores_precios),
       (select count(*) from staging.stg_proveedores_precios),
       (select count(*) from marts.fct_cotizaciones_proveedor)
union all
select 'producto',
       (select count(*) from raw.producto),
       (select count(*) from staging.stg_producto),
       (select count(*) from marts.dim_producto)
union all
select 'cliente',
       (select count(*) from raw.cliente),
       (select count(*) from staging.stg_cliente),
       (select count(*) from marts.dim_cliente)
union all
select 'sucursal',
       (select count(*) from raw.sucursal),
       (select count(*) from staging.stg_sucursal),
       (select count(*) from marts.dim_sucursal)
union all
select 'proveedor (distintos)',
       (select count(distinct id_proveedor) from raw.proveedores_precios),
       (select count(distinct id_proveedor) from staging.stg_proveedores_precios),
       (select count(*) from marts.dim_proveedor);

-- 2. Conteo de ventas por estado (raw vs marts)
select r.estado,
       r.ventas_raw,
       m.ventas_marts
from (
    select estado, count(*) as ventas_raw
    from raw.venta
    group by estado
) r
left join (
    select estado, count(distinct id_venta) as ventas_marts
    from marts.fct_ventas
    group by estado
) m on m.estado = r.estado
order by r.estado;

-- 3. Cuadre de montos: suma del subtotal en raw vs monto_venta en marts
select
    (select sum(cast(subtotal as numeric)) from raw.venta_detalle) as subtotal_raw,
    (select sum(monto_venta) from marts.fct_ventas) as monto_venta_marts,
    (select sum(cast(cantidad as integer)) from raw.venta_detalle) as unidades_raw,
    (select sum(cantidad) from marts.fct_ventas) as unidades_marts;

-- 4. Integridad referencial de los hechos (todas deben devolver 0)
select 'fct_ventas sin producto' as validacion, count(*) as huerfanos
from marts.fct_ventas f
left join marts.dim_producto d on d.id_producto = f.id_producto
where d.id_producto is null
union all
select 'fct_ventas sin cliente', count(*)
from marts.fct_ventas f
left join marts.dim_cliente d on d.id_cliente = f.id_cliente
where d.id_cliente is null
union all
select 'fct_ventas sin sucursal', count(*)
from marts.fct_ventas f
left join marts.dim_sucursal d on d.id_sucursal = f.id_sucursal
where d.id_sucursal is null
union all
select 'fct_ventas sin fecha', count(*)
from marts.fct_ventas f
left join marts.dim_fecha d on d.fecha = f.fecha
where d.fecha is null
union all
select 'fct_devoluciones sin venta', count(*)
from marts.fct_devoluciones f
where not exists (select 1 from marts.fct_ventas v where v.id_venta = f.id_venta)
union all
select 'fct_inventario sin producto', count(*)
from marts.fct_inventario f
left join marts.dim_producto d on d.id_producto = f.id_producto
where d.id_producto is null
union all
select 'fct_metas sin sucursal', count(*)
from marts.fct_metas f
left join marts.dim_sucursal d on d.id_sucursal = f.id_sucursal
where d.id_sucursal is null
union all
select 'fct_cotizaciones sin proveedor', count(*)
from marts.fct_cotizaciones_proveedor f
left join marts.dim_proveedor d on d.id_proveedor = f.id_proveedor
where d.id_proveedor is null;

-- 5. Unicidad de llaves y nulos (todas deben devolver 0)
select 'fct_ventas id_detalle duplicado' as validacion,
       count(*) - count(distinct id_detalle) as resultado
from marts.fct_ventas
union all
select 'fct_devoluciones id_devolucion duplicado',
       count(*) - count(distinct id_devolucion)
from marts.fct_devoluciones
union all
select 'fct_inventario llave compuesta duplicada',
       count(*) - count(distinct (fecha_corte, id_producto, id_sucursal))
from marts.fct_inventario
union all
select 'dim_producto nulos en llave',
       count(*) filter (where id_producto is null)
from marts.dim_producto
union all
select 'dim_cliente nulos en llave',
       count(*) filter (where id_cliente is null)
from marts.dim_cliente;

-- 6. Reglas de negocio (todas deben devolver 0)
select 'devolucion mayor a lo vendido' as validacion, count(*) as casos
from marts.fct_devoluciones d
join marts.fct_ventas v
  on v.id_venta = d.id_venta
 and v.id_producto = d.id_producto
where d.cantidad_devuelta > v.cantidad
union all
select 'vencimiento anterior al corte', count(*)
from marts.fct_inventario
where dias_para_vencer < 0
union all
select 'stock negativo', count(*)
from marts.fct_inventario
where stock_disponible < 0
union all
select 'descuento fuera de 0 a 1', count(*)
from marts.fct_ventas
where descuento not between 0 and 1;

-- 7. Trazabilidad de la carga raw
select _source, min(_loaded_at) as cargado, count(*) as filas
from (
    select _source, _loaded_at from raw.venta
    union all select _source, _loaded_at from raw.venta_detalle
    union all select _source, _loaded_at from raw.producto
    union all select _source, _loaded_at from raw.cliente
    union all select _source, _loaded_at from raw.sucursal
    union all select _source, _loaded_at from raw.categoria
    union all select _source, _loaded_at from raw.marca
    union all select _source, _loaded_at from raw.inventario_bodega
    union all select _source, _loaded_at from raw.metas_ventas
    union all select _source, _loaded_at from raw.promociones
    union all select _source, _loaded_at from raw.proveedores_precios
    union all select _source, _loaded_at from raw.devoluciones
) t
group by _source
order by _source;
