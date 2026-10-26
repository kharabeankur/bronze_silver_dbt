{#-
  KCL sco_bdt_task (incremental deltas) + sco_bdt_task_delete -> silver ukol.

  Phase 1 = current state only:
    * the latest row per task over the whole bronze history,
    * smazano_priznak = true when the task was deleted after its last change
      (rows are never physically removed - Load_Pattern step 17).
  smlouva_hkey stays NULL until the smlouva entity exists (phase 1b) and is kept
  out of hash_zaznamu so filling it later is not seen as a business change.
-#}
{%- set src = source('kcl', 'sco_bdt_task') -%}
{%- set del_src = source('kcl', 'sco_bdt_task_delete') -%}

with latest_task as (
    select *
    from {{ src }}
    qualify row_number() over (
        partition by id
        order by modification_date desc nulls last, date_inserted desc nulls last, __load_timestamp desc
    ) = 1
),

latest_delete as (
    select id, max(date_deleted) as date_deleted
    from {{ del_src }}
    group by id
),

record_kind as (
    select info_value, typ_zaznamu_kod
    from {{ ref('ref_typ_zaznamu') }}
    where source_object = '{{ source_table_name(src) }}'
),

party_map as (
    select zdrojovy_partner_id, cilovy_partner_id
    from {{ ref('mapovani_id_partnera') }}
),

projected as (
    select
        cast(t.id as bigint)                                                as ukol_id,
        coalesce(rk.typ_zaznamu_kod, '{{ var("unknown_code") }}')           as typ_zaznamu_kod,
        {{ fk_hash_key(['cast(t.task_type_id as int)']) }}                  as typ_ukolu_hkey,
        {{ fk_hash_key(['cast(t.task_subtype_id as int)', 'cast(t.company_id as int)']) }}
                                                                            as podtyp_ukolu_hkey,
        {{ fk_hash_key(['cast(t.status_id as int)', 'cast(t.company_id as int)']) }}
                                                                            as stav_ukolu_hkey,
        {{ fk_hash_key(['cast(t.finishtype_id as int)', 'cast(t.company_id as int)']) }}
                                                                            as zpusob_dokonceni_hkey,
        {{ fk_hash_key([normalize_login('t.author_login')]) }}             as autor_obchodnik_hkey,
        {{ fk_hash_key([normalize_login('t.solver_login')]) }}             as resitel_obchodnik_hkey,
        coalesce(pm.cilovy_partner_id, t.party_id)                          as partner_id,
        cast(t.policy_no as bigint)                                         as smlouva_cislo,
        cast(null as string)                                                as smlouva_hkey,
        coalesce(t.claim_no_varchar, cast(t.claim_no as string))            as pojistna_udalost_cislo,
        cast(t.task_src_id as bigint)                                       as ukol_zdroj_id,
        cast(t.queue_group_cd as string)                                    as fronta_kod,
        cast(t.case_value as decimal(38, 2))                                as bonita_castka,
        {{ to_flag('t.from_market') }}                                      as z_trziste_priznak,
        t.create_date                                                       as vznik_datum,
        t.deadline_date                                                     as termin_datum,
        t.notif_date                                                        as upozorneni_datum,
        t.finish_date                                                       as splneni_datum,
        t.modification_date                                                 as zmena_datum,
        t.queue_change_date                                                 as zmena_resitele_datum,
        cast(t.company_id as bigint)                                        as spolecnost_kod,
        coalesce(d.date_deleted >= cast(coalesce(t.modification_date, t.create_date) as timestamp), false)
                                                                            as smazano_priznak,
        named_struct(
            'jmeno',        t.client_firstname,
            'prijmeni',     t.client_surname,
            'nazev_firmy',  t.client_bus_name,
            'rodne_cislo',  t.person_in,
            'ico',          t.business_in,
            'ulice_nazev',  t.street,
            'cislo_domu',   t.street_no,
            'obec_nazev',   t.city,
            'psc',          t.zip_code,
            'stat_kod',     t.country,
            'ccd_email',    t.client_email,
            'ccd_telefon',  t.client_phone,
            'kcl_email',    t.kcl_email,
            'kcl_telefon',  t.kcl_phone
        )                                                                   as snimek_klienta_ccd,
        t.__source_system                                                   as __zdrojovy_system,
        -- valid since: last change in the source, or the deletion if that came later
        greatest(cast(coalesce(t.modification_date, t.create_date) as timestamp),
                 coalesce(d.date_deleted, timestamp'1900-01-01'))           as platnost_od_ts
    from latest_task as t
    left join latest_delete as d on d.id = t.id
    left join record_kind as rk on rk.info_value = t.info
    left join party_map as pm on pm.zdrojovy_partner_id = t.party_id
)

select
    {{ silver_standard_columns(
        hkey='ukol_hkey',
        natural_key=['ukol_id'],
        hash_columns=['ukol_id', 'typ_zaznamu_kod', 'typ_ukolu_hkey', 'podtyp_ukolu_hkey', 'stav_ukolu_hkey',
                      'zpusob_dokonceni_hkey', 'autor_obchodnik_hkey', 'resitel_obchodnik_hkey', 'partner_id',
                      'smlouva_cislo', 'pojistna_udalost_cislo', 'ukol_zdroj_id', 'fronta_kod', 'bonita_castka',
                      'z_trziste_priznak', 'vznik_datum', 'termin_datum', 'upozorneni_datum', 'splneni_datum',
                      'zmena_datum', 'zmena_resitele_datum', 'spolecnost_kod', 'smazano_priznak',
                      {'expr': 'snimek_klienta_ccd', 'data_type': 'struct'}],
        source_relation=src) }},
    {{ hash_of([{'expr': 'p.snimek_klienta_ccd', 'data_type': 'struct'}]) }} as hash_snimek_klienta_ccd
from projected as p
