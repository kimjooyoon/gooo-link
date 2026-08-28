#!/usr/bin/env bash
set -euo pipefail

locks=${1:?locks path is required}
output=${2:?output receipt path is required}
download_root=${3:?download root is required}

mkdir -p "$download_root"
release_rows="$download_root/releases.ndjson"
: > "$release_rows"

while IFS= read -r release_lock; do
  id=$(jq -r '.id' <<<"$release_lock")
  role=$(jq -r '.role' <<<"$release_lock")
  repository=$(jq -r '.repository' <<<"$release_lock")
  tag=$(jq -r '.tag' <<<"$release_lock")
  expected_tag_object=$(jq -r '.tag_object_sha' <<<"$release_lock")
  expected_target=$(jq -r '.target_commit_sha' <<<"$release_lock")
  expected_draft=$(jq -r '.draft' <<<"$release_lock")
  expected_prerelease=$(jq -r '.prerelease' <<<"$release_lock")
  release_dir="$download_root/$id"
  mkdir -p "$release_dir"

  release_json="$release_dir/release.json"
  ref_json="$release_dir/ref.json"
  tag_json="$release_dir/tag.json"
  gh api "repos/$repository/releases/tags/$tag" > "$release_json"
  gh api "repos/$repository/git/ref/tags/$tag" > "$ref_json"

  observed_tag_object=$(jq -r '.object.sha' "$ref_json")
  observed_tag_type=$(jq -r '.object.type' "$ref_json")
  test "$observed_tag_type" = tag
  test "$observed_tag_object" = "$expected_tag_object"
  gh api "repos/$repository/git/tags/$observed_tag_object" > "$tag_json"
  observed_target=$(jq -r '.object.sha' "$tag_json")
  observed_target_type=$(jq -r '.object.type' "$tag_json")
  test "$observed_target_type" = commit
  test "$observed_target" = "$expected_target"
  test "$(jq -r '.draft' "$release_json")" = "$expected_draft"
  test "$(jq -r '.prerelease' "$release_json")" = "$expected_prerelease"

  asset_rows="$release_dir/assets.ndjson"
  : > "$asset_rows"
  while IFS= read -r asset_lock; do
    kind=$(jq -r '.kind' <<<"$asset_lock")
    name=$(jq -r '.name' <<<"$asset_lock")
    expected_sha=$(jq -r '.sha256' <<<"$asset_lock")
    url=$(jq -r --arg name "$name" '.assets[] | select(.name == $name) | .browser_download_url' "$release_json")
    test -n "$url"
    curl --fail --location --retry 3 "$url" --output "$release_dir/$name"
    observed_sha=$(sha256sum "$release_dir/$name" | awk '{print $1}')
    test "$observed_sha" = "$expected_sha"
    jq -n \
      --arg kind "$kind" \
      --arg name "$name" \
      --arg sha256 "$observed_sha" \
      '{kind: $kind, name: $name, sha256: $sha256}' >> "$asset_rows"
  done < <(jq -c '.assets[]' <<<"$release_lock")

  assets=$(jq -s '.' "$asset_rows")
  jq -n \
    --arg id "$id" \
    --arg role "$role" \
    --arg repository "$repository" \
    --arg tag "$tag" \
    --arg tag_object_sha "$observed_tag_object" \
    --arg target_commit_sha "$observed_target" \
    --argjson draft "$expected_draft" \
    --argjson prerelease "$expected_prerelease" \
    --argjson assets "$assets" \
    '{id: $id, role: $role, repository: $repository, tag: $tag, tag_object_sha: $tag_object_sha, target_commit_sha: $target_commit_sha, draft: $draft, prerelease: $prerelease, assets: $assets}' >> "$release_rows"
done < <(jq -c '.releases[]' "$locks")

jq -s \
  --arg subject_sha "${GITHUB_SHA:-UNKNOWN}" \
  '{schema: "gooo/link/generator-consumer-release-observation/v1", subject_sha: $subject_sha, source_repository_writes: 0, releases: .}' \
  "$release_rows" > "$output"
