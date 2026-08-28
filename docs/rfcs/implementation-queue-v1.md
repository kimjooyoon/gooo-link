# Implementation queue observation v1

Status: Experimental operational evidence

## Question

This observation answers one bounded question without estimating project value:

> How many implementation pull requests are open for this repository and this
> candidate, and what queue operation follows from that exact cardinality?

It does not rank future language features. It makes the one-open-implementation-
PR policy observable so that parallel research cannot silently become parallel
unmerged implementation.

## Meta binding

The denominator contains exactly 12 cells. Each cell is bound to exactly one
activity in `examples/implementation-queue/main.gooo` and resolved through the
immutable Gooo `v0.2.0-dev` release CLI. Metrics without those activity receipts
do not close a cell.

Proof choices remain explicit:

- FOUNDATION: 4/4;
- COHERENCE: 4/4;
- REGRESSION: 4/4.

Indicator classes remain explicit:

- OUTCOME: 3/3;
- DRIVER: 5/5;
- GUARDRAIL: 4/4.

## Classification and denominator

An implementation PR targets `main` and has a head ref beginning with `agent/`.
The target repository limit is exactly 1. The current candidate limit is also
exactly 1. The receipt records the observation time, repository, candidate ID,
both cardinalities, the maximum, the normalized snapshot digest, and the next
operation.

The deterministic transition is:

| Open implementation PRs | State | Next operation |
|---:|---|---|
| 0 | CLEAR | SELECT_NEXT_CANDIDATE |
| 1 | ACTIVE | MERGE_OR_CLOSE_CURRENT_IMPLEMENTATION_PR |
| more than 1 | REFUTED | REDUCE_OPEN_IMPLEMENTATION_PRS |

## Resolution reduction

If the GitHub snapshot cannot be observed, the direct cell is:

- stage: `OBSERVATION`;
- step: `OBSERVE_GITHUB_PULL_REQUEST_SNAPSHOT`;
- reason: `GITHUB_PR_SNAPSHOT_UNAVAILABLE`;
- unknown class: `DIRECT_MISSING`;
- next operation: `REFRESH_GITHUB_PR_SNAPSHOT`.

Dependent cells lower their resolution to `UNKNOWN/DEPENDENCY_BLOCKED`. They are
not converted to REFUTED merely because no PR count can be observed.

If two implementation PRs are observed, the limit cell is REFUTED with
`IMPLEMENTATION_PR_LIMIT_EXCEEDED`. Dependent cells fail closed. This is a
contradiction, not missing evidence.

## Authority and non-claims

The observer reads the repository's GitHub Pull Requests API and writes only to
the Actions temporary directory. It has zero cross-project required gates and
does not become a release predecessor for any consumer.

This contract does not claim:

- that a candidate is valuable;
- that the selected PR should merge without review;
- that zero open PRs identifies which feature should be implemented;
- that branches outside the classifier are implementation PRs;
- that a successful queue observation improves the language by itself.
