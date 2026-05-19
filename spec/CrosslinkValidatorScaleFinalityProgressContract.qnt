module CrosslinkValidatorScaleFinalityProgressContractModel {
  /*
   TLC-friendly finality contract for validator-scale nil-precommit resampling.

   CrosslinkValidatorScaleProgressContract.qnt checks that the stressed
   validator-scale scenario halts the baseline path while nil-precommit
   resampling reaches a stable decision. This contract reuses that progress
   machine and adds the Crosslink finality cursor: after the stable decision,
   a fair finality applicator advances the finalized prefix to the decided
   head-sigma candidate without accepting the competing fork candidate.
   */

  import CrosslinkValidatorScaleProgressContractModel.* from
    "./CrosslinkValidatorScaleProgressContract"

  type Snapshot_t = str
  type Height_t = int
  type Block_t = str

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

  var latestFinal: Snapshot_t
  var finalized: Set[Snapshot_t]

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

  action FinalityInit = all {
    Init,
    latestFinal' = InitialFinalized,
    finalized' = Set(InitialFinalized),
  }

  action FinalityUnchanged = all {
    latestFinal' = latestFinal,
    finalized' = finalized,
  }

  action ScaleVarsUnchangedWithProgressTick = all {
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
    progress' = progress + 1,
  }

  action ScaleBaselineObserveChurnAndHalt: bool =
    all { BaselineObserveChurnAndHalt, FinalityUnchanged }

  action ScaleSeedNilSigner(p: Proc_t): bool =
    all { SeedNilSigner(p), FinalityUnchanged }

  action ScaleAdvanceAfterNilCert(p: Proc_t): bool =
    all { AdvanceAfterNilCert(p), FinalityUnchanged }

  action ScaleInsertStableProposal: bool =
    all { InsertStableProposal, FinalityUnchanged }

  action ScaleDeliverStableProposal: bool =
    all { DeliverStableProposal, FinalityUnchanged }

  action ScalePrevoteStableValue(p: Proc_t): bool =
    all { PrevoteStableValue(p), FinalityUnchanged }

  action ScaleDeliverStablePrevotes(p: Proc_t): bool =
    all { DeliverStablePrevotes(p), FinalityUnchanged }

  action ScalePrecommitStableValue(p: Proc_t): bool =
    all { PrecommitStableValue(p), FinalityUnchanged }

  action ScaleDeliverStablePrecommits: bool =
    all { DeliverStablePrecommits, FinalityUnchanged }

  action ScaleDecideStableValue: bool =
    all { DecideStableValue, FinalityUnchanged }

  action FinalizeStableDecision: bool =
    all {
      resamplingDecisionMade,
      not(finalized.contains(StableValue)),
      ValidFinalityCandidate(StableValue, StableTip),
      ScaleVarsUnchangedWithProgressTick,
      latestFinal' = StableValue,
      finalized' = finalized.union(Set(StableValue)),
    }

  action StutterAfterFinalized: bool =
    all {
      finalized.contains(StableValue),
      Unchanged,
      FinalityUnchanged,
    }

  action FinalityNext: bool =
    any {
      ScaleBaselineObserveChurnAndHalt,
      nondet p = oneOf(NilCertSigners)
      ScaleSeedNilSigner(p),
      nondet p = oneOf(Corr)
      ScaleAdvanceAfterNilCert(p),
      ScaleInsertStableProposal,
      ScaleDeliverStableProposal,
      nondet p = oneOf(Corr)
      ScalePrevoteStableValue(p),
      nondet p = oneOf(Corr)
      ScaleDeliverStablePrevotes(p),
      nondet p = oneOf(Corr)
      ScalePrecommitStableValue(p),
      ScaleDeliverStablePrecommits,
      ScaleDecideStableValue,
      FinalizeStableDecision,
      StutterAfterFinalized,
    }

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

  val FinalitySafety =
    Safety and
    FinalizedPrefixLinear and
    LatestFinalExtendsAllFinalized and
    StableDecisionFinalizesOnlyValidCandidate and
    ForkValueNotFinalized

  temporal EventuallyValidatorScaleFinalized =
    FinalityNext.weakFair(Set(progress)).implies(eventually(finalized.contains(StableValue)))

  run fairValidatorScaleFinalityProgressContractTest = {
    FinalityInit
      .then(ScaleBaselineObserveChurnAndHalt)
      .then(ScaleSeedNilSigner("p1"))
      .then(ScaleSeedNilSigner("p2"))
      .then(ScaleSeedNilSigner("p4"))
      .then(ScaleAdvanceAfterNilCert("p2"))
      .then(ScaleAdvanceAfterNilCert("p1"))
      .then(ScaleAdvanceAfterNilCert("p3"))
      .then(ScaleSeedNilSigner("p4"))
      .then(ScaleSeedNilSigner("p2"))
      .then(ScaleSeedNilSigner("p1"))
      .then(ScaleAdvanceAfterNilCert("p3"))
      .then(ScaleAdvanceAfterNilCert("p1"))
      .then(ScaleAdvanceAfterNilCert("p2"))
      .then(ScaleSeedNilSigner("p2"))
      .then(ScaleSeedNilSigner("p4"))
      .then(ScaleSeedNilSigner("p1"))
      .then(ScaleAdvanceAfterNilCert("p1"))
      .then(ScaleAdvanceAfterNilCert("p3"))
      .then(ScaleAdvanceAfterNilCert("p2"))
      .then(ScaleInsertStableProposal)
      .then(ScaleDeliverStableProposal)
      .then(ScalePrevoteStableValue("p2"))
      .then(ScalePrevoteStableValue("p3"))
      .then(ScalePrevoteStableValue("p1"))
      .then(ScaleDeliverStablePrevotes("p3"))
      .then(ScaleDeliverStablePrevotes("p1"))
      .then(ScaleDeliverStablePrevotes("p2"))
      .then(ScalePrecommitStableValue("p1"))
      .then(ScalePrecommitStableValue("p3"))
      .then(ScalePrecommitStableValue("p2"))
      .then(ScaleDeliverStablePrecommits)
      .then(ScaleDecideStableValue)
      .then(FinalizeStableDecision)
      .then(all {
        assert(baselineHalted),
        assert(resamplingDecisionMade),
        assert(finalized.contains(StableValue)),
        assert(latestFinal == StableValue),
        assert(not(finalized.contains(ForkValue))),
        assert(FinalitySafety),
        Unchanged,
        FinalityUnchanged,
      })
  }
}
