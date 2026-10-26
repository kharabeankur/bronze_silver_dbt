{#-
  ukol_hist - SCD2 history of KCL tasks (CDC, incremental MERGE, delete feed).
  file 14 dbt_Config #9: "incremental model with its own MERGE".
  full_refresh=false protects history: `--full-refresh` instead re-reads the
  complete bronze history and MERGEs it idempotently (no rebuild, no data loss).
-#}
{{ config(
    materialized='incremental',
    incremental_strategy='merge',
    unique_key=['ukol_hkey', 'platnost_od_ts'],
    incremental_predicates=["DBT_INTERNAL_DEST.platnost_do_ts = " ~ scd2_high_date()],
    on_schema_change='append_new_columns',
    full_refresh=false,
    liquid_clustered_by=['ukol_hkey', 'platnost_od_ts'],
    post_hook=["{{ set_cdc_watermark() }}"],
    tags=['pattern_cdc_scd2']
) }}

{{ scd2_incremental(
    staging=ref('stg_kcl__sco_bdt_task'),
    hkey='ukol_hkey',
    batch_mode='watermark',
    deletes=ref('stg_kcl__sco_bdt_task_delete'),
    hash_exclude=['smlouva_hkey']
) }}
