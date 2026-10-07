{{ config(post_hook='alter table {{ this }} add primary key (fecha)') }}

with fechas as (
    select cast(d as date) as fecha
    from generate_series(
        cast('2026-01-01' as date),
        cast('2026-12-31' as date),
        interval '1 day'
    ) as d
)

select
    fecha,
    cast(extract(year from fecha) as integer) as anio,
    cast(extract(quarter from fecha) as integer) as trimestre,
    cast(extract(month from fecha) as integer) as mes,
    case extract(month from fecha)
        when 1 then 'Enero'
        when 2 then 'Febrero'
        when 3 then 'Marzo'
        when 4 then 'Abril'
        when 5 then 'Mayo'
        when 6 then 'Junio'
        when 7 then 'Julio'
        when 8 then 'Agosto'
        when 9 then 'Septiembre'
        when 10 then 'Octubre'
        when 11 then 'Noviembre'
        when 12 then 'Diciembre'
    end as nombre_mes,
    cast(extract(week from fecha) as integer) as semana_anio,
    cast(extract(day from fecha) as integer) as dia,
    cast(extract(isodow from fecha) as integer) as dia_semana,
    case extract(isodow from fecha)
        when 1 then 'Lunes'
        when 2 then 'Martes'
        when 3 then 'Miércoles'
        when 4 then 'Jueves'
        when 5 then 'Viernes'
        when 6 then 'Sábado'
        when 7 then 'Domingo'
    end as nombre_dia,
    extract(isodow from fecha) in (6, 7) as es_fin_de_semana
from fechas
