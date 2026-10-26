# Adding a silver table (phase 1)

Example: KCL codelist `adt_xyz` → `ods_c_ciselnik.xyz`.

1. **Source** – add the bronze table to `models/sources/_kcl_sources.yml`.
   Full image: `{name: adt_xyz, meta: {load_type: etl_full_snapshot}, data_tests: *kcl_full_snapshot_tests}`;
   delta: `meta: {load_type: etl_incremental}`.

2. **Staging view** – `models/staging/kcl/stg_kcl__adt_xyz.sql` (copy a similar one):
   ```sql
   {%- set src = source('kcl', 'adt_xyz') -%}
   with latest_batch as ( {{ select_latest_batch(src) }} ),   -- delta source: qualify row_number() per key instead
   projected as (
       select cast(id as int)          as xyz_id,
              ...                                             -- names/types from the silver DDL, mapping from Bronze_Mapping
              __load_timestamp         as platnost_od_ts,
              __source_system          as __zdrojovy_system
       from latest_batch
   )
   select {{ silver_standard_columns(hkey='xyz_hkey', natural_key=['xyz_id'],
                                     hash_columns=[ ...all business columns... ], source_relation=src) }}
   from projected as p
   ```
   References to parents: `{{ fk_hash_key(['cast(parent_id as int)']) }}` – cast exactly like the
   parent's natural key, otherwise the hashes will not match.

3. **Staging test** – in `models/staging/_staging.yml`: `unique` + `not_null` on `xyz_hkey`,
   `not_null` on `platnost_od_ts`.

4. **Silver model** – `models/silver/ods_c_ciselnik/xyz.sql`:
   ```sql
   select * from {{ ref('stg_kcl__adt_xyz') }}
   ```
   and an entry in `_ods_c_ciselnik.yml` (`liquid_clustered_by`, key tests, `relationships` to parents).

5. **New schema?** add it under `models.gcp_lakehouse.silver` in `dbt_project.yml`
   (max 22 characters – checked automatically).

## Checklist
- [ ] `dbt build --select +xyz` passes in dev (run from the `dbt/` folder)
- [ ] every column of the current table in the silver DDL is produced, same names and types
- [ ] `hash_columns` contains only business columns (no `__...` columns)
- [ ] FK hashes use the same casts as the parent's natural key
