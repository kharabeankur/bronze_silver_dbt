{#-
  Standard silver columns (file 18 "Prehled_klicu"), added at the end of every
  staging view:

    <entity>_hkey             hash of the natural key - identity of the record
    p.*                       business columns + __zdrojovy_system + platnost_od_ts
    __zdrojova_tabulka_nazev  bronze table the row came from (schema.table)
    hash_zaznamu              fingerprint of the business columns
    __nacteno_ts              when the row was written to silver

  Phase 1 only fills hash_zaznamu (the DDL requires it). In phase 2 the same
  column decides when SCD2 creates a new version - so it is computed now,
  exactly as it will be needed later.
-#}
{% macro silver_standard_columns(hkey, natural_key, hash_columns, source_relation) -%}
    {{ hash_key(natural_key) }}                         as {{ hkey }},
    p.*,
    '{{ source_table_name(source_relation) }}'          as __zdrojova_tabulka_nazev,
    {{ record_hash(hash_columns) }}                     as hash_zaznamu,
    current_timestamp()                                 as __nacteno_ts
{%- endmacro %}
