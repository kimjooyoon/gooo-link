# Sixth direct primitive adoption: claim dependency causality

## Decision

Link observes the independently released Core `v0.4.0-dev` command
`gooo claim dependencies <file.gooo> --json` and advances the fixed primitive
mapping count from 5/30 to 6/30. This is an observation of released behavior,
not authority over Core, a new independent consumer product, or a required
cross-project gate.

## Meta binding

The executable claim program lives in `program.gooo`. A separate
`observation.gooo` contains exactly twelve activities corresponding one-to-one
with the twelve denominator cells. FOUNDATION, COHERENCE, and REGRESSION own
4/12 cells each. DRIVER, OUTCOME, and GUARDRAIL own 4/12 cells each. Metrics
without these Gooo activity bindings do not receive adoption credit.

## Exact normal path

- previous mappings: 5/30
- mapping increment: 1
- current mappings: 6/30
- remaining mappings: 24/30
- independent consumer increment: 0
- Core release cases: 20/20
- Core release eligibility: 7/7
- claim activities: 6/6
- recoverable roots: 1
- typed declarations: 5
- dependency inputs and typed edges: 8/8
- edge kinds: 4
- requires, supports, contradicts, failure-entailment: 3, 2, 2, 1
- Core indicators: 8/8 satisfied

## Resolution paths

The missing-producer case stays `INCOMPLETE / UNKNOWN / DIRECT_MISSING` and
preserves stage, step, reason, unknown class, next operation, and blocked-by
coordinates. Unsupported kind, ambiguous producer, and cycle cases stay
`FAIL_CLOSED / REFUTED`. An UNKNOWN or REFUTED primary command result keeps the
mapping at 5/30 and propagates its exact resolution into dependent cells.

## Authority and user-visible evidence

Generator and central orchestration authority are false. Cross-project
required gates, local tests, repository writes, local Go module roots, and
independent consumer increment are zero. Root README readiness is excluded.
CI prints source inventory, per-file Go and Gooo lines, command peak RSS and
wall time, exact mapping arithmetic, normal denominators, and adverse paths.
