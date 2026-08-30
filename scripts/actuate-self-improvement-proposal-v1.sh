#!/usr/bin/env bash
set -euo pipefail

if test "$#" -ne 6; then
  echo "usage: actuate-self-improvement-proposal-v1.sh ROOT GRAPH INPUT OUTPUT SUBJECT_SHA SCENARIO" >&2
  exit 64
fi

root=$(cd "$1" && pwd)
graph=$2
input=$3
output=$4
subject_sha=$5
scenario=$6
denominator="$root/contracts/self-improvement-actuator-v1-denominator.json"
policy="$root/contracts/self-improvement-actuator-v1-policy.json"
predecessor="$root/contracts/temporal-transition-bootstrap-predecessor-v1.json"
source="$root/examples/self-improvement-actuator-v1/main.gooo"

for required in "$graph" "$input" "$denominator" "$policy" "$predecessor" "$source"; do
  test -f "$required" || { echo "missing required input: $required" >&2; exit 66; }
  case "$required" in
    *.json) jq -e . "$required" >/dev/null ;;
  esac
done

if ! jq -e --slurpfile denominator "$denominator" '
  .schema_version == "gooo-graph/v1" and
  ([.nodes[]? | select(.kind == "Activity") | .name] | unique | sort) ==
    ([$denominator[0].cells[].activity] | unique | sort) and
  ([.nodes[]? | select(.kind == "Activity") | .name] | length) == 12 and
  all(.nodes[]? | select(.kind == "Activity"); .namespace == "selfimprovementactuator" and (.id|type) == "string" and (.id|length) > 0)
' "$graph" >/dev/null; then
  echo "released semantic graph binding failed" >&2
  exit 1
fi
if ! jq -e '
  .schema == "gooo/link/self-improvement-actuator-denominator/v1" and
  .target_cells == 12 and (.cells | length) == 12 and
  ([.cells[].proof_choice] | sort | group_by(.) | map(length)) == [4,4,4] and
  ([.cells[].indicator_class] | sort | group_by(.) | map(length)) == [4,4,4] and
  ([.cells[].activity] | unique | length) == 12
' "$denominator" >/dev/null; then
  echo "actuator denominator binding failed" >&2
  exit 1
fi
if ! jq -e '
  .schema == "gooo/link/self-improvement-actuator-policy/v1" and
  .input_states == ["UNKNOWN", "REFUTED"] and
  .decision_precedence == ["REFUTED", "UNKNOWN"] and
  .unknown_coordinates == ["stage", "step", "reason", "unknown_class", "next_operation", "blocked_by"] and
  .allowed_scope.repository_writes == 0 and
  .allowed_scope.source_repository_writes == 0 and
  .allowed_scope.apply_change == false and
  .expected_effect.state == "UNKNOWN" and
  .expected_effect.activity == "PreserveUnknownImprovementClaim" and
  .history_policy.preserve_historical_unknown == true and
  .history_policy.retroactive_closure_allowed == false
' "$policy" >/dev/null; then
  echo "actuator policy binding failed" >&2
  exit 1
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

source_input=$(jq -S -c '
  .replay_guard.consumed_ticket_ids = [] |
  .replay_guard.consumed_proposal_digests = []
' "$input")
source_input_digest="sha256:$(printf '%s' "$source_input" | sha256sum | awk '{print $1}')"
policy_digest="sha256:$(sha256sum "$policy" | awk '{print $1}')"

jq -S -n \
  --slurpfile input "$input" \
  --slurpfile policy "$policy" \
  --slurpfile predecessor "$predecessor" \
  --arg source_input_digest "$source_input_digest" \
  --arg policy_digest "$policy_digest" '
  ($input[0]) as $i |
  ($policy[0]) as $p |
  ($predecessor[0]) as $old |
  def choose_claim($claims):
    ([$claims[]? | select(.state == "REFUTED")] | sort_by(.id)) as $refuted |
    (if ($refuted|length) > 0 then $refuted[0]
     else ([$claims[]? | select(.state == "UNKNOWN")] | sort_by(.id) | .[0]) end);
  (choose_claim($i.observed_claims)) as $claim |
  {
    schema: "gooo/meta/self-improvement/change-proposal/v1",
    proposal_version: 1,
    proposal_id: ("gooo://self-improvement/actuator/proposal/" + ($i.input_id // "missing-input-id")),
    source_input_digest: $source_input_digest,
    policy_digest: $policy_digest,
    temporal_ticket: {
      schema: $i.temporal_ticket.schema,
      ticket_id: $i.temporal_ticket.ticket_id,
      ticket_digest: $i.temporal_ticket.ticket_digest,
      nonce: $i.temporal_ticket.nonce
    },
    observed_claim_ids: ([$i.observed_claims[]?.id] | sort),
    selected_claim: $claim,
    causal_frontier: ($claim.causal_frontier // []),
    change_request: {
      kind: $i.change_request.kind,
      declared_paths: ($i.change_request.declared_paths | sort),
      operation: "DESCRIBE_CHANGE_ONLY"
    },
    allowed_scope: $p.allowed_scope,
    expected_effect: $p.expected_effect,
    replay_rule: $p.replay_guard,
    historical_policy: $p.history_policy,
    temporal_predecessor: {
      identity: $old.identity,
      successor_observation_artifact_digest: $old.successor_observation.artifact_digest
    }
  }
' > "$work/proposal-seed.json"
proposal_digest="sha256:$(sha256sum "$work/proposal-seed.json" | awk '{print $1}')"

jq -S -n \
  --slurpfile input "$input" \
  --slurpfile policy "$policy" \
  --slurpfile predecessor "$predecessor" \
  --slurpfile denominator "$denominator" \
  --slurpfile graph "$graph" \
  --arg proposal_digest "$proposal_digest" \
  --arg source_input_digest "$source_input_digest" \
  --arg policy_digest "$policy_digest" \
  --arg subject_sha "$subject_sha" \
  --arg scenario "$scenario" '
  ($input[0]) as $i |
  ($policy[0]) as $p |
  ($predecessor[0]) as $old |
  ($denominator[0]) as $d |
  ($graph[0]) as $g |
  def choose_claim($claims):
    ([$claims[]? | select(.state == "REFUTED")] | sort_by(.id)) as $refuted |
    (if ($refuted|length) > 0 then $refuted[0]
     else ([$claims[]? | select(.state == "UNKNOWN")] | sort_by(.id) | .[0]) end);
  (choose_claim($i.observed_claims)) as $chosen |
  (if $chosen == null then
     {state:"REFUTED",stage:"ACTUATOR",step:"VALIDATE_CHANGE_PROPOSAL_INPUT",reason:"CLAIM_INPUT_MISSING",unknown_class:null,next_operation:"PROVIDE_UNKNOWN_OR_REFUTED_CLAIM",blocked_by:[],causal_frontier:[]}
   else $chosen end) as $claim |
  ([$p.unknown_coordinates[] | . as $key | $claim | has($key)] | all) as $claim_coordinates_present |
  ([$i.observed_claims[]? | select(.state == "UNKNOWN") |
      ([$p.unknown_coordinates[] | . as $key | has($key)] | all)] | all) as $unknown_coordinates_present |
  ([$i.observed_claims[]?.state] | any(. == "UNKNOWN" or . == "REFUTED")) as $claims_have_supported_state |
  ([$i.observed_claims[]? | .causal_frontier | type == "array" and length > 0] | all) as $frontiers_present |
  (($i.temporal_ticket.schema == $p.temporal_precondition.ticket_schema) and
   ($i.temporal_ticket.state == $p.temporal_precondition.required_state) and
   ($i.temporal_ticket.consumed_once == $p.temporal_precondition.required_consumed_once) and
   ($i.temporal_ticket.phase == "CONSUME_ONCE") and
   ($i.temporal_ticket.ticket_id | type) == "string" and ($i.temporal_ticket.ticket_id | length) > 0 and
   ($i.temporal_ticket.ticket_digest | startswith("sha256:")) and
   ($i.temporal_ticket.nonce | startswith("sha256:")) and
   ($i.temporal_ticket.source_predecessor == {
      identity:$old.identity,
      artifact_digest:$old.observations[0].artifact_digest,
      report_digest:$old.observations[1].artifact_digest,
      successor_observation_artifact_digest:$old.successor_observation.artifact_digest
   }) and
   ($i.temporal_ticket.ticket_digest == $old.successor_observation.artifact_digest) and
   ($old.require_successor_observation == true) and
   ($old.successor_observation.counterexample_state == "UNKNOWN")) as $ticket_ok |
  (($i.change_request.patch == null) and
   ($i.change_request.operation == "DESCRIBE_CHANGE_ONLY") and
   ($i.change_request.requested_repository_writes == 0)) as $scope_ok |
  (($i.replay_guard.post_hoc == false) and
   ($i.replay_guard.retroactive_closure_requested == false) and
   ([$i.historical_claims[]?.state] | all(. == "UNKNOWN"))) as $history_ok |
  ([$i.replay_guard.consumed_ticket_ids[]? | . == $i.temporal_ticket.ticket_id] | any) as $ticket_reuse |
  ([$i.replay_guard.consumed_proposal_digests[]? | . == $proposal_digest] | any) as $proposal_reuse |
  ($ticket_ok and $claims_have_supported_state and $claim_coordinates_present and $unknown_coordinates_present and
   $frontiers_present and $scope_ok and $history_ok and ($ticket_reuse|not) and ($proposal_reuse|not)) as $valid |
  (if $ticket_reuse then "CONSUMED_TICKET_REUSE"
   elif $proposal_reuse then "CONSUMED_PROPOSAL_REUSE"
   elif ($history_ok|not) then "RETROACTIVE_FAILURE_CLOSURE_FORBIDDEN"
   elif ($scope_ok|not) then "PROPOSAL_SCOPE_ESCALATION"
   elif ($ticket_ok|not) then "TEMPORAL_TICKET_NOT_CLOSED_CONSUMED"
   elif ($claims_have_supported_state|not) then "UNSUPPORTED_CLAIM_STATE"
   elif ($claim_coordinates_present|not or $unknown_coordinates_present|not) then "UNKNOWN_COORDINATES_MISSING"
   elif ($frontiers_present|not) then "CAUSAL_FRONTIER_MISSING"
   else ($claim.reason // "CHANGE_PROPOSAL_GENERATED") end) as $reason |
  (if $valid then $claim.state else "REFUTED" end) as $decision |
  (if $valid then "GENERATED" else "REJECTED" end) as $actuator_result |
  (if $valid then "GENERATED" else "REJECTED" end) as $proposal_status |
  (if $valid then null
   elif $ticket_reuse then "TEMPORAL_TICKET"
   elif $proposal_reuse then "PROPOSAL_ARTIFACT"
   elif ($history_ok|not) then "HISTORICAL_CLAIM"
   elif ($scope_ok|not) then "ALLOWED_SCOPE"
   elif ($ticket_ok|not) then "TEMPORAL_TICKET"
   elif ($claims_have_supported_state|not) then "CLAIM_INPUT"
   elif ($claim_coordinates_present|not or $unknown_coordinates_present|not) then "UNKNOWN_COORDINATES"
   else "CAUSAL_FRONTIER" end) as $direct_refutation |
  ($d.cells | map(
    . as $cell |
    (if $valid then
       {state:"CLOSED",reason:$cell.closed_reason,unknown_class:null,next_operation:"NONE",blocked_by:[]}
     elif $cell.id == $direct_refutation then
       {state:"REFUTED",reason:($cell.refuted_reason // $reason),unknown_class:null,next_operation:$cell.next_operation,blocked_by:[]}
     else
       {state:"REFUTED",reason:"DEPENDENCY_REFUTED",unknown_class:null,next_operation:$cell.next_operation,blocked_by:[$direct_refutation]}
     end) as $resolution |
    $cell + $resolution
  )) as $cells |
  ($cells | map({id:("gooo.metric.self-improvement-actuator." + (.id|ascii_downcase)),activity:.activity,value:(if .state=="CLOSED" then 1 else 0 end),total:1,unit:"cell",state:.state})) as $metrics |
  {
    schema: "gooo/meta/self-improvement/change-proposal-report/v1",
    scenario: $scenario,
    subject_sha: $subject_sha,
    decision: $decision,
    actuator_result: $actuator_result,
    claim: $claim,
    causal_frontier: ($claim.causal_frontier // []),
    observed_claims: $i.observed_claims,
    historical_claims: $i.historical_claims,
    proposal: {
      schema: "gooo/meta/self-improvement/change-proposal/v1",
      proposal_id: ("gooo://self-improvement/actuator/proposal/" + ($i.input_id // "missing-input-id")),
      digest: $proposal_digest,
      status: $proposal_status,
      source_input_digest: $source_input_digest,
      policy_digest: $policy_digest,
      temporal_ticket: {ticket_id:$i.temporal_ticket.ticket_id,ticket_digest:$i.temporal_ticket.ticket_digest,nonce:$i.temporal_ticket.nonce},
      generated_change: {mode:"DETERMINISTIC_PROPOSAL_ONLY",apply_change:false,patch:null,repository_writes:0},
      selected_claim: $claim,
      causal_frontier: ($claim.causal_frontier // []),
      allowed_scope: $p.allowed_scope,
      expected_effect: $p.expected_effect,
      replay_guard: {mode:"SINGLE_USE_TICKET_AND_PROPOSAL",same_input:"PROPOSAL_DIGEST_MUST_MATCH",ticket_reuse:"REFUTED",proposal_reuse:"REFUTED"}
    },
    replay_guard: {
      ticket_id: $i.temporal_ticket.ticket_id,
      ticket_nonce: $i.temporal_ticket.nonce,
      consumed_ticket_ids: ($i.replay_guard.consumed_ticket_ids // []),
      consumed_proposal_digests: ($i.replay_guard.consumed_proposal_digests // []),
      ticket_reuse: $ticket_reuse,
      proposal_reuse: $proposal_reuse,
      same_input_replay: "PROPOSAL_DIGEST_MUST_MATCH",
      accepted: ($valid and ($ticket_reuse|not) and ($proposal_reuse|not))
    },
    allowed_scope: $p.allowed_scope,
    expected_effect: ($p.expected_effect + {evidence:0,required:1}),
    improvement_claim: {state:"UNKNOWN",reason:"EXACT_COMPARABLE_BEFORE_AFTER_EVIDENCE_ABSENT",evidence:0,required:1,direction:"UNKNOWN"},
    repository_writes: 0,
    authority: $p.allowed_scope,
    cells: $cells,
    metrics: $metrics,
    summary: {
      denominator_total: 12,
      cells_closed: ([$cells[] | select(.state=="CLOSED")] | length),
      cells_unknown: ([$cells[] | select(.state=="UNKNOWN")] | length),
      cells_refuted: ([$cells[] | select(.state=="REFUTED")] | length),
      denominator_reduced: false,
      score: null
    },
    bindings: {
      gooo_meta_activity_count: 12,
      released_graph_schema: $g.schema_version,
      released_graph_source_digest: $g.source_digest,
      activity_names: ([$g.nodes[]? | select(.kind=="Activity") | .name] | sort),
      temporal_predecessor_identity: $old.identity,
      temporal_predecessor_successor_artifact_digest: $old.successor_observation.artifact_digest
    },
    validation: {
      temporal_ticket: $ticket_ok,
      supported_claim_state: $claims_have_supported_state,
      claim_coordinates: $claim_coordinates_present,
      unknown_coordinates: $unknown_coordinates_present,
      causal_frontier: $frontiers_present,
      allowed_scope: $scope_ok,
      history: $history_ok,
      ticket_reuse: $ticket_reuse,
      proposal_reuse: $proposal_reuse,
      reason: $reason
    }
  }
' < /dev/null > "$output"
