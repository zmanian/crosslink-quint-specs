module CrosslinkTenderlinkAccountabilityObserverBridgeSafety {
  /*
   Verifier-friendly safety slice for
   CrosslinkTenderlinkAccountabilityObserverBridge.qnt.

   The executable bridge composes alias imports from the concrete Tenderlink
   observer and abstract Crosslink resampling model. As with the Malachite
   router, that shape is useful for tests but too alias-heavy for the Apalache
   flattener. This direct slice keeps the same safety question small:
   transported observer equivocation facts may only become abstract signer
   evidence, and nil/value signer evidence becomes aggregate nil-unlock
   accountability only when nil-certificate and value-quorum context exists.
   */

  type Proc_t = str
  type Snapshot_t = str
  type Round_t = int
  type Vote_t = {
    src: Proc_t,
    round: Round_t,
    id: Snapshot_t,
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

  pure val BridgeHeight = 1
  pure val BridgeRound = 0
  pure val BridgeSigner =
    "0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20"
  pure val BridgeSecondCorrect =
    "2122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f40"
  pure val BridgeThirdCorrect = "bridge-p3"
  pure val BridgeFaulty = "bridge-p4"
  pure val NilSnapshot = "None"
  pure val ConcreteNilValue =
    "0000000000000000000000000000000000000000000000000000000000000000"
  pure val BridgeValue =
    "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  pure val BridgeValue2 =
    "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
  pure val NilValueKind = "nil-value-precommit-equivocation"
  pure val ValueValueKind = "value-value-precommit-equivocation"

  pure val Corr = Set(BridgeSigner, BridgeSecondCorrect, BridgeThirdCorrect)
  pure val Faulty = Set(BridgeFaulty)
  pure val Rounds = Set(BridgeRound)
  pure val Snapshots = Set(BridgeValue, BridgeValue2)
  pure val QuorumVotingPower = 3

  pure val NilValueEquivocation = {
    kind: NilValueKind,
    height: BridgeHeight,
    round: BridgeRound,
    validatorPubKey: BridgeSigner,
    firstValue: ConcreteNilValue,
    secondValue: BridgeValue,
    evidenceHex: "nil-value-evidence",
  }

  pure val ValueValueEquivocation = {
    kind: ValueValueKind,
    height: BridgeHeight,
    round: BridgeRound,
    validatorPubKey: BridgeSigner,
    firstValue: BridgeValue,
    secondValue: BridgeValue2,
    evidenceHex: "value-value-evidence",
  }

  var observedEquivocations: Set[ObserverEquivocation_t]
  var appliedEquivocations: Set[ObserverEquivocation_t]
  var evidencePrecommit: Round_t -> Set[Vote_t]
  var firedAction: str

  pure def AbstractObservedValue(value: str): Snapshot_t =
    if (value == ConcreteNilValue) {
      NilSnapshot
    } else {
      value
    }

  pure def ConcreteValueMapsToAbstract(value: str): bool =
    value == ConcreteNilValue or Snapshots.contains(value)

  pure def ConcreteEquivocationMapsToAbstract(equivocation: ObserverEquivocation_t): bool =
    equivocation.height == BridgeHeight and
    equivocation.validatorPubKey == BridgeSigner and
    Rounds.contains(equivocation.round) and
    ConcreteValueMapsToAbstract(equivocation.firstValue) and
    ConcreteValueMapsToAbstract(equivocation.secondValue) and
    AbstractObservedValue(equivocation.firstValue) !=
      AbstractObservedValue(equivocation.secondValue)

  pure def Voters(votes: Set[Vote_t]): Set[Proc_t] =
    votes.map(vote => vote.src)

  pure def VotingPowerOf(voters: Set[Proc_t]): int =
    size(voters)

  def ObservedPrecommitQuorum(r: Round_t, v: Snapshot_t): bool =
    VotingPowerOf(Voters(evidencePrecommit.get(r).filter(vote => vote.id == v))) >=
      QuorumVotingPower

  def ObservedNilPrecommitCert(r: Round_t): bool =
    ObservedPrecommitQuorum(r, NilSnapshot)

  def ObservedValuePrecommitFrom(
    p: Proc_t,
    r: Round_t,
    v: Snapshot_t,
  ): bool =
    evidencePrecommit.get(r).exists(vote => vote.src == p and vote.id == v)

  def ObservedNilPrecommitFrom(p: Proc_t, r: Round_t): bool =
    evidencePrecommit.get(r).exists(vote =>
      vote.src == p and vote.id == NilSnapshot
    )

  def CorrectSignerValueValueEquivocationEvidence(
    p: Proc_t,
    r: Round_t,
    v1: Snapshot_t,
    v2: Snapshot_t,
  ): bool =
    Corr.contains(p) and
    Rounds.contains(r) and
    Snapshots.contains(v1) and
    Snapshots.contains(v2) and
    v1 != v2 and
    ObservedValuePrecommitFrom(p, r, v1) and
    ObservedValuePrecommitFrom(p, r, v2)

  def CorrectSignerNilValueEquivocationEvidence(
    p: Proc_t,
    r: Round_t,
    v: Snapshot_t,
  ): bool =
    Corr.contains(p) and
    Rounds.contains(r) and
    Snapshots.contains(v) and
    ObservedNilPrecommitFrom(p, r) and
    ObservedValuePrecommitFrom(p, r, v)

  def CorrectSameRoundEquivocationEvidence(
    r: Round_t,
    v1: Snapshot_t,
    v2: Snapshot_t,
  ): bool =
    Corr.exists(p => CorrectSignerValueValueEquivocationEvidence(p, r, v1, v2))

  def CorrectNilValueEquivocationEvidence(r: Round_t, v: Snapshot_t): bool =
    Snapshots.contains(v) and
    ObservedNilPrecommitCert(r) and
    ObservedPrecommitQuorum(r, v) and
    Corr.exists(p => CorrectSignerNilValueEquivocationEvidence(p, r, v))

  def AbstractSignerEvidenceMatches(equivocation: ObserverEquivocation_t): bool =
    ConcreteEquivocationMapsToAbstract(equivocation) and
    if (equivocation.firstValue == ConcreteNilValue) {
      CorrectSignerNilValueEquivocationEvidence(
        equivocation.validatorPubKey,
        equivocation.round,
        AbstractObservedValue(equivocation.secondValue),
      )
    } else if (equivocation.secondValue == ConcreteNilValue) {
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

  val AppliedEquivocationsBackedByObservedFacts =
    appliedEquivocations.forall(equivocation =>
      observedEquivocations.contains(equivocation) and
      AbstractSignerEvidenceMatches(equivocation)
    )

  val AppliedValueValueReachesSameRoundAccountability =
    appliedEquivocations.contains(ValueValueEquivocation) implies
      CorrectSameRoundEquivocationEvidence(BridgeRound, BridgeValue, BridgeValue2)

  val AppliedNilValueReachesSignerEvidence =
    appliedEquivocations.contains(NilValueEquivocation) implies
      CorrectSignerNilValueEquivocationEvidence(
        BridgeSigner,
        BridgeRound,
        BridgeValue,
      )

  val NilValueAggregateRequiresQuorumContext =
    CorrectNilValueEquivocationEvidence(BridgeRound, BridgeValue) implies
      ObservedNilPrecommitCert(BridgeRound) and
      ObservedPrecommitQuorum(BridgeRound, BridgeValue) and
      CorrectSignerNilValueEquivocationEvidence(
        BridgeSigner,
        BridgeRound,
        BridgeValue,
      )

  val BridgeSafety =
    AppliedEquivocationsBackedByObservedFacts and
    AppliedValueValueReachesSameRoundAccountability and
    AppliedNilValueReachesSignerEvidence and
    NilValueAggregateRequiresQuorumContext

  action BridgeInit = all {
    observedEquivocations' = Set(),
    appliedEquivocations' = Set(),
    evidencePrecommit' = BridgeRound.to(BridgeRound).mapBy(_ => Set()),
    firedAction' = "BridgeInit",
  }

  action ObserveEquivocation(equivocation: ObserverEquivocation_t): bool =
    all {
      ConcreteEquivocationMapsToAbstract(equivocation),
      observedEquivocations' = observedEquivocations.union(Set(equivocation)),
      appliedEquivocations' = appliedEquivocations,
      evidencePrecommit' = evidencePrecommit,
      firedAction' = "ObserveEquivocation",
    }

  action ApplyObservedEquivocation(equivocation: ObserverEquivocation_t): bool =
    all {
      observedEquivocations.contains(equivocation),
      ConcreteEquivocationMapsToAbstract(equivocation),
      observedEquivocations' = observedEquivocations,
      appliedEquivocations' = appliedEquivocations.union(Set(equivocation)),
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
      firedAction' = "ApplyObservedEquivocation",
    }

  action AddNilQuorumContext: bool =
    all {
      observedEquivocations' = observedEquivocations,
      appliedEquivocations' = appliedEquivocations,
      evidencePrecommit' =
        evidencePrecommit.setBy(BridgeRound, old =>
          old
            .union(Set({ src: BridgeSecondCorrect, round: BridgeRound, id: NilSnapshot }))
            .union(Set({ src: BridgeFaulty, round: BridgeRound, id: NilSnapshot }))
        ),
      firedAction' = "AddNilQuorumContext",
    }

  action AddValueQuorumContext: bool =
    all {
      observedEquivocations' = observedEquivocations,
      appliedEquivocations' = appliedEquivocations,
      evidencePrecommit' =
        evidencePrecommit.setBy(BridgeRound, old =>
          old
            .union(Set({ src: BridgeSecondCorrect, round: BridgeRound, id: BridgeValue }))
            .union(Set({ src: BridgeFaulty, round: BridgeRound, id: BridgeValue }))
        ),
      firedAction' = "AddValueQuorumContext",
    }

  action BridgeStutter: bool =
    all {
      observedEquivocations' = observedEquivocations,
      appliedEquivocations' = appliedEquivocations,
      evidencePrecommit' = evidencePrecommit,
      firedAction' = firedAction,
    }

  action BridgeNext: bool =
    any {
      ObserveEquivocation(NilValueEquivocation),
      ObserveEquivocation(ValueValueEquivocation),
      ApplyObservedEquivocation(NilValueEquivocation),
      ApplyObservedEquivocation(ValueValueEquivocation),
      AddNilQuorumContext,
      AddValueQuorumContext,
      BridgeStutter,
    }

  run nilValueNeedsQuorumContextWitnessTest = {
    BridgeInit
      .then(ObserveEquivocation(NilValueEquivocation))
      .then(ApplyObservedEquivocation(NilValueEquivocation))
      .then(all {
        assert(CorrectSignerNilValueEquivocationEvidence(
          BridgeSigner,
          BridgeRound,
          BridgeValue,
        )),
        assert(not(CorrectNilValueEquivocationEvidence(BridgeRound, BridgeValue))),
        assert(BridgeSafety),
        BridgeStutter,
      })
  }

  run nilValueAggregateAfterQuorumContextWitnessTest = {
    BridgeInit
      .then(ObserveEquivocation(NilValueEquivocation))
      .then(ApplyObservedEquivocation(NilValueEquivocation))
      .then(AddNilQuorumContext)
      .then(AddValueQuorumContext)
      .then(all {
        assert(ObservedNilPrecommitCert(BridgeRound)),
        assert(ObservedPrecommitQuorum(BridgeRound, BridgeValue)),
        assert(CorrectNilValueEquivocationEvidence(BridgeRound, BridgeValue)),
        assert(BridgeSafety),
        BridgeStutter,
      })
  }
}

module CrosslinkTenderlinkAccountabilityObserverBridgeSafetyModel {
  import CrosslinkTenderlinkAccountabilityObserverBridgeSafety.* from
    "./CrosslinkTenderlinkAccountabilityObserverBridgeSafety"
  export CrosslinkTenderlinkAccountabilityObserverBridgeSafety.*
}
