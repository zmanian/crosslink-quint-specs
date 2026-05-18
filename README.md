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
- `spec/CrosslinkMessageAuth.qnt` models canonical payload bytes and signature
  acceptance before messages become evidence.
- `spec/CrosslinkHeightedMessageAuth.qnt` adds the BFT-height dimension to
  the authentication boundary so signed proposals, votes, and fat-pointer
  signatures bind the claimed height as well as the round and value.

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
```

Or run the commands directly:

```sh
quint typecheck spec/CrosslinkResampling.qnt
quint typecheck spec/CrosslinkForkFinality.qnt
quint typecheck spec/CrosslinkComposed.qnt
quint typecheck spec/CrosslinkMultiHeight.qnt
quint typecheck spec/CrosslinkHeightedRound.qnt
quint typecheck spec/CrosslinkHeightedFinality.qnt
quint typecheck spec/CrosslinkEvidenceGossip.qnt
quint typecheck spec/CrosslinkMessageAuth.qnt
quint typecheck spec/CrosslinkHeightedMessageAuth.qnt

quint test spec/CrosslinkResampling.qnt --main=BaselineCrosslink --max-samples=100 --backend=rust
quint test spec/CrosslinkResampling.qnt --main=NilPrecommitResamplingCrosslink --max-samples=100 --backend=rust
quint test spec/CrosslinkResampling.qnt --main=CrosslinkEvidenceBookkeepingModel --max-samples=100 --backend=rust
quint test spec/CrosslinkResampling.qnt --main=CrosslinkWeightedQuorumModel --max-samples=100 --backend=rust
quint test spec/CrosslinkResampling.qnt --main=CrosslinkMessageEvidenceModel --max-samples=100 --backend=rust
quint test spec/CrosslinkResampling.qnt --main=CrosslinkLocalDeliveryModel --max-samples=100 --backend=rust
quint test spec/CrosslinkResampling.qnt --main=CrosslinkTimeoutModel --max-samples=100 --backend=rust
quint test spec/CrosslinkResampling.qnt --main=NilPrecommitResamplingStableWindowLiveness --max-samples=100 --backend=rust
quint test spec/CrosslinkResampling.qnt --main=CrosslinkProposalValidityModel --max-samples=100 --backend=rust
quint test spec/CrosslinkResampling.qnt --main=CrosslinkValidRoundModel --max-samples=100 --backend=rust
quint test spec/CrosslinkForkFinality.qnt --main=CrosslinkForkFinalityModel --max-samples=100 --backend=rust
quint test spec/CrosslinkComposed.qnt --main=CrosslinkComposedResamplingModel --max-samples=100 --backend=rust
quint test spec/CrosslinkComposed.qnt --main=CrosslinkComposedLivenessModel --max-samples=100 --backend=rust
quint test spec/CrosslinkMultiHeight.qnt --main=CrosslinkMultiHeightModel --max-samples=100 --backend=rust
quint test spec/CrosslinkHeightedRound.qnt --main=CrosslinkHeightedRoundModel --max-samples=100 --backend=rust
quint test spec/CrosslinkHeightedFinality.qnt --main=CrosslinkHeightedFinalityModel --max-samples=100 --backend=rust
quint test spec/CrosslinkEvidenceGossip.qnt --main=CrosslinkEvidenceGossipModel --max-samples=100 --backend=rust
quint test spec/CrosslinkMessageAuth.qnt --main=CrosslinkMessageAuthModel --max-samples=100 --backend=rust
quint test spec/CrosslinkHeightedMessageAuth.qnt --main=CrosslinkHeightedMessageAuthModel --max-samples=100 --backend=rust

quint verify spec/CrosslinkResampling.qnt --main=BaselineCrosslink --init=Init --step=Next --invariants=Safety --max-steps=3
quint verify spec/CrosslinkResampling.qnt --main=NilPrecommitResamplingCrosslink --init=Init --step=Next --invariants=Safety --max-steps=3
quint verify spec/CrosslinkForkFinality.qnt --main=CrosslinkForkFinalityModel --init=Init --step=Next --invariants=Safety --max-steps=3
quint verify spec/CrosslinkComposed.qnt --main=CrosslinkComposedResamplingModel --init=ComposedInit --step=ComposedNext --invariants=ComposedSafety --max-steps=3
quint verify spec/CrosslinkMultiHeight.qnt --main=CrosslinkMultiHeightModel --init=Init --step=Next --invariants=Safety --max-steps=3
quint verify spec/CrosslinkHeightedRound.qnt --main=CrosslinkHeightedRoundModel --init=Init --step=Next --invariants=Safety --max-steps=3
quint verify spec/CrosslinkHeightedFinality.qnt --main=CrosslinkHeightedFinalityModel --init=ComposedInit --step=ComposedNext --invariants=ComposedSafety --max-steps=3
quint verify spec/CrosslinkEvidenceGossip.qnt --main=CrosslinkEvidenceGossipModel --init=Init --step=Next --invariants=Safety --max-steps=3
quint verify spec/CrosslinkMessageAuth.qnt --main=CrosslinkMessageAuthModel --init=Init --step=Next --invariants=Safety --max-steps=3
quint verify spec/CrosslinkHeightedMessageAuth.qnt --main=CrosslinkHeightedMessageAuthModel --init=Init --step=Next --invariants=Safety --max-steps=3
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
