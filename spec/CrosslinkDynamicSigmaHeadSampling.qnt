module CrosslinkDynamicSigmaHeadSampling {
  /*
   Bridge model for the third Crosslink variant.

   CrosslinkDynamicSigma.qnt makes sigma a consensus-visible per-height
   schedule. CrosslinkHeadSigmaSampling.qnt makes the proposal source
   `head - sigma` explicit for a fixed sigma. This slice composes those ideas:
   the proposal stream for BFT height h is sampled from the locally observed
   PoW head using sigmaAtHeight[h].

   The model checks two important boundaries:
   - nil-precommit round burns do not change same-height sigma or already
     sampled candidates, and
   - committed telemetry only affects future BFT heights, where `head -
     sigma(h)` may select a deeper or shallower candidate.
   */

  import CrosslinkDynamicSigma.* from "./CrosslinkDynamicSigma"
  export CrosslinkDynamicSigma.*

  type Snapshot_t = str
  type Block_t = str
  type Round_t = int
  type PowHeight_t = int

  const Snapshots: Set[Snapshot_t]
  const MaxRound: Round_t
  const MaxPowHeight: PowHeight_t
  const InitialFinalized: Snapshot_t
  const HeightOf: Snapshot_t -> PowHeight_t
  const AncestorAt: Snapshot_t -> PowHeight_t -> Block_t
  const AncestorSnapshotAt: Snapshot_t -> PowHeight_t -> Snapshot_t
  const HeadAt: Height_t -> Round_t -> Snapshot_t

  pure val NilSnapshot = "None"
  pure val Rounds = 0.to(MaxRound)
  pure val PowHeights = 0.to(MaxPowHeight)

  assume round_domain_is_small_for_bridge =
    MaxRound == 1
  assume initial_finalized_is_snapshot =
    Snapshots.contains(InitialFinalized)
  assume nil_is_not_snapshot =
    not(Snapshots.contains(NilSnapshot))
  assume snapshot_pow_heights_are_in_range =
    Snapshots.forall(v => PowHeights.contains(HeightOf.get(v)))
  assume height_round_heads_are_snapshots =
    Heights.forall(h =>
      Rounds.forall(r => Snapshots.contains(HeadAt.get(h).get(r)))
    )

  var sampled: Height_t -> Round_t -> Snapshot_t

  pure def PowHeight(v: Snapshot_t): PowHeight_t =
    HeightOf.get(v)

  pure def CandidateHeightWithSigma(tip: Snapshot_t, sigmaValue: Sigma_t): PowHeight_t =
    if (PowHeight(tip) >= sigmaValue) {
      PowHeight(tip) - sigmaValue
    } else {
      0
    }

  pure def BlockAt(v: Snapshot_t, h: PowHeight_t): Block_t =
    AncestorAt.get(v).get(h)

  pure def AncestorSnapshot(tip: Snapshot_t, h: PowHeight_t): Snapshot_t =
    AncestorSnapshotAt.get(tip).get(h)

  def SigmaForHeight(h: Height_t): Sigma_t =
    sigmaAtHeight.get(h)

  def IsSnapshot(v: Snapshot_t): bool =
    Snapshots.contains(v)

  def Extends(newer: Snapshot_t, older: Snapshot_t): bool =
    IsSnapshot(newer) and
    IsSnapshot(older) and
    PowHeight(newer) >= PowHeight(older) and
    PowHeights.forall(h =>
      h > PowHeight(older) or BlockAt(newer, h) == BlockAt(older, h)
    )

  def HeadHasSigmaTailAtHeight(h: Height_t, tip: Snapshot_t): bool =
    IsSnapshot(tip) and PowHeight(tip) >= SigmaForHeight(h)

  def DynamicHeadSigmaCandidate(h: Height_t, tip: Snapshot_t): Snapshot_t =
    AncestorSnapshot(tip, CandidateHeightWithSigma(tip, SigmaForHeight(h)))

  def TailConfirmsAtHeight(
    h: Height_t,
    tip: Snapshot_t,
    candidate: Snapshot_t,
  ): bool =
    HeadHasSigmaTailAtHeight(h, tip) and
    IsSnapshot(candidate) and
    PowHeight(tip) >= PowHeight(candidate) + SigmaForHeight(h) and
    BlockAt(tip, PowHeight(candidate)) == BlockAt(candidate, PowHeight(candidate))

  def DynamicHeadSigmaAt(h: Height_t, r: Round_t): Snapshot_t =
    DynamicHeadSigmaCandidate(h, HeadAt.get(h).get(r))

  def DynamicHeadSigmaCandidateValid(h: Height_t, r: Round_t): bool = {
    val tip = HeadAt.get(h).get(r)
    val candidate = DynamicHeadSigmaAt(h, r)
    Heights.contains(h) and
    Rounds.contains(r) and
    Extends(candidate, InitialFinalized) and
    TailConfirmsAtHeight(h, tip, candidate)
  }

  action CombinedInit = all {
    Init,
    sampled' = Heights.mapBy(_ => Rounds.mapBy(_ => NilSnapshot)),
  }

  action SampleRound(r: Round_t): bool = {
    val h = height
    all {
      Heights.contains(h),
      Rounds.contains(r),
      sampled.get(h).get(r) == NilSnapshot,
      HeadHasSigmaTailAtHeight(h, HeadAt.get(h).get(r)),
      sampled' = sampled.setBy(h, byRound =>
        byRound.set(r, DynamicHeadSigmaAt(h, r))
      ),
      height' = height,
      sigma' = sigma,
      sigmaAtHeight' = sigmaAtHeight,
      committedTelemetryHeights' = committedTelemetryHeights,
      burnedNilRounds' = burnedNilRounds,
      lastHeightBefore' = height,
      lastSigmaBefore' = sigma,
      firedAction' = "SampleRound",
    }
  }

  action BurnNilRound: bool = all {
    BurnNilPrecommitRound,
    sampled' = sampled,
  }

  action CommitHeight: bool = all {
    CommitHeightWithTelemetry,
    sampled' = sampled,
  }

  action CombinedStutter = all {
    Stutter,
    sampled' = sampled,
  }

  action CombinedNext =
    any {
      SampleRound(0),
      SampleRound(1),
      BurnNilRound,
      CommitHeight,
      CombinedStutter,
    }

  def Sampled(h: Height_t, r: Round_t): bool =
    Heights.contains(h) and
    Rounds.contains(r) and
    sampled.get(h).get(r) != NilSnapshot

  val SampledValuesMatchDynamicHeadSigma =
    Heights.forall(h =>
      Rounds.forall(r =>
        not(Sampled(h, r)) or
        sampled.get(h).get(r) == DynamicHeadSigmaAt(h, r)
      )
    )

  val SampledValuesUseHeightSigmaSchedule =
    Heights.forall(h =>
      Rounds.forall(r =>
        not(Sampled(h, r)) or
        sampled.get(h).get(r) ==
          AncestorSnapshot(
            HeadAt.get(h).get(r),
            CandidateHeightWithSigma(HeadAt.get(h).get(r), SigmaForHeight(h)),
          )
      )
    )

  val SampledValuesAreTailConfirmed =
    Heights.forall(h =>
      Rounds.forall(r =>
        not(Sampled(h, r)) or DynamicHeadSigmaCandidateValid(h, r)
      )
    )

  val SampleActionDoesNotMutateDynamicSigma =
    if (firedAction == "SampleRound") {
      height == lastHeightBefore and sigma == lastSigmaBefore
    } else {
      true
    }

  val NilBurnDoesNotMutateDynamicSamples =
    if (firedAction == "BurnNilPrecommitRound") {
      Heights.forall(h =>
        Rounds.forall(r =>
          not(Sampled(h, r)) or
          sampled.get(h).get(r) == DynamicHeadSigmaAt(h, r)
        )
      )
    } else {
      true
    }

  val DynamicHeadSigmaSafety =
    Safety and
    SampledValuesMatchDynamicHeadSigma and
    SampledValuesUseHeightSigmaSchedule and
    SampledValuesAreTailConfirmed and
    SampleActionDoesNotMutateDynamicSigma and
    NilBurnDoesNotMutateDynamicSamples
}

module CrosslinkDynamicSigmaHeadSamplingTest {
  import CrosslinkDynamicSigmaHeadSampling.* from "./CrosslinkDynamicSigmaHeadSampling"
  export CrosslinkDynamicSigmaHeadSampling.*

  action unchangedAll = all {
    height' = height,
    sigma' = sigma,
    sigmaAtHeight' = sigmaAtHeight,
    committedTelemetryHeights' = committedTelemetryHeights,
    burnedNilRounds' = burnedNilRounds,
    lastHeightBefore' = lastHeightBefore,
    lastSigmaBefore' = lastSigmaBefore,
    firedAction' = firedAction,
    sampled' = sampled,
  }

  run initialHeightSamplesWithInitialSigmaTest = {
    CombinedInit
      .then(SampleRound(0))
      .then(all {
        assert(height == 0),
        assert(SigmaForHeight(0) == 1),
        assert(sampled.get(0).get(0) == "a3"),
        assert(DynamicHeadSigmaAt(0, 0) == "a3"),
        assert(DynamicHeadSigmaSafety),
        unchangedAll,
      })
  }

  run nilRoundBurnDoesNotChangeSampleOrSigmaTest = {
    CombinedInit
      .then(SampleRound(0))
      .then(BurnNilRound)
      .then(all {
        assert(height == 0),
        assert(sigma == 1),
        assert(burnedNilRounds.get(0) == 1),
        assert(sampled.get(0).get(0) == "a3"),
        assert(DynamicHeadSigmaSafety),
        unchangedAll,
      })
  }

  run longReorgTelemetryRaisesFutureHeightAndSamplesDeeperTest = {
    CombinedInit
      .then(SampleRound(0))
      .then(CommitHeight)
      .then(SampleRound(0))
      .then(all {
        assert(height == 1),
        assert(SigmaForHeight(0) == 1),
        assert(SigmaForHeight(1) == 2),
        assert(sampled.get(0).get(0) == "a3"),
        assert(sampled.get(1).get(0) == "a2"),
        assert(PowHeight(sampled.get(1).get(0)) < PowHeight(sampled.get(0).get(0))),
        assert(DynamicHeadSigmaSafety),
        unchangedAll,
      })
  }

  run stableHighParticipationWindowLowersFutureSigmaAndSamplesShallowerTest = {
    CombinedInit
      .then(CommitHeight)
      .then(SampleRound(0))
      .then(CommitHeight)
      .then(SampleRound(0))
      .then(all {
        assert(height == 2),
        assert(SigmaForHeight(1) == 2),
        assert(SigmaForHeight(2) == 1),
        assert(sampled.get(1).get(0) == "a2"),
        assert(sampled.get(2).get(0) == "a3"),
        assert(PowHeight(sampled.get(2).get(0)) > PowHeight(sampled.get(1).get(0))),
        assert(DynamicHeadSigmaSafety),
        unchangedAll,
      })
  }

  run lowHashPowerParticipationPreventsFutureSigmaRelaxationTest = {
    CombinedInit
      .then(CommitHeight)
      .then(CommitHeight)
      .then(CommitHeight)
      .then(SampleRound(0))
      .then(CommitHeight)
      .then(SampleRound(0))
      .then(all {
        assert(height == 4),
        assert(SigmaForHeight(3) == 2),
        assert(SigmaForHeight(4) == 2),
        assert(CommittedFailureKind.get(3) == NoFailure),
        assert(CoverageCompleteAt(3)),
        assert(not(HashPowerParticipationCompleteAt(3))),
        assert(not(ShouldLowerSigma(3))),
        assert(sampled.get(3).get(0) == "a2"),
        assert(sampled.get(4).get(0) == "a2"),
        assert(DynamicHeadSigmaSafety),
        unchangedAll,
      })
  }

  run dynamicSigmaHeadSamplingSafetyTest = {
    CombinedInit
      .then(all {
        assert(DynamicHeadSigmaSafety),
        unchangedAll,
      })
  }
}

module CrosslinkDynamicSigmaHeadSamplingModel {
  import CrosslinkDynamicSigmaHeadSamplingTest(
    MaxHeight = 4,
    MinSigma = 1,
    MaxSigma = 3,
    InitialSigma = 1,
    FailureThreshold = 2,
    StableWindowThreshold = 2,
    CoverageTarget = 3,
    MaxCoverageScore = 4,
    HashPowerParticipationTargetPercent = 67,
    MaxHashPowerParticipationPercent = 100,
    CommittedFailureKind = Map(
      0 -> "long-reorg-tail",
      1 -> "none",
      2 -> "long-reorg-tail",
      3 -> "none",
      4 -> "none",
    ),
    CommittedFailureCount = Map(
      0 -> 2,
      1 -> 0,
      2 -> 2,
      3 -> 0,
      4 -> 0,
    ),
    CommittedStableWindowCount = Map(
      0 -> 0,
      1 -> 2,
      2 -> 0,
      3 -> 2,
      4 -> 0,
    ),
    CommittedCoverageScore = Map(
      0 -> 4,
      1 -> 4,
      2 -> 4,
      3 -> 4,
      4 -> 4,
    ),
    CommittedHashPowerParticipationPercent = Map(
      0 -> 80,
      1 -> 80,
      2 -> 80,
      3 -> 30,
      4 -> 80,
    ),
    Snapshots = Set("g", "a1", "a2", "a3", "a4"),
    MaxRound = 1,
    MaxPowHeight = 4,
    InitialFinalized = "g",
    HeightOf = Map(
      "g" -> 0,
      "a1" -> 1,
      "a2" -> 2,
      "a3" -> 3,
      "a4" -> 4,
    ),
    AncestorAt = Map(
      "g" -> Map(0 -> "g", 1 -> "None", 2 -> "None", 3 -> "None", 4 -> "None"),
      "a1" -> Map(0 -> "g", 1 -> "a1", 2 -> "None", 3 -> "None", 4 -> "None"),
      "a2" -> Map(0 -> "g", 1 -> "a1", 2 -> "a2", 3 -> "None", 4 -> "None"),
      "a3" -> Map(0 -> "g", 1 -> "a1", 2 -> "a2", 3 -> "a3", 4 -> "None"),
      "a4" -> Map(0 -> "g", 1 -> "a1", 2 -> "a2", 3 -> "a3", 4 -> "a4"),
    ),
    AncestorSnapshotAt = Map(
      "g" -> Map(0 -> "g", 1 -> "None", 2 -> "None", 3 -> "None", 4 -> "None"),
      "a1" -> Map(0 -> "g", 1 -> "a1", 2 -> "None", 3 -> "None", 4 -> "None"),
      "a2" -> Map(0 -> "g", 1 -> "a1", 2 -> "a2", 3 -> "None", 4 -> "None"),
      "a3" -> Map(0 -> "g", 1 -> "a1", 2 -> "a2", 3 -> "a3", 4 -> "None"),
      "a4" -> Map(0 -> "g", 1 -> "a1", 2 -> "a2", 3 -> "a3", 4 -> "a4"),
    ),
    HeadAt = Map(
      0 -> Map(0 -> "a4", 1 -> "a4"),
      1 -> Map(0 -> "a4", 1 -> "a4"),
      2 -> Map(0 -> "a4", 1 -> "a4"),
      3 -> Map(0 -> "a4", 1 -> "a4"),
      4 -> Map(0 -> "a4", 1 -> "a4"),
    ),
  ).*
}
