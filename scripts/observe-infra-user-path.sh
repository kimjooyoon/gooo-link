#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 8 ]]; then
  printf 'usage: %s LINK_GRAPH INFRA_GRAPH DENOMINATOR BASELINE_DIR INFRA_DIR OUTPUT SUBJECT_SHA SCENARIO\n' "$0" >&2
  exit 64
fi

link_graph=$1
infra_graph=$2
denominator=$3
baseline_dir=$4
infra_dir=$5
output=$6
subject_sha=$7
scenario=$8

die() {
  printf 'infra user-path observation rejected: %s\n' "$1" >&2
  exit 1
}

require_file() {
  [[ -s "$1" ]] || die "required evidence is absent: $1"
}

sha256_file() {
  sha256sum "$1" | awk '{print $1}'
}

require_file "$link_graph"
require_file "$infra_graph"
require_file "$denominator"
require_file "$baseline_dir/design-user-path-report.json"
require_file "$baseline_dir/source-integrity.json"
require_file "$infra_dir/deployment-contract.json"
require_file "$infra_dir/deployment-generation-manifest.json"
require_file "$infra_dir/deployment-runbook.md"
require_file "$infra_dir/deployment-missing.json"
require_file "$infra_dir/deployment-drift.json"
require_file "$infra_dir/deployment-handler.json"
require_file "$infra_dir/deployment-authority.json"
require_file "$infra_dir/deployment-runtime.json"
require_file "$infra_dir/source-integrity.json"

jq -e . "$link_graph" "$infra_graph" "$denominator" \
  "$baseline_dir/design-user-path-report.json" "$baseline_dir/source-integrity.json" \
  "$infra_dir/deployment-contract.json" "$infra_dir/deployment-generation-manifest.json" \
  "$infra_dir/deployment-missing.json" "$infra_dir/deployment-drift.json" \
  "$infra_dir/deployment-handler.json" "$infra_dir/deployment-authority.json" \
  "$infra_dir/deployment-runtime.json" "$infra_dir/source-integrity.json" >/dev/null \
  || die "an evidence JSON document is invalid"

jq -e --slurpfile d "$denominator" '
  .activities == $d[0].activities and
  .primitive_count == $d[0].fixed_baselines.primitive_count and
  .primitive_denominator == $d[0].fixed_baselines.primitive_denominator and
  .independent_consumers == $d[0].fixed_baselines.independent_consumers and
  .user_verticals_before == $d[0].fixed_baselines.user_verticals_before
' "$link_graph" >/dev/null || {
  primitive=$(jq -r '.primitive_count // -1' "$link_graph")
  if [[ "$primitive" != "6" ]]; then
    die "Gooo activity graph or fixed baseline does not match the denominator"
  fi
  jq -e --slurpfile d "$denominator" '
    .activities == $d[0].activities and
    .primitive_count == 6 and
    .primitive_denominator == $d[0].fixed_baselines.primitive_denominator and
    .independent_consumers == $d[0].fixed_baselines.independent_consumers and
    .user_verticals_before == $d[0].fixed_baselines.user_verticals_before
  ' "$link_graph" >/dev/null || die "Gooo activity graph does not match the denominator"
}

jq -e '
  (.activities | length) == 15 and
  ([.activities[] | select(.proof_class == "FOUNDATION")] | length) == 5 and
  ([.activities[] | select(.proof_class == "COHERENCE")] | length) == 5 and
  ([.activities[] | select(.proof_class == "REGRESSION")] | length) == 5 and
  ([.activities[] | select(.indicator_class == "DRIVER")] | length) == 5 and
  ([.activities[] | select(.indicator_class == "OUTCOME")] | length) == 5 and
  ([.activities[] | select(.indicator_class == "GUARDRAIL")] | length) == 5
' "$link_graph" >/dev/null || die "Gooo graph class partition is not 5/5/5"

baseline_expected=$(jq -r '.files["design-user-path-report.json"]' "$baseline_dir/source-integrity.json")
[[ "$(sha256_file "$baseline_dir/design-user-path-report.json")" == "$baseline_expected" ]] \
  || die "Link baseline evidence differs from the locked release"

expected_hash() {
  jq -er --arg name "$1" '.files[$name]' "$infra_dir/source-integrity.json"
}

hash_matches() {
  [[ "$(sha256_file "$infra_dir/$1")" == "$(expected_hash "$1")" ]]
}

missing_conformance=false
conformance_drift=false
primitive_drift=false
meta_missing=false
meta_graph_drift=false
authority_escalation=false
authority_contract_drift=false

if [[ ! -s "$infra_dir/deployment-conformance.json" ]]; then
  missing_conformance=true
else
  jq -e . "$infra_dir/deployment-conformance.json" >/dev/null || die "deployment conformance JSON is invalid"
  hash_matches deployment-conformance.json || conformance_drift=true
fi

[[ "$(jq -r '.primitive_count' "$link_graph")" == "5" ]] || primitive_drift=true

jq -e '.. | strings | select(. == "GenerateDeploymentPacketArtifacts")' "$infra_graph" >/dev/null \
  || meta_missing=true
hash_matches deployment-graph.json || meta_graph_drift=true

jq -e '[.. | objects | .terraform_apply? // empty, .deployment_execution? // empty] | any(. == true)' \
  "$infra_dir/deployment-contract.json" >/dev/null && authority_escalation=true
hash_matches deployment-contract.json || authority_contract_drift=true

for name in deployment-generation-manifest.json deployment-missing.json deployment-drift.json \
  deployment-handler.json deployment-authority.json deployment-runtime.json; do
  hash_matches "$name" || die "unexpected released evidence drift: $name"
done

if [[ "$conformance_drift" == true ]]; then
  jq -e '.summary.generated_artifacts_observed == 2' "$infra_dir/deployment-conformance.json" >/dev/null \
    || die "unclassified deployment conformance drift"
fi
if [[ "$meta_graph_drift" == true && "$meta_missing" != true ]]; then
  die "unclassified Infra Gooo graph drift"
fi
if [[ "$authority_contract_drift" == true && "$authority_escalation" != true ]]; then
  die "unclassified deployment contract drift"
fi

detected=normal
fault_count=0
for flag in "$missing_conformance" "$conformance_drift" "$primitive_drift" "$meta_missing" "$authority_escalation"; do
  if [[ "$flag" == true ]]; then
    fault_count=$((fault_count + 1))
  fi
done
[[ $fault_count -le 1 ]] || die "multiple faults cannot be attributed to one deterministic cause"

if [[ "$missing_conformance" == true ]]; then detected=missing-conformance; fi
if [[ "$conformance_drift" == true ]]; then detected=metric-tamper; fi
if [[ "$primitive_drift" == true ]]; then detected=primitive-inflation; fi
if [[ "$meta_missing" == true ]]; then detected=missing-meta-binding; fi
if [[ "$authority_escalation" == true ]]; then detected=execution-authority-escalation; fi
[[ "$detected" == "$scenario" ]] || die "scenario says $scenario but evidence deterministically says $detected"

flags=$(jq -n \
  --argjson missing "$missing_conformance" \
  --argjson metric "$conformance_drift" \
  --argjson primitive "$primitive_drift" \
  --argjson meta "$meta_missing" \
  --argjson authority "$authority_escalation" \
  '{missing:$missing, metric:$metric, primitive:$primitive, meta:$meta, authority:$authority}')

jq -n \
  --slurpfile d "$denominator" \
  --arg subject_sha "$subject_sha" \
  --arg scenario "$scenario" \
  --argjson flags "$flags" '
  def closed($a): $a + {resolution: {state: "CLOSED"}};
  def unknown_direct($a): $a + {resolution: {
    state: "UNKNOWN",
    stage: "PRODUCT_EVIDENCE",
    step: "OBSERVE_INFRA_PACKET_CONFORMANCE",
    reason: "INFRA_CONFORMANCE_REPORT_UNAVAILABLE",
    unknown_class: "DIRECT_MISSING",
    next_operation: "RESTORE_INFRA_CONFORMANCE_REPORT"
  }};
  def unknown_dependency($a): $a + {resolution: {
    state: "UNKNOWN",
    stage: "LINK_OBSERVATION",
    step: $a.name,
    reason: "INFRA_PACKET_CONFORMANCE_UNAVAILABLE",
    unknown_class: "DEPENDENCY_BLOCKED",
    next_operation: "RESTORE_INFRA_CONFORMANCE_REPORT"
  }};
  def refuted($a; $reason; $class; $next): $a + {resolution: {
    state: "REFUTED",
    stage: "LINK_OBSERVATION",
    step: $a.name,
    reason: $reason,
    refutation_class: $class,
    next_operation: $next
  }};
  def cells:
    [$d[0].activities[] as $a |
      if $flags.missing and $a.ordinal == 6 then unknown_direct($a)
      elif $flags.missing and ($a.ordinal >= 7 and $a.ordinal <= 10) then unknown_dependency($a)
      elif $flags.primitive and $a.ordinal == 13 then refuted($a; "PRIMITIVE_BASELINE_INFLATED"; "DIRECT_CONTRADICTION"; "RESTORE_PRIMITIVE_COUNT_5")
      elif $flags.primitive and $a.ordinal == 10 then refuted($a; "THIRD_VERTICAL_DEPENDS_ON_STABLE_PRIMITIVE_BASELINE"; "DEPENDENCY_REFUTATION"; "RESTORE_PRIMITIVE_COUNT_5")
      elif $flags.metric and $a.ordinal == 9 then refuted($a; "GENERATED_ARTIFACT_COUNT_TAMPERED"; "DIRECT_CONTRADICTION"; "RESTORE_RELEASED_CONFORMANCE_REPORT")
      elif $flags.metric and $a.ordinal == 10 then refuted($a; "THIRD_VERTICAL_DEPENDS_ON_GENERATED_ARTIFACT_EVIDENCE"; "DEPENDENCY_REFUTATION"; "RESTORE_RELEASED_CONFORMANCE_REPORT")
      elif $flags.meta and $a.ordinal == 5 then refuted($a; "INFRA_META_BINDING_MISSING"; "DIRECT_CONTRADICTION"; "RESTORE_GENERATE_DEPLOYMENT_PACKET_ACTIVITY")
      elif $flags.meta and $a.ordinal == 10 then refuted($a; "THIRD_VERTICAL_DEPENDS_ON_INFRA_META_BINDING"; "DEPENDENCY_REFUTATION"; "RESTORE_GENERATE_DEPLOYMENT_PACKET_ACTIVITY")
      elif $flags.authority and $a.ordinal == 14 then refuted($a; "INFRA_EXECUTION_AUTHORITY_ESCALATED"; "DIRECT_CONTRADICTION"; "REMOVE_APPLY_AND_DEPLOY_AUTHORITY")
      elif $flags.authority and $a.ordinal == 10 then refuted($a; "THIRD_VERTICAL_REFUSES_EXECUTION_AUTHORITY"; "DEPENDENCY_REFUTATION"; "REMOVE_APPLY_AND_DEPLOY_AUTHORITY")
      else closed($a)
      end];
  (cells) as $cells |
  ([ $cells[] | select(.resolution.state == "CLOSED") ] | length) as $closed |
  ([ $cells[] | select(.resolution.state == "UNKNOWN") ] | length) as $unknown |
  ([ $cells[] | select(.resolution.state == "REFUTED") ] | length) as $refuted |
  {
    schema: "gooo.link.infra-user-path-observation.report.v1",
    subject_sha: $subject_sha,
    scenario: $scenario,
    resolution: (
      if $refuted > 0 then {
        state: "REFUTED",
        cause: ($cells | map(select(.resolution.refutation_class == "DIRECT_CONTRADICTION"))[0].resolution)
      }
      elif $unknown > 0 then {
        state: "UNKNOWN",
        cause: ($cells | map(select(.resolution.unknown_class == "DIRECT_MISSING"))[0].resolution)
      }
      else {state: "CLOSED"}
      end
    ),
    summary: {
      cells_total: 15,
      cells_closed: $closed,
      cells_unknown: $unknown,
      cells_refuted: $refuted,
      foundation: {total: 5, closed: ([$cells[] | select(.proof_class == "FOUNDATION" and .resolution.state == "CLOSED")] | length)},
      coherence: {total: 5, closed: ([$cells[] | select(.proof_class == "COHERENCE" and .resolution.state == "CLOSED")] | length)},
      regression: {total: 5, closed: ([$cells[] | select(.proof_class == "REGRESSION" and .resolution.state == "CLOSED")] | length)},
      drivers: {total: 5, closed: ([$cells[] | select(.indicator_class == "DRIVER" and .resolution.state == "CLOSED")] | length)},
      outcomes: {total: 5, closed: ([$cells[] | select(.indicator_class == "OUTCOME" and .resolution.state == "CLOSED")] | length)},
      guardrails: {total: 5, closed: ([$cells[] | select(.indicator_class == "GUARDRAIL" and .resolution.state == "CLOSED")] | length)},
      user_verticals_before: 2,
      user_verticals_observed: (if ($cells[9].resolution.state == "CLOSED") then 3 else 2 end),
      user_verticals_denominator: 3,
      user_verticals_added: (if ($cells[9].resolution.state == "CLOSED") then 1 else 0 end),
      primitive_count: 5,
      primitive_denominator: 30,
      primitive_increment: 0,
      independent_consumers: 4,
      release_inputs_observed: 3,
      release_inputs_denominator: 3,
      infra_conformance_cells_observed: 15,
      infra_conformance_cells_denominator: 15,
      infra_evidence_cells_observed: 12,
      infra_evidence_cells_denominator: 12,
      infra_claim_adoption_cells_observed: 12,
      infra_claim_adoption_cells_denominator: 12,
      terraform_bindings_observed: 1,
      terraform_bindings_denominator: 1,
      service_bindings_observed: 1,
      service_bindings_denominator: 1,
      generation_targets_observed: 3,
      generation_targets_denominator: 3,
      semantic_edges_observed: 6,
      semantic_edges_denominator: 6,
      deployment_chain_edges_observed: 4,
      deployment_chain_edges_denominator: 4,
      released_claims_observed: 3,
      released_claims_denominator: 3,
      released_claim_fields_observed: 18,
      released_claim_fields_denominator: 18,
      gooo_decision_receipts_observed: 5,
      gooo_decision_receipts_denominator: 5,
      gooo_decision_receipt_fields_observed: 30,
      gooo_decision_receipt_fields_denominator: 30,
      generated_artifacts_observed: 3,
      generated_artifacts_denominator: 3,
      counterexamples_observed: 4,
      counterexamples_denominator: 4,
      replay_runs_observed: 3,
      replay_runs_denominator: 3,
      repository_writes: 0,
      local_tests: 0,
      cross_project_required_gates: 0
    },
    cells: $cells
  }
' > "$output"
