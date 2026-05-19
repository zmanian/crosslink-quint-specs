module CrosslinkDynamicSigmaConsensusParamFormat {
  /*
   Production-shaped bytes for dynamic-sigma consensus params.

   CrosslinkDynamicSigmaConsensusParams.qnt models the abstract
   `bc_confirmation_depth_sigma` consensus-param wire. This slice pins a compact
   production byte envelope for that wire:
   - one byte key tag,
   - little-endian u32 activation height,
   - little-endian u32 telemetry source height,
   - little-endian u16 sigma value.

   The exact implementation byte format is still future work, but this model
   gives that future code a concrete boundary to satisfy and rejects wrong-key,
   stale-activation, trailing-byte, and out-of-range-sigma envelopes before they
   can update the dynamic sigma schedule.
   */

  import CrosslinkDynamicSigmaConsensusParams.* from "./CrosslinkDynamicSigmaConsensusParams"
  export CrosslinkDynamicSigmaConsensusParams.*

  type ProductionConsensusParamWire_t = {
    byteLen: int,
    keyTag: int,
    activationHeight: Height_t,
    telemetryHeight: Height_t,
    bcConfirmationDepthSigma: Sigma_t,
  }

  const ProductionConsensusParamWires: Set[ProductionConsensusParamWire_t]

  pure val BcConfirmationDepthSigmaKeyTag = 1
  pure val KeyTagByteLen = 1
  pure val HeightByteLen = 4
  pure val SigmaByteLen = 2

  pure val KeyTagOffset = 0
  pure val ActivationHeightOffset = KeyTagOffset + KeyTagByteLen
  pure val TelemetryHeightOffset = ActivationHeightOffset + HeightByteLen
  pure val SigmaOffset = TelemetryHeightOffset + HeightByteLen
  pure val ConsensusParamWireByteLen = SigmaOffset + SigmaByteLen

  pure def FieldEndOffset(offset: int, width: int): int =
    offset + width

  pure def DecodeProductionConsensusParamWire(
    wire: ProductionConsensusParamWire_t,
  ): ConsensusParamWire_t =
    EncodeConsensusParams(
      wire.activationHeight,
      wire.telemetryHeight,
      wire.bcConfirmationDepthSigma,
    )

  pure def ProductionConsensusParamWireEnvelopeExact(
    wire: ProductionConsensusParamWire_t,
  ): bool =
    wire.byteLen == ConsensusParamWireByteLen

  pure def ProductionConsensusParamWireWellFormed(
    wire: ProductionConsensusParamWire_t,
  ): bool =
    ProductionConsensusParamWireEnvelopeExact(wire) and
    wire.keyTag == BcConfirmationDepthSigmaKeyTag and
    Heights.contains(wire.activationHeight) and
    Heights.contains(wire.telemetryHeight) and
    SigmaInBounds(wire.bcConfirmationDepthSigma)

  pure def ProductionWireMatchesConsensusParam(
    wire: ProductionConsensusParamWire_t,
    abstractWire: ConsensusParamWire_t,
  ): bool =
    ProductionConsensusParamWireWellFormed(wire) and
    DecodeProductionConsensusParamWire(wire) == abstractWire

  action ProductionParamInit =
    ConsensusParamInit

  action CommitHeightWithProductionConsensusParamWire(
    wire: ProductionConsensusParamWire_t,
  ): bool =
    all {
      ProductionConsensusParamWires.contains(wire),
      ProductionConsensusParamWireWellFormed(wire),
      CommitHeightWithConsensusParams(
        DecodeProductionConsensusParamWire(wire)
      ),
    }

  action ProductionParamNext =
    any {
      BurnNilPrecommitRoundWithParams,
      nondet wire = oneOf(ProductionConsensusParamWires)
      CommitHeightWithProductionConsensusParamWire(wire),
      ParamStutter,
    }

  val ProductionParamLayoutConstantsPinned =
    BcConfirmationDepthSigmaKeyTag == 1 and
    KeyTagByteLen == 1 and
    HeightByteLen == 4 and
    SigmaByteLen == 2 and
    KeyTagOffset == 0 and
    ActivationHeightOffset == 1 and
    TelemetryHeightOffset == 5 and
    SigmaOffset == 9 and
    ConsensusParamWireByteLen == 11

  val ProductionParamFieldOffsetsContiguous =
    FieldEndOffset(KeyTagOffset, KeyTagByteLen) == ActivationHeightOffset and
    FieldEndOffset(ActivationHeightOffset, HeightByteLen) ==
      TelemetryHeightOffset and
    FieldEndOffset(TelemetryHeightOffset, HeightByteLen) == SigmaOffset and
    FieldEndOffset(SigmaOffset, SigmaByteLen) == ConsensusParamWireByteLen

  val ActiveAbstractWireHasProductionEncoding =
    ProductionConsensusParamWires.exists(wire =>
      ProductionWireMatchesConsensusParam(
        wire,
        acceptedConsensusParamWire.get(height),
      )
    )

  val AcceptedCommittedParamWiresHaveProductionEncoding =
    Heights.forall(h =>
      if (h <= height) {
        ProductionConsensusParamWires.exists(wire =>
          ProductionWireMatchesConsensusParam(
            wire,
            acceptedConsensusParamWire.get(h),
          )
        )
      } else {
        true
      }
    )

  val ProductionConsensusParamFormatSafety =
    ConsensusParamSafety and
    ProductionParamLayoutConstantsPinned and
    ProductionParamFieldOffsetsContiguous and
    ActiveAbstractWireHasProductionEncoding and
    AcceptedCommittedParamWiresHaveProductionEncoding
}

module CrosslinkDynamicSigmaConsensusParamFormatTest {
  import CrosslinkDynamicSigmaConsensusParamFormat.* from "./CrosslinkDynamicSigmaConsensusParamFormat"
  export CrosslinkDynamicSigmaConsensusParamFormat.*

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

  pure val initialSigmaWire = {
    byteLen: 11,
    keyTag: 1,
    activationHeight: 0,
    telemetryHeight: 0,
    bcConfirmationDepthSigma: 2,
  }

  pure val heightOneSigmaThreeWire = {
    byteLen: 11,
    keyTag: 1,
    activationHeight: 1,
    telemetryHeight: 0,
    bcConfirmationDepthSigma: 3,
  }

  pure val heightTwoSigmaThreeWire = {
    byteLen: 11,
    keyTag: 1,
    activationHeight: 2,
    telemetryHeight: 1,
    bcConfirmationDepthSigma: 3,
  }

  pure val heightThreeSigmaTwoWire = {
    byteLen: 11,
    keyTag: 1,
    activationHeight: 3,
    telemetryHeight: 2,
    bcConfirmationDepthSigma: 2,
  }

  pure val heightFourSigmaThreeWire = {
    byteLen: 11,
    keyTag: 1,
    activationHeight: 4,
    telemetryHeight: 3,
    bcConfirmationDepthSigma: 3,
  }

  pure val wrongKeyWire = {
    byteLen: 11,
    keyTag: 99,
    activationHeight: 1,
    telemetryHeight: 0,
    bcConfirmationDepthSigma: 3,
  }

  pure val staleActivationWire = {
    byteLen: 11,
    keyTag: 1,
    activationHeight: 0,
    telemetryHeight: 0,
    bcConfirmationDepthSigma: 3,
  }

  pure val trailingBytesWire = {
    byteLen: 12,
    keyTag: 1,
    activationHeight: 1,
    telemetryHeight: 0,
    bcConfirmationDepthSigma: 3,
  }

  pure val outOfBoundsSigmaWire = {
    byteLen: 11,
    keyTag: 1,
    activationHeight: 1,
    telemetryHeight: 0,
    bcConfirmationDepthSigma: 99,
  }

  run productionParamLayoutPinnedTest = {
    ProductionParamInit
      .then(all {
        assert(ProductionParamLayoutConstantsPinned),
        assert(ProductionParamFieldOffsetsContiguous),
        assert(KeyTagOffset == 0),
        assert(ActivationHeightOffset == 1),
        assert(TelemetryHeightOffset == 5),
        assert(SigmaOffset == 9),
        assert(ConsensusParamWireByteLen == 11),
        unchangedAll,
      })
  }

  run initialProductionWireMatchesAbstractParamTest = {
    ProductionParamInit
      .then(all {
        assert(ProductionWireMatchesConsensusParam(
          initialSigmaWire,
          acceptedConsensusParamWire.get(0),
        )),
        assert(ActiveAbstractWireHasProductionEncoding),
        assert(ProductionConsensusParamFormatSafety),
        unchangedAll,
      })
  }

  run productionWireCommitsRaisedSigmaTest = {
    ProductionParamInit
      .then(CommitHeightWithProductionConsensusParamWire(
        heightOneSigmaThreeWire
      ))
      .then(all {
        assert(height == 1),
        assert(sigma == 3),
        assert(acceptedConsensusParamWire.get(1) ==
          EncodeConsensusParams(1, 0, 3)),
        assert(ProductionWireMatchesConsensusParam(
          heightOneSigmaThreeWire,
          acceptedConsensusParamWire.get(1),
        )),
        assert(ProductionConsensusParamFormatSafety),
        unchangedAll,
      })
  }

  run productionWireCommitsStableLoweredSigmaTest = {
    ProductionParamInit
      .then(CommitHeightWithProductionConsensusParamWire(
        heightOneSigmaThreeWire
      ))
      .then(CommitHeightWithProductionConsensusParamWire(
        heightTwoSigmaThreeWire
      ))
      .then(CommitHeightWithProductionConsensusParamWire(
        heightThreeSigmaTwoWire
      ))
      .then(all {
        assert(height == 3),
        assert(sigma == 2),
        assert(acceptedConsensusParamWire.get(3) ==
          EncodeConsensusParams(3, 2, 2)),
        assert(ProductionConsensusParamFormatSafety),
        unchangedAll,
      })
  }

  run lowParticipationWireCommitsRaisedSigmaTest = {
    ProductionParamInit
      .then(CommitHeightWithProductionConsensusParamWire(
        heightOneSigmaThreeWire
      ))
      .then(CommitHeightWithProductionConsensusParamWire(
        heightTwoSigmaThreeWire
      ))
      .then(CommitHeightWithProductionConsensusParamWire(
        heightThreeSigmaTwoWire
      ))
      .then(CommitHeightWithProductionConsensusParamWire(
        heightFourSigmaThreeWire
      ))
      .then(all {
        assert(height == 4),
        assert(HashPowerParticipationFloorBreachedAt(3)),
        assert(sigma == 3),
        assert(acceptedConsensusParamWire.get(4) ==
          EncodeConsensusParams(4, 3, 3)),
        assert(ProductionConsensusParamFormatSafety),
        unchangedAll,
      })
  }

  run nilRoundBurnPreservesProductionParamWireTest = {
    ProductionParamInit
      .then(BurnNilPrecommitRoundWithParams)
      .then(all {
        assert(height == 0),
        assert(acceptedConsensusParamWire.get(0) ==
          EncodeConsensusParams(0, 0, 2)),
        assert(ProductionConsensusParamFormatSafety),
        unchangedAll,
      })
  }

  run wrongKeyProductionWireRejectedTest = {
    ProductionParamInit
      .then(CommitHeightWithProductionConsensusParamWire(wrongKeyWire))
      .fail()
  }

  run staleActivationProductionWireRejectedTest = {
    ProductionParamInit
      .then(CommitHeightWithProductionConsensusParamWire(staleActivationWire))
      .fail()
  }

  run trailingBytesProductionWireRejectedTest = {
    ProductionParamInit
      .then(CommitHeightWithProductionConsensusParamWire(trailingBytesWire))
      .fail()
  }

  run outOfBoundsSigmaProductionWireRejectedTest = {
    ProductionParamInit
      .then(CommitHeightWithProductionConsensusParamWire(outOfBoundsSigmaWire))
      .fail()
  }

  run productionConsensusParamFormatSafetyTest = {
    ProductionParamInit
      .then(all {
        assert(ProductionConsensusParamFormatSafety),
        unchangedAll,
      })
  }
}

module CrosslinkDynamicSigmaConsensusParamFormatModel {
  import CrosslinkDynamicSigmaConsensusParamFormatTest(
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
      { paramKey: "bc_confirmation_depth_sigma", activationHeight: 0, telemetryHeight: 0, bcConfirmationDepthSigma: 2 },
      { paramKey: "bc_confirmation_depth_sigma", activationHeight: 1, telemetryHeight: 0, bcConfirmationDepthSigma: 3 },
      { paramKey: "bc_confirmation_depth_sigma", activationHeight: 2, telemetryHeight: 1, bcConfirmationDepthSigma: 3 },
      { paramKey: "bc_confirmation_depth_sigma", activationHeight: 3, telemetryHeight: 2, bcConfirmationDepthSigma: 2 },
      { paramKey: "bc_confirmation_depth_sigma", activationHeight: 4, telemetryHeight: 3, bcConfirmationDepthSigma: 3 },
      { paramKey: "bc_confirmation_depth_sigma", activationHeight: 0, telemetryHeight: 0, bcConfirmationDepthSigma: 3 },
    ),
    ProductionConsensusParamWires = Set(
      { byteLen: 11, keyTag: 1, activationHeight: 0, telemetryHeight: 0, bcConfirmationDepthSigma: 2 },
      { byteLen: 11, keyTag: 1, activationHeight: 1, telemetryHeight: 0, bcConfirmationDepthSigma: 3 },
      { byteLen: 11, keyTag: 1, activationHeight: 2, telemetryHeight: 1, bcConfirmationDepthSigma: 3 },
      { byteLen: 11, keyTag: 1, activationHeight: 3, telemetryHeight: 2, bcConfirmationDepthSigma: 2 },
      { byteLen: 11, keyTag: 1, activationHeight: 4, telemetryHeight: 3, bcConfirmationDepthSigma: 3 },
      { byteLen: 11, keyTag: 99, activationHeight: 1, telemetryHeight: 0, bcConfirmationDepthSigma: 3 },
      { byteLen: 11, keyTag: 1, activationHeight: 0, telemetryHeight: 0, bcConfirmationDepthSigma: 3 },
      { byteLen: 12, keyTag: 1, activationHeight: 1, telemetryHeight: 0, bcConfirmationDepthSigma: 3 },
      { byteLen: 11, keyTag: 1, activationHeight: 1, telemetryHeight: 0, bcConfirmationDepthSigma: 99 },
    ),
  ).*
}
