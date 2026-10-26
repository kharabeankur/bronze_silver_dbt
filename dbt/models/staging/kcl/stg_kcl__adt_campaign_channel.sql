{#- KCL adt_campaign_channel (full snapshot) -> snapshot distribucni_kanal_hist -#}
{%- set src = source('kcl', 'adt_campaign_channel') -%}

with latest_batch as (
    {{ select_latest_batch(src) }}
),

projected as (
    select
        cast(id as int)                     as kanal_id,
        cast(channel as string)             as kanal_nazev,
        cast(kod_kcc as string)             as kanal_kcc_kod,
        cast(company_id as int)             as spolecnost_kod,
        {{ to_flag('is_obsolete') }}        as neplatny_priznak,
        __source_system                     as __zdrojovy_system
    from latest_batch
)

select
    {{ snapshot_staging_columns(
        hkey='distribucni_kanal_hkey',
        natural_key=['kanal_id'],
        hash_columns=['kanal_id', 'kanal_nazev', 'kanal_kcc_kod', 'spolecnost_kod', 'neplatny_priznak'],
        source_relation=src) }}
from projected as p
