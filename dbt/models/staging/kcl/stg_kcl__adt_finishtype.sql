{#-
  KCL adt_finishtype (full snapshot) -> snapshot zpusob_dokonceni_ukolu_hist.
  NOTE: bronze key is (id, tasktype_id) but the silver natural key is
  (id, company_id). The unique test on the hkey below fails loudly if one
  finish type is shared by several task types (docs/deviations #9).
-#}
{%- set src = source('kcl', 'adt_finishtype') -%}

with latest_batch as (
    {{ select_latest_batch(src) }}
),

projected as (
    select
        cast(id as int)                                     as zpusob_dokonceni_id,
        cast(company_id as int)                             as spolecnost_kod,
        cast(name as string)                                as zpusob_dokonceni_nazev,
        {{ fk_hash_key(['cast(tasktype_id as int)']) }}     as typ_ukolu_hkey,
        {{ to_flag('success') }}                            as uspech_priznak,
        {{ to_flag('is_progress') }}                        as prubezna_priznak,
        {{ to_flag('is_obsolete') }}                        as neplatny_priznak,
        __source_system                                     as __zdrojovy_system
    from latest_batch
)

select
    {{ snapshot_staging_columns(
        hkey='zpusob_dokonceni_ukolu_hkey',
        natural_key=['zpusob_dokonceni_id', 'spolecnost_kod'],
        hash_columns=['zpusob_dokonceni_id', 'spolecnost_kod', 'zpusob_dokonceni_nazev', 'typ_ukolu_hkey',
                      'uspech_priznak', 'prubezna_priznak', 'neplatny_priznak'],
        source_relation=src) }}
from projected as p
