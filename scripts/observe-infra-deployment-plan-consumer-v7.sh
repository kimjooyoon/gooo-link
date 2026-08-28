#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 15 ]; then
  echo "usage: observe-infra-deployment-plan-consumer-v7.sh ROOT GRAPH LINK_RELEASE BASELINE INFRA_RELEASE PRODUCT_REPORT PACKET MARKDOWN PRODUCT_RUNTIME REPLAY PRODUCT_INVENTORY OBSERVATION_RUNTIME OUTPUT HEAD_SHA PHASE" >&2
  exit 64
fi

root=$(cd "$1" && pwd)
graph=$2
link_release=$3
baseline=$4
infra_release=$5
product_report=$6
packet=$7
markdown=$8
product_runtime=$9
replay=${10}
product_inventory=${11}
observation_runtime=${12}
output=${13}
head_sha=${14}
phase=${15}

denominator="$root/contracts/infra-deployment-plan-consumer-denominator-v7.json"
lock="$root/contracts/infra-deployment-plan-consumer-release-lock-v7.json"
observation="$root/examples/infra-deployment-plan-consumer-v7/observation.gooo"

for required in "$graph" "$link_release" "$baseline" "$infra_release" "$product_report" "$packet" "$product_runtime" "$replay" "$product_inventory" "$observation_runtime" "$denominator" "$lock"; do
  test -f "$required" || { echo "missing required input: $required" >&2; exit 66; }
  jq -e . "$required" >/dev/null
done
test -s "$markdown"
test -f "$observation"
jq -e '.target_cells==12 and (.cells|length)==12 and ([.cells[].activity]|unique|length)==12 and ([.proof_totals[].total]|add)==12 and ([.indicator_totals[].total]|add)==12' "$denominator" >/dev/null
jq -e '.schema=="gooo/link/infra-deployment-plan-consumer-release-lock/v7" and .link.tag=="v0.24.0-dev" and .infra.tag=="v0.8.0-dev" and .core.tag=="v0.4.0-dev" and (.infra.assets|length)==10' "$lock" >/dev/null
test "$(grep -c '^activity ' "$observation")" -eq 12

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
: > "$work/source-lines.ndjson"
while IFS= read -r -d '' file; do
  relative=$(printf '%s' "$file" | sed "s#^$root/##")
  lines=$(wc -l < "$file" | tr -d ' ')
  case "$file" in
    *.go) language=Go ;;
    *.gooo) language=Gooo ;;
    *) continue ;;
  esac
  jq -cn --arg path "$relative" --arg language "$language" --argjson lines "$lines" '{path:$path,language:$language,lines:$lines}' >> "$work/source-lines.ndjson"
done < <(find "$root" -type f -not -path "$root/.git/*" \( -name '*.go' -o -name '*.gooo' \) -print0 | sort -z)

repository_files=$(find "$root" -type f -not -path "$root/.git/*" | wc -l | tr -d ' ')
descendant_directories=$(find "$root" -mindepth 1 -type d -not -path "$root/.git" -not -path "$root/.git/*" | wc -l | tr -d ' ')
jq -s --argjson repository_files "$repository_files" --argjson descendant_directories "$descendant_directories" '
  . as $files | {
    repository_files:$repository_files,descendant_directories:$descendant_directories,root_readme_readiness:"EXCLUDED",
    go:{files:([$files[]|select(.language=="Go")]|length),lines:([$files[]|select(.language=="Go")|.lines]|add//0)},
    gooo:{files:([$files[]|select(.language=="Gooo")]|length),lines:([$files[]|select(.language=="Gooo")|.lines]|add//0)},
    per_file:$files
  }
' "$work/source-lines.ndjson" > "$work/inventory.json"

jq -S -n \
  --slurpfile denominator "$denominator" \
  --slurpfile lock "$lock" \
  --slurpfile graph "$graph" \
  --slurpfile link_release "$link_release" \
  --slurpfile baseline "$baseline" \
  --slurpfile infra_release "$infra_release" \
  --slurpfile product_report "$product_report" \
  --slurpfile packet "$packet" \
  --rawfile markdown "$markdown" \
  --slurpfile product_runtime "$product_runtime" \
  --slurpfile replay "$replay" \
  --slurpfile product_inventory "$product_inventory" \
  --slurpfile observation_runtime "$observation_runtime" \
  --slurpfile inventory "$work/inventory.json" \
  --arg head_sha "$head_sha" \
  --arg phase "$phase" '
  def activity_bound($activity):
    ([$graph[0].nodes[]? | select(.kind=="Activity" and .name==$activity)] | length)==1;
  def asset_matches($release;$asset):
    any($release.assets[];.id==$asset.id and .name==$asset.name and .size==$asset.size and .digest==$asset.digest);
  ($link_release[0].id==$lock[0].link.release_id and $link_release[0].tag_name==$lock[0].link.tag and
    $link_release[0].target_commitish==$lock[0].link.target_commit_sha and $link_release[0].draft==false and
    $link_release[0].prerelease==$lock[0].link.prerelease and asset_matches($link_release[0];$lock[0].link.assets.report)) as $link_release_ok |
  ($baseline[0].schema=="gooo/link/local-project-plan-consumer-report/v6" and
    $baseline[0].subject_sha==$lock[0].link.target_commit_sha and $baseline[0].decision=="LOCAL_PROJECT_PLAN_CONSUMER_OBSERVED" and
    $baseline[0].claim.state=="CLOSED" and $baseline[0].summary.closed_cells==12 and $baseline[0].summary.total_cells==12 and
    $baseline[0].summary.primitive_mappings_current==6 and $baseline[0].summary.primitive_mapping_increment==0 and
    $baseline[0].summary.independent_consumers_previous==0 and $baseline[0].summary.independent_consumer_increment==1 and
    $baseline[0].summary.independent_consumers_current==1 and $baseline[0].authority.cross_project_required_gates==0 and
    $baseline[0].authority.local_tests_run==0 and $baseline[0].authority.source_repository_writes==0) as $baseline_ok |
  ($infra_release[0].id==$lock[0].infra.release_id and $infra_release[0].tag_name==$lock[0].infra.tag and
    $infra_release[0].target_commitish==$lock[0].infra.target_commit_sha and $infra_release[0].draft==false and
    $infra_release[0].prerelease==$lock[0].infra.prerelease) as $release_ok |
  ($lock[0].infra.assets|to_entries) as $expected_assets |
  (($expected_assets|length)==10 and all($expected_assets[];asset_matches($infra_release[0];.value))) as $assets_ok |
  ($product_report[0].schema=="gooo/infra-evidence/semantic-deployment-plan-evaluation/v1" and
    $product_report[0].subject_sha==$lock[0].infra.target_commit_sha and $product_report[0].decision=="SEMANTIC_DEPLOYMENT_PLAN_GENERATED" and
    $product_report[0].claim.state=="CLOSED" and $product_report[0].summary.cells_closed==12 and $product_report[0].summary.cells_total==12 and
    $product_report[0].summary.cells_unknown==0 and $product_report[0].summary.cells_refuted==0 and
    $product_report[0].summary.meta_activities_bound==12 and $product_report[0].summary.deployment_activities_observed==6 and
    $product_report[0].summary.dependencies_observed==8 and $product_report[0].summary.dependency_kinds_observed==4 and
    $product_report[0].summary.prior_contract_cells_observed==15 and $product_report[0].summary.prior_generated_artifacts_observed==3 and
    $product_report[0].summary.prior_semantic_edges_observed==6 and $product_report[0].summary.prior_openapi_bindings_observed==1 and
    $product_report[0].summary.prior_terraform_bindings_observed==1 and $product_report[0].summary.prior_deployment_chain_observed==4 and
    $product_report[0].summary.generated_artifacts_observed==2 and $product_report[0].summary.unknown_coordinates_observed==6 and
    $product_report[0].summary.refuted_boundaries_observed==3 and $product_report[0].summary.replay_comparisons_observed==7 and
    all($product_report[0].proof_counts[];.observed==4 and .total==4) and
    all($product_report[0].indicator_counts[];.observed==4 and .total==4) and
    $product_report[0].summary.repository_writes==0 and $product_report[0].summary.local_tests==0 and
    $product_report[0].summary.cross_project_required_gates==0 and $product_report[0].authority.conformance_is_utility==false and
    $product_report[0].authority.deployment_execution_authorized==false and $product_report[0].authority.terraform_apply_authorized==false and
    $product_report[0].authority.network_probe_authorized==false and $product_report[0].authority.repository_mutation_authorized==false) as $conformance_ok |
  ($packet[0].schema=="gooo/infra-evidence/semantic-deployment-plan/v1" and $packet[0].decision=="DEPLOYMENT_PLAN_GENERATED" and
    $packet[0].primitive=={id:"gooo.primitive.claim-dependency-causality.v1",release:"v0.4.0-dev"} and
    $packet[0].prior_contract.summary=={contract_cells:15,generated_artifacts:3,semantic_edges:6,openapi_bindings:1,terraform_bindings:1,deployment_chain_cells:4} and
    $packet[0].semantics.scope=="STRUCTURAL_DEPLOYMENT_DEPENDENCY_ONLY" and
    $packet[0].summary.activities==6 and $packet[0].summary.dependencies==8 and $packet[0].summary.dependency_kinds==4 and
    $packet[0].summary.generated_artifacts==2 and $packet[0].summary.unknown_coordinates==6 and $packet[0].summary.refuted_boundaries==3 and
    ($packet[0].steps|length)==6 and ($packet[0].dependencies|length)==8 and ($packet[0].refutation_boundaries|length)==3 and
    ($packet[0].non_claims|length)==8 and $packet[0].authority.deployment_execution_authorized==false and
    $packet[0].authority.terraform_apply_authorized==false and $packet[0].authority.network_probe_authorized==false and
    $packet[0].authority.repository_mutation_authorized==false and $packet[0].authority.cross_project_authority==false) as $packet_ok |
  (($markdown|contains("# Semantic deployment plan")) and ($markdown|contains("## Prior released deployment evidence")) and
    ($markdown|contains("## Structural dependencies")) and ($markdown|contains("## UNKNOWN recovery")) and
    ($markdown|contains("## REFUTED boundaries")) and ($markdown|contains("## External utility")) and
    ($markdown|contains("## Non-claims"))) as $markdown_ok |
  ($product_runtime[0].schema=="gooo/infra-evidence/semantic-deployment-plan-runtime/v1" and
    ($product_runtime[0].go_version|startswith("go1.27")) and $product_runtime[0].artifacts.generated==2 and
    $product_runtime[0].repository_writes==0 and $product_runtime[0].local_tests==0 and
    $product_runtime[0].cross_project_required_gates==0 and $product_runtime[0].root_readme_readiness=="EXCLUDED" and
    $product_runtime[0].authority.deployment_execution_authorized==false and $product_runtime[0].authority.terraform_apply_authorized==false and
    $product_runtime[0].authority.network_probe_authorized==false and $product_runtime[0].authority.repository_mutation_authorized==false) as $runtime_ok |
  ($replay[0].schema=="gooo/infra-evidence/semantic-deployment-plan-replay/v1" and
    $replay[0].comparisons_satisfied==7 and $replay[0].comparisons_total==7 and $replay[0].mismatches==0) as $replay_ok |
  ($product_inventory[0].repository_files==$product_report[0].metrics.repository_files and
    $product_inventory[0].descendant_directories==$product_report[0].metrics.descendant_directories and
    $product_inventory[0].go.files==$product_report[0].metrics.go_files and $product_inventory[0].go.lines==$product_report[0].metrics.go_lines and
    $product_inventory[0].gooo.files==$product_report[0].metrics.gooo_files and $product_inventory[0].gooo.lines==$product_report[0].metrics.gooo_lines and
    $product_inventory[0].root_readme_readiness=="EXCLUDED") as $inventory_ok |
  ($product_report[0].utility.declared_external_use_cases==1 and $product_report[0].utility.evidenced_external_use_cases==0 and
    $product_report[0].utility.state=="UNKNOWN" and $product_report[0].utility.reason=="EXTERNAL_DEPLOYMENT_PLAN_USE_NOT_YET_OBSERVED") as $utility_ok |
  ($product_report[0].summary.unknown_coordinates_observed==6 and $product_report[0].summary.refuted_boundaries_observed==3 and
    $product_report[0].summary.replay_comparisons_observed==7 and $packet[0].recovery.state=="UNKNOWN" and
    $packet[0].recovery.unknown_class=="DIRECT_MISSING" and ($packet[0].recovery.blocked_by|length)==1 and
    ([$packet[0].refutation_boundaries[].state]|all(.=="REFUTED"))) as $boundaries_ok |
  (if $observation_runtime[0].releases.infra!=true then "UNKNOWN"
   elif $release_ok and $assets_ok and $conformance_ok and $packet_ok and $markdown_ok and $runtime_ok and $replay_ok and $inventory_ok then "CLOSED"
   else "REFUTED" end) as $product_mode |
  ([$denominator[0].cells[].activity|select(activity_bound(.))]|length) as $activities_bound |
  {
    ObserveFirstConsumerRelease:($observation_runtime[0].releases.link==true and $link_release_ok and $baseline_ok),
    ObserveCoreMetaToolRelease:($observation_runtime[0].releases.core==true),
    ObserveInfraDeploymentPlanRelease:($observation_runtime[0].releases.infra==true and $release_ok),
    BindTenInfraReleaseAssets:($assets_ok and $observation_runtime[0].release_assets_observed==10),
    BindProductTwelveCells:$conformance_ok,
    BindProductSixDeploymentActivities:($conformance_ok and $packet_ok and ($packet[0].steps|length)==6),
    BindProductEightDependencies:($conformance_ok and $packet_ok and ($packet[0].dependencies|length)==8),
    RecordSecondIndependentConsumer:($baseline_ok and $observation_runtime[0].primitive_mapping_increment==0 and
      $observation_runtime[0].independent_consumer_previous==1 and $observation_runtime[0].independent_consumer_increment==1),
    PreserveProductUtilityUnknown:$utility_ok,
    PreserveProductResolutionBoundaries:$boundaries_ok,
    BindTwelveConsumerMetaActivities:($activities_bound==12),
    PreserveOptionalConsumerBoundary:(
      $observation_runtime[0].repository_writes==0 and $observation_runtime[0].local_tests_run==0 and
      $observation_runtime[0].cross_project_required_gates==0 and $observation_runtime[0].generator_authority==false and
      $observation_runtime[0].central_orchestration_authorized==false and $observation_runtime[0].go_fix_module_roots==0)
  } as $facts |
  def product_dependent($activity):
    ["ObserveInfraDeploymentPlanRelease","BindTenInfraReleaseAssets","BindProductTwelveCells","BindProductSixDeploymentActivities",
     "BindProductEightDependencies","RecordSecondIndependentConsumer","PreserveProductUtilityUnknown","PreserveProductResolutionBoundaries"] | index($activity)!=null;
  def evaluate($cell):
    ($cell.activity) as $activity |
    if activity_bound($activity)|not then
      $cell+{state:"REFUTED",reason:"GOOO_META_ACTIVITY_MISSING",unknown_class:null,next_operation:"RESTORE_GOOO_META_ACTIVITY",blocked_by:[]}
    elif product_dependent($activity) and $product_mode=="UNKNOWN" then
      $cell+{state:"UNKNOWN",stage:"PRODUCT_RELEASE",step:"OBSERVE_INFRA_DEPLOYMENT_PLAN_RELEASE",reason:"INFRA_DEPLOYMENT_PLAN_RELEASE_UNAVAILABLE",unknown_class:"DIRECT_MISSING",next_operation:"FETCH_PINNED_INFRA_PRODUCT_RELEASE",blocked_by:["release:v0.8.0-dev"]}
    elif product_dependent($activity) and $product_mode=="REFUTED" then
      $cell+{state:"REFUTED",stage:"PRODUCT_EVIDENCE",step:"VALIDATE_INFRA_DEPLOYMENT_PLAN_RELEASE",reason:"INFRA_DEPLOYMENT_PLAN_REPORT_MISMATCH",unknown_class:null,next_operation:"RESTORE_INFRA_PRODUCT_RELEASE_EVIDENCE",blocked_by:["release:v0.8.0-dev"]}
    elif $facts[$activity]==true then
      $cell+{state:"CLOSED",reason:$cell.closed_reason,unknown_class:null,next_operation:"NONE",blocked_by:[]}
    else
      $cell+{state:"REFUTED",reason:$cell.refuted_reason,unknown_class:null,next_operation:$cell.next_operation,blocked_by:[]}
    end;
  ($denominator[0].cells|map(evaluate(.))) as $cells |
  ([$cells[]|select(.state=="CLOSED")]|length) as $closed_count |
  ([$cells[]|select(.state=="UNKNOWN")]|length) as $unknown_count |
  ([$cells[]|select(.state=="REFUTED")]|length) as $refuted_count |
  (([$cells[]|select(.state=="REFUTED")]|first)//([$cells[]|select(.state=="UNKNOWN")]|first)) as $first_nonclosed |
  (if $closed_count==12 then 1 else 0 end) as $consumer_increment |
  {
    schema:"gooo/link/infra-deployment-plan-consumer-report/v7",
    phase:$phase,subject_sha:$head_sha,
    decision:(if $refuted_count>0 then "FAIL_CLOSED" elif $unknown_count>0 then "INFRA_DEPLOYMENT_PLAN_CONSUMER_UNKNOWN" else "INFRA_DEPLOYMENT_PLAN_CONSUMER_OBSERVED" end),
    claim:{
      state:(if $refuted_count>0 then "REFUTED" elif $unknown_count>0 then "UNKNOWN" else "CLOSED" end),
      stage:($first_nonclosed.stage//null),step:($first_nonclosed.step//null),
      reason:($first_nonclosed.reason//"SECOND_INDEPENDENT_PRODUCT_CONSUMER_OBSERVED"),
      unknown_class:($first_nonclosed.unknown_class//null),
      next_operation:($first_nonclosed.next_operation//"EVALUATE_SHARED_FORGE_AFTER_TWO_INDEPENDENT_CONSUMERS"),
      blocked_by:($first_nonclosed.blocked_by//[])
    },
    summary:{
      total_cells:12,closed_cells:$closed_count,unknown_cells:$unknown_count,refuted_cells:$refuted_count,
      primitive_mappings_previous:6,primitive_mapping_increment:0,primitive_mappings_current:6,primitive_mapping_denominator:30,primitive_mapping_remaining:24,
      independent_consumers_previous:1,independent_consumer_increment:$consumer_increment,independent_consumers_current:(1+$consumer_increment),
      product_release_assets_observed:(if $assets_ok then 10 else 0 end),product_release_asset_total:10,
      product_cells_observed:(if $conformance_ok then 12 else 0 end),product_cell_total:12,
      product_activities_observed:(if $conformance_ok and $packet_ok then 6 else 0 end),product_activity_total:6,
      product_dependencies_observed:(if $conformance_ok and $packet_ok then 8 else 0 end),product_dependency_total:8,
      product_dependency_kinds_observed:(if $conformance_ok and $packet_ok then 4 else 0 end),product_dependency_kind_total:4,
      prior_contract_cells_observed:($product_report[0].summary.prior_contract_cells_observed//0),
      prior_semantic_edges_observed:($product_report[0].summary.prior_semantic_edges_observed//0),
      prior_openapi_bindings_observed:($product_report[0].summary.prior_openapi_bindings_observed//0),
      prior_terraform_bindings_observed:($product_report[0].summary.prior_terraform_bindings_observed//0),
      generated_artifacts_observed:(if $conformance_ok and $packet_ok then 2 else 0 end),generated_artifact_total:2,
      unknown_coordinates_observed:(if $boundaries_ok then 6 else 0 end),unknown_coordinate_total:6,
      refuted_boundaries_observed:(if $boundaries_ok then 3 else 0 end),refuted_boundary_total:3,
      replay_comparisons_observed:(if $replay_ok then 7 else 0 end),replay_comparison_total:7,
      external_use_cases_declared:($product_report[0].utility.declared_external_use_cases//0),
      external_use_cases_evidenced:($product_report[0].utility.evidenced_external_use_cases//0),
      utility_state:($product_report[0].utility.state//"INVALID"),
      link_meta_activities_observed:$activities_bound,link_meta_activity_total:12,
      repository_writes:$observation_runtime[0].repository_writes,local_tests_run:$observation_runtime[0].local_tests_run,
      cross_project_required_gates:$observation_runtime[0].cross_project_required_gates
    },
    product_metrics:{
      elapsed_ms:$product_report[0].metrics.elapsed_ms,max_rss_kib:$product_report[0].metrics.max_rss_kib,
      repository_files:$product_report[0].metrics.repository_files,descendant_directories:$product_report[0].metrics.descendant_directories,
      go_files:$product_report[0].metrics.go_files,go_lines:$product_report[0].metrics.go_lines,
      gooo_files:$product_report[0].metrics.gooo_files,gooo_lines:$product_report[0].metrics.gooo_lines,
      json_packet_bytes:$product_report[0].metrics.json_packet_bytes,markdown_packet_bytes:$product_report[0].metrics.markdown_packet_bytes,
      markdown_packet_lines:$product_report[0].metrics.markdown_packet_lines
    },
    observation_performance:$observation_runtime[0].performance,
    inventory:$inventory[0],cells:$cells,
    proofs:(["FOUNDATION","COHERENCE","REGRESSION"]|map(. as $choice|{choice:$choice,closed:([$cells[]|select(.proof_choice==$choice and .state=="CLOSED")]|length),total:([$cells[]|select(.proof_choice==$choice)]|length)})),
    indicator_classes:(["DRIVER","OUTCOME","GUARDRAIL"]|map(. as $class|{class:$class,closed:([$cells[]|select(.indicator_class==$class and .state=="CLOSED")]|length),total:([$cells[]|select(.indicator_class==$class)]|length)})),
    indicators:[$cells[]|{id:("gooo.metric.infra-deployment-plan-consumer."+(.id|ascii_downcase)+".v7"),class:.indicator_class,activity,value:(if .state=="CLOSED" then 1 else 0 end),total:1,unit:"cells"}],
    authority:{
      observation_scope:"RELEASED_INFRA_DEPLOYMENT_PLAN_CONSUMPTION_ONLY",
      link_release:"v0.24.0-dev",infra_product_release:"v0.8.0-dev",core_meta_tool_release:"v0.4.0-dev",
      independent_release_is_external_utility:false,utility_claimed:false,primitive_mapping_increment:0,
      generator_authority:$observation_runtime[0].generator_authority,
      central_orchestration_authorized:$observation_runtime[0].central_orchestration_authorized,
      cross_project_required_gates:$observation_runtime[0].cross_project_required_gates,
      local_tests_run:$observation_runtime[0].local_tests_run,source_repository_writes:$observation_runtime[0].repository_writes,
      go_fix_module_roots:$observation_runtime[0].go_fix_module_roots,root_readme_readiness:"EXCLUDED"
    }
  }
' > "$output"

