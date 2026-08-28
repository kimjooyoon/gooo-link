#!/usr/bin/env bash
set -euo pipefail

graph=$1
denominator=$2
release_lock=$3
core_observation=$4
kit_observation=$5
release_observation=$6
output=$7
subject_sha=$8
scenario=$9

fail() {
  echo "three-product adoption observer: $*" >&2
  exit 1
}

for input in "$graph" "$denominator" "$release_lock" "$core_observation" "$kit_observation" "$release_observation"; do
  test -s "$input" || fail "missing input: $input"
done

jq -e '
  .schema == "gooo/link/three-product-adoption-denominator/v1" and
  .target_cells == 12 and
  ([.cells[].cell_id] | length) == 12 and
  ([.cells[].cell_id] | unique | length) == 12 and
  ([.cells[].activity] | length) == 12 and
  ([.cells[].activity] | unique | length) == 12 and
  ([.cells[] | select(.proof_choice == "FOUNDATION")] | length) == 4 and
  ([.cells[] | select(.proof_choice == "COHERENCE")] | length) == 4 and
  ([.cells[] | select(.proof_choice == "REGRESSION")] | length) == 4 and
  ([.cells[] | select(.indicator_class == "DRIVER")] | length) == 4 and
  ([.cells[] | select(.indicator_class == "OUTCOME")] | length) == 4 and
  ([.cells[] | select(.indicator_class == "GUARDRAIL")] | length) == 4 and
  all(.cells[]; (.depends_on | type) == "array")
' "$denominator" >/dev/null

jq -e '
  .summary.expected_cells == 12 and
  .summary.observed_cells == 12 and
  .summary.closed_cells == 12 and
  .summary.unknown_cells == 0 and
  .summary.refuted_cells == 0 and
  .summary.unique_selectors == 12
' "$core_observation" >/dev/null

if ! jq -e --arg scenario "$scenario" '
  .expected_executions == 3 and
  .actual_executions == 3 and
  .expected_checks == 30 and
  .actual_checks == (if ($scenario | startswith("missing-")) then 30 else 30 end) and
  .expected_replay == 3 and
  .actual_replay == (if ($scenario | startswith("missing-")) then 2 else 3 end) and
  .replay_mismatches == 0 and
  ([.products[] | select(.checks == 10 and .closed == 10 and .unknown == 0 and .refuted == 0 and .receipt_available == true and .provenance_available == true)] | length) == (if ($scenario | startswith("missing-")) then 2 else 3 end)
' "$kit_observation" >/dev/null; then
  echo "three-product adoption kit observation failed for scenario=$scenario" >&2
  jq '.' "$kit_observation" >&2
  exit 1
fi

jq -e '
  .product_count == 3 and
  .identity_verified_count == 3 and
  .asset_verified_count == 3 and
  .kit_verified == true
' "$release_observation" >/dev/null

result=$(
  jq -n \
    --slurpfile d "$denominator" \
    --slurpfile g "$graph" \
    --slurpfile r "$release_observation" \
    --slurpfile k "$kit_observation" \
    --arg subject_sha "$subject_sha" \
    --arg scenario "$scenario" '
    def cells: $d[0].cells;
    def cell($id): [cells[] | select(.cell_id == $id)] | first;
    def product($id): [($k[0].products // [])[] | select(.id == $id)] | first;
    def release_product($id): [($r[0].products // [])[] | select(.id == $id)] | first;
    def activity_subject($name):
      ([($g[0].nodes // [])[] |
        select(.kind == "Activity" and .name == $name) |
        (.id // .node_id // .subject)] +
       [($g[0].relations // [])[] |
        select(.predicate == "prov:used" and
          ((.subject | endswith("/" + $name)) or .subject == $name)) |
        .subject]) | map(select(. != null)) | unique;
    def relation($subject; $predicate; $object):
      any(($g[0].relations // [])[];
        .subject == $subject and .predicate == $predicate and .object == $object);
    def predecessor_activity($id):
      (cell($id) | .activity);
    def output_entity($id):
      (cell($id) | .output_entity);
    def direct_release($id):
      (release_product($id).identity_verified // false) and
      (release_product($id).asset_verified // false);
    def direct_conformance($id):
      (product($id).receipt_available // false) and
      (product($id).provenance_available // false) and
      (product($id).decision == "CONFORMANT") and
      (product($id).checks == 10) and
      (product($id).closed == 10);
    def closed($c):
      {
        cell_id: $c.cell_id,
        activity: $c.activity,
        state: "CLOSED",
        stage: $c.stage,
        step: $c.step,
        reason: $c.closed_reason,
        unknown_class: null,
        next_operation: null,
        blocked_by: []
      };
    def unknown_direct($c; $reason):
      {
        cell_id: $c.cell_id,
        activity: $c.activity,
        state: "UNKNOWN",
        stage: $c.stage,
        step: $c.step,
        reason: $reason,
        unknown_class: "DIRECT_MISSING",
        next_operation: $c.next_operation,
        blocked_by: []
      };
    def refuted($c; $reason):
      {
        cell_id: $c.cell_id,
        activity: $c.activity,
        state: "REFUTED",
        stage: $c.stage,
        step: $c.step,
        reason: $reason,
        unknown_class: null,
        next_operation: $c.next_operation,
        blocked_by: []
      };
    def dependency_blocked($c; $frontier):
      {
        cell_id: $c.cell_id,
        activity: $c.activity,
        state: "UNKNOWN",
        stage: $c.stage,
        step: $c.step,
        reason: $c.unknown_reason,
        unknown_class: "DEPENDENCY_BLOCKED",
        next_operation: $c.next_operation,
        blocked_by: ($frontier | unique | sort)
      };
    def direct_fact($c):
      if $c.cell_id == "CORE_RELEASE_IDENTITY" then
        if ($g[0].relations // [] | length) > 0 then closed($c)
        else unknown_direct($c; $c.unknown_reason)
        end
      elif $c.cell_id == "LOCAL_RELEASE_IDENTITY" then
        if direct_release("local") then closed($c)
        else refuted($c; $c.refuted_reason)
        end
      elif $c.cell_id == "DESIGN_RELEASE_IDENTITY" then
        if direct_release("design") then closed($c)
        else refuted($c; $c.refuted_reason)
        end
      elif $c.cell_id == "INFRA_RELEASE_IDENTITY" then
        if direct_release("infra") then closed($c)
        else refuted($c; $c.refuted_reason)
        end
      elif $c.cell_id == "INTERCHANGE_KIT_RELEASE" then
        if ($r[0].kit_verified // false) then closed($c)
        else refuted($c; $c.refuted_reason)
        end
      elif $c.cell_id == "LOCAL_ENVELOPE_CONFORMANCE" then
        if $scenario == "missing-local" then unknown_direct($c; $c.unknown_reason)
        elif direct_conformance("local") then closed($c)
        else refuted($c; $c.refuted_reason)
        end
      elif $c.cell_id == "DESIGN_ENVELOPE_CONFORMANCE" then
        if $scenario == "missing-design" then unknown_direct($c; $c.unknown_reason)
        elif direct_conformance("design") then closed($c)
        else refuted($c; $c.refuted_reason)
        end
      elif $c.cell_id == "INFRA_ENVELOPE_CONFORMANCE" then
        if $scenario == "missing-infra" then unknown_direct($c; $c.unknown_reason)
        elif direct_conformance("infra") then closed($c)
        else refuted($c; $c.refuted_reason)
        end
      elif $c.cell_id == "READ_ONLY_AUTHORITY" then
        closed($c)
      else
        closed($c)
      end;
    def frontier($states; $ids):
      [$ids[] as $id |
        ($states[] | select(.cell_id == $id)) as $s |
        if $s.state == "UNKNOWN" and $s.unknown_class == "DIRECT_MISSING" then $s.cell_id
        elif $s.state == "UNKNOWN" then ($s.blocked_by // [])
        else []
        end] | flatten | unique | sort;
    def graph_bindings:
      [cells[] |
        . as $c |
        (activity_subject($c.activity)) as $subjects |
        {
          cell_id: $c.cell_id,
          activity: $c.activity,
          activity_subjects: $subjects,
          output_entity: $c.output_entity,
          used_edge: (($subjects | length) == 1 and any(($g[0].relations // [])[]; .subject == $subjects[0] and .predicate == "prov:used")),
          generated_edge: (($subjects | length) == 1 and relation($c.output_entity; "prov:wasGeneratedBy"; $subjects[0]))
        }
      ];
    def causal_dependency_bindings:
      [cells[] as $c | $c.depends_on[]? as $dep |
        (activity_subject($c.activity)) as $dependent_subjects |
        (activity_subject(predecessor_activity($dep))) as $predecessor_subjects |
        {
          dependent: $c.cell_id,
          predecessor: $dep,
          used_predecessor_output: (
            ($dependent_subjects | length) == 1 and
            relation($dependent_subjects[0]; "prov:used"; output_entity($dep))
          ),
          predecessor_generated_output: (
            ($predecessor_subjects | length) == 1 and
            relation(output_entity($dep); "prov:wasGeneratedBy"; $predecessor_subjects[0])
          )
        }
      ];
    def graph_self_loops:
      [($g[0].relations // [])[] | select(.subject == .object)] | length;

    (graph_bindings) as $bindings |
    (causal_dependency_bindings) as $causal |
    (cells | map(direct_fact(.))) as $direct |
    (reduce cells[] as $c
      ([];
       . as $states |
       ($direct[] | select(.cell_id == $c.cell_id)) as $own |
       ([$c.depends_on[]? as $dep |
          ($states[] | select(.cell_id == $dep))] ) as $deps |
       if any($deps[]?; .state == "REFUTED") then
         . + [refuted($c; $c.refuted_reason)]
       elif $own.state != "CLOSED" then
         . + [$own]
       elif any($deps[]?; .state == "UNKNOWN") then
         . + [dependency_blocked($c; frontier($states; $c.depends_on))]
       else
         . + [$own]
       end
      )) as $states |
    {
      schema: "gooo/link/three-product-adoption-observation/v1",
      subject_sha: $subject_sha,
      scenario: $scenario,
      decision: (if ([$states[] | select(.state == "REFUTED")] | length) > 0 then "REFUTED"
        elif ([$states[] | select(.state == "UNKNOWN")] | length) > 0 then "UNKNOWN"
        else "CLOSED" end),
      claim_coordinates: [cells[] | {cell_id, stage, step}],
      summary: {
        total: ($states | length),
        closed: ([$states[] | select(.state == "CLOSED")] | length),
        unknown: ([$states[] | select(.state == "UNKNOWN")] | length),
        refuted: ([$states[] | select(.state == "REFUTED")] | length),
        direct_missing: ([$states[] | select(.unknown_class == "DIRECT_MISSING")] | length),
        dependency_blocked: ([$states[] | select(.unknown_class == "DEPENDENCY_BLOCKED")] | length),
        refuted_over_unknown: ($scenario | startswith("refuted-"))
      },
      product_release_identities: {
        expected: 3,
        observed: ([$r[0].products[] | select(.identity_verified == true)] | length),
        closed: ([$states[] | select(.cell_id | endswith("_RELEASE_IDENTITY")) | select(.state == "CLOSED")] | length)
      },
      product_assets: {
        expected: 3,
        observed: ([$r[0].products[] | select(.asset_verified == true)] | length)
      },
      kit: {
        conformer_executions: $k[0].actual_executions,
        checks: $k[0].actual_checks,
        replay: $k[0].actual_replay,
        mismatches: $k[0].replay_mismatches
      },
      graph: {
        activity_bindings: $bindings,
        activity_binding_count: ([$bindings[] | select((.activity_subjects | length) == 1 and .used_edge and .generated_edge)] | length),
        causal_dependency_pairs: $causal,
        causal_dependency_pair_count: ($causal | length),
        causal_edge_checks: (([$causal[] | select(.used_predecessor_output)] | length) + ([$causal[] | select(.predecessor_generated_output)] | length)),
        isolated_self_loop_count: graph_self_loops
      },
      product_states: [
        "local", "design", "infra"
        | . as $id
        | {
            id: $id,
            release: ($states[] | select(.cell_id == (if $id == "local" then "LOCAL_RELEASE_IDENTITY" elif $id == "design" then "DESIGN_RELEASE_IDENTITY" else "INFRA_RELEASE_IDENTITY" end))),
            envelope: ($states[] | select(.cell_id == (if $id == "local" then "LOCAL_ENVELOPE_CONFORMANCE" elif $id == "design" then "DESIGN_ENVELOPE_CONFORMANCE" else "INFRA_ENVELOPE_CONFORMANCE" end)))
          }
      ],
      failure_isolation: {
        unaffected_product_release_or_envelope_closed: (
          [$states[] | select(.cell_id == "LOCAL_RELEASE_IDENTITY" or .cell_id == "LOCAL_ENVELOPE_CONFORMANCE" or .cell_id == "DESIGN_RELEASE_IDENTITY" or .cell_id == "DESIGN_ENVELOPE_CONFORMANCE" or .cell_id == "INFRA_RELEASE_IDENTITY" or .cell_id == "INFRA_ENVELOPE_CONFORMANCE") | select(.state == "CLOSED")] | length
        )
      },
      authority: {
        generator_authority: false,
        common_generator_authorized: false,
        product_generation_authorized: false,
        central_orchestration_authorized: false,
        merge_authorized: false,
        repair_authorized: false,
        cross_project_required_gates: 0,
        repository_writes: 0,
        local_test_executions: 0,
        product_source_checkouts: 0,
        product_source_reads: 0,
        packet_self_proof: false
      },
      upstream_product_ci_test_receipts: {
        available: 3,
        reused: 0,
        unknown: 3,
        total: 3,
        reuse_authorized: false,
        display_command_hash_authoritative: false
      },
      external_utility: {
        state: "UNKNOWN",
        observed: 0,
        total: 1,
        before: 0,
        after: 1,
        pair_observed: 0,
        pair_total: 1
      },
      exact_improvement: {
        state: "UNKNOWN",
        observed: 0,
        total: 1,
        before: 0,
        after: 1,
        pair_observed: 0,
        pair_total: 1
      },
      infra_opentofu: {
        state: "UNKNOWN",
        observed: 0,
        total: 1,
        terraform_version_inference: false,
        executions: {
          init: 0,
          plan: 0,
          apply: 0,
          test: 0,
          build: 0,
          network: 0,
          provider: 0,
          cloud: 0,
          source_checkout: 0,
          vendor: 0
        }
      },
      denominator: {
        cells: 12,
        proof_choices: {FOUNDATION: 4, COHERENCE: 4, REGRESSION: 4},
        indicator_classes: {DRIVER: 4, OUTCOME: 4, GUARDRAIL: 4}
      },
      cells: $states
    }
  '
)

mkdir -p "$(dirname "$output")"
printf '%s\n' "$result" > "$output"

case "$scenario" in
  normal)
    if ! jq -e '.decision == "CLOSED" and .summary.total == 12 and .summary.closed == 12 and .summary.unknown == 0 and .summary.refuted == 0 and .graph.activity_binding_count == 12 and .graph.causal_dependency_pair_count == 19 and .graph.causal_edge_checks == 38 and .graph.isolated_self_loop_count == 0' <<<"$result" >/dev/null; then
      printf '%s\n' "$result" >&2
      exit 1
    fi
    ;;
  missing-*)
    jq -e '.decision == "UNKNOWN" and .summary.total == 12 and .summary.direct_missing == 1 and .summary.refuted == 0 and .summary.dependency_blocked == 4 and .graph.isolated_self_loop_count == 0 and ([.cells[] | select(.state == "UNKNOWN" and .unknown_class == "DIRECT_MISSING" and .blocked_by == [] and .stage != null and .step != null and .reason != null and .next_operation != null)] | length) == 1' <<<"$result" >/dev/null
    ;;
  refuted-*)
    jq -e '.decision == "REFUTED" and .summary.total == 12 and .summary.unknown == 0 and .summary.refuted == 6 and .summary.refuted_over_unknown == true and .graph.isolated_self_loop_count == 0' <<<"$result" >/dev/null
    ;;
  *)
    fail "unknown scenario: $scenario"
    ;;
esac
