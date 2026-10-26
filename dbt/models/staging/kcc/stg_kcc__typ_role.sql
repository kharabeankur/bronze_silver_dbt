{#- KCC typ_role (daily file, full snapshot) -> silver typ_role_partnera -#}
{%- set src = source('src_kcc', 'typ_role') -%}

with latest_batch as (
    {{ select_latest_batch(src) }}
),

projected as (
    select
        cast(kod_typ_role as int)           as typ_role_kod,
        cast(typ_role as string)            as typ_role_nazev,
        cast(vyskyt_role as string)         as vyskyt_role_kod,
        cast(plati_od as date)              as platnost_od_datum,
        cast(plati_do as date)              as platnost_do_datum,
        cast(publik_od as date)             as publikovano_od_datum,
        cast(publik_do as date)             as publikovano_do_datum,
        __load_timestamp                     as platnost_od_ts,
        __source_system                     as __zdrojovy_system
    from latest_batch
)

select
    {{ silver_standard_columns(
        hkey='typ_role_partnera_hkey',
        natural_key=['typ_role_kod'],
        hash_columns=['typ_role_kod', 'typ_role_nazev', 'vyskyt_role_kod', 'platnost_od_datum',
                      'platnost_do_datum', 'publikovano_od_datum', 'publikovano_do_datum'],
        source_relation=src) }}
from projected as p
