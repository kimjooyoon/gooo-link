# Cross-consumer claim-resolution mapping v2

## Decision

The observed candidate gooo.primitive.claim-resolution-tuple.v1 now has one
experimental core implementation. This does not prove consumer adoption or
stable language compatibility.

The mapping is closed only when CI binds all of these immutable facts:

- the v0.3.0-dev core tag targets one exact commit;
- the Linux release asset has the locked SHA-256;
- the Gooo claim source at that commit has the locked SHA-256;
- the released binary resolves the source activity to a claim receipt;
- the receipt repeats the exact candidate id and the six-field UNKNOWN tuple.

## Exact denominator

- meta cells: 13
- FOUNDATION / COHERENCE / REGRESSION: 5 / 4 / 4
- DRIVER / OUTCOME / GUARDRAIL: 7 / 2 / 4
- independent consumer releases: 3
- released core primitives: 1/1
- historical open experiments: 29
- direct primitive mappings: 1/30
- repository writes: 0
- local test executions: 0
- cross-project required gates: 0

The denominator is 30 because the observer retains all 29 historical experiments
and adds one released implementation. It does not rewrite a title into evidence.

## Resolution behavior

A missing core release is UNKNOWN at CORE_RELEASE /
OBSERVE_CORE_PRIMITIVE_RELEASE with DIRECT_MISSING and a concrete publication
operation. An invalid receipt is REFUTED. Downstream mapping cells expose
DEPENDENCY_BLOCKED instead of hiding the originating stage.

## Authority boundary

The next operation is OBSERVE_INDEPENDENT_CONSUMER_ADOPTION. No consumer must
upgrade, no source repository is modified, and no successful result authorizes
automatic merge. The v1 need observation remains intact as historical evidence.
