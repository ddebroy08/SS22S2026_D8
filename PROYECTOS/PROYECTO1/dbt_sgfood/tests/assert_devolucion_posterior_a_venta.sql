select
    id_devolucion,
    fecha_venta,
    fecha_devolucion
from {{ ref('int_devoluciones_con_venta') }}
where fecha_devolucion < fecha_venta
