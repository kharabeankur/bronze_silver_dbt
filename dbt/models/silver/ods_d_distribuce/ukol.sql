{#- ukol - current state (open versions of ukol_hist), MERGE on the hkey (file 18 "smlouva" pattern). -#}
{{ config(
    materialized='incremental',
    incremental_strategy='merge',
    unique_key='ukol_hkey',
    on_schema_change='append_new_columns',
    liquid_clustered_by=['ukol_hkey'],
    tags=['pattern_cdc_scd2']
) }}

{{ current_from_cdc_history(ref('ukol_hist')) }}
