{#-
  KCL bdt_campaign_wave (INCREMENTAL deltas) -> snapshot kampan_hist.
  Because each bronze load is only a delta, the snapshot input is the latest
  row per campaign over the whole bronze history - never just the last load.
  Otherwise hard_deletes='invalidate' would close every campaign missing from
  the delta (docs/deviations #7). Campaigns are never deleted at the source.
-#}
{%- set src = source('kcl', 'bdt_campaign_wave') -%}

with latest_per_key as (
    select *
    from {{ src }}
    qualify row_number() over (
        partition by id
        order by date_modified desc nulls last, __load_timestamp desc
    ) = 1
),

projected as (
    select
        cast(id as bigint)                                          as kampan_id,
        cast(campaign_code as string)                               as kampan_kod,
        cast(campaign_name as string)                               as kampan_nazev,
        cast(description as string)                                 as kampan_popis,
        cast(campaign_type as int)                                  as typ_kampane_kod,
        {{ to_flag('microcampaign') }}                              as mikrokampan_priznak,
        {{ fk_hash_key([normalize_login('founder')]) }}             as zakladatel_obchodnik_hkey,
        {{ fk_hash_key(['cast(channel_id as int)']) }}              as distribucni_kanal_hkey,
        cast(communication_code as string)                          as komunikace_kod,
        cast(communication_name as string)                          as komunikace_nazev,
        cast(start_date as date)                                    as zacatek_datum,
        cast(end_date as date)                                      as konec_datum,
        cast(valid_to as date)                                      as platnost_do_datum,
        cast(expected_value as decimal(38, 2))                      as ocekavana_hodnota_castka,
        cast(production_plan as decimal(38, 2))                     as plan_produkce_castka,
        cast(expected_replacement as decimal(38, 2))                as ocekavana_nahrada_hodnota,
        cast(company_id as bigint)                                  as spolecnost_kod,
        __source_system                                             as __zdrojovy_system
    from latest_per_key
)

select
    {{ snapshot_staging_columns(
        hkey='kampan_hkey',
        natural_key=['kampan_id'],
        hash_columns=['kampan_id', 'kampan_kod', 'kampan_nazev', 'kampan_popis', 'typ_kampane_kod',
                      'mikrokampan_priznak', 'zakladatel_obchodnik_hkey', 'distribucni_kanal_hkey',
                      'komunikace_kod', 'komunikace_nazev', 'zacatek_datum', 'konec_datum',
                      'platnost_do_datum', 'ocekavana_hodnota_castka', 'plan_produkce_castka',
                      'ocekavana_nahrada_hodnota', 'spolecnost_kod'],
        source_relation=src) }}
from projected as p
