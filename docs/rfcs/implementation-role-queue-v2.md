# Implementation role queue v2

## Problem

The v1 queue classified every pull request whose branch started with `agent/` as an implementation pull request. That rule merged two different activities:

- parallel public research, which may remain open while alternatives are compared;
- a selected implementation, which must be integrated or closed before another implementation begins.

The observed Core portfolio at design time contained exactly 34 open pull requests: 29 `agent/luna-meta-` research pull requests, 0 explicitly selected implementation pull requests, and 5 other historical pull requests. GitHub reported 19 as DIRTY and 15 as UNSTABLE, so merge-ready pull requests were 0. These counts are observations, not a language progress percentage.

## Decision

Branch role is determined by an explicit prefix and the Core `dev` integration branch:

| Prefix | Role | Cardinality policy |
| --- | --- | --- |
| `agent/luna-meta-` | RESEARCH | observed without a maximum |
| `agent/implementation-` | IMPLEMENTATION | maximum 1 |
| every other branch | OTHER | observed, never promoted implicitly |

Titles do not grant implementation authority. Green checks do not grant implementation authority. A research branch remains research until a separate consumer-need mapping authorizes a new explicit implementation branch.

## Meta denominator

The denominator contains exactly 12 activities in `examples/implementation-role-queue/main.gooo`.

| Class | Denominator |
| --- | ---: |
| FOUNDATION | 4 |
| COHERENCE | 4 |
| REGRESSION | 4 |
| DRIVER | 5 |
| OUTCOME | 4 |
| GUARDRAIL | 3 |

The released Gooo compiler must resolve every activity exactly once. Removing `ClassifyResearchPullRequests` produces `UNKNOWN / DIRECT_MISSING`; a metric without its Gooo activity cannot close.

## Exact transitions

| Explicit implementation PRs | Queue state | Next operation |
| ---: | --- | --- |
| 0 | CLEAR | `SELECT_MAPPED_RESEARCH_EXPERIMENT` |
| 1 | ACTIVE | `MERGE_OR_CLOSE_SELECTED_IMPLEMENTATION_PR` |
| more than 1 | REFUTED | `REDUCE_EXPLICIT_IMPLEMENTATION_PRS` |

The live report always records the exact total, research, implementation, and other counts. Their partition delta must equal 0.

## Resolution loss

A missing Core PR snapshot yields exactly 3 CLOSED and 9 UNKNOWN cells. The direct cause exposes:

| Field | Value |
| --- | --- |
| stage | `OBSERVATION` |
| step | `OBSERVE_CORE_PULL_REQUEST_SNAPSHOT` |
| reason | `CORE_PR_SNAPSHOT_UNAVAILABLE` |
| unknown_class | `DIRECT_MISSING` |
| next_operation | `REFRESH_CORE_PR_SNAPSHOT` |

Eight dependent cells use `DEPENDENCY_BLOCKED`.

Two explicit implementation PRs yield 10 CLOSED and 2 REFUTED cells. A title-only authority escalation also yields 10 CLOSED and 2 REFUTED cells. In each case the report selects the direct contradiction before the dependent selection failure.

## Authority boundary

The observer is read-only, automatic merge is false, repository writes are 0, local tests are 0, and cross-project required gates are 0. Research remains public and parallel. Implementation remains explicit and serial. This role correction does not claim that any research experiment is valuable or ready to merge; it only makes the next authorized operation deterministic.
