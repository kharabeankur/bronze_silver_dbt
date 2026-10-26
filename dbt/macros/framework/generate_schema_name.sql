{#-
  Schemas are used exactly as configured (ods_c_ciselnik, ods_d_distribuce ...),
  because the Blueprint fixes schema names and derives access groups from them.
  dbt's default "<target_schema>_<custom>" concatenation is therefore disabled.
  An optional var('schema_prefix') supports isolated developer schemas in dev;
  the 22-character limit (Blueprint 4.1.2) is enforced at compile time.
-#}
{% macro generate_schema_name(custom_schema_name=none, node=none) -%}
    {%- set base = (custom_schema_name | trim) if custom_schema_name is not none else target.schema -%}
    {%- set name = (var('schema_prefix', '') ~ base) | lower -%}
    {%- if name | length > 22 -%}
        {{ exceptions.raise_compiler_error(
            "Schema name '" ~ name ~ "' exceeds 22 characters (Blueprint 4.1.2 access-group limit)") }}
    {%- endif -%}
    {{ name }}
{%- endmacro %}
