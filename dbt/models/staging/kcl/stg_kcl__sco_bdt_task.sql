{#-
  KCL sco_bdt_task (incremental deltas) -> ukol_hist (CDC, with delete feed).
  smlouva_hkey stays NULL until the smlouva entity is delivered (it will be
  resolved by pairing smlouva_cislo); it is excluded from the record hash so
  filling it later does not create false versions (same reasoning as
  Load_Pattern step 16).
-#}
{%- set src = source('kcl', 'sco_bdt_task') -%}

with record_kind as (
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
        -- version start: day-granular source change date (see docs/deviations #10)
        cast(coalesce(t.modification_date, t.create_date) as timestamp)     as platnost_od_ts,
        t.__load_timestamp                                                  as _stg_load_ts,
        coalesce(t.date_inserted, t.__load_timestamp)                       as _stg_seq
    from {{ src }} as t
    left join record_kind as rk on rk.info_value = t.info
    left join party_map as pm on pm.zdrojovy_partner_id = t.party_id
)

select
    {{ hash_key(['ukol_id']) }}                                             as ukol_hkey,
    p.* except (snimek_klienta_ccd, __zdrojovy_system, platnost_od_ts, _stg_load_ts, _stg_seq),
    p.__zdrojovy_system,
    '{{ source_table_name(src) }}'                                          as __zdrojova_tabulka_nazev,
    p.snimek_klienta_ccd,
    {{ hash_of([{'expr': 'p.snimek_klienta_ccd', 'data_type': 'struct'}]) }} as hash_snimek_klienta_ccd,
    p.platnost_od_ts,
    p._stg_load_ts,
    p._stg_seq
from projected as p
