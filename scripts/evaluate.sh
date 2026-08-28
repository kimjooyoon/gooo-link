#!/usr/bin/env bash
set -euo pipefail

if test "$#" -ne 9; then
  echo "usage: evaluate.sh ROOT RELEASES ASSETS RUNTIME ISOLATION REPLAY OUTPUT HEAD_SHA PHASE" >&2
  exit 2
fi

root=$1
releases=$2
assets_root=$3
runtime=$4
isolation=$5
replay=$6
output=$7
head_sha=$8
phase=$9

denominator="$root/contracts/link-conformance-denominator-v1.json"
core_lock="$root/contracts/core-release-lock-v1.json"
project_locks="$root/contracts/project-release-locks-v1.json"
authority="$root/examples/two-consumer-link/main.gooo"

for file in \
  "$denominator" "$core_lock" "$project_locks" "$authority" \
  "$root/schemas/project-manifest-v1.schema.json" \
  "$root/schemas/evidence-v1.schema.json" \
  "$root/schemas/compatibility-claim-v1.schema.json" \
  "$releases" "$runtime" "$isolation" "$replay"; do
  test -f "$file" || { echo "missing required input: $file" >&2; exit 2; }
done

digest_file() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print "sha256:" $1}';
  else shasum -a 256 "$1" | awk '{print "sha256:" $1}'; fi
}

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

jq -s '.' \
  "$root/fixtures/workgraph/project-manifest.json" \
  "$root/fixtures/design-evidence/project-manifest.json" > "$work/manifests.json"
jq -s '.' \
  "$root/fixtures/workgraph/compatibility-claim.json" \
  "$root/fixtures/design-evidence/compatibility-claim.json" > "$work/compatibility.json"
cat "$root/fixtures/workgraph/evidence.ndjson" "$root/fixtures/design-evidence/evidence.ndjson" | jq -s '.' > "$work/evidence.json"

jq -n '{schema:"gooo/link/asset-observations/v1",projects:[]}' > "$work/assets.json"
while IFS=$'\t' read -r key name expected_digest expected_size; do
  path="$assets_root/$key/$name"
  if test -f "$path"; then
    actual_digest=$(digest_file "$path")
    actual_size=$(wc -c < "$path" | tr -d ' ')
    available=true
  else
    actual_digest=""
    actual_size=0
    available=false
  fi
  jq \
    --arg key "$key" \
    --arg name "$name" \
    --arg expected_digest "$expected_digest" \
    --arg actual_digest "$actual_digest" \
    --argjson expected_size "$expected_size" \
    --argjson actual_size "$actual_size" \
    --argjson available "$available" \
    '.projects += [{key:$key,name:$name,expected_digest:$expected_digest,actual_digest:$actual_digest,expected_size:$expected_size,actual_size:$actual_size,available:$available}]' \
    "$work/assets.json" > "$work/assets.next.json"
  mv "$work/assets.next.json" "$work/assets.json"
done < <(jq -r '.projects[] | .key as $key | .assets[] | [$key,.name,.digest,.size] | @tsv' "$project_locks")

json_or_null() {
  path=$1
  destination=$2
  if test -f "$path" && jq -e . "$path" >/dev/null 2>&1; then
    cp "$path" "$destination"
  else
    printf 'null\n' > "$destination"
  fi
}

json_or_null "$assets_root/workgraph/workgraph-runtime.json" "$work/workgraph-runtime.json"
json_or_null "$assets_root/workgraph/workgraph-report.json" "$work/workgraph-report.json"
json_or_null "$assets_root/design-evidence/design-evidence-runtime.json" "$work/design-runtime.json"
json_or_null "$assets_root/design-evidence/design-evidence-report.json" "$work/design-report.json"

jq -n \
  --slurpfile denominator "$denominator" \
  --slurpfile core_lock "$core_lock" \
  --slurpfile project_locks "$project_locks" \
  --slurpfile releases "$releases" \
  --slurpfile runtime "$runtime" \
  --slurpfile isolation "$isolation" \
  --slurpfile replay "$replay" \
  --slurpfile manifests "$work/manifests.json" \
  --slurpfile compatibility "$work/compatibility.json" \
  --slurpfile evidence "$work/evidence.json" \
  --slurpfile assets "$work/assets.json" \
  --slurpfile workgraph_runtime "$work/workgraph-runtime.json" \
  --slurpfile workgraph_report "$work/workgraph-report.json" \
  --slurpfile design_runtime "$work/design-runtime.json" \
  --slurpfile design_report "$work/design-report.json" \
  --arg head_sha "$head_sha" \
  --arg phase "$phase" \
  --arg denominator_digest "$(digest_file "$denominator")" \
  --arg core_lock_digest "$(digest_file "$core_lock")" \
  --arg project_locks_digest "$(digest_file "$project_locks")" \
  --arg authority_digest "$(digest_file "$authority")" '
  def valid_digest: type == "string" and test("^sha256:[0-9a-f]{64}$");
  def valid_raw_digest: type == "string" and test("^[0-9a-f]{64}$");
  def asset_view($items): [$items[] | {name,digest,size}] | sort_by(.name);
  def activity_names: [$runtime[0].graph.nodes[]? | select(.kind == "Activity") | .name] | sort;
  def expected_activities: [$denominator[0].cells[].activity] | sort;
  def activity_binding_count: (expected_activities - (expected_activities - activity_names)) | length;
  def release_for($repo): $releases[0].projects[] | select(.repository == $repo);
  def lock_for($key): $project_locks[0].projects[] | select(.key == $key);
  def manifest_for($id): $manifests[0][] | select(.project.id == $id);
  def observations_for($key): [$assets[0].projects[] | select(.key == $key)];
  def project_assets_state($key):
    observations_for($key) as $items |
    if any($items[]; .available == false) then "UNKNOWN"
    elif any($items[]; .actual_digest != .expected_digest or .actual_size != .expected_size) then "REFUTED"
    else "CLOSED" end;
  def release_ok($key):
    lock_for($key) as $lock | release_for($lock.repository) as $release |
    $release.available == true and $release.tag == $lock.tag and
    $release.draft == $lock.draft and $release.prerelease == $lock.prerelease and
    $release.tag_object_type == "tag" and $release.tag_object_sha == $lock.tag_object_sha and
    $release.target_commit_sha == $lock.target_commit_sha and
    asset_view($release.assets) == asset_view($lock.assets);
  def core_release_ok:
    $releases[0].core as $release | $core_lock[0] as $lock |
    $release.available == true and $release.tag == $lock.tag and
    $release.draft == $lock.draft and $release.prerelease == $lock.prerelease and
    $release.tag_object_type == "tag" and $release.tag_object_sha == $lock.tag_object_sha and
    $release.target_commit_sha == $lock.target_commit_sha and
    asset_view($release.assets) == asset_view($lock.assets);
  def version_ok:
    $runtime[0].version.schema_version == $core_lock[0].schemas.version and
    $runtime[0].version.version == $core_lock[0].version and
    $runtime[0].version.status == $core_lock[0].status;
  def syntax_ok:
    $runtime[0].syntax_check.schema_version == $core_lock[0].schemas.check and
    $runtime[0].syntax_check.status == "ok" and ($runtime[0].syntax_check.diagnostics | length) == 0;
  def semantic_ok:
    $runtime[0].semantic_check.schema_version == $core_lock[0].schemas.check and
    $runtime[0].semantic_check.status == "ok" and
    ($runtime[0].semantic_check.semantic_hash | valid_raw_digest);
  def graph_ok:
    $runtime[0].graph.schema_version == $core_lock[0].schemas.graph and
    ($runtime[0].graph.source_digest | valid_raw_digest) and
    ($runtime[0].graph.ir.semantic_digest | valid_raw_digest) and
    ($runtime[0].graph.graph_hash | valid_raw_digest) and
    $runtime[0].source.digest == ("sha256:" + $runtime[0].graph.source_digest) and
    $runtime[0].semantic_check.semantic_hash == $runtime[0].graph.ir.semantic_digest and
    activity_names == expected_activities;
  def cli_receipt_count: ([version_ok,syntax_ok,semantic_ok,graph_ok] | map(select(. == true)) | length);
  def wire_shape_ok:
    $denominator[0].schema == "gooo/link/conformance-denominator/v1" and
    $denominator[0].target_cells == 12 and ($denominator[0].cells | length) == 12 and
    ($manifests[0] | length) == 2 and all($manifests[0][]; .schema == "gooo/link/project-manifest/v1") and
    ($compatibility[0] | length) == 2 and all($compatibility[0][]; .schema == "gooo/link/compatibility-claim/v1") and
    ($evidence[0] | length) == 4 and all($evidence[0][]; .schema == "gooo/link/evidence/v1") and
    ([$manifests[0][].project.id] | unique | length) == 2 and
    ([$evidence[0][].record_id] | unique | length) == 4;
  def independent_boundary_ok:
    $runtime[0].boundary.core_source_imports == 0 and
    $runtime[0].boundary.sibling_source_imports == 0 and
    $runtime[0].boundary.branch_dependencies == 0;
  def release_lock_count: ([core_release_ok,release_ok("workgraph"),release_ok("design-evidence")] | map(select(. == true)) | length);
  def all_assets_state:
    if any($assets[0].projects[]; .available == false) then "UNKNOWN"
    elif any($assets[0].projects[]; .actual_digest != .expected_digest or .actual_size != .expected_size) then "REFUTED"
    else "CLOSED" end;
  def source_binding_count:
    ([
      ((manifest_for("gooo://project/workgraph").source.digest == $workgraph_runtime[0].source.digest) and
       (manifest_for("gooo://project/workgraph").source.semantic_ir_digest == ("sha256:" + $workgraph_runtime[0].graph.ir.semantic_digest)) and
       (manifest_for("gooo://project/workgraph").source.graph_hash == ("sha256:" + $workgraph_runtime[0].graph.graph_hash)) and
       ($workgraph_runtime[0].subject_sha == lock_for("workgraph").target_commit_sha)),
      ((manifest_for("gooo://project/design-evidence").source.digest == ("sha256:" + $design_runtime[0].graph.source_digest)) and
       (manifest_for("gooo://project/design-evidence").source.semantic_ir_digest == ("sha256:" + $design_runtime[0].graph.ir.semantic_digest)) and
       (manifest_for("gooo://project/design-evidence").source.graph_hash == ("sha256:" + $design_runtime[0].graph.graph_hash)) and
       ($design_runtime[0].subject_sha == lock_for("design-evidence").target_commit_sha))
    ] | map(select(. == true)) | length);
  def project_evidence_state($key):
    lock_for($key) as $lock | manifest_for($lock.id) as $manifest |
    ($manifest.evidence_refs[] | select(.required == true)) as $required |
    ($evidence[0][] | select(.record_id == $required.id)) as $record |
    if project_assets_state($key) == "UNKNOWN" then "UNKNOWN"
    elif project_assets_state($key) == "REFUTED" then "REFUTED"
    elif $record.status != "CLOSED" then $record.status
    elif ($record.products[] | select(.asset == $required.asset) | .digest) != $required.digest then "REFUTED"
    else "CLOSED" end;
  def evidence_binding_count: ([project_evidence_state("workgraph"),project_evidence_state("design-evidence")] | map(select(. == "CLOSED")) | length);
  def compatibility_count:
    [$compatibility[0][] | select(
      .state == "CLOSED" and .gooo.version == $core_lock[0].version and
      .gooo.target_commit_sha == $core_lock[0].target_commit_sha and
      .gooo.schemas == $core_lock[0].schemas and
      all(.evidence_ids[]; . as $id | any($evidence[0][]; .record_id == $id))
    )] | length;
  def optional_link_count:
    [$manifests[0][] | select((.links | length) == 1 and .links[0].relation == "OPTIONAL_EVIDENCE" and .links[0].required == false and (.links[0].digest | valid_digest))] | length;
  def isolation_ok:
    $isolation[0].schema == "gooo/link/isolation-receipt/v1" and $isolation[0].observed == true and
    $isolation[0].affected_project == "gooo://project/workgraph" and $isolation[0].affected_state == "UNKNOWN" and
    $isolation[0].independent_project == "gooo://project/design-evidence" and $isolation[0].independent_state == "CLOSED" and
    $isolation[0].stage == "EVIDENCE" and $isolation[0].step == "VERIFY_REQUIRED_ASSET" and
    $isolation[0].reason == "REQUIRED_EVIDENCE_UNAVAILABLE" and ($isolation[0].scenario_report_digest | valid_digest);
  def replay_ok:
    $replay[0].schema == "gooo/link/replay-receipt/v1" and $replay[0].observed == true and
    $replay[0].equal == true and ($replay[0].first_digest | valid_digest) and
    $replay[0].first_digest == $replay[0].second_digest;
  def closed($cell): $cell + {state:"CLOSED",resolution:"EXACT",reason:$cell.closed_reason,next_operation:"NONE"};
  def unknown($cell;$reason;$next): $cell + {state:"UNKNOWN",resolution:"PREREQUISITE_CLASS",reason:$reason,next_operation:$next};
  def refuted($cell;$reason;$next): $cell + {state:"REFUTED",resolution:"EXACT",reason:$reason,next_operation:$next};
  def decide($cell):
    if $cell.id == "WIRE_SHAPE" then
      if wire_shape_ok then closed($cell) else refuted($cell;"WIRE_SHAPE_INVALID";"RESTORE_V1_WIRE_SHAPE") end
    elif $cell.id == "INDEPENDENT_BOUNDARY" then
      if independent_boundary_ok then closed($cell) else refuted($cell;"SOURCE_COUPLING_OBSERVED";"REMOVE_SOURCE_COUPLING") end
    elif $cell.id == "PUBLIC_RELEASE_LOCK" then
      if release_lock_count == 3 then closed($cell)
      elif any([$releases[0].core.available,$releases[0].projects[].available][]; . == false) then unknown($cell;$cell.unknown_reason;$cell.next_operation)
      else refuted($cell;"PUBLIC_RELEASE_IDENTITY_MISMATCH";"RESTORE_PINNED_RELEASE_IDENTITY") end
    elif $cell.id == "DIGEST_COVERAGE" then
      if all_assets_state == "CLOSED" then closed($cell)
      elif all_assets_state == "UNKNOWN" then unknown($cell;$cell.unknown_reason;$cell.next_operation)
      else refuted($cell;"PROJECT_RELEASE_ASSET_DIGEST_MISMATCH";"RESTORE_PINNED_PROJECT_ASSET") end
    elif $cell.id == "RELEASED_CLI_ONLY" then
      if cli_receipt_count == 4 and core_release_ok and
        $runtime[0].binary.checksum_verified == true and
        $runtime[0].binary.digest == ($core_lock[0].assets[] | select(.name == $core_lock[0].consumer.binary_asset) | .digest)
      then closed($cell)
      elif $runtime[0].available != true then unknown($cell;$cell.unknown_reason;$cell.next_operation)
      else refuted($cell;"RELEASED_CLI_RECEIPT_MISMATCH";"RESTORE_RELEASED_CLI_CONTRACT") end
    elif $cell.id == "SOURCE_BINDING" then
      if source_binding_count == 2 then closed($cell)
      elif any([$workgraph_runtime[0],$design_runtime[0]][]; . == null) then unknown($cell;$cell.unknown_reason;$cell.next_operation)
      else refuted($cell;"PROJECT_SOURCE_BINDING_MISMATCH";"RESTORE_PROJECT_SOURCE_BINDING") end
    elif $cell.id == "ARTIFACT_PROVENANCE" then
      if evidence_binding_count == 2 then closed($cell)
      elif any([project_evidence_state("workgraph"),project_evidence_state("design-evidence")][]; . == "REFUTED") then refuted($cell;"PROJECT_ARTIFACT_PROVENANCE_MISMATCH";"RESTORE_PROJECT_PROVENANCE")
      else unknown($cell;$cell.unknown_reason;$cell.next_operation) end
    elif $cell.id == "READ_ONLY_EFFECT" then
      if $runtime[0].repository.writes == 0 and $runtime[0].repository.before_digest == $runtime[0].repository.after_digest then closed($cell)
      elif $runtime[0].repository.writes == null then unknown($cell;$cell.unknown_reason;$cell.next_operation)
      else refuted($cell;"REPOSITORY_WRITE_EFFECT_OBSERVED";"REMOVE_INPUT_REPOSITORY_WRITES") end
    elif $cell.id == "REPLAY_STABILITY" then
      if replay_ok then closed($cell) else unknown($cell;$cell.unknown_reason;$cell.next_operation) end
    elif $cell.id == "COMPATIBILITY_CLAIM" then
      if compatibility_count == 2 then closed($cell) else refuted($cell;"COMPATIBILITY_CLAIM_MISMATCH";"RESTORE_EXACT_COMPATIBILITY_CLAIM") end
    elif $cell.id == "OPTIONAL_EVIDENCE" then
      if optional_link_count == 2 then closed($cell) else refuted($cell;"OPTIONAL_EVIDENCE_BECAME_REQUIRED";"RESTORE_OPTIONAL_LINK_POLICY") end
    elif $cell.id == "FAILURE_ISOLATION" then
      if isolation_ok then closed($cell) else unknown($cell;$cell.unknown_reason;$cell.next_operation) end
    else unknown($cell;"UNRECOGNIZED_CONFORMANCE_CELL";"IMPLEMENT_EXPLICIT_CELL_DECISION") end;
  ($denominator[0].cells | map(decide(.) | del(.closed_reason,.unknown_reason))) as $cells |
  ([$cells[] | select(.state == "CLOSED")] | length) as $closed_count |
  ([$cells[] | select(.state == "UNKNOWN")] | length) as $unknown_count |
  ([$cells[] | select(.state == "REFUTED")] | length) as $refuted_count |
  ([$cells[] | select(.state == "REFUTED")][0] // null) as $first_refuted |
  ([$cells[] | select(.state == "UNKNOWN")][0] // null) as $first_unknown |
  {
    schema:"gooo/link/conformance-report/v1",phase:$phase,subject_sha:$head_sha,
    decision:(if $refuted_count > 0 then "FAIL_CLOSED" elif $unknown_count > 0 then "INCOMPLETE" else "CONFORMANT" end),
    resolution:(if $refuted_count > 0 or $unknown_count == 0 then "EXACT" else "PREREQUISITE_CLASS" end),
    claim:{id:"gooo://claim/link-v1-conformance",
      state:(if $refuted_count > 0 then "REFUTED" elif $unknown_count > 0 then "UNKNOWN" else "CLOSED" end),
      status:(if $refuted_count > 0 then "CONTESTED" elif $unknown_count > 0 then "ACTIVE" else "DISCHARGED" end),
      stage:(if $refuted_count > 0 then $first_refuted.stage elif $unknown_count > 0 then $first_unknown.stage else null end),
      step:(if $refuted_count > 0 then $first_refuted.step elif $unknown_count > 0 then $first_unknown.step else null end),
      reason:(if $refuted_count > 0 then $first_refuted.reason elif $unknown_count > 0 then $first_unknown.reason else "LINK_V1_CONFORMANCE_CLOSED" end),
      next_operation:(if $refuted_count > 0 then $first_refuted.next_operation elif $unknown_count > 0 then $first_unknown.next_operation else "NONE" end)},
    summary:{total:12,closed:$closed_count,unknown:$unknown_count,refuted:$refuted_count,repository_writes:$runtime[0].repository.writes},
    cells:$cells,
    projects:[
      {id:"gooo://project/workgraph",state:project_evidence_state("workgraph"),stage:(if project_evidence_state("workgraph") == "UNKNOWN" then "EVIDENCE" elif project_evidence_state("workgraph") == "REFUTED" then "DIGEST" else null end),step:(if project_evidence_state("workgraph") == "UNKNOWN" then "VERIFY_REQUIRED_ASSET" elif project_evidence_state("workgraph") == "REFUTED" then "VERIFY_ASSET_DIGEST" else null end),reason:(if project_evidence_state("workgraph") == "UNKNOWN" then "REQUIRED_EVIDENCE_UNAVAILABLE" elif project_evidence_state("workgraph") == "REFUTED" then "PROJECT_RELEASE_ASSET_DIGEST_MISMATCH" else "PROJECT_EVIDENCE_BOUND" end),next_operation:(if project_evidence_state("workgraph") == "UNKNOWN" then "DOWNLOAD_PINNED_ASSET" elif project_evidence_state("workgraph") == "REFUTED" then "RESTORE_PINNED_PROJECT_ASSET" else "NONE" end)},
      {id:"gooo://project/design-evidence",state:project_evidence_state("design-evidence"),stage:(if project_evidence_state("design-evidence") == "UNKNOWN" then "EVIDENCE" elif project_evidence_state("design-evidence") == "REFUTED" then "DIGEST" else null end),step:(if project_evidence_state("design-evidence") == "UNKNOWN" then "VERIFY_REQUIRED_ASSET" elif project_evidence_state("design-evidence") == "REFUTED" then "VERIFY_ASSET_DIGEST" else null end),reason:(if project_evidence_state("design-evidence") == "UNKNOWN" then "REQUIRED_EVIDENCE_UNAVAILABLE" elif project_evidence_state("design-evidence") == "REFUTED" then "PROJECT_RELEASE_ASSET_DIGEST_MISMATCH" else "PROJECT_EVIDENCE_BOUND" end),next_operation:(if project_evidence_state("design-evidence") == "UNKNOWN" then "DOWNLOAD_PINNED_ASSET" elif project_evidence_state("design-evidence") == "REFUTED" then "RESTORE_PINNED_PROJECT_ASSET" else "NONE" end)}
    ],
    authority:{binding:"RELEASED_GOOO_GRAPH_ACTIVITY_SET",activity_bindings:activity_binding_count,activity_total:12,source_spans:"NOT_AVAILABLE",cross_project_semantic_equivalence:"NOT_CLAIMED",publisher_signatures:"NOT_CLAIMED",generation:"NOT_CLAIMED"},
    sources:{denominator_digest:$denominator_digest,core_lock_digest:$core_lock_digest,project_locks_digest:$project_locks_digest,authority_digest:$authority_digest},
    proofs:(["FOUNDATION","COHERENCE","REGRESSION"] | map(. as $proof | {choice:$proof,closed:([$cells[] | select(.proof_choice == $proof and .state == "CLOSED")] | length),total:([$cells[] | select(.proof_choice == $proof)] | length)})),
    indicators:[
      {id:"gooo.metric.link.conformance.v1",value:$closed_count,total:12,state:(if $closed_count == 12 then "SATISFIED" else "GAP" end),activity:"PreserveFailureIsolation"},
      {id:"gooo.metric.link.release-locks.v1",value:release_lock_count,total:3,state:(if release_lock_count == 3 then "SATISFIED" else "GAP" end),activity:"ObservePublicReleaseLocks"},
      {id:"gooo.metric.link.released-cli-receipts.v1",value:cli_receipt_count,total:4,state:(if cli_receipt_count == 4 then "SATISFIED" else "GAP" end),activity:"ExecuteReleasedCLI"},
      {id:"gooo.metric.link.activity-bindings.v1",value:activity_binding_count,total:12,state:(if activity_binding_count == 12 then "SATISFIED" else "GAP" end),activity:"BindSourceIdentity"},
      {id:"gooo.metric.link.project-evidence.v1",value:evidence_binding_count,total:2,state:(if evidence_binding_count == 2 then "SATISFIED" else "GAP" end),activity:"BindArtifactProvenance"},
      {id:"gooo.metric.link.required-assets.v1",value:([$assets[0].projects[] | select(.available and .actual_digest == .expected_digest and .actual_size == .expected_size)] | length),total:10,state:(if all_assets_state == "CLOSED" then "SATISFIED" elif all_assets_state == "REFUTED" then "REFUTED" else "UNKNOWN" end),activity:"VerifyDigestCoverage"},
      {id:"gooo.metric.link.compatibility-claims.v1",value:compatibility_count,total:2,state:(if compatibility_count == 2 then "SATISFIED" else "GAP" end),activity:"EvaluateCompatibilityClaim"},
      {id:"gooo.metric.link.optional-links.v1",value:optional_link_count,total:2,state:(if optional_link_count == 2 then "SATISFIED" else "GAP" end),activity:"IsolateOptionalEvidence"},
      {id:"gooo.metric.link.isolated-failures.v1",value:(if isolation_ok then 1 else 0 end),total:1,state:(if isolation_ok then "SATISFIED" else "UNKNOWN" end),activity:"PreserveFailureIsolation"},
      {id:"gooo.metric.link.repository-writes.v1",value:$runtime[0].repository.writes,total:1,state:(if $runtime[0].repository.writes == 0 then "SATISFIED" elif $runtime[0].repository.writes == null then "UNKNOWN" else "REFUTED" end),activity:"ObserveReadOnlyEffect"}
    ]
  }' > "$output"
