module CrosslinkDynamicSigmaPrototypeDecodeGate {
  /*
   Dynamic-sigma Tenderlink payload decode gate.

   Zebra's prototype dynamic-sigma path is feature gated. A payload starting
   with the dynamic-sigma magic bytes must not fall back to the legacy
   fixed-sigma decoder while the prototype gate is disabled. When the gate is
   enabled, the same tagged bytes still have to pass the dynamic-sigma payload
   validation boundary, and the decoded confirmation depth is the
   evidence-selected sigma rather than the fixed protocol parameter.
   */

  import CrosslinkDynamicSigmaBftPayloadTransportTest.* from
    "./CrosslinkDynamicSigmaBftPayloadTransport"
  export CrosslinkDynamicSigmaBftPayloadTransportTest.*

  type TenderlinkDecodeConfig_t = {
    dynamicSigmaPrototype: bool,
  }
  type TenderlinkPayloadWire_t = {
    sourceKind: str,
    startsWithDynamicSigmaMagic: bool,
    fixedBlockValid: bool,
    dynamicPayloadWellFormed: bool,
    dynamicPayload: DynamicSigmaBftPayloadEnvelope_t,
  }
  type DecodedTenderlinkPayload_t = {
    sourceKind: str,
    decodedKind: str,
    configDynamicSigmaPrototype: bool,
    startsWithDynamicSigmaMagic: bool,
    confirmationDepth: int,
    sourceEvidenceSelectedSigma: int,
    blockHeight: int,
    blockHash: str,
  }
  type RejectedTenderlinkPayload_t = {
    sourceKind: str,
    reason: str,
    configDynamicSigmaPrototype: bool,
    startsWithDynamicSigmaMagic: bool,
    dynamicPayloadWellFormed: bool,
  }

  pure val FixedSigmaPayloadKind = "fixed-sigma-bft-block"
  pure val DynamicSigmaPayloadKind = "dynamic-sigma-bft-payload"
  pure val MalformedPayloadKind = "malformed-payload"
  pure val DecodedFixedSigmaKind = "decoded-fixed-sigma"
  pure val DecodedDynamicSigmaKind = "decoded-dynamic-sigma"
  pure val FixedSigmaConfirmationDepth = 3
  pure val DynamicSigmaUnsupportedReason = "DynamicSigmaUnsupported"
  pure val DynamicSigmaInvalidReason = "DynamicSigmaInvalid"
  pure val InvalidPayloadReason = "Invalid"

  var decodedTenderlinkPayloads: Set[DecodedTenderlinkPayload_t]
  var rejectedTenderlinkPayloads: Set[RejectedTenderlinkPayload_t]
  var decodeGateFiredAction: str

  pure def FixedSigmaPayloadDecodable(wire: TenderlinkPayloadWire_t): bool =
    not(wire.startsWithDynamicSigmaMagic) and
    wire.sourceKind == FixedSigmaPayloadKind and
    wire.fixedBlockValid

  pure def DynamicSigmaPayloadDecodable(wire: TenderlinkPayloadWire_t): bool =
    wire.startsWithDynamicSigmaMagic and
    wire.sourceKind == DynamicSigmaPayloadKind and
    wire.dynamicPayloadWellFormed and
    DynamicSigmaBftPayloadEnvelopeValid(wire.dynamicPayload)

  pure def DynamicSigmaTaggedButUnsupported(
    config: TenderlinkDecodeConfig_t,
    wire: TenderlinkPayloadWire_t,
  ): bool =
    wire.startsWithDynamicSigmaMagic and
    not(config.dynamicSigmaPrototype)

  pure def DynamicSigmaTaggedButInvalid(
    config: TenderlinkDecodeConfig_t,
    wire: TenderlinkPayloadWire_t,
  ): bool =
    wire.startsWithDynamicSigmaMagic and
    config.dynamicSigmaPrototype and
    wire.dynamicPayloadWellFormed and
    not(DynamicSigmaPayloadDecodable(wire))

  pure def InvalidTenderlinkPayload(
    config: TenderlinkDecodeConfig_t,
    wire: TenderlinkPayloadWire_t,
  ): bool =
    not(FixedSigmaPayloadDecodable(wire)) and
    not(DynamicSigmaTaggedButUnsupported(config, wire)) and
    not(DynamicSigmaPayloadDecodable(wire)) and
    not(DynamicSigmaTaggedButInvalid(config, wire))

  pure def DecodedFixedPayload(
    config: TenderlinkDecodeConfig_t,
    wire: TenderlinkPayloadWire_t,
  ): DecodedTenderlinkPayload_t = {
    sourceKind: wire.sourceKind,
    decodedKind: DecodedFixedSigmaKind,
    configDynamicSigmaPrototype: config.dynamicSigmaPrototype,
    startsWithDynamicSigmaMagic: wire.startsWithDynamicSigmaMagic,
    confirmationDepth: FixedSigmaConfirmationDepth,
    sourceEvidenceSelectedSigma: FixedSigmaConfirmationDepth,
    blockHeight: FixtureLaterBftHeight,
    blockHash: "fixture-fixed-sigma-bft-block",
  }

  pure def DecodedDynamicPayload(
    config: TenderlinkDecodeConfig_t,
    wire: TenderlinkPayloadWire_t,
  ): DecodedTenderlinkPayload_t = {
    sourceKind: wire.sourceKind,
    decodedKind: DecodedDynamicSigmaKind,
    configDynamicSigmaPrototype: config.dynamicSigmaPrototype,
    startsWithDynamicSigmaMagic: wire.startsWithDynamicSigmaMagic,
    confirmationDepth: EvidenceSelectedSigma(wire.dynamicPayload.evidenceWire),
    sourceEvidenceSelectedSigma: EvidenceSelectedSigma(
      wire.dynamicPayload.evidenceWire
    ),
    blockHeight: wire.dynamicPayload.serializedBftHeight,
    blockHash: wire.dynamicPayload.blockHash,
  }

  pure def RejectedPayload(
    config: TenderlinkDecodeConfig_t,
    wire: TenderlinkPayloadWire_t,
    reason: str,
  ): RejectedTenderlinkPayload_t = {
    sourceKind: wire.sourceKind,
    reason: reason,
    configDynamicSigmaPrototype: config.dynamicSigmaPrototype,
    startsWithDynamicSigmaMagic: wire.startsWithDynamicSigmaMagic,
    dynamicPayloadWellFormed: wire.dynamicPayloadWellFormed,
  }

  action DecodeGateInit = all {
    DynamicSigmaBftPayloadTransportInit,
    decodedTenderlinkPayloads' = Set(),
    rejectedTenderlinkPayloads' = Set(),
    decodeGateFiredAction' = "DecodeGateInit",
  }

  action DecodeFixedSigmaPayload(
    config: TenderlinkDecodeConfig_t,
    wire: TenderlinkPayloadWire_t,
  ): bool =
    all {
      FixedSigmaPayloadDecodable(wire),
      DynamicSigmaBftPayloadTransportStutter,
      decodedTenderlinkPayloads' =
        decodedTenderlinkPayloads.union(Set(DecodedFixedPayload(config, wire))),
      rejectedTenderlinkPayloads' = rejectedTenderlinkPayloads,
      decodeGateFiredAction' = "DecodeFixedSigmaPayload",
    }

  action RejectUnsupportedDynamicSigmaPayload(
    config: TenderlinkDecodeConfig_t,
    wire: TenderlinkPayloadWire_t,
  ): bool =
    all {
      DynamicSigmaTaggedButUnsupported(config, wire),
      DynamicSigmaBftPayloadTransportStutter,
      decodedTenderlinkPayloads' = decodedTenderlinkPayloads,
      rejectedTenderlinkPayloads' =
        rejectedTenderlinkPayloads.union(Set(RejectedPayload(
          config,
          wire,
          DynamicSigmaUnsupportedReason,
        ))),
      decodeGateFiredAction' = "RejectUnsupportedDynamicSigmaPayload",
    }

  action DecodeDynamicSigmaPayload(
    config: TenderlinkDecodeConfig_t,
    wire: TenderlinkPayloadWire_t,
  ): bool =
    all {
      config.dynamicSigmaPrototype,
      DynamicSigmaPayloadDecodable(wire),
      DynamicSigmaBftPayloadTransportStutter,
      decodedTenderlinkPayloads' =
        decodedTenderlinkPayloads.union(Set(DecodedDynamicPayload(
          config,
          wire,
        ))),
      rejectedTenderlinkPayloads' = rejectedTenderlinkPayloads,
      decodeGateFiredAction' = "DecodeDynamicSigmaPayload",
    }

  action RejectInvalidDynamicSigmaPayload(
    config: TenderlinkDecodeConfig_t,
    wire: TenderlinkPayloadWire_t,
  ): bool =
    all {
      DynamicSigmaTaggedButInvalid(config, wire),
      DynamicSigmaBftPayloadTransportStutter,
      decodedTenderlinkPayloads' = decodedTenderlinkPayloads,
      rejectedTenderlinkPayloads' =
        rejectedTenderlinkPayloads.union(Set(RejectedPayload(
          config,
          wire,
          DynamicSigmaInvalidReason,
        ))),
      decodeGateFiredAction' = "RejectInvalidDynamicSigmaPayload",
    }

  action RejectInvalidTenderlinkPayload(
    config: TenderlinkDecodeConfig_t,
    wire: TenderlinkPayloadWire_t,
  ): bool =
    all {
      InvalidTenderlinkPayload(config, wire),
      DynamicSigmaBftPayloadTransportStutter,
      decodedTenderlinkPayloads' = decodedTenderlinkPayloads,
      rejectedTenderlinkPayloads' =
        rejectedTenderlinkPayloads.union(Set(RejectedPayload(
          config,
          wire,
          InvalidPayloadReason,
        ))),
      decodeGateFiredAction' = "RejectInvalidTenderlinkPayload",
    }

  action DecodeTenderlinkPayload(
    config: TenderlinkDecodeConfig_t,
    wire: TenderlinkPayloadWire_t,
  ): bool =
    any {
      DecodeFixedSigmaPayload(config, wire),
      RejectUnsupportedDynamicSigmaPayload(config, wire),
      DecodeDynamicSigmaPayload(config, wire),
      RejectInvalidDynamicSigmaPayload(config, wire),
      RejectInvalidTenderlinkPayload(config, wire),
    }

  action DecodeGateStutter: bool =
    all {
      DynamicSigmaBftPayloadTransportStutter,
      decodedTenderlinkPayloads' = decodedTenderlinkPayloads,
      rejectedTenderlinkPayloads' = rejectedTenderlinkPayloads,
      decodeGateFiredAction' = decodeGateFiredAction,
    }

  val DecodedDynamicPayloadsRequireEnabledPrototype =
    decodedTenderlinkPayloads.forall(decoded =>
      decoded.decodedKind != DecodedDynamicSigmaKind or
      decoded.configDynamicSigmaPrototype
    )

  val TaggedPayloadsNeverDecodeAsFixed =
    decodedTenderlinkPayloads.forall(decoded =>
      not(decoded.startsWithDynamicSigmaMagic) or
      decoded.decodedKind != DecodedFixedSigmaKind
    )

  val FixedPayloadsUseFixedConfirmationDepth =
    decodedTenderlinkPayloads.forall(decoded =>
      decoded.decodedKind != DecodedFixedSigmaKind or
      decoded.confirmationDepth == FixedSigmaConfirmationDepth
    )

  val DynamicPayloadsUseEvidenceSelectedSigma =
    decodedTenderlinkPayloads.forall(decoded =>
      decoded.decodedKind != DecodedDynamicSigmaKind or
      decoded.confirmationDepth == decoded.sourceEvidenceSelectedSigma
    )

  val UnsupportedRejectsOnlyDisabledTaggedPayloads =
    rejectedTenderlinkPayloads.forall(rejected =>
      rejected.reason != DynamicSigmaUnsupportedReason or
      (
        rejected.startsWithDynamicSigmaMagic and
        not(rejected.configDynamicSigmaPrototype)
      )
    )

  val DecodeGateSafety =
    DynamicSigmaBftPayloadTransportSafety and
    DecodedDynamicPayloadsRequireEnabledPrototype and
    TaggedPayloadsNeverDecodeAsFixed and
    FixedPayloadsUseFixedConfirmationDepth and
    DynamicPayloadsUseEvidenceSelectedSigma and
    UnsupportedRejectsOnlyDisabledTaggedPayloads
}

module CrosslinkDynamicSigmaPrototypeDecodeGateTest {
  import CrosslinkDynamicSigmaPrototypeDecodeGate.* from
    "./CrosslinkDynamicSigmaPrototypeDecodeGate"
  export CrosslinkDynamicSigmaPrototypeDecodeGate.*

  pure val PrototypeDisabled = { dynamicSigmaPrototype: false }
  pure val PrototypeEnabled = { dynamicSigmaPrototype: true }

  pure def Wire(
    sourceKind: str,
    startsWithDynamicSigmaMagic: bool,
    fixedBlockValid: bool,
    dynamicPayloadWellFormed: bool,
    dynamicPayload: DynamicSigmaBftPayloadEnvelope_t,
  ): TenderlinkPayloadWire_t = {
    sourceKind: sourceKind,
    startsWithDynamicSigmaMagic: startsWithDynamicSigmaMagic,
    fixedBlockValid: fixedBlockValid,
    dynamicPayloadWellFormed: dynamicPayloadWellFormed,
    dynamicPayload: dynamicPayload,
  }

  pure val FixedSigmaFixtureWire =
    Wire(
      FixedSigmaPayloadKind,
      false,
      true,
      false,
      DynamicSigmaFixturePayloadEnvelope,
    )

  pure val DynamicSigmaFixtureWire =
    Wire(
      DynamicSigmaPayloadKind,
      true,
      false,
      true,
      DynamicSigmaFixturePayloadEnvelope,
    )

  pure val DynamicSigmaInvalidEvidenceWire =
    Wire(
      DynamicSigmaPayloadKind,
      true,
      false,
      true,
      BelowRequiredEvidencePayloadEnvelope,
    )

  pure val DynamicSigmaMalformedTaggedWire =
    Wire(
      MalformedPayloadKind,
      true,
      false,
      false,
      DynamicSigmaFixturePayloadEnvelope,
    )

  pure val MalformedFixedWire =
    Wire(
      MalformedPayloadKind,
      false,
      false,
      false,
      DynamicSigmaFixturePayloadEnvelope,
    )

  pure val DecodeGateConfigs = Set(PrototypeDisabled, PrototypeEnabled)
  pure val DecodeGateWires = Set(
    FixedSigmaFixtureWire,
    DynamicSigmaFixtureWire,
    DynamicSigmaInvalidEvidenceWire,
    DynamicSigmaMalformedTaggedWire,
    MalformedFixedWire,
  )

  action DecodeGateNext: bool =
    any {
      nondet config = oneOf(DecodeGateConfigs)
      nondet wire = oneOf(DecodeGateWires)
      DecodeTenderlinkPayload(config, wire),
      DecodeGateStutter,
    }

  run fixedSigmaPayloadAcceptedWithFixedDepthTest = {
    DecodeGateInit
      .then(DecodeTenderlinkPayload(PrototypeDisabled, FixedSigmaFixtureWire))
      .then(all {
        assert(decodedTenderlinkPayloads.contains(DecodedFixedPayload(
          PrototypeDisabled,
          FixedSigmaFixtureWire,
        ))),
        assert(DecodeGateSafety),
        DecodeGateStutter,
      })
  }

  run dynamicSigmaPayloadRejectedByDefaultTest = {
    DecodeGateInit
      .then(DecodeTenderlinkPayload(PrototypeDisabled, DynamicSigmaFixtureWire))
      .then(all {
        assert(rejectedTenderlinkPayloads.contains(RejectedPayload(
          PrototypeDisabled,
          DynamicSigmaFixtureWire,
          DynamicSigmaUnsupportedReason,
        ))),
        assert(not(decodedTenderlinkPayloads.exists(decoded =>
          decoded.decodedKind == DecodedDynamicSigmaKind
        ))),
        assert(DecodeGateSafety),
        DecodeGateStutter,
      })
  }

  run dynamicSigmaPayloadAcceptedWhenPrototypeEnabledTest = {
    DecodeGateInit
      .then(DecodeTenderlinkPayload(PrototypeEnabled, DynamicSigmaFixtureWire))
      .then(all {
        assert(decodedTenderlinkPayloads.contains(DecodedDynamicPayload(
          PrototypeEnabled,
          DynamicSigmaFixtureWire,
        ))),
        assert(DecodedDynamicPayload(
          PrototypeEnabled,
          DynamicSigmaFixtureWire,
        ).confirmationDepth == 3),
        assert(DecodeGateSafety),
        DecodeGateStutter,
      })
  }

  run taggedPayloadNeverFallsBackToFixedTest = {
    DecodeGateInit
      .then(DecodeTenderlinkPayload(PrototypeDisabled, DynamicSigmaFixtureWire))
      .then(DecodeTenderlinkPayload(
        PrototypeEnabled,
        DynamicSigmaMalformedTaggedWire,
      ))
      .then(all {
        assert(decodedTenderlinkPayloads.forall(decoded =>
          decoded.decodedKind != DecodedFixedSigmaKind
        )),
        assert(DecodeGateSafety),
        DecodeGateStutter,
      })
  }

  run enabledPrototypeRejectsInvalidDynamicPayloadTest = {
    DecodeGateInit
      .then(DecodeTenderlinkPayload(
        PrototypeEnabled,
        DynamicSigmaInvalidEvidenceWire,
      ))
      .then(all {
        assert(rejectedTenderlinkPayloads.contains(RejectedPayload(
          PrototypeEnabled,
          DynamicSigmaInvalidEvidenceWire,
          DynamicSigmaInvalidReason,
        ))),
        assert(not(decodedTenderlinkPayloads.exists(decoded =>
          decoded.decodedKind == DecodedDynamicSigmaKind
        ))),
        assert(DecodeGateSafety),
        DecodeGateStutter,
      })
  }

  run enabledPrototypeRejectsMalformedTaggedPayloadTest = {
    DecodeGateInit
      .then(DecodeTenderlinkPayload(
        PrototypeEnabled,
        DynamicSigmaMalformedTaggedWire,
      ))
      .then(all {
        assert(rejectedTenderlinkPayloads.contains(RejectedPayload(
          PrototypeEnabled,
          DynamicSigmaMalformedTaggedWire,
          InvalidPayloadReason,
        ))),
        assert(DecodeGateSafety),
        DecodeGateStutter,
      })
  }

  run disabledPrototypeRejectsMalformedTaggedPayloadBeforeParseTest = {
    DecodeGateInit
      .then(DecodeTenderlinkPayload(
        PrototypeDisabled,
        DynamicSigmaMalformedTaggedWire,
      ))
      .then(all {
        assert(rejectedTenderlinkPayloads.contains(RejectedPayload(
          PrototypeDisabled,
          DynamicSigmaMalformedTaggedWire,
          DynamicSigmaUnsupportedReason,
        ))),
        assert(DecodeGateSafety),
        DecodeGateStutter,
      })
  }

  run malformedFixedPayloadRejectedTest = {
    DecodeGateInit
      .then(DecodeTenderlinkPayload(PrototypeDisabled, MalformedFixedWire))
      .then(all {
        assert(rejectedTenderlinkPayloads.contains(RejectedPayload(
          PrototypeDisabled,
          MalformedFixedWire,
          InvalidPayloadReason,
        ))),
        assert(DecodeGateSafety),
        DecodeGateStutter,
      })
  }
}

module CrosslinkDynamicSigmaPrototypeDecodeGateModel {
  import CrosslinkDynamicSigmaPrototypeDecodeGateTest.* from
    "./CrosslinkDynamicSigmaPrototypeDecodeGate"
  export CrosslinkDynamicSigmaPrototypeDecodeGateTest.*
}
