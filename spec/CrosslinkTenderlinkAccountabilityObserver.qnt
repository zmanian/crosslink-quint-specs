module CrosslinkTenderlinkAccountabilityObserver {
  /*
   Tenderlink accountability observer bridge.

   The format model pins canonical evidence bytes and the transport model gates
   those bytes behind a Crosslink consensus-topic envelope. This bridge adds the
   observer side: a precommit-equivocation fact can only be recorded after the
   exact canonical evidence has already passed the transported-evidence gate.
   */

  import CrosslinkTenderlinkAccountabilityEvidenceTransportTest.* from
    "./CrosslinkTenderlinkAccountabilityEvidenceTransport"
  export CrosslinkTenderlinkAccountabilityEvidenceTransportTest.*

  type ObservedPrecommitEquivocation_t = {
    kind: AccountabilityEvidenceKind_t,
    height: int,
    round: int,
    validatorPubKey: str,
    firstValue: str,
    secondValue: str,
    evidenceHex: str,
  }

  var observedPrecommitEquivocations: Set[ObservedPrecommitEquivocation_t]
  var observerFiredAction: str

  pure def PacketObservedValue(packet: VotePacket_t): str =
    if (packet.noVotes == 1 and packet.yesVotes == 0) {
      NilValueId
    } else {
      packet.valueId
    }

  pure def EquivocationFromEvidence(
    evidence: AccountabilityEvidence_t,
  ): ObservedPrecommitEquivocation_t = {
    kind: evidence.kind,
    height: evidence.height,
    round: evidence.round,
    validatorPubKey: evidence.validatorPubKey,
    firstValue: PacketObservedValue(evidence.firstVote),
    secondValue: PacketObservedValue(evidence.secondVote),
    evidenceHex: evidence.hex,
  }

  def ObservedEquivocationBackedByAcceptedTransport(
    equivocation: ObservedPrecommitEquivocation_t,
  ): bool =
    acceptedTransportedAccountabilityEvidence.exists(evidence =>
      AccountabilityEvidenceCanonical(evidence) and
      equivocation == EquivocationFromEvidence(evidence)
    )

  action ObserverInit = all {
    TransportInit,
    observedPrecommitEquivocations' = Set(),
    observerFiredAction' = "ObserverInit",
  }

  action KeepTransportState = all {
    acceptedAccountabilityEvidence' = acceptedAccountabilityEvidence,
    firedAction' = firedAction,
    transportedAccountabilityEvidence' = transportedAccountabilityEvidence,
    acceptedTransportedAccountabilityEvidence' =
      acceptedTransportedAccountabilityEvidence,
    transportFiredAction' = transportFiredAction,
  }

  action KeepObserverState = all {
    observedPrecommitEquivocations' = observedPrecommitEquivocations,
    observerFiredAction' = observerFiredAction,
  }

  action ReceiveTransportForObserver(
    env: AccountabilityEvidenceTransportEnvelope_t,
    evidence: AccountabilityEvidence_t,
  ): bool =
    all {
      ReceiveAccountabilityEvidenceTransport(env, evidence),
      KeepObserverState,
    }

  action AcceptTransportedEvidenceForObserver(
    evidence: AccountabilityEvidence_t,
  ): bool =
    all {
      AcceptTransportedAccountabilityEvidence(evidence),
      KeepObserverState,
    }

  action ObservePrecommitEquivocation(
    evidence: AccountabilityEvidence_t,
  ): bool =
    all {
      AccountabilityEvidenceCanonical(evidence),
      acceptedTransportedAccountabilityEvidence.contains(evidence),
      KeepTransportState,
      observedPrecommitEquivocations' =
        observedPrecommitEquivocations.union(Set(
          EquivocationFromEvidence(evidence),
        )),
      observerFiredAction' = "ObservePrecommitEquivocation",
    }

  action TransportStepWithObserverState: bool =
    all {
      TransportNext,
      observedPrecommitEquivocations' = observedPrecommitEquivocations,
      observerFiredAction' = observerFiredAction,
    }

  action ObserverStutter: bool =
    all {
      KeepTransportState,
      observedPrecommitEquivocations' = observedPrecommitEquivocations,
      observerFiredAction' = observerFiredAction,
    }

  def ObservedPrecommitEquivocationsBackedByTransport: bool =
    observedPrecommitEquivocations.forall(equivocation =>
      ObservedEquivocationBackedByAcceptedTransport(equivocation)
    )

  val ObserverSafety =
    TransportSafety and
    ObservedPrecommitEquivocationsBackedByTransport
}

module CrosslinkTenderlinkAccountabilityObserverTest {
  import CrosslinkTenderlinkAccountabilityObserver.* from
    "./CrosslinkTenderlinkAccountabilityObserver"
  export CrosslinkTenderlinkAccountabilityObserver.*

  pure val nilValueEquivocation =
    EquivocationFromEvidence(nilValuePrecommitEvidence)

  pure val valueValueEquivocation =
    EquivocationFromEvidence(valueValuePrecommitEvidence)

  pure val TestObserverEvidence = Set(
    nilValuePrecommitEvidence,
    valueValuePrecommitEvidence,
    prevoteEvidence,
  )

  action ObserverNext: bool =
    any {
      TransportStepWithObserverState,
      nondet evidence = oneOf(TestObserverEvidence)
      ObservePrecommitEquivocation(evidence),
      ObserverStutter,
    }

  action unchangedObserver = all {
    acceptedAccountabilityEvidence' = acceptedAccountabilityEvidence,
    firedAction' = firedAction,
    transportedAccountabilityEvidence' = transportedAccountabilityEvidence,
    acceptedTransportedAccountabilityEvidence' =
      acceptedTransportedAccountabilityEvidence,
    transportFiredAction' = transportFiredAction,
    observedPrecommitEquivocations' = observedPrecommitEquivocations,
    observerFiredAction' = observerFiredAction,
  }

  run cannotObserveWithoutTransportedEvidenceTest = {
    ObserverInit
      .then(ObservePrecommitEquivocation(nilValuePrecommitEvidence))
      .fail()
  }

  run cannotObserveAfterReceiveBeforeAcceptTest = {
    ObserverInit
      .then(ReceiveTransportForObserver(
        accountabilityEvidenceEnvelope,
        nilValuePrecommitEvidence,
      ))
      .then(ObservePrecommitEquivocation(nilValuePrecommitEvidence))
      .fail()
  }

  run observesNilValueEquivocationAfterTransportAcceptanceTest = {
    ObserverInit
      .then(ReceiveTransportForObserver(
        accountabilityEvidenceEnvelope,
        nilValuePrecommitEvidence,
      ))
      .then(AcceptTransportedEvidenceForObserver(nilValuePrecommitEvidence))
      .then(ObservePrecommitEquivocation(nilValuePrecommitEvidence))
      .then(all {
        assert(observedPrecommitEquivocations.contains(nilValueEquivocation)),
        assert(nilValueEquivocation.firstValue == NilValueId),
        assert(nilValueEquivocation.secondValue == TestValueIdHex),
        assert(ObserverSafety),
        unchangedObserver,
      })
  }

  run observesValueValueEquivocationAfterTransportAcceptanceTest = {
    ObserverInit
      .then(ReceiveTransportForObserver(
        valueValueEvidenceEnvelope,
        valueValuePrecommitEvidence,
      ))
      .then(AcceptTransportedEvidenceForObserver(valueValuePrecommitEvidence))
      .then(ObservePrecommitEquivocation(valueValuePrecommitEvidence))
      .then(all {
        assert(observedPrecommitEquivocations.contains(valueValueEquivocation)),
        assert(valueValueEquivocation.firstValue == TestValueIdHex),
        assert(valueValueEquivocation.secondValue == TestValue2IdHex),
        assert(ObserverSafety),
        unchangedObserver,
      })
  }

  run rejectsNonCanonicalObservedEvidenceTest = {
    ObserverInit
      .then(ObservePrecommitEquivocation(prevoteEvidence))
      .fail()
  }

  run observerSafetyTest = {
    ObserverInit.then(all {
      assert(ObserverSafety),
      unchangedObserver,
    })
  }
}

module CrosslinkTenderlinkAccountabilityObserverModel {
  import CrosslinkTenderlinkAccountabilityObserverTest.* from
    "./CrosslinkTenderlinkAccountabilityObserver"
  export CrosslinkTenderlinkAccountabilityObserverTest.*
}
