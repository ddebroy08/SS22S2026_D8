{% test unique_combinacion(model, columnas) %}

select
    {{ columnas | join(', ') }},
    count(*) as repeticiones
from {{ model }}
group by {{ columnas | join(', ') }}
having count(*) > 1

{% endtest %}
