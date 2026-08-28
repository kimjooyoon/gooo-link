# RFC: Gooo Link v1

Status: Experimental, implemented by one two-consumer conformance case

## Decision

`gooo/link/v1` is a wire protocol for exchanging digest-bound evidence among
independently released Gooo projects. The protocol consists of a project
manifest, NDJSON evidence records, and explicit compatibility claims.

It is not a runtime service. No project must wait for another project's CI,
branch, source checkout, or release cadence. A missing optional reference does
not create a dependency edge.

## Identity

Mutable labels are not identity. Every consumed release is bound by repository,
exact tag, annotated tag object, target commit, complete asset name/size/digest
set, and the exact bytes consumed by the evaluator.

Core and project releases are separate locks. A valid core release does not
prove a project release, and one valid project release does not prove another.

## Evidence states

`CLOSED`, `UNKNOWN`, and `REFUTED` are decisions. `NOT_CLAIMED` marks an absent
capability and is never counted as success.

Every UNKNOWN preserves the stage, step, reason, and next operation that can
raise its resolution. Directly missing evidence and dependency-blocked evidence
must not be conflated. Every REFUTED state names the observed contradiction.

## Munchausen proof choices

- FOUNDATION fixes authorities, release identities, wire shapes, and bytes.
- COHERENCE verifies links among source, semantic IR, claims, and artifacts.
- REGRESSION requires a second observation for effects, replay, and isolation.

These choices are categories, not weights or confidence scores.

## Conformance

The v1 denominator is exactly twelve cells. The denominator file and the twelve
released Gooo `Activity` nodes must have identical activity sets. Text search is
not compiler-semantic evidence.

The initial report intentionally leaves REPLAY_STABILITY and FAILURE_ISOLATION
UNKNOWN. CI then removes a required Workgraph report. The Workgraph project
claim must become UNKNOWN at `EVIDENCE / VERIFY_REQUIRED_ASSET`, while the
Design Evidence claim remains CLOSED. That report closes FAILURE_ISOLATION.
Two byte-identical candidate evaluations close REPLAY_STABILITY.

A modified required asset is REFUTED at
`DIGEST / VERIFY_ASSET_DIGEST / PROJECT_RELEASE_ASSET_DIGEST_MISMATCH`.

## Read-only boundary

All public assets, compiler outputs, observations, scenarios, and reports are
written under the CI runner temporary directory. The checked-out repository is
snapshotted before and after execution. No zero-write claim exists without both
snapshots.

## Compatibility

Compatibility is exact in v1: Gooo version, target commit, and each consumed
wire schema must match the released receipts. An unknown schema major is
UNKNOWN, not an additive success inference.

## Non-claims

- Source spans are NOT_AVAILABLE in the released graph schema.
- Publisher signatures are NOT_CLAIMED.
- Cross-project semantic equivalence is NOT_CLAIMED.
- Generation is NOT_CLAIMED.
- SLSA, in-toto, SPDX, or other external compliance is NOT_CLAIMED.

Future versions may add optional authenticated provenance without changing the
independent release boundary.
