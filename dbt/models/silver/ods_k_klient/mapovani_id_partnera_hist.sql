{#-
  mapovani_id_partnera_hist - history of the resolved party-id mapping.
  batch_mode='full': the staging view is the complete resolved mapping, because
  one new CCD merge event can re-point many older identifiers (chain shortening).
  Only real changes are written.
-#}
{{ config(
    materialized='incremental',
    incremental_strategy='merge',
    unique_key=['mapovani_id_partnera_hkey', 'platnost_od_ts'],
    incremental_predicates=["DBT_INTERNAL_DEST.platnost_do_ts = " ~ scd2_high_date()],
    on_schema_change='append_new_columns',
    full_refresh=false,
    liquid_clustered_by=['mapovani_id_partnera_hkey', 'platnost_od_ts'],
    tags=['pattern_cdc_scd2']
) }}

{{ scd2_incremental(
    staging=ref('stg_ccd__party_id_mapping'),
    hkey='mapovani_id_partnera_hkey',
    batch_mode='full'
) }}
