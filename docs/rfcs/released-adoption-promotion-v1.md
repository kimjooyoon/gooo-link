# Released adoption promotion observation v1

Status: Experimental promotion evidence

## Decision boundary

This observation consumes only three immutable `v0.4.0-dev` release archives. It does not inspect consumer branches and does not become a required gate for any consumer.

The previous three-domain observation remains historically correct: at that release, canonical adoption was 0/3 and promotion was UNKNOWN. This observation asks a new question after three independent adoptions were released.

## Exact promotion denominator

Promotion requires all of the following:

- adoption release identities 3/3;
- archive digests 3/3;
- canonical five-file bundles 3/3;
- common specification anchors 3/3;
- resolved relation endpoints 6/6 and UNKNOWN endpoints 0/6;
- conformant bundles 3/3;
- deterministic replays 3/3;
- incomplete UNKNOWN tuples fail-closed 3/3;
- checksum drift fail-closed 3/3;
- domain self-adoptions 3/3;
- at least 6 released scenarios.

The observed archives contain 12 scenarios: conformant adoption, incomplete UNKNOWN, checksum drift, and invalid core decision in each domain.

## Scope

ELIGIBLE means an advisory connector may be implemented. It does not mean the connector exists, improves the language, or may become a cross-project required gate. Implementation remains `NOT_STARTED` until a later PR produces its own evidence.
