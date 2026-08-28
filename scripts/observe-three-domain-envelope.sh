#!/usr/bin/env bash
set -euo pipefail

if test "$#" -ne 9; then
  echo "usage: observe-three-domain-envelope.sh GRAPH CORE_RESOLUTIONS DENOMINATOR CORE_LOCK RELEASE_OBSERVATION INPUT_ROOT OUTPUT SUBJECT_SHA SCENARIO" >&2
  exit 64
fi

graph=$1
core_resolutions=$2
denominator=$3
core_lock=$4
release_observation=$5
input_root=$6
output=$7
subject_sha=$8
scenario=$9

for file in "$graph" "$core_resolutions" "$denominator" "$core_lock" "$release_observation"; do
  test -f "$file" || { echo "missing required input: $file" >&2; exit 66; }
done

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
json_or_null() { if test -f "$1" && jq -e . "$1" >/dev/null 2>&1; then cp "$1" "$2"; else printf 'null\n' > "$2"; fi; }

json_or_null "$input_root/local-ledger/core-receipt-adoption.json" "$work/local.json"
json_or_null "$input_root/design-evidence/core-receipt-adoption.json" "$work/design.json"
json_or_null "$input_root/infra-evidence/infra-service-claim.json" "$work/infra.json"
json_or_null "$input_root/infra-evidence/enriched-graph.json" "$work/infra-graph.json"
json_or_null "$input_root/infra-evidence/missing-build.json" "$work/infra-missing-build.json"
json_or_null "$input_root/infra-evidence/missing-state-v2.json" "$work/infra-missing-state.json"
json_or_null "$input_root/infra-evidence/ambiguous-handler.json" "$work/infra-ambiguous.json"
json_or_null "$input_root/infra-evidence/identity-mismatch.json" "$work/infra-identity.json"
json_or_null "$input_root/infra-evidence/deployment-drift.json" "$work/infra-deployment.json"

jq -S -n \
  --slurpfile graph "$graph" --slurpfile core "$core_resolutions" --slurpfile denominator "$denominator" \
  --slurpfile core_lock "$core_lock" --slurpfile releases "$release_observation" \
  --slurpfile local "$work/local.json" --slurpfile design "$work/design.json" \
  --slurpfile infra "$work/infra.json" --slurpfile infra_graph "$work/infra-graph.json" \
  --slurpfile infra_missing_build "$work/infra-missing-build.json" --slurpfile infra_missing_state "$work/infra-missing-state.json" \
  --slurpfile infra_ambiguous "$work/infra-ambiguous.json" --slurpfile infra_identity "$work/infra-identity.json" \
  --slurpfile infra_deployment "$work/infra-deployment.json" \
  --arg subject_sha "$subject_sha" --arg scenario "$scenario" '
  ($denominator[0]) as $d |
  ($core_lock[0]) as $lock |
  def expected_core:
    {repository:$lock.repository,tag:$lock.tag,tag_object_sha:$lock.tag_object_sha,target_commit_sha:$lock.target_commit_sha,
      binary_asset:"gooo-linux-amd64.tar.gz",
      binary_sha256:($lock.assets[]|select(.name=="gooo-linux-amd64.tar.gz")|(.sha256 // (.digest|sub("^sha256:";"")))),
      resolution_schema:$lock.schemas.activity_cardinality_resolution};
  def closed_fact: {state:"CLOSED",reason:"FACT_OBSERVED",next_operation:"NONE",unknown_class:null,resolution:"EXACT",blocked_by:[]};
  def unknown_fact($reason;$next): {state:"UNKNOWN",reason:$reason,next_operation:$next,unknown_class:"DIRECT_MISSING",resolution:"PREREQUISITE_CLASS",blocked_by:[]};
  def refuted_fact($reason;$next): {state:"REFUTED",reason:$reason,next_operation:$next,unknown_class:null,resolution:"EXACT",blocked_by:[]};
  def core_resolution_fact($cell):
    if $core[0].core_release!=expected_core then
      refuted_fact("CORE_RELEASE_IDENTITY_MISMATCH";"RESTORE_PINNED_CORE_RELEASE") + {stage:"CORE_RELEASE",step:"BIND_CORE_RELEASE_IDENTITY"}
    else ([$core[0].receipts[]? | select(.selector.name?==$cell.activity)]) as $receipts |
      if ($receipts|length)==0 then unknown_fact("CORE_ACTIVITY_RESOLUTION_RECEIPT_UNAVAILABLE";"PROVIDE_CORE_ACTIVITY_RESOLUTION_RECEIPT") + {stage:"RESOLUTION_OBSERVATION",step:"BIND_CORE_ACTIVITY_RESOLUTION_RECEIPT"}
      elif ($receipts|length)>1 then refuted_fact("DUPLICATE_CORE_ACTIVITY_RESOLUTION_RECEIPT";"REMOVE_DUPLICATE_CORE_ACTIVITY_RESOLUTION_RECEIPT") + {stage:"RESOLUTION_OBSERVATION",step:"BIND_CORE_ACTIVITY_RESOLUTION_RECEIPT"}
      else ($receipts[0]) as $receipt |
        if $receipt.schema!="gooo/activity-cardinality-resolution/v1" or $receipt.selector.name!=$cell.activity or
          $receipt.subject.source_file!="examples/three-domain-envelope/main.gooo" then
          refuted_fact("INVALID_CORE_ACTIVITY_RESOLUTION_RECEIPT";"RESTORE_CORE_ACTIVITY_RESOLUTION_RECEIPT") + {stage:"RESOLUTION_OBSERVATION",step:"VALIDATE_CORE_ACTIVITY_RESOLUTION_RECEIPT"}
        elif $receipt.decision=="CLOSED" and $receipt.claim.state=="CLOSED" and $receipt.occurrences==1 and ($receipt.matches|length)==1 and
          $receipt.claim.stage=="RESOLUTION" and $receipt.claim.step=="RESOLVE_ACTIVITY_CARDINALITY" and
          $receipt.claim.reason=="ACTIVITY_UNIQUELY_RESOLVED" and $receipt.claim.next_operation=="USE_RESOLVED_ACTIVITY" and
          $receipt.claim.proof_choice=="COHERENCE" then
          closed_fact + {stage:"RESOLUTION",step:"RESOLVE_ACTIVITY_CARDINALITY",core_decision:$receipt.decision,activity_occurrences:$receipt.occurrences}
        elif $receipt.decision=="UNKNOWN" and $receipt.claim.state=="UNKNOWN" and $receipt.occurrences==0 and
          $receipt.claim.reason=="ACTIVITY_NOT_FOUND" and $receipt.claim.unknown_class=="DIRECT_MISSING" then
          unknown_fact("ACTIVITY_NOT_FOUND";"DECLARE_OR_WIDEN_ACTIVITY_SELECTOR") + {stage:"RESOLUTION",step:"RESOLVE_ACTIVITY_CARDINALITY",core_decision:$receipt.decision,activity_occurrences:$receipt.occurrences}
        elif $receipt.decision=="REFUTED" and $receipt.claim.state=="REFUTED" and $receipt.occurrences>1 and
          $receipt.claim.reason=="AMBIGUOUS_ACTIVITY_BINDING" then
          refuted_fact("AMBIGUOUS_ACTIVITY_BINDING";"NARROW_ACTIVITY_SELECTOR") + {stage:"RESOLUTION",step:"RESOLVE_ACTIVITY_CARDINALITY",core_decision:$receipt.decision,activity_occurrences:$receipt.occurrences}
        else refuted_fact("UNRECOGNIZED_CORE_ACTIVITY_RESOLUTION_DECISION";"RESTORE_CORE_ACTIVITY_RESOLUTION_RECEIPT") + {stage:"RESOLUTION",step:"RESOLVE_ACTIVITY_CARDINALITY",core_decision:($receipt.decision//null),activity_occurrences:($receipt.occurrences//null)}
        end
      end
    end;
  def class_totals($items): ["OUTCOME","DRIVER","GUARDRAIL"]|map(. as $class|([$items[]?|select(.class==$class)|.total][0]//null));
  def proof_totals($items): ["FOUNDATION","COHERENCE","REGRESSION"]|map(. as $choice|([$items[]?|select(.choice==$choice)|.total][0]//null));
  def adoption_claims($domain;$document):
    if $document==null then [] else [$document.degraded_resolution|to_entries[]|{domain:$domain,scenario:.key,claim:.value.claim,summary:.value.summary}] end;
  (adoption_claims("local-ledger";$local[0]) + adoption_claims("design-evidence";$design[0]) +
    ([
      {domain:"infra-evidence",scenario:"missing-build",report:$infra_missing_build[0]},
      {domain:"infra-evidence",scenario:"missing-state",report:$infra_missing_state[0]},
      {domain:"infra-evidence",scenario:"ambiguous-handler",report:$infra_ambiguous[0]},
      {domain:"infra-evidence",scenario:"identity-mismatch",report:$infra_identity[0]},
      {domain:"infra-evidence",scenario:"deployment-drift",report:$infra_deployment[0]}
    ]|map(select(.report!=null)|{domain,scenario,claim:.report.claim,summary:.report.summary}))) as $claims |
  ([$local[0],$design[0],$infra[0]]|map(select(.!=null))|length) as $domain_documents |
  ([$local[0].schema?,$design[0].schema?,$infra[0].schema?]|map(select(type=="string"))|unique) as $schemas |
  ([$local[0],$design[0],$infra[0]]|map(select(.!=null)|keys|sort|join(","))|unique) as $key_shapes |
  ([
    $local[0].complete.core_resolution.core_release?,
    $design[0].complete.core_resolution.core_release?,
    $infra_graph[0].activity_resolution_observation.core_release?
  ]|map(select(.==expected_core))|length) as $core_support |
  ([$local[0].complete.core_resolution.identity_anchor_count?,$design[0].complete.core_resolution.identity_anchor_count?,$infra[0].authority.core_identity_anchors?]) as $anchors |
  ([$local[0].complete.summary.total?,$design[0].complete.summary.total?,$infra[0].summary.total?]) as $cell_totals |
  (class_totals($local[0].complete.indicators//[])) as $local_indicators |
  (class_totals($design[0].complete.indicators//[])) as $design_indicators |
  (class_totals($infra[0].indicator_classes//[])) as $infra_indicators |
  (proof_totals($local[0].complete.proofs//[])) as $local_proofs |
  (proof_totals($design[0].complete.proofs//[])) as $design_proofs |
  (proof_totals($infra[0].proofs//[])) as $infra_proofs |
  ([$local[0].runtime.repository.writes?,$design[0].runtime.repository.writes?,$infra[0].summary.repository_writes?]) as $writes |
  ([$claims[]|select(.claim.state=="UNKNOWN")|.domain]|unique|length) as $unknown_domain_support |
  ([$claims[]|select(.claim.state=="REFUTED")|.domain]|unique|length) as $refuted_domain_support |
  ([$claims[]|select(.claim|has("stage") and has("step") and has("reason") and has("unknown_class") and has("next_operation"))]|length) as $complete_claim_tuples |
  ([($local[0].runtime.deterministic_replay? // false),($design[0].runtime.deterministic_replay? // false),($infra[0].deterministic_replay? // false)]|map(select(.==true))|length) as $machine_replays |
  ([$local[0],$design[0],$infra[0]]|map(select(.!=null and ((.interchange.schema? // "")=="gooo/interchange/envelope/v1")))|length) as $canonical_adoptions |
  ($releases[0].consumers|map(.selected_assets)|add) as $selected_assets |
  ($releases[0].consumers|map(.verified_assets)|add) as $verified_assets |
  ({
    RELEASED_GOOO_IDENTITY:
      (if $core[0].core_release==expected_core and $core[0].summary.closed==12 then closed_fact else refuted_fact("RELEASED_GOOO_IDENTITY_MISMATCH";"RESTORE_PINNED_GOOO_RELEASE") end),
    CONSUMER_RELEASE_IDENTITIES:
      (if ($releases[0].consumers|length)==3 and all($releases[0].consumers[];.identity_verified==true) then closed_fact else refuted_fact("CONSUMER_RELEASE_IDENTITY_MISMATCH";"RESTORE_PINNED_CONSUMER_RELEASES") end),
    SELECTED_ASSET_DIGESTS:
      (if $selected_assets==9 and $verified_assets==9 then closed_fact else refuted_fact("SELECTED_ASSET_DIGEST_MISMATCH";"RESTORE_PINNED_RELEASE_ASSETS") end),
    DISTINCT_DOMAIN_SCHEMAS:
      (if $domain_documents<3 then unknown_fact("DOMAIN_DOCUMENT_UNAVAILABLE";"PROVIDE_ALL_DOMAIN_DOCUMENTS") elif ($schemas|length)==3 then closed_fact else refuted_fact("DOMAIN_SCHEMA_DIVERSITY_MISMATCH";"PRESERVE_DISTINCT_DOMAIN_SCHEMAS") end),
    COMMON_CORE_RELEASE:
      (if $core_support==3 then closed_fact elif $domain_documents<3 then unknown_fact("CORE_RELEASE_EVIDENCE_UNAVAILABLE";"PROVIDE_CORE_RELEASE_IDENTITIES") else refuted_fact("COMMON_CORE_RELEASE_IDENTITY_MISMATCH";"RESTORE_COMMON_CORE_RELEASE") end),
    IDENTITY_ANCHOR_CARDINALITY:
      (if $anchors==[1,1,1] then closed_fact elif any($anchors[];.==null) then unknown_fact("IDENTITY_ANCHOR_EVIDENCE_UNAVAILABLE";"PROVIDE_IDENTITY_ANCHOR_COUNTS") else refuted_fact("IDENTITY_ANCHOR_CARDINALITY_MISMATCH";"DECLARE_ONE_IDENTITY_ANCHOR_PER_DOMAIN") end),
    FIXED_CELL_DENOMINATORS:
      (if $cell_totals==[12,12,12] then closed_fact elif any($cell_totals[];.==null) then unknown_fact("CELL_DENOMINATOR_EVIDENCE_UNAVAILABLE";"PROVIDE_CELL_DENOMINATORS") else refuted_fact("CELL_DENOMINATOR_MISMATCH";"PRESERVE_DOMAIN_CELL_DENOMINATORS") end),
    INDICATOR_CLASS_DENOMINATORS:
      (if $local_indicators==[3,5,4] and $design_indicators==[3,5,4] and $infra_indicators==[3,5,4] then closed_fact elif any([$local_indicators,$design_indicators,$infra_indicators][];any(.[];.==null)) then unknown_fact("INDICATOR_CLASS_EVIDENCE_UNAVAILABLE";"PROVIDE_INDICATOR_CLASS_DENOMINATORS") else refuted_fact("INDICATOR_CLASS_DENOMINATOR_MISMATCH";"PRESERVE_OBSERVED_INDICATOR_TOTALS") end),
    ZERO_REPOSITORY_WRITES:
      (if $writes==[0,0,0] then closed_fact elif any($writes[];.==null) then unknown_fact("REPOSITORY_EFFECT_EVIDENCE_UNAVAILABLE";"PROVIDE_REPOSITORY_EFFECT_RECEIPTS") else refuted_fact("REPOSITORY_WRITE_EFFECT_OBSERVED";"REMOVE_SOURCE_REPOSITORY_WRITES") end),
    DEGRADED_CLAIM_TUPLES:
      (if ($claims|length)==13 and $complete_claim_tuples==13 and $unknown_domain_support==3 and $refuted_domain_support==3 then closed_fact elif ($claims|length)<13 then unknown_fact("DEGRADED_CLAIM_EVIDENCE_UNAVAILABLE";"PROVIDE_DEGRADED_CLAIM_EVIDENCE") else refuted_fact("DEGRADED_CLAIM_TUPLE_INCOMPLETE";"RESTORE_REQUIRED_UNKNOWN_FIELDS") end),
    PRESERVED_VARIATIONS:
      (if $local_proofs==[4,4,4] and $design_proofs==[4,5,3] and $infra_proofs==[4,6,2] and ($schemas|length)==3 and ($key_shapes|length)==2 then closed_fact else refuted_fact("DOMAIN_VARIATION_MISMATCH";"PRESERVE_PROOF_AND_ENVELOPE_VARIATIONS") end),
    CONNECTOR_PROMOTION_DECISION:
      (if $machine_replays==3 and $canonical_adoptions==3 then closed_fact else unknown_fact("PUBLIC_PROMOTION_EVIDENCE_INCOMPLETE";"PUBLISH_CANONICAL_ENVELOPE_AND_REPLAY_RECEIPTS") + {details:[{id:"machine-readable-replay",observed:$machine_replays,required:3},{id:"canonical-envelope-adoption",observed:$canonical_adoptions,required:3}]} end)
  }) as $facts |
  (reduce $d.cells[] as $cell
    ({cells:[],decisions:{}};
      . as $acc |
      (core_resolution_fact($cell)) as $resolution |
      ([$cell.depends_on[]? | $acc.decisions[.]]) as $dependencies |
      ($facts[$cell.id]) as $fact |
      (if $resolution.state!="CLOSED" then $resolution
       elif any($dependencies[];.state=="REFUTED") then {state:"REFUTED",reason:"DEPENDENCY_REFUTED",next_operation:"RESOLVE_REFUTED_PREDECESSORS",unknown_class:null,resolution:"EXACT",blocked_by:[$dependencies[]|select(.state=="REFUTED")|.cell_id]}
       elif any($dependencies[];.state=="UNKNOWN") then {state:"UNKNOWN",reason:"DEPENDENCY_BLOCKED",next_operation:"RESOLVE_UNKNOWN_PREDECESSORS",unknown_class:"DEPENDENCY_BLOCKED",resolution:"PREREQUISITE_CLASS",blocked_by:[$dependencies[]|select(.state=="UNKNOWN")|.cell_id]}
       elif $fact.state!="CLOSED" then $fact
       else {state:"CLOSED",reason:$cell.closed_reason,next_operation:"NONE",unknown_class:null,resolution:"EXACT",blocked_by:[]} end) as $decision |
      ($decision + {cell_id:$cell.id,stage:($decision.stage//$cell.stage),step:($decision.step//$cell.step)}) as $indexed |
      .cells += [$cell + $indexed + {core_resolution:{state:$resolution.state,decision:($resolution.core_decision//null),activity_occurrences:($resolution.activity_occurrences//null),stage:$resolution.stage,step:$resolution.step,reason:$resolution.reason,next_operation:$resolution.next_operation,unknown_class:$resolution.unknown_class}}] |
      .decisions[$cell.id]=$indexed
    )) as $evaluation |
  ([$evaluation.cells[]|select(.state=="CLOSED")]|length) as $closed |
  ([$evaluation.cells[]|select(.state=="UNKNOWN")]|length) as $unknown |
  ([$evaluation.cells[]|select(.state=="REFUTED")]|length) as $refuted |
  ([$evaluation.cells[]|select(.unknown_class=="DIRECT_MISSING")]|length) as $direct_missing |
  ([$evaluation.cells[]|select(.unknown_class=="DEPENDENCY_BLOCKED")]|length) as $dependency_blocked |
  ([$evaluation.cells[]|select(.state!="CLOSED")][0]//null) as $first_nonclosed |
  {
    schema:"gooo/link/three-domain-envelope-observation/v1",scenario:$scenario,subject_sha:$subject_sha,
    decision:(if $refuted>0 then "FAIL_CLOSED" elif $unknown>0 then "INCOMPLETE" else "INTERCHANGE_CANDIDATE_OBSERVED" end),
    claim:{state:(if $refuted>0 then "REFUTED" elif $unknown>0 then "UNKNOWN" else "CLOSED" end),stage:($first_nonclosed.stage//null),step:($first_nonclosed.step//null),
      reason:($first_nonclosed.reason//"INTERCHANGE_CANDIDATE_OBSERVATION_CLOSED"),next_operation:($first_nonclosed.next_operation//"NONE"),unknown_class:($first_nonclosed.unknown_class//null),blocked_by:($first_nonclosed.blocked_by//[]),details:($first_nonclosed.details//[])},
    summary:{total:12,closed:$closed,unknown:$unknown,refuted:$refuted,direct_missing:$direct_missing,dependency_blocked:$dependency_blocked,domains:$domain_documents,selected_assets:$selected_assets,verified_assets:$verified_assets,degraded_scenarios:($claims|length)},
    repeated_relations:{core_release:{observed:$core_support,total:3},identity_anchor_one:{observed:([$anchors[]|select(.==1)]|length),total:3},fixed_cells_twelve:{observed:([$cell_totals[]|select(.==12)]|length),total:3},
      indicator_split_3_5_4:{observed:([$local_indicators,$design_indicators,$infra_indicators]|map(select(.==[3,5,4]))|length),total:3},zero_repository_writes:{observed:([$writes[]|select(.==0)]|length),total:3},unknown_state_domain_support:{observed:$unknown_domain_support,total:3},refuted_state_domain_support:{observed:$refuted_domain_support,total:3}},
    preserved_variations:{proof_totals:{local_ledger:$local_proofs,design_evidence:$design_proofs,infra_evidence:$infra_proofs},schema_ids:$schemas,top_level_key_shapes:($key_shapes|length),selected_asset_counts:[$releases[0].consumers[].selected_assets]},
    promotion:{state:(if $machine_replays==3 and $canonical_adoptions==3 then "ELIGIBLE" else "UNKNOWN" end),domains:{observed:$domain_documents,required:3},degraded_state_domain_support:{unknown:$unknown_domain_support,refuted:$refuted_domain_support,required:3},
      machine_readable_replay:{observed:$machine_replays,required:3},canonical_envelope_adoption:{observed:$canonical_adoptions,required:3},next_operation:(if $machine_replays==3 and $canonical_adoptions==3 then "IMPLEMENT_ADVISORY_CONNECTOR" else "PUBLISH_CANONICAL_ENVELOPE_AND_REPLAY_RECEIPTS" end)},
    authority:{consumer_inputs:"PINNED_IMMUTABLE_RELEASE_ASSETS",current_branch_inputs:0,cross_project_required_gates:0,language_wide_improvement:"NOT_CLAIMED",connector_implementation:"NOT_STARTED"},
    proofs:[$d.proof_totals[] as $proof|{choice:$proof.proof_choice,closed:([$evaluation.cells[]|select(.proof_choice==$proof.proof_choice and .state=="CLOSED")]|length),total:$proof.total}],
    indicator_classes:[$d.indicator_totals[] as $indicator|{class:$indicator.indicator_class,closed:([$evaluation.cells[]|select(.indicator_class==$indicator.indicator_class and .state=="CLOSED")]|length),total:$indicator.total}],
    degraded_claims:$claims,cells:$evaluation.cells
  }
' > "$output"
