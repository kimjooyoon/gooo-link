#!/usr/bin/env bash
set -euo pipefail

if test "$#" -ne 9; then
  echo "usage: observe-released-adoptions.sh GRAPH CORE_RESOLUTIONS DENOMINATOR CORE_LOCK RELEASE_OBSERVATION INPUT_ROOT OUTPUT SUBJECT_SHA SCENARIO" >&2
  exit 64
fi
graph=$1; core_resolutions=$2; denominator=$3; core_lock=$4; release_observation=$5; input_root=$6; output=$7; subject_sha=$8; scenario=$9
for file in "$graph" "$core_resolutions" "$denominator" "$core_lock" "$release_observation"; do test -f "$file" || exit 66; done
work=$(mktemp -d); trap 'rm -rf "$work"' EXIT
json_or_null() { if test -f "$1" && jq -e . "$1" >/dev/null 2>&1; then cp "$1" "$2"; else printf 'null\n' > "$2"; fi; }
normalize_domain() {
  local id=$1 root=$2 out=$3 bundle_files=0 replay=false
  json_or_null "$root/adoption-report.json" "$work/$id-adoption.json"
  json_or_null "$root/conformance.json" "$work/$id-conformance.json"
  json_or_null "$root/invalid-unknown.json" "$work/$id-unknown.json"
  json_or_null "$root/checksum-mismatch.json" "$work/$id-checksum.json"
  json_or_null "$root/invalid-core-decision.json" "$work/$id-core.json"
  json_or_null "$root/runtime.json" "$work/$id-runtime.json"
  json_or_null "$root/bundle-a/project.json" "$work/$id-project.json"
  json_or_null "$root/bundle-a/relations.ndjson" "$work/$id-relation.json"
  if test -d "$root/bundle-a"; then bundle_files=$(find "$root/bundle-a" -mindepth 1 -maxdepth 1 -type f | wc -l | tr -d ' '); fi
  if test -d "$root/bundle-a" && test -d "$root/bundle-b"; then
    replay=true
    for file in checksums.txt conformance.json project.json relations.ndjson unknowns.ndjson; do cmp -s "$root/bundle-a/$file" "$root/bundle-b/$file" || replay=false; done
  fi
  jq -S -n --arg id "$id" --argjson bundle_files "$bundle_files" --argjson replay "$replay" \
    --slurpfile adoption "$work/$id-adoption.json" --slurpfile conformance "$work/$id-conformance.json" \
    --slurpfile invalid_unknown "$work/$id-unknown.json" --slurpfile checksum "$work/$id-checksum.json" \
    --slurpfile invalid_core "$work/$id-core.json" --slurpfile runtime "$work/$id-runtime.json" \
    --slurpfile project "$work/$id-project.json" --slurpfile relation "$work/$id-relation.json" '
    {id:$id,bundle_files:$bundle_files,replay_equal:$replay,adoption:$adoption[0],conformance:$conformance[0],invalid_unknown:$invalid_unknown[0],checksum:$checksum[0],invalid_core:$invalid_core[0],runtime:$runtime[0],project:$project[0],relation:$relation[0],scenario_documents:([$adoption[0],$invalid_unknown[0],$checksum[0],$invalid_core[0]]|map(select(.!=null))|length)}' > "$out"
}
normalize_domain local-ledger "$input_root/local-ledger" "$work/local.json"
normalize_domain design-evidence "$input_root/design-evidence" "$work/design.json"
normalize_domain infra-evidence "$input_root/infra-evidence" "$work/infra.json"

jq -S -n --slurpfile graph "$graph" --slurpfile core "$core_resolutions" --slurpfile denominator "$denominator" --slurpfile core_lock "$core_lock" --slurpfile releases "$release_observation" --slurpfile local "$work/local.json" --slurpfile design "$work/design.json" --slurpfile infra "$work/infra.json" --arg subject_sha "$subject_sha" --arg scenario "$scenario" '
  $denominator[0] as $d | $core_lock[0] as $lock | [$local[0],$design[0],$infra[0]] as $domains |
  def expected_core:{repository:$lock.repository,tag:$lock.tag,tag_object_sha:$lock.tag_object_sha,target_commit_sha:$lock.target_commit_sha,binary_asset:"gooo-linux-amd64.tar.gz",binary_sha256:($lock.assets[]|select(.name=="gooo-linux-amd64.tar.gz")|(.digest|sub("^sha256:";""))),resolution_schema:$lock.schemas.activity_cardinality_resolution};
  def closed_fact:{state:"CLOSED",reason:"FACT_OBSERVED",next_operation:"NONE",unknown_class:null,resolution:"EXACT",blocked_by:[]};
  def unknown_fact($reason;$next):{state:"UNKNOWN",reason:$reason,next_operation:$next,unknown_class:"DIRECT_MISSING",resolution:"PREREQUISITE_CLASS",blocked_by:[]};
  def refuted_fact($reason;$next):{state:"REFUTED",reason:$reason,next_operation:$next,unknown_class:null,resolution:"EXACT",blocked_by:[]};
  def core_resolution_fact($cell):
    if $core[0].core_release!=expected_core then refuted_fact("CORE_RELEASE_IDENTITY_MISMATCH";"RESTORE_PINNED_CORE_RELEASE")+{stage:"CORE_RELEASE",step:"BIND_CORE_RELEASE_IDENTITY"}
    else ([$core[0].receipts[]?|select(.selector.name?==$cell.activity)]) as $receipts |
      if ($receipts|length)==0 then unknown_fact("CORE_ACTIVITY_RESOLUTION_RECEIPT_UNAVAILABLE";"PROVIDE_CORE_ACTIVITY_RESOLUTION_RECEIPT")+{stage:"RESOLUTION",step:"RESOLVE_ACTIVITY_CARDINALITY"}
      elif ($receipts|length)>1 then refuted_fact("DUPLICATE_CORE_ACTIVITY_RESOLUTION_RECEIPT";"REMOVE_DUPLICATE_CORE_ACTIVITY_RESOLUTION_RECEIPT")+{stage:"RESOLUTION",step:"RESOLVE_ACTIVITY_CARDINALITY"}
      else $receipts[0] as $r |
        if $r.schema!="gooo/activity-cardinality-resolution/v1" or $r.selector.name!=$cell.activity or $r.subject.source_file!="examples/released-adoption-observation/main.gooo" then refuted_fact("INVALID_CORE_ACTIVITY_RESOLUTION_RECEIPT";"RESTORE_CORE_ACTIVITY_RESOLUTION_RECEIPT")+{stage:"RESOLUTION",step:"RESOLVE_ACTIVITY_CARDINALITY"}
        elif $r.decision=="CLOSED" and $r.claim.state=="CLOSED" and $r.occurrences==1 and $r.claim.reason=="ACTIVITY_UNIQUELY_RESOLVED" then closed_fact+{stage:"RESOLUTION",step:"RESOLVE_ACTIVITY_CARDINALITY",core_decision:$r.decision,activity_occurrences:$r.occurrences}
        elif $r.decision=="UNKNOWN" then unknown_fact(($r.claim.reason//"CORE_ACTIVITY_RESOLUTION_UNKNOWN");($r.claim.next_operation//"RESOLVE_CORE_ACTIVITY"))+{stage:"RESOLUTION",step:"RESOLVE_ACTIVITY_CARDINALITY",core_decision:$r.decision,activity_occurrences:($r.occurrences//0)}
        else refuted_fact("UNRECOGNIZED_CORE_ACTIVITY_RESOLUTION_DECISION";"RESTORE_CORE_ACTIVITY_RESOLUTION_RECEIPT")+{stage:"RESOLUTION",step:"RESOLVE_ACTIVITY_CARDINALITY",core_decision:($r.decision//null),activity_occurrences:($r.occurrences//null)} end
      end
    end;
  ($releases[0].consumers|length) as $release_count |
  ([$releases[0].consumers[]|select(.identity_verified==true)]|length) as $release_verified |
  ([$releases[0].consumers[]|select(.archive_verified==true)]|length) as $archives_verified |
  ([$domains[]|select(.adoption!=null)]|length) as $domain_documents |
  ([$domains[]|select(.bundle_files==5 and .project.schema=="gooo/interchange/project/v1" and .relation.schema=="gooo/interchange/relation/v1" and .project.domain==.id)]|length) as $canonical_bundles |
  ([$domains[]|select(.relation.right.kind=="gooo/interchange/specification-report/v1" and .relation.right.id=="gooo://interchange/specification/v0.1.0-dev" and .relation.evidence.expected_sha256==$releases[0].expected_specification_report_sha256 and .relation.evidence.observed_sha256==.relation.evidence.expected_sha256)]|length) as $spec_anchors |
  ([$domains[].relation|.left,.right]) as $endpoints |
  ([$endpoints[]|select((.kind|type)=="string" and (.id|type)=="string" and (.kind|length)>0 and (.id|length)>0)]|length) as $resolved_endpoints |
  (6-$resolved_endpoints) as $unknown_endpoints |
  ([$domains[]|select(.conformance.decision=="CONFORMANT" and .conformance.summary.closed==6 and .conformance.summary.total==6 and .conformance.summary.external_required_gates==0)]|length) as $conformant_bundles |
  ([$domains[]|select(.replay_equal==true and .runtime.deterministic_replay==true and ([.conformance.checks[]|select(.id=="DETERMINISTIC_REPLAY" and .state=="CLOSED")]|length)==1)]|length) as $replays |
  ([$domains[]|select(.invalid_unknown.decision=="FAIL_CLOSED" and .invalid_unknown.summary.refuted==1 and .invalid_unknown.claim.reason=="UNKNOWN_TUPLE_INCOMPLETE")]|length) as $unknown_guards |
  ([$domains[]|select(.checksum.decision=="FAIL_CLOSED" and .checksum.summary.refuted==1 and .checksum.claim.reason=="SHA256_CHECKSUM_MISMATCH")]|length) as $checksum_guards |
  ([$domains[]|select(.invalid_core.decision=="FAIL_CLOSED" and .invalid_core.claim.reason=="UNRECOGNIZED_CORE_ACTIVITY_RESOLUTION_DECISION")]|length) as $core_decision_guards |
  ([$domains[]|select(.adoption.adoption.state=="MAIN_MERGED" and .adoption.adoption.released_domain_adoption.observed==1)]|length) as $self_adoptions |
  ([$domains[]|select(.adoption.adoption.portfolio_adoption.state?=="UNKNOWN" and .adoption.adoption.portfolio_adoption.unknown_class?=="SCOPE_DEFERRED")]|length) as $portfolio_deferred |
  ([$domains[]|.scenario_documents]|add) as $scenarios |
  ([$domains[]|select(.adoption.summary.total==12 and .adoption.summary.closed==12)]|length) as $cell_denominators |
  ([$domains[]|select(.adoption.indicator_classes==[{class:"OUTCOME",closed:3,total:3},{class:"DRIVER",closed:5,total:5},{class:"GUARDRAIL",closed:4,total:4}])]|length) as $indicator_denominators |
  ([$domains[]|.adoption.cells[]?|select(.core_identity_anchor?==true and .state=="CLOSED")]|length) as $identity_anchors |
  ({
    RELEASED_GOOO_IDENTITY:(if $core[0].core_release==expected_core and $core[0].summary.closed==12 then closed_fact else refuted_fact("RELEASED_GOOO_IDENTITY_MISMATCH";"RESTORE_PINNED_GOOO_RELEASE") end),
    ADOPTION_RELEASE_IDENTITIES:(if $release_count==3 and $release_verified==3 then closed_fact elif $release_verified<3 then unknown_fact("ADOPTION_RELEASE_IDENTITIES_UNAVAILABLE";"FETCH_PINNED_ADOPTION_RELEASES") else refuted_fact("ADOPTION_RELEASE_IDENTITY_MISMATCH";"RESTORE_PINNED_ADOPTION_RELEASES") end),
    ADOPTION_ARCHIVE_DIGESTS:(if $archives_verified==3 then closed_fact elif $archives_verified<3 then unknown_fact("ADOPTION_ARCHIVE_DIGESTS_UNAVAILABLE";"DOWNLOAD_PINNED_ADOPTION_ARCHIVES") else refuted_fact("ADOPTION_ARCHIVE_DIGEST_MISMATCH";"RESTORE_PINNED_ADOPTION_ARCHIVES") end),
    CANONICAL_BUNDLES:(if $domain_documents<3 then unknown_fact("CANONICAL_BUNDLE_UNAVAILABLE";"PROVIDE_CANONICAL_BUNDLES") elif $canonical_bundles==3 then closed_fact else refuted_fact("CANONICAL_BUNDLE_MISMATCH";"RESTORE_CANONICAL_BUNDLES") end),
    SPECIFICATION_ANCHORS:(if $domain_documents<3 then unknown_fact("SPECIFICATION_ANCHOR_UNAVAILABLE";"PROVIDE_SPECIFICATION_ANCHORS") elif $spec_anchors==3 then closed_fact else refuted_fact("SPECIFICATION_ANCHOR_MISMATCH";"RESTORE_SPECIFICATION_ANCHORS") end),
    RELATION_ENDPOINTS:(if $domain_documents<3 then unknown_fact("RELATION_ENDPOINT_UNAVAILABLE";"PROVIDE_RELATION_ENDPOINTS") elif $resolved_endpoints==6 and $unknown_endpoints==0 then closed_fact else refuted_fact("RELATION_ENDPOINT_INCOMPLETE";"RESTORE_RELATION_ENDPOINTS") end),
    CONFORMANT_BUNDLES:(if $domain_documents<3 then unknown_fact("BUNDLE_CONFORMANCE_UNAVAILABLE";"PROVIDE_BUNDLE_CONFORMANCE") elif $conformant_bundles==3 then closed_fact else refuted_fact("BUNDLE_CONFORMANCE_MISMATCH";"RESTORE_BUNDLE_CONFORMANCE") end),
    DETERMINISTIC_REPLAYS:(if $domain_documents<3 then unknown_fact("DETERMINISTIC_REPLAY_UNAVAILABLE";"PROVIDE_REPLAY_RECEIPTS") elif $replays==3 then closed_fact else refuted_fact("DETERMINISTIC_REPLAY_MISMATCH";"RESTORE_REPLAY_RECEIPTS") end),
    UNKNOWN_GUARDS:(if $domain_documents<3 then unknown_fact("UNKNOWN_GUARD_UNAVAILABLE";"PROVIDE_UNKNOWN_GUARD_RECEIPTS") elif $unknown_guards==3 then closed_fact else refuted_fact("UNKNOWN_GUARD_MISMATCH";"RESTORE_UNKNOWN_GUARD_RECEIPTS") end),
    CHECKSUM_GUARDS:(if $domain_documents<3 then unknown_fact("CHECKSUM_GUARD_UNAVAILABLE";"PROVIDE_CHECKSUM_GUARD_RECEIPTS") elif $checksum_guards==3 then closed_fact else refuted_fact("CHECKSUM_GUARD_MISMATCH";"RESTORE_CHECKSUM_GUARD_RECEIPTS") end),
    DOMAIN_SCOPED_CLAIMS:(if $domain_documents<3 then unknown_fact("DOMAIN_SCOPED_CLAIM_UNAVAILABLE";"PROVIDE_DOMAIN_SCOPED_CLAIMS") elif $self_adoptions==3 and $scenarios==12 and $core_decision_guards==3 then closed_fact else refuted_fact("DOMAIN_SCOPED_CLAIM_MISMATCH";"RESTORE_DOMAIN_SCOPED_CLAIMS") end),
    CONNECTOR_PROMOTION:(if $release_verified==3 and $archives_verified==3 and $canonical_bundles==3 and $spec_anchors==3 and $resolved_endpoints==6 and $unknown_endpoints==0 and $conformant_bundles==3 and $replays==3 and $unknown_guards==3 and $checksum_guards==3 and $self_adoptions==3 and $scenarios>=6 then closed_fact else unknown_fact("CONNECTOR_PROMOTION_EVIDENCE_INCOMPLETE";"COMPLETE_CONNECTOR_PROMOTION_EVIDENCE") end)
  }) as $facts |
  (reduce $d.cells[] as $cell ({cells:[],decisions:{}};
    . as $acc | (core_resolution_fact($cell)) as $resolution | ([$cell.depends_on[]?|$acc.decisions[.]]) as $dependencies | ($facts[$cell.id]) as $fact |
    (if $resolution.state!="CLOSED" then $resolution
     elif any($dependencies[];.state=="REFUTED") then {state:"REFUTED",reason:"DEPENDENCY_REFUTED",next_operation:"RESOLVE_REFUTED_PREDECESSORS",unknown_class:null,resolution:"EXACT",blocked_by:[$dependencies[]|select(.state=="REFUTED")|.cell_id]}
     elif any($dependencies[];.state=="UNKNOWN") then {state:"UNKNOWN",reason:"DEPENDENCY_BLOCKED",next_operation:"RESOLVE_UNKNOWN_PREDECESSORS",unknown_class:"DEPENDENCY_BLOCKED",resolution:"PREREQUISITE_CLASS",blocked_by:[$dependencies[]|select(.state=="UNKNOWN")|.cell_id]}
     elif $fact.state!="CLOSED" then $fact else {state:"CLOSED",reason:$cell.closed_reason,next_operation:"NONE",unknown_class:null,resolution:"EXACT",blocked_by:[]} end) as $decision |
    ($decision+{cell_id:$cell.id,stage:($decision.stage//$cell.stage),step:($decision.step//$cell.step)}) as $indexed |
    .cells+=[ $cell+$indexed+{core_resolution:{state:$resolution.state,decision:($resolution.core_decision//null),activity_occurrences:($resolution.activity_occurrences//null),stage:$resolution.stage,step:$resolution.step,reason:$resolution.reason,next_operation:$resolution.next_operation,unknown_class:$resolution.unknown_class}} ] | .decisions[$cell.id]=$indexed)) as $evaluation |
  ([$evaluation.cells[]|select(.state=="CLOSED")]|length) as $closed | ([$evaluation.cells[]|select(.state=="UNKNOWN")]|length) as $unknown | ([$evaluation.cells[]|select(.state=="REFUTED")]|length) as $refuted |
  ([$evaluation.cells[]|select(.unknown_class=="DIRECT_MISSING")]|length) as $direct_missing | ([$evaluation.cells[]|select(.unknown_class=="DEPENDENCY_BLOCKED")]|length) as $dependency_blocked | ([$evaluation.cells[]|select(.state!="CLOSED")][0]//null) as $first |
  {schema:"gooo/link/released-adoption-observation/v1",scenario:$scenario,subject_sha:$subject_sha,decision:(if $refuted>0 then "FAIL_CLOSED" elif $unknown>0 then "INCOMPLETE" else "CONNECTOR_PROMOTION_ELIGIBLE" end),
   claim:{state:(if $refuted>0 then "REFUTED" elif $unknown>0 then "UNKNOWN" else "CLOSED" end),stage:($first.stage//null),step:($first.step//null),reason:($first.reason//"CONNECTOR_PROMOTION_ELIGIBLE"),next_operation:($first.next_operation//"IMPLEMENT_ADVISORY_CONNECTOR"),unknown_class:($first.unknown_class//null),blocked_by:($first.blocked_by//[])},
   summary:{total:12,closed:$closed,unknown:$unknown,refuted:$refuted,direct_missing:$direct_missing,dependency_blocked:$dependency_blocked,domains:$domain_documents,scenarios:$scenarios},
   observations:{release_identities:{observed:$release_verified,total:3},archives:{observed:$archives_verified,total:3},canonical_bundles:{observed:$canonical_bundles,total:3},specification_anchors:{observed:$spec_anchors,total:3},relation_endpoints:{resolved:$resolved_endpoints,unknown:$unknown_endpoints,total:6},conformant_bundles:{observed:$conformant_bundles,total:3},deterministic_replays:{observed:$replays,total:3},unknown_guards:{observed:$unknown_guards,total:3},checksum_guards:{observed:$checksum_guards,total:3},core_decision_guards:{observed:$core_decision_guards,total:3},self_adoptions:{observed:$self_adoptions,total:3},portfolio_scope_deferred:{observed:$portfolio_deferred,total:3},identity_anchors:{observed:$identity_anchors,total:3},cell_denominators:{observed:$cell_denominators,total:3},indicator_denominators:{observed:$indicator_denominators,total:3},scenarios:{observed:$scenarios,minimum:6}},
   promotion:{state:(if $closed==12 then "ELIGIBLE" else "UNKNOWN" end),next_operation:(if $closed==12 then "IMPLEMENT_ADVISORY_CONNECTOR" else "COMPLETE_CONNECTOR_PROMOTION_EVIDENCE" end),connector_implementation:"NOT_STARTED"},
   authority:{inputs:"PINNED_IMMUTABLE_RELEASE_ARCHIVES",current_branch_inputs:0,cross_project_required_gates:0,root_readme_readiness:"EXCLUDED",language_wide_improvement:"NOT_CLAIMED"},
   proofs:[$d.proof_totals[] as $p|{choice:$p.proof_choice,closed:([$evaluation.cells[]|select(.proof_choice==$p.proof_choice and .state=="CLOSED")]|length),total:$p.total}],indicator_classes:[$d.indicator_totals[] as $i|{class:$i.indicator_class,closed:([$evaluation.cells[]|select(.indicator_class==$i.indicator_class and .state=="CLOSED")]|length),total:$i.total}],cells:$evaluation.cells}' > "$output"
