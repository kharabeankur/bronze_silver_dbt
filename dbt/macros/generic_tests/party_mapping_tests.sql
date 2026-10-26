{#-
  mapovani_id_partnera must resolve in ONE step (file 14): no resolved target
  may itself be re-mapped. A failure means a chain longer than
  var('party_chain_max_depth') or a cycle.
-#}
{% test party_mapping_fully_resolved(model) %}
select a.zdrojovy_partner_id, a.cilovy_partner_id, b.cilovy_partner_id as remapped_to
from {{ model }} as a
join {{ model }} as b
  on b.zdrojovy_partner_id = a.cilovy_partner_id
where b.cilovy_partner_id <> a.cilovy_partner_id
{% endtest %}
