{#- Silver ods_d_distribuce.ukol - current state, rebuilt from bronze on every run (phase 1). -#}
select * from {{ ref('stg_kcl__sco_bdt_task') }}
