module CrosslinkTenderlinkUnlockAccountabilityBoundary {
  /*
   Accountability boundary for nil-precommit unlocks.

   Cross-round value switching is an abstract accountability signal only when
   the abandoned round has no observed nil-precommit certificate. That absence
   is not, by itself, transportable slashing evidence: a nil certificate may be
   discovered later and justify the switch. This slice keeps that boundary
   explicit so the nil-precommit resampling rule does not accidentally weaken
   Tendermint's value-lock argument.
   */

  type Proc_t = str
  type Snapshot_t = str
  type Round_t = int
  type Vote_t = {
    src: Proc_t,
    round: Round_t,
    id: Snapshot_t,
  }
  type ValueSwitch_t = {
    signer: Proc_t,
    fromRound: Round_t,
    fromValue: Snapshot_t,
    toRound: Round_t,
    toValue: Snapshot_t,
  }

  pure val FirstRound = 0
  pure val SecondRound = 1
  pure val Signer = "unlock-signer"
  pure val Other1 = "unlock-other-1"
  pure val Other2 = "unlock-other-2"
  pure val Faulty = "unlock-faulty"
  pure val NilSnapshot = "None"
  pure val Value0 = "stream-0"
  pure val Value1 = "stream-1"

  pure val Corr = Set(Signer, Other1, Other2)
  pure val FaultySet = Set(Faulty)
  pure val Rounds = Set(FirstRound, SecondRound)
  pure val Snapshots = Set(Value0, Value1)
  pure val QuorumVotingPower = 3

  pure val SignerValueSwitch = {
    signer: Signer,
    fromRound: FirstRound,
    fromValue: Value0,
    toRound: SecondRound,
    toValue: Value1,
  }

  var observedPrecommit: Round_t -> Set[Vote_t]
  var acceptedStandaloneSwitches: Set[ValueSwitch_t]
  var firedAction: str

  pure def Voters(votes: Set[Vote_t]): Set[Proc_t] =
    votes.map(vote => vote.src)

  pure def VotingPowerOf(voters: Set[Proc_t]): int =
    size(voters)

  def ObservedPrecommitQuorum(r: Round_t, v: Snapshot_t): bool =
    VotingPowerOf(Voters(observedPrecommit.get(r).filter(vote => vote.id == v))) >=
      QuorumVotingPower

  def ObservedNilPrecommitCert(r: Round_t): bool =
    ObservedPrecommitQuorum(r, NilSnapshot)

  def ObservedAnyPrecommitQuorum(r: Round_t): bool =
    VotingPowerOf(Voters(observedPrecommit.get(r))) >= QuorumVotingPower

  def ObservedMixedPrecommitQuorumWithoutNilCert(r: Round_t): bool =
    ObservedAnyPrecommitQuorum(r) and
    not(ObservedNilPrecommitCert(r)) and
    observedPrecommit.get(r).exists(vote => vote.id == NilSnapshot) and
    observedPrecommit.get(r).exists(vote => Snapshots.contains(vote.id))

  def ObservedValuePrecommitFrom(
    p: Proc_t,
    r: Round_t,
    v: Snapshot_t,
  ): bool =
    observedPrecommit.get(r).exists(vote => vote.src == p and vote.id == v)

  def ValueSwitchObserved(switch: ValueSwitch_t): bool =
    Corr.contains(switch.signer) and
    Rounds.contains(switch.fromRound) and
    Rounds.contains(switch.toRound) and
    switch.fromRound < switch.toRound and
    Snapshots.contains(switch.fromValue) and
    Snapshots.contains(switch.toValue) and
    switch.fromValue != switch.toValue and
    ObservedValuePrecommitFrom(
      switch.signer,
      switch.fromRound,
      switch.fromValue,
    ) and
    ObservedValuePrecommitFrom(
      switch.signer,
      switch.toRound,
      switch.toValue,
    )

  def AbstractValueSwitchWithoutNilUnlock(switch: ValueSwitch_t): bool =
    ValueSwitchObserved(switch) and
    not(ObservedNilPrecommitCert(switch.fromRound))

  def ValueSwitchJustifiedByNilUnlock(switch: ValueSwitch_t): bool =
    ValueSwitchObserved(switch) and
    ObservedNilPrecommitCert(switch.fromRound)

  val StandaloneSwitchAcceptanceSound =
    acceptedStandaloneSwitches.forall(switch =>
      AbstractValueSwitchWithoutNilUnlock(switch)
    )

  val NoStandaloneAbsenceBasedSlashing =
    acceptedStandaloneSwitches == Set()

  val NilCertificateCancelsBadUnlockSignal =
    ValueSwitchJustifiedByNilUnlock(SignerValueSwitch) implies
      not(AbstractValueSwitchWithoutNilUnlock(SignerValueSwitch))

  val MixedPrecommitDoesNotCancelBadUnlockSignal =
    ObservedMixedPrecommitQuorumWithoutNilCert(FirstRound) and
    ValueSwitchObserved(SignerValueSwitch) implies
      AbstractValueSwitchWithoutNilUnlock(SignerValueSwitch)

  val BoundarySafety =
    NoStandaloneAbsenceBasedSlashing and
    NilCertificateCancelsBadUnlockSignal and
    MixedPrecommitDoesNotCancelBadUnlockSignal

  action BoundaryInit = all {
    observedPrecommit' = Rounds.mapBy(_ => Set()),
    acceptedStandaloneSwitches' = Set(),
    firedAction' = "BoundaryInit",
  }

  action ObserveSignerFromValue: bool =
    all {
      observedPrecommit' =
        observedPrecommit.setBy(FirstRound, old =>
          old.union(Set({
            src: Signer,
            round: FirstRound,
            id: Value0,
          }))
        ),
      acceptedStandaloneSwitches' = acceptedStandaloneSwitches,
      firedAction' = "ObserveSignerFromValue",
    }

  action ObserveSignerToValue: bool =
    all {
      observedPrecommit' =
        observedPrecommit.setBy(SecondRound, old =>
          old.union(Set({
            src: Signer,
            round: SecondRound,
            id: Value1,
          }))
        ),
      acceptedStandaloneSwitches' = acceptedStandaloneSwitches,
      firedAction' = "ObserveSignerToValue",
    }

  action ObserveNilCertForFirstRound: bool =
    all {
      observedPrecommit' =
        observedPrecommit.setBy(FirstRound, old =>
          old
            .union(Set({ src: Other1, round: FirstRound, id: NilSnapshot }))
            .union(Set({ src: Other2, round: FirstRound, id: NilSnapshot }))
            .union(Set({ src: Faulty, round: FirstRound, id: NilSnapshot }))
        ),
      acceptedStandaloneSwitches' = acceptedStandaloneSwitches,
      firedAction' = "ObserveNilCertForFirstRound",
    }

  action ObserveMixedPrecommitsForFirstRound: bool =
    all {
      observedPrecommit' =
        observedPrecommit.setBy(FirstRound, old =>
          old
            .union(Set({ src: Other1, round: FirstRound, id: NilSnapshot }))
            .union(Set({ src: Other2, round: FirstRound, id: Value0 }))
        ),
      acceptedStandaloneSwitches' = acceptedStandaloneSwitches,
      firedAction' = "ObserveMixedPrecommitsForFirstRound",
    }

  action AcceptStandaloneSwitchAsBadUnlock(switch: ValueSwitch_t): bool =
    all {
      AbstractValueSwitchWithoutNilUnlock(switch),
      observedPrecommit' = observedPrecommit,
      acceptedStandaloneSwitches' =
        acceptedStandaloneSwitches.union(Set(switch)),
      firedAction' = "AcceptStandaloneSwitchAsBadUnlock",
    }

  action BoundaryStutter: bool =
    all {
      observedPrecommit' = observedPrecommit,
      acceptedStandaloneSwitches' = acceptedStandaloneSwitches,
      firedAction' = firedAction,
    }

  action BoundaryNext: bool =
    any {
      ObserveSignerFromValue,
      ObserveSignerToValue,
      ObserveNilCertForFirstRound,
      ObserveMixedPrecommitsForFirstRound,
      BoundaryStutter,
    }

  run valueSwitchWithoutNilCertIsAbstractSignalTest = {
    BoundaryInit
      .then(ObserveSignerFromValue)
      .then(ObserveSignerToValue)
      .then(all {
        assert(ValueSwitchObserved(SignerValueSwitch)),
        assert(AbstractValueSwitchWithoutNilUnlock(SignerValueSwitch)),
        assert(not(ValueSwitchJustifiedByNilUnlock(SignerValueSwitch))),
        BoundaryStutter,
      })
  }

  run nilCertContextCancelsBadUnlockSignalTest = {
    BoundaryInit
      .then(ObserveSignerFromValue)
      .then(ObserveSignerToValue)
      .then(ObserveNilCertForFirstRound)
      .then(all {
        assert(ObservedNilPrecommitCert(FirstRound)),
        assert(ValueSwitchJustifiedByNilUnlock(SignerValueSwitch)),
        assert(not(AbstractValueSwitchWithoutNilUnlock(SignerValueSwitch))),
        assert(BoundarySafety),
        BoundaryStutter,
      })
  }

  run mixedPrecommitDoesNotCancelBadUnlockSignalTest = {
    BoundaryInit
      .then(ObserveSignerFromValue)
      .then(ObserveMixedPrecommitsForFirstRound)
      .then(ObserveSignerToValue)
      .then(all {
        assert(ObservedMixedPrecommitQuorumWithoutNilCert(FirstRound)),
        assert(not(ObservedNilPrecommitCert(FirstRound))),
        assert(AbstractValueSwitchWithoutNilUnlock(SignerValueSwitch)),
        assert(BoundarySafety),
        BoundaryStutter,
      })
  }

  run absenceBasedStandaloneSwitchAcceptanceIsUnsafeTest = {
    BoundaryInit
      .then(ObserveSignerFromValue)
      .then(ObserveSignerToValue)
      .then(AcceptStandaloneSwitchAsBadUnlock(SignerValueSwitch))
      .then(ObserveNilCertForFirstRound)
      .then(all {
        assert(acceptedStandaloneSwitches.contains(SignerValueSwitch)),
        assert(not(AbstractValueSwitchWithoutNilUnlock(SignerValueSwitch))),
        assert(not(StandaloneSwitchAcceptanceSound)),
        assert(not(BoundarySafety)),
        BoundaryStutter,
      })
  }

  run safeBoundaryNeverAcceptsStandaloneSwitchTest = {
    BoundaryInit
      .then(ObserveSignerFromValue)
      .then(ObserveMixedPrecommitsForFirstRound)
      .then(ObserveSignerToValue)
      .then(ObserveNilCertForFirstRound)
      .then(all {
        assert(NoStandaloneAbsenceBasedSlashing),
        assert(BoundarySafety),
        BoundaryStutter,
      })
  }
}

module CrosslinkTenderlinkUnlockAccountabilityBoundaryModel {
  import CrosslinkTenderlinkUnlockAccountabilityBoundary.* from
    "./CrosslinkTenderlinkUnlockAccountabilityBoundary"
  export CrosslinkTenderlinkUnlockAccountabilityBoundary.*
}
