{#- KCL sco_bdt_task_delete -> delete markers for ukol_hist (Load_Pattern step 17). -#}
{%- set src = source('kcl', 'sco_bdt_task_delete') -%}

select
    {{ hash_key(['cast(id as bigint)']) }}      as ukol_hkey,
    date_deleted                                as platnost_od_ts,
    __source_system                             as __zdrojovy_system,
    '{{ source_table_name(src) }}'              as __zdrojova_tabulka_nazev,
    __load_timestamp                            as _stg_load_ts,
    coalesce(date_deleted, __load_timestamp)    as _stg_seq
from {{ src }}
