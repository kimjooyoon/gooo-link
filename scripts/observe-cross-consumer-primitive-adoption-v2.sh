#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -ne 12 ]]; then
  echo "usage: $0 GRAPH DENOMINATOR BASELINE LOCAL_CURRENT LOCAL_UNKNOWN LOCAL_CLAIM_REFUTED LOCAL_CLASS_REFUTED LOCAL_CORE_REFUTED LOCAL_SCOPE_REFUTED OUTPUT SUBJECT_SHA SCENARIO" >&2
  exit 64
fi

graph=$1
denominator=$2
baseline=$3
local_current=$4
local_unknown=$5
local_claim_refuted=$6
local_class_refuted=$7
local_core_refuted=$8
local_scope_refuted=$9
output=${10}
subject_sha=${11}
scenario=${12}

candidate_id="gooo.primitive.claim-resolution-tuple.v1"
state="CLOSED"
reason="THIRD_DIRECT_CLAIM_RESOLUTION_MAPPING_OBSERVED"
stage=""
step=""
unknown_class=""
next_operation="OBSERVE_NEXT_INDEPENDENT_CONSUMER_ADOPTION"
refuted_cell=""

set_unknown() {
  if [[ "$state" == "CLOSED" ]]; then
    state="UNKNOWN"; reason=$1; stage=$2; step=$3; unknown_class=$4; next_operation=$5
  fi
}

set_refuted() {
  if [[ "$state" == "CLOSED" ]]; then
    state="REFUTED"; reason=$1; stage=$2; step=$3; refuted_cell=$4; unknown_class=""; next_operation=$5
  fi
}

digest_of() {
  if [[ -s "$1" ]]; then printf 'sha256:%s' "$(sha256sum "$1" | awk '{print $1}')"; else printf 'unavailable'; fi
}

jq -e '
  .schema=="gooo/link/cross-consumer-primitive-adoption-denominator/v2" and
  .candidate_id=="gooo.primitive.claim-resolution-tuple.v1" and .total==12 and
  (.cells|length)==12 and ([.cells[].id]|unique|length)==12 and
  ([.cells[].activity]|unique|length)==12 and
  ([.proofs[].total]|add)==12 and ([.indicator_classes[].total]|add)==12
' "$denominator" >/dev/null

jq -e --slurpfile denominator "$denominator" '
  . as $graph | .schema_version=="gooo-graph/v1" and
  ([$graph.nodes[]|select(.kind=="Activity")]|length)==12 and
  ([$denominator[0].cells[] as $cell |
    select(([$graph.nodes[]|select(.kind=="Activity" and .name==$cell.activity)]|length)==1)
  ]|length)==12
' "$graph" >/dev/null

if [[ ! -s "$baseline" ]] || jq -e '.==null' "$baseline" >/dev/null 2>&1; then
  set_unknown "BASELINE_ADOPTION_RELEASE_UNAVAILABLE" "BASELINE_RELEASE" "OBSERVE_BASELINE_PRIMITIVE_ADOPTION" "DIRECT_MISSING" "PROVIDE_PINNED_BASELINE_ADOPTION_RELEASE"
elif ! jq -e '
  .schema=="gooo/link/cross-consumer-primitive-adoption-report/v1" and
  .decision=="SECOND_DIRECT_PRIMITIVE_MAPPING_OBSERVED" and .claim.state=="CLOSED" and
  .candidate.id=="gooo.primitive.claim-resolution-tuple.v1" and
  .candidate.direct_mappings=={observed:2,total:30,remaining:28} and
  .summary.direct_mappings==2 and .summary.mapping_denominator==30 and .summary.mapping_remaining==28 and
  .summary.independent_consumer_adoptions==1 and
  .authority.central_orchestration_authorized==false and .authority.common_generator_authorized==false and
  .authority.cross_project_required_gates==0 and .authority.source_repository_writes==0
' "$baseline" >/dev/null; then
  set_refuted "BASELINE_TWO_MAPPING_RELEASE_INVALID" "BASELINE_RELEASE" "OBSERVE_BASELINE_PRIMITIVE_ADOPTION" "BASELINE_ADOPTION_RELEASE_OBSERVED" "RESTORE_BASELINE_TWO_MAPPING_RELEASE"
fi

if [[ ! -s "$local_current" ]] || jq -e '.==null' "$local_current" >/dev/null 2>&1; then
  set_unknown "LOCAL_ADOPTION_RELEASE_UNAVAILABLE" "LOCAL_ADOPTION_RELEASE" "OBSERVE_LOCAL_CLAIM_RESOLUTION_ADOPTION" "DIRECT_MISSING" "PROVIDE_PINNED_LOCAL_ADOPTION_RELEASE"
elif ! jq -e '.schema=="gooo/local-ledger/claim-resolution-adoption-report/v1"' "$local_current" >/dev/null; then
  set_refuted "LOCAL_ADOPTION_SCHEMA_INVALID" "LOCAL_ADOPTION_RELEASE" "OBSERVE_LOCAL_CLAIM_RESOLUTION_ADOPTION" "LOCAL_ADOPTION_RELEASE_OBSERVED" "RESTORE_LOCAL_ADOPTION_SCHEMA"
elif [[ "$(jq -r '.candidate.id // ""' "$local_current")" != "$candidate_id" ]]; then
  set_refuted "CLAIM_RESOLUTION_CANDIDATE_MISMATCH" "CANDIDATE_IDENTITY" "BIND_CLAIM_RESOLUTION_CANDIDATE_IDENTITY" "CANDIDATE_IDENTITY_BOUND" "RESTORE_CLAIM_RESOLUTION_CANDIDATE_IDENTITY"
else
  child_state=$(jq -r '.claim.state // ""' "$local_current")
  if [[ "$child_state" == "UNKNOWN" ]]; then
    set_unknown "$(jq -r '.claim.reason' "$local_current")" "$(jq -r '.claim.stage' "$local_current")" \
      "$(jq -r '.claim.step' "$local_current")" "$(jq -r '.claim.unknown_class' "$local_current")" \
      "$(jq -r '.claim.next_operation' "$local_current")"
  elif [[ "$child_state" == "REFUTED" ]]; then
    child_reason=$(jq -r '.claim.reason' "$local_current")
    child_cell="LOCAL_CLAIM_EVIDENCE_OBSERVED"
    case "$child_reason" in
      UNKNOWN_CLASS_BINDING_MISMATCH) child_cell="UNKNOWN_CLASS_BOUNDARY_PRESERVED" ;;
      INVALID_CORE_CLAIM_DECISION) child_cell="ADVERSE_REFUTATION_PATHS_PRESERVED" ;;
      CORE_REPOSITORY_WRITE_AUTHORITY_ESCALATION) child_cell="AUTHORITY_BOUNDARY_PRESERVED" ;;
    esac
    set_refuted "$child_reason" "$(jq -r '.claim.stage' "$local_current")" "$(jq -r '.claim.step' "$local_current")" \
      "$child_cell" "$(jq -r '.claim.next_operation' "$local_current")"
  elif [[ "$child_state" != "CLOSED" ]]; then
    set_refuted "LOCAL_ADOPTION_CLAIM_STATE_UNKNOWN" "LOCAL_ADOPTION_DECISION" "REJECT_UNRECOGNIZED_LOCAL_CLAIM_STATE" "LOCAL_ADOPTION_RELEASE_OBSERVED" "RESTORE_EXPLICIT_LOCAL_CLAIM_STATE"
  elif ! jq -e '
    .decision=="CLAIM_RESOLUTION_ADOPTION_OBSERVED" and
    .candidate.state=="ADOPTED" and .candidate.implementation_status=="INDEPENDENT_CONSUMER_ADOPTION_OBSERVED" and
    .summary.closed_cells==12 and .summary.total_cells==12 and .summary.unknown_cells==0 and .summary.refuted_cells==0 and
    .summary.claim_scenarios_resolved==3 and .summary.claim_scenarios_total==3 and
    .summary.released_claims_matched==3 and .summary.released_claims_total==3 and
    .summary.released_claim_fields_matched==15 and .summary.released_claim_fields_total==15 and
    .summary.core_claim_fields_observed==18 and .summary.core_claim_fields_total==18 and
    .summary.unknown_class_bindings_observed==1 and .summary.unknown_class_bindings_total==1 and
    .summary.rejection_scenarios_observed==2 and .summary.rejection_scenarios_total==2 and
    .summary.inventory_facts_observed==4 and .summary.inventory_facts_total==4 and
    .summary.independent_consumer_adoptions==1 and
    .inventory=={descendant_directories:2,files:6,go_physical_lines:7,gooo_physical_lines:28} and
    .summary.repository_writes==0 and .summary.local_tests_run==0 and .summary.cross_project_required_gates==0 and
    .authority.core_mutation_authorized==false and .authority.dependency_propagation_authorized==false and
    .authority.automatic_merge_authorized==false and .authority.unknown_class_binding=="EXPLICIT_GOOO_ACTIVITY_VALUE"
  ' "$local_current" >/dev/null; then
    set_refuted "LOCAL_INDEPENDENT_ADOPTION_NOT_CLOSED" "LOCAL_ADOPTION_DECISION" "COUNT_LOCAL_INDEPENDENT_ADOPTION" "LOCAL_INDEPENDENT_ADOPTION_COUNTED" "RESTORE_CLOSED_LOCAL_ADOPTION"
  fi
fi

if [[ ! -s "$local_unknown" ]] || ! jq -e '
  .decision=="CLAIM_RESOLUTION_ADOPTION_UNKNOWN" and .claim.state=="UNKNOWN" and
  .claim.stage=="CORE_RECEIPT" and .claim.step=="RESOLVE_MISSING_RUNBOOK_CLAIM" and
  .claim.reason=="CORE_CLAIM_RESOLUTION_RECEIPT_UNAVAILABLE" and .claim.unknown_class=="DIRECT_MISSING" and
  .claim.next_operation=="PROVIDE_CORE_CLAIM_RESOLUTION_RECEIPT" and
  .summary.closed_cells==9 and .summary.unknown_cells==3
' "$local_unknown" >/dev/null 2>&1; then
  set_refuted "LOCAL_ADVERSE_UNKNOWN_INVALID" "ADVERSE_UNKNOWN" "PRESERVE_LOCAL_ADVERSE_UNKNOWN" "ADVERSE_UNKNOWN_PATH_PRESERVED" "RESTORE_LOCAL_ADVERSE_UNKNOWN"
fi

if [[ ! -s "$local_claim_refuted" ]] || [[ ! -s "$local_class_refuted" ]] || [[ ! -s "$local_core_refuted" ]] || [[ ! -s "$local_scope_refuted" ]] ||
   ! jq -e '.claim.state=="REFUTED" and .claim.reason=="LOCAL_CORE_CLAIM_MISMATCH" and .claim.stage=="CLAIM_COMPARISON"' "$local_claim_refuted" >/dev/null 2>&1 ||
   ! jq -e '.claim.state=="REFUTED" and .claim.reason=="UNKNOWN_CLASS_BINDING_MISMATCH" and .claim.stage=="UNKNOWN_CLASS"' "$local_class_refuted" >/dev/null 2>&1 ||
   ! jq -e '.claim.state=="REFUTED" and .claim.reason=="INVALID_CORE_CLAIM_DECISION" and .claim.stage=="CORE_DECISION"' "$local_core_refuted" >/dev/null 2>&1 ||
   ! jq -e '.claim.state=="REFUTED" and .claim.reason=="CORE_REPOSITORY_WRITE_AUTHORITY_ESCALATION" and .claim.stage=="AUTHORITY"' "$local_scope_refuted" >/dev/null 2>&1; then
  set_refuted "LOCAL_ADVERSE_REFUTATION_SET_INVALID" "ADVERSE_REFUTATION" "PRESERVE_LOCAL_ADVERSE_REFUTATIONS" "ADVERSE_REFUTATION_PATHS_PRESERVED" "RESTORE_FOUR_LOCAL_ADVERSE_REFUTATIONS"
fi

if [[ "$state" == "CLOSED" ]]; then
  decision="THIRD_DIRECT_PRIMITIVE_MAPPING_OBSERVED"; candidate_state="ADOPTED"; implementation_status="THREE_DIRECT_MAPPINGS_OBSERVED"; direct_mappings=3; independent_adoptions=2
elif [[ "$state" == "UNKNOWN" ]]; then
  decision="CROSS_CONSUMER_PRIMITIVE_ADOPTION_UNKNOWN"; candidate_state="UNKNOWN"; implementation_status="NOT_COUNTED"; direct_mappings=2; independent_adoptions=1
else
  decision="FAIL_CLOSED"; candidate_state="REFUTED"; implementation_status="NOT_COUNTED"; direct_mappings=2; independent_adoptions=1
fi

local_scenarios=0; released_fields=0; core_fields=0; unknown_bindings=0; inventory_facts=0
if jq -e 'type=="object" and has("summary")' "$local_current" >/dev/null 2>&1; then
  local_scenarios=$(jq -r '.summary.claim_scenarios_resolved // 0' "$local_current")
  released_fields=$(jq -r '.summary.released_claim_fields_matched // 0' "$local_current")
  core_fields=$(jq -r '.summary.core_claim_fields_observed // 0' "$local_current")
  unknown_bindings=$(jq -r '.summary.unknown_class_bindings_observed // 0' "$local_current")
  inventory_facts=$(jq -r '.summary.inventory_facts_observed // 0' "$local_current")
fi

unknown_closed='["BASELINE_ADOPTION_RELEASE_OBSERVED","LOCAL_ADOPTION_RELEASE_OBSERVED","CANDIDATE_IDENTITY_BOUND","BASELINE_MAPPING_COUNT_OBSERVED","LOCAL_INVENTORY_CONTEXT_OBSERVED","ADVERSE_UNKNOWN_PATH_PRESERVED","ADVERSE_REFUTATION_PATHS_PRESERVED","AUTHORITY_BOUNDARY_PRESERVED"]'

jq -S -n \
  --slurpfile denominator "$denominator" \
  --arg subject_sha "$subject_sha" --arg scenario "$scenario" --arg decision "$decision" \
  --arg candidate_id "$candidate_id" --arg candidate_state "$candidate_state" --arg implementation_status "$implementation_status" \
  --arg claim_state "$state" --arg reason "$reason" --arg stage "$stage" --arg step "$step" \
  --arg unknown_class "$unknown_class" --arg next_operation "$next_operation" --arg refuted_cell "$refuted_cell" \
  --arg baseline_digest "$(digest_of "$baseline")" --arg local_digest "$(digest_of "$local_current")" \
  --arg graph_digest "$(digest_of "$graph")" --arg denominator_digest "$(digest_of "$denominator")" \
  --argjson direct_mappings "$direct_mappings" --argjson independent_adoptions "$independent_adoptions" \
  --argjson local_scenarios "$local_scenarios" --argjson released_fields "$released_fields" \
  --argjson core_fields "$core_fields" --argjson unknown_bindings "$unknown_bindings" \
  --argjson inventory_facts "$inventory_facts" --argjson unknown_closed "$unknown_closed" '
  $denominator[0] as $d |
  [$d.cells[] | . as $definition |
    (if $claim_state=="CLOSED" then "CLOSED"
     elif $claim_state=="UNKNOWN" then if ($unknown_closed|index($definition.id))!=null then "CLOSED" else "UNKNOWN" end
     elif $definition.id==$refuted_cell then "REFUTED"
     elif $definition.id=="THIRD_DIRECT_MAPPING_RECORDED" then "UNKNOWN"
     else "CLOSED" end) as $cell_state |
    {id:$definition.id,activity:$definition.activity,proof_choice:$definition.proof_choice,
     indicator_class:$definition.indicator_class,state:$cell_state,
     reason:(if $cell_state=="CLOSED" then $definition.closed_reason else $reason end),
     stage:(if $cell_state=="CLOSED" then null else $stage end),
     step:(if $cell_state=="CLOSED" then null else $step end),
     unknown_class:(if $cell_state=="UNKNOWN" then $unknown_class else null end),
     next_operation:(if $cell_state=="CLOSED" then "NONE" else $next_operation end),
     blocked_by:(if $cell_state=="CLOSED" then [] else [$step] end)}
  ] as $cells |
  {
    schema:"gooo/link/cross-consumer-primitive-adoption-report/v2",subject_sha:$subject_sha,scenario:$scenario,decision:$decision,
    candidate:{id:$candidate_id,state:$candidate_state,implementation_status:$implementation_status,
      direct_mappings:{observed:$direct_mappings,total:30,remaining:(30-$direct_mappings)},
      independent_consumer_adoptions:{observed:$independent_adoptions,total:2}},
    claim:{state:$claim_state,stage:(if $claim_state=="CLOSED" then null else $stage end),
      step:(if $claim_state=="CLOSED" then null else $step end),reason:$reason,
      unknown_class:(if $claim_state=="UNKNOWN" then $unknown_class else null end),next_operation:$next_operation,
      blocked_by:(if $claim_state=="CLOSED" then [] else [$step] end)},
    summary:{total_cells:12,closed_cells:([$cells[]|select(.state=="CLOSED")]|length),
      unknown_cells:([$cells[]|select(.state=="UNKNOWN")]|length),refuted_cells:([$cells[]|select(.state=="REFUTED")]|length),
      direct_mappings:$direct_mappings,mapping_denominator:30,mapping_remaining:(30-$direct_mappings),
      independent_consumer_adoptions:$independent_adoptions,
      local_claim_scenarios_resolved:$local_scenarios,local_claim_scenarios_total:3,
      local_released_claim_fields_matched:$released_fields,local_released_claim_fields_total:15,
      local_core_claim_fields_observed:$core_fields,local_core_claim_fields_total:18,
      local_unknown_class_bindings_observed:$unknown_bindings,local_unknown_class_bindings_total:1,
      local_inventory_facts_observed:$inventory_facts,local_inventory_facts_total:4,
      local_adverse_unknown_paths:1,local_adverse_refuted_paths:4,
      repository_writes:0,local_tests_run:0,cross_project_required_gates:0},
    authority:{baseline_release:"v0.14.0-dev",local_adoption_release:"v0.6.0-dev",
      observation_scope:"CROSS_CONSUMER_PRIMITIVE_ADOPTION_ONLY",source_repository_writes:0,
      local_tests_run:0,cross_project_required_gates:0,root_readme_readiness:"EXCLUDED",
      central_orchestration_authorized:false,common_generator_authorized:false,
      product_release_independence_required:true},
    evidence:{denominator_digest:$denominator_digest,graph_digest:$graph_digest,
      baseline_adoption_digest:$baseline_digest,local_adoption_digest:$local_digest},
    cells:$cells,
    proofs:[$d.proofs[] as $proof | {choice:$proof.choice,total:$proof.total,
      closed:([$cells[]|select(.proof_choice==$proof.choice and .state=="CLOSED")]|length)}],
    indicator_classes:[$d.indicator_classes[] as $indicator | {class:$indicator.class,total:$indicator.total,
      closed:([$cells[]|select(.indicator_class==$indicator.class and .state=="CLOSED")]|length)}]
  }
' > "$output"
