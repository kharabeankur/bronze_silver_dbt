{#-
  KCL adt_tasksubtype + adt_type_subtype (both full snapshot) -> silver podtyp_ukolu.
  The type link and the premium flag live on the 1:1 mapping table (file 14 PD_Tables).
-#}
{%- set src = source('kcl', 'adt_tasksubtype') -%}
{%- set map_src = source('kcl', 'adt_type_subtype') -%}

with subtype as (
    {{ select_latest_batch(src) }}
),

type_map as (
    {{ select_latest_batch(map_src) }}
),

projected as (
    select
        cast(st.id as int)                                  as podtyp_ukolu_id,
        cast(st.company_id as int)                          as spolecnost_kod,
        cast(st.name as string)                             as podtyp_ukolu_nazev,
        {{ fk_hash_key(['cast(tm.tasktype_id as int)']) }}  as typ_ukolu_hkey,
        {{ to_flag('tm.is_premium') }}                      as premiova_prilezitost_priznak,
        {{ to_flag('st.is_obsolete') }}                     as neplatny_priznak,
        st.__load_timestamp                                  as platnost_od_ts,
        st.__source_system                                  as __zdrojovy_system
    from subtype as st
    left join type_map as tm
        on  tm.tasksubtype_id = st.id
        and tm.company_id = st.company_id
)

select
    {{ silver_standard_columns(
        hkey='podtyp_ukolu_hkey',
        natural_key=['podtyp_ukolu_id', 'spolecnost_kod'],
        hash_columns=['podtyp_ukolu_id', 'spolecnost_kod', 'podtyp_ukolu_nazev', 'typ_ukolu_hkey',
                      'premiova_prilezitost_priznak', 'neplatny_priznak'],
        source_relation=src) }}
from projected as p
