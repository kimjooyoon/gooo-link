# Claim dependency candidate selection v1

## Decision

Select exactly one research meaning for an explicit minimal Core implementation:

`gooo.primitive.claim-dependency-causality.v1`

Selection is not implementation, merge eligibility, primitive adoption, or language improvement. It authorizes only the next operation `OPEN_EXPLICIT_IMPLEMENTATION_PR` on branch `agent/implementation-claim-dependency-causality-v1` while the explicit implementation queue is 0/1.

## Consumer evidence

Three immutable Link releases expose the same resolution shape:

| Metric | Exact observation |
| --- | ---: |
| Consumer domains | 3/3 |
| Direct missing roots | 3/3 |
| Dependency-blocked claims | 14/14 |
| Dependency claims with recovery operation | 14/14 |
| Dependency claims with explicit `blocked_by` predecessor | 10/14 |
| Preserved causal predecessor gap | 4/14 |

Local contributes 6 dependency-blocked claims with 6 explicit predecessors. Design contributes 4 with 4. Infra contributes 4 with 0. The four missing predecessor links are not converted to success and are the bounded problem selected for implementation.

## Research source binding

The selection pins Core research PR #566 commit `9766a04e34f60167777f2824f1b28fa2ed4657f4`. Its Gooo source has SHA-256 `bbb7c2cfba5298699a9f9dee627e9831207039cba125ebead4e2c2c87ff71656`.

CI parses and lowers the source with released Gooo and observes:

| Gooo topology | Count |
| --- | ---: |
| Activities | 6/6 |
| Reconstructed graph edges | 8/8 |
| Recoverable root programs | 1/1 |
| Typed edge programs | 5/5 |
| `REQUIRES` | 2/2 |
| `SUPPORTS` | 1/1 |
| `CONTRADICTS` | 1/1 |
| `FAILURE_ENTAILMENT` | 1/1 |

The research document is digest-locked for provenance but prose is not counted as executable evidence. The candidate ID and mapping authority live in `examples/claim-dependency-candidate-selection/main.gooo`; a title-only mapping is REFUTED.

## Meta denominator

Twelve selection activities resolve exactly once through released Gooo. FOUNDATION, COHERENCE, and REGRESSION own 4 cells each. DRIVER, OUTCOME, and GUARDRAIL own 5, 4, and 3 cells.

Normal selection is 12/12 CLOSED. Removing the causal-gap activity yields `UNKNOWN / DIRECT_MISSING` from the compiler.

## Resolution loss

| Scenario | Result |
| --- | --- |
| Design UNKNOWN evidence absent | 6 CLOSED + 6 UNKNOWN |
| Gap 4/14 laundered to 0/14 | 10 CLOSED + 2 REFUTED |
| Pinned research source drifts | 10 CLOSED + 2 REFUTED |
| Title grants candidate authority | 10 CLOSED + 2 REFUTED |
| Explicit implementation queue is already active | 10 CLOSED + 2 REFUTED |
| Core activity receipt says `FIXED_POINT` | 12 REFUTED |

UNKNOWN exposes stage, step, reason, unknown class, and recovery operation. REFUTED reports select a direct contradiction before its dependent selection failure.

## Quantitative boundary

The selected mapping changes research mappings from 0/29 to 1/29. Core primitive mappings remain 5/30 with increment 0. Explicit implementation PRs remain 0/1. Automatic merge is false. Repository writes, local tests, and cross-project required gates remain 0.
