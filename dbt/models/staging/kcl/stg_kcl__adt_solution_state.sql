{#- KCL adt_solution_state (full snapshot) -> silver stav_kontaktu -#}
{%- set src = source('kcl', 'adt_solution_state') -%}

with latest_batch as (
    {{ select_latest_batch(src) }}
),

projected as (
    select
        cast(id as int)                     as stav_kontaktu_id,
        cast(solution_state as string)      as stav_kontaktu_nazev,
        cast(description as string)         as stav_kontaktu_popis,
        cast(state_type as string)          as zpetna_vazba_kod,
        cast(company_id as int)             as spolecnost_kod,
        {{ to_flag('is_obsolete') }}        as neplatny_priznak,
        __load_timestamp                     as platnost_od_ts,
        __source_system                     as __zdrojovy_system
    from latest_batch
)

select
    {{ silver_standard_columns(
        hkey='stav_kontaktu_hkey',
        natural_key=['stav_kontaktu_id'],
        hash_columns=['stav_kontaktu_id', 'stav_kontaktu_nazev', 'stav_kontaktu_popis',
                      'zpetna_vazba_kod', 'spolecnost_kod', 'neplatny_priznak'],
        source_relation=src) }}
from projected as p
