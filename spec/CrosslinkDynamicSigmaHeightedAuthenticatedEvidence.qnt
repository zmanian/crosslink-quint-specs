module CrosslinkDynamicSigmaHeightedAuthenticatedEvidence {
  /*
   Dynamic-sigma boundary for heighted authenticated evidence.

   CrosslinkHeightedAuthenticatedEvidence.qnt checks canonical sign bytes,
   gossip-before-observe, and validator-set authorization. This wrapper keeps
   those checks, but restricts decisions, value precommit evidence, and
   fat-pointer evidence to the active height's `head - sigma(h)` candidate.
   */

  import CrosslinkHeightedAuthenticatedEvidence.* from "./CrosslinkHeightedAuthenticatedEvidence"
  export CrosslinkHeightedAuthenticatedEvidence.*

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

  assume dynamic_auth_height_domain_has_transition =
    MaxBftHeight >= 2
  assume dynamic_auth_initial_finalized_is_snapshot =
    Snapshots.contains(InitialFinalized)
  assume dynamic_auth_sigma_bounds_are_valid =
    MinSigma >= 1 and MaxSigma >= MinSigma and SigmaValues.contains(InitialSigma)
  assume dynamic_auth_thresholds_are_positive =
    FailureThreshold > 0 and
    StableWindowThreshold > 0 and
    CoverageTarget > 0 and
    MaxCoverageScore >= CoverageTarget and
    HashPowerParticipationTargetPercent > 0 and
    HashPowerParticipationFloorPercent > 0 and
    HashPowerParticipationFloorPercent <= HashPowerParticipationTargetPercent and
    MaxHashPowerParticipationPercent == 100 and
    MaxHashPowerParticipationPercent >= HashPowerParticipationTargetPercent
  assume dynamic_auth_snapshot_pow_heights_are_in_range =
    Snapshots.forall(v => PowHeights.contains(HeightOf.get(v)))
  assume dynamic_auth_height_round_heads_are_snapshots =
    Heights.forall(h =>
      Rounds.forall(r => Snapshots.contains(HeadAt.get(h).get(r)))
    )

  pure def FailureKindKnown(kind: FailureKind_t): bool =
    kind == NoFailure or
    kind == SameBranchArrivalFailure or
    kind == LongReorgTailFailure or
    kind == AmbiguousCoverageFailure

  assume dynamic_auth_committed_telemetry_is_well_formed =
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

  def DynamicValueForHeightRound(
    h: Height_t,
    r: Round_t,
    v: Snapshot_t,
  ): bool =
    h.in(Heights) and r.in(Rounds) and v == DynamicHeadSigmaAt(h, r)

  def DynamicVoteValueForHeightRound(
    h: Height_t,
    r: Round_t,
    v: Snapshot_t,
  ): bool =
    v == NilSnapshot or DynamicValueForHeightRound(h, r, v)

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

  val DynamicHeadSigmaCandidatesAreValid =
    Heights.forall(h =>
      Rounds.forall(r =>
        Extends(DynamicHeadSigmaAt(h, r), InitialFinalized) and
        TailConfirmsAtHeight(h, HeadAt.get(h).get(r), DynamicHeadSigmaAt(h, r))
      )
    )

  action DynamicInit = Init

  action DecideDynamicAt(
    h: Height_t,
    candidate: Snapshot_t,
    signers: Set[Proc_t],
  ): bool =
    all {
      Rounds.exists(r => DynamicValueForHeightRound(h, r, candidate)),
      DecideAt(h, candidate, signers),
    }

  action GossipDynamicPrecommit(
    p: Proc_t,
    h: Height_t,
    r: Round_t,
    v: Snapshot_t,
    bytes: Bytes_t,
    sig: Sig_t,
  ): bool =
    all {
      DynamicVoteValueForHeightRound(h, r, v),
      GossipPrecommit(p, h, r, v, bytes, sig),
    }

  action ObserveDynamicPrecommit(
    p: Proc_t,
    h: Height_t,
    r: Round_t,
    v: Snapshot_t,
    bytes: Bytes_t,
    sig: Sig_t,
  ): bool =
    all {
      DynamicVoteValueForHeightRound(h, r, v),
      ObservePrecommit(p, h, r, v, bytes, sig),
    }

  action GossipDynamicFatPointerSig(
    p: Proc_t,
    h: Height_t,
    r: Round_t,
    v: Snapshot_t,
    bytes: Bytes_t,
    sig: Sig_t,
  ): bool =
    all {
      DynamicValueForHeightRound(h, r, v),
      GossipFatPointerSig(p, h, r, v, bytes, sig),
    }

  action ObserveDynamicFatPointer(
    h: Height_t,
    r: Round_t,
    v: Snapshot_t,
    signers: Set[Proc_t],
  ): bool =
    all {
      DynamicValueForHeightRound(h, r, v),
      ObserveFatPointer(h, r, v, signers),
    }

  action DynamicNext =
    any {
      nondet h = oneOf(Heights)
      nondet candidate = oneOf(Snapshots)
      nondet signers = oneOf(powerset(ValidatorUniverse))
      DecideDynamicAt(h, candidate, signers),
      nondet p = oneOf(ValidatorUniverse)
      nondet h = oneOf(Heights)
      nondet r = oneOf(Rounds)
      nondet v = oneOf(VoteValues)
      nondet bytes = oneOf(Bytes)
      nondet sig = oneOf(Signatures)
      GossipDynamicPrecommit(p, h, r, v, bytes, sig),
      nondet p = oneOf(ValidatorUniverse)
      nondet h = oneOf(Heights)
      nondet r = oneOf(Rounds)
      nondet v = oneOf(VoteValues)
      nondet bytes = oneOf(Bytes)
      nondet sig = oneOf(Signatures)
      ObserveDynamicPrecommit(p, h, r, v, bytes, sig),
      nondet p = oneOf(ValidatorUniverse)
      nondet h = oneOf(Heights)
      nondet r = oneOf(Rounds)
      nondet v = oneOf(Snapshots)
      nondet bytes = oneOf(Bytes)
      nondet sig = oneOf(Signatures)
      GossipDynamicFatPointerSig(p, h, r, v, bytes, sig),
      nondet h = oneOf(Heights)
      nondet r = oneOf(Rounds)
      nondet v = oneOf(Snapshots)
      nondet signers = oneOf(powerset(ValidatorUniverse))
      ObserveDynamicFatPointer(h, r, v, signers),
      Stutter,
    }

  val DecisionsCarryDynamicHeadSigma =
    Heights.forall(h =>
      decision.get(h) == NilSnapshot or
      Rounds.exists(r => DynamicValueForHeightRound(h, r, decision.get(h)))
    )

  val GossipedPrecommitsCarryDynamicHeadSigma =
    Heights.forall(h =>
      Rounds.forall(r =>
        gossipPrecommit.get(h).get(r).forall(m =>
          DynamicVoteValueForHeightRound(m.height, m.round, m.id)
        )
      )
    )

  val ObservedPrecommitsCarryDynamicHeadSigma =
    Heights.forall(h =>
      Rounds.forall(r =>
        observedPrecommit.get(h).get(r).forall(m =>
          DynamicVoteValueForHeightRound(m.height, m.round, m.id)
        )
      )
    )

  val GossipedFatPointerSigsCarryDynamicHeadSigma =
    Heights.forall(h =>
      Rounds.forall(r =>
        gossipFatPointerSig.get(h).get(r).forall(m =>
          DynamicValueForHeightRound(m.height, m.round, m.id)
        )
      )
    )

  val ObservedFatPointersCarryDynamicHeadSigma =
    observedFatPointer.forall(fp =>
      DynamicValueForHeightRound(fp.height, fp.round, fp.id)
    )

  val DynamicAuthenticatedEvidenceSafety =
    Safety and
    SigmaScheduleMatchesTelemetry and
    SameBranchFailuresDoNotRaiseFutureSigmaByThemselves and
    CriticalHashPowerParticipationCanRaiseFutureSigma and
    DynamicHeadSigmaCandidatesAreValid and
    DecisionsCarryDynamicHeadSigma and
    GossipedPrecommitsCarryDynamicHeadSigma and
    ObservedPrecommitsCarryDynamicHeadSigma and
    GossipedFatPointerSigsCarryDynamicHeadSigma and
    ObservedFatPointersCarryDynamicHeadSigma
}

module CrosslinkDynamicSigmaHeightedAuthenticatedEvidenceTest {
  import CrosslinkDynamicSigmaHeightedAuthenticatedEvidence.* from "./CrosslinkDynamicSigmaHeightedAuthenticatedEvidence"
  export CrosslinkDynamicSigmaHeightedAuthenticatedEvidence.*

  action unchangedAll = all {
    nextBftHeight' = nextBftHeight,
    currentValidatorSet' = currentValidatorSet,
    validatorSetAtHeight' = validatorSetAtHeight,
    decision' = decision,
    commitSigners' = commitSigners,
    gossipPrecommit' = gossipPrecommit,
    gossipFatPointerSig' = gossipFatPointerSig,
    observedPrecommit' = observedPrecommit,
    observedFatPointer' = observedFatPointer,
    firedAction' = firedAction,
  }

  run dynamicAuthenticatedEvidenceAcceptedTest = {
    DynamicInit
      .then(DecideDynamicAt(1, "a1", Set("p1", "p2")))
      .then(GossipDynamicPrecommit("p1", 1, 0, "a1", "pc-1-0-a1", "sig-p1-pc-1-0-a1"))
      .then(GossipDynamicPrecommit("p2", 1, 0, "a1", "pc-1-0-a1", "sig-p2-pc-1-0-a1"))
      .then(ObserveDynamicPrecommit("p1", 1, 0, "a1", "pc-1-0-a1", "sig-p1-pc-1-0-a1"))
      .then(ObserveDynamicPrecommit("p2", 1, 0, "a1", "pc-1-0-a1", "sig-p2-pc-1-0-a1"))
      .then(GossipDynamicFatPointerSig("p1", 1, 0, "a1", "fp-1-0-a1", "sig-p1-fp-1-0-a1"))
      .then(GossipDynamicFatPointerSig("p2", 1, 0, "a1", "fp-1-0-a1", "sig-p2-fp-1-0-a1"))
      .then(ObserveDynamicFatPointer(1, 0, "a1", Set("p1", "p2")))
      .then(all {
        assert(DynamicHeadSigmaAt(1, 0) == "a1"),
        assert(observedFatPointer.contains({
          height: 1,
          round: 0,
          id: "a1",
          signers: Set("p1", "p2"),
        })),
        assert(DynamicAuthenticatedEvidenceSafety),
        unchangedAll,
      })
  }

  run telemetryRaisedHeightTwoEvidenceAcceptedTest = {
    DynamicInit
      .then(DecideDynamicAt(1, "a1", Set("p1", "p2")))
      .then(DecideDynamicAt(2, "a2", Set("p1", "p2")))
      .then(GossipDynamicPrecommit("p1", 2, 0, "a2", "pc-2-0-a2", "sig-p1-pc-2-0-a2"))
      .then(GossipDynamicPrecommit("p2", 2, 0, "a2", "pc-2-0-a2", "sig-p2-pc-2-0-a2"))
      .then(ObserveDynamicPrecommit("p1", 2, 0, "a2", "pc-2-0-a2", "sig-p1-pc-2-0-a2"))
      .then(ObserveDynamicPrecommit("p2", 2, 0, "a2", "pc-2-0-a2", "sig-p2-pc-2-0-a2"))
      .then(GossipDynamicFatPointerSig("p1", 2, 0, "a2", "fp-2-0-a2", "sig-p1-fp-2-0-a2"))
      .then(GossipDynamicFatPointerSig("p2", 2, 0, "a2", "fp-2-0-a2", "sig-p2-fp-2-0-a2"))
      .then(ObserveDynamicFatPointer(2, 0, "a2", Set("p1", "p2")))
      .then(all {
        assert(SigmaForHeight(2) == 2),
        assert(DynamicHeadSigmaAt(2, 0) == "a2"),
        assert(observedFatPointer.contains({
          height: 2,
          round: 0,
          id: "a2",
          signers: Set("p1", "p2"),
        })),
        assert(DynamicAuthenticatedEvidenceSafety),
        unchangedAll,
      })
  }

  run wrongHeightOneDynamicPrecommitRejectedTest = {
    DynamicInit
      .then(GossipDynamicPrecommit("p1", 1, 0, "a2", "pc-1-0-a2", "sig-p1-pc-1-0-a2"))
      .fail()
  }

  run wrongHeightTwoDynamicPrecommitRejectedTest = {
    DynamicInit
      .then(DecideDynamicAt(1, "a1", Set("p1", "p2")))
      .then(GossipDynamicPrecommit("p1", 2, 0, "a3", "pc-2-0-a3", "sig-p1-pc-2-0-a3"))
      .fail()
  }

  run wrongDynamicFatPointerRejectedTest = {
    DynamicInit
      .then(GossipDynamicFatPointerSig("p1", 1, 0, "a2", "fp-1-0-a2", "sig-p1-fp-1-0-a2"))
      .fail()
  }

  run dynamicAuthenticatedEvidenceSafetyTest = {
    DynamicInit
      .then(all {
        assert(DynamicAuthenticatedEvidenceSafety),
        unchangedAll,
      })
  }
}

module CrosslinkDynamicSigmaHeightedAuthenticatedEvidenceModel {
  import CrosslinkDynamicSigmaHeightedAuthenticatedEvidenceTest(
    ValidatorUniverse = Set("p1", "p2", "p3"),
    VotingPower = Map("p1" -> 1, "p2" -> 1, "p3" -> 1),
    QuorumVotingPower = 2,
    MaxBftHeight = 2,
    MaxRound = 0,
    Snapshots = Set("g", "a1", "a2", "a3", "a4"),
    Bytes = Set(
      "pc-1-0-g",
      "pc-1-0-a1",
      "pc-1-0-a2",
      "pc-1-0-a3",
      "pc-1-0-a4",
      "pc-1-0-None",
      "pc-2-0-g",
      "pc-2-0-a1",
      "pc-2-0-a2",
      "pc-2-0-a3",
      "pc-2-0-a4",
      "pc-2-0-None",
      "fp-1-0-g",
      "fp-1-0-a1",
      "fp-1-0-a2",
      "fp-1-0-a3",
      "fp-1-0-a4",
      "fp-2-0-g",
      "fp-2-0-a1",
      "fp-2-0-a2",
      "fp-2-0-a3",
      "fp-2-0-a4",
    ),
    Signatures = Set(
      "sig-p1-pc-1-0-a1",
      "sig-p2-pc-1-0-a1",
      "sig-p1-fp-1-0-a1",
      "sig-p2-fp-1-0-a1",
      "sig-p1-pc-1-0-a2",
      "sig-p1-fp-1-0-a2",
      "sig-p1-pc-2-0-a2",
      "sig-p2-pc-2-0-a2",
      "sig-p1-fp-2-0-a2",
      "sig-p2-fp-2-0-a2",
      "sig-p1-pc-2-0-a3",
    ),
    SignatureOwner = Map(
      "sig-p1-pc-1-0-a1" -> "p1",
      "sig-p2-pc-1-0-a1" -> "p2",
      "sig-p1-fp-1-0-a1" -> "p1",
      "sig-p2-fp-1-0-a1" -> "p2",
      "sig-p1-pc-1-0-a2" -> "p1",
      "sig-p1-fp-1-0-a2" -> "p1",
      "sig-p1-pc-2-0-a2" -> "p1",
      "sig-p2-pc-2-0-a2" -> "p2",
      "sig-p1-fp-2-0-a2" -> "p1",
      "sig-p2-fp-2-0-a2" -> "p2",
      "sig-p1-pc-2-0-a3" -> "p1",
    ),
    SignatureBytes = Map(
      "sig-p1-pc-1-0-a1" -> "pc-1-0-a1",
      "sig-p2-pc-1-0-a1" -> "pc-1-0-a1",
      "sig-p1-fp-1-0-a1" -> "fp-1-0-a1",
      "sig-p2-fp-1-0-a1" -> "fp-1-0-a1",
      "sig-p1-pc-1-0-a2" -> "pc-1-0-a2",
      "sig-p1-fp-1-0-a2" -> "fp-1-0-a2",
      "sig-p1-pc-2-0-a2" -> "pc-2-0-a2",
      "sig-p2-pc-2-0-a2" -> "pc-2-0-a2",
      "sig-p1-fp-2-0-a2" -> "fp-2-0-a2",
      "sig-p2-fp-2-0-a2" -> "fp-2-0-a2",
      "sig-p1-pc-2-0-a3" -> "pc-2-0-a3",
    ),
    PrecommitPayload = Map(
      1 -> Map(0 -> Map(
        "g" -> "pc-1-0-g",
        "a1" -> "pc-1-0-a1",
        "a2" -> "pc-1-0-a2",
        "a3" -> "pc-1-0-a3",
        "a4" -> "pc-1-0-a4",
        "None" -> "pc-1-0-None",
      )),
      2 -> Map(0 -> Map(
        "g" -> "pc-2-0-g",
        "a1" -> "pc-2-0-a1",
        "a2" -> "pc-2-0-a2",
        "a3" -> "pc-2-0-a3",
        "a4" -> "pc-2-0-a4",
        "None" -> "pc-2-0-None",
      )),
    ),
    FatPointerPayload = Map(
      1 -> Map(0 -> Map(
        "g" -> "fp-1-0-g",
        "a1" -> "fp-1-0-a1",
        "a2" -> "fp-1-0-a2",
        "a3" -> "fp-1-0-a3",
        "a4" -> "fp-1-0-a4",
      )),
      2 -> Map(0 -> Map(
        "g" -> "fp-2-0-g",
        "a1" -> "fp-2-0-a1",
        "a2" -> "fp-2-0-a2",
        "a3" -> "fp-2-0-a3",
        "a4" -> "fp-2-0-a4",
      )),
    ),
    InitialValidatorSet = Set("p1", "p2", "p3"),
    NextValidatorSetOf = Map(
      "g" -> Set("p1", "p2", "p3"),
      "a1" -> Set("p1", "p2", "p3"),
      "a2" -> Set("p1", "p2", "p3"),
      "a3" -> Set("p1", "p2", "p3"),
      "a4" -> Set("p1", "p2", "p3"),
    ),
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
      1 -> Map(0 -> "a2"),
      2 -> Map(0 -> "a4"),
    ),
  ).*
}
