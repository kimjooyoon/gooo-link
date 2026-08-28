# RFC: Evidence-selected core activity cardinality primitive

## Inputs

Two independent public consumers pin the same released evidence generator but
have distinct domain graphs and core-lock structures:

- local-ledger, merged consumer `1`, flat eight-asset lock;
- design-evidence, merged consumer `2`, nested eight-asset lock.

Only immutable `v0.2.0-dev` release assets are inputs. Current repository state
cannot change the comparison.

## Shared observations

Both consumers establish exactly:

- complete generation `12/12 CLOSED`;
- promoted generator patterns `11`;
- generated files `7`, manifest entries `6/6`;
- missing activity direct classification `1 DIRECT_MISSING`;
- at least one downstream `DEPENDENCY_BLOCKED` cell;
- duplicate activity produces at least one `REFUTED` cell;
- generated digest mutation produces `1 REFUTED` manifest entry;
- source repository writes `0` and local tests `0`.

## Preserved differences

The comparison must not average or erase these domain values:

- missing activity: local `4 CLOSED + 7 BLOCKED`, design `3 CLOSED + 8 BLOCKED`;
- duplicate activity: local `11 CLOSED + 1 REFUTED`, design `8 CLOSED + 4 REFUTED`;
- project graph hashes differ;
- core locks are flat and nested respectively.

## Selection rule

When all twelve selection cells close, select exactly one candidate:

`GOOO_CORE_ACTIVITY_CARDINALITY_RESOLUTION_V1`.

The proposed compiler primitive accepts an expected activity name and reports:

- occurrence `0`: `UNKNOWN / DIRECT_MISSING`;
- occurrence `1`: `CLOSED`;
- occurrence greater than `1`: `REFUTED / AMBIGUOUS_ACTIVITY_BINDING`.

Dependency propagation remains a consumer-level policy. The compiler primitive
must report cardinality only; it must not infer domain dependencies.

## Completion boundary

Selection status is `SELECTED_FOR_CORE_EVALUATION`, not improvement. The
candidate remains `NOT_IMPLEMENTED` until a core PR, adversarial core CI, merge,
release, and unchanged-denominator consumer reruns all succeed.
