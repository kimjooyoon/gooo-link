# RFC: Workgraph Product Adoption Observation v1

Status: Experimental; only CI evidence can select or refute adoption.

## Decision

Gooo Link observes the immutable `gooo-workgraph v0.2.0-dev` release as the
first independently released product that uses Gooo meta activities to bind a
user-visible result. Link does not become a Workgraph build or release gate.

The observed product result is deliberately small: one read-only workspace
inventory with nested directory and file totals, per-file language and line
counts, typed UNKNOWN and REFUTED paths, deterministic replay, and a measured
resource envelope.

## Fixed denominator

The adoption denominator has exactly twelve cells. Proof choices are
FOUNDATION 4, COHERENCE 4, and REGRESSION 4. Indicator classes are DRIVER 4,
OUTCOME 4, and GUARDRAIL 4. Every cell is declared by one activity in
`examples/workgraph-product-adoption/main.gooo` and must occur exactly once in
the released Gooo semantic graph.

Closing all twelve cells proves only this Workgraph adoption. The independent
product portfolio denominator is three, so the truthful progress remains
`1/3`. It does not authorize a central generator or orchestrator.

## Immutable evidence

The release lock fixes the tag type and target, all six release asset IDs,
sizes, and SHA-256 digests. Evaluation consumes four direct assets: the
workspace report, complete per-file inventory, runtime observation, and Gooo
semantic graph. Branches, sibling checkouts, and unreleased source are not
evidence.

## Counterexamples

- A missing product report is UNKNOWN with one direct missing cell and two
  dependency-blocked cells: 9 CLOSED, 3 UNKNOWN.
- A changed Gooo line count is REFUTED at product evidence resolution.
- A missing Workgraph activity is REFUTED at meta binding.
- A non-zero required cross-project gate is REFUTED at the authority boundary.

None of these outcomes changes Workgraph source or blocks an unrelated
Workgraph, core, design, or infrastructure release.

## Next operation

After a valid adoption the only selected operation is
`OBSERVE_NEXT_INDEPENDENT_PRODUCT_RELEASE`. A common product generator remains
unauthorized until three independent products publish their own immutable
Gooo-bound user evidence.
