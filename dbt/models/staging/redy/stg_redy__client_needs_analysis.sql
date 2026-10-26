{#-
  REDy client_needs_analysis_overview_sync_event -> analyza_potreb_klienta_hist (CDC).
  Load_Pattern step 7: party identifiers are resolved through mapovani_id_partnera
  (surviving identifier) before they enter the record hash.
-#}
{%- set src = source('src_redy', 'client_needs_analysis_overview_sync_event') -%}

with messages as (
    select *
    from {{ src }}
    where {{ message_policy_predicate('src_redy') }}
),

party_map as (
    select zdrojovy_partner_id, cilovy_partner_id
    from {{ ref('mapovani_id_partnera') }}
)

select
    {{ hash_key(['cast(coalesce(m.client_needs_analysis_id, m.id) as string)']) }}
                                                                    as analyza_potreb_klienta_hkey,
    cast(coalesce(m.client_needs_analysis_id, m.id) as string)      as analyza_id,
    coalesce(pm.cilovy_partner_id, m.client_needs_analysis_party.party_id)
                                                                    as partner_id,
    {{ fk_hash_key([normalize_login('m.client_needs_analysis_owner.domain_login')]) }}
                                                                    as obchodnik_hkey,
    cast(m.client_needs_analysis_owner.registered_agent.id as bigint) as ziskatelske_cislo,
    cast(m.client_needs_analysis_state as string)                   as stav_analyzy_kod,
    cast(m.client_needs_analysis_type as string)                    as typ_analyzy_kod,
    m.client_needs_analysis_created_on                              as vytvoreno_ts,
    m.client_needs_analysis_last_modified_on                        as zmeneno_ts,
    m.audit_information_user.domain_login                           as zmenu_provedl_login,
    cast(m.audit_information_application.id as int)                 as zdrojova_aplikace_id,
    m.__source_system                                               as __zdrojovy_system,
    '{{ source_table_name(src) }}'                                  as __zdrojova_tabulka_nazev,
    -- version start = source change time; falls back when last_modified is not yet filled
    coalesce(m.client_needs_analysis_last_modified_on,
             m.audit_information_last_updated_at,
             m.client_needs_analysis_created_on)                    as platnost_od_ts,
    m.__load_timestamp                                              as _stg_load_ts,
    m.__kafka_offset                                                as _stg_seq
from messages as m
left join party_map as pm
    on pm.zdrojovy_partner_id = m.client_needs_analysis_party.party_id
