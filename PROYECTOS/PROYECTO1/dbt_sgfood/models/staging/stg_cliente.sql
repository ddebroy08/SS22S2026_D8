with origen as (
    select * from {{ source('raw', 'cliente') }}
)

select 
    cast(id_cliente as integer) as id_cliente,
    trim(nit) as nit,
    trim(nombre) as nombre_cliente,
    trim(tipo_cliente) as tipo_cliente,
    trim(municipio) as municipio,
    trim(departamento) as departamento,
    cast(fecha_alta as date) as fecha_alta,
    cast(_loaded_at as timestamptz) as _loaded_at

from origen