# Snapshots - phase 2 (SCD2 history)

Planned: `<schema>/_snapshots.yml` defining `<entity>_hist` for full-image sources (codelists,
organisational structure, kampan), with check strategy on `hash_zaznamu` and the silver column names
(`verze_id`, `platnost_od_ts`, `platnost_do_ts`, `__dbt_updated_at`) - file 14 sheet dbt_Config.
The staging views already produce everything a snapshot needs (`<entity>_hkey`, `hash_zaznamu`).
