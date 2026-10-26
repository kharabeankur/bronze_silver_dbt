# Phase 1 Guide — Bronze → Silver with dbt (current state)

Phase 1 is deliberately simple. **Every run rebuilds each silver table from bronze** and keeps one
row per business key: the latest state. There is no history (SCD2) and no change tracking (CDC)
yet. Those come in phase 2, and their folders are already reserved.

This guide explains **what** was built, **why**, and **how**. Your **pending actions** are at the end.

---

## The big picture

```
Databricks (already done)                 dbt (this repository, phase 1)
─────────────────────────                 ─────────────────────────────────────────────
Kafka / ETL / CSV ─► landing ─► BRONZE ──► STAGING view ──────────► SILVER table
                                (raw,       (pick latest row,         (one row per key,
                                 append-     rename, cast, keys)       rebuilt every run)
                                 only)
```

* **Bronze** keeps every load and every Kafka message (append-only). dbt only reads it.
* **Staging** (a view per silver table) does all the work:
  1. Pick the right bronze rows: the latest load, or the latest row per key.
  2. Translate columns per file 14, sheet *Bronze_Mapping*.
  3. Add the key and hash columns.
* **Silver** is the staging view saved as a Delta table (`select * from staging`). Its columns
  match the current-state tables in your silver DDL (file 15), checked column by column.

### Which bronze rows become the silver row?

| Bronze delivers… | Example | Staging takes… |
|---|---|---|
| a **complete image** every load | KCL codelists, KCC CSV files | all rows of the **newest load** |
| **deltas** (only changed rows per load) | KCL `bdt_campaign_wave`, `sco_bdt_task` | the **latest row per key** over all loads |
| **one row per Kafka message** | REDy, CCD | the **latest message per key** |

---

## Step 1 — Folder structure

**What:** a standard dbt project in `dbt/`, plus folders reserved for phase 2. Each reserved folder
holds only a README saying what will go there.

```
dbt/
  models/sources/     bronze tables dbt reads                      ← phase 1
  models/staging/     bronze → silver mapping (views)              ← phase 1
  models/silver/      silver tables per schema                     ← phase 1
  macros/framework/   catalog/schema naming, standard columns      ← phase 1
  macros/keys/        hash keys, flags                             ← phase 1
  macros/generic_tests/                                            ← phase 1
  seeds/              small mapping tables (CSV)                   ← phase 1
  snapshots/          SCD2 history                                 ← phase 2 (reserved)
  macros/scd2/        SCD2 for change-based sources                ← phase 2 (reserved)
  macros/cdc/         read only new bronze rows                    ← phase 2 (reserved)
  macros/observability/, models/meta/   logging + monitoring       ← phase 2 (reserved)
  models/gold/        datamarts                                    ← phase 2 (reserved)
.github/workflows/  config/  docker/  ops/  resources/             ← phase 2 (reserved)
```

**Why:**
* The meeting agreed dbt keeps its standard layout, with one copy of the code for all environments.
* Reserving the folders now means phase 2 adds files without reorganising anything.

---

## Step 2 — Environments and connection

**What:**
* `dbt/profiles.yml` says how to connect.
* `catalogs_by_target` in `dbt/dbt_project.yml` says which catalogs each environment uses.

**Why:**
* Only the catalog names differ between dev, test and prod, so they sit in one configuration block.
* No SQL file contains an environment name, and no file contains credentials.

**How:**
* Connection values come from environment variables (your `.env` file).
* You pick the environment with `--target`. The default is `local`.
  ```bash
  dbt build --target local     # your laptop: dev catalogs, personal token
  dbt build --target test      # test catalogs (service principal)
  ```
* Models are configured with a *layer* (`silver`), not a catalog name. The macro
  `generate_database_name` swaps in the catalog for the current target.
* Schemas are used exactly as written (`ods_c_ciselnik`). A name longer than 22 characters stops
  the build, because of the Blueprint 4.1.2 access-group limit.
* The session time zone is UTC, so timestamps and their hashes are consistent.

---

## Step 3 — Sources: what dbt reads from bronze

**What:** three YAML files in `models/sources/` declaring 32 bronze tables. Each table says how it
is loaded (`meta.load_type`) and which column identifies one load (`meta.batch_column`).

**Why:**
* dbt needs the bronze tables for lineage and to apply the right catalog per environment.
* Staging needs the load type to choose the right rows (table above).

**Safety test:** the full-image tables carry `latest_batch_complete`.
* If the newest load has less than 50 % of the rows of the previous one (setting
  `latest_batch_min_ratio`), the test fails.
* When it fails, `dbt build` does not rebuild the silver codelist.
* Without this guard, a half-delivered file would silently delete rows from silver.

---

## Step 4 — Keys and hash columns

**What:** macros in `macros/keys/hashing.sql`, used by every staging view.

| Column | Meaning | Macro |
|---|---|---|
| `<entity>_hkey` | identity of the record: a hash of its natural key | `hash_key([...])` |
| `<parent>_hkey` | reference to a parent, e.g. `kampan.distribucni_kanal_hkey` | `fk_hash_key([...])` |
| `hash_zaznamu` | fingerprint of all business columns | `record_hash([...])` |
| `platnost_od_ts` | since when this state is valid (source change time or load time) | set in staging |
| `__zdrojovy_system`, `__zdrojova_tabulka_nazev`, `__nacteno_ts` | where the row came from, when it was written | `silver_standard_columns` |

**Why:**
* These columns are in your silver DDL (file 18), so phase 1 must fill them.
* A foreign key is the same hash of the same value, so parent and child join **without lookups** and
  in any load order.
* `hash_zaznamu` has no job in phase 1. It is computed now exactly as phase 2 will need it, so that
  SCD2 can compare fingerprints immediately.

**How:**
* Each value is converted to text and NULL becomes a marker. The values are joined with `||` and
  hashed with md5.
* Technical columns (`__…`) are refused by `record_hash` when dbt compiles the project.

---

## Step 5 — Staging views (the mapping layer)

**What:** one view per silver table: `models/staging/<source>/stg_<source>__<table>.sql`.

**Why:** all the translation sits in one readable place:
* rename to the Czech silver names,
* cast types,
* turn `0/1` or `A/N` into booleans,
* build keys,
* resolve party IDs.

The silver models then stay one line each.

**How — example `stg_kcl__adt_campaign_channel.sql` → `distribucni_kanal`:**

```sql
with latest_batch as ( {{ select_latest_batch(src) }} ),        -- 1. newest full load only
projected as (
    select cast(id as int)              as kanal_id,             -- 2. Bronze_Mapping
           cast(channel as string)      as kanal_nazev,
           ...
           {{ to_flag('is_obsolete') }} as neplatny_priznak,     --    1/0 → true/false
           __load_timestamp             as platnost_od_ts,
           __source_system              as __zdrojovy_system
    from latest_batch )
select {{ silver_standard_columns(hkey='distribucni_kanal_hkey', natural_key=['kanal_id'],
                                  hash_columns=[...], source_relation=src) }}   -- 3. keys + hash
from projected as p
```

**Special cases:**

| View | What is special |
|---|---|
| `stg_kcl__bdt_campaign_wave` (kampan) | bronze holds deltas → latest row per campaign over all loads |
| `stg_kcl__sco_bdt_task` (ukol) | latest row per task; joins the delete table → `smazano_priznak = true` if the task was deleted after its last change (rows are never removed) |
| `stg_redy__client_needs_analysis` | latest Kafka message per analysis |
| `stg_ccd__party_id_mapping` | follows merge chains (A→B, B→C ⇒ A→C), so any party ID resolves in one step |
| `ukol`, `analyza_potreb_klienta` | `partner_id` replaced by the surviving ID from `mapovani_id_partnera` (Load_Pattern step 7) |
| `stav_smlouvy` | adds the Sales Cockpit name from the manual mapping table, valid as of today |

**Kept as configuration, not code:**
* **Flag values:** `flag_true_values` in `dbt_project.yml`.
* **INFO flag decoding:** `seeds/ref_typ_zaznamu.csv`.
* **Unknown codes:** become `NEZNAMY` instead of losing the row.

---

## Step 6 — Silver tables

**What:** 14 models, each one line, e.g. `models/silver/ods_c_ciselnik/distribucni_kanal.sql`:

```sql
select * from {{ ref('stg_kcl__adt_campaign_channel') }}
```

**Why:**
* The staging view already has the final shape.
* Materialising it as a table (`+materialized: table` in `dbt_project.yml`) gives consumers fast
  Delta tables in the right schemas.

**How:**
* dbt runs `create or replace table … as select …` on every run, which is a full rebuild.
* The rebuild reflects bronze exactly as it is now, including deletions in codelists.
* Liquid clustering on the hash key is set in each schema's YAML, matching the DDL's `CLUSTER BY`.

| Schema | Tables |
|---|---|
| `ods_c_ciselnik` | distribucni_kanal, stav_kontaktu, stav_ukolu, typ_ukolu, podtyp_ukolu, zpusob_dokonceni_ukolu, produkt, mezinarodni_predvolba, typ_role_partnera, stav_smlouvy |
| `ods_d_distribuce` | kampan, ukol |
| `ods_k_klient` | mapovani_id_partnera, analyza_potreb_klienta |

---

## Step 7 — Tests (run inside every `dbt build`)

**Why:** Databricks does not enforce primary or foreign keys, so dbt checks them.

| Check | Where | If it fails |
|---|---|---|
| hash key unique and not null | every staging view and every silver table | **stops** the silver table |
| `platnost_od_ts` filled | every staging view | stops |
| newest full load not truncated | full-image bronze tables | stops the codelist rebuild |
| party mapping resolves in one step | `mapovani_id_partnera` | stops |
| references to codelists exist | `podtyp_ukolu`, `zpusob_dokonceni_ukolu`, `kampan`, `ukol` | warning |
| INFO flag could be decoded | `typ_ukolu`, `ukol` | warning |

`dbt build` tests each staging view **before** building the silver table from it. A duplicate key
stops there and never reaches silver.

---

## Step 8 — First run

```bash
# one-time setup (repo root)
python3.11 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env              # fill in host, SQL warehouse http path, token
set -a; source .env; set +a

cd dbt
dbt deps                          # installs dbt_utils
dbt debug                         # must say "All checks passed!"
dbt build --selector silver_codelists   # start small
dbt build --selector silver_daily       # all 14 silver tables
dbt build --select +ukol                # one table + everything it needs
```

dbt works out the order from `ref()`:

```
seed → staging views → tests → silver tables → tests
(mapovani_id_partnera is built before ukol and analyza_potreb_klienta, which use it)
```

**Check the results in Databricks SQL:**

```sql
-- one row per key
select count(*), count(distinct distribucni_kanal_hkey)
from dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.distribucni_kanal;

-- deleted tasks are flagged, not removed
select smazano_priznak, count(*) from dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.ukol group by 1;

-- compare with bronze: number of distinct campaigns
select count(distinct id) from dbx_cz_gcz_dev_czlake_bronze.kcl.bdt_campaign_wave;
select count(*)           from dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kampan;
```

---

## Your pending actions

### Before the first run (blocking)

| # | Action | Where |
|---|---|---|
| 1 | Install Python 3.11, then `pip install -r requirements.txt` | laptop / Codespace |
| 2 | Create `.env` from `.env.example`: workspace host, SQL warehouse HTTP path, personal access token | repo root (never commit it) |
| 3 | Confirm the **catalog names**: physical model `dbx_cz_gcz_*` vs naming convention `gcp_dwhbi_all_*`; adjust `catalogs_by_target` | `dbt/dbt_project.yml` |
| 4 | Check that the bronze tables exist and are loaded in dev | Databricks |
| 5 | Grants for your user (later the service principal): `USE` + `SELECT` on bronze; `USE`, `CREATE SCHEMA`, `CREATE TABLE`, `MODIFY` on the silver catalog | Unity Catalog |
| 6 | Network: if dbt runs outside the company network (e.g. a GitHub Codespace), check that it can reach the workspace (`dbt debug`) | platform team |

You do **not** need to run the silver DDL in phase 1. dbt creates the tables itself.

### Before go-live (answers from data owners)

| # | Question | Where to change |
|---|---|---|
| 7 | Real values of the KCL `INFO` flag for UKOL / INFORMACE / PRILEZITOST (0/1/2 now are placeholders) | `dbt/seeds/ref_typ_zaznamu.csv` |
| 8 | Is `__load_timestamp` the same for all rows of one KCL load? | `meta.batch_column`, `models/sources/_kcl_sources.yml` |
| 9 | Is every KCC file delivered to a unique path? (`ALL_H_Produkt.csv` has no date) | `meta.batch_column`, `_kcc_man_sources.yml` |
| 10 | How KCC flags are coded (A/N, ANO/NE …) | `flag_true_values`, `dbt_project.yml` |
| 11 | Confirm `produkt.technicka_urokova_mira` comes from `tum` (not `nep_predpis`) | `stg_kcc__produkt.sql` |
| 12 | Confirm the dbt version (1.10 assumed, ≥ 1.9 needed) and pin it exactly | `requirements.txt` |
| 13 | Governance metadata: dbt-created tables don't carry the DDL's comments, tags and PK/FK yet. Decide whether to apply them now (run the DDL's `ALTER ... SET TAGS` statements after the first build) or in phase 2 | `ddl/README.md` |

### For phase 1b (remaining 5 entities)

| # | Decision needed | Entity |
|---|---|---|
| 14 | Contract/Proposal routing, nested product/party/agent arrays, proposal → contract link | smlouva, navrh |
| 15 | Which column is the superior for each of the six KCL role tables | obchodnik |
| 16 | How the parent unit is derived (channel → region → agency) | organizacni_jednotka |
| 17 | Precedence between `solver_id`, `ad_manager`, `ad_seller` and `ad_ppz` | kontakt_v_kampani |

All open design points are in [`deviations-and-open-items.md`](deviations-and-open-items.md).

---

## What changes in phase 2 (and why phase 1 is ready for it)

| Phase 2 feature | What it adds | What phase 1 already provides |
|---|---|---|
| SCD2 history | `<entity>_hist` tables via `snapshots/` and `macros/scd2/` | `<entity>_hkey` and `hash_zaznamu` in every staging view; the history reads the same views |
| CDC | `macros/cdc/`: read only new bronze rows instead of everything | `meta.load_type` on every source; staging already isolates "latest row" logic |
| Monitoring, alerting, logging | `models/meta/`, `macros/observability/`, `config/`, `ops/` | dbt tests already produce the quality signals |
| Deployment | `.github/workflows/`, `resources/`, `docker/` | one codebase, environment chosen by `--target` |
| Gold | `models/gold/` | silver tables with stable keys for joins |
