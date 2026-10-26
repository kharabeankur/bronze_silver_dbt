{#- Silver ods_c_ciselnik.mezinarodni_predvolba - current state, rebuilt from bronze on every run (phase 1). -#}
select * from {{ ref('stg_kcc__dial_international_codes') }}
