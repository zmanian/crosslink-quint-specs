module CrosslinkComposedProgressContractModel {
  /*
   TLC-friendly temporal contract for nil-resampling plus finality.

   CrosslinkSchedulerProgressContract.qnt proves eventual entry into the stable
   decision phase for the scheduler envelope. This contract adds the finality
   cursor shape from CrosslinkComposed.qnt without importing the full round
   machine: after finitely many nil-precommit-burned rounds, a stable stream
   window can decide a value, and a fair finality applier eventually advances
   the finalized PoW prefix to that decided value.
   */

  type Proc_t = str
  type Snapshot_t = str
  type Height_t = int
  type Block_t = str

  pure val Corr = Set("p1", "p2", "p3")
  pure val NilCertSigners = Set("p1", "p2", "p4")
  pure val StableRound = 2
  pure val InitialFinalized = "g"
  pure val StableValue = "a2"
  pure val StableTip = "a3"
  pure val ForkValue = "b2"
  pure val Snapshots = Set("g", "a1", "a2", "a3", "b1", "b2", "b3")
  pure val MaxHeight = 3
  pure val Sigma = 1
  pure val Heights = 0.to(MaxHeight)
  pure val HeightOf = Map(
    "g" -> 0,
    "a1" -> 1,
    "a2" -> 2,
    "a3" -> 3,
    "b1" -> 1,
    "b2" -> 2,
    "b3" -> 3,
  )
  pure val AncestorAt = Map(
    "g" -> Map(0 -> "g", 1 -> "None", 2 -> "None", 3 -> "None"),
    "a1" -> Map(0 -> "g", 1 -> "a1", 2 -> "None", 3 -> "None"),
    "a2" -> Map(0 -> "g", 1 -> "a1", 2 -> "a2", 3 -> "None"),
    "a3" -> Map(0 -> "g", 1 -> "a1", 2 -> "a2", 3 -> "a3"),
    "b1" -> Map(0 -> "g", 1 -> "b1", 2 -> "None", 3 -> "None"),
    "b2" -> Map(0 -> "g", 1 -> "b1", 2 -> "b2", 3 -> "None"),
    "b3" -> Map(0 -> "g", 1 -> "b1", 2 -> "b2", 3 -> "b3"),
  )

  var burnRound: int
  var nilSeeded: Set[Proc_t]
  var advanced: Set[Proc_t]
  var stableProposalInserted: bool
  var stableProposalDelivered: bool
  var stablePrevoted: Set[Proc_t]
  var stablePrevotesDelivered: Set[Proc_t]
  var stablePrecommitted: Set[Proc_t]
  var stablePrecommitsDelivered: bool
  var stableDecisionMade: bool
  var latestFinal: Snapshot_t
  var finalized: Set[Snapshot_t]
  var progress: int

  def IsSnapshot(v: Snapshot_t): bool =
    Snapshots.contains(v)

  def Height(v: Snapshot_t): Height_t =
    HeightOf.get(v)

  def BlockAt(v: Snapshot_t, h: Height_t): Block_t =
    AncestorAt.get(v).get(h)

  def Extends(newer: Snapshot_t, older: Snapshot_t): bool =
    IsSnapshot(newer) and
    IsSnapshot(older) and
    Height(newer) >= Height(older) and
    Heights.forall(h =>
      h > Height(older) or BlockAt(newer, h) == BlockAt(older, h)
    )

  def Agrees(a: Snapshot_t, b: Snapshot_t): bool =
    Extends(a, b) or Extends(b, a)

  def TailConfirms(tip: Snapshot_t, candidate: Snapshot_t): bool =
    IsSnapshot(tip) and
    IsSnapshot(candidate) and
    Height(tip) >= Height(candidate) + Sigma and
    BlockAt(tip, Height(candidate)) == BlockAt(candidate, Height(candidate))

  def ValidFinalityCandidate(candidate: Snapshot_t, tip: Snapshot_t): bool =
    Extends(candidate, latestFinal) and
    Height(candidate) > Height(latestFinal) and
    TailConfirms(tip, candidate)

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
    stableDecisionMade' = false,
    latestFinal' = InitialFinalized,
    finalized' = Set(InitialFinalized),
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
    stableDecisionMade' = stableDecisionMade,
    latestFinal' = latestFinal,
    finalized' = finalized,
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
      stableDecisionMade' = stableDecisionMade,
      latestFinal' = latestFinal,
      finalized' = finalized,
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
      stableDecisionMade' = stableDecisionMade,
      latestFinal' = latestFinal,
      finalized' = finalized,
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
      stableDecisionMade' = stableDecisionMade,
      latestFinal' = latestFinal,
      finalized' = finalized,
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
      stableDecisionMade' = stableDecisionMade,
      latestFinal' = latestFinal,
      finalized' = finalized,
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
      stableDecisionMade' = stableDecisionMade,
      latestFinal' = latestFinal,
      finalized' = finalized,
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
      stableDecisionMade' = stableDecisionMade,
      latestFinal' = latestFinal,
      finalized' = finalized,
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
      stableDecisionMade' = stableDecisionMade,
      latestFinal' = latestFinal,
      finalized' = finalized,
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
      stableDecisionMade' = stableDecisionMade,
      latestFinal' = latestFinal,
      finalized' = finalized,
      progress' = progress + 1,
    }

  action DecideStableValue: bool =
    all {
      stablePrecommitsDelivered,
      not(stableDecisionMade),
      burnRound' = burnRound,
      nilSeeded' = nilSeeded,
      advanced' = advanced,
      stableProposalInserted' = stableProposalInserted,
      stableProposalDelivered' = stableProposalDelivered,
      stablePrevoted' = stablePrevoted,
      stablePrevotesDelivered' = stablePrevotesDelivered,
      stablePrecommitted' = stablePrecommitted,
      stablePrecommitsDelivered' = stablePrecommitsDelivered,
      stableDecisionMade' = true,
      latestFinal' = latestFinal,
      finalized' = finalized,
      progress' = progress + 1,
    }

  action FinalizeStableDecision: bool =
    all {
      stableDecisionMade,
      not(finalized.contains(StableValue)),
      ValidFinalityCandidate(StableValue, StableTip),
      burnRound' = burnRound,
      nilSeeded' = nilSeeded,
      advanced' = advanced,
      stableProposalInserted' = stableProposalInserted,
      stableProposalDelivered' = stableProposalDelivered,
      stablePrevoted' = stablePrevoted,
      stablePrevotesDelivered' = stablePrevotesDelivered,
      stablePrecommitted' = stablePrecommitted,
      stablePrecommitsDelivered' = stablePrecommitsDelivered,
      stableDecisionMade' = stableDecisionMade,
      latestFinal' = StableValue,
      finalized' = finalized.union(Set(StableValue)),
      progress' = progress + 1,
    }

  action StutterAfterFinalized: bool =
    all {
      finalized.contains(StableValue),
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
      FinalizeStableDecision,
      StutterAfterFinalized,
    }

  val SchedulerStateWellFormed =
    0.to(StableRound).contains(burnRound) and
    0.to(30).contains(progress) and
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
    (stableDecisionMade implies stablePrecommitsDelivered) and
    (finalized.contains(StableValue) implies stableDecisionMade)

  val FinalizedPrefixLinear =
    tuples(finalized, finalized).forall(((a, b)) =>
      Agrees(a, b)
    )

  val LatestFinalExtendsAllFinalized =
    finalized.forall(v => Extends(latestFinal, v))

  val StableDecisionFinalizesOnlyValidCandidate =
    not(finalized.contains(StableValue)) or
    ValidFinalityCandidate(StableValue, StableTip) or latestFinal == StableValue

  val ForkValueNotFinalized =
    not(finalized.contains(ForkValue))

  val Safety =
    SchedulerStateWellFormed and
    PhaseOrder and
    FinalizedPrefixLinear and
    LatestFinalExtendsAllFinalized and
    StableDecisionFinalizesOnlyValidCandidate and
    ForkValueNotFinalized

  temporal EventuallyFinalizesStableDecision =
    Next.weakFair(Set(progress)).implies(eventually(finalized.contains(StableValue)))

  run fairComposedProgressFinalizesStableDecisionTest = {
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
      .then(FinalizeStableDecision)
      .then(all {
        assert(stableDecisionMade),
        assert(finalized.contains(StableValue)),
        assert(latestFinal == StableValue),
        assert(Safety),
        Unchanged,
      })
  }
}
