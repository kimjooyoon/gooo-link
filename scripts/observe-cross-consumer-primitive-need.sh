#!/usr/bin/env bash
set -euo pipefail

if test "$#" -ne 14; then
  echo "usage: observe-cross-consumer-primitive-need.sh GRAPH DENOMINATOR LOCAL_COMPLETE LOCAL_UNKNOWN LOCAL_REFUTED DESIGN_COMPLETE DESIGN_UNKNOWN_GUARD INFRA_COMPLETE INFRA_UNKNOWN INFRA_REFUTED BACKLOG OUTPUT SUBJECT_SHA SCENARIO" >&2
  exit 64
fi

graph=$1
denominator=$2
local_complete=$3
local_unknown=$4
local_refuted=$5
design_complete=$6
design_unknown_guard=$7
infra_complete=$8
infra_unknown=$9
infra_refuted=${10}
backlog=${11}
output=${12}
subject_sha=${13}
scenario=${14}

jq -S -n \
  --slurpfile graph "$graph" \
  --slurpfile denominator "$denominator" \
  --slurpfile local_complete "$local_complete" \
  --slurpfile local_unknown "$local_unknown" \
  --slurpfile local_refuted "$local_refuted" \
  --slurpfile design_complete "$design_complete" \
  --slurpfile design_unknown_guard "$design_unknown_guard" \
  --slurpfile infra_complete "$infra_complete" \
  --slurpfile infra_unknown "$infra_unknown" \
  --slurpfile infra_refuted "$infra_refuted" \
  --slurpfile backlog "$backlog" \
  --arg subject_sha "$subject_sha" \
  --arg scenario "$scenario" '
  $graph[0] as $g |
  $denominator[0] as $d |
  $local_complete[0] as $lc |
  $local_unknown[0] as $lu |
  $local_refuted[0] as $lf |
  $design_complete[0] as $dc |
  $design_unknown_guard[0] as $dg |
  $infra_complete[0] as $ic |
  $infra_unknown[0] as $iu |
  $infra_refuted[0] as $ir |
  $backlog[0] as $b |
  $d.candidate_id as $candidate_id |
  def closed_fact($reason): {state:"CLOSED",reason:$reason,unknown_class:null,next_operation:"NONE",blocked_by:[]};
  def unknown_fact($stage;$step;$reason;$next): {state:"UNKNOWN",stage:$stage,step:$step,reason:$reason,unknown_class:"DIRECT_MISSING",next_operation:$next,blocked_by:[]};
  def refuted_fact($stage;$step;$reason;$next): {state:"REFUTED",stage:$stage,step:$step,reason:$reason,unknown_class:null,next_operation:$next,blocked_by:[]};
  def activity_count($name): [$g.nodes[]?|select(.kind=="Activity" and .name==$name)]|length;
  def envelope($x):
    if $x==null or ($x|type)!="object" then false
    else ($x|has("schema") and has("decision") and has("summary") and has("claim") and has("cells") and has("indicators") and has("authority") and (.cells|type=="array") and (.indicators|type=="array")) end;
  def claim_tuple($x):
    if $x==null or ($x|type)!="object" or ($x.claim|type)!="object" then false
    else ($x.claim|has("state") and has("stage") and has("step") and has("reason") and has("next_operation")) end;
  ($lc==null or $lu==null or $lf==null) as $local_missing |
  ($dc==null or $dg==null) as $design_missing |
  ($ic==null or $iu==null or $if==null) as $infra_missing |
  ($local_missing or $design_missing or $infra_missing) as $consumer_release_missing |
  ($lc!=null and $lc.schema=="gooo/local-ledger/readiness-report/v1" and $lc.decision=="RELEASE_READY" and $lc.summary=={total:12,closed:12,unknown:0,refuted:0,repository_writes:0} and
   $lu!=null and $lu.schema=="gooo/local-ledger/readiness-report/v1" and $lu.decision=="NOT_READY" and $lu.claim.state=="UNKNOWN" and
   $lf!=null and $lf.schema=="gooo/local-ledger/readiness-report/v1" and $lf.decision=="FAIL_CLOSED" and $lf.claim.state=="REFUTED") as $local_valid |
  ($dc!=null and $dc.schema=="gooo/design-evidence/interchange-adoption-report/v1" and $dc.decision=="ADOPTION_CONFORMANT" and $dc.summary.closed==12 and $dc.summary.total==12 and
   $dg!=null and $dg.schema=="gooo/design-evidence/interchange-conformance/v1" and $dg.decision=="FAIL_CLOSED" and $dg.claim.reason=="UNKNOWN_TUPLE_INCOMPLETE") as $design_valid |
  ($ic!=null and $ic.schema=="gooo/infra-evidence/report/v2" and $ic.decision=="EVIDENCE_CHAIN_CLOSED" and $ic.summary.closed==12 and $ic.summary.total==12 and
   $iu!=null and $iu.schema=="gooo/infra-evidence/report/v2" and $iu.decision=="INCOMPLETE" and $iu.claim.state=="UNKNOWN" and
   $ir!=null and $ir.schema=="gooo/infra-evidence/report/v2" and $ir.decision=="FAIL_CLOSED" and $ir.claim.state=="REFUTED") as $infra_valid |
  ([envelope($lc),envelope($dc),envelope($ic)]|map(select(.==true))|length) as $common_envelopes |
  ([claim_tuple($lc),claim_tuple($lu),claim_tuple($lf),claim_tuple($dc),claim_tuple($dg),claim_tuple($ic),claim_tuple($iu),claim_tuple($ir)]|all) as $base_tuple_valid |
  ([$lc,$dc,$ic]|map(select(.!=null and .claim.state=="CLOSED"))|length) as $closed_consumers |
  ([$lf,$dg,$ir]|map(select(.!=null and .claim.state=="REFUTED"))|length) as $refuted_consumers |
  ([$lu,$iu]|map(select(.!=null and .claim.state=="UNKNOWN"))|length) as $unknown_producers |
  (if $iu==null or ($iu.claim|type)!="object" then false else ($iu.claim.unknown_class=="DIRECT_MISSING" and claim_tuple($iu)) end) as $infra_typed_unknown |
  (if $dg==null or ($dg.claim|type)!="object" then false else ($dg.claim.state=="REFUTED" and $dg.claim.stage=="UNCERTAINTY" and $dg.claim.step=="VERIFY_UNKNOWN_TUPLE" and $dg.claim.reason=="UNKNOWN_TUPLE_INCOMPLETE" and $dg.claim.next_operation=="RESTORE_UNKNOWN_TUPLE") end) as $design_unknown_guard_valid |
  ([$infra_typed_unknown,$design_unknown_guard_valid]|map(select(.==true))|length) as $typed_unknown_roles |
  (if $lu==null or ($lu.claim|type)!="object" then false else ($lu.claim.state=="UNKNOWN" and (($lu.claim|has("unknown_class"))|not)) end) as $local_compatibility_gap |
  (if $b==null then false else ($b.schema=="gooo/link/core-experiment-backlog/v1" and $b.observed_open_experiments==29 and ($b.experiments|length)==29) end) as $backlog_valid |
  (if $b==null then [] else [$b.experiments[]|select(.candidate_id==$candidate_id)] end) as $candidate_mappings |
  ([$candidate_mappings[]|select((.mapping_evidence.type//"")=="EXACT_CANDIDATE_ID_IN_GOOO_SOURCE" and (.mapping_evidence.candidate_id//"")==$candidate_id)]|length) as $direct_mappings |
  ([$candidate_mappings[]|select((.mapping_evidence.type//"")!="EXACT_CANDIDATE_ID_IN_GOOO_SOURCE" or (.mapping_evidence.candidate_id//"")!=$candidate_id)]|length) as $title_only_mappings |
  def direct_fact($cell):
    if activity_count($cell.activity)!=1 then
      refuted_fact("META_BINDING";"RESOLVE_ACTIVITY_CARDINALITY";"META_ACTIVITY_CARDINALITY_INVALID";"RESTORE_EXACTLY_ONE_META_ACTIVITY")
    elif $cell.id=="local-ledger-release" then
      if $local_missing then unknown_fact("CONSUMER_RELEASE";"OBSERVE_LOCAL_LEDGER_RELEASE";"LOCAL_LEDGER_RELEASE_UNAVAILABLE";"PUBLISH_LOCAL_LEDGER_RELEASE")
      elif $local_valid then closed_fact("LOCAL_LEDGER_RELEASE_OBSERVED") else refuted_fact("CONSUMER_RELEASE";"VERIFY_LOCAL_LEDGER_RELEASE";"LOCAL_LEDGER_RELEASE_INVALID";"RESTORE_LOCAL_LEDGER_RELEASE") end
    elif $cell.id=="design-evidence-release" then
      if $design_missing then unknown_fact("CONSUMER_RELEASE";"OBSERVE_DESIGN_EVIDENCE_RELEASE";"DESIGN_EVIDENCE_RELEASE_UNAVAILABLE";"PUBLISH_DESIGN_EVIDENCE_RELEASE")
      elif $design_valid then closed_fact("DESIGN_EVIDENCE_RELEASE_OBSERVED") else refuted_fact("CONSUMER_RELEASE";"VERIFY_DESIGN_EVIDENCE_RELEASE";"DESIGN_EVIDENCE_RELEASE_INVALID";"RESTORE_DESIGN_EVIDENCE_RELEASE") end
    elif $cell.id=="infra-evidence-release" then
      if $infra_missing then unknown_fact("CONSUMER_RELEASE";"OBSERVE_INFRA_EVIDENCE_RELEASE";"INFRA_EVIDENCE_RELEASE_UNAVAILABLE";"PUBLISH_INFRA_EVIDENCE_RELEASE")
      elif $infra_valid then closed_fact("INFRA_EVIDENCE_RELEASE_OBSERVED") else refuted_fact("CONSUMER_RELEASE";"VERIFY_INFRA_EVIDENCE_RELEASE";"INFRA_EVIDENCE_RELEASE_INVALID";"RESTORE_INFRA_EVIDENCE_RELEASE") end
    elif $consumer_release_missing then closed_fact("CONSUMER_OBSERVATION_DEFERRED_TO_RELEASE_DEPENDENCY")
    elif $cell.id=="common-report-envelope" then
      if $common_envelopes==3 then closed_fact("COMMON_REPORT_ENVELOPE_OBSERVED_IN_THREE_CONSUMERS") else refuted_fact("CLAIM_ENVELOPE";"BIND_COMMON_CLAIM_ENVELOPE";"COMMON_REPORT_ENVELOPE_MISMATCH";"RESTORE_COMMON_REPORT_ENVELOPE") end
    elif $cell.id=="base-claim-resolution-tuple" then
      if $base_tuple_valid then closed_fact("BASE_CLAIM_RESOLUTION_TUPLE_OBSERVED") else refuted_fact("CLAIM_TUPLE";"OBSERVE_BASE_CLAIM_RESOLUTION_TUPLE";"BASE_CLAIM_RESOLUTION_TUPLE_INCOMPLETE";"RESTORE_BASE_CLAIM_RESOLUTION_TUPLE") end
    elif $cell.id=="three-state-claim-lifecycle" then
      if $closed_consumers==3 and $refuted_consumers==3 and $unknown_producers==2 then closed_fact("CLOSED_UNKNOWN_REFUTED_LIFECYCLE_OBSERVED") else refuted_fact("CLAIM_LIFECYCLE";"OBSERVE_THREE_STATE_CLAIM_LIFECYCLE";"THREE_STATE_CLAIM_LIFECYCLE_MISMATCH";"RESTORE_THREE_STATE_CLAIM_EVIDENCE") end
    elif $cell.id=="unknown-producing-consumers" then
      if $unknown_producers==2 then closed_fact("TWO_UNKNOWN_PRODUCING_CONSUMERS_OBSERVED") else refuted_fact("UNKNOWN";"COUNT_UNKNOWN_PRODUCING_CONSUMERS";"UNKNOWN_PRODUCER_DENOMINATOR_MISMATCH";"RESTORE_TWO_UNKNOWN_PRODUCERS") end
    elif $cell.id=="typed-unknown-evidence-roles" then
      if $typed_unknown_roles==2 then closed_fact("TYPED_UNKNOWN_PRODUCER_AND_GUARD_OBSERVED") else refuted_fact("UNKNOWN";"BIND_TYPED_UNKNOWN_EVIDENCE_ROLES";"TYPED_UNKNOWN_EVIDENCE_ROLE_MISMATCH";"RESTORE_TYPED_UNKNOWN_EVIDENCE_ROLES") end
    elif $cell.id=="claim-resolution-compatibility-gap" then
      if $local_compatibility_gap then closed_fact("LOCAL_LEDGER_UNKNOWN_CLASS_GAP_EXPOSED") else refuted_fact("COMPATIBILITY";"EXPOSE_CLAIM_RESOLUTION_COMPATIBILITY_GAP";"CLAIM_RESOLUTION_GAP_LAUNDERED";"RESTORE_OBSERVED_COMPATIBILITY_GAP") end
    elif $cell.id=="observation-authority-boundary" then
      if $scenario=="scope-escalation" then refuted_fact("AUTHORITY";"PRESERVE_OBSERVATION_AUTHORITY_BOUNDARY";"OBSERVATION_EVIDENCE_SCOPE_ESCALATION";"RESTORE_OBSERVATION_ONLY_AUTHORITY") else closed_fact("OBSERVATION_ONLY_AUTHORITY_PRESERVED") end
    elif $cell.id=="direct-experiment-mapping" then
      if $b==null then unknown_fact("EXPERIMENT_MAPPING";"OBSERVE_PINNED_EXPERIMENT_BACKLOG";"CORE_EXPERIMENT_BACKLOG_UNAVAILABLE";"PUBLISH_CORE_EXPERIMENT_BACKLOG")
      elif ($backlog_valid|not) then refuted_fact("EXPERIMENT_MAPPING";"VERIFY_CORE_EXPERIMENT_BACKLOG";"CORE_EXPERIMENT_BACKLOG_INVALID";"RESTORE_CORE_EXPERIMENT_BACKLOG")
      elif $title_only_mappings>0 then refuted_fact("EXPERIMENT_MAPPING";"REJECT_TITLE_ONLY_EXPERIMENT_MAPPING";"TITLE_ONLY_EXPERIMENT_MAPPING_FORBIDDEN";"REMOVE_UNPROVEN_EXPERIMENT_MAPPING")
      else closed_fact(if $direct_mappings==0 then "NO_DIRECT_EXPERIMENT_MAPPING_OBSERVED" else "DIRECT_EXPERIMENT_MAPPING_OBSERVED" end) end
    else closed_fact("MINIMAL_CORE_CONTRACT_OPERATION_SELECTED") end;
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
  (if $refuted>0 then "FAIL_CLOSED" elif $unknown>0 then "CROSS_CONSUMER_PRIMITIVE_NEED_UNKNOWN" else "CROSS_CONSUMER_PRIMITIVE_NEED_OBSERVED" end) as $decision |
  {
    schema:"gooo/link/cross-consumer-primitive-need-report/v1",
    scenario:$scenario,
    subject_sha:$subject_sha,
    decision:$decision,
    summary:{total:12,closed:$closed,unknown:$unknown,refuted:$refuted,direct_missing:$direct_missing,dependency_blocked:$dependency_blocked,consumer_releases:([$local_valid,$design_valid,$infra_valid]|map(select(.==true))|length),common_envelopes:$common_envelopes,base_claim_consumers:(if $base_tuple_valid then 3 else 0 end),claim_states:([$closed_consumers>0,$unknown_producers>0,$refuted_consumers>0]|map(select(.==true))|length),unknown_producers:$unknown_producers,typed_unknown_roles:$typed_unknown_roles,compatibility_gaps:(if $local_compatibility_gap then 1 else 0 end),open_experiments:($b.observed_open_experiments//0),direct_mappings:$direct_mappings},
    claim:(if $first==null then {state:"CLOSED",stage:null,step:null,reason:"CROSS_CONSUMER_CLAIM_RESOLUTION_NEED_OBSERVED",unknown_class:null,next_operation:"DEFINE_MINIMAL_CLAIM_RESOLUTION_CORE_CONTRACT",blocked_by:[]} else {state:$first.state,stage:($first.stage//"DEPENDENCY"),step:($first.step//$first.activity),reason:$first.reason,unknown_class:$first.unknown_class,next_operation:$first.next_operation,blocked_by:([$first.id]+($first.blocked_by//[]))} end),
    candidate:{id:$candidate_id,state:(if $decision=="CROSS_CONSUMER_PRIMITIVE_NEED_OBSERVED" then "OBSERVED" elif $decision=="FAIL_CLOSED" then "REFUTED" else "UNKNOWN" end),implementation_status:"NOT_SELECTED",base_claim_fields:{observed:(if $base_tuple_valid then 5 else 0 end),total:5},consumer_envelopes:{observed:$common_envelopes,total:3},unknown_producers:{observed:$unknown_producers,total:2},typed_unknown_roles:{observed:$typed_unknown_roles,total:2},compatibility_gaps:{observed:(if $local_compatibility_gap then 1 else 0 end),total:1}},
    experiments:{open:($b.observed_open_experiments//0),candidate_mentions:($candidate_mappings|length),direct_mappings:$direct_mappings,automatic_merge_allowed:false},
    consumer_observations:{local_ledger:{complete:($lc.claim.state//null),unknown:($lu.claim.state//null),refuted:($lf.claim.state//null),unknown_class_present:(if $lu==null or ($lu.claim|type)!="object" then false else ($lu.claim|has("unknown_class")) end)},design_evidence:{complete:($dc.claim.state//null),unknown_guard:($dg.claim.reason//null)},infra_evidence:{complete:($ic.claim.state//null),unknown:($iu.claim.state//null),unknown_class:($iu.claim.unknown_class//null),refuted:($ir.claim.state//null)}},
    proofs:[$d.proofs[] as $proof|{choice:$proof.choice,closed:([$evaluation.cells[]|select(.proof==$proof.choice and .state=="CLOSED")]|length),total:$proof.total}],
    indicator_classes:[$d.indicator_classes[] as $class|{class:$class.class,closed:([$evaluation.cells[]|select(.indicator_class==$class.class and .state=="CLOSED")]|length),total:$class.total}],
    indicators:[
      {id:"gooo.metric.cross-consumer.consumer-releases.v1",value:([$local_valid,$design_valid,$infra_valid]|map(select(.==true))|length),total:3,unit:"releases",class:"DRIVER",activity:"BindCommonClaimEnvelope"},
      {id:"gooo.metric.cross-consumer.common-envelopes.v1",value:$common_envelopes,total:3,unit:"consumers",class:"DRIVER",activity:"BindCommonClaimEnvelope"},
      {id:"gooo.metric.cross-consumer.claim-states.v1",value:([$closed_consumers>0,$unknown_producers>0,$refuted_consumers>0]|map(select(.==true))|length),total:3,unit:"states",class:"OUTCOME",activity:"ObserveThreeStateClaimLifecycle"},
      {id:"gooo.metric.cross-consumer.unknown-producers.v1",value:$unknown_producers,total:2,unit:"consumers",class:"DRIVER",activity:"CountUnknownProducingConsumers"},
      {id:"gooo.metric.cross-consumer.typed-unknown-roles.v1",value:$typed_unknown_roles,total:2,unit:"roles",class:"GUARDRAIL",activity:"BindTypedUnknownEvidenceRoles"},
      {id:"gooo.metric.cross-consumer.compatibility-gaps.v1",value:(if $local_compatibility_gap then 1 else 0 end),total:1,unit:"gaps",class:"GUARDRAIL",activity:"ExposeClaimResolutionCompatibilityGap"},
      {id:"gooo.metric.cross-consumer.direct-experiment-mappings.v1",value:$direct_mappings,total:($b.observed_open_experiments//0),unit:"pull_requests",class:"GUARDRAIL",activity:"RejectTitleOnlyExperimentMapping"},
      {id:"gooo.metric.cross-consumer.repository-writes.v1",value:0,total:0,unit:"writes",class:"GUARDRAIL",activity:"PreserveObservationAuthorityBoundary"}
    ],
    authority:{evidence:"PINNED_IMMUTABLE_RELEASE_ASSETS",observation_scope:"CROSS_CONSUMER_PRIMITIVE_NEED_ONLY",core_contract:"NOT_DEFINED",core_implementation:"NOT_CLAIMED",current_consumer_branches:0,cross_project_required_gates:0,source_repository_writes:0,local_tests_run:0,root_readme_readiness:"EXCLUDED"},
    cells:$evaluation.cells
  }
  ' > "$output"
