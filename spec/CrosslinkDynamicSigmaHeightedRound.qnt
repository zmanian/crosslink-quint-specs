module CrosslinkDynamicSigmaHeightedRound {
  /*
   Height-indexed Tenderlink rounds with dynamic head-sigma streams.

   CrosslinkHeightedRound.qnt models Stream(height, round) abstractly.
   CrosslinkDynamicSigma.qnt models sigma as a consensus-visible per-height
   schedule. This module composes those surfaces without importing the dynamic
   controller state variables: the schedule is an explicit consensus-parameter
   map, constrained by the same telemetry update rule, and each heighted round
   samples `head - sigma(h)`.
   */

  import CrosslinkHeightedRound.* from "./CrosslinkHeightedRound"
  export CrosslinkHeightedRound.*

  type PowHeight_t = int
  type Block_t = str
  type FailureKind_t = str

  const MaxPowHeight: PowHeight_t
  const MinSigma: int
  const MaxSigma: int
  const InitialSigma: int
  const FailureThreshold: int
  const StableWindowThreshold: int
  const CoverageTarget: int
  const MaxCoverageScore: int
  const HashPowerParticipationTargetPercent: int
  const HashPowerParticipationFloorPercent: int
  const MaxHashPowerParticipationPercent: int
  const SigmaAtHeight: Height_t -> int
  const CommittedFailureKind: Height_t -> FailureKind_t
  const CommittedFailureCount: Height_t -> int
  const CommittedStableWindowCount: Height_t -> int
  const CommittedCoverageScore: Height_t -> int
  const CommittedHashPowerParticipationPercent: Height_t -> int
  const InitialFinalized: Snapshot_t
  const HeightOf: Snapshot_t -> PowHeight_t
  const AncestorAt: Snapshot_t -> PowHeight_t -> Block_t
  const AncestorSnapshotAt: Snapshot_t -> PowHeight_t -> Snapshot_t
  const HeadAt: Height_t -> Round_t -> Snapshot_t

  pure val NoFailure = "none"
  pure val SameBranchArrivalFailure = "same-branch-arrival"
  pure val LongReorgTailFailure = "long-reorg-tail"
  pure val AmbiguousCoverageFailure = "ambiguous-low-coverage"
  pure val PowHeights = 0.to(MaxPowHeight)
  pure val SigmaValues = MinSigma.to(MaxSigma)
  pure val TransitionHeights = 1.to(MaxBftHeight - 1)

  assume dynamic_height_domain_has_transition =
    MaxBftHeight >= 2
  assume initial_finalized_is_snapshot =
    Snapshots.contains(InitialFinalized)
  assume sigma_bounds_are_valid =
    MinSigma >= 1 and MaxSigma >= MinSigma and SigmaValues.contains(InitialSigma)
  assume thresholds_are_positive =
    FailureThreshold > 0 and
    StableWindowThreshold > 0 and
    CoverageTarget > 0 and
    MaxCoverageScore >= CoverageTarget and
    HashPowerParticipationTargetPercent > 0 and
    HashPowerParticipationFloorPercent > 0 and
    HashPowerParticipationFloorPercent <= HashPowerParticipationTargetPercent and
    MaxHashPowerParticipationPercent == 100 and
    MaxHashPowerParticipationPercent >= HashPowerParticipationTargetPercent
  assume snapshot_pow_heights_are_in_range =
    Snapshots.forall(v => PowHeights.contains(HeightOf.get(v)))
  assume height_round_heads_are_snapshots =
    Heights.forall(h =>
      Rounds.forall(r => Snapshots.contains(HeadAt.get(h).get(r)))
    )

  pure def FailureKindKnown(kind: FailureKind_t): bool =
    kind == NoFailure or
    kind == SameBranchArrivalFailure or
    kind == LongReorgTailFailure or
    kind == AmbiguousCoverageFailure

  assume committed_telemetry_is_well_formed =
    Heights.forall(h =>
      FailureKindKnown(CommittedFailureKind.get(h)) and
      CommittedFailureCount.get(h) >= 0 and
      CommittedStableWindowCount.get(h) >= 0 and
      CommittedCoverageScore.get(h) >= 0 and
      CommittedCoverageScore.get(h) <= MaxCoverageScore and
      CommittedHashPowerParticipationPercent.get(h) >= 0 and
      CommittedHashPowerParticipationPercent.get(h) <= MaxHashPowerParticipationPercent
    )

  pure def PowHeight(v: Snapshot_t): PowHeight_t =
    HeightOf.get(v)

  pure def SigmaForHeight(h: Height_t): int =
    SigmaAtHeight.get(h)

  pure def SigmaInBounds(value: int): bool =
    SigmaValues.contains(value)

  pure def ClampSigma(value: int): int =
    if (value < MinSigma) {
      MinSigma
    } else {
      if (value > MaxSigma) {
        MaxSigma
      } else {
        value
      }
    }

  pure def CoverageCompleteAt(h: Height_t): bool =
    CommittedCoverageScore.get(h) >= CoverageTarget

  pure def CoverageDeficitAt(h: Height_t): int =
    if (CoverageCompleteAt(h)) {
      0
    } else {
      CoverageTarget - CommittedCoverageScore.get(h)
    }

  pure def HashPowerParticipationCompleteAt(h: Height_t): bool =
    CommittedHashPowerParticipationPercent.get(h) >=
      HashPowerParticipationTargetPercent

  pure def HashPowerParticipationFloorBreachedAt(h: Height_t): bool =
    CommittedHashPowerParticipationPercent.get(h) <
      HashPowerParticipationFloorPercent

  pure def HashPowerParticipationDeficitAt(h: Height_t): int =
    if (HashPowerParticipationCompleteAt(h)) {
      0
    } else {
      HashPowerParticipationTargetPercent -
        CommittedHashPowerParticipationPercent.get(h)
    }

  pure def SigmaRelevantFailurePressure(h: Height_t): int =
    if (CommittedFailureKind.get(h) == LongReorgTailFailure) {
      CommittedFailureCount.get(h) +
        CoverageDeficitAt(h) +
        HashPowerParticipationDeficitAt(h)
    } else {
      if (CommittedFailureKind.get(h) == AmbiguousCoverageFailure) {
        CommittedFailureCount.get(h) +
          CoverageDeficitAt(h) +
          HashPowerParticipationDeficitAt(h)
      } else {
        0
      }
    }

  pure def ShouldRaiseSigma(h: Height_t): bool =
    SigmaRelevantFailurePressure(h) >= FailureThreshold or
    HashPowerParticipationFloorBreachedAt(h)

  pure def ShouldLowerSigma(h: Height_t): bool =
    not(ShouldRaiseSigma(h)) and
    CoverageCompleteAt(h) and
    HashPowerParticipationCompleteAt(h) and
    CommittedFailureCount.get(h) == 0 and
    CommittedStableWindowCount.get(h) >= StableWindowThreshold

  pure def NextSigmaForHeight(currentSigma: int, h: Height_t): int =
    if (ShouldRaiseSigma(h)) {
      ClampSigma(currentSigma + 1)
    } else {
      if (ShouldLowerSigma(h)) {
        ClampSigma(currentSigma - 1)
      } else {
        currentSigma
      }
    }

  pure def CandidateHeightWithSigma(tip: Snapshot_t, sigmaValue: int): PowHeight_t =
    if (PowHeight(tip) >= sigmaValue) {
      PowHeight(tip) - sigmaValue
    } else {
      0
    }

  pure def BlockAt(v: Snapshot_t, h: PowHeight_t): Block_t =
    AncestorAt.get(v).get(h)

  pure def AncestorSnapshot(tip: Snapshot_t, h: PowHeight_t): Snapshot_t =
    AncestorSnapshotAt.get(tip).get(h)

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

  def DynamicProposalValidAgainstFinalized(
    h: Height_t,
    tip: Snapshot_t,
    candidate: Snapshot_t,
    finalizedPrefix: Snapshot_t,
  ): bool =
    IsSnapshot(tip) and
    IsSnapshot(candidate) and
    candidate == DynamicHeadSigmaCandidate(h, tip) and
    Extends(candidate, finalizedPrefix) and
    TailConfirmsAtHeight(h, tip, candidate)

  val SigmaScheduleMatchesTelemetry =
    SigmaForHeight(1) == InitialSigma and
    Heights.forall(h => SigmaInBounds(SigmaForHeight(h))) and
    TransitionHeights.forall(h =>
      SigmaForHeight(h + 1) == NextSigmaForHeight(SigmaForHeight(h), h)
    )

  val SameBranchFailuresDoNotRaiseFutureSigmaByThemselves =
    TransitionHeights.forall(h =>
      if (
        CommittedFailureKind.get(h) == SameBranchArrivalFailure and
        not(HashPowerParticipationFloorBreachedAt(h))
      ) {
        not(ShouldRaiseSigma(h)) and
        SigmaForHeight(h + 1) <= SigmaForHeight(h)
      } else {
        true
      }
    )

  val CriticalHashPowerParticipationCanRaiseFutureSigma =
    TransitionHeights.forall(h =>
      if (
        HashPowerParticipationFloorBreachedAt(h) and
        SigmaForHeight(h) < MaxSigma
      ) {
        SigmaForHeight(h + 1) == SigmaForHeight(h) + 1
      } else {
        true
      }
    )

  val StreamMatchesDynamicHeadSigma =
    Heights.forall(h =>
      Rounds.forall(r =>
        Stream.get(h).get(r) == DynamicHeadSigmaAt(h, r)
      )
    )

  val DynamicHeadSigmaCandidatesAreValid =
    Heights.forall(h =>
      Rounds.forall(r =>
        DynamicProposalValidAgainstFinalized(
          h,
          HeadAt.get(h).get(r),
          Stream.get(h).get(r),
          InitialFinalized,
        )
      )
    )

  val CorrectFreshProposalMessagesCarryDynamicHeadSigma =
    Heights.forall(h =>
      Rounds.forall(r =>
        msgsPropose.get(h).get(r).forall(m =>
          not(Corr.contains(m.src)) or
          m.validRound != NilRound or (
            m.proposal == DynamicHeadSigmaAt(h, r) and
            DynamicProposalValidAgainstFinalized(
              h,
              HeadAt.get(h).get(r),
              m.proposal,
              InitialFinalized,
            )
          )
        )
      )
    )

  val CorrectValuePrecommitsCarryDynamicHeadSigma =
    Heights.forall(h =>
      Rounds.forall(r =>
        msgsPrecommit.get(h).get(r).forall(m =>
          not(Corr.contains(m.src)) or
          m.id == NilSnapshot or
          m.id == DynamicHeadSigmaAt(h, r)
        )
      )
    )

  val DynamicHeightedHeadSigmaSafety =
    Safety and
    SigmaScheduleMatchesTelemetry and
    SameBranchFailuresDoNotRaiseFutureSigmaByThemselves and
    CriticalHashPowerParticipationCanRaiseFutureSigma and
    StreamMatchesDynamicHeadSigma and
    DynamicHeadSigmaCandidatesAreValid and
    CorrectFreshProposalMessagesCarryDynamicHeadSigma and
    CorrectValuePrecommitsCarryDynamicHeadSigma
}

module CrosslinkDynamicSigmaHeightedRoundTest {
  import CrosslinkDynamicSigmaHeightedRound.* from "./CrosslinkDynamicSigmaHeightedRound"
  export CrosslinkDynamicSigmaHeightedRound.*

  action unchangedAll = all {
    height' = height,
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
    seenPropose' = seenPropose,
    seenPrevote' = seenPrevote,
    seenPrecommit' = seenPrecommit,
    firedAction' = firedAction,
  }

  action CommitHeightOneForP1 = all {
    InsertProposal("p1")
      .then(DeliverProposal("p1", "p1", 1, 0, "a1", NilRound))
      .then(DeliverProposal("p2", "p1", 1, 0, "a1", NilRound))
      .then(DeliverProposal("p3", "p1", 1, 0, "a1", NilRound))
      .then(Prevote("p1", "a1"))
      .then(Prevote("p2", "a1"))
      .then(Prevote("p3", "a1"))
      .then(DeliverPrevotesTo("p1", 1, 0, "a1", Set("p1", "p2", "p3")))
      .then(DeliverPrevotesTo("p2", 1, 0, "a1", Set("p1", "p2", "p3")))
      .then(DeliverPrevotesTo("p3", 1, 0, "a1", Set("p1", "p2", "p3")))
      .then(PrecommitValue("p1", "a1"))
      .then(PrecommitValue("p2", "a1"))
      .then(PrecommitValue("p3", "a1"))
      .then(DeliverPrecommitsTo("p1", 1, 0, "a1", Set("p1", "p2", "p3")))
      .then(Decide("p1", "a1"))
  }

  run heightOneFreshProposalUsesInitialSigmaTest = {
    Init
      .then(InsertProposal("p1"))
      .then(all {
        assert(SigmaForHeight(1) == 1),
        assert(DynamicHeadSigmaAt(1, 0) == "a1"),
        assert(msgsPropose.get(1).get(0).contains({
          src: "p1",
          height: 1,
          round: 0,
          proposal: "a1",
          validRound: NilRound,
        })),
        assert(DynamicHeightedHeadSigmaSafety),
        unchangedAll,
      })
  }

  run streamChangeForDynamicHeadSigmaCandidatePrecommitsNilTest = {
    Init
      .then(InsertProposal("p1"))
      .then(DeliverProposal("p1", "p1", 1, 0, "a1", NilRound))
      .then(DeliverProposal("p2", "p1", 1, 0, "a1", NilRound))
      .then(DeliverProposal("p3", "p1", 1, 0, "a1", NilRound))
      .then(Prevote("p1", "a1"))
      .then(Prevote("p2", "a1"))
      .then(Prevote("p3", "a1"))
      .then(DeliverPrevotesTo("p1", 1, 0, "a1", Set("p1", "p2", "p3")))
      .then(PrecommitNilOnStreamChange("p1"))
      .then(all {
        assert(SigmaForHeight(1) == 1),
        assert(DynamicHeadSigmaAt(1, 0) == "a1"),
        assert(DynamicHeadSigmaAt(1, 1) == "b1"),
        assert(msgsPrecommit.get(1).get(0).exists(m =>
          m.src == "p1" and m.id == NilSnapshot
        )),
        assert(DynamicHeightedHeadSigmaSafety),
        unchangedAll,
      })
  }

  run nilCertificateResamplesSameHeightWithSameSigmaTest = {
    Init
      .then(InsertProposal("p1"))
      .then(SeedNilPrecommitCertificateAt(1, 0, Set("p1", "p2", "p3")))
      .then(AdvanceAfterPrecommitQuorum("p1"))
      .then(InsertProposal("p1"))
      .then(all {
        assert(round.get("p1").get(1) == 1),
        assert(SigmaForHeight(1) == 1),
        assert(cachedProposal.get("p1").get(1) == "b1"),
        assert(msgsPropose.get(1).get(1).contains({
          src: "p1",
          height: 1,
          round: 1,
          proposal: "b1",
          validRound: NilRound,
        })),
        assert(DynamicHeightedHeadSigmaSafety),
        unchangedAll,
      })
  }

  run decidedNextHeightUsesTelemetryRaisedSigmaTest = {
    Init
      .then(CommitHeightOneForP1)
      .then(InsertProposal("p1"))
      .then(all {
        assert(height.get("p1") == 2),
        assert(SigmaForHeight(1) == 1),
        assert(SigmaForHeight(2) == 2),
        assert(DynamicHeadSigmaAt(2, 0) == "a2"),
        assert(msgsPropose.get(2).get(0).contains({
          src: "p1",
          height: 2,
          round: 0,
          proposal: "a2",
          validRound: NilRound,
        })),
        assert(DynamicHeightedHeadSigmaSafety),
        unchangedAll,
      })
  }

  run dynamicHeightedHeadSigmaSafetyTest = {
    Init
      .then(all {
        assert(DynamicHeightedHeadSigmaSafety),
        unchangedAll,
      })
  }
}

module CrosslinkDynamicSigmaHeightedRoundModel {
  import CrosslinkDynamicSigmaHeightedRoundTest(
    Corr = Set("p1", "p2", "p3"),
    Faulty = Set("p4"),
    VotingPower = Map("p1" -> 1, "p2" -> 1, "p3" -> 1, "p4" -> 1),
    QuorumVotingPower = 3,
    MaxBftHeight = 2,
    MaxRound = 1,
    Proposer = Map(
      1 -> Map(0 -> "p1", 1 -> "p1"),
      2 -> Map(0 -> "p1", 1 -> "p1"),
    ),
    Stream = Map(
      1 -> Map(0 -> "a1", 1 -> "b1"),
      2 -> Map(0 -> "a2", 1 -> "a2"),
    ),
    Snapshots = Set("g", "a1", "a2", "a3", "a4", "b1", "b2"),
    ResampleOnNilPrecommit = true,
    MaxPowHeight = 4,
    MinSigma = 1,
    MaxSigma = 3,
    InitialSigma = 1,
    FailureThreshold = 2,
    StableWindowThreshold = 2,
    CoverageTarget = 3,
    MaxCoverageScore = 4,
    HashPowerParticipationTargetPercent = 67,
    HashPowerParticipationFloorPercent = 25,
    MaxHashPowerParticipationPercent = 100,
    SigmaAtHeight = Map(
      1 -> 1,
      2 -> 2,
    ),
    CommittedFailureKind = Map(
      1 -> "long-reorg-tail",
      2 -> "none",
    ),
    CommittedFailureCount = Map(
      1 -> 2,
      2 -> 0,
    ),
    CommittedStableWindowCount = Map(
      1 -> 0,
      2 -> 2,
    ),
    CommittedCoverageScore = Map(
      1 -> 4,
      2 -> 4,
    ),
    CommittedHashPowerParticipationPercent = Map(
      1 -> 80,
      2 -> 80,
    ),
    InitialFinalized = "g",
    HeightOf = Map(
      "g" -> 0,
      "a1" -> 1,
      "a2" -> 2,
      "a3" -> 3,
      "a4" -> 4,
      "b1" -> 1,
      "b2" -> 2,
    ),
    AncestorAt = Map(
      "g" -> Map(0 -> "g", 1 -> "None", 2 -> "None", 3 -> "None", 4 -> "None"),
      "a1" -> Map(0 -> "g", 1 -> "a1", 2 -> "None", 3 -> "None", 4 -> "None"),
      "a2" -> Map(0 -> "g", 1 -> "a1", 2 -> "a2", 3 -> "None", 4 -> "None"),
      "a3" -> Map(0 -> "g", 1 -> "a1", 2 -> "a2", 3 -> "a3", 4 -> "None"),
      "a4" -> Map(0 -> "g", 1 -> "a1", 2 -> "a2", 3 -> "a3", 4 -> "a4"),
      "b1" -> Map(0 -> "g", 1 -> "b1", 2 -> "None", 3 -> "None", 4 -> "None"),
      "b2" -> Map(0 -> "g", 1 -> "b1", 2 -> "b2", 3 -> "None", 4 -> "None"),
    ),
    AncestorSnapshotAt = Map(
      "g" -> Map(0 -> "g", 1 -> "None", 2 -> "None", 3 -> "None", 4 -> "None"),
      "a1" -> Map(0 -> "g", 1 -> "a1", 2 -> "None", 3 -> "None", 4 -> "None"),
      "a2" -> Map(0 -> "g", 1 -> "a1", 2 -> "a2", 3 -> "None", 4 -> "None"),
      "a3" -> Map(0 -> "g", 1 -> "a1", 2 -> "a2", 3 -> "a3", 4 -> "None"),
      "a4" -> Map(0 -> "g", 1 -> "a1", 2 -> "a2", 3 -> "a3", 4 -> "a4"),
      "b1" -> Map(0 -> "g", 1 -> "b1", 2 -> "None", 3 -> "None", 4 -> "None"),
      "b2" -> Map(0 -> "g", 1 -> "b1", 2 -> "b2", 3 -> "None", 4 -> "None"),
    ),
    HeadAt = Map(
      1 -> Map(0 -> "a2", 1 -> "b2"),
      2 -> Map(0 -> "a4", 1 -> "a4"),
    ),
  ).*
}
