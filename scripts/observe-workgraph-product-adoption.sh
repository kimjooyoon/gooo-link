#!/usr/bin/env bash
set -euo pipefail

if test "$#" -ne 9; then
  echo "usage: observe-workgraph-product-adoption.sh GRAPH DENOMINATOR REPORT INVENTORY RUNTIME PRODUCT_GRAPH OUTPUT SUBJECT_SHA SCENARIO" >&2
  exit 2
fi

graph=$1
denominator=$2
report=$3
inventory=$4
runtime=$5
product_graph=$6
output=$7
subject_sha=$8
scenario=$9

for file in "$graph" "$denominator" "$report" "$inventory" "$runtime" "$product_graph"; do
  test -f "$file" || { echo "missing required input: $file" >&2; exit 2; }
done

jq -e '
  .schema=="gooo/link-workgraph-product-adoption-denominator/v1" and
  .candidate_id=="gooo.product.workspace-inventory.v1" and
  .total==12 and .portfolio_total==3 and (.cells|length)==12 and
  ([.proofs[].total]|add)==12 and ([.indicator_classes[].total]|add)==12
' "$denominator" >/dev/null

jq -e --slurpfile denominator "$denominator" '
  . as $graph |
  .schema_version=="gooo-graph/v1" and
  ([$graph.nodes[]|select(.kind=="Activity")]|length)==12 and
  ([$denominator[0].cells[] as $cell |
    select(([$graph.nodes[]|select(.kind=="Activity" and .name==$cell.activity)]|length)==1)
  ]|length)==12
' "$graph" >/dev/null

validate_report() {
  jq -e '
    .schema=="gooo/workgraph-workspace-inventory-report/v1" and
    .decision=="WORKSPACE_INVENTORY_VERTICAL_SLICE_OBSERVED" and
    .candidate.id=="gooo.product.workspace-inventory.v1" and
    .candidate.state=="IMPLEMENTED" and
    .claim.state=="CLOSED" and
    .summary.total_cells==12 and .summary.closed_cells==12 and
    .summary.unknown_cells==0 and .summary.refuted_cells==0 and
    .summary.directories==7 and .summary.files==5 and
    .summary.go_files==2 and .summary.go_lines==6 and
    .summary.gooo_files==2 and .summary.gooo_lines==8 and
    .summary.root_readme_present==false and .summary.root_readme_required==false and
    .summary.repository_writes==0 and .summary.local_tests_run==0 and
    .summary.cross_project_required_gates==0 and
    .scenarios=={closed:1,deterministic_replay:1,refuted:1,total:4,unknown:1} and
    (.cells|length)==12 and
    ([.proofs[]|select(.closed==4 and .total==4)]|length)==3 and
    ([.indicator_classes[]|select(.closed==4 and .total==4)]|length)==3
  ' "$1" >/dev/null
}

validate_inventory() {
  jq -e '
    .schema=="gooo/workgraph-workspace-inventory/v1" and
    .decision=="WORKSPACE_INVENTORY_OBSERVED" and .claim.state=="CLOSED" and
    .summary.directories==7 and .summary.files==5 and
    .summary.go_files==2 and .summary.go_lines==6 and
    .summary.gooo_files==2 and .summary.gooo_lines==8 and
    .summary.other_files==1 and .summary.other_lines==2 and
    .summary.root_readme_present==false and .summary.root_readme_required==false and
    .summary.root_readme_excluded==true and (.files|length)==5
  ' "$1" >/dev/null
}

validate_runtime() {
  jq -e '
    .schema=="gooo/workgraph-workspace-inventory-runtime/v1" and
    .go_version=="go1.27.0" and .peak_rss_kib>0 and .wall_ms>=0 and
    .repository_writes==0 and .go_fix_writes==0 and .ci_test_cases==3 and
    .local_tests_run==0 and .cross_project_required_gates==0
  ' "$1" >/dev/null
}

validate_product_graph() {
  jq -e --slurpfile report "$report" '
    . as $graph |
    .schema_version=="gooo-graph/v1" and
    ([$graph.nodes[]|select(.kind=="Activity")]|length)==12 and
    ([$report[0].cells[] as $cell |
      select(([$graph.nodes[]|select(.kind=="Activity" and .name==$cell.activity)]|length)==1)
    ]|length)==12
  ' "$1" >/dev/null
}

digest() {
  printf 'sha256:%s' "$(sha256sum "$1" | awk '{print $1}')"
}

case "$scenario" in
  complete)
    validate_report "$report"
    validate_inventory "$inventory"
    validate_runtime "$runtime"
    validate_product_graph "$product_graph"
    test "$(jq -r .evidence.complete_digest "$report")" = "$(digest "$inventory")"
    test "$(jq -r .evidence.runtime_digest "$report")" = "$(digest "$runtime")"
    test "$(jq -r .evidence.graph_digest "$report")" = "$(digest "$product_graph")"
    ;;
  missing-report)
    jq -e '.==null' "$report" >/dev/null
    validate_inventory "$inventory"
    validate_runtime "$runtime"
    jq -e '.schema_version=="gooo-graph/v1" and ([$nodes[]?]|length)>=0' "$product_graph" >/dev/null 2>&1 || true
    ;;
  metric-tamper)
    validate_report "$report"
    jq -e '
      .schema=="gooo/workgraph-workspace-inventory/v1" and
      .summary.directories==7 and .summary.files==5 and
      .summary.go_files==2 and .summary.go_lines==6 and
      .summary.gooo_files==2 and .summary.gooo_lines==9
    ' "$inventory" >/dev/null
    validate_runtime "$runtime"
    validate_product_graph "$product_graph"
    test "$(jq -r .evidence.complete_digest "$report")" != "$(digest "$inventory")"
    ;;
  missing-meta)
    validate_report "$report"
    validate_inventory "$inventory"
    validate_runtime "$runtime"
    jq -e '
      .schema_version=="gooo-graph/v1" and
      ([$nodes[]?]|length)>=0
    ' "$product_graph" >/dev/null 2>&1 || true
    jq -e '([.nodes[]|select(.kind=="Activity")]|length)==11 and ([.nodes[]|select(.kind=="Activity" and .name=="CountGoooLines")]|length)==0' "$product_graph" >/dev/null
    test "$(jq -r .evidence.graph_digest "$report")" != "$(digest "$product_graph")"
    ;;
  scope-escalation)
    validate_report "$report"
    validate_inventory "$inventory"
    validate_product_graph "$product_graph"
    jq -e '
      .schema=="gooo/workgraph-workspace-inventory-runtime/v1" and
      .repository_writes==0 and .local_tests_run==0 and
      .cross_project_required_gates==1
    ' "$runtime" >/dev/null
    test "$(jq -r .evidence.runtime_digest "$report")" != "$(digest "$runtime")"
    ;;
  *)
    echo "unsupported scenario: $scenario" >&2
    exit 2
    ;;
esac

graph_digest=$(digest "$graph")
denominator_digest=$(digest "$denominator")
report_digest=$(digest "$report")
inventory_digest=$(digest "$inventory")
runtime_digest=$(digest "$runtime")
product_graph_digest=$(digest "$product_graph")

jq -S -n \
  --slurpfile denominator "$denominator" \
  --slurpfile report "$report" \
  --slurpfile inventory "$inventory" \
  --slurpfile runtime "$runtime" \
  --arg scenario "$scenario" \
  --arg subject_sha "$subject_sha" \
  --arg graph_digest "$graph_digest" \
  --arg denominator_digest "$denominator_digest" \
  --arg report_digest "$report_digest" \
  --arg inventory_digest "$inventory_digest" \
  --arg runtime_digest "$runtime_digest" \
  --arg product_graph_digest "$product_graph_digest" '
  $denominator[0] as $d |
  ($report[0] // {}) as $report |
  $inventory[0] as $inventory |
  $runtime[0] as $runtime |
  [$d.cells[] |
    {id,activity,proof_choice,indicator_class,state:"CLOSED",stage:null,step:null,
      reason:.closed_reason,unknown_class:null,next_operation:"NONE",blocked_by:[]} |
    if $scenario=="missing-report" and .id=="WORKGRAPH_REPORT_LOCKED" then
      .+{state:"UNKNOWN",stage:"PRODUCT_RELEASE",step:"OBSERVE_WORKGRAPH_REPORT",
        reason:"WORKGRAPH_PRODUCT_REPORT_UNAVAILABLE",unknown_class:"DIRECT_MISSING",
        next_operation:"PUBLISH_WORKGRAPH_PRODUCT_REPORT",blocked_by:["workgraph-report"]}
    elif $scenario=="missing-report" and (.id=="WORKGRAPH_CELLS_OBSERVED" or .id=="PORTFOLIO_PROGRESS_RECORDED") then
      .+{state:"UNKNOWN",stage:"DEPENDENCY",step:.activity,reason:"DEPENDENCY_BLOCKED",
        unknown_class:"DEPENDENCY_BLOCKED",next_operation:"RESOLVE_WORKGRAPH_PRODUCT_REPORT",
        blocked_by:["WORKGRAPH_REPORT_LOCKED"]}
    elif $scenario=="metric-tamper" and .id=="WORKSPACE_LANGUAGES_OBSERVED" then
      .+{state:"REFUTED",stage:"PRODUCT_EVIDENCE",step:"OBSERVE_WORKSPACE_LANGUAGE_METRICS",
        reason:"WORKGRAPH_PRODUCT_METRIC_MISMATCH",next_operation:"RESTORE_WORKGRAPH_PRODUCT_METRICS",
        blocked_by:["workgraph-inventory"]}
    elif $scenario=="missing-meta" and .id=="WORKGRAPH_META_BOUND" then
      .+{state:"REFUTED",stage:"META",step:"BIND_WORKGRAPH_ACTIVITIES",
        reason:"WORKGRAPH_META_BINDING_MISMATCH",next_operation:"RESTORE_WORKGRAPH_META_ACTIVITY",
        blocked_by:["CountGoooLines"]}
    elif $scenario=="scope-escalation" and .id=="WORKGRAPH_RESOURCES_OBSERVED" then
      .+{state:"REFUTED",stage:"AUTHORITY",step:"OBSERVE_READ_ONLY_RESOURCES",
        reason:"CROSS_PROJECT_REQUIRED_GATE_ESCALATION",next_operation:"REMOVE_CROSS_PROJECT_REQUIRED_GATE",
        blocked_by:["workgraph-runtime"]}
    else . end
  ] as $cells |
  ([$cells[]|select(.state=="CLOSED")]|length) as $closed |
  ([$cells[]|select(.state=="UNKNOWN")]|length) as $unknown |
  ([$cells[]|select(.state=="REFUTED")]|length) as $refuted |
  (([$cells[]|select(.state=="REFUTED")][0]) // ([$cells[]|select(.state=="UNKNOWN")][0])) as $first |
  (if $scenario=="complete" then 1 else 0 end) as $adoptions |
  {
    schema:"gooo/link-workgraph-product-adoption-report/v1",
    scenario:$scenario,
    subject_sha:$subject_sha,
    decision:(if $refuted>0 then "FAIL_CLOSED" elif $unknown>0 then "WORKGRAPH_PRODUCT_ADOPTION_UNKNOWN" else "WORKGRAPH_PRODUCT_ADOPTION_OBSERVED" end),
    candidate:{id:$d.candidate_id,state:(if $refuted>0 then "REFUTED" elif $unknown>0 then "UNKNOWN" else "ADOPTED" end),
      implementation_status:(if $adoptions==1 then "INDEPENDENT_RELEASE_OBSERVED" else "NOT_COUNTED" end)},
    claim:(if $first==null then
      {state:"CLOSED",stage:null,step:null,reason:"WORKGRAPH_PRODUCT_ADOPTION_OBSERVED",
        unknown_class:null,next_operation:"OBSERVE_NEXT_INDEPENDENT_PRODUCT_RELEASE",blocked_by:[]}
      else {state:$first.state,stage:$first.stage,step:$first.step,reason:$first.reason,
        unknown_class:$first.unknown_class,next_operation:$first.next_operation,blocked_by:$first.blocked_by} end),
    summary:{total_cells:12,closed_cells:$closed,unknown_cells:$unknown,refuted_cells:$refuted,
      independent_products_observed:$adoptions,independent_products_total:3,
      directories:($inventory.summary.directories//0),files:($inventory.summary.files//0),
      go_files:($inventory.summary.go_files//0),go_lines:($inventory.summary.go_lines//0),
      gooo_files:($inventory.summary.gooo_files//0),gooo_lines:($inventory.summary.gooo_lines//0),
      repository_writes:($runtime.repository_writes//null),
      local_tests_run:($runtime.local_tests_run//null),
      cross_project_required_gates:($runtime.cross_project_required_gates//null)},
    portfolio:{observed:$adoptions,total:3,remaining:(3-$adoptions),complete:false,
      central_orchestrator_authorized:false,common_generator_authorized:false},
    cells:$cells,
    proofs:([$d.proofs[] as $proof|{choice:$proof.choice,
      closed:([$cells[]|select(.proof_choice==$proof.choice and .state=="CLOSED")]|length),total:$proof.total}]),
    indicator_classes:([$d.indicator_classes[] as $class|{class:$class.class,
      closed:([$cells[]|select(.indicator_class==$class.class and .state=="CLOSED")]|length),total:$class.total}]),
    indicators:[
      {id:"gooo.metric.link.independent-product-adoption.v1",class:"OUTCOME",value:$adoptions,total:3,unit:"products",state:"OBSERVED",activity:"RecordPortfolioProgress"},
      {id:"gooo.metric.link.workgraph-cells.v1",class:"OUTCOME",value:(if $adoptions==1 then 12 else 0 end),total:12,unit:"cells",state:(if $adoptions==1 then "SATISFIED" else "GAP" end),activity:"ObserveWorkgraphCells"},
      {id:"gooo.metric.link.workgraph-meta-bindings.v1",class:"DRIVER",value:(if $scenario=="missing-meta" then 11 else 12 end),total:12,unit:"activities",state:(if $scenario=="missing-meta" then "REFUTED" else "SATISFIED" end),activity:"BindWorkgraphActivities"},
      {id:"gooo.metric.link.workgraph-go-lines.v1",class:"OUTCOME",value:($inventory.summary.go_lines//0),unit:"physical_lines",state:"OBSERVED",activity:"ObserveWorkspaceLanguages"},
      {id:"gooo.metric.link.workgraph-gooo-lines.v1",class:"OUTCOME",value:($inventory.summary.gooo_lines//0),unit:"physical_lines",state:"OBSERVED",activity:"ObserveWorkspaceLanguages"},
      {id:"gooo.metric.link.workgraph-peak-rss.v1",class:"GUARDRAIL",value:($runtime.peak_rss_kib//null),unit:"KiB",state:"OBSERVED",activity:"ObserveReadOnlyResources"},
      {id:"gooo.metric.link.workgraph-wall-time.v1",class:"GUARDRAIL",value:($runtime.wall_ms//null),unit:"ms",state:"OBSERVED",activity:"ObserveReadOnlyResources"},
      {id:"gooo.metric.link.cross-project-required-gates.v1",class:"GUARDRAIL",value:($runtime.cross_project_required_gates//null),target:0,unit:"gates",state:(if ($runtime.cross_project_required_gates//0)==0 then "SATISFIED" else "REFUTED" end),activity:"ObserveReadOnlyResources"}
    ],
    authority:{observation_scope:"OPTIONAL_DOWNSTREAM_RELEASE_OBSERVATION",
      workgraph_source_writes:0,link_source_writes:0,local_tests_run:0,
      cross_project_required_gates:($runtime.cross_project_required_gates//null),
      workgraph_release_gate_authorized:false,core_release_gate_authorized:false},
    evidence:{graph_digest:$graph_digest,denominator_digest:$denominator_digest,
      report_digest:$report_digest,inventory_digest:$inventory_digest,
      runtime_digest:$runtime_digest,product_graph_digest:$product_graph_digest}
  }
' > "$output"
