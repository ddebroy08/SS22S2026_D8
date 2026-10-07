select
    id_sucursal,
    periodo,
    count(*) as repeticiones
from {{ ref('stg_metas_ventas') }}
group by id_sucursal, periodo
having count(*) > 1
