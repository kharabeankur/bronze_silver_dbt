# DDL (Blueprint 4.5.3 `ddl/` folder)

| Folder | Content | How it is applied |
|---|---|---|
| `bronze/` | `06_Bronze_DDL_databricks.sql` (file 11) | Reference only - bronze is created by the Databricks ingestion framework |
| `silver/` | `15_Silver_DDL_databricks.sql` (file 14) | Run once per environment **before** the first dbt run |

**Why run the silver DDL first?** It contains what dbt does not manage: `PRIMARY KEY / FOREIGN KEY
NOT ENFORCED`, Czech `COMMENT`s and `description_en` / `data_classification` tags. When the table
already exists, dbt snapshots and incremental models simply MERGE into it by column name, so all of
that is kept (`persist_docs` is switched off in `dbt_project.yml` for this reason).

**Other environments:** the file contains `dbx_cz_gcz_dev_czlake_*`. Replace the catalog name before
running it in test/prod - use the same names as `catalogs_by_target` in `dbt/dbt_project.yml`.
