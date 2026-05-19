module CrosslinkBaselineChurnProgressContractModel {
  /*
   TLC-friendly baseline-vs-resampling churn contract.

   Baseline Crosslink carries sticky proposal/lock state across rounds. When
   the sampled PoW stream changes, the baseline path can be stuck with a stale
   value while the fresh stream has moved on. Nil-precommit resampling is the
   intended recovery: a quorum of nil precommits burns the unstable rounds,
   clears same-round recovery state, and then a stable stream window decides.
   */

  type Proc_t = str
  type Snapshot_t = str

  pure val Corr = Set("p1", "p2", "p3")
  pure val NilCertSigners = Set("p1", "p2", "p4")
  pure val StableRound = 2
  pure val InitialStickyValue = "s0"
  pure val FreshRoundValue = "s1"
  pure val StableValue = "s2"
  pure val Snapshots = Set("s0", "s1", "s2")
  pure val Stream = Map(
    0 -> InitialStickyValue,
    1 -> FreshRoundValue,
    2 -> StableValue,
  )

  var baselineRound: int
  var baselineCachedValue: Snapshot_t
  var baselineLockedValue: Snapshot_t
  var baselineHalted: bool
  var burnRound: int
  var nilSeeded: Set[Proc_t]
  var advanced: Set[Proc_t]
  var stableProposalInserted: bool
  var stableProposalDelivered: bool
  var stablePrevoted: Set[Proc_t]
  var stablePrevotesDelivered: Set[Proc_t]
  var stablePrecommitted: Set[Proc_t]
  var stablePrecommitsDelivered: bool
  var resamplingDecisionMade: bool
  var progress: int

  pure def StreamAt(round: int): Snapshot_t =
    Stream.get(round)

  def BaselineStickySampleIsStaleAtRound(round: int): bool =
    0.to(StableRound).contains(round) and
    Snapshots.contains(baselineCachedValue) and
    baselineCachedValue != StreamAt(round)

  def BaselineFreshValueBlockedAtRound(round: int): bool =
    BaselineStickySampleIsStaleAtRound(round) and
    baselineLockedValue == baselineCachedValue and
    baselineLockedValue != StreamAt(round)

  def NilSeedComplete: bool =
    NilCertSigners.subseteq(nilSeeded)

  def StableRoundReached: bool =
    burnRound == StableRound

  action Init = all {
    baselineRound' = 0,
    baselineCachedValue' = InitialStickyValue,
    baselineLockedValue' = InitialStickyValue,
    baselineHalted' = false,
    burnRound' = 0,
    nilSeeded' = Set(),
    advanced' = Set(),
    stableProposalInserted' = false,
    stableProposalDelivered' = false,
    stablePrevoted' = Set(),
    stablePrevotesDelivered' = Set(),
    stablePrecommitted' = Set(),
    stablePrecommitsDelivered' = false,
    resamplingDecisionMade' = false,
    progress' = 0,
  }

  action Unchanged = all {
    baselineRound' = baselineRound,
    baselineCachedValue' = baselineCachedValue,
    baselineLockedValue' = baselineLockedValue,
    baselineHalted' = baselineHalted,
    burnRound' = burnRound,
    nilSeeded' = nilSeeded,
    advanced' = advanced,
    stableProposalInserted' = stableProposalInserted,
    stableProposalDelivered' = stableProposalDelivered,
    stablePrevoted' = stablePrevoted,
    stablePrevotesDelivered' = stablePrevotesDelivered,
    stablePrecommitted' = stablePrecommitted,
    stablePrecommitsDelivered' = stablePrecommitsDelivered,
    resamplingDecisionMade' = resamplingDecisionMade,
    progress' = progress,
  }

  action BaselineCarryStickyStateAndHalt: bool =
    all {
      not(baselineHalted),
      baselineRound == 0,
      baselineCachedValue == InitialStickyValue,
      baselineLockedValue == InitialStickyValue,
      StreamAt(1) == FreshRoundValue,
      BaselineFreshValueBlockedAtRound(1),
      baselineRound' = 1,
      baselineCachedValue' = baselineCachedValue,
      baselineLockedValue' = baselineLockedValue,
      baselineHalted' = true,
      burnRound' = burnRound,
      nilSeeded' = nilSeeded,
      advanced' = advanced,
      stableProposalInserted' = stableProposalInserted,
      stableProposalDelivered' = stableProposalDelivered,
      stablePrevoted' = stablePrevoted,
      stablePrevotesDelivered' = stablePrevotesDelivered,
      stablePrecommitted' = stablePrecommitted,
      stablePrecommitsDelivered' = stablePrecommitsDelivered,
      resamplingDecisionMade' = resamplingDecisionMade,
      progress' = progress + 1,
    }

  action SeedNilSigner(p: Proc_t): bool =
    all {
      baselineHalted,
      burnRound < StableRound,
      NilCertSigners.contains(p),
      not(nilSeeded.contains(p)),
      baselineRound' = baselineRound,
      baselineCachedValue' = baselineCachedValue,
      baselineLockedValue' = baselineLockedValue,
      baselineHalted' = baselineHalted,
      burnRound' = burnRound,
      nilSeeded' = nilSeeded.union(Set(p)),
      advanced' = advanced,
      stableProposalInserted' = stableProposalInserted,
      stableProposalDelivered' = stableProposalDelivered,
      stablePrevoted' = stablePrevoted,
      stablePrevotesDelivered' = stablePrevotesDelivered,
      stablePrecommitted' = stablePrecommitted,
      stablePrecommitsDelivered' = stablePrecommitsDelivered,
      resamplingDecisionMade' = resamplingDecisionMade,
      progress' = progress + 1,
    }

  action AdvanceAfterNilCert(p: Proc_t): bool = {
    val advancedNow = advanced.union(Set(p))
    val roundDone = advancedNow == Corr
    all {
      baselineHalted,
      burnRound < StableRound,
      NilSeedComplete,
      Corr.contains(p),
      not(advanced.contains(p)),
      baselineRound' = baselineRound,
      baselineCachedValue' = baselineCachedValue,
      baselineLockedValue' = baselineLockedValue,
      baselineHalted' = baselineHalted,
      burnRound' = if (roundDone) { burnRound + 1 } else { burnRound },
      nilSeeded' = if (roundDone) { Set() } else { nilSeeded },
      advanced' = if (roundDone) { Set() } else { advancedNow },
      stableProposalInserted' = stableProposalInserted,
      stableProposalDelivered' = stableProposalDelivered,
      stablePrevoted' = stablePrevoted,
      stablePrevotesDelivered' = stablePrevotesDelivered,
      stablePrecommitted' = stablePrecommitted,
      stablePrecommitsDelivered' = stablePrecommitsDelivered,
      resamplingDecisionMade' = resamplingDecisionMade,
      progress' = progress + 1,
    }
  }

  action InsertStableProposal: bool =
    all {
      baselineHalted,
      StableRoundReached,
      not(stableProposalInserted),
      StreamAt(StableRound) == StableValue,
      baselineRound' = baselineRound,
      baselineCachedValue' = baselineCachedValue,
      baselineLockedValue' = baselineLockedValue,
      baselineHalted' = baselineHalted,
      burnRound' = burnRound,
      nilSeeded' = nilSeeded,
      advanced' = advanced,
      stableProposalInserted' = true,
      stableProposalDelivered' = stableProposalDelivered,
      stablePrevoted' = stablePrevoted,
      stablePrevotesDelivered' = stablePrevotesDelivered,
      stablePrecommitted' = stablePrecommitted,
      stablePrecommitsDelivered' = stablePrecommitsDelivered,
      resamplingDecisionMade' = resamplingDecisionMade,
      progress' = progress + 1,
    }

  action DeliverStableProposal: bool =
    all {
      stableProposalInserted,
      not(stableProposalDelivered),
      baselineRound' = baselineRound,
      baselineCachedValue' = baselineCachedValue,
      baselineLockedValue' = baselineLockedValue,
      baselineHalted' = baselineHalted,
      burnRound' = burnRound,
      nilSeeded' = nilSeeded,
      advanced' = advanced,
      stableProposalInserted' = stableProposalInserted,
      stableProposalDelivered' = true,
      stablePrevoted' = stablePrevoted,
      stablePrevotesDelivered' = stablePrevotesDelivered,
      stablePrecommitted' = stablePrecommitted,
      stablePrecommitsDelivered' = stablePrecommitsDelivered,
      resamplingDecisionMade' = resamplingDecisionMade,
      progress' = progress + 1,
    }

  action PrevoteStableValue(p: Proc_t): bool =
    all {
      stableProposalDelivered,
      Corr.contains(p),
      not(stablePrevoted.contains(p)),
      baselineRound' = baselineRound,
      baselineCachedValue' = baselineCachedValue,
      baselineLockedValue' = baselineLockedValue,
      baselineHalted' = baselineHalted,
      burnRound' = burnRound,
      nilSeeded' = nilSeeded,
      advanced' = advanced,
      stableProposalInserted' = stableProposalInserted,
      stableProposalDelivered' = stableProposalDelivered,
      stablePrevoted' = stablePrevoted.union(Set(p)),
      stablePrevotesDelivered' = stablePrevotesDelivered,
      stablePrecommitted' = stablePrecommitted,
      stablePrecommitsDelivered' = stablePrecommitsDelivered,
      resamplingDecisionMade' = resamplingDecisionMade,
      progress' = progress + 1,
    }

  action DeliverStablePrevotes(p: Proc_t): bool =
    all {
      Corr.subseteq(stablePrevoted),
      Corr.contains(p),
      not(stablePrevotesDelivered.contains(p)),
      baselineRound' = baselineRound,
      baselineCachedValue' = baselineCachedValue,
      baselineLockedValue' = baselineLockedValue,
      baselineHalted' = baselineHalted,
      burnRound' = burnRound,
      nilSeeded' = nilSeeded,
      advanced' = advanced,
      stableProposalInserted' = stableProposalInserted,
      stableProposalDelivered' = stableProposalDelivered,
      stablePrevoted' = stablePrevoted,
      stablePrevotesDelivered' = stablePrevotesDelivered.union(Set(p)),
      stablePrecommitted' = stablePrecommitted,
      stablePrecommitsDelivered' = stablePrecommitsDelivered,
      resamplingDecisionMade' = resamplingDecisionMade,
      progress' = progress + 1,
    }

  action PrecommitStableValue(p: Proc_t): bool =
    all {
      stablePrevotesDelivered.contains(p),
      Corr.contains(p),
      not(stablePrecommitted.contains(p)),
      baselineRound' = baselineRound,
      baselineCachedValue' = baselineCachedValue,
      baselineLockedValue' = baselineLockedValue,
      baselineHalted' = baselineHalted,
      burnRound' = burnRound,
      nilSeeded' = nilSeeded,
      advanced' = advanced,
      stableProposalInserted' = stableProposalInserted,
      stableProposalDelivered' = stableProposalDelivered,
      stablePrevoted' = stablePrevoted,
      stablePrevotesDelivered' = stablePrevotesDelivered,
      stablePrecommitted' = stablePrecommitted.union(Set(p)),
      stablePrecommitsDelivered' = stablePrecommitsDelivered,
      resamplingDecisionMade' = resamplingDecisionMade,
      progress' = progress + 1,
    }

  action DeliverStablePrecommits: bool =
    all {
      Corr.subseteq(stablePrecommitted),
      not(stablePrecommitsDelivered),
      baselineRound' = baselineRound,
      baselineCachedValue' = baselineCachedValue,
      baselineLockedValue' = baselineLockedValue,
      baselineHalted' = baselineHalted,
      burnRound' = burnRound,
      nilSeeded' = nilSeeded,
      advanced' = advanced,
      stableProposalInserted' = stableProposalInserted,
      stableProposalDelivered' = stableProposalDelivered,
      stablePrevoted' = stablePrevoted,
      stablePrevotesDelivered' = stablePrevotesDelivered,
      stablePrecommitted' = stablePrecommitted,
      stablePrecommitsDelivered' = true,
      resamplingDecisionMade' = resamplingDecisionMade,
      progress' = progress + 1,
    }

  action DecideStableValue: bool =
    all {
      stablePrecommitsDelivered,
      not(resamplingDecisionMade),
      baselineRound' = baselineRound,
      baselineCachedValue' = baselineCachedValue,
      baselineLockedValue' = baselineLockedValue,
      baselineHalted' = baselineHalted,
      burnRound' = burnRound,
      nilSeeded' = nilSeeded,
      advanced' = advanced,
      stableProposalInserted' = stableProposalInserted,
      stableProposalDelivered' = stableProposalDelivered,
      stablePrevoted' = stablePrevoted,
      stablePrevotesDelivered' = stablePrevotesDelivered,
      stablePrecommitted' = stablePrecommitted,
      stablePrecommitsDelivered' = stablePrecommitsDelivered,
      resamplingDecisionMade' = true,
      progress' = progress + 1,
    }

  action StutterAfterDecision: bool =
    all {
      resamplingDecisionMade,
      Unchanged,
    }

  action Next: bool =
    any {
      BaselineCarryStickyStateAndHalt,
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
      StutterAfterDecision,
    }

  val StateWellFormed =
    0.to(1).contains(baselineRound) and
    Snapshots.contains(baselineCachedValue) and
    Snapshots.contains(baselineLockedValue) and
    0.to(StableRound).contains(burnRound) and
    0.to(35).contains(progress) and
    nilSeeded.subseteq(NilCertSigners) and
    advanced.subseteq(Corr) and
    stablePrevoted.subseteq(Corr) and
    stablePrevotesDelivered.subseteq(Corr) and
    stablePrecommitted.subseteq(Corr)

  val BaselineHaltExplainedByStickyChurn =
    baselineHalted implies
      baselineRound == 1 and
      BaselineFreshValueBlockedAtRound(1)

  val ResamplingProgressOnlyAfterBaselineHalt =
    (burnRound > 0 or
      nilSeeded != Set() or
      advanced != Set() or
      stableProposalInserted or
      stableProposalDelivered or
      stablePrevoted != Set() or
      stablePrevotesDelivered != Set() or
      stablePrecommitted != Set() or
      stablePrecommitsDelivered or
      resamplingDecisionMade) implies baselineHalted

  val PhaseOrder =
    (stableProposalInserted implies StableRoundReached) and
    (stableProposalDelivered implies stableProposalInserted) and
    (stablePrevoted != Set() implies stableProposalDelivered) and
    (stablePrevotesDelivered != Set() implies Corr.subseteq(stablePrevoted)) and
    stablePrecommitted.forall(p => stablePrevotesDelivered.contains(p)) and
    (stablePrecommitsDelivered implies Corr.subseteq(stablePrecommitted)) and
    (resamplingDecisionMade implies stablePrecommitsDelivered)

  val Safety =
    StateWellFormed and
    BaselineHaltExplainedByStickyChurn and
    ResamplingProgressOnlyAfterBaselineHalt and
    PhaseOrder

  temporal EventuallyResamplingOutrunsBaselineHalt =
    Next.weakFair(Set(progress)).implies(eventually(
      baselineHalted and resamplingDecisionMade
    ))

  run baselineStickyChurnHaltWitnessTest = {
    Init
      .then(BaselineCarryStickyStateAndHalt)
      .then(all {
        assert(baselineHalted),
        assert(BaselineFreshValueBlockedAtRound(1)),
        assert(baselineCachedValue == InitialStickyValue),
        assert(StreamAt(1) == FreshRoundValue),
        assert(Safety),
        Unchanged,
      })
  }

  run resamplingBurnsPastBaselineStickyChurnTest = {
    Init
      .then(BaselineCarryStickyStateAndHalt)
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
        assert(baselineHalted),
        assert(BaselineFreshValueBlockedAtRound(1)),
        assert(burnRound == StableRound),
        assert(resamplingDecisionMade),
        assert(Safety),
        Unchanged,
      })
  }
}
