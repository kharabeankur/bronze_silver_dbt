{#- Silver ods_c_ciselnik.stav_kontaktu - current state, rebuilt from bronze on every run (phase 1). -#}
select * from {{ ref('stg_kcl__adt_solution_state') }}
