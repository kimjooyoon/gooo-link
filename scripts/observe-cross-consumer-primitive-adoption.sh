#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -ne 11 ]]; then
  echo "usage: $0 GRAPH DENOMINATOR BASELINE DESIGN_COMPLETE DESIGN_UNKNOWN DESIGN_MISMATCH DESIGN_CORE_REFUTED DESIGN_SCOPE_REFUTED OUTPUT SUBJECT_SHA SCENARIO" >&2
  exit 64
fi

graph=$1
denominator=$2
baseline=$3
design=$4
design_unknown=$5
design_mismatch=$6
design_core_refuted=$7
design_scope_refuted=$8
output=$9
subject_sha=${10}
scenario=${11}

candidate_id="gooo.primitive.claim-resolution-tuple.v1"
state="CLOSED"
reason="SECOND_DIRECT_CLAIM_RESOLUTION_MAPPING_OBSERVED"
stage=""
step=""
unknown_class=""
next_operation="OBSERVE_NEXT_INDEPENDENT_CONSUMER_ADOPTION"
refuted_cell=""

set_unknown() {
  if [[ "$state" == "CLOSED" ]]; then
    state="UNKNOWN"
    reason=$1
    stage=$2
    step=$3
    unknown_class=$4
    next_operation=$5
  fi
}

set_refuted() {
  if [[ "$state" == "CLOSED" ]]; then
    state="REFUTED"
    reason=$1
    stage=$2
    step=$3
    refuted_cell=$4
    unknown_class=""
    next_operation=$5
  fi
}

digest_of() {
  if [[ -s "$1" ]]; then
    printf 'sha256:%s' "$(sha256sum "$1" | awk '{print $1}')"
  else
    printf 'unavailable'
  fi
}

jq -e '
  .schema == "gooo/link/cross-consumer-primitive-adoption-denominator/v1" and
  .candidate_id == "gooo.primitive.claim-resolution-tuple.v1" and
  .total == 12 and
  ([.cells[].id] | length) == 12 and
  ([.cells[].id] | unique | length) == 12 and
  ([.cells[].activity] | unique | length) == 12 and
  ([.proofs[].total] | add) == 12 and
  ([.indicator_classes[].total] | add) == 12
' "$denominator" >/dev/null

if [[ ! -s "$graph" ]] || ! jq -e '.nodes and (.nodes | type == "array")' "$graph" >/dev/null 2>&1; then
  set_unknown "GOOO_GRAPH_UNAVAILABLE" "META_GRAPH" "OBSERVE_GOOO_ACTIVITY_GRAPH" "DIRECT_MISSING" "PROVIDE_GOOO_ACTIVITY_GRAPH"
else
  expected_activities=$(jq -c '[.cells[].activity] | sort' "$denominator")
  actual_activities=$(jq -c '[.nodes[] | select(.kind == "Activity") | .name] | sort' "$graph")
  if [[ "$actual_activities" != "$expected_activities" ]]; then
    set_refuted "GOOO_ACTIVITY_CONFORMANCE_MISMATCH" "META_GRAPH" "BIND_METRICS_TO_GOOO_ACTIVITIES" "candidate-identity" "RESTORE_GOOO_ACTIVITY_CONFORMANCE"
  fi
fi

if [[ ! -s "$baseline" ]]; then
  set_unknown "BASELINE_MAPPING_RELEASE_UNAVAILABLE" "BASELINE_RELEASE" "OBSERVE_BASELINE_PRIMITIVE_MAPPING" "DIRECT_MISSING" "PROVIDE_PINNED_BASELINE_MAPPING_RELEASE"
elif ! jq -e '
  .schema == "gooo/link/cross-consumer-primitive-mapping-report/v2" and
  .decision == "CROSS_CONSUMER_PRIMITIVE_IMPLEMENTATION_OBSERVED" and
  .claim.state == "CLOSED" and
  .candidate.id == "gooo.primitive.claim-resolution-tuple.v1"
' "$baseline" >/dev/null; then
  set_refuted "BASELINE_MAPPING_RELEASE_INVALID" "BASELINE_RELEASE" "OBSERVE_BASELINE_PRIMITIVE_MAPPING" "baseline-mapping-release" "RESTORE_PINNED_BASELINE_MAPPING_RELEASE"
elif ! jq -e '
  .candidate.direct_mappings.observed == 1 and
  .candidate.direct_mappings.total == 30 and
  .summary.direct_mappings == 1 and
  .summary.mapping_denominator == 30 and
  .summary.open_experiments == 29
' "$baseline" >/dev/null; then
  set_refuted "BASELINE_DIRECT_MAPPING_COUNT_INVALID" "MAPPING_COUNT" "OBSERVE_BASELINE_DIRECT_MAPPING_COUNT" "baseline-mapping-count" "RESTORE_BASELINE_MAPPING_COUNT_1_OF_30"
fi

if [[ ! -s "$design" ]]; then
  set_unknown "DESIGN_ADOPTION_RELEASE_UNAVAILABLE" "DESIGN_ADOPTION_RELEASE" "OBSERVE_DESIGN_CLAIM_RESOLUTION_ADOPTION" "DIRECT_MISSING" "PROVIDE_PINNED_DESIGN_ADOPTION_RELEASE"
elif ! jq -e '.schema == "gooo/design-evidence/claim-resolution-adoption-report/v1"' "$design" >/dev/null; then
  set_refuted "DESIGN_ADOPTION_SCHEMA_INVALID" "DESIGN_ADOPTION_RELEASE" "OBSERVE_DESIGN_CLAIM_RESOLUTION_ADOPTION" "design-adoption-release" "RESTORE_DESIGN_ADOPTION_SCHEMA"
elif [[ "$(jq -r '.candidate.id // ""' "$design")" != "$candidate_id" ]]; then
  set_refuted "CLAIM_RESOLUTION_CANDIDATE_MISMATCH" "CANDIDATE_IDENTITY" "BIND_CLAIM_RESOLUTION_CANDIDATE_IDENTITY" "candidate-identity" "RESTORE_CLAIM_RESOLUTION_CANDIDATE_IDENTITY"
else
  design_claim_state=$(jq -r '.claim.state // ""' "$design")
  if [[ "$design_claim_state" == "UNKNOWN" ]]; then
    set_unknown \
      "$(jq -r '.claim.reason' "$design")" \
      "$(jq -r '.claim.stage' "$design")" \
      "$(jq -r '.claim.step' "$design")" \
      "$(jq -r '.claim.unknown_class' "$design")" \
      "$(jq -r '.claim.next_operation' "$design")"
  elif [[ "$design_claim_state" == "REFUTED" ]]; then
    child_reason=$(jq -r '.claim.reason' "$design")
    child_cell="design-adoption-release"
    case "$child_reason" in
      MATCHER_CORE_CLAIM_MISMATCH) child_cell="matcher-core-equality" ;;
      INVALID_CORE_CLAIM_DECISION) child_cell="adverse-refutations" ;;
      CORE_REPOSITORY_WRITE_AUTHORITY_ESCALATION) child_cell="authority-boundary" ;;
    esac
    set_refuted \
      "$child_reason" \
      "$(jq -r '.claim.stage' "$design")" \
      "$(jq -r '.claim.step' "$design")" \
      "$child_cell" \
      "$(jq -r '.claim.next_operation' "$design")"
  elif [[ "$design_claim_state" != "CLOSED" ]]; then
    set_refuted "DESIGN_ADOPTION_CLAIM_STATE_UNKNOWN" "DESIGN_ADOPTION_DECISION" "REJECT_UNRECOGNIZED_DESIGN_CLAIM_STATE" "design-adoption-release" "RESTORE_EXPLICIT_DESIGN_CLAIM_STATE"
  elif ! jq -e '
    .decision == "CLAIM_RESOLUTION_ADOPTION_OBSERVED" and
    .candidate.state == "ADOPTED" and
    .candidate.implementation_status == "INDEPENDENT_CONSUMER_ADOPTION_OBSERVED" and
    .summary.closed_cells == 12 and
    .summary.total_cells == 12 and
    .summary.unknown_cells == 0 and
    .summary.refuted_cells == 0 and
    .summary.independent_consumer_adoptions == 1
  ' "$design" >/dev/null; then
    set_refuted "DESIGN_INDEPENDENT_ADOPTION_NOT_CLOSED" "DESIGN_ADOPTION_DECISION" "COUNT_INDEPENDENT_DESIGN_ADOPTION" "independent-design-adoption" "RESTORE_CLOSED_DESIGN_ADOPTION"
  elif ! jq -e '
    .summary.claim_scenarios_resolved == 4 and
    .summary.claim_scenarios_total == 4 and
    .summary.claim_fields_observed == 24 and
    .summary.claim_fields_total == 24
  ' "$design" >/dev/null; then
    set_refuted "DESIGN_CLAIM_RESOLUTION_COVERAGE_INCOMPLETE" "DESIGN_CLAIM_COVERAGE" "OBSERVE_DESIGN_CLAIM_SCENARIOS" "design-claim-scenarios" "RESTORE_DESIGN_CLAIM_RESOLUTION_COVERAGE"
  elif ! jq -e '
    .summary.matcher_claims_matched == 4 and
    .summary.matcher_claims_total == 4 and
    .summary.rejection_scenarios_observed == 2 and
    .summary.rejection_scenarios_total == 2
  ' "$design" >/dev/null; then
    set_refuted "MATCHER_CORE_OR_REJECTION_COVERAGE_INCOMPLETE" "DESIGN_CONFORMANCE" "PRESERVE_MATCHER_CORE_EQUALITY" "matcher-core-equality" "RESTORE_MATCHER_CORE_AND_REJECTION_COVERAGE"
  elif ! jq -e '
    .summary.local_tests_run == 0 and
    .summary.repository_writes == 0 and
    .summary.cross_project_required_gates == 0 and
    .authority.automatic_merge_authorized == false and
    .authority.core_mutation_authorized == false and
    .authority.dependency_propagation_authorized == false
  ' "$design" >/dev/null; then
    set_refuted "DESIGN_ADOPTION_AUTHORITY_ESCALATION" "AUTHORITY" "PRESERVE_OBSERVATION_AUTHORITY_BOUNDARY" "authority-boundary" "RESTORE_READ_ONLY_INDEPENDENT_ADOPTION"
  fi
fi

if [[ ! -s "$design_unknown" ]] || ! jq -e '
  .decision == "CLAIM_RESOLUTION_ADOPTION_UNKNOWN" and
  .claim.state == "UNKNOWN" and
  .claim.stage == "CORE_RECEIPT" and
  .claim.step == "RESOLVE_MISSING_EVIDENCE_UNKNOWN" and
  .claim.reason == "CORE_CLAIM_RESOLUTION_RECEIPT_UNAVAILABLE" and
  .claim.unknown_class == "DIRECT_MISSING" and
  .claim.next_operation == "PROVIDE_CORE_CLAIM_RESOLUTION_RECEIPT" and
  .summary.closed_cells == 9 and
  .summary.unknown_cells == 3
' "$design_unknown" >/dev/null 2>&1; then
  set_refuted "ADVERSE_UNKNOWN_RESOLUTION_INVALID" "ADVERSE_UNKNOWN" "PRESERVE_ADVERSE_UNKNOWN_RESOLUTION" "adverse-unknown-resolution" "RESTORE_TYPED_ADVERSE_UNKNOWN_RESOLUTION"
fi

if [[ ! -s "$design_mismatch" ]] || [[ ! -s "$design_core_refuted" ]] || [[ ! -s "$design_scope_refuted" ]] ||
   ! jq -e '.claim.state == "REFUTED" and .claim.reason == "MATCHER_CORE_CLAIM_MISMATCH" and .claim.stage == "CLAIM_COMPARISON"' "$design_mismatch" >/dev/null 2>&1 ||
   ! jq -e '.claim.state == "REFUTED" and .claim.reason == "INVALID_CORE_CLAIM_DECISION" and .claim.stage == "CORE_DECISION"' "$design_core_refuted" >/dev/null 2>&1 ||
   ! jq -e '.claim.state == "REFUTED" and .claim.reason == "CORE_REPOSITORY_WRITE_AUTHORITY_ESCALATION" and .claim.stage == "AUTHORITY"' "$design_scope_refuted" >/dev/null 2>&1; then
  set_refuted "ADVERSE_REFUTATION_SET_INVALID" "ADVERSE_REFUTATION" "PRESERVE_ADVERSE_REFUTATIONS" "adverse-refutations" "RESTORE_THREE_ADVERSE_REFUTATIONS"
fi

if [[ "$state" == "CLOSED" ]]; then
  decision="SECOND_DIRECT_PRIMITIVE_MAPPING_OBSERVED"
  candidate_state="ADOPTED"
  implementation_status="TWO_DIRECT_MAPPINGS_OBSERVED"
  direct_mappings=2
  independent_adoptions=1
elif [[ "$state" == "UNKNOWN" ]]; then
  decision="CROSS_CONSUMER_PRIMITIVE_ADOPTION_UNKNOWN"
  candidate_state="UNKNOWN"
  implementation_status="NOT_COUNTED"
  direct_mappings=1
  independent_adoptions=0
else
  decision="FAIL_CLOSED"
  candidate_state="REFUTED"
  implementation_status="NOT_COUNTED"
  direct_mappings=1
  independent_adoptions=0
fi

baseline_digest=$(digest_of "$baseline")
design_digest=$(digest_of "$design")
graph_digest=$(digest_of "$graph")
denominator_digest=$(digest_of "$denominator")
unknown_closed='["baseline-mapping-release","baseline-mapping-count","adverse-unknown-resolution","adverse-refutations","authority-boundary"]'

jq -n \
  --slurpfile denominator "$denominator" \
  --arg schema "gooo/link/cross-consumer-primitive-adoption-report/v1" \
  --arg subject_sha "$subject_sha" \
  --arg scenario "$scenario" \
  --arg decision "$decision" \
  --arg candidate_id "$candidate_id" \
  --arg candidate_state "$candidate_state" \
  --arg implementation_status "$implementation_status" \
  --arg claim_state "$state" \
  --arg reason "$reason" \
  --arg stage "$stage" \
  --arg step "$step" \
  --arg unknown_class "$unknown_class" \
  --arg next_operation "$next_operation" \
  --arg refuted_cell "$refuted_cell" \
  --arg baseline_digest "$baseline_digest" \
  --arg design_digest "$design_digest" \
  --arg graph_digest "$graph_digest" \
  --arg denominator_digest "$denominator_digest" \
  --argjson direct_mappings "$direct_mappings" \
  --argjson independent_adoptions "$independent_adoptions" \
  --argjson unknown_closed "$unknown_closed" \
  '
    $denominator[0] as $d |
    [
      $d.cells[] |
      . as $definition |
      (
        if $claim_state == "CLOSED" then "CLOSED"
        elif $claim_state == "UNKNOWN" then
          if ($unknown_closed | index($definition.id)) != null then "CLOSED" else "UNKNOWN" end
        elif $definition.id == $refuted_cell then "REFUTED"
        elif $definition.id == "direct-mapping-progress" then "UNKNOWN"
        else "CLOSED"
        end
      ) as $cell_state |
      {
        id: $definition.id,
        activity: $definition.activity,
        proof_choice: $definition.proof,
        indicator_class: $definition.indicator_class,
        state: $cell_state,
        reason: (
          if $cell_state == "CLOSED"
          then (($definition.id | ascii_upcase | gsub("-"; "_")) + "_CLOSED")
          else $reason
          end
        ),
        stage: (if $cell_state == "CLOSED" then null else $stage end),
        step: (if $cell_state == "CLOSED" then null else $step end),
        unknown_class: (if $cell_state == "UNKNOWN" then $unknown_class else null end),
        next_operation: (if $cell_state == "CLOSED" then "NONE" else $next_operation end),
        blocked_by: (if $cell_state == "CLOSED" then [] else [$step] end)
      }
    ] as $cells |
    {
      schema: $schema,
      subject_sha: $subject_sha,
      scenario: $scenario,
      decision: $decision,
      candidate: {
        id: $candidate_id,
        state: $candidate_state,
        implementation_status: $implementation_status,
        direct_mappings: {
          observed: $direct_mappings,
          total: 30,
          remaining: (30 - $direct_mappings)
        },
        independent_consumer_adoptions: {
          observed: $independent_adoptions,
          total: 1
        }
      },
      authority: {
        baseline_release: "v0.10.0-dev",
        design_adoption_release: "v0.6.0-dev",
        observation_scope: "CROSS_CONSUMER_PRIMITIVE_ADOPTION_ONLY",
        source_repository_writes: 0,
        local_tests_run: 0,
        cross_project_required_gates: 0,
        root_readme_readiness: "EXCLUDED",
        central_orchestration_authorized: false,
        common_generator_authorized: false,
        product_release_independence_required: true
      },
      claim: {
        state: $claim_state,
        stage: (if $claim_state == "CLOSED" then null else $stage end),
        step: (if $claim_state == "CLOSED" then null else $step end),
        reason: $reason,
        unknown_class: (if $claim_state == "UNKNOWN" then $unknown_class else null end),
        next_operation: $next_operation,
        blocked_by: (if $claim_state == "CLOSED" then [] else [$step] end)
      },
      cells: $cells,
      proofs: [
        $d.proofs[] as $proof |
        {
          choice: $proof.choice,
          closed: ([$cells[] | select(.proof_choice == $proof.choice and .state == "CLOSED")] | length),
          total: $proof.total
        }
      ],
      indicator_classes: [
        $d.indicator_classes[] as $indicator |
        {
          class: $indicator.class,
          closed: ([$cells[] | select(.indicator_class == $indicator.class and .state == "CLOSED")] | length),
          total: $indicator.total
        }
      ],
      summary: {
        closed_cells: ([$cells[] | select(.state == "CLOSED")] | length),
        unknown_cells: ([$cells[] | select(.state == "UNKNOWN")] | length),
        refuted_cells: ([$cells[] | select(.state == "REFUTED")] | length),
        total_cells: ($cells | length),
        direct_mappings: $direct_mappings,
        mapping_denominator: 30,
        mapping_remaining: (30 - $direct_mappings),
        independent_consumer_adoptions: $independent_adoptions,
        claim_scenarios_resolved: (if $claim_state == "CLOSED" then 4 else 0 end),
        claim_scenarios_total: 4,
        claim_fields_observed: (if $claim_state == "CLOSED" then 24 else 0 end),
        claim_fields_total: 24,
        matcher_claims_matched: (if $claim_state == "CLOSED" then 4 else 0 end),
        matcher_claims_total: 4,
        adverse_unknown_paths: 1,
        adverse_refuted_paths: 3,
        repository_writes: 0,
        local_tests_run: 0,
        cross_project_required_gates: 0
      },
      evidence: {
        denominator_digest: $denominator_digest,
        graph_digest: $graph_digest,
        baseline_mapping_digest: $baseline_digest,
        design_adoption_digest: $design_digest
      }
    }
  ' > "$output"
