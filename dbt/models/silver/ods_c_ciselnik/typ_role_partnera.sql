{#- Silver ods_c_ciselnik.typ_role_partnera - current state, rebuilt from bronze on every run (phase 1). -#}
select * from {{ ref('stg_kcc__typ_role') }}
