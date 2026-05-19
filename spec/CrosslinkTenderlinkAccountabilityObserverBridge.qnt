module CrosslinkTenderlinkAccountabilityObserverBridge {
  /*
   Bridge concrete Tenderlink accountability observations into the abstract
   Crosslink round-recovery accountability predicates.

   The observer model records canonical, transported nil/value and value/value
   precommit-equivocation facts using production-shaped Tenderlink evidence.
   This bridge maps those facts into the abstract `evidencePrecommit` observer
   state used by CrosslinkResampling, while preserving the distinction between
   signer-level slashing evidence and quorum/certificate accountability context.
   */

  import CrosslinkTenderlinkAccountabilityObserver as Observer from
    "./CrosslinkTenderlinkAccountabilityObserver"

  import CrosslinkResampling(
    Corr = Set(Observer::TestPubKeyHex, Observer::TestPubKey2Hex, "bridge-p3"),
    Faulty = Set("bridge-p4"),
    N = 4,
    T = 1,
    VotingPower = Map(
      Observer::TestPubKeyHex -> 1,
      Observer::TestPubKey2Hex -> 1,
      "bridge-p3" -> 1,
      "bridge-p4" -> 1,
    ),
    TotalVotingPower = 4,
    FaultyVotingPowerBound = 1,
    QuorumVotingPower = 3,
    MaxRound = 2,
    Proposer = Map(
      0 -> Observer::TestPubKeyHex,
      1 -> Observer::TestPubKey2Hex,
      2 -> "bridge-p3",
    ),
    Stream = Map(
      0 -> Observer::TestValueIdHex,
      1 -> Observer::TestValue2IdHex,
      2 -> Observer::TestValue2IdHex,
    ),
    Snapshots = Set(Observer::TestValueIdHex, Observer::TestValue2IdHex),
    StructurallyValid = Map(
      Observer::TestValueIdHex -> true,
      Observer::TestValue2IdHex -> true,
    ),
    PowChainValid = Map(
      Observer::TestValueIdHex -> true,
      Observer::TestValue2IdHex -> true,
    ),
    FinalityCandidateValid = Map(
      Observer::TestValueIdHex -> true,
      Observer::TestValue2IdHex -> true,
    ),
    ResampleOnNilPrecommit = true,
  ).* from "./CrosslinkResampling"

  type ObserverVotePacketEntry_t = {
    rosterIndex: int,
    pubKey: str,
    valueId: str,
    signBytes: str,
    voteSignature: str,
  }

  type ObserverVotePacket_t = {
    packetType: int,
    byteLen: int,
    noVotes: int,
    yesVotes: int,
    round: int,
    height: int,
    valueId: str,
    entries: int -> ObserverVotePacketEntry_t,
    hex: str,
  }

  type ObserverEvidence_t = {
    kind: str,
    byteLen: int,
    height: int,
    round: int,
    validatorPubKey: str,
    firstPacketType: int,
    secondPacketType: int,
    firstPacketByteLen: int,
    secondPacketByteLen: int,
    firstVote: ObserverVotePacket_t,
    secondVote: ObserverVotePacket_t,
    hex: str,
  }

  type ObserverEnvelope_t = {
    topic: str,
    kind: str,
    height: int,
    round: int,
    validatorPubKey: str,
    evidenceByteLen: int,
    evidenceHex: str,
  }

  type ObserverEquivocation_t = {
    kind: str,
    height: int,
    round: int,
    validatorPubKey: str,
    firstValue: str,
    secondValue: str,
    evidenceHex: str,
  }

  var appliedObserverEquivocations: Set[ObserverEquivocation_t]
  var bridgeFiredAction: str

  pure val BridgeHeight = 1
  pure val BridgeSigner = Observer::TestPubKeyHex
  pure val BridgeSecondCorrect = Observer::TestPubKey2Hex
  pure val BridgeThirdCorrect = "bridge-p3"
  pure val BridgeFaulty = "bridge-p4"
  pure val BridgeValue = Observer::TestValueIdHex
  pure val BridgeValue2 = Observer::TestValue2IdHex
  pure val BridgeNilValueEvidence = Observer::nilValuePrecommitEvidence
  pure val BridgeValueValueEvidence = Observer::valueValuePrecommitEvidence
  pure val BridgeNilValueEnvelope = Observer::accountabilityEvidenceEnvelope
  pure val BridgeValueValueEnvelope = Observer::valueValueEvidenceEnvelope
  pure val BridgeNilValueEquivocation =
    Observer::EquivocationFromEvidence(BridgeNilValueEvidence)
  pure val BridgeValueValueEquivocation =
    Observer::EquivocationFromEvidence(BridgeValueValueEvidence)
  pure val BridgeObserverEvidence = Set(
    BridgeNilValueEvidence,
    BridgeValueValueEvidence,
    Observer::prevoteEvidence,
  )

  pure def AbstractObservedValue(value: str): Snapshot_t =
    if (value == Observer::NilValueId) {
      NilSnapshot
    } else {
      value
    }

  pure def ConcreteValueMapsToAbstract(value: str): bool =
    value == Observer::NilValueId or Snapshots.contains(value)

  pure def ConcreteEquivocationMapsToAbstract(equivocation: ObserverEquivocation_t): bool =
    equivocation.height == BridgeHeight and
    equivocation.validatorPubKey == BridgeSigner and
    equivocation.round.in(Rounds) and
    ConcreteValueMapsToAbstract(equivocation.firstValue) and
    ConcreteValueMapsToAbstract(equivocation.secondValue) and
    AbstractObservedValue(equivocation.firstValue) !=
      AbstractObservedValue(equivocation.secondValue)

  def AbstractSignerEvidenceMatches(equivocation: ObserverEquivocation_t): bool =
    ConcreteEquivocationMapsToAbstract(equivocation) and
    if (equivocation.firstValue == Observer::NilValueId) {
      CorrectSignerNilValueEquivocationEvidence(
        equivocation.validatorPubKey,
        equivocation.round,
        AbstractObservedValue(equivocation.secondValue),
      )
    } else if (equivocation.secondValue == Observer::NilValueId) {
      CorrectSignerNilValueEquivocationEvidence(
        equivocation.validatorPubKey,
        equivocation.round,
        AbstractObservedValue(equivocation.firstValue),
      )
    } else {
      CorrectSignerValueValueEquivocationEvidence(
        equivocation.validatorPubKey,
        equivocation.round,
        AbstractObservedValue(equivocation.firstValue),
        AbstractObservedValue(equivocation.secondValue),
      )
    }

  def BridgeObservedPrecommitQuorum(r: Round_t, v: Snapshot_t): bool =
    ObservedPrecommitQuorum(r, v)

  def BridgeObservedNilPrecommitCert(r: Round_t): bool =
    ObservedNilPrecommitCert(r)

  def BridgeCorrectSignerNilValueEquivocationEvidence(
    p: Proc_t,
    r: Round_t,
    v: Snapshot_t,
  ): bool =
    CorrectSignerNilValueEquivocationEvidence(p, r, v)

  def BridgeCorrectSignerValueValueEquivocationEvidence(
    p: Proc_t,
    r: Round_t,
    v1: Snapshot_t,
    v2: Snapshot_t,
  ): bool =
    CorrectSignerValueValueEquivocationEvidence(p, r, v1, v2)

  def BridgeCorrectSameRoundEquivocationEvidence(
    r: Round_t,
    v1: Snapshot_t,
    v2: Snapshot_t,
  ): bool =
    CorrectSameRoundEquivocationEvidence(r, v1, v2)

  def BridgeCorrectNilValueEquivocationEvidence(
    r: Round_t,
    v: Snapshot_t,
  ): bool =
    CorrectNilValueEquivocationEvidence(r, v)

  val AppliedObserverEquivocationsBackedByAbstractEvidence =
    appliedObserverEquivocations.forall(equivocation =>
      Observer::observedPrecommitEquivocations.contains(equivocation) and
      AbstractSignerEvidenceMatches(equivocation)
    )

  val BridgeSafety =
    Observer::ObserverSafety and
    Safety and
    AppliedObserverEquivocationsBackedByAbstractEvidence

  action KeepAbstractState = all {
    round' = round,
    step' = step,
    decision' = decision,
    lockedValue' = lockedValue,
    lockedRound' = lockedRound,
    validValue' = validValue,
    validRound' = validRound,
    cachedProposal' = cachedProposal,
    cachedProposalRound' = cachedProposalRound,
    msgsPropose' = msgsPropose,
    msgsPrevote' = msgsPrevote,
    msgsPrecommit' = msgsPrecommit,
    evidencePropose' = evidencePropose,
    evidencePrevote' = evidencePrevote,
    evidencePrecommit' = evidencePrecommit,
    evidenceFatPointer' = evidenceFatPointer,
    seenPropose' = seenPropose,
    seenPrevote' = seenPrevote,
    seenPrecommit' = seenPrecommit,
    firedAction' = firedAction,
  }

  action KeepAbstractExceptPrecommitEvidence = all {
    round' = round,
    step' = step,
    decision' = decision,
    lockedValue' = lockedValue,
    lockedRound' = lockedRound,
    validValue' = validValue,
    validRound' = validRound,
    cachedProposal' = cachedProposal,
    cachedProposalRound' = cachedProposalRound,
    msgsPropose' = msgsPropose,
    msgsPrevote' = msgsPrevote,
    msgsPrecommit' = msgsPrecommit,
    evidencePropose' = evidencePropose,
    evidencePrevote' = evidencePrevote,
    evidenceFatPointer' = evidenceFatPointer,
    seenPropose' = seenPropose,
    seenPrevote' = seenPrevote,
    seenPrecommit' = seenPrecommit,
  }

  action KeepBridgeApplied = all {
    appliedObserverEquivocations' = appliedObserverEquivocations,
  }

  action BridgeInit = all {
    Init,
    Observer::ObserverInit,
    appliedObserverEquivocations' = Set(),
    bridgeFiredAction' = "BridgeInit",
  }

  action ReceiveObserverEvidenceForBridge(
    env: ObserverEnvelope_t,
    evidence: ObserverEvidence_t,
  ): bool =
    all {
      Observer::ReceiveTransportForObserver(env, evidence),
      KeepAbstractState,
      KeepBridgeApplied,
      bridgeFiredAction' = "ReceiveObserverEvidenceForBridge",
    }

  action AcceptObserverEvidenceForBridge(evidence: ObserverEvidence_t): bool =
    all {
      Observer::AcceptTransportedEvidenceForObserver(evidence),
      KeepAbstractState,
      KeepBridgeApplied,
      bridgeFiredAction' = "AcceptObserverEvidenceForBridge",
    }

  action ObserveObserverEquivocationForBridge(evidence: ObserverEvidence_t): bool =
    all {
      Observer::ObservePrecommitEquivocation(evidence),
      KeepAbstractState,
      KeepBridgeApplied,
      bridgeFiredAction' = "ObserveObserverEquivocationForBridge",
    }

  action ApplyObservedEquivocationToAbstractEvidence(
    equivocation: ObserverEquivocation_t,
  ): bool =
    all {
      Observer::observedPrecommitEquivocations.contains(equivocation),
      ConcreteEquivocationMapsToAbstract(equivocation),
      Observer::ObserverStutter,
      KeepAbstractExceptPrecommitEvidence,
      evidencePrecommit' =
        evidencePrecommit.setBy(equivocation.round, old =>
          old
            .union(Set({
              src: equivocation.validatorPubKey,
              round: equivocation.round,
              id: AbstractObservedValue(equivocation.firstValue),
            }))
            .union(Set({
              src: equivocation.validatorPubKey,
              round: equivocation.round,
              id: AbstractObservedValue(equivocation.secondValue),
            }))
        ),
      firedAction' = "ApplyObservedEquivocationToAbstractEvidence",
      appliedObserverEquivocations' =
        appliedObserverEquivocations.union(Set(equivocation)),
      bridgeFiredAction' = "ApplyObservedEquivocationToAbstractEvidence",
    }

  action AddCorrectNilPrecommitEvidenceForBridge(p: Proc_t, r: Round_t): bool =
    all {
      SeedCorrectNilPrecommitEvidence(p, r),
      Observer::ObserverStutter,
      KeepBridgeApplied,
      bridgeFiredAction' = "AddCorrectNilPrecommitEvidenceForBridge",
    }

  action AddFaultyNilPrecommitEvidenceForBridge(p: Proc_t, r: Round_t): bool =
    all {
      SeedFaultyNilPrecommitEvidence(p, r),
      Observer::ObserverStutter,
      KeepBridgeApplied,
      bridgeFiredAction' = "AddFaultyNilPrecommitEvidenceForBridge",
    }

  action AddCorrectPrecommitEvidenceForBridge(
    p: Proc_t,
    r: Round_t,
    v: Snapshot_t,
  ): bool =
    all {
      SeedCorrectPrecommitEvidence(p, r, v),
      Observer::ObserverStutter,
      KeepBridgeApplied,
      bridgeFiredAction' = "AddCorrectPrecommitEvidenceForBridge",
    }

  action AddFaultyPrecommitEvidenceForBridge(
    p: Proc_t,
    r: Round_t,
    v: Snapshot_t,
  ): bool =
    all {
      SeedFaultyPrecommitEvidence(p, r, v),
      Observer::ObserverStutter,
      KeepBridgeApplied,
      bridgeFiredAction' = "AddFaultyPrecommitEvidenceForBridge",
    }

  action ObserverStepForBridge: bool =
    all {
      any {
        Observer::TransportStepWithObserverState,
        nondet evidence = oneOf(BridgeObserverEvidence)
        Observer::ObservePrecommitEquivocation(evidence),
        Observer::ObserverStutter,
      },
      KeepAbstractState,
      KeepBridgeApplied,
      bridgeFiredAction' = "ObserverStepForBridge",
    }

  action BridgeStutter: bool =
    all {
      Observer::ObserverStutter,
      KeepAbstractState,
      KeepBridgeApplied,
      bridgeFiredAction' = bridgeFiredAction,
    }

  action BridgeNext: bool =
    any {
      ObserverStepForBridge,
      ApplyObservedEquivocationToAbstractEvidence(BridgeNilValueEquivocation),
      ApplyObservedEquivocationToAbstractEvidence(BridgeValueValueEquivocation),
      BridgeStutter,
    }
}

module CrosslinkTenderlinkAccountabilityObserverBridgeTest {
  import CrosslinkTenderlinkAccountabilityObserverBridge.* from
    "./CrosslinkTenderlinkAccountabilityObserverBridge"
  export CrosslinkTenderlinkAccountabilityObserverBridge.*

  run cannotApplyBeforeObserverRecordsEvidenceTest = {
    BridgeInit
      .then(ApplyObservedEquivocationToAbstractEvidence(BridgeNilValueEquivocation))
      .fail()
  }

  run nilValueObserverEvidenceBridgesToSignerPredicateTest = {
    BridgeInit
      .then(ReceiveObserverEvidenceForBridge(
        BridgeNilValueEnvelope,
        BridgeNilValueEvidence,
      ))
      .then(AcceptObserverEvidenceForBridge(BridgeNilValueEvidence))
      .then(ObserveObserverEquivocationForBridge(BridgeNilValueEvidence))
      .then(ApplyObservedEquivocationToAbstractEvidence(BridgeNilValueEquivocation))
      .then(all {
        assert(appliedObserverEquivocations.contains(BridgeNilValueEquivocation)),
        assert(BridgeCorrectSignerNilValueEquivocationEvidence(
          BridgeSigner,
          0,
          BridgeValue,
        )),
        assert(not(BridgeCorrectNilValueEquivocationEvidence(0, BridgeValue))),
        assert(BridgeSafety),
        BridgeStutter,
      })
  }

  run valueValueObserverEvidenceBridgesToSameRoundPredicateTest = {
    BridgeInit
      .then(ReceiveObserverEvidenceForBridge(
        BridgeValueValueEnvelope,
        BridgeValueValueEvidence,
      ))
      .then(AcceptObserverEvidenceForBridge(BridgeValueValueEvidence))
      .then(ObserveObserverEquivocationForBridge(BridgeValueValueEvidence))
      .then(ApplyObservedEquivocationToAbstractEvidence(BridgeValueValueEquivocation))
      .then(all {
        assert(appliedObserverEquivocations.contains(BridgeValueValueEquivocation)),
        assert(BridgeCorrectSignerValueValueEquivocationEvidence(
          BridgeSigner,
          0,
          BridgeValue,
          BridgeValue2,
        )),
        assert(BridgeCorrectSameRoundEquivocationEvidence(
          0,
          BridgeValue,
          BridgeValue2,
        )),
        assert(BridgeSafety),
        BridgeStutter,
      })
  }

  run nilValueObserverBridgeNeedsQuorumContextForAggregateTest = {
    BridgeInit
      .then(ReceiveObserverEvidenceForBridge(
        BridgeNilValueEnvelope,
        BridgeNilValueEvidence,
      ))
      .then(AcceptObserverEvidenceForBridge(BridgeNilValueEvidence))
      .then(ObserveObserverEquivocationForBridge(BridgeNilValueEvidence))
      .then(ApplyObservedEquivocationToAbstractEvidence(BridgeNilValueEquivocation))
      .then(AddCorrectNilPrecommitEvidenceForBridge(BridgeSecondCorrect, 0))
      .then(AddFaultyNilPrecommitEvidenceForBridge(BridgeFaulty, 0))
      .then(AddCorrectPrecommitEvidenceForBridge(BridgeSecondCorrect, 0, BridgeValue))
      .then(AddFaultyPrecommitEvidenceForBridge(BridgeFaulty, 0, BridgeValue))
      .then(all {
        assert(BridgeObservedNilPrecommitCert(0)),
        assert(BridgeObservedPrecommitQuorum(0, BridgeValue)),
        assert(BridgeCorrectSignerNilValueEquivocationEvidence(
          BridgeSigner,
          0,
          BridgeValue,
        )),
        assert(BridgeCorrectNilValueEquivocationEvidence(0, BridgeValue)),
        assert(BridgeSafety),
        BridgeStutter,
      })
  }

  run bridgeSafetyTest = {
    BridgeInit.then(all {
      assert(BridgeSafety),
      BridgeStutter,
    })
  }
}

module CrosslinkTenderlinkAccountabilityObserverBridgeModel {
  import CrosslinkTenderlinkAccountabilityObserverBridgeTest.* from
    "./CrosslinkTenderlinkAccountabilityObserverBridge"
  export CrosslinkTenderlinkAccountabilityObserverBridgeTest.*
}
