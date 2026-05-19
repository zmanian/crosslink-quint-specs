# Completeness Audit

This is a working audit against the objective: build Crosslink Quint specs for
both baseline Crosslink and nil-precommit resampling, aiming at the same
completeness and review quality level as the upstream Tendermint Quint specs.

Status terms:

- `covered`: model, executable witness, bounded verification, and documentation
  are present at the current abstraction level.
- `partial`: a useful model exists, but an important part of the target remains
  abstract, scripted, one-height, or disconnected from implementation data.
- `open`: not yet modeled.

## Prompt-To-Artifact Checklist

| Requirement | Current evidence | Status | Gap |
| --- | --- | --- | --- |
| Standalone GitHub repo | `zmanian/crosslink-quint-specs`, `main` branch | covered | None. |
| Baseline Crosslink spec | `BaselineCrosslink` in `spec/CrosslinkResampling.qnt`; `test:baseline`; `verify:baseline-safety` | covered | Heighted round-machine coverage is currently a separate model. |
| Nil-precommit resampling spec | `NilPrecommitResamplingCrosslink`; `test:resampling`; `verify:resampling-safety`; `CrosslinkHeightedRound.qnt` | covered | Heighted round-machine coverage is currently a separate model. |
| Shared protocol core with explicit variants | Shared `CrosslinkResampling` core with baseline/resampling modules, plus standalone `CrosslinkDynamicSigmaModel`, `CrosslinkDynamicSigmaConsensusParamsModel`, `CrosslinkDynamicSigmaConsensusParamFormatModel`, `CrosslinkDynamicSigmaConsensusParamTransportModel`, `CrosslinkDynamicSigmaHeadSamplingModel`, `CrosslinkDynamicSigmaHeightedRoundModel`, `CrosslinkDynamicSigmaHeightedFinalityModel`, `CrosslinkDynamicSigmaHeightedAuthenticatedEvidenceModel`, and `CrosslinkDynamicSigmaAuthenticatedFinalityModel` for the third dynamic-sigma variant | partial | Dynamic sigma is first-class in the spec surface and now bridged through an abstract consensus-parameter envelope, a production-shaped consensus-param byte format, authenticated production-byte gossip/config application, head-sigma sampling, the heighted round machine, Crosslink finality, and authenticated evidence/finality; real implementation vectors and code integration remain open. |
| Proposal values as PoW stream snapshots | `Stream(round)`, `StickyOrStreamProposal`, `IsFreshForRound`, `CrosslinkHeadSigmaSamplingModel`, `CrosslinkDynamicSigmaHeadSamplingModel`, `CrosslinkDynamicSigmaHeightedRoundModel`, `CrosslinkHeightedHeadSigmaRoundModel`, `CrosslinkBftBlockShapeModel`, `CrosslinkBftBlockValidationGapModel`, `CrosslinkBftBlockProductionVectorsModel`; `fixtures/production-bft-block-vectors.json`; `CrosslinkProductionFixtureVectorsGenerated.qnt`; `test:head-sigma`; `test:dynamic-sigma-head-sampling`; `test:dynamic-sigma-heighted-round`; `test:heighted-head-sigma`; `test:bft-block-shape`; `test:bft-block-validation-gap`; `test:bft-block-production-vectors`; `test:fixture-manifest`; `test:generated-fixture-module`; `verify:head-sigma-safety`; `verify:dynamic-sigma-head-sampling-safety`; `verify:dynamic-sigma-heighted-round-safety`; `verify:heighted-head-sigma-safety`; `verify:bft-block-shape-safety`; `verify:bft-block-validation-gap-safety`; `verify:bft-block-production-vectors-safety` | partial | Abstract, heighted, dynamic-sigma, production-shape `head - sigma`, constructor-gap, and BFT-block wire-vector models exist. The checked-in `test_pos_block_*.bin` envelopes now have a generated manifest, generated Quint constants, and CI-checkable schema/formula/up-to-date validators; still need broader validation from production serialized blocks and regenerated fixture data after the implementation format stabilizes. |
| Proposal validity split | `StaticProposalValidity`, `StructurallyValid`, `PowChainValid`, `FinalityCandidateValid`, `IsFreshForRound`; `CrosslinkBftBlockShape.qnt`; `CrosslinkBftBlockValidationGap.qnt`; `CrosslinkBftBlockProductionVectors.qnt`; `test:proposal-validity`; `test:bft-block-shape`; `test:bft-block-validation-gap`; `test:bft-block-production-vectors`; `test:fixture-manifest`; `test:generated-fixture-module` | partial | Abstract validity split exists, and the specs now record that current `BftBlock::try_from` only enforces header count while documented version/order/PoW checks remain unimplemented. Production wire offsets, generated fixture-envelope metadata for current version-4 fixtures, and deserialization sigma-bypass are pinned; concrete production header validation still needs implementation. |
| Tendermint lock and valid-value rules | `lockedValue`, `lockedRound`, `validValue`, `validRound`, `ProposalUnlocksCurrentLock`; `ProposalFor` reuses only real `validValue`/`validRound` state; per-height lock/valid state and height-scoped valid-round unlock in `CrosslinkHeightedRound.qnt` | partial | Needs production proposal evidence encoding and broader production finality/auth/evidence integration. |
| Valid-round/POL evidence | `LocalValidRoundJustified`, `CorrectProposalValidRoundSound`; `test:valid-round`; `unjustifiedHeightedValidRoundProposalPrevotesNilTest`; `justifiedHeightedValidRoundUnlocksOlderLockTest` | covered | Needs production proposal evidence encoding. |
| Stream change between prevote and precommit | `UponStreamChangePrecommitNil`; baseline and resampling witnesses | covered | Needs broader temporal liveness and adversarial scheduling. |
| Stochastic PoW production and long reorgs | `CrosslinkHeadSigmaSampling.qnt`, `CrosslinkPowStochasticAssumptions.qnt`, `CrosslinkPowReorgStress.qnt`, `CrosslinkStreamChurnRisk.qnt`, `CrosslinkForkFinality.qnt`, and `CrosslinkHeightedHeadSigmaRound.qnt`; `test:pow-stochastic-assumptions`; `test:pow-reorg-stress`; `test:stream-churn-risk`; `verify:pow-stochastic-assumptions-safety`; `verify:pow-reorg-stress-safety`; `verify:stream-churn-risk-safety` | partial | Safety is modeled against adversarial bounded fork-tree evolution. The stress models cover long reorg and same-branch block-arrival churn, plus validator-set size, linear/quadratic GST, sigma, and reorg-depth tails with bounded integer risk numerators. `CrosslinkPowStochasticAssumptions.qnt` now pins Zebra's 75-second post-Blossom target spacing, makes normal block-arrival exposure an explicit Poisson/union-bound numerator, and constrains the long-reorg tail to a geometric sigma-decay profile; the numeric calibration is still assumed rather than measured. |
| Dynamic-sigma Crosslink variant | `CrosslinkDynamicSigma.qnt`; `CrosslinkDynamicSigmaConsensusParams.qnt`; `CrosslinkDynamicSigmaConsensusParamFormat.qnt`; `CrosslinkDynamicSigmaConsensusParamTransport.qnt`; `CrosslinkDynamicSigmaHeadSampling.qnt`; `CrosslinkDynamicSigmaHeightedRound.qnt`; `CrosslinkDynamicSigmaHeightedFinality.qnt`; `CrosslinkDynamicSigmaHeightedAuthenticatedEvidence.qnt`; `CrosslinkDynamicSigmaAuthenticatedFinality.qnt`; `CrosslinkDynamicSigmaModel`; `CrosslinkDynamicSigmaConsensusParamsModel`; `CrosslinkDynamicSigmaConsensusParamFormatModel`; `CrosslinkDynamicSigmaConsensusParamTransportModel`; `CrosslinkDynamicSigmaHeadSamplingModel`; `CrosslinkDynamicSigmaHeightedRoundModel`; `CrosslinkDynamicSigmaHeightedFinalityModel`; `CrosslinkDynamicSigmaHeightedAuthenticatedEvidenceModel`; `CrosslinkDynamicSigmaAuthenticatedFinalityModel`; `test:dynamic-sigma`; `test:dynamic-sigma-consensus-params`; `test:dynamic-sigma-consensus-param-format`; `test:dynamic-sigma-consensus-param-transport`; `test:dynamic-sigma-head-sampling`; `test:dynamic-sigma-heighted-round`; `test:dynamic-sigma-heighted-finality`; `test:dynamic-sigma-heighted-authenticated-evidence`; `test:dynamic-sigma-authenticated-finality`; `verify:dynamic-sigma-safety`; `verify:dynamic-sigma-consensus-params-safety`; `verify:dynamic-sigma-consensus-param-format-safety`; `verify:dynamic-sigma-consensus-param-transport-safety`; `verify:dynamic-sigma-head-sampling-safety`; `verify:dynamic-sigma-heighted-round-safety`; `verify:dynamic-sigma-heighted-finality-safety`; `verify:dynamic-sigma-heighted-authenticated-evidence-safety`; `verify:dynamic-sigma-authenticated-finality-safety`; `verify:extended:dynamic-sigma`; `verify:extended:dynamic-sigma-consensus-params`; `verify:extended:dynamic-sigma-consensus-param-format`; `verify:extended:dynamic-sigma-consensus-param-transport`; `verify:extended:dynamic-sigma-head-sampling`; `verify:extended:dynamic-sigma-heighted-round`; `verify:extended:dynamic-sigma-heighted-finality`; `verify:extended:dynamic-sigma-heighted-authenticated-evidence`; `verify:extended:dynamic-sigma-authenticated-finality` | partial | First controller model treats dynamic sigma as a third Crosslink variant, keeps sigma fixed for the active BFT height, updates only at height boundaries from committed telemetry, validator/network coverage evidence, and Crosslink-participating PoW hash-power percentage, refuses to raise sigma for same-branch block-arrival failures by themselves, and applies raise/decrease hysteresis. Low participating hash power contributes to long-reorg/ambiguous-failure pressure, prevents sigma relaxation below the target, and directly raises sigma below a critical participation floor. The consensus-param bridges check that committed next-height abstract wires and production-shaped bytes decode to the deterministic controller-selected sigma, cannot be rewritten by nil-round burns, reject malformed/stale/out-of-bounds/wrong-key/trailing-byte sigma envelopes, and include low-participation witnesses where the encoded next-height sigma rises. The format bridge pins key tag, u32 activation height, u32 telemetry height, u16 sigma layout, and exact little-endian hex vectors. The transport bridge now imports that production format bridge, requires quorum-signed canonical production param bytes on the Crosslink consensus topic before node config follows a committed next-height sigma, signs the format model's exact hex bytes, records the installed production wire beside the decoded abstract config, and rejects wrong-topic, wrong-kind, wrong-byte, wrong-signature, malformed production envelopes, no-quorum, quorum-signed stale activation, and nondeterministic-sigma updates. The head-sampling, heighted-round, heighted-finality, authenticated-evidence, and authenticated-finality bridges now check `head - sigma(h)` semantics across future-height sigma changes, including proposals, value precommits, nil-round resampling, a height transition, finality validation against the active height's dynamic sigma tail, and authenticated fat-pointer evidence for the dynamic candidate. Real implementation vectors and code integration remain open. |
| Nil-precommit same-round unlock | `StartNextRoundAfterPrecommitQuorum`, `ApplyLateNilPrecommitCertificate` | covered | None at current one-height abstraction level. |
| Preserve older locks | `nilPrecommitPreservesOlderTendermintValueLockTest`, `laterNilCertificateDoesNotUnlockOlderValueLockTest`, `nilResamplingDoesNotClearOtherHeightStateTest` | covered | Needs full composition with finality and production evidence formats. |
| Mixed precommit is not unlock evidence | `mixedPrecommitQuorumDoesNotUnlockTest` | covered | None. |
| Local receive/delivery semantics | `seenPropose`, `seenPrevote`, `seenPrecommit`, `Deliver*`; `test:local-delivery` | covered | Needs network scheduling/fairness assumptions. |
| Timeout transitions | `TimeoutProposePrevoteNil`, `TimeoutPrevotePrecommitNil`, `TimeoutPrecommitStartNextRound`; `test:timeout`; `precommitTimeoutDoesNotClearHeightedLockTest`; `timeoutWithoutValueLockNextFreshProposalResamplesTest` | partial | Needs fuller timeout scheduling and temporal properties. |
| Height-indexed round machine | `spec/CrosslinkHeightedRound.qnt`; `spec/CrosslinkHeightedHeadSigmaRound.qnt`; `spec/CrosslinkDynamicSigmaHeightedRound.qnt`; `spec/CrosslinkDynamicSigmaHeightedAuthenticatedEvidence.qnt`; `test:heighted-round`; `test:heighted-head-sigma`; `test:dynamic-sigma-heighted-round`; `test:dynamic-sigma-heighted-authenticated-evidence`; `verify:heighted-round-safety`; `verify:heighted-head-sigma-safety`; `verify:dynamic-sigma-heighted-round-safety`; `verify:dynamic-sigma-heighted-authenticated-evidence-safety` | partial | First receive-reactive heighted slice now has fixed-sigma and dynamic-sigma head-sigma stream linkage, plus a dynamic-sigma authenticated-evidence bridge; full production auth/evidence integration remains open. |
| Weighted voting power | `VotingPowerOf`, `QuorumVotingPower`; `test:weighted`; `CrosslinkFatPointerFormat.qnt`; `CrosslinkFatPointerProductionVectors.qnt`; `test:fat-pointer-production-vectors`; `verify:fat-pointer-production-vectors-safety` | covered | Production fat-pointer signer-vector, exact wire-envelope offset/length, checked-in fixture offsets/byte probes, and producer-round-data derivation shapes are modeled; broader production integration remains open. |
| Dynamic validator-set changes | `spec/CrosslinkValidatorSetChange.qnt`; `spec/CrosslinkHeightedValidatorEvidence.qnt`; `spec/CrosslinkHeightedAuthenticatedEvidence.qnt`; `spec/CrosslinkHeightedAuthenticatedGossipTransport.qnt`; `spec/CrosslinkFatPointerFormat.qnt`; `spec/CrosslinkFatPointerProductionVectors.qnt`; `spec/CrosslinkFatPointerAuthenticatedEvidence.qnt`; `test:validator-set-change`; `test:heighted-validator-evidence`; `test:heighted-authenticated-evidence`; `test:heighted-authenticated-gossip-transport`; `test:fat-pointer-format`; `test:fat-pointer-production-vectors`; `test:fat-pointer-authenticated-evidence`; `verify:validator-set-change-safety`; `verify:heighted-validator-evidence-safety`; `verify:heighted-authenticated-evidence-safety`; `verify:heighted-authenticated-gossip-transport-safety`; `verify:fat-pointer-format-safety`; `verify:fat-pointer-production-vectors-safety`; `verify:fat-pointer-authenticated-evidence-safety` | partial | Validator-set rotation is now linked to heighted authenticated evidence signer authorization, a Crosslink-topic transport-envelope boundary, production-shaped fat-pointer signer vectors, and pinned fat-pointer byte vectors; end-to-end integration remains open. |
| Message evidence bookkeeping | `CrosslinkMessageEvidenceModel`; `test:message-evidence` | covered | Needs production evidence encoding. |
| Evidence gossip and observer process | `spec/CrosslinkEvidenceGossip.qnt`; `spec/CrosslinkHeightedEvidenceGossip.qnt`; `spec/CrosslinkHeightedAuthenticatedEvidence.qnt`; `spec/CrosslinkHeightedAuthenticatedGossipTransport.qnt`; `spec/CrosslinkDynamicSigmaHeightedAuthenticatedEvidence.qnt`; `spec/CrosslinkDynamicSigmaAuthenticatedFinality.qnt`; `spec/CrosslinkFatPointerAuthenticatedEvidence.qnt`; `spec/CrosslinkFixtureAuthenticatedEvidence.qnt`; `spec/CrosslinkFixtureGossipTransport.qnt`; `test:evidence-gossip`; `test:heighted-evidence-gossip`; `test:heighted-authenticated-evidence`; `test:heighted-authenticated-gossip-transport`; `test:dynamic-sigma-heighted-authenticated-evidence`; `test:dynamic-sigma-authenticated-finality`; `test:fat-pointer-authenticated-evidence`; `test:fixture-authenticated-evidence`; `test:fixture-gossip-transport`; `verify:evidence-gossip-safety`; `verify:heighted-evidence-gossip-safety`; `verify:heighted-authenticated-evidence-safety`; `verify:heighted-authenticated-gossip-transport-safety`; `verify:dynamic-sigma-heighted-authenticated-evidence-safety`; `verify:dynamic-sigma-authenticated-finality-safety`; `verify:fat-pointer-authenticated-evidence-safety`; `verify:fixture-authenticated-evidence-safety`; `verify:fixture-gossip-transport-safety` | partial | Abstract standalone, first authenticated composition, a generic heighted authenticated gossip-transport bridge, dynamic-sigma authenticated evidence/finality composition, production-shaped fat-pointer observer models, generated-fixture observer bridge, and a fixture transport-gossip bridge exist, including exact counted-envelope and Crosslink-topic envelope checks; full concrete production gossip transport remains open. |
| Message authentication/canonical bytes | `spec/CrosslinkMessageAuth.qnt`; `spec/CrosslinkHeightedMessageAuth.qnt`; `spec/CrosslinkHeightedAuthenticatedEvidence.qnt`; `spec/CrosslinkHeightedAuthenticatedGossipTransport.qnt`; `spec/CrosslinkDynamicSigmaHeightedAuthenticatedEvidence.qnt`; `spec/CrosslinkDynamicSigmaAuthenticatedFinality.qnt`; `spec/CrosslinkFatPointerFormat.qnt`; `spec/CrosslinkFatPointerProductionVectors.qnt`; `spec/CrosslinkFatPointerAuthenticatedEvidence.qnt`; `spec/CrosslinkFixtureAuthenticatedEvidence.qnt`; `spec/CrosslinkFixtureGossipTransport.qnt`; `test:message-auth`; `test:heighted-message-auth`; `test:heighted-authenticated-evidence`; `test:heighted-authenticated-gossip-transport`; `test:dynamic-sigma-heighted-authenticated-evidence`; `test:dynamic-sigma-authenticated-finality`; `test:fat-pointer-format`; `test:fat-pointer-production-vectors`; `test:fat-pointer-authenticated-evidence`; `test:fixture-authenticated-evidence`; `test:fixture-gossip-transport`; `verify:message-auth-safety`; `verify:heighted-message-auth-safety`; `verify:heighted-authenticated-evidence-safety`; `verify:heighted-authenticated-gossip-transport-safety`; `verify:dynamic-sigma-heighted-authenticated-evidence-safety`; `verify:dynamic-sigma-authenticated-finality-safety`; `verify:fat-pointer-format-safety`; `verify:fat-pointer-production-vectors-safety`; `verify:fat-pointer-authenticated-evidence-safety`; `verify:fixture-authenticated-evidence-safety`; `verify:fixture-gossip-transport-safety` | partial | Abstract signature metadata, evidence-pipeline composition, generic heighted topic/kind envelope gating, dynamic-sigma evidence/finality authentication, production-shaped fat-pointer canonical bytes, production byte-vector offsets, generated fixture constants, full generated fixture sign-data/signature hex strings, generated-fixture observer linkage, real Ed25519 verification in the fixture-manifest gate, and fixture-level transport envelope gating exist; concrete serialized Tenderlink messages and full production gossip transport remain open. |
| Accountability witnesses | `ConflictingCommitsAccountable`, nil/value equivocation and invalid-unlock witnesses; `CrosslinkFatPointerFormat.qnt` duplicate-pubkey, removed-validator, wrong-payload, cross-height replay, low-power, wire-offset, trailing-byte, truncated-wire, and producer-round-data derivation witnesses; `CrosslinkFatPointerProductionVectors.qnt` `try_from_bytes` reversed-slice gap witness; `CrosslinkFatPointerAuthenticatedEvidence.qnt` gossip-before-observe, missing-signer, and trailing-byte wire witnesses; `docs/accountability.md` | covered | Production slashing evidence formats remain open. |
| Fork finality over PoW branches | `spec/CrosslinkForkFinality.qnt`; `test:finality`; `verify:finality-safety` | covered | Needs concrete PoW-chain data. |
| Multi-height finalized prefix | `spec/CrosslinkMultiHeight.qnt`; `spec/CrosslinkHeightedRound.qnt`; `spec/CrosslinkHeightedFinality.qnt`; `spec/CrosslinkDynamicSigmaHeightedFinality.qnt`; `spec/CrosslinkDynamicSigmaAuthenticatedFinality.qnt`; `test:multi-height`; `test:heighted-round`; `test:heighted-finality`; `test:dynamic-sigma-heighted-finality`; `test:dynamic-sigma-authenticated-finality`; `verify:multi-height-safety`; `verify:heighted-round-safety`; `verify:heighted-finality-safety`; `verify:dynamic-sigma-heighted-finality-safety`; `verify:dynamic-sigma-authenticated-finality-safety` | partial | Heighted finality exists for fixed and dynamic sigma, including authenticated dynamic finality; production data/linkage remains abstract. |
| Composed round recovery plus finality | `spec/CrosslinkComposed.qnt`; `spec/CrosslinkHeightedFinality.qnt`; `spec/CrosslinkDynamicSigmaHeightedFinality.qnt`; `spec/CrosslinkDynamicSigmaAuthenticatedFinality.qnt`; `spec/CrosslinkComposedProgressContract.qnt`; `test:composed`; `test:heighted-finality`; `test:dynamic-sigma-heighted-finality`; `test:dynamic-sigma-authenticated-finality`; `test:composed-progress-contract`; `verify:composed-safety`; `verify:heighted-finality-safety`; `verify:dynamic-sigma-heighted-finality-safety`; `verify:dynamic-sigma-authenticated-finality-safety`; `verify:composed-progress-contract-safety` | partial | Heighted fixed-sigma, dynamic-sigma, and authenticated dynamic-sigma finality compositions plus a TLC-sized composed progress contract exist; production data/linkage and a temporal proof over the full imported protocol remain abstract. |
| Liveness under stream stability | `NilPrecommitResamplingStableWindowLiveness`, `CrosslinkComposedLivenessModel`, `CrosslinkSchedulerLivenessModel`, `CrosslinkSchedulerProgressContractModel`, `CrosslinkFinalityProgressContractModel`, `CrosslinkComposedProgressContractModel`; `test:scheduler-liveness`; `test:scheduler-progress-contract`; `test:finality-progress-contract`; `test:composed-progress-contract`; `verify:scheduler-liveness-safety`; `verify:scheduler-progress-contract-safety`; `verify:finality-progress-contract-safety`; `verify:composed-progress-contract-safety`; `verify:temporal` | partial | Bounded scheduler-parametric checks and TLC temporal contracts now cover scheduler progress, decision-to-finality progress, and a self-contained composed nil-resampling/finality progress slice; no full imported round-machine temporal liveness proof yet. |
| CI for checks | `package.json` scripts and `.github/workflows/quint.yml` | covered | Latest pushed commit may still be running until GitHub Actions completes. |
| Documentation mapping to Tendermint | `docs/tendermint-crosslink-map.md`, `docs/implementation-correspondence.md`, `docs/spec-roadmap.md` | covered | Should keep updated as models become less abstract. |

## Current Verification Gates

The package scripts currently cover:

```text
npm run typecheck
npm test
npm run verify
npm run verify:extended
npm run verify:temporal
```

`npm test` covers baseline, resampling, evidence bookkeeping, weighted quorum,
message evidence, local delivery, timeout, liveness witnesses, scheduler
liveness, scheduler progress contract, finality progress contract, composed
progress contract, stream-churn risk, PoW stochastic assumptions,
PoW-reorg stress, dynamic-sigma controller, dynamic-sigma head-sampling,
dynamic-sigma consensus-params, dynamic-sigma consensus-param-format,
dynamic-sigma consensus-param-transport,
dynamic-sigma heighted-round,
dynamic-sigma heighted-finality,
dynamic-sigma heighted-authenticated-evidence, dynamic-sigma authenticated-finality,
head-sigma sampling, heighted head-sigma rounds,
BFT-block header shape checks,
BFT-block validation-gap checks, BFT-block production-vector checks,
BFT-block fixture-manifest validation and generated-Quint fixture validation,
fat-pointer signer-vector format checks, fat-pointer production-vector checks,
fat-pointer
authenticated-evidence checks, fixture-authenticated evidence checks,
fixture-gossip transport checks, proposal validity, valid-round evidence, fork
finality, composed resampling/finality, composed liveness, multi-height finality,
height-indexed round-machine behavior, heighted finality composition, evidence
gossip, heighted evidence gossip, message authentication, heighted message
authentication, validator-set changes, heighted validator evidence, heighted
authenticated evidence, and heighted authenticated gossip transport.

`npm run verify` currently runs bounded Apalache safety checks, mostly at
depth 3, with the smaller fat-pointer format model checked at depth 5, for:

```text
BaselineCrosslink
NilPrecommitResamplingCrosslink
CrosslinkForkFinalityModel
CrosslinkComposedResamplingModel
CrosslinkMultiHeightModel
CrosslinkHeightedRoundModel
CrosslinkHeightedFinalityModel
CrosslinkEvidenceGossipModel
CrosslinkHeightedEvidenceGossipModel
CrosslinkMessageAuthModel
CrosslinkHeightedMessageAuthModel
CrosslinkValidatorSetChangeModel
CrosslinkHeightedValidatorEvidenceModel
CrosslinkHeightedAuthenticatedEvidenceModel
CrosslinkHeightedAuthenticatedGossipTransportModel
CrosslinkSchedulerLivenessModel
CrosslinkSchedulerProgressContractModel
CrosslinkFinalityProgressContractModel
CrosslinkComposedProgressContractModel
CrosslinkStreamChurnRiskModel
CrosslinkPowStochasticAssumptionsModel
CrosslinkPowReorgStressModel
CrosslinkDynamicSigmaModel
CrosslinkDynamicSigmaConsensusParamsModel
CrosslinkDynamicSigmaConsensusParamFormatModel
CrosslinkDynamicSigmaConsensusParamTransportModel
CrosslinkDynamicSigmaHeadSamplingModel
CrosslinkDynamicSigmaHeightedRoundModel
CrosslinkDynamicSigmaHeightedFinalityModel
CrosslinkDynamicSigmaHeightedAuthenticatedEvidenceModel
CrosslinkDynamicSigmaAuthenticatedFinalityModel
CrosslinkHeadSigmaSamplingModel
CrosslinkHeightedHeadSigmaRoundModel
CrosslinkBftBlockShapeModel
CrosslinkBftBlockValidationGapModel
CrosslinkBftBlockProductionVectorsModel
CrosslinkFatPointerFormatModel
CrosslinkFatPointerProductionVectorsModel
CrosslinkFatPointerAuthenticatedEvidenceModel
CrosslinkFixtureAuthenticatedEvidenceModel
CrosslinkFixtureGossipTransportModel
```

`npm run verify:extended` is a non-default deeper gate for the newest
finality-progress, composed-progress, stream-churn, PoW stochastic-assumption,
PoW-reorg stress, dynamic-sigma controller, dynamic-sigma consensus-params,
dynamic-sigma consensus-param-format, dynamic-sigma consensus-param-transport,
dynamic-sigma head-sampling, dynamic-sigma heighted-round,
dynamic-sigma heighted-finality,
dynamic-sigma heighted-authenticated-evidence,
dynamic-sigma authenticated-finality,
head-sigma stream, BFT-block-shape, BFT-block
validation-gap, BFT-block production-vector, fat-pointer-format, fat-pointer
production-vector, evidence-composition, fixture-authenticated evidence, and
fixture-gossip transport, and heighted authenticated gossip transport models.
It currently runs depth-5 Apalache checks, with the PoW-reorg stress model
also checked at depth 8, for:

```text
CrosslinkFinalityProgressContractModel
CrosslinkComposedProgressContractModel
CrosslinkStreamChurnRiskModel
CrosslinkPowStochasticAssumptionsModel
CrosslinkPowReorgStressModel
CrosslinkDynamicSigmaModel
CrosslinkDynamicSigmaConsensusParamsModel
CrosslinkDynamicSigmaConsensusParamFormatModel
CrosslinkDynamicSigmaConsensusParamTransportModel
CrosslinkDynamicSigmaHeadSamplingModel
CrosslinkDynamicSigmaHeightedRoundModel
CrosslinkDynamicSigmaHeightedFinalityModel
CrosslinkDynamicSigmaHeightedAuthenticatedEvidenceModel
CrosslinkDynamicSigmaAuthenticatedFinalityModel
CrosslinkHeadSigmaSamplingModel
CrosslinkHeightedHeadSigmaRoundModel
CrosslinkBftBlockShapeModel
CrosslinkBftBlockValidationGapModel
CrosslinkBftBlockProductionVectorsModel
CrosslinkFatPointerFormatModel
CrosslinkFatPointerProductionVectorsModel
CrosslinkFatPointerAuthenticatedEvidenceModel
CrosslinkFixtureAuthenticatedEvidenceModel
CrosslinkFixtureGossipTransportModel
CrosslinkHeightedValidatorEvidenceModel
CrosslinkHeightedAuthenticatedEvidenceModel
CrosslinkHeightedAuthenticatedGossipTransportModel
```

`npm run verify:temporal` currently runs TLC on:

```text
CrosslinkSchedulerProgressContractModel / EventuallyStableDecision
CrosslinkFinalityProgressContractModel / EventuallyFinalized
CrosslinkComposedProgressContractModel / EventuallyFinalizesStableDecision
```

These are temporal progress contracts for the scheduler envelope, the
scheduler-to-finality handoff, and a self-contained composed
nil-resampling/finality slice. They are not yet temporal proofs over the full
imported protocol state.

A direct TLC run over the current imported `CrosslinkComposed` state is not in
the gate yet: the map-heavy imported round-machine state currently fails in the
Quint-to-TLA/TLC path before state exploration. The standalone progress
contracts are the green temporal bridge until that imported-state shape or
backend support is refactored.

## Remaining Work

The goal is not complete yet. The strongest remaining gaps are:

- lift the TLC-checked progress contracts into a general temporal liveness
  proof over the imported composed protocol under post-GST stream stability;
- replace the current analytic PoW-arrival, propagation-race, GST scaling, and
  long-tail reorg numerators with measured distributions;
- expand the generated BFT-block fixture manifest beyond the current
  checked-in `test_pos_block_*.bin` envelopes, regenerate it as the production
  block format stabilizes, and add production code coverage for version,
  header-order, and PoW-solution checks;
- link message-authentication and evidence-gossip models to concrete production
  serialization, signatures, and full production gossip transport; the abstract
  heighted transport bridge exists, but not real Tenderlink message vectors;
- link the dynamic-sigma consensus-param format/transport models to real
  implementation serialization vectors, signatures, gossip, and node
  configuration update paths;
- extend the script-level Ed25519 fixture verification, fixture-gossip transport
  bridge, and abstract heighted transport bridge into full production
  gossip/transport integration;
- continue expanding bounded verification depth and targeted counterexample
  searches beyond the current depth-5 extended gate for the new standalone
  models.
