# RFC: Design Product Adoption Observation v1

Status: Experimental; only CI evidence can select or refute adoption.

## Decision

Gooo Link observes `gooo-design-evidence v0.5.0-dev` as the second independent
product whose user-visible result is bound to Gooo meta activities. The result
is a small design/code relation matcher, not a general design synchronizer:
three explicit matches, one reviewed mismatch, two typed UNKNOWN paths, and one
unresolved-contradiction REFUTED path.

Link consumes one immutable public ZIP. It neither checks out Design Evidence
source nor participates in that project's build, pull request, or release.

## Two resolutions

Relation state and aggregate claim state are deliberately distinct. A relation
may remain `MISMATCH` with disposition `REVIEWED_DIFFERENCE` while the aggregate
claim is `CLOSED`. A missing Code Connect property or missing explicit lineage
is `UNKNOWN` with stage, step, reason, unknown class, blocked evidence, and next
operation. A broken DTCG alias is an unresolved contradiction and therefore
`REFUTED`.

Names, values, AI confidence, and visual similarity are not evidence. A match
requires explicit lineage and the declared source artifacts.

## Fixed denominator

The adoption denominator has exactly twelve cells. Proof choices are
FOUNDATION 4, COHERENCE 4, and REGRESSION 4. Indicator classes are DRIVER 4,
OUTCOME 4, and GUARDRAIL 4. Every cell is declared by exactly one activity in
`examples/design-product-adoption/main.gooo`.

The independently observed product count changes from `1/3` to `2/3` only when
all twelve cells close. This count does not authorize a central orchestrator or
common generator. Both remain false until a separately defined decision can
cite three independent products.

## Counterexamples

- A missing conformance document yields 9 CLOSED and 3 UNKNOWN cells.
- A changed explicit-match count refutes the relation observation.
- A missing product Gooo activity refutes the meta binding.
- A non-zero cross-project required gate refutes the resource boundary.
- A missing Link adoption activity is rejected before a report can claim
  conformance.

No counterexample mutates the product, this repository, or another project's
release state.

## Next operation

After a valid observation, the only selected operation is
`OBSERVE_INFRASTRUCTURE_PRODUCT_RELEASE`. Design Evidence remains independently
releasable and the third product is not a required gate for it.
