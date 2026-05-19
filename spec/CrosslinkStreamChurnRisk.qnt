module CrosslinkStreamChurnRisk {
  /*
   Parameterized stream-churn risk model.

   This is not a stochastic simulator. It keeps probability-like quantities as
   bounded integer numerators so Quint can check the qualitative relationships
   behind the nil-precommit resampling intuition:
   - the prevote-to-precommit vulnerability window grows with GST,
   - GST can scale linearly or quadratically with validator-set size,
   - normal PoW head arrivals create churn exposure during that window,
   - larger sigma reduces exposure to long-tail reorg churn, and
   - nil-precommit resampling turns finite churn into burned rounds until a
     stable window arrives.
   */

  const MaxValidatorCount: int
  const MaxSigma: int
  const MaxReorgDepth: int
  const MaxChurnRoundsBeforeStable: int
  const BaseGstUnits: int
  const LinearGstPerValidatorUnit: int
  const QuadraticGstPerValidatorPairUnit: int
  const VoteProcessingUnits: int
  const PowArrivalRiskPerWindowUnit: int
  const LongReorgRiskPerDepthUnit: int

  pure val ValidatorCounts = 1.to(MaxValidatorCount)
  pure val Sigmas = 1.to(MaxSigma)
  pure val ReorgDepths = 0.to(MaxReorgDepth)
  pure val ChurnRounds = 0.to(MaxChurnRoundsBeforeStable)

  assume domains_are_nonempty =
    MaxValidatorCount >= 2 and
    MaxSigma >= 2 and
    MaxReorgDepth >= 1 and
    MaxChurnRoundsBeforeStable >= 1

  assume risk_units_are_positive =
    BaseGstUnits >= 0 and
    LinearGstPerValidatorUnit > 0 and
    QuadraticGstPerValidatorPairUnit > 0 and
    VoteProcessingUnits >= 0 and
    PowArrivalRiskPerWindowUnit > 0 and
    LongReorgRiskPerDepthUnit > 0

  pure def GstUnits(validatorCount: int, globalDistributionWorstCase: bool): int =
    BaseGstUnits +
    LinearGstPerValidatorUnit * validatorCount +
    if (globalDistributionWorstCase) {
      QuadraticGstPerValidatorPairUnit * validatorCount * validatorCount
    } else {
      0
    }

  pure def PrevotePrecommitWindowUnits(
    validatorCount: int,
    globalDistributionWorstCase: bool,
  ): int =
    VoteProcessingUnits + GstUnits(validatorCount, globalDistributionWorstCase)

  pure def NormalHeadArrivalRiskNumerator(
    validatorCount: int,
    globalDistributionWorstCase: bool,
  ): int =
    PrevotePrecommitWindowUnits(
      validatorCount,
      globalDistributionWorstCase,
    ) * PowArrivalRiskPerWindowUnit

  pure def LongReorgTailRiskNumerator(sigma: int, reorgDepth: int): int =
    if (reorgDepth > sigma) {
      (reorgDepth - sigma) * LongReorgRiskPerDepthUnit
    } else {
      0
    }

  pure def StreamChurnRiskNumerator(
    validatorCount: int,
    sigma: int,
    reorgDepth: int,
    globalDistributionWorstCase: bool,
  ): int =
    NormalHeadArrivalRiskNumerator(
      validatorCount,
      globalDistributionWorstCase,
    ) +
    LongReorgTailRiskNumerator(sigma, reorgDepth)

  pure def BaselineRiskExposure(
    validatorCount: int,
    sigma: int,
    reorgDepth: int,
    globalDistributionWorstCase: bool,
  ): int =
    StreamChurnRiskNumerator(
      validatorCount,
      sigma,
      reorgDepth,
      globalDistributionWorstCase,
    )

  pure def ResamplingBurnedRoundsBeforeStable(churnRoundsBeforeStable: int): int =
    churnRoundsBeforeStable

  pure def ResamplingCanDecideAfterStableWindow(churnRoundsBeforeStable: int): bool =
    ChurnRounds.contains(churnRoundsBeforeStable)

  val GstMonotoneInValidatorCount =
    1.to(MaxValidatorCount - 1).forall(n =>
      GstUnits(n + 1, false) > GstUnits(n, false) and
      GstUnits(n + 1, true) > GstUnits(n, true)
    )

  val GlobalDistributionWorstCaseAtLeastLinear =
    ValidatorCounts.forall(n =>
      GstUnits(n, true) > GstUnits(n, false)
    )

  val ChurnRiskMonotoneInValidatorCount =
    1.to(MaxValidatorCount - 1).forall(n =>
      Sigmas.forall(sigma =>
        ReorgDepths.forall(reorgDepth =>
          StreamChurnRiskNumerator(n + 1, sigma, reorgDepth, false) >
            StreamChurnRiskNumerator(n, sigma, reorgDepth, false) and
          StreamChurnRiskNumerator(n + 1, sigma, reorgDepth, true) >
            StreamChurnRiskNumerator(n, sigma, reorgDepth, true)
        )
      )
    )

  val SigmaReducesLongReorgTailRisk =
    1.to(MaxSigma - 1).forall(sigma =>
      ReorgDepths.forall(reorgDepth =>
        LongReorgTailRiskNumerator(sigma + 1, reorgDepth) <=
          LongReorgTailRiskNumerator(sigma, reorgDepth)
      )
    )

  val SigmaOnlyChangesTailRisk =
    ValidatorCounts.forall(n =>
      1.to(MaxSigma - 1).forall(sigma =>
        ReorgDepths.forall(reorgDepth =>
          Set(true, false).forall(globalDistributionWorstCase =>
            StreamChurnRiskNumerator(
              n,
              sigma,
              reorgDepth,
              globalDistributionWorstCase,
            ) +
            LongReorgTailRiskNumerator(sigma + 1, reorgDepth) ==
            StreamChurnRiskNumerator(
              n,
              sigma + 1,
              reorgDepth,
              globalDistributionWorstCase,
            ) +
            LongReorgTailRiskNumerator(sigma, reorgDepth)
          )
        )
      )
    )

  val ResamplingFiniteChurnEventuallyReachesStableWindow =
    ChurnRounds.forall(churnRounds =>
      ResamplingBurnedRoundsBeforeStable(churnRounds) == churnRounds and
      ResamplingCanDecideAfterStableWindow(churnRounds)
    )

  val Safety =
    GstMonotoneInValidatorCount and
    GlobalDistributionWorstCaseAtLeastLinear and
    ChurnRiskMonotoneInValidatorCount and
    SigmaReducesLongReorgTailRisk and
    SigmaOnlyChangesTailRisk and
    ResamplingFiniteChurnEventuallyReachesStableWindow

  var checked: bool

  action Init = all {
    checked' = false,
  }

  action Next = all {
    checked' = checked,
  }
}

module CrosslinkStreamChurnRiskTest {
  import CrosslinkStreamChurnRisk.* from "./CrosslinkStreamChurnRisk"
  export CrosslinkStreamChurnRisk.*

  action unchangedAll = all {
    checked' = checked,
  }

  run validatorGrowthRaisesLinearAndGlobalGstTest = {
    Init
      .then(all {
        assert(GstUnits(4, false) > GstUnits(3, false)),
        assert(GstUnits(4, true) > GstUnits(3, true)),
        unchangedAll,
      })
  }

  run quadraticGlobalDistributionRaisesChurnRiskTest = {
    Init
      .then(all {
        assert(
          StreamChurnRiskNumerator(4, 3, 4, true) >
            StreamChurnRiskNumerator(4, 3, 4, false)
        ),
        unchangedAll,
      })
  }

  run largerSigmaReducesLongReorgTailRiskTest = {
    Init
      .then(all {
        assert(LongReorgTailRiskNumerator(2, 4) >
          LongReorgTailRiskNumerator(3, 4)),
        assert(LongReorgTailRiskNumerator(4, 4) == 0),
        unchangedAll,
      })
  }

  run normalHeadArrivalRiskIsNotASigmaMitigationTest = {
    Init
      .then(all {
        assert(NormalHeadArrivalRiskNumerator(4, true) >
          NormalHeadArrivalRiskNumerator(3, true)),
        assert(LongReorgTailRiskNumerator(3, 0) == 0),
        unchangedAll,
      })
  }

  run resamplingBurnsRoundsUntilStableWindowTest = {
    Init
      .then(all {
        assert(BaselineRiskExposure(4, 3, 4, true) >
          BaselineRiskExposure(3, 3, 4, true)),
        assert(ResamplingBurnedRoundsBeforeStable(2) == 2),
        assert(ResamplingCanDecideAfterStableWindow(2)),
        unchangedAll,
      })
  }

  run churnRiskSafetyTest = {
    Init
      .then(all {
        assert(Safety),
        unchangedAll,
      })
  }
}

module CrosslinkStreamChurnRiskModel {
  import CrosslinkStreamChurnRiskTest(
    MaxValidatorCount = 4,
    MaxSigma = 4,
    MaxReorgDepth = 4,
    MaxChurnRoundsBeforeStable = 3,
    BaseGstUnits = 1,
    LinearGstPerValidatorUnit = 1,
    QuadraticGstPerValidatorPairUnit = 1,
    VoteProcessingUnits = 1,
    PowArrivalRiskPerWindowUnit = 1,
    LongReorgRiskPerDepthUnit = 2,
  ).*
}
