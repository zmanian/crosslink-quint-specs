module CrosslinkSchedulerProgressContractModel {
  /*
   Temporal progress contract for the nil-precommit resampling scheduler.

   CrosslinkSchedulerLiveness.qnt composes this scheduler shape with the
   protocol round machine. Current Quint/TLC and Quint/Apalache temporal
   backends have trouble with that full imported state. This small contract
   keeps only the scheduler envelope, so the temporal liveness obligation can
   be checked directly while the composed model keeps the protocol safety
   obligations.
   */

  type Proc_t = str

  pure val Corr = Set("p1", "p2", "p3")
  pure val NilCertSigners = Set("p1", "p2", "p4")
  pure val StableRound = 2

  var burnRound: int
  var nilSeeded: Set[Proc_t]
  var advanced: Set[Proc_t]
  var stableProposalInserted: bool
  var stableProposalDelivered: bool
  var stablePrevoted: Set[Proc_t]
  var stablePrevotesDelivered: Set[Proc_t]
  var stablePrecommitted: Set[Proc_t]
  var stablePrecommitsDelivered: bool
  var schedulerDone: bool
  var progress: int

  action Init = all {
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
    progress' = 0,
  }

  action Unchanged = all {
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
    progress' = progress,
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
      progress' = progress + 1,
    }

  action AdvanceAfterNilCert(p: Proc_t): bool = {
    val advancedNow = advanced.union(Set(p))
    val roundDone = advancedNow == Corr
    all {
      burnRound < StableRound,
      NilSeedComplete,
      Corr.contains(p),
      not(advanced.contains(p)),
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
      progress' = progress + 1,
    }
  }

  action InsertStableProposal: bool =
    all {
      StableRoundReached,
      not(stableProposalInserted),
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
      progress' = progress + 1,
    }

  action DeliverStableProposal: bool =
    all {
      stableProposalInserted,
      not(stableProposalDelivered),
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
      progress' = progress + 1,
    }

  action PrevoteStableValue(p: Proc_t): bool =
    all {
      stableProposalDelivered,
      Corr.contains(p),
      not(stablePrevoted.contains(p)),
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
      progress' = progress + 1,
    }

  action DeliverStablePrevotes(p: Proc_t): bool =
    all {
      Corr.subseteq(stablePrevoted),
      Corr.contains(p),
      not(stablePrevotesDelivered.contains(p)),
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
      progress' = progress + 1,
    }

  action PrecommitStableValue(p: Proc_t): bool =
    all {
      stablePrevotesDelivered.contains(p),
      Corr.contains(p),
      not(stablePrecommitted.contains(p)),
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
      progress' = progress + 1,
    }

  action DeliverStablePrecommits: bool =
    all {
      Corr.subseteq(stablePrecommitted),
      not(stablePrecommitsDelivered),
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
      progress' = progress + 1,
    }

  action DecideStableValue: bool =
    all {
      stablePrecommitsDelivered,
      not(schedulerDone),
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
      progress' = progress + 1,
    }

  action StutterAfterDone: bool =
    all {
      schedulerDone,
      Unchanged,
    }

  action Next: bool =
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
      DeliverStablePrecommits,
      DecideStableValue,
      StutterAfterDone,
    }

  val StateWellFormed =
    0.to(StableRound).contains(burnRound) and
    0.to(25).contains(progress) and
    nilSeeded.subseteq(NilCertSigners) and
    advanced.subseteq(Corr) and
    stablePrevoted.subseteq(Corr) and
    stablePrevotesDelivered.subseteq(Corr) and
    stablePrecommitted.subseteq(Corr)

  val PhaseOrder =
    (stableProposalInserted implies StableRoundReached) and
    (stableProposalDelivered implies stableProposalInserted) and
    (stablePrevoted != Set() implies stableProposalDelivered) and
    (stablePrevotesDelivered != Set() implies Corr.subseteq(stablePrevoted)) and
    stablePrecommitted.forall(p => stablePrevotesDelivered.contains(p)) and
    (stablePrecommitsDelivered implies Corr.subseteq(stablePrecommitted)) and
    (schedulerDone implies stablePrecommitsDelivered)

  val Safety =
    StateWellFormed and PhaseOrder

  temporal EventuallyStableDecision =
    Next.weakFair(Set(progress)).implies(eventually(schedulerDone))

  run fairSchedulerProgressContractTest = {
    Init
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
      .then(DeliverStablePrecommits)
      .then(DecideStableValue)
      .then(all {
        assert(schedulerDone),
        assert(Safety),
        Unchanged,
      })
  }
}
