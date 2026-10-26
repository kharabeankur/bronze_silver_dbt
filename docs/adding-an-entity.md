# Adding a silver entity

Decide the pattern from file 14 sheet `dbt_Config`:

* **snapshot** — the source delivers a complete image (codelists, organisational structure)
* **CDC incremental** — the source delivers changes (Kafka topics, KCL incremental tables, delete feeds)

## Snapshot entity (example: a new KCL codelist `adt_xyz` → `ods_c_ciselnik.xyz`)

1. **Source** — add the table to `models/sources/_kcl_sources.yml` with
   `meta: {load_type: etl_full_snapshot}` and `data_tests: *kcl_full_snapshot_tests`.
2. **Staging** — `models/staging/kcl/stg_kcl__adt_xyz.sql`, copy an existing codelist:
   ```sql
   {%- set src = source('kcl', 'adt_xyz') -%}
   with latest_batch as ( {{ select_latest_batch(src) }} ),
   projected as (
       select cast(id as int) as xyz_id, ..., __source_system as __zdrojovy_system
       from latest_batch
   )
   select {{ snapshot_staging_columns(hkey='xyz_hkey', natural_key=['xyz_id'],
                                      hash_columns=[...business columns...], source_relation=src) }}
   from projected as p
   ```
   Column names, types and order follow the silver DDL; mappings follow Bronze_Mapping.
   FKs: `{{ fk_hash_key(['cast(parent_id as int)']) }}` — cast exactly like the parent's natural key.
3. **Staging tests** — add `unique` + `not_null` on `xyz_hkey` in `models/staging/_staging.yml`.
4. **Snapshot** — add an entry to `snapshots/ods_c_ciselnik/_snapshots.yml` (name `xyz_hist`,
   `relation: ref('stg_kcl__adt_xyz')`, `unique_key: xyz_hkey`, SCD2 tests).
5. **Current table** — `models/silver/ods_c_ciselnik/xyz.sql`:
   `{{ current_from_snapshot(ref('xyz_hist')) }}` + an entry in `_ods_c_ciselnik.yml`.
6. **DDL** — the table pair must exist in `ddl/silver` (PowerDesigner) and be applied per environment.

## CDC entity (example: Kafka topic → `ods_x_abc.abc`)

1. **Source** with `meta: {load_type: kafka_cdc}` and the `invalid_message_ratio` test.
2. **Staging view** honouring the contract of `scd2_incremental` (see the macro header):
   `abc_hkey`, payload columns, `platnost_od_ts` (source change time), `_stg_load_ts`
   (`__load_timestamp`), `_stg_seq` (`__kafka_offset`). Apply `message_policy_predicate('<source>')`,
   resolve party ids through `ref('mapovani_id_partnera')`. Nested arrays must be sorted:
   `array_sort(transform(...), (l, r) -> ...)` (Load_Pattern step 11). Diagnostic `hash_<area>`
   columns may be added — they never decide a version.
3. **Delete feed** (optional) — a second staging view with `abc_hkey, platnost_od_ts, __zdrojovy_system,
   __zdrojova_tabulka_nazev, _stg_load_ts, _stg_seq`.
4. **History model** `abc_hist.sql` — copy `ukol_hist.sql`, change refs, hkey and `hash_exclude`.
5. **Current model** `abc.sql` — copy `ukol.sql`.
6. **YAML** — copy the `ukol_hist` / `ukol` blocks of `_ods_d_distribuce.yml` (SCD2 tests, FKs).
7. If the new schema folder is new, add it under `models.gcp_lakehouse.silver` in `dbt_project.yml`
   (schema ≤ 22 characters — enforced at compile time).

## Checklist before the pull request

- [ ] `dbt build --select +abc` passes in dev (from the dbt/ folder)
- [ ] every column of the silver DDL is produced, names and types match
- [ ] `hash_columns` / payload reviewed: no technical columns, derived late-filled FKs in `hash_exclude`
- [ ] FK hashes use the same casts as the parent natural key
- [ ] open decisions added to `docs/deviations-and-open-items.md`
