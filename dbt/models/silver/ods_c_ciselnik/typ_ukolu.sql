{#- Silver ods_c_ciselnik.typ_ukolu - current state, rebuilt from bronze on every run (phase 1). -#}
select * from {{ ref('stg_kcl__adt_tasktype') }}
