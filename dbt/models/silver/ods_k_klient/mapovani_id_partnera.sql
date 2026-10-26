{#- Silver ods_k_klient.mapovani_id_partnera - current state, rebuilt from bronze on every run (phase 1). -#}
select * from {{ ref('stg_ccd__party_id_mapping') }}
