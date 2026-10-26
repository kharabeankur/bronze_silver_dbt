{#- Silver ods_c_ciselnik.podtyp_ukolu - current state, rebuilt from bronze on every run (phase 1). -#}
select * from {{ ref('stg_kcl__adt_tasksubtype') }}
