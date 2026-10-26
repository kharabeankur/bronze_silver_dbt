{#-
  Current-state tables (<entity>) derived from history (<entity>_hist).
  The current table always equals the open versions of the history
  (Load_Pattern step 15 / check 3); the test scd2_current_matches_history
  verifies it after every run.
-#}

{#- For snapshot-based entities: small tables, full rewrite (file 18 "kampan"). -#}
{% macro current_from_snapshot(history) -%}
select * except (verze_id, platnost_do_ts, __dbt_updated_at)
from {{ history }}
where platnost_do_ts = {{ scd2_high_date() }}
{%- endmacro %}


{#-
  For CDC entities: incremental MERGE on the hkey (file 18 "smlouva"), reading
  only versions written since the last run of this model.
-#}
{% macro current_from_cdc_history(history) -%}
select * except (verze_id, platnost_do_ts)
from {{ history }}
where platnost_do_ts = {{ scd2_high_date() }}
{%- if is_incremental() %}
  and __nacteno_ts > (
        select coalesce(max(__nacteno_ts), to_timestamp('{{ var("cdc_low_watermark_default") }}'))
        from {{ this }}
  )
{%- endif %}
{%- endmacro %}
