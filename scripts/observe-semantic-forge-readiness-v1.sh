#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 12 ]; then
  echo "usage: observe-semantic-forge-readiness-v1.sh ROOT GRAPH LINK_RELEASE LINK_REPORT LOCAL_RELEASE LOCAL_DIR INFRA_RELEASE INFRA_DIR RUNTIME OUTPUT HEAD_SHA PHASE" >&2
  exit 64
fi

root=$(cd "$1" && pwd)
graph=$2
link_release=$3
link_report=$4
local_release=$5
local_dir=$6
infra_release=$7
infra_dir=$8
runtime=$9
output=${10}
head_sha=${11}
phase=${12}

denominator="$root/contracts/semantic-forge-readiness-denominator-v1.json"
lock="$root/contracts/semantic-forge-readiness-release-lock-v1.json"
observation="$root/examples/semantic-forge-readiness-v1/observation.gooo"
local_report="$local_dir/normal.json"
local_packet="$local_dir/project-plan.json"
local_markdown="$local_dir/project-plan.md"
local_runtime="$local_dir/runtime.json"
local_replay="$local_dir/replay.json"
local_inventory="$local_dir/inventory.json"
infra_report="$infra_dir/semantic-deployment-plan-evaluation.json"
infra_packet="$infra_dir/deployment-plan.json"
infra_markdown="$infra_dir/deployment-plan.md"
infra_runtime="$infra_dir/semantic-deployment-plan-runtime.json"
infra_replay="$infra_dir/semantic-deployment-plan-replay.json"
infra_inventory="$infra_dir/semantic-deployment-plan-inventory.json"

for required in "$graph" "$link_release" "$link_report" "$local_release" "$infra_release" "$runtime" "$denominator" "$lock" "$local_report" "$local_packet" "$local_runtime" "$local_replay" "$local_inventory" "$infra_report" "$infra_packet" "$infra_runtime" "$infra_replay" "$infra_inventory"; do
  test -f "$required" || { echo "missing required input: $required" >&2; exit 66; }
  jq -e . "$required" >/dev/null
done
test -s "$local_markdown"
test -s "$infra_markdown"
test -f "$observation"
jq -e '.target_cells==12 and (.cells|length)==12 and (.shared_invariants|length)==8 and ([.cells[].activity]|unique|length)==12 and ([.proof_totals[].total]|add)==12 and ([.indicator_totals[].total]|add)==12' "$denominator" >/dev/null
jq -e '.schema=="gooo/link/semantic-forge-readiness-release-lock/v1" and .link.tag=="v0.25.0-dev" and .local.tag=="v0.8.0-dev" and .infra.tag=="v0.8.0-dev" and .core.tag=="v0.4.0-dev" and (.local.assets|length)==6 and (.infra.assets|length)==6' "$lock" >/dev/null
test "$(grep -c '^activity ' "$observation")" -eq 12

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
: > "$work/source-lines.ndjson"
while IFS= read -r -d '' file; do
  relative=$(printf '%s' "$file" | sed "s#^$root/##")
  lines=$(wc -l < "$file" | tr -d ' ')
  case "$file" in *.go) language=Go ;; *.gooo) language=Gooo ;; *) continue ;; esac
  jq -cn --arg path "$relative" --arg language "$language" --argjson lines "$lines" '{path:$path,language:$language,lines:$lines}' >> "$work/source-lines.ndjson"
done < <(find "$root" -type f -not -path "$root/.git/*" \( -name '*.go' -o -name '*.gooo' \) -print0 | sort -z)
repository_files=$(find "$root" -type f -not -path "$root/.git/*" | wc -l | tr -d ' ')
descendant_directories=$(find "$root" -mindepth 1 -type d -not -path "$root/.git" -not -path "$root/.git/*" | wc -l | tr -d ' ')
jq -s --argjson repository_files "$repository_files" --argjson descendant_directories "$descendant_directories" '
  . as $files | {repository_files:$repository_files,descendant_directories:$descendant_directories,root_readme_readiness:"EXCLUDED",
    go:{files:([$files[]|select(.language=="Go")]|length),lines:([$files[]|select(.language=="Go")|.lines]|add//0)},
    gooo:{files:([$files[]|select(.language=="Gooo")]|length),lines:([$files[]|select(.language=="Gooo")|.lines]|add//0)},per_file:$files}
' "$work/source-lines.ndjson" > "$work/inventory.json"

jq -S -n \
  --slurpfile denominator "$denominator" --slurpfile lock "$lock" --slurpfile graph "$graph" \
  --slurpfile link_release "$link_release" --slurpfile link_report "$link_report" \
  --slurpfile local_release "$local_release" --slurpfile local_report "$local_report" --slurpfile local_packet "$local_packet" \
  --rawfile local_markdown "$local_markdown" --slurpfile local_runtime "$local_runtime" --slurpfile local_replay "$local_replay" --slurpfile local_inventory "$local_inventory" \
  --slurpfile infra_release "$infra_release" --slurpfile infra_report "$infra_report" --slurpfile infra_packet "$infra_packet" \
  --rawfile infra_markdown "$infra_markdown" --slurpfile infra_runtime "$infra_runtime" --slurpfile infra_replay "$infra_replay" --slurpfile infra_inventory "$infra_inventory" \
  --slurpfile runtime "$runtime" --slurpfile inventory "$work/inventory.json" --arg head_sha "$head_sha" --arg phase "$phase" '
  def activity_bound($activity): ([$graph[0].nodes[]?|select(.kind=="Activity" and .name==$activity)]|length)==1;
  def asset_matches($release;$asset): any($release.assets[];.id==$asset.id and .name==$asset.name and .size==$asset.size and .digest==$asset.digest);
  def release_ok($release;$expected):
    $release.id==$expected.release_id and $release.tag_name==$expected.tag and $release.target_commitish==$expected.target_commit_sha and
    $release.draft==false and $release.prerelease==$expected.prerelease;
  (release_ok($link_release[0];$lock[0].link) and asset_matches($link_release[0];$lock[0].link.assets.report)) as $link_release_ok |
  ($link_report[0].schema=="gooo/link/infra-deployment-plan-consumer-report/v7" and
    $link_report[0].subject_sha==$lock[0].link.target_commit_sha and $link_report[0].decision=="INFRA_DEPLOYMENT_PLAN_CONSUMER_OBSERVED" and
    $link_report[0].claim.state=="CLOSED" and $link_report[0].summary.closed_cells==12 and $link_report[0].summary.total_cells==12 and
    $link_report[0].summary.primitive_mappings_current==6 and $link_report[0].summary.independent_consumers_current==2 and
    $link_report[0].summary.independent_consumer_increment==1 and $link_report[0].summary.external_use_cases_evidenced==0 and
    $link_report[0].summary.external_use_cases_declared==1 and $link_report[0].summary.utility_state=="UNKNOWN" and
    $link_report[0].authority.cross_project_required_gates==0 and $link_report[0].authority.local_tests_run==0 and
    $link_report[0].authority.source_repository_writes==0 and $link_report[0].authority.generator_authority==false) as $baseline_ok |
  (release_ok($local_release[0];$lock[0].local)) as $local_release_ok |
  (release_ok($infra_release[0];$lock[0].infra)) as $infra_release_ok |
  (($lock[0].local.assets|to_entries|length)==6 and all($lock[0].local.assets|to_entries[];asset_matches($local_release[0];.value))) as $local_assets_ok |
  (($lock[0].infra.assets|to_entries|length)==6 and all($lock[0].infra.assets|to_entries[];asset_matches($infra_release[0];.value))) as $infra_assets_ok |
  ($local_report[0].schema=="gooo/local-ledger/semantic-project-plan-evaluation/v1" and
    $local_report[0].subject_sha==$lock[0].local.target_commit_sha and $local_report[0].decision=="SEMANTIC_PROJECT_PLAN_PACKET_GENERATED" and
    $local_report[0].claim.state=="CLOSED" and $local_report[0].summary.cells_closed==12 and $local_report[0].summary.cells_total==12 and
    $local_report[0].summary.meta_activities_bound==12 and $local_report[0].summary.project_activities_observed==6 and
    $local_report[0].summary.dependencies_observed==8 and $local_report[0].summary.dependency_kinds_observed==4 and
    $local_report[0].summary.generated_artifacts_observed==2 and $local_report[0].summary.unknown_coordinates_observed==6 and
    $local_report[0].summary.refuted_boundaries_observed==3 and $local_report[0].summary.replay_comparisons_observed==7) as $local_report_ok |
  ($infra_report[0].schema=="gooo/infra-evidence/semantic-deployment-plan-evaluation/v1" and
    $infra_report[0].subject_sha==$lock[0].infra.target_commit_sha and $infra_report[0].decision=="SEMANTIC_DEPLOYMENT_PLAN_GENERATED" and
    $infra_report[0].claim.state=="CLOSED" and $infra_report[0].summary.cells_closed==12 and $infra_report[0].summary.cells_total==12 and
    $infra_report[0].summary.meta_activities_bound==12 and $infra_report[0].summary.deployment_activities_observed==6 and
    $infra_report[0].summary.dependencies_observed==8 and $infra_report[0].summary.dependency_kinds_observed==4 and
    $infra_report[0].summary.generated_artifacts_observed==2 and $infra_report[0].summary.unknown_coordinates_observed==6 and
    $infra_report[0].summary.refuted_boundaries_observed==3 and $infra_report[0].summary.replay_comparisons_observed==7) as $infra_report_ok |
  ($local_packet[0].schema=="gooo/local-ledger/semantic-project-plan/v1" and $local_packet[0].decision=="PROJECT_PLAN_PACKET_GENERATED" and
    ($local_packet[0].steps|length)==6 and ($local_packet[0].dependencies|length)==8 and ($local_packet[0].refutation_boundaries|length)==3) as $local_packet_ok |
  ($infra_packet[0].schema=="gooo/infra-evidence/semantic-deployment-plan/v1" and $infra_packet[0].decision=="DEPLOYMENT_PLAN_GENERATED" and
    ($infra_packet[0].steps|length)==6 and ($infra_packet[0].dependencies|length)==8 and ($infra_packet[0].refutation_boundaries|length)==3) as $infra_packet_ok |
  ($local_runtime[0].schema=="gooo/local-ledger/semantic-project-plan-runtime/v1" and $local_runtime[0].repository_writes==0 and
    $local_runtime[0].local_tests==0 and $local_runtime[0].cross_project_required_gates==0 and $local_runtime[0].root_readme_readiness=="EXCLUDED") as $local_runtime_ok |
  ($infra_runtime[0].schema=="gooo/infra-evidence/semantic-deployment-plan-runtime/v1" and $infra_runtime[0].repository_writes==0 and
    $infra_runtime[0].local_tests==0 and $infra_runtime[0].cross_project_required_gates==0 and $infra_runtime[0].root_readme_readiness=="EXCLUDED") as $infra_runtime_ok |
  ($local_replay[0].comparisons_satisfied==7 and $local_replay[0].comparisons_total==7 and $local_replay[0].mismatches==0) as $local_replay_ok |
  ($infra_replay[0].comparisons_satisfied==7 and $infra_replay[0].comparisons_total==7 and $infra_replay[0].mismatches==0) as $infra_replay_ok |
  ($local_inventory[0].root_readme_readiness=="EXCLUDED" and $infra_inventory[0].root_readme_readiness=="EXCLUDED") as $inventories_ok |
  (($local_markdown|contains("# Semantic project plan")) and ($infra_markdown|contains("# Semantic deployment plan"))) as $markdown_ok |
  ($local_packet[0].primitive==$infra_packet[0].primitive and $local_packet[0].primitive=={id:"gooo.primitive.claim-dependency-causality.v1",release:"v0.4.0-dev"}) as $primitive_ok |
  ($local_packet[0].summary.activities==6 and $infra_packet[0].summary.activities==6 and
    $local_packet[0].summary.dependencies==8 and $infra_packet[0].summary.dependencies==8 and
    $local_packet[0].summary.dependency_kinds==4 and $infra_packet[0].summary.dependency_kinds==4 and
    $local_packet[0].kind_counts==$infra_packet[0].kind_counts and $local_packet[0].kind_counts=={requires:3,supports:2,contradicts:2,failure_entailment:1}) as $shape_ok |
  ($local_packet[0].summary.unknown_coordinates==6 and $infra_packet[0].summary.unknown_coordinates==6 and
    $local_packet[0].summary.refuted_boundaries==3 and $infra_packet[0].summary.refuted_boundaries==3 and
    $local_packet[0].recovery.state=="UNKNOWN" and $infra_packet[0].recovery.state=="UNKNOWN" and
    $local_packet[0].recovery.unknown_class=="DIRECT_MISSING" and $infra_packet[0].recovery.unknown_class=="DIRECT_MISSING") as $resolution_ok |
  ($local_packet[0].summary.generated_artifacts==2 and $infra_packet[0].summary.generated_artifacts==2 and
    $local_replay_ok and $infra_replay_ok and $markdown_ok) as $artifact_ok |
  ($local_report[0].utility.declared_external_use_cases==1 and $local_report[0].utility.evidenced_external_use_cases==0 and $local_report[0].utility.state=="UNKNOWN" and
    $infra_report[0].utility.declared_external_use_cases==1 and $infra_report[0].utility.evidenced_external_use_cases==0 and $infra_report[0].utility.state=="UNKNOWN") as $utility_ok |
  ($local_runtime_ok and $infra_runtime_ok and
    $runtime[0].repository_writes==0 and $runtime[0].local_tests_run==0 and $runtime[0].cross_project_required_gates==0 and
    $runtime[0].common_generator_authorized==false and $runtime[0].product_generation_authorized==false and
    $runtime[0].central_orchestration_authorized==false and $runtime[0].go_fix_module_roots==0) as $authority_ok |
  ($local_release_ok and $local_assets_ok and $local_report_ok and $local_packet_ok and $local_runtime_ok and $local_replay_ok and $inventories_ok) as $local_product_ok |
  ($infra_release_ok and $infra_assets_ok and $infra_report_ok and $infra_packet_ok and $infra_runtime_ok and $infra_replay_ok and $inventories_ok) as $infra_product_ok |
  (if $runtime[0].releases.local!=true or $runtime[0].releases.infra!=true then "UNKNOWN" elif $local_product_ok and $infra_product_ok then "CLOSED" else "REFUTED" end) as $product_mode |
  ([$denominator[0].cells[].activity|select(activity_bound(.))]|length) as $activities_bound |
  ($baseline_ok and $primitive_ok and $shape_ok and $resolution_ok and $artifact_ok and $utility_ok and $authority_ok and $local_product_ok and $infra_product_ok) as $selection_ok |
  {
    ObserveTwoConsumerLinkRelease:($runtime[0].releases.link==true and $link_release_ok and $baseline_ok),
    ObserveCoreMetaToolRelease:($runtime[0].releases.core==true),
    ObserveLocalProductRelease:($runtime[0].releases.local==true and $local_product_ok),
    ObserveInfraProductRelease:($runtime[0].releases.infra==true and $infra_product_ok),
    BindSharedPrimitiveIdentity:$primitive_ok,
    BindSharedGraphShape:$shape_ok,
    BindSharedResolutionModel:$resolution_ok,
    BindSharedArtifactModel:$artifact_ok,
    PreserveAggregateUtilityUnknown:$utility_ok,
    PreserveReadOnlyProductAuthority:$authority_ok,
    BindTwelveReadinessMetaActivities:($activities_bound==12),
    SelectOptionalForgeExperiment:$selection_ok
  } as $facts |
  def product_dependent($activity):
    ["ObserveInfraProductRelease","BindSharedPrimitiveIdentity","BindSharedGraphShape","BindSharedResolutionModel","BindSharedArtifactModel","PreserveAggregateUtilityUnknown","PreserveReadOnlyProductAuthority","SelectOptionalForgeExperiment"]|index($activity)!=null;
  def evaluate($cell):
    ($cell.activity) as $activity |
    if activity_bound($activity)|not then $cell+{state:"REFUTED",reason:"GOOO_META_ACTIVITY_MISSING",unknown_class:null,next_operation:"RESTORE_GOOO_META_ACTIVITY",blocked_by:[]}
    elif product_dependent($activity) and $product_mode=="UNKNOWN" then $cell+{state:"UNKNOWN",stage:"PRODUCT_RELEASE",step:"OBSERVE_INFRA_PRODUCT_RELEASE",reason:"INFRA_PRODUCT_RELEASE_UNAVAILABLE",unknown_class:"DIRECT_MISSING",next_operation:"FETCH_PINNED_INFRA_PRODUCT_RELEASE",blocked_by:["release:v0.8.0-dev"]}
    elif product_dependent($activity) and $product_mode=="REFUTED" then $cell+{state:"REFUTED",stage:"PRODUCT_EVIDENCE",step:"VALIDATE_TWO_PRODUCT_RELEASES",reason:"PRODUCT_RELEASE_EVIDENCE_MISMATCH",unknown_class:null,next_operation:"RESTORE_PRODUCT_RELEASE_EVIDENCE",blocked_by:["local:v0.8.0-dev","infra:v0.8.0-dev"]}
    elif $facts[$activity]==true then $cell+{state:"CLOSED",reason:$cell.closed_reason,unknown_class:null,next_operation:"NONE",blocked_by:[]}
    else $cell+{state:"REFUTED",reason:$cell.refuted_reason,unknown_class:null,next_operation:$cell.next_operation,blocked_by:[]} end;
  ($denominator[0].cells|map(evaluate(.))) as $cells |
  ([$cells[]|select(.state=="CLOSED")]|length) as $closed_count |
  ([$cells[]|select(.state=="UNKNOWN")]|length) as $unknown_count |
  ([$cells[]|select(.state=="REFUTED")]|length) as $refuted_count |
  (([$cells[]|select(.state=="REFUTED")]|first)//([$cells[]|select(.state=="UNKNOWN")]|first)) as $first_nonclosed |
  ([$primitive_ok,$shape_ok,$resolution_ok,$artifact_ok]|map(if . then 2 else 0 end)|add) as $shared_invariants |
  {
    schema:"gooo/link/semantic-forge-readiness-report/v1",phase:$phase,subject_sha:$head_sha,
    decision:(if $refuted_count>0 then "FAIL_CLOSED" elif $unknown_count>0 then "SEMANTIC_FORGE_READINESS_UNKNOWN" else "SEMANTIC_FORGE_EXPERIMENT_READY" end),
    claim:{state:(if $refuted_count>0 then "REFUTED" elif $unknown_count>0 then "UNKNOWN" else "CLOSED" end),stage:($first_nonclosed.stage//null),step:($first_nonclosed.step//null),
      reason:($first_nonclosed.reason//"TWELVE_OF_TWELVE_FORGE_READINESS_CELLS_CLOSED"),unknown_class:($first_nonclosed.unknown_class//null),
      next_operation:($first_nonclosed.next_operation//"CREATE_OPTIONAL_SEMANTIC_FORGE_EXPERIMENT"),blocked_by:($first_nonclosed.blocked_by//[])},
    summary:{
      total_cells:12,closed_cells:$closed_count,unknown_cells:$unknown_count,refuted_cells:$refuted_count,
      independent_consumers_observed:(if $baseline_ok then 2 else 0 end),product_releases_observed:([$local_product_ok,$infra_product_ok]|map(select(.==true))|length),
      selected_evidence_assets_observed:(if $local_assets_ok then 6 else 0 end)+(if $infra_assets_ok then 6 else 0 end),selected_evidence_assets_total:12,
      shared_invariants_observed:$shared_invariants,shared_invariants_total:8,
      product_conformance_cells_observed:(if $local_report_ok then 12 else 0 end)+(if $infra_report_ok then 12 else 0 end),product_conformance_cells_total:24,
      product_activities_observed:(if $local_report_ok then 6 else 0 end)+(if $infra_report_ok then 6 else 0 end),product_activities_total:12,
      product_dependencies_observed:(if $local_report_ok then 8 else 0 end)+(if $infra_report_ok then 8 else 0 end),product_dependencies_total:16,
      generated_artifacts_observed:(if $artifact_ok then 4 else 0 end),generated_artifacts_total:4,
      unknown_coordinates_observed:(if $resolution_ok then 12 else 0 end),unknown_coordinates_total:12,
      refuted_boundaries_observed:(if $resolution_ok then 6 else 0 end),refuted_boundaries_total:6,
      replay_comparisons_observed:(if $artifact_ok then 14 else 0 end),replay_comparisons_total:14,
      external_use_cases_declared:2,external_use_cases_evidenced:(($local_report[0].utility.evidenced_external_use_cases//0)+($infra_report[0].utility.evidenced_external_use_cases//0)),
      utility_state:(if $utility_ok then "UNKNOWN" else "INVALID" end),primitive_mappings_observed:($runtime[0].primitive_mappings_observed//0),primitive_mapping_denominator:30,
      optional_forge_experiment_selected:(if $closed_count==12 then 1 else 0 end),common_generator_authorized:(if $runtime[0].common_generator_authorized then 1 else 0 end),
      repository_writes:$runtime[0].repository_writes,local_tests_run:$runtime[0].local_tests_run,cross_project_required_gates:$runtime[0].cross_project_required_gates
    },
    shared_invariants:[
      {id:"PRIMITIVE_IDENTITY",observed:$primitive_ok},{id:"SIX_ACTIVITY_GRAPH",observed:$shape_ok},{id:"EIGHT_DEPENDENCY_GRAPH",observed:$shape_ok},{id:"FOUR_KIND_PROFILE",observed:$shape_ok},
      {id:"TWO_ARTIFACT_PACKET",observed:$artifact_ok},{id:"SIX_UNKNOWN_COORDINATES",observed:$resolution_ok},{id:"THREE_REFUTED_BOUNDARIES",observed:$resolution_ok},{id:"SEVEN_REPLAY_COMPARISONS",observed:$artifact_ok}
    ],
    performance:$runtime[0].performance,inventory:$inventory[0],cells:$cells,
    proofs:(["FOUNDATION","COHERENCE","REGRESSION"]|map(. as $choice|{choice:$choice,closed:([$cells[]|select(.proof_choice==$choice and .state=="CLOSED")]|length),total:([$cells[]|select(.proof_choice==$choice)]|length)})),
    indicator_classes:(["DRIVER","OUTCOME","GUARDRAIL"]|map(. as $class|{class:$class,closed:([$cells[]|select(.indicator_class==$class and .state=="CLOSED")]|length),total:([$cells[]|select(.indicator_class==$class)]|length)})),
    indicators:[$cells[]|{id:("gooo.metric.semantic-forge-readiness."+(.id|ascii_downcase)+".v1"),class:.indicator_class,activity,value:(if .state=="CLOSED" then 1 else 0 end),total:1,unit:"cells"}],
    authority:{observation_scope:"TWO_RELEASED_PRODUCTS_OPTIONAL_FORGE_SELECTION_ONLY",optional_forge_experiment_selected:($closed_count==12),
      common_generator_authorized:$runtime[0].common_generator_authorized,product_generation_authorized:$runtime[0].product_generation_authorized,
      central_orchestration_authorized:$runtime[0].central_orchestration_authorized,cross_project_required_gates:$runtime[0].cross_project_required_gates,
      local_tests_run:$runtime[0].local_tests_run,source_repository_writes:$runtime[0].repository_writes,root_readme_readiness:"EXCLUDED"}
  }
' > "$output"

