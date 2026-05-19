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
CrosslinkMixedWaitProgressContractModel / EventuallyNilCertUnlocksMixedWait
CrosslinkHeightedProgressProjectionContractModel / EventuallyHeightedProgressFinalizesTwoHeights
CrosslinkHeightedAuthenticatedProgressProjectionContractModel / EventuallyHeightedAuthenticatedProgressFinalizesTwoHeights
CrosslinkRotatingAuthenticatedProgressProjectionContractModel / EventuallyRotatingAuthenticatedProgressFinalizesTwoHeights
precommitTimeoutDoesNotUnlockWithoutNilCertificateTest
precommitTimeoutDoesNotClearHeightedLockTest
```

The heighted progress projection adds the multi-height boundary: a nil
certificate can clear the active height's same-round recovery state without
touching the next BFT height before the current height has decided.

The authenticated progress projection adds the finality/evidence boundary:
that same recovery path cannot finalize either BFT height until observer-local
authenticated precommit evidence and matching fat-pointer signatures exist for
the finalized height and round.

The rotating authenticated projection adds the validator-set boundary: height 1
evidence must be signed by height-1 validators, height 2 evidence must be
signed by the rotated height-2 validators, and removed or newly added validators
cannot be replayed into the wrong height's observer evidence.

## Conflicting Commit Accountability

If two conflicting values are both committed, accountability should expose at
least one of:

- same-round correct-validator equivocation,
- concrete value/value precommit equivocation for the same signer, height, and
  round,
- nil/value equivocation for a bogus nil unlock, or
- a correct validator switching values without a valid nil certificate for the
  abandoned round.

The model names these predicates:

```text
ObservedPrecommitQuorum
ObservedNilPrecommitCert
CorrectSignerValueValueEquivocationEvidence
CorrectSignerNilValueEquivocationEvidence
CorrectSameRoundEquivocationEvidence
CorrectNilValueEquivocationEvidence
CorrectValueSwitchWithoutUnlock
ConflictHasAccountabilityEvidence
ConflictingCommitsAccountable
```

The abstract model intentionally separates signer-level slashing facts from
quorum/certificate context. A value/value precommit equivocation from one
correct signer is enough to witness same-round equivocation. A nil/value
precommit equivocation from one correct signer is recorded as signer evidence,
but `CorrectNilValueEquivocationEvidence` still requires both the nil
certificate and the conflicting value quorum for the round. This keeps the
Tendermint value-lock rule from treating a lone nil precommit as unlock
evidence.

`CrosslinkTenderlinkUnlockAccountabilityBoundary.qnt` records the matching
negative boundary for invalid-unlock evidence. A correct signer with a value
precommit in round `r` and a different value precommit in a later round is an
abstract bad-unlock signal only while there is no observed nil-precommit
certificate for `r`. That absence is not standalone slashing evidence: a valid
nil certificate can be learned later and justify the switch. Mixed precommits
still do not cancel the signal, because only nil itself having quorum is unlock
evidence.

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
signerValueValueEquivocationEvidenceWitnessTest
signerNilValueEvidenceAloneDoesNotImplyNilValueAccountabilityTest
nilValueSignerEvidenceWithQuorumContextTest
cannotApplyBeforeObserverRecordsEvidenceTest
nilValueObserverEvidenceBridgesToSignerPredicateTest
valueValueObserverEvidenceBridgesToSameRoundPredicateTest
nilValueObserverBridgeNeedsQuorumContextForAggregateTest
valueSwitchWithoutNilCertIsAbstractSignalTest
nilCertContextCancelsBadUnlockSignalTest
mixedPrecommitDoesNotCancelBadUnlockSignalTest
absenceBasedStandaloneSwitchAcceptanceIsUnsafeTest
safeBoundaryNeverAcceptsStandaloneSwitchTest
validFatPointerEvidenceWitnessTest
fatPointerRequiresSignerPrecommitEvidenceTest
fatPointerRequiresQuorumVotingPowerTest
cannotObserveUngossipedPrecommitTest
observedPrecommitQuorumRequiresGossipTest
cannotObserveFatPointerBeforeSignerPrecommitsObservedTest
observesFatPointerAfterSignerPrecommitsTest
cannotObserveUngossipedHeightedPrecommitTest
observedHeightedPrecommitQuorumRequiresGossipTest
rejectsCrossHeightFatPointerSignerEvidenceTest
cannotObserveHeightedFatPointerBeforeSignerPrecommitsObservedTest
observesHeightedFatPointerAfterSignerPrecommitsTest
acceptsCanonicalProposalSignatureTest
rejectsMismatchedPrecommitBytesTest
rejectsForgedSignatureTest
acceptsFatPointerSignatureQuorumTest
acceptsCanonicalHeightedProposalSignatureTest
rejectsCrossHeightPrecommitReplayTest
rejectsForgedHeightedPrevoteSignatureTest
acceptsHeightedFatPointerSignatureQuorumTest
acceptsCurrentRosterFatPointerTest
acceptsExactWireEnvelopeTest
wireOffsetsMatchImplementationTest
rejectsTrailingByteWireEnvelopeTest
rejectsTruncatedWireEnvelopeTest
validProducerRoundDataDerivesFatPointerTest
producerRoundDataRejectsMissingSignatureTest
producerRoundDataRejectsNilPrecommitSignerTest
producerRoundDataRejectsWrongHeightFatPointerTest
currentTryFromOnlyChecksHeaderCountGapTest
currentTryFromAcceptsWrongHeaderVersionGapTest
deserializationBypassesTryFromSigmaGapTest
currentTryFromAcceptsBadVersionGapTest
currentTryFromAcceptsBadHeaderOrderGapTest
currentTryFromAcceptsBadPowGapTest
currentTryFromStillRejectsWrongHeaderCountTest
bftBlockPrefixOffsetsForNullPreviousFatPointerTest
bftBlockPrefixOffsetsForOnePreviousSignatureTest
bftBlockWireLengthVectorsTest
deserializationBypassesTryFromSigmaGapRecordedTest
prototypeTryFromBytesCountSliceGapRecordedTest
rejectsDuplicatePubKeyQuorumInflationTest
rejectsRemovedValidatorAtNewHeightTest
rejectsCrossHeightSignatureReplayTest
rejectsLowPowerFatPointerTest
observesProductionFatPointerAfterGossipedPrecommitsTest
cannotObserveFatPointerBeforeGossipedPrecommitsTest
observesProductionFatPointerWireAfterGossipedPrecommitsTest
cannotObserveFatPointerWireBeforeGossipedPrecommitsTest
trailingByteFatPointerWireRejectedDespiteGossipTest
missingSignerPrecommitRejectsFatPointerObservationTest
removedValidatorCannotGossipNextHeightPrecommitTest
duplicateSignerFatPointerRejectedDespiteGossipTest
oldHeightFatPointerUsesOldAuthorizedSetTest
generatedFixtureWireConstantsAreCoherentTest
generatedFixtureWireObservedAfterGossipTest
generatedFixtureWireRejectedBeforeGossipTest
acceptsNilValuePrecommitEvidenceTest
acceptsValueValuePrecommitEvidenceTest
rejectsPrevoteEvidenceTest
rejectsRoundMismatchEvidenceTest
rejectsHeightMismatchEvidenceTest
rejectsWrongLengthEvidenceTest
rejectsSameValueEvidenceTest
rejectsWrongSignerEvidenceTest
rejectsWrongHexEvidenceTest
accountabilityEvidenceTransportEnvelopeAcceptedTest
transportedAccountabilityEvidenceAcceptedTest
missingTransportRejectedTest
wrongTopicTransportRejectedTest
wrongKindTransportRejectedTest
wrongLengthTransportRejectedTest
wrongHeightTransportRejectedTest
wrongSignerTransportRejectedTest
wrongBytesTransportRejectedTest
nonCanonicalEvidenceTransportRejectedTest
valueValueAccountabilityEvidenceTransportEnvelopeAcceptedTest
valueValueTransportedAccountabilityEvidenceAcceptedTest
cannotObserveWithoutTransportedEvidenceTest
cannotObserveAfterReceiveBeforeAcceptTest
observesNilValueEquivocationAfterTransportAcceptanceTest
observesValueValueEquivocationAfterTransportAcceptanceTest
rejectsNonCanonicalObservedEvidenceTest
```

## Current Limitations

The round model now has separate bookkeeping for proposal, prevote, precommit,
and fat-pointer evidence. The standalone evidence-gossip model adds explicit
gossip-to-observer acceptance ordering, including the rule that a fat pointer is
not accepted until its signer precommits have been observed locally. This is
paired with standalone message-authentication models that check canonical
payload bytes and validator signatures before messages are accepted. The
heighted authentication slice binds BFT height into proposal, vote, and
fat-pointer sign bytes, including cross-height replay rejection. The
dynamic-sigma authenticated-evidence and authenticated-finality slices add the
corresponding Crosslink-specific boundary: value precommits, fat pointers, and
finality cursor advancement must be backed by authenticated evidence for the
active height's `head - sigma(h)` candidate, including telemetry-raised sigma
at later heights. The
fat-pointer-format model now also captures the production-shaped signer vector,
including its counted wire layout, exact wire-envelope length,
byte offsets, duplicate-pubkey rejection, canonical per-signer vote bytes, and
height-scoped authorization. It also checks that a fat pointer is derivable
from producer round data only when the included precommit signatures match the
proposal value at the same height. The production-vector model pins exact
0-4 signature wire lengths, the streaming serializer/deserializer count slice,
and the current prototype `try_from_bytes` reversed-slice gap. The production
fat-pointer authenticated-evidence model then requires each active signer
entry to have a matching gossiped precommit and each observed wire to have the
exact counted-envelope length before observer acceptance. The fixture-gossip
transport model adds the first transport boundary for the checked-in generated
fixture: the matching precommit and fat-pointer wire must arrive through
canonical Crosslink-topic envelopes, wrong topic/sign-bytes/kind/length
envelopes are rejected, and a fixture precommit cannot enter gossip unless its
matching transport envelope was seen. The production-finality projection then
uses a production-shaped BFT-block proposal envelope plus that fixture
transport bridge at the finality boundary: candidate observation cannot happen
before proposal transport, proposal transport must match the generated
serialized BFT-block version, serialized BFT height, finalization-candidate
field, and header-prefix offsets, and finality cannot advance from the
generated fixture unless both the transported checked-in BFT-block shape and
the transported authenticated fat-pointer wire have been observed.
`CrosslinkTenderlinkAccountabilityEvidenceFormat.qnt`
adds concrete slashing-evidence envelopes for nil/value precommit equivocation
under the nil-precommit rule and ordinary value/value precommit equivocation by
one validator at the same height and round, encoded as typed header fields plus
two canonical `PacketVotes` payloads. It rejects prevote evidence,
wrong-height/round evidence, wrong byte lengths, same-value packets,
wrong-signer claims, and non-canonical envelope bytes. This is still partial:
the model now covers the authentication boundary, wire shape,
gossip-before-observe rule, fixture-level transport gate, production-fixture
proposal/finality gate with generated serialized prefix-field checks,
fixture-manifest Ed25519 verification, and nil/value plus value/value
precommit equivocation evidence envelopes, but does not yet call a full
production gossip transport implementation or cover every future
slashing evidence encoding. The
`CrosslinkTenderlinkAccountabilityEvidenceTransport.qnt` bridge narrows that
gap for these envelopes by requiring a Crosslink consensus-topic transport
envelope with exact evidence bytes and matching height, round, and signer
metadata before transported accountability evidence can be accepted.
`CrosslinkTenderlinkAccountabilityObserver.qnt` then narrows the observer side:
nil/value and value/value precommit-equivocation facts are recorded only after
the exact transported evidence has been accepted, and receive-without-accept
does not create observer-local accountability evidence.
`CrosslinkTenderlinkAccountabilityObserverBridge.qnt` connects those concrete
observer facts back into the abstract Crosslink round-recovery model by mapping
the Tenderlink validator pubkey to the abstract validator id and the concrete
nil value id to `NilSnapshot`. Its witnesses check that value/value evidence
reaches `CorrectSameRoundEquivocationEvidence`, while nil/value evidence stays
signer-level until a separate nil certificate and value quorum are present.
`CrosslinkTenderlinkAccountabilityObserverBridgeSafety.qnt` keeps the same
obligations in a direct verifier-friendly state machine for Apalache.
`CrosslinkTenderlinkUnlockAccountabilityBoundary.qnt` adds the parallel
invalid-unlock boundary: absence-based value-switch detection is useful for the
abstract accountability proof, but should not be accepted as production
slashing evidence unless a future evidence format carries an explicit,
sound proof of invalid unlock.
