# DDL (Blueprint 4.5.3 `ddl/` folder)

| Folder | Content |
|---|---|
| `bronze/` | `06_Bronze_DDL_databricks.sql` (file 11) - reference; bronze is created by the Databricks ingestion framework |
| `silver/` | `15_Silver_DDL_databricks.sql` (file 14) - current tables **and** `_hist` tables |

## Phase 1

dbt creates the silver **current-state** tables itself (`create or replace table`), so the silver DDL
does **not** have to be run first. Their columns match the DDL exactly.

What dbt-created tables do not carry yet: Czech `COMMENT`s, `description_en` / `data_classification`
tags and `PRIMARY/FOREIGN KEY ... NOT ENFORCED`. Option for now: after a build, run the
`ALTER TABLE ... SET TAGS` statements of the current tables from the DDL file. Note that a full
rebuild (`create or replace`) may reset table-level metadata, so re-apply after rebuilds.

## Phase 2

With SCD2 the tables become long-lived (MERGE instead of rebuild). The DDL - including the `_hist`
tables - is then applied once per environment before dbt runs, and dbt merges into it.

The file contains `dbx_cz_gcz_dev_czlake_*`; replace the catalog for test/prod with the names in
`catalogs_by_target` (`dbt/dbt_project.yml`).
