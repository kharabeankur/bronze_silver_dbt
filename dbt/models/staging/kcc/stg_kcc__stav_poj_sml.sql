{#-
  KCC stav_poj_sml + man.stav_poj_sml_sales_cockpit -> snapshot stav_smlouvy_hist.
  The Sales Cockpit display name is merged in from the manual mapping table
  "for the date on which the codelist item is valid" (file 14 Bronze_Mapping);
  the as-of date is configuration: var('sales_cockpit_mapping_as_of').
  A change of the mapping validity therefore creates a new codelist version.
-#}
{%- set src = source('src_kcc', 'stav_poj_sml') -%}
{%- set map_src = source('man', 'stav_poj_sml_sales_cockpit') -%}

with status as (
    {{ select_latest_batch(src) }}
),

sales_cockpit_map as (
    select company_id, kod_stav, nazev_stav_sales_cockpit
    from (
        {{ select_latest_batch(map_src) }}
    ) as latest_map
    where plati_od <= {{ var('sales_cockpit_mapping_as_of') }}
      and (plati_do is null or plati_do >= {{ var('sales_cockpit_mapping_as_of') }})
    qualify row_number() over (partition by company_id, kod_stav order by plati_od desc) = 1
),

projected as (
    select
        cast(s.kod_stav as int)                         as stav_smlouvy_kod,
        cast(s.company_id as int)                       as spolecnost_kod,
        cast(s.nazev_stav as string)                    as stav_smlouvy_nazev,
        cast(s.alfanum_kod as string)                   as stav_smlouvy_alfanum_kod,
        cast(m.nazev_stav_sales_cockpit as string)      as stav_sales_cockpit_nazev,
        cast(s.vyskyt_stavu as string)                  as vyskyt_stavu_kod,
        cast(s.poradi as int)                           as poradi,
        cast(s.plati_od as date)                        as platnost_od_datum,
        cast(s.plati_do as date)                        as platnost_do_datum,
        cast(s.publik_od as date)                       as publikovano_od_datum,
        cast(s.publik_do as date)                       as publikovano_do_datum,
        s.__source_system                               as __zdrojovy_system
    from status as s
    left join sales_cockpit_map as m
        on  m.company_id = s.company_id
        and m.kod_stav = s.kod_stav
)

select
    {{ snapshot_staging_columns(
        hkey='stav_smlouvy_hkey',
        natural_key=['stav_smlouvy_kod', 'spolecnost_kod'],
        hash_columns=['stav_smlouvy_kod', 'spolecnost_kod', 'stav_smlouvy_nazev', 'stav_smlouvy_alfanum_kod',
                      'stav_sales_cockpit_nazev', 'vyskyt_stavu_kod', 'poradi', 'platnost_od_datum',
                      'platnost_do_datum', 'publikovano_od_datum', 'publikovano_do_datum'],
        source_relation=src) }}
from projected as p
