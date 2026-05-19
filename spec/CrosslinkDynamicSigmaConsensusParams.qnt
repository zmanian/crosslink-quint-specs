module CrosslinkDynamicSigmaConsensusParams {
  /*
   Dynamic-sigma consensus-parameter encoding.

   CrosslinkDynamicSigma.qnt models the controller that computes sigma at BFT
   height boundaries. This slice models the production-facing handoff: the
   next height's `bc_confirmation_depth_sigma` value must be carried in an
   explicit consensus-parameter envelope whose activation height, telemetry
   source height, and sigma value decode to the deterministic controller output.

   The model deliberately keeps bytes abstract, but pins the consensus-param
   field boundary and rejects malformed, stale, or out-of-range parameter
   updates.
   */

  import CrosslinkDynamicSigma.* from "./CrosslinkDynamicSigma"
  export CrosslinkDynamicSigma.*

  type ConsensusParamWire_t = {
    paramKey: str,
    activationHeight: Height_t,
    telemetryHeight: Height_t,
    bcConfirmationDepthSigma: Sigma_t,
  }

  type ConsensusParams_t = {
    activationHeight: Height_t,
    telemetryHeight: Height_t,
    bcConfirmationDepthSigma: Sigma_t,
    wire: ConsensusParamWire_t,
  }

  const ConsensusParamWires: Set[ConsensusParamWire_t]

  pure val BcConfirmationDepthSigmaKey = "bc_confirmation_depth_sigma"

  pure def EncodeConsensusParams(
    activationHeight: Height_t,
    telemetryHeight: Height_t,
    sigmaValue: Sigma_t,
  ): ConsensusParamWire_t = {
    paramKey: BcConfirmationDepthSigmaKey,
    activationHeight: activationHeight,
    telemetryHeight: telemetryHeight,
    bcConfirmationDepthSigma: sigmaValue,
  }

  pure def DecodeConsensusParams(wire: ConsensusParamWire_t): ConsensusParams_t = {
    activationHeight: wire.activationHeight,
    telemetryHeight: wire.telemetryHeight,
    bcConfirmationDepthSigma: wire.bcConfirmationDepthSigma,
    wire: wire,
  }

  pure def ConsensusParamWireWellFormed(wire: ConsensusParamWire_t): bool =
    wire.paramKey == BcConfirmationDepthSigmaKey and
    Heights.contains(wire.activationHeight) and
    Heights.contains(wire.telemetryHeight) and
    SigmaInBounds(wire.bcConfirmationDepthSigma)

  pure def ConsensusParamsWellFormed(params: ConsensusParams_t): bool =
    ConsensusParamWireWellFormed(params.wire) and
    params.activationHeight == params.wire.activationHeight and
    params.telemetryHeight == params.wire.telemetryHeight and
    params.bcConfirmationDepthSigma == params.wire.bcConfirmationDepthSigma and
    params.wire ==
      EncodeConsensusParams(
        params.activationHeight,
        params.telemetryHeight,
        params.bcConfirmationDepthSigma,
      )

  pure def ParamsFor(
    activationHeight: Height_t,
    telemetryHeight: Height_t,
    sigmaValue: Sigma_t,
  ): ConsensusParams_t =
    DecodeConsensusParams(
      EncodeConsensusParams(activationHeight, telemetryHeight, sigmaValue)
    )

  var consensusParamsAtHeight: Height_t -> ConsensusParams_t
  var acceptedConsensusParamWire: Height_t -> ConsensusParamWire_t
  var committedConsensusParamHeights: Set[Height_t]
  var lastConsensusParamHeightBefore: Height_t
  var lastConsensusParamSigmaBefore: Sigma_t
  var lastConsensusParamWireBefore: ConsensusParamWire_t

  action ConsensusParamInit = all {
    Init,
    consensusParamsAtHeight' =
      Heights.mapBy(h => ParamsFor(h, 0, InitialSigma)),
    acceptedConsensusParamWire' =
      Heights.mapBy(h => EncodeConsensusParams(h, 0, InitialSigma)),
    committedConsensusParamHeights' = Set(),
    lastConsensusParamHeightBefore' = 0,
    lastConsensusParamSigmaBefore' = InitialSigma,
    lastConsensusParamWireBefore' =
      EncodeConsensusParams(0, 0, InitialSigma),
  }

  action KeepConsensusParams = all {
    consensusParamsAtHeight' = consensusParamsAtHeight,
    acceptedConsensusParamWire' = acceptedConsensusParamWire,
    committedConsensusParamHeights' = committedConsensusParamHeights,
    lastConsensusParamHeightBefore' = height,
    lastConsensusParamSigmaBefore' =
      consensusParamsAtHeight.get(height).bcConfirmationDepthSigma,
    lastConsensusParamWireBefore' = acceptedConsensusParamWire.get(height),
  }

  action BurnNilPrecommitRoundWithParams: bool =
    all { BurnNilPrecommitRound, KeepConsensusParams }

  action CommitHeightWithConsensusParams(wire: ConsensusParamWire_t): bool = {
    val h = height
    val nextHeight = h + 1
    val nextSigma = NextSigmaForHeight(sigma, h)
    val decoded = DecodeConsensusParams(wire)
    all {
      TransitionHeights.contains(h),
      ConsensusParamWires.contains(wire),
      wire == EncodeConsensusParams(nextHeight, h, nextSigma),
      ConsensusParamsWellFormed(decoded),
      decoded.activationHeight == nextHeight,
      decoded.telemetryHeight == h,
      decoded.bcConfirmationDepthSigma == nextSigma,
      CommitHeightWithTelemetry,
      consensusParamsAtHeight' =
        consensusParamsAtHeight.set(nextHeight, decoded),
      acceptedConsensusParamWire' =
        acceptedConsensusParamWire.set(nextHeight, wire),
      committedConsensusParamHeights' =
        committedConsensusParamHeights.union(Set(nextHeight)),
      lastConsensusParamHeightBefore' = h,
      lastConsensusParamSigmaBefore' =
        consensusParamsAtHeight.get(h).bcConfirmationDepthSigma,
      lastConsensusParamWireBefore' = acceptedConsensusParamWire.get(h),
    }
  }

  action ParamStutter = all { Stutter, KeepConsensusParams }

  action ConsensusParamNext =
    any {
      BurnNilPrecommitRoundWithParams,
      nondet wire = oneOf(ConsensusParamWires)
      CommitHeightWithConsensusParams(wire),
      ParamStutter,
    }

  val ActiveConsensusParamMatchesSigma =
    ConsensusParamsWellFormed(consensusParamsAtHeight.get(height)) and
    consensusParamsAtHeight.get(height).activationHeight == height and
    consensusParamsAtHeight.get(height).bcConfirmationDepthSigma == sigma and
    acceptedConsensusParamWire.get(height) ==
      consensusParamsAtHeight.get(height).wire

  val AcceptedParamsDecodeToSchedule =
    Heights.forall(h =>
      if (h <= height) {
        ConsensusParamsWellFormed(consensusParamsAtHeight.get(h)) and
        consensusParamsAtHeight.get(h).activationHeight == h and
        consensusParamsAtHeight.get(h).bcConfirmationDepthSigma ==
          sigmaAtHeight.get(h) and
        DecodeConsensusParams(acceptedConsensusParamWire.get(h)) ==
          consensusParamsAtHeight.get(h)
      } else {
        true
      }
    )

  val SameHeightConsensusParamStable =
    if (height == lastConsensusParamHeightBefore) {
      acceptedConsensusParamWire.get(height) ==
        lastConsensusParamWireBefore and
      consensusParamsAtHeight.get(height).bcConfirmationDepthSigma ==
        lastConsensusParamSigmaBefore
    } else {
      true
    }

  val ConsensusParamChangesOnlyAtHeightBoundary =
    if (acceptedConsensusParamWire.get(height) != lastConsensusParamWireBefore) {
      firedAction == "CommitHeightWithTelemetry" and
      height == lastConsensusParamHeightBefore + 1
    } else {
      true
    }

  val CommitUsesEncodedDeterministicConsensusParams =
    if (firedAction == "CommitHeightWithTelemetry") {
      consensusParamsAtHeight.get(height).activationHeight == height and
      consensusParamsAtHeight.get(height).telemetryHeight ==
        lastConsensusParamHeightBefore and
      consensusParamsAtHeight.get(height).bcConfirmationDepthSigma ==
        NextSigmaForHeight(
          lastConsensusParamSigmaBefore,
          lastConsensusParamHeightBefore,
        ) and
      acceptedConsensusParamWire.get(height) ==
        EncodeConsensusParams(
          height,
          lastConsensusParamHeightBefore,
          consensusParamsAtHeight.get(height).bcConfirmationDepthSigma,
        ) and
      committedConsensusParamHeights.contains(height)
    } else {
      true
    }

  val NilRoundBurnsDoNotRewriteConsensusParams =
    if (firedAction == "BurnNilPrecommitRound") {
      height == lastConsensusParamHeightBefore and
      acceptedConsensusParamWire.get(height) == lastConsensusParamWireBefore
    } else {
      true
    }

  val ConsensusParamSafety =
    Safety and
    ActiveConsensusParamMatchesSigma and
    AcceptedParamsDecodeToSchedule and
    SameHeightConsensusParamStable and
    ConsensusParamChangesOnlyAtHeightBoundary and
    CommitUsesEncodedDeterministicConsensusParams and
    NilRoundBurnsDoNotRewriteConsensusParams
}

module CrosslinkDynamicSigmaConsensusParamsTest {
  import CrosslinkDynamicSigmaConsensusParams.* from "./CrosslinkDynamicSigmaConsensusParams"
  export CrosslinkDynamicSigmaConsensusParams.*

  action unchangedAll = all {
    height' = height,
    sigma' = sigma,
    sigmaAtHeight' = sigmaAtHeight,
    committedTelemetryHeights' = committedTelemetryHeights,
    burnedNilRounds' = burnedNilRounds,
    lastHeightBefore' = lastHeightBefore,
    lastSigmaBefore' = lastSigmaBefore,
    firedAction' = firedAction,
    consensusParamsAtHeight' = consensusParamsAtHeight,
    acceptedConsensusParamWire' = acceptedConsensusParamWire,
    committedConsensusParamHeights' = committedConsensusParamHeights,
    lastConsensusParamHeightBefore' = lastConsensusParamHeightBefore,
    lastConsensusParamSigmaBefore' = lastConsensusParamSigmaBefore,
    lastConsensusParamWireBefore' = lastConsensusParamWireBefore,
  }

  pure val invalidKeyWire = {
    paramKey: "not_bc_confirmation_depth_sigma",
    activationHeight: 1,
    telemetryHeight: 0,
    bcConfirmationDepthSigma: 3,
  }

  pure val staleActivationWire = {
    paramKey: BcConfirmationDepthSigmaKey,
    activationHeight: 0,
    telemetryHeight: 0,
    bcConfirmationDepthSigma: 3,
  }

  pure val outOfBoundsSigmaWire = {
    paramKey: BcConfirmationDepthSigmaKey,
    activationHeight: 1,
    telemetryHeight: 0,
    bcConfirmationDepthSigma: 99,
  }

  run initialConsensusParamMatchesInitialSigmaTest = {
    ConsensusParamInit
      .then(all {
        assert(height == 0),
        assert(consensusParamsAtHeight.get(0).activationHeight == 0),
        assert(consensusParamsAtHeight.get(0).telemetryHeight == 0),
        assert(consensusParamsAtHeight.get(0).bcConfirmationDepthSigma ==
          InitialSigma),
        assert(ActiveConsensusParamMatchesSigma),
        assert(ConsensusParamSafety),
        unchangedAll,
      })
  }

  run nilRoundBurnDoesNotRewriteConsensusParamsTest = {
    ConsensusParamInit
      .then(BurnNilPrecommitRoundWithParams)
      .then(all {
        assert(height == 0),
        assert(acceptedConsensusParamWire.get(0) ==
          EncodeConsensusParams(0, 0, InitialSigma)),
        assert(NilRoundBurnsDoNotRewriteConsensusParams),
        assert(ConsensusParamSafety),
        unchangedAll,
      })
  }

  run encodedParamActivatesNextHeightSigmaTest = {
    ConsensusParamInit
      .then(CommitHeightWithConsensusParams(
        EncodeConsensusParams(1, 0, 3)
      ))
      .then(all {
        assert(height == 1),
        assert(sigma == 3),
        assert(consensusParamsAtHeight.get(1).activationHeight == 1),
        assert(consensusParamsAtHeight.get(1).telemetryHeight == 0),
        assert(consensusParamsAtHeight.get(1).bcConfirmationDepthSigma == 3),
        assert(committedConsensusParamHeights.contains(1)),
        assert(CommitUsesEncodedDeterministicConsensusParams),
        assert(ConsensusParamSafety),
        unchangedAll,
      })
  }

  run stableWindowEncodedParamCanLowerSigmaTest = {
    ConsensusParamInit
      .then(CommitHeightWithConsensusParams(
        EncodeConsensusParams(1, 0, 3)
      ))
      .then(CommitHeightWithConsensusParams(
        EncodeConsensusParams(2, 1, 3)
      ))
      .then(CommitHeightWithConsensusParams(
        EncodeConsensusParams(3, 2, 2)
      ))
      .then(all {
        assert(height == 3),
        assert(sigma == 2),
        assert(consensusParamsAtHeight.get(3).activationHeight == 3),
        assert(consensusParamsAtHeight.get(3).telemetryHeight == 2),
        assert(consensusParamsAtHeight.get(3).bcConfirmationDepthSigma == 2),
        assert(ConsensusParamSafety),
        unchangedAll,
      })
  }

  run criticalParticipationEncodedParamRaisesSigmaTest = {
    ConsensusParamInit
      .then(CommitHeightWithConsensusParams(
        EncodeConsensusParams(1, 0, 3)
      ))
      .then(CommitHeightWithConsensusParams(
        EncodeConsensusParams(2, 1, 3)
      ))
      .then(CommitHeightWithConsensusParams(
        EncodeConsensusParams(3, 2, 2)
      ))
      .then(CommitHeightWithConsensusParams(
        EncodeConsensusParams(4, 3, 3)
      ))
      .then(all {
        assert(height == 4),
        assert(CommittedFailureKind.get(3) == NoFailure),
        assert(HashPowerParticipationFloorBreachedAt(3)),
        assert(ShouldRaiseSigma(3)),
        assert(sigma == 3),
        assert(consensusParamsAtHeight.get(4).telemetryHeight == 3),
        assert(consensusParamsAtHeight.get(4).bcConfirmationDepthSigma == 3),
        assert(ConsensusParamSafety),
        unchangedAll,
      })
  }

  run malformedConsensusParamKeyRejectedTest = {
    ConsensusParamInit
      .then(CommitHeightWithConsensusParams(invalidKeyWire))
      .fail()
  }

  run staleConsensusParamActivationRejectedTest = {
    ConsensusParamInit
      .then(CommitHeightWithConsensusParams(staleActivationWire))
      .fail()
  }

  run outOfBoundsConsensusParamSigmaRejectedTest = {
    ConsensusParamInit
      .then(CommitHeightWithConsensusParams(outOfBoundsSigmaWire))
      .fail()
  }

  run consensusParamSafetyTest = {
    ConsensusParamInit
      .then(all {
        assert(ConsensusParamSafety),
        unchangedAll,
      })
  }
}

module CrosslinkDynamicSigmaConsensusParamsModel {
  import CrosslinkDynamicSigmaConsensusParamsTest(
    MaxHeight = 4,
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
      4 -> "none",
    ),
    CommittedFailureCount = Map(
      0 -> 2,
      1 -> 3,
      2 -> 0,
      3 -> 0,
      4 -> 0,
    ),
    CommittedStableWindowCount = Map(
      0 -> 0,
      1 -> 0,
      2 -> 2,
      3 -> 2,
      4 -> 2,
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
      3 -> 10,
      4 -> 80,
    ),
    ConsensusParamWires = Set(
      {
        paramKey: "bc_confirmation_depth_sigma",
        activationHeight: 0,
        telemetryHeight: 0,
        bcConfirmationDepthSigma: 2,
      },
      {
        paramKey: "bc_confirmation_depth_sigma",
        activationHeight: 1,
        telemetryHeight: 0,
        bcConfirmationDepthSigma: 3,
      },
      {
        paramKey: "bc_confirmation_depth_sigma",
        activationHeight: 2,
        telemetryHeight: 1,
        bcConfirmationDepthSigma: 3,
      },
      {
        paramKey: "bc_confirmation_depth_sigma",
        activationHeight: 3,
        telemetryHeight: 2,
        bcConfirmationDepthSigma: 2,
      },
      {
        paramKey: "bc_confirmation_depth_sigma",
        activationHeight: 4,
        telemetryHeight: 3,
        bcConfirmationDepthSigma: 3,
      },
      {
        paramKey: "not_bc_confirmation_depth_sigma",
        activationHeight: 1,
        telemetryHeight: 0,
        bcConfirmationDepthSigma: 3,
      },
      {
        paramKey: "bc_confirmation_depth_sigma",
        activationHeight: 0,
        telemetryHeight: 0,
        bcConfirmationDepthSigma: 3,
      },
      {
        paramKey: "bc_confirmation_depth_sigma",
        activationHeight: 1,
        telemetryHeight: 0,
        bcConfirmationDepthSigma: 99,
      },
    ),
  ).*
}
