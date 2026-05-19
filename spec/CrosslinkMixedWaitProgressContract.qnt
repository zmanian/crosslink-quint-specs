module CrosslinkMixedWaitProgressContractModel {
  /*
   TLC-friendly progress contract for mixed-precommit waiting.

   A mixed precommit quorum is enough evidence that the precommit wait made
   progress, but it is not unlock evidence. This contract checks the intended
   runtime shape: keep same-round value-lock state while the observed precommit
   set is mixed, then unlock only after an actual 2f + 1 nil-precommit
   certificate appears. Once that nil certificate is present, the next stable
   round can resample and decide while older Tendermint locks remain intact.
   */

  type Proc_t = str

  pure val P1 = "p1"
  pure val P2 = "p2"
  pure val P3 = "p3"
  pure val P4 = "p4"
  pure val Corr = Set(P1, P2, P3)
  pure val Validators = Set(P1, P2, P3, P4)
  pure val QuorumPower = 3

  var round: int
  var nilPrecommits: Set[Proc_t]
  var valuePrecommits: Set[Proc_t]
  var waitedOnMixed: bool
  var sameRoundStateCleared: bool
  var currentRoundLock: Set[Proc_t]
  var olderValueLock: Set[Proc_t]
  var stableProposalInserted: bool
  var stableProposalDelivered: bool
  var stablePrevoted: Set[Proc_t]
  var stablePrevotesDelivered: Set[Proc_t]
  var stablePrecommitted: Set[Proc_t]
  var stablePrecommitsDelivered: bool
  var stableDecisionMade: bool
  var progress: int

  pure def VotingPowerOf(voters: Set[Proc_t]): int =
    size(voters)

  def AnyPrecommitQuorum: bool =
    VotingPowerOf(nilPrecommits.union(valuePrecommits)) >= QuorumPower

  def NilPrecommitCertificate: bool =
    VotingPowerOf(nilPrecommits) >= QuorumPower

  def ValuePrecommitCertificate: bool =
    VotingPowerOf(valuePrecommits) >= QuorumPower

  def MixedPrecommitQuorumWithoutNilCert: bool =
    AnyPrecommitQuorum and
    not(NilPrecommitCertificate) and
    not(ValuePrecommitCertificate) and
    nilPrecommits != Set() and
    valuePrecommits != Set()

  action Init = all {
    round' = 0,
    nilPrecommits' = Set(),
    valuePrecommits' = Set(),
    waitedOnMixed' = false,
    sameRoundStateCleared' = false,
    currentRoundLock' = Corr,
    olderValueLock' = Corr,
    stableProposalInserted' = false,
    stableProposalDelivered' = false,
    stablePrevoted' = Set(),
    stablePrevotesDelivered' = Set(),
    stablePrecommitted' = Set(),
    stablePrecommitsDelivered' = false,
    stableDecisionMade' = false,
    progress' = 0,
  }

  action Unchanged = all {
    round' = round,
    nilPrecommits' = nilPrecommits,
    valuePrecommits' = valuePrecommits,
    waitedOnMixed' = waitedOnMixed,
    sameRoundStateCleared' = sameRoundStateCleared,
    currentRoundLock' = currentRoundLock,
    olderValueLock' = olderValueLock,
    stableProposalInserted' = stableProposalInserted,
    stableProposalDelivered' = stableProposalDelivered,
    stablePrevoted' = stablePrevoted,
    stablePrevotesDelivered' = stablePrevotesDelivered,
    stablePrecommitted' = stablePrecommitted,
    stablePrecommitsDelivered' = stablePrecommitsDelivered,
    stableDecisionMade' = stableDecisionMade,
    progress' = progress,
  }

  action ObserveInitialNilPrecommit(p: Proc_t): bool =
    all {
      round == 0,
      Set(P1, P2).contains(p),
      not(nilPrecommits.contains(p)),
      nilPrecommits' = nilPrecommits.union(Set(p)),
      valuePrecommits' = valuePrecommits,
      waitedOnMixed' = waitedOnMixed,
      sameRoundStateCleared' = sameRoundStateCleared,
      currentRoundLock' = currentRoundLock,
      olderValueLock' = olderValueLock,
      stableProposalInserted' = stableProposalInserted,
      stableProposalDelivered' = stableProposalDelivered,
      stablePrevoted' = stablePrevoted,
      stablePrevotesDelivered' = stablePrevotesDelivered,
      stablePrecommitted' = stablePrecommitted,
      stablePrecommitsDelivered' = stablePrecommitsDelivered,
      stableDecisionMade' = stableDecisionMade,
      round' = round,
      progress' = progress + 1,
    }

  action ObserveInitialValuePrecommit: bool =
    all {
      round == 0,
      not(valuePrecommits.contains(P3)),
      valuePrecommits' = valuePrecommits.union(Set(P3)),
      nilPrecommits' = nilPrecommits,
      waitedOnMixed' = waitedOnMixed,
      sameRoundStateCleared' = sameRoundStateCleared,
      currentRoundLock' = currentRoundLock,
      olderValueLock' = olderValueLock,
      stableProposalInserted' = stableProposalInserted,
      stableProposalDelivered' = stableProposalDelivered,
      stablePrevoted' = stablePrevoted,
      stablePrevotesDelivered' = stablePrevotesDelivered,
      stablePrecommitted' = stablePrecommitted,
      stablePrecommitsDelivered' = stablePrecommitsDelivered,
      stableDecisionMade' = stableDecisionMade,
      round' = round,
      progress' = progress + 1,
    }

  action WaitOnMixedPrecommitQuorum: bool =
    all {
      round == 0,
      MixedPrecommitQuorumWithoutNilCert,
      not(waitedOnMixed),
      nilPrecommits' = nilPrecommits,
      valuePrecommits' = valuePrecommits,
      waitedOnMixed' = true,
      sameRoundStateCleared' = false,
      currentRoundLock' = currentRoundLock,
      olderValueLock' = olderValueLock,
      stableProposalInserted' = stableProposalInserted,
      stableProposalDelivered' = stableProposalDelivered,
      stablePrevoted' = stablePrevoted,
      stablePrevotesDelivered' = stablePrevotesDelivered,
      stablePrecommitted' = stablePrecommitted,
      stablePrecommitsDelivered' = stablePrecommitsDelivered,
      stableDecisionMade' = stableDecisionMade,
      round' = round,
      progress' = progress + 1,
    }

  action ObserveNilCertCompleter: bool =
    all {
      round == 0,
      waitedOnMixed,
      not(nilPrecommits.contains(P4)),
      nilPrecommits' = nilPrecommits.union(Set(P4)),
      valuePrecommits' = valuePrecommits,
      waitedOnMixed' = waitedOnMixed,
      sameRoundStateCleared' = sameRoundStateCleared,
      currentRoundLock' = currentRoundLock,
      olderValueLock' = olderValueLock,
      stableProposalInserted' = stableProposalInserted,
      stableProposalDelivered' = stableProposalDelivered,
      stablePrevoted' = stablePrevoted,
      stablePrevotesDelivered' = stablePrevotesDelivered,
      stablePrecommitted' = stablePrecommitted,
      stablePrecommitsDelivered' = stablePrecommitsDelivered,
      stableDecisionMade' = stableDecisionMade,
      round' = round,
      progress' = progress + 1,
    }

  action UnlockSameRoundAfterNilCert: bool =
    all {
      round == 0,
      NilPrecommitCertificate,
      not(sameRoundStateCleared),
      nilPrecommits' = nilPrecommits,
      valuePrecommits' = valuePrecommits,
      waitedOnMixed' = waitedOnMixed,
      sameRoundStateCleared' = true,
      currentRoundLock' = Set(),
      olderValueLock' = olderValueLock,
      stableProposalInserted' = stableProposalInserted,
      stableProposalDelivered' = stableProposalDelivered,
      stablePrevoted' = stablePrevoted,
      stablePrevotesDelivered' = stablePrevotesDelivered,
      stablePrecommitted' = stablePrecommitted,
      stablePrecommitsDelivered' = stablePrecommitsDelivered,
      stableDecisionMade' = stableDecisionMade,
      round' = 1,
      progress' = progress + 1,
    }

  action InsertStableProposal: bool =
    all {
      round == 1,
      sameRoundStateCleared,
      not(stableProposalInserted),
      nilPrecommits' = nilPrecommits,
      valuePrecommits' = valuePrecommits,
      waitedOnMixed' = waitedOnMixed,
      sameRoundStateCleared' = sameRoundStateCleared,
      currentRoundLock' = currentRoundLock,
      olderValueLock' = olderValueLock,
      stableProposalInserted' = true,
      stableProposalDelivered' = stableProposalDelivered,
      stablePrevoted' = stablePrevoted,
      stablePrevotesDelivered' = stablePrevotesDelivered,
      stablePrecommitted' = stablePrecommitted,
      stablePrecommitsDelivered' = stablePrecommitsDelivered,
      stableDecisionMade' = stableDecisionMade,
      round' = round,
      progress' = progress + 1,
    }

  action DeliverStableProposal: bool =
    all {
      stableProposalInserted,
      not(stableProposalDelivered),
      nilPrecommits' = nilPrecommits,
      valuePrecommits' = valuePrecommits,
      waitedOnMixed' = waitedOnMixed,
      sameRoundStateCleared' = sameRoundStateCleared,
      currentRoundLock' = currentRoundLock,
      olderValueLock' = olderValueLock,
      stableProposalInserted' = stableProposalInserted,
      stableProposalDelivered' = true,
      stablePrevoted' = stablePrevoted,
      stablePrevotesDelivered' = stablePrevotesDelivered,
      stablePrecommitted' = stablePrecommitted,
      stablePrecommitsDelivered' = stablePrecommitsDelivered,
      stableDecisionMade' = stableDecisionMade,
      round' = round,
      progress' = progress + 1,
    }

  action PrevoteStableValue(p: Proc_t): bool =
    all {
      stableProposalDelivered,
      Corr.contains(p),
      not(stablePrevoted.contains(p)),
      nilPrecommits' = nilPrecommits,
      valuePrecommits' = valuePrecommits,
      waitedOnMixed' = waitedOnMixed,
      sameRoundStateCleared' = sameRoundStateCleared,
      currentRoundLock' = currentRoundLock,
      olderValueLock' = olderValueLock,
      stableProposalInserted' = stableProposalInserted,
      stableProposalDelivered' = stableProposalDelivered,
      stablePrevoted' = stablePrevoted.union(Set(p)),
      stablePrevotesDelivered' = stablePrevotesDelivered,
      stablePrecommitted' = stablePrecommitted,
      stablePrecommitsDelivered' = stablePrecommitsDelivered,
      stableDecisionMade' = stableDecisionMade,
      round' = round,
      progress' = progress + 1,
    }

  action DeliverStablePrevotes(p: Proc_t): bool =
    all {
      Corr.subseteq(stablePrevoted),
      Corr.contains(p),
      not(stablePrevotesDelivered.contains(p)),
      nilPrecommits' = nilPrecommits,
      valuePrecommits' = valuePrecommits,
      waitedOnMixed' = waitedOnMixed,
      sameRoundStateCleared' = sameRoundStateCleared,
      currentRoundLock' = currentRoundLock,
      olderValueLock' = olderValueLock,
      stableProposalInserted' = stableProposalInserted,
      stableProposalDelivered' = stableProposalDelivered,
      stablePrevoted' = stablePrevoted,
      stablePrevotesDelivered' = stablePrevotesDelivered.union(Set(p)),
      stablePrecommitted' = stablePrecommitted,
      stablePrecommitsDelivered' = stablePrecommitsDelivered,
      stableDecisionMade' = stableDecisionMade,
      round' = round,
      progress' = progress + 1,
    }

  action PrecommitStableValue(p: Proc_t): bool =
    all {
      stablePrevotesDelivered.contains(p),
      Corr.contains(p),
      not(stablePrecommitted.contains(p)),
      nilPrecommits' = nilPrecommits,
      valuePrecommits' = valuePrecommits,
      waitedOnMixed' = waitedOnMixed,
      sameRoundStateCleared' = sameRoundStateCleared,
      currentRoundLock' = currentRoundLock,
      olderValueLock' = olderValueLock,
      stableProposalInserted' = stableProposalInserted,
      stableProposalDelivered' = stableProposalDelivered,
      stablePrevoted' = stablePrevoted,
      stablePrevotesDelivered' = stablePrevotesDelivered,
      stablePrecommitted' = stablePrecommitted.union(Set(p)),
      stablePrecommitsDelivered' = stablePrecommitsDelivered,
      stableDecisionMade' = stableDecisionMade,
      round' = round,
      progress' = progress + 1,
    }

  action DeliverStablePrecommits: bool =
    all {
      Corr.subseteq(stablePrecommitted),
      not(stablePrecommitsDelivered),
      nilPrecommits' = nilPrecommits,
      valuePrecommits' = valuePrecommits,
      waitedOnMixed' = waitedOnMixed,
      sameRoundStateCleared' = sameRoundStateCleared,
      currentRoundLock' = currentRoundLock,
      olderValueLock' = olderValueLock,
      stableProposalInserted' = stableProposalInserted,
      stableProposalDelivered' = stableProposalDelivered,
      stablePrevoted' = stablePrevoted,
      stablePrevotesDelivered' = stablePrevotesDelivered,
      stablePrecommitted' = stablePrecommitted,
      stablePrecommitsDelivered' = true,
      stableDecisionMade' = stableDecisionMade,
      round' = round,
      progress' = progress + 1,
    }

  action DecideStableValue: bool =
    all {
      stablePrecommitsDelivered,
      not(stableDecisionMade),
      nilPrecommits' = nilPrecommits,
      valuePrecommits' = valuePrecommits,
      waitedOnMixed' = waitedOnMixed,
      sameRoundStateCleared' = sameRoundStateCleared,
      currentRoundLock' = currentRoundLock,
      olderValueLock' = olderValueLock,
      stableProposalInserted' = stableProposalInserted,
      stableProposalDelivered' = stableProposalDelivered,
      stablePrevoted' = stablePrevoted,
      stablePrevotesDelivered' = stablePrevotesDelivered,
      stablePrecommitted' = stablePrecommitted,
      stablePrecommitsDelivered' = stablePrecommitsDelivered,
      stableDecisionMade' = true,
      round' = round,
      progress' = progress + 1,
    }

  action StutterAfterDecision: bool =
    all {
      stableDecisionMade,
      Unchanged,
    }

  action Next: bool =
    any {
      nondet p = oneOf(Set(P1, P2))
      ObserveInitialNilPrecommit(p),
      ObserveInitialValuePrecommit,
      WaitOnMixedPrecommitQuorum,
      ObserveNilCertCompleter,
      UnlockSameRoundAfterNilCert,
      InsertStableProposal,
      DeliverStableProposal,
      nondet p = oneOf(Corr)
      PrevoteStableValue(p),
      nondet p = oneOf(Corr)
      DeliverStablePrevotes(p),
      nondet p = oneOf(Corr)
      PrecommitStableValue(p),
      DeliverStablePrecommits,
      DecideStableValue,
      StutterAfterDecision,
    }

  val StateWellFormed =
    0.to(1).contains(round) and
    nilPrecommits.subseteq(Validators) and
    valuePrecommits.subseteq(Validators) and
    nilPrecommits.intersect(valuePrecommits) == Set() and
    currentRoundLock.subseteq(Corr) and
    olderValueLock.subseteq(Corr) and
    stablePrevoted.subseteq(Corr) and
    stablePrevotesDelivered.subseteq(Corr) and
    stablePrecommitted.subseteq(Corr) and
    0.to(30).contains(progress)

  val MixedWaitDoesNotUnlock =
    (waitedOnMixed and not(NilPrecommitCertificate)) implies
      round == 0 and
      not(sameRoundStateCleared) and
      currentRoundLock == Corr and
      not(stableProposalInserted)

  val NilCertificateRequiredForUnlock =
    sameRoundStateCleared implies NilPrecommitCertificate

  val OlderValueLockPreserved =
    olderValueLock == Corr

  val StableDecisionRequiresNilUnlock =
    stableDecisionMade implies
      waitedOnMixed and
      sameRoundStateCleared and
      NilPrecommitCertificate and
      stablePrecommitsDelivered

  val PhaseOrder =
    (waitedOnMixed implies AnyPrecommitQuorum) and
    (sameRoundStateCleared implies waitedOnMixed) and
    (stableProposalInserted implies sameRoundStateCleared) and
    (stableProposalDelivered implies stableProposalInserted) and
    (stablePrevoted != Set() implies stableProposalDelivered) and
    (stablePrevotesDelivered != Set() implies Corr.subseteq(stablePrevoted)) and
    stablePrecommitted.forall(p => stablePrevotesDelivered.contains(p)) and
    (stablePrecommitsDelivered implies Corr.subseteq(stablePrecommitted)) and
    (stableDecisionMade implies stablePrecommitsDelivered)

  val Safety =
    StateWellFormed and
    MixedWaitDoesNotUnlock and
    NilCertificateRequiredForUnlock and
    OlderValueLockPreserved and
    StableDecisionRequiresNilUnlock and
    PhaseOrder

  temporal EventuallyNilCertUnlocksMixedWait =
    Next.weakFair(Set(progress)).implies(eventually(
      waitedOnMixed and sameRoundStateCleared and stableDecisionMade
    ))

  run mixedQuorumWaitsWithoutUnlockTest = {
    Init
      .then(ObserveInitialNilPrecommit(P2))
      .then(ObserveInitialNilPrecommit(P1))
      .then(ObserveInitialValuePrecommit)
      .then(WaitOnMixedPrecommitQuorum)
      .then(all {
        assert(MixedPrecommitQuorumWithoutNilCert),
        assert(waitedOnMixed),
        assert(not(sameRoundStateCleared)),
        assert(currentRoundLock == Corr),
        assert(not(stableProposalInserted)),
        assert(Safety),
        Unchanged,
      })
  }

  run nilCertificateUnlocksSameRoundStateTest = {
    Init
      .then(ObserveInitialNilPrecommit(P1))
      .then(ObserveInitialNilPrecommit(P2))
      .then(ObserveInitialValuePrecommit)
      .then(WaitOnMixedPrecommitQuorum)
      .then(ObserveNilCertCompleter)
      .then(UnlockSameRoundAfterNilCert)
      .then(all {
        assert(NilPrecommitCertificate),
        assert(sameRoundStateCleared),
        assert(currentRoundLock == Set()),
        assert(olderValueLock == Corr),
        assert(Safety),
        Unchanged,
      })
  }

  run nilCertWaitProgressDecisionTest = {
    Init
      .then(ObserveInitialNilPrecommit(P2))
      .then(ObserveInitialNilPrecommit(P1))
      .then(ObserveInitialValuePrecommit)
      .then(WaitOnMixedPrecommitQuorum)
      .then(ObserveNilCertCompleter)
      .then(UnlockSameRoundAfterNilCert)
      .then(InsertStableProposal)
      .then(DeliverStableProposal)
      .then(PrevoteStableValue(P1))
      .then(PrevoteStableValue(P3))
      .then(PrevoteStableValue(P2))
      .then(DeliverStablePrevotes(P2))
      .then(DeliverStablePrevotes(P1))
      .then(DeliverStablePrevotes(P3))
      .then(PrecommitStableValue(P3))
      .then(PrecommitStableValue(P1))
      .then(PrecommitStableValue(P2))
      .then(DeliverStablePrecommits)
      .then(DecideStableValue)
      .then(all {
        assert(waitedOnMixed),
        assert(NilPrecommitCertificate),
        assert(stableDecisionMade),
        assert(olderValueLock == Corr),
        assert(Safety),
        Unchanged,
      })
  }
}
