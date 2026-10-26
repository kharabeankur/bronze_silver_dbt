{#-
  ===========================================================================
  scd2_incremental - CDC history (<entity>_hist) for incremental entities.

  Implements file 14 Load_Pattern for the entities whose dbt_Config row says
  "incremental with its own MERGE": steps 1 (watermark), 9 (new vs existing),
  12 (record hash, skip unchanged), 13 (close previous version), 14 (insert new
  version), 17 (deletes -> new version with smazano_priznak, never physical),
  18 (idempotence, dedup, late arrivals).

  Contract of the staging relation (one view per entity, see models/staging):
    <hkey>               hash of the natural key
    platnost_od_ts       source change timestamp (the version start)
    _stg_load_ts         bronze __load_timestamp (CDC window column)
    _stg_seq             ordering tie-breaker (kafka offset / load ts)
    every other column   business / technical payload, copied as-is.
                         hash_* columns are diagnostic and never decide a version.
  Contract of the optional delete relation:
    <hkey>, platnost_od_ts, _stg_load_ts, _stg_seq, plus the columns listed in
    delete_passthrough_columns (default: __zdrojovy_system, __zdrojova_tabulka_nazev).

  Parameters
    staging            ref() of the staging view
    hkey               name of the entity hash key column
    batch_mode         'watermark' (read only the CDC window) | 'full' (staging
                       is a complete current image, e.g. resolved party mapping)
    deletes            ref() of the delete-feed staging view, or none
    hash_exclude       business columns that must not create versions
                       (derived references filled later, Load_Pattern step 16)

  Output columns: <hkey>, <payload...>, [smazano_priznak], verze_id,
                  platnost_od_ts, platnost_do_ts, hash_zaznamu, __nacteno_ts
  Model config required: materialized='incremental', incremental_strategy='merge',
                         unique_key=[<hkey>, 'platnost_od_ts']
  ===========================================================================
-#}
{% macro scd2_incremental(staging, hkey, batch_mode='watermark', deletes=none, hash_exclude=[],
                          delete_passthrough_columns=['__zdrojovy_system', '__zdrojova_tabulka_nazev']) %}

    {%- if batch_mode not in ['watermark', 'full'] -%}
        {{ exceptions.raise_compiler_error("scd2_incremental: batch_mode must be 'watermark' or 'full'") }}
    {%- endif -%}

    {#- Parse time: refs are already captured by the caller; emit a stub. -#}
    {%- if not execute -%}
        {{ return('select 1 as _parse_stub') }}
    {%- endif -%}

    {%- set vf = 'platnost_od_ts' -%}
    {%- set high = scd2_high_date() -%}
    {%- set track_deletes = deletes is not none -%}
    {%- set reserved = [hkey, vf, '_stg_load_ts', '_stg_seq', 'smazano_priznak',
                        'verze_id', 'platnost_do_ts', 'hash_zaznamu', '__nacteno_ts'] -%}

    {#- ---- column contract ------------------------------------------------ -#}
    {%- set stg_cols = adapter.get_columns_in_relation(staging) -%}
    {%- set names = stg_cols | map(attribute='name') | map('lower') | list -%}
    {%- for required in [hkey, vf, '_stg_seq'] + (['_stg_load_ts'] if batch_mode == 'watermark' else []) -%}
        {%- if required not in names -%}
            {{ exceptions.raise_compiler_error("scd2_incremental: staging " ~ staging ~ " lacks column '" ~ required ~ "'") }}
        {%- endif -%}
    {%- endfor -%}

    {%- set payload = [] -%}
    {%- set seq_type = [] -%}
    {%- for c in stg_cols -%}
        {%- if c.name | lower == '_stg_seq' -%}{%- do seq_type.append(c.data_type) -%}{%- endif -%}
        {%- if c.name | lower not in reserved -%}{%- do payload.append(c) -%}{%- endif -%}
    {%- endfor -%}
    {%- set seq_type = seq_type[0] -%}

    {%- set hash_items = [] -%}
    {%- for c in payload -%}
        {%- set n = c.name | lower -%}
        {%- if not n.startswith('__') and not n.startswith('hash_') and n not in hash_exclude -%}
            {%- do hash_items.append({'expr': c.name, 'data_type': c.data_type}) -%}
        {%- endif -%}
    {%- endfor -%}
    {%- if track_deletes -%}{%- do hash_items.append({'expr': 'smazano_priznak', 'data_type': 'boolean'}) -%}{%- endif -%}

    {#- columns already present on the target (schema evolution safety) -#}
    {%- set target_names = [] -%}
    {%- if is_incremental() -%}
        {%- for c in adapter.get_columns_in_relation(this) -%}{%- do target_names.append(c.name | lower) -%}{%- endfor -%}
    {%- endif -%}

    {%- if batch_mode == 'watermark' -%}
        {%- set window = cdc_window_predicate() -%}
    {%- endif -%}

with

batch as (
    select
        {{ hkey }},
        {{ vf }},
        {%- for c in payload %}
        {{ c.name }},
        {%- endfor %}
        {%- if track_deletes %}
        false                               as smazano_priznak,
        {%- endif %}
        false                               as _is_delete_marker,
        1                                   as _prio,
        _stg_seq,
        cast(null as timestamp)             as _baseline_loaded_ts,
        cast(null as string)                as _stored_hash
    from {{ staging }}
    {%- if batch_mode == 'watermark' %}
    where {{ window }}
    {%- endif %}
),

{%- if track_deletes %}

delete_markers as (
    -- Load_Pattern step 17: a delete becomes a new version, rows are never removed.
    select
        d.{{ hkey }},
        d.{{ vf }},
        {%- for c in payload %}
        {%- if c.name | lower in delete_passthrough_columns %}
        d.{{ c.name }},
        {%- else %}
        cast(null as {{ c.data_type }})     as {{ c.name }},
        {%- endif %}
        {%- endfor %}
        true                                as smazano_priznak,
        true                                as _is_delete_marker,
        0                                   as _prio,
        cast(d._stg_seq as {{ seq_type }})  as _stg_seq,
        cast(null as timestamp)             as _baseline_loaded_ts,
        cast(null as string)                as _stored_hash
    from {{ deletes }} as d
    {%- if batch_mode == 'watermark' %}
    where {{ cdc_window_predicate('d') }}
    {%- endif %}
),
{%- endif %}

{%- if is_incremental() %}

baseline as (
    -- Open versions of the entities touched by this batch (Load_Pattern step 9).
    select
        t.{{ hkey }},
        t.{{ vf }},
        {%- for c in payload %}
        {%- if c.name | lower in target_names %}
        t.{{ c.name }},
        {%- else %}
        cast(null as {{ c.data_type }})     as {{ c.name }},
        {%- endif %}
        {%- endfor %}
        {%- if track_deletes %}
        t.smazano_priznak,
        {%- endif %}
        false                               as _is_delete_marker,
        2                                   as _prio,
        cast(null as {{ seq_type }})        as _stg_seq,
        t.__nacteno_ts                      as _baseline_loaded_ts,
        t.hash_zaznamu                      as _stored_hash
    from {{ this }} as t
    where t.platnost_do_ts = {{ high }}
    {%- if batch_mode == 'watermark' %}
      and t.{{ hkey }} in (
            select {{ hkey }} from batch
            {%- if track_deletes %}
            union
            select {{ hkey }} from delete_markers
            {%- endif %}
      )
    {%- endif %}
),
{%- endif %}

unioned as (
    select * from batch
    {%- if track_deletes %}
    union all
    select * from delete_markers
    {%- endif %}
    {%- if is_incremental() %}
    union all
    select * from baseline
    {%- endif %}
),

in_order as (
    -- Load_Pattern step 18: a change older than the open version is a replay or a
    -- late arrival and must not create a false version.
    select *
    from (
        select u.*, max(case when _prio = 2 then {{ vf }} end) over (partition by {{ hkey }}) as _baseline_vf
        from unioned as u
    ) as bounded
    where _baseline_vf is null or {{ vf }} >= _baseline_vf
),

deduped as (
    -- One row per (entity, version start). Priority: delete > new change > stored version;
    -- within the batch the latest message wins (_stg_seq).
    select
        *,
        -- hash of the stored version starting at the same instant (if any): lets the
        -- final filter skip re-writing a version that did not change (overlap re-reads,
        -- batch_mode='full').
        max(_stored_hash) over (partition by {{ hkey }}, {{ vf }}) as _same_vf_stored_hash
    from in_order
    qualify row_number() over (
        partition by {{ hkey }}, {{ vf }}
        order by _prio asc, _stg_seq desc nulls last
    ) = 1
),

{%- if track_deletes %}

state_ref as (
    select
        d.*,
        last_value(case when not _is_delete_marker then {{ vf }} end, true) over (
            partition by {{ hkey }} order by {{ vf }}
            rows between unbounded preceding and current row
        ) as _state_vf
    from deduped as d
),

filled as (
    -- A delete marker carries the last known business state of the entity.
    select
        m.{{ hkey }},
        m.{{ vf }},
        {%- for c in payload %}
        {%- if c.name | lower in delete_passthrough_columns %}
        m.{{ c.name }},
        {%- else %}
        case when m._is_delete_marker then s.{{ c.name }} else m.{{ c.name }} end as {{ c.name }},
        {%- endif %}
        {%- endfor %}
        m.smazano_priznak,
        m._prio,
        m._baseline_loaded_ts,
        m._same_vf_stored_hash
    from state_ref as m
    left join deduped as s
        on  m._is_delete_marker
        and s.{{ hkey }} = m.{{ hkey }}
        and s.{{ vf }} = m._state_vf
    -- a delete of an entity never seen before has no state to version
    where not (m._is_delete_marker and m._state_vf is null)
),
{%- else %}

filled as (
    select * except (_baseline_vf, _is_delete_marker, _stg_seq, _stored_hash)
    from deduped
),
{%- endif %}

hashed as (
    select f.*, {{ record_hash(hash_items) }} as hash_zaznamu
    from filled as f
),

collapsed as (
    -- Load_Pattern step 12: identical consecutive states are one version.
    select *
    from (
        select h.*, lag(hash_zaznamu) over (partition by {{ hkey }} order by {{ vf }}) as _prev_hash
        from hashed as h
    ) as changes
    where _prev_hash is null or _prev_hash <> hash_zaznamu
),

versioned as (
    -- Load_Pattern steps 13/14: each version ends exactly where the next begins.
    select
        c.*,
        coalesce(lead({{ vf }}) over (partition by {{ hkey }} order by {{ vf }}), {{ high }}) as _valid_to
    from collapsed as c
)

select
    {{ hkey }},
    {%- for c in payload %}
    {{ c.name }},
    {%- endfor %}
    {%- if track_deletes %}
    smazano_priznak,
    {%- endif %}
    {{ hash_key([hkey, vf]) }}                              as verze_id,
    {{ vf }},
    _valid_to                                               as platnost_do_ts,
    hash_zaznamu,
    coalesce(_baseline_loaded_ts, current_timestamp())      as __nacteno_ts
from versioned
-- no write for versions that stay open and unchanged: stored rows, and batch rows
-- identical to the stored version they would replace
where not (_prio = 2 and _valid_to = {{ high }})
  and not (_prio <> 2 and _valid_to = {{ high }} and _same_vf_stored_hash = hash_zaznamu)

{% endmacro %}
