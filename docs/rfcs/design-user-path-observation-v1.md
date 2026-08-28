# RFC: Optional Design User-Path Observation v1

Status: Experimental. Only immutable releases and GitHub Actions determine observation.

## Decision

Link observes the independently released Design Review Packet without becoming its orchestrator. A complete released-evidence path advances the fixed user-vertical count from 1/3 to 2/3. It does not change the primitive mapping count, independent consumer count, Design repository, core repository, or any required cross-project gate.

The observed user path is concrete:

1. One Button review request is present.
2. Four released design-code relations receive review dispositions.
3. Four released claim tuples expose 24 fields.
4. Five Gooo decision receipts expose CLOSED, UNKNOWN, and REFUTED boundaries.
5. Two review artifacts are generated for a tool and a human.

## Fixed denominator

The Link denominator has fifteen cells. FOUNDATION, COHERENCE, and REGRESSION each own 5/15. DRIVER, OUTCOME, and GUARDRAIL each own 5/15. Every cell binds to exactly one activity in `examples/design-user-path-observation/main.gooo`.

Normal observation records exact counts:

- Planned user verticals: 2/3.
- Primitive mappings: 5/30; increment: 0.
- Independent primitive consumers: 4.
- Design conformance: 15/15.
- Design release inputs: 3/3.
- Review requests: 1/1.
- Relation dispositions: 4/4.
- Claim tuples and fields: 4/4 and 24/24.
- Gooo decision receipts: 5/5.
- Generated review artifacts: 2/2.
- Design counterexamples and replay: 4/4 and 2/2.
- Repository writes, local tests, and cross-project required gates: 0/0/0.

The root `README.md` is excluded from repository inventory. Every Go and Gooo source file reports its physical line count.

## Resolution loss

- Removing the Design conformance report yields 10 CLOSED / 5 UNKNOWN. The direct UNKNOWN records product-evidence stage, observation step, missing-report reason, `DIRECT_MISSING`, restoration operation, and file coordinate. Four dependents record `DEPENDENCY_BLOCKED`.
- Inflating primitive mappings yields 13 CLOSED / 2 REFUTED.
- Changing the generated-artifact count yields 13 CLOSED / 2 REFUTED.
- Removing one Design Gooo activity yields 13 CLOSED / 2 REFUTED.
- Granting central orchestration authority yields 13 CLOSED / 2 REFUTED.

Removing a Link Gooo activity rejects the observer before these scenarios are evaluated.

## Non-blocking topology

Core v0.3.0-dev, Link v0.18.0-dev, and Design v0.7.0-dev are immutable inputs. Design does not wait for Link. Link may independently release the observation, and all cross-project required gates remain zero.
