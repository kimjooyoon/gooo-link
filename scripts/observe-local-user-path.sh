#!/usr/bin/env bash
set -euo pipefail

if test "$#" -ne 7; then
  echo "usage: observe-local-user-path.sh LINK_GRAPH DENOMINATOR BASELINE_DIR LOCAL_DIR OUTPUT SUBJECT_SHA SCENARIO" >&2
  exit 2
fi

link_graph=$1
denominator=$2
baseline_dir=$3
local_dir=$4
output=$5
subject_sha=$6
scenario=$7
baseline="$baseline_dir/report.json"
local_normal="$local_dir/projection-report.json"
local_unknown="$local_dir/projection-unknown.json"
local_refuted="$local_dir/projection-refuted.json"
local_runtime="$local_dir/projection-runtime.json"
local_graph="$local_dir/projection-graph.json"
local_replay="$local_dir/evidence/replay.json"
undeclared="$local_dir/evidence/counterexamples/undeclared.json"
duplicate="$local_dir/evidence/counterexamples/duplicate.json"

for file in "$link_graph" "$denominator" "$baseline" "$local_normal" "$local_unknown" "$local_refuted" "$local_runtime" "$local_graph" "$local_replay" "$undeclared" "$duplicate"; do
  test -f "$file" || { echo "missing local user-path evidence: $file" >&2; exit 2; }
done

jq -e '
  .schema=="gooo/link/local-user-path-observation-denominator/v1" and
  .candidate_id=="gooo.product.local-readiness-claim-projection.v1" and
  .target_cells==12 and (.cells|length)==12 and
  .planned_user_verticals_previous==0 and .planned_user_verticals_total==3 and
  .primitive_direct_mappings_expected==5 and .primitive_direct_mappings_total==30 and
  .independent_consumers_expected==4 and
  ([.proof_totals[].total]|add)==12 and ([.indicator_totals[].total]|add)==12
' "$denominator" >/dev/null

jq -e --slurpfile denominator "$denominator" '
  .schema_version=="gooo-graph/v1" and
  ([.nodes[]|select(.kind=="Activity")]|length)==12 and
  ([$denominator[0].cells[] as $cell |
    select(([.nodes[]|select(.kind=="Activity" and .name==$cell.activity)]|length)==1)
  ]|length)==12
' "$link_graph" >/dev/null

validate_baseline() {
  jq -e '
    .schema=="gooo/link/cross-consumer-primitive-adoption-report/v4" and
    .decision=="FIFTH_DIRECT_PRIMITIVE_MAPPING_OBSERVED" and
    .summary.total_cells==12 and .summary.closed_cells==12 and
    .summary.direct_mappings==5 and .summary.mapping_denominator==30 and .summary.mapping_remaining==25 and
    .summary.independent_consumer_adoptions==4 and .summary.repository_writes==0 and
    .summary.local_tests_run==0 and .summary.cross_project_required_gates==0
  ' "$1" >/dev/null
}

validate_local_normal() {
  jq -e '
    .schema=="gooo/local-ledger/readiness-claim-projection-report/v1" and
    .decision=="READINESS_CLAIM_PROJECTION_OBSERVED" and .claim.state=="CLOSED" and
    .summary.total_cells==12 and .summary.closed_cells==12 and
    .summary.source_readiness_reports_observed==3 and .summary.source_claim_fields_observed==15 and
    .summary.projected_claim_programs_observed==3 and .summary.projected_claim_receipts_observed==3 and
    .summary.projected_claim_fields_observed==18 and .summary.unknown_class_bindings_observed==1 and
    .summary.classification_entries_observed==12 and .summary.projection_counterexamples_rejected==2 and
    .summary.replay_comparisons_equal==9 and .summary.repository_writes==0 and
    .summary.local_tests_run==0 and .summary.cross_project_required_gates==0 and
    .authority.common_generator_authorized==false and .authority.central_orchestration_authorized==false
  ' "$1" >/dev/null
}

validate_local_unknown() {
  jq -e '
    .schema=="gooo/local-ledger/readiness-claim-projection-report/v1" and
    .decision=="READINESS_CLAIM_PROJECTION_UNKNOWN" and
    .summary.closed_cells==8 and .summary.unknown_cells==4 and .summary.refuted_cells==0 and
    .claim.state=="UNKNOWN" and .claim.stage=="CLAIM_RECEIPT" and
    .claim.step=="RESOLVE_UNKNOWN_READINESS_CLAIM" and
    .claim.reason=="PROJECTED_UNKNOWN_CLAIM_RECEIPT_UNAVAILABLE" and
    .claim.unknown_class=="DIRECT_MISSING" and .claim.next_operation=="RESOLVE_UNKNOWN_READINESS_CLAIM"
  ' "$local_unknown" >/dev/null
}

validate_local_refuted() {
  jq -e '
    .schema=="gooo/local-ledger/readiness-claim-projection-report/v1" and
    .decision=="FAIL_CLOSED" and .summary.closed_cells==8 and .summary.refuted_cells==4 and
    .claim.state=="REFUTED" and .claim.stage=="CLAIM_RECEIPT" and
    .claim.reason=="PROJECTED_UNKNOWN_CLAIM_TUPLE_MISMATCH" and
    .claim.next_operation=="RESTORE_UNKNOWN_CLAIM_PROJECTION"
  ' "$local_refuted" >/dev/null
}

validate_local_runtime() {
  jq -e '
    .schema=="gooo/local-ledger/readiness-claim-projection-runtime/v1" and
    .core_release_observed==true and .readiness_release_observed==true and
    .release_locks_observed==2 and .go_version=="go1.27.0" and .go_fix_module_roots==0 and
    .performance.peak_rss_kib>0 and .performance.wall_ms>=0 and
    .repository_writes==0 and .local_tests_run==0 and .cross_project_required_gates==0
  ' "$local_runtime" >/dev/null
}

validate_local_graph() {
  jq -e --slurpfile normal "$local_normal" '
    .schema_version=="gooo-graph/v1" and
    ([.nodes[]|select(.kind=="Activity")]|length)==12 and
    ([$normal[0].cells[] as $cell |
      select(([.nodes[]|select(.kind=="Activity" and .name==$cell.activity)]|length)==1)
    ]|length)==12
  ' "$1" >/dev/null
}

validate_regressions() {
  jq -e '.schema=="gooo/local-ledger/readiness-claim-projection-replay/v1" and .comparisons_total==9 and .comparisons_equal==9 and .deterministic==true' "$local_replay" >/dev/null
  jq -e '.decision=="FAIL_CLOSED" and .claim.reason=="UNKNOWN_COORDINATE_UNDECLARED" and .generated_claim_programs==0' "$undeclared" >/dev/null
  jq -e '.decision=="FAIL_CLOSED" and .claim.reason=="UNKNOWN_CLASSIFICATION_COORDINATE_DUPLICATED" and .generated_claim_programs==0' "$duplicate" >/dev/null
}

case "$scenario" in
  complete)
    validate_baseline "$baseline"
    validate_local_normal "$local_normal"
    validate_local_unknown
    validate_local_refuted
    validate_local_runtime
    validate_local_graph "$local_graph"
    validate_regressions
    ;;
  missing-local-report)
    validate_baseline "$baseline"
    jq -e '.==null' "$local_normal" >/dev/null
    validate_local_unknown
    validate_local_refuted
    validate_local_runtime
    validate_regressions
    ;;
  primitive-baseline-tamper)
    jq -e '.schema=="gooo/link/cross-consumer-primitive-adoption-report/v4" and .summary.direct_mappings==6 and .summary.mapping_denominator==30 and .summary.mapping_remaining==24' "$baseline" >/dev/null
    validate_local_normal "$local_normal"
    validate_local_unknown
    validate_local_refuted
    validate_local_runtime
    validate_local_graph "$local_graph"
    validate_regressions
    ;;
  local-metric-tamper)
    validate_baseline "$baseline"
    jq -e '.schema=="gooo/local-ledger/readiness-claim-projection-report/v1" and .summary.source_claim_fields_observed==14' "$local_normal" >/dev/null
    validate_local_unknown
    validate_local_refuted
    validate_local_runtime
    validate_regressions
    ;;
  missing-product-meta)
    validate_baseline "$baseline"
    validate_local_normal "$local_normal"
    validate_local_unknown
    validate_local_refuted
    validate_local_runtime
    jq -e '([.nodes[]|select(.kind=="Activity")]|length)==11 and ([.nodes[]|select(.name=="PublishReadinessResolutionReceipt")]|length)==0' "$local_graph" >/dev/null
    validate_regressions
    ;;
  scope-escalation)
    validate_baseline "$baseline"
    jq -e '.schema=="gooo/local-ledger/readiness-claim-projection-report/v1" and .authority.central_orchestration_authorized==true' "$local_normal" >/dev/null
    validate_local_unknown
    validate_local_refuted
    validate_local_runtime
    validate_regressions
    ;;
  *) echo "unsupported scenario: $scenario" >&2; exit 2;;
esac

digest() { printf 'sha256:%s' "$(sha256sum "$1" | awk '{print $1}')"; }

jq -S -n \
  --slurpfile denominator "$denominator" --slurpfile baseline "$baseline" \
  --slurpfile local_normal "$local_normal" --slurpfile local_unknown "$local_unknown" \
  --slurpfile local_refuted "$local_refuted" --slurpfile local_runtime "$local_runtime" \
  --slurpfile local_graph "$local_graph" \
  --arg subject_sha "$subject_sha" --arg scenario "$scenario" \
  --arg baseline_digest "$(digest "$baseline")" --arg local_digest "$(digest "$local_normal")" \
  --arg local_unknown_digest "$(digest "$local_unknown")" --arg local_refuted_digest "$(digest "$local_refuted")" \
  --arg local_runtime_digest "$(digest "$local_runtime")" --arg local_graph_digest "$(digest "$local_graph")" '
  $denominator[0] as $d |
  ($baseline[0] // {}) as $baseline |
  ($local_normal[0] // {}) as $local |
  ($local_runtime[0] // {}) as $runtime |
  [$d.cells[] | .id as $cell_id |
    {id,activity,proof_choice,indicator_class,state:"CLOSED",stage:null,step:null,
      reason:.closed_reason,unknown_class:null,next_operation:"NONE",blocked_by:[]} |
    if $scenario=="missing-local-report" and .id=="LOCAL_PROJECTION_CONFORMANCE" then
      .+{state:"UNKNOWN",stage:"PRODUCT_EVIDENCE",step:"OBSERVE_LOCAL_PROJECTION_CONFORMANCE",
        reason:"LOCAL_PROJECTION_REPORT_UNAVAILABLE",unknown_class:"DIRECT_MISSING",
        next_operation:"PUBLISH_LOCAL_PROJECTION_REPORT",blocked_by:["projection-report.json"]}
    elif $scenario=="missing-local-report" and (["CLAIM_FIELD_PROJECTION","GENERATED_GOOO_PROGRAMS","UNKNOWN_RESOLUTION","REFUTED_RESOLUTION","COUNTEREXAMPLE_AND_REPLAY","OPTIONAL_VERTICAL_PROGRESS"]|index($cell_id))!=null then
      .+{state:"UNKNOWN",stage:"DEPENDENCY",step:.activity,reason:"DEPENDENCY_EVIDENCE_UNAVAILABLE",
        unknown_class:"DEPENDENCY_BLOCKED",next_operation:"RESOLVE_LOCAL_PROJECTION_CONFORMANCE",
        blocked_by:["LOCAL_PROJECTION_CONFORMANCE"]}
    elif $scenario=="primitive-baseline-tamper" and .id=="PRIMITIVE_BASELINE_PRESERVED" then
      .+{state:"REFUTED",stage:"PRIMITIVE_BASELINE",step:"PRESERVE_FIVE_OF_THIRTY_PRIMITIVE_BASELINE",
        reason:"PRIMITIVE_MAPPING_COUNT_INFLATED",next_operation:"RESTORE_FIVE_OF_THIRTY_BASELINE",blocked_by:["report.json"]}
    elif $scenario=="primitive-baseline-tamper" and .id=="OPTIONAL_VERTICAL_PROGRESS" then
      .+{state:"REFUTED",stage:"DEPENDENCY",step:.activity,reason:"DEPENDENCY_REFUTED",
        next_operation:"RESTORE_PRIMITIVE_BASELINE",blocked_by:["PRIMITIVE_BASELINE_PRESERVED"]}
    elif $scenario=="local-metric-tamper" and .id=="CLAIM_FIELD_PROJECTION" then
      .+{state:"REFUTED",stage:"CLAIM_FIELDS",step:"OBSERVE_FIVE_TO_SIX_FIELD_PROJECTION",
        reason:"SOURCE_CLAIM_FIELD_COUNT_MISMATCH",next_operation:"RESTORE_LOCAL_PROJECTION_METRICS",blocked_by:["projection-report.json"]}
    elif $scenario=="local-metric-tamper" and .id=="OPTIONAL_VERTICAL_PROGRESS" then
      .+{state:"REFUTED",stage:"DEPENDENCY",step:.activity,reason:"DEPENDENCY_REFUTED",
        next_operation:"RESTORE_LOCAL_PROJECTION_METRICS",blocked_by:["CLAIM_FIELD_PROJECTION"]}
    elif $scenario=="missing-product-meta" and .id=="META_ACTIVITY_BINDINGS" then
      .+{state:"REFUTED",stage:"META",step:"BIND_LOCAL_AND_LINK_META_ACTIVITIES",
        reason:"LOCAL_META_ACTIVITY_BINDING_MISMATCH",next_operation:"RESTORE_LOCAL_META_ACTIVITY",blocked_by:["PublishReadinessResolutionReceipt"]}
    elif $scenario=="missing-product-meta" and .id=="OPTIONAL_VERTICAL_PROGRESS" then
      .+{state:"REFUTED",stage:"DEPENDENCY",step:.activity,reason:"DEPENDENCY_REFUTED",
        next_operation:"RESTORE_LOCAL_META_ACTIVITY",blocked_by:["META_ACTIVITY_BINDINGS"]}
    elif $scenario=="scope-escalation" and .id=="OPTIONAL_VERTICAL_PROGRESS" then
      .+{state:"REFUTED",stage:"AUTHORITY",step:"RECORD_OPTIONAL_LOCAL_VERTICAL_PROGRESS",
        reason:"CENTRAL_ORCHESTRATION_AUTHORITY_ESCALATED",next_operation:"REMOVE_CENTRAL_ORCHESTRATION_AUTHORITY",blocked_by:["projection-report.json"]}
    else . end
  ] as $cells |
  ([$cells[]|select(.state=="CLOSED")]|length) as $closed |
  ([$cells[]|select(.state=="UNKNOWN")]|length) as $unknown_count |
  ([$cells[]|select(.state=="REFUTED")]|length) as $refuted_count |
  (([$cells[]|select(.state=="REFUTED")][0]) // ([$cells[]|select(.state=="UNKNOWN")][0])) as $first |
  (if $scenario=="complete" then 1 else 0 end) as $new_vertical |
  {
    schema:"gooo/link/local-user-path-observation-report/v1",scenario:$scenario,subject_sha:$subject_sha,
    decision:(if $refuted_count>0 then "FAIL_CLOSED" elif $unknown_count>0 then "LOCAL_USER_PATH_OBSERVATION_UNKNOWN" else "LOCAL_USER_PATH_OBSERVED" end),
    candidate:{id:$d.candidate_id,state:(if $refuted_count>0 then "REFUTED" elif $unknown_count>0 then "UNKNOWN" else "OBSERVED" end)},
    claim:(if $first==null then {state:"CLOSED",stage:null,step:null,reason:"LOCAL_USER_PATH_OBSERVED",unknown_class:null,next_operation:"OBSERVE_DESIGN_USER_PATH_PROJECTION",blocked_by:[]}
      else {state:$first.state,stage:$first.stage,step:$first.step,reason:$first.reason,unknown_class:$first.unknown_class,next_operation:$first.next_operation,blocked_by:$first.blocked_by} end),
    summary:{total_cells:12,closed_cells:$closed,unknown_cells:$unknown_count,refuted_cells:$refuted_count,
      planned_user_verticals_observed:($d.planned_user_verticals_previous+$new_vertical),planned_user_verticals_total:$d.planned_user_verticals_total,
      primitive_direct_mappings:($baseline.summary.direct_mappings//0),primitive_direct_mappings_total:$d.primitive_direct_mappings_total,
      primitive_mapping_increment:0,independent_consumers:($baseline.summary.independent_consumer_adoptions//0),
      local_projection_cells:($local.summary.closed_cells//0),source_claim_fields:($local.summary.source_claim_fields_observed//0),
      projected_claim_fields:($local.summary.projected_claim_fields_observed//0),generated_gooo_programs:($local.summary.projected_claim_programs_observed//0),
      projection_counterexamples:($local.summary.projection_counterexamples_rejected//0),replay_comparisons:($local.summary.replay_comparisons_equal//0),
      local_meta_activities:([$local_graph[0].nodes[]?|select(.kind=="Activity")]|length),link_meta_activities:12,
      repository_writes:($runtime.repository_writes//null),local_tests_run:($runtime.local_tests_run//null),cross_project_required_gates:($runtime.cross_project_required_gates//null)},
    progress:{planned_user_verticals_previous:$d.planned_user_verticals_previous,new_user_verticals_observed:$new_vertical,
      planned_user_verticals_observed:($d.planned_user_verticals_previous+$new_vertical),planned_user_verticals_total:$d.planned_user_verticals_total,
      primitive_mapping_previous:5,primitive_mapping_increment:0,primitive_mapping_current:5,primitive_mapping_total:30,
      independent_consumers:4},
    authority:{observation_scope:"LOCAL_USER_PATH_ONLY",product_release_independence_required:true,
      root_readme_readiness:"EXCLUDED",common_generator_authorized:false,central_orchestration_authorized:false,
      source_repository_writes:0,cross_project_required_gates:0},
    local_inventory:($runtime.inventory//{}),local_performance:($runtime.performance//{}),
    evidence:{baseline_digest:$baseline_digest,local_report_digest:$local_digest,local_unknown_digest:$local_unknown_digest,
      local_refuted_digest:$local_refuted_digest,local_runtime_digest:$local_runtime_digest,local_graph_digest:$local_graph_digest},
    cells:$cells,
    proofs:(["FOUNDATION","COHERENCE","REGRESSION"]|map(. as $proof|{choice:$proof,closed:([$cells[]|select(.proof_choice==$proof and .state=="CLOSED")]|length),total:4})),
    indicator_classes:(["DRIVER","OUTCOME","GUARDRAIL"]|map(. as $class|{class:$class,closed:([$cells[]|select(.indicator_class==$class and .state=="CLOSED")]|length),total:4})),
    indicators:[
      {id:"gooo.metric.link.user-verticals.v1",value:($d.planned_user_verticals_previous+$new_vertical),total:3,unit:"verticals",activity:"RecordOptionalLocalVerticalProgress"},
      {id:"gooo.metric.link.primitive-mappings-preserved.v1",value:($baseline.summary.direct_mappings//0),total:30,unit:"mappings",activity:"PreserveFiveOfThirtyPrimitiveBaseline"},
      {id:"gooo.metric.link.primitive-mapping-increment.v1",value:0,total:0,unit:"mappings",activity:"PreserveFiveOfThirtyPrimitiveBaseline"},
      {id:"gooo.metric.link.local-projection-cells.v1",value:($local.summary.closed_cells//0),total:12,unit:"cells",activity:"ObserveLocalProjectionConformance"},
      {id:"gooo.metric.link.local-claim-fields.v1",value:($local.summary.projected_claim_fields_observed//0),total:18,unit:"fields",activity:"ObserveFiveToSixFieldProjection"},
      {id:"gooo.metric.link.local-generated-gooo-programs.v1",value:($local.summary.projected_claim_programs_observed//0),total:3,unit:"programs",activity:"ObserveGeneratedGoooClaimPrograms"},
      {id:"gooo.metric.link.local-replay.v1",value:($local.summary.replay_comparisons_equal//0),total:9,unit:"comparisons",activity:"ObserveProjectionCounterexamplesAndReplay"}
    ]
  }
' > "$output"
