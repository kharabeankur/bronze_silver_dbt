{#- Silver ods_c_ciselnik.distribucni_kanal - current state, rebuilt from bronze on every run (phase 1). -#}
select * from {{ ref('stg_kcl__adt_campaign_channel') }}
