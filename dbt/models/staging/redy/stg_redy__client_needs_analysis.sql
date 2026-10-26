{#-
  REDy client_needs_analysis_overview_sync_event -> silver analyza_potreb_klienta.
  Bronze holds one row per Kafka message; the current state is the latest
  message per analysis. Party ids are resolved to the surviving identifier
  through mapovani_id_partnera (Load_Pattern step 7).
-#}
{%- set src = source('src_redy', 'client_needs_analysis_overview_sync_event') -%}

with messages as (
    select
        *,
        coalesce(client_needs_analysis_id, id)                  as _analyza_id,
        coalesce(client_needs_analysis_last_modified_on,
                 audit_information_last_updated_at,
                 client_needs_analysis_created_on)              as _changed_at
    from {{ src }}
    where {{ message_policy_predicate('src_redy') }}
),

latest as (
    select *
    from messages
    qualify row_number() over (
        partition by _analyza_id
        order by _changed_at desc nulls last, __kafka_offset desc
    ) = 1
),

party_map as (
    select zdrojovy_partner_id, cilovy_partner_id
    from {{ ref('mapovani_id_partnera') }}
),

projected as (
    select
        cast(m._analyza_id as string)                                   as analyza_id,
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
        m._changed_at                                                   as platnost_od_ts
    from latest as m
    left join party_map as pm
        on pm.zdrojovy_partner_id = m.client_needs_analysis_party.party_id
)

select
    {{ silver_standard_columns(
        hkey='analyza_potreb_klienta_hkey',
        natural_key=['analyza_id'],
        hash_columns=['analyza_id', 'partner_id', 'obchodnik_hkey', 'ziskatelske_cislo', 'stav_analyzy_kod',
                      'typ_analyzy_kod', 'vytvoreno_ts', 'zmeneno_ts', 'zmenu_provedl_login', 'zdrojova_aplikace_id'],
        source_relation=src) }}
from projected as p
