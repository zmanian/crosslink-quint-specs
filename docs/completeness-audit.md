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
| Shared protocol core with explicit variants | Shared `CrosslinkResampling` core with baseline/resampling modules, plus standalone `CrosslinkDynamicSigmaModel`, `CrosslinkDynamicSigmaCalibrationModel`, `CrosslinkDynamicSigmaTelemetryModel`, `CrosslinkDynamicSigmaProposalEvidenceFormatModel`, `CrosslinkDynamicSigmaBftPayloadTransportModel`, `CrosslinkDynamicSigmaPrototypeDecodeGateModel`, `CrosslinkProductionDynamicSigmaConsensusParamIngressBridgeModel`, `CrosslinkProductionDynamicSigmaConsensusParamIngressBridgeSafetyModel`, `CrosslinkProductionDynamicSigmaPayloadIngressBridgeModel`, `CrosslinkProductionDynamicSigmaPayloadIngressBridgeSafetyModel`, `CrosslinkDynamicSigmaForkScheduleModel`, `CrosslinkDynamicSigmaBranchCompetitionModel`, `CrosslinkDynamicSigmaResamplingModel`, `CrosslinkDynamicSigmaFinalityModel`, `CrosslinkDynamicSigmaConsensusParamsModel`, `CrosslinkDynamicSigmaConsensusParamFormatModel`, `CrosslinkDynamicSigmaConsensusParamTransportModel`, `CrosslinkDynamicSigmaHeadSamplingModel`, `CrosslinkDynamicSigmaHeightedRoundModel`, `CrosslinkDynamicSigmaHeightedFinalityModel`, `CrosslinkDynamicSigmaHeightedAuthenticatedEvidenceModel`, and `CrosslinkDynamicSigmaAuthenticatedFinalityModel` for the third dynamic-sigma variant | partial | Dynamic sigma is first-class in the spec surface and now bridged through measured-window calibration, a production-shaped telemetry contract, Zebra's production proposal-evidence byte payload, the tagged dynamic-sigma BFT payload transport boundary, Zebra prototype decode gate, production ingress bridges and verifier-friendly projections for signed consensus-param config and tagged dynamic payload transport/decode, derived fork-schedule and branch-competition rollback signals, nil-precommit resampling, Crosslink finality, an abstract consensus-parameter envelope, a production-shaped consensus-param byte format, authenticated production-byte gossip/config application, head-sigma sampling, the heighted round machine, and authenticated evidence/finality; broader code integration remains open. |
| Proposal values as PoW stream snapshots | `Stream(round)`, `StickyOrStreamProposal`, `IsFreshForRound`, `CrosslinkHeadSigmaSamplingModel`, `CrosslinkDynamicSigmaHeadSamplingModel`, `CrosslinkDynamicSigmaHeightedRoundModel`, `CrosslinkHeightedHeadSigmaRoundModel`, `CrosslinkBftBlockShapeModel`, `CrosslinkBftBlockValidationGapModel`, `CrosslinkBftBlockProductionVectorsModel`, `CrosslinkProductionFinalityProjectionContractModel`; `fixtures/production-bft-block-vectors.json`; `CrosslinkProductionFixtureVectorsGenerated.qnt`; `test:head-sigma`; `test:dynamic-sigma-head-sampling`; `test:dynamic-sigma-heighted-round`; `test:heighted-head-sigma`; `test:bft-block-shape`; `test:bft-block-validation-gap`; `test:bft-block-production-vectors`; `test:fixture-manifest`; `test:generated-fixture-module`; `test:production-finality-projection-contract`; `verify:head-sigma-safety`; `verify:dynamic-sigma-head-sampling-safety`; `verify:dynamic-sigma-heighted-round-safety`; `verify:heighted-head-sigma-safety`; `verify:bft-block-shape-safety`; `verify:bft-block-validation-gap-safety`; `verify:bft-block-production-vectors-safety`; `verify:production-finality-projection-contract-safety` | partial | Abstract, heighted, dynamic-sigma, production-shape `head - sigma`, constructor-gap, BFT-block wire-vector, and production-fixture proposal/finality-gate models exist. The generated manifest now covers both checked-in `test_pos_block_*.bin` BFT envelopes and raw `test_pow_block_*.bin` blocks, links embedded BFT headers back to matching raw PoW fixture headers, exposes serialized BFT-block version/height/finalization/header-prefix constants, pins the full checked-in BFT-height sequence and adjacent fat-pointer continuity, and has CI-checkable schema/formula/up-to-date validators; the production-finality projection now requires the checked-in BFT-block candidate to arrive through a proposal transport envelope whose serialized prefix fields match the generated fixture before finality, but broader validation from production serialized blocks and regenerated fixture data after the implementation format stabilizes remains open. |
| Proposal validity split | `StaticProposalValidity`, `StructurallyValid`, `PowChainValid`, `FinalityCandidateValid`, `IsFreshForRound`; `CrosslinkBftBlockShape.qnt`; `CrosslinkBftBlockValidationGap.qnt`; `CrosslinkBftBlockProductionVectors.qnt`; `test:proposal-validity`; `test:bft-block-shape`; `test:bft-block-validation-gap`; `test:bft-block-production-vectors`; `test:fixture-manifest`; `test:generated-fixture-module` | partial | Abstract validity split exists, and the specs now record that current `BftBlock::try_from` only enforces header count while documented version/order/PoW checks remain unimplemented. The validation-gap slice also pins repaired constructor and deserializer targets with exact intended acceptance and no over-acceptance for bad version, bad order, bad PoW, wrong sigma count, or counted-envelope deserialization bypass. Production wire offsets, serialized BFT-block version/height/finalization prefix fields, generated fixture-envelope metadata for current version-4 fixtures, raw PoW block header/body vector metadata, and full checked-in fixture-sequence metadata are pinned; concrete production header validation still needs implementation. |
| Tendermint lock and valid-value rules | `lockedValue`, `lockedRound`, `validValue`, `validRound`, `ProposalUnlocksCurrentLock`; `ProposalFor` reuses only real `validValue`/`validRound` state; per-height lock/valid state and height-scoped valid-round unlock in `CrosslinkHeightedRound.qnt`; `CrosslinkTenderlinkProposalPolEvidence.qnt` bridges non-nil `validRound` proposal chunks to canonical prevote packet evidence; `CrosslinkTenderlinkProposalPolTransport.qnt` links that evidence to exact compact Tenderlink transport receipt | partial | Needs broader production finality/auth/evidence integration and real larger-validator-set vectors from implementation fixtures. |
| Valid-round/POL evidence | `LocalValidRoundJustified`, `CorrectProposalValidRoundSound`; `CrosslinkTenderlinkProposalPolEvidence.qnt`; `CrosslinkTenderlinkProposalPolTransport.qnt`; `test:valid-round`; `test:tenderlink-proposal-pol-evidence`; `test:tenderlink-proposal-pol-transport`; `unjustifiedHeightedValidRoundProposalPrevotesNilTest`; `justifiedHeightedValidRoundUnlocksOlderLockTest`; `verify:tenderlink-proposal-pol-evidence-safety`; `verify:tenderlink-proposal-pol-transport-safety` | covered | Full production gossip integration beyond the compact Tenderlink packet boundary remains open; the bounded production-shaped bridge now covers weighted packet power, a five-entry larger-validator-set quorum, and exact transport receipt for the proposal/POL pair. |
| Stream change between prevote and precommit | `UponStreamChangePrecommitNil`; baseline and resampling witnesses; `CrosslinkBaselineChurnProgressContract.qnt`; `test:baseline-churn-progress-contract`; `verify:baseline-churn-progress-contract-safety`; `verify:temporal:baseline-churn-progress-contract` | covered | The TLC-sized contract now shows the specific sticky-baseline halt and nil-precommit resampling recovery path; full imported/adversarial scheduling remains open. |
| Stochastic PoW production and long reorgs | `CrosslinkHeadSigmaSampling.qnt`, `CrosslinkPowStochasticAssumptions.qnt`, `CrosslinkPowFixtureMeasuredDistribution.qnt`, `CrosslinkPowForkSchedule.qnt`, `CrosslinkPowBranchCompetition.qnt`, `CrosslinkPowReorgStress.qnt`, `CrosslinkStreamChurnRisk.qnt`, `CrosslinkValidatorScaleLivenessEnvelope.qnt`, `CrosslinkValidatorScaleProgressContract.qnt`, `CrosslinkValidatorScaleFinalityProgressContract.qnt`, `CrosslinkForkFinality.qnt`, and `CrosslinkHeightedHeadSigmaRound.qnt`; `test:pow-stochastic-assumptions`; `test:pow-fixture-measured-distribution`; `test:pow-fork-schedule`; `test:pow-branch-competition`; `test:pow-reorg-stress`; `test:stream-churn-risk`; `test:validator-scale-liveness-envelope`; `test:validator-scale-progress-contract`; `test:validator-scale-finality-progress-contract`; `verify:pow-stochastic-assumptions-safety`; `verify:pow-fixture-measured-distribution-safety`; `verify:pow-fork-schedule-safety`; `verify:pow-branch-competition-safety`; `verify:pow-reorg-stress-safety`; `verify:stream-churn-risk-safety`; `verify:validator-scale-liveness-envelope-safety`; `verify:validator-scale-progress-contract-safety`; `verify:validator-scale-finality-progress-contract-safety`; `verify:temporal:validator-scale-progress-contract`; `verify:temporal:validator-scale-finality-progress-contract` | partial | Safety is modeled against adversarial bounded fork-tree evolution. The stress models cover long reorg and same-branch block-arrival churn, plus validator-set size, linear/quadratic GST, sigma, derived best-tip rollback depth, published-tip branch competition, and reorg-depth tails with bounded integer risk numerators. `CrosslinkValidatorScaleLivenessEnvelope.qnt` checks the qualitative scale argument directly: a globally distributed larger validator set can exceed the baseline halt-risk budget while staying inside a finite nil-resampling round-burn budget, and larger sigma does not reduce normal head-arrival exposure. `CrosslinkValidatorScaleProgressContract.qnt` makes that scale case temporal in a finite TLC graph: the stressed baseline halts, while nil-precommit resampling burns the bounded churn rounds and reaches a stable decision. `CrosslinkValidatorScaleFinalityProgressContract.qnt` then composes the same path with finality and checks eventual finalization of the stable candidate while rejecting the competing fork candidate. `CrosslinkPowStochasticAssumptions.qnt` pins Zebra's 75-second post-Blossom target spacing, makes normal block-arrival exposure an explicit Poisson/union-bound numerator, and constrains the long-reorg tail to a geometric sigma-decay profile. `CrosslinkPowFixtureMeasuredDistribution.qnt` imports generated raw-PoW fixture timestamps and pins the checked-in interval distribution, while explicitly recording that the deterministic fixtures are not production stochastic calibration data; production calibration remains open. |
| Dynamic-sigma Crosslink variant | `CrosslinkDynamicSigma.qnt`; `CrosslinkDynamicSigmaCalibration.qnt`; `CrosslinkDynamicSigmaTelemetry.qnt`; `CrosslinkDynamicSigmaProposalEvidenceFormat.qnt`; `CrosslinkDynamicSigmaBftPayloadTransport.qnt`; `CrosslinkDynamicSigmaPrototypeDecodeGate.qnt`; `CrosslinkProductionDynamicSigmaConsensusParamIngressBridge.qnt`; `CrosslinkProductionDynamicSigmaConsensusParamIngressBridgeSafety.qnt`; `CrosslinkProductionDynamicSigmaPayloadIngressBridge.qnt`; `CrosslinkProductionDynamicSigmaPayloadIngressBridgeSafety.qnt`; `CrosslinkDynamicSigmaForkSchedule.qnt`; `CrosslinkDynamicSigmaBranchCompetition.qnt`; `CrosslinkDynamicSigmaResampling.qnt`; `CrosslinkDynamicSigmaFinality.qnt`; `CrosslinkDynamicSigmaConsensusParams.qnt`; `CrosslinkDynamicSigmaConsensusParamFormat.qnt`; `CrosslinkDynamicSigmaConsensusParamTransport.qnt`; `CrosslinkDynamicSigmaHeadSampling.qnt`; `CrosslinkDynamicSigmaHeightedRound.qnt`; `CrosslinkDynamicSigmaHeightedFinality.qnt`; `CrosslinkDynamicSigmaHeightedAuthenticatedEvidence.qnt`; `CrosslinkDynamicSigmaAuthenticatedFinality.qnt`; `CrosslinkDynamicSigmaModel`; `CrosslinkDynamicSigmaCalibrationModel`; `CrosslinkDynamicSigmaTelemetryModel`; `CrosslinkDynamicSigmaProposalEvidenceFormatModel`; `CrosslinkDynamicSigmaBftPayloadTransportModel`; `CrosslinkDynamicSigmaPrototypeDecodeGateModel`; `CrosslinkProductionDynamicSigmaConsensusParamIngressBridgeModel`; `CrosslinkProductionDynamicSigmaConsensusParamIngressBridgeSafetyModel`; `CrosslinkProductionDynamicSigmaPayloadIngressBridgeModel`; `CrosslinkProductionDynamicSigmaPayloadIngressBridgeSafetyModel`; `CrosslinkDynamicSigmaForkScheduleModel`; `CrosslinkDynamicSigmaBranchCompetitionModel`; `CrosslinkDynamicSigmaResamplingModel`; `CrosslinkDynamicSigmaFinalityModel`; `CrosslinkDynamicSigmaConsensusParamsModel`; `CrosslinkDynamicSigmaConsensusParamFormatModel`; `CrosslinkDynamicSigmaConsensusParamTransportModel`; `CrosslinkDynamicSigmaHeadSamplingModel`; `CrosslinkDynamicSigmaHeightedRoundModel`; `CrosslinkDynamicSigmaHeightedFinalityModel`; `CrosslinkDynamicSigmaHeightedAuthenticatedEvidenceModel`; `CrosslinkDynamicSigmaAuthenticatedFinalityModel`; `test:dynamic-sigma`; `test:dynamic-sigma-calibration`; `test:dynamic-sigma-telemetry`; `test:dynamic-sigma-proposal-evidence-format`; `test:dynamic-sigma-bft-payload-transport`; `test:dynamic-sigma-prototype-decode-gate`; `test:production-dynamic-sigma-consensus-param-ingress-bridge`; `test:production-dynamic-sigma-consensus-param-ingress-bridge-safety`; `test:production-dynamic-sigma-payload-ingress-bridge`; `test:production-dynamic-sigma-payload-ingress-bridge-safety`; `test:dynamic-sigma-fork-schedule`; `test:dynamic-sigma-branch-competition`; `test:dynamic-sigma-resampling`; `test:dynamic-sigma-finality`; `test:dynamic-sigma-consensus-params`; `test:dynamic-sigma-consensus-param-format`; `test:dynamic-sigma-consensus-param-transport`; `test:dynamic-sigma-head-sampling`; `test:dynamic-sigma-heighted-round`; `test:dynamic-sigma-heighted-finality`; `test:dynamic-sigma-heighted-authenticated-evidence`; `test:dynamic-sigma-authenticated-finality`; `verify:dynamic-sigma-safety`; `verify:dynamic-sigma-calibration-safety`; `verify:dynamic-sigma-telemetry-safety`; `verify:dynamic-sigma-proposal-evidence-format-safety`; `verify:dynamic-sigma-bft-payload-transport-safety`; `verify:dynamic-sigma-prototype-decode-gate-safety`; `verify:production-dynamic-sigma-consensus-param-ingress-bridge-safety`; `verify:production-dynamic-sigma-payload-ingress-bridge-safety`; `verify:dynamic-sigma-fork-schedule-safety`; `verify:dynamic-sigma-branch-competition-safety`; `verify:dynamic-sigma-resampling-safety`; `verify:dynamic-sigma-finality-safety`; `verify:dynamic-sigma-consensus-params-safety`; `verify:dynamic-sigma-consensus-param-format-safety`; `verify:dynamic-sigma-consensus-param-transport-safety`; `verify:dynamic-sigma-head-sampling-safety`; `verify:dynamic-sigma-heighted-round-safety`; `verify:dynamic-sigma-heighted-finality-safety`; `verify:dynamic-sigma-heighted-authenticated-evidence-safety`; `verify:dynamic-sigma-authenticated-finality-safety`; `verify:extended:dynamic-sigma`; `verify:extended:dynamic-sigma-calibration`; `verify:extended:dynamic-sigma-telemetry`; `verify:extended:dynamic-sigma-proposal-evidence-format`; `verify:extended:dynamic-sigma-bft-payload-transport`; `verify:extended:dynamic-sigma-prototype-decode-gate`; `verify:extended:production-dynamic-sigma-consensus-param-ingress-bridge`; `verify:extended:production-dynamic-sigma-payload-ingress-bridge`; `verify:extended:dynamic-sigma-fork-schedule`; `verify:extended:dynamic-sigma-branch-competition`; `verify:extended:dynamic-sigma-resampling`; `verify:extended:dynamic-sigma-finality-protocol-projection`; `verify:extended:dynamic-sigma-finality-finality-projection`; `verify:extended:dynamic-sigma-finality-work-competition-projection`; `verify:extended:dynamic-sigma-consensus-params`; `verify:extended:dynamic-sigma-consensus-param-format`; `verify:extended:dynamic-sigma-consensus-param-transport`; `verify:extended:dynamic-sigma-head-sampling`; `verify:extended:dynamic-sigma-heighted-round`; `verify:extended:dynamic-sigma-heighted-finality`; `verify:extended:dynamic-sigma-heighted-authenticated-evidence`; `verify:extended:dynamic-sigma-authenticated-finality` | partial | First controller model treats dynamic sigma as a third Crosslink variant, keeps sigma fixed for the active BFT height, updates only at height boundaries from committed telemetry, validator/network coverage evidence, and Crosslink-participating PoW hash-power percentage, refuses to raise sigma for same-branch block-arrival failures by themselves, and applies raise/decrease hysteresis. Low participating hash power contributes to long-reorg/ambiguous-failure pressure, prevents sigma relaxation below the target, and directly raises sigma below a critical participation floor. The measured calibration harness classifies bounded hash-participation, round-failure, block-variance, and reorg-depth windows into expected sigma floors; the telemetry contract then derives participation from Crosslink-participating work over total observed work, checks conservative coverage/round-failure estimates, monotone rollback-risk curves, and explicit rollback-risk plus expected-loss budgets over nine bounded windows. The proposal-evidence format slice now pins Zebra's 123-byte `DynamicSigmaProposalEvidence` serialization, including split u128 high/low words, exact degraded-participation and wide-counter hex vectors, and rejection of trailing/wrong bytes or selected sigma below the deterministic floor. The BFT-payload transport slice pins the adjacent `CLDSIG01 || evidence || BftBlock` payload boundary, imports the checked-in BFT-block fixture shape, and rejects wrong magic/topic/kind, noncanonical evidence, evidence-byte mismatch, selected-sigma mismatch, and header-count mismatch. The prototype decode-gate slice mirrors Zebra's `dynamic_sigma_prototype` guard, rejecting tagged bytes by default, preventing fixed-sigma fallback, and accepting dynamic payloads with evidence-selected confirmation depth only when the gate is enabled. The production consensus-param ingress bridge now requires raised/recovered dynamic-sigma param records to pass the production gossip registry and node ingress lane before quorum-signed gossip can install node config; the safety projection keeps the same ordering in an Apalache-friendly scalar graph. The production payload ingress bridge now requires the tagged dynamic-sigma BFT payload to pass the production gossip registry and node ingress lane before transport acceptance or prototype decode can occur, while rejecting Tenderlink and production-finality traffic as substitutes; the safety projection keeps the same ordering in an Apalache-friendly scalar graph. The fork-schedule and branch-competition bridges feed rollback depth derived from best-tip transitions and published-tip work competition into the controller; the resampling/finality bridge checks that this derived signal can raise sigma before nil-precommit recovery decides a fresh stream value, then uses live dynamic sigma as the Crosslink finality tail depth. The consensus-param bridges check that committed next-height abstract wires and production-shaped bytes decode to the deterministic controller-selected sigma, cannot be rewritten by nil-round burns, reject malformed/stale/out-of-bounds/wrong-key/trailing-byte sigma envelopes, and include low-participation witnesses where the encoded next-height sigma rises. The format bridge pins key tag, u32 activation height, u32 telemetry height, u16 sigma layout, and exact little-endian hex vectors. The transport bridge now imports that production format bridge, requires quorum-signed canonical production param bytes on the Crosslink consensus topic before node config follows a committed next-height sigma, signs the format model's exact hex bytes, records the installed production wire beside the decoded abstract config, and rejects wrong-topic, wrong-kind, wrong-byte, wrong-signature, malformed production envelopes, no-quorum, quorum-signed stale activation, and nondeterministic-sigma updates. The head-sampling, heighted-round, heighted-finality, authenticated-evidence, and authenticated-finality bridges now check `head - sigma(h)` semantics across future-height sigma changes, including proposals, value precommits, nil-round resampling, a height transition, finality validation against the active height's dynamic sigma tail, and authenticated fat-pointer evidence for the dynamic candidate. Broader code integration remains open. |
| Nil-precommit same-round unlock | `StartNextRoundAfterPrecommitQuorum`, `ApplyLateNilPrecommitCertificate`, `CrosslinkMixedWaitProgressContract.qnt`; `test:mixed-wait-progress-contract`; `verify:mixed-wait-progress-contract-safety`; `verify:temporal:mixed-wait-progress-contract` | covered | The new TLC-sized progress contract checks that same-round state unlocks only after a real nil-precommit certificate, after mixed precommit waiting. |
| Preserve older locks | `nilPrecommitPreservesOlderTendermintValueLockTest`, `laterNilCertificateDoesNotUnlockOlderValueLockTest`, `nilResamplingDoesNotClearOtherHeightStateTest`, `CrosslinkMixedWaitProgressContractModel`, `CrosslinkHeightedAuthenticatedProgressProjectionContractModel`, `CrosslinkRotatingAuthenticatedProgressProjectionContractModel` | covered | The mixed-wait contract preserves older locks while clearing only same-round state after a nil certificate, and the authenticated heighted projections check that the recovery path does not create observer evidence or finality before a recovered height decides. The rotating projection also checks that validator-set rotation does not admit removed/new signers at the wrong height. Concrete production evidence formats remain open. |
| Mixed precommit is not unlock evidence | `mixedPrecommitQuorumDoesNotUnlockTest`; `CrosslinkMixedWaitProgressContract.qnt`; `test:mixed-wait-progress-contract`; `verify:mixed-wait-progress-contract-safety`; `verify:temporal:mixed-wait-progress-contract` | covered | None at the current abstraction level; the TLC contract now checks mixed quorum waiting followed by later nil-certificate recovery. |
| Local receive/delivery semantics | `seenPropose`, `seenPrevote`, `seenPrecommit`, `Deliver*`; `CrosslinkDeliveryFairnessContract.qnt`; `test:local-delivery`; `test:delivery-fairness-contract`; `verify:delivery-fairness-contract-safety`; `verify:temporal:delivery-fairness-contract` | partial | Local delivery is modeled in the round machine and a TLC-sized fairness envelope now checks that delivered receiver-local messages, not broadcast alone, create local quorum evidence and eventually let a correct decider see a precommit quorum. Full imported network scheduling and timing proof remains open. |
| Timeout transitions | `TimeoutProposePrevoteNil`, `TimeoutPrevotePrecommitNil`, `TimeoutPrecommitStartNextRound`; `CrosslinkTimeoutProgressContract.qnt`; `test:timeout`; `test:timeout-progress-contract`; `precommitTimeoutDoesNotClearHeightedLockTest`; `timeoutWithoutValueLockNextFreshProposalResamplesTest`; `verify:timeout-progress-contract-safety`; `verify:temporal:timeout-progress-contract` | partial | Timeout temporal envelope now checks round burn, nil-certificate recovery, older-lock preservation, and stable justified decision; full imported round-machine/network timing temporal proof remains open. |
| Height-indexed round machine | `spec/CrosslinkHeightedRound.qnt`; `spec/CrosslinkHeightedHeadSigmaRound.qnt`; `spec/CrosslinkDynamicSigmaHeightedRound.qnt`; `spec/CrosslinkDynamicSigmaHeightedAuthenticatedEvidence.qnt`; `spec/CrosslinkHeightedProgressProjectionContract.qnt`; `spec/CrosslinkHeightedAuthenticatedProgressProjectionContract.qnt`; `spec/CrosslinkRotatingAuthenticatedProgressProjectionContract.qnt`; `test:heighted-round`; `test:heighted-head-sigma`; `test:dynamic-sigma-heighted-round`; `test:dynamic-sigma-heighted-authenticated-evidence`; `test:heighted-progress-projection-contract`; `test:heighted-authenticated-progress-projection-contract`; `test:rotating-authenticated-progress-projection-contract`; `verify:heighted-round-safety`; `verify:heighted-head-sigma-safety`; `verify:dynamic-sigma-heighted-round-safety`; `verify:dynamic-sigma-heighted-authenticated-evidence-safety`; `verify:heighted-progress-projection-contract-safety`; `verify:heighted-authenticated-progress-projection-contract-safety`; `verify:rotating-authenticated-progress-projection-contract-safety`; `verify:temporal:heighted-progress-projection-contract`; `verify:temporal:heighted-authenticated-progress-projection-contract`; `verify:temporal:rotating-authenticated-progress-projection-contract` | partial | First receive-reactive heighted slice now has fixed-sigma and dynamic-sigma head-sigma stream linkage, plus a dynamic-sigma authenticated-evidence bridge. The heighted progress projections add TLC temporal bridges for mixed-precommit waiting, nil-certified height-1 recovery, pristine future-height state, height-2 decision, ordered finality, authenticated finality gating, and height-indexed validator-set authorization after rotation; full imported-protocol temporal proof and concrete production auth/evidence integration remain open. |
| Weighted voting power | `VotingPowerOf`, `QuorumVotingPower`; `test:weighted`; `CrosslinkFatPointerFormat.qnt`; `CrosslinkFatPointerProductionVectors.qnt`; `test:fat-pointer-production-vectors`; `verify:fat-pointer-production-vectors-safety` | covered | Production fat-pointer signer-vector, exact wire-envelope offset/length, checked-in fixture offsets/byte probes, and producer-round-data derivation shapes are modeled; broader production integration remains open. |
| Dynamic validator-set changes | `spec/CrosslinkValidatorSetChange.qnt`; `spec/CrosslinkHeightedValidatorEvidence.qnt`; `spec/CrosslinkHeightedAuthenticatedEvidence.qnt`; `spec/CrosslinkHeightedAuthenticatedGossipTransport.qnt`; `spec/CrosslinkRotatingAuthenticatedProgressProjectionContract.qnt`; `spec/CrosslinkFatPointerFormat.qnt`; `spec/CrosslinkFatPointerProductionVectors.qnt`; `spec/CrosslinkFatPointerAuthenticatedEvidence.qnt`; `test:validator-set-change`; `test:heighted-validator-evidence`; `test:heighted-authenticated-evidence`; `test:heighted-authenticated-gossip-transport`; `test:rotating-authenticated-progress-projection-contract`; `test:fat-pointer-format`; `test:fat-pointer-production-vectors`; `test:fat-pointer-authenticated-evidence`; `verify:validator-set-change-safety`; `verify:heighted-validator-evidence-safety`; `verify:heighted-authenticated-evidence-safety`; `verify:heighted-authenticated-gossip-transport-safety`; `verify:rotating-authenticated-progress-projection-contract-safety`; `verify:temporal:rotating-authenticated-progress-projection-contract`; `verify:fat-pointer-format-safety`; `verify:fat-pointer-production-vectors-safety`; `verify:fat-pointer-authenticated-evidence-safety` | partial | Validator-set rotation is now linked to heighted authenticated evidence signer authorization, a Crosslink-topic transport-envelope boundary, production-shaped fat-pointer signer vectors, pinned fat-pointer byte vectors, and a TLC temporal projection that finalizes across a height-1 to height-2 rotation only with height-authorized signers; production-code integration remains open. |
| Message evidence bookkeeping | `CrosslinkMessageEvidenceModel`; `test:message-evidence` | covered | Needs production evidence encoding. |
| Evidence gossip and observer process | `spec/CrosslinkEvidenceGossip.qnt`; `spec/CrosslinkHeightedEvidenceGossip.qnt`; `spec/CrosslinkHeightedAuthenticatedEvidence.qnt`; `spec/CrosslinkHeightedAuthenticatedGossipTransport.qnt`; `spec/CrosslinkDynamicSigmaHeightedAuthenticatedEvidence.qnt`; `spec/CrosslinkDynamicSigmaAuthenticatedFinality.qnt`; `spec/CrosslinkHeightedAuthenticatedProgressProjectionContract.qnt`; `spec/CrosslinkRotatingAuthenticatedProgressProjectionContract.qnt`; `spec/CrosslinkFatPointerAuthenticatedEvidence.qnt`; `spec/CrosslinkFixtureAuthenticatedEvidence.qnt`; `spec/CrosslinkFixtureGossipTransport.qnt`; `spec/CrosslinkProductionFinalityProjectionContract.qnt`; `spec/CrosslinkProductionFinalityTenderlinkEvidenceBridge.qnt`; `spec/CrosslinkProductionFinalityIngressProjectionBridge.qnt`; `spec/CrosslinkProductionFinalityIngressProjectionBridgeSafety.qnt`; `test:evidence-gossip`; `test:heighted-evidence-gossip`; `test:heighted-authenticated-evidence`; `test:heighted-authenticated-gossip-transport`; `test:dynamic-sigma-heighted-authenticated-evidence`; `test:dynamic-sigma-authenticated-finality`; `test:heighted-authenticated-progress-projection-contract`; `test:rotating-authenticated-progress-projection-contract`; `test:fat-pointer-authenticated-evidence`; `test:fixture-authenticated-evidence`; `test:fixture-gossip-transport`; `test:production-finality-projection-contract`; `test:production-finality-tenderlink-evidence-bridge`; `test:production-finality-ingress-projection-bridge`; `test:production-finality-ingress-projection-bridge-safety`; `verify:evidence-gossip-safety`; `verify:heighted-evidence-gossip-safety`; `verify:heighted-authenticated-evidence-safety`; `verify:heighted-authenticated-gossip-transport-safety`; `verify:dynamic-sigma-heighted-authenticated-evidence-safety`; `verify:dynamic-sigma-authenticated-finality-safety`; `verify:heighted-authenticated-progress-projection-contract-safety`; `verify:rotating-authenticated-progress-projection-contract-safety`; `verify:production-finality-projection-contract-safety`; `verify:production-finality-tenderlink-evidence-bridge-safety`; `verify:production-finality-ingress-projection-bridge-safety`; `verify:temporal:rotating-authenticated-progress-projection-contract`; `verify:temporal:production-finality-projection-contract`; `verify:temporal:production-finality-tenderlink-evidence-bridge`; `verify:fat-pointer-authenticated-evidence-safety`; `verify:fixture-authenticated-evidence-safety`; `verify:fixture-gossip-transport-safety` | partial | Abstract standalone, first authenticated composition, a generic heighted authenticated gossip-transport bridge, dynamic-sigma authenticated evidence/finality composition, TLC-friendly authenticated progress/finality projections including validator-set rotation, production-shaped fat-pointer observer models, generated-fixture observer bridge, fixture transport-gossip bridge, and production-fixture proposal/finality gate exist, including exact counted-envelope, Crosslink-topic envelope, proposal-before-candidate, serialized BFT-block prefix-field checks, finality-before-evidence checks, a finality/Tenderlink evidence bridge requiring the router-recorded value-precommit certificate before finality precommit evidence projection, and production finality ingress/projection gates that require accepted and router-recorded Tenderlink value-precommit-certificate ingress before finality precommit evidence can be gossiped; full concrete production gossip transport remains open. |
| Message authentication/canonical bytes | `spec/CrosslinkMessageAuth.qnt`; `spec/CrosslinkHeightedMessageAuth.qnt`; `spec/CrosslinkHeightedMessageGossipTransport.qnt`; `spec/CrosslinkTenderlinkVoteSignBytes.qnt`; `spec/CrosslinkTenderlinkProposalChunkSignBytes.qnt`; `spec/CrosslinkTenderlinkVotePacketFormat.qnt`; `spec/CrosslinkTenderlinkProposalPolEvidence.qnt`; `spec/CrosslinkTenderlinkProposalPolTransport.qnt`; `spec/CrosslinkTenderlinkConsensusPacketFormat.qnt`; `spec/CrosslinkTenderlinkPrecommitTransport.qnt`; `spec/CrosslinkTenderlinkAccountabilityEvidenceFormat.qnt`; `spec/CrosslinkTenderlinkAccountabilityEvidenceTransport.qnt`; `spec/CrosslinkTenderlinkAccountabilityObserver.qnt`; `spec/CrosslinkTenderlinkNonceAckTransport.qnt`; `spec/CrosslinkTenderlinkStatusPacketFormat.qnt`; `spec/CrosslinkMalachiteProposalProtobufFormat.qnt`; `spec/CrosslinkMalachiteProposalGossipTransport.qnt`; `spec/CrosslinkMalachiteLivenessProtobufFormat.qnt`; `spec/CrosslinkMalachiteLivenessGossipTransport.qnt`; `spec/CrosslinkMalachiteSyncProtobufFormat.qnt`; `spec/CrosslinkMalachiteSyncGossipTransport.qnt`; `spec/CrosslinkHeightedAuthenticatedEvidence.qnt`; `spec/CrosslinkHeightedAuthenticatedGossipTransport.qnt`; `spec/CrosslinkDynamicSigmaHeightedAuthenticatedEvidence.qnt`; `spec/CrosslinkDynamicSigmaAuthenticatedFinality.qnt`; `spec/CrosslinkFatPointerFormat.qnt`; `spec/CrosslinkFatPointerProductionVectors.qnt`; `spec/CrosslinkFatPointerAuthenticatedEvidence.qnt`; `spec/CrosslinkFixtureAuthenticatedEvidence.qnt`; `spec/CrosslinkFixtureGossipTransport.qnt`; `test:message-auth`; `test:heighted-message-auth`; `test:heighted-message-gossip-transport`; `test:tenderlink-vote-sign-bytes`; `test:tenderlink-proposal-chunk-sign-bytes`; `test:tenderlink-vote-packet-format`; `test:tenderlink-proposal-pol-evidence`; `test:tenderlink-proposal-pol-transport`; `test:tenderlink-consensus-packet-format`; `test:tenderlink-precommit-transport`; `test:tenderlink-accountability-evidence-format`; `test:tenderlink-accountability-evidence-transport`; `test:tenderlink-accountability-observer`; `test:tenderlink-nonce-ack-transport`; `test:tenderlink-status-packet-format`; `test:malachite-proposal-protobuf-format`; `test:malachite-proposal-gossip-transport`; `test:malachite-liveness-protobuf-format`; `test:malachite-liveness-gossip-transport`; `test:malachite-sync-protobuf-format`; `test:malachite-sync-gossip-transport`; `test:heighted-authenticated-evidence`; `test:heighted-authenticated-gossip-transport`; `test:dynamic-sigma-heighted-authenticated-evidence`; `test:dynamic-sigma-authenticated-finality`; `test:fat-pointer-format`; `test:fat-pointer-production-vectors`; `test:fat-pointer-authenticated-evidence`; `test:fixture-authenticated-evidence`; `test:fixture-gossip-transport`; `verify:message-auth-safety`; `verify:heighted-message-auth-safety`; `verify:heighted-message-gossip-transport-safety`; `verify:tenderlink-vote-sign-bytes-safety`; `verify:tenderlink-proposal-chunk-sign-bytes-safety`; `verify:tenderlink-vote-packet-format-safety`; `verify:tenderlink-proposal-pol-evidence-safety`; `verify:tenderlink-proposal-pol-transport-safety`; `verify:tenderlink-consensus-packet-format-safety`; `verify:tenderlink-precommit-transport-safety`; `verify:tenderlink-accountability-evidence-format-safety`; `verify:tenderlink-accountability-evidence-transport-safety`; `verify:tenderlink-accountability-observer-safety`; `verify:tenderlink-nonce-ack-transport-safety`; `verify:tenderlink-status-packet-format-safety`; `verify:malachite-proposal-protobuf-format-safety`; `verify:malachite-proposal-gossip-transport-safety`; `verify:malachite-liveness-protobuf-format-safety`; `verify:malachite-liveness-gossip-transport-safety`; `verify:malachite-sync-protobuf-format-safety`; `verify:malachite-sync-gossip-transport-safety`; `verify:heighted-authenticated-evidence-safety`; `verify:heighted-authenticated-gossip-transport-safety`; `verify:dynamic-sigma-heighted-authenticated-evidence-safety`; `verify:dynamic-sigma-authenticated-finality-safety`; `verify:fat-pointer-format-safety`; `verify:fat-pointer-production-vectors-safety`; `verify:fat-pointer-authenticated-evidence-safety`; `verify:fixture-authenticated-evidence-safety`; `verify:fixture-gossip-transport-safety` | partial | Abstract signature metadata, a generic heighted proposal/vote/fat-pointer-signature topic/kind envelope bridge, implementation-linked Tenderlink/Malachite vote sign-byte layout, implementation-linked legacy Tenderlink proposal chunk sign-byte layout, implementation-linked legacy Tenderlink vote packet layout, a production-shaped proposal/POL evidence bridge, a compact Tenderlink proposal/POL transport bridge, implementation-linked compact Tenderlink consensus packet envelope layout, a compact Tenderlink precommit transport bridge, implementation-linked nil/value and value/value precommit accountability envelopes, implementation-linked accountability-evidence transport gate, implementation-linked accountability observer bridge, implementation-linked known-peer nonce/ack replay-window transport slice, implementation-linked status packet request format, implementation-linked Malachite proposal protobuf vectors, implementation-linked Malachite proposal gossip transport, implementation-linked Malachite liveness protobuf vectors, implementation-linked Malachite liveness gossip transport, implementation-linked Malachite sync protobuf vectors, implementation-linked Malachite sync gossip transport, evidence-pipeline composition, generic heighted evidence envelope gating, dynamic-sigma evidence/finality authentication, production-shaped fat-pointer canonical bytes, production byte-vector offsets, generated fixture constants, full generated fixture sign-data/signature hex strings, generated-fixture observer linkage, real Ed25519 verification in the fixture-manifest gate, and fixture-level transport envelope gating exist. The vote layout pins validator-pubkey/value-or-zero/height/round-type bytes plus the 44-byte fat-pointer payload suffix; the proposal chunk layout pins the 56-byte header, `valid_round = -1` as `u32::MAX`, and chunk data concatenation; the vote packet layout pins vote batch offsets and reconstructs canonical sign bytes from packet fields, including nil precommit, two distinct value precommit vectors, nil/value precommit quorum-certificate packets, one-signature, two-signature weighted, three-signature value-prevote, and five-entry larger-validator-set packets at height 2/round 1 for POL evidence; the proposal/POL bridge requires non-nil `validRound` chunks to carry matching prevote-packet evidence by height, round, value id, and certified packet-derived voting power, including a forged-certified-power rejection and a higher-threshold larger-validator-set witness; the POL transport bridge requires the non-nil proposal chunk and weighted, f = 1, or larger-validator-set POL packet to be received through decrypted exact compact Tenderlink packet envelopes before transported POL evidence is accepted; the compact consensus packet layout pins the 16-byte `PacketHeader`, including nonzero `ack_latest`/`ack_field` bytes, proposal chunk packet, non-nil POL proposal packet, and 112/178/244/376-byte prevote plus precommit batch packet bytes; the precommit transport bridge requires exact decrypted consensus-topic packet envelopes before nil/value precommit packets or nil/value certificate evidence are accepted and rejects low-power batches as certificate evidence; the accountability envelopes pin nil/value and value/value precommit equivocation by one validator at the same height and round as a 51-byte typed header plus two canonical `PacketVotes` payloads; the accountability-evidence transport gate requires exact canonical evidence bytes on the Crosslink consensus topic with matching height, round, and signer metadata; the accountability observer records precommit-equivocation facts only after accepted transported evidence; the nonce/ack transport slice pins little-endian outer nonce prefixes and replay-window behavior before canonical packet acceptance; the status packet slice pins the status-flagged header plus inline height/round/proposal/prevote/precommit request ranges; and the Malachite protobuf proposal slice pins Value, Proposal, SignedMessage::Proposal, and streamed proposal vectors; the Malachite proposal gossip transport slice requires correct topic/kind envelopes before accepted raw/signed/streamed proposal messages; the Malachite liveness protobuf slice pins polka, skip-round nil, and value precommit certificate vectors; the Malachite liveness gossip transport slice requires correct topic/kind envelopes before accepted polka/round messages; the Malachite sync protobuf slice pins request/response, commit certificate, synced value, and no-value response vectors; and the Malachite sync gossip transport slice requires correct topic/kind envelopes before accepted sync messages. Full production gossip transport remains open. |
| Tenderlink precommit transport safety | `spec/CrosslinkTenderlinkPrecommitTransport.qnt`; `spec/CrosslinkTenderlinkPrecommitTransportSafety.qnt`; `test:tenderlink-precommit-transport`; `test:tenderlink-precommit-transport-safety`; `verify:tenderlink-precommit-transport-safety` | covered | The imported bridge pins nil, value, and mixed compact precommit packets on the consensus topic. The safety slice checks that only transported all-nil quorum packets become nil certificates, only transported all-value quorum packets become value certificates, and mixed precommit quorums remain wait/message evidence rather than unlock or commit evidence. |
| Tenderlink gossip router/channel registry | `spec/CrosslinkTenderlinkGossipRouter.qnt`; `spec/CrosslinkTenderlinkGossipRouterSafety.qnt`; `test:tenderlink-gossip-router`; `test:tenderlink-gossip-router-safety`; `verify:tenderlink-gossip-router-safety` | partial | The imported router composes the current Tenderlink compact transport lanes: proposal/POL packets, nil/value/mixed precommit packets, nil/value precommit certificates, accountability evidence, known-peer consensus packets, and status packets all share the Crosslink consensus topic but remain separated by channel/kind namespace, while preserving each underlying transport safety invariant. Mixed precommit quorums route as wait/message records, not nil-unlock or value-commit certificates. The safety slice now imports the exact compact proposal/POL packet hex from the consensus packet format model, exact compact precommit packet hex from the precommit transport safety model, and exact accountability/known-peer/status side-lane bytes from their format/transport models, checks correct routing, rejects wrong-topic/wrong-kind/wrong-bytes inputs, and records cross-channel/unknown-channel injections as invariant violations. Full production gossip integration remains open. |
| Malachite gossip router/channel registry | `spec/CrosslinkMalachiteGossipRouter.qnt`; `spec/CrosslinkMalachiteGossipRouterSafety.qnt`; `test:malachite-gossip-router`; `test:malachite-gossip-router-safety`; `verify:malachite-gossip-router-safety` | partial | Proposal, liveness, and sync transport machines are composed behind one shared router, with a verifier-friendly direct safety slice for Apalache. The router records accepted messages on channel-specific sets, checks topic/channel disjointness, preserves each underlying transport safety invariant, imports exact proposal/liveness/sync protobuf fixture bytes for the direct safety route witnesses, and rejects wrong-channel/wrong-topic/wrong-kind behavior through explicit witnesses. Full production gossip integration remains open. |
| Production gossip registry and ingress | `spec/CrosslinkProductionGossipRegistry.qnt`; `spec/CrosslinkProductionGossipIngress.qnt`; `spec/CrosslinkProductionFinalityTenderlinkEvidenceBridge.qnt`; `spec/CrosslinkProductionDynamicSigmaConsensusParamIngressBridge.qnt`; `spec/CrosslinkProductionDynamicSigmaConsensusParamIngressBridgeSafety.qnt`; `spec/CrosslinkProductionDynamicSigmaPayloadIngressBridge.qnt`; `spec/CrosslinkProductionDynamicSigmaPayloadIngressBridgeSafety.qnt`; `spec/CrosslinkProductionFinalityIngressBridge.qnt`; `spec/CrosslinkProductionFinalityIngressProjectionBridge.qnt`; `spec/CrosslinkProductionFinalityIngressProjectionBridgeSafety.qnt`; `test:production-gossip-registry`; `test:production-gossip-ingress`; `test:production-finality-tenderlink-evidence-bridge`; `test:production-dynamic-sigma-consensus-param-ingress-bridge`; `test:production-dynamic-sigma-consensus-param-ingress-bridge-safety`; `test:production-dynamic-sigma-payload-ingress-bridge`; `test:production-dynamic-sigma-payload-ingress-bridge-safety`; `test:production-finality-ingress-bridge`; `test:production-finality-ingress-projection-bridge`; `test:production-finality-ingress-projection-bridge-safety`; `verify:production-gossip-registry-safety`; `verify:production-gossip-ingress-safety`; `verify:production-finality-tenderlink-evidence-bridge-safety`; `verify:production-dynamic-sigma-consensus-param-ingress-bridge-safety`; `verify:production-dynamic-sigma-payload-ingress-bridge-safety`; `verify:production-finality-ingress-bridge-safety`; `verify:production-finality-ingress-projection-bridge-safety`; `verify:temporal:production-finality-tenderlink-evidence-bridge`; `verify:temporal:production-finality-ingress-projection-bridge` | partial | A direct production-level registry now composes the Tenderlink compact consensus/evidence/known-peer/status lanes, Malachite proposal/liveness/sync lanes, dynamic-sigma consensus-param and BFT-payload lanes, and production-finality proposal/fat-pointer lanes, with exact compact Tenderlink proposal/POL packet hex from the consensus packet format model, exact compact Tenderlink precommit packet hex from the precommit transport safety model, exact Tenderlink accountability/known-peer/status side-lane bytes from their format/transport models, exact Malachite proposal/liveness/sync protobuf fixture bytes from the format models, exact raised/recovered consensus-param hex vectors from the production-shaped format bridge, tagged dynamic-sigma payload metadata shared with the transport/decode gate, and compact finality byte labels whose route validity directly checks generated fixture version/height/finality/offset/length/header-count metadata. The node-local ingress slice then checks that registry-valid records still enter only their matching downstream lane, rejecting evidence handed to Tenderlink consensus ingress, Malachite proposal traffic handed to Tenderlink ingress, dynamic-sigma params or BFT payloads handed to Tenderlink/Malachite ingress, production-finality records handed to unrelated ingress lanes, and cross-protocol raw injection. The finality/Tenderlink evidence bridge links the production Tenderlink router's value-precommit-certificate record to finality precommit evidence projection, rejecting router skips and wrong-lane production-finality ingress substitutes. The dynamic-sigma consensus-param ingress bridge links accepted dynamic param ingress to signed param gossip and node config installation, rejecting gossip/config skips and wrong-lane substitutes; its safety projection proves the same ordering under Apalache. The dynamic-sigma payload ingress bridge links accepted dynamic payload ingress to transport acceptance and prototype decode, rejecting transport/decode skips and wrong-lane substitutes; the safety projection proves the same ordering under Apalache. The compact finality-ingress bridge now links accepted production-finality ingress records and accepted plus router-recorded Tenderlink value-precommit-certificate ingress to projection readiness and finality, rejecting projection/finality skips, standalone precommit-evidence projection, router recording without ingress, and Tenderlink precommit traffic as a proposal-lane substitute. The direct ingress/projection bridge additionally exercises the imported production ingress and projection action graph plus the same router-recorded precommit-evidence gate under the Rust backend, and the verifier-friendly staged projection proves the intermediate proposal transport, candidate observation, Tenderlink router recording, precommit evidence, fat-pointer transport, fat-pointer observation, and finality gates under Apalache/TLC while the direct imported graph still hits Quint flattening limits. Concrete node gossip integration remains open. |
| Accountability witnesses | `ConflictingCommitsAccountable`, nil/value equivocation and invalid-unlock witnesses; signer-level value/value and nil/value equivocation predicates with witnesses that keep lone nil/value signer evidence separate from quorum/certificate nil-unlock context; `CrosslinkTenderlinkAccountabilityEvidenceFormat.qnt` nil/value and value/value precommit equivocation envelope witnesses; `CrosslinkTenderlinkAccountabilityEvidenceTransport.qnt` missing-transport, wrong-topic, wrong-kind, wrong-length, wrong-height, wrong-signer, wrong-bytes, non-canonical evidence, and value/value transport witnesses; `CrosslinkTenderlinkAccountabilityObserver.qnt` receive-before-accept, missing-transport, nil/value observation, value/value observation, and non-canonical observation witnesses; `CrosslinkTenderlinkAccountabilityObserverBridge.qnt` concrete observer-to-abstract signer evidence witnesses, including nil/value evidence requiring extra quorum/certificate context before aggregate accountability; `CrosslinkTenderlinkAccountabilityObserverBridgeSafety.qnt` direct Apalache projection of those bridge obligations; `CrosslinkTenderlinkUnlockAccountabilityBoundary.qnt` checks that cross-round value switches are only abstract bad-unlock signals until nil-certificate absence is made sound, and that low-power nil observations, mixed precommits, and value precommit certificates do not clear the signal; `CrosslinkFatPointerFormat.qnt` duplicate-pubkey, removed-validator, wrong-payload, cross-height replay, low-power, wire-offset, trailing-byte, truncated-wire, and producer-round-data derivation witnesses; `CrosslinkFatPointerProductionVectors.qnt` `try_from_bytes` reversed-slice gap witness; `CrosslinkFatPointerAuthenticatedEvidence.qnt` gossip-before-observe, missing-signer, and trailing-byte wire witnesses; `docs/accountability.md` | covered | Further slashing evidence formats beyond same-round precommit equivocation remain open. |
| Fork finality over PoW branches | `spec/CrosslinkForkFinality.qnt`; `test:finality`; `verify:finality-safety` | covered | Needs concrete PoW-chain data. |
| Multi-height finalized prefix | `spec/CrosslinkBftHeights.qnt`; `spec/CrosslinkMultiHeight.qnt`; `spec/CrosslinkHeightedRound.qnt`; `spec/CrosslinkHeightedFinality.qnt`; `spec/CrosslinkDynamicSigmaHeightedFinality.qnt`; `spec/CrosslinkDynamicSigmaAuthenticatedFinality.qnt`; `spec/CrosslinkHeightedProgressProjectionContract.qnt`; `spec/CrosslinkHeightedAuthenticatedProgressProjectionContract.qnt`; `spec/CrosslinkRotatingAuthenticatedProgressProjectionContract.qnt`; `spec/CrosslinkProductionFinalityProjectionContract.qnt`; `test:bft-heights`; `test:multi-height`; `test:heighted-round`; `test:heighted-finality`; `test:dynamic-sigma-heighted-finality`; `test:dynamic-sigma-authenticated-finality`; `test:heighted-progress-projection-contract`; `test:heighted-authenticated-progress-projection-contract`; `test:rotating-authenticated-progress-projection-contract`; `test:production-finality-projection-contract`; `verify:bft-heights-safety`; `verify:multi-height-safety`; `verify:heighted-round-safety`; `verify:heighted-finality-safety`; `verify:dynamic-sigma-heighted-finality-safety`; `verify:dynamic-sigma-authenticated-finality-safety`; `verify:heighted-progress-projection-contract-safety`; `verify:heighted-authenticated-progress-projection-contract-safety`; `verify:rotating-authenticated-progress-projection-contract-safety`; `verify:production-finality-projection-contract-safety`; `verify:temporal:heighted-progress-projection-contract`; `verify:temporal:heighted-authenticated-progress-projection-contract`; `verify:temporal:rotating-authenticated-progress-projection-contract`; `verify:temporal:production-finality-projection-contract` | partial | Heighted finality exists for fixed and dynamic sigma, including authenticated dynamic finality; `CrosslinkBftHeights` keeps a compact scheduled-height sanity harness; the projections check TLC temporal progress across two ordered heights, with authenticated evidence before finality and height-authorized signer evidence across validator-set rotation; the production-finality projection now checks a fixture-level proposal-transported BFT-block with serialized prefix-field matching plus fat-pointer evidence gate; broader production data/linkage remains partial. |
| Composed round recovery plus finality | `spec/CrosslinkComposed.qnt`; `spec/CrosslinkHeightedFinality.qnt`; `spec/CrosslinkDynamicSigmaHeightedFinality.qnt`; `spec/CrosslinkDynamicSigmaAuthenticatedFinality.qnt`; `spec/CrosslinkComposedProgressContract.qnt`; `spec/CrosslinkHeightedProgressProjectionContract.qnt`; `spec/CrosslinkHeightedAuthenticatedProgressProjectionContract.qnt`; `spec/CrosslinkRotatingAuthenticatedProgressProjectionContract.qnt`; `spec/CrosslinkProductionFinalityProjectionContract.qnt`; `spec/CrosslinkValidatorScaleFinalityProgressContract.qnt`; `test:composed`; `test:heighted-finality`; `test:dynamic-sigma-heighted-finality`; `test:dynamic-sigma-authenticated-finality`; `test:composed-progress-contract`; `test:heighted-progress-projection-contract`; `test:heighted-authenticated-progress-projection-contract`; `test:rotating-authenticated-progress-projection-contract`; `test:production-finality-projection-contract`; `test:validator-scale-finality-progress-contract`; `verify:composed-safety`; `verify:heighted-finality-safety`; `verify:dynamic-sigma-heighted-finality-safety`; `verify:dynamic-sigma-authenticated-finality-safety`; `verify:composed-progress-contract-safety`; `verify:heighted-progress-projection-contract-safety`; `verify:heighted-authenticated-progress-projection-contract-safety`; `verify:rotating-authenticated-progress-projection-contract-safety`; `verify:production-finality-projection-contract-safety`; `verify:validator-scale-finality-progress-contract-safety`; `verify:temporal:heighted-progress-projection-contract`; `verify:temporal:heighted-authenticated-progress-projection-contract`; `verify:temporal:rotating-authenticated-progress-projection-contract`; `verify:temporal:production-finality-projection-contract`; `verify:temporal:validator-scale-finality-progress-contract` | partial | Heighted fixed-sigma, dynamic-sigma, and authenticated dynamic-sigma finality compositions plus TLC-sized composed progress contracts exist, including the validator-scale stress-to-finality slice, a heighted two-height recovery/finality projection, an authenticated two-height recovery/finality projection, a rotating-validator authenticated recovery/finality projection, and a production-fixture proposal/finality projection with generated serialized prefix-field checks; production data/linkage and a temporal proof over the full imported protocol remain partial. |
| Imported composed-predicate temporal bridge | `spec/CrosslinkComposedImportedProgressBridge.qnt`; `CrosslinkComposedImportedProgressBridgeModel`; `test:composed-imported-progress-bridge`; `verify:composed-imported-progress-bridge-safety`; `verify:extended:composed-imported-progress-bridge`; `verify:temporal:composed-imported-progress-bridge` | partial | The bridge imports `CrosslinkComposed.qnt` quorum-power, lock-scope, and finality predicates into a TLC-checkable scalar progress graph, verifies nil/prevote/precommit quorum gates, rejects insufficient or faulty stable quorum witnesses, rejects over-f current-round lock residue, checks older-lock preservation plus valid-round-style justification before crossing an older lock, rejects phase skips across resampling, proposal delivery, prevote delivery, precommit delivery, decision, and finality, and verifies finalization of the stable candidate through imported candidate validation. The full imported round-machine action graph still needs a temporal proof once the nested map-heavy TLC translation blocker is removed or refactored. |
| Liveness under stream stability | `NilPrecommitResamplingStableWindowLiveness`, `CrosslinkComposedLivenessModel`, `CrosslinkSchedulerLivenessModel`, `CrosslinkSchedulerProgressContractModel`, `CrosslinkDeliveryFairnessContractModel`, `CrosslinkTimeoutProgressContractModel`, `CrosslinkFinalityProgressContractModel`, `CrosslinkComposedProgressContractModel`, `CrosslinkBaselineChurnProgressContractModel`, `CrosslinkMixedWaitProgressContractModel`, `CrosslinkHeightedProgressProjectionContractModel`, `CrosslinkHeightedAuthenticatedProgressProjectionContractModel`, `CrosslinkRotatingAuthenticatedProgressProjectionContractModel`, `CrosslinkValidatorScaleProgressContractModel`, `CrosslinkValidatorScaleFinalityProgressContractModel`; `test:scheduler-liveness`; `test:scheduler-progress-contract`; `test:delivery-fairness-contract`; `test:timeout-progress-contract`; `test:finality-progress-contract`; `test:composed-progress-contract`; `test:baseline-churn-progress-contract`; `test:mixed-wait-progress-contract`; `test:heighted-progress-projection-contract`; `test:heighted-authenticated-progress-projection-contract`; `test:rotating-authenticated-progress-projection-contract`; `test:validator-scale-progress-contract`; `test:validator-scale-finality-progress-contract`; `verify:scheduler-liveness-safety`; `verify:scheduler-progress-contract-safety`; `verify:delivery-fairness-contract-safety`; `verify:timeout-progress-contract-safety`; `verify:finality-progress-contract-safety`; `verify:composed-progress-contract-safety`; `verify:baseline-churn-progress-contract-safety`; `verify:mixed-wait-progress-contract-safety`; `verify:heighted-progress-projection-contract-safety`; `verify:heighted-authenticated-progress-projection-contract-safety`; `verify:rotating-authenticated-progress-projection-contract-safety`; `verify:validator-scale-progress-contract-safety`; `verify:validator-scale-finality-progress-contract-safety`; `verify:temporal` | partial | Bounded scheduler-parametric checks and TLC temporal contracts now cover scheduler progress, local-delivery fairness, timeout recovery, decision-to-finality progress, a self-contained composed nil-resampling/finality progress slice, the baseline sticky-churn halt/resampling-outruns-baseline case, mixed-precommit wait followed by nil-certificate recovery, a two-height mixed-wait/nil-resampling/finality progression, the same two-height progression with authenticated observer evidence before finality, a rotating-validator authenticated progression, and validator-scale stress cases where baseline halts but resampling decides and finalizes after bounded burned rounds; no full imported round-machine temporal liveness proof yet. |
| CI for checks | `package.json` scripts and `.github/workflows/quint.yml` | covered | Latest pushed commit may still be running until GitHub Actions completes. |
| Documentation mapping to Tendermint | `docs/tendermint-crosslink-map.md`, `docs/implementation-correspondence.md`, `docs/spec-roadmap.md`, `docs/dynamic-sigma-telemetry-integration.md` | covered | Should keep updated as models become less abstract. |

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
message evidence, local delivery, delivery fairness, timeout, timeout progress contract, liveness
witnesses, scheduler liveness, scheduler progress contract, finality progress
contract, composed progress contract, composed imported-predicate bridge,
baseline churn progress contract,
mixed-wait progress contract, heighted progress projection contract,
heighted authenticated progress projection contract, rotating authenticated
progress projection contract, stream-churn risk, validator-scale liveness
envelope, validator-scale progress contract, validator-scale finality progress
contract, PoW stochastic assumptions, PoW fixture measured distribution,
PoW fork schedule, PoW branch competition, PoW-reorg stress,
BFT-height finality, dynamic-sigma controller, dynamic-sigma calibration,
dynamic-sigma telemetry, dynamic-sigma proposal-evidence-format,
dynamic-sigma BFT-payload transport, dynamic-sigma prototype decode gate,
production dynamic-sigma consensus-param ingress bridge, production dynamic-sigma payload ingress bridge,
dynamic-sigma fork-schedule, dynamic-sigma branch-competition,
dynamic-sigma resampling, dynamic-sigma finality,
dynamic-sigma head-sampling, dynamic-sigma consensus-params, dynamic-sigma consensus-param-format,
dynamic-sigma consensus-param-transport,
dynamic-sigma heighted-round,
dynamic-sigma heighted-finality,
dynamic-sigma heighted-authenticated-evidence, dynamic-sigma authenticated-finality,
head-sigma sampling, heighted head-sigma rounds,
BFT-block header shape checks,
BFT-block validation-gap checks, BFT-block production-vector checks,
BFT-block fixture-manifest validation and generated-Quint fixture validation,
fat-pointer signer-vector format checks, fat-pointer production-vector checks,
fat-pointer authenticated-evidence checks, fixture-authenticated evidence
checks, fixture-gossip transport checks, production-finality projection checks,
production dynamic-sigma consensus-param ingress bridge checks, production Tenderlink/Malachite ingress router bridge checks, production finality/Tenderlink evidence bridge checks, production dynamic-sigma payload ingress bridge checks,
production-finality ingress bridge checks, production-finality
ingress/projection bridge checks, production-finality ingress/projection
safety projection checks,
proposal validity, valid-round evidence, fork
finality, composed resampling/finality, composed liveness, multi-height finality,
height-indexed round-machine behavior, heighted finality composition, evidence
gossip, heighted evidence gossip, message authentication, heighted message
authentication, heighted message gossip transport, validator-set changes,
heighted validator evidence, heighted authenticated evidence, heighted
authenticated gossip transport, Tenderlink vote/proposal sign bytes,
Tenderlink vote packet, proposal/POL evidence, consensus packet,
precommit transport, accountability evidence, accountability evidence transport, accountability observer,
accountability observer bridge, unlock-accountability boundary,
nonce/ack transport, status
packet, Tenderlink gossip router, Tenderlink gossip router safety,
Malachite proposal protobuf, Malachite proposal gossip transport, Malachite
liveness protobuf, Malachite liveness gossip transport, Malachite sync
protobuf, Malachite sync gossip transport, Malachite gossip router, and
Malachite gossip router safety formats.

`npm run verify` currently runs bounded Apalache safety checks, mostly at
depth 3, with smaller byte-layout and transport models checked at depth 5, for:

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
CrosslinkHeightedMessageGossipTransportModel
CrosslinkTenderlinkVoteSignBytesModel
CrosslinkTenderlinkProposalChunkSignBytesModel
CrosslinkTenderlinkVotePacketFormatModel
CrosslinkTenderlinkProposalPolEvidenceModel
CrosslinkTenderlinkProposalPolTransportModel
CrosslinkTenderlinkConsensusPacketFormatModel
CrosslinkTenderlinkPrecommitTransportSafetyModel
CrosslinkTenderlinkAccountabilityEvidenceFormatModel
CrosslinkTenderlinkAccountabilityEvidenceTransportModel
CrosslinkTenderlinkAccountabilityObserverModel
CrosslinkTenderlinkAccountabilityObserverBridgeSafetyModel
CrosslinkTenderlinkUnlockAccountabilityBoundaryModel
CrosslinkTenderlinkNonceAckTransportModel
CrosslinkTenderlinkStatusPacketFormatModel
CrosslinkTenderlinkGossipRouterSafetyModel
CrosslinkMalachiteProposalProtobufFormatModel
CrosslinkMalachiteProposalGossipTransportModel
CrosslinkMalachiteLivenessProtobufFormatModel
CrosslinkMalachiteLivenessGossipTransportModel
CrosslinkMalachiteSyncProtobufFormatModel
CrosslinkMalachiteSyncGossipTransportModel
CrosslinkMalachiteGossipRouterModel
CrosslinkMalachiteGossipRouterSafetyModel
CrosslinkProductionGossipRegistryModel
CrosslinkProductionGossipIngressModel
CrosslinkProductionTenderlinkIngressRouterBridgeModel
CrosslinkProductionTenderlinkIngressRouterBridgeSafetyModel
CrosslinkProductionFinalityTenderlinkEvidenceBridgeModel
CrosslinkProductionMalachiteIngressRouterBridgeModel
CrosslinkProductionMalachiteIngressRouterBridgeSafetyModel
CrosslinkValidatorSetChangeModel
CrosslinkHeightedValidatorEvidenceModel
CrosslinkHeightedAuthenticatedEvidenceModel
CrosslinkHeightedAuthenticatedGossipTransportModel
CrosslinkSchedulerLivenessModel
CrosslinkSchedulerProgressContractModel
CrosslinkDeliveryFairnessContractModel
CrosslinkTimeoutProgressContractModel
CrosslinkFinalityProgressContractModel
CrosslinkComposedProgressContractModel
CrosslinkComposedImportedProgressBridgeModel
CrosslinkBaselineChurnProgressContractModel
CrosslinkMixedWaitProgressContractModel
CrosslinkHeightedProgressProjectionContractModel
CrosslinkHeightedAuthenticatedProgressProjectionContractModel
CrosslinkRotatingAuthenticatedProgressProjectionContractModel
CrosslinkStreamChurnRiskModel
CrosslinkValidatorScaleLivenessEnvelopeModel
CrosslinkValidatorScaleProgressContractModel
CrosslinkValidatorScaleFinalityProgressContractModel
CrosslinkPowStochasticAssumptionsModel
CrosslinkPowFixtureMeasuredDistributionModel
CrosslinkPowForkScheduleModel
CrosslinkPowBranchCompetitionModel
CrosslinkPowReorgStressModel
CrosslinkDynamicSigmaModel
CrosslinkDynamicSigmaTelemetryModel
CrosslinkDynamicSigmaProposalEvidenceFormatModel
CrosslinkDynamicSigmaBftPayloadTransportModel
CrosslinkDynamicSigmaPrototypeDecodeGateModel
CrosslinkProductionDynamicSigmaPayloadIngressBridgeModel
CrosslinkProductionDynamicSigmaPayloadIngressBridgeSafetyModel
CrosslinkDynamicSigmaForkScheduleModel
CrosslinkDynamicSigmaBranchCompetitionModel
CrosslinkDynamicSigmaResamplingModel
CrosslinkDynamicSigmaFinalityModel
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
CrosslinkProductionDynamicSigmaPayloadIngressBridgeModel
CrosslinkProductionDynamicSigmaPayloadIngressBridgeSafetyModel
CrosslinkProductionFinalityIngressBridgeModel
CrosslinkProductionFinalityIngressProjectionBridgeSafetyModel
CrosslinkProductionFinalityProjectionContractModel
CrosslinkProductionFinalityTemporalProjectionModel
```

`npm run verify:extended` is a non-default deeper gate for the newest
finality-progress, composed-progress, composed imported-predicate progress
bridge, baseline-churn-progress,
mixed-wait-progress, heighted-progress-projection,
heighted-authenticated-progress-projection,
rotating-authenticated-progress-projection,
delivery-fairness, timeout-progress, stream-churn,
validator-scale liveness envelope, validator-scale progress contract,
validator-scale finality progress contract, PoW stochastic-assumption,
PoW fixture measured-distribution,
PoW fork-schedule, PoW branch-competition, PoW-reorg stress,
BFT-height finality, dynamic-sigma controller, dynamic-sigma calibration,
dynamic-sigma telemetry, dynamic-sigma proposal-evidence-format,
dynamic-sigma BFT-payload transport, dynamic-sigma prototype decode gate,
production dynamic-sigma consensus-param ingress bridge, production Tenderlink/Malachite ingress router bridge, production finality/Tenderlink evidence bridge, production dynamic-sigma payload ingress bridge,
dynamic-sigma fork-schedule, dynamic-sigma branch-competition,
dynamic-sigma resampling, dynamic-sigma finality,
dynamic-sigma consensus-params, dynamic-sigma consensus-param-format, dynamic-sigma consensus-param-transport,
dynamic-sigma head-sampling, dynamic-sigma heighted-round,
dynamic-sigma heighted-finality,
dynamic-sigma heighted-authenticated-evidence,
dynamic-sigma authenticated-finality,
head-sigma stream, BFT-height finality, BFT-block-shape, BFT-block
validation-gap, BFT-block production-vector, fat-pointer-format, fat-pointer
production-vector, evidence-composition, fixture-authenticated evidence,
fixture-gossip transport, production-finality projection,
production dynamic-sigma consensus-param ingress bridge, production Tenderlink/Malachite ingress router bridge, production finality/Tenderlink evidence bridge, production dynamic-sigma payload ingress bridge,
production-finality ingress bridge, production-finality ingress/projection
bridge, production-finality ingress/projection safety projection,
heighted message gossip transport,
Tenderlink
vote/proposal sign bytes, Tenderlink vote packets, Tenderlink consensus
packets, Tenderlink precommit transport, Tenderlink accountability evidence, Tenderlink accountability evidence
transport, Tenderlink accountability observer, Tenderlink unlock-accountability
boundary, Tenderlink nonce/ack transport,
Tenderlink status packets,
Tenderlink gossip router,
Malachite proposal protobuf, Malachite proposal gossip transport, Malachite
liveness protobuf, Malachite liveness gossip transport, Malachite sync protobuf, Malachite sync gossip transport, Malachite gossip router, Malachite gossip router safety,
and heighted authenticated gossip transport models.
It currently runs depth-5 Apalache checks, with the PoW fork-schedule,
branch-competition, and reorg-stress models also checked at depth 8, for:

```text
CrosslinkFinalityProgressContractModel
CrosslinkComposedProgressContractModel
CrosslinkComposedImportedProgressBridgeModel
CrosslinkBaselineChurnProgressContractModel
CrosslinkMixedWaitProgressContractModel
CrosslinkHeightedProgressProjectionContractModel
CrosslinkHeightedAuthenticatedProgressProjectionContractModel
CrosslinkRotatingAuthenticatedProgressProjectionContractModel
CrosslinkTimeoutProgressContractModel
CrosslinkStreamChurnRiskModel
CrosslinkValidatorScaleLivenessEnvelopeModel
CrosslinkValidatorScaleProgressContractModel
CrosslinkValidatorScaleFinalityProgressContractModel
CrosslinkPowStochasticAssumptionsModel
CrosslinkPowFixtureMeasuredDistributionModel
CrosslinkPowForkScheduleModel
CrosslinkPowBranchCompetitionModel
CrosslinkPowReorgStressModel
CrosslinkDynamicSigmaModel
CrosslinkDynamicSigmaTelemetryModel
CrosslinkDynamicSigmaProposalEvidenceFormatModel
CrosslinkDynamicSigmaBftPayloadTransportModel
CrosslinkDynamicSigmaPrototypeDecodeGateModel
CrosslinkProductionDynamicSigmaPayloadIngressBridgeModel
CrosslinkProductionDynamicSigmaPayloadIngressBridgeSafetyModel
CrosslinkDynamicSigmaForkScheduleModel
CrosslinkDynamicSigmaBranchCompetitionModel
CrosslinkDynamicSigmaResamplingModel
CrosslinkDynamicSigmaFinalityModel
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
CrosslinkHeightedMessageGossipTransportModel
CrosslinkTenderlinkVoteSignBytesModel
CrosslinkTenderlinkProposalChunkSignBytesModel
CrosslinkTenderlinkVotePacketFormatModel
CrosslinkTenderlinkProposalPolEvidenceModel
CrosslinkTenderlinkProposalPolTransportModel
CrosslinkTenderlinkConsensusPacketFormatModel
CrosslinkTenderlinkPrecommitTransportSafetyModel
CrosslinkTenderlinkAccountabilityEvidenceFormatModel
CrosslinkTenderlinkAccountabilityEvidenceTransportModel
CrosslinkTenderlinkAccountabilityObserverModel
CrosslinkTenderlinkAccountabilityObserverBridgeSafetyModel
CrosslinkTenderlinkUnlockAccountabilityBoundaryModel
CrosslinkTenderlinkNonceAckTransportModel
CrosslinkTenderlinkStatusPacketFormatModel
CrosslinkMalachiteProposalProtobufFormatModel
CrosslinkMalachiteProposalGossipTransportModel
CrosslinkMalachiteLivenessProtobufFormatModel
CrosslinkMalachiteLivenessGossipTransportModel
CrosslinkMalachiteSyncProtobufFormatModel
CrosslinkMalachiteSyncGossipTransportModel
CrosslinkMalachiteGossipRouterModel
CrosslinkMalachiteGossipRouterSafetyModel
CrosslinkProductionGossipRegistryModel
CrosslinkProductionGossipIngressModel
CrosslinkProductionTenderlinkIngressRouterBridgeModel
CrosslinkProductionTenderlinkIngressRouterBridgeSafetyModel
CrosslinkProductionFinalityTenderlinkEvidenceBridgeModel
CrosslinkProductionMalachiteIngressRouterBridgeModel
CrosslinkProductionMalachiteIngressRouterBridgeSafetyModel
CrosslinkProductionDynamicSigmaConsensusParamIngressBridgeModel
CrosslinkProductionDynamicSigmaConsensusParamIngressBridgeSafetyModel
CrosslinkProductionDynamicSigmaPayloadIngressBridgeModel
CrosslinkProductionDynamicSigmaPayloadIngressBridgeSafetyModel
CrosslinkProductionFinalityIngressBridgeModel
CrosslinkProductionFinalityIngressProjectionBridgeSafetyModel
CrosslinkHeightedValidatorEvidenceModel
CrosslinkHeightedAuthenticatedEvidenceModel
CrosslinkHeightedAuthenticatedGossipTransportModel
```

`npm run verify:temporal` currently runs TLC on:

```text
CrosslinkSchedulerProgressContractModel / EventuallyStableDecision
CrosslinkDeliveryFairnessContractModel / EventuallyLocalDecision
CrosslinkTimeoutProgressContractModel / EventuallyTimeoutRecoveryDecides
CrosslinkFinalityProgressContractModel / EventuallyFinalized
CrosslinkComposedProgressContractModel / EventuallyFinalizesStableDecision
CrosslinkComposedImportedProgressBridgeModel / EventuallyImportedPredicateBridgeFinalizes
CrosslinkBaselineChurnProgressContractModel / EventuallyResamplingOutrunsBaselineHalt
CrosslinkMixedWaitProgressContractModel / EventuallyNilCertUnlocksMixedWait
CrosslinkHeightedProgressProjectionContractModel / EventuallyHeightedProgressFinalizesTwoHeights
CrosslinkHeightedAuthenticatedProgressProjectionContractModel / EventuallyHeightedAuthenticatedProgressFinalizesTwoHeights
CrosslinkRotatingAuthenticatedProgressProjectionContractModel / EventuallyRotatingAuthenticatedProgressFinalizesTwoHeights
CrosslinkProductionFinalityTemporalProjectionModel / EventuallyProductionFixtureFinalized
CrosslinkProductionFinalityIngressBridgeModel / EventuallyFinalityIngressBridgeFinalizes
CrosslinkProductionFinalityTenderlinkEvidenceBridgeModel / EventuallyProjectsFinalityPrecommitEvidence
CrosslinkProductionFinalityIngressProjectionBridgeSafetyModel / EventuallyProductionIngressProjectionFinalizes
CrosslinkValidatorScaleProgressContractModel / EventuallyResamplingDecision
CrosslinkValidatorScaleFinalityProgressContractModel / EventuallyValidatorScaleFinalized
```

These are temporal progress contracts for the scheduler envelope, the
local-delivery fairness envelope, the timeout recovery envelope, the
scheduler-to-finality handoff, a self-contained composed
nil-resampling/finality slice, an imported-predicate composed bridge that calls
the `CrosslinkComposed.qnt` quorum/lock-scope/finality/fork-prefix checks, the
sticky-baseline stream-churn recovery contract, the mixed-precommit
wait/recovery contract, the two-height
mixed-wait/nil-resampling/finality projection, the same two-height projection
with authenticated observer evidence before finality, the rotating-validator
authenticated projection, the production-finality fixture projection, the
production-finality ingress-to-projection bridge, and validator-scale stress
envelopes where baseline Crosslink halts
but nil-precommit resampling reaches a stable decision and then finalizes after
bounded burned rounds. They are not yet temporal
proofs over the full imported protocol state.

A direct TLC run over the current imported `CrosslinkComposed` action graph is
not in the gate yet: the nested helper actions over map-heavy imported
round-machine state currently fail in the Quint-to-TLA/TLC path before state
exploration. The standalone progress contracts plus the imported-predicate
bridge are the green temporal bridge until that imported-state shape or backend
support is refactored. The imported bridge now carries the key Tendermint lock
constraint for nil-precommit resampling: only same-round recovery state is
cleared, older locks remain outside the nil-certificate scope, and crossing an
older lock still needs valid-round-style quorum justification.

## Remaining Work

The goal is not complete yet. The strongest remaining gaps are:

- lift the TLC-checked progress contracts and imported-predicate bridge into a
  general temporal liveness proof over the imported composed protocol action
  graph under post-GST stream stability;
- replace the current analytic PoW-arrival, propagation-race, GST scaling, and
  long-tail reorg numerators with production measured distributions; the
  checked-in raw-PoW fixture interval contract exists, but it is deterministic
  fixture data rather than production calibration data;
- keep expanding the generated BFT-block fixture manifest beyond the current
  checked-in `test_pos_block_*.bin` envelopes and raw `test_pow_block_*.bin`
  samples, regenerate it as the production block format stabilizes, and add
  production code coverage for the already-modeled repaired constructor target: version, header-order, and PoW-solution checks;
- link message-authentication and evidence-gossip models to concrete production
  serialization, signatures, and full production gossip transport; the abstract
  heighted message and evidence transport bridges exist, and the concrete
  Tenderlink vote sign-byte, legacy proposal-chunk sign-byte, vote packet, and
  compact consensus packet layouts are now pinned, with focused
  proposal/POL and accountability-evidence transport/observer bridges for the
  valid-round, nil/value equivocation, and value/value equivocation evidence
  paths. Known-peer
  nonce/ack replay gating, the status packet format, and a shared imported
  Tenderlink compact-transport router namespace contract are modeled. Initial
  Malachite proposal, liveness, and sync protobuf vectors are pinned, first
  proposal/liveness/sync gossip-envelope bridges exist, and a shared Malachite
  gossip router plus verifier-friendly router safety slice compose those
  channel namespaces. A production-level registry plus Tenderlink and Malachite
  ingress/router bridges now check that Tenderlink, Malachite, dynamic-sigma,
  and production-finality lanes cannot be cross-routed or routed before
  matching node-local ingress, and the finality/Tenderlink evidence bridge
  checks that finality precommit evidence waits for the Tenderlink router's
  value-precommit certificate record; broader concrete node gossip integration
  remains open;
- link the dynamic-sigma consensus-param format/transport models to real
  implementation serialization vectors, signatures, gossip, and node
  configuration update paths;
- extend the script-level Ed25519 fixture verification, fixture-gossip transport
  bridge, and abstract heighted message/evidence transport bridges into full production
  gossip/transport integration;
- continue expanding bounded verification depth and targeted counterexample
  searches beyond the current depth-5 extended gate for the new standalone
  models.
