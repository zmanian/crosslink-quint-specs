module CrosslinkValidatorScaleProgressContractModel {
  /*
   TLC-friendly temporal contract for validator-scale nil-precommit resampling.

   CrosslinkValidatorScaleLivenessEnvelope.qnt records the qualitative risk
   envelope: a larger globally distributed validator set stretches GST, making
   a stream change between prevote and precommit more likely. This contract
   turns that envelope into a temporal progress obligation. In the stressed
   scenario, baseline Crosslink observes the stream-change hazard and halts,
   while nil-precommit resampling burns the bounded churn rounds and then
   reaches a stable decision window.
   */

  type Proc_t = str
  type ValidatorCount_t = int
  type Sigma_t = int

  pure val Corr = Set("p1", "p2", "p3")
  pure val NilCertSigners = Set("p1", "p2", "p4")

  pure val SmallValidatorSet = 2
  pure val LargerValidatorSet = 5
  pure val BaseGstUnits = 1
  pure val LinearGstPerValidatorUnit = 1
  pure val QuadraticGstPerValidatorPairUnit = 1
  pure val VoteProcessingUnits = 1
  pure val PowArrivalRiskPerWindowUnit = 1
  pure val BaselineHaltRiskBudget = 18
  pure val BurnRiskCapacityPerRound = 6
  pure val ResamplingRoundBurnBudget = 3
  pure val StressSigma = 2
  pure val StableRound = 3

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

  def VulnerableStressScenario: bool =
    BaselineWithinHaltRiskBudget(SmallValidatorSet, true, StressSigma) and
    not(BaselineWithinHaltRiskBudget(LargerValidatorSet, true, StressSigma)) and
    ResamplingWithinRoundBurnBudget(LargerValidatorSet, true, StressSigma) and
    ChurnRoundsBeforeStable(LargerValidatorSet, true, StressSigma) == StableRound

  def StableRoundReached: bool =
    burnRound == StableRound

  def NilSeedComplete: bool =
    NilCertSigners.subseteq(nilSeeded)

  action Init = all {
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

  action BaselineObserveChurnAndHalt: bool =
    all {
      not(baselineHalted),
      VulnerableStressScenario,
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
      BaselineObserveChurnAndHalt,
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
    0.to(StableRound).contains(burnRound) and
    0.to(40).contains(progress) and
    nilSeeded.subseteq(NilCertSigners) and
    advanced.subseteq(Corr) and
    stablePrevoted.subseteq(Corr) and
    stablePrevotesDelivered.subseteq(Corr) and
    stablePrecommitted.subseteq(Corr)

  val ScaleEnvelopeMatchesStressScenario =
    VulnerableStressScenario and
    StableRound <= ResamplingRoundBurnBudget and
    NormalHeadArrivalRiskNumerator(LargerValidatorSet, true, 1) ==
      NormalHeadArrivalRiskNumerator(LargerValidatorSet, true, 4)

  val BaselineHaltOnlyOutsideRiskBudget =
    baselineHalted implies
      not(BaselineWithinHaltRiskBudget(
        LargerValidatorSet,
        true,
        StressSigma,
      ))

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
    ScaleEnvelopeMatchesStressScenario and
    BaselineHaltOnlyOutsideRiskBudget and
    ResamplingProgressOnlyAfterBaselineHalt and
    PhaseOrder

  temporal EventuallyResamplingDecision =
    Next.weakFair(Set(progress)).implies(eventually(resamplingDecisionMade))

  run baselineHaltsBeforeResamplingBurnsTest = {
    Init
      .then(BaselineObserveChurnAndHalt)
      .then(all {
        assert(baselineHalted),
        assert(burnRound == 0),
        assert(not(resamplingDecisionMade)),
        assert(Safety),
        Unchanged,
      })
  }

  run fairValidatorScaleProgressContractTest = {
    Init
      .then(BaselineObserveChurnAndHalt)
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
      .then(SeedNilSigner("p2"))
      .then(SeedNilSigner("p4"))
      .then(SeedNilSigner("p1"))
      .then(AdvanceAfterNilCert("p1"))
      .then(AdvanceAfterNilCert("p3"))
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
        assert(burnRound == StableRound),
        assert(resamplingDecisionMade),
        assert(Safety),
        Unchanged,
      })
  }
}
