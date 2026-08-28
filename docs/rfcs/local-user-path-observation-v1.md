# RFC: Optional Local User-Path Observation v1

Status: Experimental read-only portfolio observation

## Decision

Gooo Link observes `gooo-local-ledger v0.7.0-dev` only after that product has
merged, passed its own main CI, and published its own release. Local Ledger does
not depend on this observation. Link consumes a digest-locked public archive and
does not check out Local Ledger source, inspect a branch, or become a required
gate.

This is the first of three planned user verticals: Local, Design, and Infra. It
is not a sixth direct primitive mapping. The primitive denominator remains
`5/30`, the mapping increment is exactly `0`, and the independent consumer count
remains `4`.

## Product evidence

The Local user path projects three released five-field readiness claims into
three generated Gooo programs and three six-field core receipts. Link observes:

- Local projection cells: `12/12`
- source readiness reports: `3/3`
- source claim fields: `15/15`
- generated Gooo claim programs: `3/3`
- resolved claim receipts: `3/3`
- projected claim fields: `18/18`
- UNKNOWN classification entries: `12/12`
- projection counterexamples: `2/2`
- deterministic replay comparisons: `9/9`

The missing-receipt path remains `8 CLOSED + 4 UNKNOWN` with the complete
stage, step, reason, unknown class, and next operation. A changed UNKNOWN class
remains `8 CLOSED + 4 REFUTED`.

## Observation denominator

The Link observation has twelve cells. FOUNDATION, COHERENCE, and REGRESSION
are four cells each. DRIVER, OUTCOME, and GUARDRAIL are four cells each. Every
cell names one activity in `examples/local-user-path-observation/main.gooo`.

Progress changes from `0/3` to `1/3` only if all twelve observation cells close.
The product's primitive and consumer counts do not change.

## Counterexamples

- A missing Local projection report yields `5 CLOSED + 7 UNKNOWN`.
- Changing the baseline from `5/30` to `6/30` is REFUTED as metric inflation.
- Changing the source claim-field count is REFUTED.
- Removing a Local Gooo activity is REFUTED.
- Enabling central orchestration authority is REFUTED.
- Removing a Link observation activity prevents report generation.

## Authority boundary

Cross-project required gates, source repository writes, and local tests are all
zero. Common generator and central orchestration authority are false. Root
README readiness is excluded. The next optional operation is to observe a
separately released Design user-path projection; that future release is not a
gate for Local Ledger or Link.
