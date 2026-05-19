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
- `spec/CrosslinkFatPointerFormat.qnt` models the production fat-pointer
  signer-vector shape: the 44-byte vote payload suffix, little-endian u16
  signature count, 96-byte pubkey/signature entries, duplicate-pubkey
  rejection, exact wire-envelope offsets and length, height-scoped signer
  authorization, canonical signed bytes, quorum voting power over unique
  signers, and derivation from producer round data.

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
It runs deeper bounded Apalache checks at depth 5 for the newer head-sigma,
BFT-block-shape, fat-pointer-format, validator-evidence, and
authenticated-evidence composition models.

`npm run verify:temporal` runs in CI as a separate TLC-backed step for the
small scheduler progress contract, because TLC has mature temporal property
support while Apalache's temporal support is still experimental.

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
quint typecheck spec/CrosslinkHeadSigmaSampling.qnt
quint typecheck spec/CrosslinkHeightedHeadSigmaRound.qnt
quint typecheck spec/CrosslinkBftBlockShape.qnt
quint typecheck spec/CrosslinkFatPointerFormat.qnt

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
quint test spec/CrosslinkHeadSigmaSampling.qnt --main=CrosslinkHeadSigmaSamplingModel --max-samples=100 --backend=rust
quint test spec/CrosslinkHeightedHeadSigmaRound.qnt --main=CrosslinkHeightedHeadSigmaRoundModel --max-samples=100 --backend=rust
quint test spec/CrosslinkBftBlockShape.qnt --main=CrosslinkBftBlockShapeModel --max-samples=100 --backend=rust
quint test spec/CrosslinkFatPointerFormat.qnt --main=CrosslinkFatPointerFormatModel --max-samples=100 --backend=rust
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
quint verify spec/CrosslinkHeadSigmaSampling.qnt --main=CrosslinkHeadSigmaSamplingModel --init=Init --step=Next --invariants=Safety --max-steps=3
quint verify spec/CrosslinkHeightedHeadSigmaRound.qnt --main=CrosslinkHeightedHeadSigmaRoundModel --init=Init --step=Next --invariants=HeadSigmaSafety --max-steps=3
quint verify spec/CrosslinkBftBlockShape.qnt --main=CrosslinkBftBlockShapeModel --init=Init --step=Next --invariants=Safety --max-steps=3
quint verify spec/CrosslinkFatPointerFormat.qnt --main=CrosslinkFatPointerFormatModel --init=Init --step=Next --invariants=Safety --max-steps=5

quint verify spec/CrosslinkHeadSigmaSampling.qnt --main=CrosslinkHeadSigmaSamplingModel --init=Init --step=Next --invariants=Safety --max-steps=5
quint verify spec/CrosslinkHeightedHeadSigmaRound.qnt --main=CrosslinkHeightedHeadSigmaRoundModel --init=Init --step=Next --invariants=HeadSigmaSafety --max-steps=5
quint verify spec/CrosslinkBftBlockShape.qnt --main=CrosslinkBftBlockShapeModel --init=Init --step=Next --invariants=Safety --max-steps=5
quint verify spec/CrosslinkFatPointerFormat.qnt --main=CrosslinkFatPointerFormatModel --init=Init --step=Next --invariants=Safety --max-steps=5
quint verify spec/CrosslinkHeightedValidatorEvidence.qnt --main=CrosslinkHeightedValidatorEvidenceModel --init=Init --step=Next --invariants=Safety --max-steps=5
quint verify spec/CrosslinkHeightedAuthenticatedEvidence.qnt --main=CrosslinkHeightedAuthenticatedEvidenceModel --init=Init --step=Next --invariants=Safety --max-steps=5

quint verify spec/CrosslinkSchedulerProgressContract.qnt --backend=tlc --main=CrosslinkSchedulerProgressContractModel --init=Init --step=Next --temporal=EventuallyStableDecision --max-steps=30
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
