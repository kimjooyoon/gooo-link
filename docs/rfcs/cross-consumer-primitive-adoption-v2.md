# RFC: Cross-consumer Primitive Adoption v2

Status: Observational progression contract

## Decision

The v0.14 Link release is the immutable two-mapping baseline. Local Ledger
v0.6 is observed as the second independent product consumer and the third
direct mapping of `gooo.primitive.claim-resolution-tuple.v1`. The exact
progress is three of thirty, with twenty-seven mappings remaining.

## Non-blocking topology

Local Ledger and Design Evidence publish independently. Link consumes only
immutable release assets after publication. Neither product is a required gate
for the other, and Link has no authority to mutate either repository.

## Evidence boundary

The Local Ledger release contributes three claim scenarios, fifteen released
readiness fields, eighteen Core claim fields, one explicit UNKNOWN-class
binding, four inventory facts, one adverse UNKNOWN path, and four adverse
REFUTED paths. Each number is bound to one of twelve Gooo activities.

## Generator authority

Three direct mappings do not authorize a common generator or central
orchestration. Both authority flags remain false. This contract records the
next operation as observing another independent consumer adoption, not
propagating changes across products.
