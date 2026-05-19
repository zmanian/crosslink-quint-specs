module CrosslinkDynamicSigma {
  /*
   Third Crosslink variant: nil-precommit resampling plus a consensus-visible
   sigma controller.

   Baseline Crosslink and fixed-sigma resampling treat sigma as a static
   parameter. This variant makes sigma part of the committed BFT-height state:
   validators use one sigma value for the entire active height, then compute
   the next height's sigma from committed round-failure telemetry, a
   quorum-backed network coverage model, and the observed percentage of PoW
   hash power participating in Crosslink. The participation target gates sigma
   relaxation, while a lower participation floor is a direct risk signal that
   raises sigma even before a classified long-reorg failure appears.

   The important safety shape is:
   - nil-precommit failures can burn rounds without changing same-height sigma,
   - sigma only changes at height boundaries,
   - the update is deterministic from committed evidence,
   - ordinary same-branch head-arrival churn is not treated as sigma-relevant,
   - long-reorg-tail or ambiguous low-coverage/low-hash-participation failures
     can raise sigma,
   - critically low Crosslink-participating hash power can raise sigma by
     itself, and
   - stable, well-covered, high-participation windows lower sigma slowly.
   */

  type Height_t = int
  type Sigma_t = int
  type FailureKind_t = str

  const MaxHeight: Height_t
  const MinSigma: Sigma_t
  const MaxSigma: Sigma_t
  const InitialSigma: Sigma_t
  const FailureThreshold: int
  const StableWindowThreshold: int
  const CoverageTarget: int
  const MaxCoverageScore: int
  const HashPowerParticipationTargetPercent: int
  const HashPowerParticipationFloorPercent: int
  const MaxHashPowerParticipationPercent: int
  const CommittedFailureKind: Height_t -> FailureKind_t
  const CommittedFailureCount: Height_t -> int
  const CommittedStableWindowCount: Height_t -> int
  const CommittedCoverageScore: Height_t -> int
  const CommittedHashPowerParticipationPercent: Height_t -> int

  pure val BaselineFixedSigmaVariant = "baseline-fixed-sigma"
  pure val NilPrecommitFixedSigmaVariant = "nil-precommit-fixed-sigma"
  pure val DynamicSigmaVariant = "dynamic-sigma-resampling"
  pure val Variant = DynamicSigmaVariant

  pure val NoFailure = "none"
  pure val SameBranchArrivalFailure = "same-branch-arrival"
  pure val LongReorgTailFailure = "long-reorg-tail"
  pure val AmbiguousCoverageFailure = "ambiguous-low-coverage"

  pure val Heights = 0.to(MaxHeight)
  pure val TransitionHeights = 0.to(MaxHeight - 1)
  pure val SigmaValues = MinSigma.to(MaxSigma)

  assume height_domain_is_nonempty =
    MaxHeight >= 1

  assume sigma_bounds_are_valid =
    MinSigma >= 1 and
    MaxSigma >= MinSigma and
    SigmaValues.contains(InitialSigma)

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

  var height: Height_t
  var sigma: Sigma_t
  var sigmaAtHeight: Height_t -> Sigma_t
  var committedTelemetryHeights: Set[Height_t]
  var burnedNilRounds: Height_t -> int
  var lastHeightBefore: Height_t
  var lastSigmaBefore: Sigma_t
  var firedAction: str

  pure def SigmaInBounds(value: Sigma_t): bool =
    SigmaValues.contains(value)

  pure def ClampSigma(value: Sigma_t): Sigma_t =
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

  pure def NextSigmaForHeight(currentSigma: Sigma_t, h: Height_t): Sigma_t =
    if (ShouldRaiseSigma(h)) {
      ClampSigma(currentSigma + 1)
    } else {
      if (ShouldLowerSigma(h)) {
        ClampSigma(currentSigma - 1)
      } else {
        currentSigma
      }
    }

  action Init = all {
    height' = 0,
    sigma' = InitialSigma,
    sigmaAtHeight' = Heights.mapBy(_ => InitialSigma),
    committedTelemetryHeights' = Set(),
    burnedNilRounds' = Heights.mapBy(_ => 0),
    lastHeightBefore' = 0,
    lastSigmaBefore' = InitialSigma,
    firedAction' = "Init",
  }

  action BurnNilPrecommitRound: bool = all {
    Heights.contains(height),
    lastHeightBefore' = height,
    lastSigmaBefore' = sigma,
    height' = height,
    sigma' = sigma,
    sigmaAtHeight' = sigmaAtHeight,
    committedTelemetryHeights' = committedTelemetryHeights,
    burnedNilRounds' =
      burnedNilRounds.set(height, burnedNilRounds.get(height) + 1),
    firedAction' = "BurnNilPrecommitRound",
  }

  action CommitHeightWithTelemetry: bool = {
    val h = height
    val nextSigma = NextSigmaForHeight(sigma, h)
    all {
      TransitionHeights.contains(h),
      lastHeightBefore' = h,
      lastSigmaBefore' = sigma,
      height' = h + 1,
      sigma' = nextSigma,
      sigmaAtHeight' = sigmaAtHeight.set(h + 1, nextSigma),
      committedTelemetryHeights' = committedTelemetryHeights.union(Set(h)),
      burnedNilRounds' = burnedNilRounds,
      firedAction' = "CommitHeightWithTelemetry",
    }
  }

  action Stutter = all {
    lastHeightBefore' = height,
    lastSigmaBefore' = sigma,
    height' = height,
    sigma' = sigma,
    sigmaAtHeight' = sigmaAtHeight,
    committedTelemetryHeights' = committedTelemetryHeights,
    burnedNilRounds' = burnedNilRounds,
    firedAction' = "Stutter",
  }

  action Next =
    any {
      BurnNilPrecommitRound,
      CommitHeightWithTelemetry,
      Stutter,
    }

  val DynamicSigmaIsThirdVariant =
    Variant == DynamicSigmaVariant and
    Variant != BaselineFixedSigmaVariant and
    Variant != NilPrecommitFixedSigmaVariant

  val ActiveSigmaMatchesHeightSchedule =
    SigmaInBounds(sigma) and
    Heights.contains(height) and
    sigma == sigmaAtHeight.get(height)

  val SigmaScheduleWithinBounds =
    Heights.forall(h =>
      if (h <= height) {
        SigmaInBounds(sigmaAtHeight.get(h))
      } else {
        true
      }
    )

  val SigmaChangesOnlyAtHeightBoundary =
    if (sigma != lastSigmaBefore) {
      firedAction == "CommitHeightWithTelemetry" and
      height == lastHeightBefore + 1
    } else {
      true
    }

  val SameHeightSigmaStable =
    if (height == lastHeightBefore) {
      sigma == lastSigmaBefore
    } else {
      true
    }

  val CommitUsesDeterministicTelemetry =
    if (firedAction == "CommitHeightWithTelemetry") {
      sigma == NextSigmaForHeight(lastSigmaBefore, lastHeightBefore) and
      committedTelemetryHeights.contains(lastHeightBefore)
    } else {
      true
    }

  val SameBranchFailuresDoNotRaiseSigmaByThemselves =
    Heights.forall(h =>
      if (
        CommittedFailureKind.get(h) == SameBranchArrivalFailure and
        not(HashPowerParticipationFloorBreachedAt(h))
      ) {
        not(ShouldRaiseSigma(h))
      } else {
        true
      }
    )

  val IncompleteCoverageCannotLowerSigma =
    Heights.forall(h =>
      if (not(CoverageCompleteAt(h))) {
        not(ShouldLowerSigma(h))
      } else {
        true
      }
    )

  val LowHashPowerParticipationCannotLowerSigma =
    Heights.forall(h =>
      if (not(HashPowerParticipationCompleteAt(h))) {
        not(ShouldLowerSigma(h))
      } else {
        true
      }
    )

  val HashPowerParticipationFactorsIntoSigmaPressure =
    Heights.forall(h =>
      if (
        not(HashPowerParticipationCompleteAt(h)) and
        (CommittedFailureKind.get(h) == LongReorgTailFailure or
          CommittedFailureKind.get(h) == AmbiguousCoverageFailure)
      ) {
        SigmaRelevantFailurePressure(h) >
          CommittedFailureCount.get(h) + CoverageDeficitAt(h)
      } else {
        true
      }
    )

  val CriticalHashPowerParticipationCanRaiseSigma =
    SigmaValues.forall(currentSigma =>
      Heights.forall(h =>
        if (
          HashPowerParticipationFloorBreachedAt(h) and
          currentSigma < MaxSigma
        ) {
          NextSigmaForHeight(currentSigma, h) == currentSigma + 1
        } else {
          true
        }
      )
    )

  val SigmaStepIsAtMostOne =
    SigmaValues.forall(currentSigma =>
      Heights.forall(h =>
        NextSigmaForHeight(currentSigma, h) == currentSigma or
        NextSigmaForHeight(currentSigma, h) == currentSigma + 1 or
        NextSigmaForHeight(currentSigma, h) == currentSigma - 1
      )
    )

  val LongReorgFailureCanRaiseSigma =
    SigmaValues.forall(currentSigma =>
      Heights.forall(h =>
        if (
          CommittedFailureKind.get(h) == LongReorgTailFailure and
          CommittedFailureCount.get(h) >= FailureThreshold and
          currentSigma < MaxSigma
        ) {
          NextSigmaForHeight(currentSigma, h) == currentSigma + 1
        } else {
          true
        }
      )
    )

  val StableCoveredWindowLowersSigmaSlowly =
    SigmaValues.forall(currentSigma =>
      Heights.forall(h =>
        if (
          CommittedFailureKind.get(h) == NoFailure and
          CommittedFailureCount.get(h) == 0 and
          CommittedStableWindowCount.get(h) >= StableWindowThreshold and
          CoverageCompleteAt(h) and
          HashPowerParticipationCompleteAt(h) and
          currentSigma > MinSigma
        ) {
          NextSigmaForHeight(currentSigma, h) == currentSigma - 1
        } else {
          true
        }
      )
    )

  val NilRoundBurnsDoNotRewriteSigmaSchedule =
    if (firedAction == "BurnNilPrecommitRound") {
      height == lastHeightBefore and
      sigma == lastSigmaBefore and
      sigmaAtHeight.get(height) == sigma
    } else {
      true
    }

  val BurnedNilRoundsNonNegative =
    Heights.forall(h => burnedNilRounds.get(h) >= 0)

  val Safety =
    DynamicSigmaIsThirdVariant and
    ActiveSigmaMatchesHeightSchedule and
    SigmaScheduleWithinBounds and
    SigmaChangesOnlyAtHeightBoundary and
    SameHeightSigmaStable and
    CommitUsesDeterministicTelemetry and
    SameBranchFailuresDoNotRaiseSigmaByThemselves and
    IncompleteCoverageCannotLowerSigma and
    LowHashPowerParticipationCannotLowerSigma and
    HashPowerParticipationFactorsIntoSigmaPressure and
    CriticalHashPowerParticipationCanRaiseSigma and
    SigmaStepIsAtMostOne and
    LongReorgFailureCanRaiseSigma and
    StableCoveredWindowLowersSigmaSlowly and
    NilRoundBurnsDoNotRewriteSigmaSchedule and
    BurnedNilRoundsNonNegative
}

module CrosslinkDynamicSigmaTest {
  import CrosslinkDynamicSigma.* from "./CrosslinkDynamicSigma"
  export CrosslinkDynamicSigma.*

  action unchangedAll = all {
    height' = height,
    sigma' = sigma,
    sigmaAtHeight' = sigmaAtHeight,
    committedTelemetryHeights' = committedTelemetryHeights,
    burnedNilRounds' = burnedNilRounds,
    lastHeightBefore' = lastHeightBefore,
    lastSigmaBefore' = lastSigmaBefore,
    firedAction' = firedAction,
  }

  run dynamicSigmaIsAThirdVariantTest = {
    Init
      .then(all {
        assert(DynamicSigmaIsThirdVariant),
        unchangedAll,
      })
  }

  run nilPrecommitRoundBurnDoesNotChangeSameHeightSigmaTest = {
    Init
      .then(BurnNilPrecommitRound)
      .then(all {
        assert(height == 0),
        assert(sigma == InitialSigma),
        assert(burnedNilRounds.get(0) == 1),
        assert(NilRoundBurnsDoNotRewriteSigmaSchedule),
        assert(Safety),
        unchangedAll,
      })
  }

  run longReorgTelemetryRaisesNextHeightSigmaTest = {
    Init
      .then(CommitHeightWithTelemetry)
      .then(all {
        assert(height == 1),
        assert(sigma == 3),
        assert(sigmaAtHeight.get(1) == 3),
        assert(ShouldRaiseSigma(0)),
        assert(Safety),
        unchangedAll,
      })
  }

  run sameBranchFailureDoesNotRaiseSigmaTest = {
    Init
      .then(CommitHeightWithTelemetry)
      .then(CommitHeightWithTelemetry)
      .then(all {
        assert(height == 2),
        assert(CommittedFailureKind.get(1) == SameBranchArrivalFailure),
        assert(not(HashPowerParticipationFloorBreachedAt(1))),
        assert(not(ShouldRaiseSigma(1))),
        assert(sigma == 3),
        assert(Safety),
        unchangedAll,
      })
  }

  run stableCoveredWindowLowersSigmaSlowlyTest = {
    Init
      .then(CommitHeightWithTelemetry)
      .then(CommitHeightWithTelemetry)
      .then(CommitHeightWithTelemetry)
      .then(all {
        assert(height == 3),
        assert(sigma == 2),
        assert(ShouldLowerSigma(2)),
        assert(Safety),
        unchangedAll,
      })
  }

  run incompleteCoverageDoesNotLowerSigmaTest = {
    Init
      .then(CommitHeightWithTelemetry)
      .then(CommitHeightWithTelemetry)
      .then(CommitHeightWithTelemetry)
      .then(CommitHeightWithTelemetry)
      .then(all {
        assert(height == 4),
        assert(not(CoverageCompleteAt(3))),
        assert(not(ShouldLowerSigma(3))),
        assert(sigma == 2),
        assert(Safety),
        unchangedAll,
      })
  }

  run ambiguousLowCoverageFailureRaisesConservativelyTest = {
    Init
      .then(CommitHeightWithTelemetry)
      .then(CommitHeightWithTelemetry)
      .then(CommitHeightWithTelemetry)
      .then(CommitHeightWithTelemetry)
      .then(CommitHeightWithTelemetry)
      .then(all {
        assert(height == 5),
        assert(CommittedFailureKind.get(4) == AmbiguousCoverageFailure),
        assert(not(HashPowerParticipationCompleteAt(4))),
        assert(HashPowerParticipationDeficitAt(4) == 37),
        assert(HashPowerParticipationFactorsIntoSigmaPressure),
        assert(ShouldRaiseSigma(4)),
        assert(sigma == 3),
        assert(Safety),
        unchangedAll,
      })
  }

  run lowHashPowerParticipationPreventsSigmaRelaxationTest = {
    Init
      .then(CommitHeightWithTelemetry)
      .then(CommitHeightWithTelemetry)
      .then(CommitHeightWithTelemetry)
      .then(CommitHeightWithTelemetry)
      .then(CommitHeightWithTelemetry)
      .then(CommitHeightWithTelemetry)
      .then(all {
        assert(height == 6),
        assert(CommittedFailureKind.get(5) == NoFailure),
        assert(CoverageCompleteAt(5)),
        assert(not(HashPowerParticipationCompleteAt(5))),
        assert(not(ShouldLowerSigma(5))),
        assert(sigma == 3),
        assert(Safety),
        unchangedAll,
      })
  }

  run criticalLowHashPowerParticipationRaisesSigmaTest = {
    Init
      .then(CommitHeightWithTelemetry)
      .then(CommitHeightWithTelemetry)
      .then(CommitHeightWithTelemetry)
      .then(CommitHeightWithTelemetry)
      .then(CommitHeightWithTelemetry)
      .then(CommitHeightWithTelemetry)
      .then(CommitHeightWithTelemetry)
      .then(all {
        assert(height == 7),
        assert(CommittedFailureKind.get(6) == NoFailure),
        assert(HashPowerParticipationFloorBreachedAt(6)),
        assert(ShouldRaiseSigma(6)),
        assert(sigma == 4),
        assert(Safety),
        unchangedAll,
      })
  }

  run dynamicSigmaSafetyTest = {
    Init
      .then(all {
        assert(Safety),
        unchangedAll,
      })
  }
}

module CrosslinkDynamicSigmaModel {
  import CrosslinkDynamicSigmaTest(
    MaxHeight = 7,
    MinSigma = 1,
    MaxSigma = 4,
    InitialSigma = 2,
    FailureThreshold = 2,
    StableWindowThreshold = 2,
    CoverageTarget = 3,
    MaxCoverageScore = 4,
    HashPowerParticipationTargetPercent = 67,
    HashPowerParticipationFloorPercent = 25,
    MaxHashPowerParticipationPercent = 100,
    CommittedFailureKind = Map(
      0 -> "long-reorg-tail",
      1 -> "same-branch-arrival",
      2 -> "none",
      3 -> "none",
      4 -> "ambiguous-low-coverage",
      5 -> "none",
      6 -> "none",
      7 -> "none",
    ),
    CommittedFailureCount = Map(
      0 -> 2,
      1 -> 3,
      2 -> 0,
      3 -> 0,
      4 -> 2,
      5 -> 0,
      6 -> 0,
      7 -> 0,
    ),
    CommittedStableWindowCount = Map(
      0 -> 0,
      1 -> 0,
      2 -> 2,
      3 -> 2,
      4 -> 0,
      5 -> 0,
      6 -> 0,
      7 -> 0,
    ),
    CommittedCoverageScore = Map(
      0 -> 4,
      1 -> 4,
      2 -> 4,
      3 -> 1,
      4 -> 1,
      5 -> 4,
      6 -> 4,
      7 -> 4,
    ),
    CommittedHashPowerParticipationPercent = Map(
      0 -> 80,
      1 -> 80,
      2 -> 80,
      3 -> 80,
      4 -> 30,
      5 -> 30,
      6 -> 10,
      7 -> 80,
    ),
  ).*
}
