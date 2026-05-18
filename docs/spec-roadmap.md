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
