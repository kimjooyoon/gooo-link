# Cross-consumer claim-resolution need v1

## Decision

Observe one narrow candidate, `gooo.primitive.claim-resolution-tuple.v1`, without
claiming that a core primitive has been designed or implemented.

Three independent immutable consumer releases repeat the same report envelope and
the base claim fields `state`, `stage`, `step`, `reason`, and `next_operation`.
Their adversarial evidence also exposes all three states: `CLOSED`, `UNKNOWN`, and
`REFUTED`.

The typed UNKNOWN evidence is deliberately not flattened:

- infra evidence produces an UNKNOWN claim with `unknown_class=DIRECT_MISSING`;
- design evidence rejects an incomplete UNKNOWN tuple;
- local ledger produces UNKNOWN without `unknown_class`, exposing one compatibility
  gap rather than silently treating the outputs as identical.

## Exact denominator

- meta cells: 12
- independent consumer releases: 3
- common report envelopes: 3/3
- base claim tuple consumers: 3/3
- claim states observed: 3/3
- UNKNOWN-producing consumers: 2/2
- typed UNKNOWN evidence roles: 2/2
- compatibility gaps preserved: 1/1
- existing core experiments: 29
- direct candidate mappings: 0/29

The twelve cells bind one-to-one to twelve activities in
`examples/cross-consumer-primitive-need/main.gooo`. Proof choices are fixed at
FOUNDATION 4, COHERENCE 4, and REGRESSION 4. Indicator classes are fixed at DRIVER
6, OUTCOME 2, and GUARDRAIL 4.

## Authority boundary

This observation may select a need. It cannot select syntax, an implementation,
or a merge candidate. Existing experiment titles are not mapping evidence. A
mapping requires the exact candidate id in a Gooo source artifact and a matching
evidence receipt.

The next authorized operation is
`DEFINE_MINIMAL_CLAIM_RESOLUTION_CORE_CONTRACT`. Consumer repositories keep zero
required cross-project gates, and the observer writes to no consumer repository.

## Refutation

The observation fails closed when a pinned release is invalid, observation evidence
is escalated to implementation authority, a title-only experiment mapping is
introduced, or the observed local compatibility gap is laundered away.
