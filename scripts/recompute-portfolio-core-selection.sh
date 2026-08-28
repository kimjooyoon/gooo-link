#!/usr/bin/env bash
set -euo pipefail

if test "$#" -ne 10; then
  echo "usage: recompute-portfolio-core-selection.sh GRAPH DENOMINATOR PROMOTION CONSUMER_RELEASES QUEUE HISTORICAL BACKLOG OUTPUT SUBJECT_SHA SCENARIO" >&2
  exit 64
fi

graph=$1
denominator=$2
promotion=$3
consumer_releases=$4
queue=$5
historical=$6
backlog=$7
output=$8
subject_sha=$9
scenario=${10}

jq -S -n \
  --slurpfile graph "$graph" \
  --slurpfile denominator "$denominator" \
  --slurpfile promotion "$promotion" \
  --slurpfile consumer_releases "$consumer_releases" \
  --slurpfile queue "$queue" \
  --slurpfile historical "$historical" \
  --slurpfile backlog "$backlog" \
  --arg subject_sha "$subject_sha" \
  --arg scenario "$scenario" '
  $graph[0] as $g |
  $denominator[0] as $d |
  $promotion[0] as $p |
  $consumer_releases[0] as $r |
  $queue[0] as $q |
  $historical[0] as $h |
  $backlog[0] as $b |
  def closed_fact($reason): {state:"CLOSED",reason:$reason,unknown_class:null,next_operation:"NONE",blocked_by:[]};
  def unknown_fact($stage;$step;$reason;$next): {state:"UNKNOWN",stage:$stage,step:$step,reason:$reason,unknown_class:"DIRECT_MISSING",next_operation:$next,blocked_by:[]};
  def refuted_fact($stage;$step;$reason;$next): {state:"REFUTED",stage:$stage,step:$step,reason:$reason,unknown_class:null,next_operation:$next,blocked_by:[]};
  def activity_count($name): [$g.nodes[]?|select(.kind=="Activity" and .name==$name)]|length;
  ($p!=null and $p.schema=="gooo/link/generator-consumer-promotion-report/v1" and $p.decision=="GENERATOR_PROMOTION_ELIGIBLE" and $p.summary.closed==12 and $p.summary.total==12 and $p.observations.independent_consumers=={observed:2,total:2}) as $promotion_valid |
  ($p!=null and $p.observations.evidence_assets=={observed:10,total:10} and $p.observations.generated_cells=={observed:24,total:24} and $p.observations.verification_cells=={observed:12,total:12}) as $consumer_contract_valid |
  ($r!=null and $r.schema=="gooo/link/generator-consumer-release-observation/v1" and ([$r.releases[]|select(.role=="consumer")]|length)==2 and ([$r.releases[]|select(.role=="consumer")|.repository]|unique|length)==2) as $repetition_valid |
  ($p!=null and $p.authority.generator_scope=="DECLARATIVE_EVIDENCE_PROJECT_GENERATION" and $p.authority.executable_ci_generation=="NOT_CLAIMED" and $p.authority.cross_project_required_gates==0 and $p.authority.current_branch_inputs==0) as $boundary_valid |
  ($h!=null and $h.decision=="CORE_RELEASE_ADOPTED" and $h.claim.next_operation=="RERUN_CONSUMER_ADOPTIONS" and $promotion_valid) as $stale_operation_observed |
  ($b.primitive_candidates_observed//0) as $primitive_candidates |
  ($b.mapped_pull_requests//0) as $mapped_prs |
  ($b.merge_eligible_pull_requests//0) as $eligible_prs |
  def direct_fact($cell):
    if activity_count($cell.activity)!=1 then
      refuted_fact("META_BINDING";"RESOLVE_ACTIVITY_CARDINALITY";"META_ACTIVITY_CARDINALITY_INVALID";"RESTORE_EXACTLY_ONE_META_ACTIVITY")
    elif $cell.id=="generator-promotion-release" then
      if $p==null then unknown_fact("PORTFOLIO_RELEASE";"OBSERVE_GENERATOR_PROMOTION_RELEASE";"GENERATOR_PROMOTION_RELEASE_UNAVAILABLE";"PUBLISH_GENERATOR_PROMOTION_RELEASE")
      elif $promotion_valid then closed_fact("GENERATOR_PROMOTION_RELEASE_OBSERVED")
      else refuted_fact("PORTFOLIO_RELEASE";"VERIFY_GENERATOR_PROMOTION_REPORT";"GENERATOR_PROMOTION_REPORT_INVALID";"RESTORE_GENERATOR_PROMOTION_REPORT") end
    elif $cell.id=="external-consumer-contract" then
      if $p==null then closed_fact("EXTERNAL_CONSUMER_CONTRACT_DEFERRED_TO_RELEASE_DEPENDENCY")
      elif $consumer_contract_valid then closed_fact("EXTERNAL_CONSUMER_CONTRACT_CLOSED") else refuted_fact("PORTFOLIO_CONTRACT";"BIND_EXTERNAL_CONSUMER_EVIDENCE";"EXTERNAL_CONSUMER_CONTRACT_MISMATCH";"RESTORE_EXTERNAL_CONSUMER_CONTRACT") end
    elif $cell.id=="independent-consumer-repetition" then
      if $repetition_valid then closed_fact("TWO_INDEPENDENT_CONSUMERS_BOUND") else refuted_fact("PORTFOLIO_REPETITION";"BIND_INDEPENDENT_CONSUMERS";"INDEPENDENT_CONSUMER_REPETITION_MISMATCH";"RESTORE_INDEPENDENT_CONSUMER_EVIDENCE") end
    elif $cell.id=="portfolio-authority-boundary" then
      if $p==null then closed_fact("PORTFOLIO_BOUNDARY_DEFERRED_TO_RELEASE_DEPENDENCY")
      elif $boundary_valid then closed_fact("OPTIONAL_PORTFOLIO_BOUNDARY_PRESERVED") else refuted_fact("AUTHORITY";"PRESERVE_PORTFOLIO_AUTHORITY_BOUNDARY";"PORTFOLIO_EVIDENCE_SCOPE_ESCALATION";"RESTORE_OPTIONAL_PORTFOLIO_SCOPE") end
    elif $cell.id=="stale-adoption-operation" then
      if $p==null then closed_fact("STALE_OPERATION_DEFERRED_TO_RELEASE_DEPENDENCY")
      elif $stale_operation_observed then closed_fact("COMPLETED_ADOPTION_OPERATION_REFUTED") else refuted_fact("SELF_IMPROVEMENT_SELECTION";"REFUTE_COMPLETED_ADOPTION_OPERATION";"UNAUTHORIZED_OR_UNRECOGNIZED_NEXT_OPERATION";"RESTORE_PORTFOLIO_RECOMPUTATION") end
    elif $cell.id=="core-primitive-candidate" then
      if $primitive_candidates==0 then unknown_fact("PRIMITIVE_SELECTION";"OBSERVE_CORE_PRIMITIVE_CANDIDATE";"CORE_PRIMITIVE_EVIDENCE_UNAVAILABLE";"OBSERVE_CROSS_CONSUMER_PRIMITIVE_NEED")
      else refuted_fact("PRIMITIVE_SELECTION";"OBSERVE_CORE_PRIMITIVE_CANDIDATE";"PRIMITIVE_CANDIDATE_WITHOUT_CROSS_CONSUMER_EVIDENCE";"REMOVE_UNSUPPORTED_PRIMITIVE_CANDIDATE") end
    elif $cell.id=="experiment-pr-mapping" then
      if $mapped_prs==0 then unknown_fact("PULL_REQUEST_MAPPING";"BIND_EXPERIMENT_PULL_REQUEST_MAPPING";"EXPERIMENT_PULL_REQUEST_MAPPING_UNAVAILABLE";"MAP_SELECTED_PRIMITIVE_TO_ONE_EXPERIMENT_PR")
      elif $eligible_prs==1 then closed_fact("ONE_EXPERIMENT_PULL_REQUEST_MAPPED")
      else refuted_fact("PULL_REQUEST_MAPPING";"BIND_EXPERIMENT_PULL_REQUEST_MAPPING";"EXPERIMENT_PULL_REQUEST_MAPPING_INVALID";"RESTORE_SINGLE_ELIGIBLE_PULL_REQUEST") end
    else closed_fact("DIRECT_POLICY_GUARD_OBSERVED") end;
  (reduce $d.cells[] as $cell ({cells:[],by_id:{}};
    . as $acc |
    (direct_fact($cell)) as $direct |
    ([$cell.depends_on[]?|$acc.by_id[.]]) as $dependencies |
    (if $direct.state=="REFUTED" then $direct
     elif any($dependencies[];.state=="REFUTED") then refuted_fact("DEPENDENCY";$cell.activity;"DEPENDENCY_REFUTED";"RESTORE_REFUTED_DEPENDENCY")+{blocked_by:[$dependencies[]|select(.state=="REFUTED")|.id]}
     elif $direct.state=="UNKNOWN" then $direct
     elif any($dependencies[];.state=="UNKNOWN") then unknown_fact("DEPENDENCY";$cell.activity;"DEPENDENCY_BLOCKED";"RESOLVE_UNKNOWN_DEPENDENCY")+{unknown_class:"DEPENDENCY_BLOCKED",blocked_by:[$dependencies[]|select(.state=="UNKNOWN")|.id]}
     else $direct end) as $resolved |
    ($resolved+{id:$cell.id,activity:$cell.activity,proof:$cell.proof,indicator_class:$cell.indicator_class}) as $result |
    .cells+=[ $result ] | .by_id[$cell.id]=$result
  )) as $evaluation |
  ([$evaluation.cells[]|select(.state=="CLOSED")]|length) as $closed |
  ([$evaluation.cells[]|select(.state=="UNKNOWN")]|length) as $unknown |
  ([$evaluation.cells[]|select(.state=="REFUTED")]|length) as $refuted |
  ([$evaluation.cells[]|select(.unknown_class=="DIRECT_MISSING")]|length) as $direct_missing |
  ([$evaluation.cells[]|select(.unknown_class=="DEPENDENCY_BLOCKED")]|length) as $dependency_blocked |
  ([$evaluation.cells[]|select(.state=="REFUTED")][0] // [$evaluation.cells[]|select(.state=="UNKNOWN")][0] // null) as $first |
  (if $refuted>0 then "FAIL_CLOSED" elif $unknown>0 then "CORE_PRIMITIVE_SELECTION_UNKNOWN" else "CORE_PRIMITIVE_SELECTED" end) as $decision |
  {
    schema:"gooo/link/portfolio-core-improvement-selection/v1",
    scenario:$scenario,
    subject_sha:$subject_sha,
    decision:$decision,
    summary:{total:12,closed:$closed,unknown:$unknown,refuted:$refuted,direct_missing:$direct_missing,dependency_blocked:$dependency_blocked,external_consumers:($p.observations.independent_consumers.observed//0),open_experiments:($b.observed_open_experiments//0),mapped_pull_requests:$mapped_prs,merge_eligible_pull_requests:$eligible_prs},
    claim:(if $first==null then {state:"CLOSED",stage:null,step:null,reason:"CORE_PRIMITIVE_SELECTED",unknown_class:null,next_operation:"OPEN_SELECTED_CORE_IMPLEMENTATION_PR",blocked_by:[]} else {state:$first.state,stage:($first.stage//"DEPENDENCY"),step:($first.step//$first.activity),reason:$first.reason,unknown_class:$first.unknown_class,next_operation:$first.next_operation,blocked_by:([$first.id]+$first.blocked_by)} end),
    candidate:{id:null,state:(if $primitive_candidates==0 then "UNKNOWN" else "REFUTED" end),required:1,observed:$primitive_candidates,cross_consumer_need:{observed:0,total:2},semantic_invariants:{observed:0,total:1},version_locks:{observed:0,total:1}},
    experiments:{open:($b.observed_open_experiments//0),mapped:$mapped_prs,merge_eligible:$eligible_prs,automatic_merge_allowed:false},
    stale_operation:{operation:($h.claim.next_operation//null),state:(if $stale_operation_observed then "REFUTED" else "UNKNOWN" end),reason:(if $stale_operation_observed then "CONSUMER_ADOPTIONS_ALREADY_COMPLETE" else "HISTORICAL_SELECTION_UNRECOGNIZED" end),replacement:"OBSERVE_CROSS_CONSUMER_PRIMITIVE_NEED"},
    portfolio:{generator_promotion:$p.decision,external_consumers:$p.observations.independent_consumers,evidence_assets:$p.observations.evidence_assets,generated_cells:$p.observations.generated_cells,verification_cells:$p.observations.verification_cells,queue_decision:$q.decision},
    proofs:[$d.proofs[] as $proof|{choice:$proof.choice,closed:([$evaluation.cells[]|select(.proof==$proof.choice and .state=="CLOSED")]|length),total:$proof.total}],
    indicator_classes:[$d.indicator_classes[] as $class|{class:$class.class,closed:([$evaluation.cells[]|select(.indicator_class==$class.class and .state=="CLOSED")]|length),total:$class.total}],
    indicators:[
      {id:"gooo.metric.portfolio-selection.meta-cells.v1",value:$closed,total:12,unit:"cells",activity:"SelectNextSelfImprovementOperation"},
      {id:"gooo.metric.portfolio-selection.external-consumers.v1",value:($p.observations.independent_consumers.observed//0),total:2,unit:"repositories",activity:"BindIndependentConsumerRepetition"},
      {id:"gooo.metric.portfolio-selection.primitive-candidates.v1",value:$primitive_candidates,total:1,unit:"candidates",activity:"ObserveCorePrimitiveCandidate"},
      {id:"gooo.metric.portfolio-selection.experiment-pr-mappings.v1",value:$mapped_prs,total:($b.observed_open_experiments//0),unit:"pull_requests",activity:"BindExperimentPullRequestMapping"},
      {id:"gooo.metric.portfolio-selection.merge-eligible-prs.v1",value:$eligible_prs,total:1,unit:"pull_requests",activity:"EnforceSelectedImplementationPullRequest"},
      {id:"gooo.metric.portfolio-selection.cross-project-required-gates.v1",value:0,total:0,unit:"gates",activity:"PreservePortfolioAuthorityBoundary"}
    ],
    authority:{portfolio_release:"PINNED_IMMUTABLE_V0.7_RELEASE",core_primitive_selection:"NOT_ESTABLISHED",current_core_pr_branches_for_promotion:0,cross_project_required_gates:0,source_repository_writes:0,local_tests_run:0,root_readme_readiness:"EXCLUDED"},
    cells:$evaluation.cells
  }
' > "$output"
