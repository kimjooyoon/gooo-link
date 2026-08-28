# RFC: Three-domain envelope observation

Status: Experimental observation, connector not promoted

## Decision

Observe three independent public releases before defining a shared interchange
format. The inputs are immutable release assets from local-ledger,
design-evidence, and infra-evidence. No consumer branch or source checkout is
an input, and no consumer release is blocked by this repository.

## Repeated relations

The released documents establish these exact common relations in 3/3 domains:

- Gooo core release v0.2.0-dev identity;
- exactly one core identity anchor;
- exactly twelve domain cells;
- indicator classes OUTCOME 3, DRIVER 5, GUARDRAIL 4;
- zero source-repository writes;
- UNKNOWN and REFUTED degraded evidence in every domain.

Thirteen degraded scenarios expose stage, step, reason, unknown_class, and
next_operation. UNKNOWN remains in the denominator and lowers resolution.

## Preserved differences

The proof distributions are local 4/4/4, design 4/5/3, and infra 4/6/2.
The three domain document schemas are distinct, and there are two top-level
key shapes. These values are observations, not defects to average away.

## Promotion boundary

A connector is not promoted by this RFC. Machine-readable replay evidence is
present in 2/3 complete domain documents, while canonical interchange envelope
adoption is 0/3. The promotion cell is therefore UNKNOWN at
PROMOTION / EVALUATE_CONNECTOR_PROMOTION with next operation
PUBLISH_CANONICAL_ENVELOPE_AND_REPLAY_RECEIPTS.

This is not a language-wide improvement claim. It is an exact observation that
justifies designing an advisory file protocol without making that protocol a
required cross-project gate.
