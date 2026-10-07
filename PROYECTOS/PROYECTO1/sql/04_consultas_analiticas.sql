-- Base: sgfood_dw. Los ingresos consideran solo ventas COMPLETADA.

-- 1. ¿Cómo evolucionan las ventas, el costo y el margen bruto por mes?
select
    f.anio,
    f.mes,
    f.nombre_mes,
    count(distinct v.id_venta) as ventas,
    sum(v.cantidad) as unidades,
    sum(v.monto_venta) as ingresos,
    sum(v.costo_venta) as costo,
    sum(v.monto_venta - v.costo_venta) as margen_bruto,
    round(100 * sum(v.monto_venta - v.costo_venta) / nullif(sum(v.monto_venta), 0), 2) as margen_pct
from marts.fct_ventas v
join marts.dim_fecha f on f.fecha = v.fecha
where v.estado = 'COMPLETADA'
group by f.anio, f.mes, f.nombre_mes
order by f.anio, f.mes;

-- 2. ¿Qué sucursales cumplen su meta mensual de ventas y de unidades?
with real as (
    select
        date_trunc('month', v.fecha)::date as fecha_periodo,
        v.id_sucursal,
        sum(v.monto_venta) as ventas_reales,
        sum(v.cantidad) as unidades_reales
    from marts.fct_ventas v
    where v.estado = 'COMPLETADA'
    group by 1, 2
)
select
    m.fecha_periodo,
    s.nombre_sucursal,
    m.meta_ventas,
    coalesce(r.ventas_reales, 0) as ventas_reales,
    round(100 * coalesce(r.ventas_reales, 0) / m.meta_ventas, 2) as cumplimiento_ventas_pct,
    m.meta_unidades,
    coalesce(r.unidades_reales, 0) as unidades_reales,
    round(100.0 * coalesce(r.unidades_reales, 0) / m.meta_unidades, 2) as cumplimiento_unidades_pct
from marts.fct_metas m
join marts.dim_sucursal s on s.id_sucursal = m.id_sucursal
left join real r
  on r.fecha_periodo = m.fecha_periodo
 and r.id_sucursal = m.id_sucursal
order by m.fecha_periodo, s.nombre_sucursal;

-- 3. ¿Cuáles son los 10 productos con más ingresos y cuál es su margen?
select
    p.sku,
    p.nombre_producto,
    p.nombre_categoria,
    p.nombre_marca,
    sum(v.cantidad) as unidades,
    sum(v.monto_venta) as ingresos,
    sum(v.monto_venta - v.costo_venta) as margen_bruto
from marts.fct_ventas v
join marts.dim_producto p on p.id_producto = v.id_producto
where v.estado = 'COMPLETADA'
group by p.sku, p.nombre_producto, p.nombre_categoria, p.nombre_marca
order by ingresos desc
limit 10;

-- 4. ¿Qué categorías y marcas aportan más ingresos?
select
    p.nombre_categoria,
    p.nombre_marca,
    sum(v.monto_venta) as ingresos,
    round(100 * sum(v.monto_venta) / sum(sum(v.monto_venta)) over (), 2) as participacion_pct
from marts.fct_ventas v
join marts.dim_producto p on p.id_producto = v.id_producto
where v.estado = 'COMPLETADA'
group by p.nombre_categoria, p.nombre_marca
order by ingresos desc;

-- 5. ¿Cómo se distribuyen las ventas por canal y método de pago?
select
    v.canal,
    v.metodo_pago,
    count(distinct v.id_venta) as ventas,
    sum(v.monto_venta) as ingresos,
    round(sum(v.monto_venta) / count(distinct v.id_venta), 2) as ticket_promedio
from marts.fct_ventas v
where v.estado = 'COMPLETADA'
group by v.canal, v.metodo_pago
order by v.canal, ingresos desc;

-- 6. ¿Las promociones aumentan las unidades vendidas por línea y qué pasa con el margen?
select
    p.nombre_categoria,
    v.en_promocion,
    count(*) as lineas,
    round(avg(v.cantidad), 2) as unidades_promedio_por_linea,
    sum(v.monto_venta) as ingresos,
    round(100 * sum(v.monto_venta - v.costo_venta) / nullif(sum(v.monto_venta), 0), 2) as margen_pct
from marts.fct_ventas v
join marts.dim_producto p on p.id_producto = v.id_producto
where v.estado = 'COMPLETADA'
group by p.nombre_categoria, v.en_promocion
order by p.nombre_categoria, v.en_promocion;

-- 7. ¿Qué productos tienen mayor tasa de devolución y por qué motivo?
with vendidas as (
    select id_producto, sum(cantidad) as unidades_vendidas
    from marts.fct_ventas
    where estado = 'COMPLETADA'
    group by id_producto
),
devueltas as (
    select id_producto, sum(cantidad_devuelta) as unidades_devueltas, sum(monto_devuelto) as monto_devuelto
    from marts.fct_devoluciones
    group by id_producto
)
select
    p.nombre_producto,
    vd.unidades_vendidas,
    d.unidades_devueltas,
    round(100.0 * d.unidades_devueltas / nullif(vd.unidades_vendidas, 0), 2) as tasa_devolucion_pct,
    d.monto_devuelto
from devueltas d
join marts.dim_producto p on p.id_producto = d.id_producto
left join vendidas vd on vd.id_producto = d.id_producto
order by tasa_devolucion_pct desc nulls last
limit 10;

select
    motivo,
    count(*) as devoluciones,
    sum(cantidad_devuelta) as unidades,
    sum(monto_devuelto) as monto_devuelto
from marts.fct_devoluciones
group by motivo
order by monto_devuelto desc;

-- 8. ¿Qué sucursales tienen productos con stock bajo en el último corte?
select
    s.nombre_sucursal,
    i.estado_stock,
    count(*) as productos
from marts.fct_inventario i
join marts.dim_sucursal s on s.id_sucursal = i.id_sucursal
where i.fecha_corte = (select max(fecha_corte) from marts.fct_inventario)
group by s.nombre_sucursal, i.estado_stock
order by s.nombre_sucursal, i.estado_stock;

-- 9. ¿Qué lotes vencen en 30 días o menos según el último corte?
select
    s.nombre_sucursal,
    p.nombre_producto,
    i.lote,
    i.fecha_vencimiento,
    i.dias_para_vencer,
    i.stock_disponible
from marts.fct_inventario i
join marts.dim_sucursal s on s.id_sucursal = i.id_sucursal
join marts.dim_producto p on p.id_producto = i.id_producto
where i.fecha_corte = (select max(fecha_corte) from marts.fct_inventario)
  and i.dias_para_vencer <= 30
order by i.dias_para_vencer, s.nombre_sucursal;

-- 10. ¿Qué proveedor ofrece el menor costo por producto y cuánto difiere del costo base?
select distinct on (c.id_producto)
    p.nombre_producto,
    pr.nombre_proveedor,
    c.costo_proveedor,
    p.costo_base,
    c.costo_proveedor - p.costo_base as diferencia_vs_costo_base,
    c.plazo_dias
from marts.fct_cotizaciones_proveedor c
join marts.dim_producto p on p.id_producto = c.id_producto
join marts.dim_proveedor pr on pr.id_proveedor = c.id_proveedor
order by c.id_producto, c.costo_proveedor, c.plazo_dias;

-- 11. ¿Qué proveedores entregan más rápido y a qué costo promedio?
select
    pr.nombre_proveedor,
    count(*) as productos_ofrecidos,
    round(avg(c.plazo_dias), 1) as plazo_promedio_dias,
    round(avg(c.costo_proveedor), 2) as costo_promedio
from marts.fct_cotizaciones_proveedor c
join marts.dim_proveedor pr on pr.id_proveedor = c.id_proveedor
group by pr.nombre_proveedor
order by plazo_promedio_dias;

-- 12. ¿Qué tipo de cliente y qué departamento generan más ingresos?
select
    c.tipo_cliente,
    c.departamento,
    count(distinct v.id_cliente) as clientes,
    sum(v.monto_venta) as ingresos
from marts.fct_ventas v
join marts.dim_cliente c on c.id_cliente = v.id_cliente
where v.estado = 'COMPLETADA'
group by c.tipo_cliente, c.departamento
order by ingresos desc;

-- 13. ¿Se vende más entre semana o en fin de semana?
select
    f.dia_semana,
    f.nombre_dia,
    f.es_fin_de_semana,
    count(distinct v.id_venta) as ventas,
    sum(v.monto_venta) as ingresos
from marts.fct_ventas v
join marts.dim_fecha f on f.fecha = v.fecha
where v.estado = 'COMPLETADA'
group by f.dia_semana, f.nombre_dia, f.es_fin_de_semana
order by f.dia_semana;

-- 14. ¿Cuánto se deja de facturar por ventas anuladas o pendientes?
select
    estado,
    count(distinct id_venta) as ventas,
    sum(monto_venta) as monto
from marts.fct_ventas
group by estado
order by monto desc;
