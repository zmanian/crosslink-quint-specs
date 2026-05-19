module CrosslinkValidatorScaleLivenessEnvelope {
  /*
   Validator-scale liveness envelope for nil-precommit resampling.

   This is a bounded qualitative model, not a stochastic simulator. It captures
   the liveness intuition behind the resampling change:
   - the vulnerable prevote-to-precommit window grows with GST,
   - globally distributed validator sets can add a quadratic delay component,
   - ordinary PoW head arrivals during that window are not fixed by larger
     sigma, and
   - resampling can tolerate larger validator sets by converting finite churn
     into burned rounds until the stream is stable.
   */

  type ValidatorCount_t = int
  type Sigma_t = int

  pure val ValidatorCounts = 1.to(6)
  pure val Sigmas = 1.to(4)
  pure val ChurnRounds = 0.to(4)

  pure val SmallValidatorSet = 2
  pure val LargerValidatorSet = 5
  pure val GlobalStressValidatorSet = 4

  pure val BaseGstUnits = 1
  pure val LinearGstPerValidatorUnit = 1
  pure val QuadraticGstPerValidatorPairUnit = 1
  pure val VoteProcessingUnits = 1
  pure val PowArrivalRiskPerWindowUnit = 1
  pure val BaselineHaltRiskBudget = 18
  pure val BurnRiskCapacityPerRound = 6
  pure val ResamplingRoundBurnBudget = 3

  var checked: bool

  pure def GstUnits(
    validatorCount: ValidatorCount_t,
    globalDistributionWorstCase: bool,
  ): int =
    BaseGstUnits +
    LinearGstPerValidatorUnit * validatorCount +
    if (globalDistributionWorstCase) {
      QuadraticGstPerValidatorPairUnit * validatorCount * validatorCount
    } else {
      0
    }

  pure def PrevotePrecommitWindowUnits(
    validatorCount: ValidatorCount_t,
    globalDistributionWorstCase: bool,
  ): int =
    VoteProcessingUnits + GstUnits(validatorCount, globalDistributionWorstCase)

  pure def NormalHeadArrivalRiskNumerator(
    validatorCount: ValidatorCount_t,
    globalDistributionWorstCase: bool,
    sigma: Sigma_t,
  ): int =
    PrevotePrecommitWindowUnits(
      validatorCount,
      globalDistributionWorstCase,
    ) * PowArrivalRiskPerWindowUnit

  pure def BaselineWithinHaltRiskBudget(
    validatorCount: ValidatorCount_t,
    globalDistributionWorstCase: bool,
    sigma: Sigma_t,
  ): bool =
    NormalHeadArrivalRiskNumerator(
      validatorCount,
      globalDistributionWorstCase,
      sigma,
    ) <= BaselineHaltRiskBudget

  pure def ChurnRoundsBeforeStable(
    validatorCount: ValidatorCount_t,
    globalDistributionWorstCase: bool,
    sigma: Sigma_t,
  ): int = {
    val risk = NormalHeadArrivalRiskNumerator(
      validatorCount,
      globalDistributionWorstCase,
      sigma,
    )
    if (risk <= BaselineHaltRiskBudget) {
      0
    } else if (risk <= BaselineHaltRiskBudget + BurnRiskCapacityPerRound) {
      1
    } else if (risk <= BaselineHaltRiskBudget + 2 * BurnRiskCapacityPerRound) {
      2
    } else if (risk <= BaselineHaltRiskBudget + 3 * BurnRiskCapacityPerRound) {
      3
    } else {
      4
    }
  }

  pure def ResamplingWithinRoundBurnBudget(
    validatorCount: ValidatorCount_t,
    globalDistributionWorstCase: bool,
    sigma: Sigma_t,
  ): bool =
    ChurnRoundsBeforeStable(
      validatorCount,
      globalDistributionWorstCase,
      sigma,
    ) <= ResamplingRoundBurnBudget

  pure def StableWindowDecisionPossibleAfterBurns(
    validatorCount: ValidatorCount_t,
    globalDistributionWorstCase: bool,
    sigma: Sigma_t,
  ): bool =
    ChurnRounds.contains(ChurnRoundsBeforeStable(
      validatorCount,
      globalDistributionWorstCase,
      sigma,
    )) and
    ResamplingWithinRoundBurnBudget(
      validatorCount,
      globalDistributionWorstCase,
      sigma,
    )

  val GstMonotoneInValidatorCount =
    1.to(5).forall(n =>
      GstUnits(n + 1, false) > GstUnits(n, false) and
      GstUnits(n + 1, true) > GstUnits(n, true)
    )

  val GlobalDistributionCanBeQuadratic =
    ValidatorCounts.forall(n =>
      GstUnits(n, true) >= GstUnits(n, false)
    ) and
    GstUnits(GlobalStressValidatorSet, true) >
      GstUnits(GlobalStressValidatorSet, false)

  val NormalHeadArrivalRiskMonotoneInValidatorCount =
    1.to(5).forall(n =>
      Sigmas.forall(sigma =>
        NormalHeadArrivalRiskNumerator(n + 1, false, sigma) >
          NormalHeadArrivalRiskNumerator(n, false, sigma) and
        NormalHeadArrivalRiskNumerator(n + 1, true, sigma) >
          NormalHeadArrivalRiskNumerator(n, true, sigma)
      )
    )

  val LargerSigmaDoesNotReduceNormalHeadArrivalExposure =
    ValidatorCounts.forall(n =>
      Set(true, false).forall(globalDistributionWorstCase =>
        1.to(3).forall(sigma =>
          NormalHeadArrivalRiskNumerator(
            n,
            globalDistributionWorstCase,
            sigma + 1,
          ) ==
            NormalHeadArrivalRiskNumerator(
              n,
              globalDistributionWorstCase,
              sigma,
            )
        )
      )
    )

  val ResamplingStrictlyExtendsValidatorEnvelope =
    BaselineWithinHaltRiskBudget(SmallValidatorSet, true, 2) and
    not(BaselineWithinHaltRiskBudget(LargerValidatorSet, true, 2)) and
    ResamplingWithinRoundBurnBudget(LargerValidatorSet, true, 2) and
    StableWindowDecisionPossibleAfterBurns(LargerValidatorSet, true, 2)

  val GlobalDistributionNeedsResamplingEarlierThanLinearDistribution =
    BaselineWithinHaltRiskBudget(GlobalStressValidatorSet, false, 2) and
    not(BaselineWithinHaltRiskBudget(GlobalStressValidatorSet, true, 2)) and
    ResamplingWithinRoundBurnBudget(GlobalStressValidatorSet, true, 2)

  val BoundedChurnRoundBurnsStayFinite =
    ValidatorCounts.forall(n =>
      Sigmas.forall(sigma =>
        Set(true, false).forall(globalDistributionWorstCase =>
          ResamplingWithinRoundBurnBudget(
            n,
            globalDistributionWorstCase,
            sigma,
          ) implies
            StableWindowDecisionPossibleAfterBurns(
              n,
              globalDistributionWorstCase,
              sigma,
            )
        )
      )
    )

  val Safety =
    GstMonotoneInValidatorCount and
    GlobalDistributionCanBeQuadratic and
    NormalHeadArrivalRiskMonotoneInValidatorCount and
    LargerSigmaDoesNotReduceNormalHeadArrivalExposure and
    ResamplingStrictlyExtendsValidatorEnvelope and
    GlobalDistributionNeedsResamplingEarlierThanLinearDistribution and
    BoundedChurnRoundBurnsStayFinite

  action Init = all {
    checked' = false,
  }

  action Next = all {
    checked' = checked,
  }
}

module CrosslinkValidatorScaleLivenessEnvelopeTest {
  import CrosslinkValidatorScaleLivenessEnvelope.* from
    "./CrosslinkValidatorScaleLivenessEnvelope"
  export CrosslinkValidatorScaleLivenessEnvelope.*

  action unchangedAll = all {
    checked' = checked,
  }

  run validatorGrowthMakesBaselineFailBeforeResamplingTest = {
    Init
      .then(all {
        assert(BaselineWithinHaltRiskBudget(SmallValidatorSet, true, 2)),
        assert(not(BaselineWithinHaltRiskBudget(LargerValidatorSet, true, 2))),
        assert(ResamplingWithinRoundBurnBudget(LargerValidatorSet, true, 2)),
        assert(ChurnRoundsBeforeStable(LargerValidatorSet, true, 2) == 3),
        unchangedAll,
      })
  }

  run quadraticGlobalDistributionTriggersResamplingEnvelopeTest = {
    Init
      .then(all {
        assert(BaselineWithinHaltRiskBudget(GlobalStressValidatorSet, false, 2)),
        assert(not(BaselineWithinHaltRiskBudget(GlobalStressValidatorSet, true, 2))),
        assert(ResamplingWithinRoundBurnBudget(GlobalStressValidatorSet, true, 2)),
        unchangedAll,
      })
  }

  run largerSigmaDoesNotFixNormalArrivalExposureTest = {
    Init
      .then(all {
        assert(NormalHeadArrivalRiskNumerator(LargerValidatorSet, true, 1) ==
          NormalHeadArrivalRiskNumerator(LargerValidatorSet, true, 4)),
        assert(LargerSigmaDoesNotReduceNormalHeadArrivalExposure),
        unchangedAll,
      })
  }

  run boundedChurnBurnsRoundsThenStableWindowDecidesTest = {
    Init
      .then(all {
        assert(StableWindowDecisionPossibleAfterBurns(
          LargerValidatorSet,
          true,
          2,
        )),
        assert(BoundedChurnRoundBurnsStayFinite),
        unchangedAll,
      })
  }

  run validatorScaleEnvelopeSafetyTest = {
    Init
      .then(all {
        assert(Safety),
        unchangedAll,
      })
  }
}

module CrosslinkValidatorScaleLivenessEnvelopeModel {
  import CrosslinkValidatorScaleLivenessEnvelopeTest.* from
    "./CrosslinkValidatorScaleLivenessEnvelope"
  export CrosslinkValidatorScaleLivenessEnvelopeTest.*
}
