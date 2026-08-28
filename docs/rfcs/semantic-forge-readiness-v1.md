# Semantic Forge Readiness v1

## Decision

Link compares two independently released products that use the same released Core claim-dependency primitive. Readiness is a selection for one optional Forge experiment, not authorization for a common generator.

Local Ledger and Infra Evidence remain independent producers. They do not import Forge, wait for Forge CI, or grant Forge mutation authority. Forge may later consume their immutable releases, but neither product may require Forge.

## Fixed denominator

The readiness denominator contains twelve cells, with four cells for each Munchausen proof choice and four cells for each indicator class. Every cell has one Gooo meta activity.

Eight shared invariants are counted: primitive identity, six activities, eight dependencies, four dependency kinds, two generated artifacts, six UNKNOWN coordinates, three REFUTED boundaries, and seven replay comparisons.

## Exact input evidence

- Independent released consumers: 2/2
- Product releases: 2/2
- Selected release assets: 12/12
- Product conformance cells: 24/24
- Product activities: 12/12
- Product dependencies: 16/16
- Generated artifacts: 4/4
- UNKNOWN coordinates: 12/12
- REFUTED boundaries: 6/6
- Replay comparisons: 14/14
- External utility evidence: 0/2 UNKNOWN

## Selection boundary

Closing all twelve cells selects creation of a public experimental repository whose first output is a read-only semantic packet. It does not authorize product code generation, repository mutation, central orchestration, automatic repair, automatic merge, deployment, or a required cross-project gate.

A missing product release lowers eight dependent cells to UNKNOWN with explicit coordinates. Primitive mismatch, utility laundering, authority escalation, a missing meta activity, or a changed two-consumer baseline fails closed.

