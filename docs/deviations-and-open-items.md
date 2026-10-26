# Deviations from the documents & open items

Sources compared: Blueprint DBX v1.1 (BP), RFP draft v0.2, meeting summary "Databricks repo" (MTG),
Naming Conventions v0.4 (NC), files 11–18 (PowerDesigner models, keys/hashes/dates).
Each item says what the documents say, what this repo does, and who should decide.
Phase 1 scope: dbt bronze → silver only. Alerting, monitoring, Docker, CI/CD and job deployment are phase 2.

## A. Conflicts between the documents — decision needed

| # | Topic | Documents say | Implemented | Decide |
|---|---|---|---|---|
| 1 | Catalog names | Files 11/14/15: `dbx_cz_gcz_dev_czlake_<layer>`. BP 3.6.1 / NC sheet 4: `gcp_dwhbi_all_<layer>_<env>` | Physical-model names, defined once in `catalogs_by_target` (`dbt/dbt_project.yml`). Changing is config-only (+ DDL substitution) | Architects |
| 2 | Environment name | BP: `uat`. NC v0.4: `test` | `test` | Architects |
| 3 | Branch model | BP table 15: feature → main(uat) → tag(prod). MTG: "environment branches received strong support", final model pending | Phase 2 (CI/CD not in phase 1) | Miloš V. / Lukáš Ř. |
| 4 | Silver schema store prefix | BP/NC: `ads_<letter>_<domain>` (e.g. `ads_p_party`). Files 14/15: `ods_s_smlouva`, `ods_k_klient`, `ods_d_distribuce`, `ods_c_ciselnik` (BP text itself says ods = operational data store) | `ods_*` as in the DDL | Data modeller + NC owner |
| 5 | Surrogate / durable keys | BP table 12: `<table>_key` identity, `<table>_dkey`. File 14 Databricks_Options #5–7: not used, hash key instead. Load_Pattern step 15 still says "MERGE on the surrogate key" | Hash key only (file 14), MERGE on `hkey` | Architecture & Governance Board – BP deviation must be approved at the design gate (BP 4.2.3) |
| 6 | CI/CD platform | BP: Terraform on GitLab, ADF on Azure DevOps, data projects `.github/workflows`. MTG: Azure DevOps artifacts | Phase 2 (folder `.github/workflows` reserved) | Platform team |
| 7 | Silver streaming | BP 4.6.1: one Structured Streaming code base for batch + low-latency silver; RFP: "DLT templates for silver/gold" | dbt = batch only. Fine for weekly/monthly Sales Cockpit KPIs; a low-latency path would need DLT/streaming outside dbt | Product owner |
| 8 | Delete handling via dbt meta columns | File 14 dbt_Config maps `dbt_is_deleted → smazano_priznak` with `hard_deletes=new_record`, but the four entities with delete feeds are *incremental* models, not snapshots | Own MERGE writes a new version with `smazano_priznak=true` (Load_Pattern step 17). Snapshots use `hard_deletes: invalidate` | Data modeller (confirm) |
| 9 | Which entities carry `smazano_priznak` | File 14 Databricks_Options #10: "three entities"; dbt_Config: "four entities" (smlouva, navrh, ukol, kontakt_v_kampani) | ukol implemented; the rest follows the DDL | Data modeller |
| 10 | Snapshot `platnost_od_ts` | Silver DDL comment: snapshots carry the **run time**. File 18 sheet "kampan": "from DATE_MODIFIED" | Run time (no `updated_at`), as the DDL and file 18's own snapshot config | Data modeller |

## B. Errors found in the design — corrected (please confirm)

| # | Topic | Problem | Implemented |
|---|---|---|---|
| 11 | `verze_id = md5(hkey + hash_zaznamu)` (file 18) | Not unique: a record going A → B → A gets the same id twice | `verze_id = hash(hkey, platnost_od_ts)` (unique per history PK) |
| 12 | `md5(concat_ws("\|", ...))` (file 18 example) | `concat_ws` skips NULLs → `('a',null,'b')` and `('a','b',null)` collide; the composite example `smlouva_cislo \|\| zdrojova_aplikace_id` has no separator at all (`1`+`23` = `12`+`3`) | Explicit NULL token + separator in one macro. Hash values therefore differ from any hashes precomputed elsewhere |
| 13 | `kampan` snapshot with `invalidate_hard_deletes=true` on an **incremental** KCL source | If the snapshot reads only the delta, every campaign missing from the delta is closed | Snapshot input = latest row per key over all bronze |
| 14 | `invalidate_hard_deletes` | Deprecated in dbt 1.9 | `hard_deletes: invalidate` |
| 15 | `produkt.technicka_urokova_mira` ← `nep_predpis` (STRING) | Bronze has `tum DECIMAL(3,1)` = technická úroková míra, exactly the silver type | **`tum` used — confirm** |
| 16 | `adt_finishtype` key | Bronze PK `(id, tasktype_id)`, silver hkey `(id, company_id)` | As modelled; the staging `unique` test fails loudly if it collapses rows |
| 17 | `mapovani_id_partnera_hkey` | DDL comment "Náhradní primární klíč" contradicts "no surrogate keys" | `hash(zdrojovy_partner_id)` |
| 18 | Bronze README says payload is VARIANT | The bronze DDL has typed level-1 STRUCT columns (Load_Pattern step 2 agrees) | Staging reads the typed columns |
| 19 | Bronze schema tags | Dev DDL tags every schema `environment = 'prod'`; owner `grp-dbx-team-dwhbi` vs NC `gcp-dbx-team-<projekt>` | Not changed (bronze is not owned here); `meta.owner` uses `gcp-dbx-team-dwhbi` |

## C. Data facts needed from source owners

| # | Question | Impact | Where to change |
|---|---|---|---|
| 20 | Values of the KCL `INFO` flag for UKOL / INFORMACE / PRILEZITOST (adt_tasktype and sco_bdt_task) | `typ_zaznamu_kod`; placeholders 0/1/2 now, unknown → `NEZNAMY` + warning | `dbt/seeds/ref_typ_zaznamu.csv` |
| 21 | Is `__load_timestamp` constant within one KCL full-snapshot load? | Latest-batch selection | `meta.batch_column` in `models/sources/_kcl_sources.yml` |
| 22 | Are landing paths unique per delivery (`ALL_H_Produkt.csv` has no date)? | Latest-batch selection for KCC files | `meta.batch_column` in `_kcc_man_sources.yml` |
| 23 | Flag encodings in KCC (`kod_zivot`, `sjednavan`, …: A/N? ANO/NE?) | Booleans | var `flag_true_values` |
| 24 | Login normalisation (case / whitespace) of domain logins across KCL, HUGO, LISA, TIA, KDP, REDy | All `*_obchodnik_hkey` joins | var `login_normalization` |
| 25 | `sco_bdt_task.modification_date` is a DATE | Several changes on one day collapse into one version (last wins) | Accept, or use `date_inserted` as version start (staging) |
| 26 | REDy `last_modified_on` can be NULL | Version start falls back to audit `last_updated_at`, then `created_on` | staging `stg_redy__client_needs_analysis` |
| 27 | Party merges after load | Party ids are resolved at load time (Load_Pattern step 7); a later merge does not rewrite older versions of tasks/analyses | Accept, or add a periodic re-resolution job |

## D. Platform prerequisites (phase 1)

| # | Item | Owner |
|---|---|---|
| 28 | dbt-core / dbt-databricks line (1.10 assumed; ≥ 1.9 mandatory) - pin exact versions in `requirements.txt` | Martin D. (MTG action) |
| 32 | Schema `dbt_stg` (silver catalog: staging views, seeds, CDC watermark table) is not covered by NC | NC owner |
| 33 | Who applies the silver DDL per environment (object framework, BP 4.2.3) before the first dbt run | Platform |

## E. Not yet implemented (next sprint)

| Entity | Blocked by |
|---|---|
| smlouva, navrh | Nested `ARRAY<STRUCT>` assembly + sorting (Load_Pattern 10–11), routing via the Sales Cockpit mapping (step 4), `navrh_identifikator` (5), proposal → contract link (16), "not live in both" (check 12). The framework already supports them: staging builds the arrays with `array_sort(transform(...))`, `scd2_incremental` with `deletes=` handles the delete topics |
| obchodnik | Union of six KCL role tables; `nadrizeny_obchodnik_hkey` maps from different columns per role (superior / agency_id / region_id) — semantics to confirm |
| organizacni_jednotka | Derivation of `nadrizena_jednotka_hkey` from the channel–region–agency hierarchy |
| kontakt_v_kampani | `resitel_obchodnik_hkey` comes from four columns (solver_id, ad_manager, ad_seller, ad_ppz) — precedence rule needed |
