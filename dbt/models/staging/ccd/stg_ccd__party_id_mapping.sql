{#-
  CCD party_id_change_event -> mapovani_id_partnera_hist (batch_mode='full').

  Every identifier a party has ever had is mapped to the surviving one.
  "Chains are shortened during the load, so a lookup never needs more than one
  step" (file 14 Bronze_Mapping): A->B followed by B->C yields A->C and B->C.
  The chain is followed up to var('party_chain_max_depth') hops; the test
  party_mapping_fully_resolved fails if a longer chain or a cycle remains.

  Because a new event can re-point old identifiers, this view always emits the
  complete resolved mapping; the SCD2 macro then writes only real changes.
  platnost_od_ts = the latest change along the chain (when the resolved target
  became what it is).
-#}
{%- set src = source('src_ccd', 'party_id_change_event') -%}
{%- set depth = var('party_chain_max_depth') | int -%}

with events as (
    select
        cast(coalesce(party_party_id, party_id) as string)      as zdrojovy_partner_id,
        cast(party_new_party_id as string)                      as cilovy_partner_id,
        audit_information_last_updated_at                       as zmena_ts,
        audit_information_user.domain_login                     as zmenu_provedl_login,
        cast(audit_information_application.id as int)          as zdrojova_aplikace_id,
        __source_system                                         as __zdrojovy_system,
        __kafka_offset
    from {{ src }}
    where {{ message_policy_predicate('src_ccd') }}
      and party_new_party_id is not null
      and coalesce(party_party_id, party_id) <> party_new_party_id
    -- latest change per identifier wins (replays / re-sent messages)
    qualify row_number() over (
        partition by coalesce(party_party_id, party_id)
        order by audit_information_last_updated_at desc, __kafka_offset desc
    ) = 1
),

hop_0 as (
    select
        e.*,
        e.cilovy_partner_id     as resolved_id,
        e.zmena_ts              as chain_ts,
        1                       as chain_length
    from events as e
)
{%- for i in range(1, depth + 1) %},

hop_{{ i }} as (
    select
        h.zdrojovy_partner_id, h.cilovy_partner_id, h.zmena_ts, h.zmenu_provedl_login,
        h.zdrojova_aplikace_id, h.__zdrojovy_system, h.__kafka_offset,
        coalesce(n.cilovy_partner_id, h.resolved_id)                        as resolved_id,
        greatest(h.chain_ts, coalesce(n.zmena_ts, h.chain_ts))              as chain_ts,
        h.chain_length + case when n.zdrojovy_partner_id is null then 0 else 1 end as chain_length
    from hop_{{ i - 1 }} as h
    left join events as n
        on  n.zdrojovy_partner_id = h.resolved_id
        and n.cilovy_partner_id <> h.zdrojovy_partner_id     -- stop at a 2-cycle
)
{%- endfor %}

select
    {{ hash_key(['zdrojovy_partner_id']) }}     as mapovani_id_partnera_hkey,
    zdrojovy_partner_id,
    resolved_id                                 as cilovy_partner_id,
    zmena_ts,
    chain_length                                as delka_retezce,
    zmenu_provedl_login,
    zdrojova_aplikace_id,
    __zdrojovy_system,
    '{{ source_table_name(src) }}'              as __zdrojova_tabulka_nazev,
    chain_ts                                    as platnost_od_ts,
    cast(0 as bigint)                           as _stg_seq
from hop_{{ depth }}
