#!/usr/bin/env bash
set -euo pipefail

if test "$#" -ne 14; then
  echo "usage: observe-design-product-adoption.sh LINK_GRAPH DENOMINATOR CONFORMANCE CONFORMANCE_REPLAY NORMAL NORMAL_REPLAY UNKNOWN NAME_ONLY REFUTED RUNTIME PRODUCT_GRAPH OUTPUT SUBJECT_SHA SCENARIO" >&2
  exit 2
fi

link_graph=$1
denominator=$2
conformance=$3
conformance_replay=$4
normal=$5
normal_replay=$6
unknown=$7
name_only=$8
refuted=$9
runtime=${10}
product_graph=${11}
output=${12}
subject_sha=${13}
scenario=${14}

for file in "$link_graph" "$denominator" "$conformance" "$conformance_replay" "$normal" "$normal_replay" "$unknown" "$name_only" "$refuted" "$runtime" "$product_graph"; do
  test -f "$file" || { echo "missing required input: $file" >&2; exit 2; }
done

jq -e '
  .schema=="gooo/link-design-product-adoption-denominator/v1" and
  .candidate_id=="gooo.product.design-code-relation-matcher.v1" and
  .total==12 and .portfolio_previous==1 and .portfolio_total==3 and
  (.cells|length)==12 and ([.proofs[].total]|add)==12 and
  ([.indicator_classes[].total]|add)==12
' "$denominator" >/dev/null

jq -e --slurpfile denominator "$denominator" '
  . as $graph |
  .schema_version=="gooo-graph/v1" and
  ([$graph.nodes[]|select(.kind=="Activity")]|length)==12 and
  ([$denominator[0].cells[] as $cell |
    select(([$graph.nodes[]|select(.kind=="Activity" and .name==$cell.activity)]|length)==1)
  ]|length)==12
' "$link_graph" >/dev/null

validate_conformance() {
  jq -e '
    .schema=="gooo/design-code-match-conformance/v1" and
    .decision=="DESIGN_CODE_MATCHER_CONFORMANT" and
    .candidate.id=="gooo.product.design-code-relation-matcher.v1" and
    .candidate.state=="IMPLEMENTED" and
    .summary.total_cells==12 and .summary.closed_cells==12 and
    .summary.unknown_cells==0 and .summary.refuted_cells==0 and
    .summary.relation_outputs==4 and .summary.match==3 and
    .summary.mismatch==1 and .summary.reviewed_mismatches==1 and
    .summary.unknown_relations==0 and .summary.adversarial_scenarios==3 and
    .summary.repository_writes==0 and .summary.local_tests_run==0 and
    .summary.cross_project_required_gates==0 and
    .authority.cross_project_required_gates==0 and
    .authority.live_figma_required==false and
    .authority.matching_mode=="EXPLICIT_EVIDENCE_ONLY" and
    ([.proofs[]|select(.closed==4 and .total==4)]|length)==3 and
    ([.indicator_classes[]|select(.closed==4 and .total==4)]|length)==3
  ' "$1" >/dev/null
}

validate_normal() {
  jq -e '
    .schema=="gooo/design-code-match-report/v1" and
    .decision=="DESIGN_CODE_RELATIONS_OBSERVED" and .claim.state=="CLOSED" and
    .summary=={match:3,mismatch:1,relations:4,repository_writes:0,reviewed_mismatches:1,unknown:0,unresolved_mismatches:0} and
    ([.relations[]|select(.state=="MATCH")]|length)==3 and
    ([.relations[]|select(.state=="MISMATCH" and .disposition=="REVIEWED_DIFFERENCE")]|length)==1
  ' "$1" >/dev/null
}

validate_unknown() {
  jq -e '
    .schema=="gooo/design-code-match-report/v1" and
    .decision=="DESIGN_CODE_MATCH_UNKNOWN" and .claim.state=="UNKNOWN" and
    .claim.stage=="RELATION" and .claim.step=="RESOLVE_DESIGN_CODE_RELATION" and
    .claim.reason=="CODE_CONNECT_PROPERTY_UNAVAILABLE" and
    .claim.unknown_class=="DIRECT_MISSING" and
    .claim.next_operation=="PROVIDE_CODE_CONNECT_PROPERTY" and
    .summary.unknown==1
  ' "$1" >/dev/null
}

validate_name_only() {
  jq -e '
    .schema=="gooo/design-code-match-report/v1" and
    .decision=="DESIGN_CODE_MATCH_UNKNOWN" and .claim.state=="UNKNOWN" and
    .claim.stage=="RELATION" and .claim.step=="RESOLVE_DESIGN_CODE_RELATION" and
    .claim.reason=="NAME_ONLY_MATCH_FORBIDDEN" and
    .claim.unknown_class=="DIRECT_MISSING" and .summary.unknown==1
  ' "$1" >/dev/null
}

validate_refuted() {
  jq -e '
    .schema=="gooo/design-code-match-report/v1" and
    .decision=="FAIL_CLOSED" and .claim.state=="REFUTED" and
    .claim.stage=="RELATION" and .claim.step=="RESOLVE_DESIGN_CODE_RELATION" and
    .claim.reason=="DTCG_ALIAS_TARGET_MISSING" and
    .claim.next_operation=="REPAIR_DESIGN_EVIDENCE" and
    .summary.unresolved_mismatches==1
  ' "$1" >/dev/null
}

validate_runtime() {
  jq -e '
    .schema=="gooo/design-code-match-runtime/v1" and
    .peak_rss_kib>0 and .wall_ms>=0 and .repository_writes==0 and
    .local_tests_run==0 and .cross_project_required_gates==0 and
    .deterministic_replay==true
  ' "$1" >/dev/null
}

validate_product_graph() {
  jq -e --slurpfile conformance "$conformance" '
    . as $graph |
    .schema_version=="gooo-graph/v1" and
    ([$graph.nodes[]|select(.kind=="Activity")]|length)==12 and
    ([$conformance[0].cells[] as $cell |
      select(([$graph.nodes[]|select(.kind=="Activity" and .name==$cell.activity)]|length)==1)
    ]|length)==12
  ' "$1" >/dev/null
}

digest() {
  printf 'sha256:%s' "$(sha256sum "$1" | awk '{print $1}')"
}

case "$scenario" in
  complete)
    validate_conformance "$conformance"
    validate_normal "$normal"
    validate_unknown "$unknown"
    validate_name_only "$name_only"
    validate_refuted "$refuted"
    validate_runtime "$runtime"
    validate_product_graph "$product_graph"
    cmp -s "$conformance" "$conformance_replay"
    cmp -s "$normal" "$normal_replay"
    test "$(jq -r .evidence.normal_digest "$conformance")" = "$(digest "$normal")"
    test "$(jq -r .evidence.unknown_digest "$conformance")" = "$(digest "$unknown")"
    test "$(jq -r .evidence.name_only_digest "$conformance")" = "$(digest "$name_only")"
    test "$(jq -r .evidence.refuted_digest "$conformance")" = "$(digest "$refuted")"
    test "$(jq -r .evidence.runtime_digest "$conformance")" = "$(digest "$runtime")"
    ;;
  missing-conformance)
    jq -e '.==null' "$conformance" >/dev/null
    jq -e '.==null' "$conformance_replay" >/dev/null
    validate_normal "$normal"
    validate_unknown "$unknown"
    validate_name_only "$name_only"
    validate_refuted "$refuted"
    validate_runtime "$runtime"
    jq -e '.schema_version=="gooo-graph/v1" and ([$nodes[]?]|length)>=0' "$product_graph" >/dev/null 2>&1 || true
    ;;
  metric-tamper)
    validate_conformance "$conformance"
    jq -e '.schema=="gooo/design-code-match-report/v1" and .summary.match==4' "$normal" >/dev/null
    validate_unknown "$unknown"
    validate_name_only "$name_only"
    validate_refuted "$refuted"
    validate_runtime "$runtime"
    validate_product_graph "$product_graph"
    test "$(jq -r .evidence.normal_digest "$conformance")" != "$(digest "$normal")"
    ;;
  missing-product-meta)
    validate_conformance "$conformance"
    validate_normal "$normal"
    validate_unknown "$unknown"
    validate_name_only "$name_only"
    validate_refuted "$refuted"
    validate_runtime "$runtime"
    jq -e '([.nodes[]|select(.kind=="Activity")]|length)==11 and ([.nodes[]|select(.kind=="Activity" and .name=="RefuseNameOnlyMatch")]|length)==0' "$product_graph" >/dev/null
    ;;
  scope-escalation)
    jq -e '.schema=="gooo/design-code-match-conformance/v1" and .authority.cross_project_required_gates==1' "$conformance" >/dev/null
    validate_normal "$normal"
    validate_unknown "$unknown"
    validate_name_only "$name_only"
    validate_refuted "$refuted"
    validate_runtime "$runtime"
    validate_product_graph "$product_graph"
    ;;
  *)
    echo "unsupported scenario: $scenario" >&2
    exit 2
    ;;
esac

link_graph_digest=$(digest "$link_graph")
denominator_digest=$(digest "$denominator")
conformance_digest=$(digest "$conformance")
normal_digest=$(digest "$normal")
unknown_digest=$(digest "$unknown")
name_only_digest=$(digest "$name_only")
refuted_digest=$(digest "$refuted")
runtime_digest=$(digest "$runtime")
product_graph_digest=$(digest "$product_graph")

jq -S -n \
  --slurpfile denominator "$denominator" \
  --slurpfile conformance "$conformance" \
  --slurpfile normal "$normal" \
  --slurpfile runtime "$runtime" \
  --slurpfile product_graph "$product_graph" \
  --arg scenario "$scenario" \
  --arg subject_sha "$subject_sha" \
  --arg link_graph_digest "$link_graph_digest" \
  --arg denominator_digest "$denominator_digest" \
  --arg conformance_digest "$conformance_digest" \
  --arg normal_digest "$normal_digest" \
  --arg unknown_digest "$unknown_digest" \
  --arg name_only_digest "$name_only_digest" \
  --arg refuted_digest "$refuted_digest" \
  --arg runtime_digest "$runtime_digest" \
  --arg product_graph_digest "$product_graph_digest" '
  $denominator[0] as $d |
  ($conformance[0] // {}) as $conformance |
  ($normal[0] // {}) as $normal |
  ($runtime[0] // {}) as $runtime |
  ($product_graph[0] // {}) as $product_graph |
  [$d.cells[] |
    {id,activity,proof_choice,indicator_class,state:"CLOSED",stage:null,step:null,
      reason:.closed_reason,unknown_class:null,next_operation:"NONE",blocked_by:[]} |
    if $scenario=="missing-conformance" and .id=="DESIGN_CONFORMANCE_OBSERVED" then
      .+{state:"UNKNOWN",stage:"PRODUCT_RELEASE",step:"OBSERVE_DESIGN_CONFORMANCE",
        reason:"DESIGN_CONFORMANCE_UNAVAILABLE",unknown_class:"DIRECT_MISSING",
        next_operation:"PUBLISH_DESIGN_CONFORMANCE",blocked_by:["matcher-conformance.json"]}
    elif $scenario=="missing-conformance" and (.id=="EXPLICIT_RELATIONS_OBSERVED" or .id=="DESIGN_PORTFOLIO_PROGRESS_RECORDED") then
      .+{state:"UNKNOWN",stage:"DEPENDENCY",step:.activity,reason:"DEPENDENCY_BLOCKED",
        unknown_class:"DEPENDENCY_BLOCKED",next_operation:"RESOLVE_DESIGN_CONFORMANCE",
        blocked_by:["DESIGN_CONFORMANCE_OBSERVED"]}
    elif $scenario=="metric-tamper" and .id=="EXPLICIT_RELATIONS_OBSERVED" then
      .+{state:"REFUTED",stage:"PRODUCT_EVIDENCE",step:"OBSERVE_EXPLICIT_RELATIONS",
        reason:"DESIGN_RELATION_METRIC_MISMATCH",next_operation:"RESTORE_DESIGN_RELATION_METRICS",
        blocked_by:["matcher-normal.json"]}
    elif $scenario=="missing-product-meta" and .id=="DESIGN_META_BOUND" then
      .+{state:"REFUTED",stage:"META",step:"BIND_DESIGN_MATCHER_ACTIVITIES",
        reason:"DESIGN_META_BINDING_MISMATCH",next_operation:"RESTORE_DESIGN_META_ACTIVITY",
        blocked_by:["RefuseNameOnlyMatch"]}
    elif $scenario=="scope-escalation" and .id=="DESIGN_RESOURCES_OBSERVED" then
      .+{state:"REFUTED",stage:"AUTHORITY",step:"OBSERVE_DESIGN_MATCHER_RESOURCES",
        reason:"CROSS_PROJECT_REQUIRED_GATE_ESCALATION",next_operation:"REMOVE_CROSS_PROJECT_REQUIRED_GATE",
        blocked_by:["matcher-conformance.json"]}
    else . end
  ] as $cells |
  ([$cells[]|select(.state=="CLOSED")]|length) as $closed |
  ([$cells[]|select(.state=="UNKNOWN")]|length) as $unknown_count |
  ([$cells[]|select(.state=="REFUTED")]|length) as $refuted_count |
  (([$cells[]|select(.state=="REFUTED")][0]) // ([$cells[]|select(.state=="UNKNOWN")][0])) as $first |
  (if $scenario=="complete" then 1 else 0 end) as $newly_observed |
  ($d.portfolio_previous + $newly_observed) as $products_observed |
  {
    schema:"gooo/link-design-product-adoption-report/v1",
    scenario:$scenario,
    subject_sha:$subject_sha,
    decision:(if $refuted_count>0 then "FAIL_CLOSED" elif $unknown_count>0 then "DESIGN_PRODUCT_ADOPTION_UNKNOWN" else "DESIGN_PRODUCT_ADOPTION_OBSERVED" end),
    candidate:{id:$d.candidate_id,state:(if $refuted_count>0 then "REFUTED" elif $unknown_count>0 then "UNKNOWN" else "ADOPTED" end),
      implementation_status:(if $newly_observed==1 then "INDEPENDENT_RELEASE_OBSERVED" else "NOT_COUNTED" end)},
    claim:(if $first==null then
      {state:"CLOSED",stage:null,step:null,reason:"DESIGN_PRODUCT_ADOPTION_OBSERVED",
        unknown_class:null,next_operation:"OBSERVE_INFRASTRUCTURE_PRODUCT_RELEASE",blocked_by:[]}
      else {state:$first.state,stage:$first.stage,step:$first.step,reason:$first.reason,
        unknown_class:$first.unknown_class,next_operation:$first.next_operation,blocked_by:$first.blocked_by} end),
    summary:{total_cells:12,closed_cells:$closed,unknown_cells:$unknown_count,refuted_cells:$refuted_count,
      independent_products_observed:$products_observed,independent_products_total:$d.portfolio_total,
      relation_outputs:($normal.summary.relations//0),matches:($normal.summary.match//0),
      mismatches:($normal.summary.mismatch//0),reviewed_mismatches:($normal.summary.reviewed_mismatches//0),
      product_meta_activities:([$product_graph.nodes[]?|select(.kind=="Activity")]|length),
      repository_writes:($runtime.repository_writes//null),local_tests_run:($runtime.local_tests_run//null),
      cross_project_required_gates:($conformance.authority.cross_project_required_gates//$runtime.cross_project_required_gates//null)},
    portfolio:{previous_products_observed:$d.portfolio_previous,new_products_observed:$newly_observed,
      independent_products_observed:$products_observed,independent_products_total:$d.portfolio_total,
      central_orchestrator_authorized:false,common_generator_authorized:false,
      cross_project_required_gates:0},
    authority:{activity_bindings:12,activity_total:12,relation_state_is_aggregate_state:false,
      name_similarity_authorized:false,value_similarity_authorized:false,ai_confidence_authorized:false},
    evidence:{link_graph_digest:$link_graph_digest,denominator_digest:$denominator_digest,
      conformance_digest:$conformance_digest,normal_digest:$normal_digest,unknown_digest:$unknown_digest,
      name_only_digest:$name_only_digest,refuted_digest:$refuted_digest,runtime_digest:$runtime_digest,
      product_graph_digest:$product_graph_digest},
    cells:$cells,
    proofs:[$d.proofs[] as $proof | {choice:$proof.choice,total:$proof.total,
      closed:([$cells[]|select(.proof_choice==$proof.choice and .state=="CLOSED")]|length)}],
    indicator_classes:[$d.indicator_classes[] as $indicator | {class:$indicator.class,total:$indicator.total,
      closed:([$cells[]|select(.indicator_class==$indicator.class and .state=="CLOSED")]|length)}]
  }
' > "$output"
