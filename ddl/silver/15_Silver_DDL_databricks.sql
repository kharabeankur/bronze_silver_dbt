-- ###########################################################################
-- SILVER LAYER DDL for Databricks
-- Catalog: dbx_cz_gcz_dev_czlake_silver
-- Entity-centric conformed canonical model per Model_Návrh.docx.
-- Naming per Adastra Generali Blueprint 4.1: singular lower_snake_case English
-- names, type suffixes from table 11, key naming from table 12, no dim_ / fact_
-- prefix (GOLD only). Schema mask <store>_<domain_letter>_<domain_abbrev>.
-- Comments are English; the Czech text goes into the description_cz tag.
-- Every entity has a current-state table and an SCD2 history table (_hist).
-- ###########################################################################

CREATE SCHEMA IF NOT EXISTS dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva COMMENT 'Entity pojistné smlouvy a návrhu.';
ALTER SCHEMA dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva SET TAGS ('environment' = 'prod', 'layer' = 'silver', 'data_domain' = 'smlouva', 'data_classification' = 'confidential', 'cost_center' = 'cc-4711', 'owner' = 'grp-dbx-team-dwhbi', 'description_en' = 'Insurance contract and offer entities.');

CREATE SCHEMA IF NOT EXISTS dbx_cz_gcz_dev_czlake_silver.ods_k_klient COMMENT 'Entity související s klientem.';
ALTER SCHEMA dbx_cz_gcz_dev_czlake_silver.ods_k_klient SET TAGS ('environment' = 'prod', 'layer' = 'silver', 'data_domain' = 'klient', 'data_classification' = 'confidential', 'cost_center' = 'cc-4711', 'owner' = 'grp-dbx-team-dwhbi', 'description_en' = 'Client related entities.');

CREATE SCHEMA IF NOT EXISTS dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce COMMENT 'Entity obchodní sítě, kampaní, úkolů a plánů.';
ALTER SCHEMA dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce SET TAGS ('environment' = 'prod', 'layer' = 'silver', 'data_domain' = 'distribuce', 'data_classification' = 'confidential', 'cost_center' = 'cc-4711', 'owner' = 'grp-dbx-team-dwhbi', 'description_en' = 'Sales network, campaign, task and plan entities.');

CREATE SCHEMA IF NOT EXISTS dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik COMMENT 'Konformované číselníky společné pro všechny domény.';
ALTER SCHEMA dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik SET TAGS ('environment' = 'prod', 'layer' = 'silver', 'data_domain' = 'ciselnik', 'data_classification' = 'internal', 'cost_center' = 'cc-4711', 'owner' = 'grp-dbx-team-dwhbi', 'description_en' = 'Conformed codelists shared across the domains.');

-- ========================= dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.smlouva =========================
-- current state | grain: Jeden řádek na smlouvu | sources: TIA, KDP
CREATE TABLE IF NOT EXISTS dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.smlouva (
    smlouva_hkey                   STRING NOT NULL  COMMENT 'Hash přirozeného klíče (smlouva_cislo + zdrojova_aplikace_id). Identifikuje entitu, je stabilní napříč verzemi a slouží jako cíl odkazů z jiných entit i jako unique_key snapshotu v dbt.',
    pojistne_odvetvi_kod           STRING NOT NULL  COMMENT 'ZIVOT nebo NEZIVOT. Odvozeno z topiku; není součástí klíče, protože ten už odvětví rozlišuje přes zdrojovou aplikaci.',
    smlouva_cislo                  BIGINT NOT NULL  COMMENT 'Unikátní a veřejný identifikátor smlouvy, ve zdroji označovaný jako číslo smlouvy. Spolu se zdrojova_aplikace_id jednoznačně identifikuje řádek; pro tuto entitu je vždy vyplněn.',
    nadrizena_smlouva_hkey         STRING  COMMENT 'Rámcová smlouva, ke které tato smlouva patří.',
    ramcova_smlouva_priznak        BOOLEAN NOT NULL  COMMENT 'TRUE, když je smlouva sama rámcovou smlouvou.',
    stav_smlouvy_kod               INT NOT NULL  COMMENT 'Stav smlouvy nebo stavu před uzavřením.',
    spolecnost_kod                 BIGINT NOT NULL  COMMENT 'Společnost skupiny, která je pojistitelem.',
    aplikace_kod                   INT NOT NULL  COMMENT 'Zdrojová aplikace, ve které je smlouva spravována.',
    balicek_produktu_kod           STRING  COMMENT 'Katalogový balíček produktů. Pouze neživot.',
    zivotni_znacka_kod             BIGINT  COMMENT 'Katalogová životní značka. Pouze život.',
    datum_podpisu                  DATE  COMMENT 'Datum podpisu smlouvy. Zdroj hodnotu mění při novém podpisu a před podpisem ji vyplňuje předpokládaným datem, takže sama o sobě není spolehlivým datem vzniku.',
    datum_vzniku_smlouvy           DATE  COMMENT 'Datum, kdy se smlouva poprvé dostala do stavu smlouvy. Plnění si drží první zachycené datum podpisu a nedovolí novému podpisu s ním pohnout.',
    platnost_od_datum              DATE  COMMENT 'Počátek pojistné ochrany.',
    platnost_do_datum              DATE  COMMENT 'Konec pojistné ochrany.',
    puvodni_platnost_do_datum      DATE  COMMENT 'Původně sjednaný konec pojistné ochrany.',
    datum_zruseni                  DATE  COMMENT 'Datum zrušení smlouvy.',
    datum_obnovy                   DATE  COMMENT 'Datum nejbližší obnovy.',
    verze_platnost_od_datum        DATE  COMMENT 'Počátek platnosti této verze smlouvy ve zdroji.',
    frekvence_platby_kod           INT NOT NULL  COMMENT 'Jak často se platí pojistné.',
    termin_aktivacni_platby_datum  DATE  COMMENT 'Termín pro aktivační platbu.',
    rocni_pojistne_castka          DECIMAL(38,2) NOT NULL  COMMENT 'Roční pojistné celé smlouvy.',
    legacy_navrh_cislo             STRING  COMMENT 'Číslo návrhu ze starého systému Generali.',
    legacy_duvod_zruseni_popis     STRING  COMMENT 'Důvod zrušení ze starého systému Generali.',
    instance_produktu              
        ARRAY<STRUCT<`produkt_kod`: INT, `sjednana_rada_cislo`: BIGINT, `stav_instance_kod`: INT, `datum_podpisu`: DATE, `platnost_od_datum`: DATE, `platnost_do_datum`: DATE, `rocni_pojistne_castka`: DECIMAL(38,2), `vozidlo`: ARRAY<STRUCT<`vin`: STRING, `registracni_znacka`: STRING, `znacka_nazev`: STRING, `typ_nazev`: STRING, `kategorie_kod`: STRING, `rok_vyroby`: INT, `objem_motoru_hodnota`: INT, `vykon_motoru_hodnota`: INT>>, `misto_pojisteni`: ARRAY<STRUCT<`stat_kod`: STRING, `obec_nazev`: STRING, `cast_obce_nazev`: STRING, `ulice_nazev`: STRING, `cislo_orientacni`: STRING, `cislo_popisne`: STRING, `cislo_evidencni`: STRING, `psc`: STRING, `ruian_adresni_bod_kod`: BIGINT, `katastralni_uzemi_id`: BIGINT, `katastralni_uzemi_nazev`: STRING, `parcela_cislo`: STRING, `parcela_podlomeni`: STRING>>>> NOT NULL  COMMENT 'Produkty umístěné na smlouvě. Životní smlouva má právě jednu instanci, neživotní jednu nebo více. Vozidla a místa pojištění jsou vnořena o úroveň níž.',
    partner_role                   
        ARRAY<STRUCT<`partner_id`: STRING, `typ_role_kod`: INT, `zaznam_partnera_ext_id`: BIGINT, `pravni_typ_kod`: INT, `typ_partnera_kod`: STRING, `jmeno`: STRING, `prijmeni`: STRING, `nazev_partnera`: STRING, `titul_pred`: STRING, `titul_za`: STRING, `datum_narozeni`: DATE, `rodne_cislo`: STRING, `datum_umrti`: DATE, `pohlavi_kod`: INT, `statni_prislusnost_kod`: STRING, `ico`: STRING, `stat_registrace_kod`: STRING, `registrovany_nazev`: STRING, `pravni_forma_kod`: INT, `organ_vm_priznak`: BOOLEAN, `datum_ukonceni_cinnosti`: DATE, `adresa`: ARRAY<STRUCT<`typ_pouziti_kod`: STRING, `ext_id`: BIGINT, `stat_kod`: STRING, `obec_nazev`: STRING, `cast_obce_nazev`: STRING, `ulice_nazev`: STRING, `cislo_orientacni`: STRING, `cislo_popisne`: STRING, `cislo_evidencni`: STRING, `psc`: STRING, `pokyn_doruceni_popis`: STRING, `ruian_adresni_bod_kod`: BIGINT>>, `telefon`: ARRAY<STRUCT<`typ_telefonu_kod`: STRING, `ext_id`: BIGINT, `cele_cislo`: STRING, `mezinarodni_predvolba`: INT, `narodni_cislo`: STRING>>, `email`: ARRAY<STRUCT<`ext_id`: BIGINT, `emailova_adresa`: STRING>>>> NOT NULL  COMMENT 'Partneři na smlouvě s rolemi a účelovými údaji platnými pro tuto smlouvu. Jeden partner může mít více rolí.',
    ucast_obchodnika               
        ARRAY<STRUCT<`obchodnik_hkey`: STRING, `obchodnik_login`: STRING, `typ_ucasti_kod`: STRING, `role_kod`: ARRAY<STRING>, `ziskatelske_cislo`: BIGINT, `osobni_cislo`: BIGINT, `podobchodnik_login`: STRING, `provizni_podil_castka`: DECIMAL(38,2), `poradi`: INT>>  COMMENT 'Obchodníci spravující smlouvu, se získatelským číslem, pořadím a provizním podílem.',
    zmenu_provedl_login            STRING  COMMENT 'Domain login uživatele, který záznam ve zdrojovém systému naposledy změnil.',
    zdrojova_aplikace_id           INT NOT NULL  COMMENT 'Identifikátor zdrojové aplikace, ve které je smlouva spravována. Spolu se smlouva_cislo tvoří přirozený klíč a u mazání se jím rozliší, zda zpráva přišla z TIA nebo z KDP.',
    __zdrojovy_system              STRING NOT NULL  COMMENT 'Zdrojový systém, ze kterého byl záznam načten. Přebírá se z metadatového sloupce __source_system odpovídající bronze tabulky.',
    __zdrojova_tabulka_nazev       STRING NOT NULL  COMMENT 'Plně kvalifikovaná bronze tabulka, ze které byl záznam načten. U konformovaných entit plněných z více bronze tabulek je to jediný údaj, který rozliší původ konkrétního řádku.',
    smazano_priznak                BOOLEAN NOT NULL  COMMENT 'TRUE, když zdroj oznámil smazání záznamu. Logické smazání, řádek zůstává, aby zůstala dohledatelná historie i odkazy.',
    hash_instance_produktu         STRING  COMMENT 'Diagnostický hash vnořeného sloupce instance_produktu. Neúčastní se rozhodnutí o nové verzi, slouží jen ke zjištění, která oblast se změnila. Pole se před hashováním řadí podle stabilního klíče.',
    hash_partner_role              STRING  COMMENT 'Diagnostický hash vnořeného sloupce partner_role. Neúčastní se rozhodnutí o nové verzi, slouží jen ke zjištění, která oblast se změnila. Pole se před hashováním řadí podle stabilního klíče.',
    hash_ucast_obchodnika          STRING  COMMENT 'Diagnostický hash vnořeného sloupce ucast_obchodnika. Neúčastní se rozhodnutí o nové verzi, slouží jen ke zjištění, která oblast se změnila. Pole se před hashováním řadí podle stabilního klíče.',
    platnost_od_ts                 TIMESTAMP NOT NULL  COMMENT 'Okamžik, od kterého je tato verze řádku platná. U inkrementálních tabulek se plní časem poslední změny ve zdroji: u sync topiků z dataUpdatedAt, u delete topiků z auditInformation.lastUpdatedAt. U tabulek plněných snapshotem nese čas běhu, tedy okamžik, kdy jsme stav pozorovali - zdroj posílá celý snímek a vlastní čas změny u číselníků nenabízí.',
    hash_zaznamu                   STRING NOT NULL  COMMENT 'Rozhodovací hash přes všechny byznysové sloupce. Podle něj se pozná skutečná změna a v dbt je to jediný sloupec v check_cols. Technické sloupce do hashe nevstupují, jinak by vznikala nová verze při každém běhu, a vnořená pole se před hashováním řadí podle stabilního klíče, jinak by jiné pořadí prvků vypadalo jako změna.',
    __nacteno_ts                   TIMESTAMP NOT NULL  COMMENT 'Časové razítko, kdy byl záznam vložen do této silver tabulky.',
    CONSTRAINT pk_smlouva PRIMARY KEY (smlouva_hkey) NOT ENFORCED
)
USING DELTA
COMMENT 'Konformovaná pojistná smlouva. Jedna entita pro život i neživot, plněná výhradně z přehledových topiků TIA a KDP, a to jen u záznamů, které splní všechny tři podmínky: mají vyplněné smlouva_cislo, spolecnost_kod odpovídá CompanyID v ruční mapovací tabulce a stav_smlouvy_kod odpovídá KodStav v téže tabulce s hodnotou NazevStavSalesCockpit rovnou "Úspěch". Záznamy z TIA a KDP, které podmínku nesplní, jdou do entity Návrh. Protože pro tuto entitu je smlouva_cislo vždy vyplněné, tvoří spolu se zdrojova_aplikace_id jednoznačný identifikátor řádku. Instance produktů, partneři ve svých rolích a spravující obchodníci jsou vnořeni; údaje o partnerovi jsou účelové a platné jen pro tuto smlouvu.'
CLUSTER BY (smlouva_hkey)
TBLPROPERTIES (
    'delta.columnMapping.mode'   = 'name',
    'delta.enableChangeDataFeed' = 'true',
    'model.layer'                = 'silver',
    'model.table_kind'           = 'current'
);
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.smlouva SET TAGS ('description_en' = 'Conformed insurance contract. Fed only from the TIA and KDP overview topics, and only for records that satisfy all three conditions: the contract number is filled, the company code matches CompanyID in the manual mapping table, and the status code matches KodStav there with NazevStavSalesCockpit equal to "Úspěch". Records from TIA and KDP that fail the condition go to the Proposal entity. Since the contract number is always filled here, it forms the row identifier together with the source application id.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.smlouva ALTER COLUMN smlouva_hkey SET TAGS ('description_en' = 'Hash of the natural key (smlouva_cislo + zdrojova_aplikace_id). Identifies the entity, is stable across versions and serves both as the reference target and as the dbt snapshot unique_key.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.smlouva ALTER COLUMN pojistne_odvetvi_kod SET TAGS ('description_en' = 'LIFE or NONLIFE, derived from the topic. It is not part of the key, because the sourceapplication already tells the branches apart.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.smlouva ALTER COLUMN smlouva_cislo SET TAGS ('description_en' = 'Unique and public identifier of the contract. Together with the source application id it uniquely identifies the row; for this entity it is always filled.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.smlouva ALTER COLUMN nadrizena_smlouva_hkey SET TAGS ('description_en' = 'Framework contract this contract belongs to.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.smlouva ALTER COLUMN ramcova_smlouva_priznak SET TAGS ('description_en' = 'TRUE when the contract is itself a framework contract.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.smlouva ALTER COLUMN stav_smlouvy_kod SET TAGS ('description_en' = 'Status of the contract or the pre-contract state.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.smlouva ALTER COLUMN spolecnost_kod SET TAGS ('description_en' = 'Group company that is the insurer.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.smlouva ALTER COLUMN aplikace_kod SET TAGS ('description_en' = 'Source application the contract is administered in.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.smlouva ALTER COLUMN balicek_produktu_kod SET TAGS ('description_en' = 'Catalogue product bundle. Non-life only.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.smlouva ALTER COLUMN zivotni_znacka_kod SET TAGS ('description_en' = 'Catalogue life brand. Life only.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.smlouva ALTER COLUMN datum_podpisu SET TAGS ('description_en' = 'Date the contract was signed. The source changes this value on re-signature andpre-fills it with an expected date before signature, so on its own it is not areliable date of creation.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.smlouva ALTER COLUMN datum_vzniku_smlouvy SET TAGS ('description_en' = 'Date the contract first reached the contract state. Derived by the load, which keepsthe first observed signed date and does not let a re-signature move it.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.smlouva ALTER COLUMN platnost_od_datum SET TAGS ('description_en' = 'Start of the insurance cover.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.smlouva ALTER COLUMN platnost_do_datum SET TAGS ('description_en' = 'End of the insurance cover.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.smlouva ALTER COLUMN puvodni_platnost_do_datum SET TAGS ('description_en' = 'Originally agreed end of cover.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.smlouva ALTER COLUMN datum_zruseni SET TAGS ('description_en' = 'Date the contract was cancelled.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.smlouva ALTER COLUMN datum_obnovy SET TAGS ('description_en' = 'Date of the next renewal.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.smlouva ALTER COLUMN verze_platnost_od_datum SET TAGS ('description_en' = 'Start of validity of this version in the source.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.smlouva ALTER COLUMN frekvence_platby_kod SET TAGS ('description_en' = 'How often the premium is paid.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.smlouva ALTER COLUMN termin_aktivacni_platby_datum SET TAGS ('description_en' = 'Deadline for the activating payment.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.smlouva ALTER COLUMN rocni_pojistne_castka SET TAGS ('description_en' = 'Yearly premium of the whole contract.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.smlouva ALTER COLUMN legacy_navrh_cislo SET TAGS ('description_en' = 'Quotation number from the legacy Generali system.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.smlouva ALTER COLUMN legacy_duvod_zruseni_popis SET TAGS ('description_en' = 'Cancellation reason from the legacy Generali system.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.smlouva ALTER COLUMN instance_produktu SET TAGS ('description_en' = 'Products placed on the contract, with vehicles and property locations nested one level deeper.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.smlouva ALTER COLUMN partner_role SET TAGS ('description_en' = 'Parties on the contract with their roles and purpose-specific details.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.smlouva ALTER COLUMN ucast_obchodnika SET TAGS ('description_en' = 'Agents administering the contract, with their acquisition number, ordering andcommission share.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.smlouva ALTER COLUMN zmenu_provedl_login SET TAGS ('description_en' = 'Domain login of the user who last changed the record in the source system.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.smlouva ALTER COLUMN zdrojova_aplikace_id SET TAGS ('description_en' = 'Identifier of the source application the contract is administered in. Together withthe contract number it forms the natural key, and on a delete event it tells TIA apartfrom KDP.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.smlouva ALTER COLUMN __zdrojovy_system SET TAGS ('description_en' = 'Source system the record was loaded from, taken from the __source_system metadata column of the bronze table.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.smlouva ALTER COLUMN __zdrojova_tabulka_nazev SET TAGS ('description_en' = 'Fully qualified bronze table the record was loaded from. For conformed entities fedfrom several bronze tables it is the only value that tells the origin of a row apart.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.smlouva ALTER COLUMN smazano_priznak SET TAGS ('description_en' = 'TRUE when the source reported the record as deleted. Soft delete; the row is kept.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.smlouva ALTER COLUMN hash_instance_produktu SET TAGS ('description_en' = 'Diagnostic hash of the nested column product_instance. It does not take part in the version decision.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.smlouva ALTER COLUMN hash_partner_role SET TAGS ('description_en' = 'Diagnostic hash of the nested column party_role. It does not take part in the version decision.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.smlouva ALTER COLUMN hash_ucast_obchodnika SET TAGS ('description_en' = 'Diagnostic hash of the nested column agent_participation. It does not take part in the version decision.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.smlouva ALTER COLUMN platnost_od_ts SET TAGS ('description_en' = 'Point in time from which this version is valid, taken from the source change timestamp.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.smlouva ALTER COLUMN hash_zaznamu SET TAGS ('description_en' = 'The decision hash over all business columns and the only column in the dbt check_cols. Nested arrays must be sorted by a stable key before hashing.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.smlouva ALTER COLUMN __nacteno_ts SET TAGS ('description_en' = 'Timestamp of when the record was inserted into this silver table.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.smlouva ALTER COLUMN smlouva_hkey SET TAGS ('data_classification' = 'confidential');

-- ========================= dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.smlouva_hist =========================
-- SCD2 history | grain: Jeden řádek na smlouvu | sources: TIA, KDP
CREATE TABLE IF NOT EXISTS dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.smlouva_hist (
    smlouva_hkey                   STRING NOT NULL  COMMENT 'Hash přirozeného klíče (smlouva_cislo + zdrojova_aplikace_id). Identifikuje entitu, je stabilní napříč verzemi a slouží jako cíl odkazů z jiných entit i jako unique_key snapshotu v dbt.',
    pojistne_odvetvi_kod           STRING NOT NULL  COMMENT 'ZIVOT nebo NEZIVOT. Odvozeno z topiku; není součástí klíče, protože ten už odvětví rozlišuje přes zdrojovou aplikaci.',
    smlouva_cislo                  BIGINT NOT NULL  COMMENT 'Unikátní a veřejný identifikátor smlouvy, ve zdroji označovaný jako číslo smlouvy. Spolu se zdrojova_aplikace_id jednoznačně identifikuje řádek; pro tuto entitu je vždy vyplněn.',
    nadrizena_smlouva_hkey         STRING  COMMENT 'Rámcová smlouva, ke které tato smlouva patří.',
    ramcova_smlouva_priznak        BOOLEAN NOT NULL  COMMENT 'TRUE, když je smlouva sama rámcovou smlouvou.',
    stav_smlouvy_kod               INT NOT NULL  COMMENT 'Stav smlouvy nebo stavu před uzavřením.',
    spolecnost_kod                 BIGINT NOT NULL  COMMENT 'Společnost skupiny, která je pojistitelem.',
    aplikace_kod                   INT NOT NULL  COMMENT 'Zdrojová aplikace, ve které je smlouva spravována.',
    balicek_produktu_kod           STRING  COMMENT 'Katalogový balíček produktů. Pouze neživot.',
    zivotni_znacka_kod             BIGINT  COMMENT 'Katalogová životní značka. Pouze život.',
    datum_podpisu                  DATE  COMMENT 'Datum podpisu smlouvy. Zdroj hodnotu mění při novém podpisu a před podpisem ji vyplňuje předpokládaným datem, takže sama o sobě není spolehlivým datem vzniku.',
    datum_vzniku_smlouvy           DATE  COMMENT 'Datum, kdy se smlouva poprvé dostala do stavu smlouvy. Plnění si drží první zachycené datum podpisu a nedovolí novému podpisu s ním pohnout.',
    platnost_od_datum              DATE  COMMENT 'Počátek pojistné ochrany.',
    platnost_do_datum              DATE  COMMENT 'Konec pojistné ochrany.',
    puvodni_platnost_do_datum      DATE  COMMENT 'Původně sjednaný konec pojistné ochrany.',
    datum_zruseni                  DATE  COMMENT 'Datum zrušení smlouvy.',
    datum_obnovy                   DATE  COMMENT 'Datum nejbližší obnovy.',
    verze_platnost_od_datum        DATE  COMMENT 'Počátek platnosti této verze smlouvy ve zdroji.',
    frekvence_platby_kod           INT NOT NULL  COMMENT 'Jak často se platí pojistné.',
    termin_aktivacni_platby_datum  DATE  COMMENT 'Termín pro aktivační platbu.',
    rocni_pojistne_castka          DECIMAL(38,2) NOT NULL  COMMENT 'Roční pojistné celé smlouvy.',
    legacy_navrh_cislo             STRING  COMMENT 'Číslo návrhu ze starého systému Generali.',
    legacy_duvod_zruseni_popis     STRING  COMMENT 'Důvod zrušení ze starého systému Generali.',
    instance_produktu              
        ARRAY<STRUCT<`produkt_kod`: INT, `sjednana_rada_cislo`: BIGINT, `stav_instance_kod`: INT, `datum_podpisu`: DATE, `platnost_od_datum`: DATE, `platnost_do_datum`: DATE, `rocni_pojistne_castka`: DECIMAL(38,2), `vozidlo`: ARRAY<STRUCT<`vin`: STRING, `registracni_znacka`: STRING, `znacka_nazev`: STRING, `typ_nazev`: STRING, `kategorie_kod`: STRING, `rok_vyroby`: INT, `objem_motoru_hodnota`: INT, `vykon_motoru_hodnota`: INT>>, `misto_pojisteni`: ARRAY<STRUCT<`stat_kod`: STRING, `obec_nazev`: STRING, `cast_obce_nazev`: STRING, `ulice_nazev`: STRING, `cislo_orientacni`: STRING, `cislo_popisne`: STRING, `cislo_evidencni`: STRING, `psc`: STRING, `ruian_adresni_bod_kod`: BIGINT, `katastralni_uzemi_id`: BIGINT, `katastralni_uzemi_nazev`: STRING, `parcela_cislo`: STRING, `parcela_podlomeni`: STRING>>>> NOT NULL  COMMENT 'Produkty umístěné na smlouvě. Životní smlouva má právě jednu instanci, neživotní jednu nebo více. Vozidla a místa pojištění jsou vnořena o úroveň níž.',
    partner_role                   
        ARRAY<STRUCT<`partner_id`: STRING, `typ_role_kod`: INT, `zaznam_partnera_ext_id`: BIGINT, `pravni_typ_kod`: INT, `typ_partnera_kod`: STRING, `jmeno`: STRING, `prijmeni`: STRING, `nazev_partnera`: STRING, `titul_pred`: STRING, `titul_za`: STRING, `datum_narozeni`: DATE, `rodne_cislo`: STRING, `datum_umrti`: DATE, `pohlavi_kod`: INT, `statni_prislusnost_kod`: STRING, `ico`: STRING, `stat_registrace_kod`: STRING, `registrovany_nazev`: STRING, `pravni_forma_kod`: INT, `organ_vm_priznak`: BOOLEAN, `datum_ukonceni_cinnosti`: DATE, `adresa`: ARRAY<STRUCT<`typ_pouziti_kod`: STRING, `ext_id`: BIGINT, `stat_kod`: STRING, `obec_nazev`: STRING, `cast_obce_nazev`: STRING, `ulice_nazev`: STRING, `cislo_orientacni`: STRING, `cislo_popisne`: STRING, `cislo_evidencni`: STRING, `psc`: STRING, `pokyn_doruceni_popis`: STRING, `ruian_adresni_bod_kod`: BIGINT>>, `telefon`: ARRAY<STRUCT<`typ_telefonu_kod`: STRING, `ext_id`: BIGINT, `cele_cislo`: STRING, `mezinarodni_predvolba`: INT, `narodni_cislo`: STRING>>, `email`: ARRAY<STRUCT<`ext_id`: BIGINT, `emailova_adresa`: STRING>>>> NOT NULL  COMMENT 'Partneři na smlouvě s rolemi a účelovými údaji platnými pro tuto smlouvu. Jeden partner může mít více rolí.',
    ucast_obchodnika               
        ARRAY<STRUCT<`obchodnik_hkey`: STRING, `obchodnik_login`: STRING, `typ_ucasti_kod`: STRING, `role_kod`: ARRAY<STRING>, `ziskatelske_cislo`: BIGINT, `osobni_cislo`: BIGINT, `podobchodnik_login`: STRING, `provizni_podil_castka`: DECIMAL(38,2), `poradi`: INT>>  COMMENT 'Obchodníci spravující smlouvu, se získatelským číslem, pořadím a provizním podílem.',
    zmenu_provedl_login            STRING  COMMENT 'Domain login uživatele, který záznam ve zdrojovém systému naposledy změnil.',
    zdrojova_aplikace_id           INT NOT NULL  COMMENT 'Identifikátor zdrojové aplikace, ve které je smlouva spravována. Spolu se smlouva_cislo tvoří přirozený klíč a u mazání se jím rozliší, zda zpráva přišla z TIA nebo z KDP.',
    __zdrojovy_system              STRING NOT NULL  COMMENT 'Zdrojový systém, ze kterého byl záznam načten. Přebírá se z metadatového sloupce __source_system odpovídající bronze tabulky.',
    __zdrojova_tabulka_nazev       STRING NOT NULL  COMMENT 'Plně kvalifikovaná bronze tabulka, ze které byl záznam načten. U konformovaných entit plněných z více bronze tabulek je to jediný údaj, který rozliší původ konkrétního řádku.',
    smazano_priznak                BOOLEAN NOT NULL  COMMENT 'TRUE, když zdroj oznámil smazání záznamu. Logické smazání, řádek zůstává, aby zůstala dohledatelná historie i odkazy.',
    hash_instance_produktu         STRING  COMMENT 'Diagnostický hash vnořeného sloupce instance_produktu. Neúčastní se rozhodnutí o nové verzi, slouží jen ke zjištění, která oblast se změnila. Pole se před hashováním řadí podle stabilního klíče.',
    hash_partner_role              STRING  COMMENT 'Diagnostický hash vnořeného sloupce partner_role. Neúčastní se rozhodnutí o nové verzi, slouží jen ke zjištění, která oblast se změnila. Pole se před hashováním řadí podle stabilního klíče.',
    hash_ucast_obchodnika          STRING  COMMENT 'Diagnostický hash vnořeného sloupce ucast_obchodnika. Neúčastní se rozhodnutí o nové verzi, slouží jen ke zjištění, která oblast se změnila. Pole se před hashováním řadí podle stabilního klíče.',
    verze_id                       STRING NOT NULL  COMMENT 'Identifikátor jedné verze záznamu, md5 hash přirozeného klíče a indikátoru změny, takže se liší verzi od verze. U snapshotů ho plní dbt jako dbt_scd_id, u inkrementálních tabulek ho stejným způsobem počítá plnění. Není to identita entity - tu nese <entita>_hkey, který zůstává napříč verzemi stejný.',
    platnost_od_ts                 TIMESTAMP NOT NULL  COMMENT 'Okamžik, od kterého byla tato verze platná. U inkrementálních tabulek čas poslední změny ve zdroji, u snapshotů čas běhu, kdy byl stav pozorován.',
    platnost_do_ts                 TIMESTAMP NOT NULL  COMMENT 'Okamžik, do kterého byla verze platná. Otevřená verze nese 9999-12-31 místo NULL, aby porovnávání období nemuselo řešit NULL. Otevřená verze je právě ta, která je v tabulce aktuálního stavu.',
    hash_zaznamu                   STRING NOT NULL  COMMENT 'Rozhodovací hash přes všechny byznysové sloupce této verze. Technické sloupce do hashe nevstupují a vnořená pole se před hashováním řadí podle stabilního klíče.',
    __nacteno_ts                   TIMESTAMP NOT NULL  COMMENT 'Časové razítko, kdy byla verze vložena do této silver tabulky.',
    CONSTRAINT pk_smlouva_hist PRIMARY KEY (smlouva_hkey, platnost_od_ts) NOT ENFORCED
)
USING DELTA
COMMENT 'Historie SCD2 entity smlouva. Jeden řádek na verzi, platnou mezi platnost_od_ts a platnost_do_ts. Konformovaná pojistná smlouva. Jedna entita pro život i neživot, plněná výhradně z přehledových topiků TIA a KDP, a to jen u záznamů, které splní všechny tři podmínky: mají vyplněné smlouva_cislo, spolecnost_kod odpovídá CompanyID v ruční mapovací tabulce a stav_smlouvy_kod odpovídá KodStav v téže tabulce s hodnotou NazevStavSalesCockpit rovnou "Úspěch". Záznamy z TIA a KDP, které podmínku nesplní, jdou do entity Návrh. Protože pro tuto entitu je smlouva_cislo vždy vyplněné, tvoří spolu se zdrojova_aplikace_id jednoznačný identifikátor řádku. Instance produktů, partneři ve svých rolích a spravující obchodníci jsou vnořeni; údaje o partnerovi jsou účelové a platné jen pro tuto smlouvu.'
CLUSTER BY (smlouva_hkey, platnost_od_ts)
TBLPROPERTIES (
    'delta.columnMapping.mode'   = 'name',
    'delta.enableChangeDataFeed' = 'true',
    'model.layer'                = 'silver',
    'model.table_kind'           = 'history'
);
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.smlouva_hist SET TAGS ('description_en' = 'SCD2 history of contract, one row per version valid between valid_from_timestamp and valid_to_timestamp. Conformed insurance contract. Fed only from the TIA and KDP overview topics, and only for records that satisfy all three conditions: the contract number is filled, the company code matches CompanyID in the manual mapping table, and the status code matches KodStav there with NazevStavSalesCockpit equal to "Úspěch". Records from TIA and KDP that fail the condition go to the Proposal entity. Since the contract number is always filled here, it forms the row identifier together with the source application id.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.smlouva_hist ALTER COLUMN smlouva_hkey SET TAGS ('description_en' = 'Hash of the natural key (smlouva_cislo + zdrojova_aplikace_id). Identifies the entity, is stable across versions and serves both as the reference target and as the dbt snapshot unique_key.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.smlouva_hist ALTER COLUMN pojistne_odvetvi_kod SET TAGS ('description_en' = 'LIFE or NONLIFE, derived from the topic. It is not part of the key, because the sourceapplication already tells the branches apart.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.smlouva_hist ALTER COLUMN smlouva_cislo SET TAGS ('description_en' = 'Unique and public identifier of the contract. Together with the source application id it uniquely identifies the row; for this entity it is always filled.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.smlouva_hist ALTER COLUMN nadrizena_smlouva_hkey SET TAGS ('description_en' = 'Framework contract this contract belongs to.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.smlouva_hist ALTER COLUMN ramcova_smlouva_priznak SET TAGS ('description_en' = 'TRUE when the contract is itself a framework contract.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.smlouva_hist ALTER COLUMN stav_smlouvy_kod SET TAGS ('description_en' = 'Status of the contract or the pre-contract state.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.smlouva_hist ALTER COLUMN spolecnost_kod SET TAGS ('description_en' = 'Group company that is the insurer.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.smlouva_hist ALTER COLUMN aplikace_kod SET TAGS ('description_en' = 'Source application the contract is administered in.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.smlouva_hist ALTER COLUMN balicek_produktu_kod SET TAGS ('description_en' = 'Catalogue product bundle. Non-life only.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.smlouva_hist ALTER COLUMN zivotni_znacka_kod SET TAGS ('description_en' = 'Catalogue life brand. Life only.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.smlouva_hist ALTER COLUMN datum_podpisu SET TAGS ('description_en' = 'Date the contract was signed. The source changes this value on re-signature andpre-fills it with an expected date before signature, so on its own it is not areliable date of creation.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.smlouva_hist ALTER COLUMN datum_vzniku_smlouvy SET TAGS ('description_en' = 'Date the contract first reached the contract state. Derived by the load, which keepsthe first observed signed date and does not let a re-signature move it.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.smlouva_hist ALTER COLUMN platnost_od_datum SET TAGS ('description_en' = 'Start of the insurance cover.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.smlouva_hist ALTER COLUMN platnost_do_datum SET TAGS ('description_en' = 'End of the insurance cover.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.smlouva_hist ALTER COLUMN puvodni_platnost_do_datum SET TAGS ('description_en' = 'Originally agreed end of cover.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.smlouva_hist ALTER COLUMN datum_zruseni SET TAGS ('description_en' = 'Date the contract was cancelled.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.smlouva_hist ALTER COLUMN datum_obnovy SET TAGS ('description_en' = 'Date of the next renewal.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.smlouva_hist ALTER COLUMN verze_platnost_od_datum SET TAGS ('description_en' = 'Start of validity of this version in the source.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.smlouva_hist ALTER COLUMN frekvence_platby_kod SET TAGS ('description_en' = 'How often the premium is paid.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.smlouva_hist ALTER COLUMN termin_aktivacni_platby_datum SET TAGS ('description_en' = 'Deadline for the activating payment.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.smlouva_hist ALTER COLUMN rocni_pojistne_castka SET TAGS ('description_en' = 'Yearly premium of the whole contract.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.smlouva_hist ALTER COLUMN legacy_navrh_cislo SET TAGS ('description_en' = 'Quotation number from the legacy Generali system.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.smlouva_hist ALTER COLUMN legacy_duvod_zruseni_popis SET TAGS ('description_en' = 'Cancellation reason from the legacy Generali system.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.smlouva_hist ALTER COLUMN instance_produktu SET TAGS ('description_en' = 'Products placed on the contract, with vehicles and property locations nested one level deeper.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.smlouva_hist ALTER COLUMN partner_role SET TAGS ('description_en' = 'Parties on the contract with their roles and purpose-specific details.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.smlouva_hist ALTER COLUMN ucast_obchodnika SET TAGS ('description_en' = 'Agents administering the contract, with their acquisition number, ordering andcommission share.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.smlouva_hist ALTER COLUMN zmenu_provedl_login SET TAGS ('description_en' = 'Domain login of the user who last changed the record in the source system.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.smlouva_hist ALTER COLUMN zdrojova_aplikace_id SET TAGS ('description_en' = 'Identifier of the source application the contract is administered in. Together withthe contract number it forms the natural key, and on a delete event it tells TIA apartfrom KDP.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.smlouva_hist ALTER COLUMN __zdrojovy_system SET TAGS ('description_en' = 'Source system the record was loaded from, taken from the __source_system metadata column of the bronze table.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.smlouva_hist ALTER COLUMN __zdrojova_tabulka_nazev SET TAGS ('description_en' = 'Fully qualified bronze table the record was loaded from. For conformed entities fedfrom several bronze tables it is the only value that tells the origin of a row apart.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.smlouva_hist ALTER COLUMN smazano_priznak SET TAGS ('description_en' = 'TRUE when the source reported the record as deleted. Soft delete; the row is kept.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.smlouva_hist ALTER COLUMN hash_instance_produktu SET TAGS ('description_en' = 'Diagnostic hash of the nested column product_instance. It does not take part in the version decision.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.smlouva_hist ALTER COLUMN hash_partner_role SET TAGS ('description_en' = 'Diagnostic hash of the nested column party_role. It does not take part in the version decision.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.smlouva_hist ALTER COLUMN hash_ucast_obchodnika SET TAGS ('description_en' = 'Diagnostic hash of the nested column agent_participation. It does not take part in the version decision.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.smlouva_hist ALTER COLUMN verze_id SET TAGS ('description_en' = 'Identifier of a single version, an md5 hash of the natural key and the change indicator. Filled by dbt_scd_id on snapshots and computed the same way by the load on incremental tables. It is not the entity identity.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.smlouva_hist ALTER COLUMN platnost_od_ts SET TAGS ('description_en' = 'Point in time from which this version was valid. Part of the history primary key.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.smlouva_hist ALTER COLUMN platnost_do_ts SET TAGS ('description_en' = 'Point in time until which this version was valid; the open version carries 9999-12-31.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.smlouva_hist ALTER COLUMN hash_zaznamu SET TAGS ('description_en' = 'The decision hash over all business columns of this version.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.smlouva_hist ALTER COLUMN __nacteno_ts SET TAGS ('description_en' = 'Timestamp of when the version was inserted into this silver table.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.smlouva_hist ALTER COLUMN smlouva_hkey SET TAGS ('data_classification' = 'confidential');

-- ========================= dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.navrh =========================
-- current state | grain: Jeden řádek na návrh | sources: TIA, KDP, HUGO, LISA
CREATE TABLE IF NOT EXISTS dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.navrh (
    navrh_hkey                     STRING NOT NULL  COMMENT 'Hash přirozeného klíče (navrh_identifikator + zdrojova_aplikace_id). Identifikuje entitu, je stabilní napříč verzemi a slouží jako cíl odkazů z jiných entit i jako unique_key snapshotu v dbt.',
    pojistne_odvetvi_kod           STRING NOT NULL  COMMENT 'ZIVOT nebo NEZIVOT. Odvozeno z topiku; není součástí klíče, protože ten už odvětví rozlišuje přes zdrojovou aplikaci.',
    navrh_identifikator            STRING NOT NULL  COMMENT 'Jednoznačný identifikátor návrhu, plněný vlastním povinným identifikátorem každého zdroje: číslem smlouvy z TIA a KDP, identifikátorem prodeje z HUGO a číslem prodejního případu z LISA. Všechny čtyři zdroje svůj identifikátor vždy vyplňují a nikdy ho nemění, takže klíč přežije i okamžik, kdy systém správy smluv teprve přidělí číslo smlouvy. Spolu se zdrojova_aplikace_id jednoznačně identifikuje řádek.',
    smlouva_cislo                  BIGINT  COMMENT 'Číslo smlouvy, ke které návrh vede. U záznamů z HUGO a LISA bývá prázdné, dokud ho systém správy smluv nepřidělí; u záznamů z TIA a KDP je vyplněné vždy a shoduje se s navrh_identifikator.',
    smlouva_hkey                   STRING  COMMENT 'Smlouva, ke které návrh vede, pokud už existuje. Dohledá se podle smlouva_cislo a zdrojové aplikace podle odvětví: TIA pro NEZIVOT, KDP pro ZIVOT. U návrhů z TIA a KDP jde o přímou shodu, protože jejich vlastní zdrojova_aplikace_id už je správní aplikací; u návrhů z HUGO a LISA jde o překlad HUGO na TIA a LISA na KDP. Dokud smlouva neexistuje nebo číslo chybí, zůstává prázdné a doplní se při dalším běhu.',
    stav_navrhu_kod                INT NOT NULL  COMMENT 'Stav návrhu.',
    spolecnost_kod                 BIGINT NOT NULL  COMMENT 'Společnost skupiny, která by byla pojistitelem.',
    aplikace_kod                   INT NOT NULL  COMMENT 'Zdrojová aplikace. Tímto se také rozliší HUGO od LISA.',
    balicek_produktu_kod           STRING  COMMENT 'Katalogový balíček produktů. Hodnota FA označuje rámcovou smlouvu.',
    ramcova_smlouva_priznak        BOOLEAN NOT NULL  COMMENT 'TRUE pro návrh na rámcovou smlouvu. Odvozeno z super na životním topiku a z kódu balíčku FA na neživotním, což je rozdíl, který musí konformace vstřebat.',
    datum_vzniku_pripadu           DATE NOT NULL  COMMENT 'Datum vzniku prodejního případu. Nemění se, na rozdíl od data podpisu na smlouvě.',
    datum_ucinnosti_zmeny          DATE  COMMENT 'Datum účinnosti změny. Pouze neživot.',
    datum_podpisu                  DATE  COMMENT 'Datum podpisu návrhu. Aktuální verze životního návrhového schématu tuto položku nenese, u neživota ji návrhový topik nemá vůbec, takže zůstává nenaplněné, dokud ji zdroj nezačne posílat.',
    platnost_od_datum              DATE  COMMENT 'Počátek navrhované pojistné ochrany.',
    platnost_do_datum              DATE  COMMENT 'Konec navrhované pojistné ochrany.',
    frekvence_platby_kod           INT NOT NULL  COMMENT 'Jak často by se platilo pojistné.',
    rocni_pojistne_castka          DECIMAL(38,2)  COMMENT 'Navrhované roční pojistné. Od verze schématu v1_1 je na neživotním topiku nepovinné.',
    zakladni_pojistne_castka       DECIMAL(38,2)  COMMENT 'Základní pojistné před slevami a přirážkami. Pouze neživot.',
    pojistne_po_slevach_castka     DECIMAL(38,2)  COMMENT 'Pojistné za období po slevách. Pouze život.',
    typ_udalosti_kod               STRING  COMMENT 'Typ události životní návrhu. Pouze život.',
    zivotni_znacka_kod             BIGINT  COMMENT 'Katalogová životní značka. Pouze život.',
    technicky_id                   STRING  COMMENT 'Technický identifikátor návrhu v systému LISA. Identifikuje úroveň pod prodejním případem, takže nejde o přirozený klíč entity.',
    nadrizena_smlouva_cislo        BIGINT  COMMENT 'Číslo rámcové smlouvy, ke které návrh patří. Pouze život.',
    termin_aktivacni_platby_datum  DATE  COMMENT 'Termín pro aktivační platbu. Pouze neživot.',
    pripad_cislo                   STRING  COMMENT 'Číslo prodejního případu. U neživota samostatný údaj, u života shodný s navrh_identifikator.',
    zmenu_provedl_login            STRING  COMMENT 'Domain login uživatele, který návrh naposledy změnil. Neživotní sales cockpit ho nese jako lastUpdatedBy, životní ho zatím neposílá.',
    instance_produktu              
        ARRAY<STRUCT<`produkt_kod`: INT, `sjednana_rada_cislo`: BIGINT, `stav_instance_kod`: INT, `datum_podpisu`: DATE, `platnost_od_datum`: DATE, `platnost_do_datum`: DATE, `rocni_pojistne_castka`: DECIMAL(38,2), `vozidlo`: ARRAY<STRUCT<`vin`: STRING, `registracni_znacka`: STRING, `znacka_nazev`: STRING, `typ_nazev`: STRING, `kategorie_kod`: STRING, `rok_vyroby`: INT, `objem_motoru_hodnota`: INT, `vykon_motoru_hodnota`: INT>>, `misto_pojisteni`: ARRAY<STRUCT<`stat_kod`: STRING, `obec_nazev`: STRING, `cast_obce_nazev`: STRING, `ulice_nazev`: STRING, `cislo_orientacni`: STRING, `cislo_popisne`: STRING, `cislo_evidencni`: STRING, `psc`: STRING, `ruian_adresni_bod_kod`: BIGINT, `katastralni_uzemi_id`: BIGINT, `katastralni_uzemi_nazev`: STRING, `parcela_cislo`: STRING, `parcela_podlomeni`: STRING>>>> NOT NULL  COMMENT 'Navrhované produkty. Životní topik nese produkt přímo na návrhu, neživotní seznam instancí; konformace obojí sjednotí.',
    partner_role                   
        ARRAY<STRUCT<`partner_id`: STRING, `typ_role_kod`: INT, `zaznam_partnera_ext_id`: BIGINT, `pravni_typ_kod`: INT, `typ_partnera_kod`: STRING, `jmeno`: STRING, `prijmeni`: STRING, `nazev_partnera`: STRING, `titul_pred`: STRING, `titul_za`: STRING, `datum_narozeni`: DATE, `rodne_cislo`: STRING, `datum_umrti`: DATE, `pohlavi_kod`: INT, `statni_prislusnost_kod`: STRING, `ico`: STRING, `stat_registrace_kod`: STRING, `registrovany_nazev`: STRING, `pravni_forma_kod`: INT, `organ_vm_priznak`: BOOLEAN, `datum_ukonceni_cinnosti`: DATE, `adresa`: ARRAY<STRUCT<`typ_pouziti_kod`: STRING, `ext_id`: BIGINT, `stat_kod`: STRING, `obec_nazev`: STRING, `cast_obce_nazev`: STRING, `ulice_nazev`: STRING, `cislo_orientacni`: STRING, `cislo_popisne`: STRING, `cislo_evidencni`: STRING, `psc`: STRING, `pokyn_doruceni_popis`: STRING, `ruian_adresni_bod_kod`: BIGINT>>, `telefon`: ARRAY<STRUCT<`typ_telefonu_kod`: STRING, `ext_id`: BIGINT, `cele_cislo`: STRING, `mezinarodni_predvolba`: INT, `narodni_cislo`: STRING>>, `email`: ARRAY<STRUCT<`ext_id`: BIGINT, `emailova_adresa`: STRING>>>> NOT NULL  COMMENT 'Partneři na návrhu s rolemi a účelovými údaji platnými pro tento návrh. Topiky sales cockpitu nesou od verze schématu v1_1 jediného partnera v položce partyInPolicy, takže z HUGO a LISA má pole nejvýše jeden prvek; přehledové topiky TIA a KDP nesou pole partiesInPolicy s jedním nebo více partnery. Neživotní topik nese všechny tři právní typy, životní jen fyzickou a právnickou osobu.',
    ucast_obchodnika               
        ARRAY<STRUCT<`obchodnik_hkey`: STRING, `obchodnik_login`: STRING, `typ_ucasti_kod`: STRING, `role_kod`: ARRAY<STRING>, `ziskatelske_cislo`: BIGINT, `osobni_cislo`: BIGINT, `podobchodnik_login`: STRING, `provizni_podil_castka`: DECIMAL(38,2), `poradi`: INT>> NOT NULL  COMMENT 'Obchodníci zpracovávající návrh. Konformováno ze seznamů akvizitérů a realizátorů MTA neživotního topiku a ze seznamu obchodníků životního topiku.',
    zdrojova_aplikace_id           INT NOT NULL  COMMENT 'Identifikátor zdrojové aplikace, ve které návrh vznikl. Rozliší všechny čtyři zdroje od sebe a spolu s navrh_identifikator tvoří přirozený klíč. Díky němu může tatáž obchodní příležitost existovat zvlášť jako záznam z HUGO a zvlášť jako předsmluvní stav z TIA, protože TIA žádný identifikátor z HUGO nenese a spojit je lze teprve po přidělení čísla smlouvy.',
    __zdrojovy_system              STRING NOT NULL  COMMENT 'Zdrojový systém, ze kterého byl záznam načten. Přebírá se z metadatového sloupce __source_system odpovídající bronze tabulky.',
    __zdrojova_tabulka_nazev       STRING NOT NULL  COMMENT 'Plně kvalifikovaná bronze tabulka, ze které byl záznam načten. U konformovaných entit plněných z více bronze tabulek je to jediný údaj, který rozliší původ konkrétního řádku.',
    smazano_priznak                BOOLEAN NOT NULL  COMMENT 'TRUE, když zdroj oznámil smazání záznamu. Logické smazání, řádek zůstává, aby zůstala dohledatelná historie i odkazy.',
    hash_instance_produktu         STRING  COMMENT 'Diagnostický hash vnořeného sloupce instance_produktu. Neúčastní se rozhodnutí o nové verzi, slouží jen ke zjištění, která oblast se změnila. Pole se před hashováním řadí podle stabilního klíče.',
    hash_partner_role              STRING  COMMENT 'Diagnostický hash vnořeného sloupce partner_role. Neúčastní se rozhodnutí o nové verzi, slouží jen ke zjištění, která oblast se změnila. Pole se před hashováním řadí podle stabilního klíče.',
    hash_ucast_obchodnika          STRING  COMMENT 'Diagnostický hash vnořeného sloupce ucast_obchodnika. Neúčastní se rozhodnutí o nové verzi, slouží jen ke zjištění, která oblast se změnila. Pole se před hashováním řadí podle stabilního klíče.',
    platnost_od_ts                 TIMESTAMP NOT NULL  COMMENT 'Okamžik, od kterého je tato verze řádku platná. U inkrementálních tabulek se plní časem poslední změny ve zdroji: u sync topiků z dataUpdatedAt, u delete topiků z auditInformation.lastUpdatedAt. U tabulek plněných snapshotem nese čas běhu, tedy okamžik, kdy jsme stav pozorovali - zdroj posílá celý snímek a vlastní čas změny u číselníků nenabízí.',
    hash_zaznamu                   STRING NOT NULL  COMMENT 'Rozhodovací hash přes všechny byznysové sloupce. Podle něj se pozná skutečná změna a v dbt je to jediný sloupec v check_cols. Technické sloupce do hashe nevstupují, jinak by vznikala nová verze při každém běhu, a vnořená pole se před hashováním řadí podle stabilního klíče, jinak by jiné pořadí prvků vypadalo jako změna.',
    __nacteno_ts                   TIMESTAMP NOT NULL  COMMENT 'Časové razítko, kdy byl záznam vložen do této silver tabulky.',
    CONSTRAINT pk_navrh PRIMARY KEY (navrh_hkey) NOT ENFORCED
)
USING DELTA
COMMENT 'Konformovaný návrh, tedy stav před uzavřením smlouvy. Jedna entita pro život i neživot, plněná ze všech čtyř zdrojů: z HUGO a LISA všechny záznamy, z TIA a KDP pouze ty, které nesplní podmínku pro zařazení do entity Smlouva, tedy nemají vyplněné číslo smlouvy nebo jejich kombinace společnosti a stavu neodpovídá v ruční mapovací tabulce hodnotě "Úspěch". Každý ze čtyř zdrojů má vlastní povinný identifikátor, který se ukládá do navrh_identifikator a spolu se zdrojova_aplikace_id tvoří přirozený klíč. Zdrojová schémata se liší víc, než jejich názvy napovídají: HUGO je klíčováno identifikátorem prodeje a nese akvizitéry a realizátory MTA, LISA číslem prodejního případu a jednoduchým seznamem obchodníků, a obě přehledová schémata číslem smlouvy.'
CLUSTER BY (navrh_hkey)
TBLPROPERTIES (
    'delta.columnMapping.mode'   = 'name',
    'delta.enableChangeDataFeed' = 'true',
    'model.layer'                = 'silver',
    'model.table_kind'           = 'current'
);
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.navrh SET TAGS ('description_en' = 'Conformed proposal, that is a pre-contract state of the sales process. One entity for life and non-life, fed from all four sources: every record from HUGO and LISA, and from TIA and KDP only those that fail the condition for the Contract entity, meaning the contract number is missing or the company and status combination does not match the value "Úspěch" in the manual mapping table. Each of the four sources has its own mandatory identifier, which is stored in the proposal identifier and together with the source application id forms the natural key. The source schemas differ more than their names suggest: HUGO is keyed by the sales identifier and carries acquirers and MTA realizators, LISA by the sales case number and a plain agent list, and both overview schemas by the contract number.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.navrh ALTER COLUMN navrh_hkey SET TAGS ('description_en' = 'Hash of the natural key (navrh_identifikator + zdrojova_aplikace_id). Identifies the entity, is stable across versions and serves both as the reference target and as the dbt snapshot unique_key.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.navrh ALTER COLUMN pojistne_odvetvi_kod SET TAGS ('description_en' = 'LIFE or NONLIFE, derived from the topic. It is not part of the key, because the sourceapplication already tells the branches apart.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.navrh ALTER COLUMN navrh_identifikator SET TAGS ('description_en' = 'Unique identifier of the proposal, filled from the mandatory identifier of each source: the contract number from TIA and KDP, the sales identifier from HUGO and the sales case number from LISA. Together with the source application id it identifies the row.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.navrh ALTER COLUMN smlouva_cislo SET TAGS ('description_en' = 'Number of the contract the proposal leads to. For records from HUGO and LISA it isusually empty until the contract administration system assigns it; for records fromTIA and KDP it is always filled and equals the proposal identifier.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.navrh ALTER COLUMN smlouva_hkey SET TAGS ('description_en' = 'Contract the proposal leads to, where it already exists. Resolved by the contractnumber and the administering application derived from the branch: TIA for non-life,KDP for life. For proposals from TIA and KDP it is a direct match; for HUGO and LISAit is a translation of HUGO to TIA and LISA to KDP. While the contract does not existit stays empty and is filled on a later run.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.navrh ALTER COLUMN stav_navrhu_kod SET TAGS ('description_en' = 'Status of the offer.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.navrh ALTER COLUMN spolecnost_kod SET TAGS ('description_en' = 'Group company that would be the insurer.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.navrh ALTER COLUMN aplikace_kod SET TAGS ('description_en' = 'Source application, which is also how HUGO is told apart from LISA.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.navrh ALTER COLUMN balicek_produktu_kod SET TAGS ('description_en' = 'Catalogue product bundle. Value FA marks a framework contract.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.navrh ALTER COLUMN ramcova_smlouva_priznak SET TAGS ('description_en' = 'TRUE when the proposal is for a framework contract. Derived from super on the lifetopic and from product bundle code FA on the non-life one, which is a difference theconformation has to absorb.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.navrh ALTER COLUMN datum_vzniku_pripadu SET TAGS ('description_en' = 'Date the sales case was created; it does not change.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.navrh ALTER COLUMN datum_ucinnosti_zmeny SET TAGS ('description_en' = 'Date the change becomes effective.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.navrh ALTER COLUMN datum_podpisu SET TAGS ('description_en' = 'Date the proposal was signed. The current life proposal schema does not carry thisitem and the non-life proposal topic has never had it, so it stays empty until asource starts sending it.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.navrh ALTER COLUMN platnost_od_datum SET TAGS ('description_en' = 'Start of the proposed cover.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.navrh ALTER COLUMN platnost_do_datum SET TAGS ('description_en' = 'End of the proposed cover.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.navrh ALTER COLUMN frekvence_platby_kod SET TAGS ('description_en' = 'How often the premium would be paid.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.navrh ALTER COLUMN rocni_pojistne_castka SET TAGS ('description_en' = 'Yearly premium proposed. Optional on the non-life topic since schema version v1_1.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.navrh ALTER COLUMN zakladni_pojistne_castka SET TAGS ('description_en' = 'Basic premium before discounts. Non-life only.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.navrh ALTER COLUMN pojistne_po_slevach_castka SET TAGS ('description_en' = 'Premium per period after discounts. Life only.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.navrh ALTER COLUMN typ_udalosti_kod SET TAGS ('description_en' = 'Type of the life offer event.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.navrh ALTER COLUMN zivotni_znacka_kod SET TAGS ('description_en' = 'Catalogue life brand. Life only.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.navrh ALTER COLUMN technicky_id SET TAGS ('description_en' = 'Technical identifier of the offer in LISA. It identifies a level below the sales case, so it is not the natural key.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.navrh ALTER COLUMN nadrizena_smlouva_cislo SET TAGS ('description_en' = 'Number of the framework contract the offer belongs to. Life only.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.navrh ALTER COLUMN termin_aktivacni_platby_datum SET TAGS ('description_en' = 'Deadline for the activating payment. Non-life only.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.navrh ALTER COLUMN pripad_cislo SET TAGS ('description_en' = 'Sales case number. A separate value for non-life; for life it equals the proposalidentifier.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.navrh ALTER COLUMN zmenu_provedl_login SET TAGS ('description_en' = 'Domain login of the user who last changed the proposal. The non-life sales cockpitcarries it as lastUpdatedBy; the life one does not send it yet.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.navrh ALTER COLUMN instance_produktu SET TAGS ('description_en' = 'Products proposed. The life topic carries the product directly on the proposal, thenon-life topic a list of instances; the conformation normalises both into this array.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.navrh ALTER COLUMN partner_role SET TAGS ('description_en' = 'Parties on the proposal with their roles and the purpose-specific details valid for this proposal. Since schema version v1_1 the sales cockpit topics carry a single party in partyInPolicy, so from HUGO and LISA the array holds at most one element; the overview topics TIA and KDP carry an array with one or more parties. The non-life topic carries all three legal types, the life one only natural and juridical persons.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.navrh ALTER COLUMN ucast_obchodnika SET TAGS ('description_en' = 'Agents handling the proposal. Conformed from the acquirer and MTA realizator lists ofthe non-life topic and the agent list of the life topic.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.navrh ALTER COLUMN zdrojova_aplikace_id SET TAGS ('description_en' = 'Identifier of the source application the proposal arose in. It tells all four sourcesapart and forms the natural key together with the proposal identifier. Thanks to itthe same business opportunity can exist separately as a record from HUGO and as apre-contract state from TIA, because TIA carries no HUGO identifier.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.navrh ALTER COLUMN __zdrojovy_system SET TAGS ('description_en' = 'Source system the record was loaded from, taken from the __source_system metadata column of the bronze table.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.navrh ALTER COLUMN __zdrojova_tabulka_nazev SET TAGS ('description_en' = 'Fully qualified bronze table the record was loaded from. For conformed entities fedfrom several bronze tables it is the only value that tells the origin of a row apart.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.navrh ALTER COLUMN smazano_priznak SET TAGS ('description_en' = 'TRUE when the source reported the record as deleted. Soft delete; the row is kept.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.navrh ALTER COLUMN hash_instance_produktu SET TAGS ('description_en' = 'Diagnostic hash of the nested column product_instance. It does not take part in the version decision.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.navrh ALTER COLUMN hash_partner_role SET TAGS ('description_en' = 'Diagnostic hash of the nested column party_role. It does not take part in the version decision.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.navrh ALTER COLUMN hash_ucast_obchodnika SET TAGS ('description_en' = 'Diagnostic hash of the nested column agent_participation. It does not take part in the version decision.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.navrh ALTER COLUMN platnost_od_ts SET TAGS ('description_en' = 'Point in time from which this version is valid, taken from the source change timestamp.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.navrh ALTER COLUMN hash_zaznamu SET TAGS ('description_en' = 'The decision hash over all business columns and the only column in the dbt check_cols. Nested arrays must be sorted by a stable key before hashing.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.navrh ALTER COLUMN __nacteno_ts SET TAGS ('description_en' = 'Timestamp of when the record was inserted into this silver table.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.navrh ALTER COLUMN navrh_hkey SET TAGS ('data_classification' = 'confidential');

-- ========================= dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.navrh_hist =========================
-- SCD2 history | grain: Jeden řádek na návrh | sources: TIA, KDP, HUGO, LISA
CREATE TABLE IF NOT EXISTS dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.navrh_hist (
    navrh_hkey                     STRING NOT NULL  COMMENT 'Hash přirozeného klíče (navrh_identifikator + zdrojova_aplikace_id). Identifikuje entitu, je stabilní napříč verzemi a slouží jako cíl odkazů z jiných entit i jako unique_key snapshotu v dbt.',
    pojistne_odvetvi_kod           STRING NOT NULL  COMMENT 'ZIVOT nebo NEZIVOT. Odvozeno z topiku; není součástí klíče, protože ten už odvětví rozlišuje přes zdrojovou aplikaci.',
    navrh_identifikator            STRING NOT NULL  COMMENT 'Jednoznačný identifikátor návrhu, plněný vlastním povinným identifikátorem každého zdroje: číslem smlouvy z TIA a KDP, identifikátorem prodeje z HUGO a číslem prodejního případu z LISA. Všechny čtyři zdroje svůj identifikátor vždy vyplňují a nikdy ho nemění, takže klíč přežije i okamžik, kdy systém správy smluv teprve přidělí číslo smlouvy. Spolu se zdrojova_aplikace_id jednoznačně identifikuje řádek.',
    smlouva_cislo                  BIGINT  COMMENT 'Číslo smlouvy, ke které návrh vede. U záznamů z HUGO a LISA bývá prázdné, dokud ho systém správy smluv nepřidělí; u záznamů z TIA a KDP je vyplněné vždy a shoduje se s navrh_identifikator.',
    smlouva_hkey                   STRING  COMMENT 'Smlouva, ke které návrh vede, pokud už existuje. Dohledá se podle smlouva_cislo a zdrojové aplikace podle odvětví: TIA pro NEZIVOT, KDP pro ZIVOT. U návrhů z TIA a KDP jde o přímou shodu, protože jejich vlastní zdrojova_aplikace_id už je správní aplikací; u návrhů z HUGO a LISA jde o překlad HUGO na TIA a LISA na KDP. Dokud smlouva neexistuje nebo číslo chybí, zůstává prázdné a doplní se při dalším běhu.',
    stav_navrhu_kod                INT NOT NULL  COMMENT 'Stav návrhu.',
    spolecnost_kod                 BIGINT NOT NULL  COMMENT 'Společnost skupiny, která by byla pojistitelem.',
    aplikace_kod                   INT NOT NULL  COMMENT 'Zdrojová aplikace. Tímto se také rozliší HUGO od LISA.',
    balicek_produktu_kod           STRING  COMMENT 'Katalogový balíček produktů. Hodnota FA označuje rámcovou smlouvu.',
    ramcova_smlouva_priznak        BOOLEAN NOT NULL  COMMENT 'TRUE pro návrh na rámcovou smlouvu. Odvozeno z super na životním topiku a z kódu balíčku FA na neživotním, což je rozdíl, který musí konformace vstřebat.',
    datum_vzniku_pripadu           DATE NOT NULL  COMMENT 'Datum vzniku prodejního případu. Nemění se, na rozdíl od data podpisu na smlouvě.',
    datum_ucinnosti_zmeny          DATE  COMMENT 'Datum účinnosti změny. Pouze neživot.',
    datum_podpisu                  DATE  COMMENT 'Datum podpisu návrhu. Aktuální verze životního návrhového schématu tuto položku nenese, u neživota ji návrhový topik nemá vůbec, takže zůstává nenaplněné, dokud ji zdroj nezačne posílat.',
    platnost_od_datum              DATE  COMMENT 'Počátek navrhované pojistné ochrany.',
    platnost_do_datum              DATE  COMMENT 'Konec navrhované pojistné ochrany.',
    frekvence_platby_kod           INT NOT NULL  COMMENT 'Jak často by se platilo pojistné.',
    rocni_pojistne_castka          DECIMAL(38,2)  COMMENT 'Navrhované roční pojistné. Od verze schématu v1_1 je na neživotním topiku nepovinné.',
    zakladni_pojistne_castka       DECIMAL(38,2)  COMMENT 'Základní pojistné před slevami a přirážkami. Pouze neživot.',
    pojistne_po_slevach_castka     DECIMAL(38,2)  COMMENT 'Pojistné za období po slevách. Pouze život.',
    typ_udalosti_kod               STRING  COMMENT 'Typ události životní návrhu. Pouze život.',
    zivotni_znacka_kod             BIGINT  COMMENT 'Katalogová životní značka. Pouze život.',
    technicky_id                   STRING  COMMENT 'Technický identifikátor návrhu v systému LISA. Identifikuje úroveň pod prodejním případem, takže nejde o přirozený klíč entity.',
    nadrizena_smlouva_cislo        BIGINT  COMMENT 'Číslo rámcové smlouvy, ke které návrh patří. Pouze život.',
    termin_aktivacni_platby_datum  DATE  COMMENT 'Termín pro aktivační platbu. Pouze neživot.',
    pripad_cislo                   STRING  COMMENT 'Číslo prodejního případu. U neživota samostatný údaj, u života shodný s navrh_identifikator.',
    zmenu_provedl_login            STRING  COMMENT 'Domain login uživatele, který návrh naposledy změnil. Neživotní sales cockpit ho nese jako lastUpdatedBy, životní ho zatím neposílá.',
    instance_produktu              
        ARRAY<STRUCT<`produkt_kod`: INT, `sjednana_rada_cislo`: BIGINT, `stav_instance_kod`: INT, `datum_podpisu`: DATE, `platnost_od_datum`: DATE, `platnost_do_datum`: DATE, `rocni_pojistne_castka`: DECIMAL(38,2), `vozidlo`: ARRAY<STRUCT<`vin`: STRING, `registracni_znacka`: STRING, `znacka_nazev`: STRING, `typ_nazev`: STRING, `kategorie_kod`: STRING, `rok_vyroby`: INT, `objem_motoru_hodnota`: INT, `vykon_motoru_hodnota`: INT>>, `misto_pojisteni`: ARRAY<STRUCT<`stat_kod`: STRING, `obec_nazev`: STRING, `cast_obce_nazev`: STRING, `ulice_nazev`: STRING, `cislo_orientacni`: STRING, `cislo_popisne`: STRING, `cislo_evidencni`: STRING, `psc`: STRING, `ruian_adresni_bod_kod`: BIGINT, `katastralni_uzemi_id`: BIGINT, `katastralni_uzemi_nazev`: STRING, `parcela_cislo`: STRING, `parcela_podlomeni`: STRING>>>> NOT NULL  COMMENT 'Navrhované produkty. Životní topik nese produkt přímo na návrhu, neživotní seznam instancí; konformace obojí sjednotí.',
    partner_role                   
        ARRAY<STRUCT<`partner_id`: STRING, `typ_role_kod`: INT, `zaznam_partnera_ext_id`: BIGINT, `pravni_typ_kod`: INT, `typ_partnera_kod`: STRING, `jmeno`: STRING, `prijmeni`: STRING, `nazev_partnera`: STRING, `titul_pred`: STRING, `titul_za`: STRING, `datum_narozeni`: DATE, `rodne_cislo`: STRING, `datum_umrti`: DATE, `pohlavi_kod`: INT, `statni_prislusnost_kod`: STRING, `ico`: STRING, `stat_registrace_kod`: STRING, `registrovany_nazev`: STRING, `pravni_forma_kod`: INT, `organ_vm_priznak`: BOOLEAN, `datum_ukonceni_cinnosti`: DATE, `adresa`: ARRAY<STRUCT<`typ_pouziti_kod`: STRING, `ext_id`: BIGINT, `stat_kod`: STRING, `obec_nazev`: STRING, `cast_obce_nazev`: STRING, `ulice_nazev`: STRING, `cislo_orientacni`: STRING, `cislo_popisne`: STRING, `cislo_evidencni`: STRING, `psc`: STRING, `pokyn_doruceni_popis`: STRING, `ruian_adresni_bod_kod`: BIGINT>>, `telefon`: ARRAY<STRUCT<`typ_telefonu_kod`: STRING, `ext_id`: BIGINT, `cele_cislo`: STRING, `mezinarodni_predvolba`: INT, `narodni_cislo`: STRING>>, `email`: ARRAY<STRUCT<`ext_id`: BIGINT, `emailova_adresa`: STRING>>>> NOT NULL  COMMENT 'Partneři na návrhu s rolemi a účelovými údaji platnými pro tento návrh. Topiky sales cockpitu nesou od verze schématu v1_1 jediného partnera v položce partyInPolicy, takže z HUGO a LISA má pole nejvýše jeden prvek; přehledové topiky TIA a KDP nesou pole partiesInPolicy s jedním nebo více partnery. Neživotní topik nese všechny tři právní typy, životní jen fyzickou a právnickou osobu.',
    ucast_obchodnika               
        ARRAY<STRUCT<`obchodnik_hkey`: STRING, `obchodnik_login`: STRING, `typ_ucasti_kod`: STRING, `role_kod`: ARRAY<STRING>, `ziskatelske_cislo`: BIGINT, `osobni_cislo`: BIGINT, `podobchodnik_login`: STRING, `provizni_podil_castka`: DECIMAL(38,2), `poradi`: INT>> NOT NULL  COMMENT 'Obchodníci zpracovávající návrh. Konformováno ze seznamů akvizitérů a realizátorů MTA neživotního topiku a ze seznamu obchodníků životního topiku.',
    zdrojova_aplikace_id           INT NOT NULL  COMMENT 'Identifikátor zdrojové aplikace, ve které návrh vznikl. Rozliší všechny čtyři zdroje od sebe a spolu s navrh_identifikator tvoří přirozený klíč. Díky němu může tatáž obchodní příležitost existovat zvlášť jako záznam z HUGO a zvlášť jako předsmluvní stav z TIA, protože TIA žádný identifikátor z HUGO nenese a spojit je lze teprve po přidělení čísla smlouvy.',
    __zdrojovy_system              STRING NOT NULL  COMMENT 'Zdrojový systém, ze kterého byl záznam načten. Přebírá se z metadatového sloupce __source_system odpovídající bronze tabulky.',
    __zdrojova_tabulka_nazev       STRING NOT NULL  COMMENT 'Plně kvalifikovaná bronze tabulka, ze které byl záznam načten. U konformovaných entit plněných z více bronze tabulek je to jediný údaj, který rozliší původ konkrétního řádku.',
    smazano_priznak                BOOLEAN NOT NULL  COMMENT 'TRUE, když zdroj oznámil smazání záznamu. Logické smazání, řádek zůstává, aby zůstala dohledatelná historie i odkazy.',
    hash_instance_produktu         STRING  COMMENT 'Diagnostický hash vnořeného sloupce instance_produktu. Neúčastní se rozhodnutí o nové verzi, slouží jen ke zjištění, která oblast se změnila. Pole se před hashováním řadí podle stabilního klíče.',
    hash_partner_role              STRING  COMMENT 'Diagnostický hash vnořeného sloupce partner_role. Neúčastní se rozhodnutí o nové verzi, slouží jen ke zjištění, která oblast se změnila. Pole se před hashováním řadí podle stabilního klíče.',
    hash_ucast_obchodnika          STRING  COMMENT 'Diagnostický hash vnořeného sloupce ucast_obchodnika. Neúčastní se rozhodnutí o nové verzi, slouží jen ke zjištění, která oblast se změnila. Pole se před hashováním řadí podle stabilního klíče.',
    verze_id                       STRING NOT NULL  COMMENT 'Identifikátor jedné verze záznamu, md5 hash přirozeného klíče a indikátoru změny, takže se liší verzi od verze. U snapshotů ho plní dbt jako dbt_scd_id, u inkrementálních tabulek ho stejným způsobem počítá plnění. Není to identita entity - tu nese <entita>_hkey, který zůstává napříč verzemi stejný.',
    platnost_od_ts                 TIMESTAMP NOT NULL  COMMENT 'Okamžik, od kterého byla tato verze platná. U inkrementálních tabulek čas poslední změny ve zdroji, u snapshotů čas běhu, kdy byl stav pozorován.',
    platnost_do_ts                 TIMESTAMP NOT NULL  COMMENT 'Okamžik, do kterého byla verze platná. Otevřená verze nese 9999-12-31 místo NULL, aby porovnávání období nemuselo řešit NULL. Otevřená verze je právě ta, která je v tabulce aktuálního stavu.',
    hash_zaznamu                   STRING NOT NULL  COMMENT 'Rozhodovací hash přes všechny byznysové sloupce této verze. Technické sloupce do hashe nevstupují a vnořená pole se před hashováním řadí podle stabilního klíče.',
    __nacteno_ts                   TIMESTAMP NOT NULL  COMMENT 'Časové razítko, kdy byla verze vložena do této silver tabulky.',
    CONSTRAINT pk_navrh_hist PRIMARY KEY (navrh_hkey, platnost_od_ts) NOT ENFORCED
)
USING DELTA
COMMENT 'Historie SCD2 entity navrh. Jeden řádek na verzi, platnou mezi platnost_od_ts a platnost_do_ts. Konformovaný návrh, tedy stav před uzavřením smlouvy. Jedna entita pro život i neživot, plněná ze všech čtyř zdrojů: z HUGO a LISA všechny záznamy, z TIA a KDP pouze ty, které nesplní podmínku pro zařazení do entity Smlouva, tedy nemají vyplněné číslo smlouvy nebo jejich kombinace společnosti a stavu neodpovídá v ruční mapovací tabulce hodnotě "Úspěch". Každý ze čtyř zdrojů má vlastní povinný identifikátor, který se ukládá do navrh_identifikator a spolu se zdrojova_aplikace_id tvoří přirozený klíč. Zdrojová schémata se liší víc, než jejich názvy napovídají: HUGO je klíčováno identifikátorem prodeje a nese akvizitéry a realizátory MTA, LISA číslem prodejního případu a jednoduchým seznamem obchodníků, a obě přehledová schémata číslem smlouvy.'
CLUSTER BY (navrh_hkey, platnost_od_ts)
TBLPROPERTIES (
    'delta.columnMapping.mode'   = 'name',
    'delta.enableChangeDataFeed' = 'true',
    'model.layer'                = 'silver',
    'model.table_kind'           = 'history'
);
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.navrh_hist SET TAGS ('description_en' = 'SCD2 history of proposal, one row per version valid between valid_from_timestamp and valid_to_timestamp. Conformed proposal, that is a pre-contract state of the sales process. One entity for life and non-life, fed from all four sources: every record from HUGO and LISA, and from TIA and KDP only those that fail the condition for the Contract entity, meaning the contract number is missing or the company and status combination does not match the value "Úspěch" in the manual mapping table. Each of the four sources has its own mandatory identifier, which is stored in the proposal identifier and together with the source application id forms the natural key. The source schemas differ more than their names suggest: HUGO is keyed by the sales identifier and carries acquirers and MTA realizators, LISA by the sales case number and a plain agent list, and both overview schemas by the contract number.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.navrh_hist ALTER COLUMN navrh_hkey SET TAGS ('description_en' = 'Hash of the natural key (navrh_identifikator + zdrojova_aplikace_id). Identifies the entity, is stable across versions and serves both as the reference target and as the dbt snapshot unique_key.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.navrh_hist ALTER COLUMN pojistne_odvetvi_kod SET TAGS ('description_en' = 'LIFE or NONLIFE, derived from the topic. It is not part of the key, because the sourceapplication already tells the branches apart.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.navrh_hist ALTER COLUMN navrh_identifikator SET TAGS ('description_en' = 'Unique identifier of the proposal, filled from the mandatory identifier of each source: the contract number from TIA and KDP, the sales identifier from HUGO and the sales case number from LISA. Together with the source application id it identifies the row.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.navrh_hist ALTER COLUMN smlouva_cislo SET TAGS ('description_en' = 'Number of the contract the proposal leads to. For records from HUGO and LISA it isusually empty until the contract administration system assigns it; for records fromTIA and KDP it is always filled and equals the proposal identifier.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.navrh_hist ALTER COLUMN smlouva_hkey SET TAGS ('description_en' = 'Contract the proposal leads to, where it already exists. Resolved by the contractnumber and the administering application derived from the branch: TIA for non-life,KDP for life. For proposals from TIA and KDP it is a direct match; for HUGO and LISAit is a translation of HUGO to TIA and LISA to KDP. While the contract does not existit stays empty and is filled on a later run.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.navrh_hist ALTER COLUMN stav_navrhu_kod SET TAGS ('description_en' = 'Status of the offer.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.navrh_hist ALTER COLUMN spolecnost_kod SET TAGS ('description_en' = 'Group company that would be the insurer.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.navrh_hist ALTER COLUMN aplikace_kod SET TAGS ('description_en' = 'Source application, which is also how HUGO is told apart from LISA.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.navrh_hist ALTER COLUMN balicek_produktu_kod SET TAGS ('description_en' = 'Catalogue product bundle. Value FA marks a framework contract.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.navrh_hist ALTER COLUMN ramcova_smlouva_priznak SET TAGS ('description_en' = 'TRUE when the proposal is for a framework contract. Derived from super on the lifetopic and from product bundle code FA on the non-life one, which is a difference theconformation has to absorb.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.navrh_hist ALTER COLUMN datum_vzniku_pripadu SET TAGS ('description_en' = 'Date the sales case was created; it does not change.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.navrh_hist ALTER COLUMN datum_ucinnosti_zmeny SET TAGS ('description_en' = 'Date the change becomes effective.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.navrh_hist ALTER COLUMN datum_podpisu SET TAGS ('description_en' = 'Date the proposal was signed. The current life proposal schema does not carry thisitem and the non-life proposal topic has never had it, so it stays empty until asource starts sending it.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.navrh_hist ALTER COLUMN platnost_od_datum SET TAGS ('description_en' = 'Start of the proposed cover.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.navrh_hist ALTER COLUMN platnost_do_datum SET TAGS ('description_en' = 'End of the proposed cover.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.navrh_hist ALTER COLUMN frekvence_platby_kod SET TAGS ('description_en' = 'How often the premium would be paid.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.navrh_hist ALTER COLUMN rocni_pojistne_castka SET TAGS ('description_en' = 'Yearly premium proposed. Optional on the non-life topic since schema version v1_1.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.navrh_hist ALTER COLUMN zakladni_pojistne_castka SET TAGS ('description_en' = 'Basic premium before discounts. Non-life only.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.navrh_hist ALTER COLUMN pojistne_po_slevach_castka SET TAGS ('description_en' = 'Premium per period after discounts. Life only.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.navrh_hist ALTER COLUMN typ_udalosti_kod SET TAGS ('description_en' = 'Type of the life offer event.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.navrh_hist ALTER COLUMN zivotni_znacka_kod SET TAGS ('description_en' = 'Catalogue life brand. Life only.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.navrh_hist ALTER COLUMN technicky_id SET TAGS ('description_en' = 'Technical identifier of the offer in LISA. It identifies a level below the sales case, so it is not the natural key.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.navrh_hist ALTER COLUMN nadrizena_smlouva_cislo SET TAGS ('description_en' = 'Number of the framework contract the offer belongs to. Life only.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.navrh_hist ALTER COLUMN termin_aktivacni_platby_datum SET TAGS ('description_en' = 'Deadline for the activating payment. Non-life only.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.navrh_hist ALTER COLUMN pripad_cislo SET TAGS ('description_en' = 'Sales case number. A separate value for non-life; for life it equals the proposalidentifier.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.navrh_hist ALTER COLUMN zmenu_provedl_login SET TAGS ('description_en' = 'Domain login of the user who last changed the proposal. The non-life sales cockpitcarries it as lastUpdatedBy; the life one does not send it yet.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.navrh_hist ALTER COLUMN instance_produktu SET TAGS ('description_en' = 'Products proposed. The life topic carries the product directly on the proposal, thenon-life topic a list of instances; the conformation normalises both into this array.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.navrh_hist ALTER COLUMN partner_role SET TAGS ('description_en' = 'Parties on the proposal with their roles and the purpose-specific details valid for this proposal. Since schema version v1_1 the sales cockpit topics carry a single party in partyInPolicy, so from HUGO and LISA the array holds at most one element; the overview topics TIA and KDP carry an array with one or more parties. The non-life topic carries all three legal types, the life one only natural and juridical persons.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.navrh_hist ALTER COLUMN ucast_obchodnika SET TAGS ('description_en' = 'Agents handling the proposal. Conformed from the acquirer and MTA realizator lists ofthe non-life topic and the agent list of the life topic.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.navrh_hist ALTER COLUMN zdrojova_aplikace_id SET TAGS ('description_en' = 'Identifier of the source application the proposal arose in. It tells all four sourcesapart and forms the natural key together with the proposal identifier. Thanks to itthe same business opportunity can exist separately as a record from HUGO and as apre-contract state from TIA, because TIA carries no HUGO identifier.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.navrh_hist ALTER COLUMN __zdrojovy_system SET TAGS ('description_en' = 'Source system the record was loaded from, taken from the __source_system metadata column of the bronze table.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.navrh_hist ALTER COLUMN __zdrojova_tabulka_nazev SET TAGS ('description_en' = 'Fully qualified bronze table the record was loaded from. For conformed entities fedfrom several bronze tables it is the only value that tells the origin of a row apart.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.navrh_hist ALTER COLUMN smazano_priznak SET TAGS ('description_en' = 'TRUE when the source reported the record as deleted. Soft delete; the row is kept.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.navrh_hist ALTER COLUMN hash_instance_produktu SET TAGS ('description_en' = 'Diagnostic hash of the nested column product_instance. It does not take part in the version decision.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.navrh_hist ALTER COLUMN hash_partner_role SET TAGS ('description_en' = 'Diagnostic hash of the nested column party_role. It does not take part in the version decision.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.navrh_hist ALTER COLUMN hash_ucast_obchodnika SET TAGS ('description_en' = 'Diagnostic hash of the nested column agent_participation. It does not take part in the version decision.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.navrh_hist ALTER COLUMN verze_id SET TAGS ('description_en' = 'Identifier of a single version, an md5 hash of the natural key and the change indicator. Filled by dbt_scd_id on snapshots and computed the same way by the load on incremental tables. It is not the entity identity.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.navrh_hist ALTER COLUMN platnost_od_ts SET TAGS ('description_en' = 'Point in time from which this version was valid. Part of the history primary key.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.navrh_hist ALTER COLUMN platnost_do_ts SET TAGS ('description_en' = 'Point in time until which this version was valid; the open version carries 9999-12-31.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.navrh_hist ALTER COLUMN hash_zaznamu SET TAGS ('description_en' = 'The decision hash over all business columns of this version.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.navrh_hist ALTER COLUMN __nacteno_ts SET TAGS ('description_en' = 'Timestamp of when the version was inserted into this silver table.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.navrh_hist ALTER COLUMN navrh_hkey SET TAGS ('data_classification' = 'confidential');

-- ========================= dbx_cz_gcz_dev_czlake_silver.ods_k_klient.analyza_potreb_klienta =========================
-- current state | grain: Jeden řádek na analýzu | sources: REDy
CREATE TABLE IF NOT EXISTS dbx_cz_gcz_dev_czlake_silver.ods_k_klient.analyza_potreb_klienta (
    analyza_potreb_klienta_hkey  STRING NOT NULL  COMMENT 'Hash přirozeného klíče (analyza_id). Identifikuje entitu, je stabilní napříč verzemi a slouží jako cíl odkazů z jiných entit i jako unique_key snapshotu v dbt.',
    analyza_id                   STRING NOT NULL  COMMENT 'Unikátní identifikátor analýzy.',
    partner_id                   STRING NOT NULL  COMMENT 'Identifikátor partnera, pro kterého byla analýza provedena. Ve zdroji je povinný, clientNeedsAnalysis.party i partyId mají kardinalitu 1..1. Vyhodnocuje se přes mapovani_id_partnera.',
    obchodnik_hkey               STRING NOT NULL  COMMENT 'Obchodník, který analýzu vlastní. Ve zdroji je povinný.',
    ziskatelske_cislo            BIGINT  COMMENT 'Získatelské číslo vlastníka analýzy, pokud je uvedeno.',
    stav_analyzy_kod             STRING NOT NULL  COMMENT 'Stav analýzy.',
    typ_analyzy_kod              STRING NOT NULL  COMMENT 'Typ analýzy.',
    vytvoreno_ts                 TIMESTAMP NOT NULL  COMMENT 'Kdy byla analýza vytvořena.',
    zmeneno_ts                   TIMESTAMP  COMMENT 'Kdy byla analýza naposledy změněna.',
    zmenu_provedl_login          STRING  COMMENT 'Domain login uživatele, který záznam ve zdrojovém systému naposledy změnil.',
    zdrojova_aplikace_id         INT NOT NULL  COMMENT 'Identifikátor zdrojové aplikace, ve které analýza vznikla.',
    __zdrojovy_system            STRING NOT NULL  COMMENT 'Zdrojový systém, ze kterého byl záznam načten. Přebírá se z metadatového sloupce __source_system odpovídající bronze tabulky.',
    __zdrojova_tabulka_nazev     STRING NOT NULL  COMMENT 'Plně kvalifikovaná bronze tabulka, ze které byl záznam načten. U konformovaných entit plněných z více bronze tabulek je to jediný údaj, který rozliší původ konkrétního řádku.',
    platnost_od_ts               TIMESTAMP NOT NULL  COMMENT 'Okamžik, od kterého je tato verze řádku platná. U inkrementálních tabulek se plní časem poslední změny ve zdroji: u sync topiků z dataUpdatedAt, u delete topiků z auditInformation.lastUpdatedAt. U tabulek plněných snapshotem nese čas běhu, tedy okamžik, kdy jsme stav pozorovali - zdroj posílá celý snímek a vlastní čas změny u číselníků nenabízí.',
    hash_zaznamu                 STRING NOT NULL  COMMENT 'Rozhodovací hash přes všechny byznysové sloupce. Podle něj se pozná skutečná změna a v dbt je to jediný sloupec v check_cols. Technické sloupce do hashe nevstupují, jinak by vznikala nová verze při každém běhu, a vnořená pole se před hashováním řadí podle stabilního klíče, jinak by jiné pořadí prvků vypadalo jako změna.',
    __nacteno_ts                 TIMESTAMP NOT NULL  COMMENT 'Časové razítko, kdy byl záznam vložen do této silver tabulky.',
    CONSTRAINT pk_analyza_potreb_klienta PRIMARY KEY (analyza_potreb_klienta_hkey) NOT ENFORCED
)
USING DELTA
COMMENT 'Jedna analýza potřeb klienta provedená dotazníkem. Jediná entita, která spojuje obchodníka s partnerem přímo, bez smlouvy nebo návrhu mezi nimi. Identifikátor partnera se drží zde, protože i tady jde o účelový údaj platný pro tuto analýzu.'
CLUSTER BY (analyza_potreb_klienta_hkey)
TBLPROPERTIES (
    'delta.columnMapping.mode'   = 'name',
    'delta.enableChangeDataFeed' = 'true',
    'model.layer'                = 'silver',
    'model.table_kind'           = 'current'
);
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_k_klient.analyza_potreb_klienta SET TAGS ('description_en' = 'One questionnaire based analysis of the needs of one client. It is the only entity that links an agent to a party directly, with no contract or proposal in between. The party identifier is held here, because it too is purpose-specific to this analysis.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_k_klient.analyza_potreb_klienta ALTER COLUMN analyza_potreb_klienta_hkey SET TAGS ('description_en' = 'Hash of the natural key (analyza_id). Identifies the entity, is stable across versions and serves both as the reference target and as the dbt snapshot unique_key.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_k_klient.analyza_potreb_klienta ALTER COLUMN analyza_id SET TAGS ('description_en' = 'Unique identifier of the analysis.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_k_klient.analyza_potreb_klienta ALTER COLUMN partner_id SET TAGS ('description_en' = 'Identifier of the party the analysis was made for. Mandatory in the source: both clientNeedsAnalysis.party and partyId have cardinality 1..1. Resolved through the party identifier mapping table.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_k_klient.analyza_potreb_klienta ALTER COLUMN obchodnik_hkey SET TAGS ('description_en' = 'Agent who owns the analysis; mandatory in the source.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_k_klient.analyza_potreb_klienta ALTER COLUMN ziskatelske_cislo SET TAGS ('description_en' = 'Acquisition number of the owner, where stated.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_k_klient.analyza_potreb_klienta ALTER COLUMN stav_analyzy_kod SET TAGS ('description_en' = 'State of the analysis.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_k_klient.analyza_potreb_klienta ALTER COLUMN typ_analyzy_kod SET TAGS ('description_en' = 'Type of the analysis.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_k_klient.analyza_potreb_klienta ALTER COLUMN vytvoreno_ts SET TAGS ('description_en' = 'When the analysis was created.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_k_klient.analyza_potreb_klienta ALTER COLUMN zmeneno_ts SET TAGS ('description_en' = 'When the analysis was last modified.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_k_klient.analyza_potreb_klienta ALTER COLUMN zmenu_provedl_login SET TAGS ('description_en' = 'Domain login of the user who last changed the record in the source system.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_k_klient.analyza_potreb_klienta ALTER COLUMN zdrojova_aplikace_id SET TAGS ('description_en' = 'Identifier of the source application.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_k_klient.analyza_potreb_klienta ALTER COLUMN __zdrojovy_system SET TAGS ('description_en' = 'Source system the record was loaded from, taken from the __source_system metadata column of the bronze table.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_k_klient.analyza_potreb_klienta ALTER COLUMN __zdrojova_tabulka_nazev SET TAGS ('description_en' = 'Fully qualified bronze table the record was loaded from. For conformed entities fedfrom several bronze tables it is the only value that tells the origin of a row apart.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_k_klient.analyza_potreb_klienta ALTER COLUMN platnost_od_ts SET TAGS ('description_en' = 'Point in time from which this version is valid, taken from the source change timestamp.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_k_klient.analyza_potreb_klienta ALTER COLUMN hash_zaznamu SET TAGS ('description_en' = 'The decision hash over all business columns and the only column in the dbt check_cols. Nested arrays must be sorted by a stable key before hashing.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_k_klient.analyza_potreb_klienta ALTER COLUMN __nacteno_ts SET TAGS ('description_en' = 'Timestamp of when the record was inserted into this silver table.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_k_klient.analyza_potreb_klienta ALTER COLUMN analyza_potreb_klienta_hkey SET TAGS ('data_classification' = 'confidential');

-- ========================= dbx_cz_gcz_dev_czlake_silver.ods_k_klient.analyza_potreb_klienta_hist =========================
-- SCD2 history | grain: Jeden řádek na analýzu | sources: REDy
CREATE TABLE IF NOT EXISTS dbx_cz_gcz_dev_czlake_silver.ods_k_klient.analyza_potreb_klienta_hist (
    analyza_potreb_klienta_hkey  STRING NOT NULL  COMMENT 'Hash přirozeného klíče (analyza_id). Identifikuje entitu, je stabilní napříč verzemi a slouží jako cíl odkazů z jiných entit i jako unique_key snapshotu v dbt.',
    analyza_id                   STRING NOT NULL  COMMENT 'Unikátní identifikátor analýzy.',
    partner_id                   STRING NOT NULL  COMMENT 'Identifikátor partnera, pro kterého byla analýza provedena. Ve zdroji je povinný, clientNeedsAnalysis.party i partyId mají kardinalitu 1..1. Vyhodnocuje se přes mapovani_id_partnera.',
    obchodnik_hkey               STRING NOT NULL  COMMENT 'Obchodník, který analýzu vlastní. Ve zdroji je povinný.',
    ziskatelske_cislo            BIGINT  COMMENT 'Získatelské číslo vlastníka analýzy, pokud je uvedeno.',
    stav_analyzy_kod             STRING NOT NULL  COMMENT 'Stav analýzy.',
    typ_analyzy_kod              STRING NOT NULL  COMMENT 'Typ analýzy.',
    vytvoreno_ts                 TIMESTAMP NOT NULL  COMMENT 'Kdy byla analýza vytvořena.',
    zmeneno_ts                   TIMESTAMP  COMMENT 'Kdy byla analýza naposledy změněna.',
    zmenu_provedl_login          STRING  COMMENT 'Domain login uživatele, který záznam ve zdrojovém systému naposledy změnil.',
    zdrojova_aplikace_id         INT NOT NULL  COMMENT 'Identifikátor zdrojové aplikace, ve které analýza vznikla.',
    __zdrojovy_system            STRING NOT NULL  COMMENT 'Zdrojový systém, ze kterého byl záznam načten. Přebírá se z metadatového sloupce __source_system odpovídající bronze tabulky.',
    __zdrojova_tabulka_nazev     STRING NOT NULL  COMMENT 'Plně kvalifikovaná bronze tabulka, ze které byl záznam načten. U konformovaných entit plněných z více bronze tabulek je to jediný údaj, který rozliší původ konkrétního řádku.',
    verze_id                     STRING NOT NULL  COMMENT 'Identifikátor jedné verze záznamu, md5 hash přirozeného klíče a indikátoru změny, takže se liší verzi od verze. U snapshotů ho plní dbt jako dbt_scd_id, u inkrementálních tabulek ho stejným způsobem počítá plnění. Není to identita entity - tu nese <entita>_hkey, který zůstává napříč verzemi stejný.',
    platnost_od_ts               TIMESTAMP NOT NULL  COMMENT 'Okamžik, od kterého byla tato verze platná. U inkrementálních tabulek čas poslední změny ve zdroji, u snapshotů čas běhu, kdy byl stav pozorován.',
    platnost_do_ts               TIMESTAMP NOT NULL  COMMENT 'Okamžik, do kterého byla verze platná. Otevřená verze nese 9999-12-31 místo NULL, aby porovnávání období nemuselo řešit NULL. Otevřená verze je právě ta, která je v tabulce aktuálního stavu.',
    hash_zaznamu                 STRING NOT NULL  COMMENT 'Rozhodovací hash přes všechny byznysové sloupce této verze. Technické sloupce do hashe nevstupují a vnořená pole se před hashováním řadí podle stabilního klíče.',
    __nacteno_ts                 TIMESTAMP NOT NULL  COMMENT 'Časové razítko, kdy byla verze vložena do této silver tabulky.',
    CONSTRAINT pk_analyza_potreb_klienta_hist PRIMARY KEY (analyza_potreb_klienta_hkey, platnost_od_ts) NOT ENFORCED
)
USING DELTA
COMMENT 'Historie SCD2 entity analyza_potreb_klienta. Jeden řádek na verzi, platnou mezi platnost_od_ts a platnost_do_ts. Jedna analýza potřeb klienta provedená dotazníkem. Jediná entita, která spojuje obchodníka s partnerem přímo, bez smlouvy nebo návrhu mezi nimi. Identifikátor partnera se drží zde, protože i tady jde o účelový údaj platný pro tuto analýzu.'
CLUSTER BY (analyza_potreb_klienta_hkey, platnost_od_ts)
TBLPROPERTIES (
    'delta.columnMapping.mode'   = 'name',
    'delta.enableChangeDataFeed' = 'true',
    'model.layer'                = 'silver',
    'model.table_kind'           = 'history'
);
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_k_klient.analyza_potreb_klienta_hist SET TAGS ('description_en' = 'SCD2 history of client_needs_analysis, one row per version valid between valid_from_timestamp and valid_to_timestamp. One questionnaire based analysis of the needs of one client. It is the only entity that links an agent to a party directly, with no contract or proposal in between. The party identifier is held here, because it too is purpose-specific to this analysis.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_k_klient.analyza_potreb_klienta_hist ALTER COLUMN analyza_potreb_klienta_hkey SET TAGS ('description_en' = 'Hash of the natural key (analyza_id). Identifies the entity, is stable across versions and serves both as the reference target and as the dbt snapshot unique_key.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_k_klient.analyza_potreb_klienta_hist ALTER COLUMN analyza_id SET TAGS ('description_en' = 'Unique identifier of the analysis.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_k_klient.analyza_potreb_klienta_hist ALTER COLUMN partner_id SET TAGS ('description_en' = 'Identifier of the party the analysis was made for. Mandatory in the source: both clientNeedsAnalysis.party and partyId have cardinality 1..1. Resolved through the party identifier mapping table.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_k_klient.analyza_potreb_klienta_hist ALTER COLUMN obchodnik_hkey SET TAGS ('description_en' = 'Agent who owns the analysis; mandatory in the source.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_k_klient.analyza_potreb_klienta_hist ALTER COLUMN ziskatelske_cislo SET TAGS ('description_en' = 'Acquisition number of the owner, where stated.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_k_klient.analyza_potreb_klienta_hist ALTER COLUMN stav_analyzy_kod SET TAGS ('description_en' = 'State of the analysis.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_k_klient.analyza_potreb_klienta_hist ALTER COLUMN typ_analyzy_kod SET TAGS ('description_en' = 'Type of the analysis.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_k_klient.analyza_potreb_klienta_hist ALTER COLUMN vytvoreno_ts SET TAGS ('description_en' = 'When the analysis was created.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_k_klient.analyza_potreb_klienta_hist ALTER COLUMN zmeneno_ts SET TAGS ('description_en' = 'When the analysis was last modified.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_k_klient.analyza_potreb_klienta_hist ALTER COLUMN zmenu_provedl_login SET TAGS ('description_en' = 'Domain login of the user who last changed the record in the source system.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_k_klient.analyza_potreb_klienta_hist ALTER COLUMN zdrojova_aplikace_id SET TAGS ('description_en' = 'Identifier of the source application.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_k_klient.analyza_potreb_klienta_hist ALTER COLUMN __zdrojovy_system SET TAGS ('description_en' = 'Source system the record was loaded from, taken from the __source_system metadata column of the bronze table.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_k_klient.analyza_potreb_klienta_hist ALTER COLUMN __zdrojova_tabulka_nazev SET TAGS ('description_en' = 'Fully qualified bronze table the record was loaded from. For conformed entities fedfrom several bronze tables it is the only value that tells the origin of a row apart.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_k_klient.analyza_potreb_klienta_hist ALTER COLUMN verze_id SET TAGS ('description_en' = 'Identifier of a single version, an md5 hash of the natural key and the change indicator. Filled by dbt_scd_id on snapshots and computed the same way by the load on incremental tables. It is not the entity identity.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_k_klient.analyza_potreb_klienta_hist ALTER COLUMN platnost_od_ts SET TAGS ('description_en' = 'Point in time from which this version was valid. Part of the history primary key.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_k_klient.analyza_potreb_klienta_hist ALTER COLUMN platnost_do_ts SET TAGS ('description_en' = 'Point in time until which this version was valid; the open version carries 9999-12-31.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_k_klient.analyza_potreb_klienta_hist ALTER COLUMN hash_zaznamu SET TAGS ('description_en' = 'The decision hash over all business columns of this version.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_k_klient.analyza_potreb_klienta_hist ALTER COLUMN __nacteno_ts SET TAGS ('description_en' = 'Timestamp of when the version was inserted into this silver table.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_k_klient.analyza_potreb_klienta_hist ALTER COLUMN analyza_potreb_klienta_hkey SET TAGS ('data_classification' = 'confidential');

-- ========================= dbx_cz_gcz_dev_czlake_silver.ods_k_klient.mapovani_id_partnera =========================
-- current state | grain: Jeden řádek na historický identifikátor partnera | sources: CCD
CREATE TABLE IF NOT EXISTS dbx_cz_gcz_dev_czlake_silver.ods_k_klient.mapovani_id_partnera (
    mapovani_id_partnera_hkey  STRING NOT NULL  COMMENT 'Náhradní primární klíč.',
    zdrojovy_partner_id        STRING NOT NULL  COMMENT 'Identifikátor, jak ho dodal zdrojový systém. Může být již vyřazený.',
    cilovy_partner_id          STRING NOT NULL  COMMENT 'Přeživší identifikátor. Řetězce se při plnění zkracují, takže dohledání nepotřebuje více než jeden krok.',
    zmena_ts                   TIMESTAMP NOT NULL  COMMENT 'Kdy ke změně identifikátoru došlo.',
    delka_retezce              INT NOT NULL  COMMENT 'Kolik následných změn bylo do tohoto řádku zkráceno. 1 znamená přímou změnu.',
    zmenu_provedl_login        STRING  COMMENT 'Domain login uživatele, který záznam ve zdrojovém systému naposledy změnil.',
    zdrojova_aplikace_id       INT NOT NULL  COMMENT 'Identifikátor zdrojové aplikace, která změnu identifikátoru ohlásila.',
    __zdrojovy_system          STRING NOT NULL  COMMENT 'Zdrojový systém, ze kterého byl záznam načten. Přebírá se z metadatového sloupce __source_system odpovídající bronze tabulky.',
    __zdrojova_tabulka_nazev   STRING NOT NULL  COMMENT 'Plně kvalifikovaná bronze tabulka, ze které byl záznam načten. U konformovaných entit plněných z více bronze tabulek je to jediný údaj, který rozliší původ konkrétního řádku.',
    platnost_od_ts             TIMESTAMP NOT NULL  COMMENT 'Okamžik, od kterého je tato verze řádku platná. U inkrementálních tabulek se plní časem poslední změny ve zdroji: u sync topiků z dataUpdatedAt, u delete topiků z auditInformation.lastUpdatedAt. U tabulek plněných snapshotem nese čas běhu, tedy okamžik, kdy jsme stav pozorovali - zdroj posílá celý snímek a vlastní čas změny u číselníků nenabízí.',
    hash_zaznamu               STRING NOT NULL  COMMENT 'Rozhodovací hash přes všechny byznysové sloupce. Podle něj se pozná skutečná změna a v dbt je to jediný sloupec v check_cols. Technické sloupce do hashe nevstupují, jinak by vznikala nová verze při každém běhu, a vnořená pole se před hashováním řadí podle stabilního klíče, jinak by jiné pořadí prvků vypadalo jako změna.',
    __nacteno_ts               TIMESTAMP NOT NULL  COMMENT 'Časové razítko, kdy byl záznam vložen do této silver tabulky.',
    CONSTRAINT pk_mapovani_id_partnera PRIMARY KEY (mapovani_id_partnera_hkey) NOT ENFORCED
)
USING DELTA
COMMENT 'Mapuje každý identifikátor, který partner kdy měl, na přeživší identifikátor. Plní se z událostí o změně identifikátoru ze systému CCD. Zůstává samostatnou entitou i po odstranění entity partnera, protože je to reálný zdrojový topik a jediné místo, kde se sloučení duplicitních klientů dá vyhodnotit. Každé partner_id uvnitř smlouvy, návrhu, analýzy, kontaktu v kampani a úkolu se vyhodnocuje přes tuto tabulku.'
CLUSTER BY (mapovani_id_partnera_hkey)
TBLPROPERTIES (
    'delta.columnMapping.mode'   = 'name',
    'delta.enableChangeDataFeed' = 'true',
    'model.layer'                = 'silver',
    'model.table_kind'           = 'current'
);
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_k_klient.mapovani_id_partnera SET TAGS ('description_en' = 'Maps every identifier a party has ever had to the surviving one. Written from the CCD party identifier change events. It stays a standalone entity even after the party entity was removed, because it is a real source topic and the only place a merge of duplicate clients can be resolved. Every party identifier inside contract, proposal, analysis, campaign contact and task is resolved through this table.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_k_klient.mapovani_id_partnera ALTER COLUMN mapovani_id_partnera_hkey SET TAGS ('description_en' = 'Surrogate primary key.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_k_klient.mapovani_id_partnera ALTER COLUMN zdrojovy_partner_id SET TAGS ('description_en' = 'Identifier as delivered, possibly retired.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_k_klient.mapovani_id_partnera ALTER COLUMN cilovy_partner_id SET TAGS ('description_en' = 'Surviving identifier the source one resolves to. Chains are collapsed on load, so alookup never needs more than one hop.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_k_klient.mapovani_id_partnera ALTER COLUMN zmena_ts SET TAGS ('description_en' = 'When the change was made.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_k_klient.mapovani_id_partnera ALTER COLUMN delka_retezce SET TAGS ('description_en' = 'How many successive changes were collapsed into this row.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_k_klient.mapovani_id_partnera ALTER COLUMN zmenu_provedl_login SET TAGS ('description_en' = 'Domain login of the user who last changed the record in the source system.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_k_klient.mapovani_id_partnera ALTER COLUMN zdrojova_aplikace_id SET TAGS ('description_en' = 'Identifier of the source application that reported the change.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_k_klient.mapovani_id_partnera ALTER COLUMN __zdrojovy_system SET TAGS ('description_en' = 'Source system the record was loaded from, taken from the __source_system metadata column of the bronze table.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_k_klient.mapovani_id_partnera ALTER COLUMN __zdrojova_tabulka_nazev SET TAGS ('description_en' = 'Fully qualified bronze table the record was loaded from. For conformed entities fedfrom several bronze tables it is the only value that tells the origin of a row apart.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_k_klient.mapovani_id_partnera ALTER COLUMN platnost_od_ts SET TAGS ('description_en' = 'Point in time from which this version is valid, taken from the source change timestamp.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_k_klient.mapovani_id_partnera ALTER COLUMN hash_zaznamu SET TAGS ('description_en' = 'The decision hash over all business columns and the only column in the dbt check_cols. Nested arrays must be sorted by a stable key before hashing.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_k_klient.mapovani_id_partnera ALTER COLUMN __nacteno_ts SET TAGS ('description_en' = 'Timestamp of when the record was inserted into this silver table.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_k_klient.mapovani_id_partnera ALTER COLUMN mapovani_id_partnera_hkey SET TAGS ('data_classification' = 'confidential');

-- ========================= dbx_cz_gcz_dev_czlake_silver.ods_k_klient.mapovani_id_partnera_hist =========================
-- SCD2 history | grain: Jeden řádek na historický identifikátor partnera | sources: CCD
CREATE TABLE IF NOT EXISTS dbx_cz_gcz_dev_czlake_silver.ods_k_klient.mapovani_id_partnera_hist (
    mapovani_id_partnera_hkey  STRING NOT NULL  COMMENT 'Náhradní primární klíč.',
    zdrojovy_partner_id        STRING NOT NULL  COMMENT 'Identifikátor, jak ho dodal zdrojový systém. Může být již vyřazený.',
    cilovy_partner_id          STRING NOT NULL  COMMENT 'Přeživší identifikátor. Řetězce se při plnění zkracují, takže dohledání nepotřebuje více než jeden krok.',
    zmena_ts                   TIMESTAMP NOT NULL  COMMENT 'Kdy ke změně identifikátoru došlo.',
    delka_retezce              INT NOT NULL  COMMENT 'Kolik následných změn bylo do tohoto řádku zkráceno. 1 znamená přímou změnu.',
    zmenu_provedl_login        STRING  COMMENT 'Domain login uživatele, který záznam ve zdrojovém systému naposledy změnil.',
    zdrojova_aplikace_id       INT NOT NULL  COMMENT 'Identifikátor zdrojové aplikace, která změnu identifikátoru ohlásila.',
    __zdrojovy_system          STRING NOT NULL  COMMENT 'Zdrojový systém, ze kterého byl záznam načten. Přebírá se z metadatového sloupce __source_system odpovídající bronze tabulky.',
    __zdrojova_tabulka_nazev   STRING NOT NULL  COMMENT 'Plně kvalifikovaná bronze tabulka, ze které byl záznam načten. U konformovaných entit plněných z více bronze tabulek je to jediný údaj, který rozliší původ konkrétního řádku.',
    verze_id                   STRING NOT NULL  COMMENT 'Identifikátor jedné verze záznamu, md5 hash přirozeného klíče a indikátoru změny, takže se liší verzi od verze. U snapshotů ho plní dbt jako dbt_scd_id, u inkrementálních tabulek ho stejným způsobem počítá plnění. Není to identita entity - tu nese <entita>_hkey, který zůstává napříč verzemi stejný.',
    platnost_od_ts             TIMESTAMP NOT NULL  COMMENT 'Okamžik, od kterého byla tato verze platná. U inkrementálních tabulek čas poslední změny ve zdroji, u snapshotů čas běhu, kdy byl stav pozorován.',
    platnost_do_ts             TIMESTAMP NOT NULL  COMMENT 'Okamžik, do kterého byla verze platná. Otevřená verze nese 9999-12-31 místo NULL, aby porovnávání období nemuselo řešit NULL. Otevřená verze je právě ta, která je v tabulce aktuálního stavu.',
    hash_zaznamu               STRING NOT NULL  COMMENT 'Rozhodovací hash přes všechny byznysové sloupce této verze. Technické sloupce do hashe nevstupují a vnořená pole se před hashováním řadí podle stabilního klíče.',
    __nacteno_ts               TIMESTAMP NOT NULL  COMMENT 'Časové razítko, kdy byla verze vložena do této silver tabulky.',
    CONSTRAINT pk_mapovani_id_partnera_hist PRIMARY KEY (mapovani_id_partnera_hkey, platnost_od_ts) NOT ENFORCED
)
USING DELTA
COMMENT 'Historie SCD2 entity mapovani_id_partnera. Jeden řádek na verzi, platnou mezi platnost_od_ts a platnost_do_ts. Mapuje každý identifikátor, který partner kdy měl, na přeživší identifikátor. Plní se z událostí o změně identifikátoru ze systému CCD. Zůstává samostatnou entitou i po odstranění entity partnera, protože je to reálný zdrojový topik a jediné místo, kde se sloučení duplicitních klientů dá vyhodnotit. Každé partner_id uvnitř smlouvy, návrhu, analýzy, kontaktu v kampani a úkolu se vyhodnocuje přes tuto tabulku.'
CLUSTER BY (mapovani_id_partnera_hkey, platnost_od_ts)
TBLPROPERTIES (
    'delta.columnMapping.mode'   = 'name',
    'delta.enableChangeDataFeed' = 'true',
    'model.layer'                = 'silver',
    'model.table_kind'           = 'history'
);
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_k_klient.mapovani_id_partnera_hist SET TAGS ('description_en' = 'SCD2 history of party_id_mapping, one row per version valid between valid_from_timestamp and valid_to_timestamp. Maps every identifier a party has ever had to the surviving one. Written from the CCD party identifier change events. It stays a standalone entity even after the party entity was removed, because it is a real source topic and the only place a merge of duplicate clients can be resolved. Every party identifier inside contract, proposal, analysis, campaign contact and task is resolved through this table.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_k_klient.mapovani_id_partnera_hist ALTER COLUMN mapovani_id_partnera_hkey SET TAGS ('description_en' = 'Surrogate primary key.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_k_klient.mapovani_id_partnera_hist ALTER COLUMN zdrojovy_partner_id SET TAGS ('description_en' = 'Identifier as delivered, possibly retired.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_k_klient.mapovani_id_partnera_hist ALTER COLUMN cilovy_partner_id SET TAGS ('description_en' = 'Surviving identifier the source one resolves to. Chains are collapsed on load, so alookup never needs more than one hop.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_k_klient.mapovani_id_partnera_hist ALTER COLUMN zmena_ts SET TAGS ('description_en' = 'When the change was made.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_k_klient.mapovani_id_partnera_hist ALTER COLUMN delka_retezce SET TAGS ('description_en' = 'How many successive changes were collapsed into this row.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_k_klient.mapovani_id_partnera_hist ALTER COLUMN zmenu_provedl_login SET TAGS ('description_en' = 'Domain login of the user who last changed the record in the source system.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_k_klient.mapovani_id_partnera_hist ALTER COLUMN zdrojova_aplikace_id SET TAGS ('description_en' = 'Identifier of the source application that reported the change.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_k_klient.mapovani_id_partnera_hist ALTER COLUMN __zdrojovy_system SET TAGS ('description_en' = 'Source system the record was loaded from, taken from the __source_system metadata column of the bronze table.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_k_klient.mapovani_id_partnera_hist ALTER COLUMN __zdrojova_tabulka_nazev SET TAGS ('description_en' = 'Fully qualified bronze table the record was loaded from. For conformed entities fedfrom several bronze tables it is the only value that tells the origin of a row apart.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_k_klient.mapovani_id_partnera_hist ALTER COLUMN verze_id SET TAGS ('description_en' = 'Identifier of a single version, an md5 hash of the natural key and the change indicator. Filled by dbt_scd_id on snapshots and computed the same way by the load on incremental tables. It is not the entity identity.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_k_klient.mapovani_id_partnera_hist ALTER COLUMN platnost_od_ts SET TAGS ('description_en' = 'Point in time from which this version was valid. Part of the history primary key.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_k_klient.mapovani_id_partnera_hist ALTER COLUMN platnost_do_ts SET TAGS ('description_en' = 'Point in time until which this version was valid; the open version carries 9999-12-31.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_k_klient.mapovani_id_partnera_hist ALTER COLUMN hash_zaznamu SET TAGS ('description_en' = 'The decision hash over all business columns of this version.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_k_klient.mapovani_id_partnera_hist ALTER COLUMN __nacteno_ts SET TAGS ('description_en' = 'Timestamp of when the version was inserted into this silver table.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_k_klient.mapovani_id_partnera_hist ALTER COLUMN mapovani_id_partnera_hkey SET TAGS ('data_classification' = 'confidential');

-- ========================= dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.obchodnik =========================
-- current state | grain: Jeden řádek na obchodníka | sources: KCL
CREATE TABLE IF NOT EXISTS dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.obchodnik (
    obchodnik_hkey            STRING NOT NULL  COMMENT 'Hash přirozeného klíče (obchodnik_login). Identifikuje entitu, je stabilní napříč verzemi a slouží jako cíl odkazů z jiných entit i jako unique_key snapshotu v dbt.',
    obchodnik_login           STRING NOT NULL  COMMENT 'Domain login obchodníka. Jediný identifikátor, který nesou všechny zdroje, proto je přirozeným klíčem.',
    obchodnik_cdu_id          BIGINT  COMMENT 'CDU identifikátor obchodníka.',
    obchodnik_oid             BIGINT  COMMENT 'OID obchodníka.',
    jmeno                     STRING  COMMENT 'Křestní jméno obchodníka.',
    prijmeni                  STRING  COMMENT 'Příjmení obchodníka.',
    role_obchodnika_kod       STRING NOT NULL  COMMENT 'Kanonická role: PVZ_OBCHODNIK, OBCHODNIK, MANAZER_SKUPINY, OBLASTNI_REDITEL, REGIONALNI_REDITEL nebo ADMINISTRATIVA.',
    uroven_hierarchie         INT NOT NULL  COMMENT 'Pozice v obchodní hierarchii, 1 pro PVZ obchodníka až 5 pro regionálního ředitele.',
    nadrizeny_obchodnik_hkey  STRING  COMMENT 'Přímý nadřízený obchodníka.',
    verejny_zaznam_priznak    BOOLEAN NOT NULL  COMMENT 'TRUE pro veřejný záznam, FALSE pro technický sloužící jen ke konstrukci struktury.',
    spolecnost_kod            BIGINT NOT NULL  COMMENT 'Společnost skupiny.',
    prirazeni                 
        ARRAY<STRUCT<`organizacni_jednotka_hkey`: STRING, `oblast_id`: BIGINT, `region_id`: BIGINT, `kanal_id`: INT, `ziskatelske_cislo`: STRING, `osobni_cislo`: BIGINT>> NOT NULL  COMMENT 'Přiřazení obchodníka k oblasti, regionu a kanálu, každé se získatelským a osobním číslem. Vnořené, protože obchodník jich má několik současně a zdroj to vyjadřuje opakováním celého řádku.',
    __zdrojovy_system         STRING NOT NULL  COMMENT 'Zdrojový systém, ze kterého byl záznam načten. Přebírá se z metadatového sloupce __source_system odpovídající bronze tabulky.',
    __zdrojova_tabulka_nazev  STRING NOT NULL  COMMENT 'Plně kvalifikovaná bronze tabulka, ze které byl záznam načten. U konformovaných entit plněných z více bronze tabulek je to jediný údaj, který rozliší původ konkrétního řádku.',
    hash_prirazeni            STRING  COMMENT 'Diagnostický hash vnořeného sloupce prirazeni. Neúčastní se rozhodnutí o nové verzi, slouží jen ke zjištění, která oblast se změnila. Pole se před hashováním řadí podle stabilního klíče.',
    platnost_od_ts            TIMESTAMP NOT NULL  COMMENT 'Okamžik, od kterého je tato verze řádku platná. U inkrementálních tabulek se plní časem poslední změny ve zdroji: u sync topiků z dataUpdatedAt, u delete topiků z auditInformation.lastUpdatedAt. U tabulek plněných snapshotem nese čas běhu, tedy okamžik, kdy jsme stav pozorovali - zdroj posílá celý snímek a vlastní čas změny u číselníků nenabízí.',
    hash_zaznamu              STRING NOT NULL  COMMENT 'Rozhodovací hash přes všechny byznysové sloupce. Podle něj se pozná skutečná změna a v dbt je to jediný sloupec v check_cols. Technické sloupce do hashe nevstupují, jinak by vznikala nová verze při každém běhu, a vnořená pole se před hashováním řadí podle stabilního klíče, jinak by jiné pořadí prvků vypadalo jako změna.',
    __nacteno_ts              TIMESTAMP NOT NULL  COMMENT 'Časové razítko, kdy byl záznam vložen do této silver tabulky.',
    CONSTRAINT pk_obchodnik PRIMARY KEY (obchodnik_hkey) NOT ENFORCED
)
USING DELTA
COMMENT 'Kanonický obchodník. Tvoří se výhradně z organizačních tabulek KCL, nikoliv z odkazů na obchodníka v HUGO, LISA, TIA, KDP a REDy - ty na entitu jen odkazují přes domain login. Jedna entita pro všech šest rolí, které organizační struktura KCL rozlišuje vlastní tabulkou. Role a pozice v hierarchii se stávají atributy, přiřazení k oblasti, regionu a kanálu jsou vnořená, protože jeden člověk jich drží několik zároveň.'
CLUSTER BY (obchodnik_hkey)
TBLPROPERTIES (
    'delta.columnMapping.mode'   = 'name',
    'delta.enableChangeDataFeed' = 'true',
    'model.layer'                = 'silver',
    'model.table_kind'           = 'current'
);
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.obchodnik SET TAGS ('description_en' = 'Canonical sales person. Built exclusively from the KCL organisational tables, not from the agent references in HUGO, LISA, TIA, KDP and REDy, which only point at the entity by domain login. One entity for all six roles the KCL structure keeps in a table of its own: sub-agent seller, seller, group manager, district director, regional director and administration employee. The role and the position in the hierarchy become attributes, and the assignments to agency, region and channel are nested, because one person legitimately holds several of them at the same time.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.obchodnik ALTER COLUMN obchodnik_hkey SET TAGS ('description_en' = 'Hash of the natural key (obchodnik_login). Identifies the entity, is stable across versions and serves both as the reference target and as the dbt snapshot unique_key.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.obchodnik ALTER COLUMN obchodnik_login SET TAGS ('description_en' = 'Domain login of the agent, the only identifier all sources carry.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.obchodnik ALTER COLUMN obchodnik_cdu_id SET TAGS ('description_en' = 'CDU identifier of the agent.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.obchodnik ALTER COLUMN obchodnik_oid SET TAGS ('description_en' = 'OID of the agent.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.obchodnik ALTER COLUMN jmeno SET TAGS ('description_en' = 'First name.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.obchodnik ALTER COLUMN prijmeni SET TAGS ('description_en' = 'Surname.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.obchodnik ALTER COLUMN role_obchodnika_kod SET TAGS ('description_en' = 'Canonical role: sub-agent seller, seller, group manager, district director, regionaldirector or administration. Derived from which KCL table the row came from.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.obchodnik ALTER COLUMN uroven_hierarchie SET TAGS ('description_en' = 'Position in the sales hierarchy, 1 for the sub-agent seller up to 5 for the regionaldirector. It lets the hierarchy be walked without knowing the source table names.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.obchodnik ALTER COLUMN nadrizeny_obchodnik_hkey SET TAGS ('description_en' = 'Immediate superior of the agent.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.obchodnik ALTER COLUMN verejny_zaznam_priznak SET TAGS ('description_en' = 'TRUE for a public record, FALSE for a technical one.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.obchodnik ALTER COLUMN spolecnost_kod SET TAGS ('description_en' = 'Group company.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.obchodnik ALTER COLUMN prirazeni SET TAGS ('description_en' = 'Assignments of the agent to an agency, a region and a distribution channel, each withthe acquisition and personnel numbers valid there. Nested, because one agent holdsseveral at the same time and the source repeats the whole row.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.obchodnik ALTER COLUMN __zdrojovy_system SET TAGS ('description_en' = 'Source system the record was loaded from, taken from the __source_system metadata column of the bronze table.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.obchodnik ALTER COLUMN __zdrojova_tabulka_nazev SET TAGS ('description_en' = 'Fully qualified bronze table the record was loaded from. For conformed entities fedfrom several bronze tables it is the only value that tells the origin of a row apart.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.obchodnik ALTER COLUMN hash_prirazeni SET TAGS ('description_en' = 'Diagnostic hash of the nested column assignment. It does not take part in the version decision.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.obchodnik ALTER COLUMN platnost_od_ts SET TAGS ('description_en' = 'Point in time from which this version is valid, taken from the source change timestamp.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.obchodnik ALTER COLUMN hash_zaznamu SET TAGS ('description_en' = 'The decision hash over all business columns and the only column in the dbt check_cols. Nested arrays must be sorted by a stable key before hashing.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.obchodnik ALTER COLUMN __nacteno_ts SET TAGS ('description_en' = 'Timestamp of when the record was inserted into this silver table.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.obchodnik ALTER COLUMN obchodnik_hkey SET TAGS ('data_classification' = 'confidential');

-- ========================= dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.obchodnik_hist =========================
-- SCD2 history | grain: Jeden řádek na obchodníka | sources: KCL
CREATE TABLE IF NOT EXISTS dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.obchodnik_hist (
    obchodnik_hkey            STRING NOT NULL  COMMENT 'Hash přirozeného klíče (obchodnik_login). Identifikuje entitu, je stabilní napříč verzemi a slouží jako cíl odkazů z jiných entit i jako unique_key snapshotu v dbt.',
    obchodnik_login           STRING NOT NULL  COMMENT 'Domain login obchodníka. Jediný identifikátor, který nesou všechny zdroje, proto je přirozeným klíčem.',
    obchodnik_cdu_id          BIGINT  COMMENT 'CDU identifikátor obchodníka.',
    obchodnik_oid             BIGINT  COMMENT 'OID obchodníka.',
    jmeno                     STRING  COMMENT 'Křestní jméno obchodníka.',
    prijmeni                  STRING  COMMENT 'Příjmení obchodníka.',
    role_obchodnika_kod       STRING NOT NULL  COMMENT 'Kanonická role: PVZ_OBCHODNIK, OBCHODNIK, MANAZER_SKUPINY, OBLASTNI_REDITEL, REGIONALNI_REDITEL nebo ADMINISTRATIVA.',
    uroven_hierarchie         INT NOT NULL  COMMENT 'Pozice v obchodní hierarchii, 1 pro PVZ obchodníka až 5 pro regionálního ředitele.',
    nadrizeny_obchodnik_hkey  STRING  COMMENT 'Přímý nadřízený obchodníka.',
    verejny_zaznam_priznak    BOOLEAN NOT NULL  COMMENT 'TRUE pro veřejný záznam, FALSE pro technický sloužící jen ke konstrukci struktury.',
    spolecnost_kod            BIGINT NOT NULL  COMMENT 'Společnost skupiny.',
    prirazeni                 
        ARRAY<STRUCT<`organizacni_jednotka_hkey`: STRING, `oblast_id`: BIGINT, `region_id`: BIGINT, `kanal_id`: INT, `ziskatelske_cislo`: STRING, `osobni_cislo`: BIGINT>> NOT NULL  COMMENT 'Přiřazení obchodníka k oblasti, regionu a kanálu, každé se získatelským a osobním číslem. Vnořené, protože obchodník jich má několik současně a zdroj to vyjadřuje opakováním celého řádku.',
    __zdrojovy_system         STRING NOT NULL  COMMENT 'Zdrojový systém, ze kterého byl záznam načten. Přebírá se z metadatového sloupce __source_system odpovídající bronze tabulky.',
    __zdrojova_tabulka_nazev  STRING NOT NULL  COMMENT 'Plně kvalifikovaná bronze tabulka, ze které byl záznam načten. U konformovaných entit plněných z více bronze tabulek je to jediný údaj, který rozliší původ konkrétního řádku.',
    hash_prirazeni            STRING  COMMENT 'Diagnostický hash vnořeného sloupce prirazeni. Neúčastní se rozhodnutí o nové verzi, slouží jen ke zjištění, která oblast se změnila. Pole se před hashováním řadí podle stabilního klíče.',
    verze_id                  STRING NOT NULL  COMMENT 'Identifikátor jedné verze záznamu, md5 hash přirozeného klíče a indikátoru změny, takže se liší verzi od verze. U snapshotů ho plní dbt jako dbt_scd_id, u inkrementálních tabulek ho stejným způsobem počítá plnění. Není to identita entity - tu nese <entita>_hkey, který zůstává napříč verzemi stejný.',
    platnost_od_ts            TIMESTAMP NOT NULL  COMMENT 'Okamžik, od kterého byla tato verze platná. U inkrementálních tabulek čas poslední změny ve zdroji, u snapshotů čas běhu, kdy byl stav pozorován.',
    platnost_do_ts            TIMESTAMP NOT NULL  COMMENT 'Okamžik, do kterého byla verze platná. Otevřená verze nese 9999-12-31 místo NULL, aby porovnávání období nemuselo řešit NULL. Otevřená verze je právě ta, která je v tabulce aktuálního stavu.',
    hash_zaznamu              STRING NOT NULL  COMMENT 'Rozhodovací hash přes všechny byznysové sloupce této verze. Technické sloupce do hashe nevstupují a vnořená pole se před hashováním řadí podle stabilního klíče.',
    __nacteno_ts              TIMESTAMP NOT NULL  COMMENT 'Časové razítko, kdy byla verze vložena do této silver tabulky.',
    __dbt_updated_at          TIMESTAMP NOT NULL  COMMENT 'Vnitřní pracovní značka dbt, proti které se při dalším běhu porovnává stav zdroje. Nese tutéž hodnotu jako platnost_od_ts, protože dbt zapisuje obě meta pole zvlášť a namapovat je na jeden sloupec nelze; rozejít se mohou jedině při zneplatnění smazaného záznamu. Prefix __ a jméno dbt v názvu říkají, že jde o technický sloupec nástroje - pro dotazy používejte platnost_od_ts. Vzniká jen u tabulek plněných snapshotem.',
    CONSTRAINT pk_obchodnik_hist PRIMARY KEY (obchodnik_hkey, platnost_od_ts) NOT ENFORCED
)
USING DELTA
COMMENT 'Historie SCD2 entity obchodnik. Jeden řádek na verzi, platnou mezi platnost_od_ts a platnost_do_ts. Kanonický obchodník. Tvoří se výhradně z organizačních tabulek KCL, nikoliv z odkazů na obchodníka v HUGO, LISA, TIA, KDP a REDy - ty na entitu jen odkazují přes domain login. Jedna entita pro všech šest rolí, které organizační struktura KCL rozlišuje vlastní tabulkou. Role a pozice v hierarchii se stávají atributy, přiřazení k oblasti, regionu a kanálu jsou vnořená, protože jeden člověk jich drží několik zároveň.'
CLUSTER BY (obchodnik_hkey, platnost_od_ts)
TBLPROPERTIES (
    'delta.columnMapping.mode'   = 'name',
    'delta.enableChangeDataFeed' = 'true',
    'model.layer'                = 'silver',
    'model.table_kind'           = 'history'
);
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.obchodnik_hist SET TAGS ('description_en' = 'SCD2 history of agent, one row per version valid between valid_from_timestamp and valid_to_timestamp. Canonical sales person. Built exclusively from the KCL organisational tables, not from the agent references in HUGO, LISA, TIA, KDP and REDy, which only point at the entity by domain login. One entity for all six roles the KCL structure keeps in a table of its own: sub-agent seller, seller, group manager, district director, regional director and administration employee. The role and the position in the hierarchy become attributes, and the assignments to agency, region and channel are nested, because one person legitimately holds several of them at the same time.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.obchodnik_hist ALTER COLUMN obchodnik_hkey SET TAGS ('description_en' = 'Hash of the natural key (obchodnik_login). Identifies the entity, is stable across versions and serves both as the reference target and as the dbt snapshot unique_key.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.obchodnik_hist ALTER COLUMN obchodnik_login SET TAGS ('description_en' = 'Domain login of the agent, the only identifier all sources carry.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.obchodnik_hist ALTER COLUMN obchodnik_cdu_id SET TAGS ('description_en' = 'CDU identifier of the agent.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.obchodnik_hist ALTER COLUMN obchodnik_oid SET TAGS ('description_en' = 'OID of the agent.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.obchodnik_hist ALTER COLUMN jmeno SET TAGS ('description_en' = 'First name.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.obchodnik_hist ALTER COLUMN prijmeni SET TAGS ('description_en' = 'Surname.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.obchodnik_hist ALTER COLUMN role_obchodnika_kod SET TAGS ('description_en' = 'Canonical role: sub-agent seller, seller, group manager, district director, regionaldirector or administration. Derived from which KCL table the row came from.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.obchodnik_hist ALTER COLUMN uroven_hierarchie SET TAGS ('description_en' = 'Position in the sales hierarchy, 1 for the sub-agent seller up to 5 for the regionaldirector. It lets the hierarchy be walked without knowing the source table names.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.obchodnik_hist ALTER COLUMN nadrizeny_obchodnik_hkey SET TAGS ('description_en' = 'Immediate superior of the agent.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.obchodnik_hist ALTER COLUMN verejny_zaznam_priznak SET TAGS ('description_en' = 'TRUE for a public record, FALSE for a technical one.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.obchodnik_hist ALTER COLUMN spolecnost_kod SET TAGS ('description_en' = 'Group company.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.obchodnik_hist ALTER COLUMN prirazeni SET TAGS ('description_en' = 'Assignments of the agent to an agency, a region and a distribution channel, each withthe acquisition and personnel numbers valid there. Nested, because one agent holdsseveral at the same time and the source repeats the whole row.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.obchodnik_hist ALTER COLUMN __zdrojovy_system SET TAGS ('description_en' = 'Source system the record was loaded from, taken from the __source_system metadata column of the bronze table.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.obchodnik_hist ALTER COLUMN __zdrojova_tabulka_nazev SET TAGS ('description_en' = 'Fully qualified bronze table the record was loaded from. For conformed entities fedfrom several bronze tables it is the only value that tells the origin of a row apart.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.obchodnik_hist ALTER COLUMN hash_prirazeni SET TAGS ('description_en' = 'Diagnostic hash of the nested column assignment. It does not take part in the version decision.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.obchodnik_hist ALTER COLUMN verze_id SET TAGS ('description_en' = 'Identifier of a single version, an md5 hash of the natural key and the change indicator. Filled by dbt_scd_id on snapshots and computed the same way by the load on incremental tables. It is not the entity identity.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.obchodnik_hist ALTER COLUMN platnost_od_ts SET TAGS ('description_en' = 'Point in time from which this version was valid. Part of the history primary key.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.obchodnik_hist ALTER COLUMN platnost_do_ts SET TAGS ('description_en' = 'Point in time until which this version was valid; the open version carries 9999-12-31.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.obchodnik_hist ALTER COLUMN hash_zaznamu SET TAGS ('description_en' = 'The decision hash over all business columns of this version.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.obchodnik_hist ALTER COLUMN __nacteno_ts SET TAGS ('description_en' = 'Timestamp of when the version was inserted into this silver table.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.obchodnik_hist ALTER COLUMN __dbt_updated_at SET TAGS ('description_en' = 'An internal dbt working marker. It carries the same value as the valid-from column; the two can only diverge when a hard-deleted record is invalidated. Only snapshot tables have it.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.obchodnik_hist ALTER COLUMN obchodnik_hkey SET TAGS ('data_classification' = 'confidential');

-- ========================= dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.organizacni_jednotka =========================
-- current state | grain: Jeden řádek na organizační jednotku | sources: KCL
CREATE TABLE IF NOT EXISTS dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.organizacni_jednotka (
    organizacni_jednotka_hkey  STRING NOT NULL  COMMENT 'Hash přirozeného klíče (kanal_id + region_id + oblast_id). Identifikuje entitu, je stabilní napříč verzemi a slouží jako cíl odkazů z jiných entit i jako unique_key snapshotu v dbt.',
    kanal_id                   INT NOT NULL  COMMENT 'ID distribučního kanálu.',
    region_id                  BIGINT  COMMENT 'ID regionu.',
    oblast_id                  BIGINT  COMMENT 'ID oblasti. Pro jednotku na úrovni regionu se rovná ID regionu.',
    jednotka_nazev             STRING  COMMENT 'Název jednotky.',
    uroven_jednotky            INT NOT NULL  COMMENT 'Úroveň jednotky: 1 oblast, 2 region, 3 kanál.',
    nadrizena_jednotka_hkey    STRING  COMMENT 'Jednotka o úroveň výš.',
    spolecnost_kod             BIGINT NOT NULL  COMMENT 'Společnost skupiny.',
    __zdrojovy_system          STRING NOT NULL  COMMENT 'Zdrojový systém, ze kterého byl záznam načten. Přebírá se z metadatového sloupce __source_system odpovídající bronze tabulky.',
    __zdrojova_tabulka_nazev   STRING NOT NULL  COMMENT 'Plně kvalifikovaná bronze tabulka, ze které byl záznam načten. U konformovaných entit plněných z více bronze tabulek je to jediný údaj, který rozliší původ konkrétního řádku.',
    platnost_od_ts             TIMESTAMP NOT NULL  COMMENT 'Okamžik, od kterého je tato verze řádku platná. U inkrementálních tabulek se plní časem poslední změny ve zdroji: u sync topiků z dataUpdatedAt, u delete topiků z auditInformation.lastUpdatedAt. U tabulek plněných snapshotem nese čas běhu, tedy okamžik, kdy jsme stav pozorovali - zdroj posílá celý snímek a vlastní čas změny u číselníků nenabízí.',
    hash_zaznamu               STRING NOT NULL  COMMENT 'Rozhodovací hash přes všechny byznysové sloupce. Podle něj se pozná skutečná změna a v dbt je to jediný sloupec v check_cols. Technické sloupce do hashe nevstupují, jinak by vznikala nová verze při každém běhu, a vnořená pole se před hashováním řadí podle stabilního klíče, jinak by jiné pořadí prvků vypadalo jako změna.',
    __nacteno_ts               TIMESTAMP NOT NULL  COMMENT 'Časové razítko, kdy byl záznam vložen do této silver tabulky.',
    CONSTRAINT pk_organizacni_jednotka PRIMARY KEY (organizacni_jednotka_hkey) NOT ENFORCED
)
USING DELTA
COMMENT 'Jednotka obchodní organizace: distribuční kanál, region nebo oblast. Jedna entita s atributem úrovně místo tří tabulek, což umožňuje projít hierarchii jedním rekurzivním spojením.'
CLUSTER BY (organizacni_jednotka_hkey)
TBLPROPERTIES (
    'delta.columnMapping.mode'   = 'name',
    'delta.enableChangeDataFeed' = 'true',
    'model.layer'                = 'silver',
    'model.table_kind'           = 'current'
);
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.organizacni_jednotka SET TAGS ('description_en' = 'Unit of the sales organisation: a distribution channel, a region or an agency. One entity with a level attribute rather than three tables, which is what lets the hierarchy be walked with a single recursive join.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.organizacni_jednotka ALTER COLUMN organizacni_jednotka_hkey SET TAGS ('description_en' = 'Hash of the natural key (kanal_id + region_id + oblast_id). Identifies the entity, is stable across versions and serves both as the reference target and as the dbt snapshot unique_key.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.organizacni_jednotka ALTER COLUMN kanal_id SET TAGS ('description_en' = 'Distribution channel identifier.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.organizacni_jednotka ALTER COLUMN region_id SET TAGS ('description_en' = 'Region identifier.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.organizacni_jednotka ALTER COLUMN oblast_id SET TAGS ('description_en' = 'Agency identifier, equal to the region identifier at region level.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.organizacni_jednotka ALTER COLUMN jednotka_nazev SET TAGS ('description_en' = 'Name of the unit.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.organizacni_jednotka ALTER COLUMN uroven_jednotky SET TAGS ('description_en' = 'Level: 1 agency, 2 region, 3 channel.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.organizacni_jednotka ALTER COLUMN nadrizena_jednotka_hkey SET TAGS ('description_en' = 'Unit one level up.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.organizacni_jednotka ALTER COLUMN spolecnost_kod SET TAGS ('description_en' = 'Group company.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.organizacni_jednotka ALTER COLUMN __zdrojovy_system SET TAGS ('description_en' = 'Source system the record was loaded from, taken from the __source_system metadata column of the bronze table.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.organizacni_jednotka ALTER COLUMN __zdrojova_tabulka_nazev SET TAGS ('description_en' = 'Fully qualified bronze table the record was loaded from. For conformed entities fedfrom several bronze tables it is the only value that tells the origin of a row apart.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.organizacni_jednotka ALTER COLUMN platnost_od_ts SET TAGS ('description_en' = 'Point in time from which this version is valid, taken from the source change timestamp.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.organizacni_jednotka ALTER COLUMN hash_zaznamu SET TAGS ('description_en' = 'The decision hash over all business columns and the only column in the dbt check_cols. Nested arrays must be sorted by a stable key before hashing.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.organizacni_jednotka ALTER COLUMN __nacteno_ts SET TAGS ('description_en' = 'Timestamp of when the record was inserted into this silver table.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.organizacni_jednotka ALTER COLUMN organizacni_jednotka_hkey SET TAGS ('data_classification' = 'confidential');

-- ========================= dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.organizacni_jednotka_hist =========================
-- SCD2 history | grain: Jeden řádek na organizační jednotku | sources: KCL
CREATE TABLE IF NOT EXISTS dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.organizacni_jednotka_hist (
    organizacni_jednotka_hkey  STRING NOT NULL  COMMENT 'Hash přirozeného klíče (kanal_id + region_id + oblast_id). Identifikuje entitu, je stabilní napříč verzemi a slouží jako cíl odkazů z jiných entit i jako unique_key snapshotu v dbt.',
    kanal_id                   INT NOT NULL  COMMENT 'ID distribučního kanálu.',
    region_id                  BIGINT  COMMENT 'ID regionu.',
    oblast_id                  BIGINT  COMMENT 'ID oblasti. Pro jednotku na úrovni regionu se rovná ID regionu.',
    jednotka_nazev             STRING  COMMENT 'Název jednotky.',
    uroven_jednotky            INT NOT NULL  COMMENT 'Úroveň jednotky: 1 oblast, 2 region, 3 kanál.',
    nadrizena_jednotka_hkey    STRING  COMMENT 'Jednotka o úroveň výš.',
    spolecnost_kod             BIGINT NOT NULL  COMMENT 'Společnost skupiny.',
    __zdrojovy_system          STRING NOT NULL  COMMENT 'Zdrojový systém, ze kterého byl záznam načten. Přebírá se z metadatového sloupce __source_system odpovídající bronze tabulky.',
    __zdrojova_tabulka_nazev   STRING NOT NULL  COMMENT 'Plně kvalifikovaná bronze tabulka, ze které byl záznam načten. U konformovaných entit plněných z více bronze tabulek je to jediný údaj, který rozliší původ konkrétního řádku.',
    verze_id                   STRING NOT NULL  COMMENT 'Identifikátor jedné verze záznamu, md5 hash přirozeného klíče a indikátoru změny, takže se liší verzi od verze. U snapshotů ho plní dbt jako dbt_scd_id, u inkrementálních tabulek ho stejným způsobem počítá plnění. Není to identita entity - tu nese <entita>_hkey, který zůstává napříč verzemi stejný.',
    platnost_od_ts             TIMESTAMP NOT NULL  COMMENT 'Okamžik, od kterého byla tato verze platná. U inkrementálních tabulek čas poslední změny ve zdroji, u snapshotů čas běhu, kdy byl stav pozorován.',
    platnost_do_ts             TIMESTAMP NOT NULL  COMMENT 'Okamžik, do kterého byla verze platná. Otevřená verze nese 9999-12-31 místo NULL, aby porovnávání období nemuselo řešit NULL. Otevřená verze je právě ta, která je v tabulce aktuálního stavu.',
    hash_zaznamu               STRING NOT NULL  COMMENT 'Rozhodovací hash přes všechny byznysové sloupce této verze. Technické sloupce do hashe nevstupují a vnořená pole se před hashováním řadí podle stabilního klíče.',
    __nacteno_ts               TIMESTAMP NOT NULL  COMMENT 'Časové razítko, kdy byla verze vložena do této silver tabulky.',
    __dbt_updated_at           TIMESTAMP NOT NULL  COMMENT 'Vnitřní pracovní značka dbt, proti které se při dalším běhu porovnává stav zdroje. Nese tutéž hodnotu jako platnost_od_ts, protože dbt zapisuje obě meta pole zvlášť a namapovat je na jeden sloupec nelze; rozejít se mohou jedině při zneplatnění smazaného záznamu. Prefix __ a jméno dbt v názvu říkají, že jde o technický sloupec nástroje - pro dotazy používejte platnost_od_ts. Vzniká jen u tabulek plněných snapshotem.',
    CONSTRAINT pk_organizacni_jednotka_hist PRIMARY KEY (organizacni_jednotka_hkey, platnost_od_ts) NOT ENFORCED
)
USING DELTA
COMMENT 'Historie SCD2 entity organizacni_jednotka. Jeden řádek na verzi, platnou mezi platnost_od_ts a platnost_do_ts. Jednotka obchodní organizace: distribuční kanál, region nebo oblast. Jedna entita s atributem úrovně místo tří tabulek, což umožňuje projít hierarchii jedním rekurzivním spojením.'
CLUSTER BY (organizacni_jednotka_hkey, platnost_od_ts)
TBLPROPERTIES (
    'delta.columnMapping.mode'   = 'name',
    'delta.enableChangeDataFeed' = 'true',
    'model.layer'                = 'silver',
    'model.table_kind'           = 'history'
);
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.organizacni_jednotka_hist SET TAGS ('description_en' = 'SCD2 history of organisation_unit, one row per version valid between valid_from_timestamp and valid_to_timestamp. Unit of the sales organisation: a distribution channel, a region or an agency. One entity with a level attribute rather than three tables, which is what lets the hierarchy be walked with a single recursive join.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.organizacni_jednotka_hist ALTER COLUMN organizacni_jednotka_hkey SET TAGS ('description_en' = 'Hash of the natural key (kanal_id + region_id + oblast_id). Identifies the entity, is stable across versions and serves both as the reference target and as the dbt snapshot unique_key.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.organizacni_jednotka_hist ALTER COLUMN kanal_id SET TAGS ('description_en' = 'Distribution channel identifier.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.organizacni_jednotka_hist ALTER COLUMN region_id SET TAGS ('description_en' = 'Region identifier.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.organizacni_jednotka_hist ALTER COLUMN oblast_id SET TAGS ('description_en' = 'Agency identifier, equal to the region identifier at region level.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.organizacni_jednotka_hist ALTER COLUMN jednotka_nazev SET TAGS ('description_en' = 'Name of the unit.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.organizacni_jednotka_hist ALTER COLUMN uroven_jednotky SET TAGS ('description_en' = 'Level: 1 agency, 2 region, 3 channel.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.organizacni_jednotka_hist ALTER COLUMN nadrizena_jednotka_hkey SET TAGS ('description_en' = 'Unit one level up.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.organizacni_jednotka_hist ALTER COLUMN spolecnost_kod SET TAGS ('description_en' = 'Group company.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.organizacni_jednotka_hist ALTER COLUMN __zdrojovy_system SET TAGS ('description_en' = 'Source system the record was loaded from, taken from the __source_system metadata column of the bronze table.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.organizacni_jednotka_hist ALTER COLUMN __zdrojova_tabulka_nazev SET TAGS ('description_en' = 'Fully qualified bronze table the record was loaded from. For conformed entities fedfrom several bronze tables it is the only value that tells the origin of a row apart.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.organizacni_jednotka_hist ALTER COLUMN verze_id SET TAGS ('description_en' = 'Identifier of a single version, an md5 hash of the natural key and the change indicator. Filled by dbt_scd_id on snapshots and computed the same way by the load on incremental tables. It is not the entity identity.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.organizacni_jednotka_hist ALTER COLUMN platnost_od_ts SET TAGS ('description_en' = 'Point in time from which this version was valid. Part of the history primary key.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.organizacni_jednotka_hist ALTER COLUMN platnost_do_ts SET TAGS ('description_en' = 'Point in time until which this version was valid; the open version carries 9999-12-31.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.organizacni_jednotka_hist ALTER COLUMN hash_zaznamu SET TAGS ('description_en' = 'The decision hash over all business columns of this version.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.organizacni_jednotka_hist ALTER COLUMN __nacteno_ts SET TAGS ('description_en' = 'Timestamp of when the version was inserted into this silver table.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.organizacni_jednotka_hist ALTER COLUMN __dbt_updated_at SET TAGS ('description_en' = 'An internal dbt working marker. It carries the same value as the valid-from column; the two can only diverge when a hard-deleted record is invalidated. Only snapshot tables have it.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.organizacni_jednotka_hist ALTER COLUMN organizacni_jednotka_hkey SET TAGS ('data_classification' = 'confidential');

-- ========================= dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kampan =========================
-- current state | grain: Jeden řádek na kampaň | sources: KCL
CREATE TABLE IF NOT EXISTS dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kampan (
    kampan_hkey                STRING NOT NULL  COMMENT 'Hash přirozeného klíče (kampan_id). Identifikuje entitu, je stabilní napříč verzemi a slouží jako cíl odkazů z jiných entit i jako unique_key snapshotu v dbt.',
    kampan_id                  BIGINT NOT NULL  COMMENT 'ID kampaně.',
    kampan_kod                 STRING  COMMENT 'Kód kampaně.',
    kampan_nazev               STRING  COMMENT 'Název kampaně.',
    kampan_popis               STRING  COMMENT 'Popis kampaně.',
    typ_kampane_kod            INT  COMMENT 'Typ kampaně: 0 standardní, 3 dožití.',
    mikrokampan_priznak        BOOLEAN  COMMENT 'TRUE pro mikrokampaň.',
    zakladatel_obchodnik_hkey  STRING  COMMENT 'Obchodník, který mikrokampaň založil.',
    distribucni_kanal_hkey     STRING  COMMENT 'Kanál kampaně.',
    komunikace_kod             STRING  COMMENT 'Kód komunikace.',
    komunikace_nazev           STRING  COMMENT 'Název komunikace.',
    zacatek_datum              DATE  COMMENT 'Začátek kampaně.',
    konec_datum                DATE  COMMENT 'Konec kampaně, včetně celého posledního dne.',
    platnost_do_datum          DATE  COMMENT 'Příznak vymazání kampaně. Null znamená stále aktivní.',
    ocekavana_hodnota_castka   DECIMAL(38,2)  COMMENT 'Očekávaná produkce na kontakt. Pouze standardní kampaně.',
    plan_produkce_castka       DECIMAL(38,2)  COMMENT 'Očekávaná celková produkce na kampaň. Pouze kampaně dožití.',
    ocekavana_nahrada_hodnota  DECIMAL(38,2)  COMMENT 'Očekávaná náhrada životního pojištění v procentech.',
    spolecnost_kod             BIGINT NOT NULL  COMMENT 'Společnost skupiny.',
    __zdrojovy_system          STRING NOT NULL  COMMENT 'Zdrojový systém, ze kterého byl záznam načten. Přebírá se z metadatového sloupce __source_system odpovídající bronze tabulky.',
    __zdrojova_tabulka_nazev   STRING NOT NULL  COMMENT 'Plně kvalifikovaná bronze tabulka, ze které byl záznam načten. U konformovaných entit plněných z více bronze tabulek je to jediný údaj, který rozliší původ konkrétního řádku.',
    platnost_od_ts             TIMESTAMP NOT NULL  COMMENT 'Okamžik, od kterého je tato verze řádku platná. U inkrementálních tabulek se plní časem poslední změny ve zdroji: u sync topiků z dataUpdatedAt, u delete topiků z auditInformation.lastUpdatedAt. U tabulek plněných snapshotem nese čas běhu, tedy okamžik, kdy jsme stav pozorovali - zdroj posílá celý snímek a vlastní čas změny u číselníků nenabízí.',
    hash_zaznamu               STRING NOT NULL  COMMENT 'Rozhodovací hash přes všechny byznysové sloupce. Podle něj se pozná skutečná změna a v dbt je to jediný sloupec v check_cols. Technické sloupce do hashe nevstupují, jinak by vznikala nová verze při každém běhu, a vnořená pole se před hashováním řadí podle stabilního klíče, jinak by jiné pořadí prvků vypadalo jako změna.',
    __nacteno_ts               TIMESTAMP NOT NULL  COMMENT 'Časové razítko, kdy byl záznam vložen do této silver tabulky.',
    CONSTRAINT pk_kampan PRIMARY KEY (kampan_hkey) NOT ENFORCED
)
USING DELTA
COMMENT 'Obchodní kampaň, ve zdroji nazvaná vlna kampaně. Řádky se na zdroji nemažou; kampaň přestává být platná, jakmile je datum konce platnosti v minulosti.'
CLUSTER BY (kampan_hkey)
TBLPROPERTIES (
    'delta.columnMapping.mode'   = 'name',
    'delta.enableChangeDataFeed' = 'true',
    'model.layer'                = 'silver',
    'model.table_kind'           = 'current'
);
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kampan SET TAGS ('description_en' = 'Sales campaign, called a campaign wave in the source. Rows are never deleted at the source; a campaign stops being valid once its valid to date is in the past.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kampan ALTER COLUMN kampan_hkey SET TAGS ('description_en' = 'Hash of the natural key (kampan_id). Identifies the entity, is stable across versions and serves both as the reference target and as the dbt snapshot unique_key.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kampan ALTER COLUMN kampan_id SET TAGS ('description_en' = 'Identifier of the campaign.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kampan ALTER COLUMN kampan_kod SET TAGS ('description_en' = 'Code of the campaign.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kampan ALTER COLUMN kampan_nazev SET TAGS ('description_en' = 'Name of the campaign.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kampan ALTER COLUMN kampan_popis SET TAGS ('description_en' = 'Description.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kampan ALTER COLUMN typ_kampane_kod SET TAGS ('description_en' = 'Type: 0 standard, 3 maturity.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kampan ALTER COLUMN mikrokampan_priznak SET TAGS ('description_en' = 'TRUE for a micro campaign.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kampan ALTER COLUMN zakladatel_obchodnik_hkey SET TAGS ('description_en' = 'Agent who founded the micro campaign.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kampan ALTER COLUMN distribucni_kanal_hkey SET TAGS ('description_en' = 'Channel of the campaign.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kampan ALTER COLUMN komunikace_kod SET TAGS ('description_en' = 'Communication code.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kampan ALTER COLUMN komunikace_nazev SET TAGS ('description_en' = 'Communication name.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kampan ALTER COLUMN zacatek_datum SET TAGS ('description_en' = 'Start of the campaign.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kampan ALTER COLUMN konec_datum SET TAGS ('description_en' = 'End of the campaign.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kampan ALTER COLUMN platnost_do_datum SET TAGS ('description_en' = 'Deletion flag; null means still active.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kampan ALTER COLUMN ocekavana_hodnota_castka SET TAGS ('description_en' = 'Expected production per contact.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kampan ALTER COLUMN plan_produkce_castka SET TAGS ('description_en' = 'Expected total production for the campaign.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kampan ALTER COLUMN ocekavana_nahrada_hodnota SET TAGS ('description_en' = 'Expected replacement of life insurance, in percent.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kampan ALTER COLUMN spolecnost_kod SET TAGS ('description_en' = 'Group company.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kampan ALTER COLUMN __zdrojovy_system SET TAGS ('description_en' = 'Source system the record was loaded from, taken from the __source_system metadata column of the bronze table.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kampan ALTER COLUMN __zdrojova_tabulka_nazev SET TAGS ('description_en' = 'Fully qualified bronze table the record was loaded from. For conformed entities fedfrom several bronze tables it is the only value that tells the origin of a row apart.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kampan ALTER COLUMN platnost_od_ts SET TAGS ('description_en' = 'Point in time from which this version is valid, taken from the source change timestamp.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kampan ALTER COLUMN hash_zaznamu SET TAGS ('description_en' = 'The decision hash over all business columns and the only column in the dbt check_cols. Nested arrays must be sorted by a stable key before hashing.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kampan ALTER COLUMN __nacteno_ts SET TAGS ('description_en' = 'Timestamp of when the record was inserted into this silver table.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kampan ALTER COLUMN kampan_hkey SET TAGS ('data_classification' = 'confidential');

-- ========================= dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kampan_hist =========================
-- SCD2 history | grain: Jeden řádek na kampaň | sources: KCL
CREATE TABLE IF NOT EXISTS dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kampan_hist (
    kampan_hkey                STRING NOT NULL  COMMENT 'Hash přirozeného klíče (kampan_id). Identifikuje entitu, je stabilní napříč verzemi a slouží jako cíl odkazů z jiných entit i jako unique_key snapshotu v dbt.',
    kampan_id                  BIGINT NOT NULL  COMMENT 'ID kampaně.',
    kampan_kod                 STRING  COMMENT 'Kód kampaně.',
    kampan_nazev               STRING  COMMENT 'Název kampaně.',
    kampan_popis               STRING  COMMENT 'Popis kampaně.',
    typ_kampane_kod            INT  COMMENT 'Typ kampaně: 0 standardní, 3 dožití.',
    mikrokampan_priznak        BOOLEAN  COMMENT 'TRUE pro mikrokampaň.',
    zakladatel_obchodnik_hkey  STRING  COMMENT 'Obchodník, který mikrokampaň založil.',
    distribucni_kanal_hkey     STRING  COMMENT 'Kanál kampaně.',
    komunikace_kod             STRING  COMMENT 'Kód komunikace.',
    komunikace_nazev           STRING  COMMENT 'Název komunikace.',
    zacatek_datum              DATE  COMMENT 'Začátek kampaně.',
    konec_datum                DATE  COMMENT 'Konec kampaně, včetně celého posledního dne.',
    platnost_do_datum          DATE  COMMENT 'Příznak vymazání kampaně. Null znamená stále aktivní.',
    ocekavana_hodnota_castka   DECIMAL(38,2)  COMMENT 'Očekávaná produkce na kontakt. Pouze standardní kampaně.',
    plan_produkce_castka       DECIMAL(38,2)  COMMENT 'Očekávaná celková produkce na kampaň. Pouze kampaně dožití.',
    ocekavana_nahrada_hodnota  DECIMAL(38,2)  COMMENT 'Očekávaná náhrada životního pojištění v procentech.',
    spolecnost_kod             BIGINT NOT NULL  COMMENT 'Společnost skupiny.',
    __zdrojovy_system          STRING NOT NULL  COMMENT 'Zdrojový systém, ze kterého byl záznam načten. Přebírá se z metadatového sloupce __source_system odpovídající bronze tabulky.',
    __zdrojova_tabulka_nazev   STRING NOT NULL  COMMENT 'Plně kvalifikovaná bronze tabulka, ze které byl záznam načten. U konformovaných entit plněných z více bronze tabulek je to jediný údaj, který rozliší původ konkrétního řádku.',
    verze_id                   STRING NOT NULL  COMMENT 'Identifikátor jedné verze záznamu, md5 hash přirozeného klíče a indikátoru změny, takže se liší verzi od verze. U snapshotů ho plní dbt jako dbt_scd_id, u inkrementálních tabulek ho stejným způsobem počítá plnění. Není to identita entity - tu nese <entita>_hkey, který zůstává napříč verzemi stejný.',
    platnost_od_ts             TIMESTAMP NOT NULL  COMMENT 'Okamžik, od kterého byla tato verze platná. U inkrementálních tabulek čas poslední změny ve zdroji, u snapshotů čas běhu, kdy byl stav pozorován.',
    platnost_do_ts             TIMESTAMP NOT NULL  COMMENT 'Okamžik, do kterého byla verze platná. Otevřená verze nese 9999-12-31 místo NULL, aby porovnávání období nemuselo řešit NULL. Otevřená verze je právě ta, která je v tabulce aktuálního stavu.',
    hash_zaznamu               STRING NOT NULL  COMMENT 'Rozhodovací hash přes všechny byznysové sloupce této verze. Technické sloupce do hashe nevstupují a vnořená pole se před hashováním řadí podle stabilního klíče.',
    __nacteno_ts               TIMESTAMP NOT NULL  COMMENT 'Časové razítko, kdy byla verze vložena do této silver tabulky.',
    __dbt_updated_at           TIMESTAMP NOT NULL  COMMENT 'Vnitřní pracovní značka dbt, proti které se při dalším běhu porovnává stav zdroje. Nese tutéž hodnotu jako platnost_od_ts, protože dbt zapisuje obě meta pole zvlášť a namapovat je na jeden sloupec nelze; rozejít se mohou jedině při zneplatnění smazaného záznamu. Prefix __ a jméno dbt v názvu říkají, že jde o technický sloupec nástroje - pro dotazy používejte platnost_od_ts. Vzniká jen u tabulek plněných snapshotem.',
    CONSTRAINT pk_kampan_hist PRIMARY KEY (kampan_hkey, platnost_od_ts) NOT ENFORCED
)
USING DELTA
COMMENT 'Historie SCD2 entity kampan. Jeden řádek na verzi, platnou mezi platnost_od_ts a platnost_do_ts. Obchodní kampaň, ve zdroji nazvaná vlna kampaně. Řádky se na zdroji nemažou; kampaň přestává být platná, jakmile je datum konce platnosti v minulosti.'
CLUSTER BY (kampan_hkey, platnost_od_ts)
TBLPROPERTIES (
    'delta.columnMapping.mode'   = 'name',
    'delta.enableChangeDataFeed' = 'true',
    'model.layer'                = 'silver',
    'model.table_kind'           = 'history'
);
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kampan_hist SET TAGS ('description_en' = 'SCD2 history of campaign, one row per version valid between valid_from_timestamp and valid_to_timestamp. Sales campaign, called a campaign wave in the source. Rows are never deleted at the source; a campaign stops being valid once its valid to date is in the past.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kampan_hist ALTER COLUMN kampan_hkey SET TAGS ('description_en' = 'Hash of the natural key (kampan_id). Identifies the entity, is stable across versions and serves both as the reference target and as the dbt snapshot unique_key.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kampan_hist ALTER COLUMN kampan_id SET TAGS ('description_en' = 'Identifier of the campaign.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kampan_hist ALTER COLUMN kampan_kod SET TAGS ('description_en' = 'Code of the campaign.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kampan_hist ALTER COLUMN kampan_nazev SET TAGS ('description_en' = 'Name of the campaign.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kampan_hist ALTER COLUMN kampan_popis SET TAGS ('description_en' = 'Description.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kampan_hist ALTER COLUMN typ_kampane_kod SET TAGS ('description_en' = 'Type: 0 standard, 3 maturity.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kampan_hist ALTER COLUMN mikrokampan_priznak SET TAGS ('description_en' = 'TRUE for a micro campaign.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kampan_hist ALTER COLUMN zakladatel_obchodnik_hkey SET TAGS ('description_en' = 'Agent who founded the micro campaign.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kampan_hist ALTER COLUMN distribucni_kanal_hkey SET TAGS ('description_en' = 'Channel of the campaign.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kampan_hist ALTER COLUMN komunikace_kod SET TAGS ('description_en' = 'Communication code.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kampan_hist ALTER COLUMN komunikace_nazev SET TAGS ('description_en' = 'Communication name.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kampan_hist ALTER COLUMN zacatek_datum SET TAGS ('description_en' = 'Start of the campaign.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kampan_hist ALTER COLUMN konec_datum SET TAGS ('description_en' = 'End of the campaign.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kampan_hist ALTER COLUMN platnost_do_datum SET TAGS ('description_en' = 'Deletion flag; null means still active.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kampan_hist ALTER COLUMN ocekavana_hodnota_castka SET TAGS ('description_en' = 'Expected production per contact.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kampan_hist ALTER COLUMN plan_produkce_castka SET TAGS ('description_en' = 'Expected total production for the campaign.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kampan_hist ALTER COLUMN ocekavana_nahrada_hodnota SET TAGS ('description_en' = 'Expected replacement of life insurance, in percent.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kampan_hist ALTER COLUMN spolecnost_kod SET TAGS ('description_en' = 'Group company.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kampan_hist ALTER COLUMN __zdrojovy_system SET TAGS ('description_en' = 'Source system the record was loaded from, taken from the __source_system metadata column of the bronze table.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kampan_hist ALTER COLUMN __zdrojova_tabulka_nazev SET TAGS ('description_en' = 'Fully qualified bronze table the record was loaded from. For conformed entities fedfrom several bronze tables it is the only value that tells the origin of a row apart.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kampan_hist ALTER COLUMN verze_id SET TAGS ('description_en' = 'Identifier of a single version, an md5 hash of the natural key and the change indicator. Filled by dbt_scd_id on snapshots and computed the same way by the load on incremental tables. It is not the entity identity.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kampan_hist ALTER COLUMN platnost_od_ts SET TAGS ('description_en' = 'Point in time from which this version was valid. Part of the history primary key.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kampan_hist ALTER COLUMN platnost_do_ts SET TAGS ('description_en' = 'Point in time until which this version was valid; the open version carries 9999-12-31.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kampan_hist ALTER COLUMN hash_zaznamu SET TAGS ('description_en' = 'The decision hash over all business columns of this version.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kampan_hist ALTER COLUMN __nacteno_ts SET TAGS ('description_en' = 'Timestamp of when the version was inserted into this silver table.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kampan_hist ALTER COLUMN __dbt_updated_at SET TAGS ('description_en' = 'An internal dbt working marker. It carries the same value as the valid-from column; the two can only diverge when a hard-deleted record is invalidated. Only snapshot tables have it.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kampan_hist ALTER COLUMN kampan_hkey SET TAGS ('data_classification' = 'confidential');

-- ========================= dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kontakt_v_kampani =========================
-- current state | grain: Jeden řádek na kontakt v kampani | sources: KCL
CREATE TABLE IF NOT EXISTS dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kontakt_v_kampani (
    kontakt_v_kampani_hkey     STRING NOT NULL  COMMENT 'Hash přirozeného klíče (kontakt_id). Identifikuje entitu, je stabilní napříč verzemi a slouží jako cíl odkazů z jiných entit i jako unique_key snapshotu v dbt.',
    kontakt_id                 BIGINT NOT NULL  COMMENT 'ID kontaktu.',
    kampan_hkey                STRING NOT NULL  COMMENT 'Kampaň, ke které kontakt patří.',
    partner_id                 STRING  COMMENT 'Identifikátor partnera, pokud je osoba klientem. Vyhodnocuje se přes mapovani_id_partnera.',
    crm_klient_id              STRING  COMMENT 'Identifikátor klienta z CRM. Nevyplněno pro neklienty.',
    klient_priznak             BOOLEAN NOT NULL  COMMENT 'TRUE, když je kontakt existujícím klientem.',
    stav_kontaktu_hkey         STRING  COMMENT 'Zadaná zpětná vazba ke kontaktu.',
    resitel_obchodnik_hkey     STRING  COMMENT 'Obchodník, kterému je kontakt přidělen.',
    organizacni_jednotka_hkey  STRING  COMMENT 'Organizační jednotka, které je kontakt přidělen.',
    smlouva_cislo              BIGINT  COMMENT 'Smlouva, ke které se kontakt vztahuje.',
    smlouva_hkey               STRING  COMMENT 'Smlouva vyhodnocená podle čísla.',
    produkt_kod                STRING  COMMENT 'Produkt podle CRM. Pokud jich smlouva má více, CRM bere jen jeden.',
    pojistne_castka            DECIMAL(38,2)  COMMENT 'Pojistné z CRM.',
    smlouva_konec_datum        DATE  COMMENT 'Konec platnosti smlouvy. Pouze životní pojištění.',
    ruian_adresni_bod_kod      BIGINT  COMMENT 'Adresní bod RUIAN kontaktu, používaný pro párování brutto produkce.',
    vytvoreno_ts               TIMESTAMP NOT NULL  COMMENT 'Kdy kontakt vznikl.',
    zmeneno_ts                 TIMESTAMP  COMMENT 'Kdy byl kontakt naposledy změněn.',
    posledni_prirazeni_datum   DATE  COMMENT 'Kdy byl kontakt naposledy přidělen.',
    spolecnost_kod             BIGINT NOT NULL  COMMENT 'Společnost skupiny.',
    snimek_klienta_crm         
        STRUCT<`jmeno`: STRING, `prijmeni`: STRING, `nazev_firmy`: STRING, `titul_pred`: STRING, `titul_za`: STRING, `rodne_cislo`: STRING, `ico`: STRING, `ulice_nazev`: STRING, `cislo_ulice`: STRING, `obec_nazev`: STRING, `psc`: STRING, `telefon_1`: STRING, `telefon_2`: STRING, `emailova_adresa`: STRING>  COMMENT 'Údaje o klientovi zkopírované z CRM, uchované přesně jak přišly, aby kampaň zůstala reprodukovatelná i po změně údajů u partnera.',
    __zdrojovy_system          STRING NOT NULL  COMMENT 'Zdrojový systém, ze kterého byl záznam načten. Přebírá se z metadatového sloupce __source_system odpovídající bronze tabulky.',
    __zdrojova_tabulka_nazev   STRING NOT NULL  COMMENT 'Plně kvalifikovaná bronze tabulka, ze které byl záznam načten. U konformovaných entit plněných z více bronze tabulek je to jediný údaj, který rozliší původ konkrétního řádku.',
    smazano_priznak            BOOLEAN NOT NULL  COMMENT 'TRUE, když zdroj oznámil smazání záznamu. Logické smazání, řádek zůstává, aby zůstala dohledatelná historie i odkazy.',
    hash_snimek_klienta_crm    STRING  COMMENT 'Diagnostický hash vnořeného sloupce snimek_klienta_crm. Neúčastní se rozhodnutí o nové verzi, slouží jen ke zjištění, která oblast se změnila. Pole se před hashováním řadí podle stabilního klíče.',
    platnost_od_ts             TIMESTAMP NOT NULL  COMMENT 'Okamžik, od kterého je tato verze řádku platná. U inkrementálních tabulek se plní časem poslední změny ve zdroji: u sync topiků z dataUpdatedAt, u delete topiků z auditInformation.lastUpdatedAt. U tabulek plněných snapshotem nese čas běhu, tedy okamžik, kdy jsme stav pozorovali - zdroj posílá celý snímek a vlastní čas změny u číselníků nenabízí.',
    hash_zaznamu               STRING NOT NULL  COMMENT 'Rozhodovací hash přes všechny byznysové sloupce. Podle něj se pozná skutečná změna a v dbt je to jediný sloupec v check_cols. Technické sloupce do hashe nevstupují, jinak by vznikala nová verze při každém běhu, a vnořená pole se před hashováním řadí podle stabilního klíče, jinak by jiné pořadí prvků vypadalo jako změna.',
    __nacteno_ts               TIMESTAMP NOT NULL  COMMENT 'Časové razítko, kdy byl záznam vložen do této silver tabulky.',
    CONSTRAINT pk_kontakt_v_kampani PRIMARY KEY (kontakt_v_kampani_hkey) NOT ENFORCED
)
USING DELTA
COMMENT 'Jeden kontakt jedné kampaně, tedy osoba nebo organizace k oslovení, se zpětnou vazbou, kterou obchodník zadal. Snímek klienta z CRM se uchovává tak, jak přišel, protože je to opět účelový údaj platný pro tento kontakt.'
CLUSTER BY (kontakt_v_kampani_hkey)
TBLPROPERTIES (
    'delta.columnMapping.mode'   = 'name',
    'delta.enableChangeDataFeed' = 'true',
    'model.layer'                = 'silver',
    'model.table_kind'           = 'current'
);
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kontakt_v_kampani SET TAGS ('description_en' = 'One contact of one campaign, that is one person or organisation to be approached, together with the feedback the agent entered. The client snapshot the source copies from CRM is kept as delivered, because it too is a purpose-specific value valid for this contact.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kontakt_v_kampani ALTER COLUMN kontakt_v_kampani_hkey SET TAGS ('description_en' = 'Hash of the natural key (kontakt_id). Identifies the entity, is stable across versions and serves both as the reference target and as the dbt snapshot unique_key.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kontakt_v_kampani ALTER COLUMN kontakt_id SET TAGS ('description_en' = 'Identifier of the contact.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kontakt_v_kampani ALTER COLUMN kampan_hkey SET TAGS ('description_en' = 'Campaign the contact belongs to.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kontakt_v_kampani ALTER COLUMN partner_id SET TAGS ('description_en' = 'Party identifier where the person is a client. Resolved through the party identifiermapping table.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kontakt_v_kampani ALTER COLUMN crm_klient_id SET TAGS ('description_en' = 'Client identifier from CRM.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kontakt_v_kampani ALTER COLUMN klient_priznak SET TAGS ('description_en' = 'TRUE when the contact is an existing client.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kontakt_v_kampani ALTER COLUMN stav_kontaktu_hkey SET TAGS ('description_en' = 'Feedback entered for the contact.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kontakt_v_kampani ALTER COLUMN resitel_obchodnik_hkey SET TAGS ('description_en' = 'Agent the contact is assigned to.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kontakt_v_kampani ALTER COLUMN organizacni_jednotka_hkey SET TAGS ('description_en' = 'Organisation unit the contact is assigned to.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kontakt_v_kampani ALTER COLUMN smlouva_cislo SET TAGS ('description_en' = 'Contract the contact relates to.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kontakt_v_kampani ALTER COLUMN smlouva_hkey SET TAGS ('description_en' = 'Contract, resolved.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kontakt_v_kampani ALTER COLUMN produkt_kod SET TAGS ('description_en' = 'Product according to CRM.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kontakt_v_kampani ALTER COLUMN pojistne_castka SET TAGS ('description_en' = 'Premium from CRM.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kontakt_v_kampani ALTER COLUMN smlouva_konec_datum SET TAGS ('description_en' = 'Contract end date.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kontakt_v_kampani ALTER COLUMN ruian_adresni_bod_kod SET TAGS ('description_en' = 'RUIAN address point of the contact.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kontakt_v_kampani ALTER COLUMN vytvoreno_ts SET TAGS ('description_en' = 'When the contact was created.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kontakt_v_kampani ALTER COLUMN zmeneno_ts SET TAGS ('description_en' = 'When the contact was last modified.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kontakt_v_kampani ALTER COLUMN posledni_prirazeni_datum SET TAGS ('description_en' = 'When the contact was last assigned.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kontakt_v_kampani ALTER COLUMN spolecnost_kod SET TAGS ('description_en' = 'Group company.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kontakt_v_kampani ALTER COLUMN snimek_klienta_crm SET TAGS ('description_en' = 'Client details the source copied from CRM, kept exactly as delivered so that thecampaign stays reproducible even after the party details change.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kontakt_v_kampani ALTER COLUMN __zdrojovy_system SET TAGS ('description_en' = 'Source system the record was loaded from, taken from the __source_system metadata column of the bronze table.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kontakt_v_kampani ALTER COLUMN __zdrojova_tabulka_nazev SET TAGS ('description_en' = 'Fully qualified bronze table the record was loaded from. For conformed entities fedfrom several bronze tables it is the only value that tells the origin of a row apart.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kontakt_v_kampani ALTER COLUMN smazano_priznak SET TAGS ('description_en' = 'TRUE when the source reported the record as deleted. Soft delete; the row is kept.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kontakt_v_kampani ALTER COLUMN hash_snimek_klienta_crm SET TAGS ('description_en' = 'Diagnostic hash of the nested column crm_client_snapshot. It does not take part in the version decision.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kontakt_v_kampani ALTER COLUMN platnost_od_ts SET TAGS ('description_en' = 'Point in time from which this version is valid, taken from the source change timestamp.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kontakt_v_kampani ALTER COLUMN hash_zaznamu SET TAGS ('description_en' = 'The decision hash over all business columns and the only column in the dbt check_cols. Nested arrays must be sorted by a stable key before hashing.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kontakt_v_kampani ALTER COLUMN __nacteno_ts SET TAGS ('description_en' = 'Timestamp of when the record was inserted into this silver table.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kontakt_v_kampani ALTER COLUMN kontakt_v_kampani_hkey SET TAGS ('data_classification' = 'confidential');

-- ========================= dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kontakt_v_kampani_hist =========================
-- SCD2 history | grain: Jeden řádek na kontakt v kampani | sources: KCL
CREATE TABLE IF NOT EXISTS dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kontakt_v_kampani_hist (
    kontakt_v_kampani_hkey     STRING NOT NULL  COMMENT 'Hash přirozeného klíče (kontakt_id). Identifikuje entitu, je stabilní napříč verzemi a slouží jako cíl odkazů z jiných entit i jako unique_key snapshotu v dbt.',
    kontakt_id                 BIGINT NOT NULL  COMMENT 'ID kontaktu.',
    kampan_hkey                STRING NOT NULL  COMMENT 'Kampaň, ke které kontakt patří.',
    partner_id                 STRING  COMMENT 'Identifikátor partnera, pokud je osoba klientem. Vyhodnocuje se přes mapovani_id_partnera.',
    crm_klient_id              STRING  COMMENT 'Identifikátor klienta z CRM. Nevyplněno pro neklienty.',
    klient_priznak             BOOLEAN NOT NULL  COMMENT 'TRUE, když je kontakt existujícím klientem.',
    stav_kontaktu_hkey         STRING  COMMENT 'Zadaná zpětná vazba ke kontaktu.',
    resitel_obchodnik_hkey     STRING  COMMENT 'Obchodník, kterému je kontakt přidělen.',
    organizacni_jednotka_hkey  STRING  COMMENT 'Organizační jednotka, které je kontakt přidělen.',
    smlouva_cislo              BIGINT  COMMENT 'Smlouva, ke které se kontakt vztahuje.',
    smlouva_hkey               STRING  COMMENT 'Smlouva vyhodnocená podle čísla.',
    produkt_kod                STRING  COMMENT 'Produkt podle CRM. Pokud jich smlouva má více, CRM bere jen jeden.',
    pojistne_castka            DECIMAL(38,2)  COMMENT 'Pojistné z CRM.',
    smlouva_konec_datum        DATE  COMMENT 'Konec platnosti smlouvy. Pouze životní pojištění.',
    ruian_adresni_bod_kod      BIGINT  COMMENT 'Adresní bod RUIAN kontaktu, používaný pro párování brutto produkce.',
    vytvoreno_ts               TIMESTAMP NOT NULL  COMMENT 'Kdy kontakt vznikl.',
    zmeneno_ts                 TIMESTAMP  COMMENT 'Kdy byl kontakt naposledy změněn.',
    posledni_prirazeni_datum   DATE  COMMENT 'Kdy byl kontakt naposledy přidělen.',
    spolecnost_kod             BIGINT NOT NULL  COMMENT 'Společnost skupiny.',
    snimek_klienta_crm         
        STRUCT<`jmeno`: STRING, `prijmeni`: STRING, `nazev_firmy`: STRING, `titul_pred`: STRING, `titul_za`: STRING, `rodne_cislo`: STRING, `ico`: STRING, `ulice_nazev`: STRING, `cislo_ulice`: STRING, `obec_nazev`: STRING, `psc`: STRING, `telefon_1`: STRING, `telefon_2`: STRING, `emailova_adresa`: STRING>  COMMENT 'Údaje o klientovi zkopírované z CRM, uchované přesně jak přišly, aby kampaň zůstala reprodukovatelná i po změně údajů u partnera.',
    __zdrojovy_system          STRING NOT NULL  COMMENT 'Zdrojový systém, ze kterého byl záznam načten. Přebírá se z metadatového sloupce __source_system odpovídající bronze tabulky.',
    __zdrojova_tabulka_nazev   STRING NOT NULL  COMMENT 'Plně kvalifikovaná bronze tabulka, ze které byl záznam načten. U konformovaných entit plněných z více bronze tabulek je to jediný údaj, který rozliší původ konkrétního řádku.',
    smazano_priznak            BOOLEAN NOT NULL  COMMENT 'TRUE, když zdroj oznámil smazání záznamu. Logické smazání, řádek zůstává, aby zůstala dohledatelná historie i odkazy.',
    hash_snimek_klienta_crm    STRING  COMMENT 'Diagnostický hash vnořeného sloupce snimek_klienta_crm. Neúčastní se rozhodnutí o nové verzi, slouží jen ke zjištění, která oblast se změnila. Pole se před hashováním řadí podle stabilního klíče.',
    verze_id                   STRING NOT NULL  COMMENT 'Identifikátor jedné verze záznamu, md5 hash přirozeného klíče a indikátoru změny, takže se liší verzi od verze. U snapshotů ho plní dbt jako dbt_scd_id, u inkrementálních tabulek ho stejným způsobem počítá plnění. Není to identita entity - tu nese <entita>_hkey, který zůstává napříč verzemi stejný.',
    platnost_od_ts             TIMESTAMP NOT NULL  COMMENT 'Okamžik, od kterého byla tato verze platná. U inkrementálních tabulek čas poslední změny ve zdroji, u snapshotů čas běhu, kdy byl stav pozorován.',
    platnost_do_ts             TIMESTAMP NOT NULL  COMMENT 'Okamžik, do kterého byla verze platná. Otevřená verze nese 9999-12-31 místo NULL, aby porovnávání období nemuselo řešit NULL. Otevřená verze je právě ta, která je v tabulce aktuálního stavu.',
    hash_zaznamu               STRING NOT NULL  COMMENT 'Rozhodovací hash přes všechny byznysové sloupce této verze. Technické sloupce do hashe nevstupují a vnořená pole se před hashováním řadí podle stabilního klíče.',
    __nacteno_ts               TIMESTAMP NOT NULL  COMMENT 'Časové razítko, kdy byla verze vložena do této silver tabulky.',
    CONSTRAINT pk_kontakt_v_kampani_hist PRIMARY KEY (kontakt_v_kampani_hkey, platnost_od_ts) NOT ENFORCED
)
USING DELTA
COMMENT 'Historie SCD2 entity kontakt_v_kampani. Jeden řádek na verzi, platnou mezi platnost_od_ts a platnost_do_ts. Jeden kontakt jedné kampaně, tedy osoba nebo organizace k oslovení, se zpětnou vazbou, kterou obchodník zadal. Snímek klienta z CRM se uchovává tak, jak přišel, protože je to opět účelový údaj platný pro tento kontakt.'
CLUSTER BY (kontakt_v_kampani_hkey, platnost_od_ts)
TBLPROPERTIES (
    'delta.columnMapping.mode'   = 'name',
    'delta.enableChangeDataFeed' = 'true',
    'model.layer'                = 'silver',
    'model.table_kind'           = 'history'
);
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kontakt_v_kampani_hist SET TAGS ('description_en' = 'SCD2 history of campaign_contact, one row per version valid between valid_from_timestamp and valid_to_timestamp. One contact of one campaign, that is one person or organisation to be approached, together with the feedback the agent entered. The client snapshot the source copies from CRM is kept as delivered, because it too is a purpose-specific value valid for this contact.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kontakt_v_kampani_hist ALTER COLUMN kontakt_v_kampani_hkey SET TAGS ('description_en' = 'Hash of the natural key (kontakt_id). Identifies the entity, is stable across versions and serves both as the reference target and as the dbt snapshot unique_key.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kontakt_v_kampani_hist ALTER COLUMN kontakt_id SET TAGS ('description_en' = 'Identifier of the contact.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kontakt_v_kampani_hist ALTER COLUMN kampan_hkey SET TAGS ('description_en' = 'Campaign the contact belongs to.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kontakt_v_kampani_hist ALTER COLUMN partner_id SET TAGS ('description_en' = 'Party identifier where the person is a client. Resolved through the party identifiermapping table.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kontakt_v_kampani_hist ALTER COLUMN crm_klient_id SET TAGS ('description_en' = 'Client identifier from CRM.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kontakt_v_kampani_hist ALTER COLUMN klient_priznak SET TAGS ('description_en' = 'TRUE when the contact is an existing client.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kontakt_v_kampani_hist ALTER COLUMN stav_kontaktu_hkey SET TAGS ('description_en' = 'Feedback entered for the contact.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kontakt_v_kampani_hist ALTER COLUMN resitel_obchodnik_hkey SET TAGS ('description_en' = 'Agent the contact is assigned to.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kontakt_v_kampani_hist ALTER COLUMN organizacni_jednotka_hkey SET TAGS ('description_en' = 'Organisation unit the contact is assigned to.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kontakt_v_kampani_hist ALTER COLUMN smlouva_cislo SET TAGS ('description_en' = 'Contract the contact relates to.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kontakt_v_kampani_hist ALTER COLUMN smlouva_hkey SET TAGS ('description_en' = 'Contract, resolved.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kontakt_v_kampani_hist ALTER COLUMN produkt_kod SET TAGS ('description_en' = 'Product according to CRM.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kontakt_v_kampani_hist ALTER COLUMN pojistne_castka SET TAGS ('description_en' = 'Premium from CRM.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kontakt_v_kampani_hist ALTER COLUMN smlouva_konec_datum SET TAGS ('description_en' = 'Contract end date.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kontakt_v_kampani_hist ALTER COLUMN ruian_adresni_bod_kod SET TAGS ('description_en' = 'RUIAN address point of the contact.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kontakt_v_kampani_hist ALTER COLUMN vytvoreno_ts SET TAGS ('description_en' = 'When the contact was created.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kontakt_v_kampani_hist ALTER COLUMN zmeneno_ts SET TAGS ('description_en' = 'When the contact was last modified.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kontakt_v_kampani_hist ALTER COLUMN posledni_prirazeni_datum SET TAGS ('description_en' = 'When the contact was last assigned.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kontakt_v_kampani_hist ALTER COLUMN spolecnost_kod SET TAGS ('description_en' = 'Group company.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kontakt_v_kampani_hist ALTER COLUMN snimek_klienta_crm SET TAGS ('description_en' = 'Client details the source copied from CRM, kept exactly as delivered so that thecampaign stays reproducible even after the party details change.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kontakt_v_kampani_hist ALTER COLUMN __zdrojovy_system SET TAGS ('description_en' = 'Source system the record was loaded from, taken from the __source_system metadata column of the bronze table.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kontakt_v_kampani_hist ALTER COLUMN __zdrojova_tabulka_nazev SET TAGS ('description_en' = 'Fully qualified bronze table the record was loaded from. For conformed entities fedfrom several bronze tables it is the only value that tells the origin of a row apart.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kontakt_v_kampani_hist ALTER COLUMN smazano_priznak SET TAGS ('description_en' = 'TRUE when the source reported the record as deleted. Soft delete; the row is kept.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kontakt_v_kampani_hist ALTER COLUMN hash_snimek_klienta_crm SET TAGS ('description_en' = 'Diagnostic hash of the nested column crm_client_snapshot. It does not take part in the version decision.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kontakt_v_kampani_hist ALTER COLUMN verze_id SET TAGS ('description_en' = 'Identifier of a single version, an md5 hash of the natural key and the change indicator. Filled by dbt_scd_id on snapshots and computed the same way by the load on incremental tables. It is not the entity identity.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kontakt_v_kampani_hist ALTER COLUMN platnost_od_ts SET TAGS ('description_en' = 'Point in time from which this version was valid. Part of the history primary key.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kontakt_v_kampani_hist ALTER COLUMN platnost_do_ts SET TAGS ('description_en' = 'Point in time until which this version was valid; the open version carries 9999-12-31.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kontakt_v_kampani_hist ALTER COLUMN hash_zaznamu SET TAGS ('description_en' = 'The decision hash over all business columns of this version.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kontakt_v_kampani_hist ALTER COLUMN __nacteno_ts SET TAGS ('description_en' = 'Timestamp of when the version was inserted into this silver table.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kontakt_v_kampani_hist ALTER COLUMN kontakt_v_kampani_hkey SET TAGS ('data_classification' = 'confidential');

-- ========================= dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.ukol =========================
-- current state | grain: Jeden řádek na úkol | sources: KCL
CREATE TABLE IF NOT EXISTS dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.ukol (
    ukol_hkey                 STRING NOT NULL  COMMENT 'Hash přirozeného klíče (ukol_id). Identifikuje entitu, je stabilní napříč verzemi a slouží jako cíl odkazů z jiných entit i jako unique_key snapshotu v dbt.',
    ukol_id                   BIGINT NOT NULL  COMMENT 'ID úkolu.',
    typ_zaznamu_kod           STRING NOT NULL  COMMENT 'UKOL, INFORMACE nebo PRILEZITOST. Odvozeno z příznaku INFO, jehož kódování se mezi zdrojovými sloupci liší.',
    typ_ukolu_hkey            STRING  COMMENT 'Typ úkolu.',
    podtyp_ukolu_hkey         STRING  COMMENT 'Podtyp úkolu.',
    stav_ukolu_hkey           STRING  COMMENT 'Stav úkolu.',
    zpusob_dokonceni_hkey     STRING  COMMENT 'Způsob dokončení úkolu.',
    autor_obchodnik_hkey      STRING  COMMENT 'Obchodník, který úkol vytvořil.',
    resitel_obchodnik_hkey    STRING  COMMENT 'Obchodník řešící úkol.',
    partner_id                STRING  COMMENT 'Identifikátor partnera, kterého se úkol týká. Vyhodnocuje se přes mapovani_id_partnera.',
    smlouva_cislo             BIGINT  COMMENT 'Smlouva, ke které se úkol vztahuje.',
    smlouva_hkey              STRING  COMMENT 'Smlouva vyhodnocená podle čísla.',
    pojistna_udalost_cislo    STRING  COMMENT 'Pojistná událost, ke které se úkol vztahuje. Jako text, protože čísla staré Generali obsahují nenumerické znaky.',
    ukol_zdroj_id             BIGINT  COMMENT 'Identifikátor úkolu ve zdrojovém systému.',
    fronta_kod                STRING  COMMENT 'Fronta, do které je úkol přiřazen. Většinou se používá ke seskupování dat v reportech pro byznys uživatele.',
    bonita_castka             DECIMAL(38,2)  COMMENT 'Bonita úkolu, pokud je vyjádřena.',
    z_trziste_priznak         BOOLEAN  COMMENT 'TRUE, když úkol přišel z tržiště.',
    vznik_datum               DATE NOT NULL  COMMENT 'Kdy úkol vznikl.',
    termin_datum              DATE  COMMENT 'Termín splnění úkolu.',
    upozorneni_datum          DATE  COMMENT 'Termín upozornění.',
    splneni_datum             DATE  COMMENT 'Kdy byl úkol splněn.',
    zmena_datum               DATE  COMMENT 'Kdy byl úkol naposledy změněn.',
    zmena_resitele_datum      DATE  COMMENT 'Kdy se naposledy změnil řešitel.',
    spolecnost_kod            BIGINT NOT NULL  COMMENT 'Společnost skupiny.',
    snimek_klienta_ccd        
        STRUCT<`jmeno`: STRING, `prijmeni`: STRING, `nazev_firmy`: STRING, `rodne_cislo`: STRING, `ico`: STRING, `ulice_nazev`: STRING, `cislo_domu`: STRING, `obec_nazev`: STRING, `psc`: STRING, `stat_kod`: STRING, `ccd_email`: STRING, `ccd_telefon`: STRING, `kcl_email`: STRING, `kcl_telefon`: STRING>  COMMENT 'Jméno, adresa a kontaktní údaje klienta zkopírované z CCD. E-mail a telefon pro KCL jsou ty, na které má být klient skutečně kontaktován při řešení úkolu.',
    __zdrojovy_system         STRING NOT NULL  COMMENT 'Zdrojový systém, ze kterého byl záznam načten. Přebírá se z metadatového sloupce __source_system odpovídající bronze tabulky.',
    __zdrojova_tabulka_nazev  STRING NOT NULL  COMMENT 'Plně kvalifikovaná bronze tabulka, ze které byl záznam načten. U konformovaných entit plněných z více bronze tabulek je to jediný údaj, který rozliší původ konkrétního řádku.',
    smazano_priznak           BOOLEAN NOT NULL  COMMENT 'TRUE, když zdroj oznámil smazání záznamu. Logické smazání, řádek zůstává, aby zůstala dohledatelná historie i odkazy.',
    hash_snimek_klienta_ccd   STRING  COMMENT 'Diagnostický hash vnořeného sloupce snimek_klienta_ccd. Neúčastní se rozhodnutí o nové verzi, slouží jen ke zjištění, která oblast se změnila. Pole se před hashováním řadí podle stabilního klíče.',
    platnost_od_ts            TIMESTAMP NOT NULL  COMMENT 'Okamžik, od kterého je tato verze řádku platná. U inkrementálních tabulek se plní časem poslední změny ve zdroji: u sync topiků z dataUpdatedAt, u delete topiků z auditInformation.lastUpdatedAt. U tabulek plněných snapshotem nese čas běhu, tedy okamžik, kdy jsme stav pozorovali - zdroj posílá celý snímek a vlastní čas změny u číselníků nenabízí.',
    hash_zaznamu              STRING NOT NULL  COMMENT 'Rozhodovací hash přes všechny byznysové sloupce. Podle něj se pozná skutečná změna a v dbt je to jediný sloupec v check_cols. Technické sloupce do hashe nevstupují, jinak by vznikala nová verze při každém běhu, a vnořená pole se před hashováním řadí podle stabilního klíče, jinak by jiné pořadí prvků vypadalo jako změna.',
    __nacteno_ts              TIMESTAMP NOT NULL  COMMENT 'Časové razítko, kdy byl záznam vložen do této silver tabulky.',
    CONSTRAINT pk_ukol PRIMARY KEY (ukol_hkey) NOT ENFORCED
)
USING DELTA
COMMENT 'Jeden úkol, informace nebo příležitost pro obchodníka. Všechny tři jsou jednou entitou, protože zdroj je drží v jedné tabulce a rozlišuje příznakem; model to zachovává jako typ_zaznamu_kod. Snímek klienta z CCD se drží zde, protože platí pro řešení tohoto úkolu.'
CLUSTER BY (ukol_hkey)
TBLPROPERTIES (
    'delta.columnMapping.mode'   = 'name',
    'delta.enableChangeDataFeed' = 'true',
    'model.layer'                = 'silver',
    'model.table_kind'           = 'current'
);
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.ukol SET TAGS ('description_en' = 'One task, information item or lead opportunity for an agent. The three are one entity because the source holds them in one table and distinguishes them by a flag; the model keeps that as the record kind code. The CCD client snapshot is held here, because it is valid for the handling of this task.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.ukol ALTER COLUMN ukol_hkey SET TAGS ('description_en' = 'Hash of the natural key (ukol_id). Identifies the entity, is stable across versions and serves both as the reference target and as the dbt snapshot unique_key.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.ukol ALTER COLUMN ukol_id SET TAGS ('description_en' = 'Identifier of the task.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.ukol ALTER COLUMN typ_zaznamu_kod SET TAGS ('description_en' = 'TASK, INFORMATION or LEAD_OPPORTUNITY. Derived from the INFO flag of the source, whosecoding differs between the two source columns.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.ukol ALTER COLUMN typ_ukolu_hkey SET TAGS ('description_en' = 'Type of the task.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.ukol ALTER COLUMN podtyp_ukolu_hkey SET TAGS ('description_en' = 'Subtype of the task.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.ukol ALTER COLUMN stav_ukolu_hkey SET TAGS ('description_en' = 'Status of the task.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.ukol ALTER COLUMN zpusob_dokonceni_hkey SET TAGS ('description_en' = 'How the task was completed.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.ukol ALTER COLUMN autor_obchodnik_hkey SET TAGS ('description_en' = 'Agent who created the task.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.ukol ALTER COLUMN resitel_obchodnik_hkey SET TAGS ('description_en' = 'Agent solving the task.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.ukol ALTER COLUMN partner_id SET TAGS ('description_en' = 'Identifier of the party the task is about. Resolved through the party identifiermapping table.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.ukol ALTER COLUMN smlouva_cislo SET TAGS ('description_en' = 'Contract the task relates to.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.ukol ALTER COLUMN smlouva_hkey SET TAGS ('description_en' = 'Contract, resolved.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.ukol ALTER COLUMN pojistna_udalost_cislo SET TAGS ('description_en' = 'Insurance claim the task relates to. Held as a string, because the old Generalinumbers contain non-numeric characters.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.ukol ALTER COLUMN ukol_zdroj_id SET TAGS ('description_en' = 'Identifier of the task in the originating system.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.ukol ALTER COLUMN fronta_kod SET TAGS ('description_en' = 'Queue the task is assigned to, mostly used to group data in business reports.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.ukol ALTER COLUMN bonita_castka SET TAGS ('description_en' = 'Value of the task, where expressed.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.ukol ALTER COLUMN z_trziste_priznak SET TAGS ('description_en' = 'TRUE when the task came from the marketplace.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.ukol ALTER COLUMN vznik_datum SET TAGS ('description_en' = 'When the task was created.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.ukol ALTER COLUMN termin_datum SET TAGS ('description_en' = 'Deadline.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.ukol ALTER COLUMN upozorneni_datum SET TAGS ('description_en' = 'Notification deadline.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.ukol ALTER COLUMN splneni_datum SET TAGS ('description_en' = 'When the task was completed.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.ukol ALTER COLUMN zmena_datum SET TAGS ('description_en' = 'When the task was last changed.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.ukol ALTER COLUMN zmena_resitele_datum SET TAGS ('description_en' = 'When the solver last changed.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.ukol ALTER COLUMN spolecnost_kod SET TAGS ('description_en' = 'Group company.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.ukol ALTER COLUMN snimek_klienta_ccd SET TAGS ('description_en' = 'Client name, address and contact details the source copied from CCD. The KCL specificemail and phone are the ones the client should be contacted on while the task ishandled.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.ukol ALTER COLUMN __zdrojovy_system SET TAGS ('description_en' = 'Source system the record was loaded from, taken from the __source_system metadata column of the bronze table.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.ukol ALTER COLUMN __zdrojova_tabulka_nazev SET TAGS ('description_en' = 'Fully qualified bronze table the record was loaded from. For conformed entities fedfrom several bronze tables it is the only value that tells the origin of a row apart.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.ukol ALTER COLUMN smazano_priznak SET TAGS ('description_en' = 'TRUE when the source reported the record as deleted. Soft delete; the row is kept.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.ukol ALTER COLUMN hash_snimek_klienta_ccd SET TAGS ('description_en' = 'Diagnostic hash of the nested column client_contact_snapshot. It does not take part in the version decision.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.ukol ALTER COLUMN platnost_od_ts SET TAGS ('description_en' = 'Point in time from which this version is valid, taken from the source change timestamp.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.ukol ALTER COLUMN hash_zaznamu SET TAGS ('description_en' = 'The decision hash over all business columns and the only column in the dbt check_cols. Nested arrays must be sorted by a stable key before hashing.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.ukol ALTER COLUMN __nacteno_ts SET TAGS ('description_en' = 'Timestamp of when the record was inserted into this silver table.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.ukol ALTER COLUMN ukol_hkey SET TAGS ('data_classification' = 'confidential');

-- ========================= dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.ukol_hist =========================
-- SCD2 history | grain: Jeden řádek na úkol | sources: KCL
CREATE TABLE IF NOT EXISTS dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.ukol_hist (
    ukol_hkey                 STRING NOT NULL  COMMENT 'Hash přirozeného klíče (ukol_id). Identifikuje entitu, je stabilní napříč verzemi a slouží jako cíl odkazů z jiných entit i jako unique_key snapshotu v dbt.',
    ukol_id                   BIGINT NOT NULL  COMMENT 'ID úkolu.',
    typ_zaznamu_kod           STRING NOT NULL  COMMENT 'UKOL, INFORMACE nebo PRILEZITOST. Odvozeno z příznaku INFO, jehož kódování se mezi zdrojovými sloupci liší.',
    typ_ukolu_hkey            STRING  COMMENT 'Typ úkolu.',
    podtyp_ukolu_hkey         STRING  COMMENT 'Podtyp úkolu.',
    stav_ukolu_hkey           STRING  COMMENT 'Stav úkolu.',
    zpusob_dokonceni_hkey     STRING  COMMENT 'Způsob dokončení úkolu.',
    autor_obchodnik_hkey      STRING  COMMENT 'Obchodník, který úkol vytvořil.',
    resitel_obchodnik_hkey    STRING  COMMENT 'Obchodník řešící úkol.',
    partner_id                STRING  COMMENT 'Identifikátor partnera, kterého se úkol týká. Vyhodnocuje se přes mapovani_id_partnera.',
    smlouva_cislo             BIGINT  COMMENT 'Smlouva, ke které se úkol vztahuje.',
    smlouva_hkey              STRING  COMMENT 'Smlouva vyhodnocená podle čísla.',
    pojistna_udalost_cislo    STRING  COMMENT 'Pojistná událost, ke které se úkol vztahuje. Jako text, protože čísla staré Generali obsahují nenumerické znaky.',
    ukol_zdroj_id             BIGINT  COMMENT 'Identifikátor úkolu ve zdrojovém systému.',
    fronta_kod                STRING  COMMENT 'Fronta, do které je úkol přiřazen. Většinou se používá ke seskupování dat v reportech pro byznys uživatele.',
    bonita_castka             DECIMAL(38,2)  COMMENT 'Bonita úkolu, pokud je vyjádřena.',
    z_trziste_priznak         BOOLEAN  COMMENT 'TRUE, když úkol přišel z tržiště.',
    vznik_datum               DATE NOT NULL  COMMENT 'Kdy úkol vznikl.',
    termin_datum              DATE  COMMENT 'Termín splnění úkolu.',
    upozorneni_datum          DATE  COMMENT 'Termín upozornění.',
    splneni_datum             DATE  COMMENT 'Kdy byl úkol splněn.',
    zmena_datum               DATE  COMMENT 'Kdy byl úkol naposledy změněn.',
    zmena_resitele_datum      DATE  COMMENT 'Kdy se naposledy změnil řešitel.',
    spolecnost_kod            BIGINT NOT NULL  COMMENT 'Společnost skupiny.',
    snimek_klienta_ccd        
        STRUCT<`jmeno`: STRING, `prijmeni`: STRING, `nazev_firmy`: STRING, `rodne_cislo`: STRING, `ico`: STRING, `ulice_nazev`: STRING, `cislo_domu`: STRING, `obec_nazev`: STRING, `psc`: STRING, `stat_kod`: STRING, `ccd_email`: STRING, `ccd_telefon`: STRING, `kcl_email`: STRING, `kcl_telefon`: STRING>  COMMENT 'Jméno, adresa a kontaktní údaje klienta zkopírované z CCD. E-mail a telefon pro KCL jsou ty, na které má být klient skutečně kontaktován při řešení úkolu.',
    __zdrojovy_system         STRING NOT NULL  COMMENT 'Zdrojový systém, ze kterého byl záznam načten. Přebírá se z metadatového sloupce __source_system odpovídající bronze tabulky.',
    __zdrojova_tabulka_nazev  STRING NOT NULL  COMMENT 'Plně kvalifikovaná bronze tabulka, ze které byl záznam načten. U konformovaných entit plněných z více bronze tabulek je to jediný údaj, který rozliší původ konkrétního řádku.',
    smazano_priznak           BOOLEAN NOT NULL  COMMENT 'TRUE, když zdroj oznámil smazání záznamu. Logické smazání, řádek zůstává, aby zůstala dohledatelná historie i odkazy.',
    hash_snimek_klienta_ccd   STRING  COMMENT 'Diagnostický hash vnořeného sloupce snimek_klienta_ccd. Neúčastní se rozhodnutí o nové verzi, slouží jen ke zjištění, která oblast se změnila. Pole se před hashováním řadí podle stabilního klíče.',
    verze_id                  STRING NOT NULL  COMMENT 'Identifikátor jedné verze záznamu, md5 hash přirozeného klíče a indikátoru změny, takže se liší verzi od verze. U snapshotů ho plní dbt jako dbt_scd_id, u inkrementálních tabulek ho stejným způsobem počítá plnění. Není to identita entity - tu nese <entita>_hkey, který zůstává napříč verzemi stejný.',
    platnost_od_ts            TIMESTAMP NOT NULL  COMMENT 'Okamžik, od kterého byla tato verze platná. U inkrementálních tabulek čas poslední změny ve zdroji, u snapshotů čas běhu, kdy byl stav pozorován.',
    platnost_do_ts            TIMESTAMP NOT NULL  COMMENT 'Okamžik, do kterého byla verze platná. Otevřená verze nese 9999-12-31 místo NULL, aby porovnávání období nemuselo řešit NULL. Otevřená verze je právě ta, která je v tabulce aktuálního stavu.',
    hash_zaznamu              STRING NOT NULL  COMMENT 'Rozhodovací hash přes všechny byznysové sloupce této verze. Technické sloupce do hashe nevstupují a vnořená pole se před hashováním řadí podle stabilního klíče.',
    __nacteno_ts              TIMESTAMP NOT NULL  COMMENT 'Časové razítko, kdy byla verze vložena do této silver tabulky.',
    CONSTRAINT pk_ukol_hist PRIMARY KEY (ukol_hkey, platnost_od_ts) NOT ENFORCED
)
USING DELTA
COMMENT 'Historie SCD2 entity ukol. Jeden řádek na verzi, platnou mezi platnost_od_ts a platnost_do_ts. Jeden úkol, informace nebo příležitost pro obchodníka. Všechny tři jsou jednou entitou, protože zdroj je drží v jedné tabulce a rozlišuje příznakem; model to zachovává jako typ_zaznamu_kod. Snímek klienta z CCD se drží zde, protože platí pro řešení tohoto úkolu.'
CLUSTER BY (ukol_hkey, platnost_od_ts)
TBLPROPERTIES (
    'delta.columnMapping.mode'   = 'name',
    'delta.enableChangeDataFeed' = 'true',
    'model.layer'                = 'silver',
    'model.table_kind'           = 'history'
);
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.ukol_hist SET TAGS ('description_en' = 'SCD2 history of task, one row per version valid between valid_from_timestamp and valid_to_timestamp. One task, information item or lead opportunity for an agent. The three are one entity because the source holds them in one table and distinguishes them by a flag; the model keeps that as the record kind code. The CCD client snapshot is held here, because it is valid for the handling of this task.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.ukol_hist ALTER COLUMN ukol_hkey SET TAGS ('description_en' = 'Hash of the natural key (ukol_id). Identifies the entity, is stable across versions and serves both as the reference target and as the dbt snapshot unique_key.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.ukol_hist ALTER COLUMN ukol_id SET TAGS ('description_en' = 'Identifier of the task.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.ukol_hist ALTER COLUMN typ_zaznamu_kod SET TAGS ('description_en' = 'TASK, INFORMATION or LEAD_OPPORTUNITY. Derived from the INFO flag of the source, whosecoding differs between the two source columns.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.ukol_hist ALTER COLUMN typ_ukolu_hkey SET TAGS ('description_en' = 'Type of the task.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.ukol_hist ALTER COLUMN podtyp_ukolu_hkey SET TAGS ('description_en' = 'Subtype of the task.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.ukol_hist ALTER COLUMN stav_ukolu_hkey SET TAGS ('description_en' = 'Status of the task.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.ukol_hist ALTER COLUMN zpusob_dokonceni_hkey SET TAGS ('description_en' = 'How the task was completed.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.ukol_hist ALTER COLUMN autor_obchodnik_hkey SET TAGS ('description_en' = 'Agent who created the task.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.ukol_hist ALTER COLUMN resitel_obchodnik_hkey SET TAGS ('description_en' = 'Agent solving the task.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.ukol_hist ALTER COLUMN partner_id SET TAGS ('description_en' = 'Identifier of the party the task is about. Resolved through the party identifiermapping table.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.ukol_hist ALTER COLUMN smlouva_cislo SET TAGS ('description_en' = 'Contract the task relates to.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.ukol_hist ALTER COLUMN smlouva_hkey SET TAGS ('description_en' = 'Contract, resolved.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.ukol_hist ALTER COLUMN pojistna_udalost_cislo SET TAGS ('description_en' = 'Insurance claim the task relates to. Held as a string, because the old Generalinumbers contain non-numeric characters.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.ukol_hist ALTER COLUMN ukol_zdroj_id SET TAGS ('description_en' = 'Identifier of the task in the originating system.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.ukol_hist ALTER COLUMN fronta_kod SET TAGS ('description_en' = 'Queue the task is assigned to, mostly used to group data in business reports.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.ukol_hist ALTER COLUMN bonita_castka SET TAGS ('description_en' = 'Value of the task, where expressed.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.ukol_hist ALTER COLUMN z_trziste_priznak SET TAGS ('description_en' = 'TRUE when the task came from the marketplace.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.ukol_hist ALTER COLUMN vznik_datum SET TAGS ('description_en' = 'When the task was created.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.ukol_hist ALTER COLUMN termin_datum SET TAGS ('description_en' = 'Deadline.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.ukol_hist ALTER COLUMN upozorneni_datum SET TAGS ('description_en' = 'Notification deadline.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.ukol_hist ALTER COLUMN splneni_datum SET TAGS ('description_en' = 'When the task was completed.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.ukol_hist ALTER COLUMN zmena_datum SET TAGS ('description_en' = 'When the task was last changed.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.ukol_hist ALTER COLUMN zmena_resitele_datum SET TAGS ('description_en' = 'When the solver last changed.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.ukol_hist ALTER COLUMN spolecnost_kod SET TAGS ('description_en' = 'Group company.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.ukol_hist ALTER COLUMN snimek_klienta_ccd SET TAGS ('description_en' = 'Client name, address and contact details the source copied from CCD. The KCL specificemail and phone are the ones the client should be contacted on while the task ishandled.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.ukol_hist ALTER COLUMN __zdrojovy_system SET TAGS ('description_en' = 'Source system the record was loaded from, taken from the __source_system metadata column of the bronze table.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.ukol_hist ALTER COLUMN __zdrojova_tabulka_nazev SET TAGS ('description_en' = 'Fully qualified bronze table the record was loaded from. For conformed entities fedfrom several bronze tables it is the only value that tells the origin of a row apart.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.ukol_hist ALTER COLUMN smazano_priznak SET TAGS ('description_en' = 'TRUE when the source reported the record as deleted. Soft delete; the row is kept.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.ukol_hist ALTER COLUMN hash_snimek_klienta_ccd SET TAGS ('description_en' = 'Diagnostic hash of the nested column client_contact_snapshot. It does not take part in the version decision.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.ukol_hist ALTER COLUMN verze_id SET TAGS ('description_en' = 'Identifier of a single version, an md5 hash of the natural key and the change indicator. Filled by dbt_scd_id on snapshots and computed the same way by the load on incremental tables. It is not the entity identity.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.ukol_hist ALTER COLUMN platnost_od_ts SET TAGS ('description_en' = 'Point in time from which this version was valid. Part of the history primary key.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.ukol_hist ALTER COLUMN platnost_do_ts SET TAGS ('description_en' = 'Point in time until which this version was valid; the open version carries 9999-12-31.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.ukol_hist ALTER COLUMN hash_zaznamu SET TAGS ('description_en' = 'The decision hash over all business columns of this version.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.ukol_hist ALTER COLUMN __nacteno_ts SET TAGS ('description_en' = 'Timestamp of when the version was inserted into this silver table.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.ukol_hist ALTER COLUMN ukol_hkey SET TAGS ('data_classification' = 'confidential');

-- ========================= dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.produkt =========================
-- current state | grain: Jeden řádek na položku číselníku | sources: KCČ
CREATE TABLE IF NOT EXISTS dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.produkt (
    produkt_hkey              STRING NOT NULL  COMMENT 'Hash přirozeného klíče (produkt_kod + spolecnost_kod). Identifikuje entitu, je stabilní napříč verzemi a slouží jako cíl odkazů z jiných entit i jako unique_key snapshotu v dbt.',
    produkt_kod               INT NOT NULL  COMMENT 'Kód produktu.',
    spolecnost_kod            INT NOT NULL  COMMENT 'Společnost skupiny.',
    produkt_kratky_nazev      STRING  COMMENT 'Krátký název produktu.',
    produkt_nazev             STRING  COMMENT 'Dlouhý název produktu.',
    produkt_obchodni_nazev    STRING  COMMENT 'Název produktu používaný v obchodních směrnicích.',
    produkt_zkratka           STRING  COMMENT 'Zkratka produktu.',
    seskupeni_kod             INT  COMMENT 'Seskupení, do kterého produkt patří.',
    zivotni_produkt_priznak   BOOLEAN  COMMENT 'TRUE pro produkt životního pojištění.',
    sjednavan_priznak         BOOLEAN  COMMENT 'TRUE, dokud se produkt ještě sjednává.',
    prodej_od_datum           DATE  COMMENT 'Datum počátku sjednávání produktu.',
    prodej_do_datum           DATE  COMMENT 'Datum ukončení sjednávání produktu.',
    technicka_urokova_mira    DECIMAL(3,1)  COMMENT 'Technická úroková míra.',
    danove_uznatelny_priznak  BOOLEAN  COMMENT 'TRUE, když je produkt daňově uznatelný.',
    fiktivni_produkt_priznak  BOOLEAN  COMMENT 'TRUE pro fiktivní produkt používaný jen pro analýzu ziskovosti.',
    kategorie_pojisteni_kod   INT  COMMENT 'Kategorie pojištění pro zajištění neživota.',
    portfolio_kod             STRING  COMMENT 'Portfolio pojištění pro zajištění neživota.',
    investicni_produkt_kod    STRING  COMMENT 'Rozlišuje investiční a tradiční produkty.',
    odbytne_priznak           BOOLEAN  COMMENT 'TRUE pro životní produkty, u kterých má klient po stornu právo na odbytné.',
    psp_vazba_priznak         BOOLEAN  COMMENT 'Vazba do databáze PSP, prodejně-servisního portálu HUGO.',
    sap_kvalifikace_objid     STRING  COMMENT 'Číslo kvalifikace produktového oprávnění ze SAP.',
    platnost_od_datum         DATE  COMMENT 'Počátek platnosti položky číselníku.',
    platnost_do_datum         DATE  COMMENT 'Konec platnosti položky číselníku.',
    publikovano_od_datum      DATE  COMMENT 'Datum, od kdy je položka publikována.',
    publikovano_do_datum      DATE  COMMENT 'Datum, do kdy je položka publikována.',
    __zdrojovy_system         STRING NOT NULL  COMMENT 'Zdrojový systém, ze kterého byl záznam načten. Přebírá se z metadatového sloupce __source_system odpovídající bronze tabulky.',
    __zdrojova_tabulka_nazev  STRING NOT NULL  COMMENT 'Plně kvalifikovaná bronze tabulka, ze které byl záznam načten. U konformovaných entit plněných z více bronze tabulek je to jediný údaj, který rozliší původ konkrétního řádku.',
    platnost_od_ts            TIMESTAMP NOT NULL  COMMENT 'Okamžik, od kterého je tato verze řádku platná. U inkrementálních tabulek se plní časem poslední změny ve zdroji: u sync topiků z dataUpdatedAt, u delete topiků z auditInformation.lastUpdatedAt. U tabulek plněných snapshotem nese čas běhu, tedy okamžik, kdy jsme stav pozorovali - zdroj posílá celý snímek a vlastní čas změny u číselníků nenabízí.',
    hash_zaznamu              STRING NOT NULL  COMMENT 'Rozhodovací hash přes všechny byznysové sloupce. Podle něj se pozná skutečná změna a v dbt je to jediný sloupec v check_cols. Technické sloupce do hashe nevstupují, jinak by vznikala nová verze při každém běhu, a vnořená pole se před hashováním řadí podle stabilního klíče, jinak by jiné pořadí prvků vypadalo jako změna.',
    __nacteno_ts              TIMESTAMP NOT NULL  COMMENT 'Časové razítko, kdy byl záznam vložen do této silver tabulky.',
    CONSTRAINT pk_produkt PRIMARY KEY (produkt_hkey) NOT ENFORCED
)
USING DELTA
COMMENT 'Konformovaný katalog pojistných produktů z pohledu controllingu a odměňování. Odkazuje se na něj z pole instancí produktů u smlouvy i návrhu.'
CLUSTER BY (produkt_hkey)
TBLPROPERTIES (
    'delta.columnMapping.mode'   = 'name',
    'delta.enableChangeDataFeed' = 'true',
    'model.layer'                = 'silver',
    'model.table_kind'           = 'current'
);
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.produkt SET TAGS ('description_en' = 'Conformed catalogue of insurance products, from the perspective of controlling and remuneration. It is referenced out of the product instance array of both contract and proposal.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.produkt ALTER COLUMN produkt_hkey SET TAGS ('description_en' = 'Hash of the natural key (produkt_kod + spolecnost_kod). Identifies the entity, is stable across versions and serves both as the reference target and as the dbt snapshot unique_key.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.produkt ALTER COLUMN produkt_kod SET TAGS ('description_en' = 'Code of the product.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.produkt ALTER COLUMN spolecnost_kod SET TAGS ('description_en' = 'Group company.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.produkt ALTER COLUMN produkt_kratky_nazev SET TAGS ('description_en' = 'Short product name.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.produkt ALTER COLUMN produkt_nazev SET TAGS ('description_en' = 'Long product name.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.produkt ALTER COLUMN produkt_obchodni_nazev SET TAGS ('description_en' = 'Product name used in the sales guidelines.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.produkt ALTER COLUMN produkt_zkratka SET TAGS ('description_en' = 'Abbreviation of the product.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.produkt ALTER COLUMN seskupeni_kod SET TAGS ('description_en' = 'Group the product belongs to.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.produkt ALTER COLUMN zivotni_produkt_priznak SET TAGS ('description_en' = 'TRUE for a life insurance product.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.produkt ALTER COLUMN sjednavan_priznak SET TAGS ('description_en' = 'TRUE while the product can still be sold.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.produkt ALTER COLUMN prodej_od_datum SET TAGS ('description_en' = 'Date from which the product can be sold.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.produkt ALTER COLUMN prodej_do_datum SET TAGS ('description_en' = 'Date from which the product can no longer be sold.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.produkt ALTER COLUMN technicka_urokova_mira SET TAGS ('description_en' = 'Technical interest rate.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.produkt ALTER COLUMN danove_uznatelny_priznak SET TAGS ('description_en' = 'TRUE when the product is tax deductible.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.produkt ALTER COLUMN fiktivni_produkt_priznak SET TAGS ('description_en' = 'TRUE for a fictitious product.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.produkt ALTER COLUMN kategorie_pojisteni_kod SET TAGS ('description_en' = 'Insurance category for non-life reinsurance.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.produkt ALTER COLUMN portfolio_kod SET TAGS ('description_en' = 'Insurance portfolio for non-life reinsurance.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.produkt ALTER COLUMN investicni_produkt_kod SET TAGS ('description_en' = 'Distinguishes investment from traditional products.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.produkt ALTER COLUMN odbytne_priznak SET TAGS ('description_en' = 'TRUE where the client is entitled to a surrender value.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.produkt ALTER COLUMN psp_vazba_priznak SET TAGS ('description_en' = 'Link into the PSP database, the sales and service portal HUGO.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.produkt ALTER COLUMN sap_kvalifikace_objid SET TAGS ('description_en' = 'Qualification number of the product authorisation from SAP.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.produkt ALTER COLUMN platnost_od_datum SET TAGS ('description_en' = 'Start of validity of the codelist entry.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.produkt ALTER COLUMN platnost_do_datum SET TAGS ('description_en' = 'End of validity of the codelist entry.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.produkt ALTER COLUMN publikovano_od_datum SET TAGS ('description_en' = 'Date from which the entry is published.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.produkt ALTER COLUMN publikovano_do_datum SET TAGS ('description_en' = 'Date until which the entry is published.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.produkt ALTER COLUMN __zdrojovy_system SET TAGS ('description_en' = 'Source system the record was loaded from, taken from the __source_system metadata column of the bronze table.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.produkt ALTER COLUMN __zdrojova_tabulka_nazev SET TAGS ('description_en' = 'Fully qualified bronze table the record was loaded from. For conformed entities fedfrom several bronze tables it is the only value that tells the origin of a row apart.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.produkt ALTER COLUMN platnost_od_ts SET TAGS ('description_en' = 'Point in time from which this version is valid, taken from the source change timestamp.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.produkt ALTER COLUMN hash_zaznamu SET TAGS ('description_en' = 'The decision hash over all business columns and the only column in the dbt check_cols. Nested arrays must be sorted by a stable key before hashing.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.produkt ALTER COLUMN __nacteno_ts SET TAGS ('description_en' = 'Timestamp of when the record was inserted into this silver table.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.produkt ALTER COLUMN produkt_hkey SET TAGS ('data_classification' = 'internal');

-- ========================= dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.produkt_hist =========================
-- SCD2 history | grain: Jeden řádek na položku číselníku | sources: KCČ
CREATE TABLE IF NOT EXISTS dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.produkt_hist (
    produkt_hkey              STRING NOT NULL  COMMENT 'Hash přirozeného klíče (produkt_kod + spolecnost_kod). Identifikuje entitu, je stabilní napříč verzemi a slouží jako cíl odkazů z jiných entit i jako unique_key snapshotu v dbt.',
    produkt_kod               INT NOT NULL  COMMENT 'Kód produktu.',
    spolecnost_kod            INT NOT NULL  COMMENT 'Společnost skupiny.',
    produkt_kratky_nazev      STRING  COMMENT 'Krátký název produktu.',
    produkt_nazev             STRING  COMMENT 'Dlouhý název produktu.',
    produkt_obchodni_nazev    STRING  COMMENT 'Název produktu používaný v obchodních směrnicích.',
    produkt_zkratka           STRING  COMMENT 'Zkratka produktu.',
    seskupeni_kod             INT  COMMENT 'Seskupení, do kterého produkt patří.',
    zivotni_produkt_priznak   BOOLEAN  COMMENT 'TRUE pro produkt životního pojištění.',
    sjednavan_priznak         BOOLEAN  COMMENT 'TRUE, dokud se produkt ještě sjednává.',
    prodej_od_datum           DATE  COMMENT 'Datum počátku sjednávání produktu.',
    prodej_do_datum           DATE  COMMENT 'Datum ukončení sjednávání produktu.',
    technicka_urokova_mira    DECIMAL(3,1)  COMMENT 'Technická úroková míra.',
    danove_uznatelny_priznak  BOOLEAN  COMMENT 'TRUE, když je produkt daňově uznatelný.',
    fiktivni_produkt_priznak  BOOLEAN  COMMENT 'TRUE pro fiktivní produkt používaný jen pro analýzu ziskovosti.',
    kategorie_pojisteni_kod   INT  COMMENT 'Kategorie pojištění pro zajištění neživota.',
    portfolio_kod             STRING  COMMENT 'Portfolio pojištění pro zajištění neživota.',
    investicni_produkt_kod    STRING  COMMENT 'Rozlišuje investiční a tradiční produkty.',
    odbytne_priznak           BOOLEAN  COMMENT 'TRUE pro životní produkty, u kterých má klient po stornu právo na odbytné.',
    psp_vazba_priznak         BOOLEAN  COMMENT 'Vazba do databáze PSP, prodejně-servisního portálu HUGO.',
    sap_kvalifikace_objid     STRING  COMMENT 'Číslo kvalifikace produktového oprávnění ze SAP.',
    platnost_od_datum         DATE  COMMENT 'Počátek platnosti položky číselníku.',
    platnost_do_datum         DATE  COMMENT 'Konec platnosti položky číselníku.',
    publikovano_od_datum      DATE  COMMENT 'Datum, od kdy je položka publikována.',
    publikovano_do_datum      DATE  COMMENT 'Datum, do kdy je položka publikována.',
    __zdrojovy_system         STRING NOT NULL  COMMENT 'Zdrojový systém, ze kterého byl záznam načten. Přebírá se z metadatového sloupce __source_system odpovídající bronze tabulky.',
    __zdrojova_tabulka_nazev  STRING NOT NULL  COMMENT 'Plně kvalifikovaná bronze tabulka, ze které byl záznam načten. U konformovaných entit plněných z více bronze tabulek je to jediný údaj, který rozliší původ konkrétního řádku.',
    verze_id                  STRING NOT NULL  COMMENT 'Identifikátor jedné verze záznamu, md5 hash přirozeného klíče a indikátoru změny, takže se liší verzi od verze. U snapshotů ho plní dbt jako dbt_scd_id, u inkrementálních tabulek ho stejným způsobem počítá plnění. Není to identita entity - tu nese <entita>_hkey, který zůstává napříč verzemi stejný.',
    platnost_od_ts            TIMESTAMP NOT NULL  COMMENT 'Okamžik, od kterého byla tato verze platná. U inkrementálních tabulek čas poslední změny ve zdroji, u snapshotů čas běhu, kdy byl stav pozorován.',
    platnost_do_ts            TIMESTAMP NOT NULL  COMMENT 'Okamžik, do kterého byla verze platná. Otevřená verze nese 9999-12-31 místo NULL, aby porovnávání období nemuselo řešit NULL. Otevřená verze je právě ta, která je v tabulce aktuálního stavu.',
    hash_zaznamu              STRING NOT NULL  COMMENT 'Rozhodovací hash přes všechny byznysové sloupce této verze. Technické sloupce do hashe nevstupují a vnořená pole se před hashováním řadí podle stabilního klíče.',
    __nacteno_ts              TIMESTAMP NOT NULL  COMMENT 'Časové razítko, kdy byla verze vložena do této silver tabulky.',
    __dbt_updated_at          TIMESTAMP NOT NULL  COMMENT 'Vnitřní pracovní značka dbt, proti které se při dalším běhu porovnává stav zdroje. Nese tutéž hodnotu jako platnost_od_ts, protože dbt zapisuje obě meta pole zvlášť a namapovat je na jeden sloupec nelze; rozejít se mohou jedině při zneplatnění smazaného záznamu. Prefix __ a jméno dbt v názvu říkají, že jde o technický sloupec nástroje - pro dotazy používejte platnost_od_ts. Vzniká jen u tabulek plněných snapshotem.',
    CONSTRAINT pk_produkt_hist PRIMARY KEY (produkt_hkey, platnost_od_ts) NOT ENFORCED
)
USING DELTA
COMMENT 'Historie SCD2 entity produkt. Jeden řádek na verzi, platnou mezi platnost_od_ts a platnost_do_ts. Konformovaný katalog pojistných produktů z pohledu controllingu a odměňování. Odkazuje se na něj z pole instancí produktů u smlouvy i návrhu.'
CLUSTER BY (produkt_hkey, platnost_od_ts)
TBLPROPERTIES (
    'delta.columnMapping.mode'   = 'name',
    'delta.enableChangeDataFeed' = 'true',
    'model.layer'                = 'silver',
    'model.table_kind'           = 'history'
);
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.produkt_hist SET TAGS ('description_en' = 'SCD2 history of product, one row per version valid between valid_from_timestamp and valid_to_timestamp. Conformed catalogue of insurance products, from the perspective of controlling and remuneration. It is referenced out of the product instance array of both contract and proposal.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.produkt_hist ALTER COLUMN produkt_hkey SET TAGS ('description_en' = 'Hash of the natural key (produkt_kod + spolecnost_kod). Identifies the entity, is stable across versions and serves both as the reference target and as the dbt snapshot unique_key.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.produkt_hist ALTER COLUMN produkt_kod SET TAGS ('description_en' = 'Code of the product.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.produkt_hist ALTER COLUMN spolecnost_kod SET TAGS ('description_en' = 'Group company.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.produkt_hist ALTER COLUMN produkt_kratky_nazev SET TAGS ('description_en' = 'Short product name.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.produkt_hist ALTER COLUMN produkt_nazev SET TAGS ('description_en' = 'Long product name.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.produkt_hist ALTER COLUMN produkt_obchodni_nazev SET TAGS ('description_en' = 'Product name used in the sales guidelines.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.produkt_hist ALTER COLUMN produkt_zkratka SET TAGS ('description_en' = 'Abbreviation of the product.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.produkt_hist ALTER COLUMN seskupeni_kod SET TAGS ('description_en' = 'Group the product belongs to.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.produkt_hist ALTER COLUMN zivotni_produkt_priznak SET TAGS ('description_en' = 'TRUE for a life insurance product.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.produkt_hist ALTER COLUMN sjednavan_priznak SET TAGS ('description_en' = 'TRUE while the product can still be sold.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.produkt_hist ALTER COLUMN prodej_od_datum SET TAGS ('description_en' = 'Date from which the product can be sold.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.produkt_hist ALTER COLUMN prodej_do_datum SET TAGS ('description_en' = 'Date from which the product can no longer be sold.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.produkt_hist ALTER COLUMN technicka_urokova_mira SET TAGS ('description_en' = 'Technical interest rate.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.produkt_hist ALTER COLUMN danove_uznatelny_priznak SET TAGS ('description_en' = 'TRUE when the product is tax deductible.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.produkt_hist ALTER COLUMN fiktivni_produkt_priznak SET TAGS ('description_en' = 'TRUE for a fictitious product.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.produkt_hist ALTER COLUMN kategorie_pojisteni_kod SET TAGS ('description_en' = 'Insurance category for non-life reinsurance.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.produkt_hist ALTER COLUMN portfolio_kod SET TAGS ('description_en' = 'Insurance portfolio for non-life reinsurance.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.produkt_hist ALTER COLUMN investicni_produkt_kod SET TAGS ('description_en' = 'Distinguishes investment from traditional products.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.produkt_hist ALTER COLUMN odbytne_priznak SET TAGS ('description_en' = 'TRUE where the client is entitled to a surrender value.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.produkt_hist ALTER COLUMN psp_vazba_priznak SET TAGS ('description_en' = 'Link into the PSP database, the sales and service portal HUGO.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.produkt_hist ALTER COLUMN sap_kvalifikace_objid SET TAGS ('description_en' = 'Qualification number of the product authorisation from SAP.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.produkt_hist ALTER COLUMN platnost_od_datum SET TAGS ('description_en' = 'Start of validity of the codelist entry.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.produkt_hist ALTER COLUMN platnost_do_datum SET TAGS ('description_en' = 'End of validity of the codelist entry.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.produkt_hist ALTER COLUMN publikovano_od_datum SET TAGS ('description_en' = 'Date from which the entry is published.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.produkt_hist ALTER COLUMN publikovano_do_datum SET TAGS ('description_en' = 'Date until which the entry is published.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.produkt_hist ALTER COLUMN __zdrojovy_system SET TAGS ('description_en' = 'Source system the record was loaded from, taken from the __source_system metadata column of the bronze table.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.produkt_hist ALTER COLUMN __zdrojova_tabulka_nazev SET TAGS ('description_en' = 'Fully qualified bronze table the record was loaded from. For conformed entities fedfrom several bronze tables it is the only value that tells the origin of a row apart.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.produkt_hist ALTER COLUMN verze_id SET TAGS ('description_en' = 'Identifier of a single version, an md5 hash of the natural key and the change indicator. Filled by dbt_scd_id on snapshots and computed the same way by the load on incremental tables. It is not the entity identity.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.produkt_hist ALTER COLUMN platnost_od_ts SET TAGS ('description_en' = 'Point in time from which this version was valid. Part of the history primary key.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.produkt_hist ALTER COLUMN platnost_do_ts SET TAGS ('description_en' = 'Point in time until which this version was valid; the open version carries 9999-12-31.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.produkt_hist ALTER COLUMN hash_zaznamu SET TAGS ('description_en' = 'The decision hash over all business columns of this version.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.produkt_hist ALTER COLUMN __nacteno_ts SET TAGS ('description_en' = 'Timestamp of when the version was inserted into this silver table.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.produkt_hist ALTER COLUMN __dbt_updated_at SET TAGS ('description_en' = 'An internal dbt working marker. It carries the same value as the valid-from column; the two can only diverge when a hard-deleted record is invalidated. Only snapshot tables have it.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.produkt_hist ALTER COLUMN produkt_hkey SET TAGS ('data_classification' = 'internal');

-- ========================= dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.stav_smlouvy =========================
-- current state | grain: Jeden řádek na položku číselníku | sources: KCČ, Manual
CREATE TABLE IF NOT EXISTS dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.stav_smlouvy (
    stav_smlouvy_hkey         STRING NOT NULL  COMMENT 'Hash přirozeného klíče (stav_smlouvy_kod + spolecnost_kod). Identifikuje entitu, je stabilní napříč verzemi a slouží jako cíl odkazů z jiných entit i jako unique_key snapshotu v dbt.',
    stav_smlouvy_kod          INT NOT NULL  COMMENT 'Kód stavu.',
    spolecnost_kod            INT NOT NULL  COMMENT 'Společnost skupiny.',
    stav_smlouvy_nazev        STRING NOT NULL  COMMENT 'Název stavu.',
    stav_smlouvy_alfanum_kod  STRING  COMMENT 'Alfanumerický kód stavu.',
    stav_sales_cockpit_nazev  STRING  COMMENT 'Název stavu používaný v Sales Cockpitu. Připojeno z ruční mapovací tabulky podle stavu a společnosti pro datum, kdy je položka číselníku platná.',
    vyskyt_stavu_kod          STRING  COMMENT 'Zda stav odpovídá smlouvě nebo návrhu.',
    poradi                    INT  COMMENT 'Pořadí pro zobrazení ve front endu.',
    platnost_od_datum         DATE  COMMENT 'Počátek platnosti položky číselníku.',
    platnost_do_datum         DATE  COMMENT 'Konec platnosti položky číselníku.',
    publikovano_od_datum      DATE  COMMENT 'Datum, od kdy je položka publikována.',
    publikovano_do_datum      DATE  COMMENT 'Datum, do kdy je položka publikována.',
    __zdrojovy_system         STRING NOT NULL  COMMENT 'Zdrojový systém, ze kterého byl záznam načten. Přebírá se z metadatového sloupce __source_system odpovídající bronze tabulky.',
    __zdrojova_tabulka_nazev  STRING NOT NULL  COMMENT 'Plně kvalifikovaná bronze tabulka, ze které byl záznam načten. U konformovaných entit plněných z více bronze tabulek je to jediný údaj, který rozliší původ konkrétního řádku.',
    platnost_od_ts            TIMESTAMP NOT NULL  COMMENT 'Okamžik, od kterého je tato verze řádku platná. U inkrementálních tabulek se plní časem poslední změny ve zdroji: u sync topiků z dataUpdatedAt, u delete topiků z auditInformation.lastUpdatedAt. U tabulek plněných snapshotem nese čas běhu, tedy okamžik, kdy jsme stav pozorovali - zdroj posílá celý snímek a vlastní čas změny u číselníků nenabízí.',
    hash_zaznamu              STRING NOT NULL  COMMENT 'Rozhodovací hash přes všechny byznysové sloupce. Podle něj se pozná skutečná změna a v dbt je to jediný sloupec v check_cols. Technické sloupce do hashe nevstupují, jinak by vznikala nová verze při každém běhu, a vnořená pole se před hashováním řadí podle stabilního klíče, jinak by jiné pořadí prvků vypadalo jako změna.',
    __nacteno_ts              TIMESTAMP NOT NULL  COMMENT 'Časové razítko, kdy byl záznam vložen do této silver tabulky.',
    CONSTRAINT pk_stav_smlouvy PRIMARY KEY (stav_smlouvy_hkey) NOT ENFORCED
)
USING DELTA
COMMENT 'Konformovaný číselník stavů smlouvy a návrhu. Zobrazovaný název ze Sales Cockpitu je přiložen z ručně nahrávané mapovací tabulky, ne držen jako druhá entita.'
CLUSTER BY (stav_smlouvy_hkey)
TBLPROPERTIES (
    'delta.columnMapping.mode'   = 'name',
    'delta.enableChangeDataFeed' = 'true',
    'model.layer'                = 'silver',
    'model.table_kind'           = 'current'
);
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.stav_smlouvy SET TAGS ('description_en' = 'Conformed codelist of contract and proposal statuses. The Sales Cockpit display name is merged in from the manually uploaded mapping table rather than kept as a second entity.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.stav_smlouvy ALTER COLUMN stav_smlouvy_hkey SET TAGS ('description_en' = 'Hash of the natural key (stav_smlouvy_kod + spolecnost_kod). Identifies the entity, is stable across versions and serves both as the reference target and as the dbt snapshot unique_key.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.stav_smlouvy ALTER COLUMN stav_smlouvy_kod SET TAGS ('description_en' = 'Code of the status.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.stav_smlouvy ALTER COLUMN spolecnost_kod SET TAGS ('description_en' = 'Group company.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.stav_smlouvy ALTER COLUMN stav_smlouvy_nazev SET TAGS ('description_en' = 'Name of the status.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.stav_smlouvy ALTER COLUMN stav_smlouvy_alfanum_kod SET TAGS ('description_en' = 'Alphanumeric code of the status.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.stav_smlouvy ALTER COLUMN stav_sales_cockpit_nazev SET TAGS ('description_en' = 'Status name as used in the Sales Cockpit. Joined from the manual mapping table bystatus and company for the date the codelist entry is valid.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.stav_smlouvy ALTER COLUMN vyskyt_stavu_kod SET TAGS ('description_en' = 'Whether the status belongs to a contract or an offer.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.stav_smlouvy ALTER COLUMN poradi SET TAGS ('description_en' = 'Display order in the front end.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.stav_smlouvy ALTER COLUMN platnost_od_datum SET TAGS ('description_en' = 'Start of validity of the codelist entry.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.stav_smlouvy ALTER COLUMN platnost_do_datum SET TAGS ('description_en' = 'End of validity of the codelist entry.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.stav_smlouvy ALTER COLUMN publikovano_od_datum SET TAGS ('description_en' = 'Date from which the entry is published.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.stav_smlouvy ALTER COLUMN publikovano_do_datum SET TAGS ('description_en' = 'Date until which the entry is published.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.stav_smlouvy ALTER COLUMN __zdrojovy_system SET TAGS ('description_en' = 'Source system the record was loaded from, taken from the __source_system metadata column of the bronze table.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.stav_smlouvy ALTER COLUMN __zdrojova_tabulka_nazev SET TAGS ('description_en' = 'Fully qualified bronze table the record was loaded from. For conformed entities fedfrom several bronze tables it is the only value that tells the origin of a row apart.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.stav_smlouvy ALTER COLUMN platnost_od_ts SET TAGS ('description_en' = 'Point in time from which this version is valid, taken from the source change timestamp.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.stav_smlouvy ALTER COLUMN hash_zaznamu SET TAGS ('description_en' = 'The decision hash over all business columns and the only column in the dbt check_cols. Nested arrays must be sorted by a stable key before hashing.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.stav_smlouvy ALTER COLUMN __nacteno_ts SET TAGS ('description_en' = 'Timestamp of when the record was inserted into this silver table.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.stav_smlouvy ALTER COLUMN stav_smlouvy_hkey SET TAGS ('data_classification' = 'internal');

-- ========================= dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.stav_smlouvy_hist =========================
-- SCD2 history | grain: Jeden řádek na položku číselníku | sources: KCČ, Manual
CREATE TABLE IF NOT EXISTS dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.stav_smlouvy_hist (
    stav_smlouvy_hkey         STRING NOT NULL  COMMENT 'Hash přirozeného klíče (stav_smlouvy_kod + spolecnost_kod). Identifikuje entitu, je stabilní napříč verzemi a slouží jako cíl odkazů z jiných entit i jako unique_key snapshotu v dbt.',
    stav_smlouvy_kod          INT NOT NULL  COMMENT 'Kód stavu.',
    spolecnost_kod            INT NOT NULL  COMMENT 'Společnost skupiny.',
    stav_smlouvy_nazev        STRING NOT NULL  COMMENT 'Název stavu.',
    stav_smlouvy_alfanum_kod  STRING  COMMENT 'Alfanumerický kód stavu.',
    stav_sales_cockpit_nazev  STRING  COMMENT 'Název stavu používaný v Sales Cockpitu. Připojeno z ruční mapovací tabulky podle stavu a společnosti pro datum, kdy je položka číselníku platná.',
    vyskyt_stavu_kod          STRING  COMMENT 'Zda stav odpovídá smlouvě nebo návrhu.',
    poradi                    INT  COMMENT 'Pořadí pro zobrazení ve front endu.',
    platnost_od_datum         DATE  COMMENT 'Počátek platnosti položky číselníku.',
    platnost_do_datum         DATE  COMMENT 'Konec platnosti položky číselníku.',
    publikovano_od_datum      DATE  COMMENT 'Datum, od kdy je položka publikována.',
    publikovano_do_datum      DATE  COMMENT 'Datum, do kdy je položka publikována.',
    __zdrojovy_system         STRING NOT NULL  COMMENT 'Zdrojový systém, ze kterého byl záznam načten. Přebírá se z metadatového sloupce __source_system odpovídající bronze tabulky.',
    __zdrojova_tabulka_nazev  STRING NOT NULL  COMMENT 'Plně kvalifikovaná bronze tabulka, ze které byl záznam načten. U konformovaných entit plněných z více bronze tabulek je to jediný údaj, který rozliší původ konkrétního řádku.',
    verze_id                  STRING NOT NULL  COMMENT 'Identifikátor jedné verze záznamu, md5 hash přirozeného klíče a indikátoru změny, takže se liší verzi od verze. U snapshotů ho plní dbt jako dbt_scd_id, u inkrementálních tabulek ho stejným způsobem počítá plnění. Není to identita entity - tu nese <entita>_hkey, který zůstává napříč verzemi stejný.',
    platnost_od_ts            TIMESTAMP NOT NULL  COMMENT 'Okamžik, od kterého byla tato verze platná. U inkrementálních tabulek čas poslední změny ve zdroji, u snapshotů čas běhu, kdy byl stav pozorován.',
    platnost_do_ts            TIMESTAMP NOT NULL  COMMENT 'Okamžik, do kterého byla verze platná. Otevřená verze nese 9999-12-31 místo NULL, aby porovnávání období nemuselo řešit NULL. Otevřená verze je právě ta, která je v tabulce aktuálního stavu.',
    hash_zaznamu              STRING NOT NULL  COMMENT 'Rozhodovací hash přes všechny byznysové sloupce této verze. Technické sloupce do hashe nevstupují a vnořená pole se před hashováním řadí podle stabilního klíče.',
    __nacteno_ts              TIMESTAMP NOT NULL  COMMENT 'Časové razítko, kdy byla verze vložena do této silver tabulky.',
    __dbt_updated_at          TIMESTAMP NOT NULL  COMMENT 'Vnitřní pracovní značka dbt, proti které se při dalším běhu porovnává stav zdroje. Nese tutéž hodnotu jako platnost_od_ts, protože dbt zapisuje obě meta pole zvlášť a namapovat je na jeden sloupec nelze; rozejít se mohou jedině při zneplatnění smazaného záznamu. Prefix __ a jméno dbt v názvu říkají, že jde o technický sloupec nástroje - pro dotazy používejte platnost_od_ts. Vzniká jen u tabulek plněných snapshotem.',
    CONSTRAINT pk_stav_smlouvy_hist PRIMARY KEY (stav_smlouvy_hkey, platnost_od_ts) NOT ENFORCED
)
USING DELTA
COMMENT 'Historie SCD2 entity stav_smlouvy. Jeden řádek na verzi, platnou mezi platnost_od_ts a platnost_do_ts. Konformovaný číselník stavů smlouvy a návrhu. Zobrazovaný název ze Sales Cockpitu je přiložen z ručně nahrávané mapovací tabulky, ne držen jako druhá entita.'
CLUSTER BY (stav_smlouvy_hkey, platnost_od_ts)
TBLPROPERTIES (
    'delta.columnMapping.mode'   = 'name',
    'delta.enableChangeDataFeed' = 'true',
    'model.layer'                = 'silver',
    'model.table_kind'           = 'history'
);
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.stav_smlouvy_hist SET TAGS ('description_en' = 'SCD2 history of contract_status, one row per version valid between valid_from_timestamp and valid_to_timestamp. Conformed codelist of contract and proposal statuses. The Sales Cockpit display name is merged in from the manually uploaded mapping table rather than kept as a second entity.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.stav_smlouvy_hist ALTER COLUMN stav_smlouvy_hkey SET TAGS ('description_en' = 'Hash of the natural key (stav_smlouvy_kod + spolecnost_kod). Identifies the entity, is stable across versions and serves both as the reference target and as the dbt snapshot unique_key.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.stav_smlouvy_hist ALTER COLUMN stav_smlouvy_kod SET TAGS ('description_en' = 'Code of the status.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.stav_smlouvy_hist ALTER COLUMN spolecnost_kod SET TAGS ('description_en' = 'Group company.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.stav_smlouvy_hist ALTER COLUMN stav_smlouvy_nazev SET TAGS ('description_en' = 'Name of the status.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.stav_smlouvy_hist ALTER COLUMN stav_smlouvy_alfanum_kod SET TAGS ('description_en' = 'Alphanumeric code of the status.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.stav_smlouvy_hist ALTER COLUMN stav_sales_cockpit_nazev SET TAGS ('description_en' = 'Status name as used in the Sales Cockpit. Joined from the manual mapping table bystatus and company for the date the codelist entry is valid.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.stav_smlouvy_hist ALTER COLUMN vyskyt_stavu_kod SET TAGS ('description_en' = 'Whether the status belongs to a contract or an offer.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.stav_smlouvy_hist ALTER COLUMN poradi SET TAGS ('description_en' = 'Display order in the front end.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.stav_smlouvy_hist ALTER COLUMN platnost_od_datum SET TAGS ('description_en' = 'Start of validity of the codelist entry.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.stav_smlouvy_hist ALTER COLUMN platnost_do_datum SET TAGS ('description_en' = 'End of validity of the codelist entry.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.stav_smlouvy_hist ALTER COLUMN publikovano_od_datum SET TAGS ('description_en' = 'Date from which the entry is published.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.stav_smlouvy_hist ALTER COLUMN publikovano_do_datum SET TAGS ('description_en' = 'Date until which the entry is published.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.stav_smlouvy_hist ALTER COLUMN __zdrojovy_system SET TAGS ('description_en' = 'Source system the record was loaded from, taken from the __source_system metadata column of the bronze table.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.stav_smlouvy_hist ALTER COLUMN __zdrojova_tabulka_nazev SET TAGS ('description_en' = 'Fully qualified bronze table the record was loaded from. For conformed entities fedfrom several bronze tables it is the only value that tells the origin of a row apart.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.stav_smlouvy_hist ALTER COLUMN verze_id SET TAGS ('description_en' = 'Identifier of a single version, an md5 hash of the natural key and the change indicator. Filled by dbt_scd_id on snapshots and computed the same way by the load on incremental tables. It is not the entity identity.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.stav_smlouvy_hist ALTER COLUMN platnost_od_ts SET TAGS ('description_en' = 'Point in time from which this version was valid. Part of the history primary key.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.stav_smlouvy_hist ALTER COLUMN platnost_do_ts SET TAGS ('description_en' = 'Point in time until which this version was valid; the open version carries 9999-12-31.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.stav_smlouvy_hist ALTER COLUMN hash_zaznamu SET TAGS ('description_en' = 'The decision hash over all business columns of this version.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.stav_smlouvy_hist ALTER COLUMN __nacteno_ts SET TAGS ('description_en' = 'Timestamp of when the version was inserted into this silver table.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.stav_smlouvy_hist ALTER COLUMN __dbt_updated_at SET TAGS ('description_en' = 'An internal dbt working marker. It carries the same value as the valid-from column; the two can only diverge when a hard-deleted record is invalidated. Only snapshot tables have it.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.stav_smlouvy_hist ALTER COLUMN stav_smlouvy_hkey SET TAGS ('data_classification' = 'internal');

-- ========================= dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.typ_role_partnera =========================
-- current state | grain: Jeden řádek na položku číselníku | sources: KCČ
CREATE TABLE IF NOT EXISTS dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.typ_role_partnera (
    typ_role_partnera_hkey    STRING NOT NULL  COMMENT 'Hash přirozeného klíče (typ_role_kod). Identifikuje entitu, je stabilní napříč verzemi a slouží jako cíl odkazů z jiných entit i jako unique_key snapshotu v dbt.',
    typ_role_kod              INT NOT NULL  COMMENT 'Kód typu role.',
    typ_role_nazev            STRING NOT NULL  COMMENT 'Název typu role.',
    vyskyt_role_kod           STRING  COMMENT 'Pro co je typ role definován.',
    platnost_od_datum         DATE  COMMENT 'Počátek platnosti položky číselníku.',
    platnost_do_datum         DATE  COMMENT 'Konec platnosti položky číselníku.',
    publikovano_od_datum      DATE  COMMENT 'Datum, od kdy je položka publikována.',
    publikovano_do_datum      DATE  COMMENT 'Datum, do kdy je položka publikována.',
    __zdrojovy_system         STRING NOT NULL  COMMENT 'Zdrojový systém, ze kterého byl záznam načten. Přebírá se z metadatového sloupce __source_system odpovídající bronze tabulky.',
    __zdrojova_tabulka_nazev  STRING NOT NULL  COMMENT 'Plně kvalifikovaná bronze tabulka, ze které byl záznam načten. U konformovaných entit plněných z více bronze tabulek je to jediný údaj, který rozliší původ konkrétního řádku.',
    platnost_od_ts            TIMESTAMP NOT NULL  COMMENT 'Okamžik, od kterého je tato verze řádku platná. U inkrementálních tabulek se plní časem poslední změny ve zdroji: u sync topiků z dataUpdatedAt, u delete topiků z auditInformation.lastUpdatedAt. U tabulek plněných snapshotem nese čas běhu, tedy okamžik, kdy jsme stav pozorovali - zdroj posílá celý snímek a vlastní čas změny u číselníků nenabízí.',
    hash_zaznamu              STRING NOT NULL  COMMENT 'Rozhodovací hash přes všechny byznysové sloupce. Podle něj se pozná skutečná změna a v dbt je to jediný sloupec v check_cols. Technické sloupce do hashe nevstupují, jinak by vznikala nová verze při každém běhu, a vnořená pole se před hashováním řadí podle stabilního klíče, jinak by jiné pořadí prvků vypadalo jako změna.',
    __nacteno_ts              TIMESTAMP NOT NULL  COMMENT 'Časové razítko, kdy byl záznam vložen do této silver tabulky.',
    CONSTRAINT pk_typ_role_partnera PRIMARY KEY (typ_role_partnera_hkey) NOT ENFORCED
)
USING DELTA
COMMENT 'Konformovaný číselník rolí, které může partner zastávat na smlouvě nebo pojistné události.'
CLUSTER BY (typ_role_partnera_hkey)
TBLPROPERTIES (
    'delta.columnMapping.mode'   = 'name',
    'delta.enableChangeDataFeed' = 'true',
    'model.layer'                = 'silver',
    'model.table_kind'           = 'current'
);
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.typ_role_partnera SET TAGS ('description_en' = 'Conformed codelist of the roles a party can hold on a contract or on an insurance claim, for example policyholder, insured or driver.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.typ_role_partnera ALTER COLUMN typ_role_partnera_hkey SET TAGS ('description_en' = 'Hash of the natural key (typ_role_kod). Identifies the entity, is stable across versions and serves both as the reference target and as the dbt snapshot unique_key.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.typ_role_partnera ALTER COLUMN typ_role_kod SET TAGS ('description_en' = 'Code of the role type.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.typ_role_partnera ALTER COLUMN typ_role_nazev SET TAGS ('description_en' = 'Name of the role type.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.typ_role_partnera ALTER COLUMN vyskyt_role_kod SET TAGS ('description_en' = 'What the role type is defined for.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.typ_role_partnera ALTER COLUMN platnost_od_datum SET TAGS ('description_en' = 'Start of validity of the codelist entry.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.typ_role_partnera ALTER COLUMN platnost_do_datum SET TAGS ('description_en' = 'End of validity of the codelist entry.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.typ_role_partnera ALTER COLUMN publikovano_od_datum SET TAGS ('description_en' = 'Date from which the entry is published.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.typ_role_partnera ALTER COLUMN publikovano_do_datum SET TAGS ('description_en' = 'Date until which the entry is published.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.typ_role_partnera ALTER COLUMN __zdrojovy_system SET TAGS ('description_en' = 'Source system the record was loaded from, taken from the __source_system metadata column of the bronze table.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.typ_role_partnera ALTER COLUMN __zdrojova_tabulka_nazev SET TAGS ('description_en' = 'Fully qualified bronze table the record was loaded from. For conformed entities fedfrom several bronze tables it is the only value that tells the origin of a row apart.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.typ_role_partnera ALTER COLUMN platnost_od_ts SET TAGS ('description_en' = 'Point in time from which this version is valid, taken from the source change timestamp.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.typ_role_partnera ALTER COLUMN hash_zaznamu SET TAGS ('description_en' = 'The decision hash over all business columns and the only column in the dbt check_cols. Nested arrays must be sorted by a stable key before hashing.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.typ_role_partnera ALTER COLUMN __nacteno_ts SET TAGS ('description_en' = 'Timestamp of when the record was inserted into this silver table.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.typ_role_partnera ALTER COLUMN typ_role_partnera_hkey SET TAGS ('data_classification' = 'internal');

-- ========================= dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.typ_role_partnera_hist =========================
-- SCD2 history | grain: Jeden řádek na položku číselníku | sources: KCČ
CREATE TABLE IF NOT EXISTS dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.typ_role_partnera_hist (
    typ_role_partnera_hkey    STRING NOT NULL  COMMENT 'Hash přirozeného klíče (typ_role_kod). Identifikuje entitu, je stabilní napříč verzemi a slouží jako cíl odkazů z jiných entit i jako unique_key snapshotu v dbt.',
    typ_role_kod              INT NOT NULL  COMMENT 'Kód typu role.',
    typ_role_nazev            STRING NOT NULL  COMMENT 'Název typu role.',
    vyskyt_role_kod           STRING  COMMENT 'Pro co je typ role definován.',
    platnost_od_datum         DATE  COMMENT 'Počátek platnosti položky číselníku.',
    platnost_do_datum         DATE  COMMENT 'Konec platnosti položky číselníku.',
    publikovano_od_datum      DATE  COMMENT 'Datum, od kdy je položka publikována.',
    publikovano_do_datum      DATE  COMMENT 'Datum, do kdy je položka publikována.',
    __zdrojovy_system         STRING NOT NULL  COMMENT 'Zdrojový systém, ze kterého byl záznam načten. Přebírá se z metadatového sloupce __source_system odpovídající bronze tabulky.',
    __zdrojova_tabulka_nazev  STRING NOT NULL  COMMENT 'Plně kvalifikovaná bronze tabulka, ze které byl záznam načten. U konformovaných entit plněných z více bronze tabulek je to jediný údaj, který rozliší původ konkrétního řádku.',
    verze_id                  STRING NOT NULL  COMMENT 'Identifikátor jedné verze záznamu, md5 hash přirozeného klíče a indikátoru změny, takže se liší verzi od verze. U snapshotů ho plní dbt jako dbt_scd_id, u inkrementálních tabulek ho stejným způsobem počítá plnění. Není to identita entity - tu nese <entita>_hkey, který zůstává napříč verzemi stejný.',
    platnost_od_ts            TIMESTAMP NOT NULL  COMMENT 'Okamžik, od kterého byla tato verze platná. U inkrementálních tabulek čas poslední změny ve zdroji, u snapshotů čas běhu, kdy byl stav pozorován.',
    platnost_do_ts            TIMESTAMP NOT NULL  COMMENT 'Okamžik, do kterého byla verze platná. Otevřená verze nese 9999-12-31 místo NULL, aby porovnávání období nemuselo řešit NULL. Otevřená verze je právě ta, která je v tabulce aktuálního stavu.',
    hash_zaznamu              STRING NOT NULL  COMMENT 'Rozhodovací hash přes všechny byznysové sloupce této verze. Technické sloupce do hashe nevstupují a vnořená pole se před hashováním řadí podle stabilního klíče.',
    __nacteno_ts              TIMESTAMP NOT NULL  COMMENT 'Časové razítko, kdy byla verze vložena do této silver tabulky.',
    __dbt_updated_at          TIMESTAMP NOT NULL  COMMENT 'Vnitřní pracovní značka dbt, proti které se při dalším běhu porovnává stav zdroje. Nese tutéž hodnotu jako platnost_od_ts, protože dbt zapisuje obě meta pole zvlášť a namapovat je na jeden sloupec nelze; rozejít se mohou jedině při zneplatnění smazaného záznamu. Prefix __ a jméno dbt v názvu říkají, že jde o technický sloupec nástroje - pro dotazy používejte platnost_od_ts. Vzniká jen u tabulek plněných snapshotem.',
    CONSTRAINT pk_typ_role_partnera_hist PRIMARY KEY (typ_role_partnera_hkey, platnost_od_ts) NOT ENFORCED
)
USING DELTA
COMMENT 'Historie SCD2 entity typ_role_partnera. Jeden řádek na verzi, platnou mezi platnost_od_ts a platnost_do_ts. Konformovaný číselník rolí, které může partner zastávat na smlouvě nebo pojistné události.'
CLUSTER BY (typ_role_partnera_hkey, platnost_od_ts)
TBLPROPERTIES (
    'delta.columnMapping.mode'   = 'name',
    'delta.enableChangeDataFeed' = 'true',
    'model.layer'                = 'silver',
    'model.table_kind'           = 'history'
);
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.typ_role_partnera_hist SET TAGS ('description_en' = 'SCD2 history of party_role_type, one row per version valid between valid_from_timestamp and valid_to_timestamp. Conformed codelist of the roles a party can hold on a contract or on an insurance claim, for example policyholder, insured or driver.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.typ_role_partnera_hist ALTER COLUMN typ_role_partnera_hkey SET TAGS ('description_en' = 'Hash of the natural key (typ_role_kod). Identifies the entity, is stable across versions and serves both as the reference target and as the dbt snapshot unique_key.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.typ_role_partnera_hist ALTER COLUMN typ_role_kod SET TAGS ('description_en' = 'Code of the role type.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.typ_role_partnera_hist ALTER COLUMN typ_role_nazev SET TAGS ('description_en' = 'Name of the role type.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.typ_role_partnera_hist ALTER COLUMN vyskyt_role_kod SET TAGS ('description_en' = 'What the role type is defined for.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.typ_role_partnera_hist ALTER COLUMN platnost_od_datum SET TAGS ('description_en' = 'Start of validity of the codelist entry.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.typ_role_partnera_hist ALTER COLUMN platnost_do_datum SET TAGS ('description_en' = 'End of validity of the codelist entry.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.typ_role_partnera_hist ALTER COLUMN publikovano_od_datum SET TAGS ('description_en' = 'Date from which the entry is published.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.typ_role_partnera_hist ALTER COLUMN publikovano_do_datum SET TAGS ('description_en' = 'Date until which the entry is published.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.typ_role_partnera_hist ALTER COLUMN __zdrojovy_system SET TAGS ('description_en' = 'Source system the record was loaded from, taken from the __source_system metadata column of the bronze table.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.typ_role_partnera_hist ALTER COLUMN __zdrojova_tabulka_nazev SET TAGS ('description_en' = 'Fully qualified bronze table the record was loaded from. For conformed entities fedfrom several bronze tables it is the only value that tells the origin of a row apart.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.typ_role_partnera_hist ALTER COLUMN verze_id SET TAGS ('description_en' = 'Identifier of a single version, an md5 hash of the natural key and the change indicator. Filled by dbt_scd_id on snapshots and computed the same way by the load on incremental tables. It is not the entity identity.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.typ_role_partnera_hist ALTER COLUMN platnost_od_ts SET TAGS ('description_en' = 'Point in time from which this version was valid. Part of the history primary key.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.typ_role_partnera_hist ALTER COLUMN platnost_do_ts SET TAGS ('description_en' = 'Point in time until which this version was valid; the open version carries 9999-12-31.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.typ_role_partnera_hist ALTER COLUMN hash_zaznamu SET TAGS ('description_en' = 'The decision hash over all business columns of this version.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.typ_role_partnera_hist ALTER COLUMN __nacteno_ts SET TAGS ('description_en' = 'Timestamp of when the version was inserted into this silver table.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.typ_role_partnera_hist ALTER COLUMN __dbt_updated_at SET TAGS ('description_en' = 'An internal dbt working marker. It carries the same value as the valid-from column; the two can only diverge when a hard-deleted record is invalidated. Only snapshot tables have it.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.typ_role_partnera_hist ALTER COLUMN typ_role_partnera_hkey SET TAGS ('data_classification' = 'internal');

-- ========================= dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.mezinarodni_predvolba =========================
-- current state | grain: Jeden řádek na položku číselníku | sources: KCČ
CREATE TABLE IF NOT EXISTS dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.mezinarodni_predvolba (
    mezinarodni_predvolba_hkey  STRING NOT NULL  COMMENT 'Hash přirozeného klíče (stat_iso2_kod). Identifikuje entitu, je stabilní napříč verzemi a slouží jako cíl odkazů z jiných entit i jako unique_key snapshotu v dbt.',
    predvolba_kod               INT NOT NULL  COMMENT 'Mezinárodní předvolba. Není primárním klíčem číselníku, ale je to jediný sloupec, kterým lze číselník napojit na smlouvu a návrh, protože internationalPrefix je v AVRO typu int; CountryCodeISO2 je varchar(2) a spojit je nelze.',
    stat_iso2_kod               STRING NOT NULL  COMMENT 'Dvoumístný kód země podle ISO 3166.',
    stat_iso3_kod               STRING  COMMENT 'Třímístný kód země podle ISO 3166.',
    stat_nazev                  STRING  COMMENT 'Název země nebo oblasti.',
    poradi                      INT  COMMENT 'Uživatelsky definované pořadí.',
    platnost_od_datum           DATE  COMMENT 'Počátek platnosti položky číselníku.',
    platnost_do_datum           DATE  COMMENT 'Konec platnosti položky číselníku.',
    publikovano_od_datum        DATE  COMMENT 'Datum, od kdy je položka publikována.',
    publikovano_do_datum        DATE  COMMENT 'Datum, do kdy je položka publikována.',
    __zdrojovy_system           STRING NOT NULL  COMMENT 'Zdrojový systém, ze kterého byl záznam načten. Přebírá se z metadatového sloupce __source_system odpovídající bronze tabulky.',
    __zdrojova_tabulka_nazev    STRING NOT NULL  COMMENT 'Plně kvalifikovaná bronze tabulka, ze které byl záznam načten. U konformovaných entit plněných z více bronze tabulek je to jediný údaj, který rozliší původ konkrétního řádku.',
    platnost_od_ts              TIMESTAMP NOT NULL  COMMENT 'Okamžik, od kterého je tato verze řádku platná. U inkrementálních tabulek se plní časem poslední změny ve zdroji: u sync topiků z dataUpdatedAt, u delete topiků z auditInformation.lastUpdatedAt. U tabulek plněných snapshotem nese čas běhu, tedy okamžik, kdy jsme stav pozorovali - zdroj posílá celý snímek a vlastní čas změny u číselníků nenabízí.',
    hash_zaznamu                STRING NOT NULL  COMMENT 'Rozhodovací hash přes všechny byznysové sloupce. Podle něj se pozná skutečná změna a v dbt je to jediný sloupec v check_cols. Technické sloupce do hashe nevstupují, jinak by vznikala nová verze při každém běhu, a vnořená pole se před hashováním řadí podle stabilního klíče, jinak by jiné pořadí prvků vypadalo jako změna.',
    __nacteno_ts                TIMESTAMP NOT NULL  COMMENT 'Časové razítko, kdy byl záznam vložen do této silver tabulky.',
    CONSTRAINT pk_mezinarodni_predvolba PRIMARY KEY (mezinarodni_predvolba_hkey) NOT ENFORCED
)
USING DELTA
COMMENT 'Konformovaný číselník mezinárodních předvoleb a ISO kódů zemí. Primárním klíčem je stat_iso2_kod, ale vazba na smlouvu a návrh vede přes predvolba_kod. Číselník se čte denně ze souboru V_DialInternationalCodes.csv v landing zóně a obsahuje pouze aktuální stav, protože má vyplněné jen PlatiOd a PlatiDo je prázdné.'
CLUSTER BY (mezinarodni_predvolba_hkey)
TBLPROPERTIES (
    'delta.columnMapping.mode'   = 'name',
    'delta.enableChangeDataFeed' = 'true',
    'model.layer'                = 'silver',
    'model.table_kind'           = 'current'
);
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.mezinarodni_predvolba SET TAGS ('description_en' = 'Conformed codelist of international dialling codes and ISO country codes. The primary key is the two letter ISO country code, but the reference to contract and proposal goes through the dial code. It is read daily from V_DialInternationalCodes.csv in the landing zone and holds the current state only, because the valid-to date is always empty.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.mezinarodni_predvolba ALTER COLUMN mezinarodni_predvolba_hkey SET TAGS ('description_en' = 'Hash of the natural key (stat_iso2_kod). Identifies the entity, is stable across versions and serves both as the reference target and as the dbt snapshot unique_key.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.mezinarodni_predvolba ALTER COLUMN predvolba_kod SET TAGS ('description_en' = 'International dialling code. Not the primary key of the codelist, but the only column that can join it to contract and proposal, because internationalPrefix is an int.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.mezinarodni_predvolba ALTER COLUMN stat_iso2_kod SET TAGS ('description_en' = 'Two letter ISO 3166 country code.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.mezinarodni_predvolba ALTER COLUMN stat_iso3_kod SET TAGS ('description_en' = 'Three letter ISO 3166 country code.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.mezinarodni_predvolba ALTER COLUMN stat_nazev SET TAGS ('description_en' = 'Name of the country or area.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.mezinarodni_predvolba ALTER COLUMN poradi SET TAGS ('description_en' = 'User defined display order.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.mezinarodni_predvolba ALTER COLUMN platnost_od_datum SET TAGS ('description_en' = 'Start of validity of the codelist entry.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.mezinarodni_predvolba ALTER COLUMN platnost_do_datum SET TAGS ('description_en' = 'End of validity of the codelist entry.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.mezinarodni_predvolba ALTER COLUMN publikovano_od_datum SET TAGS ('description_en' = 'Date from which the entry is published.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.mezinarodni_predvolba ALTER COLUMN publikovano_do_datum SET TAGS ('description_en' = 'Date until which the entry is published.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.mezinarodni_predvolba ALTER COLUMN __zdrojovy_system SET TAGS ('description_en' = 'Source system the record was loaded from, taken from the __source_system metadata column of the bronze table.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.mezinarodni_predvolba ALTER COLUMN __zdrojova_tabulka_nazev SET TAGS ('description_en' = 'Fully qualified bronze table the record was loaded from. For conformed entities fedfrom several bronze tables it is the only value that tells the origin of a row apart.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.mezinarodni_predvolba ALTER COLUMN platnost_od_ts SET TAGS ('description_en' = 'Point in time from which this version is valid, taken from the source change timestamp.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.mezinarodni_predvolba ALTER COLUMN hash_zaznamu SET TAGS ('description_en' = 'The decision hash over all business columns and the only column in the dbt check_cols. Nested arrays must be sorted by a stable key before hashing.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.mezinarodni_predvolba ALTER COLUMN __nacteno_ts SET TAGS ('description_en' = 'Timestamp of when the record was inserted into this silver table.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.mezinarodni_predvolba ALTER COLUMN mezinarodni_predvolba_hkey SET TAGS ('data_classification' = 'internal');

-- ========================= dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.mezinarodni_predvolba_hist =========================
-- SCD2 history | grain: Jeden řádek na položku číselníku | sources: KCČ
CREATE TABLE IF NOT EXISTS dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.mezinarodni_predvolba_hist (
    mezinarodni_predvolba_hkey  STRING NOT NULL  COMMENT 'Hash přirozeného klíče (stat_iso2_kod). Identifikuje entitu, je stabilní napříč verzemi a slouží jako cíl odkazů z jiných entit i jako unique_key snapshotu v dbt.',
    predvolba_kod               INT NOT NULL  COMMENT 'Mezinárodní předvolba. Není primárním klíčem číselníku, ale je to jediný sloupec, kterým lze číselník napojit na smlouvu a návrh, protože internationalPrefix je v AVRO typu int; CountryCodeISO2 je varchar(2) a spojit je nelze.',
    stat_iso2_kod               STRING NOT NULL  COMMENT 'Dvoumístný kód země podle ISO 3166.',
    stat_iso3_kod               STRING  COMMENT 'Třímístný kód země podle ISO 3166.',
    stat_nazev                  STRING  COMMENT 'Název země nebo oblasti.',
    poradi                      INT  COMMENT 'Uživatelsky definované pořadí.',
    platnost_od_datum           DATE  COMMENT 'Počátek platnosti položky číselníku.',
    platnost_do_datum           DATE  COMMENT 'Konec platnosti položky číselníku.',
    publikovano_od_datum        DATE  COMMENT 'Datum, od kdy je položka publikována.',
    publikovano_do_datum        DATE  COMMENT 'Datum, do kdy je položka publikována.',
    __zdrojovy_system           STRING NOT NULL  COMMENT 'Zdrojový systém, ze kterého byl záznam načten. Přebírá se z metadatového sloupce __source_system odpovídající bronze tabulky.',
    __zdrojova_tabulka_nazev    STRING NOT NULL  COMMENT 'Plně kvalifikovaná bronze tabulka, ze které byl záznam načten. U konformovaných entit plněných z více bronze tabulek je to jediný údaj, který rozliší původ konkrétního řádku.',
    verze_id                    STRING NOT NULL  COMMENT 'Identifikátor jedné verze záznamu, md5 hash přirozeného klíče a indikátoru změny, takže se liší verzi od verze. U snapshotů ho plní dbt jako dbt_scd_id, u inkrementálních tabulek ho stejným způsobem počítá plnění. Není to identita entity - tu nese <entita>_hkey, který zůstává napříč verzemi stejný.',
    platnost_od_ts              TIMESTAMP NOT NULL  COMMENT 'Okamžik, od kterého byla tato verze platná. U inkrementálních tabulek čas poslední změny ve zdroji, u snapshotů čas běhu, kdy byl stav pozorován.',
    platnost_do_ts              TIMESTAMP NOT NULL  COMMENT 'Okamžik, do kterého byla verze platná. Otevřená verze nese 9999-12-31 místo NULL, aby porovnávání období nemuselo řešit NULL. Otevřená verze je právě ta, která je v tabulce aktuálního stavu.',
    hash_zaznamu                STRING NOT NULL  COMMENT 'Rozhodovací hash přes všechny byznysové sloupce této verze. Technické sloupce do hashe nevstupují a vnořená pole se před hashováním řadí podle stabilního klíče.',
    __nacteno_ts                TIMESTAMP NOT NULL  COMMENT 'Časové razítko, kdy byla verze vložena do této silver tabulky.',
    __dbt_updated_at            TIMESTAMP NOT NULL  COMMENT 'Vnitřní pracovní značka dbt, proti které se při dalším běhu porovnává stav zdroje. Nese tutéž hodnotu jako platnost_od_ts, protože dbt zapisuje obě meta pole zvlášť a namapovat je na jeden sloupec nelze; rozejít se mohou jedině při zneplatnění smazaného záznamu. Prefix __ a jméno dbt v názvu říkají, že jde o technický sloupec nástroje - pro dotazy používejte platnost_od_ts. Vzniká jen u tabulek plněných snapshotem.',
    CONSTRAINT pk_mezinarodni_predvolba_hist PRIMARY KEY (mezinarodni_predvolba_hkey, platnost_od_ts) NOT ENFORCED
)
USING DELTA
COMMENT 'Historie SCD2 entity mezinarodni_predvolba. Jeden řádek na verzi, platnou mezi platnost_od_ts a platnost_do_ts. Konformovaný číselník mezinárodních předvoleb a ISO kódů zemí. Primárním klíčem je stat_iso2_kod, ale vazba na smlouvu a návrh vede přes predvolba_kod. Číselník se čte denně ze souboru V_DialInternationalCodes.csv v landing zóně a obsahuje pouze aktuální stav, protože má vyplněné jen PlatiOd a PlatiDo je prázdné.'
CLUSTER BY (mezinarodni_predvolba_hkey, platnost_od_ts)
TBLPROPERTIES (
    'delta.columnMapping.mode'   = 'name',
    'delta.enableChangeDataFeed' = 'true',
    'model.layer'                = 'silver',
    'model.table_kind'           = 'history'
);
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.mezinarodni_predvolba_hist SET TAGS ('description_en' = 'SCD2 history of country_dial_code, one row per version valid between valid_from_timestamp and valid_to_timestamp. Conformed codelist of international dialling codes and ISO country codes. The primary key is the two letter ISO country code, but the reference to contract and proposal goes through the dial code. It is read daily from V_DialInternationalCodes.csv in the landing zone and holds the current state only, because the valid-to date is always empty.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.mezinarodni_predvolba_hist ALTER COLUMN mezinarodni_predvolba_hkey SET TAGS ('description_en' = 'Hash of the natural key (stat_iso2_kod). Identifies the entity, is stable across versions and serves both as the reference target and as the dbt snapshot unique_key.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.mezinarodni_predvolba_hist ALTER COLUMN predvolba_kod SET TAGS ('description_en' = 'International dialling code. Not the primary key of the codelist, but the only column that can join it to contract and proposal, because internationalPrefix is an int.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.mezinarodni_predvolba_hist ALTER COLUMN stat_iso2_kod SET TAGS ('description_en' = 'Two letter ISO 3166 country code.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.mezinarodni_predvolba_hist ALTER COLUMN stat_iso3_kod SET TAGS ('description_en' = 'Three letter ISO 3166 country code.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.mezinarodni_predvolba_hist ALTER COLUMN stat_nazev SET TAGS ('description_en' = 'Name of the country or area.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.mezinarodni_predvolba_hist ALTER COLUMN poradi SET TAGS ('description_en' = 'User defined display order.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.mezinarodni_predvolba_hist ALTER COLUMN platnost_od_datum SET TAGS ('description_en' = 'Start of validity of the codelist entry.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.mezinarodni_predvolba_hist ALTER COLUMN platnost_do_datum SET TAGS ('description_en' = 'End of validity of the codelist entry.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.mezinarodni_predvolba_hist ALTER COLUMN publikovano_od_datum SET TAGS ('description_en' = 'Date from which the entry is published.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.mezinarodni_predvolba_hist ALTER COLUMN publikovano_do_datum SET TAGS ('description_en' = 'Date until which the entry is published.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.mezinarodni_predvolba_hist ALTER COLUMN __zdrojovy_system SET TAGS ('description_en' = 'Source system the record was loaded from, taken from the __source_system metadata column of the bronze table.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.mezinarodni_predvolba_hist ALTER COLUMN __zdrojova_tabulka_nazev SET TAGS ('description_en' = 'Fully qualified bronze table the record was loaded from. For conformed entities fedfrom several bronze tables it is the only value that tells the origin of a row apart.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.mezinarodni_predvolba_hist ALTER COLUMN verze_id SET TAGS ('description_en' = 'Identifier of a single version, an md5 hash of the natural key and the change indicator. Filled by dbt_scd_id on snapshots and computed the same way by the load on incremental tables. It is not the entity identity.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.mezinarodni_predvolba_hist ALTER COLUMN platnost_od_ts SET TAGS ('description_en' = 'Point in time from which this version was valid. Part of the history primary key.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.mezinarodni_predvolba_hist ALTER COLUMN platnost_do_ts SET TAGS ('description_en' = 'Point in time until which this version was valid; the open version carries 9999-12-31.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.mezinarodni_predvolba_hist ALTER COLUMN hash_zaznamu SET TAGS ('description_en' = 'The decision hash over all business columns of this version.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.mezinarodni_predvolba_hist ALTER COLUMN __nacteno_ts SET TAGS ('description_en' = 'Timestamp of when the version was inserted into this silver table.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.mezinarodni_predvolba_hist ALTER COLUMN __dbt_updated_at SET TAGS ('description_en' = 'An internal dbt working marker. It carries the same value as the valid-from column; the two can only diverge when a hard-deleted record is invalidated. Only snapshot tables have it.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.mezinarodni_predvolba_hist ALTER COLUMN mezinarodni_predvolba_hkey SET TAGS ('data_classification' = 'internal');

-- ========================= dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.distribucni_kanal =========================
-- current state | grain: Jeden řádek na položku číselníku | sources: KCL
CREATE TABLE IF NOT EXISTS dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.distribucni_kanal (
    distribucni_kanal_hkey    STRING NOT NULL  COMMENT 'Hash přirozeného klíče (kanal_id). Identifikuje entitu, je stabilní napříč verzemi a slouží jako cíl odkazů z jiných entit i jako unique_key snapshotu v dbt.',
    kanal_id                  INT NOT NULL  COMMENT 'ID kanálu.',
    kanal_nazev               STRING NOT NULL  COMMENT 'Název kanálu.',
    kanal_kcc_kod             STRING  COMMENT 'Kód kanálu v číselníku KCČ.',
    spolecnost_kod            INT  COMMENT 'Společnost skupiny.',
    neplatny_priznak          BOOLEAN  COMMENT 'TRUE, když položka číselníku už neplatí. Číselníky KCL nemají interval platnosti, pracují s příznakem zastarání.',
    __zdrojovy_system         STRING NOT NULL  COMMENT 'Zdrojový systém, ze kterého byl záznam načten. Přebírá se z metadatového sloupce __source_system odpovídající bronze tabulky.',
    __zdrojova_tabulka_nazev  STRING NOT NULL  COMMENT 'Plně kvalifikovaná bronze tabulka, ze které byl záznam načten. U konformovaných entit plněných z více bronze tabulek je to jediný údaj, který rozliší původ konkrétního řádku.',
    platnost_od_ts            TIMESTAMP NOT NULL  COMMENT 'Okamžik, od kterého je tato verze řádku platná. U inkrementálních tabulek se plní časem poslední změny ve zdroji: u sync topiků z dataUpdatedAt, u delete topiků z auditInformation.lastUpdatedAt. U tabulek plněných snapshotem nese čas běhu, tedy okamžik, kdy jsme stav pozorovali - zdroj posílá celý snímek a vlastní čas změny u číselníků nenabízí.',
    hash_zaznamu              STRING NOT NULL  COMMENT 'Rozhodovací hash přes všechny byznysové sloupce. Podle něj se pozná skutečná změna a v dbt je to jediný sloupec v check_cols. Technické sloupce do hashe nevstupují, jinak by vznikala nová verze při každém běhu, a vnořená pole se před hashováním řadí podle stabilního klíče, jinak by jiné pořadí prvků vypadalo jako změna.',
    __nacteno_ts              TIMESTAMP NOT NULL  COMMENT 'Časové razítko, kdy byl záznam vložen do této silver tabulky.',
    CONSTRAINT pk_distribucni_kanal PRIMARY KEY (distribucni_kanal_hkey) NOT ENFORCED
)
USING DELTA
COMMENT 'Konformovaný číselník distribučních kanálů.'
CLUSTER BY (distribucni_kanal_hkey)
TBLPROPERTIES (
    'delta.columnMapping.mode'   = 'name',
    'delta.enableChangeDataFeed' = 'true',
    'model.layer'                = 'silver',
    'model.table_kind'           = 'current'
);
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.distribucni_kanal SET TAGS ('description_en' = 'Conformed codelist of distribution channels.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.distribucni_kanal ALTER COLUMN distribucni_kanal_hkey SET TAGS ('description_en' = 'Hash of the natural key (kanal_id). Identifies the entity, is stable across versions and serves both as the reference target and as the dbt snapshot unique_key.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.distribucni_kanal ALTER COLUMN kanal_id SET TAGS ('description_en' = 'Identifier of the channel.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.distribucni_kanal ALTER COLUMN kanal_nazev SET TAGS ('description_en' = 'Name of the channel.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.distribucni_kanal ALTER COLUMN kanal_kcc_kod SET TAGS ('description_en' = 'Channel code in the KCC codelist.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.distribucni_kanal ALTER COLUMN spolecnost_kod SET TAGS ('description_en' = 'Group company.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.distribucni_kanal ALTER COLUMN neplatny_priznak SET TAGS ('description_en' = 'TRUE when the codelist entry is no longer valid. The KCL codelists have no validity interval, they use an obsolete flag.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.distribucni_kanal ALTER COLUMN __zdrojovy_system SET TAGS ('description_en' = 'Source system the record was loaded from, taken from the __source_system metadata column of the bronze table.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.distribucni_kanal ALTER COLUMN __zdrojova_tabulka_nazev SET TAGS ('description_en' = 'Fully qualified bronze table the record was loaded from. For conformed entities fedfrom several bronze tables it is the only value that tells the origin of a row apart.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.distribucni_kanal ALTER COLUMN platnost_od_ts SET TAGS ('description_en' = 'Point in time from which this version is valid, taken from the source change timestamp.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.distribucni_kanal ALTER COLUMN hash_zaznamu SET TAGS ('description_en' = 'The decision hash over all business columns and the only column in the dbt check_cols. Nested arrays must be sorted by a stable key before hashing.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.distribucni_kanal ALTER COLUMN __nacteno_ts SET TAGS ('description_en' = 'Timestamp of when the record was inserted into this silver table.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.distribucni_kanal ALTER COLUMN distribucni_kanal_hkey SET TAGS ('data_classification' = 'internal');

-- ========================= dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.distribucni_kanal_hist =========================
-- SCD2 history | grain: Jeden řádek na položku číselníku | sources: KCL
CREATE TABLE IF NOT EXISTS dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.distribucni_kanal_hist (
    distribucni_kanal_hkey    STRING NOT NULL  COMMENT 'Hash přirozeného klíče (kanal_id). Identifikuje entitu, je stabilní napříč verzemi a slouží jako cíl odkazů z jiných entit i jako unique_key snapshotu v dbt.',
    kanal_id                  INT NOT NULL  COMMENT 'ID kanálu.',
    kanal_nazev               STRING NOT NULL  COMMENT 'Název kanálu.',
    kanal_kcc_kod             STRING  COMMENT 'Kód kanálu v číselníku KCČ.',
    spolecnost_kod            INT  COMMENT 'Společnost skupiny.',
    neplatny_priznak          BOOLEAN  COMMENT 'TRUE, když položka číselníku už neplatí. Číselníky KCL nemají interval platnosti, pracují s příznakem zastarání.',
    __zdrojovy_system         STRING NOT NULL  COMMENT 'Zdrojový systém, ze kterého byl záznam načten. Přebírá se z metadatového sloupce __source_system odpovídající bronze tabulky.',
    __zdrojova_tabulka_nazev  STRING NOT NULL  COMMENT 'Plně kvalifikovaná bronze tabulka, ze které byl záznam načten. U konformovaných entit plněných z více bronze tabulek je to jediný údaj, který rozliší původ konkrétního řádku.',
    verze_id                  STRING NOT NULL  COMMENT 'Identifikátor jedné verze záznamu, md5 hash přirozeného klíče a indikátoru změny, takže se liší verzi od verze. U snapshotů ho plní dbt jako dbt_scd_id, u inkrementálních tabulek ho stejným způsobem počítá plnění. Není to identita entity - tu nese <entita>_hkey, který zůstává napříč verzemi stejný.',
    platnost_od_ts            TIMESTAMP NOT NULL  COMMENT 'Okamžik, od kterého byla tato verze platná. U inkrementálních tabulek čas poslední změny ve zdroji, u snapshotů čas běhu, kdy byl stav pozorován.',
    platnost_do_ts            TIMESTAMP NOT NULL  COMMENT 'Okamžik, do kterého byla verze platná. Otevřená verze nese 9999-12-31 místo NULL, aby porovnávání období nemuselo řešit NULL. Otevřená verze je právě ta, která je v tabulce aktuálního stavu.',
    hash_zaznamu              STRING NOT NULL  COMMENT 'Rozhodovací hash přes všechny byznysové sloupce této verze. Technické sloupce do hashe nevstupují a vnořená pole se před hashováním řadí podle stabilního klíče.',
    __nacteno_ts              TIMESTAMP NOT NULL  COMMENT 'Časové razítko, kdy byla verze vložena do této silver tabulky.',
    __dbt_updated_at          TIMESTAMP NOT NULL  COMMENT 'Vnitřní pracovní značka dbt, proti které se při dalším běhu porovnává stav zdroje. Nese tutéž hodnotu jako platnost_od_ts, protože dbt zapisuje obě meta pole zvlášť a namapovat je na jeden sloupec nelze; rozejít se mohou jedině při zneplatnění smazaného záznamu. Prefix __ a jméno dbt v názvu říkají, že jde o technický sloupec nástroje - pro dotazy používejte platnost_od_ts. Vzniká jen u tabulek plněných snapshotem.',
    CONSTRAINT pk_distribucni_kanal_hist PRIMARY KEY (distribucni_kanal_hkey, platnost_od_ts) NOT ENFORCED
)
USING DELTA
COMMENT 'Historie SCD2 entity distribucni_kanal. Jeden řádek na verzi, platnou mezi platnost_od_ts a platnost_do_ts. Konformovaný číselník distribučních kanálů.'
CLUSTER BY (distribucni_kanal_hkey, platnost_od_ts)
TBLPROPERTIES (
    'delta.columnMapping.mode'   = 'name',
    'delta.enableChangeDataFeed' = 'true',
    'model.layer'                = 'silver',
    'model.table_kind'           = 'history'
);
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.distribucni_kanal_hist SET TAGS ('description_en' = 'SCD2 history of distribution_channel, one row per version valid between valid_from_timestamp and valid_to_timestamp. Conformed codelist of distribution channels.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.distribucni_kanal_hist ALTER COLUMN distribucni_kanal_hkey SET TAGS ('description_en' = 'Hash of the natural key (kanal_id). Identifies the entity, is stable across versions and serves both as the reference target and as the dbt snapshot unique_key.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.distribucni_kanal_hist ALTER COLUMN kanal_id SET TAGS ('description_en' = 'Identifier of the channel.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.distribucni_kanal_hist ALTER COLUMN kanal_nazev SET TAGS ('description_en' = 'Name of the channel.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.distribucni_kanal_hist ALTER COLUMN kanal_kcc_kod SET TAGS ('description_en' = 'Channel code in the KCC codelist.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.distribucni_kanal_hist ALTER COLUMN spolecnost_kod SET TAGS ('description_en' = 'Group company.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.distribucni_kanal_hist ALTER COLUMN neplatny_priznak SET TAGS ('description_en' = 'TRUE when the codelist entry is no longer valid. The KCL codelists have no validity interval, they use an obsolete flag.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.distribucni_kanal_hist ALTER COLUMN __zdrojovy_system SET TAGS ('description_en' = 'Source system the record was loaded from, taken from the __source_system metadata column of the bronze table.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.distribucni_kanal_hist ALTER COLUMN __zdrojova_tabulka_nazev SET TAGS ('description_en' = 'Fully qualified bronze table the record was loaded from. For conformed entities fedfrom several bronze tables it is the only value that tells the origin of a row apart.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.distribucni_kanal_hist ALTER COLUMN verze_id SET TAGS ('description_en' = 'Identifier of a single version, an md5 hash of the natural key and the change indicator. Filled by dbt_scd_id on snapshots and computed the same way by the load on incremental tables. It is not the entity identity.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.distribucni_kanal_hist ALTER COLUMN platnost_od_ts SET TAGS ('description_en' = 'Point in time from which this version was valid. Part of the history primary key.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.distribucni_kanal_hist ALTER COLUMN platnost_do_ts SET TAGS ('description_en' = 'Point in time until which this version was valid; the open version carries 9999-12-31.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.distribucni_kanal_hist ALTER COLUMN hash_zaznamu SET TAGS ('description_en' = 'The decision hash over all business columns of this version.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.distribucni_kanal_hist ALTER COLUMN __nacteno_ts SET TAGS ('description_en' = 'Timestamp of when the version was inserted into this silver table.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.distribucni_kanal_hist ALTER COLUMN __dbt_updated_at SET TAGS ('description_en' = 'An internal dbt working marker. It carries the same value as the valid-from column; the two can only diverge when a hard-deleted record is invalidated. Only snapshot tables have it.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.distribucni_kanal_hist ALTER COLUMN distribucni_kanal_hkey SET TAGS ('data_classification' = 'internal');

-- ========================= dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.typ_ukolu =========================
-- current state | grain: Jeden řádek na položku číselníku | sources: KCL
CREATE TABLE IF NOT EXISTS dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.typ_ukolu (
    typ_ukolu_hkey            STRING NOT NULL  COMMENT 'Hash přirozeného klíče (typ_ukolu_id). Identifikuje entitu, je stabilní napříč verzemi a slouží jako cíl odkazů z jiných entit i jako unique_key snapshotu v dbt.',
    typ_ukolu_id              INT NOT NULL  COMMENT 'ID typu úkolu.',
    typ_ukolu_nazev           STRING NOT NULL  COMMENT 'Název typu úkolu.',
    typ_ukolu_kratky_nazev    STRING  COMMENT 'Krátký název, používaný v push notifikacích na mobily.',
    typ_zaznamu_kod           STRING  COMMENT 'Zda je typ úkol, informace nebo příležitost.',
    dnu_na_splneni            INT  COMMENT 'Počet dnů pro splnění úkolu.',
    dnu_do_archivace          INT  COMMENT 'Počet dnů po termínu, kdy se úkol přesune do historické tabulky.',
    spolecnost_kod            INT  COMMENT 'Společnost skupiny.',
    neplatny_priznak          BOOLEAN  COMMENT 'TRUE, když položka číselníku už neplatí. Číselníky KCL nemají interval platnosti, pracují s příznakem zastarání.',
    __zdrojovy_system         STRING NOT NULL  COMMENT 'Zdrojový systém, ze kterého byl záznam načten. Přebírá se z metadatového sloupce __source_system odpovídající bronze tabulky.',
    __zdrojova_tabulka_nazev  STRING NOT NULL  COMMENT 'Plně kvalifikovaná bronze tabulka, ze které byl záznam načten. U konformovaných entit plněných z více bronze tabulek je to jediný údaj, který rozliší původ konkrétního řádku.',
    platnost_od_ts            TIMESTAMP NOT NULL  COMMENT 'Okamžik, od kterého je tato verze řádku platná. U inkrementálních tabulek se plní časem poslední změny ve zdroji: u sync topiků z dataUpdatedAt, u delete topiků z auditInformation.lastUpdatedAt. U tabulek plněných snapshotem nese čas běhu, tedy okamžik, kdy jsme stav pozorovali - zdroj posílá celý snímek a vlastní čas změny u číselníků nenabízí.',
    hash_zaznamu              STRING NOT NULL  COMMENT 'Rozhodovací hash přes všechny byznysové sloupce. Podle něj se pozná skutečná změna a v dbt je to jediný sloupec v check_cols. Technické sloupce do hashe nevstupují, jinak by vznikala nová verze při každém běhu, a vnořená pole se před hashováním řadí podle stabilního klíče, jinak by jiné pořadí prvků vypadalo jako změna.',
    __nacteno_ts              TIMESTAMP NOT NULL  COMMENT 'Časové razítko, kdy byl záznam vložen do této silver tabulky.',
    CONSTRAINT pk_typ_ukolu PRIMARY KEY (typ_ukolu_hkey) NOT ENFORCED
)
USING DELTA
COMMENT 'Konformovaný číselník typů úkolu s vlastnostmi, které řídí zpracování úkolu.'
CLUSTER BY (typ_ukolu_hkey)
TBLPROPERTIES (
    'delta.columnMapping.mode'   = 'name',
    'delta.enableChangeDataFeed' = 'true',
    'model.layer'                = 'silver',
    'model.table_kind'           = 'current'
);
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.typ_ukolu SET TAGS ('description_en' = 'Conformed codelist of task types with the properties that drive task handling, such as the number of days allowed and when the task is archived.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.typ_ukolu ALTER COLUMN typ_ukolu_hkey SET TAGS ('description_en' = 'Hash of the natural key (typ_ukolu_id). Identifies the entity, is stable across versions and serves both as the reference target and as the dbt snapshot unique_key.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.typ_ukolu ALTER COLUMN typ_ukolu_id SET TAGS ('description_en' = 'Identifier of the task type.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.typ_ukolu ALTER COLUMN typ_ukolu_nazev SET TAGS ('description_en' = 'Name of the task type.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.typ_ukolu ALTER COLUMN typ_ukolu_kratky_nazev SET TAGS ('description_en' = 'Short name used in mobile push notifications.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.typ_ukolu ALTER COLUMN typ_zaznamu_kod SET TAGS ('description_en' = 'Whether the type is a task, information or opportunity.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.typ_ukolu ALTER COLUMN dnu_na_splneni SET TAGS ('description_en' = 'Number of days allowed to complete the task.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.typ_ukolu ALTER COLUMN dnu_do_archivace SET TAGS ('description_en' = 'Days after the deadline when the task is archived.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.typ_ukolu ALTER COLUMN spolecnost_kod SET TAGS ('description_en' = 'Group company.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.typ_ukolu ALTER COLUMN neplatny_priznak SET TAGS ('description_en' = 'TRUE when the codelist entry is no longer valid. The KCL codelists have no validity interval, they use an obsolete flag.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.typ_ukolu ALTER COLUMN __zdrojovy_system SET TAGS ('description_en' = 'Source system the record was loaded from, taken from the __source_system metadata column of the bronze table.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.typ_ukolu ALTER COLUMN __zdrojova_tabulka_nazev SET TAGS ('description_en' = 'Fully qualified bronze table the record was loaded from. For conformed entities fedfrom several bronze tables it is the only value that tells the origin of a row apart.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.typ_ukolu ALTER COLUMN platnost_od_ts SET TAGS ('description_en' = 'Point in time from which this version is valid, taken from the source change timestamp.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.typ_ukolu ALTER COLUMN hash_zaznamu SET TAGS ('description_en' = 'The decision hash over all business columns and the only column in the dbt check_cols. Nested arrays must be sorted by a stable key before hashing.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.typ_ukolu ALTER COLUMN __nacteno_ts SET TAGS ('description_en' = 'Timestamp of when the record was inserted into this silver table.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.typ_ukolu ALTER COLUMN typ_ukolu_hkey SET TAGS ('data_classification' = 'internal');

-- ========================= dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.typ_ukolu_hist =========================
-- SCD2 history | grain: Jeden řádek na položku číselníku | sources: KCL
CREATE TABLE IF NOT EXISTS dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.typ_ukolu_hist (
    typ_ukolu_hkey            STRING NOT NULL  COMMENT 'Hash přirozeného klíče (typ_ukolu_id). Identifikuje entitu, je stabilní napříč verzemi a slouží jako cíl odkazů z jiných entit i jako unique_key snapshotu v dbt.',
    typ_ukolu_id              INT NOT NULL  COMMENT 'ID typu úkolu.',
    typ_ukolu_nazev           STRING NOT NULL  COMMENT 'Název typu úkolu.',
    typ_ukolu_kratky_nazev    STRING  COMMENT 'Krátký název, používaný v push notifikacích na mobily.',
    typ_zaznamu_kod           STRING  COMMENT 'Zda je typ úkol, informace nebo příležitost.',
    dnu_na_splneni            INT  COMMENT 'Počet dnů pro splnění úkolu.',
    dnu_do_archivace          INT  COMMENT 'Počet dnů po termínu, kdy se úkol přesune do historické tabulky.',
    spolecnost_kod            INT  COMMENT 'Společnost skupiny.',
    neplatny_priznak          BOOLEAN  COMMENT 'TRUE, když položka číselníku už neplatí. Číselníky KCL nemají interval platnosti, pracují s příznakem zastarání.',
    __zdrojovy_system         STRING NOT NULL  COMMENT 'Zdrojový systém, ze kterého byl záznam načten. Přebírá se z metadatového sloupce __source_system odpovídající bronze tabulky.',
    __zdrojova_tabulka_nazev  STRING NOT NULL  COMMENT 'Plně kvalifikovaná bronze tabulka, ze které byl záznam načten. U konformovaných entit plněných z více bronze tabulek je to jediný údaj, který rozliší původ konkrétního řádku.',
    verze_id                  STRING NOT NULL  COMMENT 'Identifikátor jedné verze záznamu, md5 hash přirozeného klíče a indikátoru změny, takže se liší verzi od verze. U snapshotů ho plní dbt jako dbt_scd_id, u inkrementálních tabulek ho stejným způsobem počítá plnění. Není to identita entity - tu nese <entita>_hkey, který zůstává napříč verzemi stejný.',
    platnost_od_ts            TIMESTAMP NOT NULL  COMMENT 'Okamžik, od kterého byla tato verze platná. U inkrementálních tabulek čas poslední změny ve zdroji, u snapshotů čas běhu, kdy byl stav pozorován.',
    platnost_do_ts            TIMESTAMP NOT NULL  COMMENT 'Okamžik, do kterého byla verze platná. Otevřená verze nese 9999-12-31 místo NULL, aby porovnávání období nemuselo řešit NULL. Otevřená verze je právě ta, která je v tabulce aktuálního stavu.',
    hash_zaznamu              STRING NOT NULL  COMMENT 'Rozhodovací hash přes všechny byznysové sloupce této verze. Technické sloupce do hashe nevstupují a vnořená pole se před hashováním řadí podle stabilního klíče.',
    __nacteno_ts              TIMESTAMP NOT NULL  COMMENT 'Časové razítko, kdy byla verze vložena do této silver tabulky.',
    __dbt_updated_at          TIMESTAMP NOT NULL  COMMENT 'Vnitřní pracovní značka dbt, proti které se při dalším běhu porovnává stav zdroje. Nese tutéž hodnotu jako platnost_od_ts, protože dbt zapisuje obě meta pole zvlášť a namapovat je na jeden sloupec nelze; rozejít se mohou jedině při zneplatnění smazaného záznamu. Prefix __ a jméno dbt v názvu říkají, že jde o technický sloupec nástroje - pro dotazy používejte platnost_od_ts. Vzniká jen u tabulek plněných snapshotem.',
    CONSTRAINT pk_typ_ukolu_hist PRIMARY KEY (typ_ukolu_hkey, platnost_od_ts) NOT ENFORCED
)
USING DELTA
COMMENT 'Historie SCD2 entity typ_ukolu. Jeden řádek na verzi, platnou mezi platnost_od_ts a platnost_do_ts. Konformovaný číselník typů úkolu s vlastnostmi, které řídí zpracování úkolu.'
CLUSTER BY (typ_ukolu_hkey, platnost_od_ts)
TBLPROPERTIES (
    'delta.columnMapping.mode'   = 'name',
    'delta.enableChangeDataFeed' = 'true',
    'model.layer'                = 'silver',
    'model.table_kind'           = 'history'
);
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.typ_ukolu_hist SET TAGS ('description_en' = 'SCD2 history of task_type, one row per version valid between valid_from_timestamp and valid_to_timestamp. Conformed codelist of task types with the properties that drive task handling, such as the number of days allowed and when the task is archived.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.typ_ukolu_hist ALTER COLUMN typ_ukolu_hkey SET TAGS ('description_en' = 'Hash of the natural key (typ_ukolu_id). Identifies the entity, is stable across versions and serves both as the reference target and as the dbt snapshot unique_key.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.typ_ukolu_hist ALTER COLUMN typ_ukolu_id SET TAGS ('description_en' = 'Identifier of the task type.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.typ_ukolu_hist ALTER COLUMN typ_ukolu_nazev SET TAGS ('description_en' = 'Name of the task type.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.typ_ukolu_hist ALTER COLUMN typ_ukolu_kratky_nazev SET TAGS ('description_en' = 'Short name used in mobile push notifications.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.typ_ukolu_hist ALTER COLUMN typ_zaznamu_kod SET TAGS ('description_en' = 'Whether the type is a task, information or opportunity.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.typ_ukolu_hist ALTER COLUMN dnu_na_splneni SET TAGS ('description_en' = 'Number of days allowed to complete the task.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.typ_ukolu_hist ALTER COLUMN dnu_do_archivace SET TAGS ('description_en' = 'Days after the deadline when the task is archived.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.typ_ukolu_hist ALTER COLUMN spolecnost_kod SET TAGS ('description_en' = 'Group company.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.typ_ukolu_hist ALTER COLUMN neplatny_priznak SET TAGS ('description_en' = 'TRUE when the codelist entry is no longer valid. The KCL codelists have no validity interval, they use an obsolete flag.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.typ_ukolu_hist ALTER COLUMN __zdrojovy_system SET TAGS ('description_en' = 'Source system the record was loaded from, taken from the __source_system metadata column of the bronze table.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.typ_ukolu_hist ALTER COLUMN __zdrojova_tabulka_nazev SET TAGS ('description_en' = 'Fully qualified bronze table the record was loaded from. For conformed entities fedfrom several bronze tables it is the only value that tells the origin of a row apart.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.typ_ukolu_hist ALTER COLUMN verze_id SET TAGS ('description_en' = 'Identifier of a single version, an md5 hash of the natural key and the change indicator. Filled by dbt_scd_id on snapshots and computed the same way by the load on incremental tables. It is not the entity identity.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.typ_ukolu_hist ALTER COLUMN platnost_od_ts SET TAGS ('description_en' = 'Point in time from which this version was valid. Part of the history primary key.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.typ_ukolu_hist ALTER COLUMN platnost_do_ts SET TAGS ('description_en' = 'Point in time until which this version was valid; the open version carries 9999-12-31.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.typ_ukolu_hist ALTER COLUMN hash_zaznamu SET TAGS ('description_en' = 'The decision hash over all business columns of this version.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.typ_ukolu_hist ALTER COLUMN __nacteno_ts SET TAGS ('description_en' = 'Timestamp of when the version was inserted into this silver table.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.typ_ukolu_hist ALTER COLUMN __dbt_updated_at SET TAGS ('description_en' = 'An internal dbt working marker. It carries the same value as the valid-from column; the two can only diverge when a hard-deleted record is invalidated. Only snapshot tables have it.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.typ_ukolu_hist ALTER COLUMN typ_ukolu_hkey SET TAGS ('data_classification' = 'internal');

-- ========================= dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.podtyp_ukolu =========================
-- current state | grain: Jeden řádek na položku číselníku | sources: KCL
CREATE TABLE IF NOT EXISTS dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.podtyp_ukolu (
    podtyp_ukolu_hkey             STRING NOT NULL  COMMENT 'Hash přirozeného klíče (podtyp_ukolu_id + spolecnost_kod). Identifikuje entitu, je stabilní napříč verzemi a slouží jako cíl odkazů z jiných entit i jako unique_key snapshotu v dbt.',
    podtyp_ukolu_id               INT NOT NULL  COMMENT 'ID podtypu.',
    spolecnost_kod                INT NOT NULL  COMMENT 'Společnost skupiny.',
    podtyp_ukolu_nazev            STRING NOT NULL  COMMENT 'Název podtypu.',
    typ_ukolu_hkey                STRING  COMMENT 'Typ úkolu, ke kterému podtyp patří.',
    premiova_prilezitost_priznak  BOOLEAN  COMMENT 'TRUE pro prémiovou příležitost. Ve zdroji je příznak na mapovací tabulce typu a podtypu, ne na typu samotném.',
    neplatny_priznak              BOOLEAN  COMMENT 'TRUE, když položka číselníku už neplatí. Číselníky KCL nemají interval platnosti, pracují s příznakem zastarání.',
    __zdrojovy_system             STRING NOT NULL  COMMENT 'Zdrojový systém, ze kterého byl záznam načten. Přebírá se z metadatového sloupce __source_system odpovídající bronze tabulky.',
    __zdrojova_tabulka_nazev      STRING NOT NULL  COMMENT 'Plně kvalifikovaná bronze tabulka, ze které byl záznam načten. U konformovaných entit plněných z více bronze tabulek je to jediný údaj, který rozliší původ konkrétního řádku.',
    platnost_od_ts                TIMESTAMP NOT NULL  COMMENT 'Okamžik, od kterého je tato verze řádku platná. U inkrementálních tabulek se plní časem poslední změny ve zdroji: u sync topiků z dataUpdatedAt, u delete topiků z auditInformation.lastUpdatedAt. U tabulek plněných snapshotem nese čas běhu, tedy okamžik, kdy jsme stav pozorovali - zdroj posílá celý snímek a vlastní čas změny u číselníků nenabízí.',
    hash_zaznamu                  STRING NOT NULL  COMMENT 'Rozhodovací hash přes všechny byznysové sloupce. Podle něj se pozná skutečná změna a v dbt je to jediný sloupec v check_cols. Technické sloupce do hashe nevstupují, jinak by vznikala nová verze při každém běhu, a vnořená pole se před hashováním řadí podle stabilního klíče, jinak by jiné pořadí prvků vypadalo jako změna.',
    __nacteno_ts                  TIMESTAMP NOT NULL  COMMENT 'Časové razítko, kdy byl záznam vložen do této silver tabulky.',
    CONSTRAINT pk_podtyp_ukolu PRIMARY KEY (podtyp_ukolu_hkey) NOT ENFORCED
)
USING DELTA
COMMENT 'Konformovaný číselník podtypů úkolu. Zdroj drží vazbu na typ úkolu v samostatné mapovací tabulce; model ji nese jako cizí klíč, protože mapování je 1:1.'
CLUSTER BY (podtyp_ukolu_hkey)
TBLPROPERTIES (
    'delta.columnMapping.mode'   = 'name',
    'delta.enableChangeDataFeed' = 'true',
    'model.layer'                = 'silver',
    'model.table_kind'           = 'current'
);
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.podtyp_ukolu SET TAGS ('description_en' = 'Conformed codelist of task subtypes. The source keeps the link to the task type in a separate mapping table; the model carries it as a foreign key here, because the mapping is one to one.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.podtyp_ukolu ALTER COLUMN podtyp_ukolu_hkey SET TAGS ('description_en' = 'Hash of the natural key (podtyp_ukolu_id + spolecnost_kod). Identifies the entity, is stable across versions and serves both as the reference target and as the dbt snapshot unique_key.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.podtyp_ukolu ALTER COLUMN podtyp_ukolu_id SET TAGS ('description_en' = 'Identifier of the subtype.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.podtyp_ukolu ALTER COLUMN spolecnost_kod SET TAGS ('description_en' = 'Group company.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.podtyp_ukolu ALTER COLUMN podtyp_ukolu_nazev SET TAGS ('description_en' = 'Name of the subtype.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.podtyp_ukolu ALTER COLUMN typ_ukolu_hkey SET TAGS ('description_en' = 'Task type the subtype belongs to.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.podtyp_ukolu ALTER COLUMN premiova_prilezitost_priznak SET TAGS ('description_en' = 'TRUE for a premium opportunity. In the source the flag sits on the type-subtype mapping table.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.podtyp_ukolu ALTER COLUMN neplatny_priznak SET TAGS ('description_en' = 'TRUE when the codelist entry is no longer valid. The KCL codelists have no validity interval, they use an obsolete flag.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.podtyp_ukolu ALTER COLUMN __zdrojovy_system SET TAGS ('description_en' = 'Source system the record was loaded from, taken from the __source_system metadata column of the bronze table.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.podtyp_ukolu ALTER COLUMN __zdrojova_tabulka_nazev SET TAGS ('description_en' = 'Fully qualified bronze table the record was loaded from. For conformed entities fedfrom several bronze tables it is the only value that tells the origin of a row apart.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.podtyp_ukolu ALTER COLUMN platnost_od_ts SET TAGS ('description_en' = 'Point in time from which this version is valid, taken from the source change timestamp.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.podtyp_ukolu ALTER COLUMN hash_zaznamu SET TAGS ('description_en' = 'The decision hash over all business columns and the only column in the dbt check_cols. Nested arrays must be sorted by a stable key before hashing.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.podtyp_ukolu ALTER COLUMN __nacteno_ts SET TAGS ('description_en' = 'Timestamp of when the record was inserted into this silver table.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.podtyp_ukolu ALTER COLUMN podtyp_ukolu_hkey SET TAGS ('data_classification' = 'internal');

-- ========================= dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.podtyp_ukolu_hist =========================
-- SCD2 history | grain: Jeden řádek na položku číselníku | sources: KCL
CREATE TABLE IF NOT EXISTS dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.podtyp_ukolu_hist (
    podtyp_ukolu_hkey             STRING NOT NULL  COMMENT 'Hash přirozeného klíče (podtyp_ukolu_id + spolecnost_kod). Identifikuje entitu, je stabilní napříč verzemi a slouží jako cíl odkazů z jiných entit i jako unique_key snapshotu v dbt.',
    podtyp_ukolu_id               INT NOT NULL  COMMENT 'ID podtypu.',
    spolecnost_kod                INT NOT NULL  COMMENT 'Společnost skupiny.',
    podtyp_ukolu_nazev            STRING NOT NULL  COMMENT 'Název podtypu.',
    typ_ukolu_hkey                STRING  COMMENT 'Typ úkolu, ke kterému podtyp patří.',
    premiova_prilezitost_priznak  BOOLEAN  COMMENT 'TRUE pro prémiovou příležitost. Ve zdroji je příznak na mapovací tabulce typu a podtypu, ne na typu samotném.',
    neplatny_priznak              BOOLEAN  COMMENT 'TRUE, když položka číselníku už neplatí. Číselníky KCL nemají interval platnosti, pracují s příznakem zastarání.',
    __zdrojovy_system             STRING NOT NULL  COMMENT 'Zdrojový systém, ze kterého byl záznam načten. Přebírá se z metadatového sloupce __source_system odpovídající bronze tabulky.',
    __zdrojova_tabulka_nazev      STRING NOT NULL  COMMENT 'Plně kvalifikovaná bronze tabulka, ze které byl záznam načten. U konformovaných entit plněných z více bronze tabulek je to jediný údaj, který rozliší původ konkrétního řádku.',
    verze_id                      STRING NOT NULL  COMMENT 'Identifikátor jedné verze záznamu, md5 hash přirozeného klíče a indikátoru změny, takže se liší verzi od verze. U snapshotů ho plní dbt jako dbt_scd_id, u inkrementálních tabulek ho stejným způsobem počítá plnění. Není to identita entity - tu nese <entita>_hkey, který zůstává napříč verzemi stejný.',
    platnost_od_ts                TIMESTAMP NOT NULL  COMMENT 'Okamžik, od kterého byla tato verze platná. U inkrementálních tabulek čas poslední změny ve zdroji, u snapshotů čas běhu, kdy byl stav pozorován.',
    platnost_do_ts                TIMESTAMP NOT NULL  COMMENT 'Okamžik, do kterého byla verze platná. Otevřená verze nese 9999-12-31 místo NULL, aby porovnávání období nemuselo řešit NULL. Otevřená verze je právě ta, která je v tabulce aktuálního stavu.',
    hash_zaznamu                  STRING NOT NULL  COMMENT 'Rozhodovací hash přes všechny byznysové sloupce této verze. Technické sloupce do hashe nevstupují a vnořená pole se před hashováním řadí podle stabilního klíče.',
    __nacteno_ts                  TIMESTAMP NOT NULL  COMMENT 'Časové razítko, kdy byla verze vložena do této silver tabulky.',
    __dbt_updated_at              TIMESTAMP NOT NULL  COMMENT 'Vnitřní pracovní značka dbt, proti které se při dalším běhu porovnává stav zdroje. Nese tutéž hodnotu jako platnost_od_ts, protože dbt zapisuje obě meta pole zvlášť a namapovat je na jeden sloupec nelze; rozejít se mohou jedině při zneplatnění smazaného záznamu. Prefix __ a jméno dbt v názvu říkají, že jde o technický sloupec nástroje - pro dotazy používejte platnost_od_ts. Vzniká jen u tabulek plněných snapshotem.',
    CONSTRAINT pk_podtyp_ukolu_hist PRIMARY KEY (podtyp_ukolu_hkey, platnost_od_ts) NOT ENFORCED
)
USING DELTA
COMMENT 'Historie SCD2 entity podtyp_ukolu. Jeden řádek na verzi, platnou mezi platnost_od_ts a platnost_do_ts. Konformovaný číselník podtypů úkolu. Zdroj drží vazbu na typ úkolu v samostatné mapovací tabulce; model ji nese jako cizí klíč, protože mapování je 1:1.'
CLUSTER BY (podtyp_ukolu_hkey, platnost_od_ts)
TBLPROPERTIES (
    'delta.columnMapping.mode'   = 'name',
    'delta.enableChangeDataFeed' = 'true',
    'model.layer'                = 'silver',
    'model.table_kind'           = 'history'
);
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.podtyp_ukolu_hist SET TAGS ('description_en' = 'SCD2 history of task_subtype, one row per version valid between valid_from_timestamp and valid_to_timestamp. Conformed codelist of task subtypes. The source keeps the link to the task type in a separate mapping table; the model carries it as a foreign key here, because the mapping is one to one.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.podtyp_ukolu_hist ALTER COLUMN podtyp_ukolu_hkey SET TAGS ('description_en' = 'Hash of the natural key (podtyp_ukolu_id + spolecnost_kod). Identifies the entity, is stable across versions and serves both as the reference target and as the dbt snapshot unique_key.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.podtyp_ukolu_hist ALTER COLUMN podtyp_ukolu_id SET TAGS ('description_en' = 'Identifier of the subtype.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.podtyp_ukolu_hist ALTER COLUMN spolecnost_kod SET TAGS ('description_en' = 'Group company.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.podtyp_ukolu_hist ALTER COLUMN podtyp_ukolu_nazev SET TAGS ('description_en' = 'Name of the subtype.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.podtyp_ukolu_hist ALTER COLUMN typ_ukolu_hkey SET TAGS ('description_en' = 'Task type the subtype belongs to.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.podtyp_ukolu_hist ALTER COLUMN premiova_prilezitost_priznak SET TAGS ('description_en' = 'TRUE for a premium opportunity. In the source the flag sits on the type-subtype mapping table.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.podtyp_ukolu_hist ALTER COLUMN neplatny_priznak SET TAGS ('description_en' = 'TRUE when the codelist entry is no longer valid. The KCL codelists have no validity interval, they use an obsolete flag.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.podtyp_ukolu_hist ALTER COLUMN __zdrojovy_system SET TAGS ('description_en' = 'Source system the record was loaded from, taken from the __source_system metadata column of the bronze table.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.podtyp_ukolu_hist ALTER COLUMN __zdrojova_tabulka_nazev SET TAGS ('description_en' = 'Fully qualified bronze table the record was loaded from. For conformed entities fedfrom several bronze tables it is the only value that tells the origin of a row apart.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.podtyp_ukolu_hist ALTER COLUMN verze_id SET TAGS ('description_en' = 'Identifier of a single version, an md5 hash of the natural key and the change indicator. Filled by dbt_scd_id on snapshots and computed the same way by the load on incremental tables. It is not the entity identity.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.podtyp_ukolu_hist ALTER COLUMN platnost_od_ts SET TAGS ('description_en' = 'Point in time from which this version was valid. Part of the history primary key.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.podtyp_ukolu_hist ALTER COLUMN platnost_do_ts SET TAGS ('description_en' = 'Point in time until which this version was valid; the open version carries 9999-12-31.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.podtyp_ukolu_hist ALTER COLUMN hash_zaznamu SET TAGS ('description_en' = 'The decision hash over all business columns of this version.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.podtyp_ukolu_hist ALTER COLUMN __nacteno_ts SET TAGS ('description_en' = 'Timestamp of when the version was inserted into this silver table.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.podtyp_ukolu_hist ALTER COLUMN __dbt_updated_at SET TAGS ('description_en' = 'An internal dbt working marker. It carries the same value as the valid-from column; the two can only diverge when a hard-deleted record is invalidated. Only snapshot tables have it.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.podtyp_ukolu_hist ALTER COLUMN podtyp_ukolu_hkey SET TAGS ('data_classification' = 'internal');

-- ========================= dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.stav_ukolu =========================
-- current state | grain: Jeden řádek na položku číselníku | sources: KCL
CREATE TABLE IF NOT EXISTS dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.stav_ukolu (
    stav_ukolu_hkey           STRING NOT NULL  COMMENT 'Hash přirozeného klíče (stav_ukolu_id + spolecnost_kod). Identifikuje entitu, je stabilní napříč verzemi a slouží jako cíl odkazů z jiných entit i jako unique_key snapshotu v dbt.',
    stav_ukolu_id             INT NOT NULL  COMMENT 'ID stavu.',
    spolecnost_kod            INT NOT NULL  COMMENT 'Společnost skupiny.',
    stav_ukolu_nazev          STRING NOT NULL  COMMENT 'Název stavu.',
    neplatny_priznak          BOOLEAN  COMMENT 'TRUE, když položka číselníku už neplatí. Číselníky KCL nemají interval platnosti, pracují s příznakem zastarání.',
    __zdrojovy_system         STRING NOT NULL  COMMENT 'Zdrojový systém, ze kterého byl záznam načten. Přebírá se z metadatového sloupce __source_system odpovídající bronze tabulky.',
    __zdrojova_tabulka_nazev  STRING NOT NULL  COMMENT 'Plně kvalifikovaná bronze tabulka, ze které byl záznam načten. U konformovaných entit plněných z více bronze tabulek je to jediný údaj, který rozliší původ konkrétního řádku.',
    platnost_od_ts            TIMESTAMP NOT NULL  COMMENT 'Okamžik, od kterého je tato verze řádku platná. U inkrementálních tabulek se plní časem poslední změny ve zdroji: u sync topiků z dataUpdatedAt, u delete topiků z auditInformation.lastUpdatedAt. U tabulek plněných snapshotem nese čas běhu, tedy okamžik, kdy jsme stav pozorovali - zdroj posílá celý snímek a vlastní čas změny u číselníků nenabízí.',
    hash_zaznamu              STRING NOT NULL  COMMENT 'Rozhodovací hash přes všechny byznysové sloupce. Podle něj se pozná skutečná změna a v dbt je to jediný sloupec v check_cols. Technické sloupce do hashe nevstupují, jinak by vznikala nová verze při každém běhu, a vnořená pole se před hashováním řadí podle stabilního klíče, jinak by jiné pořadí prvků vypadalo jako změna.',
    __nacteno_ts              TIMESTAMP NOT NULL  COMMENT 'Časové razítko, kdy byl záznam vložen do této silver tabulky.',
    CONSTRAINT pk_stav_ukolu PRIMARY KEY (stav_ukolu_hkey) NOT ENFORCED
)
USING DELTA
COMMENT 'Konformovaný číselník stavů úkolu.'
CLUSTER BY (stav_ukolu_hkey)
TBLPROPERTIES (
    'delta.columnMapping.mode'   = 'name',
    'delta.enableChangeDataFeed' = 'true',
    'model.layer'                = 'silver',
    'model.table_kind'           = 'current'
);
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.stav_ukolu SET TAGS ('description_en' = 'Conformed codelist of task statuses.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.stav_ukolu ALTER COLUMN stav_ukolu_hkey SET TAGS ('description_en' = 'Hash of the natural key (stav_ukolu_id + spolecnost_kod). Identifies the entity, is stable across versions and serves both as the reference target and as the dbt snapshot unique_key.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.stav_ukolu ALTER COLUMN stav_ukolu_id SET TAGS ('description_en' = 'Identifier of the status.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.stav_ukolu ALTER COLUMN spolecnost_kod SET TAGS ('description_en' = 'Group company.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.stav_ukolu ALTER COLUMN stav_ukolu_nazev SET TAGS ('description_en' = 'Name of the status.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.stav_ukolu ALTER COLUMN neplatny_priznak SET TAGS ('description_en' = 'TRUE when the codelist entry is no longer valid. The KCL codelists have no validity interval, they use an obsolete flag.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.stav_ukolu ALTER COLUMN __zdrojovy_system SET TAGS ('description_en' = 'Source system the record was loaded from, taken from the __source_system metadata column of the bronze table.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.stav_ukolu ALTER COLUMN __zdrojova_tabulka_nazev SET TAGS ('description_en' = 'Fully qualified bronze table the record was loaded from. For conformed entities fedfrom several bronze tables it is the only value that tells the origin of a row apart.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.stav_ukolu ALTER COLUMN platnost_od_ts SET TAGS ('description_en' = 'Point in time from which this version is valid, taken from the source change timestamp.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.stav_ukolu ALTER COLUMN hash_zaznamu SET TAGS ('description_en' = 'The decision hash over all business columns and the only column in the dbt check_cols. Nested arrays must be sorted by a stable key before hashing.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.stav_ukolu ALTER COLUMN __nacteno_ts SET TAGS ('description_en' = 'Timestamp of when the record was inserted into this silver table.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.stav_ukolu ALTER COLUMN stav_ukolu_hkey SET TAGS ('data_classification' = 'internal');

-- ========================= dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.stav_ukolu_hist =========================
-- SCD2 history | grain: Jeden řádek na položku číselníku | sources: KCL
CREATE TABLE IF NOT EXISTS dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.stav_ukolu_hist (
    stav_ukolu_hkey           STRING NOT NULL  COMMENT 'Hash přirozeného klíče (stav_ukolu_id + spolecnost_kod). Identifikuje entitu, je stabilní napříč verzemi a slouží jako cíl odkazů z jiných entit i jako unique_key snapshotu v dbt.',
    stav_ukolu_id             INT NOT NULL  COMMENT 'ID stavu.',
    spolecnost_kod            INT NOT NULL  COMMENT 'Společnost skupiny.',
    stav_ukolu_nazev          STRING NOT NULL  COMMENT 'Název stavu.',
    neplatny_priznak          BOOLEAN  COMMENT 'TRUE, když položka číselníku už neplatí. Číselníky KCL nemají interval platnosti, pracují s příznakem zastarání.',
    __zdrojovy_system         STRING NOT NULL  COMMENT 'Zdrojový systém, ze kterého byl záznam načten. Přebírá se z metadatového sloupce __source_system odpovídající bronze tabulky.',
    __zdrojova_tabulka_nazev  STRING NOT NULL  COMMENT 'Plně kvalifikovaná bronze tabulka, ze které byl záznam načten. U konformovaných entit plněných z více bronze tabulek je to jediný údaj, který rozliší původ konkrétního řádku.',
    verze_id                  STRING NOT NULL  COMMENT 'Identifikátor jedné verze záznamu, md5 hash přirozeného klíče a indikátoru změny, takže se liší verzi od verze. U snapshotů ho plní dbt jako dbt_scd_id, u inkrementálních tabulek ho stejným způsobem počítá plnění. Není to identita entity - tu nese <entita>_hkey, který zůstává napříč verzemi stejný.',
    platnost_od_ts            TIMESTAMP NOT NULL  COMMENT 'Okamžik, od kterého byla tato verze platná. U inkrementálních tabulek čas poslední změny ve zdroji, u snapshotů čas běhu, kdy byl stav pozorován.',
    platnost_do_ts            TIMESTAMP NOT NULL  COMMENT 'Okamžik, do kterého byla verze platná. Otevřená verze nese 9999-12-31 místo NULL, aby porovnávání období nemuselo řešit NULL. Otevřená verze je právě ta, která je v tabulce aktuálního stavu.',
    hash_zaznamu              STRING NOT NULL  COMMENT 'Rozhodovací hash přes všechny byznysové sloupce této verze. Technické sloupce do hashe nevstupují a vnořená pole se před hashováním řadí podle stabilního klíče.',
    __nacteno_ts              TIMESTAMP NOT NULL  COMMENT 'Časové razítko, kdy byla verze vložena do této silver tabulky.',
    __dbt_updated_at          TIMESTAMP NOT NULL  COMMENT 'Vnitřní pracovní značka dbt, proti které se při dalším běhu porovnává stav zdroje. Nese tutéž hodnotu jako platnost_od_ts, protože dbt zapisuje obě meta pole zvlášť a namapovat je na jeden sloupec nelze; rozejít se mohou jedině při zneplatnění smazaného záznamu. Prefix __ a jméno dbt v názvu říkají, že jde o technický sloupec nástroje - pro dotazy používejte platnost_od_ts. Vzniká jen u tabulek plněných snapshotem.',
    CONSTRAINT pk_stav_ukolu_hist PRIMARY KEY (stav_ukolu_hkey, platnost_od_ts) NOT ENFORCED
)
USING DELTA
COMMENT 'Historie SCD2 entity stav_ukolu. Jeden řádek na verzi, platnou mezi platnost_od_ts a platnost_do_ts. Konformovaný číselník stavů úkolu.'
CLUSTER BY (stav_ukolu_hkey, platnost_od_ts)
TBLPROPERTIES (
    'delta.columnMapping.mode'   = 'name',
    'delta.enableChangeDataFeed' = 'true',
    'model.layer'                = 'silver',
    'model.table_kind'           = 'history'
);
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.stav_ukolu_hist SET TAGS ('description_en' = 'SCD2 history of task_status, one row per version valid between valid_from_timestamp and valid_to_timestamp. Conformed codelist of task statuses.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.stav_ukolu_hist ALTER COLUMN stav_ukolu_hkey SET TAGS ('description_en' = 'Hash of the natural key (stav_ukolu_id + spolecnost_kod). Identifies the entity, is stable across versions and serves both as the reference target and as the dbt snapshot unique_key.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.stav_ukolu_hist ALTER COLUMN stav_ukolu_id SET TAGS ('description_en' = 'Identifier of the status.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.stav_ukolu_hist ALTER COLUMN spolecnost_kod SET TAGS ('description_en' = 'Group company.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.stav_ukolu_hist ALTER COLUMN stav_ukolu_nazev SET TAGS ('description_en' = 'Name of the status.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.stav_ukolu_hist ALTER COLUMN neplatny_priznak SET TAGS ('description_en' = 'TRUE when the codelist entry is no longer valid. The KCL codelists have no validity interval, they use an obsolete flag.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.stav_ukolu_hist ALTER COLUMN __zdrojovy_system SET TAGS ('description_en' = 'Source system the record was loaded from, taken from the __source_system metadata column of the bronze table.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.stav_ukolu_hist ALTER COLUMN __zdrojova_tabulka_nazev SET TAGS ('description_en' = 'Fully qualified bronze table the record was loaded from. For conformed entities fedfrom several bronze tables it is the only value that tells the origin of a row apart.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.stav_ukolu_hist ALTER COLUMN verze_id SET TAGS ('description_en' = 'Identifier of a single version, an md5 hash of the natural key and the change indicator. Filled by dbt_scd_id on snapshots and computed the same way by the load on incremental tables. It is not the entity identity.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.stav_ukolu_hist ALTER COLUMN platnost_od_ts SET TAGS ('description_en' = 'Point in time from which this version was valid. Part of the history primary key.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.stav_ukolu_hist ALTER COLUMN platnost_do_ts SET TAGS ('description_en' = 'Point in time until which this version was valid; the open version carries 9999-12-31.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.stav_ukolu_hist ALTER COLUMN hash_zaznamu SET TAGS ('description_en' = 'The decision hash over all business columns of this version.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.stav_ukolu_hist ALTER COLUMN __nacteno_ts SET TAGS ('description_en' = 'Timestamp of when the version was inserted into this silver table.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.stav_ukolu_hist ALTER COLUMN __dbt_updated_at SET TAGS ('description_en' = 'An internal dbt working marker. It carries the same value as the valid-from column; the two can only diverge when a hard-deleted record is invalidated. Only snapshot tables have it.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.stav_ukolu_hist ALTER COLUMN stav_ukolu_hkey SET TAGS ('data_classification' = 'internal');

-- ========================= dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.zpusob_dokonceni_ukolu =========================
-- current state | grain: Jeden řádek na položku číselníku | sources: KCL
CREATE TABLE IF NOT EXISTS dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.zpusob_dokonceni_ukolu (
    zpusob_dokonceni_ukolu_hkey  STRING NOT NULL  COMMENT 'Hash přirozeného klíče (zpusob_dokonceni_id + spolecnost_kod). Identifikuje entitu, je stabilní napříč verzemi a slouží jako cíl odkazů z jiných entit i jako unique_key snapshotu v dbt.',
    zpusob_dokonceni_id          INT NOT NULL  COMMENT 'ID způsobu dokončení.',
    spolecnost_kod               INT NOT NULL  COMMENT 'Společnost skupiny.',
    zpusob_dokonceni_nazev       STRING NOT NULL  COMMENT 'Název způsobu dokončení.',
    typ_ukolu_hkey               STRING  COMMENT 'Typ úkolu, ke kterému se způsob dokončení vztahuje.',
    uspech_priznak               BOOLEAN  COMMENT 'TRUE, když se dokončení počítá jako úspěch.',
    prubezna_priznak             BOOLEAN  COMMENT 'TRUE pro průběžný způsob dokončení, FALSE pro finální.',
    neplatny_priznak             BOOLEAN  COMMENT 'TRUE, když položka číselníku už neplatí. Číselníky KCL nemají interval platnosti, pracují s příznakem zastarání.',
    __zdrojovy_system            STRING NOT NULL  COMMENT 'Zdrojový systém, ze kterého byl záznam načten. Přebírá se z metadatového sloupce __source_system odpovídající bronze tabulky.',
    __zdrojova_tabulka_nazev     STRING NOT NULL  COMMENT 'Plně kvalifikovaná bronze tabulka, ze které byl záznam načten. U konformovaných entit plněných z více bronze tabulek je to jediný údaj, který rozliší původ konkrétního řádku.',
    platnost_od_ts               TIMESTAMP NOT NULL  COMMENT 'Okamžik, od kterého je tato verze řádku platná. U inkrementálních tabulek se plní časem poslední změny ve zdroji: u sync topiků z dataUpdatedAt, u delete topiků z auditInformation.lastUpdatedAt. U tabulek plněných snapshotem nese čas běhu, tedy okamžik, kdy jsme stav pozorovali - zdroj posílá celý snímek a vlastní čas změny u číselníků nenabízí.',
    hash_zaznamu                 STRING NOT NULL  COMMENT 'Rozhodovací hash přes všechny byznysové sloupce. Podle něj se pozná skutečná změna a v dbt je to jediný sloupec v check_cols. Technické sloupce do hashe nevstupují, jinak by vznikala nová verze při každém běhu, a vnořená pole se před hashováním řadí podle stabilního klíče, jinak by jiné pořadí prvků vypadalo jako změna.',
    __nacteno_ts                 TIMESTAMP NOT NULL  COMMENT 'Časové razítko, kdy byl záznam vložen do této silver tabulky.',
    CONSTRAINT pk_zpusob_dokonceni_ukolu PRIMARY KEY (zpusob_dokonceni_ukolu_hkey) NOT ENFORCED
)
USING DELTA
COMMENT 'Konformovaný číselník způsobů dokončení úkolu, s příznakem, zda se dokončení počítá jako úspěch.'
CLUSTER BY (zpusob_dokonceni_ukolu_hkey)
TBLPROPERTIES (
    'delta.columnMapping.mode'   = 'name',
    'delta.enableChangeDataFeed' = 'true',
    'model.layer'                = 'silver',
    'model.table_kind'           = 'current'
);
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.zpusob_dokonceni_ukolu SET TAGS ('description_en' = 'Conformed codelist of task completion types, with the flag that says whether the completion counts as a success.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.zpusob_dokonceni_ukolu ALTER COLUMN zpusob_dokonceni_ukolu_hkey SET TAGS ('description_en' = 'Hash of the natural key (zpusob_dokonceni_id + spolecnost_kod). Identifies the entity, is stable across versions and serves both as the reference target and as the dbt snapshot unique_key.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.zpusob_dokonceni_ukolu ALTER COLUMN zpusob_dokonceni_id SET TAGS ('description_en' = 'Identifier of the completion type.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.zpusob_dokonceni_ukolu ALTER COLUMN spolecnost_kod SET TAGS ('description_en' = 'Group company.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.zpusob_dokonceni_ukolu ALTER COLUMN zpusob_dokonceni_nazev SET TAGS ('description_en' = 'Name of the completion type.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.zpusob_dokonceni_ukolu ALTER COLUMN typ_ukolu_hkey SET TAGS ('description_en' = 'Task type the completion type applies to.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.zpusob_dokonceni_ukolu ALTER COLUMN uspech_priznak SET TAGS ('description_en' = 'TRUE when the completion counts as a success.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.zpusob_dokonceni_ukolu ALTER COLUMN prubezna_priznak SET TAGS ('description_en' = 'TRUE for an interim completion type.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.zpusob_dokonceni_ukolu ALTER COLUMN neplatny_priznak SET TAGS ('description_en' = 'TRUE when the codelist entry is no longer valid. The KCL codelists have no validity interval, they use an obsolete flag.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.zpusob_dokonceni_ukolu ALTER COLUMN __zdrojovy_system SET TAGS ('description_en' = 'Source system the record was loaded from, taken from the __source_system metadata column of the bronze table.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.zpusob_dokonceni_ukolu ALTER COLUMN __zdrojova_tabulka_nazev SET TAGS ('description_en' = 'Fully qualified bronze table the record was loaded from. For conformed entities fedfrom several bronze tables it is the only value that tells the origin of a row apart.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.zpusob_dokonceni_ukolu ALTER COLUMN platnost_od_ts SET TAGS ('description_en' = 'Point in time from which this version is valid, taken from the source change timestamp.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.zpusob_dokonceni_ukolu ALTER COLUMN hash_zaznamu SET TAGS ('description_en' = 'The decision hash over all business columns and the only column in the dbt check_cols. Nested arrays must be sorted by a stable key before hashing.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.zpusob_dokonceni_ukolu ALTER COLUMN __nacteno_ts SET TAGS ('description_en' = 'Timestamp of when the record was inserted into this silver table.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.zpusob_dokonceni_ukolu ALTER COLUMN zpusob_dokonceni_ukolu_hkey SET TAGS ('data_classification' = 'internal');

-- ========================= dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.zpusob_dokonceni_ukolu_hist =========================
-- SCD2 history | grain: Jeden řádek na položku číselníku | sources: KCL
CREATE TABLE IF NOT EXISTS dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.zpusob_dokonceni_ukolu_hist (
    zpusob_dokonceni_ukolu_hkey  STRING NOT NULL  COMMENT 'Hash přirozeného klíče (zpusob_dokonceni_id + spolecnost_kod). Identifikuje entitu, je stabilní napříč verzemi a slouží jako cíl odkazů z jiných entit i jako unique_key snapshotu v dbt.',
    zpusob_dokonceni_id          INT NOT NULL  COMMENT 'ID způsobu dokončení.',
    spolecnost_kod               INT NOT NULL  COMMENT 'Společnost skupiny.',
    zpusob_dokonceni_nazev       STRING NOT NULL  COMMENT 'Název způsobu dokončení.',
    typ_ukolu_hkey               STRING  COMMENT 'Typ úkolu, ke kterému se způsob dokončení vztahuje.',
    uspech_priznak               BOOLEAN  COMMENT 'TRUE, když se dokončení počítá jako úspěch.',
    prubezna_priznak             BOOLEAN  COMMENT 'TRUE pro průběžný způsob dokončení, FALSE pro finální.',
    neplatny_priznak             BOOLEAN  COMMENT 'TRUE, když položka číselníku už neplatí. Číselníky KCL nemají interval platnosti, pracují s příznakem zastarání.',
    __zdrojovy_system            STRING NOT NULL  COMMENT 'Zdrojový systém, ze kterého byl záznam načten. Přebírá se z metadatového sloupce __source_system odpovídající bronze tabulky.',
    __zdrojova_tabulka_nazev     STRING NOT NULL  COMMENT 'Plně kvalifikovaná bronze tabulka, ze které byl záznam načten. U konformovaných entit plněných z více bronze tabulek je to jediný údaj, který rozliší původ konkrétního řádku.',
    verze_id                     STRING NOT NULL  COMMENT 'Identifikátor jedné verze záznamu, md5 hash přirozeného klíče a indikátoru změny, takže se liší verzi od verze. U snapshotů ho plní dbt jako dbt_scd_id, u inkrementálních tabulek ho stejným způsobem počítá plnění. Není to identita entity - tu nese <entita>_hkey, který zůstává napříč verzemi stejný.',
    platnost_od_ts               TIMESTAMP NOT NULL  COMMENT 'Okamžik, od kterého byla tato verze platná. U inkrementálních tabulek čas poslední změny ve zdroji, u snapshotů čas běhu, kdy byl stav pozorován.',
    platnost_do_ts               TIMESTAMP NOT NULL  COMMENT 'Okamžik, do kterého byla verze platná. Otevřená verze nese 9999-12-31 místo NULL, aby porovnávání období nemuselo řešit NULL. Otevřená verze je právě ta, která je v tabulce aktuálního stavu.',
    hash_zaznamu                 STRING NOT NULL  COMMENT 'Rozhodovací hash přes všechny byznysové sloupce této verze. Technické sloupce do hashe nevstupují a vnořená pole se před hashováním řadí podle stabilního klíče.',
    __nacteno_ts                 TIMESTAMP NOT NULL  COMMENT 'Časové razítko, kdy byla verze vložena do této silver tabulky.',
    __dbt_updated_at             TIMESTAMP NOT NULL  COMMENT 'Vnitřní pracovní značka dbt, proti které se při dalším běhu porovnává stav zdroje. Nese tutéž hodnotu jako platnost_od_ts, protože dbt zapisuje obě meta pole zvlášť a namapovat je na jeden sloupec nelze; rozejít se mohou jedině při zneplatnění smazaného záznamu. Prefix __ a jméno dbt v názvu říkají, že jde o technický sloupec nástroje - pro dotazy používejte platnost_od_ts. Vzniká jen u tabulek plněných snapshotem.',
    CONSTRAINT pk_zpusob_dokonceni_ukolu_hist PRIMARY KEY (zpusob_dokonceni_ukolu_hkey, platnost_od_ts) NOT ENFORCED
)
USING DELTA
COMMENT 'Historie SCD2 entity zpusob_dokonceni_ukolu. Jeden řádek na verzi, platnou mezi platnost_od_ts a platnost_do_ts. Konformovaný číselník způsobů dokončení úkolu, s příznakem, zda se dokončení počítá jako úspěch.'
CLUSTER BY (zpusob_dokonceni_ukolu_hkey, platnost_od_ts)
TBLPROPERTIES (
    'delta.columnMapping.mode'   = 'name',
    'delta.enableChangeDataFeed' = 'true',
    'model.layer'                = 'silver',
    'model.table_kind'           = 'history'
);
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.zpusob_dokonceni_ukolu_hist SET TAGS ('description_en' = 'SCD2 history of task_finish_type, one row per version valid between valid_from_timestamp and valid_to_timestamp. Conformed codelist of task completion types, with the flag that says whether the completion counts as a success.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.zpusob_dokonceni_ukolu_hist ALTER COLUMN zpusob_dokonceni_ukolu_hkey SET TAGS ('description_en' = 'Hash of the natural key (zpusob_dokonceni_id + spolecnost_kod). Identifies the entity, is stable across versions and serves both as the reference target and as the dbt snapshot unique_key.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.zpusob_dokonceni_ukolu_hist ALTER COLUMN zpusob_dokonceni_id SET TAGS ('description_en' = 'Identifier of the completion type.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.zpusob_dokonceni_ukolu_hist ALTER COLUMN spolecnost_kod SET TAGS ('description_en' = 'Group company.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.zpusob_dokonceni_ukolu_hist ALTER COLUMN zpusob_dokonceni_nazev SET TAGS ('description_en' = 'Name of the completion type.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.zpusob_dokonceni_ukolu_hist ALTER COLUMN typ_ukolu_hkey SET TAGS ('description_en' = 'Task type the completion type applies to.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.zpusob_dokonceni_ukolu_hist ALTER COLUMN uspech_priznak SET TAGS ('description_en' = 'TRUE when the completion counts as a success.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.zpusob_dokonceni_ukolu_hist ALTER COLUMN prubezna_priznak SET TAGS ('description_en' = 'TRUE for an interim completion type.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.zpusob_dokonceni_ukolu_hist ALTER COLUMN neplatny_priznak SET TAGS ('description_en' = 'TRUE when the codelist entry is no longer valid. The KCL codelists have no validity interval, they use an obsolete flag.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.zpusob_dokonceni_ukolu_hist ALTER COLUMN __zdrojovy_system SET TAGS ('description_en' = 'Source system the record was loaded from, taken from the __source_system metadata column of the bronze table.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.zpusob_dokonceni_ukolu_hist ALTER COLUMN __zdrojova_tabulka_nazev SET TAGS ('description_en' = 'Fully qualified bronze table the record was loaded from. For conformed entities fedfrom several bronze tables it is the only value that tells the origin of a row apart.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.zpusob_dokonceni_ukolu_hist ALTER COLUMN verze_id SET TAGS ('description_en' = 'Identifier of a single version, an md5 hash of the natural key and the change indicator. Filled by dbt_scd_id on snapshots and computed the same way by the load on incremental tables. It is not the entity identity.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.zpusob_dokonceni_ukolu_hist ALTER COLUMN platnost_od_ts SET TAGS ('description_en' = 'Point in time from which this version was valid. Part of the history primary key.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.zpusob_dokonceni_ukolu_hist ALTER COLUMN platnost_do_ts SET TAGS ('description_en' = 'Point in time until which this version was valid; the open version carries 9999-12-31.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.zpusob_dokonceni_ukolu_hist ALTER COLUMN hash_zaznamu SET TAGS ('description_en' = 'The decision hash over all business columns of this version.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.zpusob_dokonceni_ukolu_hist ALTER COLUMN __nacteno_ts SET TAGS ('description_en' = 'Timestamp of when the version was inserted into this silver table.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.zpusob_dokonceni_ukolu_hist ALTER COLUMN __dbt_updated_at SET TAGS ('description_en' = 'An internal dbt working marker. It carries the same value as the valid-from column; the two can only diverge when a hard-deleted record is invalidated. Only snapshot tables have it.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.zpusob_dokonceni_ukolu_hist ALTER COLUMN zpusob_dokonceni_ukolu_hkey SET TAGS ('data_classification' = 'internal');

-- ========================= dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.stav_kontaktu =========================
-- current state | grain: Jeden řádek na položku číselníku | sources: KCL
CREATE TABLE IF NOT EXISTS dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.stav_kontaktu (
    stav_kontaktu_hkey        STRING NOT NULL  COMMENT 'Hash přirozeného klíče (stav_kontaktu_id). Identifikuje entitu, je stabilní napříč verzemi a slouží jako cíl odkazů z jiných entit i jako unique_key snapshotu v dbt.',
    stav_kontaktu_id          INT NOT NULL  COMMENT 'ID stavu.',
    stav_kontaktu_nazev       STRING NOT NULL  COMMENT 'Zobrazovaný název zpětné vazby.',
    stav_kontaktu_popis       STRING  COMMENT 'Detailnější popis zpětné vazby.',
    zpetna_vazba_kod          STRING  COMMENT 'Text určující zpětnou vazbu, například SYSTEM, PROGRESS, FAIL nebo SUCCESSFUL.',
    spolecnost_kod            INT  COMMENT 'Společnost skupiny.',
    neplatny_priznak          BOOLEAN  COMMENT 'TRUE, když položka číselníku už neplatí. Číselníky KCL nemají interval platnosti, pracují s příznakem zastarání.',
    __zdrojovy_system         STRING NOT NULL  COMMENT 'Zdrojový systém, ze kterého byl záznam načten. Přebírá se z metadatového sloupce __source_system odpovídající bronze tabulky.',
    __zdrojova_tabulka_nazev  STRING NOT NULL  COMMENT 'Plně kvalifikovaná bronze tabulka, ze které byl záznam načten. U konformovaných entit plněných z více bronze tabulek je to jediný údaj, který rozliší původ konkrétního řádku.',
    platnost_od_ts            TIMESTAMP NOT NULL  COMMENT 'Okamžik, od kterého je tato verze řádku platná. U inkrementálních tabulek se plní časem poslední změny ve zdroji: u sync topiků z dataUpdatedAt, u delete topiků z auditInformation.lastUpdatedAt. U tabulek plněných snapshotem nese čas běhu, tedy okamžik, kdy jsme stav pozorovali - zdroj posílá celý snímek a vlastní čas změny u číselníků nenabízí.',
    hash_zaznamu              STRING NOT NULL  COMMENT 'Rozhodovací hash přes všechny byznysové sloupce. Podle něj se pozná skutečná změna a v dbt je to jediný sloupec v check_cols. Technické sloupce do hashe nevstupují, jinak by vznikala nová verze při každém běhu, a vnořená pole se před hashováním řadí podle stabilního klíče, jinak by jiné pořadí prvků vypadalo jako změna.',
    __nacteno_ts              TIMESTAMP NOT NULL  COMMENT 'Časové razítko, kdy byl záznam vložen do této silver tabulky.',
    CONSTRAINT pk_stav_kontaktu PRIMARY KEY (stav_kontaktu_hkey) NOT ENFORCED
)
USING DELTA
COMMENT 'Konformovaný číselník stavů kontaktu v kampani, tedy zpětné vazby, kterou může obchodník ke kontaktu zadat.'
CLUSTER BY (stav_kontaktu_hkey)
TBLPROPERTIES (
    'delta.columnMapping.mode'   = 'name',
    'delta.enableChangeDataFeed' = 'true',
    'model.layer'                = 'silver',
    'model.table_kind'           = 'current'
);
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.stav_kontaktu SET TAGS ('description_en' = 'Conformed codelist of campaign contact states, that is the feedback an agent can enter on a contact.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.stav_kontaktu ALTER COLUMN stav_kontaktu_hkey SET TAGS ('description_en' = 'Hash of the natural key (stav_kontaktu_id). Identifies the entity, is stable across versions and serves both as the reference target and as the dbt snapshot unique_key.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.stav_kontaktu ALTER COLUMN stav_kontaktu_id SET TAGS ('description_en' = 'Identifier of the state.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.stav_kontaktu ALTER COLUMN stav_kontaktu_nazev SET TAGS ('description_en' = 'Displayed name of the feedback.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.stav_kontaktu ALTER COLUMN stav_kontaktu_popis SET TAGS ('description_en' = 'More detailed description.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.stav_kontaktu ALTER COLUMN zpetna_vazba_kod SET TAGS ('description_en' = 'Text identifying the feedback.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.stav_kontaktu ALTER COLUMN spolecnost_kod SET TAGS ('description_en' = 'Group company.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.stav_kontaktu ALTER COLUMN neplatny_priznak SET TAGS ('description_en' = 'TRUE when the codelist entry is no longer valid. The KCL codelists have no validity interval, they use an obsolete flag.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.stav_kontaktu ALTER COLUMN __zdrojovy_system SET TAGS ('description_en' = 'Source system the record was loaded from, taken from the __source_system metadata column of the bronze table.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.stav_kontaktu ALTER COLUMN __zdrojova_tabulka_nazev SET TAGS ('description_en' = 'Fully qualified bronze table the record was loaded from. For conformed entities fedfrom several bronze tables it is the only value that tells the origin of a row apart.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.stav_kontaktu ALTER COLUMN platnost_od_ts SET TAGS ('description_en' = 'Point in time from which this version is valid, taken from the source change timestamp.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.stav_kontaktu ALTER COLUMN hash_zaznamu SET TAGS ('description_en' = 'The decision hash over all business columns and the only column in the dbt check_cols. Nested arrays must be sorted by a stable key before hashing.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.stav_kontaktu ALTER COLUMN __nacteno_ts SET TAGS ('description_en' = 'Timestamp of when the record was inserted into this silver table.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.stav_kontaktu ALTER COLUMN stav_kontaktu_hkey SET TAGS ('data_classification' = 'internal');

-- ========================= dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.stav_kontaktu_hist =========================
-- SCD2 history | grain: Jeden řádek na položku číselníku | sources: KCL
CREATE TABLE IF NOT EXISTS dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.stav_kontaktu_hist (
    stav_kontaktu_hkey        STRING NOT NULL  COMMENT 'Hash přirozeného klíče (stav_kontaktu_id). Identifikuje entitu, je stabilní napříč verzemi a slouží jako cíl odkazů z jiných entit i jako unique_key snapshotu v dbt.',
    stav_kontaktu_id          INT NOT NULL  COMMENT 'ID stavu.',
    stav_kontaktu_nazev       STRING NOT NULL  COMMENT 'Zobrazovaný název zpětné vazby.',
    stav_kontaktu_popis       STRING  COMMENT 'Detailnější popis zpětné vazby.',
    zpetna_vazba_kod          STRING  COMMENT 'Text určující zpětnou vazbu, například SYSTEM, PROGRESS, FAIL nebo SUCCESSFUL.',
    spolecnost_kod            INT  COMMENT 'Společnost skupiny.',
    neplatny_priznak          BOOLEAN  COMMENT 'TRUE, když položka číselníku už neplatí. Číselníky KCL nemají interval platnosti, pracují s příznakem zastarání.',
    __zdrojovy_system         STRING NOT NULL  COMMENT 'Zdrojový systém, ze kterého byl záznam načten. Přebírá se z metadatového sloupce __source_system odpovídající bronze tabulky.',
    __zdrojova_tabulka_nazev  STRING NOT NULL  COMMENT 'Plně kvalifikovaná bronze tabulka, ze které byl záznam načten. U konformovaných entit plněných z více bronze tabulek je to jediný údaj, který rozliší původ konkrétního řádku.',
    verze_id                  STRING NOT NULL  COMMENT 'Identifikátor jedné verze záznamu, md5 hash přirozeného klíče a indikátoru změny, takže se liší verzi od verze. U snapshotů ho plní dbt jako dbt_scd_id, u inkrementálních tabulek ho stejným způsobem počítá plnění. Není to identita entity - tu nese <entita>_hkey, který zůstává napříč verzemi stejný.',
    platnost_od_ts            TIMESTAMP NOT NULL  COMMENT 'Okamžik, od kterého byla tato verze platná. U inkrementálních tabulek čas poslední změny ve zdroji, u snapshotů čas běhu, kdy byl stav pozorován.',
    platnost_do_ts            TIMESTAMP NOT NULL  COMMENT 'Okamžik, do kterého byla verze platná. Otevřená verze nese 9999-12-31 místo NULL, aby porovnávání období nemuselo řešit NULL. Otevřená verze je právě ta, která je v tabulce aktuálního stavu.',
    hash_zaznamu              STRING NOT NULL  COMMENT 'Rozhodovací hash přes všechny byznysové sloupce této verze. Technické sloupce do hashe nevstupují a vnořená pole se před hashováním řadí podle stabilního klíče.',
    __nacteno_ts              TIMESTAMP NOT NULL  COMMENT 'Časové razítko, kdy byla verze vložena do této silver tabulky.',
    __dbt_updated_at          TIMESTAMP NOT NULL  COMMENT 'Vnitřní pracovní značka dbt, proti které se při dalším běhu porovnává stav zdroje. Nese tutéž hodnotu jako platnost_od_ts, protože dbt zapisuje obě meta pole zvlášť a namapovat je na jeden sloupec nelze; rozejít se mohou jedině při zneplatnění smazaného záznamu. Prefix __ a jméno dbt v názvu říkají, že jde o technický sloupec nástroje - pro dotazy používejte platnost_od_ts. Vzniká jen u tabulek plněných snapshotem.',
    CONSTRAINT pk_stav_kontaktu_hist PRIMARY KEY (stav_kontaktu_hkey, platnost_od_ts) NOT ENFORCED
)
USING DELTA
COMMENT 'Historie SCD2 entity stav_kontaktu. Jeden řádek na verzi, platnou mezi platnost_od_ts a platnost_do_ts. Konformovaný číselník stavů kontaktu v kampani, tedy zpětné vazby, kterou může obchodník ke kontaktu zadat.'
CLUSTER BY (stav_kontaktu_hkey, platnost_od_ts)
TBLPROPERTIES (
    'delta.columnMapping.mode'   = 'name',
    'delta.enableChangeDataFeed' = 'true',
    'model.layer'                = 'silver',
    'model.table_kind'           = 'history'
);
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.stav_kontaktu_hist SET TAGS ('description_en' = 'SCD2 history of contact_state, one row per version valid between valid_from_timestamp and valid_to_timestamp. Conformed codelist of campaign contact states, that is the feedback an agent can enter on a contact.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.stav_kontaktu_hist ALTER COLUMN stav_kontaktu_hkey SET TAGS ('description_en' = 'Hash of the natural key (stav_kontaktu_id). Identifies the entity, is stable across versions and serves both as the reference target and as the dbt snapshot unique_key.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.stav_kontaktu_hist ALTER COLUMN stav_kontaktu_id SET TAGS ('description_en' = 'Identifier of the state.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.stav_kontaktu_hist ALTER COLUMN stav_kontaktu_nazev SET TAGS ('description_en' = 'Displayed name of the feedback.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.stav_kontaktu_hist ALTER COLUMN stav_kontaktu_popis SET TAGS ('description_en' = 'More detailed description.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.stav_kontaktu_hist ALTER COLUMN zpetna_vazba_kod SET TAGS ('description_en' = 'Text identifying the feedback.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.stav_kontaktu_hist ALTER COLUMN spolecnost_kod SET TAGS ('description_en' = 'Group company.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.stav_kontaktu_hist ALTER COLUMN neplatny_priznak SET TAGS ('description_en' = 'TRUE when the codelist entry is no longer valid. The KCL codelists have no validity interval, they use an obsolete flag.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.stav_kontaktu_hist ALTER COLUMN __zdrojovy_system SET TAGS ('description_en' = 'Source system the record was loaded from, taken from the __source_system metadata column of the bronze table.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.stav_kontaktu_hist ALTER COLUMN __zdrojova_tabulka_nazev SET TAGS ('description_en' = 'Fully qualified bronze table the record was loaded from. For conformed entities fedfrom several bronze tables it is the only value that tells the origin of a row apart.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.stav_kontaktu_hist ALTER COLUMN verze_id SET TAGS ('description_en' = 'Identifier of a single version, an md5 hash of the natural key and the change indicator. Filled by dbt_scd_id on snapshots and computed the same way by the load on incremental tables. It is not the entity identity.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.stav_kontaktu_hist ALTER COLUMN platnost_od_ts SET TAGS ('description_en' = 'Point in time from which this version was valid. Part of the history primary key.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.stav_kontaktu_hist ALTER COLUMN platnost_do_ts SET TAGS ('description_en' = 'Point in time until which this version was valid; the open version carries 9999-12-31.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.stav_kontaktu_hist ALTER COLUMN hash_zaznamu SET TAGS ('description_en' = 'The decision hash over all business columns of this version.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.stav_kontaktu_hist ALTER COLUMN __nacteno_ts SET TAGS ('description_en' = 'Timestamp of when the version was inserted into this silver table.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.stav_kontaktu_hist ALTER COLUMN __dbt_updated_at SET TAGS ('description_en' = 'An internal dbt working marker. It carries the same value as the valid-from column; the two can only diverge when a hard-deleted record is invalidated. Only snapshot tables have it.');
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.stav_kontaktu_hist ALTER COLUMN stav_kontaktu_hkey SET TAGS ('data_classification' = 'internal');

-- ==========================================================================
-- Foreign keys on the current-state tables only. A historical row references a
-- version of its parent that the current parent table no longer holds, so a
-- plain foreign key between history tables would be wrong; join those on the
-- key plus an overlap of the two validity periods instead.
-- ==========================================================================

ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.smlouva ADD CONSTRAINT fk_001_smlouva_smlouva FOREIGN KEY (nadrizena_smlouva_hkey) REFERENCES dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.smlouva (smlouva_hkey) NOT ENFORCED;
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.navrh ADD CONSTRAINT fk_002_navrh_smlouva FOREIGN KEY (smlouva_hkey) REFERENCES dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.smlouva (smlouva_hkey) NOT ENFORCED;
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.smlouva ADD CONSTRAINT fk_003_smlouva_stav_smlouvy FOREIGN KEY (stav_smlouvy_kod) REFERENCES dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.stav_smlouvy (stav_smlouvy_kod) NOT ENFORCED;
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.navrh ADD CONSTRAINT fk_004_navrh_stav_smlouvy FOREIGN KEY (stav_navrhu_kod) REFERENCES dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.stav_smlouvy (stav_smlouvy_kod) NOT ENFORCED;
-- rel_005 from produkt to smlouva resolves inside a nested array (instance_produktu.produkt_kod) and is enforced in the load, not by a constraint
-- rel_006 from produkt to navrh resolves inside a nested array (instance_produktu.produkt_kod) and is enforced in the load, not by a constraint
-- rel_007 from typ_role_partnera to smlouva resolves inside a nested array (partner_role.typ_role_kod) and is enforced in the load, not by a constraint
-- rel_008 from typ_role_partnera to navrh resolves inside a nested array (partner_role.typ_role_kod) and is enforced in the load, not by a constraint
-- rel_009 from mezinarodni_predvolba to smlouva resolves inside a nested array (partner_role.telefon.mezinarodni_predvolba) and is enforced in the load, not by a constraint
-- rel_010 from mezinarodni_predvolba to navrh resolves inside a nested array (partner_role.telefon.mezinarodni_predvolba) and is enforced in the load, not by a constraint
-- rel_011 from mapovani_id_partnera to smlouva resolves inside a nested array (partner_role.partner_id) and is enforced in the load, not by a constraint
-- rel_012 from mapovani_id_partnera to navrh resolves inside a nested array (partner_role.partner_id) and is enforced in the load, not by a constraint
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_k_klient.analyza_potreb_klienta ADD CONSTRAINT fk_013_analyza_potreb_kli_mapovani_id_partne FOREIGN KEY (partner_id) REFERENCES dbx_cz_gcz_dev_czlake_silver.ods_k_klient.mapovani_id_partnera (zdrojovy_partner_id) NOT ENFORCED;
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kontakt_v_kampani ADD CONSTRAINT fk_014_kontakt_v_kampani_mapovani_id_partne FOREIGN KEY (partner_id) REFERENCES dbx_cz_gcz_dev_czlake_silver.ods_k_klient.mapovani_id_partnera (zdrojovy_partner_id) NOT ENFORCED;
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.ukol ADD CONSTRAINT fk_015_ukol_mapovani_id_partne FOREIGN KEY (partner_id) REFERENCES dbx_cz_gcz_dev_czlake_silver.ods_k_klient.mapovani_id_partnera (zdrojovy_partner_id) NOT ENFORCED;
-- rel_016 from obchodnik to smlouva resolves inside a nested array (ucast_obchodnika.obchodnik_key) and is enforced in the load, not by a constraint
-- rel_017 from obchodnik to navrh resolves inside a nested array (ucast_obchodnika.obchodnik_key) and is enforced in the load, not by a constraint
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_k_klient.analyza_potreb_klienta ADD CONSTRAINT fk_018_analyza_potreb_kli_obchodnik FOREIGN KEY (obchodnik_hkey) REFERENCES dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.obchodnik (obchodnik_hkey) NOT ENFORCED;
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.obchodnik ADD CONSTRAINT fk_019_obchodnik_obchodnik FOREIGN KEY (nadrizeny_obchodnik_hkey) REFERENCES dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.obchodnik (obchodnik_hkey) NOT ENFORCED;
-- rel_020 from organizacni_jednotka to obchodnik resolves inside a nested array (prirazeni.organizacni_jednotka_key) and is enforced in the load, not by a constraint
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.organizacni_jednotka ADD CONSTRAINT fk_021_organizacni_jednot_organizacni_jednot FOREIGN KEY (nadrizena_jednotka_hkey) REFERENCES dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.organizacni_jednotka (organizacni_jednotka_hkey) NOT ENFORCED;
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kampan ADD CONSTRAINT fk_022_kampan_distribucni_kanal FOREIGN KEY (distribucni_kanal_hkey) REFERENCES dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.distribucni_kanal (distribucni_kanal_hkey) NOT ENFORCED;
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kampan ADD CONSTRAINT fk_023_kampan_obchodnik FOREIGN KEY (zakladatel_obchodnik_hkey) REFERENCES dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.obchodnik (obchodnik_hkey) NOT ENFORCED;
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kontakt_v_kampani ADD CONSTRAINT fk_024_kontakt_v_kampani_kampan FOREIGN KEY (kampan_hkey) REFERENCES dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kampan (kampan_hkey) NOT ENFORCED;
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kontakt_v_kampani ADD CONSTRAINT fk_025_kontakt_v_kampani_stav_kontaktu FOREIGN KEY (stav_kontaktu_hkey) REFERENCES dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.stav_kontaktu (stav_kontaktu_hkey) NOT ENFORCED;
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kontakt_v_kampani ADD CONSTRAINT fk_026_kontakt_v_kampani_obchodnik FOREIGN KEY (resitel_obchodnik_hkey) REFERENCES dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.obchodnik (obchodnik_hkey) NOT ENFORCED;
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kontakt_v_kampani ADD CONSTRAINT fk_027_kontakt_v_kampani_organizacni_jednot FOREIGN KEY (organizacni_jednotka_hkey) REFERENCES dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.organizacni_jednotka (organizacni_jednotka_hkey) NOT ENFORCED;
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kontakt_v_kampani ADD CONSTRAINT fk_028_kontakt_v_kampani_smlouva FOREIGN KEY (smlouva_hkey) REFERENCES dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.smlouva (smlouva_hkey) NOT ENFORCED;
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.ukol ADD CONSTRAINT fk_029_ukol_typ_ukolu FOREIGN KEY (typ_ukolu_hkey) REFERENCES dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.typ_ukolu (typ_ukolu_hkey) NOT ENFORCED;
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.ukol ADD CONSTRAINT fk_030_ukol_podtyp_ukolu FOREIGN KEY (podtyp_ukolu_hkey) REFERENCES dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.podtyp_ukolu (podtyp_ukolu_hkey) NOT ENFORCED;
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.ukol ADD CONSTRAINT fk_031_ukol_stav_ukolu FOREIGN KEY (stav_ukolu_hkey) REFERENCES dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.stav_ukolu (stav_ukolu_hkey) NOT ENFORCED;
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.ukol ADD CONSTRAINT fk_032_ukol_zpusob_dokonceni_u FOREIGN KEY (zpusob_dokonceni_hkey) REFERENCES dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.zpusob_dokonceni_ukolu (zpusob_dokonceni_ukolu_hkey) NOT ENFORCED;
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.podtyp_ukolu ADD CONSTRAINT fk_033_podtyp_ukolu_typ_ukolu FOREIGN KEY (typ_ukolu_hkey) REFERENCES dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.typ_ukolu (typ_ukolu_hkey) NOT ENFORCED;
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.zpusob_dokonceni_ukolu ADD CONSTRAINT fk_034_zpusob_dokonceni_u_typ_ukolu FOREIGN KEY (typ_ukolu_hkey) REFERENCES dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.typ_ukolu (typ_ukolu_hkey) NOT ENFORCED;
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.ukol ADD CONSTRAINT fk_035_ukol_obchodnik FOREIGN KEY (autor_obchodnik_hkey) REFERENCES dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.obchodnik (obchodnik_hkey) NOT ENFORCED;
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.ukol ADD CONSTRAINT fk_036_ukol_obchodnik FOREIGN KEY (resitel_obchodnik_hkey) REFERENCES dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.obchodnik (obchodnik_hkey) NOT ENFORCED;
ALTER TABLE dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.ukol ADD CONSTRAINT fk_037_ukol_smlouva FOREIGN KEY (smlouva_hkey) REFERENCES dbx_cz_gcz_dev_czlake_silver.ods_s_smlouva.smlouva (smlouva_hkey) NOT ENFORCED;
