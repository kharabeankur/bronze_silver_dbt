# gcp-lakehouse-dbt — Phase 1: Bronze → Silver

dbt project that moves data from the **bronze** tables (loaded by Databricks from Kafka / ETL / files)
into the **silver** layer modelled in PowerDesigner (files 12–15, 18), with SCD2 history and CDC.

**New here? Read [`docs/PHASE1_GUIDE.md`](docs/PHASE1_GUIDE.md)** – what was built, why, how, and what you
need to do. Open decisions: [`docs/deviations-and-open-items.md`](docs/deviations-and-open-items.md).

## Folder structure

```
gcp-lakehouse-dbt/
├── dbt/                         ← PHASE 1: everything that runs lives here
│   ├── dbt_project.yml            project config + catalogs per environment (catalogs_by_target)
│   ├── profiles.yml               connection (values from environment variables)
│   ├── packages.yml               dbt_utils
│   ├── selectors.yml              silver_daily | silver_codelists | silver_cdc
│   ├── models/
│   │   ├── sources/               bronze tables dbt reads (32 tables)
│   │   ├── staging/               bronze → silver column mapping (views)
│   │   ├── silver/                silver tables: <entity> (current) and <entity>_hist (history)
│   │   ├── gold/                  (phase 2)
│   │   └── meta/                  (phase 2: monitoring views)
│   ├── snapshots/                 SCD2 history for codelists / campaign (YAML only)
│   ├── macros/                    reusable framework: keys, hashes, SCD2, CDC, tests
│   ├── seeds/                     small reference/mapping tables (CSV)
│   ├── tests/  analyses/          (for singular tests / ad-hoc SQL)
├── ddl/                          PowerDesigner DDL (run silver DDL before dbt)
├── docs/                         guide, deviations, how to add an entity
├── .github/workflows/            (phase 2: CI/CD)
├── config/                       (phase 2: alerting + per-environment config)
├── docker/                       (phase 2: pinned image)
├── ops/                          (phase 2: logging / alerting runner)
├── resources/                    (phase 2: Databricks job definitions)
├── requirements.txt              dbt-core + dbt-databricks
└── .env.example                  connection variables template
```

## Run it (5 commands)

```bash
python3.11 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env              # fill in host, http path, token
set -a; source .env; set +a
cd dbt && dbt deps && dbt debug && dbt build --selector silver_codelists
```
Then the full load: `dbt build --selector silver_daily`. Other environment: add `--target test`.

## Implemented in phase 1 (14 silver entities, 28 tables)

| Pattern | Entities |
|---|---|
| Snapshot SCD2 (full image sources) | distribucni_kanal, stav_kontaktu, stav_ukolu, typ_ukolu, podtyp_ukolu, zpusob_dokonceni_ukolu, produkt, mezinarodni_predvolba, typ_role_partnera, stav_smlouvy, kampan |
| CDC incremental SCD2 | ukol (with deletes), analyza_potreb_klienta, mapovani_id_partnera |
| Phase 1b (decisions pending) | smlouva, navrh, obchodnik, organizacni_jednotka, kontakt_v_kampani |
