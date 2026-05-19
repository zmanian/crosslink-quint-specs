module CrosslinkSchedulerLivenessModel {
  /*
   Bounded fair-scheduler liveness for nil-precommit resampling.

   The earlier liveness witnesses hard-code one validator/action sequence. This
   model keeps the same concrete Crosslink round machine underneath, but adds a
   small scheduler layer whose validator duties can occur in different orders.

   The scheduler assumption is intentionally explicit: before the stream is
   stable, it eventually obtains a 2f + 1 nil-precommit certificate and advances
   every correct validator to the next round. Once the stream is stable, it
   fairly delivers the proposal, prevotes, and precommits needed for one correct
   validator to decide.
   */

  import CrosslinkResampling(
    Corr = Set("p1", "p2", "p3"),
    Faulty = Set("p4"),
    N = 4,
    T = 1,
    VotingPower = Map("p1" -> 1, "p2" -> 1, "p3" -> 1, "p4" -> 1),
    TotalVotingPower = 4,
    FaultyVotingPowerBound = 1,
    QuorumVotingPower = 3,
    MaxRound = 3,
    Proposer = Map(0 -> "p1", 1 -> "p2", 2 -> "p3", 3 -> "p1"),
    Stream = Map(0 -> "s0", 1 -> "s1", 2 -> "s2", 3 -> "s2"),
    Snapshots = Set("s0", "s1", "s2"),
    StructurallyValid = Map("s0" -> true, "s1" -> true, "s2" -> true),
    PowChainValid = Map("s0" -> true, "s1" -> true, "s2" -> true),
    FinalityCandidateValid = Map("s0" -> true, "s1" -> true, "s2" -> true),
    ResampleOnNilPrecommit = true,
  ).* from "./CrosslinkResampling"

  pure val StableRound = 2
  pure val StableValue = "s2"
  pure val Decider = "p1"
  pure val NilCertSigners = Set("p1", "p2", "p4")

  var burnRound: Round_t
  var nilSeeded: Set[Proc_t]
  var advanced: Set[Proc_t]
  var stableProposalInserted: bool
  var stableProposalDelivered: bool
  var stablePrevoted: Set[Proc_t]
  var stablePrevotesDelivered: Set[Proc_t]
  var stablePrecommitted: Set[Proc_t]
  var stablePrecommitsDelivered: bool
  var schedulerDone: bool

  action SchedulerInit = all {
    Init,
    burnRound' = 0,
    nilSeeded' = Set(),
    advanced' = Set(),
    stableProposalInserted' = false,
    stableProposalDelivered' = false,
    stablePrevoted' = Set(),
    stablePrevotesDelivered' = Set(),
    stablePrecommitted' = Set(),
    stablePrecommitsDelivered' = false,
    schedulerDone' = false,
  }

  action ProtocolUnchanged = all {
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

  action SchedulerUnchanged = all {
    burnRound' = burnRound,
    nilSeeded' = nilSeeded,
    advanced' = advanced,
    stableProposalInserted' = stableProposalInserted,
    stableProposalDelivered' = stableProposalDelivered,
    stablePrevoted' = stablePrevoted,
    stablePrevotesDelivered' = stablePrevotesDelivered,
    stablePrecommitted' = stablePrecommitted,
    stablePrecommitsDelivered' = stablePrecommitsDelivered,
    schedulerDone' = schedulerDone,
  }

  def NilSeedComplete: bool =
    NilCertSigners.subseteq(nilSeeded)

  def StableRoundReached: bool =
    burnRound == StableRound

  action SeedNilSigner(p: Proc_t): bool =
    all {
      burnRound < StableRound,
      NilCertSigners.contains(p),
      not(nilSeeded.contains(p)),
      if (Corr.contains(p)) {
        SeedValidNilPrecommitStateAt(p, burnRound)
      } else {
        SeedFaultyNilPrecommitAt(p, burnRound)
      },
      burnRound' = burnRound,
      nilSeeded' = nilSeeded.union(Set(p)),
      advanced' = advanced,
      stableProposalInserted' = stableProposalInserted,
      stableProposalDelivered' = stableProposalDelivered,
      stablePrevoted' = stablePrevoted,
      stablePrevotesDelivered' = stablePrevotesDelivered,
      stablePrecommitted' = stablePrecommitted,
      stablePrecommitsDelivered' = stablePrecommitsDelivered,
      schedulerDone' = schedulerDone,
    }

  action AdvanceAfterNilCert(p: Proc_t): bool = {
    val advancedNow = advanced.union(Set(p))
    val roundDone = advancedNow == Corr
    all {
      burnRound < StableRound,
      NilSeedComplete,
      Corr.contains(p),
      not(advanced.contains(p)),
      StartNextRoundAfterPrecommitQuorum(p),
      burnRound' = if (roundDone) { burnRound + 1 } else { burnRound },
      nilSeeded' = if (roundDone) { Set() } else { nilSeeded },
      advanced' = if (roundDone) { Set() } else { advancedNow },
      stableProposalInserted' = stableProposalInserted,
      stableProposalDelivered' = stableProposalDelivered,
      stablePrevoted' = stablePrevoted,
      stablePrevotesDelivered' = stablePrevotesDelivered,
      stablePrecommitted' = stablePrecommitted,
      stablePrecommitsDelivered' = stablePrecommitsDelivered,
      schedulerDone' = schedulerDone,
    }
  }

  action InsertStableProposal: bool =
    all {
      StableRoundReached,
      not(stableProposalInserted),
      InsertProposal("p3"),
      burnRound' = burnRound,
      nilSeeded' = nilSeeded,
      advanced' = advanced,
      stableProposalInserted' = true,
      stableProposalDelivered' = stableProposalDelivered,
      stablePrevoted' = stablePrevoted,
      stablePrevotesDelivered' = stablePrevotesDelivered,
      stablePrecommitted' = stablePrecommitted,
      stablePrecommitsDelivered' = stablePrecommitsDelivered,
      schedulerDone' = schedulerDone,
    }

  action DeliverStableProposal: bool =
    all {
      stableProposalInserted,
      not(stableProposalDelivered),
      DeliverProposalToAllCorrect("p3", StableRound, StableValue, NilRound),
      burnRound' = burnRound,
      nilSeeded' = nilSeeded,
      advanced' = advanced,
      stableProposalInserted' = stableProposalInserted,
      stableProposalDelivered' = true,
      stablePrevoted' = stablePrevoted,
      stablePrevotesDelivered' = stablePrevotesDelivered,
      stablePrecommitted' = stablePrecommitted,
      stablePrecommitsDelivered' = stablePrecommitsDelivered,
      schedulerDone' = schedulerDone,
    }

  action PrevoteStableValue(p: Proc_t): bool =
    all {
      stableProposalDelivered,
      Corr.contains(p),
      not(stablePrevoted.contains(p)),
      UponProposalPrevote(p, StableValue),
      burnRound' = burnRound,
      nilSeeded' = nilSeeded,
      advanced' = advanced,
      stableProposalInserted' = stableProposalInserted,
      stableProposalDelivered' = stableProposalDelivered,
      stablePrevoted' = stablePrevoted.union(Set(p)),
      stablePrevotesDelivered' = stablePrevotesDelivered,
      stablePrecommitted' = stablePrecommitted,
      stablePrecommitsDelivered' = stablePrecommitsDelivered,
      schedulerDone' = schedulerDone,
    }

  action DeliverStablePrevotes(p: Proc_t): bool =
    all {
      Corr.subseteq(stablePrevoted),
      Corr.contains(p),
      not(stablePrevotesDelivered.contains(p)),
      DeliverPrevotesTo(p, StableRound, StableValue, Corr),
      burnRound' = burnRound,
      nilSeeded' = nilSeeded,
      advanced' = advanced,
      stableProposalInserted' = stableProposalInserted,
      stableProposalDelivered' = stableProposalDelivered,
      stablePrevoted' = stablePrevoted,
      stablePrevotesDelivered' = stablePrevotesDelivered.union(Set(p)),
      stablePrecommitted' = stablePrecommitted,
      stablePrecommitsDelivered' = stablePrecommitsDelivered,
      schedulerDone' = schedulerDone,
    }

  action PrecommitStableValue(p: Proc_t): bool =
    all {
      stablePrevotesDelivered.contains(p),
      Corr.contains(p),
      not(stablePrecommitted.contains(p)),
      UponValuePrevoteQuorum(p, StableValue),
      burnRound' = burnRound,
      nilSeeded' = nilSeeded,
      advanced' = advanced,
      stableProposalInserted' = stableProposalInserted,
      stableProposalDelivered' = stableProposalDelivered,
      stablePrevoted' = stablePrevoted,
      stablePrevotesDelivered' = stablePrevotesDelivered,
      stablePrecommitted' = stablePrecommitted.union(Set(p)),
      stablePrecommitsDelivered' = stablePrecommitsDelivered,
      schedulerDone' = schedulerDone,
    }

  action DeliverStablePrecommitsToDecider: bool =
    all {
      Corr.subseteq(stablePrecommitted),
      not(stablePrecommitsDelivered),
      DeliverPrecommitsTo(Decider, StableRound, StableValue, Corr),
      burnRound' = burnRound,
      nilSeeded' = nilSeeded,
      advanced' = advanced,
      stableProposalInserted' = stableProposalInserted,
      stableProposalDelivered' = stableProposalDelivered,
      stablePrevoted' = stablePrevoted,
      stablePrevotesDelivered' = stablePrevotesDelivered,
      stablePrecommitted' = stablePrecommitted,
      stablePrecommitsDelivered' = true,
      schedulerDone' = schedulerDone,
    }

  action DecideStableValue: bool =
    all {
      stablePrecommitsDelivered,
      not(schedulerDone),
      Decide(Decider, StableRound, StableValue),
      burnRound' = burnRound,
      nilSeeded' = nilSeeded,
      advanced' = advanced,
      stableProposalInserted' = stableProposalInserted,
      stableProposalDelivered' = stableProposalDelivered,
      stablePrevoted' = stablePrevoted,
      stablePrevotesDelivered' = stablePrevotesDelivered,
      stablePrecommitted' = stablePrecommitted,
      stablePrecommitsDelivered' = stablePrecommitsDelivered,
      schedulerDone' = true,
    }

  action SchedulerStutter: bool =
    all {
      schedulerDone,
      ProtocolUnchanged,
      SchedulerUnchanged,
    }

  action SchedulerStep: bool =
    any {
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
      DeliverStablePrecommitsToDecider,
      DecideStableValue,
      SchedulerStutter,
    }

  val SchedulerStateWellFormed =
    0.to(StableRound).contains(burnRound) and
    nilSeeded.subseteq(NilCertSigners) and
    advanced.subseteq(Corr) and
    stablePrevoted.subseteq(Corr) and
    stablePrevotesDelivered.subseteq(Corr) and
    stablePrecommitted.subseteq(Corr)

  val BurnedRoundsHaveNilCert =
    0.to(StableRound - 1).forall(r =>
      r >= burnRound or NilPrecommitCert(r)
    )

  val SchedulerPhaseOrder =
    (stableProposalInserted implies StableRoundReached) and
    (stableProposalDelivered implies stableProposalInserted) and
    (stablePrevoted != Set() implies stableProposalDelivered) and
    (stablePrevotesDelivered != Set() implies Corr.subseteq(stablePrevoted)) and
    stablePrecommitted.forall(p => stablePrevotesDelivered.contains(p)) and
    (stablePrecommitsDelivered implies Corr.subseteq(stablePrecommitted)) and
    (schedulerDone implies stablePrecommitsDelivered)

  val NoDecisionBeforeStableWindow =
    Corr.forall(p =>
      decision.get(p) == NilSnapshot or (
        stablePrecommitsDelivered and decision.get(p) == StableValue
      )
    )

  val SchedulerDoneMeansStableDecision =
    not(schedulerDone) or decision.get(Decider) == StableValue

  val SchedulerSafety =
    Safety and
    SchedulerStateWellFormed and
    BurnedRoundsHaveNilCert and
    SchedulerPhaseOrder and
    NoDecisionBeforeStableWindow and
    SchedulerDoneMeansStableDecision

  run fairSchedulerBurnsUnstableRoundsUntilStableDecisionTest = {
    SchedulerInit
      .then(SeedNilSigner("p1"))
      .then(SeedNilSigner("p2"))
      .then(SeedNilSigner("p4"))
      .then(AdvanceAfterNilCert("p2"))
      .then(AdvanceAfterNilCert("p1"))
      .then(AdvanceAfterNilCert("p3"))
      .then(SeedNilSigner("p4"))
      .then(SeedNilSigner("p2"))
      .then(SeedNilSigner("p1"))
      .then(AdvanceAfterNilCert("p3"))
      .then(AdvanceAfterNilCert("p1"))
      .then(AdvanceAfterNilCert("p2"))
      .then(InsertStableProposal)
      .then(DeliverStableProposal)
      .then(PrevoteStableValue("p2"))
      .then(PrevoteStableValue("p3"))
      .then(PrevoteStableValue("p1"))
      .then(DeliverStablePrevotes("p3"))
      .then(DeliverStablePrevotes("p1"))
      .then(DeliverStablePrevotes("p2"))
      .then(PrecommitStableValue("p1"))
      .then(PrecommitStableValue("p3"))
      .then(PrecommitStableValue("p2"))
      .then(DeliverStablePrecommitsToDecider)
      .then(DecideStableValue)
      .then(all {
        assert(schedulerDone),
        assert(NilPrecommitCert(0)),
        assert(NilPrecommitCert(1)),
        assert(not(StreamChangedAfter(StableRound))),
        assert(decision.get(Decider) == StableValue),
        assert(SchedulerSafety),
        ProtocolUnchanged,
        SchedulerUnchanged,
      })
  }
}
