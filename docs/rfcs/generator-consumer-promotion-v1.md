# Generator external-consumer promotion observation v1

## User question

Can the common evidence generator be promoted because independent public products actually used it, rather than because its own repository generated a fixture for itself?

This observer answers that question from immutable public releases. It does not generate application code, edit a consumer repository, coordinate releases, or become a required gate for any consumer.

## Fixed denominator

The decision has exactly 12 cells. Every cell is bound to exactly one Activity in `examples/generator-consumer-promotion/main.gooo`.

- FOUNDATION: 4/4 release identities.
- COHERENCE: 5/5 independence, common identity, contract, generation, and verification bindings.
- REGRESSION: 3/3 runtime, checksum, and promotion-selection guards.
- OUTCOME: 3/3.
- DRIVER: 5/5.
- GUARDRAIL: 4/4.

Promotion requires exactly these directly observable minima:

- independent public consumer repositories: 2/2;
- public evidence assets: 10/10, five per consumer;
- generated evidence cells: 24/24;
- generated-file verification cells: 12/12;
- source and consumer repository writes: 0;
- local test executions: 0;
- cross-project required gates: 0;
- current branch inputs: 0.

The two initial consumers are `gooo-local-ledger v0.3.0-dev` and `gooo-design-evidence v0.3.0-dev`. Their reports use `gooo/evidence-generator/report/v2`, but their proof distributions remain product-owned: local is FOUNDATION 4/4, COHERENCE 4/4, REGRESSION 4/4; design is FOUNDATION 4/4, COHERENCE 5/5, REGRESSION 3/3.

## Resolution behavior

- A missing consumer asset is UNKNOWN/DIRECT_MISSING. Dependent cells become UNKNOWN/DEPENDENCY_BLOCKED.
- Two entries naming the same repository are REFUTED as non-independent.
- A consumer pinning a different generator identity is REFUTED.
- A report that does not remain 12/12 CLOSED is REFUTED.
- An absent or duplicated Gooo Activity is REFUTED because a metric without meta code has no authority.

UNKNOWN retains stage, step, reason, unknown class, next operation, and blocking cells. UNKNOWN is never converted to promotion eligibility.

## Authority and non-claims

The observer reads annotated tags, target commits, release assets, and SHA-256 digests. It consumes no branch and modifies no source repository. Different product versions are valid because each edge is bound to a complete release identity; a shared semantic contract does not require shared repository version numbers.

`GENERATOR_PROMOTION_ELIGIBLE` means only that a declarative evidence-project generator has at least two independent external public consumers with their own CI evidence. It does not claim executable CI generation, application-code generation, central orchestration, language completeness, or permission to make the generator a required cross-project gate.

GitHub Actions is the sole execution authority for normal, missing, duplicate, mismatched, and invalid-report scenarios. Go 1.27 runs formatting, fix, vet, and build conformance without executing local tests.
