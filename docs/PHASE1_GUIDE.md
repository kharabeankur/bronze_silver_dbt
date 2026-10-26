# Phase 1 Guide — Bronze → Silver with dbt

This guide explains, step by step, **what** was built, **why** it was built that way, and **how** it
works. At the end there is a checklist of **your pending actions**.

---

## The big picture

```
Databricks (already done)                 dbt (this repository)
─────────────────────────                 ──────────────────────────────────────────────────────
Kafka / ETL / CSV ─► landing ─► BRONZE ──► STAGING view ──► SILVER <entity>_hist ──► SILVER <entity>
                                (raw,        (rename, cast,     (every version,         (current state:
                                 append-     keys, hashes)       SCD2)                   1 row per key)
                                 only)
```

* **Bronze** is source-aligned and only ever grows (new loads are appended). dbt never writes to it.
* **Staging** is a view per source table. It translates bronze columns into silver columns exactly
  as described in file 14, sheet *Bronze_Mapping*.
* **Silver history (`_hist`)** keeps every version of every record (SCD2). It answers questions like
  "what did this look like on 1 March?".
* **Silver current** holds only the latest version. It is what most consumers query.

There are **two ways** to build the history. Which one is used depends on what the source delivers.

| Source delivers… | Example | dbt mechanism | Why |
|---|---|---|---|
| a **complete image** every load | KCL codelists, KCC CSV files | **dbt snapshot** | dbt compares the new image with the stored history itself |
| only **changes** (deltas, events, deletes) | Kafka topics, KCL tasks | **incremental model with our own MERGE** | we must merge changes, apply deletes and handle late or repeated messages |

This split is exactly what your file 14, sheet *dbt_Config*, prescribes for each entity.

---

## Step 1 — Folder structure

**What:** a standard dbt project inside `dbt/`, plus empty folders reserved for phase 2.

**Why:**
* The meeting agreed that "dbt requires its standard project layout", so dbt keeps its own structure.
* There must be no separate dev/test/prod copies of the code.
* The empty folders (`.github/workflows`, `docker`, `config`, `ops`, `resources`, `models/gold`,
  `models/meta`, `macros/observability`) each contain a README. It says what will go there, so
  phase 2 slots in without restructuring.

**How:** inside `dbt/models/` the folders follow the data flow.

```
sources/   → staging/   → silver/<schema>/        (+ snapshots/<schema>/ for snapshot entities)
```

Silver folders are named after the silver schemas from the DDL: `ods_c_ciselnik`,
`ods_d_distribuce`, `ods_k_klient` and, for phase 1b, `ods_s_smlouva`.

---

## Step 2 — Environments and connection

**What:** `dbt/profiles.yml` (how to connect) and `catalogs_by_target` in `dbt/dbt_project.yml`
(which catalogs to use).

**Why:**
* The same code must run in dev, test and prod, and only the catalog names differ.
* Putting those names in one configuration block means no SQL file contains an environment name.
* Credentials are never stored in files.

**How:**
* `profiles.yml` reads host, HTTP path and token from environment variables. You fill them into `.env`.
* You choose the environment with `--target`. Without it, `local` is used.
  ```bash
  dbt build --target local     # your laptop, dev catalogs, personal token
  dbt build --target test      # test catalogs (service principal)
  ```
* Every model is configured with a *layer* (`bronze` / `silver` / `gold`), not a catalog name.
  The macro `generate_database_name` looks the layer up in `catalogs_by_target[<target>]`.
* Schemas are used exactly as written (`ods_c_ciselnik`, not dbt's default `dbt_stg_ods_c_ciselnik`).
  This happens in `generate_schema_name`.
  * A schema longer than 22 characters stops the build, because of the Blueprint 4.1.2 access-group limit.
* The session time zone is pinned to UTC. Without that, timestamps compared with `9999-12-31` could
  silently shift by hours. File 18 warns about exactly this.

---

## Step 3 — Sources (what dbt reads from bronze)

**What:** three YAML files in `models/sources/` that declare 32 bronze tables.

**Why:**
* dbt needs to know the bronze tables to build lineage and to apply the right catalog per environment.
* Each table also says **how it is loaded**, because staging must treat each load type differently.

| `meta.load_type` | Meaning | How staging reads it |
|---|---|---|
| `etl_full_snapshot` / `file_full_snapshot` | every load is a complete image | only the **latest load** (`select_latest_batch`) |
| `etl_incremental` | every load is a delta | changes (CDC) or the latest row per key |
| `kafka_cdc` | one row per message | changes since the last run (CDC) |

**Safety test:** full-snapshot tables carry the test `latest_batch_complete`.
* If the newest load has less than 50 % of the rows of the previous one (setting
  `latest_batch_min_ratio`), the test fails.
* When it fails, `dbt build` skips the dependent snapshot.
* Without this guard, a half-loaded file would make every missing codelist row look "deleted".

---

## Step 4 — Keys and hashes

**What:** the macros in `macros/keys/hashing.sql`.

**Why:** file 18 defines the identity of each record and of each of its versions through hashes.
All hashes must be produced the same way, otherwise joins between tables break.

| Column | What it is | Built by |
|---|---|---|
| `<entity>_hkey` | identity of the entity: a hash of the natural key, the same in every version | `hash_key([...])` |
| `<parent>_hkey` on a child | reference to the parent: the same hash of the parent's natural key | `fk_hash_key([...])` (NULL when there is no parent) |
| `hash_zaznamu` | fingerprint of all business columns; a different fingerprint means a new version | `record_hash([...])` |
| `verze_id` | identity of one version | snapshot: dbt; CDC: `hash(hkey, platnost_od_ts)` |

**How:** each value is converted to text and NULL is replaced by a marker. Then the values are
joined with `||` and hashed with md5.

* A foreign key needs no lookup. `kampan.distribucni_kanal_hkey = hash(channel_id)` matches
  `distribucni_kanal.distribucni_kanal_hkey = hash(kanal_id)` because both use the same macro on
  the same integer type. So load order between parent and child does not matter.
* Technical columns (`__...`) are rejected by `record_hash` when dbt compiles the project. Otherwise
  every run would create a new version, which is Load_Pattern check 9.
* Two deliberate improvements over the documents:
  * NULL-safe hashing.
  * A unique `verze_id`.
  * See the deviations document, items 11 and 12.

---

## Step 5 — Staging: the bronze → silver mapping

**What:** one view per source in `models/staging/<source>/stg_<source>__<table>.sql`.

**Why:**
* All "translation" happens in one visible place: renaming to Czech silver names, casting types,
  converting 0/1 or A/N flags to booleans, computing keys and hashes, and resolving party IDs.
* The snapshots and the history models then contain no business logic, so they stay generic.

**How — example `stg_kcl__adt_campaign_channel.sql` (→ `distribucni_kanal`):**

```sql
with latest_batch as ( {{ select_latest_batch(src) }} ),      -- only the newest full load
projected as (
    select cast(id as int)            as kanal_id,            -- Bronze_Mapping: id → kanal_id
           cast(channel as string)    as kanal_nazev,
           ...
           {{ to_flag('is_obsolete') }} as neplatny_priznak,  -- 1/0 → true/false
           __source_system            as __zdrojovy_system
    from latest_batch )
select {{ snapshot_staging_columns(hkey='distribucni_kanal_hkey', natural_key=['kanal_id'],
                                   hash_columns=[...], source_relation=src) }}
from projected as p
```

`snapshot_staging_columns` adds four columns:
* `distribucni_kanal_hkey`
* `__zdrojova_tabulka_nazev` (`kcl.adt_campaign_channel`)
* `hash_zaznamu`
* `__nacteno_ts`

Some details live in **configuration** rather than code:
* **Flag values:** `flag_true_values` in `dbt_project.yml`.
* **INFO flag decoding:** `seeds/ref_typ_zaznamu.csv`.
* **Unknown codes:** become `NEZNAMY` (`unknown_code`) instead of losing the row.

---

## Step 6 — SCD2 pattern A: snapshots (11 entities)

**What:**
* `snapshots/ods_c_ciselnik/_snapshots.yml` (10 codelists).
* `snapshots/ods_d_distribuce/_snapshots.yml` (`kampan`).
* These files contain **configuration only**.

**Why:**
* For complete-image sources, a dbt snapshot does SCD2 out of the box: it closes the old version,
  inserts the new one and invalidates keys that disappeared.
* File 14 *dbt_Config* asks for exactly this.

**How:** the common rules are set once in `dbt_project.yml` and apply to every snapshot.

| Setting | Value | Effect |
|---|---|---|
| `strategy: check`, `check_cols: [hash_zaznamu]` | new version only when the fingerprint changes | unchanged rows are not touched |
| `snapshot_meta_column_names` | `dbt_valid_from → platnost_od_ts`, `dbt_valid_to → platnost_do_ts`, `dbt_scd_id → verze_id`, `dbt_updated_at → __dbt_updated_at` | silver column names from the DDL |
| `dbt_valid_to_current` | `9999-12-31` | the open version has a high date, not NULL |
| `hard_deletes: invalidate` | a key missing from the latest image is closed | deletions are kept as history |

Each snapshot entry then only names its input and key:

```yaml
- name: distribucni_kanal_hist
  relation: ref('stg_kcl__adt_campaign_channel')
  config: {schema: ods_c_ciselnik, unique_key: distribucni_kanal_hkey}
```

**`kampan` is special.** KCL delivers campaigns as deltas. If the snapshot saw only the delta, every
campaign missing from it would be closed. Its staging view therefore gives the latest row per
campaign over the whole bronze history (deviations item 13).

⚠️ The column names of a snapshot are fixed by its first run. Apply the silver DDL first (Step 10).

---

## Step 7 — SCD2 pattern B: CDC incremental (3 entities)

**What:**
* `ukol_hist` (KCL tasks, plus the delete feed).
* `analyza_potreb_klienta_hist` (REDy, Kafka).
* `mapovani_id_partnera_hist` (CCD party merges).

All three are built by one generic macro, `macros/scd2/scd2_incremental.sql`.

**Why:**
* These sources send *changes*: new messages, repeated messages, messages arriving late, and deletes
  in a separate table.
* A dbt snapshot cannot handle that, so file 14 asks for an incremental model with our own MERGE.

**How:** the model file is only a call to the framework.

```sql
{{ scd2_incremental(staging=ref('stg_kcl__sco_bdt_task'),
                    hkey='ukol_hkey',
                    deletes=ref('stg_kcl__sco_bdt_task_delete'),
                    hash_exclude=['smlouva_hkey']) }}
```

What the macro does on every run, in plain words (Load_Pattern step numbers in brackets):

1. **Read only new bronze rows.** These are rows with `__load_timestamp` between the last processed
   point and the start of this run [1]. The "last processed point" (the *watermark*) is stored in
   the small table `dbt_stg.cdc_watermark`. It is created automatically on the first run.
2. **Add deletes** from the delete feed as special "delete" rows [17].
3. **Fetch the current open version** of every affected record from the history table [9].
4. **Drop stale changes:** anything older than the open version is a replay or a late message [18].
5. **Keep one row per record per timestamp:** delete beats change, change beats stored, and the
   newest message wins [18].
6. **Give delete rows the last known values** and set `smazano_priznak = true`. Rows are never
   physically removed [17].
7. **Compute `hash_zaznamu` and drop "changes" that change nothing** [12].
8. **Set validity:** each version ends exactly where the next begins; the last one ends at
   `9999-12-31` [13, 14].
9. **MERGE** new versions and closed old versions into `<entity>_hist`.
10. **Save the new watermark**, but only after the MERGE succeeded (post-hook `set_cdc_watermark`).

**What makes it safe:**
* **A failed run is harmless.** The watermark does not move, the next run re-reads the same rows, and
  step 7 makes sure nothing is written twice.
* **A small overlap is re-read on purpose** (60 minutes, `cdc_watermark_overlap_minutes`). It covers
  clock differences and late commits.
* **The history cannot be dropped by accident.** History models have `full_refresh: false`, so
  `dbt build --full-refresh` re-reads all of bronze and merges it again instead of dropping the table.

**`mapovani_id_partnera` works slightly differently** (`batch_mode='full'`):
* One CCD merge event can change the final target of many older IDs. For example, A→B followed by
  B→C means both A and B must now point to C.
* So its staging view always produces the complete, chain-resolved mapping, and only real changes
  are written.
* Party IDs in `ukol` and `analyza_potreb_klienta` are translated through this table before hashing
  (Load_Pattern step 7).

---

## Step 8 — Current-state tables

**What:** one model per entity, e.g. `models/silver/ods_c_ciselnik/distribucni_kanal.sql`.

**Why:**
* Most consumers need "the latest state".
* File 18 defines it as "the open versions of history", so it is never built separately from bronze.
* It is always derived from `_hist`.

**How:**
* **Snapshot entities:** `current_from_snapshot()` rewrites the whole small table on every run.
* **CDC entities:** `current_from_cdc_history()` merges only versions written since the last run,
  keyed on `<entity>_hkey`.

---

## Step 9 — Tests (part of every `dbt build`)

**Why:** Databricks does not enforce primary or foreign keys. File 14 lists what "the load must
guarantee itself", and each item became a test.

| Guarantee | Test | If it fails |
|---|---|---|
| keys unique | `unique` on staging hkeys and on current tables; `(hkey, platnost_od_ts)` unique on history | **stops** dependent models |
| exactly one open version per key | `scd2_single_open_version` | stops |
| no gaps or overlaps in validity | `scd2_contiguous_versions` | stops |
| current = open history | `scd2_current_matches_history` | stops |
| party mapping resolved in one step | `party_mapping_fully_resolved` | stops |
| references to codelists exist | `relationships` | warning only |
| codes could be decoded | `accepted_or_unknown` | warning only |

`dbt build` runs each test straight after the model it checks. So a broken staging key never
reaches the silver tables.

---

## Step 10 — First run

```bash
# one-time
python3.11 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env            # fill in DBT_DATABRICKS_HOST, ..._HTTP_PATH, ..._TOKEN
set -a; source .env; set +a
cd dbt
dbt deps                        # installs dbt_utils
dbt debug                       # must end with "All checks passed!"

# build
dbt build --selector silver_codelists   # start small: codelists only
dbt build --selector silver_daily       # everything
dbt build --select +ukol                # one entity incl. everything it depends on
```

**Order** (dbt works it out from `ref()`):

```
seed → staging views → [tests] → snapshots / history → [tests] → current tables → [tests]
                      mapovani_id_partnera is built before ukol and analyza (they use it)
```

**Check the results in Databricks SQL:**

```sql
-- every codelist row has exactly one open version
select count(*), count(distinct distribucni_kanal_hkey)
from dbx_cz_gcz_dev_czlake_silver.ods_c_ciselnik.distribucni_kanal_hist
where platnost_do_ts = timestamp'9999-12-31';

-- history of one task
select ukol_id, smazano_priznak, platnost_od_ts, platnost_do_ts, hash_zaznamu
from dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.ukol_hist
where ukol_id = <id> order by platnost_od_ts;

-- how far each CDC model has processed bronze
select * from dbx_cz_gcz_dev_czlake_silver.dbt_stg.cdc_watermark;

-- state as of a date (file 18 pattern)
select * from dbx_cz_gcz_dev_czlake_silver.ods_d_distribuce.kampan_hist
where platnost_od_ts <= timestamp'2026-10-01' and timestamp'2026-10-01' < platnost_do_ts;
```

**Run it twice.** The second run of `silver_daily` must write no new history versions when bronze
hasn't changed. That run proves the hashing and the idempotence.

---

## Your pending actions

### Before the first run (blocking)

| # | Action | Where |
|---|---|---|
| 1 | Install Python 3.11 and `pip install -r requirements.txt` | laptop |
| 2 | Create `.env` from `.env.example`: workspace host, SQL warehouse HTTP path, personal access token | repo root |
| 3 | Confirm the **catalog names**: physical model `dbx_cz_gcz_*` vs naming convention `gcp_dwhbi_all_*`; adjust `catalogs_by_target` if needed | `dbt/dbt_project.yml` |
| 4 | Make sure the bronze tables exist and are loaded in dev | Databricks |
| 5 | Run the **silver DDL** (`ddl/silver/15_Silver_DDL_databricks.sql`) in dev, then the test/prod equivalents with their catalog names | Databricks SQL |
| 6 | Your identity (laptop) or the service principal (scheduled runs) needs: `USE`+`SELECT` on bronze; `USE`, `CREATE`, `MODIFY` on silver incl. schema `dbt_stg` | Unity Catalog grants |

### Before go-live (data answers needed)

| # | Question | Where to change |
|---|---|---|
| 7 | Real values of the KCL `INFO` flag for UKOL / INFORMACE / PRILEZITOST (the 0/1/2 now are placeholders) | `dbt/seeds/ref_typ_zaznamu.csv` |
| 8 | Is `__load_timestamp` the same for all rows of one KCL load? | `meta.batch_column` in `models/sources/_kcl_sources.yml` |
| 9 | Is every KCC file delivered to a unique path? (`ALL_H_Produkt.csv` has no date) | `meta.batch_column` in `_kcc_man_sources.yml` |
| 10 | How KCC flags are coded (A/N, ANO/NE …) | `flag_true_values` in `dbt_project.yml` |
| 11 | Confirm `produkt.technicka_urokova_mira` comes from `tum` (not `nep_predpis`) | `models/staging/kcc/stg_kcc__produkt.sql` |
| 12 | Confirm the dbt version line (1.10 assumed, ≥ 1.9 required) and pin exact versions | `requirements.txt` |
| 13 | Decide the other open items, especially #1–5 and #10–17 | `docs/deviations-and-open-items.md` |

### For phase 1b (the remaining 5 entities)

| # | Decision | Entity |
|---|---|---|
| 14 | Rules for nested arrays, Contract/Proposal routing, proposal → contract link | smlouva, navrh |
| 15 | Which column is the superior for each of the six KCL role tables | obchodnik |
| 16 | How the parent unit is derived (channel → region → agency) | organizacni_jednotka |
| 17 | Precedence between `solver_id`, `ad_manager`, `ad_seller` and `ad_ppz` | kontakt_v_kampani |

---

## What comes next (folders already reserved)

| Phase | Item | Folder |
|---|---|---|
| 1b | smlouva, navrh, obchodnik, organizacni_jednotka, kontakt_v_kampani | `models/silver/ods_s_smlouva`, `ods_d_distribuce` |
| 2 | Scheduling as a Databricks job, Asset Bundle deployment | `resources/`, `databricks.yml` |
| 2 | CI/CD (parse + tests on PR, promotion dev → test → prod) | `.github/workflows/` |
| 2 | Logging, monitoring views, alerting | `macros/observability/`, `models/meta/`, `config/`, `ops/` |
| 2 | Pinned Docker image for CI and local runs | `docker/` |
| 2 | Gold datamarts | `models/gold/` |

Adding another entity follows a fixed recipe; see [`adding-an-entity.md`](adding-an-entity.md).
