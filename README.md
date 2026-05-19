# Crosslink Quint Specs

Quint specifications for Crosslink and Tenderlink-style consensus over a moving
proof-of-work stream.

This repository is intended to grow into a Crosslink counterpart of the upstream
Tendermint Quint specs. It currently starts from the focused models developed in
the Zebra Crosslink working branch:

- `spec/CrosslinkResampling.qnt` models the Tenderlink round machine fragment
  where Crosslink proposals sample a moving PoW stream.
- `spec/CrosslinkForkFinality.qnt` models Crosslink finality over a PoW fork
  tree, including skipped PoW heights on one branch and fork rejection after
  finality.
- `spec/CrosslinkComposed.qnt` composes the round-recovery model with the
  finality model.
- `spec/CrosslinkMultiHeight.qnt` lifts the finality obligations to sequential
  BFT heights, while still allowing a BFT decision to skip PoW heights on the
  same branch.
- `spec/CrosslinkHeightedRound.qnt` adds a first height-indexed,
  receive-reactive Tenderlink round-machine slice, including per-height locks,
  valid-round/POL checks, decisions, local delivery, timeout transitions, and
  nil-precommit resampling.
- `spec/CrosslinkHeightedFinality.qnt` composes the height-indexed round
  machine with a Crosslink finality cursor so finalized BFT heights must come
  from local heighted decisions and extend the finalized PoW prefix.
- `spec/CrosslinkEvidenceGossip.qnt` separates evidence gossip from
  observer-local accepted evidence for accountability checks.
- `spec/CrosslinkHeightedEvidenceGossip.qnt` adds the BFT-height dimension to
  evidence gossip, requiring observed precommits and fat pointers to be
  justified by gossip at the same height.
- `spec/CrosslinkMessageAuth.qnt` models canonical payload bytes and signature
  acceptance before messages become evidence.
- `spec/CrosslinkHeightedMessageAuth.qnt` adds the BFT-height dimension to
  the authentication boundary so signed proposals, votes, and fat-pointer
  signatures bind the claimed height as well as the round and value.
- `spec/CrosslinkValidatorSetChange.qnt` models validator-set rotation across
  BFT heights, requiring each height's commit signers to be authorized by that
  height's active validator set.
- `spec/CrosslinkHeightedValidatorEvidence.qnt` composes validator-set
  rotation with heighted evidence, so observed precommits and fat pointers are
  authorized by the validator set active at their BFT height.
- `spec/CrosslinkHeightedAuthenticatedEvidence.qnt` composes heighted
  canonical signatures, gossip-first observer acceptance, and validator-set
  authorization for precommit and fat-pointer evidence.
- `spec/CrosslinkSchedulerLiveness.qnt` adds a bounded fair-scheduler
  liveness model for nil-precommit resampling: unstable rounds burn
  nil-precommit certificates, then a stable stream window can deliver the
  proposal/vote duties in nondeterministic validator order and decide.
- `spec/CrosslinkSchedulerProgressContract.qnt` extracts the scheduler envelope
  into a verifier-friendly temporal contract. TLC checks that the progress-only
  scheduler envelope eventually reaches the stable decision phase.
- `spec/CrosslinkFinalityProgressContract.qnt` extends that temporal scheduler
  contract with a fair finality applicator, checking that a stable decision is
  eventually reflected in the Crosslink finality cursor.
- `spec/CrosslinkComposedProgressContract.qnt` adds a stronger TLC-friendly
  composed progress contract: finitely many nil-precommit-burned rounds,
  stable proposal/vote/precommit delivery, finality-candidate validation, and
  eventual advancement of a linear finalized PoW prefix.
- `spec/CrosslinkStreamChurnRisk.qnt` adds a parameterized integer-risk model
  for the liveness intuition behind resampling: GST grows with validator-set
  size, global distribution can add quadratic delay, normal PoW head arrivals
  create prevote-to-precommit churn exposure, larger sigma only mitigates
  long-tail reorg churn, and nil-precommit resampling burns rounds until a
  stable stream window appears.
- `spec/CrosslinkPowStochasticAssumptions.qnt` turns the stochastic inputs for
  that risk layer into an executable assumption profile. It pins Zebra's
  post-Blossom 75-second PoW target spacing as the arrival-risk denominator,
  models validator-set/GST growth as the vulnerable window, and keeps
  long-reorg tails as explicit monotone integer numerators by sigma.
- `spec/CrosslinkPowReorgStress.qnt` adds a concrete bounded fork-tree stress
  witness for that risk: a long reorg and a same-branch block arrival both
  change `head - sigma` between prevote and precommit, causing nil-precommit
  resampling to burn rounds until a stable head-sigma window decides.
- `spec/CrosslinkHeadSigmaSampling.qnt` makes the proposal stream source
  explicit: `Stream(round)` corresponds to the `head - sigma` ancestor of the
  locally observed PoW head, including same-branch progress, fork switches, and
  stable-head windows.
- `spec/CrosslinkHeightedHeadSigmaRound.qnt` connects that concrete
  `head - sigma` stream back into the height-indexed round machine, checking
  that fresh proposals and value precommits line up with the current
  fork-tree-derived candidate for the BFT height and round.
- `spec/CrosslinkBftBlockShape.qnt` models the production BFT-block header
  vector shape from `FindBlockHeaders(candidate)`, separating the declared
  `head - sigma` candidate from the descendant headers carried in the proposal
  and checking stateless version, ordering, and PoW-validation guards.
- `spec/CrosslinkBftBlockValidationGap.qnt` records the current prototype
  implementation gap in `BftBlock::try_from`: incorrect header count is
  rejected, but documented version, header-order, and PoW-solution checks are
  not yet enforced at that constructor boundary. The shape model also records
  that deserialization currently has only a 2048-header envelope cap and does
  not delegate through `try_from`.
- `spec/CrosslinkBftBlockProductionVectors.qnt` pins the production BFT-block
  wire layout: u32 version, u32 BFT height, counted previous-block fat pointer,
  u32 finalization-candidate height, u32 header count, and contiguous serialized
  PoW headers. It also pins a generated manifest for the checked-in
  `test_pos_block_*.bin` `BftBlockAndFatPointerToIt` envelopes: the first
  fixture has a zero-signature previous fat pointer, later fixtures have one
  previous fat-pointer signature, all current fixtures carry three version-4
  PoW headers without header fat pointers, and all have one trailing fat
  pointer signature. The manifest also pins previous/trailing fat-pointer count
  bytes and first signer-entry byte probes. It records the current
  deserialization sigma-bypass gap.
- `spec/CrosslinkFatPointerFormat.qnt` models the production fat-pointer
  signer-vector shape: the 44-byte vote payload suffix, little-endian u16
  signature count, 96-byte pubkey/signature entries, duplicate-pubkey
  rejection, exact wire-envelope offsets and length, height-scoped signer
  authorization, canonical signed bytes, quorum voting power over unique
  signers, and derivation from producer round data.
- `spec/CrosslinkFatPointerProductionVectors.qnt` pins the small production
  byte vectors for fat pointers: count bytes 44..46, 0-4 signer wire lengths,
  contiguous 96-byte signature entries, streaming serializer/deserializer
  count-slice agreement, checked-in `test_pos_block_*.bin` previous/trailing
  fat-pointer offsets and byte probes, and the current prototype
  `try_from_bytes` reversed range gap.
- `spec/CrosslinkFatPointerAuthenticatedEvidence.qnt` connects that
  production-shaped fat pointer to the authenticated evidence path: a fat
  pointer wire can only be observed after its envelope is exact and each active
  signer entry has a matching gossiped precommit at the same height, round, and
  value.

The round-recovery model has two first-class instantiations:

- `BaselineCrosslink`: baseline Crosslink behavior where round state carries
  a stale stream sample across a failed round.
- `NilPrecommitResamplingCrosslink`: proposed nil-precommit resampling behavior
  where a `2f + 1 PRECOMMIT nil` certificate abandons that round, clears
  same-round lock/valid state, and lets the next round resample the stream.

The intended safety rule is deliberately narrow:

```text
2f + 1 PRECOMMIT value V -> decide V
2f + 1 PRECOMMIT nil     -> abort the round and resample
mixed/no quorum          -> wait or timeout; do not unlock
```

## Current Status

This is an initial standalone spec repository, not yet a complete protocol
specification. The current models are high-signal witnesses for the nil
precommit idea and Crosslink fork-finality semantics. The target is to expand
them to the same level of coverage as the upstream Tendermint Quint models:
full state-machine coverage, message validity, quorum/accountability invariants,
and model-checkable safety and liveness obligations.

See `docs/spec-roadmap.md` for the planned path to that completeness level.
The current Tendermint-to-Crosslink rule mapping is in
`docs/tendermint-crosslink-map.md`, and the nil-precommit accountability notes
are in `docs/accountability.md`. The implementation correspondence notes are in
`docs/implementation-correspondence.md`. `docs/completeness-audit.md` tracks
which roadmap requirements are covered, partial, or still open.

## Running Checks

The current specs typecheck and run with Quint `0.31.0`. Use Node 22, matching
CI. The JavaScript CLI is still the stable command-line entry point; the
simulator can use the Rust backend with `--backend=rust`.

```sh
npm install
npm test
npm run verify
npm run verify:extended
npm run verify:temporal
```

`npm run verify:extended` is intentionally separate from the default CI gate.
It runs deeper bounded Apalache checks for the newer finality-progress,
composed-progress, stream-churn risk, PoW stochastic-assumption,
PoW-reorg stress, head-sigma, BFT-block-shape, BFT-block validation-gap,
BFT-block production-vector, fat-pointer-format, fat-pointer
production-vector, fat-pointer authenticated-evidence, validator-evidence,
and authenticated evidence composition models.

`npm run verify:temporal` runs in CI as a separate TLC-backed step for the
small scheduler progress contract, the scheduler-plus-finality contract, and
the composed nil-resampling/finality progress contract, because TLC has mature
temporal property support while Apalache's temporal support is still
experimental.

Or run the commands directly:

```sh
quint typecheck spec/CrosslinkResampling.qnt
quint typecheck spec/CrosslinkForkFinality.qnt
quint typecheck spec/CrosslinkComposed.qnt
quint typecheck spec/CrosslinkMultiHeight.qnt
quint typecheck spec/CrosslinkHeightedRound.qnt
quint typecheck spec/CrosslinkHeightedFinality.qnt
quint typecheck spec/CrosslinkEvidenceGossip.qnt
quint typecheck spec/CrosslinkHeightedEvidenceGossip.qnt
quint typecheck spec/CrosslinkMessageAuth.qnt
quint typecheck spec/CrosslinkHeightedMessageAuth.qnt
quint typecheck spec/CrosslinkValidatorSetChange.qnt
quint typecheck spec/CrosslinkHeightedValidatorEvidence.qnt
quint typecheck spec/CrosslinkHeightedAuthenticatedEvidence.qnt
quint typecheck spec/CrosslinkSchedulerLiveness.qnt
quint typecheck spec/CrosslinkSchedulerProgressContract.qnt
quint typecheck spec/CrosslinkFinalityProgressContract.qnt
quint typecheck spec/CrosslinkComposedProgressContract.qnt
quint typecheck spec/CrosslinkStreamChurnRisk.qnt
quint typecheck spec/CrosslinkPowStochasticAssumptions.qnt
quint typecheck spec/CrosslinkPowReorgStress.qnt
quint typecheck spec/CrosslinkHeadSigmaSampling.qnt
quint typecheck spec/CrosslinkHeightedHeadSigmaRound.qnt
quint typecheck spec/CrosslinkBftBlockShape.qnt
quint typecheck spec/CrosslinkBftBlockValidationGap.qnt
quint typecheck spec/CrosslinkBftBlockProductionVectors.qnt
quint typecheck spec/CrosslinkFatPointerFormat.qnt
quint typecheck spec/CrosslinkFatPointerProductionVectors.qnt
quint typecheck spec/CrosslinkFatPointerAuthenticatedEvidence.qnt

quint test spec/CrosslinkResampling.qnt --main=BaselineCrosslink --max-samples=100 --backend=rust
quint test spec/CrosslinkResampling.qnt --main=NilPrecommitResamplingCrosslink --max-samples=100 --backend=rust
quint test spec/CrosslinkResampling.qnt --main=CrosslinkEvidenceBookkeepingModel --max-samples=100 --backend=rust
quint test spec/CrosslinkResampling.qnt --main=CrosslinkWeightedQuorumModel --max-samples=100 --backend=rust
quint test spec/CrosslinkResampling.qnt --main=CrosslinkMessageEvidenceModel --max-samples=100 --backend=rust
quint test spec/CrosslinkResampling.qnt --main=CrosslinkLocalDeliveryModel --max-samples=100 --backend=rust
quint test spec/CrosslinkResampling.qnt --main=CrosslinkTimeoutModel --max-samples=100 --backend=rust
quint test spec/CrosslinkResampling.qnt --main=NilPrecommitResamplingStableWindowLiveness --max-samples=100 --backend=rust
quint test spec/CrosslinkSchedulerLiveness.qnt --main=CrosslinkSchedulerLivenessModel --max-samples=100 --backend=rust
quint test spec/CrosslinkSchedulerProgressContract.qnt --main=CrosslinkSchedulerProgressContractModel --max-samples=100 --backend=rust
quint test spec/CrosslinkFinalityProgressContract.qnt --main=CrosslinkFinalityProgressContractModel --max-samples=100 --backend=rust
quint test spec/CrosslinkComposedProgressContract.qnt --main=CrosslinkComposedProgressContractModel --max-samples=100 --backend=rust
quint test spec/CrosslinkStreamChurnRisk.qnt --main=CrosslinkStreamChurnRiskModel --max-samples=100 --backend=rust
quint test spec/CrosslinkPowStochasticAssumptions.qnt --main=CrosslinkPowStochasticAssumptionsModel --max-samples=100 --backend=rust
quint test spec/CrosslinkPowReorgStress.qnt --main=CrosslinkPowReorgStressModel --max-samples=100 --backend=rust
quint test spec/CrosslinkHeadSigmaSampling.qnt --main=CrosslinkHeadSigmaSamplingModel --max-samples=100 --backend=rust
quint test spec/CrosslinkHeightedHeadSigmaRound.qnt --main=CrosslinkHeightedHeadSigmaRoundModel --max-samples=100 --backend=rust
quint test spec/CrosslinkBftBlockShape.qnt --main=CrosslinkBftBlockShapeModel --max-samples=100 --backend=rust
quint test spec/CrosslinkBftBlockValidationGap.qnt --main=CrosslinkBftBlockValidationGapModel --max-samples=100 --backend=rust
quint test spec/CrosslinkBftBlockProductionVectors.qnt --main=CrosslinkBftBlockProductionVectorsModel --max-samples=100 --backend=rust
node scripts/extract-bft-block-vectors.mjs --validate
quint test spec/CrosslinkFatPointerFormat.qnt --main=CrosslinkFatPointerFormatModel --max-samples=100 --backend=rust
quint test spec/CrosslinkFatPointerProductionVectors.qnt --main=CrosslinkFatPointerProductionVectorsModel --max-samples=100 --backend=rust
quint test spec/CrosslinkFatPointerAuthenticatedEvidence.qnt --main=CrosslinkFatPointerAuthenticatedEvidenceModel --max-samples=100 --backend=rust
quint test spec/CrosslinkResampling.qnt --main=CrosslinkProposalValidityModel --max-samples=100 --backend=rust
quint test spec/CrosslinkResampling.qnt --main=CrosslinkValidRoundModel --max-samples=100 --backend=rust
quint test spec/CrosslinkForkFinality.qnt --main=CrosslinkForkFinalityModel --max-samples=100 --backend=rust
quint test spec/CrosslinkComposed.qnt --main=CrosslinkComposedResamplingModel --max-samples=100 --backend=rust
quint test spec/CrosslinkComposed.qnt --main=CrosslinkComposedLivenessModel --max-samples=100 --backend=rust
quint test spec/CrosslinkMultiHeight.qnt --main=CrosslinkMultiHeightModel --max-samples=100 --backend=rust
quint test spec/CrosslinkHeightedRound.qnt --main=CrosslinkHeightedRoundModel --max-samples=100 --backend=rust
quint test spec/CrosslinkHeightedFinality.qnt --main=CrosslinkHeightedFinalityModel --max-samples=100 --backend=rust
quint test spec/CrosslinkEvidenceGossip.qnt --main=CrosslinkEvidenceGossipModel --max-samples=100 --backend=rust
quint test spec/CrosslinkHeightedEvidenceGossip.qnt --main=CrosslinkHeightedEvidenceGossipModel --max-samples=100 --backend=rust
quint test spec/CrosslinkMessageAuth.qnt --main=CrosslinkMessageAuthModel --max-samples=100 --backend=rust
quint test spec/CrosslinkHeightedMessageAuth.qnt --main=CrosslinkHeightedMessageAuthModel --max-samples=100 --backend=rust
quint test spec/CrosslinkValidatorSetChange.qnt --main=CrosslinkValidatorSetChangeModel --max-samples=100 --backend=rust
quint test spec/CrosslinkHeightedValidatorEvidence.qnt --main=CrosslinkHeightedValidatorEvidenceModel --max-samples=100 --backend=rust
quint test spec/CrosslinkHeightedAuthenticatedEvidence.qnt --main=CrosslinkHeightedAuthenticatedEvidenceModel --max-samples=100 --backend=rust

quint verify spec/CrosslinkResampling.qnt --main=BaselineCrosslink --init=Init --step=Next --invariants=Safety --max-steps=3
quint verify spec/CrosslinkResampling.qnt --main=NilPrecommitResamplingCrosslink --init=Init --step=Next --invariants=Safety --max-steps=3
quint verify spec/CrosslinkForkFinality.qnt --main=CrosslinkForkFinalityModel --init=Init --step=Next --invariants=Safety --max-steps=3
quint verify spec/CrosslinkComposed.qnt --main=CrosslinkComposedResamplingModel --init=ComposedInit --step=ComposedNext --invariants=ComposedSafety --max-steps=3
quint verify spec/CrosslinkMultiHeight.qnt --main=CrosslinkMultiHeightModel --init=Init --step=Next --invariants=Safety --max-steps=3
quint verify spec/CrosslinkHeightedRound.qnt --main=CrosslinkHeightedRoundModel --init=Init --step=Next --invariants=Safety --max-steps=3
quint verify spec/CrosslinkHeightedFinality.qnt --main=CrosslinkHeightedFinalityModel --init=ComposedInit --step=ComposedNext --invariants=ComposedSafety --max-steps=3
quint verify spec/CrosslinkEvidenceGossip.qnt --main=CrosslinkEvidenceGossipModel --init=Init --step=Next --invariants=Safety --max-steps=3
quint verify spec/CrosslinkHeightedEvidenceGossip.qnt --main=CrosslinkHeightedEvidenceGossipModel --init=Init --step=Next --invariants=Safety --max-steps=3
quint verify spec/CrosslinkMessageAuth.qnt --main=CrosslinkMessageAuthModel --init=Init --step=Next --invariants=Safety --max-steps=3
quint verify spec/CrosslinkHeightedMessageAuth.qnt --main=CrosslinkHeightedMessageAuthModel --init=Init --step=Next --invariants=Safety --max-steps=3
quint verify spec/CrosslinkValidatorSetChange.qnt --main=CrosslinkValidatorSetChangeModel --init=Init --step=Next --invariants=Safety --max-steps=3
quint verify spec/CrosslinkHeightedValidatorEvidence.qnt --main=CrosslinkHeightedValidatorEvidenceModel --init=Init --step=Next --invariants=Safety --max-steps=3
quint verify spec/CrosslinkHeightedAuthenticatedEvidence.qnt --main=CrosslinkHeightedAuthenticatedEvidenceModel --init=Init --step=Next --invariants=Safety --max-steps=3
quint verify spec/CrosslinkSchedulerLiveness.qnt --main=CrosslinkSchedulerLivenessModel --init=SchedulerInit --step=SchedulerStep --invariants=SchedulerSafety --max-steps=3
quint verify spec/CrosslinkSchedulerProgressContract.qnt --main=CrosslinkSchedulerProgressContractModel --init=Init --step=Next --invariants=Safety --max-steps=5
quint verify spec/CrosslinkFinalityProgressContract.qnt --main=CrosslinkFinalityProgressContractModel --init=FinalityInit --step=FinalityNext --invariants=FinalitySafety --max-steps=5
quint verify spec/CrosslinkComposedProgressContract.qnt --main=CrosslinkComposedProgressContractModel --init=Init --step=Next --invariants=Safety --max-steps=5
quint verify spec/CrosslinkStreamChurnRisk.qnt --main=CrosslinkStreamChurnRiskModel --init=Init --step=Next --invariants=Safety --max-steps=5
quint verify spec/CrosslinkPowStochasticAssumptions.qnt --main=CrosslinkPowStochasticAssumptionsModel --init=Init --step=Next --invariants=Safety --max-steps=5
quint verify spec/CrosslinkPowReorgStress.qnt --main=CrosslinkPowReorgStressModel --init=Init --step=Next --invariants=Safety --max-steps=5
quint verify spec/CrosslinkHeadSigmaSampling.qnt --main=CrosslinkHeadSigmaSamplingModel --init=Init --step=Next --invariants=Safety --max-steps=3
quint verify spec/CrosslinkHeightedHeadSigmaRound.qnt --main=CrosslinkHeightedHeadSigmaRoundModel --init=Init --step=Next --invariants=HeadSigmaSafety --max-steps=3
quint verify spec/CrosslinkBftBlockShape.qnt --main=CrosslinkBftBlockShapeModel --init=Init --step=Next --invariants=Safety --max-steps=3
quint verify spec/CrosslinkBftBlockValidationGap.qnt --main=CrosslinkBftBlockValidationGapModel --init=Init --step=Next --invariants=Safety --max-steps=3
quint verify spec/CrosslinkBftBlockProductionVectors.qnt --main=CrosslinkBftBlockProductionVectorsModel --init=Init --step=Next --invariants=Safety --max-steps=5
quint verify spec/CrosslinkFatPointerFormat.qnt --main=CrosslinkFatPointerFormatModel --init=Init --step=Next --invariants=Safety --max-steps=5
quint verify spec/CrosslinkFatPointerProductionVectors.qnt --main=CrosslinkFatPointerProductionVectorsModel --init=Init --step=Next --invariants=Safety --max-steps=3
quint verify spec/CrosslinkFatPointerAuthenticatedEvidence.qnt --main=CrosslinkFatPointerAuthenticatedEvidenceModel --init=PipelineInit --step=PipelineNext --invariants=PipelineSafety --max-steps=5

quint verify spec/CrosslinkFinalityProgressContract.qnt --main=CrosslinkFinalityProgressContractModel --init=FinalityInit --step=FinalityNext --invariants=FinalitySafety --max-steps=5
quint verify spec/CrosslinkComposedProgressContract.qnt --main=CrosslinkComposedProgressContractModel --init=Init --step=Next --invariants=Safety --max-steps=5
quint verify spec/CrosslinkStreamChurnRisk.qnt --main=CrosslinkStreamChurnRiskModel --init=Init --step=Next --invariants=Safety --max-steps=5
quint verify spec/CrosslinkPowStochasticAssumptions.qnt --main=CrosslinkPowStochasticAssumptionsModel --init=Init --step=Next --invariants=Safety --max-steps=5
quint verify spec/CrosslinkPowReorgStress.qnt --main=CrosslinkPowReorgStressModel --init=Init --step=Next --invariants=Safety --max-steps=8
quint verify spec/CrosslinkHeadSigmaSampling.qnt --main=CrosslinkHeadSigmaSamplingModel --init=Init --step=Next --invariants=Safety --max-steps=5
quint verify spec/CrosslinkHeightedHeadSigmaRound.qnt --main=CrosslinkHeightedHeadSigmaRoundModel --init=Init --step=Next --invariants=HeadSigmaSafety --max-steps=5
quint verify spec/CrosslinkBftBlockShape.qnt --main=CrosslinkBftBlockShapeModel --init=Init --step=Next --invariants=Safety --max-steps=5
quint verify spec/CrosslinkBftBlockValidationGap.qnt --main=CrosslinkBftBlockValidationGapModel --init=Init --step=Next --invariants=Safety --max-steps=5
quint verify spec/CrosslinkBftBlockProductionVectors.qnt --main=CrosslinkBftBlockProductionVectorsModel --init=Init --step=Next --invariants=Safety --max-steps=5
quint verify spec/CrosslinkFatPointerFormat.qnt --main=CrosslinkFatPointerFormatModel --init=Init --step=Next --invariants=Safety --max-steps=5
quint verify spec/CrosslinkFatPointerProductionVectors.qnt --main=CrosslinkFatPointerProductionVectorsModel --init=Init --step=Next --invariants=Safety --max-steps=5
quint verify spec/CrosslinkFatPointerAuthenticatedEvidence.qnt --main=CrosslinkFatPointerAuthenticatedEvidenceModel --init=PipelineInit --step=PipelineNext --invariants=PipelineSafety --max-steps=5
quint verify spec/CrosslinkHeightedValidatorEvidence.qnt --main=CrosslinkHeightedValidatorEvidenceModel --init=Init --step=Next --invariants=Safety --max-steps=5
quint verify spec/CrosslinkHeightedAuthenticatedEvidence.qnt --main=CrosslinkHeightedAuthenticatedEvidenceModel --init=Init --step=Next --invariants=Safety --max-steps=5

quint verify spec/CrosslinkSchedulerProgressContract.qnt --backend=tlc --main=CrosslinkSchedulerProgressContractModel --init=Init --step=Next --temporal=EventuallyStableDecision --max-steps=30
quint verify spec/CrosslinkFinalityProgressContract.qnt --backend=tlc --main=CrosslinkFinalityProgressContractModel --init=FinalityInit --step=FinalityNext --temporal=EventuallyFinalized --max-steps=35
quint verify spec/CrosslinkComposedProgressContract.qnt --backend=tlc --main=CrosslinkComposedProgressContractModel --init=Init --step=Next --temporal=EventuallyFinalizesStableDecision --max-steps=35
```

## Source

Initial contents were extracted from the Zebra Crosslink working branch at:

```text
zmanian/zebra@79dcc6ff9a0c36b0db2f123c1d1e3b4011955464
```

## License

Licensed under either of:

- Apache License, Version 2.0, in `LICENSE-APACHE`
- MIT license, in `LICENSE-MIT`

at your option.
