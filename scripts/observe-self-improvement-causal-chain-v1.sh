#!/usr/bin/env bash
set -euo pipefail

if test "$#" -ne 7; then
  echo "usage: observe-self-improvement-causal-chain-v1.sh ROOT GRAPH SCENARIOS RUNTIME OUTPUT SUBJECT_SHA PHASE" >&2
  exit 64
fi

root=$(cd "$1" && pwd)
graph=$2
scenarios=$3
runtime=$4
output=$5
subject_sha=$6
phase=$7
denominator="$root/contracts/self-improvement-causal-chain-denominator-v1.json"
source="$root/examples/self-improvement-causal-chain-v1/main.gooo"

for required in "$graph" "$runtime" "$denominator" "$source"; do
  test -f "$required" || { echo "missing required input: $required" >&2; exit 66; }
  case "$required" in
    *.json) jq -e . "$required" >/dev/null ;;
  esac
done
test -d "$scenarios"

jq -e --arg source "$source" --slurpfile denominator "$denominator" '
  .schema_version == "gooo-graph/v1" and
  ([.nodes[]? | select(.kind == "Activity") | .name] | unique | sort) ==
    ([$denominator[0].cells[].activity] | unique | sort) and
  ([.nodes[]? | select(.kind == "Activity") | .name] | length) == 12 and
  all(.nodes[]? | select(.kind == "Activity"); .namespace == "selfimprovementcausalchain" and (.id|type) == "string" and (.id|length) > 0)
' "$graph" >/dev/null
jq -e '.target_cells == 12 and (.cells | length) == 12 and
  ([.cells[].proof_choice] | sort | group_by(.) | map(length)) == [4,4,4] and
  ([.cells[].indicator_class] | sort | group_by(.) | map(length)) == [4,4,4] and
  (.stage_sequence | length) == 7 and (.edge_sequence | length) == 6 and
  (.required_edge_fields | length) == 6 and (.unknown_coordinates | length) == 6
' "$denominator" >/dev/null

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/scenario-reports"

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
done < <(find "$root" -type f -not -path "$root/.git/*" -not -path "$root/README.md" -print0 | sort -z)

regular_files=$(find "$root" -type f -not -path "$root/.git/*" -not -path "$root/README.md" | wc -l | tr -d ' ')
descendant_directories=$(find "$root" -mindepth 1 -type d -not -path "$root/.git" -not -path "$root/.git/*" | wc -l | tr -d ' ')
physical_lines=$(find "$root" -type f -not -path "$root/.git/*" -not -path "$root/README.md" -print0 |
  xargs -0 -r cat | wc -l | tr -d ' ')
jq -S -s --argjson regular_files "$regular_files" --argjson descendant_directories "$descendant_directories" \
  --argjson physical_lines "$physical_lines" '
  . as $files |
  {root_readme_policy:"EXCLUDED",regular_files:$regular_files,descendant_directories:$descendant_directories,
   physical_lines:$physical_lines,
   go:{files:([$files[]|select(.language=="Go")]|length),lines:([$files[]|select(.language=="Go")|.lines]|add//0)},
   gooo:{files:([$files[]|select(.language=="Gooo")]|length),lines:([$files[]|select(.language=="Gooo")|.lines]|add//0)},
   per_file:$files}
' "$work/source-lines.ndjson" > "$work/inventory.json"

evaluate_scenario() {
  local scenario_file=$1
  local scenario_output=$2
  jq -S -n \
    --slurpfile denominator "$denominator" \
    --slurpfile graph "$graph" \
    --slurpfile scenario "$scenario_file" \
    --slurpfile inventory "$work/inventory.json" \
    --arg subject_sha "$subject_sha" \
    --arg phase "$phase" '
    ($denominator[0]) as $d |
    ($graph[0]) as $g |
    ($scenario[0]) as $s |
    def stage_count($id): [$s.stages[]? | select(.id == $id)] | length;
    def stage($id): ([$s.stages[]? | select(.id == $id)] | if length == 1 then .[0] else null end);
    def nonempty_string:
      if type == "string" then length > 0 else false end;
    def edge_has_fields($edge):
      all($d.required_edge_fields[]; (($edge[.]? // null) | nonempty_string)) and
      (($edge.artifact_digest? // "") | startswith("sha256:")) and
      (($edge.toolchain_digest? // "") | startswith("sha256:")) and
      (($edge.policy_digest? // "") | startswith("sha256:"));
    def edge_matches_stage($edge):
      (stage($edge.from_stage)) as $producer |
      ($producer != null and
       $edge.producer_identity == $producer.producer_identity and
       $edge.producer_release_or_run == $producer.producer_release_or_run and
       $edge.artifact_digest == $producer.artifact_digest and
       $edge.scenario == $s.scenario_id and
       $edge.toolchain_digest == $producer.toolchain_digest and
       $edge.policy_digest == $producer.policy_digest);
    def stages_complete:
      ($s.stages | length) == ($d.stage_sequence | length) and
      all($d.stage_sequence[]; stage_count(.id) == 1 and (stage(.id).available == true));
    def topology_complete:
      ($s.edges | length) == ($d.edge_sequence | length) and
      all(range(0; ($d.edge_sequence | length));
        $s.edges[.]?.from_stage == $d.edge_sequence[.].from and
        $s.edges[.]?.to_stage == $d.edge_sequence[.].to);
    def edges_complete:
      topology_complete and all($s.edges[]?; edge_has_fields(.) and edge_matches_stage(.));
    def normal_statuses:
      stage("OBSERVATION_RECEIPT").status == "OBSERVED" and
      stage("COUNTEREXAMPLE_OR_UNKNOWN").status == "NO_COUNTEREXAMPLE" and
      stage("REVISION_PROPOSAL").status == "PROPOSED" and
      stage("CONFORMANCE_RECEIPT").status == "CONFORMANT" and
      stage("HUMAN_DECISION").status == "APPROVED" and
      stage("MERGE_OR_DEFER_RECEIPT").status == "RECORDED" and
      stage("SUCCESSOR_OBSERVATION").status == "OBSERVED";
    def normal_ready: stages_complete and edges_complete and normal_statuses;
    def decision_known:
      ["CLOSED","UNKNOWN","REFUTED"] | index($s.decision.state) != null;
    def authority_escalated:
      ($s.authority.repository_writes != 0) or
      ($s.authority.local_test_executions != 0) or
      ($s.authority.cross_project_required_gates != 0) or
      ($s.authority.automatic_merge_allowed == true) or
      ($s.authority.release_authority == true) or
      ($s.authority.deploy_authority == true);
    def missing_observation: stage_count("OBSERVATION_RECEIPT") == 0;
    def revision_blocked: ((stage("REVISION_PROPOSAL") // {}).status) == "BLOCKED";
    def stale_conformance:
      ((stage("CONFORMANCE_RECEIPT") // {}).status == "STALE") or
      ((stage("CONFORMANCE_RECEIPT") // {}).freshness == "STALE");
    def ambiguous_human: ((stage("HUMAN_DECISION") // {}).status) == "AMBIGUOUS";
    def explicit_counterexample:
      ((stage("COUNTEREXAMPLE_OR_UNKNOWN") // {}).kind == "EXPLICIT_COUNTEREXAMPLE") and
      ((stage("COUNTEREXAMPLE_OR_UNKNOWN") // {}).status == "REFUTED");
    def digest_laundering:
      ([ $s.edges[]? | select((stage(.from_stage)) != null and
        .artifact_digest != (stage(.from_stage).artifact_digest) and
        (.artifact_digest? // "") != "") ] | length) > 0;
    def unknown_claim:
      if missing_observation then
        {state:"UNKNOWN",stage:"OBSERVATION",step:"RECEIVE_OBSERVATION_RECEIPT",reason:"OBSERVATION_RECEIPT_MISSING",unknown_class:"DIRECT_MISSING",next_operation:"PROVIDE_OBSERVATION_RECEIPT",blocked_by:[],causal_frontier:["OBSERVATION_RECEIPT"]}
      elif revision_blocked then
        {state:"UNKNOWN",stage:"REVISION",step:"PROPOSE_REVISION",reason:"REVISION_DEPENDENCY_BLOCKED",unknown_class:"DEPENDENCY_BLOCKED",next_operation:"RESOLVE_COUNTEREXAMPLE_OR_UNKNOWN",blocked_by:["COUNTEREXAMPLE_OR_UNKNOWN"],causal_frontier:["COUNTEREXAMPLE_OR_UNKNOWN"]}
      elif stale_conformance then
        {state:"UNKNOWN",stage:"CONFORMANCE",step:"CHECK_CONFORMANCE_RECEIPT",reason:"CONFORMANCE_RECEIPT_STALE",unknown_class:"STALE",next_operation:"REISSUE_CONFORMANCE_RECEIPT",blocked_by:["REVISION_PROPOSAL"],causal_frontier:["CONFORMANCE_RECEIPT"]}
      elif ambiguous_human then
        {state:"UNKNOWN",stage:"DECISION",step:"RESOLVE_HUMAN_DECISION",reason:"HUMAN_DECISION_AMBIGUOUS",unknown_class:"AMBIGUOUS",next_operation:"OBTAIN_EXPLICIT_HUMAN_DECISION",blocked_by:["HUMAN_DECISION"],causal_frontier:["HUMAN_DECISION"]}
      else null end;
    def refuted_claim:
      if decision_known | not then
        {state:"REFUTED",stage:"DECISION",step:"VALIDATE_TOP_LEVEL_DECISION",reason:"UNRECOGNIZED_TOP_LEVEL_DECISION",unknown_class:null,next_operation:"RESTORE_RECOGNIZED_DECISION",blocked_by:[],causal_frontier:[]}
      elif authority_escalated then
        {state:"REFUTED",stage:"AUTHORITY",step:"PRESERVE_CALLER_OWNED_AUTHORITY",reason:"AUTHORITY_WRITE_ESCALATION",unknown_class:null,next_operation:"RESTORE_CALLER_OWNED_BOUNDARY",blocked_by:[],causal_frontier:[]}
      elif digest_laundering then
        {state:"REFUTED",stage:"EDGE",step:"VERIFY_IMMUTABLE_EDGE_PROVENANCE",reason:"DIGEST_LAUNDERING_DETECTED",unknown_class:null,next_operation:"RESTORE_EDGE_PROVENANCE",blocked_by:[],causal_frontier:[]}
      elif explicit_counterexample then
        {state:"REFUTED",stage:"COUNTEREXAMPLE",step:"EVALUATE_COUNTEREXAMPLE_OR_UNKNOWN",reason:"EXPLICIT_COUNTEREXAMPLE_OBSERVED",unknown_class:null,next_operation:"DEFER_OR_REVISE_CLAIM",blocked_by:[],causal_frontier:[]}
      elif (missing_observation | not) and (revision_blocked | not) and (stale_conformance | not) and (ambiguous_human | not) and
        ((stages_complete | not) or (edges_complete | not)) then
        {state:"REFUTED",stage:"CHAIN",step:"VALIDATE_TYPED_CAUSAL_CHAIN",reason:"CAUSAL_CHAIN_STRUCTURE_INVALID",unknown_class:null,next_operation:"RESTORE_TYPED_CAUSAL_CHAIN",blocked_by:[],causal_frontier:[]}
      elif (missing_observation | not) and (revision_blocked | not) and (stale_conformance | not) and (ambiguous_human | not) and
        (normal_statuses | not) then
        {state:"REFUTED",stage:"CHAIN",step:"VALIDATE_TYPED_CAUSAL_CHAIN",reason:"UNRECOGNIZED_STAGE_STATUS",unknown_class:null,next_operation:"RESTORE_RECOGNIZED_STAGE_STATUS",blocked_by:[],causal_frontier:[]}
      else null end;
    (unknown_claim) as $unknown |
    (refuted_claim) as $refuted |
    (if $refuted != null then "REFUTED" elif $unknown != null then "UNKNOWN" elif normal_ready and $s.decision.state == "CLOSED" then "CLOSED" else "REFUTED" end) as $state |
    (if $state == "REFUTED" then $refuted elif $state == "UNKNOWN" then $unknown else
      {state:"CLOSED",stage:null,step:null,reason:"CAUSAL_CHAIN_CLOSED",unknown_class:null,next_operation:"NONE",blocked_by:[],causal_frontier:[]}
    end) as $claim |
    ([missing_observation,revision_blocked,stale_conformance,ambiguous_human] | map(select(. == true)) | length) as $unknown_conditions |
    ([decision_known|not,authority_escalated,digest_laundering,explicit_counterexample] | map(select(. == true)) | length) as $refuted_conditions |
    ([ $s.edges[]? | select(edge_has_fields(.) and edge_matches_stage(.)) ] | length) as $valid_edges |
    {
      schema:"gooo/meta/self-improvement-causal-chain/scenario-report/v1",
      phase:$phase,
      subject_sha:$subject_sha,
      id:$s.scenario_id,
      declared_decision:($s.decision.state // null),
      expected_state:$s.expected_state,
      state:$state,
      claim:$claim,
      matches_expected:($state == $s.expected_state),
      conditions:{unknown:$unknown_conditions,refuted:$refuted_conditions},
      stages:{observed:($s.stages|length),total:($d.stage_sequence|length)},
      edges:{observed:($s.edges|length),total:($d.edge_sequence|length),valid:$valid_edges,required_fields:($d.required_edge_fields|length)},
      unknown_coordinates_present:(if $state == "UNKNOWN" then
        (["stage","step","reason","unknown_class","next_operation","blocked_by"] | all(.[]; $claim[.] != null))
      else true end),
      causal_frontier_present:($claim.causal_frontier != null),
      inventory:$inventory[0]
    }
  ' "$scenario_file" > "$scenario_output"
}

while IFS= read -r -d '' scenario_file; do
  name=$(basename "$scenario_file" .json)
  evaluate_scenario "$scenario_file" "$work/scenario-reports/$name.json"
done < <(find "$scenarios" -maxdepth 1 -type f -name '*.json' -print0 | sort -z)

scenario_count=$(find "$work/scenario-reports" -maxdepth 1 -type f -name '*.json' | wc -l | tr -d ' ')
test "$scenario_count" -gt 0
jq -S -s '.' "$work/scenario-reports"/*.json > "$work/scenarios.json"

jq -S -n \
  --slurpfile denominator "$denominator" \
  --slurpfile graph "$graph" \
  --slurpfile runtime "$runtime" \
  --slurpfile inventory "$work/inventory.json" \
  --slurpfile scenarios "$work/scenarios.json" \
  --arg subject_sha "$subject_sha" \
  --arg phase "$phase" '
  ($denominator[0]) as $d |
  ($graph[0]) as $g |
  ($runtime[0]) as $r |
  ($scenarios[0]) as $cases |
  ([ $cases[] | select(.state == "CLOSED") ] | length) as $closed |
  ([ $cases[] | select(.state == "UNKNOWN") ] | length) as $unknown |
  ([ $cases[] | select(.state == "REFUTED") ] | length) as $refuted |
  ([ $g.nodes[]? | select(.kind == "Activity") | .name ] | unique) as $activities |
  ([$d.cells[] | select(.proof_choice == "FOUNDATION")] | length) as $foundation_total |
  ([$d.cells[] | select(.proof_choice == "COHERENCE")] | length) as $coherence_total |
  ([$d.cells[] | select(.proof_choice == "REGRESSION")] | length) as $regression_total |
  {
    schema:"gooo/meta/self-improvement-causal-chain/report/v1",
    phase:$phase,
    subject_sha:$subject_sha,
    decision:(if $refuted > 0 then "REFUTED" elif $unknown > 0 then "UNKNOWN" elif $closed == ($cases|length) then "CLOSED" else "REFUTED" end),
    claim:(if $refuted > 0 then
      (($cases | map(select(.state == "REFUTED")) | .[0]).claim)
    elif $unknown > 0 then
      (($cases | map(select(.state == "UNKNOWN")) | .[0]).claim)
    else {state:"CLOSED",stage:null,step:null,reason:"CAUSAL_CHAIN_CASES_CLOSED",unknown_class:null,next_operation:"NONE",blocked_by:[],causal_frontier:[]} end),
    summary:{scenarios_total:($cases|length),closed:$closed,unknown:$unknown,refuted:$refuted,
      stage_total:($d.stage_sequence|length),edge_total:($d.edge_sequence|length),required_edge_fields:($d.required_edge_fields|length),
      unknown_coordinate_fields:($d.unknown_coordinates|length),causal_frontiers_required:($cases|length),
      scenario_expectations_met:([$cases[]|select(.matches_expected==true)]|length),
      scenario_expectations_total:($cases|length)},
    ir:{schema:($g.schema_version // null),source_digest:($g.source_digest // null),meta_activities_observed:($activities|length),meta_activities_total:12,
      typed_chain_stages:($d.stage_sequence|length),typed_chain_edges:($d.edge_sequence|length),activity_names:$activities},
    stage_sequence:$d.stage_sequence,
    edge_sequence:($d.edge_sequence | map(. + {required_fields:$d.required_edge_fields})),
    scenarios:$cases,
    proof_choices:[
      {choice:"FOUNDATION",closed:(if ($activities|length)==12 then $foundation_total else 0 end),total:$foundation_total},
      {choice:"COHERENCE",closed:(if ($activities|length)==12 then $coherence_total else 0 end),total:$coherence_total},
      {choice:"REGRESSION",closed:(if ($activities|length)==12 then $regression_total else 0 end),total:$regression_total}
    ],
    authority:{repository_writes:$r.authority.repository_writes,local_test_executions:$r.authority.local_test_executions,
      cross_project_required_gates:$r.authority.cross_project_required_gates,automatic_merge_allowed:false,release_authority:false,deploy_authority:false},
    performance:$r.performance,
    toolchain:$r.toolchain,
    inventory:$inventory[0],
    artifacts:$r.artifacts,
    improvement:{external_utility:{state:"UNKNOWN",observed:0,required:1,reason:"NO_PUBLIC_UTILITY_RECEIPT"},
      saved_build_ms:{state:"UNKNOWN",observed:null,required:1,reason:"NO_BEFORE_AFTER_BUILD_RECEIPT"},
      saved_test_ms:{state:"UNKNOWN",observed:null,required:1,reason:"NO_BEFORE_AFTER_TEST_RECEIPT"}}
  }
' > "$output"
