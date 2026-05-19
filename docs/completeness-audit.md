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
| Shared protocol core with explicit variants | Shared `CrosslinkResampling` core with baseline/resampling modules | covered | None at current abstraction level. |
| Proposal values as PoW stream snapshots | `Stream(round)`, `StickyOrStreamProposal`, `IsFreshForRound`, `CrosslinkHeadSigmaSamplingModel`, `CrosslinkHeightedHeadSigmaRoundModel`, `CrosslinkBftBlockShapeModel`; `test:head-sigma`; `test:heighted-head-sigma`; `test:bft-block-shape`; `verify:head-sigma-safety`; `verify:heighted-head-sigma-safety`; `verify:bft-block-shape-safety` | partial | Abstract, heighted, and first production-shape `head - sigma` models exist; need captured production data vectors. |
| Proposal validity split | `StaticProposalValidity`, `StructurallyValid`, `PowChainValid`, `FinalityCandidateValid`, `IsFreshForRound`; `CrosslinkBftBlockShape.qnt`; `test:proposal-validity`; `test:bft-block-shape` | partial | Abstract validity split exists; the first concrete BFT-block header-vector shape and stateless version/order/PoW guards are modeled, but production header validation remains abstract. |
| Tendermint lock and valid-value rules | `lockedValue`, `lockedRound`, `validValue`, `validRound`, `ProposalUnlocksCurrentLock`; `ProposalFor` reuses only real `validValue`/`validRound` state; per-height lock/valid state and height-scoped valid-round unlock in `CrosslinkHeightedRound.qnt` | partial | Needs production proposal evidence encoding and broader finality/auth/evidence composition. |
| Valid-round/POL evidence | `LocalValidRoundJustified`, `CorrectProposalValidRoundSound`; `test:valid-round`; `unjustifiedHeightedValidRoundProposalPrevotesNilTest`; `justifiedHeightedValidRoundUnlocksOlderLockTest` | covered | Needs production proposal evidence encoding. |
| Stream change between prevote and precommit | `UponStreamChangePrecommitNil`; baseline and resampling witnesses | covered | Needs broader temporal liveness and adversarial scheduling. |
| Nil-precommit same-round unlock | `StartNextRoundAfterPrecommitQuorum`, `ApplyLateNilPrecommitCertificate` | covered | None at current one-height abstraction level. |
| Preserve older locks | `nilPrecommitPreservesOlderTendermintValueLockTest`, `laterNilCertificateDoesNotUnlockOlderValueLockTest`, `nilResamplingDoesNotClearOtherHeightStateTest` | covered | Needs full composition with finality and production evidence formats. |
| Mixed precommit is not unlock evidence | `mixedPrecommitQuorumDoesNotUnlockTest` | covered | None. |
| Local receive/delivery semantics | `seenPropose`, `seenPrevote`, `seenPrecommit`, `Deliver*`; `test:local-delivery` | covered | Needs network scheduling/fairness assumptions. |
| Timeout transitions | `TimeoutProposePrevoteNil`, `TimeoutPrevotePrecommitNil`, `TimeoutPrecommitStartNextRound`; `test:timeout`; `precommitTimeoutDoesNotClearHeightedLockTest`; `timeoutWithoutValueLockNextFreshProposalResamplesTest` | partial | Needs fuller timeout scheduling and temporal properties. |
| Height-indexed round machine | `spec/CrosslinkHeightedRound.qnt`; `spec/CrosslinkHeightedHeadSigmaRound.qnt`; `test:heighted-round`; `test:heighted-head-sigma`; `verify:heighted-round-safety`; `verify:heighted-head-sigma-safety` | partial | First receive-reactive heighted slice now has concrete head-sigma stream linkage; not yet composed with auth/evidence rules. |
| Weighted voting power | `VotingPowerOf`, `QuorumVotingPower`; `test:weighted` | covered | Production signer-set formats remain open. |
| Dynamic validator-set changes | `spec/CrosslinkValidatorSetChange.qnt`; `spec/CrosslinkHeightedValidatorEvidence.qnt`; `spec/CrosslinkHeightedAuthenticatedEvidence.qnt`; `test:validator-set-change`; `test:heighted-validator-evidence`; `test:heighted-authenticated-evidence`; `verify:validator-set-change-safety`; `verify:heighted-validator-evidence-safety`; `verify:heighted-authenticated-evidence-safety` | partial | Validator-set rotation is now linked to heighted authenticated evidence signer authorization; production signer-set formats remain open. |
| Message evidence bookkeeping | `CrosslinkMessageEvidenceModel`; `test:message-evidence` | covered | Needs production evidence encoding. |
| Evidence gossip and observer process | `spec/CrosslinkEvidenceGossip.qnt`; `spec/CrosslinkHeightedEvidenceGossip.qnt`; `spec/CrosslinkHeightedAuthenticatedEvidence.qnt`; `test:evidence-gossip`; `test:heighted-evidence-gossip`; `test:heighted-authenticated-evidence`; `verify:evidence-gossip-safety`; `verify:heighted-evidence-gossip-safety`; `verify:heighted-authenticated-evidence-safety` | partial | Abstract standalone and first authenticated composition models exist; not yet wired into production gossip. |
| Message authentication/canonical bytes | `spec/CrosslinkMessageAuth.qnt`; `spec/CrosslinkHeightedMessageAuth.qnt`; `spec/CrosslinkHeightedAuthenticatedEvidence.qnt`; `test:message-auth`; `test:heighted-message-auth`; `test:heighted-authenticated-evidence`; `verify:message-auth-safety`; `verify:heighted-message-auth-safety`; `verify:heighted-authenticated-evidence-safety` | partial | Abstract signature metadata and first evidence-pipeline composition exist; not yet linked to concrete serialization or crypto. |
| Accountability witnesses | `ConflictingCommitsAccountable`, nil/value equivocation and invalid-unlock witnesses; `docs/accountability.md` | covered | Production slashing evidence formats remain open. |
| Fork finality over PoW branches | `spec/CrosslinkForkFinality.qnt`; `test:finality`; `verify:finality-safety` | covered | Needs concrete PoW-chain data. |
| Multi-height finalized prefix | `spec/CrosslinkMultiHeight.qnt`; `spec/CrosslinkHeightedRound.qnt`; `spec/CrosslinkHeightedFinality.qnt`; `test:multi-height`; `test:heighted-round`; `test:heighted-finality`; `verify:multi-height-safety`; `verify:heighted-round-safety`; `verify:heighted-finality-safety` | partial | Heighted finality exists; production data/linkage remains abstract. |
| Composed round recovery plus finality | `spec/CrosslinkComposed.qnt`; `spec/CrosslinkHeightedFinality.qnt`; `test:composed`; `test:heighted-finality`; `verify:composed-safety`; `verify:heighted-finality-safety` | partial | Heighted composition exists; production data/linkage remains abstract. |
| Liveness under stream stability | `NilPrecommitResamplingStableWindowLiveness`, `CrosslinkComposedLivenessModel`, `CrosslinkSchedulerLivenessModel`, `CrosslinkSchedulerProgressContractModel`; `test:scheduler-liveness`; `test:scheduler-progress-contract`; `verify:scheduler-liveness-safety`; `verify:scheduler-progress-contract-safety`; `verify:temporal` | partial | Bounded scheduler-parametric checks and a TLC temporal scheduler contract now exist; no full composed protocol temporal liveness proof yet. |
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
liveness, scheduler progress contract, head-sigma sampling, heighted
head-sigma rounds, BFT-block header shape checks, proposal validity, valid-round evidence, fork
finality, composed resampling/finality, composed liveness, multi-height finality,
height-indexed round-machine behavior, heighted finality composition, evidence
gossip, heighted evidence gossip, message authentication, heighted message
authentication, validator-set changes, heighted validator evidence, and
heighted authenticated evidence.

`npm run verify` currently runs bounded Apalache safety checks at depth 3 for:

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
CrosslinkSchedulerLivenessModel
CrosslinkSchedulerProgressContractModel
CrosslinkHeadSigmaSamplingModel
CrosslinkHeightedHeadSigmaRoundModel
CrosslinkBftBlockShapeModel
```

`npm run verify:extended` is a non-default deeper gate for the newest moving
stream, BFT-block-shape, and evidence-composition models. It currently runs
depth-5 Apalache checks for:

```text
CrosslinkHeadSigmaSamplingModel
CrosslinkHeightedHeadSigmaRoundModel
CrosslinkBftBlockShapeModel
CrosslinkHeightedValidatorEvidenceModel
CrosslinkHeightedAuthenticatedEvidenceModel
```

`npm run verify:temporal` currently runs TLC on:

```text
CrosslinkSchedulerProgressContractModel / EventuallyStableDecision
```

This is a temporal progress contract for the scheduler envelope, not yet a
temporal proof over the full imported protocol state.

## Remaining Work

The goal is not complete yet. The strongest remaining gaps are:

- lift the TLC-checked scheduler progress contract into a general temporal
  liveness proof over the composed protocol under post-GST stream stability;
- expand the BFT-block header-shape model into captured production data vectors
  and concrete header-validation checks;
- link message-authentication and evidence-gossip models to production
  serialization, signatures, and gossip transport;
- link dynamic validator-set changes to production signer-set formats;
- continue expanding bounded verification depth and targeted counterexample
  searches beyond the current depth-5 extended gate for the new standalone
  models.
