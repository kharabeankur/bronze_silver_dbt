{#-
  ===========================================================================
  Hash keys and record hashes (file 18 sheet Prehled_klicu).

  ONE implementation for every hash in the silver layer. A foreign hkey on a
  child (e.g. kampan.distribucni_kanal_hkey) is only joinable to the parent's
  hkey if both are produced by these macros from identically typed values.

  Design choices (see docs/deviations-and-open-items.md):
   * Every value is wrapped in coalesce(.., null_token). Plain concat_ws drops
     NULLs, so ('a', null, 'b') and ('a', 'b', null) would collide.
   * Complex types (STRUCT / ARRAY / MAP) are serialised with to_json; arrays
     must already be sorted by a stable key (Load_Pattern step 11).
   * Algorithm, separator and null token are configuration (dbt_project vars).
  ===========================================================================
-#}

{% macro _hash_fn(expr) -%}
    {%- set algo = var('hash_algorithm', 'md5') -%}
    {%- if algo == 'md5' -%} md5({{ expr }})
    {%- elif algo == 'sha2_256' -%} sha2({{ expr }}, 256)
    {%- else -%} {{ exceptions.raise_compiler_error("Unsupported hash_algorithm '" ~ algo ~ "'") }}
    {%- endif -%}
{%- endmacro %}


{#- Serialise one expression to a deterministic string. data_type optional. -#}
{% macro hash_input(expr, data_type=none) -%}
    {%- set dt = (data_type or '') | lower -%}
    {%- if dt.startswith('struct') or dt.startswith('array') or dt.startswith('map') -%}
        coalesce(to_json({{ expr }}), '{{ var("hash_null_token") }}')
    {%- else -%}
        coalesce(cast({{ expr }} as string), '{{ var("hash_null_token") }}')
    {%- endif -%}
{%- endmacro %}


{#-
  Hash of a list of expressions. Items may be plain SQL strings or
  {'expr': .., 'data_type': ..} dicts (used by the SCD2 macro after column
  introspection).
-#}
{% macro hash_of(items) -%}
    {%- if items | length == 0 -%}
        {{ exceptions.raise_compiler_error("hash_of() needs at least one column") }}
    {%- endif -%}
    {%- set parts = [] -%}
    {%- for item in items -%}
        {%- if item is mapping -%}
            {%- do parts.append(hash_input(item['expr'], item.get('data_type'))) -%}
        {%- else -%}
            {%- do parts.append(hash_input(item)) -%}
        {%- endif -%}
    {%- endfor -%}
    {{ _hash_fn("concat_ws('" ~ var('hash_separator') ~ "', " ~ parts | join(', ') ~ ")") }}
{%- endmacro %}


{#- Primary hash key from the natural key columns: <entity>_hkey. Never NULL. -#}
{% macro hash_key(columns) -%}
    {{ hash_of(columns) }}
{%- endmacro %}


{#-
  Foreign hash key (<parent>_hkey on the child). NULL when every natural key
  part is NULL, so "no parent" stays NULL instead of a hash pointing nowhere.
-#}
{% macro fk_hash_key(columns) -%}
    case when {% for c in columns %}{{ c }} is null{% if not loop.last %} and {% endif %}{% endfor %}
         then cast(null as string)
         else {{ hash_of(columns) }}
    end
{%- endmacro %}


{#- Record (decision) hash: hash_zaznamu. Technical "__" columns are rejected. -#}
{% macro record_hash(columns) -%}
    {%- for c in columns -%}
        {%- set name = (c['expr'] if c is mapping else c) | trim -%}
        {%- if name.startswith('__') -%}
            {{ exceptions.raise_compiler_error(
                "Technical column '" ~ name ~ "' must not enter hash_zaznamu (Load_Pattern check 9)") }}
        {%- endif -%}
    {%- endfor -%}
    {{ hash_of(columns) }}
{%- endmacro %}


{#- Normalised domain login - the natural key of obchodnik. -#}
{% macro normalize_login(col) -%}
    {{ var('login_normalization', '{col}') | replace('{col}', col) }}
{%- endmacro %}
