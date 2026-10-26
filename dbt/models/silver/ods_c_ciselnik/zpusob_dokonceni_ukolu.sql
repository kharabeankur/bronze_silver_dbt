{#- Silver ods_c_ciselnik.zpusob_dokonceni_ukolu - current state, rebuilt from bronze on every run (phase 1). -#}
select * from {{ ref('stg_kcl__adt_finishtype') }}
