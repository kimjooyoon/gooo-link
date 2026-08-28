# Gooo Link

Gooo Link is a digest-bound evidence exchange protocol for independent Gooo
projects. It is not a package manager, build system, central coordinator, or
cross-project semantic equivalence prover.

The protocol has three public wire artifacts:

- `gooo/link/project-manifest/v1`
- `gooo/link/evidence/v1` as NDJSON records
- `gooo/link/compatibility-claim/v1`

Each project owns its source, release, evidence, and cadence. A link may name
another project only by an immutable release identity and content digest. It
never requires a sibling checkout, branch, CI status, or internal Go package.

## Closed example

The first conformance case connects two separately released consumers:

- [Gooo Workgraph v0.1.0-dev](https://github.com/kimjooyoon/gooo-workgraph/releases/tag/v0.1.0-dev)
- [Gooo Design Evidence v0.1.0-dev](https://github.com/kimjooyoon/gooo-design-evidence/releases/tag/v0.1.0-dev)

CI downloads their public release assets and the released Gooo
`v0.1.0-dev` CLI. It does not clone either project or the compiler source.

The immutable denominator has exactly twelve cells:

| Cell | Proof choice |
|---|---|
| WIRE_SHAPE | FOUNDATION |
| INDEPENDENT_BOUNDARY | FOUNDATION |
| PUBLIC_RELEASE_LOCK | FOUNDATION |
| DIGEST_COVERAGE | FOUNDATION |
| RELEASED_CLI_ONLY | FOUNDATION |
| SOURCE_BINDING | COHERENCE |
| ARTIFACT_PROVENANCE | COHERENCE |
| READ_ONLY_EFFECT | REGRESSION |
| REPLAY_STABILITY | REGRESSION |
| COMPATIBILITY_CLAIM | COHERENCE |
| OPTIONAL_EVIDENCE | COHERENCE |
| FAILURE_ISOLATION | REGRESSION |

The normal transition is `10/12 CLOSED, 2 UNKNOWN` to `12/12 CLOSED`. The
remaining cells close only after CI observes byte-identical replay and proves
that removing one required Workgraph asset leaves the independent Design
Evidence claim closed.

## Decision model

- `CLOSED`: the exact evidence required by a cell was observed.
- `UNKNOWN`: evidence is absent, stale, ambiguous, or unsupported. The report
  preserves `stage`, `step`, `reason`, and `next_operation`.
- `REFUTED`: an observed identity, digest, schema, or predicate contradicts
  the claim.
- `NOT_CLAIMED`: a capability such as signatures or cross-project semantic
  equivalence is outside this protocol and is never counted as success.

`REFUTED` has priority over `UNKNOWN`; neither is converted to a score.

## Non-claims

- No source-span binding is claimed because `gooo-graph/v1` does not expose it.
- No publisher signature is claimed by this development release.
- No cross-project semantic equivalence is inferred.
- No generator is part of `gooo/link/v1`.

See [the v1 RFC](docs/rfcs/link-v1.md).

## Implementation queue observation

The optional implementation queue observer binds the repository's open
implementation PR count to 12 released Gooo activities. It emits an exact
receipt for the target repository, candidate, observed cardinality, maximum,
and next queue operation.

- `0` open implementation PRs selects `SELECT_NEXT_CANDIDATE`.
- `1` selects `MERGE_OR_CLOSE_CURRENT_IMPLEMENTATION_PR`.
- More than `1` is REFUTED with `IMPLEMENTATION_PR_LIMIT_EXCEEDED`.
- An unavailable GitHub snapshot remains typed UNKNOWN and lowers dependent
  resolution instead of inventing a count.

The observer is read-only, has zero cross-project required gates, and does not
rank candidate value. See [the queue RFC](docs/rfcs/implementation-queue-v1.md).

## Independent product portfolio

The portfolio observation is intentionally smaller than a package registry or
central orchestrator. Each product remains independently releasable and Link
only consumes immutable public evidence.

- Workgraph workspace inventory: `1/3` observed by its own adoption path.
- Design/code relation matcher: the second product, observed from
  [`gooo-design-evidence v0.5.0-dev`](https://github.com/kimjooyoon/gooo-design-evidence/releases/tag/v0.5.0-dev).
- Infrastructure/service evidence linker: the third product, observed from
  [`gooo-infra-evidence v0.5.0-dev`](https://github.com/kimjooyoon/gooo-infra-evidence/releases/tag/v0.5.0-dev).
- Exact portfolio progress after all three observations: `3/3`.
- Central orchestrator authorized: `false`.
- Common generator authorized: `false`.
- Generator authority evaluation required: `true`.
- Cross-project required gates: `0`.

The design observation preserves relation-level `MATCH`, `UNKNOWN`, and
`MISMATCH` separately from the aggregate claim. A reviewed mismatch may remain
visible while the aggregate is closed; missing evidence lowers resolution to a
typed UNKNOWN; an unresolved contradiction refutes the claim. See
[the design product adoption RFC](docs/rfcs/design-product-adoption-v1.md).

The infrastructure observation binds a HashiCorp HCL syntax-tree receipt to
the released Gooo activity graph and the captured declaration, plan, state,
OpenAPI, Go symbol, artifact, deployment, and runtime chain. Reaching `3/3`
selects a separate generator-authority evaluation; it does not make the
portfolio a central build gate. See
[the infrastructure product adoption RFC](docs/rfcs/infra-product-adoption-v1.md).
