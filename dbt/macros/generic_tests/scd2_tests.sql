{#-
  SCD2 integrity tests - file 14 Load_Pattern "Co musí plnění hlídat":
    check 2  exactly one open version per key      -> scd2_single_open_version
    check 4  contiguous periods, no gaps/overlaps  -> scd2_contiguous_versions
    check 3  current table equals open history     -> scd2_current_matches_history
-#}

{% test scd2_single_open_version(model, column_name) %}
select {{ column_name }}, count(*) as open_versions
from {{ model }}
where platnost_do_ts = {{ scd2_high_date() }}
group by {{ column_name }}
having count(*) > 1
{% endtest %}


{% test scd2_contiguous_versions(model, column_name) %}
with ordered as (
    select
        {{ column_name }},
        platnost_od_ts,
        platnost_do_ts,
        lead(platnost_od_ts) over (partition by {{ column_name }} order by platnost_od_ts) as next_od
    from {{ model }}
)
select *
from ordered
where platnost_do_ts is null                                        -- open marker must be the high date
   or platnost_do_ts <= platnost_od_ts                              -- empty / inverted period
   or (next_od is not null and platnost_do_ts <> next_od)           -- gap or overlap
-- A closed last version is legitimate: hard_deletes='invalidate' closes deleted keys.
{% endtest %}


{% test scd2_current_matches_history(model, column_name, history) %}
with cur as (
    select {{ column_name }} as k, hash_zaznamu, platnost_od_ts from {{ model }}
),
hist as (
    select {{ column_name }} as k, hash_zaznamu, platnost_od_ts
    from {{ history }}
    where platnost_do_ts = {{ scd2_high_date() }}
)
select coalesce(cur.k, hist.k) as k,
       cur.hash_zaznamu as current_hash, hist.hash_zaznamu as history_hash
from cur
full outer join hist on cur.k = hist.k
where cur.k is null or hist.k is null
   or cur.hash_zaznamu <> hist.hash_zaznamu
   or cur.platnost_od_ts <> hist.platnost_od_ts
{% endtest %}
