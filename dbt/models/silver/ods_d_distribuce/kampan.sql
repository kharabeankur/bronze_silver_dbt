{#- Silver ods_d_distribuce.kampan - current state, rebuilt from bronze on every run (phase 1). -#}
select * from {{ ref('stg_kcl__bdt_campaign_wave') }}
