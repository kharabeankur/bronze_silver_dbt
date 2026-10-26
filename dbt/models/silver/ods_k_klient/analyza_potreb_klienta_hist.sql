{#- analyza_potreb_klienta_hist - SCD2 history of REDy client needs analyses (Kafka CDC). -#}
{{ config(
    materialized='incremental',
    incremental_strategy='merge',
    unique_key=['analyza_potreb_klienta_hkey', 'platnost_od_ts'],
    incremental_predicates=["DBT_INTERNAL_DEST.platnost_do_ts = " ~ scd2_high_date()],
    on_schema_change='append_new_columns',
    full_refresh=false,
    liquid_clustered_by=['analyza_potreb_klienta_hkey', 'platnost_od_ts'],
    post_hook=["{{ set_cdc_watermark() }}"],
    tags=['pattern_cdc_scd2']
) }}

{{ scd2_incremental(
    staging=ref('stg_redy__client_needs_analysis'),
    hkey='analyza_potreb_klienta_hkey',
    batch_mode='watermark'
) }}
