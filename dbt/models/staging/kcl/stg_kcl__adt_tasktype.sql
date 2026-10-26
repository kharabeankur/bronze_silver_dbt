{#- KCL adt_tasktype (full snapshot) -> snapshot typ_ukolu_hist -#}
{%- set src = source('kcl', 'adt_tasktype') -%}

with latest_batch as (
    {{ select_latest_batch(src) }}
),

record_kind as (
    select info_value, typ_zaznamu_kod
    from {{ ref('ref_typ_zaznamu') }}
    where source_object = '{{ source_table_name(src) }}'
),

projected as (
    select
        cast(s.id as int)                                           as typ_ukolu_id,
        cast(s.name as string)                                      as typ_ukolu_nazev,
        cast(s.short_name as string)                                as typ_ukolu_kratky_nazev,
        coalesce(rk.typ_zaznamu_kod, '{{ var("unknown_code") }}')   as typ_zaznamu_kod,
        cast(s.deadline as int)                                     as dnu_na_splneni,
        cast(s.ttl as int)                                          as dnu_do_archivace,
        cast(s.company_id as int)                                   as spolecnost_kod,
        {{ to_flag('s.is_obsolete') }}                              as neplatny_priznak,
        s.__source_system                                           as __zdrojovy_system
    from latest_batch as s
    left join record_kind as rk
        on rk.info_value = s.info
)

select
    {{ snapshot_staging_columns(
        hkey='typ_ukolu_hkey',
        natural_key=['typ_ukolu_id'],
        hash_columns=['typ_ukolu_id', 'typ_ukolu_nazev', 'typ_ukolu_kratky_nazev', 'typ_zaznamu_kod',
                      'dnu_na_splneni', 'dnu_do_archivace', 'spolecnost_kod', 'neplatny_priznak'],
        source_relation=src) }}
from projected as p
