{#- Bronze safety tests attached to sources (they run before dependent models in `dbt build`).
    Phase 2 adds monitoring tests here: invalid payload ratio, unresolved quarantine. -#}

{#-
  Full-snapshot completeness guard. Snapshots use hard_deletes='invalidate':
  a truncated latest load would close every missing key. Fail if the latest
  batch is smaller than min_ratio x the previous batch.
-#}
{% test latest_batch_complete(model, batch_column='__load_timestamp', min_ratio=none) %}
{%- set ratio = min_ratio if min_ratio is not none else var('latest_batch_min_ratio') -%}
with batches as (
    select {{ batch_column }} as batch_id, max(__load_timestamp) as loaded_at, count(*) as row_count
    from {{ model }}
    group by {{ batch_column }}
),
ranked as (
    select *, row_number() over (order by loaded_at desc) as rn from batches
)
select cur.batch_id, cur.row_count as latest_rows, prev.row_count as previous_rows
from ranked as cur
join ranked as prev on prev.rn = 2
where cur.rn = 1
  and cur.row_count < prev.row_count * {{ ratio }}
{% endtest %}


{#- Warns when a code could not be decoded and was replaced by the unknown member (var unknown_code). -#}
{% test accepted_or_unknown(model, column_name, unknown_value=none) %}
{%- set unknown = unknown_value or var('unknown_code') -%}
select {{ column_name }}, count(*) as rows_with_unknown
from {{ model }}
where {{ column_name }} = '{{ unknown }}'
group by {{ column_name }}
{% endtest %}
