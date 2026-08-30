# RFC: Self-improvement causal chain v1

## Decision

The Gooo meta program declares one typed causal chain with seven fixed stages:

`OBSERVATION_RECEIPT -> COUNTEREXAMPLE_OR_UNKNOWN -> REVISION_PROPOSAL -> CONFORMANCE_RECEIPT -> HUMAN_DECISION -> MERGE_OR_DEFER_RECEIPT -> SUCCESSOR_OBSERVATION`

The generated `gooo-graph/v1` IR is the authority for the twelve meta
activities. The evaluator does not infer the chain from a sibling checkout,
branch state, or live CI state. Those values are not inputs to the chain.

Every edge carries the immutable producer identity, an exact release or run,
artifact digest, scenario, toolchain digest, and policy digest. An edge must
match the producer stage byte-for-byte at those coordinates. A changed digest
after receipt rebinding is digest laundering and is REFUTED.

## Decisions and uncertainty

The only top-level decisions are `CLOSED`, `UNKNOWN`, and `REFUTED`; any other
value is fail-closed and REFUTED. REFUTED has priority over UNKNOWN in a mixed
case. An UNKNOWN preserves these six coordinates:

`stage`, `step`, `reason`, `unknown_class`, `next_operation`, `blocked_by`

It also preserves the smallest `causal_frontier` that identifies the missing or
blocked predecessor. `FIXED_POINT` is not a general escape hatch; this v1
does not admit it in the normal policy. Unknown values remain UNKNOWN.

The fixed CI scenarios cover normal closure, missing observation, dependency-
blocked revision, stale conformance, ambiguous human decision, explicit
counterexample, digest laundering, unknown top-level decision, mixed
REFUTED-over-UNKNOWN, and authority/write escalation.

## Munchausen choices and authority

Each denominator cell names exactly one of `FOUNDATION`, `COHERENCE`, or
`REGRESSION`, four cells each. These are proof roles, not confidence weights;
the evaluator never lowers a denominator while running. The evaluator is
caller-owned and read-only: repository writes, local test executions,
cross-project required gates, automatic merge, release, and deploy authority
are all prohibited.

The fixture is synthetic. No public immutable receipt proves external utility
or a performance improvement, so those claims remain typed UNKNOWN.

## CI evidence

GitHub Actions uses the exact digest-locked released Gooo CLI and Go 1.27.
It publishes the generated IR, aggregate report, runtime receipt, synthetic
scenario inputs, and the exact artifact file count. Inventory excludes the
root README and records regular files, descendant directories, physical lines,
and Go/Gooo file and line totals.
