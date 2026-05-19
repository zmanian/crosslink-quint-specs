module CrosslinkDynamicSigmaHeightedFinality {
  /*
   Height-indexed Tenderlink rounds plus Crosslink finality with dynamic sigma.

   CrosslinkDynamicSigmaHeightedRound.qnt checks that proposals and value
   precommits follow `head - sigma(h)`. This module keeps the same schedule
   discipline and adds a Crosslink finality cursor whose candidate validation
   also uses the active BFT height's sigma.
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

  assume dynamic_finality_height_domain_has_transition =
    MaxBftHeight >= 2
  assume dynamic_finality_initial_finalized_is_snapshot =
    Snapshots.contains(InitialFinalized)
  assume dynamic_finality_sigma_bounds_are_valid =
    MinSigma >= 1 and MaxSigma >= MinSigma and SigmaValues.contains(InitialSigma)
  assume dynamic_finality_thresholds_are_positive =
    FailureThreshold > 0 and
    StableWindowThreshold > 0 and
    CoverageTarget > 0 and
    MaxCoverageScore >= CoverageTarget and
    HashPowerParticipationTargetPercent > 0 and
    HashPowerParticipationFloorPercent > 0 and
    HashPowerParticipationFloorPercent <= HashPowerParticipationTargetPercent and
    MaxHashPowerParticipationPercent == 100 and
    MaxHashPowerParticipationPercent >= HashPowerParticipationTargetPercent
  assume dynamic_finality_snapshot_pow_heights_are_in_range =
    Snapshots.forall(v => PowHeights.contains(HeightOf.get(v)))
  assume dynamic_finality_height_round_heads_are_snapshots =
    Heights.forall(h =>
      Rounds.forall(r => Snapshots.contains(HeadAt.get(h).get(r)))
    )

  pure def FailureKindKnown(kind: FailureKind_t): bool =
    kind == NoFailure or
    kind == SameBranchArrivalFailure or
    kind == LongReorgTailFailure or
    kind == AmbiguousCoverageFailure

  assume dynamic_finality_committed_telemetry_is_well_formed =
    Heights.forall(h =>
      FailureKindKnown(CommittedFailureKind.get(h)) and
      CommittedFailureCount.get(h) >= 0 and
      CommittedStableWindowCount.get(h) >= 0 and
      CommittedCoverageScore.get(h) >= 0 and
      CommittedCoverageScore.get(h) <= MaxCoverageScore and
      CommittedHashPowerParticipationPercent.get(h) >= 0 and
      CommittedHashPowerParticipationPercent.get(h) <= MaxHashPowerParticipationPercent
    )

  var nextFinalityHeight: Height_t
  var finalityDecision: Height_t -> Snapshot_t
  var latestFinal: Snapshot_t
  var finalized: Set[Snapshot_t]
  var finalityAction: str

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

  def Agrees(a: Snapshot_t, b: Snapshot_t): bool =
    Extends(a, b) or Extends(b, a)

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
    PowHeight(candidate) > PowHeight(finalizedPrefix) and
    TailConfirmsAtHeight(h, tip, candidate)

  def DynamicTipWitnessForHeight(
    h: Height_t,
    tip: Snapshot_t,
    candidate: Snapshot_t,
  ): bool =
    Rounds.exists(r =>
      tip == HeadAt.get(h).get(r) and candidate == DynamicHeadSigmaAt(h, r)
    )

  def ValidDynamicFinalityCandidateAtHeight(
    h: Height_t,
    candidate: Snapshot_t,
    tip: Snapshot_t,
  ): bool =
    DynamicTipWitnessForHeight(h, tip, candidate) and
    DynamicProposalValidAgainstFinalized(h, tip, candidate, latestFinal)

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

  action ComposedInit = all {
    Init,
    nextFinalityHeight' = 1,
    finalityDecision' = Heights.mapBy(_ => NilSnapshot),
    latestFinal' = InitialFinalized,
    finalized' = Set(InitialFinalized),
    finalityAction' = "ComposedInit",
  }

  action FinalityUnchanged = all {
    nextFinalityHeight' = nextFinalityHeight,
    finalityDecision' = finalityDecision,
    latestFinal' = latestFinal,
    finalized' = finalized,
    finalityAction' = finalityAction,
  }

  action ProtocolUnchanged = all {
    KeepValidatorState,
    KeepMessages,
    firedAction' = firedAction,
  }

  action Propose(p: Proc_t): bool =
    all { InsertProposal(p), FinalityUnchanged }

  action PrevoteValue(p: Proc_t, v: Snapshot_t): bool =
    all { Prevote(p, v), FinalityUnchanged }

  action PrecommitValueAt(p: Proc_t, v: Snapshot_t): bool =
    all { PrecommitValue(p, v), FinalityUnchanged }

  action PrecommitNilForStreamChange(p: Proc_t): bool =
    all { PrecommitNilOnStreamChange(p), FinalityUnchanged }

  action AdvanceRound(p: Proc_t): bool =
    all { AdvanceAfterPrecommitQuorum(p), FinalityUnchanged }

  action DecideValue(p: Proc_t, v: Snapshot_t): bool =
    all { Decide(p, v), FinalityUnchanged }

  action DeliverProposalToAll(
    from: Proc_t,
    h: Height_t,
    r: Round_t,
    v: Snapshot_t,
    vr: Round_t,
  ): bool = {
    val msg = { src: from, height: h, round: r, proposal: v, validRound: vr }
    all {
      h.in(Heights),
      r.in(Rounds),
      vr.in(ProposalValidRounds),
      msgsPropose.get(h).get(r).contains(msg),
      seenPropose' =
        Corr.mapBy(dst =>
          seenPropose.get(dst).setBy(h, byRound =>
            byRound.setBy(r, old => old.union(Set(msg)))
          )
        ),
      seenPrevote' = seenPrevote,
      seenPrecommit' = seenPrecommit,
      msgsPropose' = msgsPropose,
      msgsPrevote' = msgsPrevote,
      msgsPrecommit' = msgsPrecommit,
      KeepValidatorState,
      firedAction' = "DeliverProposalToAll",
      FinalityUnchanged,
    }
  }

  action DeliverPrevoteQuorumToAll(
    h: Height_t,
    r: Round_t,
    v: Snapshot_t,
    signers: Set[Proc_t],
  ): bool =
    all {
      h.in(Heights),
      r.in(Rounds),
      VoteValues.contains(v),
      signers.forall(s => Corr.union(Faulty).contains(s)),
      signers.forall(s => msgsPrevote.get(h).get(r).contains({
        src: s,
        height: h,
        round: r,
        id: v,
      })),
      seenPropose' = seenPropose,
      seenPrevote' =
        Corr.mapBy(dst =>
          seenPrevote.get(dst).setBy(h, byRound =>
            byRound.setBy(r, old => old.union(signers.map(s => {
              src: s,
              height: h,
              round: r,
              id: v,
            })))
          )
        ),
      seenPrecommit' = seenPrecommit,
      msgsPropose' = msgsPropose,
      msgsPrevote' = msgsPrevote,
      msgsPrecommit' = msgsPrecommit,
      KeepValidatorState,
      firedAction' = "DeliverPrevoteQuorumToAll",
      FinalityUnchanged,
    }

  action DeliverPrecommitQuorumToAll(
    h: Height_t,
    r: Round_t,
    v: Snapshot_t,
    signers: Set[Proc_t],
  ): bool =
    all {
      h.in(Heights),
      r.in(Rounds),
      VoteValues.contains(v),
      signers.forall(s => Corr.union(Faulty).contains(s)),
      signers.forall(s => msgsPrecommit.get(h).get(r).contains({
        src: s,
        height: h,
        round: r,
        id: v,
      })),
      seenPropose' = seenPropose,
      seenPrevote' = seenPrevote,
      seenPrecommit' =
        Corr.mapBy(dst =>
          seenPrecommit.get(dst).setBy(h, byRound =>
            byRound.setBy(r, old => old.union(signers.map(s => {
              src: s,
              height: h,
              round: r,
              id: v,
            })))
          )
        ),
      msgsPropose' = msgsPropose,
      msgsPrevote' = msgsPrevote,
      msgsPrecommit' = msgsPrecommit,
      KeepValidatorState,
      firedAction' = "DeliverPrecommitQuorumToAll",
      FinalityUnchanged,
    }

  action FinalizeNextDynamicDecided(
    p: Proc_t,
    candidate: Snapshot_t,
    tip: Snapshot_t,
  ): bool = {
    val h = nextFinalityHeight
    all {
      p.in(Corr),
      h.in(Heights),
      finalityDecision.get(h) == NilSnapshot,
      decision.get(p).get(h) == candidate,
      ValidDynamicFinalityCandidateAtHeight(h, candidate, tip),
      ProtocolUnchanged,
      nextFinalityHeight' = h + 1,
      finalityDecision' = finalityDecision.set(h, candidate),
      latestFinal' = candidate,
      finalized' = finalized.union(Set(candidate)),
      finalityAction' = "FinalizeNextDynamicDecided",
    }
  }

  action ProtocolNext =
    all { Next, FinalityUnchanged }

  action ComposedStutter = all {
    ProtocolUnchanged,
    FinalityUnchanged,
  }

  action ComposedNext =
    any {
      ProtocolNext,
      nondet p = oneOf(Corr)
      nondet candidate = oneOf(Snapshots)
      nondet tip = oneOf(Snapshots)
      FinalizeNextDynamicDecided(p, candidate, tip),
      ComposedStutter,
    }

  def FinalityHeightDecided(h: Height_t): bool =
    Heights.contains(h) and finalityDecision.get(h) != NilSnapshot

  val FinalityCursorSequential =
    CursorHeights.contains(nextFinalityHeight) and
    Heights.forall(h =>
      if (h < nextFinalityHeight) {
        FinalityHeightDecided(h)
      } else {
        finalityDecision.get(h) == NilSnapshot
      }
    )

  val FinalityDecisionsWereLocallyDecided =
    Heights.forall(h =>
      finalityDecision.get(h) == NilSnapshot or
      Corr.exists(p => decision.get(p).get(h) == finalityDecision.get(h))
    )

  val FinalityDecisionsRespectFinalizedPrefix =
    Heights.forall(h1 =>
      Heights.forall(h2 =>
        not(FinalityHeightDecided(h1) and FinalityHeightDecided(h2) and h1 < h2) or
        Extends(finalityDecision.get(h2), finalityDecision.get(h1))
      )
    )

  val FinalizedPrefixLinear =
    tuples(finalized, finalized).forall(((a, b)) =>
      Agrees(a, b)
    )

  val LatestFinalExtendsAllFinalized =
    finalized.forall(v => Extends(latestFinal, v))

  val InitialFinalizedRemainsFinalized =
    finalized.contains(InitialFinalized)

  val LatestFinalMatchesFinalityCursor =
    if (nextFinalityHeight == 1) {
      latestFinal == InitialFinalized
    } else {
      Heights.contains(nextFinalityHeight - 1) and
      finalityDecision.get(nextFinalityHeight - 1) == latestFinal
    }

  val FinalityDecisionsCarryDynamicHeadSigma =
    Heights.forall(h =>
      finalityDecision.get(h) == NilSnapshot or
      Rounds.exists(r => finalityDecision.get(h) == DynamicHeadSigmaAt(h, r))
    )

  val FinalityDecisionsHaveDynamicTail =
    Heights.forall(h =>
      finalityDecision.get(h) == NilSnapshot or
      Rounds.exists(r =>
        TailConfirmsAtHeight(
          h,
          HeadAt.get(h).get(r),
          finalityDecision.get(h),
        )
      )
    )

  val DynamicFinalitySafety =
    FinalityCursorSequential and
    FinalityDecisionsWereLocallyDecided and
    FinalityDecisionsRespectFinalizedPrefix and
    FinalizedPrefixLinear and
    LatestFinalExtendsAllFinalized and
    InitialFinalizedRemainsFinalized and
    LatestFinalMatchesFinalityCursor and
    FinalityDecisionsCarryDynamicHeadSigma and
    FinalityDecisionsHaveDynamicTail

  val DynamicHeightedFinalitySafety =
    Safety and
    SigmaScheduleMatchesTelemetry and
    SameBranchFailuresDoNotRaiseFutureSigmaByThemselves and
    CriticalHashPowerParticipationCanRaiseFutureSigma and
    StreamMatchesDynamicHeadSigma and
    DynamicHeadSigmaCandidatesAreValid and
    CorrectFreshProposalMessagesCarryDynamicHeadSigma and
    CorrectValuePrecommitsCarryDynamicHeadSigma and
    DynamicFinalitySafety
}

module CrosslinkDynamicSigmaHeightedFinalityTest {
  import CrosslinkDynamicSigmaHeightedFinality.* from "./CrosslinkDynamicSigmaHeightedFinality"
  export CrosslinkDynamicSigmaHeightedFinality.*

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
    nextFinalityHeight' = nextFinalityHeight,
    finalityDecision' = finalityDecision,
    latestFinal' = latestFinal,
    finalized' = finalized,
    finalityAction' = finalityAction,
  }

  action CommitHeightOneForAll = all {
    Propose("p1")
      .then(DeliverProposalToAll("p1", 1, 0, "a1", NilRound))
      .then(PrevoteValue("p1", "a1"))
      .then(PrevoteValue("p2", "a1"))
      .then(PrevoteValue("p3", "a1"))
      .then(DeliverPrevoteQuorumToAll(1, 0, "a1", Corr))
      .then(PrecommitValueAt("p1", "a1"))
      .then(PrecommitValueAt("p2", "a1"))
      .then(PrecommitValueAt("p3", "a1"))
      .then(DeliverPrecommitQuorumToAll(1, 0, "a1", Corr))
      .then(DecideValue("p1", "a1"))
      .then(DecideValue("p2", "a1"))
      .then(DecideValue("p3", "a1"))
  }

  action CommitHeightTwoForAll = all {
    Propose("p1")
      .then(DeliverProposalToAll("p1", 2, 0, "a2", NilRound))
      .then(PrevoteValue("p1", "a2"))
      .then(PrevoteValue("p2", "a2"))
      .then(PrevoteValue("p3", "a2"))
      .then(DeliverPrevoteQuorumToAll(2, 0, "a2", Corr))
      .then(PrecommitValueAt("p1", "a2"))
      .then(PrecommitValueAt("p2", "a2"))
      .then(PrecommitValueAt("p3", "a2"))
      .then(DeliverPrecommitQuorumToAll(2, 0, "a2", Corr))
      .then(DecideValue("p1", "a2"))
      .then(DecideValue("p2", "a2"))
      .then(DecideValue("p3", "a2"))
  }

  run nilResamplingFinalizesDynamicRoundCandidateTest = {
    ComposedInit
      .then(Propose("p1"))
      .then(DeliverProposalToAll("p1", 1, 0, "a1", NilRound))
      .then(PrevoteValue("p1", "a1"))
      .then(PrevoteValue("p2", "a1"))
      .then(PrevoteValue("p3", "a1"))
      .then(DeliverPrevoteQuorumToAll(1, 0, "a1", Corr))
      .then(PrecommitNilForStreamChange("p1"))
      .then(PrecommitNilForStreamChange("p2"))
      .then(PrecommitNilForStreamChange("p3"))
      .then(DeliverPrecommitQuorumToAll(1, 0, NilSnapshot, Corr))
      .then(AdvanceRound("p1"))
      .then(AdvanceRound("p2"))
      .then(AdvanceRound("p3"))
      .then(Propose("p1"))
      .then(DeliverProposalToAll("p1", 1, 1, "b1", NilRound))
      .then(PrevoteValue("p1", "b1"))
      .then(PrevoteValue("p2", "b1"))
      .then(PrevoteValue("p3", "b1"))
      .then(DeliverPrevoteQuorumToAll(1, 1, "b1", Corr))
      .then(PrecommitValueAt("p1", "b1"))
      .then(PrecommitValueAt("p2", "b1"))
      .then(PrecommitValueAt("p3", "b1"))
      .then(DeliverPrecommitQuorumToAll(1, 1, "b1", Corr))
      .then(DecideValue("p1", "b1"))
      .then(FinalizeNextDynamicDecided("p1", "b1", "b2"))
      .then(all {
        assert(SigmaForHeight(1) == 1),
        assert(DynamicHeadSigmaAt(1, 1) == "b1"),
        assert(nextFinalityHeight == 2),
        assert(latestFinal == "b1"),
        assert(finalityDecision.get(1) == "b1"),
        assert(DynamicHeightedFinalitySafety),
        unchangedAll,
      })
  }

  run telemetryRaisedSigmaFinalizesNextHeightTest = {
    ComposedInit
      .then(CommitHeightOneForAll)
      .then(FinalizeNextDynamicDecided("p1", "a1", "a2"))
      .then(CommitHeightTwoForAll)
      .then(FinalizeNextDynamicDecided("p1", "a2", "a4"))
      .then(all {
        assert(SigmaForHeight(1) == 1),
        assert(SigmaForHeight(2) == 2),
        assert(DynamicHeadSigmaAt(2, 0) == "a2"),
        assert(nextFinalityHeight == 3),
        assert(latestFinal == "a2"),
        assert(finalityDecision.get(2) == "a2"),
        assert(DynamicHeightedFinalitySafety),
        unchangedAll,
      })
  }

  run rejectsHeightTwoFinalityWithoutDynamicSigmaTailTest = {
    ComposedInit
      .then(CommitHeightOneForAll)
      .then(FinalizeNextDynamicDecided("p1", "a1", "a2"))
      .then(CommitHeightTwoForAll)
      .then(FinalizeNextDynamicDecided("p1", "a2", "a3"))
      .fail()
  }

  run rejectsUndecidedDynamicHeightFinalizationTest = {
    ComposedInit
      .then(FinalizeNextDynamicDecided("p1", "a1", "a2"))
      .fail()
  }

  run dynamicHeightedFinalitySafetyTest = {
    ComposedInit
      .then(all {
        assert(DynamicHeightedFinalitySafety),
        unchangedAll,
      })
  }
}

module CrosslinkDynamicSigmaHeightedFinalityModel {
  import CrosslinkDynamicSigmaHeightedFinalityTest(
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
