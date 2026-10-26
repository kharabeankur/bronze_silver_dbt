{#-
  KCC produkt (daily file, full snapshot) -> snapshot produkt_hist.
  DEVIATION (docs/deviations #8): file 14 maps technicka_urokova_mira from
  nep_predpis (STRING). Bronze carries tum DECIMAL(3,1) = "technická úroková
  míra", which matches the silver type exactly; tum is used here pending
  confirmation by the data modeller.
-#}
{%- set src = source('src_kcc', 'produkt') -%}

with latest_batch as (
    {{ select_latest_batch(src) }}
),

projected as (
    select
        cast(kod_produkt as int)                    as produkt_kod,
        cast(company_id as int)                     as spolecnost_kod,
        cast(kr_naz_produkt as string)              as produkt_kratky_nazev,
        cast(dl_naz_produkt as string)              as produkt_nazev,
        cast(obch_naz_produkt as string)            as produkt_obchodni_nazev,
        cast(zkrat as string)                       as produkt_zkratka,
        cast(seskupeni as int)                      as seskupeni_kod,
        {{ to_flag('kod_zivot') }}                  as zivotni_produkt_priznak,
        {{ to_flag('sjednavan') }}                  as sjednavan_priznak,
        cast(prod_plat_od as date)                  as prodej_od_datum,
        cast(prod_plat_do as date)                  as prodej_do_datum,
        cast(tum as decimal(3, 1))                  as technicka_urokova_mira,
        {{ to_flag('dan_uznatelnost') }}            as danove_uznatelny_priznak,
        {{ to_flag('fikt_produkt') }}               as fiktivni_produkt_priznak,
        cast(kateg_poji as int)                     as kategorie_pojisteni_kod,
        cast(portfolio as string)                   as portfolio_kod,
        cast(tr_ul as string)                       as investicni_produkt_kod,
        {{ to_flag('odkup') }}                      as odbytne_priznak,
        {{ to_flag('vazba_psp') }}                  as psp_vazba_priznak,
        cast(sap_objid as string)                   as sap_kvalifikace_objid,
        cast(plati_od as date)                      as platnost_od_datum,
        cast(plati_do as date)                      as platnost_do_datum,
        cast(publik_od as date)                     as publikovano_od_datum,
        cast(publik_do as date)                     as publikovano_do_datum,
        __source_system                             as __zdrojovy_system
    from latest_batch
)

select
    {{ snapshot_staging_columns(
        hkey='produkt_hkey',
        natural_key=['produkt_kod', 'spolecnost_kod'],
        hash_columns=['produkt_kod', 'spolecnost_kod', 'produkt_kratky_nazev', 'produkt_nazev',
                      'produkt_obchodni_nazev', 'produkt_zkratka', 'seskupeni_kod', 'zivotni_produkt_priznak',
                      'sjednavan_priznak', 'prodej_od_datum', 'prodej_do_datum', 'technicka_urokova_mira',
                      'danove_uznatelny_priznak', 'fiktivni_produkt_priznak', 'kategorie_pojisteni_kod',
                      'portfolio_kod', 'investicni_produkt_kod', 'odbytne_priznak', 'psp_vazba_priznak',
                      'sap_kvalifikace_objid', 'platnost_od_datum', 'platnost_do_datum',
                      'publikovano_od_datum', 'publikovano_do_datum'],
        source_relation=src) }}
from projected as p
