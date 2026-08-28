#!/usr/bin/env bash
set -euo pipefail

if test "$#" -ne 7; then
  echo "usage: evaluate-implementation-role-queue.sh ROOT CORE_OBSERVATION PR_SNAPSHOT RUNTIME OUTPUT SUBJECT_SHA SCENARIO" >&2
  exit 64
fi

root=$1
core_observation=$2
pr_snapshot=$3
runtime=$4
output=$5
subject_sha=$6
scenario=$7
denominator="$root/contracts/implementation-role-queue-denominator-v2.json"
policy="$root/contracts/implementation-role-queue-policy-v2.json"

jq -S -n \
  --slurpfile denominator "$denominator" \
  --slurpfile policy "$policy" \
  --slurpfile core "$core_observation" \
  --slurpfile snapshot "$pr_snapshot" \
  --slurpfile runtime "$runtime" \
  --arg subject_sha "$subject_sha" \
  --arg scenario "$scenario" '
  $denominator[0] as $d |
  $policy[0] as $p |
  $core[0] as $c |
  $snapshot[0] as $s |
  $runtime[0] as $r |
  $p.classification.research_head_ref_prefix as $research_prefix |
  $p.classification.implementation_head_ref_prefix as $implementation_prefix |
  ($s.pull_requests // []) as $prs |
  def expected_role($pr):
    if $pr.base_ref == $p.classification.base_ref and ($pr.head_ref | startswith($implementation_prefix)) then "IMPLEMENTATION"
    elif $pr.base_ref == $p.classification.base_ref and ($pr.head_ref | startswith($research_prefix)) then "RESEARCH"
    else "OTHER"
    end;
  def closed($cell): $cell + {resolution:{state:"CLOSED",resolution:"EXACT",reason:"FACT_OBSERVED",unknown_class:null,refutation_class:null,next_operation:"NONE",blocked_by:[]}};
  def unknown_direct($cell): $cell + {resolution:{state:"UNKNOWN",resolution:"LOWERED",reason:$p.missing_snapshot.reason,unknown_class:$p.missing_snapshot.unknown_class,refutation_class:null,next_operation:$p.missing_snapshot.next_operation,blocked_by:[]}};
  def unknown_dependency($cell): $cell + {resolution:{state:"UNKNOWN",resolution:"LOWERED",reason:"CORE_PR_SNAPSHOT_DEPENDENCY_UNKNOWN",unknown_class:"DEPENDENCY_BLOCKED",refutation_class:null,next_operation:$p.missing_snapshot.next_operation,blocked_by:["CORE_PR_SNAPSHOT"]}};
  def refuted_direct($cell;$reason;$next): $cell + {resolution:{state:"REFUTED",resolution:"EXACT",reason:$reason,unknown_class:null,refutation_class:"DIRECT_CONTRADICTION",next_operation:$next,blocked_by:[]}};
  def refuted_dependency($cell;$reason;$blocked;$next): $cell + {resolution:{state:"REFUTED",resolution:"EXACT",reason:$reason,unknown_class:null,refutation_class:"DEPENDENCY_REFUTATION",next_operation:$next,blocked_by:[$blocked]}};
  ($c.schema == "gooo/link/implementation-role-queue-core-resolution/v2" and
   $c.summary.expected == 12 and $c.summary.observed == 12 and $c.summary.closed == 12 and
   ($c.receipts | length) == 12 and
   all($c.receipts[]; .decision == "CLOSED" and .claim.state == "CLOSED" and .occurrences == 1)) as $core_valid |
  ($p.schema == "gooo/link/implementation-role-queue-policy/v2" and
   $p.target_repository == "kimjooyoon/meta-ontology-go" and
   $research_prefix != $implementation_prefix and
   (($research_prefix | startswith($implementation_prefix)) | not) and
   (($implementation_prefix | startswith($research_prefix)) | not) and
   $p.limits.open_implementation_pull_requests == 1 and
   $p.authority.title_grants_implementation_authority == false and
   $p.authority.research_branch_grants_implementation_authority == false and
   $p.authority.automatic_merge_allowed == false and
   $p.authority.cross_project_required_gates == 0) as $policy_valid |
  ($s.complete == true and $s.schema == "gooo/link/core-pr-role-snapshot/v2" and
   $s.target_repository == $p.target_repository and
   ($s.snapshot_sha256 | type) == "string" and ($s.snapshot_sha256 | length) == 64 and
   ($prs | type) == "array") as $snapshot_complete |
  ($snapshot_complete and all($prs[];
    (.number | type) == "number" and (.head_ref | type) == "string" and
    (.base_ref | type) == "string" and (.role | type) == "string" and
    .role == expected_role(.) and
    (if .role == "IMPLEMENTATION" then
       (.candidate_id | type) == "string" and (.candidate_id | length) > 0
     else .candidate_id == null end) and
    (.title_only_implementation_authority | type) == "boolean")) as $classification_valid |
  ([$prs[] | select(.role == "RESEARCH")] | length) as $research_count |
  ([$prs[] | select(.role == "IMPLEMENTATION")] | length) as $implementation_count |
  ([$prs[] | select(.role == "OTHER")] | length) as $other_count |
  (($prs | length) == ($research_count + $implementation_count + $other_count)) as $partition_valid |
  (any($prs[]; .role != "IMPLEMENTATION" and .title_only_implementation_authority == true)) as $title_authority_escalation |
  (if ($core_valid | not) then "invalid-core-decision"
   elif ($snapshot_complete | not) then "missing-pr-snapshot"
   elif $implementation_count > 1 then "duplicate-implementation-prs"
   elif $title_authority_escalation then "title-only-promotion"
   else "live" end) as $detected_scenario |
  if $scenario != $detected_scenario then error("scenario does not match observed evidence") else . end |
  [$d.cells[] as $cell |
    if ($core_valid | not) and $cell.id == "RELEASED_GOOO_IDENTITY" then refuted_direct($cell;"UNRECOGNIZED_CORE_ACTIVITY_RESOLUTION_DECISION";"RESTORE_CORE_ACTIVITY_RESOLUTION_RECEIPTS")
    elif ($core_valid | not) then refuted_dependency($cell;"CORE_ACTIVITY_RESOLUTION_DEPENDENCY_REFUTED";"RELEASED_GOOO_IDENTITY";"RESTORE_CORE_ACTIVITY_RESOLUTION_RECEIPTS")
    elif $cell.id == "RELEASED_GOOO_IDENTITY" then closed($cell)
    elif ($policy_valid | not) and $cell.id == "ROLE_POLICY_IDENTITY" then refuted_direct($cell;"IMPLEMENTATION_ROLE_POLICY_INVALID";"RESTORE_IMPLEMENTATION_ROLE_POLICY")
    elif ($policy_valid | not) then refuted_dependency($cell;"IMPLEMENTATION_ROLE_POLICY_DEPENDENCY_REFUTED";"ROLE_POLICY_IDENTITY";"RESTORE_IMPLEMENTATION_ROLE_POLICY")
    elif $cell.id == "ROLE_POLICY_IDENTITY" then closed($cell)
    elif ($snapshot_complete | not) and $cell.id == "CORE_PR_SNAPSHOT" then unknown_direct($cell)
    elif ($snapshot_complete | not) and $cell.id == "MISSING_SNAPSHOT_PRESERVATION" then closed($cell)
    elif ($snapshot_complete | not) then unknown_dependency($cell)
    elif ($classification_valid | not) and $cell.id == "RESEARCH_CLASSIFICATION" then refuted_direct($cell;"PULL_REQUEST_ROLE_CLASSIFICATION_INVALID";"RESTORE_PREFIX_DERIVED_ROLE_CLASSIFICATION")
    elif ($classification_valid | not) and ($cell.ordinal >= 5) then refuted_dependency($cell;"ROLE_CLASSIFICATION_DEPENDENCY_REFUTED";"RESEARCH_CLASSIFICATION";"RESTORE_PREFIX_DERIVED_ROLE_CLASSIFICATION")
    elif ($partition_valid | not) and $cell.id == "ROLE_PARTITION" then refuted_direct($cell;"OPEN_PULL_REQUEST_PARTITION_INCOMPLETE";"RESTORE_COMPLETE_ROLE_PARTITION")
    elif ($partition_valid | not) and ($cell.ordinal >= 7) then refuted_dependency($cell;"ROLE_PARTITION_DEPENDENCY_REFUTED";"ROLE_PARTITION";"RESTORE_COMPLETE_ROLE_PARTITION")
    elif $implementation_count > 1 and $cell.id == "SINGLE_IMPLEMENTATION_LIMIT" then refuted_direct($cell;"EXPLICIT_IMPLEMENTATION_PR_LIMIT_EXCEEDED";"REDUCE_EXPLICIT_IMPLEMENTATION_PRS")
    elif $implementation_count > 1 and $cell.id == "NEXT_OPERATION_SELECTION" then refuted_dependency($cell;"NEXT_OPERATION_DEPENDS_ON_SINGLE_IMPLEMENTATION_LIMIT";"SINGLE_IMPLEMENTATION_LIMIT";"REDUCE_EXPLICIT_IMPLEMENTATION_PRS")
    elif $title_authority_escalation and $cell.id == "TITLE_AUTHORITY_REFUSAL" then refuted_direct($cell;"TITLE_ONLY_IMPLEMENTATION_AUTHORITY_ESCALATED";"REMOVE_TITLE_ONLY_IMPLEMENTATION_AUTHORITY")
    elif $title_authority_escalation and $cell.id == "NEXT_OPERATION_SELECTION" then refuted_dependency($cell;"NEXT_OPERATION_DEPENDS_ON_TITLE_AUTHORITY_REFUSAL";"TITLE_AUTHORITY_REFUSAL";"REMOVE_TITLE_ONLY_IMPLEMENTATION_AUTHORITY")
    else closed($cell)
    end] as $cells |
  ([$cells[] | select(.resolution.state == "CLOSED")] | length) as $closed_count |
  ([$cells[] | select(.resolution.state == "UNKNOWN")] | length) as $unknown_count |
  ([$cells[] | select(.resolution.state == "REFUTED")] | length) as $refuted_count |
  ([$cells[] | select(.resolution.unknown_class == "DIRECT_MISSING")] | length) as $direct_missing |
  ([$cells[] | select(.resolution.unknown_class == "DEPENDENCY_BLOCKED")] | length) as $dependency_blocked |
  (if $refuted_count > 0 then
     {state:"REFUTED",cause:([$cells[] | select(.resolution.refutation_class == "DIRECT_CONTRADICTION")][0].resolution)}
   elif $unknown_count > 0 then
     {state:"UNKNOWN",cause:([$cells[] | select(.resolution.unknown_class == "DIRECT_MISSING")][0].resolution)}
   else {state:"CLOSED"} end) as $resolution |
  (if $refuted_count > 0 then
     (if $implementation_count > 1 then "REDUCE_EXPLICIT_IMPLEMENTATION_PRS"
      elif $title_authority_escalation then "REMOVE_TITLE_ONLY_IMPLEMENTATION_AUTHORITY"
      else "RESTORE_ROLE_QUEUE_EVIDENCE" end)
   elif $unknown_count > 0 then $p.missing_snapshot.next_operation
   elif $implementation_count == 0 then "SELECT_MAPPED_RESEARCH_EXPERIMENT"
   else "MERGE_OR_CLOSE_SELECTED_IMPLEMENTATION_PR" end) as $next_operation |
  (if $refuted_count > 0 then "REFUTED"
   elif $unknown_count > 0 then "UNKNOWN"
   elif $implementation_count == 0 then "CLEAR"
   else "ACTIVE" end) as $queue_state |
  {
    schema:"gooo/link/implementation-role-queue-observation/v2",
    subject_sha:$subject_sha,
    scenario:$scenario,
    decision:(if $refuted_count > 0 then "FAIL_CLOSED" elif $unknown_count > 0 then "INCOMPLETE" elif $implementation_count == 0 then "QUEUE_CLEAR" else "QUEUE_ACTIVE" end),
    resolution:$resolution,
    queue:{state:$queue_state,next_operation:$next_operation,target_repository:$p.target_repository,maximum_open_implementation_pull_requests:$p.limits.open_implementation_pull_requests},
    summary:{
      cells_total:12,
      cells_closed:$closed_count,
      cells_unknown:$unknown_count,
      cells_refuted:$refuted_count,
      direct_missing:$direct_missing,
      dependency_blocked:$dependency_blocked,
      all_open_pull_requests:($prs|length),
      research_pull_requests:$research_count,
      implementation_pull_requests:$implementation_count,
      other_pull_requests:$other_count,
      partitioned_pull_requests:($research_count+$implementation_count+$other_count),
      partition_delta:(($prs|length)-($research_count+$implementation_count+$other_count)),
      automatic_merge_allowed:false,
      repository_writes:$r.repository.writes,
      local_tests:$r.local_tests_run,
      cross_project_required_gates:$p.authority.cross_project_required_gates
    },
    proof_classes:[$d.proof_totals[] as $proof | {class:$proof.proof_choice,total:$proof.total,closed:([$cells[]|select(.proof_choice==$proof.proof_choice and .resolution.state=="CLOSED")]|length)}],
    indicator_classes:[$d.indicator_totals[] as $indicator | {class:$indicator.indicator_class,total:$indicator.total,closed:([$cells[]|select(.indicator_class==$indicator.indicator_class and .resolution.state=="CLOSED")]|length)}],
    indicators:[
      {id:"gooo.metric.role-queue.research-prs.v2",value:$research_count,unit:"pull_requests",activity:"CountResearchPullRequests"},
      {id:"gooo.metric.role-queue.implementation-prs.v2",value:$implementation_count,total:1,unit:"pull_requests",activity:"CountExplicitImplementationPullRequests"},
      {id:"gooo.metric.role-queue.other-prs.v2",value:$other_count,unit:"pull_requests",activity:"PartitionOpenPullRequests"},
      {id:"gooo.metric.role-queue.partition-delta.v2",value:(($prs|length)-($research_count+$implementation_count+$other_count)),total:0,unit:"pull_requests",activity:"PartitionOpenPullRequests"},
      {id:"gooo.metric.role-queue.meta-cells.v2",value:$closed_count,total:12,unit:"cells",activity:"SelectNextImplementationOperation"},
      {id:"gooo.metric.role-queue.peak-rss.v2",value:$r.observer.peak_rss_kib,unit:"KiB",activity:"ObserveCorePullRequestSnapshot"},
      {id:"gooo.metric.role-queue.wall-time.v2",value:$r.observer.wall_ms,unit:"ms",activity:"ObserveCorePullRequestSnapshot"}
    ],
    receipt:{observed_at:($s.observed_at//null),snapshot_sha256:($s.snapshot_sha256//null),target_repository:$p.target_repository,research_pull_requests:$research_count,implementation_pull_requests:$implementation_count,other_pull_requests:$other_count,next_operation:$next_operation},
    cells:$cells,
    runtime:$r
  }
' > "$output"
