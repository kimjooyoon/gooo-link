#!/usr/bin/env bash
set -euo pipefail

if test "$#" -ne 15; then
  echo "usage: observe-cross-consumer-primitive-mapping.sh GRAPH DENOMINATOR LOCAL_COMPLETE LOCAL_UNKNOWN LOCAL_REFUTED DESIGN_COMPLETE DESIGN_UNKNOWN_GUARD INFRA_COMPLETE INFRA_UNKNOWN INFRA_REFUTED CORE_CLAIM BACKLOG OUTPUT SUBJECT_SHA SCENARIO" >&2
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
core_claim=${11}
backlog=${12}
output=${13}
subject_sha=${14}
scenario=${15}
base=$(mktemp)
trap 'rm -f "$base"' EXIT

jq -e '
  .schema=="gooo/link/cross-consumer-primitive-mapping-denominator/v2" and
  .candidate_id=="gooo.primitive.claim-resolution-tuple.v1" and
  .total==13 and
  ([.proofs[]|select(.choice=="FOUNDATION").total][0]==5) and
  ([.indicator_classes[]|select(.class=="DRIVER").total][0]==7) and
  ([.cells[]|select(.id=="core-primitive-release")]|length)==1
' "$denominator" >/dev/null

bash "$(dirname "$0")/observe-cross-consumer-primitive-need.sh"   "$graph" contracts/cross-consumer-primitive-need-denominator-v1.json   "$local_complete" "$local_unknown" "$local_refuted"   "$design_complete" "$design_unknown_guard"   "$infra_complete" "$infra_unknown" "$infra_refuted"   "$backlog" "$base" "$subject_sha" "$scenario"

jq -S -n   --slurpfile base "$base"   --slurpfile denominator "$denominator"   --slurpfile core "$core_claim"   --arg subject_sha "$subject_sha"   --arg scenario "$scenario" '
  $base[0] as $r |
  $denominator[0] as $d |
  $core[0] as $cc |
  def closed_fact($reason):
    {state:"CLOSED",reason:$reason,unknown_class:null,next_operation:"NONE",blocked_by:[]};
  def unknown_fact($stage;$step;$reason;$class;$next;$blocked):
    {state:"UNKNOWN",stage:$stage,step:$step,reason:$reason,unknown_class:$class,next_operation:$next,blocked_by:$blocked};
  def refuted_fact($stage;$step;$reason;$next;$blocked):
    {state:"REFUTED",stage:$stage,step:$step,reason:$reason,unknown_class:null,next_operation:$next,blocked_by:$blocked};
  def core_valid($x):
    ($x!=null and ($x|type)=="object" and
     $x.schema=="gooo/claim-resolution/v1" and
     $x.candidate_id=="gooo.primitive.claim-resolution-tuple.v1" and
     $x.decision=="CLAIM_RESOLUTION_OBSERVED" and
     $x.subject.activity_occurrences==1 and
     ($x.subject.source_digest|startswith("sha256:")) and
     ($x.subject.value_program_digest|startswith("sha256:")) and
     $x.contract.version=="claim.resolve/v1" and
     ($x.contract.base_fields|length)==6 and
     ($x.contract.states|length)==3 and
     $x.contract.unknown_class_required==true and
     $x.claim.state=="UNKNOWN" and
     $x.claim.stage=="SOURCE" and
     $x.claim.step=="OBSERVE_INPUT" and
     $x.claim.reason=="INPUT_UNAVAILABLE" and
     $x.claim.unknown_class=="DIRECT_MISSING" and
     $x.claim.next_operation=="PROVIDE_INPUT" and
     $x.summary.fields_observed==6 and
     $x.summary.fields_total==6 and
     $x.summary.resolutions_observed==1 and
     $x.summary.resolutions_total==1 and
     $x.summary.repository_writes==0 and
     $x.authority.core_mutation_authorized==false and
     $x.authority.repository_writes==0);
  (core_valid($cc)) as $core_valid |
  (if $cc==null then
     unknown_fact("CORE_RELEASE";"OBSERVE_CORE_PRIMITIVE_RELEASE";"CORE_PRIMITIVE_RELEASE_UNAVAILABLE";"DIRECT_MISSING";"PUBLISH_CORE_PRIMITIVE_RELEASE";[])
   elif $core_valid then
     closed_fact("CORE_CLAIM_RESOLUTION_PRIMITIVE_RELEASE_OBSERVED")
   else
     refuted_fact("CORE_RELEASE";"VERIFY_CORE_PRIMITIVE_RELEASE";"CORE_PRIMITIVE_RELEASE_INVALID";"RESTORE_CORE_PRIMITIVE_RELEASE";[])
   end) as $core_fact |
  ($r.cells | map(
    if .id!="direct-experiment-mapping" then .
    elif $core_fact.state=="REFUTED" then
      refuted_fact("DEPENDENCY";.activity;"DEPENDENCY_REFUTED";"RESTORE_REFUTED_DEPENDENCY";["core-primitive-release"]) +
      {id:.id,activity:.activity,proof:.proof,indicator_class:.indicator_class}
    elif .state=="REFUTED" then .
    elif $core_fact.state=="UNKNOWN" then
      unknown_fact("DEPENDENCY";.activity;"DEPENDENCY_BLOCKED";"DEPENDENCY_BLOCKED";"RESOLVE_UNKNOWN_DEPENDENCY";["core-primitive-release"]) +
      {id:.id,activity:.activity,proof:.proof,indicator_class:.indicator_class}
    elif .state=="UNKNOWN" then .
    else .reason="EXACT_CORE_PRIMITIVE_MAPPING_OBSERVED"
    end
  )) as $with_direct |
  ($with_direct[]|select(.id=="direct-experiment-mapping")) as $direct |
  ($with_direct | map(
    if .id!="minimal-core-contract-operation" then .
    elif .state=="REFUTED" then .
    elif $core_fact.state=="REFUTED" or $direct.state=="REFUTED" then
      refuted_fact("DEPENDENCY";.activity;"DEPENDENCY_REFUTED";"RESTORE_REFUTED_DEPENDENCY";
        ["core-primitive-release","direct-experiment-mapping"]) +
      {id:.id,activity:.activity,proof:.proof,indicator_class:.indicator_class}
    elif .state=="UNKNOWN" then .
    elif $core_fact.state=="UNKNOWN" or $direct.state=="UNKNOWN" then
      unknown_fact("DEPENDENCY";.activity;"DEPENDENCY_BLOCKED";"DEPENDENCY_BLOCKED";"RESOLVE_UNKNOWN_DEPENDENCY";
        ["core-primitive-release","direct-experiment-mapping"]) +
      {id:.id,activity:.activity,proof:.proof,indicator_class:.indicator_class}
    else .reason="MINIMAL_CORE_CONTRACT_IMPLEMENTATION_OBSERVED"
    end
  )) as $updated |
  ([$d.cells[] as $spec |
    if $spec.id=="core-primitive-release" then
      $core_fact + {id:$spec.id,activity:$spec.activity,proof:$spec.proof,indicator_class:$spec.indicator_class}
    else
      $updated[] | select(.id==$spec.id)
    end
  ]) as $cells |
  ([$cells[]|select(.state=="CLOSED")]|length) as $closed |
  ([$cells[]|select(.state=="UNKNOWN")]|length) as $unknown |
  ([$cells[]|select(.state=="REFUTED")]|length) as $refuted |
  ([$cells[]|select(.state=="UNKNOWN" and .unknown_class=="DIRECT_MISSING")]|length) as $direct_missing |
  ([$cells[]|select(.state=="UNKNOWN" and .unknown_class=="DEPENDENCY_BLOCKED")]|length) as $dependency_blocked |
  (if $core_valid then 1 else 0 end) as $core_direct_mappings |
  ($r.experiments.direct_mappings+$core_direct_mappings) as $direct_mappings |
  ($r.experiments.open+1) as $mapping_denominator |
  ([$cells[]|select(.state!="CLOSED")]) as $unresolved |
  ($unresolved[0]//null) as $first |
  (if $refuted>0 then "FAIL_CLOSED"
   elif $unknown>0 then "CROSS_CONSUMER_PRIMITIVE_MAPPING_UNKNOWN"
   else "CROSS_CONSUMER_PRIMITIVE_IMPLEMENTATION_OBSERVED" end) as $decision |
  {
    schema:"gooo/link/cross-consumer-primitive-mapping-report/v2",
    scenario:$scenario,
    subject_sha:$subject_sha,
    decision:$decision,
    summary:($r.summary+{
      total:$d.total,closed:$closed,unknown:$unknown,refuted:$refuted,
      direct_missing:$direct_missing,dependency_blocked:$dependency_blocked,
      core_releases:(if $core_valid then 1 else 0 end),
      mapping_denominator:$mapping_denominator,direct_mappings:$direct_mappings
    }),
    claim:(if $first==null then
      {state:"CLOSED",stage:null,step:null,reason:"CROSS_CONSUMER_CLAIM_RESOLUTION_PRIMITIVE_IMPLEMENTED",
       unknown_class:null,next_operation:"OBSERVE_INDEPENDENT_CONSUMER_ADOPTION",blocked_by:[]}
      else
      {state:$first.state,stage:($first.stage//"DEPENDENCY"),step:($first.step//$first.activity),
       reason:$first.reason,unknown_class:$first.unknown_class,next_operation:$first.next_operation,
       blocked_by:([$first.id]+($first.blocked_by//[]))}
      end),
    candidate:($r.candidate+{
      state:(if $core_valid then "IMPLEMENTED" elif $core_fact.state=="REFUTED" then "REFUTED" else "UNKNOWN" end),
      implementation_status:(if $core_valid then "RELEASED_EXPERIMENTAL" elif $core_fact.state=="REFUTED" then "INVALID" else "UNAVAILABLE" end),
      core_release:{observed:(if $core_valid then 1 else 0 end),total:1},
      direct_mappings:{observed:$direct_mappings,total:$mapping_denominator}
    }),
    experiments:($r.experiments+{
      mapping_denominator:$mapping_denominator,
      direct_mappings:$direct_mappings,
      automatic_merge_allowed:false
    }),
    consumer_observations:$r.consumer_observations,
    proofs:[$d.proofs[] as $proof|{
      choice:$proof.choice,
      closed:([$cells[]|select(.proof==$proof.choice and .state=="CLOSED")]|length),
      total:$proof.total
    }],
    indicator_classes:[$d.indicator_classes[] as $class|{
      class:$class.class,
      closed:([$cells[]|select(.indicator_class==$class.class and .state=="CLOSED")]|length),
      total:$class.total
    }],
    indicators:(
      [$r.indicators[] |
        if .id=="gooo.metric.cross-consumer.direct-experiment-mappings.v1" then
          .id="gooo.metric.cross-consumer.direct-primitive-mappings.v2" |
          .value=$direct_mappings | .total=$mapping_denominator | .unit="mappings"
        else . end
      ] +
      [{
        id:"gooo.metric.cross-consumer.core-primitive-releases.v2",
        value:(if $core_valid then 1 else 0 end),total:1,unit:"releases",class:"DRIVER",
        activity:"ObserveCorePrimitiveRelease"
      }]
    ),
    authority:($r.authority+{
      evidence:"PINNED_IMMUTABLE_RELEASE_AND_SOURCE",
      observation_scope:"CROSS_CONSUMER_PRIMITIVE_MAPPING_ONLY",
      core_contract:"RELEASED_EXPERIMENTAL",
      core_implementation:(if $core_valid then "OBSERVED" else "NOT_OBSERVED" end),
      current_consumer_branches:0,cross_project_required_gates:0,
      source_repository_writes:0,local_tests_run:0,root_readme_readiness:"EXCLUDED"
    }),
    cells:$cells
  }
  ' > "$output"
