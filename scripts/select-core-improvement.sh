#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 12 ]; then
  echo "usage: select-core-improvement.sh GRAPH CORE_RESOLUTIONS DENOMINATOR LOCKS RELEASE_OBSERVATION LOCAL_ADOPTION LOCAL_BUNDLE DESIGN_ADOPTION DESIGN_BUNDLE OUTPUT SUBJECT_SHA SCENARIO" >&2
  exit 64
fi

graph=$1
core_resolutions=$2
denominator=$3
locks=$4
release_observation=$5
local_adoption_input=$6
local_bundle=$7
design_adoption_input=$8
design_bundle=$9
output=${10}
subject_sha=${11}
scenario=${12}

json_or_null() {
  input=$1
  destination=$2
  if [ -s "$input" ] && jq -e . "$input" >/dev/null 2>&1; then
    jq -S . "$input" > "$destination"
  else
    printf 'null\n' > "$destination"
  fi
}

tmp=$(mktemp -d)
json_or_null "$local_adoption_input" "$tmp/local-adoption.json"
json_or_null "$design_adoption_input" "$tmp/design-adoption.json"
json_or_null "$local_bundle/generation-report.json" "$tmp/local-report.json"
json_or_null "$design_bundle/generation-report.json" "$tmp/design-report.json"
json_or_null "$local_bundle/contracts/core-release-lock-v1.json" "$tmp/local-core-lock.json"
json_or_null "$design_bundle/contracts/core-release-lock-v1.json" "$tmp/design-core-lock.json"

jq -e '.schema_version=="gooo-graph/v1"' "$graph" >/dev/null
jq -e '.schema=="gooo/link/core-activity-cardinality-observation/v1" and (.receipts|type)=="array"' "$core_resolutions" >/dev/null
jq -e '.schema=="gooo/link/core-improvement-selection-denominator/v1" and .target_cells==12 and (.cells|length)==12' "$denominator" >/dev/null
jq -e '.schema=="gooo/link/generator-consumer-release-locks/v1" and (.consumers|length)==2' "$locks" >/dev/null
jq -e '.schema=="gooo/link/generator-consumer-release-observation/v1" and (.consumers|length)==2' "$release_observation" >/dev/null

jq -S -n \
  --slurpfile graph "$graph" \
  --slurpfile core_resolutions "$core_resolutions" \
  --slurpfile denominator "$denominator" \
  --slurpfile locks "$locks" \
  --slurpfile releases "$release_observation" \
  --slurpfile local_adoption "$tmp/local-adoption.json" \
  --slurpfile design_adoption "$tmp/design-adoption.json" \
  --slurpfile local_report "$tmp/local-report.json" \
  --slurpfile design_report "$tmp/design-report.json" \
  --slurpfile local_lock "$tmp/local-core-lock.json" \
  --slurpfile design_lock "$tmp/design-core-lock.json" \
  --arg subject_sha "$subject_sha" \
  --arg scenario "$scenario" '
  ($graph[0]) as $g |
  ($core_resolutions[0]) as $core |
  ($denominator[0]) as $d |
  ($locks[0]) as $lockset |
  ($releases[0]) as $release |
  ($local_adoption[0]) as $la |
  ($design_adoption[0]) as $da |
  ($local_report[0]) as $lr |
  ($design_report[0]) as $dr |
  ($local_lock[0]) as $ll |
  ($design_lock[0]) as $dl |
  def activity_occurrences($name):
    [$g.nodes[]? | select(.kind=="Activity" and .name==$name)] | length;
  def closed_fact: {state:"CLOSED",reason:"FACT_OBSERVED",next_operation:"NONE",unknown_class:null,blocked_by:[]};
  def unknown_fact($reason;$next): {state:"UNKNOWN",reason:$reason,next_operation:$next,unknown_class:"DIRECT_MISSING",blocked_by:[]};
  def refuted_fact($reason;$next): {state:"REFUTED",reason:$reason,next_operation:$next,unknown_class:null,blocked_by:[]};
  def core_resolution_fact($cell):
    if $core.core_release != $lockset.core_release then
      refuted_fact("CORE_RELEASE_IDENTITY_MISMATCH";"RESTORE_PINNED_CORE_RELEASE") +
        {stage:"RELEASE",step:"BIND_CORE_RELEASE_IDENTITY",activity_occurrences:null,core_decision:null}
    else
      ([$core.receipts[]? | select(.selector.name?==$cell.activity)]) as $receipts |
      if ($receipts|length)==0 then
        unknown_fact("CORE_ACTIVITY_RESOLUTION_RECEIPT_UNAVAILABLE";"PROVIDE_CORE_ACTIVITY_RESOLUTION_RECEIPT") +
          {stage:"RESOLUTION_OBSERVATION",step:"BIND_CORE_ACTIVITY_RESOLUTION_RECEIPT",activity_occurrences:null,core_decision:null}
      elif ($receipts|length)>1 then
        refuted_fact("DUPLICATE_CORE_ACTIVITY_RESOLUTION_RECEIPT";"REMOVE_DUPLICATE_CORE_ACTIVITY_RESOLUTION_RECEIPT") +
          {stage:"RESOLUTION_OBSERVATION",step:"BIND_CORE_ACTIVITY_RESOLUTION_RECEIPT",activity_occurrences:null,core_decision:null}
      else
        ($receipts[0]) as $receipt |
        if $receipt.schema!=$lockset.core_release.resolution_schema or
          $receipt.selector.name!=$cell.activity or
          $receipt.subject.source_file!="examples/core-improvement-selection/main.gooo" then
          refuted_fact("INVALID_CORE_ACTIVITY_RESOLUTION_RECEIPT";"RESTORE_CORE_ACTIVITY_RESOLUTION_RECEIPT") +
            {stage:"RESOLUTION_OBSERVATION",step:"VALIDATE_CORE_ACTIVITY_RESOLUTION_RECEIPT",activity_occurrences:($receipt.occurrences // null),core_decision:($receipt.decision // null)}
        elif $receipt.decision=="CLOSED" and $receipt.claim.state=="CLOSED" and
          $receipt.occurrences==1 and ($receipt.matches|length)==1 and
          $receipt.claim.stage=="RESOLUTION" and $receipt.claim.step=="RESOLVE_ACTIVITY_CARDINALITY" and
          $receipt.claim.reason=="ACTIVITY_UNIQUELY_RESOLVED" and
          $receipt.claim.next_operation=="USE_RESOLVED_ACTIVITY" and
          $receipt.claim.proof_choice=="COHERENCE" and ($receipt.claim.blocked_by|length)==0 then
          {state:"CLOSED",reason:$receipt.claim.reason,next_operation:$receipt.claim.next_operation,unknown_class:null,blocked_by:$receipt.claim.blocked_by,stage:$receipt.claim.stage,step:$receipt.claim.step,activity_occurrences:$receipt.occurrences,core_decision:$receipt.decision}
        elif $receipt.decision=="UNKNOWN" and $receipt.claim.state=="UNKNOWN" and
          $receipt.occurrences==0 and ($receipt.matches|length)==0 and
          $receipt.claim.stage=="RESOLUTION" and $receipt.claim.step=="RESOLVE_ACTIVITY_CARDINALITY" and
          $receipt.claim.reason=="ACTIVITY_NOT_FOUND" and $receipt.claim.unknown_class=="DIRECT_MISSING" and
          $receipt.claim.next_operation=="DECLARE_OR_WIDEN_ACTIVITY_SELECTOR" and
          $receipt.claim.proof_choice=="FOUNDATION" and ($receipt.claim.blocked_by|length)==0 then
          {state:"UNKNOWN",reason:$receipt.claim.reason,next_operation:$receipt.claim.next_operation,unknown_class:$receipt.claim.unknown_class,blocked_by:$receipt.claim.blocked_by,stage:$receipt.claim.stage,step:$receipt.claim.step,activity_occurrences:$receipt.occurrences,core_decision:$receipt.decision}
        elif $receipt.decision=="REFUTED" and $receipt.claim.state=="REFUTED" and
          $receipt.occurrences>1 and ($receipt.matches|length)==$receipt.occurrences and
          $receipt.claim.stage=="RESOLUTION" and $receipt.claim.step=="RESOLVE_ACTIVITY_CARDINALITY" and
          $receipt.claim.reason=="AMBIGUOUS_ACTIVITY_BINDING" and
          $receipt.claim.next_operation=="NARROW_ACTIVITY_SELECTOR" and
          $receipt.claim.proof_choice=="REGRESSION" and ($receipt.claim.blocked_by|length)==0 then
          {state:"REFUTED",reason:$receipt.claim.reason,next_operation:$receipt.claim.next_operation,unknown_class:null,blocked_by:$receipt.claim.blocked_by,stage:$receipt.claim.stage,step:$receipt.claim.step,activity_occurrences:$receipt.occurrences,core_decision:$receipt.decision}
        else
          refuted_fact("UNRECOGNIZED_CORE_ACTIVITY_RESOLUTION_DECISION";"RESTORE_CORE_ACTIVITY_RESOLUTION_RECEIPT") +
            {stage:"RESOLUTION",step:"RESOLVE_ACTIVITY_CARDINALITY",activity_occurrences:($receipt.occurrences // null),core_decision:($receipt.decision // null)}
        end
      end
    end;
  ($la != null and $da != null) as $adoptions_available |
  ($lr != null and $dr != null and $ll != null and $dl != null) as $bundles_available |
  ($lockset.consumers[]|select(.id=="local-ledger")) as $local_release_lock |
  ($lockset.consumers[]|select(.id=="design-evidence")) as $design_release_lock |
  ({
    CONSUMER_RELEASE_IDENTITIES:
      (if ($release.consumers|length)==2 and all($release.consumers[];.identity_verified and .assets_verified==2 and .manifest_entries_verified==6)
       then closed_fact else refuted_fact("CONSUMER_RELEASE_IDENTITY_MISMATCH";"RESTORE_PINNED_RELEASE_ASSETS") end),
    MERGED_ADOPTION_RECEIPTS:
      (if ($adoptions_available|not) then unknown_fact("MERGED_ADOPTION_RECEIPT_UNAVAILABLE";"PROVIDE_MERGED_ADOPTION_RECEIPTS")
       elif $la.schema=="gooo/evidence-generator/consumer-adoption/v1" and $da.schema=="gooo/evidence-generator/consumer-adoption/v1" and
         $la.adoption_state=="MAIN_MERGED" and $da.adoption_state=="MAIN_MERGED" and
         [$la.merged_public_consumers,$da.merged_public_consumers]==[1,2] and
         $la.subject_sha==$local_release_lock.target_commit_sha and $da.subject_sha==$design_release_lock.target_commit_sha
       then closed_fact else refuted_fact("MERGED_ADOPTION_RECEIPT_MISMATCH";"RESTORE_MERGED_ADOPTION_RECEIPTS") end),
    DISTINCT_PROJECT_GRAPHS:
      (if ($bundles_available|not) then unknown_fact("PROJECT_GRAPH_EVIDENCE_UNAVAILABLE";"PROVIDE_GENERATED_PROJECT_REPORTS")
       elif $lr.subject.meta_graph_hash==$dr.subject.meta_graph_hash and
         $lr.subject.project_graph_hash!=$dr.subject.project_graph_hash and
         $lr.subject.project_graph_hash!=$lr.subject.meta_graph_hash and
         $dr.subject.project_graph_hash!=$dr.subject.meta_graph_hash and
         ($ll.assets|length)==8 and ($dl|has("assets")|not) and ($dl.release.assets|length)==8
       then closed_fact else refuted_fact("PROJECT_GRAPH_DIVERSITY_MISMATCH";"RESTORE_DISTINCT_PROJECT_EVIDENCE") end),
    COMPLETE_GENERATION:
      (if ($bundles_available|not) then unknown_fact("COMPLETE_GENERATION_UNAVAILABLE";"PROVIDE_COMPLETE_GENERATION_REPORTS")
       elif $lr.decision=="PROJECT_GENERATED" and $dr.decision=="PROJECT_GENERATED" and
         $lr.summary.closed==12 and $dr.summary.closed==12 and $lr.summary.unknown==0 and $dr.summary.unknown==0 and
         $lr.summary.refuted==0 and $dr.summary.refuted==0
       then closed_fact else refuted_fact("COMPLETE_GENERATION_MISMATCH";"RESTORE_COMPLETE_GENERATION") end),
    PROMOTED_PATTERNS:
      (if ($bundles_available|not) then closed_fact
       elif $lr.patterns.promoted==11 and $dr.patterns.promoted==11 then closed_fact
       else refuted_fact("PROMOTED_PATTERN_COUNT_MISMATCH";"RESTORE_PROMOTED_PATTERN_COUNTS") end),
    GENERATED_FILE_COUNTS:
      (if ($adoptions_available|not) then closed_fact
       elif $la.complete.generated_files==7 and $da.complete.generated_files==7 then closed_fact
       else refuted_fact("GENERATED_FILE_COUNT_MISMATCH";"RESTORE_GENERATED_FILE_COUNTS") end),
    MISSING_RESOLUTION:
      (if ($adoptions_available|not) then closed_fact
       elif $la.missing.direct_missing==1 and $da.missing.direct_missing==1 and
         $la.missing.dependency_blocked>0 and $da.missing.dependency_blocked>0
       then closed_fact else refuted_fact("DIRECT_MISSING_INVARIANT_MISMATCH";"RESTORE_DIRECT_MISSING_RESOLUTION") end),
    DUPLICATE_RESOLUTION:
      (if ($adoptions_available|not) then closed_fact
       elif $la.duplicate.refuted>0 and $da.duplicate.refuted>0
       then closed_fact else refuted_fact("AMBIGUOUS_ACTIVITY_INVARIANT_MISMATCH";"RESTORE_DUPLICATE_ACTIVITY_RESOLUTION") end),
    DOMAIN_SPECIFIC_COUNTS:
      (if ($adoptions_available|not) then closed_fact
       elif [$la.missing.closed,$da.missing.closed]==[4,3] and
         [$la.missing.dependency_blocked,$da.missing.dependency_blocked]==[7,8] and
         [$la.duplicate.closed,$da.duplicate.closed]==[11,8] and
         [$la.duplicate.refuted,$da.duplicate.refuted]==[1,4]
       then closed_fact else refuted_fact("DOMAIN_SPECIFIC_COUNT_MISMATCH";"RESTORE_DOMAIN_SPECIFIC_COUNTS") end),
    ZERO_REPOSITORY_WRITES:
      (if ($adoptions_available|not) then closed_fact
       elif $la.repository_writes==0 and $da.repository_writes==0 and $la.local_tests_run==0 and $da.local_tests_run==0
       then closed_fact else refuted_fact("CONSUMER_EFFECT_MISMATCH";"RESTORE_ZERO_WRITE_RECEIPTS") end),
    DETERMINISTIC_ARTIFACTS:
      (if all($release.consumers[];.assets_verified==2 and .manifest_entries_verified==6)
       then closed_fact else refuted_fact("CONSUMER_ARTIFACT_DIGEST_MISMATCH";"RESTORE_CONSUMER_ARTIFACTS") end),
    CORE_IMPROVEMENT_SELECTION: closed_fact
  }) as $facts |
  (reduce $d.cells[] as $cell
    ({cells:[],decisions:{}};
      . as $acc |
      (core_resolution_fact($cell)) as $resolution |
      ([$cell.depends_on[]? | $acc.decisions[.]]) as $dependencies |
      ($facts[$cell.id]) as $fact |
      (if $resolution.state!="CLOSED" then $resolution
       elif $fact.state!="CLOSED" then $fact
       elif any($dependencies[];.state=="REFUTED") then
         {state:"REFUTED",reason:"DEPENDENCY_REFUTED",next_operation:"RESOLVE_REFUTED_PREDECESSORS",unknown_class:null,blocked_by:[$dependencies[]|select(.state=="REFUTED")|.cell_id]}
       elif any($dependencies[];.state=="UNKNOWN") then
         {state:"UNKNOWN",reason:"DEPENDENCY_BLOCKED",next_operation:"RESOLVE_UNKNOWN_PREDECESSORS",unknown_class:"DEPENDENCY_BLOCKED",blocked_by:[$dependencies[]|select(.state=="UNKNOWN")|.cell_id]}
       else {state:"CLOSED",reason:$cell.closed_reason,next_operation:"NONE",unknown_class:null,blocked_by:[]}
       end) as $decision |
      ($decision + {cell_id:$cell.id}) as $indexed |
      .cells += [$cell + $decision + {activity_occurrences:$resolution.activity_occurrences,core_resolution:{decision:$resolution.core_decision,state:$resolution.state,stage:$resolution.stage,step:$resolution.step,reason:$resolution.reason,next_operation:$resolution.next_operation,unknown_class:$resolution.unknown_class}}] |
      .decisions[$cell.id]=$indexed
    )) as $evaluation |
  ([$evaluation.cells[]|select(.state=="CLOSED")]|length) as $closed |
  ([$evaluation.cells[]|select(.state=="UNKNOWN")]|length) as $unknown |
  ([$evaluation.cells[]|select(.state=="REFUTED")]|length) as $refuted |
  ([$evaluation.cells[]|select(.unknown_class=="DIRECT_MISSING")]|length) as $direct_missing |
  ([$evaluation.cells[]|select(.unknown_class=="DEPENDENCY_BLOCKED")]|length) as $dependency_blocked |
  ([$evaluation.cells[].core_resolution|select(.state=="CLOSED")]|length) as $core_closed |
  ([$evaluation.cells[].core_resolution|select(.state=="UNKNOWN")]|length) as $core_unknown |
  ([$evaluation.cells[].core_resolution|select(.state=="REFUTED")]|length) as $core_refuted |
  ($core.receipts|length) as $core_observed |
  ([$core.receipts[].selector.name?]|unique|length) as $core_unique |
  ($lockset.selection_rule.required_core_resolution_receipts) as $core_required |
  ($core.core_release==$lockset.core_release and $core_observed==$core_required and $core_unique==$core_required and $core_closed==$core_required and $core_unknown==0 and $core_refuted==0) as $core_adopted |
  ([$evaluation.cells[]|select(.state!="CLOSED")][0] // null) as $first_nonclosed |
  {
    schema:"gooo/link/core-improvement-selection/v2",
    decision:(if $refuted>0 then "FAIL_CLOSED" elif $unknown>0 then "INCOMPLETE" else "CORE_RELEASE_ADOPTED" end),
    scenario:$scenario,
    subject:{sha:$subject_sha,graph_hash:$g.graph_hash,source_digest:$g.source_digest},
    authority:{consumer_releases:"PINNED_IMMUTABLE_RELEASE_ASSETS",core_release:"PINNED_IMMUTABLE_RELEASE_ASSET",selection_policy:$lockset.selection_rule,
      domain_dependency_propagation:"NOT_SELECTED_FOR_CORE",implementation_claim:(if $core_adopted then "RELEASED_AND_CONSUMED" elif $core_refuted>0 then "CORE_RELEASE_ADOPTION_REFUTED" else "CORE_RELEASE_ADOPTION_INCOMPLETE" end)},
    summary:{total:12,closed:$closed,unknown:$unknown,refuted:$refuted,direct_missing:$direct_missing,dependency_blocked:$dependency_blocked,consumers:2},
    comparison:{
      common:{complete_cells:[$la.complete.closed?,$da.complete.closed?],promoted_patterns:[$la.complete.promoted_patterns?,$da.complete.promoted_patterns?],generated_files:[$la.complete.generated_files?,$da.complete.generated_files?],direct_missing:[$la.missing.direct_missing?,$da.missing.direct_missing?],repository_writes:[$la.repository_writes?,$da.repository_writes?]},
      variation:{missing_closed:[$la.missing.closed?,$da.missing.closed?],dependency_blocked:[$la.missing.dependency_blocked?,$da.missing.dependency_blocked?],duplicate_closed:[$la.duplicate.closed?,$da.duplicate.closed?],duplicate_refuted:[$la.duplicate.refuted?,$da.duplicate.refuted?],core_lock_structures:["flat","nested"],project_graph_hashes:[$lr.subject.project_graph_hash?,$dr.subject.project_graph_hash?]}
    },
    core_adoption:{release:$core.core_release,identity_verified:($core.core_release==$lockset.core_release),summary:{required:$core_required,observed:$core_observed,unique_activity_selectors:$core_unique,closed:$core_closed,unknown:$core_unknown,refuted:$core_refuted}},
    candidate:{id:$lockset.selection_rule.candidate_id,
      state:(if $core_refuted>0 or ($core.core_release!=$lockset.core_release) then "REFUTED" elif $core_adopted then "ADOPTED_FROM_CORE_RELEASE" else "UNKNOWN" end),
      primitive:"ACTIVITY_CARDINALITY_RESOLUTION",expected_occurrence_states:{zero:"UNKNOWN_DIRECT_MISSING",one:"CLOSED",many:"REFUTED_AMBIGUOUS_ACTIVITY_BINDING"},implementation_status:(if $core_adopted then "RELEASED_AND_CONSUMED" elif $core_refuted>0 then "CORE_RELEASE_ADOPTION_REFUTED" else "CORE_RELEASE_ADOPTION_INCOMPLETE" end)},
    proofs:[$d.proof_totals[] as $proof|{choice:$proof.proof_choice,closed:([$evaluation.cells[]|select(.proof_choice==$proof.proof_choice and .state=="CLOSED")]|length),total:$proof.total}],
    cells:$evaluation.cells,
    claim:(if $first_nonclosed!=null then {state:$first_nonclosed.state,stage:$first_nonclosed.stage,step:$first_nonclosed.step,reason:$first_nonclosed.reason,next_operation:$first_nonclosed.next_operation,unknown_class:$first_nonclosed.unknown_class,blocked_by:$first_nonclosed.blocked_by}
      else {state:"CLOSED",stage:"ADOPTION",step:"ADOPT_RELEASED_ACTIVITY_CARDINALITY_PRIMITIVE",reason:"ACTIVITY_CARDINALITY_CORE_RELEASE_ADOPTED",next_operation:"RERUN_CONSUMER_ADOPTIONS",unknown_class:null,blocked_by:[]} end)
  }
' > "$output"
