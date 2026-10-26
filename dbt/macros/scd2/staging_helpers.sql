{#-
  Standard tail of a snapshot staging view (file 18, kampan_hist example):
  hkey first, the projected business + __zdrojovy_system columns, then the
  technical columns. The column list passed as hash_columns is exactly what
  decides a new version - keep it explicit and reviewed.
-#}
{% macro snapshot_staging_columns(hkey, natural_key, hash_columns, source_relation) -%}
    {{ hash_key(natural_key) }}                         as {{ hkey }},
    p.*,
    '{{ source_table_name(source_relation) }}'          as __zdrojova_tabulka_nazev,
    {{ record_hash(hash_columns) }}                     as hash_zaznamu,
    current_timestamp()                                 as __nacteno_ts
{%- endmacro %}
