{#- Silver ods_k_klient.analyza_potreb_klienta - current state, rebuilt from bronze on every run (phase 1). -#}
select * from {{ ref('stg_redy__client_needs_analysis') }}
