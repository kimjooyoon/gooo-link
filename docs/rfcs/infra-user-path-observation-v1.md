# Infra user-path observation v1

## Decision

Link observes the released Infrastructure Deployment Contract Packet as the third independent user vertical. The observation is optional: it adds no required cross-project gate and grants Link no authority to run `terraform apply`, deploy a service, write another repository, or reinterpret a product result.

The observation closes one small development loop:

1. Gooo meta activities define what Link is allowed to observe.
2. Three immutable releases provide Core, Link-baseline, and Infrastructure evidence.
3. Link emits a 15-cell report that a person can read in CI.
4. Missing or contradictory evidence lowers resolution instead of being converted to success.

## Quantitative denominator

The denominator is fixed before observation.

| Dimension | Closed requirement |
| --- | ---: |
| Total activities | 15/15 |
| FOUNDATION / COHERENCE / REGRESSION | 5/5 each |
| DRIVER / OUTCOME / GUARDRAIL | 5/5 each |
| User verticals | 3/3 |
| Primitive count | 5/30 |
| Primitive increment | 0 |
| Independent consumers | 4 |
| Release inputs | 3/3 |
| Cross-project required gates | 0 |
| Repository writes | 0 |
| Local tests | 0 |

The third vertical is counted only when `RecordThirdUserVertical` is CLOSED. A REFUTED or UNKNOWN vertical leaves the observed count at 2/3. This is a count, not an estimate of language completeness.

## Meta-code connection

`examples/infra-user-path-observation/main.gooo` is the authority for all 15 activity names, proof classes, indicator classes, and claims. CI compiles those declarations into an activity graph. The observer rejects a graph when one activity is missing or when its classification differs from the fixed denominator.

The meta program therefore precedes the metric. A JSON number without the corresponding Gooo activity cannot close a cell.

## Munchausen choices

| Proof class | Question answered |
| --- | --- |
| FOUNDATION | Which immutable releases and optional authority boundary are observed? |
| COHERENCE | Do released Terraform, OpenAPI-to-Go, manifest, and generated-artifact facts agree? |
| REGRESSION | Are UNKNOWN, REFUTED, primitive stability, execution refusal, and runtime visibility preserved? |

No proof class is described as universally complete. Each closes only its declared finite cells.

## Indicator choices

| Indicator class | Meaning |
| --- | --- |
| DRIVER | Inputs and bindings available before the observation |
| OUTCOME | User-visible deployment packet facts observed from the released product |
| GUARDRAIL | Conditions that prevent success inflation or authority escalation |

## Resolution loss

The missing-conformance case produces exactly 10 CLOSED and 5 UNKNOWN cells. The direct UNKNOWN records:

| Field | Value |
| --- | --- |
| stage | `PRODUCT_EVIDENCE` |
| step | `OBSERVE_INFRA_PACKET_CONFORMANCE` |
| reason | `INFRA_CONFORMANCE_REPORT_UNAVAILABLE` |
| unknown_class | `DIRECT_MISSING` |
| next_operation | `RESTORE_INFRA_CONFORMANCE_REPORT` |

Four downstream cells use `DEPENDENCY_BLOCKED`. The report selects the direct missing cause before dependency effects.

Four contradiction cases each produce exactly 13 CLOSED and 2 REFUTED cells:

| Case | Direct refutation | Dependent refutation |
| --- | --- | --- |
| Primitive count changes from 5 to 6 | Primitive baseline guard | Third user vertical |
| Generated artifact count changes from 3 to 2 | Generated artifacts | Third user vertical |
| `GenerateDeploymentPacketArtifacts` disappears | Infra meta binding | Third user vertical |
| Apply or deployment authority becomes true | Execution authority guard | Third user vertical |

The top-level cause is always the direct contradiction, independent of activity order.

## Human-readable CI evidence

The Actions artifact contains the normal report, deterministic replay, five adverse reports, both Gooo activity graphs, repository inventory, runtime observation, denominator, and release lock. Inventory excludes the repository-root `README.md` and reports exact per-file Go and Gooo physical lines. Runtime reports measured peak RSS in KiB and wall time in milliseconds.

CI uses Go 1.27.0. `go fix` is invoked only for discovered module roots, and the exact root count is recorded. No local validation is part of this contract.

## Non-gates

This observation does not block Core, Infrastructure, Design, or Local releases. It does not create a central orchestrator. Each product remains independently releasable, and Link may only observe already published evidence.
