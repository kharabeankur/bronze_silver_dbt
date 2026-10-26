# CI/CD - phase 2

Planned: `ci.yml` (on pull request: `dbt deps` + `dbt parse` + lint) and `cd.yml`
(merge to main -> deploy to test, release tag vX.Y.Z -> prod with approval), Blueprint 4.5.2 table 15.
Until then, run dbt manually (see docs/PHASE1_GUIDE.md).
