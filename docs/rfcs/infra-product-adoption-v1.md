# RFC: Infrastructure Product Adoption Observation v1

Status: Experimental; only CI evidence can select or refute adoption.

## Decision

Gooo Link observes `gooo-infra-evidence v0.5.0-dev` as the third independent
product whose user-visible result is bound to Gooo meta activities. The product
connects captured Terraform declaration, plan, state, OpenAPI operation, Go
handler symbol, artifact, deployment, and runtime evidence without executing
Terraform, contacting a cloud provider, deploying, or probing a network.

Link consumes five digest-locked public release assets. It does not import the
product's Go packages, check out its source, or participate in its CI.

## Structured evidence

The declaration receipt is produced by HashiCorp HCL v2.24.0
`hclsyntax.ParseConfig`, records the exact parser module checksum and source
range, and binds one resource address with two literal attributes. Missing HCL
is a direct UNKNOWN; an expression that needs evaluation context is a distinct
context-missing UNKNOWN. Invalid syntax and contradictory literal values are
REFUTED.

The aggregate product report closes twelve cells and six semantic edges. Its
released Gooo activity-resolution graph contains twelve uniquely resolved
activities. A deployment artifact identity contradiction refutes two dependent
cells rather than being averaged into a score.

## Fixed denominator

The Link adoption denominator has exactly twelve cells. Proof choices are
FOUNDATION 4, COHERENCE 4, and REGRESSION 4. Indicator classes are DRIVER 4,
OUTCOME 4, and GUARDRAIL 4. Every cell is declared by exactly one activity in
`examples/infra-product-adoption/main.gooo`.

Closing all twelve cells changes the independently observed product count from
`2/3` to `3/3`. This only selects a separate generator-authority evaluation.
It does not authorize a central orchestrator, common generator, cross-project
required gate, Terraform execution, deployment, or network access.

## Counterexamples

- A missing aggregate report yields 9 CLOSED and 3 UNKNOWN cells.
- A changed semantic-edge count refutes the product metric observation.
- A missing released product activity refutes the meta binding.
- Claiming Terraform or deployment execution refutes the authority boundary.
- A missing Link adoption activity is rejected before a report can claim
  conformance.

No counterexample mutates Infra Evidence, Link, or another product.

## Next operation

After a valid observation, the selected operation is
`EVALUATE_GENERATOR_AUTHORITY_WITH_THREE_PRODUCTS`. The evaluation must use the
three independently released products as evidence and may still conclude that
no common generator is authorized.
