{#- "schema.table" of a bronze source relation, env independent (silver __zdrojova_tabulka_nazev). -#}
{% macro source_table_name(relation) -%}
    {{ (relation.schema ~ '.' ~ relation.identifier) | lower }}
{%- endmacro %}


{#-
  Latest complete load of a full-snapshot source (KCL codelists, KCC files).
  Bronze is append-only, so a full-snapshot source holds every load; only the
  newest one represents the current state. The batch column is declared per
  source table in its YAML meta (batch_column), default __load_timestamp.
  For file loads use __file_path, so one file = one batch.
-#}
{% macro select_latest_batch(relation, batch_column=none) -%}
    {%- set col = batch_column or source_meta(relation, 'batch_column', '__load_timestamp') -%}
    select *
    from {{ relation }}
    where {{ col }} = (
        select max_by({{ col }}, __load_timestamp) from {{ relation }}
    )
{%- endmacro %}


{#- Read a meta key declared on a source table (falls back to source level, then default). -#}
{% macro source_meta(relation, key, default=none) -%}
    {%- if not execute -%}{{ return(default) }}{%- endif -%}
    {%- for node in graph.sources.values() -%}
        {%- if node.database == relation.database and node.schema == relation.schema
              and node.identifier == relation.identifier -%}
            {%- set table_meta = node.meta or {} -%}
            {%- set source_level = node.source_meta or {} -%}
            {{ return(table_meta.get(key, source_level.get(key, default))) }}
        {%- endif -%}
    {%- endfor -%}
    {{ return(default) }}
{%- endmacro %}


{#-
  Payload validation policy for Kafka bronze tables (file 11 Payload_Validation).
  pass   - keep every message (default; invalid rows are surfaced by source tests)
  filter - drop rows where __message_valid_flag is false
-#}
{% macro message_policy_predicate(source_name) -%}
    {%- set by_source = var('invalid_message_policy_by_source', {}) -%}
    {%- set policy = by_source.get(source_name, var('invalid_message_policy', 'pass')) -%}
    {%- if policy == 'filter' -%}
        coalesce(__message_valid_flag, false)
    {%- elif policy == 'pass' -%}
        true
    {%- else -%}
        {{ exceptions.raise_compiler_error("Unknown invalid_message_policy '" ~ policy ~ "'") }}
    {%- endif -%}
{%- endmacro %}
