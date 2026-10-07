-- Base: sgfood_dw
-- Las tablas de marts las crea dbt (dbt run). Este script refleja la misma estructura,
-- tipos, llaves primarias y foráneas que quedan en PostgreSQL.

CREATE SCHEMA IF NOT EXISTS raw;
CREATE SCHEMA IF NOT EXISTS staging;
CREATE SCHEMA IF NOT EXISTS intermediate;
CREATE SCHEMA IF NOT EXISTS marts;

-- =====================================================================
-- RAW: copia fiel de las fuentes, todas las columnas como texto
-- =====================================================================

CREATE TABLE IF NOT EXISTS raw.sucursal (
    id_sucursal text, nombre text, ciudad text, departamento text,
    _loaded_at text, _source text
);

CREATE TABLE IF NOT EXISTS raw.categoria (
    id_categoria text, nombre text,
    _loaded_at text, _source text
);

CREATE TABLE IF NOT EXISTS raw.marca (
    id_marca text, nombre text,
    _loaded_at text, _source text
);

CREATE TABLE IF NOT EXISTS raw.producto (
    id_producto text, sku text, nombre text, id_categoria text, id_marca text,
    unidad_medida text, costo_base text, precio_lista text, activo text,
    _loaded_at text, _source text
);

CREATE TABLE IF NOT EXISTS raw.cliente (
    id_cliente text, nit text, nombre text, tipo_cliente text, municipio text,
    departamento text, fecha_alta text,
    _loaded_at text, _source text
);

CREATE TABLE IF NOT EXISTS raw.venta (
    id_venta text, fecha text, id_cliente text, id_sucursal text, canal text,
    metodo_pago text, estado text,
    _loaded_at text, _source text
);

CREATE TABLE IF NOT EXISTS raw.venta_detalle (
    id_detalle text, id_venta text, id_producto text, cantidad text,
    precio_unitario text, descuento text, subtotal text,
    _loaded_at text, _source text
);

CREATE TABLE IF NOT EXISTS raw.inventario_bodega (
    fecha_corte text, id_sucursal text, id_producto text, stock_disponible text,
    stock_minimo text, stock_maximo text, lote text, fecha_vencimiento text,
    _loaded_at text, _source text
);

CREATE TABLE IF NOT EXISTS raw.metas_ventas (
    periodo text, id_sucursal text, meta_ventas text, meta_unidades text,
    _loaded_at text, _source text
);

CREATE TABLE IF NOT EXISTS raw.promociones (
    id_promocion text, nombre text, fecha_inicio text, fecha_fin text,
    id_categoria text, porcentaje_descuento text,
    _loaded_at text, _source text
);

CREATE TABLE IF NOT EXISTS raw.proveedores_precios (
    id_proveedor text, proveedor text, id_producto text, costo_proveedor text,
    plazo_dias text, fecha_vigencia text,
    _loaded_at text, _source text
);

CREATE TABLE IF NOT EXISTS raw.devoluciones (
    id_devolucion text, fecha text, id_venta text, id_producto text,
    cantidad text, motivo text,
    _loaded_at text, _source text
);

-- =====================================================================
-- MARTS: dimensiones
-- =====================================================================

CREATE TABLE marts.dim_fecha (
    fecha             date PRIMARY KEY,
    anio              integer,
    trimestre         integer,
    mes               integer,
    nombre_mes        text,
    semana_anio       integer,
    dia               integer,
    dia_semana        integer,
    nombre_dia        text,
    es_fin_de_semana  boolean
);

CREATE TABLE marts.dim_producto (
    id_producto       integer PRIMARY KEY,
    sku               text,
    nombre_producto   text,
    unidad_medida     text,
    costo_base        numeric(12,2),
    precio_lista      numeric(12,2),
    activo            boolean,
    id_categoria      integer,
    nombre_categoria  text,
    nombre_marca      text
);

CREATE TABLE marts.dim_cliente (
    id_cliente        integer PRIMARY KEY,
    nit               text,
    nombre_cliente    text,
    tipo_cliente      text,
    municipio         text,
    departamento      text,
    fecha_alta        date
);

CREATE TABLE marts.dim_sucursal (
    id_sucursal       integer PRIMARY KEY,
    nombre_sucursal   text,
    ciudad            text,
    departamento      text
);

CREATE TABLE marts.dim_proveedor (
    id_proveedor      integer PRIMARY KEY,
    nombre_proveedor  text
);

-- =====================================================================
-- MARTS: hechos
-- =====================================================================

CREATE TABLE marts.fct_ventas (
    id_detalle        bigint PRIMARY KEY,
    id_venta          bigint,
    fecha             date    REFERENCES marts.dim_fecha (fecha),
    id_producto       integer REFERENCES marts.dim_producto (id_producto),
    id_cliente        integer REFERENCES marts.dim_cliente (id_cliente),
    id_sucursal       integer REFERENCES marts.dim_sucursal (id_sucursal),
    canal             text,
    metodo_pago       text,
    estado            text,
    en_promocion      boolean,
    cantidad          integer,
    precio_unitario   numeric(12,2),
    descuento         numeric(5,4),
    monto_venta       numeric(14,2),
    costo_venta       numeric(14,2)
);

CREATE TABLE marts.fct_devoluciones (
    id_devolucion     integer PRIMARY KEY,
    id_venta          bigint,
    fecha_devolucion  date    REFERENCES marts.dim_fecha (fecha),
    id_producto       integer REFERENCES marts.dim_producto (id_producto),
    id_cliente        integer REFERENCES marts.dim_cliente (id_cliente),
    id_sucursal       integer REFERENCES marts.dim_sucursal (id_sucursal),
    motivo            text,
    cantidad_devuelta integer,
    monto_devuelto    numeric(14,2)
);

CREATE TABLE marts.fct_inventario (
    fecha_corte       date    REFERENCES marts.dim_fecha (fecha),
    id_producto       integer REFERENCES marts.dim_producto (id_producto),
    id_sucursal       integer REFERENCES marts.dim_sucursal (id_sucursal),
    lote              text,
    fecha_vencimiento date,
    dias_para_vencer  integer,
    estado_stock      text,
    stock_disponible  integer,
    stock_minimo      integer,
    stock_maximo      integer,
    PRIMARY KEY (fecha_corte, id_producto, id_sucursal)
);

CREATE TABLE marts.fct_metas (
    fecha_periodo     date    REFERENCES marts.dim_fecha (fecha),
    id_sucursal       integer REFERENCES marts.dim_sucursal (id_sucursal),
    meta_ventas       numeric(14,2),
    meta_unidades     integer,
    PRIMARY KEY (fecha_periodo, id_sucursal)
);

CREATE TABLE marts.fct_cotizaciones_proveedor (
    id_proveedor      integer REFERENCES marts.dim_proveedor (id_proveedor),
    id_producto       integer REFERENCES marts.dim_producto (id_producto),
    fecha_vigencia    date    REFERENCES marts.dim_fecha (fecha),
    costo_proveedor   numeric(12,2),
    plazo_dias        integer,
    PRIMARY KEY (id_proveedor, id_producto)
);
