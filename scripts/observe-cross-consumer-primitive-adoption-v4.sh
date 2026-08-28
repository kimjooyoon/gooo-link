#!/usr/bin/env bash
set -euo pipefail

if test "$#" -ne 13; then
  echo "usage: observe-cross-consumer-primitive-adoption-v4.sh ROOT GRAPH BASELINE WORKGRAPH MISSING_CORE MISSING_UPSTREAM TAMPERED LAUNDERED CHILD_AUTHORITY RUNTIME OUTPUT HEAD_SHA PHASE" >&2
  exit 64
fi

root=$(cd "$1" && pwd); graph=$2; baseline=$3; workgraph=$4; missing_core=$5; missing_upstream=$6
tampered=$7; laundered=$8; child_authority=$9; runtime=${10}; output=${11}; head_sha=${12}; phase=${13}
denominator="$root/contracts/cross-consumer-primitive-adoption-denominator-v4.json"
lock="$root/contracts/cross-consumer-primitive-adoption-release-lock-v4.json"
source="$root/examples/cross-consumer-primitive-adoption-v4/main.gooo"
for required in "$graph" "$baseline" "$workgraph" "$missing_core" "$missing_upstream" "$tampered" "$laundered" "$child_authority" "$runtime" "$denominator" "$lock"; do
  test -f "$required" || { echo "missing required input: $required" >&2; exit 66; }
  jq -e . "$required" >/dev/null
done
test -f "$source"
jq -e '.target_cells==12 and (.cells|length)==12 and ([.cells[].activity]|unique|length)==12 and ([.proof_totals[].total]|add)==12 and ([.indicator_totals[].total]|add)==12' "$denominator" >/dev/null
jq -e '.schema=="gooo/link/cross-consumer-primitive-adoption-release-lock/v4" and .core.tag=="v0.3.0-dev" and .baseline.tag=="v0.16.0-dev" and .workgraph.tag=="v0.3.0-dev"' "$lock" >/dev/null
test "$(grep -c '^activity ' "$source")" -eq 12
grep -Fq 'gooo.primitive.claim-resolution-tuple.v1' "$source"

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
  --slurpfile baseline "$baseline" --slurpfile candidate "$workgraph" --slurpfile missing_core "$missing_core" \
  --slurpfile missing_upstream "$missing_upstream" --slurpfile tampered "$tampered" --slurpfile laundered "$laundered" \
  --slurpfile child_authority "$child_authority" --slurpfile runtime "$runtime" --slurpfile inventory "$work/inventory.json" \
  --rawfile source "$source" --arg head_sha "$head_sha" --arg phase "$phase" '
  def has_six($claim): ($claim|type)=="object" and ($claim|has("state")) and ($claim|has("stage")) and ($claim|has("step")) and ($claim|has("reason")) and ($claim|has("unknown_class")) and ($claim|has("next_operation"));
  def activity_bound($activity): ([$graph[0].nodes[]?|select(.kind=="Activity" and .name==$activity)]|length)==1;
  ($baseline[0]) as $b | ($candidate[0]) as $c | ($missing_core[0]) as $mc | ($missing_upstream[0]) as $mu |
  ($tampered[0]) as $t | ($laundered[0]) as $l | ($child_authority[0]) as $ca |
  ($b.schema=="gooo/link/cross-consumer-primitive-adoption-report/v3" and $b.subject_sha==$lock[0].baseline.target_commit_sha and
    $b.decision=="FOURTH_DIRECT_PRIMITIVE_MAPPING_OBSERVED" and $b.summary.closed_cells==12 and $b.summary.total_cells==12 and
    $b.summary.direct_mappings==4 and $b.summary.mapping_denominator==30 and $b.summary.mapping_remaining==26 and
    $b.summary.independent_consumer_adoptions==3 and $b.authority.generator_authority==false and
    $b.authority.central_orchestration_authorized==false and $b.authority.cross_project_required_gates==0) as $baseline_ok |
  ($c.schema=="gooo/workgraph/claim-resolution-adoption-report/v1" and $c.subject_sha==$lock[0].workgraph.target_commit_sha and
    $c.decision=="WORKGRAPH_CLAIM_RESOLUTION_ADOPTED" and $c.claim.state=="CLOSED" and $c.summary.closed==12 and $c.summary.total==12 and
    $c.adoption.candidate_id=="gooo.primitive.claim-resolution-tuple.v1" and $c.adoption.direct_mappings==1 and $c.adoption.direct_mapping_total==1 and
    $c.adoption.released_scenarios==3 and $c.adoption.released_scenario_total==3 and
    $c.adoption.released_claim_fields==18 and $c.adoption.released_claim_field_total==18 and
    $c.adoption.core_claim_fields==18 and $c.adoption.core_claim_field_total==18 and
    $c.adoption.workspace_inventory_facts==9 and $c.adoption.workspace_inventory_fact_total==9 and
    $c.adoption.invalid_tuples_rejected==2 and $c.adoption.invalid_tuple_total==2 and
    $c.adoption.activities_bound==12 and $c.adoption.activity_total==12 and
    ([$c.proofs[]|select(.closed==4 and .total==4)]|length)==3 and ([$c.indicator_classes[]|select(.closed==4 and .total==4)]|length)==3 and
    $c.authority.generator_authority==false and $c.authority.cross_project_required_gates==0 and $c.authority.repository_writes==0) as $candidate_ok |
  (if $candidate_ok then "CLOSED" elif $c.decision=="ADOPTION_EVIDENCE_UNKNOWN" and $c.claim.state=="UNKNOWN" and has_six($c.claim) then "UNKNOWN"
   elif $c.decision=="FAIL_CLOSED" and $c.claim.state=="REFUTED" and has_six($c.claim) then "REFUTED" else "INVALID" end) as $candidate_mode |
  ($mc.decision=="ADOPTION_EVIDENCE_UNKNOWN" and $mc.summary.closed==11 and $mc.summary.unknown==1 and
    $mc.claim.reason=="CORE_CLAIM_RESOLUTION_RECEIPT_UNAVAILABLE" and $mc.claim.unknown_class=="DIRECT_MISSING") as $missing_core_ok |
  ($mu.decision=="ADOPTION_EVIDENCE_UNKNOWN" and $mu.summary.closed==10 and $mu.summary.unknown==2 and
    $mu.claim.reason=="RELEASED_WORKSPACE_UNKNOWN_CLAIM_UNAVAILABLE" and $mu.claim.unknown_class=="DIRECT_MISSING") as $missing_upstream_ok |
  ($t.decision=="FAIL_CLOSED" and $t.summary.closed==10 and $t.summary.refuted==2 and $t.claim.reason=="RELEASED_WORKSPACE_UNKNOWN_CLAIM_MISMATCH") as $tampered_ok |
  ($l.decision=="FAIL_CLOSED" and $l.summary.closed==9 and $l.summary.refuted==3 and $l.claim.reason=="RELEASED_WORKSPACE_CLOSED_CLAIM_OR_FACT_MISMATCH") as $laundered_ok |
  ($ca.decision=="FAIL_CLOSED" and $ca.summary.closed==11 and $ca.summary.refuted==1 and $ca.claim.reason=="WORKGRAPH_ADOPTION_AUTHORITY_ESCALATED") as $child_authority_ok |
  ([$denominator[0].cells[].activity|select(activity_bound(.))]|length) as $activities_bound |
  {
    ObserveLinkBaselineRelease:($runtime[0].releases.baseline==true and activity_bound("ObserveLinkBaselineRelease")),
    ObserveWorkgraphAdoptionRelease:($runtime[0].releases.workgraph==true and activity_bound("ObserveWorkgraphAdoptionRelease")),
    BindClaimResolutionCandidateIdentity:($runtime[0].releases.core==true and ($source|contains("gooo.primitive.claim-resolution-tuple.v1")) and activity_bound("BindClaimResolutionCandidateIdentity")),
    BindFourOfThirtyBaseline:$baseline_ok,
    BindWorkgraphDirectMapping:$candidate_ok,
    AdvanceToFiveOfThirty:($baseline_ok and $candidate_ok and ($b.summary.direct_mappings+$c.adoption.direct_mappings)==5 and (30-5)==25),
    CountFourIndependentConsumers:($b.summary.independent_consumer_adoptions==3 and $c.adoption.independent_consumers==1 and (3+1)==4),
    BindWorkgraphAdoptionEvidence:$candidate_ok,
    PreserveWorkgraphUnknownResolutions:($missing_core_ok and $missing_upstream_ok),
    PreserveWorkgraphRefutedResolutions:($tampered_ok and $laundered_ok and $child_authority_ok),
    BindTwelveMetaActivities:($activities_bound==12),
    PreserveOptionalReadOnlyBoundary:($runtime[0].repository_writes==0 and $runtime[0].local_tests_run==0 and $runtime[0].cross_project_required_gates==0 and
      $runtime[0].generator_authority==false and $runtime[0].central_orchestration_authorized==false and $runtime[0].go_fix_module_roots==0)
  } as $facts |
  def child_dependent($activity): ["BindWorkgraphDirectMapping","AdvanceToFiveOfThirty","CountFourIndependentConsumers","BindWorkgraphAdoptionEvidence"]|index($activity)!=null;
  def evaluate($cell):
    ($cell.activity) as $activity |
    if activity_bound($activity)|not then $cell+{state:"REFUTED",reason:"GOOO_META_ACTIVITY_MISSING",unknown_class:null,next_operation:"RESTORE_GOOO_META_ACTIVITY"}
    elif child_dependent($activity) and $candidate_mode=="UNKNOWN" then $cell+{state:"UNKNOWN",stage:$c.claim.stage,step:$c.claim.step,reason:$c.claim.reason,unknown_class:$c.claim.unknown_class,next_operation:$c.claim.next_operation}
    elif child_dependent($activity) and $candidate_mode=="REFUTED" then $cell+{state:"REFUTED",stage:$c.claim.stage,step:$c.claim.step,reason:$c.claim.reason,unknown_class:null,next_operation:$c.claim.next_operation}
    elif child_dependent($activity) and $candidate_mode=="INVALID" then $cell+{state:"REFUTED",stage:"PRODUCT_EVIDENCE",step:"VALIDATE_WORKGRAPH_ADOPTION_REPORT",reason:"WORKGRAPH_ADOPTION_REPORT_INVALID",unknown_class:null,next_operation:"RESTORE_PINNED_WORKGRAPH_ADOPTION_REPORT"}
    elif $facts[$activity]==true then $cell+{state:"CLOSED",reason:$cell.closed_reason,unknown_class:null,next_operation:"NONE"}
    else $cell+{state:"REFUTED",reason:$cell.refuted_reason,unknown_class:null} end;
  ($denominator[0].cells|map(evaluate(.))) as $cells |
  ([$cells[]|select(.state=="CLOSED")]|length) as $closed_count | ([$cells[]|select(.state=="UNKNOWN")]|length) as $unknown_count |
  ([$cells[]|select(.state=="REFUTED")]|length) as $refuted_count |
  (([$cells[]|select(.state=="REFUTED")]|first)//([$cells[]|select(.state=="UNKNOWN")]|first)) as $first_nonclosed |
  (if $candidate_ok then ($b.summary.direct_mappings+1) else $b.summary.direct_mappings end) as $direct_mappings |
  (if $candidate_ok then ($b.summary.independent_consumer_adoptions+1) else $b.summary.independent_consumer_adoptions end) as $independent_consumers |
  {
    schema:"gooo/link/cross-consumer-primitive-adoption-report/v4",phase:$phase,subject_sha:$head_sha,
    decision:(if $refuted_count>0 then "FAIL_CLOSED" elif $unknown_count>0 then "FIFTH_MAPPING_OBSERVATION_UNKNOWN" else "FIFTH_DIRECT_PRIMITIVE_MAPPING_OBSERVED" end),
    claim:{state:(if $refuted_count>0 then "REFUTED" elif $unknown_count>0 then "UNKNOWN" else "CLOSED" end),stage:($first_nonclosed.stage//null),step:($first_nonclosed.step//null),
      reason:($first_nonclosed.reason//"FIFTH_DIRECT_CLAIM_RESOLUTION_MAPPING_OBSERVED"),unknown_class:($first_nonclosed.unknown_class//null),
      next_operation:($first_nonclosed.next_operation//"OBSERVE_NEXT_INDEPENDENT_CONSUMER_ADOPTION")},
    summary:{total_cells:12,closed_cells:$closed_count,unknown_cells:$unknown_count,refuted_cells:$refuted_count,direct_mappings:$direct_mappings,
      mapping_denominator:30,mapping_remaining:(30-$direct_mappings),independent_consumer_adoptions:$independent_consumers,
      workgraph_claim_scenarios_observed:(if $candidate_ok then 3 else 0 end),workgraph_claim_scenarios_total:3,
      workgraph_released_claim_fields_observed:(if $candidate_ok then 18 else 0 end),workgraph_released_claim_fields_total:18,
      workgraph_core_claim_fields_observed:(if $candidate_ok then 18 else 0 end),workgraph_core_claim_fields_total:18,
      workgraph_inventory_facts_observed:(if $candidate_ok then 9 else 0 end),workgraph_inventory_fact_total:9,
      workgraph_invalid_tuples_rejected:(if $candidate_ok then 2 else 0 end),workgraph_invalid_tuple_total:2,
      workgraph_meta_activities_observed:(if $candidate_ok then 12 else 0 end),workgraph_meta_activity_total:12,
      workgraph_adverse_unknown_paths:([$missing_core_ok,$missing_upstream_ok]|map(select(.==true))|length),workgraph_adverse_unknown_path_total:2,
      workgraph_adverse_refuted_paths:([$tampered_ok,$laundered_ok,$child_authority_ok]|map(select(.==true))|length),workgraph_adverse_refuted_path_total:3,
      link_meta_activities_observed:$activities_bound,link_meta_activity_total:12,repository_writes:$runtime[0].repository_writes,
      local_tests_run:$runtime[0].local_tests_run,cross_project_required_gates:$runtime[0].cross_project_required_gates},
    authority:{observation_scope:"CROSS_CONSUMER_PRIMITIVE_ADOPTION_ONLY",baseline_release:"v0.16.0-dev",workgraph_adoption_release:"v0.3.0-dev",
      product_release_independence_required:true,common_generator_authorized:false,central_orchestration_authorized:$runtime[0].central_orchestration_authorized,
      generator_authority:$runtime[0].generator_authority,cross_project_required_gates:$runtime[0].cross_project_required_gates,
      local_tests_run:$runtime[0].local_tests_run,source_repository_writes:$runtime[0].repository_writes,go_fix_module_roots:$runtime[0].go_fix_module_roots,root_readme_readiness:"EXCLUDED"},
    performance:$runtime[0].performance,inventory:$inventory[0],cells:$cells,
    proofs:(["FOUNDATION","COHERENCE","REGRESSION"]|map(. as $choice|{choice:$choice,closed:([$cells[]|select(.proof_choice==$choice and .state=="CLOSED")]|length),total:([$cells[]|select(.proof_choice==$choice)]|length)})),
    indicator_classes:(["DRIVER","OUTCOME","GUARDRAIL"]|map(. as $class|{class:$class,closed:([$cells[]|select(.indicator_class==$class and .state=="CLOSED")]|length),total:([$cells[]|select(.indicator_class==$class)]|length)})),
    indicators:[
      {id:"gooo.metric.cross-consumer.direct-mappings.v4",class:"OUTCOME",activity:"AdvanceToFiveOfThirty",value:$direct_mappings,total:30,unit:"mappings"},
      {id:"gooo.metric.cross-consumer.mapping-remaining.v4",class:"OUTCOME",activity:"AdvanceToFiveOfThirty",value:(30-$direct_mappings),total:30,unit:"mappings"},
      {id:"gooo.metric.cross-consumer.independent-consumers.v4",class:"OUTCOME",activity:"CountFourIndependentConsumers",value:$independent_consumers,total:4,unit:"consumers"},
      {id:"gooo.metric.cross-consumer.workgraph-scenarios.v4",class:"DRIVER",activity:"BindWorkgraphAdoptionEvidence",value:(if $candidate_ok then 3 else 0 end),total:3,unit:"scenarios"},
      {id:"gooo.metric.cross-consumer.workgraph-claim-fields.v4",class:"DRIVER",activity:"BindWorkgraphAdoptionEvidence",value:(if $candidate_ok then 36 else 0 end),total:36,unit:"fields"},
      {id:"gooo.metric.cross-consumer.workgraph-inventory-facts.v4",class:"DRIVER",activity:"BindWorkgraphAdoptionEvidence",value:(if $candidate_ok then 9 else 0 end),total:9,unit:"facts"},
      {id:"gooo.metric.cross-consumer.workgraph-adverse-paths.v4",class:"GUARDRAIL",activity:"PreserveWorkgraphRefutedResolutions",value:([$missing_core_ok,$missing_upstream_ok,$tampered_ok,$laundered_ok,$child_authority_ok]|map(select(.==true))|length),total:5,unit:"paths"},
      {id:"gooo.metric.cross-consumer.meta-activities.v4",class:"DRIVER",activity:"BindTwelveMetaActivities",value:$activities_bound,total:12,unit:"activities"},
      {id:"gooo.metric.cross-consumer.graph-peak-rss.v4",class:"DRIVER",activity:"BindTwelveMetaActivities",value:$runtime[0].performance.graph_peak_rss_kib,unit:"KiB"},
      {id:"gooo.metric.cross-consumer.graph-wall-time.v4",class:"DRIVER",activity:"BindTwelveMetaActivities",value:$runtime[0].performance.graph_wall_ms,unit:"ms"},
      {id:"gooo.metric.cross-consumer.repository-writes.v4",class:"GUARDRAIL",activity:"PreserveOptionalReadOnlyBoundary",value:$runtime[0].repository_writes,total:0,unit:"writes"},
      {id:"gooo.metric.cross-consumer.gooo-lines.v4",class:"DRIVER",activity:"ObserveWorkgraphAdoptionRelease",value:$inventory[0].gooo.lines,unit:"lines"}
    ]
  }' > "$output"
