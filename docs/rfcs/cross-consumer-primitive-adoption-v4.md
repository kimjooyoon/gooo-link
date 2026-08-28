# RFC: Fifth cross-consumer primitive adoption

Status: Experimental observation-only accumulation

## Decision

Link observes the independently released Workgraph v0.3 claim-resolution
adoption. The fixed mapping count advances from 4/30 to 5/30, remaining work
changes from 26 to 25, and independently released consumers change from 3 to
4. These are integer transitions over immutable release reports.

Workgraph was already released before Link observed it. Workgraph has no Link
branch, source, workflow, or current-status dependency.

## Meta binding

Twelve denominator cells name twelve activities in
`examples/cross-consumer-primitive-adoption-v4/main.gooo`. Released Gooo must
resolve each activity exactly once. The candidate primitive identity is an
explicit Gooo entity. FOUNDATION, COHERENCE, and REGRESSION each own 4/12
cells; DRIVER, OUTCOME, and GUARDRAIL each own 4/12 cells.

## Workgraph evidence observed

- direct mapping: 1/1
- adoption cells: 12/12
- scenarios: 3/3
- released and core fields: 18/18 and 18/18
- workspace inventory facts: 9/9
- invalid tuples rejected: 2/2
- Workgraph meta activities: 12/12
- adverse paths: 2 UNKNOWN and 3 REFUTED

Selecting either Workgraph UNKNOWN report keeps Link at the 4/30 baseline and
copies stage, step, reason, unknown class, and next operation into four
dependent cells. Selecting a Workgraph REFUTED report also keeps the baseline
and preserves the contradiction.

## Authority boundary

Common generator authority, generator authority, and central orchestration
authority are false. Cross-project required gates, local tests, repository
writes, and local Go module roots are zero. Root README readiness is excluded.
Link observes release assets but cannot mutate or authorize Workgraph.

## Human-readable evidence

CI reports the 5/30 count, 25 remaining mappings, four independent consumers,
all Workgraph denominators and adverse paths, graph RSS and wall time,
repository files and descendant directories, and per-file Go and Gooo lines.
