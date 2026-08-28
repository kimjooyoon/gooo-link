#!/usr/bin/env bash
set -euo pipefail
if test "$#" -ne 8; then
  echo "usage: evaluate-implementation-queue.sh ROOT CORE_OBSERVATION PR_SNAPSHOT RUNTIME OUTPUT SUBJECT_SHA PUBLIC_STATE SCENARIO" >&2
  exit 64
fi

root=$1
core_observation=$2
pr_snapshot=$3
runtime=$4
output=$5
subject_sha=$6
public_state=$7
scenario=$8
denominator="$root/contracts/implementation-queue-denominator-v1.json"
policy="$root/contracts/implementation-queue-policy-v1.json"
core_lock="$root/contracts/core-activity-cardinality-release-lock-v1.json"

jq -S -n \
  --slurpfile denominator "$denominator" \
  --slurpfile policy "$policy" \
  --slurpfile core_lock "$core_lock" \
  --slurpfile core "$core_observation" \
  --slurpfile snapshot "$pr_snapshot" \
  --slurpfile runtime "$runtime" \
  --arg subject_sha "$subject_sha" \
  --arg public_state "$public_state" \
  --arg active_candidate_id "${ACTIVE_CANDIDATE_ID:-}" \
  --arg scenario "$scenario" '
  $denominator[0] as $d |
  $policy[0] as $p |
  $core_lock[0] as $lock |
  $core[0] as $c |
  $snapshot[0] as $s |
  $runtime[0] as $r |
  (if ($active_candidate_id|length)>0 then $active_candidate_id else $p.candidate_id end) as $candidate_id |
  def strip: del(.closed_reason,.unknown_reason,.refuted_reason,.restore_operation);
  def closed_fact: {state:"CLOSED",reason:"FACT_OBSERVED",next_operation:"NONE",unknown_class:null,resolution:"EXACT",blocked_by:[]};
  def unknown_fact($reason;$next;$class): {state:"UNKNOWN",reason:$reason,next_operation:$next,unknown_class:$class,resolution:"PREREQUISITE_CLASS",blocked_by:[]};
  def refuted_fact($reason;$next): {state:"REFUTED",reason:$reason,next_operation:$next,unknown_class:null,resolution:"EXACT",blocked_by:[]};
  def expected_core: {
    repository:$lock.repository,
    tag:$lock.tag,
    tag_object_sha:$lock.tag_object_sha,
    target_commit_sha:$lock.target_commit_sha,
    binary_asset:$lock.consumer.binary_asset,
    binary_sha256:($lock.assets[]|select(.name==$lock.consumer.binary_asset)|.digest|sub("^sha256:";"")),
    resolution_schema:$lock.schemas.activity_cardinality_resolution
  };
  def core_resolution($cell):
    if $c.core_release!=expected_core then
      refuted_fact("CORE_RELEASE_IDENTITY_MISMATCH";"RESTORE_PINNED_GOOO_RELEASE")+{stage:"CORE_RELEASE",step:"BIND_CORE_RELEASE_IDENTITY"}
    else ([$c.receipts[]?|select(.selector.name?==$cell.activity)]) as $receipts |
      if ($receipts|length)==0 then
        unknown_fact("CORE_ACTIVITY_RESOLUTION_RECEIPT_UNAVAILABLE";"PROVIDE_CORE_ACTIVITY_RESOLUTION_RECEIPT";"DIRECT_MISSING")+{stage:"RESOLUTION",step:"RESOLVE_ACTIVITY_CARDINALITY"}
      elif ($receipts|length)>1 then
        refuted_fact("DUPLICATE_CORE_ACTIVITY_RESOLUTION_RECEIPT";"REMOVE_DUPLICATE_CORE_ACTIVITY_RESOLUTION_RECEIPT")+{stage:"RESOLUTION",step:"RESOLVE_ACTIVITY_CARDINALITY"}
      else $receipts[0] as $receipt |
        if $receipt.schema!="gooo/activity-cardinality-resolution/v1" or $receipt.selector.name!=$cell.activity or $receipt.subject.source_file!="examples/implementation-queue/main.gooo" then
          refuted_fact("INVALID_CORE_ACTIVITY_RESOLUTION_RECEIPT";"RESTORE_CORE_ACTIVITY_RESOLUTION_RECEIPT")+{stage:"RESOLUTION",step:"RESOLVE_ACTIVITY_CARDINALITY"}
        elif $receipt.decision=="CLOSED" and $receipt.claim.state=="CLOSED" and $receipt.claim.reason=="ACTIVITY_UNIQUELY_RESOLVED" and $receipt.occurrences==1 then
          closed_fact+{stage:"RESOLUTION",step:"RESOLVE_ACTIVITY_CARDINALITY",core_decision:$receipt.decision,activity_occurrences:$receipt.occurrences}
        elif $receipt.decision=="UNKNOWN" then
          unknown_fact(($receipt.claim.reason//"CORE_ACTIVITY_RESOLUTION_UNKNOWN");($receipt.claim.next_operation//"RESOLVE_CORE_ACTIVITY");($receipt.claim.unknown_class//"DIRECT_MISSING"))+{stage:"RESOLUTION",step:"RESOLVE_ACTIVITY_CARDINALITY",core_decision:$receipt.decision,activity_occurrences:($receipt.occurrences//0)}
        else
          refuted_fact("UNRECOGNIZED_CORE_ACTIVITY_RESOLUTION_DECISION";"RESTORE_CORE_ACTIVITY_RESOLUTION_RECEIPT")+{stage:"RESOLUTION",step:"RESOLVE_ACTIVITY_CARDINALITY",core_decision:($receipt.decision//null),activity_occurrences:($receipt.occurrences//null)}
        end
      end
    end;
  ($s.complete==true and $s.schema=="gooo/link/github-pr-snapshot/v1" and ($s.pull_requests|type)=="array" and ($s.snapshot_sha256|type)=="string" and ($s.snapshot_sha256|length)==64) as $snapshot_complete |
  ($s.pull_requests//[]) as $all_prs |
  [$all_prs[]|select(.is_implementation==true)] as $implementation_prs |
  [$implementation_prs[]|select(.target_repository==$p.target_repository)] as $target_prs |
  [$target_prs[]|select(.candidate_id==$candidate_id)] as $candidate_prs |
  ($target_prs|length) as $target_count |
  ($candidate_prs|length) as $candidate_count |
  (all($all_prs[]; (.number|type)=="number" and (.target_repository|type)=="string" and (.head_ref|type)=="string" and (.base_ref|type)=="string" and (.is_implementation|type)=="boolean" and (if .is_implementation then (.candidate_id|type)=="string" and (.candidate_id|length)>0 else true end))) as $classification_valid |
  ($p.schema=="gooo/link/implementation-queue-policy/v1" and $p.target_repository=="kimjooyoon/gooo-link" and $p.limits.open_implementation_prs_per_target_repository==1 and $p.limits.open_implementation_prs_per_candidate==1 and $p.authority.cross_project_required_gates==0 and $p.authority.effect=="READ_ONLY") as $policy_valid |
  ($p.unknown_contract=={stage:"OBSERVATION",step:"OBSERVE_GITHUB_PULL_REQUEST_SNAPSHOT",reason:"GITHUB_PR_SNAPSHOT_UNAVAILABLE",unknown_class:"DIRECT_MISSING",next_operation:"REFRESH_GITHUB_PR_SNAPSHOT"}) as $unknown_contract_valid |
  ($p.refuted_contract=={stage:"CARDINALITY",step:"ENFORCE_SINGLE_IMPLEMENTATION_PULL_REQUEST",reason:"IMPLEMENTATION_PR_LIMIT_EXCEEDED",next_operation:"REDUCE_OPEN_IMPLEMENTATION_PRS"}) as $refuted_contract_valid |
  ($p.next_execution_order==[
    {ordinal:1,when:"OPEN_IMPLEMENTATION_PRS_GT_1",operation:"REDUCE_OPEN_IMPLEMENTATION_PRS"},
    {ordinal:2,when:"OPEN_IMPLEMENTATION_PRS_EQ_1",operation:"MERGE_OR_CLOSE_CURRENT_IMPLEMENTATION_PR"},
    {ordinal:3,when:"OPEN_IMPLEMENTATION_PRS_EQ_0",operation:"SELECT_NEXT_CANDIDATE"}
  ]) as $selection_valid |
  ({
    RELEASED_GOOO_IDENTITY:($c.core_release==expected_core and $c.summary.closed==12),
    QUEUE_POLICY_IDENTITY:$policy_valid,
    GITHUB_PR_SNAPSHOT:(if $snapshot_complete then true else null end),
    IMPLEMENTATION_PR_CLASSIFICATION:(if $snapshot_complete then $classification_valid else null end),
    TARGET_REPOSITORY_CARDINALITY:(if $snapshot_complete and $classification_valid then true else null end),
    CANDIDATE_CARDINALITY:(if $snapshot_complete and $classification_valid then true else null end),
    SINGLE_PR_LIMIT:(if $snapshot_complete and $classification_valid then ($target_count<=$p.limits.open_implementation_prs_per_target_repository and $candidate_count<=$p.limits.open_implementation_prs_per_candidate) else null end),
    UNKNOWN_INPUT_PRESERVATION:$unknown_contract_valid,
    DUPLICATE_PR_REFUTATION:$refuted_contract_valid,
    DETERMINISTIC_REPLAY:($r.deterministic_replay==true),
    READ_ONLY_EFFECT:($r.repository.writes==0 and $r.repository.before_digest==$r.repository.after_digest and $r.local_tests_run==0 and $p.authority.cross_project_required_gates==0),
    NEXT_EXECUTION_SELECTION:(if $snapshot_complete and $classification_valid and $target_count<=1 and $candidate_count<=1 then $selection_valid else false end)
  }) as $facts |
  def direct_fact($cell):
    ($facts[$cell.id]) as $fact |
    if $cell.id=="GITHUB_PR_SNAPSHOT" and $fact==null then
      ($cell|strip)+unknown_fact(($s.reason//$p.unknown_contract.reason);($s.next_operation//$p.unknown_contract.next_operation);($s.unknown_class//$p.unknown_contract.unknown_class))+{stage:($s.stage//$p.unknown_contract.stage),step:($s.step//$p.unknown_contract.step)}
    elif $fact==true then
      ($cell|strip)+closed_fact+{reason:$cell.closed_reason,stage:$cell.stage,step:$cell.step}
    elif $fact==null then
      ($cell|strip)+unknown_fact($cell.unknown_reason;$cell.next_operation;"DIRECT_MISSING")+{stage:$cell.stage,step:$cell.step}
    else
      ($cell|strip)+refuted_fact($cell.refuted_reason;$cell.restore_operation)+{stage:$cell.stage,step:$cell.step}
    end;
  (reduce $d.cells[] as $cell ({cells:[],decisions:{}};
    . as $acc |
    (core_resolution($cell)) as $resolution |
    (direct_fact($cell)) as $candidate |
    ([$cell.depends_on[]?|$acc.decisions[.]]) as $dependencies |
    (if $resolution.state=="REFUTED" then $resolution
     elif any($dependencies[];.state=="REFUTED") then refuted_fact("DEPENDENCY_REFUTED";"RESOLVE_REFUTED_PREDECESSORS")+{stage:$cell.stage,step:$cell.step,blocked_by:[$dependencies[]|select(.state=="REFUTED")|.cell_id]}
     elif $resolution.state=="UNKNOWN" then $resolution
     elif any($dependencies[];.state=="UNKNOWN") then unknown_fact("DEPENDENCY_UNKNOWN";"RESOLVE_UNKNOWN_PREDECESSORS";"DEPENDENCY_BLOCKED")+{stage:$cell.stage,step:$cell.step,blocked_by:[$dependencies[]|select(.state=="UNKNOWN")|.cell_id]}
     else $candidate end) as $decision |
    ($decision+{cell_id:$cell.id,core_resolution:{state:$resolution.state,decision:($resolution.core_decision//null),activity_occurrences:($resolution.activity_occurrences//null),stage:$resolution.stage,step:$resolution.step,reason:$resolution.reason,next_operation:$resolution.next_operation,unknown_class:$resolution.unknown_class}}) as $indexed |
    .cells+=[ $indexed ] | .decisions[$cell.id]=$indexed
  )) as $evaluation |
  ([$evaluation.cells[]|select(.state=="CLOSED")]|length) as $closed |
  ([$evaluation.cells[]|select(.state=="UNKNOWN")]|length) as $unknown |
  ([$evaluation.cells[]|select(.state=="REFUTED")]|length) as $refuted |
  ([$evaluation.cells[]|select(.unknown_class=="DIRECT_MISSING")]|length) as $direct_missing |
  ([$evaluation.cells[]|select(.unknown_class=="DEPENDENCY_BLOCKED")]|length) as $dependency_blocked |
  ([$evaluation.cells[]|select(.state!="CLOSED")][0]//null) as $first |
  (if $refuted>0 then "REDUCE_OPEN_IMPLEMENTATION_PRS" elif $unknown>0 then ($first.next_operation//"REFRESH_IMPLEMENTATION_QUEUE_EVIDENCE") elif $target_count==0 then "SELECT_NEXT_CANDIDATE" else "MERGE_OR_CLOSE_CURRENT_IMPLEMENTATION_PR" end) as $next_operation |
  (if $refuted>0 then "REFUTED" elif $unknown>0 then "UNKNOWN" elif $target_count==0 then "CLEAR" else "ACTIVE" end) as $queue_state |
  (if $refuted>0 then "FAIL_CLOSED" elif $unknown>0 then "INCOMPLETE" elif $target_count==0 then "QUEUE_CLEAR" else "QUEUE_CONFORMANT" end) as $decision |
  {
    schema:"gooo/link/implementation-queue-observation/v1",
    scenario:$scenario,
    subject_sha:$subject_sha,
    decision:$decision,
    claim:(if $first!=null then {state:$first.state,stage:$first.stage,step:$first.step,reason:$first.reason,next_operation:$first.next_operation,unknown_class:$first.unknown_class,blocked_by:$first.blocked_by} else {state:"CLOSED",stage:null,step:null,reason:(if $target_count==0 then "IMPLEMENTATION_QUEUE_CLEAR" else "IMPLEMENTATION_QUEUE_CONFORMANT" end),next_operation:$next_operation,unknown_class:null,blocked_by:[]} end),
    summary:{total:12,closed:$closed,unknown:$unknown,refuted:$refuted,direct_missing:$direct_missing,dependency_blocked:$dependency_blocked,all_open_pull_requests:($s.all_open_pull_requests//0),open_implementation_prs:$target_count,open_candidate_prs:$candidate_count,maximum_open_implementation_prs:$p.limits.open_implementation_prs_per_target_repository},
    queue:{state:$queue_state,next_operation:$next_operation,target_repository:$p.target_repository,candidate_id:$candidate_id},
    receipt:{observed_at:($s.observed_at//null),target_repository:$p.target_repository,candidate_id:$candidate_id,open_implementation_prs:$target_count,open_candidate_prs:$candidate_count,maximum_open_implementation_prs:$p.limits.open_implementation_prs_per_target_repository,next_operation:$next_operation,snapshot_sha256:($s.snapshot_sha256//null)},
    implementation:{state:$public_state,effect:"READ_ONLY",cross_project_required_gates:$p.authority.cross_project_required_gates},
    proofs:[$d.proof_totals[] as $proof|{choice:$proof.proof_choice,closed:([$evaluation.cells[]|select(.proof_choice==$proof.proof_choice and .state=="CLOSED")]|length),total:$proof.total}],
    indicator_classes:[$d.indicator_totals[] as $indicator|{class:$indicator.indicator_class,closed:([$evaluation.cells[]|select(.indicator_class==$indicator.indicator_class and .state=="CLOSED")]|length),total:$indicator.total}],
    indicators:[
      {id:"gooo.metric.queue.open-implementation-prs.v1",value:$target_count,total:$p.limits.open_implementation_prs_per_target_repository,unit:"pull_requests",activity:"CountTargetRepositoryImplementationPullRequests"},
      {id:"gooo.metric.queue.open-candidate-prs.v1",value:$candidate_count,total:$p.limits.open_implementation_prs_per_candidate,unit:"pull_requests",activity:"CountCandidateImplementationPullRequests"},
      {id:"gooo.metric.queue.meta-cells.v1",value:$closed,total:12,unit:"cells",activity:"SelectNextImplementationQueueOperation"},
      {id:"gooo.metric.queue.repository-writes.v1",value:$r.repository.writes,total:0,unit:"writes",activity:"PreserveQueueReadOnlyEffect"},
      {id:"gooo.metric.queue.peak-rss.v1",value:$r.observer.peak_rss_kib,unit:"KiB",activity:"ObserveGithubPullRequestSnapshot"},
      {id:"gooo.metric.queue.wall-time.v1",value:$r.observer.wall_ms,unit:"ms",activity:"ObserveGithubPullRequestSnapshot"}
    ],
    cells:$evaluation.cells,
    runtime:$r
  }
' > "$output"
