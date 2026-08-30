# RFC: Deterministic self-improvement change-proposal actuator v1

## Decision

The actuator is a small, caller-owned read-only operation. It accepts an
observed claim whose state is `UNKNOWN` or `REFUTED`, plus a `CLOSED` temporal
ticket that was already consumed exactly once. It emits a deterministic
`gooo/meta/self-improvement/change-proposal/v1` artifact. It never applies the
proposed change, writes the source repository, merges, releases, or deploys.

The actuator is intentionally a proposal boundary, not an autonomous coding
agent. A generated proposal is not evidence that the proposed change improves
the product.

## Inputs and precedence

The temporal input is bound to the closed successor observation from the
prospective `PREDECLARE -> CONSUME_ONCE` flow. Its ticket schema, `CLOSED`
state, `consumed_once` flag, ticket id, ticket digest, nonce, and predecessor
artifact/report digests are retained in the output. The actuator does not
consume that ticket again.

Observed claims may contain one or more candidates. Selection is deterministic:
`REFUTED` claims sort before `UNKNOWN` claims, then claim id is used as the
stable tie-breaker. A known contradiction therefore remains `REFUTED`; it is
never downgraded to `UNKNOWN` or counted as a successful improvement.

For every `UNKNOWN` claim the artifact preserves exactly these coordinates:
`stage`, `step`, `reason`, `unknown_class`, `next_operation`, and `blocked_by`.
The smallest supplied causal frontier is copied without inference. Historical
UNKNOWN claims are copied as history and cannot be closed by this actuator.

## Proposal artifact

The proposal contains the selected claim, causal frontier, declared paths,
allowed scope, expected effect, and replay guard. Its canonical digest is
computed from the input with consumed-ticket and consumed-proposal history
removed from the seed. Runtime values, timestamps, and run ids are excluded.
Therefore the same input produces the same proposal digest, while a consumed
ticket id or proposal digest causes a `REFUTED` rejection.

Allowed scope is fixed to proposal description only:

- repository writes: `0`;
- apply, merge, release, and deploy authority: `false`;
- target repository and branch: `kimjooyoon/gooo-link` / `main`;
- no generated patch bytes.

The expected effect is always typed `UNKNOWN` with reason
`EXACT_COMPARABLE_BEFORE_AFTER_EVIDENCE_ABSENT`. No denominator is lowered and
no score is formed by summing successful cells.

## Fixed evidence boundary

The denominator has twelve immutable cells: FOUNDATION 4, COHERENCE 4, and
REGRESSION 4. Each metric has one exact `activity` name and is checked against
the twelve Activity nodes in the released Gooo semantic graph. The workflow
uses only the digest-locked released Gooo CLI and GitHub Actions. It runs
normal UNKNOWN and REFUTED inputs, mixed REFUTED-over-UNKNOWN precedence,
same-input replay, consumed ticket reuse, consumed proposal reuse, scope
escalation, and historical-closure attempts.

Actual improvement and external utility remain UNKNOWN because this artifact
contains no exact comparable before/after evidence. Existing historical
UNKNOWN observations remain unchanged.
