{#- KCL adt_taskstatus (full snapshot) -> snapshot stav_ukolu_hist -#}
{%- set src = source('kcl', 'adt_taskstatus') -%}

with latest_batch as (
    {{ select_latest_batch(src) }}
),

projected as (
    select
        cast(id as int)                     as stav_ukolu_id,
        cast(company_id as int)             as spolecnost_kod,
        cast(name as string)                as stav_ukolu_nazev,
        {{ to_flag('is_obsolete') }}        as neplatny_priznak,
        __source_system                     as __zdrojovy_system
    from latest_batch
)

select
    {{ snapshot_staging_columns(
        hkey='stav_ukolu_hkey',
        natural_key=['stav_ukolu_id', 'spolecnost_kod'],
        hash_columns=['stav_ukolu_id', 'spolecnost_kod', 'stav_ukolu_nazev', 'neplatny_priznak'],
        source_relation=src) }}
from projected as p
