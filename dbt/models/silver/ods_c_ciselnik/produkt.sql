{#- Silver ods_c_ciselnik.produkt - current state, rebuilt from bronze on every run (phase 1). -#}
select * from {{ ref('stg_kcc__produkt') }}
