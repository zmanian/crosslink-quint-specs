# Spec Roadmap

The goal is a Crosslink Quint specification with roughly the same completeness
and review quality as the upstream Tendermint Quint specs.

## Baseline Crosslink

The baseline spec should model Crosslink without nil-precommit resampling.

Required pieces:

- Full Tenderlink height/round/step state machine, not only the current focused
  round-recovery fragment.
- Proposal values as PoW-stream snapshots, including `head - sigma` sampling.
- Proposal validity split into structural validity, PoW-chain validity,
  finality-candidate validity, and freshness against the locally observed
  stream.
- Tendermint lock and valid-value rules, including `validRound` handling across
  proposals.
- Baseline behavior when the PoW stream changes between prevote and precommit.
- Finality over a fork tree, including skipped PoW heights and rejection of
  finalizing a fork after an incompatible block is already final.
- Safety invariants for one-value-per-height BFT decisions and one-linearized
  finalized PoW prefix.
- Liveness witnesses that show the known baseline halt or wasted-round behavior
  under stream churn.

## Nil-Precommit Resampling Variant

The resampling spec should layer one explicit rule on top of the baseline:

```text
Only a 2f + 1 PRECOMMIT nil certificate for round r may clear lock/valid state
whose round is exactly r and let the next round resample the moving stream.
```

Required pieces:

- Same-round unlock and cache clearing on a nil-precommit quorum.
- Late nil-precommit certificates that clear abandoned-round state without
  rewinding a validator already in a later round.
- Preservation of older Tendermint locks.
- Explicit negative rule: a mixed precommit set is not unlock evidence unless
  nil itself has quorum.
- Accountability witnesses showing that conflicting commits require either an
  invalid unlock transition or slashable nil/value equivocation.
- Liveness witnesses where repeated stream changes burn rounds but do not
  permanently wedge the protocol once the stream is stable across the
  prevote/precommit window.

## Tendermint-Quality Target

The upstream Tendermint Quint specs are useful because they are not just unit
tests. They provide:

- a small but faithful protocol transition system,
- clear assumptions about validator sets and fault thresholds,
- executable examples,
- invariants suitable for bounded model checking,
- accountability lemmas/witnesses, and
- readable documentation that ties the model back to the paper/protocol rules.

For Crosslink, matching that quality means adding:

- a single shared protocol core with separate baseline and resampling variants,
- stronger message-domain modeling for proposals, prevotes, precommits, and
  decided/fat-pointer evidence,
- model-checkable safety invariants beyond scripted witness runs,
- temporal/liveness properties for eventual decision under post-GST stream
  stability,
- an implementation correspondence document for Zebra Crosslink/Tenderlink, and
- CI that runs typecheck, example tests, and bounded verification jobs.

## Near-Term Milestones

1. Split the current focused model into a shared core plus explicit
   `BaselineCrosslink` and `NilPrecommitResamplingCrosslink` modules.
2. Import the relevant structure from the upstream Tendermint Quint examples and
   map every Tendermint rule to a Crosslink-specific rule or deviation.
3. Add model-checkable invariants for decision uniqueness, lock safety, finality
   prefix linearity, and nil-certificate unlock safety.
4. Add bounded counterexample searches for mixed-precommit unlocks and stale
   proposal carries.
5. Add a liveness model parameterized by stream-stability windows.
6. Document the accountability model: what evidence proves a bad unlock, what
   evidence proves nil/value equivocation, and what cannot be inferred from a
   mixed precommit set.

## Progress Log

### 2026-05-18

- Milestone 1 has an initial implementation: `CrosslinkResampling.qnt` now has
  explicit `BaselineCrosslink` and `NilPrecommitResamplingCrosslink` modules
  over the shared `CrosslinkResampling` core.
- Milestone 2 has a first mapping document in
  `docs/tendermint-crosslink-map.md`.
- Milestone 3 has named safety obligations in the round-recovery model:
  `DecisionUniqueness`, `DecisionsHaveCommitQuorum`, `LockSafety`, and
  `NilCertificateUnlockSafety`, all included in `Safety`. CI now also runs
  bounded Apalache safety checks for baseline round recovery, nil-precommit
  resampling, fork finality, and the composed resampling/finality model.
- Baseline proposal validity is now split into structural validity,
  PoW-chain validity, finality-candidate validity, and stream freshness.
  `CrosslinkProposalValidityModel` checks that a fresh but structurally invalid
  proposal receives a nil prevote.
- Milestone 4 has an executable negative witness:
  `mixedPrecommitQuorumDoesNotUnlockTest`.
- Milestone 6 has a first accountability document in
  `docs/accountability.md`.
- Accountability now has a first explicit observer-bookkeeping slice:
  `evidencePrecommit` is separate from protocol `msgsPrecommit`, the
  `Observed*` quorum helpers drive conflicting-commit accountability, and
  `CrosslinkEvidenceBookkeepingModel` checks that evidence can be recorded
  without mutating protocol precommit state.
- Quorum checks now use `VotingPowerOf` over explicit validator voting power
  instead of raw signer counts. The default examples remain equal-weight, and
  `CrosslinkWeightedQuorumModel` checks that two high-power validators can form
  a quorum when their summed power reaches the threshold.
- `CrosslinkValidatorSetChange.qnt` adds the first dynamic validator-set
  slice: a BFT decision records the active signer set for that height and
  installs the decided next validator set for the following height. It rejects
  removed validators signing at the next height and signer sets without quorum.
- `CrosslinkHeightedValidatorEvidence.qnt` composes that validator-set rotation
  with heighted evidence. Observed precommits and fat pointers are authorized
  by the validator set active at the evidence height, so old-height evidence
  still uses the old set while next-height evidence uses the rotated set.
- `CrosslinkHeightedAuthenticatedEvidence.qnt` adds the first composed
  authenticated evidence pipeline. A heighted precommit must have canonical
  signed bytes before it can enter gossip or observer evidence, observation
  requires prior gossip, and fat pointers require quorum signer precommits plus
  authenticated fat-pointer signatures authorized by that height's validator
  set.
- `CrosslinkSchedulerLiveness.qnt` adds a bounded fair-scheduler liveness
  slice for nil-precommit resampling. It still assumes a bounded post-GST
  window, but it no longer fixes a single validator ordering: unstable rounds
  can burn nil-precommit certificates and advance correct validators in
  nondeterministic order, then a stable round can deliver proposal, prevote,
  and precommit duties until a correct validator decides.
- `CrosslinkSchedulerProgressContract.qnt` adds the first explicit temporal
  liveness check for the scheduler envelope. It abstracts away the protocol
  state from `CrosslinkSchedulerLiveness.qnt`, keeps only progress transitions
  before decision, and TLC checks eventual entry into the stable decision
  phase over the complete finite state graph.
- `CrosslinkHeadSigmaSampling.qnt` makes the source of `Stream(round)`
  explicit. It samples the `head - sigma` ancestor of each locally observed
  PoW head and checks same-branch progress, fork-switch churn, stable-head
  windows, and tail-confirmed candidate validity.
- `CrosslinkHeightedHeadSigmaRound.qnt` connects that concrete `head - sigma`
  stream back into the height-indexed round machine. Fresh correct proposals
  must carry the current fork-tree-derived candidate, value precommits must
  target that current candidate, and a nil-precommit certificate clears the
  cached round-0 candidate so the next round can resample the new head-sigma
  value.
- `CrosslinkBftBlockShape.qnt` adds the first implementation-shaped proposal
  payload model. It captures the fact that Zebra's `FindBlockHeaders` response
  starts after the known candidate hash, so a locally produced proposal can
  carry exactly sigma descendant headers while the finality candidate remains
  the declared `head - sigma` ancestor. It also models the stateless validation
  guards documented on `BftBlock::try_from`: expected version, sigma header
  count, consecutive header order, and valid PoW solutions.
- `CrosslinkFatPointerFormat.qnt` adds the first production-shaped fat-pointer
  signer-vector model. It captures the 44-byte vote payload suffix,
  little-endian u16 count, and 96-byte pubkey/signature entries; rejects
  truncated or trailing-byte wire envelopes, wrong byte offsets, and duplicate
  pubkeys that could inflate quorum power; scopes signer authorization to the
  evidence BFT height; checks canonical signed bytes before a fat pointer can
  be accepted; and models derivation from producer round data so missing
  signatures, nil precommit signers, and wrong-height fat pointers are
  rejected.
- `CrosslinkFatPointerAuthenticatedEvidence.qnt` connects that
  production-shaped signer vector to the authenticated observer pipeline. A
  production fat pointer can only be observed after every active signer entry
  is backed by a matching gossiped precommit at the same BFT height, round, and
  value; the witnesses reject observation before gossip, missing signer
  precommits, duplicate signer entries, and removed-validator next-height
  precommits.
- Message-domain evidence now covers proposals, prevotes, precommits, and
  decided/fat-pointer certificates. `MessageEvidenceSoundness` checks that
  protocol messages are mirrored into observer evidence and that fat pointers
  have authorized signer sets with observed precommit quorum power.
- `CrosslinkEvidenceGossip.qnt` adds an explicit gossip/observer-process
  model: observers can only accept gossiped consensus messages, observed
  precommit quorums require corresponding gossip quorums, and observed fat
  pointers must be locally justified by already-observed signer precommits.
- `CrosslinkHeightedEvidenceGossip.qnt` adds the same observer-process shape
  for height-indexed evidence. Observed precommit quorums and fat pointers are
  justified only by gossip and signer precommit evidence at the same BFT
  height, including a cross-height fat-pointer rejection witness.
- `CrosslinkMessageAuth.qnt` adds a first canonical payload/signature boundary:
  proposals, prevotes, precommits, and fat-pointer signatures are only accepted
  when the bytes match the claimed message and the signature verifies for the
  claimed validator.
- `CrosslinkHeightedMessageAuth.qnt` adds the same boundary for height-indexed
  messages. Canonical proposal, vote, and fat-pointer bytes bind the claimed
  BFT height, preventing cross-height replay at the model boundary.
- The model now has a first local-delivery slice: `seenPropose`,
  `seenPrevote`, and `seenPrecommit` track receiver-local messages,
  `DeliverProposal`/`DeliverPrevote`/`DeliverPrecommit` refuse messages that
  were not broadcast, and `CrosslinkLocalDeliveryModel` shows that local quorum
  evidence only appears after delivery.
- The main round machine now uses local receive guards for proposal prevote,
  value precommit, precommit-quorum round advancement, late nil-certificate
  recovery, and decision. Global quorum predicates remain as broadcast-level
  evidence helpers for invariants and witnesses.
- The round model now includes initial Tenderlink timeout transitions:
  propose timeout broadcasts a nil prevote, prevote timeout broadcasts a nil
  precommit, and precommit timeout advances the round without clearing
  lock/valid/cache state unless a nil-precommit certificate exists.
- The heighted round model now distinguishes a cached proposal from a real
  Tendermint `validValue`/`validRound` lock. After a timeout-only round advance
  with no value lock, the next fresh proposal resamples the current
  `head - sigma` stream; older value locks remain preserved across timeout and
  mixed-precommit paths.
- Valid-round handling now has a first Tendermint-style rule: a proposal with a
  non-`-1` `validRound` must be justified by a prevote quorum for that value in
  the referenced round, `CorrectProposalValidRoundSound` makes this a safety
  obligation for correct proposal messages, and an older lock only votes across
  values when that evidence is present. `CrosslinkValidRoundModel` covers
  unjustified rejection, justified unlock, and correct-proposer rejection for
  unjustified valid-round state.
- The implementation-correspondence track has a first document in
  `docs/implementation-correspondence.md`.
- `npm run verify:extended` adds a non-default deeper bounded-check gate for
  the newest head-sigma, BFT-block-shape, fat-pointer-format, heighted
  validator-evidence, and heighted authenticated-evidence models. It keeps
  default CI at bounded depth while giving reviewers a depth-5 Apalache check
  for the models most likely to hide cross-component state-space mistakes.

- Milestone 5 has an initial stream-stability witness:
  `NilPrecommitResamplingStableWindowLiveness` shows two stream-change aborts
  followed by a stable window where resampling reaches a decision. This still
  needs to become a general temporal liveness property rather than a scripted
  executable trace.
- `CrosslinkSchedulerLivenessModel` strengthens that liveness track with a
  bounded fair-scheduler model and a `SchedulerSafety` invariant. It remains a
  bounded scheduler-parametric check, not a full temporal proof.
- `CrosslinkSchedulerProgressContractModel` now supplies a TLC-checked temporal
  contract for that scheduler envelope. It is not yet a full composed protocol
  liveness proof, because current temporal backends have trouble with the full
  imported round-machine state.
- `CrosslinkComposedLivenessModel` now has an executable end-to-end liveness
  script that includes explicit local delivery of the proposal, prevotes, and
  precommits before finalizing the fresh candidate.
- `CrosslinkHeadSigmaSamplingModel` closes the first part of the
  `head - sigma` sampling gap by replacing arbitrary stream values with a
  concrete fork-tree-derived stream witness.
- The first multi-height finality model is in `CrosslinkMultiHeight.qnt`.
  It makes BFT decision heights sequential, permits a decision to skip PoW
  heights on the same branch, rejects skipped or duplicate BFT-height
  decisions, and keeps the finalized PoW prefix linear across BFT heights.
- `CrosslinkHeightedRound.qnt` adds the first height-indexed
  receive-reactive round-machine slice. Each validator has a sequential BFT
  height cursor, per-height round/step/lock/valid/cache state, per-height
  valid-round/POL evidence, local delivery, timeout transitions, and
  per-height decisions. It checks that nil-precommit resampling clears only
  the same height and same round, that mixed precommit quorums do not unlock
  heighted lock state, that precommit timeout does not unlock heighted lock
  state, that unjustified heighted `validRound` proposals prevote nil, and
  that a validator cannot decide height `h + 1` before height `h`.
- `CrosslinkHeightedFinality.qnt` composes that height-indexed round machine
  with a finality cursor. A BFT height only advances finality after a local
  heighted decision, and the decided snapshot must extend the finalized PoW
  prefix. The witnesses cover nil-precommit resampling followed by finality,
  rejection of undecided-height finality, and rejection of a later fork after
  an earlier BFT height is final.
- The remaining multi-height work is to connect the heighted auth, evidence,
  validator-set, BFT-block-shape, fat-pointer-format, and production-shaped
  fat-pointer observer models to concrete serialization vectors, real
  signatures, header validity checks, and gossip transport, and to lift the
  scheduler temporal contract into a full composed protocol temporal proof.
