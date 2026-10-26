{#-
  Source flags arrive as INT 0/1 (KCL), 'A'/'N' or 'ANO'/'NE' strings (KCC).
  The accepted TRUE values are configuration: var('flag_true_values').
  NULL stays NULL (unknown), it is not coerced to FALSE.
-#}
{% macro to_flag(col) -%}
    {%- set values = var('flag_true_values') -%}
    case
        when {{ col }} is null then cast(null as boolean)
        when upper(trim(cast({{ col }} as string))) in (
            {%- for v in values %}'{{ v | upper }}'{% if not loop.last %}, {% endif %}{% endfor -%}
        ) then true
        else false
    end
{%- endmacro %}
