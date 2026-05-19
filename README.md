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
  models validator-set/GST growth as the vulnerable window, uses the
  one-block Poisson/union-bound numerator for normal block-arrival exposure,
  and keeps long-reorg tails as an explicit geometric-decay profile by sigma.
- `spec/CrosslinkPowReorgStress.qnt` adds a concrete bounded fork-tree stress
  witness for that risk: a long reorg and a same-branch block arrival both
  change `head - sigma` between prevote and precommit, causing nil-precommit
  resampling to burn rounds until a stable head-sigma window decides.
- `spec/CrosslinkDynamicSigma.qnt` models dynamic-sigma Crosslink as a third
  first-class variant: nil-precommit resampling plus a consensus-visible sigma
  schedule. Sigma is fixed for an active BFT height, then updated at height
  boundaries from committed round-failure telemetry and a quorum-backed network
  coverage model, including the percentage of PoW hash power participating in
  Crosslink. Participation has two thresholds: the target required before sigma
  may relax, and a lower floor where participation is itself enough to raise
  sigma.
- `spec/CrosslinkDynamicSigmaConsensusParams.qnt` adds the consensus-parameter
  boundary for that controller: committed per-height
  `bc_confirmation_depth_sigma` params must decode to the active sigma,
  activation height, and telemetry source height; nil-precommit round burns
  cannot rewrite params; malformed, stale, or out-of-range param wires are
  rejected.
- `spec/CrosslinkDynamicSigmaConsensusParamFormat.qnt` pins the first
  production-shaped byte envelope for those params: key tag, activation height,
  telemetry height, and sigma at fixed offsets, with trailing-byte, wrong-key,
  stale-activation, and out-of-range-sigma rejection.
- `spec/CrosslinkDynamicSigmaConsensusParamTransport.qnt` adds the
  authenticated gossip and node-config boundary for those bytes: a node only
  installs a next-height sigma param after quorum-signed canonical param bytes
  are gossiped on the Crosslink consensus topic.
- `spec/CrosslinkDynamicSigmaHeadSampling.qnt` composes that third variant with
  concrete `head - sigma(h)` sampling: already-sampled same-height candidates
  survive nil-precommit round burns, while committed telemetry changes the
  candidate depth only for future BFT heights.
- `spec/CrosslinkDynamicSigmaHeightedRound.qnt` carries the dynamic-sigma
  schedule into the height-indexed round machine: fresh proposals and value
  precommits use `head - sigma(h)`, nil-precommit resampling keeps the active
  height's sigma fixed, and a BFT-height transition uses committed telemetry to
  change the next height's proposal depth.
- `spec/CrosslinkDynamicSigmaHeightedFinality.qnt` composes that dynamic
  `head - sigma(h)` round stream with Crosslink finality: finalized BFT heights
  must come from local heighted decisions and satisfy the decided height's
  dynamic sigma tail, including telemetry-raised sigma at later heights.
- `spec/CrosslinkDynamicSigmaHeightedAuthenticatedEvidence.qnt` constrains the
  heighted authenticated-evidence pipeline to the same dynamic candidates:
  signed value precommits and fat pointers must carry the active height/round's
  `head - sigma(h)` value.
- `spec/CrosslinkDynamicSigmaAuthenticatedFinality.qnt` adds authenticated
  evidence to that dynamic finality boundary: the finality cursor advances only
  after observer-local authenticated precommit evidence and fat-pointer
  signatures support the same dynamic height/round/candidate.
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
- `spec/CrosslinkProductionFixtureVectorsGenerated.qnt` is generated from that
  fixture manifest and is imported by the BFT-block and fat-pointer production
  vector specs so checked-in fixture constants do not have to be copied by hand.
  The manifest/module also pin the fixture payload, pubkey, vote signature, and
  `pubkey || payload` sign-data hex strings; `test:fixture-manifest` verifies
  those Ed25519 signatures with Node's built-in crypto.
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
- `spec/CrosslinkFixtureAuthenticatedEvidence.qnt` bridges the generated
  production fixture constants into that authenticated observer pipeline: the
  one-signature checked-in fixture wire is accepted only after its matching
  abstract precommit is gossiped. The executable model keeps signature tokens
  compact while the generated fixture artifacts pin the real byte strings.
- `spec/CrosslinkFixtureGossipTransport.qnt` adds a fixture transport boundary:
  the generated fixture precommit and fat-pointer wire must first be gossiped
  in canonical Crosslink-topic envelopes before the observer accepts the wire;
  wrong topic, wrong sign bytes, wrong kind, and wrong wire length are rejected.

The current spec surface has three first-class Crosslink variants:

- `BaselineCrosslink`: baseline Crosslink behavior where round state carries
  a stale stream sample across a failed round.
- `NilPrecommitResamplingCrosslink`: proposed nil-precommit resampling behavior
  where a `2f + 1 PRECOMMIT nil` certificate abandons that round, clears
  same-round lock/valid state, and lets the next round resample the stream.
- `CrosslinkDynamicSigmaModel`: dynamic-sigma Crosslink, which keeps the
  nil-precommit resampling rule but makes sigma a consensus-visible per-height
  schedule updated only from committed telemetry at BFT-height boundaries.
  Low Crosslink-participating PoW hash power is modeled separately from
  validator/network coverage: it contributes to sigma-relevant pressure for
  long-reorg or ambiguous low-coverage failures, prevents sigma relaxation below
  the target, and raises sigma directly below the critical participation floor.
  `CrosslinkDynamicSigmaConsensusParamsModel` checks that the schedule is
  installed through canonical `bc_confirmation_depth_sigma` consensus-param
  wires at height boundaries and rejects malformed keys, stale activation
  heights, and out-of-range sigma values.
  `CrosslinkDynamicSigmaConsensusParamFormatModel` pins a compact production
  byte layout for those wires and routes accepted bytes through the same
  controller.
  `CrosslinkDynamicSigmaConsensusParamTransportModel` requires quorum-signed
  canonical param bytes on the Crosslink gossip topic before the node config
  follows a committed next-height sigma.
  `CrosslinkDynamicSigmaHeightedRoundModel` now checks that this schedule is
  also respected by height-indexed proposals, precommits, and nil-round
  resampling, `CrosslinkDynamicSigmaHeightedFinalityModel` checks that finality
  uses the active BFT height's dynamic sigma tail,
  `CrosslinkDynamicSigmaHeightedAuthenticatedEvidenceModel` checks that
  authenticated evidence carries the same dynamic candidate, and
  `CrosslinkDynamicSigmaAuthenticatedFinalityModel` requires authenticated
  fat-pointer evidence before dynamic finality can advance.

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
PoW-reorg stress, dynamic-sigma, dynamic-sigma consensus-params,
dynamic-sigma consensus-param-format, dynamic-sigma consensus-param-transport,
dynamic-sigma head-sampling, dynamic-sigma heighted-round,
dynamic-sigma heighted-finality,
dynamic-sigma heighted-authenticated-evidence,
dynamic-sigma authenticated-finality, head-sigma, BFT-block-shape,
BFT-block validation-gap, BFT-block production-vector, fat-pointer-format,
fat-pointer production-vector, fat-pointer
authenticated-evidence, fixture-authenticated evidence, fixture-gossip
transport, validator-evidence, and authenticated evidence composition models.

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
quint typecheck spec/CrosslinkDynamicSigma.qnt
quint typecheck spec/CrosslinkDynamicSigmaConsensusParams.qnt
quint typecheck spec/CrosslinkDynamicSigmaConsensusParamFormat.qnt
quint typecheck spec/CrosslinkDynamicSigmaConsensusParamTransport.qnt
quint typecheck spec/CrosslinkDynamicSigmaHeadSampling.qnt
quint typecheck spec/CrosslinkDynamicSigmaHeightedRound.qnt
quint typecheck spec/CrosslinkDynamicSigmaHeightedFinality.qnt
quint typecheck spec/CrosslinkDynamicSigmaHeightedAuthenticatedEvidence.qnt
quint typecheck spec/CrosslinkDynamicSigmaAuthenticatedFinality.qnt
quint typecheck spec/CrosslinkHeadSigmaSampling.qnt
quint typecheck spec/CrosslinkHeightedHeadSigmaRound.qnt
quint typecheck spec/CrosslinkBftBlockShape.qnt
quint typecheck spec/CrosslinkBftBlockValidationGap.qnt
quint typecheck spec/CrosslinkProductionFixtureVectorsGenerated.qnt
quint typecheck spec/CrosslinkBftBlockProductionVectors.qnt
quint typecheck spec/CrosslinkFatPointerFormat.qnt
quint typecheck spec/CrosslinkFatPointerProductionVectors.qnt
quint typecheck spec/CrosslinkFatPointerAuthenticatedEvidence.qnt
quint typecheck spec/CrosslinkFixtureAuthenticatedEvidence.qnt
quint typecheck spec/CrosslinkFixtureGossipTransport.qnt

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
quint test spec/CrosslinkDynamicSigma.qnt --main=CrosslinkDynamicSigmaModel --max-samples=100 --backend=rust
quint test spec/CrosslinkDynamicSigmaConsensusParams.qnt --main=CrosslinkDynamicSigmaConsensusParamsModel --max-samples=100 --backend=rust
quint test spec/CrosslinkDynamicSigmaConsensusParamFormat.qnt --main=CrosslinkDynamicSigmaConsensusParamFormatModel --max-samples=100 --backend=rust
quint test spec/CrosslinkDynamicSigmaConsensusParamTransport.qnt --main=CrosslinkDynamicSigmaConsensusParamTransportModel --max-samples=100 --backend=rust
quint test spec/CrosslinkDynamicSigmaHeadSampling.qnt --main=CrosslinkDynamicSigmaHeadSamplingModel --max-samples=100 --backend=rust
quint test spec/CrosslinkDynamicSigmaHeightedRound.qnt --main=CrosslinkDynamicSigmaHeightedRoundModel --max-samples=100 --backend=rust
quint test spec/CrosslinkDynamicSigmaHeightedFinality.qnt --main=CrosslinkDynamicSigmaHeightedFinalityModel --max-samples=100 --backend=rust
quint test spec/CrosslinkDynamicSigmaHeightedAuthenticatedEvidence.qnt --main=CrosslinkDynamicSigmaHeightedAuthenticatedEvidenceModel --max-samples=100 --backend=rust
quint test spec/CrosslinkDynamicSigmaAuthenticatedFinality.qnt --main=CrosslinkDynamicSigmaAuthenticatedFinalityModel --max-samples=100 --backend=rust
quint test spec/CrosslinkHeadSigmaSampling.qnt --main=CrosslinkHeadSigmaSamplingModel --max-samples=100 --backend=rust
quint test spec/CrosslinkHeightedHeadSigmaRound.qnt --main=CrosslinkHeightedHeadSigmaRoundModel --max-samples=100 --backend=rust
quint test spec/CrosslinkBftBlockShape.qnt --main=CrosslinkBftBlockShapeModel --max-samples=100 --backend=rust
quint test spec/CrosslinkBftBlockValidationGap.qnt --main=CrosslinkBftBlockValidationGapModel --max-samples=100 --backend=rust
quint test spec/CrosslinkBftBlockProductionVectors.qnt --main=CrosslinkBftBlockProductionVectorsModel --max-samples=100 --backend=rust
node scripts/extract-bft-block-vectors.mjs --validate
node scripts/extract-bft-block-vectors.mjs --check-quint
quint test spec/CrosslinkFatPointerFormat.qnt --main=CrosslinkFatPointerFormatModel --max-samples=100 --backend=rust
quint test spec/CrosslinkFatPointerProductionVectors.qnt --main=CrosslinkFatPointerProductionVectorsModel --max-samples=100 --backend=rust
quint test spec/CrosslinkFatPointerAuthenticatedEvidence.qnt --main=CrosslinkFatPointerAuthenticatedEvidenceModel --max-samples=100 --backend=rust
quint test spec/CrosslinkFixtureAuthenticatedEvidence.qnt --main=CrosslinkFixtureAuthenticatedEvidenceModel --max-samples=100 --backend=rust
quint test spec/CrosslinkFixtureGossipTransport.qnt --main=CrosslinkFixtureGossipTransportModel --max-samples=100 --backend=rust
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
quint verify spec/CrosslinkDynamicSigma.qnt --main=CrosslinkDynamicSigmaModel --init=Init --step=Next --invariants=Safety --max-steps=5
quint verify spec/CrosslinkDynamicSigmaConsensusParams.qnt --main=CrosslinkDynamicSigmaConsensusParamsModel --init=ConsensusParamInit --step=ConsensusParamNext --invariants=ConsensusParamSafety --max-steps=5
quint verify spec/CrosslinkDynamicSigmaConsensusParamFormat.qnt --main=CrosslinkDynamicSigmaConsensusParamFormatModel --init=ProductionParamInit --step=ProductionParamNext --invariants=ProductionConsensusParamFormatSafety --max-steps=5
quint verify spec/CrosslinkDynamicSigmaConsensusParamTransport.qnt --main=CrosslinkDynamicSigmaConsensusParamTransportModel --init=ParamTransportInit --step=ParamTransportNext --invariants=ParamTransportSafety --max-steps=5
quint verify spec/CrosslinkDynamicSigmaHeadSampling.qnt --main=CrosslinkDynamicSigmaHeadSamplingModel --init=CombinedInit --step=CombinedNext --invariants=DynamicHeadSigmaSafety --max-steps=5
quint verify spec/CrosslinkDynamicSigmaHeightedRound.qnt --main=CrosslinkDynamicSigmaHeightedRoundModel --init=Init --step=Next --invariants=DynamicHeightedHeadSigmaSafety --max-steps=3
quint verify spec/CrosslinkDynamicSigmaHeightedFinality.qnt --main=CrosslinkDynamicSigmaHeightedFinalityModel --init=ComposedInit --step=ComposedNext --invariants=DynamicHeightedFinalitySafety --max-steps=3
quint verify spec/CrosslinkDynamicSigmaHeightedAuthenticatedEvidence.qnt --main=CrosslinkDynamicSigmaHeightedAuthenticatedEvidenceModel --init=DynamicInit --step=DynamicNext --invariants=DynamicAuthenticatedEvidenceSafety --max-steps=3
quint verify spec/CrosslinkDynamicSigmaAuthenticatedFinality.qnt --main=CrosslinkDynamicSigmaAuthenticatedFinalityModel --init=AuthenticatedInit --step=AuthenticatedNext --invariants=AuthenticatedDynamicFinalitySafety --max-steps=3
quint verify spec/CrosslinkHeadSigmaSampling.qnt --main=CrosslinkHeadSigmaSamplingModel --init=Init --step=Next --invariants=Safety --max-steps=3
quint verify spec/CrosslinkHeightedHeadSigmaRound.qnt --main=CrosslinkHeightedHeadSigmaRoundModel --init=Init --step=Next --invariants=HeadSigmaSafety --max-steps=3
quint verify spec/CrosslinkBftBlockShape.qnt --main=CrosslinkBftBlockShapeModel --init=Init --step=Next --invariants=Safety --max-steps=3
quint verify spec/CrosslinkBftBlockValidationGap.qnt --main=CrosslinkBftBlockValidationGapModel --init=Init --step=Next --invariants=Safety --max-steps=3
quint verify spec/CrosslinkBftBlockProductionVectors.qnt --main=CrosslinkBftBlockProductionVectorsModel --init=Init --step=Next --invariants=Safety --max-steps=5
quint verify spec/CrosslinkFatPointerFormat.qnt --main=CrosslinkFatPointerFormatModel --init=Init --step=Next --invariants=Safety --max-steps=5
quint verify spec/CrosslinkFatPointerProductionVectors.qnt --main=CrosslinkFatPointerProductionVectorsModel --init=Init --step=Next --invariants=Safety --max-steps=3
quint verify spec/CrosslinkFatPointerAuthenticatedEvidence.qnt --main=CrosslinkFatPointerAuthenticatedEvidenceModel --init=PipelineInit --step=PipelineNext --invariants=PipelineSafety --max-steps=5
quint verify spec/CrosslinkFixtureAuthenticatedEvidence.qnt --main=CrosslinkFixtureAuthenticatedEvidenceModel --init=PipelineInit --step=FixtureNext --invariants=FixtureSafety --max-steps=5
quint verify spec/CrosslinkFixtureGossipTransport.qnt --main=CrosslinkFixtureGossipTransportModel --init=TransportPipelineInit --step=TransportNext --invariants=TransportSafety --max-steps=5

quint verify spec/CrosslinkFinalityProgressContract.qnt --main=CrosslinkFinalityProgressContractModel --init=FinalityInit --step=FinalityNext --invariants=FinalitySafety --max-steps=5
quint verify spec/CrosslinkComposedProgressContract.qnt --main=CrosslinkComposedProgressContractModel --init=Init --step=Next --invariants=Safety --max-steps=5
quint verify spec/CrosslinkStreamChurnRisk.qnt --main=CrosslinkStreamChurnRiskModel --init=Init --step=Next --invariants=Safety --max-steps=5
quint verify spec/CrosslinkPowStochasticAssumptions.qnt --main=CrosslinkPowStochasticAssumptionsModel --init=Init --step=Next --invariants=Safety --max-steps=5
quint verify spec/CrosslinkPowReorgStress.qnt --main=CrosslinkPowReorgStressModel --init=Init --step=Next --invariants=Safety --max-steps=8
quint verify spec/CrosslinkDynamicSigma.qnt --main=CrosslinkDynamicSigmaModel --init=Init --step=Next --invariants=Safety --max-steps=8
quint verify spec/CrosslinkDynamicSigmaConsensusParams.qnt --main=CrosslinkDynamicSigmaConsensusParamsModel --init=ConsensusParamInit --step=ConsensusParamNext --invariants=ConsensusParamSafety --max-steps=8
quint verify spec/CrosslinkDynamicSigmaConsensusParamFormat.qnt --main=CrosslinkDynamicSigmaConsensusParamFormatModel --init=ProductionParamInit --step=ProductionParamNext --invariants=ProductionConsensusParamFormatSafety --max-steps=8
quint verify spec/CrosslinkDynamicSigmaConsensusParamTransport.qnt --main=CrosslinkDynamicSigmaConsensusParamTransportModel --init=ParamTransportInit --step=ParamTransportNext --invariants=ParamTransportSafety --max-steps=8
quint verify spec/CrosslinkDynamicSigmaHeadSampling.qnt --main=CrosslinkDynamicSigmaHeadSamplingModel --init=CombinedInit --step=CombinedNext --invariants=DynamicHeadSigmaSafety --max-steps=8
quint verify spec/CrosslinkDynamicSigmaHeightedRound.qnt --main=CrosslinkDynamicSigmaHeightedRoundModel --init=Init --step=Next --invariants=DynamicHeightedHeadSigmaSafety --max-steps=5
quint verify spec/CrosslinkDynamicSigmaHeightedFinality.qnt --main=CrosslinkDynamicSigmaHeightedFinalityModel --init=ComposedInit --step=ComposedNext --invariants=DynamicHeightedFinalitySafety --max-steps=5
quint verify spec/CrosslinkDynamicSigmaHeightedAuthenticatedEvidence.qnt --main=CrosslinkDynamicSigmaHeightedAuthenticatedEvidenceModel --init=DynamicInit --step=DynamicNext --invariants=DynamicAuthenticatedEvidenceSafety --max-steps=5
quint verify spec/CrosslinkDynamicSigmaAuthenticatedFinality.qnt --main=CrosslinkDynamicSigmaAuthenticatedFinalityModel --init=AuthenticatedInit --step=AuthenticatedNext --invariants=AuthenticatedDynamicFinalitySafety --max-steps=5
quint verify spec/CrosslinkHeadSigmaSampling.qnt --main=CrosslinkHeadSigmaSamplingModel --init=Init --step=Next --invariants=Safety --max-steps=5
quint verify spec/CrosslinkHeightedHeadSigmaRound.qnt --main=CrosslinkHeightedHeadSigmaRoundModel --init=Init --step=Next --invariants=HeadSigmaSafety --max-steps=5
quint verify spec/CrosslinkBftBlockShape.qnt --main=CrosslinkBftBlockShapeModel --init=Init --step=Next --invariants=Safety --max-steps=5
quint verify spec/CrosslinkBftBlockValidationGap.qnt --main=CrosslinkBftBlockValidationGapModel --init=Init --step=Next --invariants=Safety --max-steps=5
quint verify spec/CrosslinkBftBlockProductionVectors.qnt --main=CrosslinkBftBlockProductionVectorsModel --init=Init --step=Next --invariants=Safety --max-steps=5
quint verify spec/CrosslinkFatPointerFormat.qnt --main=CrosslinkFatPointerFormatModel --init=Init --step=Next --invariants=Safety --max-steps=5
quint verify spec/CrosslinkFatPointerProductionVectors.qnt --main=CrosslinkFatPointerProductionVectorsModel --init=Init --step=Next --invariants=Safety --max-steps=5
quint verify spec/CrosslinkFatPointerAuthenticatedEvidence.qnt --main=CrosslinkFatPointerAuthenticatedEvidenceModel --init=PipelineInit --step=PipelineNext --invariants=PipelineSafety --max-steps=5
quint verify spec/CrosslinkFixtureAuthenticatedEvidence.qnt --main=CrosslinkFixtureAuthenticatedEvidenceModel --init=PipelineInit --step=FixtureNext --invariants=FixtureSafety --max-steps=5
quint verify spec/CrosslinkFixtureGossipTransport.qnt --main=CrosslinkFixtureGossipTransportModel --init=TransportPipelineInit --step=TransportNext --invariants=TransportSafety --max-steps=5
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
