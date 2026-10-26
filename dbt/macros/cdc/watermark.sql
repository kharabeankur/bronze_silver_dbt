{#-
  ===========================================================================
  CDC watermarks (Load_Pattern step 1: "filter bronze on __load_timestamp
  greater than the last watermark").

  Window per run:   (low, high]
    low  = last committed high watermark of this model - overlap minutes
           (or cdc_low_watermark_default on first run / --full-refresh)
    high = run_started_at - constant for the whole dbt invocation, so the
           value the model reads is exactly the value the post-hook commits.
  The post-hook set_cdc_watermark() runs only after a successful MERGE;
  a failed run leaves the watermark untouched and the retry re-reads the same
  window. The overlap absorbs clock skew and late commits - re-reading is
  safe because the SCD2 MERGE is idempotent.
  ===========================================================================
-#}

{#- The one framework table: <silver catalog>.<staging schema>.cdc_watermark -#}
{% macro cdc_watermark_relation() -%}
    {{ layer_catalog('silver') }}.{{ generate_schema_name(var('staging_schema')) }}.cdc_watermark
{%- endmacro %}


{#- on-run-start: create the schema and the watermark table if missing (idempotent). -#}
{% macro ensure_cdc_watermark_table() -%}
    {%- if not execute -%}{{ return('select 1') }}{%- endif -%}
    {%- do run_query("create schema if not exists " ~ layer_catalog('silver') ~ "." ~ generate_schema_name(var('staging_schema'))) -%}
    {%- do run_query("create table if not exists " ~ cdc_watermark_relation() ~ " (
            model_name        string    not null comment 'schema.table of the incremental model',
            high_watermark_ts timestamp not null comment 'Upper bound of the last successfully processed CDC window',
            invocation_id     string    not null,
            environment       string    not null,
            updated_at        timestamp not null
        ) using delta
        comment 'CDC watermarks of incremental silver models (Load_Pattern step 1).'") -%}
    {{ return('select 1') }}
{%- endmacro %}


{% macro cdc_model_key() -%}
    {{ (this.schema ~ '.' ~ this.identifier) | lower }}
{%- endmacro %}


{% macro cdc_high_watermark() -%}
    to_timestamp('{{ run_started_at.strftime("%Y-%m-%d %H:%M:%S.%f") }}')
{%- endmacro %}


{% macro cdc_low_watermark() -%}
    {%- set default_expr = "to_timestamp('" ~ var('cdc_low_watermark_default') ~ "')" -%}
    {%- if not execute or not is_incremental() or flags.FULL_REFRESH -%}
        {{ return(default_expr) }}
    {%- endif -%}
    {%- set query -%}
        select cast(max(high_watermark_ts) as string) as wm
        from {{ cdc_watermark_relation() }}
        where model_name = '{{ cdc_model_key() }}'
    {%- endset -%}
    {%- set result = run_query(query) -%}
    {%- set value = result.columns[0].values()[0] if result is not none and result.rows | length > 0 else none -%}
    {%- if value is none -%}
        {{ log("No watermark for " ~ cdc_model_key() ~ " - reading full bronze history", info=true) }}
        {{ return(default_expr) }}
    {%- endif -%}
    {{ return("(to_timestamp('" ~ value ~ "') - interval " ~ var('cdc_watermark_overlap_minutes') ~ " minutes)") }}
{%- endmacro %}


{#- Predicate selecting the current CDC window from a staging relation. -#}
{% macro cdc_window_predicate(alias=none) -%}
    {%- set col = (alias ~ '.' if alias else '') ~ '_stg_load_ts' -%}
    {{ col }} > {{ cdc_low_watermark() }} and {{ col }} <= {{ cdc_high_watermark() }}
{%- endmacro %}


{#- post_hook: commit the high watermark after a successful run. -#}
{% macro set_cdc_watermark() -%}
    merge into {{ cdc_watermark_relation() }} as t
    using (
        select
            '{{ cdc_model_key() }}'        as model_name,
            {{ cdc_high_watermark() }}     as high_watermark_ts,
            '{{ invocation_id }}'          as invocation_id,
            '{{ target.name }}'            as environment,
            current_timestamp()            as updated_at
    ) as s
    on t.model_name = s.model_name
    when matched then update set *
    when not matched then insert *
{%- endmacro %}
