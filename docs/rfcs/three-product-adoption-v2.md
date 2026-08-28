# RFC: three-product adoption v2

Status: implementation proposal in one PR against main and v0.26.0-dev. Merge and release remain parent decisions.

This profile makes Link a post-release, read-only observer of three independently released products. It consumes only the exact public Local v0.9.0-dev, Design v0.8.0-dev, Infra v0.9.0-dev assets and the released Interchange v0.3.0-dev consumer kit. It never checks out or reads product source, reruns product build or test, imports Core source, or requires a cross-project gate. A Link outage therefore cannot block a product release.

The denominator is fixed at 12 cells, each bound exactly once to an actual Gooo activity in the released graph. The graph must contain real prov:used and prov:wasGeneratedBy edges for every activity and every declared dependency; an isolated self-loop is invalid. Proof choices are FOUNDATION 4, COHERENCE 4, REGRESSION 4. Indicator classes are DRIVER 4, OUTCOME 4, GUARDRAIL 4.

The normal profile has 1 evaluation and 12 CLOSED cells. Three missing-receipt evaluations have 1 direct UNKNOWN with stage, step, reason, unknown_class=DIRECT_MISSING, next_operation, and blocked_by=[]; only four true downstream cells become DEPENDENCY_BLOCKED, while the other products stay CLOSED. Three corrupted-asset evaluations have 6 REFUTED cells, 0 UNKNOWN cells, and REFUTED precedence over earlier UNKNOWN state; unrelated products stay CLOSED.

Each product conforms independently through one released kit execution with 10 checks: 3 executions, 30/30 checks, 3/3 replay receipts, 0 mismatches, and 3/3 exact release identities/assets. Upstream product CI/test receipts are available 3, reused 0, unknown 3. Display command hashes are non-authoritative and cannot authorize reuse.

External utility and exact improvement remain UNKNOWN at 0/1, with the exact observed pair 0/1; one run is not an improvement. Infra Terraform identity is explicit, while OpenTofu adoption is UNKNOWN at 0/1. No OpenTofu init, plan, apply, test, build, network, provider, cloud, source checkout, or vendor execution occurs; Terraform version never infers the engine.

The generator, product generation, central orchestration, merge, repair, and cross-project required-gate authorities are all false or 0. Generated packet files exist only in runner-owned temporary output. The packet does not self-prove its existence; runtime observation and replay are recorded separately. PR and push-main jobs use immutable Actions and publish an exact 10-file packet suitable for a later v0.27.0-dev release.
