{#- analyza_potreb_klienta - current state of the REDy analyses. -#}
{{ config(
    materialized='incremental',
    incremental_strategy='merge',
    unique_key='analyza_potreb_klienta_hkey',
    on_schema_change='append_new_columns',
    liquid_clustered_by=['analyza_potreb_klienta_hkey'],
    tags=['pattern_cdc_scd2']
) }}

{{ current_from_cdc_history(ref('analyza_potreb_klienta_hist')) }}
