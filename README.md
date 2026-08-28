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
