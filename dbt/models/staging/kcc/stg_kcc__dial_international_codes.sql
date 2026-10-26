{#- KCC dial_international_codes (daily file, full snapshot) -> snapshot mezinarodni_predvolba_hist -#}
{%- set src = source('src_kcc', 'dial_international_codes') -%}

with latest_batch as (
    {{ select_latest_batch(src) }}
),

projected as (
    select
        cast(dial_code as int)              as predvolba_kod,
        cast(country_code_iso2 as string)   as stat_iso2_kod,
        cast(country_code_iso3 as string)   as stat_iso3_kod,
        cast(country_region as string)      as stat_nazev,
        cast(sequence as int)               as poradi,
        cast(plati_od as date)              as platnost_od_datum,
        cast(plati_do as date)              as platnost_do_datum,
        cast(publik_od as date)             as publikovano_od_datum,
        cast(publik_do as date)             as publikovano_do_datum,
        __source_system                     as __zdrojovy_system
    from latest_batch
)

select
    {{ snapshot_staging_columns(
        hkey='mezinarodni_predvolba_hkey',
        natural_key=['stat_iso2_kod'],
        hash_columns=['predvolba_kod', 'stat_iso2_kod', 'stat_iso3_kod', 'stat_nazev', 'poradi',
                      'platnost_od_datum', 'platnost_do_datum', 'publikovano_od_datum', 'publikovano_do_datum'],
        source_relation=src) }}
from projected as p
