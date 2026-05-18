# Accountability Notes

The nil-precommit resampling rule is meant to improve liveness under Crosslink
stream churn without weakening Tendermint-style accountability.

## Evidence Types

### Value Commit Certificate

A value commit certificate for `(round r, value v)` is:

```text
2f + 1 PRECOMMIT v
```

In the model this is:

```text
PrecommitQuorum(r, v)
```

### Nil Round-Abandon Certificate

A nil round-abandon certificate for round `r` is:

```text
2f + 1 PRECOMMIT nil
```

In the model this is:

```text
NilPrecommitCert(r)
```

This is the only unlock evidence introduced by the resampling variant.

### Mixed Precommit Set

A mixed precommit set has enough total precommits to end the precommit wait, but
does not have `2f + 1` nil precommits:

```text
MixedPrecommitQuorumWithoutNilCert(r)
```

This is intentionally not unlock evidence. A mixed set does not rule out a
hidden value commit quorum under Byzantine equivocation or message delay.

## Safe Unlock Rule

The resampling rule is:

```text
If NilPrecommitCert(r):
  clear cached proposal, validValue, and lockedValue only when their round is r
  preserve older locks
  allow the next round to resample the PoW stream
```

The important non-rule is:

```text
Do not unlock on mixed precommits.
```

The model checks this with:

```text
mixedPrecommitQuorumDoesNotUnlockTest
```

## Conflicting Commit Accountability

If two conflicting values are both committed, accountability should expose at
least one of:

- same-round correct-validator equivocation,
- nil/value equivocation for a bogus nil unlock, or
- a correct validator switching values without a valid nil certificate for the
  abandoned round.

The model names these predicates:

```text
CorrectSameRoundEquivocationEvidence
CorrectNilValueEquivocationEvidence
CorrectValueSwitchWithoutUnlock
ConflictHasAccountabilityEvidence
ConflictingCommitsAccountable
```

The executable witnesses are:

```text
conflictingCommitsExposeInvalidUnlockEvidenceTest
conflictWithBogusNilUnlockExposesEquivocationEvidenceTest
nilPrecommitCertificateJustifiesSameRoundSwitchTest
laterNilCertificateDoesNotUnlockOlderValueLockTest
```

## Current Limitations

This repository does not yet fully model evidence collection as separate
bookkeeping state. The current accountability predicates inspect the message
sets directly. That is enough for the focused nil-precommit question, but the
upstream-quality version should track evidence explicitly so that the model can
distinguish protocol state from slashable evidence known to an observer.
