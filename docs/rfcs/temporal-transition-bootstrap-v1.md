# Temporal transition bootstrap v1

## Scope

This is the foundation bootstrap for an immutable `PREDECLARE` to
`CONSUME_ONCE` transition ticket. It is the first consumer of the immutable
`gooo-evidence-generator v0.6.1-dev` evidence release. The release is pinned
by release ID, immutable flag, annotated tag object, target commit, both asset
IDs, sizes, and SHA-256 digests in
`contracts/temporal-transition-bootstrap-release-lock-v1.json`.

The workflow revalidates that release on every pull request and main push. It
also downloads the external conformer scripts from the pinned target commit
and checks each downloaded file against its pinned Git blob SHA. The consumer
does not copy or modify the conformer implementation.

## Ticket protocol

`PREDECLARE` freezes the predecessor main commit, immutable predecessor
artifact and report digests, proposal digest, expected pull-request tree
digest, target branch, policy digest, Go/conformer toolchain digest, workflow
digest, proof choice, expiry policy, expiry instant, nonce, and ticket ID.
The successor commit SHA is intentionally late. On a protected main push,
`CONSUME_ONCE` accepts exactly one typed squash receipt:

`SQUASH_COMMIT_TO_EXPECTED_TREE`

The receipt must bind the merged commit and merged tree digest to the
predeclared expected tree. The workflow records a successor observation with
the consumed ticket digest and nonce. A second consume attempt with the same
nonce is `REFUTED`.

The transition precedence is `REFUTED > UNKNOWN > CLOSED`. Missing or stale
evidence remains `UNKNOWN` with its class, coordinates, next operation, and
causal frontier. Unknown top-level decisions, wrong tree/policy/toolchain or
workflow bindings, consume-before-prepare, replay, digest laundering,
retroactive closure, and authority escalation fail closed.

## Fixed denominator

Every case runs the same 12 released activity bindings. The denominator is
fixed at 12 cells, with proof distribution `FOUNDATION 4 / COHERENCE 4 /
REGRESSION 4` and indicator distribution `DRIVER 4 / OUTCOME 4 / GUARDRAIL
4`. This bootstrap transition itself declares `FOUNDATION`; the ordinary
follow-up route is not widened by this protocol and must use `COHERENCE` only
after bootstrap main success.

The pull-request run exercises normal, missing, stale, dependency-blocked,
mismatch, replay, laundering, unknown-decision, post-hoc, retroactive, and
authority cases through the external conformer. The main-push run consumes
the actual PR artifact ticket once and then records the replay refusal.

## Authority and non-claims

The workflow writes only caller-owned temporary output and uploaded evidence.
It performs no source-repository writes, local tests, builds, releases,
deployments, or automatic merges. GitHub Actions is the only validation
environment. External utility and performance improvement remain `UNKNOWN`
because this bootstrap supplies neither independent utility evidence nor a
comparable before/after performance pair.

The historical `meta-ontology-go` failures are not retroactively closed.
They remain outside this ticket's authority and are represented only by the
explicit predecessor policy boundary.
