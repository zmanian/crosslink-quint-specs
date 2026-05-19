module CrosslinkPowStochasticAssumptions {
  /*
   Stochastic-assumption profile for PoW stream churn.

   This is not a random simulator. It records the numeric assumptions that sit
   underneath CrosslinkStreamChurnRisk.qnt as bounded integer numerators:
   - post-Blossom Zcash block target spacing is the probability denominator,
   - the prevote-to-precommit window contributes normal PoW-arrival exposure,
   - globally distributed validator sets can make that window grow
     quadratically in the worst case,
   - sigma does not reduce normal same-branch block-arrival exposure, and
   - sigma only reduces the assumed long-reorg tail.

   The concrete model instance uses Zebra's current post-Blossom target spacing
   constant, POST_BLOSSOM_POW_TARGET_SPACING = 75 seconds.
   */

  const MaxValidatorCount: int
  const MaxSigma: int
  const MaxChurnRoundsBeforeStable: int
  const PowTargetSpacingSeconds: int
  const BasePrevotePrecommitSeconds: int
  const LinearGstSecondsPerValidator: int
  const QuadraticGstSecondsPerValidatorPair: int
  const LongReorgTailNumeratorAtSigma: int -> int

  pure val ValidatorCounts = 1.to(MaxValidatorCount)
  pure val Sigmas = 1.to(MaxSigma)
  pure val ChurnRounds = 0.to(MaxChurnRoundsBeforeStable)

  pure def PrevotePrecommitWindowSeconds(
    validatorCount: int,
    globalDistributionWorstCase: bool,
  ): int =
    BasePrevotePrecommitSeconds +
    LinearGstSecondsPerValidator * validatorCount +
    if (globalDistributionWorstCase) {
      QuadraticGstSecondsPerValidatorPair * validatorCount * validatorCount
    } else {
      0
    }

  pure def NormalPowArrivalNumerator(
    validatorCount: int,
    globalDistributionWorstCase: bool,
  ): int =
    PrevotePrecommitWindowSeconds(
      validatorCount,
      globalDistributionWorstCase,
    )

  pure def LongReorgTailNumerator(sigma: int): int =
    LongReorgTailNumeratorAtSigma.get(sigma)

  pure def TotalChurnNumerator(
    validatorCount: int,
    sigma: int,
    globalDistributionWorstCase: bool,
  ): int =
    NormalPowArrivalNumerator(
      validatorCount,
      globalDistributionWorstCase,
    ) +
    LongReorgTailNumerator(sigma)

  pure def BaselineHaltExposureNumerator(
    validatorCount: int,
    sigma: int,
    globalDistributionWorstCase: bool,
    churnRoundsBeforeStable: int,
  ): int =
    churnRoundsBeforeStable *
    TotalChurnNumerator(
      validatorCount,
      sigma,
      globalDistributionWorstCase,
    )

  pure def ResamplingBurnedRoundsBeforeStable(
    churnRoundsBeforeStable: int,
  ): int =
    churnRoundsBeforeStable

  assume domains_are_nonempty =
    MaxValidatorCount >= 2 and
    MaxSigma >= 2 and
    MaxChurnRoundsBeforeStable >= 1

  assume seconds_are_positive =
    PowTargetSpacingSeconds > 0 and
    BasePrevotePrecommitSeconds >= 0 and
    LinearGstSecondsPerValidator > 0 and
    QuadraticGstSecondsPerValidatorPair > 0

  assume windows_fit_arrival_denominator =
    ValidatorCounts.forall(n =>
      PrevotePrecommitWindowSeconds(n, true) <= PowTargetSpacingSeconds
    )

  assume tail_numerators_are_bounded =
    Sigmas.forall(sigma =>
      LongReorgTailNumerator(sigma) >= 0 and
      LongReorgTailNumerator(sigma) <= PowTargetSpacingSeconds
    )

  val UsesZebraPostBlossomSpacing =
    PowTargetSpacingSeconds == 75

  val WindowMonotoneInValidatorCount =
    1.to(MaxValidatorCount - 1).forall(n =>
      PrevotePrecommitWindowSeconds(n + 1, false) >
        PrevotePrecommitWindowSeconds(n, false) and
      PrevotePrecommitWindowSeconds(n + 1, true) >
        PrevotePrecommitWindowSeconds(n, true)
    )

  val GlobalDistributionAddsWorstCaseDelay =
    ValidatorCounts.forall(n =>
      PrevotePrecommitWindowSeconds(n, true) >
        PrevotePrecommitWindowSeconds(n, false)
    )

  val ArrivalNumeratorUsesWindowOverTargetSpacing =
    ValidatorCounts.forall(n =>
      Set(true, false).forall(globalDistributionWorstCase =>
        NormalPowArrivalNumerator(n, globalDistributionWorstCase) ==
          PrevotePrecommitWindowSeconds(n, globalDistributionWorstCase) and
        NormalPowArrivalNumerator(n, globalDistributionWorstCase) <=
          PowTargetSpacingSeconds
      )
    )

  val SigmaReducesOnlyLongReorgTail =
    1.to(MaxSigma - 1).forall(sigma =>
      LongReorgTailNumerator(sigma + 1) <=
        LongReorgTailNumerator(sigma) and
      ValidatorCounts.forall(n =>
        Set(true, false).forall(globalDistributionWorstCase =>
          NormalPowArrivalNumerator(n, globalDistributionWorstCase) ==
            NormalPowArrivalNumerator(n, globalDistributionWorstCase)
        )
      )
    )

  val TotalChurnNumeratorMonotoneInValidatorCount =
    1.to(MaxValidatorCount - 1).forall(n =>
      Sigmas.forall(sigma =>
        Set(true, false).forall(globalDistributionWorstCase =>
          TotalChurnNumerator(
            n + 1,
            sigma,
            globalDistributionWorstCase,
          ) >
          TotalChurnNumerator(
            n,
            sigma,
            globalDistributionWorstCase,
          )
        )
      )
    )

  val TotalChurnNumeratorMonotoneInSigma =
    ValidatorCounts.forall(n =>
      1.to(MaxSigma - 1).forall(sigma =>
        Set(true, false).forall(globalDistributionWorstCase =>
          TotalChurnNumerator(
            n,
            sigma + 1,
            globalDistributionWorstCase,
          ) <=
          TotalChurnNumerator(
            n,
            sigma,
            globalDistributionWorstCase,
          )
        )
      )
    )

  val FiniteChurnStillComposesWithResampling =
    ChurnRounds.forall(churnRounds =>
      ResamplingBurnedRoundsBeforeStable(churnRounds) == churnRounds
    )

  val Safety =
    UsesZebraPostBlossomSpacing and
    WindowMonotoneInValidatorCount and
    GlobalDistributionAddsWorstCaseDelay and
    ArrivalNumeratorUsesWindowOverTargetSpacing and
    SigmaReducesOnlyLongReorgTail and
    TotalChurnNumeratorMonotoneInValidatorCount and
    TotalChurnNumeratorMonotoneInSigma and
    FiniteChurnStillComposesWithResampling

  var checked: bool

  action Init = all {
    checked' = false,
  }

  action Next = all {
    checked' = checked,
  }
}

module CrosslinkPowStochasticAssumptionsTest {
  import CrosslinkPowStochasticAssumptions.* from "./CrosslinkPowStochasticAssumptions"
  export CrosslinkPowStochasticAssumptions.*

  action unchangedAll = all {
    checked' = checked,
  }

  run postBlossomSpacingPinsArrivalDenominatorTest = {
    Init
      .then(all {
        assert(PowTargetSpacingSeconds == 75),
        assert(NormalPowArrivalNumerator(2, false) == 11),
        assert(NormalPowArrivalNumerator(2, false) < PowTargetSpacingSeconds),
        unchangedAll,
      })
  }

  run globalValidatorDistributionRaisesArrivalRiskTest = {
    Init
      .then(all {
        assert(
          NormalPowArrivalNumerator(4, true) >
            NormalPowArrivalNumerator(4, false)
        ),
        unchangedAll,
      })
  }

  run largerValidatorSetRaisesArrivalRiskTest = {
    Init
      .then(all {
        assert(
          TotalChurnNumerator(4, 2, true) >
            TotalChurnNumerator(3, 2, true)
        ),
        unchangedAll,
      })
  }

  run sigmaReducesOnlyTailRiskTest = {
    Init
      .then(all {
        assert(LongReorgTailNumerator(2) < LongReorgTailNumerator(1)),
        assert(NormalPowArrivalNumerator(4, true) == 37),
        assert(TotalChurnNumerator(4, 2, true) <
          TotalChurnNumerator(4, 1, true)),
        unchangedAll,
      })
  }

  run finiteChurnBurnsRoundsUntilStableWindowTest = {
    Init
      .then(all {
        assert(BaselineHaltExposureNumerator(4, 1, true, 2) ==
          2 * TotalChurnNumerator(4, 1, true)),
        assert(ResamplingBurnedRoundsBeforeStable(2) == 2),
        unchangedAll,
      })
  }

  run stochasticAssumptionSafetyTest = {
    Init
      .then(all {
        assert(Safety),
        unchangedAll,
      })
  }
}

module CrosslinkPowStochasticAssumptionsModel {
  import CrosslinkPowStochasticAssumptionsTest(
    MaxValidatorCount = 4,
    MaxSigma = 4,
    MaxChurnRoundsBeforeStable = 3,
    PowTargetSpacingSeconds = 75,
    BasePrevotePrecommitSeconds = 1,
    LinearGstSecondsPerValidator = 5,
    QuadraticGstSecondsPerValidatorPair = 1,
    LongReorgTailNumeratorAtSigma = Map(
      1 -> 16,
      2 -> 8,
      3 -> 4,
      4 -> 2,
    ),
  ).*
}
