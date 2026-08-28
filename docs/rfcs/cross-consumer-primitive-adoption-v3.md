# RFC: Fourth cross-consumer primitive adoption

Status: Experimental observation-only accumulation

## Decision

Link observes the independently released Infra Evidence v0.6 adoption and
advances the fixed claim-resolution mapping denominator from 3/30 to 4/30.
The remaining count changes from 27 to 26, and independently released consumer
adoptions change from 2 to 3. These are integer transitions, not estimates.

The observer does not make the Infra release depend on Link. Link consumes only
immutable public assets after Infra has already passed its own CI and release.

## Meta binding

Twelve denominator cells name twelve activities in
`examples/cross-consumer-primitive-adoption-v3/main.gooo`. The released Gooo
graph must resolve every activity exactly once. The candidate identity is also
present in a Gooo entity. A score detached from this graph cannot close.

Munchausen choices are FOUNDATION 4, COHERENCE 4, and REGRESSION 4. Indicator
classes are DRIVER 4, OUTCOME 4, and GUARDRAIL 4.

## Infra evidence observed

- Infra direct mapping: 1/1
- normal adoption cells: 12/12
- released scenarios: 3/3
- released claim fields: 18/18
- core claim fields: 18/18
- invalid tuples rejected: 2/2
- Infra meta activities: 12/12
- adverse paths: 1 UNKNOWN and 2 REFUTED

If the selected Infra report is UNKNOWN, Link keeps the baseline at 3/30 and
copies the child's stage, step, reason, unknown class, and next operation into
four dependent cells. A child REFUTED report is likewise preserved rather than
converted into a successful mapping.

## Independence boundary

Common generator authority and central orchestration authority are false.
Cross-project required gates, local tests, module-root `go fix` executions, and
repository writes are zero. Root README readiness is excluded. Link may observe
another release, but it cannot authorize, mutate, or block that product.

## Human-readable evidence

CI reports the 4/30 mapping count, 26 remaining mappings, all fixed
denominators, graph RSS and wall time, repository files and descendant
directories, and total and per-file Go and Gooo line counts.
