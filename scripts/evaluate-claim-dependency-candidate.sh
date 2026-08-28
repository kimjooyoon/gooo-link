#!/usr/bin/env bash
set -euo pipefail

if test "$#" -ne 9; then
  echo "usage: evaluate-claim-dependency-candidate.sh ROOT META_OBSERVATION QUEUE_REPORT CONSUMER_OBSERVATION RESEARCH_OBSERVATION RUNTIME OUTPUT SUBJECT_SHA SCENARIO" >&2
  exit 64
fi

root=$1
meta_observation=$2
queue_report=$3
consumer_observation=$4
research_observation=$5
runtime=$6
output=$7
subject_sha=$8
scenario=$9
denominator="$root/contracts/claim-dependency-candidate-denominator-v1.json"

jq -S -n \
  --slurpfile denominator "$denominator" \
  --slurpfile meta "$meta_observation" \
  --slurpfile queue "$queue_report" \
  --slurpfile consumer "$consumer_observation" \
  --slurpfile research "$research_observation" \
  --slurpfile runtime "$runtime" \
  --arg subject_sha "$subject_sha" \
  --arg scenario "$scenario" '
  $denominator[0] as $d |
  $meta[0] as $m |
  $queue[0] as $q |
  $consumer[0] as $c |
  $research[0] as $r |
  $runtime[0] as $rt |
  def closed($cell): $cell + {resolution:{state:"CLOSED",reason:"FACT_OBSERVED",unknown_class:null,refutation_class:null,next_operation:"NONE",blocked_by:[]}};
  def unknown_direct($cell): $cell + {resolution:{state:"UNKNOWN",reason:"DESIGN_USER_PATH_UNKNOWN_EVIDENCE_UNAVAILABLE",unknown_class:"DIRECT_MISSING",refutation_class:null,next_operation:"RESTORE_DESIGN_USER_PATH_UNKNOWN_EVIDENCE",blocked_by:[]}};
  def unknown_dependency($cell): $cell + {resolution:{state:"UNKNOWN",reason:"DESIGN_USER_PATH_EVIDENCE_DEPENDENCY_UNKNOWN",unknown_class:"DEPENDENCY_BLOCKED",refutation_class:null,next_operation:"RESTORE_DESIGN_USER_PATH_UNKNOWN_EVIDENCE",blocked_by:["DESIGN_USER_PATH_RELEASE"]}};
  def refuted_direct($cell;$reason;$next): $cell + {resolution:{state:"REFUTED",reason:$reason,unknown_class:null,refutation_class:"DIRECT_CONTRADICTION",next_operation:$next,blocked_by:[]}};
  def refuted_dependency($cell;$reason;$blocked;$next): $cell + {resolution:{state:"REFUTED",reason:$reason,unknown_class:null,refutation_class:"DEPENDENCY_REFUTATION",next_operation:$next,blocked_by:[$blocked]}};
  ($m.schema=="gooo/link/claim-dependency-selection-meta-observation/v1" and $m.summary.expected==12 and $m.summary.observed==12 and $m.summary.closed==12 and ($m.receipts|length)==12 and all($m.receipts[];.decision=="CLOSED" and .claim.state=="CLOSED" and .occurrences==1)) as $meta_valid |
  ($q.schema=="gooo/link/implementation-role-queue-observation/v2" and $q.resolution.state=="CLOSED" and $q.summary.cells_closed==12 and $q.summary.all_open_pull_requests==34 and $q.summary.research_pull_requests==29 and $q.summary.implementation_pull_requests==0 and $q.summary.other_pull_requests==5 and $q.summary.partition_delta==0 and $q.summary.automatic_merge_allowed==false) as $queue_clear |
  ($c.complete==true and $c.domains_observed==3 and $c.direct_missing_roots==3 and $c.dependency_blocked_claims==14 and $c.recovery_operations==14 and $c.explicit_causal_predecessors==10 and $c.causal_predecessor_gap==4) as $consumer_exact |
  ($r.commit_valid==true and $r.source_valid==true and $r.document_valid==true and $r.activities==6 and $r.graph_edges==0 and $r.recoverable_roots==1 and $r.typed_edge_programs==5 and $r.requires_programs==2 and $r.supports_programs==1 and $r.contradicts_programs==1 and $r.failure_entailment_programs==1) as $research_exact |
  (if ($meta_valid|not) then "invalid-core-decision"
   elif $c.complete!=true then "missing-design-evidence"
   elif $c.causal_predecessor_gap!=4 or $c.explicit_causal_predecessors!=10 then "causal-gap-laundering"
   elif $r.source_valid!=true or ($research_exact|not) then "research-source-drift"
   elif $r.mapping_authority!="PINNED_GOOO_SOURCE" then "title-only-promotion"
   elif ($queue_clear|not) then "active-implementation-queue"
   else "live" end) as $detected |
  if $scenario!=$detected then error("scenario does not match candidate evidence") else . end |
  [$d.cells[] as $cell |
    if ($meta_valid|not) and $cell.id=="ROLE_QUEUE_RELEASE" then refuted_direct($cell;"UNRECOGNIZED_CORE_ACTIVITY_RESOLUTION_DECISION";"RESTORE_SELECTION_META_RECEIPTS")
    elif ($meta_valid|not) then refuted_dependency($cell;"SELECTION_META_RECEIPT_DEPENDENCY_REFUTED";"ROLE_QUEUE_RELEASE";"RESTORE_SELECTION_META_RECEIPTS")
    elif $c.complete!=true and $cell.id=="DESIGN_USER_PATH_RELEASE" then unknown_direct($cell)
    elif $c.complete!=true and (["DIRECT_MISSING_ROOTS","DEPENDENCY_BLOCKED_CLAIMS","RECOVERY_AND_PREDECESSOR_BINDING","CAUSAL_PREDECESSOR_GAP","EXPLICIT_IMPLEMENTATION_OPERATION"]|index($cell.id))!=null then unknown_dependency($cell)
    elif ($consumer_exact|not) and $cell.id=="CAUSAL_PREDECESSOR_GAP" then refuted_direct($cell;"CAUSAL_PREDECESSOR_GAP_LAUNDERED";"RESTORE_OBSERVED_PREDECESSOR_GAP_4_OF_14")
    elif ($consumer_exact|not) and $cell.id=="EXPLICIT_IMPLEMENTATION_OPERATION" then refuted_dependency($cell;"IMPLEMENTATION_SELECTION_DEPENDS_ON_PRESERVED_CAUSAL_GAP";"CAUSAL_PREDECESSOR_GAP";"RESTORE_OBSERVED_PREDECESSOR_GAP_4_OF_14")
    elif ($research_exact|not) and $cell.id=="CANDIDATE_GOOO_TOPOLOGY" then refuted_direct($cell;"PINNED_RESEARCH_GOOO_TOPOLOGY_MISMATCH";"RESTORE_PINNED_RESEARCH_SOURCE")
    elif ($research_exact|not) and $cell.id=="EXPLICIT_IMPLEMENTATION_OPERATION" then refuted_dependency($cell;"IMPLEMENTATION_SELECTION_DEPENDS_ON_RESEARCH_TOPOLOGY";"CANDIDATE_GOOO_TOPOLOGY";"RESTORE_PINNED_RESEARCH_SOURCE")
    elif $r.mapping_authority!="PINNED_GOOO_SOURCE" and $cell.id=="SELECTION_AUTHORITY" then refuted_direct($cell;"TITLE_ONLY_CANDIDATE_AUTHORITY_REFUSED";"BIND_PINNED_GOOO_SOURCE")
    elif $r.mapping_authority!="PINNED_GOOO_SOURCE" and $cell.id=="EXPLICIT_IMPLEMENTATION_OPERATION" then refuted_dependency($cell;"IMPLEMENTATION_SELECTION_DEPENDS_ON_SOURCE_AUTHORITY";"SELECTION_AUTHORITY";"BIND_PINNED_GOOO_SOURCE")
    elif ($queue_clear|not) and $cell.id=="SELECTION_AUTHORITY" then refuted_direct($cell;"EXPLICIT_IMPLEMENTATION_QUEUE_NOT_CLEAR";"MERGE_OR_CLOSE_SELECTED_IMPLEMENTATION_PR")
    elif ($queue_clear|not) and $cell.id=="EXPLICIT_IMPLEMENTATION_OPERATION" then refuted_dependency($cell;"IMPLEMENTATION_SELECTION_DEPENDS_ON_CLEAR_QUEUE";"SELECTION_AUTHORITY";"MERGE_OR_CLOSE_SELECTED_IMPLEMENTATION_PR")
    else closed($cell)
    end] as $cells |
  ([$cells[]|select(.resolution.state=="CLOSED")]|length) as $closed_count |
  ([$cells[]|select(.resolution.state=="UNKNOWN")]|length) as $unknown_count |
  ([$cells[]|select(.resolution.state=="REFUTED")]|length) as $refuted_count |
  (if $refuted_count>0 then {state:"REFUTED",cause:([$cells[]|select(.resolution.refutation_class=="DIRECT_CONTRADICTION")][0].resolution)} elif $unknown_count>0 then {state:"UNKNOWN",cause:([$cells[]|select(.resolution.unknown_class=="DIRECT_MISSING")][0].resolution)} else {state:"CLOSED"} end) as $resolution |
  {
    schema:"gooo/link/claim-dependency-candidate-selection/v1",
    subject_sha:$subject_sha,
    scenario:$scenario,
    decision:(if $refuted_count>0 then "FAIL_CLOSED" elif $unknown_count>0 then "INCOMPLETE" else "CANDIDATE_SELECTED" end),
    resolution:$resolution,
    candidate:{id:$d.candidate_id,research_pull_request:566,research_commit:$r.commit_sha,mapping_authority:$r.mapping_authority,implementation_state:"NOT_STARTED",automatic_merge_allowed:false,next_operation:(if $closed_count==12 then "OPEN_EXPLICIT_IMPLEMENTATION_PR" else $resolution.cause.next_operation end),implementation_branch:"agent/implementation-claim-dependency-causality-v1"},
    summary:{cells_total:12,cells_closed:$closed_count,cells_unknown:$unknown_count,cells_refuted:$refuted_count,consumer_domains:($c.domains_observed//0),direct_missing_roots:($c.direct_missing_roots//0),dependency_blocked_claims:($c.dependency_blocked_claims//0),recovery_operations:($c.recovery_operations//0),explicit_causal_predecessors:($c.explicit_causal_predecessors//0),causal_predecessor_gap:($c.causal_predecessor_gap//0),research_experiments:29,direct_candidate_mappings:(if $closed_count==12 then 1 else 0 end),primitive_mappings:5,primitive_denominator:30,primitive_increment:0,explicit_implementation_pull_requests:$q.summary.implementation_pull_requests,maximum_explicit_implementation_pull_requests:1,repository_writes:$rt.repository.writes,local_tests:$rt.local_tests_run,cross_project_required_gates:0},
    proof_classes:[$d.proof_totals[] as $proof|{class:$proof.proof_choice,total:$proof.total,closed:([$cells[]|select(.proof_choice==$proof.proof_choice and .resolution.state=="CLOSED")]|length)}],
    indicator_classes:[$d.indicator_totals[] as $indicator|{class:$indicator.indicator_class,total:$indicator.total,closed:([$cells[]|select(.indicator_class==$indicator.indicator_class and .resolution.state=="CLOSED")]|length)}],
    indicators:[
      {id:"gooo.metric.candidate.direct-missing-roots.v1",value:($c.direct_missing_roots//0),total:3,unit:"claims",activity:"CountDirectMissingRoots"},
      {id:"gooo.metric.candidate.dependency-blocked.v1",value:($c.dependency_blocked_claims//0),total:14,unit:"claims",activity:"CountDependencyBlockedClaims"},
      {id:"gooo.metric.candidate.explicit-predecessors.v1",value:($c.explicit_causal_predecessors//0),total:14,unit:"claims",activity:"BindRecoveryAndCausalPredecessors"},
      {id:"gooo.metric.candidate.predecessor-gap.v1",value:($c.causal_predecessor_gap//0),total:14,unit:"claims",activity:"PreserveCausalPredecessorGap"},
      {id:"gooo.metric.candidate.mapping.v1",value:(if $closed_count==12 then 1 else 0 end),total:29,unit:"research_experiments",activity:"SelectExplicitImplementationOperation"},
      {id:"gooo.metric.candidate.peak-rss.v1",value:$rt.observer.peak_rss_kib,unit:"KiB",activity:"ObserveClaimDependencyResearchCommit"},
      {id:"gooo.metric.candidate.wall-time.v1",value:$rt.observer.wall_ms,unit:"ms",activity:"ObserveClaimDependencyResearchCommit"}
    ],
    cells:$cells,
    runtime:$rt
  }
' > "$output"
