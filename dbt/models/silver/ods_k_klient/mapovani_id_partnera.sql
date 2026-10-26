{#- mapovani_id_partnera - current resolved mapping; every party_id in silver is resolved through it (Load_Pattern step 7). -#}
{{ config(
    materialized='incremental',
    incremental_strategy='merge',
    unique_key='mapovani_id_partnera_hkey',
    on_schema_change='append_new_columns',
    liquid_clustered_by=['mapovani_id_partnera_hkey'],
    tags=['pattern_cdc_scd2']
) }}

{{ current_from_cdc_history(ref('mapovani_id_partnera_hist')) }}
