{#-
  Configs use layer keys (bronze | silver | gold) as `database`.
  They are translated to the real Unity Catalog catalog of the current dbt
  target via var('catalogs_by_target').
-#}
{% macro current_catalogs() -%}
    {%- set by_target = var('catalogs_by_target', {}) -%}
    {%- if target.name not in by_target -%}
        {{ exceptions.raise_compiler_error("No catalogs configured for target '" ~ target.name ~
           "' in var catalogs_by_target (dbt_project.yml)") }}
    {%- endif -%}
    {{ return(by_target[target.name]) }}
{%- endmacro %}


{% macro generate_database_name(custom_database_name=none, node=none) -%}
    {%- set catalogs = current_catalogs() -%}
    {%- if custom_database_name is none -%}
        {{ target.database }}
    {%- elif custom_database_name | trim in catalogs -%}
        {{ catalogs[custom_database_name | trim] }}
    {%- else -%}
        {{ custom_database_name | trim }}
    {%- endif -%}
{%- endmacro %}


{#- Catalog of one layer for the current target, e.g. layer_catalog('silver'). -#}
{% macro layer_catalog(layer) -%}
    {%- set catalogs = current_catalogs() -%}
    {%- if layer not in catalogs -%}
        {{ exceptions.raise_compiler_error("Unknown layer '" ~ layer ~ "'") }}
    {%- endif -%}
    {{ catalogs[layer] }}
{%- endmacro %}
