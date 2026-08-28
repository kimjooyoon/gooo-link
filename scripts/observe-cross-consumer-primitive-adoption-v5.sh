#!/usr/bin/env bash
set -euo pipefail

if test "$#" -ne 14; then
  echo "usage: observe-cross-consumer-primitive-adoption-v5.sh ROOT GRAPH BASELINE CORE_REPORT ELIGIBILITY DEPENDENCY MISSING UNSUPPORTED AMBIGUOUS CYCLE RUNTIME OUTPUT HEAD_SHA PHASE" >&2
  exit 64
fi

root=$(cd "$1" && pwd); graph=$2; baseline=$3; core_report=$4; eligibility=$5; dependency=$6; missing=$7
unsupported=$8; ambiguous=$9; cycle=${10}; runtime=${11}; output=${12}; head_sha=${13}; phase=${14}
denominator="$root/contracts/cross-consumer-primitive-adoption-denominator-v5.json"
lock="$root/contracts/cross-consumer-primitive-adoption-release-lock-v5.json"
observation="$root/examples/cross-consumer-primitive-adoption-v5/observation.gooo"
program="$root/examples/cross-consumer-primitive-adoption-v5/program.gooo"
for required in "$graph" "$baseline" "$core_report" "$eligibility" "$dependency" "$missing" "$unsupported" "$ambiguous" "$cycle" "$runtime" "$denominator" "$lock"; do
  test -f "$required" || { echo "missing required input: $required" >&2; exit 66; }
  jq -e . "$required" >/dev/null
done
test -f "$observation"; test -f "$program"
jq -e '.target_cells==12 and (.cells|length)==12 and ([.cells[].activity]|unique|length)==12 and ([.proof_totals[].total]|add)==12 and ([.indicator_totals[].total]|add)==12' "$denominator" >/dev/null
jq -e '.schema=="gooo/link/cross-consumer-primitive-adoption-release-lock/v5" and .link.tag=="v0.22.0-dev" and .core.tag=="v0.4.0-dev"' "$lock" >/dev/null
test "$(grep -c '^activity ' "$observation")" -eq 12
grep -Fq 'gooo.primitive.claim-dependency-causality.v1' "$program"

work=$(mktemp -d); trap 'rm -rf "$work"' EXIT
: > "$work/source-lines.ndjson"
while IFS= read -r -d '' file; do
  relative=${file#"$root/"}; lines=$(wc -l < "$file" | tr -d ' ')
  case "$file" in *.go) language=Go ;; *.gooo) language=Gooo ;; *) continue ;; esac
  jq -cn --arg path "$relative" --arg language "$language" --argjson lines "$lines" '{path:$path,language:$language,lines:$lines}' >> "$work/source-lines.ndjson"
done < <(find "$root" -type f -not -path "$root/.git/*" \( -name '*.go' -o -name '*.gooo' \) -print0 | sort -z)
repository_files=$(find "$root" -type f -not -path "$root/.git/*" | wc -l | tr -d ' ')
descendant_directories=$(find "$root" -mindepth 1 -type d -not -path "$root/.git" -not -path "$root/.git/*" | wc -l | tr -d ' ')
jq -s --argjson repository_files "$repository_files" --argjson descendant_directories "$descendant_directories" '
  . as $files|{repository_files:$repository_files,descendant_directories:$descendant_directories,root_readme_readiness:"EXCLUDED",
    go:{files:([$files[]|select(.language=="Go")]|length),lines:([$files[]|select(.language=="Go")|.lines]|add//0)},
    gooo:{files:([$files[]|select(.language=="Gooo")]|length),lines:([$files[]|select(.language=="Gooo")|.lines]|add//0)},per_file:$files}' "$work/source-lines.ndjson" > "$work/inventory.json"

jq -S -n --slurpfile denominator "$denominator" --slurpfile lock "$lock" --slurpfile graph "$graph" \
  --slurpfile baseline "$baseline" --slurpfile core_report "$core_report" --slurpfile eligibility "$eligibility" \
  --slurpfile dependency "$dependency" --slurpfile missing "$missing" --slurpfile unsupported "$unsupported" \
  --slurpfile ambiguous "$ambiguous" --slurpfile cycle "$cycle" --slurpfile runtime "$runtime" --slurpfile inventory "$work/inventory.json" \
  --rawfile observation "$observation" --rawfile program "$program" --arg head_sha "$head_sha" --arg phase "$phase" '
  def activity_bound($activity): ([$graph[0].nodes[]?|select(.kind=="Activity" and .name==$activity)]|length)==1;
  def indicators_satisfied($r): ($r.indicators|length)==8 and all($r.indicators[]; if .comparator=="EQ" then .value==.target elif .comparator=="GTE" then .value>=.target elif .comparator=="LTE" then .value<=.target else false end);
  def complete($r): $r.schema=="gooo/claim-dependency-causality/v1" and $r.candidate_id=="gooo.primitive.claim-dependency-causality.v1" and
    $r.decision=="CLAIM_DEPENDENCY_OBSERVED" and $r.resolution.state=="CLOSED" and $r.resolution.reason=="CLAIM_DEPENDENCY_CAUSALITY_OBSERVED" and
    $r.summary.activities_total==6 and $r.summary.activities_observed==6 and $r.summary.recoverable_roots==1 and $r.summary.typed_declarations==5 and
    $r.summary.dependency_inputs==8 and $r.summary.typed_edges==8 and $r.summary.edge_kinds_observed==4 and $r.summary.unresolved_inputs==0 and
    $r.summary.cyclic_activities==0 and $r.summary.repository_writes==0 and $r.kind_counts.requires==3 and $r.kind_counts.supports==2 and
    $r.kind_counts.contradicts==2 and $r.kind_counts.failure_entailment==1 and ($r.nodes|length)==6 and ($r.edges|length)==8 and ($r.gaps|length)==0 and
    indicators_satisfied($r) and $r.authority.semantic_truth_claimed==false and $r.authority.state_propagation_authorized==false and
    $r.authority.core_mutation_authorized==false and $r.authority.automatic_merge_allowed==false and $r.authority.repository_writes==0;
  def unknown_missing($r): $r.schema=="gooo/claim-dependency-causality/v1" and $r.decision=="INCOMPLETE" and $r.resolution.state=="UNKNOWN" and
    $r.resolution.stage=="DEPENDENCY_DISCOVERY" and $r.resolution.step=="BIND_INPUT_PRODUCER" and $r.resolution.reason=="CLAIM_INPUT_PRODUCER_UNAVAILABLE" and
    $r.resolution.unknown_class=="DIRECT_MISSING" and $r.resolution.next_operation=="DECLARE_INPUT_PRODUCER" and ($r.resolution.blocked_by|length)==1 and
    $r.summary.unresolved_inputs==1;
  def refuted($r;$reason): $r.schema=="gooo/claim-dependency-causality/v1" and $r.decision=="FAIL_CLOSED" and $r.resolution.state=="REFUTED" and $r.resolution.reason==$reason;
  ($baseline[0]) as $b | ($core_report[0]) as $cr | ($eligibility[0]) as $ce | ($dependency[0]) as $d |
  ($b.schema=="gooo/link/claim-dependency-candidate-selection/v1" and $b.subject_sha==$lock[0].link.target_commit_sha and $b.decision=="CANDIDATE_SELECTED" and
    $b.candidate.id=="gooo.primitive.claim-dependency-causality.v1" and $b.candidate.mapping_authority=="PINNED_GOOO_SOURCE" and
    $b.summary.cells_closed==12 and $b.summary.cells_total==12 and $b.summary.cells_unknown==0 and $b.summary.cells_refuted==0 and
    $b.summary.primitive_mappings==5 and $b.summary.primitive_denominator==30 and $b.summary.primitive_increment==0 and
    $b.summary.repository_writes==0 and $b.summary.local_tests==0 and $b.summary.cross_project_required_gates==0) as $baseline_ok |
  ($cr.schema=="gooo/toolchain-cross-platform-release-report/v1" and $cr.head_sha==$lock[0].core.target_commit_sha and $cr.decision=="PASS" and
    $cr.resolution=="EXACT" and $cr.summary.cases_satisfied==20 and $cr.summary.cases_total==20 and $cr.summary.platform_receipts==3 and
    $cr.summary.missing_receipts==0 and $cr.summary.case_failures==0 and $cr.summary.head_mismatches==0 and $cr.summary.proof_failures==0 and
    $cr.summary.unresolved==0 and $cr.summary.repository_writes==0 and $cr.summary.mutation_authorities==0) as $core_report_ok |
  ($ce.schema=="gooo/release-eligibility/v1" and $ce.head_sha==$lock[0].core.target_commit_sha and $ce.decision=="EVIDENCE_CLOSED" and
    $ce.resolution=="EXACT" and $ce.summary.total_work==7 and $ce.summary.closed==7 and $ce.summary.unknown==0 and $ce.summary.refuted==0 and
    $ce.summary.repository_writes==0) as $eligibility_ok |
  (complete($d)) as $complete_ok | (unknown_missing($d)) as $primary_unknown |
  (if $complete_ok then "CLOSED" elif $primary_unknown then "UNKNOWN" elif $d.decision=="FAIL_CLOSED" and $d.resolution.state=="REFUTED" then "REFUTED" else "INVALID" end) as $dependency_mode |
  (unknown_missing($missing[0])) as $missing_ok |
  (refuted($unsupported[0];"CLAIM_DEPENDENCY_EDGE_KIND_UNSUPPORTED")) as $unsupported_ok |
  (refuted($ambiguous[0];"CLAIM_OUTPUT_PRODUCER_AMBIGUOUS")) as $ambiguous_ok |
  (refuted($cycle[0];"CLAIM_DEPENDENCY_CYCLE_DETECTED")) as $cycle_ok |
  ([$denominator[0].cells[].activity|select(activity_bound(.))]|length) as $activities_bound |
  {
    ObserveCandidateSelectionRelease:($runtime[0].releases.link==true and $baseline_ok and activity_bound("ObserveCandidateSelectionRelease")),
    ObserveCorePrimitiveRelease:($runtime[0].releases.core==true and $core_report_ok and activity_bound("ObserveCorePrimitiveRelease")),
    BindCoreReleaseEligibility:($eligibility_ok and activity_bound("BindCoreReleaseEligibility")),
    BindFiveOfThirtyBaseline:$baseline_ok,
    ExecuteReleasedClaimDependencyCommand:$complete_ok,
    BindEightStructuralEdges:($complete_ok and $d.summary.typed_edges==8 and $d.summary.dependency_inputs==8),
    AdvanceToSixOfThirty:($baseline_ok and $complete_ok and ($b.summary.primitive_mappings+1)==6 and (30-6)==24),
    PreserveZeroConsumerIncrement:($runtime[0].independent_consumer_increment==0),
    PreserveUnknownCoordinates:$missing_ok,
    PreserveRefutedCounterexamples:($unsupported_ok and $ambiguous_ok and $cycle_ok),
    BindTwelveMetaActivities:($activities_bound==12),
    PreserveOptionalReadOnlyBoundary:($runtime[0].repository_writes==0 and $runtime[0].local_tests_run==0 and $runtime[0].cross_project_required_gates==0 and
      $runtime[0].generator_authority==false and $runtime[0].central_orchestration_authorized==false and $runtime[0].go_fix_module_roots==0)
  } as $facts |
  def dependent($activity): ["ExecuteReleasedClaimDependencyCommand","BindEightStructuralEdges","AdvanceToSixOfThirty"]|index($activity)!=null;
  def evaluate($cell): ($cell.activity) as $activity |
    if activity_bound($activity)|not then $cell+{state:"REFUTED",reason:"GOOO_META_ACTIVITY_MISSING",unknown_class:null,next_operation:"RESTORE_GOOO_META_ACTIVITY"}
    elif dependent($activity) and $dependency_mode=="UNKNOWN" then $cell+{state:"UNKNOWN",stage:$d.resolution.stage,step:$d.resolution.step,reason:$d.resolution.reason,unknown_class:$d.resolution.unknown_class,next_operation:$d.resolution.next_operation,blocked_by:$d.resolution.blocked_by}
    elif dependent($activity) and $dependency_mode=="REFUTED" then $cell+{state:"REFUTED",stage:$d.resolution.stage,step:$d.resolution.step,reason:$d.resolution.reason,unknown_class:null,next_operation:$d.resolution.next_operation,blocked_by:$d.resolution.blocked_by}
    elif dependent($activity) and $dependency_mode=="INVALID" then $cell+{state:"REFUTED",stage:"PRIMITIVE_EVIDENCE",step:"VALIDATE_CLAIM_DEPENDENCY_REPORT",reason:"CLAIM_DEPENDENCY_REPORT_INVALID",unknown_class:null,next_operation:"RESTORE_RELEASED_COMMAND_REPORT"}
    elif $facts[$activity]==true then $cell+{state:"CLOSED",reason:$cell.closed_reason,unknown_class:null,next_operation:"NONE"}
    else $cell+{state:"REFUTED",reason:$cell.refuted_reason,unknown_class:null,next_operation:$cell.next_operation} end;
  ($denominator[0].cells|map(evaluate(.))) as $cells |
  ([$cells[]|select(.state=="CLOSED")]|length) as $closed_count | ([$cells[]|select(.state=="UNKNOWN")]|length) as $unknown_count |
  ([$cells[]|select(.state=="REFUTED")]|length) as $refuted_count |
  (([$cells[]|select(.state=="REFUTED")]|first)//([$cells[]|select(.state=="UNKNOWN")]|first)) as $first_nonclosed |
  (if $closed_count==12 then 1 else 0 end) as $mapping_increment | (($b.summary.primitive_mappings//0)+$mapping_increment) as $current_mappings |
  {
    schema:"gooo/link/cross-consumer-primitive-adoption-report/v5",phase:$phase,subject_sha:$head_sha,
    decision:(if $refuted_count>0 then "FAIL_CLOSED" elif $unknown_count>0 then "CLAIM_DEPENDENCY_ADOPTION_UNKNOWN" else "CLAIM_DEPENDENCY_PRIMITIVE_ADOPTED" end),
    claim:{state:(if $refuted_count>0 then "REFUTED" elif $unknown_count>0 then "UNKNOWN" else "CLOSED" end),stage:($first_nonclosed.stage//null),step:($first_nonclosed.step//null),
      reason:($first_nonclosed.reason//"SIXTH_DIRECT_CLAIM_DEPENDENCY_MAPPING_OBSERVED"),unknown_class:($first_nonclosed.unknown_class//null),
      next_operation:($first_nonclosed.next_operation//"OBSERVE_NEXT_RELEASED_PRIMITIVE_ADOPTION"),blocked_by:($first_nonclosed.blocked_by//[])},
    summary:{total_cells:12,closed_cells:$closed_count,unknown_cells:$unknown_count,refuted_cells:$refuted_count,
      primitive_mapping_previous:($b.summary.primitive_mappings//0),primitive_mapping_increment:$mapping_increment,direct_mappings:$current_mappings,
      mapping_denominator:30,mapping_remaining:(30-$current_mappings),independent_consumer_increment:$runtime[0].independent_consumer_increment,
      core_release_cases_observed:(if $core_report_ok then 20 else 0 end),core_release_case_total:20,
      core_release_cells_observed:(if $eligibility_ok then 7 else 0 end),core_release_cell_total:7,
      claim_activities_observed:(if $complete_ok then 6 else 0 end),claim_activity_total:6,recoverable_roots:(if $complete_ok then 1 else 0 end),
      typed_declarations:(if $complete_ok then 5 else 0 end),dependency_inputs:(if $complete_ok then 8 else 0 end),typed_edges:(if $complete_ok then 8 else 0 end),
      edge_kinds_observed:(if $complete_ok then 4 else 0 end),requires_edges:(if $complete_ok then 3 else 0 end),supports_edges:(if $complete_ok then 2 else 0 end),
      contradicts_edges:(if $complete_ok then 2 else 0 end),failure_entailment_edges:(if $complete_ok then 1 else 0 end),
      core_indicators_satisfied:(if $complete_ok then 8 else 0 end),core_indicator_total:8,unknown_paths_observed:(if $missing_ok then 1 else 0 end),unknown_path_total:1,
      unknown_coordinates_observed:(if $missing_ok then 6 else 0 end),unknown_coordinate_total:6,
      refuted_paths_observed:([$unsupported_ok,$ambiguous_ok,$cycle_ok]|map(select(.==true))|length),refuted_path_total:3,
      link_meta_activities_observed:$activities_bound,link_meta_activity_total:12,repository_writes:$runtime[0].repository_writes,
      local_tests_run:$runtime[0].local_tests_run,cross_project_required_gates:$runtime[0].cross_project_required_gates},
    authority:{observation_scope:"RELEASED_CLAIM_DEPENDENCY_PRIMITIVE_ADOPTION_ONLY",link_selection_release:"v0.22.0-dev",core_primitive_release:"v0.4.0-dev",
      product_release_independence_required:true,common_generator_authorized:false,central_orchestration_authorized:$runtime[0].central_orchestration_authorized,
      generator_authority:$runtime[0].generator_authority,cross_project_required_gates:$runtime[0].cross_project_required_gates,
      local_tests_run:$runtime[0].local_tests_run,source_repository_writes:$runtime[0].repository_writes,go_fix_module_roots:$runtime[0].go_fix_module_roots,
      independent_consumer_increment:$runtime[0].independent_consumer_increment,root_readme_readiness:"EXCLUDED"},
    performance:$runtime[0].performance,inventory:$inventory[0],cells:$cells,
    proofs:(["FOUNDATION","COHERENCE","REGRESSION"]|map(. as $choice|{choice:$choice,closed:([$cells[]|select(.proof_choice==$choice and .state=="CLOSED")]|length),total:([$cells[]|select(.proof_choice==$choice)]|length)})),
    indicator_classes:(["DRIVER","OUTCOME","GUARDRAIL"]|map(. as $class|{class:$class,closed:([$cells[]|select(.indicator_class==$class and .state=="CLOSED")]|length),total:([$cells[]|select(.indicator_class==$class)]|length)})),
    indicators:[
      {id:"gooo.metric.cross-consumer.direct-mappings.v5",class:"OUTCOME",activity:"AdvanceToSixOfThirty",value:$current_mappings,total:30,unit:"mappings"},
      {id:"gooo.metric.cross-consumer.mapping-increment.v5",class:"OUTCOME",activity:"AdvanceToSixOfThirty",value:$mapping_increment,total:1,unit:"mappings"},
      {id:"gooo.metric.cross-consumer.mapping-remaining.v5",class:"OUTCOME",activity:"AdvanceToSixOfThirty",value:(30-$current_mappings),total:30,unit:"mappings"},
      {id:"gooo.metric.cross-consumer.core-release-cases.v5",class:"DRIVER",activity:"ObserveCorePrimitiveRelease",value:(if $core_report_ok then 20 else 0 end),total:20,unit:"cases"},
      {id:"gooo.metric.cross-consumer.claim-dependency-edges.v5",class:"DRIVER",activity:"BindEightStructuralEdges",value:(if $complete_ok then 8 else 0 end),total:8,unit:"edges"},
      {id:"gooo.metric.cross-consumer.claim-dependency-indicators.v5",class:"DRIVER",activity:"ExecuteReleasedClaimDependencyCommand",value:(if $complete_ok then 8 else 0 end),total:8,unit:"indicators"},
      {id:"gooo.metric.cross-consumer.unknown-coordinates.v5",class:"GUARDRAIL",activity:"PreserveUnknownCoordinates",value:(if $missing_ok then 6 else 0 end),total:6,unit:"coordinates"},
      {id:"gooo.metric.cross-consumer.refuted-paths.v5",class:"GUARDRAIL",activity:"PreserveRefutedCounterexamples",value:([$unsupported_ok,$ambiguous_ok,$cycle_ok]|map(select(.==true))|length),total:3,unit:"paths"},
      {id:"gooo.metric.cross-consumer.independent-consumer-increment.v5",class:"GUARDRAIL",activity:"PreserveZeroConsumerIncrement",value:$runtime[0].independent_consumer_increment,total:0,unit:"consumers"},
      {id:"gooo.metric.cross-consumer.graph-peak-rss.v5",class:"DRIVER",activity:"BindTwelveMetaActivities",value:$runtime[0].performance.command_peak_rss_kib,unit:"KiB"},
      {id:"gooo.metric.cross-consumer.command-wall-time.v5",class:"DRIVER",activity:"BindTwelveMetaActivities",value:$runtime[0].performance.command_wall_ms,unit:"ms"},
      {id:"gooo.metric.cross-consumer.repository-writes.v5",class:"GUARDRAIL",activity:"PreserveOptionalReadOnlyBoundary",value:$runtime[0].repository_writes,total:0,unit:"writes"}
    ]
  }' > "$output"
