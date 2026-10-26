{#- Silver ods_c_ciselnik.stav_smlouvy - current state, rebuilt from bronze on every run (phase 1). -#}
select * from {{ ref('stg_kcc__stav_poj_sml') }}
