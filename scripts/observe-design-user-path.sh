#!/usr/bin/env bash
set -euo pipefail

if test "$#" -ne 8; then
  echo "usage: observe-design-user-path.sh LINK_GRAPH DESIGN_GRAPH DENOMINATOR BASELINE_DIR DESIGN_DIR OUTPUT SUBJECT_SHA SCENARIO" >&2
  exit 2
fi

link_graph=$1
design_graph=$2
denominator=$3
baseline_dir=$4
design_dir=$5
output=$6
subject_sha=$7
scenario=$8

baseline="$baseline_dir/local-user-path-report.json"
design_conformance="$design_dir/design-review-conformance.json"
design_packet="$design_dir/design-review-packet.json"
design_unknown="$design_dir/design-review-unknown.json"
design_tuple_refuted="$design_dir/design-review-tuple-refuted.json"
design_mismatch_refuted="$design_dir/design-review-mismatch-refuted.json"
design_authority_refuted="$design_dir/design-review-authority-refuted.json"
design_runtime="$design_dir/design-review-runtime.json"

for file in "$link_graph" "$design_graph" "$denominator" "$baseline" "$design_conformance" "$design_packet" \
  "$design_unknown" "$design_tuple_refuted" "$design_mismatch_refuted" "$design_authority_refuted" "$design_runtime"; do
  test -f "$file" || { echo "missing design user-path evidence: $file" >&2; exit 2; }
done

case "$scenario" in
  complete|missing-design-report|primitive-baseline-tamper|design-metric-tamper|missing-design-meta|authority-escalation) ;;
  *) echo "unsupported design user-path scenario: $scenario" >&2; exit 2 ;;
esac

jq -e '
  .schema=="gooo/link/design-user-path-observation-denominator/v1" and
  .candidate_id=="gooo.product.design-release-review-packet.v1" and
  .total==15 and (.cells|length)==15 and
  ([.proofs[].total]|add)==15 and ([.indicator_classes[].total]|add)==15
' "$denominator" >/dev/null

jq -e --slurpfile denominator "$denominator" '
  . as $graph |
  .schema_version=="gooo-graph/v1" and
  ([$graph.nodes[]|select(.kind=="Activity")]|length)==15 and
  ([$denominator[0].cells[] as $cell |
    select(([$graph.nodes[]|select(.kind=="Activity" and .name==$cell.activity)]|length)==1)
  ]|length)==15
' "$link_graph" >/dev/null

validate_design_graph() {
  local missing=$1
  jq -e --arg missing "$missing" '
    def expected: [
      "BindReviewAuthority","ObserveCoreClaimResolutionRelease","ObserveReleasedMatcherEvidence",
      "ObserveReleasedClaimReceipts","ObserveReviewRequest","ProjectRelationDispositions",
      "ProjectClaimTupleLedger","GenerateMachineReviewPacket","GenerateHumanReviewPacket",
      "ResolveReviewReadyClaim","PreserveMissingMatcherUnknown","RefuteClaimTupleMismatch",
      "RefuteUnreviewedMismatch","RefuteAuthorityEscalation","ObserveReviewRuntime"
    ];
    .schema_version=="gooo-graph/v1" and
    ([.nodes[]|select(.kind=="Activity")|.name]|sort)==
      ((expected|map(select(.!=$missing)))|sort)
  ' "$design_graph" >/dev/null
}

validate_baseline() {
  if test "$scenario" = primitive-baseline-tamper; then
    jq -e '
      .schema=="gooo/link/local-user-path-observation-report/v1" and
      .decision=="LOCAL_USER_PATH_OBSERVED" and .summary.closed_cells==12 and
      .summary.planned_user_verticals_observed==1 and .summary.planned_user_verticals_total==3 and
      .summary.primitive_direct_mappings==6 and .summary.primitive_direct_mappings_total==30 and
      .summary.independent_consumers==4 and .summary.repository_writes==0 and
      .summary.local_tests_run==0 and .summary.cross_project_required_gates==0
    ' "$baseline" >/dev/null
  else
    jq -e '
      .schema=="gooo/link/local-user-path-observation-report/v1" and
      .decision=="LOCAL_USER_PATH_OBSERVED" and .summary.closed_cells==12 and
      .summary.planned_user_verticals_observed==1 and .summary.planned_user_verticals_total==3 and
      .summary.primitive_direct_mappings==5 and .summary.primitive_direct_mappings_total==30 and
      .summary.primitive_mapping_increment==0 and .summary.independent_consumers==4 and
      .summary.repository_writes==0 and .summary.local_tests_run==0 and
      .summary.cross_project_required_gates==0
    ' "$baseline" >/dev/null
  fi
}

validate_design_conformance() {
  if test "$scenario" = missing-design-report; then
    jq -e '.==null' "$design_conformance" >/dev/null
    return
  fi
  local artifacts=2
  if test "$scenario" = design-metric-tamper; then artifacts=1; fi
  jq -e --argjson artifacts "$artifacts" '
    .schema=="gooo/design-evidence/review-packet-conformance/v1" and
    .decision=="DESIGN_RELEASE_REVIEW_PACKET_CONFORMANT" and .summary.total_cells==15 and
    .summary.closed_cells==15 and .summary.release_inputs_observed==3 and
    .summary.review_requests_observed==1 and .summary.relation_dispositions_observed==4 and
    .summary.claim_tuples_observed==4 and .summary.claim_fields_observed==24 and
    .summary.meta_decision_receipts_observed==5 and .summary.meta_decision_fields_observed==30 and
    .summary.generated_artifacts_observed==$artifacts and .summary.generated_artifacts_total==2 and
    .summary.counterexamples_observed==4 and .summary.replay_comparisons_equal==2 and
    .summary.repository_writes==0 and .summary.local_tests_run==0 and
    .summary.cross_project_required_gates==0
  ' "$design_conformance" >/dev/null
}

validate_design_packet() {
  local central=false
  if test "$scenario" = authority-escalation; then central=true; fi
  jq -e --argjson central "$central" '
    .schema=="gooo/design-evidence/review-packet/v1" and .scenario=="complete" and
    .decision=="DESIGN_RELEASE_REVIEW_PACKET_GENERATED" and .claim.state=="CLOSED" and
    .request.component=="Button" and .summary.closed_cells==15 and
    .summary.relation_dispositions_observed==4 and .summary.claim_tuples_observed==4 and
    .summary.generated_artifacts_observed==2 and .summary.publishable_artifacts==2 and
    .summary.reviewed_mismatches==1 and .summary.unresolved_mismatches==0 and
    .authority.automatic_merge_authorized==false and
    .authority.repository_writes_authorized==false and
    .authority.central_orchestration_authorized==$central
  ' "$design_packet" >/dev/null
}

validate_design_adverse() {
  jq -e '
    .scenario=="missing-matcher-report" and .decision=="DESIGN_RELEASE_REVIEW_UNKNOWN" and
    .claim.state=="UNKNOWN" and .claim.stage=="RELEASE_EVIDENCE" and
    .claim.reason=="MATCHER_RELEASE_REPORT_UNAVAILABLE" and .claim.unknown_class=="DIRECT_MISSING" and
    .claim.next_operation=="RESTORE_MATCHER_RELEASE_REPORT" and
    .summary.closed_cells==10 and .summary.unknown_cells==5 and .summary.publishable_artifacts==0
  ' "$design_unknown" >/dev/null
  jq -e '
    .scenario=="claim-tuple-tamper" and .decision=="FAIL_CLOSED" and .claim.state=="REFUTED" and
    .claim.reason=="RELEASED_CLAIM_TUPLE_MISMATCH" and .summary.closed_cells==11 and .summary.refuted_cells==4
  ' "$design_tuple_refuted" >/dev/null
  jq -e '
    .scenario=="unreviewed-mismatch" and .decision=="FAIL_CLOSED" and .claim.state=="REFUTED" and
    .claim.reason=="UNREVIEWED_DESIGN_MISMATCH" and .summary.closed_cells==11 and .summary.refuted_cells==4
  ' "$design_mismatch_refuted" >/dev/null
  jq -e '
    .scenario=="authority-escalation" and .decision=="FAIL_CLOSED" and .claim.state=="REFUTED" and
    .claim.reason=="AUTOMATIC_MERGE_AUTHORITY_ESCALATED" and .summary.closed_cells==13 and .summary.refuted_cells==2
  ' "$design_authority_refuted" >/dev/null
}

validate_design_runtime() {
  jq -e '
    .schema=="gooo/design-evidence/review-packet-runtime/v1" and .go_version=="go1.27.0" and
    .go_fix_module_roots==0 and .decision_receipts_equal==5 and .replay_comparisons_equal==2 and
    .inventory.root_readme_excluded==true and .inventory.repository_files==57 and
    .inventory.descendant_directories==16 and .inventory.go.files==0 and .inventory.go.physical_lines==0 and
    .inventory.gooo.files==6 and .inventory.gooo.physical_lines==172 and
    .peak_rss_kib==4216 and .wall_ms==614 and .repository_writes==0 and
    .local_tests_run==0 and .cross_project_required_gates==0
  ' "$design_runtime" >/dev/null
}

validate_baseline
validate_design_conformance
validate_design_packet
validate_design_adverse
validate_design_runtime
if test "$scenario" = missing-design-meta; then validate_design_graph GenerateHumanReviewPacket; else validate_design_graph NONE; fi

digest() {
  printf 'sha256:%s' "$(sha256sum "$1" | awk '{print $1}')"
}

jq -S -n \
  --slurpfile denominator "$denominator" --slurpfile baseline "$baseline" \
  --slurpfile design_conformance "$design_conformance" --slurpfile design_packet "$design_packet" \
  --slurpfile design_unknown "$design_unknown" --slurpfile design_tuple_refuted "$design_tuple_refuted" \
  --slurpfile design_mismatch_refuted "$design_mismatch_refuted" \
  --slurpfile design_authority_refuted "$design_authority_refuted" --slurpfile design_runtime "$design_runtime" \
  --arg scenario "$scenario" --arg subject_sha "$subject_sha" \
  --arg link_graph_digest "$(digest "$link_graph")" --arg design_graph_digest "$(digest "$design_graph")" \
  --arg denominator_digest "$(digest "$denominator")" --arg baseline_digest "$(digest "$baseline")" \
  --arg design_conformance_digest "$(digest "$design_conformance")" --arg design_packet_digest "$(digest "$design_packet")" \
  --arg design_unknown_digest "$(digest "$design_unknown")" \
  --arg design_tuple_refuted_digest "$(digest "$design_tuple_refuted")" \
  --arg design_mismatch_refuted_digest "$(digest "$design_mismatch_refuted")" \
  --arg design_authority_refuted_digest "$(digest "$design_authority_refuted")" \
  --arg design_runtime_digest "$(digest "$design_runtime")" '
  $denominator[0] as $d | $baseline[0] as $baseline |
  ($design_conformance[0] // {}) as $design | $design_packet[0] as $packet | $design_runtime[0] as $runtime |
  [$d.cells[] | .id as $cell_id |
    {id,activity,proof_choice,indicator_class,state:"CLOSED",stage:null,step:null,
      reason:.closed_reason,unknown_class:null,next_operation:"NONE",blocked_by:[]} |
    if $scenario=="missing-design-report" and $cell_id=="DESIGN_REVIEW_CONFORMANCE" then
      .+{state:"UNKNOWN",stage:"PRODUCT_EVIDENCE",step:"OBSERVE_DESIGN_REVIEW_CONFORMANCE",
        reason:"DESIGN_CONFORMANCE_REPORT_UNAVAILABLE",unknown_class:"DIRECT_MISSING",
        next_operation:"RESTORE_DESIGN_CONFORMANCE_REPORT",blocked_by:["design-review-conformance.json"]}
    elif $scenario=="missing-design-report" and (["REVIEW_REQUEST_RELATIONS","CLAIM_TUPLE_LEDGER","GENERATED_REVIEW_ARTIFACTS","SECOND_USER_VERTICAL"]|index($cell_id))!=null then
      .+{state:"UNKNOWN",stage:"DEPENDENCY",step:.activity,reason:"DEPENDENCY_EVIDENCE_UNAVAILABLE",
        unknown_class:"DEPENDENCY_BLOCKED",next_operation:"RESTORE_DESIGN_CONFORMANCE_REPORT",
        blocked_by:["DESIGN_REVIEW_CONFORMANCE"]}
    elif $scenario=="primitive-baseline-tamper" and $cell_id=="PRIMITIVE_BASELINE_PRESERVED" then
      .+{state:"REFUTED",stage:"PRIMITIVE_BASELINE",step:"PRESERVE_PRIMITIVE_BASELINE",
        reason:"PRIMITIVE_MAPPING_COUNT_INFLATED",next_operation:"RESTORE_FIVE_OF_THIRTY_BASELINE",
        blocked_by:["local-user-path-report.json"]}
    elif $scenario=="primitive-baseline-tamper" and $cell_id=="SECOND_USER_VERTICAL" then
      .+{state:"REFUTED",stage:"DEPENDENCY",step:"RECORD_SECOND_USER_VERTICAL",reason:"DEPENDENCY_REFUTED",
        next_operation:"RESTORE_FIVE_OF_THIRTY_BASELINE",blocked_by:["PRIMITIVE_BASELINE_PRESERVED"]}
    elif $scenario=="design-metric-tamper" and $cell_id=="GENERATED_REVIEW_ARTIFACTS" then
      .+{state:"REFUTED",stage:"DESIGN_OUTPUTS",step:"OBSERVE_GENERATED_REVIEW_ARTIFACTS",
        reason:"GENERATED_REVIEW_ARTIFACT_COUNT_MISMATCH",next_operation:"RESTORE_DESIGN_REVIEW_METRICS",
        blocked_by:["design-review-conformance.json"]}
    elif $scenario=="design-metric-tamper" and $cell_id=="SECOND_USER_VERTICAL" then
      .+{state:"REFUTED",stage:"DEPENDENCY",step:"RECORD_SECOND_USER_VERTICAL",reason:"DEPENDENCY_REFUTED",
        next_operation:"RESTORE_DESIGN_REVIEW_METRICS",blocked_by:["GENERATED_REVIEW_ARTIFACTS"]}
    elif $scenario=="missing-design-meta" and $cell_id=="DESIGN_META_BINDINGS" then
      .+{state:"REFUTED",stage:"META",step:"OBSERVE_DESIGN_META_BINDINGS",
        reason:"DESIGN_META_ACTIVITY_BINDING_MISMATCH",next_operation:"RESTORE_DESIGN_META_ACTIVITY",
        blocked_by:["GenerateHumanReviewPacket"]}
    elif $scenario=="missing-design-meta" and $cell_id=="SECOND_USER_VERTICAL" then
      .+{state:"REFUTED",stage:"DEPENDENCY",step:"RECORD_SECOND_USER_VERTICAL",reason:"DEPENDENCY_REFUTED",
        next_operation:"RESTORE_DESIGN_META_ACTIVITY",blocked_by:["DESIGN_META_BINDINGS"]}
    elif $scenario=="authority-escalation" and $cell_id=="OPTIONAL_AUTHORITY_BOUND" then
      .+{state:"REFUTED",stage:"AUTHORITY",step:"BIND_OPTIONAL_DESIGN_OBSERVATION",
        reason:"CENTRAL_ORCHESTRATION_AUTHORITY_ESCALATED",next_operation:"REMOVE_CENTRAL_ORCHESTRATION_AUTHORITY",
        blocked_by:["design-review-packet.json"]}
    elif $scenario=="authority-escalation" and $cell_id=="SECOND_USER_VERTICAL" then
      .+{state:"REFUTED",stage:"DEPENDENCY",step:"RECORD_SECOND_USER_VERTICAL",reason:"DEPENDENCY_REFUTED",
        next_operation:"REMOVE_CENTRAL_ORCHESTRATION_AUTHORITY",blocked_by:["OPTIONAL_AUTHORITY_BOUND"]}
    else . end
  ] as $cells |
  ([$cells[]|select(.state=="CLOSED")]|length) as $closed |
  ([$cells[]|select(.state=="UNKNOWN")]|length) as $unknown_count |
  ([$cells[]|select(.state=="REFUTED")]|length) as $refuted_count |
  (if $scenario=="complete" then 1 else 0 end) as $new_vertical |
  (if $scenario=="missing-design-report" then 0 else 15 end) as $design_cells |
  (if $scenario=="missing-design-report" then 0 else 4 end) as $relations |
  (if $scenario=="missing-design-report" then 0 else 4 end) as $claims |
  (if $scenario=="missing-design-report" or $scenario=="design-metric-tamper" then
    (if $scenario=="design-metric-tamper" then 1 else 0 end) else 2 end) as $artifacts |
  (if $scenario=="missing-design-report" then ["design-review-conformance.json"]
    elif $scenario=="primitive-baseline-tamper" then ["local-user-path-report.json"]
    elif $scenario=="design-metric-tamper" then ["design-review-conformance.json"]
    elif $scenario=="missing-design-meta" then ["GenerateHumanReviewPacket"]
    elif $scenario=="authority-escalation" then ["design-review-packet.json"] else [] end) as $blocked_by |
  {
    schema:"gooo/link/design-user-path-observation-report/v1",scenario:$scenario,subject_sha:$subject_sha,
    decision:(if $refuted_count>0 then "FAIL_CLOSED" elif $unknown_count>0 then "DESIGN_USER_PATH_OBSERVATION_UNKNOWN" else "DESIGN_USER_PATH_OBSERVED" end),
    candidate:{id:$d.candidate_id,state:(if $refuted_count>0 then "REFUTED" elif $unknown_count>0 then "UNKNOWN" else "OBSERVED" end)},
    claim:(if $refuted_count>0 then
      (([$cells[]|select(.state=="REFUTED" and .reason!="DEPENDENCY_REFUTED")][0]) //
       ([$cells[]|select(.state=="REFUTED")][0])|{state,stage,step,reason,unknown_class,next_operation})+{blocked_by:$blocked_by}
      elif $unknown_count>0 then
      ([$cells[]|select(.state=="UNKNOWN")][0]|{state,stage,step,reason,unknown_class,next_operation})+{blocked_by:$blocked_by}
      else {state:"CLOSED",stage:null,step:null,reason:"DESIGN_USER_PATH_OBSERVED",unknown_class:null,next_operation:"NONE",blocked_by:[]} end),
    summary:{total_cells:15,closed_cells:$closed,unknown_cells:$unknown_count,refuted_cells:$refuted_count,
      planned_user_verticals_previous:1,planned_user_verticals_observed:(1+$new_vertical),planned_user_verticals_total:3,
      primitive_direct_mappings:$baseline.summary.primitive_direct_mappings,
      primitive_direct_mappings_total:30,primitive_mapping_increment:0,independent_consumers:4,
      design_conformance_cells:$design_cells,design_conformance_cells_total:15,
      design_release_inputs:(if $scenario=="missing-design-report" then 2 else 3 end),design_release_inputs_total:3,
      design_review_requests:(if $scenario=="missing-design-report" then 0 else 1 end),design_review_requests_total:1,
      design_relation_dispositions:$relations,design_relation_dispositions_total:4,
      design_claim_tuples:$claims,design_claim_tuples_total:4,
      design_claim_fields:($claims*6),design_claim_fields_total:24,
      design_meta_decision_receipts:(if $scenario=="missing-design-report" then 0 else 5 end),design_meta_decision_receipts_total:5,
      design_generated_artifacts:$artifacts,design_generated_artifacts_total:2,
      design_counterexamples:4,design_counterexamples_total:4,
      design_replay_comparisons:2,design_replay_comparisons_total:2,
      repository_writes:0,local_tests_run:0,cross_project_required_gates:0},
    design_inventory:$runtime.inventory,design_performance:{peak_rss_kib:$runtime.peak_rss_kib,wall_ms:$runtime.wall_ms},
    authority:{meta_source:"examples/design-user-path-observation/main.gooo",observation_mode:"RELEASED_EVIDENCE_ONLY",
      core_mutation_authorized:false,design_mutation_authorized:false,link_baseline_mutation_authorized:false,
      automatic_merge_authorized:false,central_orchestration_authorized:$packet.authority.central_orchestration_authorized,
      cross_project_required_gates:0},
    evidence:{link_graph_digest:$link_graph_digest,design_graph_digest:$design_graph_digest,
      denominator_digest:$denominator_digest,baseline_digest:$baseline_digest,
      design_conformance_digest:$design_conformance_digest,design_packet_digest:$design_packet_digest,
      design_unknown_digest:$design_unknown_digest,design_tuple_refuted_digest:$design_tuple_refuted_digest,
      design_mismatch_refuted_digest:$design_mismatch_refuted_digest,
      design_authority_refuted_digest:$design_authority_refuted_digest,design_runtime_digest:$design_runtime_digest},
    cells:$cells,
    proofs:[$d.proofs[] as $proof|{choice:$proof.choice,total:$proof.total,
      closed:([$cells[]|select(.proof_choice==$proof.choice and .state=="CLOSED")]|length)}],
    indicator_classes:[$d.indicator_classes[] as $class|{class:$class.class,total:$class.total,
      closed:([$cells[]|select(.indicator_class==$class.class and .state=="CLOSED")]|length)}],
    indicators:[
      {id:"gooo.metric.link.user-verticals.v1",class:"OUTCOME",value:(1+$new_vertical),total:3,unit:"verticals",activity:"RecordSecondUserVertical"},
      {id:"gooo.metric.link.primitive-mappings-preserved.v1",class:"GUARDRAIL",value:$baseline.summary.primitive_direct_mappings,total:30,unit:"mappings",activity:"PreservePrimitiveBaseline"},
      {id:"gooo.metric.link.primitive-mapping-increment.v1",class:"GUARDRAIL",value:0,total:0,unit:"mappings",activity:"PreservePrimitiveBaseline"},
      {id:"gooo.metric.link.design-conformance-cells.v1",class:"OUTCOME",value:$design_cells,total:15,unit:"cells",activity:"ObserveDesignReviewConformance"},
      {id:"gooo.metric.link.design-relations.v1",class:"OUTCOME",value:$relations,total:4,unit:"relations",activity:"ObserveReviewRequestAndRelations"},
      {id:"gooo.metric.link.design-claim-tuples.v1",class:"OUTCOME",value:$claims,total:4,unit:"tuples",activity:"ObserveClaimTupleLedger"},
      {id:"gooo.metric.link.design-generated-artifacts.v1",class:"OUTCOME",value:$artifacts,total:2,unit:"artifacts",activity:"ObserveGeneratedReviewArtifacts"},
      {id:"gooo.metric.link.repository-writes.v1",class:"GUARDRAIL",value:0,total:0,unit:"writes",activity:"ObserveDesignObservationRuntime"}
    ]
  }
' > "$output"
