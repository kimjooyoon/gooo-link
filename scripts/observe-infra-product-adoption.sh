#!/usr/bin/env bash
set -euo pipefail

if test "$#" -ne 15; then
  echo "usage: observe-infra-product-adoption.sh LINK_GRAPH DENOMINATOR REPORT REPLAY HCL_RECEIPT TOOLCHAIN PRODUCT_GRAPH MISSING_HCL CONTEXT_HCL INVALID_HCL MISMATCHED_HCL DEPLOYMENT_DRIFT OUTPUT SUBJECT_SHA SCENARIO" >&2
  exit 2
fi

link_graph=$1
denominator=$2
report=$3
replay=$4
hcl_receipt=$5
toolchain=$6
product_graph=$7
missing_hcl=$8
context_hcl=$9
invalid_hcl=${10}
mismatched_hcl=${11}
deployment_drift=${12}
output=${13}
subject_sha=${14}
scenario=${15}

for file in "$link_graph" "$denominator" "$report" "$replay" "$hcl_receipt" "$toolchain" "$product_graph" "$missing_hcl" "$context_hcl" "$invalid_hcl" "$mismatched_hcl" "$deployment_drift"; do
  test -f "$file" || { echo "missing required input: $file" >&2; exit 2; }
done

jq -e '
  .schema=="gooo/link-infra-product-adoption-denominator/v1" and
  .candidate_id=="gooo.product.infra-service-evidence-linker.v1" and
  .total==12 and .portfolio_previous==2 and .portfolio_total==3 and
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

validate_report() {
  jq -e '
    .schema=="gooo/infra-evidence/report/v2" and
    .decision=="EVIDENCE_CHAIN_CLOSED" and .claim.state=="CLOSED" and
    .claim.reason=="INFRA_SERVICE_SYMBOL_EVIDENCE_CHAIN_CLOSED" and
    .subject_sha=="bbe32a92bf40d1e4f290a911eb4756a6018c1a6d" and
    .summary=={closed:12,dependency_blocked:0,direct_missing:0,refuted:0,repository_writes:0,total:12,unknown:0} and
    .authority.binding=="RELEASED_GOOO_ACTIVITY_RESOLUTION_RECEIPTS" and
    .authority.core_activity_receipts==12 and .authority.core_activity_total==12 and
    .authority.terraform_declaration_parser=="HASHICORP_HCL_V2" and
    .authority.terraform_parser_version=="v2.24.0" and
    .authority.terraform_execution=="NOT_CLAIMED" and
    .authority.deployment_execution=="NOT_CLAIMED" and
    .authority.live_cloud_state=="NOT_CLAIMED" and .authority.live_network_probe=="NOT_CLAIMED" and
    ([.proofs[]|select((.choice=="FOUNDATION" and .closed==4 and .total==4) or
      (.choice=="COHERENCE" and .closed==6 and .total==6) or
      (.choice=="REGRESSION" and .closed==2 and .total==2))]|length)==3 and
    ([.indicator_classes[]|select(.closed==.total)]|length)==3 and
    (.indicators[]|select(.id=="gooo.metric.infra-evidence.semantic-edges.v2")|.value==6 and .total==6) and
    (.indicators[]|select(.id=="gooo.metric.infra-evidence.hcl-resource-bindings.v2")|.value==1 and .total==1) and
    (.indicators[]|select(.id=="gooo.metric.infra-evidence.repository-writes.v2")|.value==0) and
    (.indicators[]|select(.id=="gooo.metric.infra-evidence.graph-peak-rss.v2")|.value>0) and
    (.indicators[]|select(.id=="gooo.metric.infra-evidence.hcl-parser-peak-rss.v2")|.value>0)
  ' "$1" >/dev/null
}

validate_hcl_receipt() {
  jq -e '
    .schema=="gooo/infra-evidence/hcl-declaration-receipt/v1" and
    .decision=="CLOSED" and .claim.state=="CLOSED" and
    .claim.reason=="HCL_TERRAFORM_DECLARATION_BOUND" and
    .subject.project_id=="checkout://service/v2" and
    .subject.source_file=="terraform/main.tf" and
    .binding.resource_address=="example_service.checkout" and
    .binding.target=="prod/checkout" and
    .counts.resource_block_occurrences==1 and
    .counts.target_attribute_occurrences==1 and
    .counts.image_digest_attribute_occurrences==1 and .counts.parser_diagnostics==0 and
    .authority.go_toolchain=="go1.27.0" and
    .authority.parser_module=="github.com/hashicorp/hcl/v2" and
    .authority.parser_version=="v2.24.0" and
    .authority.parser_api=="hclsyntax.ParseConfig" and
    .authority.source_mutation=="NONE" and .authority.terraform_execution=="NOT_USED"
  ' "$1" >/dev/null
}

validate_toolchain() {
  jq -e '
    .schema=="gooo/infra-evidence/go-toolchain/v1" and .version=="go1.27.0" and
    .gofmt_changes==0 and .fix_changes==0 and .vet_findings==0 and
    .hcl_parser.module=="github.com/hashicorp/hcl/v2" and
    .hcl_parser.version=="v2.24.0" and .hcl_parser.parser_api=="hclsyntax.ParseConfig"
  ' "$1" >/dev/null
}

validate_product_graph() {
  jq -e '
    .activity_resolution_observation.schema=="gooo/evidence-generator/activity-resolution-observation/v1" and
    .activity_resolution_observation.role=="project_graph" and
    .activity_resolution_observation.summary=={closed:12,expected:12,observed:12,refuted:0,unique_selectors:12,unknown:0} and
    (.activity_resolution_observation.entries|length)==12 and
    all(.activity_resolution_observation.entries[];
      .receipt.decision=="CLOSED" and .receipt.occurrences==1 and .receipt.claim.state=="CLOSED")
  ' "$1" >/dev/null
}

validate_unknowns() {
  jq -e '
    .schema=="gooo/infra-evidence/report/v2" and .decision=="INCOMPLETE" and
    .claim.state=="UNKNOWN" and .claim.stage=="INFRA_DECLARATION" and
    .claim.step=="PARSE_HCL_TERRAFORM_DECLARATION" and
    .claim.reason=="HCL_TERRAFORM_DECLARATION_UNAVAILABLE" and
    .claim.unknown_class=="DIRECT_MISSING" and
    .summary.closed==6 and .summary.unknown==6 and
    .summary.direct_missing==1 and .summary.dependency_blocked==5
  ' "$missing_hcl" >/dev/null
  jq -e '
    .schema=="gooo/infra-evidence/report/v2" and .decision=="INCOMPLETE" and
    .claim.state=="UNKNOWN" and .claim.reason=="HCL_RESOURCE_VALUE_UNRESOLVED" and
    .claim.unknown_class=="CONTEXT_MISSING" and
    .summary.closed==6 and .summary.unknown==6 and
    .summary.direct_missing==0 and .summary.dependency_blocked==5
  ' "$context_hcl" >/dev/null
}

validate_refutations() {
  jq -e '.decision=="FAIL_CLOSED" and .claim.state=="REFUTED" and .claim.reason=="HCL_TERRAFORM_DECLARATION_INVALID" and .summary.closed==6 and .summary.refuted==6' "$invalid_hcl" >/dev/null
  jq -e '.decision=="FAIL_CLOSED" and .claim.state=="REFUTED" and .claim.reason=="HCL_RESOURCE_VALUE_MISMATCH" and .summary.closed==6 and .summary.refuted==6' "$mismatched_hcl" >/dev/null
  jq -e '.decision=="FAIL_CLOSED" and .claim.state=="REFUTED" and .claim.reason=="ARTIFACT_IDENTITY_MISMATCH" and .summary.closed==10 and .summary.refuted==2' "$deployment_drift" >/dev/null
}

digest() {
  printf 'sha256:%s' "$(sha256sum "$1" | awk '{print $1}')"
}

case "$scenario" in
  complete)
    validate_report "$report"
    validate_hcl_receipt "$hcl_receipt"
    validate_toolchain "$toolchain"
    validate_product_graph "$product_graph"
    validate_unknowns
    validate_refutations
    cmp -s "$report" "$replay"
    ;;
  missing-report)
    jq -e '.==null' "$report" >/dev/null
    jq -e '.==null' "$replay" >/dev/null
    validate_hcl_receipt "$hcl_receipt"
    validate_toolchain "$toolchain"
    validate_product_graph "$product_graph"
    validate_unknowns
    validate_refutations
    ;;
  metric-tamper)
    jq -e '.schema=="gooo/infra-evidence/report/v2" and (.indicators[]|select(.id=="gooo.metric.infra-evidence.semantic-edges.v2")|.value==7)' "$report" >/dev/null
    validate_hcl_receipt "$hcl_receipt"
    validate_toolchain "$toolchain"
    validate_product_graph "$product_graph"
    validate_unknowns
    validate_refutations
    ;;
  missing-product-meta)
    validate_report "$report"
    validate_hcl_receipt "$hcl_receipt"
    validate_toolchain "$toolchain"
    jq -e '
      (.activity_resolution_observation.entries|length)==11 and
      ([.activity_resolution_observation.entries[]|select(.activity=="ObserveRuntimeDrift")]|length)==0
    ' "$product_graph" >/dev/null
    validate_unknowns
    validate_refutations
    ;;
  execution-escalation)
    jq -e '.schema=="gooo/infra-evidence/report/v2" and .authority.terraform_execution=="EXECUTED"' "$report" >/dev/null
    validate_hcl_receipt "$hcl_receipt"
    validate_toolchain "$toolchain"
    validate_product_graph "$product_graph"
    validate_unknowns
    validate_refutations
    ;;
  *)
    echo "unsupported scenario: $scenario" >&2
    exit 2
    ;;
esac

jq -S -n \
  --slurpfile denominator "$denominator" \
  --slurpfile report "$report" \
  --slurpfile hcl "$hcl_receipt" \
  --slurpfile toolchain "$toolchain" \
  --slurpfile product_graph "$product_graph" \
  --arg scenario "$scenario" \
  --arg subject_sha "$subject_sha" \
  --arg link_graph_digest "$(digest "$link_graph")" \
  --arg denominator_digest "$(digest "$denominator")" \
  --arg report_digest "$(digest "$report")" \
  --arg hcl_digest "$(digest "$hcl_receipt")" \
  --arg toolchain_digest "$(digest "$toolchain")" \
  --arg product_graph_digest "$(digest "$product_graph")" \
  --arg missing_hcl_digest "$(digest "$missing_hcl")" \
  --arg context_hcl_digest "$(digest "$context_hcl")" \
  --arg invalid_hcl_digest "$(digest "$invalid_hcl")" \
  --arg mismatched_hcl_digest "$(digest "$mismatched_hcl")" \
  --arg deployment_drift_digest "$(digest "$deployment_drift")" '
  $denominator[0] as $d |
  ($report[0] // {}) as $report |
  ($hcl[0] // {}) as $hcl |
  ($toolchain[0] // {}) as $toolchain |
  ($product_graph[0] // {}) as $product_graph |
  [$d.cells[] |
    {id,activity,proof_choice,indicator_class,state:"CLOSED",stage:null,step:null,
      reason:.closed_reason,unknown_class:null,next_operation:"NONE",blocked_by:[]} |
    if $scenario=="missing-report" and .id=="INFRA_CHAIN_OBSERVED" then
      .+{state:"UNKNOWN",stage:"PRODUCT_RELEASE",step:"OBSERVE_INFRA_EVIDENCE_CHAIN",
        reason:"INFRA_PRODUCT_REPORT_UNAVAILABLE",unknown_class:"DIRECT_MISSING",
        next_operation:"PUBLISH_INFRA_PRODUCT_REPORT",blocked_by:["infra-product-report"]}
    elif $scenario=="missing-report" and (.id=="SEMANTIC_EDGES_OBSERVED" or .id=="INFRA_PORTFOLIO_PROGRESS_RECORDED") then
      .+{state:"UNKNOWN",stage:"DEPENDENCY",step:.activity,reason:"DEPENDENCY_BLOCKED",
        unknown_class:"DEPENDENCY_BLOCKED",next_operation:"RESOLVE_INFRA_PRODUCT_REPORT",
        blocked_by:["INFRA_CHAIN_OBSERVED"]}
    elif $scenario=="metric-tamper" and .id=="SEMANTIC_EDGES_OBSERVED" then
      .+{state:"REFUTED",stage:"PRODUCT_EVIDENCE",step:"OBSERVE_INFRA_SEMANTIC_EDGES",
        reason:"INFRA_SEMANTIC_EDGE_METRIC_MISMATCH",next_operation:"RESTORE_INFRA_SEMANTIC_EDGE_METRIC",
        blocked_by:["infra-product-report"]}
    elif $scenario=="missing-product-meta" and .id=="INFRA_META_BOUND" then
      .+{state:"REFUTED",stage:"META",step:"BIND_INFRA_PRODUCT_ACTIVITIES",
        reason:"INFRA_META_BINDING_MISMATCH",next_operation:"RESTORE_INFRA_META_ACTIVITY",
        blocked_by:["ObserveRuntimeDrift"]}
    elif $scenario=="execution-escalation" and .id=="INFRA_RESOURCES_OBSERVED" then
      .+{state:"REFUTED",stage:"AUTHORITY",step:"OBSERVE_INFRA_RESOURCES",
        reason:"UNCLAIMED_EXECUTION_AUTHORITY_ESCALATION",next_operation:"RESTORE_READ_ONLY_INFRA_AUTHORITY",
        blocked_by:["terraform_execution"]}
    else . end
  ] as $cells |
  ([$cells[]|select(.state=="CLOSED")]|length) as $closed |
  ([$cells[]|select(.state=="UNKNOWN")]|length) as $unknown_count |
  ([$cells[]|select(.state=="REFUTED")]|length) as $refuted_count |
  (([$cells[]|select(.state=="REFUTED")][0]) // ([$cells[]|select(.state=="UNKNOWN")][0])) as $first |
  (if $scenario=="complete" then 1 else 0 end) as $newly_observed |
  ($d.portfolio_previous + $newly_observed) as $products_observed |
  {
    schema:"gooo/link-infra-product-adoption-report/v1",
    scenario:$scenario,
    subject_sha:$subject_sha,
    decision:(if $refuted_count>0 then "FAIL_CLOSED" elif $unknown_count>0 then "INFRA_PRODUCT_ADOPTION_UNKNOWN" else "INFRA_PRODUCT_ADOPTION_OBSERVED" end),
    candidate:{id:$d.candidate_id,state:(if $refuted_count>0 then "REFUTED" elif $unknown_count>0 then "UNKNOWN" else "ADOPTED" end),
      implementation_status:(if $newly_observed==1 then "INDEPENDENT_RELEASE_OBSERVED" else "NOT_COUNTED" end)},
    claim:(if $first==null then
      {state:"CLOSED",stage:null,step:null,reason:"INFRA_PRODUCT_ADOPTION_OBSERVED",
        unknown_class:null,next_operation:"EVALUATE_GENERATOR_AUTHORITY_WITH_THREE_PRODUCTS",blocked_by:[]}
      else {state:$first.state,stage:$first.stage,step:$first.step,reason:$first.reason,
        unknown_class:$first.unknown_class,next_operation:$first.next_operation,blocked_by:$first.blocked_by} end),
    summary:{total_cells:12,closed_cells:$closed,unknown_cells:$unknown_count,refuted_cells:$refuted_count,
      independent_products_observed:$products_observed,independent_products_total:$d.portfolio_total,
      product_cells:($report.summary.closed//0),
      semantic_edges:(([$report.indicators[]?|select(.id=="gooo.metric.infra-evidence.semantic-edges.v2")][0].value)//0),
      hcl_bindings:(([$report.indicators[]?|select(.id=="gooo.metric.infra-evidence.hcl-resource-bindings.v2")][0].value)//0),
      product_activity_receipts:($product_graph.activity_resolution_observation.summary.closed//0),
      go_version:($toolchain.version//null),repository_writes:($report.summary.repository_writes//null),
      local_tests_run:0,cross_project_required_gates:0},
    portfolio:{previous_products_observed:$d.portfolio_previous,new_products_observed:$newly_observed,
      independent_products_observed:$products_observed,independent_products_total:$d.portfolio_total,
      generator_authority_evaluation_required:($products_observed==$d.portfolio_total),
      central_orchestrator_authorized:false,common_generator_authorized:false,
      cross_project_required_gates:0},
    authority:{activity_bindings:12,activity_total:12,hcl_parser:($hcl.authority.parser_module//null),
      hcl_parser_version:($hcl.authority.parser_version//null),terraform_execution:($report.authority.terraform_execution//null),
      deployment_execution:($report.authority.deployment_execution//null),live_cloud_state:($report.authority.live_cloud_state//null),
      live_network_probe:($report.authority.live_network_probe//null)},
    evidence:{link_graph_digest:$link_graph_digest,denominator_digest:$denominator_digest,
      report_digest:$report_digest,hcl_digest:$hcl_digest,toolchain_digest:$toolchain_digest,
      product_graph_digest:$product_graph_digest,missing_hcl_digest:$missing_hcl_digest,
      context_hcl_digest:$context_hcl_digest,invalid_hcl_digest:$invalid_hcl_digest,
      mismatched_hcl_digest:$mismatched_hcl_digest,deployment_drift_digest:$deployment_drift_digest},
    cells:$cells,
    proofs:[$d.proofs[] as $proof | {choice:$proof.choice,total:$proof.total,
      closed:([$cells[]|select(.proof_choice==$proof.choice and .state=="CLOSED")]|length)}],
    indicator_classes:[$d.indicator_classes[] as $indicator | {class:$indicator.class,total:$indicator.total,
      closed:([$cells[]|select(.indicator_class==$indicator.class and .state=="CLOSED")]|length)}]
  }
' > "$output"
