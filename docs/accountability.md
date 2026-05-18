# Accountability Notes

The nil-precommit resampling rule is meant to improve liveness under Crosslink
stream churn without weakening Tendermint-style accountability.

The notation below still says `2f + 1` because that is the familiar
Tendermint shorthand. In the Quint model, quorum predicates are computed over
summed validator voting power via `VotingPowerOf(...) >= QuorumVotingPower`.
The height-indexed model scopes the same rule to `(height h, round r)`.

## Evidence Types

### Value Commit Certificate

A value commit certificate for `(round r, value v)` is:

```text
2f + 1 PRECOMMIT v
```

In the model this is:

```text
ObservedPrecommitQuorum(r, v)
```

`LocalPrecommitQuorum(p, r, v)` is the receiver-local quorum used by decision
rules. `PrecommitQuorum(r, v)` remains a broadcast-level helper in invariants
and witnesses. Accountability checks use observed evidence, so they can reason
about certificates after the live protocol state has moved on.

### Nil Round-Abandon Certificate

A nil round-abandon certificate for round `r` is:

```text
2f + 1 PRECOMMIT nil
```

In the model this is:

```text
ObservedNilPrecommitCert(r)
```

This is the only unlock evidence introduced by the resampling variant.
`LocalNilPrecommitCert(p, r)` is the receiver-local condition that actually
clears same-round state in the resampling transition. `NilPrecommitCert(r)`
remains a broadcast-level helper for invariants and witnesses.

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
If LocalNilPrecommitCert(p, r):
  clear cached proposal, validValue, and lockedValue only when their round is r
  preserve older locks
  allow the next round to resample the PoW stream
```

In `CrosslinkHeightedRound.qnt`, the same rule is height-scoped:

```text
If LocalNilPrecommitCert(p, h, r):
  clear only active-height state whose round is r
  preserve state for other BFT heights
```

The important non-rule is:

```text
Do not unlock on mixed precommits.
Do not unlock on timeout alone.
```

The model checks this with:

```text
mixedPrecommitQuorumDoesNotUnlockTest
mixedPrecommitQuorumDoesNotClearHeightedLockTest
precommitTimeoutDoesNotUnlockWithoutNilCertificateTest
precommitTimeoutDoesNotClearHeightedLockTest
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
ObservedPrecommitQuorum
ObservedNilPrecommitCert
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

The bookkeeping-specific witnesses are:

```text
observedEvidenceDoesNotMutateProtocolMessagesTest
evidenceOnlyConflictStillHasAccountabilityWitnessTest
validFatPointerEvidenceWitnessTest
fatPointerRequiresSignerPrecommitEvidenceTest
fatPointerRequiresQuorumVotingPowerTest
cannotObserveUngossipedPrecommitTest
observedPrecommitQuorumRequiresGossipTest
cannotObserveFatPointerBeforeSignerPrecommitsObservedTest
observesFatPointerAfterSignerPrecommitsTest
acceptsCanonicalProposalSignatureTest
rejectsMismatchedPrecommitBytesTest
rejectsForgedSignatureTest
acceptsFatPointerSignatureQuorumTest
acceptsCanonicalHeightedProposalSignatureTest
rejectsCrossHeightPrecommitReplayTest
rejectsForgedHeightedPrevoteSignatureTest
acceptsHeightedFatPointerSignatureQuorumTest
```

## Current Limitations

The round model now has separate bookkeeping for proposal, prevote, precommit,
and fat-pointer evidence. The standalone evidence-gossip model adds explicit
gossip-to-observer acceptance ordering, including the rule that a fat pointer is
not accepted until its signer precommits have been observed locally. This is
paired with standalone message-authentication models that check canonical
payload bytes and validator signatures before messages are accepted. The
heighted authentication slice binds BFT height into proposal, vote, and
fat-pointer sign bytes, including cross-height replay rejection. This is still
abstract: it models the authentication boundary but does not yet call
production signature verification, serialization code, or gossip transport.
