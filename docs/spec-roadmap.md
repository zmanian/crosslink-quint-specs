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
- Message-domain evidence now covers proposals, prevotes, precommits, and
  decided/fat-pointer certificates. `MessageEvidenceSoundness` checks that
  protocol messages are mirrored into observer evidence and that fat pointers
  have authorized signer sets with observed precommit quorum power.
- `CrosslinkEvidenceGossip.qnt` adds an explicit gossip/observer-process
  model: observers can only accept gossiped consensus messages, observed
  precommit quorums require corresponding gossip quorums, and observed fat
  pointers must be locally justified by already-observed signer precommits.
- `CrosslinkMessageAuth.qnt` adds a first canonical payload/signature boundary:
  proposals, prevotes, precommits, and fat-pointer signatures are only accepted
  when the bytes match the claimed message and the signature verifies for the
  claimed validator.
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
- Valid-round handling now has a first Tendermint-style rule: a proposal with a
  non-`-1` `validRound` must be justified by a prevote quorum for that value in
  the referenced round, `CorrectProposalValidRoundSound` makes this a safety
  obligation for correct proposal messages, and an older lock only votes across
  values when that evidence is present. `CrosslinkValidRoundModel` covers
  unjustified rejection, justified unlock, and correct-proposer rejection for
  unjustified valid-round state.
- The implementation-correspondence track has a first document in
  `docs/implementation-correspondence.md`.

- Milestone 5 has an initial stream-stability witness:
  `NilPrecommitResamplingStableWindowLiveness` shows two stream-change aborts
  followed by a stable window where resampling reaches a decision. This still
  needs to become a general temporal liveness property rather than a scripted
  executable trace.
- `CrosslinkComposedLivenessModel` now has an executable end-to-end liveness
  script that includes explicit local delivery of the proposal, prevotes, and
  precommits before finalizing the fresh candidate.
- The first multi-height finality model is in `CrosslinkMultiHeight.qnt`.
  It makes BFT decision heights sequential, permits a decision to skip PoW
  heights on the same branch, rejects skipped or duplicate BFT-height
  decisions, and keeps the finalized PoW prefix linear across BFT heights.
- `CrosslinkHeightedRound.qnt` adds the first height-indexed
  receive-reactive round-machine slice. Each validator has a sequential BFT
  height cursor, per-height round/step/lock/valid/cache state, per-height
  local delivery, and per-height decisions. It checks that nil-precommit
  resampling clears only the same height and same round, that mixed
  precommit quorums do not unlock heighted lock state, and that a validator
  cannot decide height `h + 1` before height `h`.
- The remaining multi-height work is to compose that height-indexed round
  machine with the richer one-height timeout/valid-round rules and the
  finalized-prefix model, rather than keeping round recovery and finality as
  separate slices.
