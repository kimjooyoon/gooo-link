# RFC: Evidence-selected core activity cardinality primitive

## Inputs

Two independent public consumers pin the same released evidence generator but
have distinct domain graphs and core-lock structures:

- local-ledger, merged consumer `1`, flat eight-asset lock;
- design-evidence, merged consumer `2`, nested eight-asset lock.

Only immutable `v0.2.0-dev` release assets are inputs. Current repository state
cannot change the comparison.

The selected primitive is now also consumed only from the immutable Gooo
`v0.2.0-dev` release. Its annotated tag object is
`733f7b22a365606d42bf238f5c535ff12e5abf8c` and its target commit is
`050b11e56d9f972e0d507d406e5da8a60595052b`.

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

The selection denominator remains exactly twelve cells. Each cell is connected
to one compiler-produced `gooo/activity-cardinality-resolution/v1` receipt;
the selector no longer counts Activity nodes itself. The adoption closes only
when all of these exact quantities hold:

- pinned core identities `1/1`;
- core resolution receipts `12/12`;
- unique Activity selectors `12/12`;
- core decisions `12 CLOSED + 0 UNKNOWN + 0 REFUTED`;
- selection cells `12/12 CLOSED`;
- public consumers `2/2`.

A missing core receipt lowers resolution at
`RESOLUTION_OBSERVATION / BIND_CORE_ACTIVITY_RESOLUTION_RECEIPT` and exposes
`DIRECT_MISSING` plus the next operation. An unrecognized decision such as
`FIXED_POINT` is not accepted as closure; it produces `FAIL_CLOSED /
UNRECOGNIZED_CORE_ACTIVITY_RESOLUTION_DECISION`.

`ADOPTED_FROM_CORE_RELEASE / RELEASED_AND_CONSUMED` means only that the selected
primitive completed the public cycle from consumer evidence to compiler release
and back to this independent consumer. It does not claim language-wide
improvement.
