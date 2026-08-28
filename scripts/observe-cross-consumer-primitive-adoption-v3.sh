#!/usr/bin/env bash
set -euo pipefail

if test "$#" -ne 11; then
  echo "usage: observe-cross-consumer-primitive-adoption-v3.sh ROOT GRAPH BASELINE INFRA INFRA_UNKNOWN INFRA_TAMPER INFRA_AUTHORITY RUNTIME OUTPUT HEAD_SHA PHASE" >&2
  exit 64
fi

root=$(cd "$1" && pwd)
graph=$2
baseline=$3
infra=$4
infra_unknown=$5
infra_tamper=$6
infra_authority=$7
runtime=$8
output=$9
head_sha=${10}
phase=${11}
denominator="$root/contracts/cross-consumer-primitive-adoption-denominator-v3.json"
lock="$root/contracts/cross-consumer-primitive-adoption-release-lock-v3.json"
source="$root/examples/cross-consumer-primitive-adoption-v3/main.gooo"

for required in "$graph" "$baseline" "$infra" "$infra_unknown" "$infra_tamper" "$infra_authority" "$runtime" "$denominator" "$lock" "$source"; do
  test -f "$required" || { echo "missing required input: $required" >&2; exit 66; }
  test "$required" = "$source" || jq -e . "$required" >/dev/null
done

jq -e '.target_cells==12 and (.cells|length)==12 and ([.cells[].activity]|unique|length)==12 and
  ([.proof_totals[].total]|add)==12 and ([.indicator_totals[].total]|add)==12' "$denominator" >/dev/null
jq -e '.schema=="gooo/link/cross-consumer-primitive-adoption-release-lock/v3" and
  .core.tag=="v0.3.0-dev" and .baseline.tag=="v0.15.0-dev" and .infra.tag=="v0.6.0-dev"' "$lock" >/dev/null
test "$(grep -c '^activity ' "$source")" -eq 12
grep -Fq 'gooo.primitive.claim-resolution-tuple.v1' "$source"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
: > "$work/source-lines.ndjson"
while IFS= read -r -d '' file; do
  relative=${file#"$root/"}
  lines=$(wc -l < "$file" | tr -d ' ')
  case "$file" in
    *.go) language=Go ;;
    *.gooo) language=Gooo ;;
    *) continue ;;
  esac
  jq -cn --arg path "$relative" --arg language "$language" --argjson lines "$lines" \
    '{path:$path,language:$language,lines:$lines}' >> "$work/source-lines.ndjson"
done < <(find "$root" -type f -not -path "$root/.git/*" \( -name '*.go' -o -name '*.gooo' \) -print0 | sort -z)

repository_files=$(find "$root" -type f -not -path "$root/.git/*" | wc -l | tr -d ' ')
descendant_directories=$(find "$root" -mindepth 1 -type d -not -path "$root/.git" -not -path "$root/.git/*" | wc -l | tr -d ' ')
jq -s --argjson repository_files "$repository_files" --argjson descendant_directories "$descendant_directories" '
  . as $files |
  {repository_files:$repository_files,descendant_directories:$descendant_directories,root_readme_readiness:"EXCLUDED",
   go:{files:([$files[]|select(.language=="Go")]|length),lines:([$files[]|select(.language=="Go")|.lines]|add//0)},
   gooo:{files:([$files[]|select(.language=="Gooo")]|length),lines:([$files[]|select(.language=="Gooo")|.lines]|add//0)},
   per_file:$files}' "$work/source-lines.ndjson" > "$work/inventory.json"

jq -S -n \
  --slurpfile denominator "$denominator" --slurpfile lock "$lock" --slurpfile graph "$graph" \
  --slurpfile baseline "$baseline" --slurpfile infra "$infra" --slurpfile infra_unknown "$infra_unknown" \
  --slurpfile infra_tamper "$infra_tamper" --slurpfile infra_authority "$infra_authority" \
  --slurpfile runtime "$runtime" --slurpfile inventory "$work/inventory.json" --rawfile source "$source" \
  --arg head_sha "$head_sha" --arg phase "$phase" '
  def has_six($claim):
    ($claim|type)=="object" and ($claim|has("state")) and ($claim|has("stage")) and ($claim|has("step")) and
    ($claim|has("reason")) and ($claim|has("unknown_class")) and ($claim|has("next_operation"));
  def activity_bound($activity): ([$graph[0].nodes[]?|select(.kind=="Activity" and .name==$activity)]|length)==1;
  ($baseline[0]) as $b |
  ($infra[0]) as $i |
  ($infra_unknown[0]) as $iu |
  ($infra_tamper[0]) as $it |
  ($infra_authority[0]) as $ia |
  ($b.schema=="gooo/link/cross-consumer-primitive-adoption-report/v2" and $b.subject_sha==$lock[0].baseline.target_commit_sha and
    $b.decision=="THIRD_DIRECT_PRIMITIVE_MAPPING_OBSERVED" and $b.summary.closed_cells==12 and $b.summary.total_cells==12 and
    $b.summary.direct_mappings==3 and $b.summary.mapping_denominator==30 and $b.summary.mapping_remaining==27 and
    $b.summary.independent_consumer_adoptions==2 and $b.summary.cross_project_required_gates==0 and
    $b.authority.common_generator_authorized==false and $b.authority.central_orchestration_authorized==false) as $baseline_ok |
  ($i.schema=="gooo/infra-evidence/claim-resolution-adoption-report/v1" and $i.subject_sha==$lock[0].infra.target_commit_sha and
    $i.decision=="ADOPTION_EVIDENCE_CLOSED" and $i.claim.state=="CLOSED" and $i.summary.closed==12 and $i.summary.total==12 and
    $i.adoption.candidate_id=="gooo.primitive.claim-resolution-tuple.v1" and $i.adoption.direct_mappings==1 and $i.adoption.direct_mapping_total==1 and
    $i.adoption.released_scenarios==3 and $i.adoption.released_scenario_total==3 and
    $i.adoption.released_claim_fields==18 and $i.adoption.released_claim_field_total==18 and
    $i.adoption.core_claim_fields==18 and $i.adoption.core_claim_field_total==18 and
    $i.adoption.invalid_tuples_rejected==2 and $i.adoption.invalid_tuple_total==2 and
    $i.adoption.activities_bound==12 and $i.adoption.activity_total==12 and
    ([ $i.proofs[]|select(.closed==4 and .total==4) ]|length)==3 and
    ([ $i.indicator_classes[]|select(.closed==4 and .total==4) ]|length)==3 and
    $i.authority.generator_authority==false and $i.authority.cross_project_required_gates==0 and
    $i.authority.repository_writes==0 and $i.authority.local_test_executions==0) as $infra_ok |
  (if $infra_ok then "CLOSED"
   elif $i.decision=="INCOMPLETE" and $i.claim.state=="UNKNOWN" and has_six($i.claim) then "UNKNOWN"
   elif $i.decision=="FAIL_CLOSED" and $i.claim.state=="REFUTED" and has_six($i.claim) then "REFUTED"
   else "INVALID" end) as $infra_mode |
  ($iu.decision=="INCOMPLETE" and $iu.summary.closed==11 and $iu.summary.unknown==1 and $iu.summary.refuted==0 and
    $iu.claim=={next_operation:"PROVIDE_CORE_CLAIM_RESOLUTION_RECEIPT",reason:"CORE_CLAIM_RESOLUTION_RECEIPT_UNAVAILABLE",stage:"CORE_RECEIPT",state:"UNKNOWN",step:"OBSERVE_CLAIM_RESOLUTION_RECEIPT",unknown_class:"DIRECT_MISSING"}) as $unknown_path_ok |
  ($it.decision=="FAIL_CLOSED" and $it.summary.closed==10 and $it.summary.refuted==2 and
    $it.claim.state=="REFUTED" and $it.claim.reason=="RELEASED_INFRA_UNKNOWN_CLAIM_MISMATCH") as $tamper_path_ok |
  ($ia.decision=="FAIL_CLOSED" and $ia.summary.closed==11 and $ia.summary.refuted==1 and
    $ia.claim.state=="REFUTED" and $ia.claim.reason=="ADOPTION_AUTHORITY_BOUNDARY_VIOLATED") as $authority_path_ok |
  ([$denominator[0].cells[].activity|select(activity_bound(.))]|length) as $activities_bound |
  {
    ObserveLinkBaselineRelease:($runtime[0].releases.baseline==true and activity_bound("ObserveLinkBaselineRelease")),
    ObserveInfraAdoptionRelease:($runtime[0].releases.infra==true and activity_bound("ObserveInfraAdoptionRelease")),
    BindClaimResolutionCandidateIdentity:($runtime[0].releases.core==true and ($source|contains("gooo.primitive.claim-resolution-tuple.v1")) and activity_bound("BindClaimResolutionCandidateIdentity")),
    BindThreeOfThirtyBaseline:$baseline_ok,
    BindInfraDirectMapping:$infra_ok,
    AdvanceToFourOfThirty:($baseline_ok and $infra_ok and ($b.summary.direct_mappings+$i.adoption.direct_mappings)==4 and (30-4)==26),
    CountThreeIndependentConsumers:($b.summary.independent_consumer_adoptions==2 and $i.adoption.independent_consumers==1 and (2+1)==3),
    BindInfraAdoptionEvidence:$infra_ok,
    PreserveInfraUnknownResolution:$unknown_path_ok,
    PreserveInfraRefutedResolution:($tamper_path_ok and $authority_path_ok),
    BindTwelveMetaActivities:($activities_bound==12),
    PreserveOptionalReadOnlyBoundary:($runtime[0].repository_writes==0 and $runtime[0].local_tests_run==0 and
      $runtime[0].cross_project_required_gates==0 and $runtime[0].generator_authority==false and
      $runtime[0].central_orchestration_authorized==false and $runtime[0].go_fix_module_roots==0)
  } as $facts |
  def child_dependent($activity): ["BindInfraDirectMapping","AdvanceToFourOfThirty","CountThreeIndependentConsumers","BindInfraAdoptionEvidence"]|index($activity)!=null;
  def evaluate($cell):
    ($cell.activity) as $activity |
    if activity_bound($activity)|not then
      $cell+{state:"REFUTED",reason:"GOOO_META_ACTIVITY_MISSING",unknown_class:null,next_operation:"RESTORE_GOOO_META_ACTIVITY"}
    elif child_dependent($activity) and $infra_mode=="UNKNOWN" then
      $cell+{state:"UNKNOWN",stage:$i.claim.stage,step:$i.claim.step,reason:$i.claim.reason,unknown_class:$i.claim.unknown_class,next_operation:$i.claim.next_operation}
    elif child_dependent($activity) and $infra_mode=="REFUTED" then
      $cell+{state:"REFUTED",stage:$i.claim.stage,step:$i.claim.step,reason:$i.claim.reason,unknown_class:null,next_operation:$i.claim.next_operation}
    elif child_dependent($activity) and $infra_mode=="INVALID" then
      $cell+{state:"REFUTED",stage:"PRODUCT_EVIDENCE",step:"VALIDATE_INFRA_ADOPTION_REPORT",reason:"INFRA_ADOPTION_REPORT_INVALID",unknown_class:null,next_operation:"RESTORE_PINNED_INFRA_ADOPTION_REPORT"}
    elif $facts[$activity]==true then
      $cell+{state:"CLOSED",reason:$cell.closed_reason,unknown_class:null,next_operation:"NONE"}
    else
      $cell+{state:"REFUTED",reason:$cell.refuted_reason,unknown_class:null}
    end;
  ($denominator[0].cells|map(evaluate(.))) as $cells |
  ([$cells[]|select(.state=="CLOSED")]|length) as $closed_count |
  ([$cells[]|select(.state=="UNKNOWN")]|length) as $unknown_count |
  ([$cells[]|select(.state=="REFUTED")]|length) as $refuted_count |
  (([$cells[]|select(.state=="REFUTED")]|first)//([$cells[]|select(.state=="UNKNOWN")]|first)) as $first_nonclosed |
  (if $infra_ok then 4 else 3 end) as $direct_mappings |
  (if $infra_ok then 3 else 2 end) as $independent_consumers |
  {
    schema:"gooo/link/cross-consumer-primitive-adoption-report/v3",phase:$phase,subject_sha:$head_sha,
    decision:(if $refuted_count>0 then "FAIL_CLOSED" elif $unknown_count>0 then "FOURTH_MAPPING_OBSERVATION_UNKNOWN" else "FOURTH_DIRECT_PRIMITIVE_MAPPING_OBSERVED" end),
    claim:{state:(if $refuted_count>0 then "REFUTED" elif $unknown_count>0 then "UNKNOWN" else "CLOSED" end),
      stage:($first_nonclosed.stage//null),step:($first_nonclosed.step//null),
      reason:($first_nonclosed.reason//"FOURTH_DIRECT_CLAIM_RESOLUTION_MAPPING_OBSERVED"),
      unknown_class:($first_nonclosed.unknown_class//null),
      next_operation:($first_nonclosed.next_operation//"OBSERVE_NEXT_INDEPENDENT_CONSUMER_ADOPTION")},
    summary:{total_cells:12,closed_cells:$closed_count,unknown_cells:$unknown_count,refuted_cells:$refuted_count,
      direct_mappings:$direct_mappings,mapping_denominator:30,mapping_remaining:(30-$direct_mappings),
      independent_consumer_adoptions:$independent_consumers,infra_claim_scenarios_observed:(if $infra_ok then 3 else 0 end),infra_claim_scenarios_total:3,
      infra_released_claim_fields_observed:(if $infra_ok then 18 else 0 end),infra_released_claim_fields_total:18,
      infra_core_claim_fields_observed:(if $infra_ok then 18 else 0 end),infra_core_claim_fields_total:18,
      infra_invalid_tuples_rejected:(if $infra_ok then 2 else 0 end),infra_invalid_tuple_total:2,
      infra_meta_activities_observed:(if $infra_ok then 12 else 0 end),infra_meta_activity_total:12,
      infra_adverse_unknown_paths:(if $unknown_path_ok then 1 else 0 end),infra_adverse_unknown_path_total:1,
      infra_adverse_refuted_paths:([$tamper_path_ok,$authority_path_ok]|map(select(.==true))|length),infra_adverse_refuted_path_total:2,
      link_meta_activities_observed:$activities_bound,link_meta_activity_total:12,repository_writes:$runtime[0].repository_writes,
      local_tests_run:$runtime[0].local_tests_run,cross_project_required_gates:$runtime[0].cross_project_required_gates},
    authority:{observation_scope:"CROSS_CONSUMER_PRIMITIVE_ADOPTION_ONLY",baseline_release:"v0.15.0-dev",infra_adoption_release:"v0.6.0-dev",
      product_release_independence_required:true,common_generator_authorized:false,central_orchestration_authorized:$runtime[0].central_orchestration_authorized,
      generator_authority:$runtime[0].generator_authority,cross_project_required_gates:$runtime[0].cross_project_required_gates,
      local_tests_run:$runtime[0].local_tests_run,source_repository_writes:$runtime[0].repository_writes,go_fix_module_roots:$runtime[0].go_fix_module_roots,
      root_readme_readiness:"EXCLUDED"},
    performance:$runtime[0].performance,inventory:$inventory[0],cells:$cells,
    proofs:(["FOUNDATION","COHERENCE","REGRESSION"]|map(. as $choice|{choice:$choice,closed:([$cells[]|select(.proof_choice==$choice and .state=="CLOSED")]|length),total:([$cells[]|select(.proof_choice==$choice)]|length)})),
    indicator_classes:(["DRIVER","OUTCOME","GUARDRAIL"]|map(. as $class|{class:$class,closed:([$cells[]|select(.indicator_class==$class and .state=="CLOSED")]|length),total:([$cells[]|select(.indicator_class==$class)]|length)})),
    indicators:[
      {id:"gooo.metric.cross-consumer.direct-mappings.v3",class:"OUTCOME",activity:"AdvanceToFourOfThirty",value:$direct_mappings,total:30,unit:"mappings"},
      {id:"gooo.metric.cross-consumer.mapping-remaining.v3",class:"OUTCOME",activity:"AdvanceToFourOfThirty",value:(30-$direct_mappings),total:30,unit:"mappings"},
      {id:"gooo.metric.cross-consumer.independent-consumers.v3",class:"OUTCOME",activity:"CountThreeIndependentConsumers",value:$independent_consumers,total:3,unit:"consumers"},
      {id:"gooo.metric.cross-consumer.infra-scenarios.v3",class:"DRIVER",activity:"BindInfraAdoptionEvidence",value:(if $infra_ok then 3 else 0 end),total:3,unit:"scenarios"},
      {id:"gooo.metric.cross-consumer.infra-claim-fields.v3",class:"DRIVER",activity:"BindInfraAdoptionEvidence",value:(if $infra_ok then 36 else 0 end),total:36,unit:"fields"},
      {id:"gooo.metric.cross-consumer.infra-invalid-tuples.v3",class:"GUARDRAIL",activity:"PreserveInfraRefutedResolution",value:(if $infra_ok then 2 else 0 end),total:2,unit:"tuples"},
      {id:"gooo.metric.cross-consumer.meta-activities.v3",class:"DRIVER",activity:"BindTwelveMetaActivities",value:$activities_bound,total:12,unit:"activities"},
      {id:"gooo.metric.cross-consumer.graph-peak-rss.v3",class:"DRIVER",activity:"BindTwelveMetaActivities",value:$runtime[0].performance.graph_peak_rss_kib,unit:"KiB"},
      {id:"gooo.metric.cross-consumer.graph-wall-time.v3",class:"DRIVER",activity:"BindTwelveMetaActivities",value:$runtime[0].performance.graph_wall_ms,unit:"ms"},
      {id:"gooo.metric.cross-consumer.repository-writes.v3",class:"GUARDRAIL",activity:"PreserveOptionalReadOnlyBoundary",value:$runtime[0].repository_writes,total:0,unit:"writes"},
      {id:"gooo.metric.cross-consumer.go-lines.v3",class:"DRIVER",activity:"ObserveLinkBaselineRelease",value:$inventory[0].go.lines,unit:"lines"},
      {id:"gooo.metric.cross-consumer.gooo-lines.v3",class:"DRIVER",activity:"ObserveInfraAdoptionRelease",value:$inventory[0].gooo.lines,unit:"lines"}
    ]
  }' > "$output"
