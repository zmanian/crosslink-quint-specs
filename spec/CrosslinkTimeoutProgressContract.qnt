module CrosslinkTimeoutProgressContractModel {
  /*
   TLC-friendly temporal contract for timeout-driven nil-precommit recovery.

   The imported round-machine tests check the concrete timeout actions. This
   contract keeps a small progress envelope that captures the liveness shape:
   ordinary timeouts can burn a round without clearing Tendermint lock state,
   a later nil-precommit certificate clears only same-round recovery state, and
   a stable justified proposal can then decide.
   */

  type Proc_t = str

  pure val Corr = Set("p1", "p2", "p3")
  pure val NilCertSigners = Set("p1", "p2", "p4")
  pure val StableRound = 2

  var round: int
  var timeoutPrevoted: Set[Proc_t]
  var timeoutPrecommitted: Set[Proc_t]
  var timeoutAdvanced: Set[Proc_t]
  var olderLock: Set[Proc_t]
  var recoveryRoundState: Set[Proc_t]
  var recoveryCleared: Set[Proc_t]
  var nilSeeded: Set[Proc_t]
  var stableProposalInserted: bool
  var stableProposalDelivered: bool
  var stableProposalJustified: bool
  var stablePrevoted: Set[Proc_t]
  var stablePrevotesDelivered: Set[Proc_t]
  var stablePrecommitted: Set[Proc_t]
  var stablePrecommitsDelivered: bool
  var schedulerDone: bool
  var progress: int

  action Init = all {
    round' = 0,
    timeoutPrevoted' = Set(),
    timeoutPrecommitted' = Set(),
    timeoutAdvanced' = Set(),
    olderLock' = Corr,
    recoveryRoundState' = Set(),
    recoveryCleared' = Set(),
    nilSeeded' = Set(),
    stableProposalInserted' = false,
    stableProposalDelivered' = false,
    stableProposalJustified' = false,
    stablePrevoted' = Set(),
    stablePrevotesDelivered' = Set(),
    stablePrecommitted' = Set(),
    stablePrecommitsDelivered' = false,
    schedulerDone' = false,
    progress' = 0,
  }

  action Unchanged = all {
    round' = round,
    timeoutPrevoted' = timeoutPrevoted,
    timeoutPrecommitted' = timeoutPrecommitted,
    timeoutAdvanced' = timeoutAdvanced,
    olderLock' = olderLock,
    recoveryRoundState' = recoveryRoundState,
    recoveryCleared' = recoveryCleared,
    nilSeeded' = nilSeeded,
    stableProposalInserted' = stableProposalInserted,
    stableProposalDelivered' = stableProposalDelivered,
    stableProposalJustified' = stableProposalJustified,
    stablePrevoted' = stablePrevoted,
    stablePrevotesDelivered' = stablePrevotesDelivered,
    stablePrecommitted' = stablePrecommitted,
    stablePrecommitsDelivered' = stablePrecommitsDelivered,
    schedulerDone' = schedulerDone,
    progress' = progress,
  }

  def TimeoutRoundComplete: bool =
    Corr.subseteq(timeoutAdvanced)

  def RecoveryRoundStateComplete: bool =
    Corr.subseteq(recoveryRoundState.union(recoveryCleared))

  def NilSeedComplete: bool =
    NilCertSigners.subseteq(nilSeeded)

  def RecoveryRoundCleared: bool =
    Corr.subseteq(recoveryCleared)

  def StableRoundReached: bool =
    round == StableRound

  action TimeoutProposePrevoteNil(p: Proc_t): bool =
    all {
      round == 0,
      Corr.contains(p),
      not(timeoutPrevoted.contains(p)),
      round' = round,
      timeoutPrevoted' = timeoutPrevoted.union(Set(p)),
      timeoutPrecommitted' = timeoutPrecommitted,
      timeoutAdvanced' = timeoutAdvanced,
      olderLock' = olderLock,
      recoveryRoundState' = recoveryRoundState,
      recoveryCleared' = recoveryCleared,
      nilSeeded' = nilSeeded,
      stableProposalInserted' = stableProposalInserted,
      stableProposalDelivered' = stableProposalDelivered,
      stableProposalJustified' = stableProposalJustified,
      stablePrevoted' = stablePrevoted,
      stablePrevotesDelivered' = stablePrevotesDelivered,
      stablePrecommitted' = stablePrecommitted,
      stablePrecommitsDelivered' = stablePrecommitsDelivered,
      schedulerDone' = schedulerDone,
      progress' = progress + 1,
    }

  action TimeoutPrevotePrecommitNil(p: Proc_t): bool =
    all {
      round == 0,
      timeoutPrevoted.contains(p),
      not(timeoutPrecommitted.contains(p)),
      round' = round,
      timeoutPrevoted' = timeoutPrevoted,
      timeoutPrecommitted' = timeoutPrecommitted.union(Set(p)),
      timeoutAdvanced' = timeoutAdvanced,
      olderLock' = olderLock,
      recoveryRoundState' = recoveryRoundState,
      recoveryCleared' = recoveryCleared,
      nilSeeded' = nilSeeded,
      stableProposalInserted' = stableProposalInserted,
      stableProposalDelivered' = stableProposalDelivered,
      stableProposalJustified' = stableProposalJustified,
      stablePrevoted' = stablePrevoted,
      stablePrevotesDelivered' = stablePrevotesDelivered,
      stablePrecommitted' = stablePrecommitted,
      stablePrecommitsDelivered' = stablePrecommitsDelivered,
      schedulerDone' = schedulerDone,
      progress' = progress + 1,
    }

  action TimeoutPrecommitStartNextRound(p: Proc_t): bool = {
    val advancedNow = timeoutAdvanced.union(Set(p))
    val timeoutDone = Corr.subseteq(advancedNow)
    all {
      round == 0,
      timeoutPrecommitted.contains(p),
      not(timeoutAdvanced.contains(p)),
      round' = if (timeoutDone) { 1 } else { round },
      timeoutPrevoted' = timeoutPrevoted,
      timeoutPrecommitted' = timeoutPrecommitted,
      timeoutAdvanced' = advancedNow,
      olderLock' = olderLock,
      recoveryRoundState' = recoveryRoundState,
      recoveryCleared' = recoveryCleared,
      nilSeeded' = nilSeeded,
      stableProposalInserted' = stableProposalInserted,
      stableProposalDelivered' = stableProposalDelivered,
      stableProposalJustified' = stableProposalJustified,
      stablePrevoted' = stablePrevoted,
      stablePrevotesDelivered' = stablePrevotesDelivered,
      stablePrecommitted' = stablePrecommitted,
      stablePrecommitsDelivered' = stablePrecommitsDelivered,
      schedulerDone' = schedulerDone,
      progress' = progress + 1,
    }
  }

  action SeedRecoveryRoundState(p: Proc_t): bool =
    all {
      round == 1,
      Corr.contains(p),
      not(recoveryRoundState.contains(p)),
      not(recoveryCleared.contains(p)),
      round' = round,
      timeoutPrevoted' = timeoutPrevoted,
      timeoutPrecommitted' = timeoutPrecommitted,
      timeoutAdvanced' = timeoutAdvanced,
      olderLock' = olderLock,
      recoveryRoundState' = recoveryRoundState.union(Set(p)),
      recoveryCleared' = recoveryCleared,
      nilSeeded' = nilSeeded,
      stableProposalInserted' = stableProposalInserted,
      stableProposalDelivered' = stableProposalDelivered,
      stableProposalJustified' = stableProposalJustified,
      stablePrevoted' = stablePrevoted,
      stablePrevotesDelivered' = stablePrevotesDelivered,
      stablePrecommitted' = stablePrecommitted,
      stablePrecommitsDelivered' = stablePrecommitsDelivered,
      schedulerDone' = schedulerDone,
      progress' = progress + 1,
    }

  action SeedNilSigner(p: Proc_t): bool =
    all {
      round == 1,
      RecoveryRoundStateComplete,
      NilCertSigners.contains(p),
      not(nilSeeded.contains(p)),
      round' = round,
      timeoutPrevoted' = timeoutPrevoted,
      timeoutPrecommitted' = timeoutPrecommitted,
      timeoutAdvanced' = timeoutAdvanced,
      olderLock' = olderLock,
      recoveryRoundState' = recoveryRoundState,
      recoveryCleared' = recoveryCleared,
      nilSeeded' = nilSeeded.union(Set(p)),
      stableProposalInserted' = stableProposalInserted,
      stableProposalDelivered' = stableProposalDelivered,
      stableProposalJustified' = stableProposalJustified,
      stablePrevoted' = stablePrevoted,
      stablePrevotesDelivered' = stablePrevotesDelivered,
      stablePrecommitted' = stablePrecommitted,
      stablePrecommitsDelivered' = stablePrecommitsDelivered,
      schedulerDone' = schedulerDone,
      progress' = progress + 1,
    }

  action AdvanceAfterNilCert(p: Proc_t): bool = {
    val clearedNow = recoveryCleared.union(Set(p))
    val recoveryDone = Corr.subseteq(clearedNow)
    all {
      round == 1,
      NilSeedComplete,
      recoveryRoundState.contains(p),
      not(recoveryCleared.contains(p)),
      round' = if (recoveryDone) { StableRound } else { round },
      timeoutPrevoted' = timeoutPrevoted,
      timeoutPrecommitted' = timeoutPrecommitted,
      timeoutAdvanced' = timeoutAdvanced,
      olderLock' = olderLock,
      recoveryRoundState' = recoveryRoundState.exclude(Set(p)),
      recoveryCleared' = clearedNow,
      nilSeeded' = nilSeeded,
      stableProposalInserted' = stableProposalInserted,
      stableProposalDelivered' = stableProposalDelivered,
      stableProposalJustified' = stableProposalJustified,
      stablePrevoted' = stablePrevoted,
      stablePrevotesDelivered' = stablePrevotesDelivered,
      stablePrecommitted' = stablePrecommitted,
      stablePrecommitsDelivered' = stablePrecommitsDelivered,
      schedulerDone' = schedulerDone,
      progress' = progress + 1,
    }
  }

  action InsertStableProposal: bool =
    all {
      StableRoundReached,
      RecoveryRoundCleared,
      not(stableProposalInserted),
      round' = round,
      timeoutPrevoted' = timeoutPrevoted,
      timeoutPrecommitted' = timeoutPrecommitted,
      timeoutAdvanced' = timeoutAdvanced,
      olderLock' = olderLock,
      recoveryRoundState' = recoveryRoundState,
      recoveryCleared' = recoveryCleared,
      nilSeeded' = nilSeeded,
      stableProposalInserted' = true,
      stableProposalDelivered' = stableProposalDelivered,
      stableProposalJustified' = true,
      stablePrevoted' = stablePrevoted,
      stablePrevotesDelivered' = stablePrevotesDelivered,
      stablePrecommitted' = stablePrecommitted,
      stablePrecommitsDelivered' = stablePrecommitsDelivered,
      schedulerDone' = schedulerDone,
      progress' = progress + 1,
    }

  action DeliverStableProposal: bool =
    all {
      stableProposalInserted,
      not(stableProposalDelivered),
      round' = round,
      timeoutPrevoted' = timeoutPrevoted,
      timeoutPrecommitted' = timeoutPrecommitted,
      timeoutAdvanced' = timeoutAdvanced,
      olderLock' = olderLock,
      recoveryRoundState' = recoveryRoundState,
      recoveryCleared' = recoveryCleared,
      nilSeeded' = nilSeeded,
      stableProposalInserted' = stableProposalInserted,
      stableProposalDelivered' = true,
      stableProposalJustified' = stableProposalJustified,
      stablePrevoted' = stablePrevoted,
      stablePrevotesDelivered' = stablePrevotesDelivered,
      stablePrecommitted' = stablePrecommitted,
      stablePrecommitsDelivered' = stablePrecommitsDelivered,
      schedulerDone' = schedulerDone,
      progress' = progress + 1,
    }

  action PrevoteStableValue(p: Proc_t): bool =
    all {
      stableProposalDelivered,
      stableProposalJustified,
      Corr.contains(p),
      not(stablePrevoted.contains(p)),
      round' = round,
      timeoutPrevoted' = timeoutPrevoted,
      timeoutPrecommitted' = timeoutPrecommitted,
      timeoutAdvanced' = timeoutAdvanced,
      olderLock' = olderLock,
      recoveryRoundState' = recoveryRoundState,
      recoveryCleared' = recoveryCleared,
      nilSeeded' = nilSeeded,
      stableProposalInserted' = stableProposalInserted,
      stableProposalDelivered' = stableProposalDelivered,
      stableProposalJustified' = stableProposalJustified,
      stablePrevoted' = stablePrevoted.union(Set(p)),
      stablePrevotesDelivered' = stablePrevotesDelivered,
      stablePrecommitted' = stablePrecommitted,
      stablePrecommitsDelivered' = stablePrecommitsDelivered,
      schedulerDone' = schedulerDone,
      progress' = progress + 1,
    }

  action DeliverStablePrevotes(p: Proc_t): bool =
    all {
      Corr.subseteq(stablePrevoted),
      Corr.contains(p),
      not(stablePrevotesDelivered.contains(p)),
      round' = round,
      timeoutPrevoted' = timeoutPrevoted,
      timeoutPrecommitted' = timeoutPrecommitted,
      timeoutAdvanced' = timeoutAdvanced,
      olderLock' = olderLock,
      recoveryRoundState' = recoveryRoundState,
      recoveryCleared' = recoveryCleared,
      nilSeeded' = nilSeeded,
      stableProposalInserted' = stableProposalInserted,
      stableProposalDelivered' = stableProposalDelivered,
      stableProposalJustified' = stableProposalJustified,
      stablePrevoted' = stablePrevoted,
      stablePrevotesDelivered' = stablePrevotesDelivered.union(Set(p)),
      stablePrecommitted' = stablePrecommitted,
      stablePrecommitsDelivered' = stablePrecommitsDelivered,
      schedulerDone' = schedulerDone,
      progress' = progress + 1,
    }

  action PrecommitStableValue(p: Proc_t): bool =
    all {
      stablePrevotesDelivered.contains(p),
      Corr.contains(p),
      not(stablePrecommitted.contains(p)),
      round' = round,
      timeoutPrevoted' = timeoutPrevoted,
      timeoutPrecommitted' = timeoutPrecommitted,
      timeoutAdvanced' = timeoutAdvanced,
      olderLock' = olderLock,
      recoveryRoundState' = recoveryRoundState,
      recoveryCleared' = recoveryCleared,
      nilSeeded' = nilSeeded,
      stableProposalInserted' = stableProposalInserted,
      stableProposalDelivered' = stableProposalDelivered,
      stableProposalJustified' = stableProposalJustified,
      stablePrevoted' = stablePrevoted,
      stablePrevotesDelivered' = stablePrevotesDelivered,
      stablePrecommitted' = stablePrecommitted.union(Set(p)),
      stablePrecommitsDelivered' = stablePrecommitsDelivered,
      schedulerDone' = schedulerDone,
      progress' = progress + 1,
    }

  action DeliverStablePrecommits: bool =
    all {
      Corr.subseteq(stablePrecommitted),
      not(stablePrecommitsDelivered),
      round' = round,
      timeoutPrevoted' = timeoutPrevoted,
      timeoutPrecommitted' = timeoutPrecommitted,
      timeoutAdvanced' = timeoutAdvanced,
      olderLock' = olderLock,
      recoveryRoundState' = recoveryRoundState,
      recoveryCleared' = recoveryCleared,
      nilSeeded' = nilSeeded,
      stableProposalInserted' = stableProposalInserted,
      stableProposalDelivered' = stableProposalDelivered,
      stableProposalJustified' = stableProposalJustified,
      stablePrevoted' = stablePrevoted,
      stablePrevotesDelivered' = stablePrevotesDelivered,
      stablePrecommitted' = stablePrecommitted,
      stablePrecommitsDelivered' = true,
      schedulerDone' = schedulerDone,
      progress' = progress + 1,
    }

  action DecideStableValue: bool =
    all {
      stablePrecommitsDelivered,
      not(schedulerDone),
      round' = round,
      timeoutPrevoted' = timeoutPrevoted,
      timeoutPrecommitted' = timeoutPrecommitted,
      timeoutAdvanced' = timeoutAdvanced,
      olderLock' = olderLock,
      recoveryRoundState' = recoveryRoundState,
      recoveryCleared' = recoveryCleared,
      nilSeeded' = nilSeeded,
      stableProposalInserted' = stableProposalInserted,
      stableProposalDelivered' = stableProposalDelivered,
      stableProposalJustified' = stableProposalJustified,
      stablePrevoted' = stablePrevoted,
      stablePrevotesDelivered' = stablePrevotesDelivered,
      stablePrecommitted' = stablePrecommitted,
      stablePrecommitsDelivered' = stablePrecommitsDelivered,
      schedulerDone' = true,
      progress' = progress + 1,
    }

  action StutterAfterDone: bool =
    all {
      schedulerDone,
      Unchanged,
    }

  action Next: bool =
    any {
      nondet p = oneOf(Corr)
      TimeoutProposePrevoteNil(p),
      nondet p = oneOf(Corr)
      TimeoutPrevotePrecommitNil(p),
      nondet p = oneOf(Corr)
      TimeoutPrecommitStartNextRound(p),
      nondet p = oneOf(Corr)
      SeedRecoveryRoundState(p),
      nondet p = oneOf(NilCertSigners)
      SeedNilSigner(p),
      nondet p = oneOf(Corr)
      AdvanceAfterNilCert(p),
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
      StutterAfterDone,
    }

  val StateWellFormed =
    0.to(StableRound).contains(round) and
    0.to(35).contains(progress) and
    timeoutPrevoted.subseteq(Corr) and
    timeoutPrecommitted.subseteq(Corr) and
    timeoutAdvanced.subseteq(Corr) and
    olderLock == Corr and
    recoveryRoundState.subseteq(Corr) and
    recoveryCleared.subseteq(Corr) and
    nilSeeded.subseteq(NilCertSigners) and
    stablePrevoted.subseteq(Corr) and
    stablePrevotesDelivered.subseteq(Corr) and
    stablePrecommitted.subseteq(Corr)

  val TimeoutPhaseOrder =
    timeoutPrecommitted.subseteq(timeoutPrevoted) and
    timeoutAdvanced.subseteq(timeoutPrecommitted) and
    (round > 0 implies TimeoutRoundComplete) and
    (recoveryRoundState != Set() implies round >= 1) and
    (recoveryCleared != Set() implies NilSeedComplete) and
    recoveryRoundState.intersect(recoveryCleared) == Set()

  val StablePhaseOrder =
    (stableProposalInserted implies StableRoundReached) and
    (stableProposalInserted implies RecoveryRoundCleared) and
    (stableProposalDelivered implies stableProposalInserted) and
    (stableProposalDelivered implies stableProposalJustified) and
    (stablePrevoted != Set() implies stableProposalDelivered) and
    (stablePrevotesDelivered != Set() implies Corr.subseteq(stablePrevoted)) and
    stablePrecommitted.forall(p => stablePrevotesDelivered.contains(p)) and
    (stablePrecommitsDelivered implies Corr.subseteq(stablePrecommitted)) and
    (schedulerDone implies stablePrecommitsDelivered)

  val NilUnlockDiscipline =
    (not(NilSeedComplete) implies recoveryCleared == Set()) and
    (stablePrevoted != Set() implies RecoveryRoundCleared) and
    (schedulerDone implies RecoveryRoundCleared) and
    (schedulerDone implies olderLock == Corr) and
    (schedulerDone implies stableProposalJustified)

  val Safety =
    StateWellFormed and TimeoutPhaseOrder and StablePhaseOrder and NilUnlockDiscipline

  temporal EventuallyTimeoutRecoveryDecides =
    Next.weakFair(Set(progress)).implies(eventually(schedulerDone))

  run timeoutRoundDoesNotClearTendermintLockTest = {
    Init
      .then(TimeoutProposePrevoteNil("p1"))
      .then(TimeoutProposePrevoteNil("p2"))
      .then(TimeoutProposePrevoteNil("p3"))
      .then(TimeoutPrevotePrecommitNil("p1"))
      .then(TimeoutPrevotePrecommitNil("p2"))
      .then(TimeoutPrevotePrecommitNil("p3"))
      .then(TimeoutPrecommitStartNextRound("p2"))
      .then(TimeoutPrecommitStartNextRound("p1"))
      .then(TimeoutPrecommitStartNextRound("p3"))
      .then(all {
        assert(round == 1),
        assert(olderLock == Corr),
        assert(recoveryCleared == Set()),
        assert(Safety),
        Unchanged,
      })
  }

  run nilCertificateClearsOnlyRecoveryRoundStateTest = {
    Init
      .then(TimeoutProposePrevoteNil("p1"))
      .then(TimeoutProposePrevoteNil("p2"))
      .then(TimeoutProposePrevoteNil("p3"))
      .then(TimeoutPrevotePrecommitNil("p1"))
      .then(TimeoutPrevotePrecommitNil("p2"))
      .then(TimeoutPrevotePrecommitNil("p3"))
      .then(TimeoutPrecommitStartNextRound("p1"))
      .then(TimeoutPrecommitStartNextRound("p2"))
      .then(TimeoutPrecommitStartNextRound("p3"))
      .then(SeedRecoveryRoundState("p1"))
      .then(SeedRecoveryRoundState("p2"))
      .then(SeedRecoveryRoundState("p3"))
      .then(SeedNilSigner("p1"))
      .then(SeedNilSigner("p2"))
      .then(SeedNilSigner("p4"))
      .then(AdvanceAfterNilCert("p3"))
      .then(AdvanceAfterNilCert("p1"))
      .then(AdvanceAfterNilCert("p2"))
      .then(all {
        assert(StableRoundReached),
        assert(RecoveryRoundCleared),
        assert(recoveryRoundState == Set()),
        assert(olderLock == Corr),
        assert(Safety),
        Unchanged,
      })
  }

  run timeoutRecoveryStableDecisionTest = {
    Init
      .then(TimeoutProposePrevoteNil("p2"))
      .then(TimeoutProposePrevoteNil("p1"))
      .then(TimeoutProposePrevoteNil("p3"))
      .then(TimeoutPrevotePrecommitNil("p3"))
      .then(TimeoutPrevotePrecommitNil("p1"))
      .then(TimeoutPrevotePrecommitNil("p2"))
      .then(TimeoutPrecommitStartNextRound("p3"))
      .then(TimeoutPrecommitStartNextRound("p2"))
      .then(TimeoutPrecommitStartNextRound("p1"))
      .then(SeedRecoveryRoundState("p2"))
      .then(SeedRecoveryRoundState("p3"))
      .then(SeedRecoveryRoundState("p1"))
      .then(SeedNilSigner("p4"))
      .then(SeedNilSigner("p2"))
      .then(SeedNilSigner("p1"))
      .then(AdvanceAfterNilCert("p2"))
      .then(AdvanceAfterNilCert("p1"))
      .then(AdvanceAfterNilCert("p3"))
      .then(InsertStableProposal)
      .then(DeliverStableProposal)
      .then(PrevoteStableValue("p3"))
      .then(PrevoteStableValue("p1"))
      .then(PrevoteStableValue("p2"))
      .then(DeliverStablePrevotes("p1"))
      .then(DeliverStablePrevotes("p2"))
      .then(DeliverStablePrevotes("p3"))
      .then(PrecommitStableValue("p2"))
      .then(PrecommitStableValue("p3"))
      .then(PrecommitStableValue("p1"))
      .then(DeliverStablePrecommits)
      .then(DecideStableValue)
      .then(all {
        assert(schedulerDone),
        assert(olderLock == Corr),
        assert(RecoveryRoundCleared),
        assert(stableProposalJustified),
        assert(Safety),
        Unchanged,
      })
  }
}
