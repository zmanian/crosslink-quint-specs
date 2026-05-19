module CrosslinkDynamicSigmaBftPayloadTransport {
  /*
   Dynamic-sigma BFT payload transport boundary.

   Zebra's dynamic-sigma Tenderlink payload is intentionally tagged so it
   cannot be parsed as a fixed-sigma BFT block:

     DYNAMIC_SIGMA_BFT_BLOCK_PAYLOAD_MAGIC || DynamicSigmaProposalEvidence || BftBlock

   The proposal-evidence format model pins the evidence bytes. The production
   BFT-block vector model pins the checked-in BFT-block fixture shape. This
   slice composes them at the proposal payload boundary: a transported
   dynamic-sigma BFT payload is accepted only when the magic is exact, the
   evidence bytes are canonical, and the carried BFT block header count matches
   the selected sigma justified by that evidence.
   */

  import CrosslinkDynamicSigmaProposalEvidenceFormat(
    BaseSigma = 1,
    RaisedSigma = 3,
    MaxSigma = 6,
    TargetHashParticipationPct = 67,
    CriticalHashParticipationPct = 50,
    MaxAcceptableRollbackRiskPpm = 25,
    CoverageRiskWeight = 2,
    RoundFailureRiskWeight = 3,
    BlockVarianceRiskWeight = 1,
    ReorgDepthRiskWeight = 5,
    RiskScoreRaisedThreshold = 60,
    RiskScoreMaxThreshold = 100,
    ProductionProposalEvidenceWires = Set(),
  ) as Evidence from
    "./CrosslinkDynamicSigmaProposalEvidenceFormat"
  import CrosslinkBftBlockProductionVectors(
    MaxPreviousFatPointerSignatures = 2,
    MaxHeaderCountVector = 4,
    Sigma = 3,
    DeserializerHeaderCountCap = 2048,
  ) as BftVectors from
    "./CrosslinkBftBlockProductionVectors"

  type Bytes_t = str
  type ProposalTopic_t = str
  type ProposalEnvelopeKind_t = str
  type BlockHash_t = str
  type U128Le_t = {
    low64: int,
    high64: int,
  }
  type RollbackRiskCurve_t = {
    baseSigmaPpm: int,
    raisedSigmaPpm: int,
    maxSigmaPpm: int,
  }
  type DynamicSigmaRawTelemetry_t = {
    totalHashWork: U128Le_t,
    crosslinkParticipatingHashWork: U128Le_t,
    totalTenderlinkRounds: int,
    failedTenderlinkRounds: int,
    measuredBlockIntervalVariancePct: int,
    measuredObservedReorgDepth: int,
    rollbackRisk: RollbackRiskCurve_t,
    valueAtRiskUnits: U128Le_t,
    maxAcceptableExpectedLossUnits: U128Le_t,
  }
  type TelemetryEstimateMargins_t = {
    coverageRiskMarginPct: int,
    roundFailureMarginPct: int,
  }
  type DynamicSigmaProposalEvidence_t = {
    rawTelemetry: DynamicSigmaRawTelemetry_t,
    margins: TelemetryEstimateMargins_t,
    selectedSigma: int,
  }
  type ProductionDynamicSigmaProposalEvidenceWire_t = {
    byteLen: int,
    evidence: DynamicSigmaProposalEvidence_t,
    bytes: Bytes_t,
  }

  type DynamicSigmaBftPayloadEnvelope_t = {
    topic: ProposalTopic_t,
    kind: ProposalEnvelopeKind_t,
    height: int,
    round: int,
    blockHash: BlockHash_t,
    magicByteLen: int,
    magicHex: Bytes_t,
    evidenceOffset: int,
    evidenceByteLen: int,
    evidenceBytes: Bytes_t,
    evidenceWire: ProductionDynamicSigmaProposalEvidenceWire_t,
    blockOffset: int,
    bftBlockByteLen: int,
    payloadByteLen: int,
    serializedBftBlockVersion: int,
    serializedBftHeight: int,
    finalizationCandidateHeight: int,
    finalizationCandidateHeightOffset: int,
    headerCountOffset: int,
    headersStartOffset: int,
    previousFatPointerSignatureCount: int,
    headerCount: int,
    selectedSigma: int,
  }

  pure val CrosslinkDynamicSigmaProposalTopic =
    "crosslink-dynamic-sigma-proposal-v1"
  pure val WrongProposalTopic = "zcash-blocks-v1"
  pure val DynamicSigmaBftPayloadEnvelopeKind =
    "dynamic-sigma-bft-payload"
  pure val WrongDynamicSigmaPayloadKind = "fixed-sigma-bft-block"
  pure val DynamicSigmaBftPayloadMagicByteLen = 8
  pure val DynamicSigmaBftPayloadMagicHex = "434c445349473031"
  pure val WrongDynamicSigmaBftPayloadMagicHex = "bc4c445349473031"
  pure val DynamicSigmaBftPayloadEvidenceOffset =
    DynamicSigmaBftPayloadMagicByteLen
  pure val DynamicSigmaBftPayloadBlockOffset =
    DynamicSigmaBftPayloadEvidenceOffset +
    Evidence::DynamicSigmaProposalEvidenceByteLen
  pure val FixtureLaterBftHeight = BftVectors::FixtureLaterBftHeight
  pure val FixtureLaterBftBlockByteLen =
    BftVectors::FixtureLaterBftBlockByteLen
  pure val FixtureLaterBftBlockVersion =
    BftVectors::FixtureLaterBftBlockVersion
  pure val FixtureLaterFinalizationCandidateHeight =
    BftVectors::FixtureLaterFinalizationCandidateHeight
  pure val FixtureLaterFinalizationCandidateHeightOffset =
    BftVectors::FixtureLaterFinalizationCandidateHeightOffset
  pure val FixtureLaterHeaderCountOffset =
    BftVectors::FixtureLaterHeaderCountOffset
  pure val FixtureLaterHeadersStartOffset =
    BftVectors::FixtureLaterHeadersStartOffset
  pure val FixtureLaterPreviousFatPointerSignatureCount =
    BftVectors::FixtureLaterPreviousFatPointerSignatureCount
  pure val FixtureHeaderCount = BftVectors::FixtureHeaderCount

  var transportedDynamicSigmaBftPayload:
    Set[DynamicSigmaBftPayloadEnvelope_t]
  var acceptedDynamicSigmaBftPayload:
    Set[DynamicSigmaBftPayloadEnvelope_t]
  var dynamicSigmaBftPayloadFiredAction: str

  pure def EvidenceSelectedSigma(
    wire: ProductionDynamicSigmaProposalEvidenceWire_t,
  ): int =
    Evidence::DecodeProductionProposalEvidenceWire(wire).selectedSigma

  pure def DynamicSigmaBftPayloadExpectedByteLen(
    env: DynamicSigmaBftPayloadEnvelope_t,
  ): int =
    DynamicSigmaBftPayloadBlockOffset + env.bftBlockByteLen

  pure def DynamicSigmaBftPayloadLayoutPinned: bool =
    DynamicSigmaBftPayloadMagicByteLen == 8 and
    DynamicSigmaBftPayloadMagicHex == "434c445349473031" and
    DynamicSigmaBftPayloadEvidenceOffset == 8 and
    DynamicSigmaBftPayloadBlockOffset == 131

  pure def DynamicSigmaBftBlockFixtureShapeValid(
    env: DynamicSigmaBftPayloadEnvelope_t,
  ): bool =
    env.bftBlockByteLen == BftVectors::FixtureLaterBftBlockByteLen and
    env.serializedBftBlockVersion == BftVectors::FixtureLaterBftBlockVersion and
    env.serializedBftHeight == BftVectors::FixtureLaterBftHeight and
    env.finalizationCandidateHeight ==
      BftVectors::FixtureLaterFinalizationCandidateHeight and
    env.finalizationCandidateHeightOffset ==
      BftVectors::FixtureLaterFinalizationCandidateHeightOffset and
    env.headerCountOffset == BftVectors::FixtureLaterHeaderCountOffset and
    env.headersStartOffset == BftVectors::FixtureLaterHeadersStartOffset and
    env.previousFatPointerSignatureCount ==
      BftVectors::FixtureLaterPreviousFatPointerSignatureCount and
    env.headerCount == BftVectors::FixtureHeaderCount and
    BftVectors::TryFromWouldAcceptHeaderCount(env.headerCount)

  pure def DynamicSigmaBftPayloadEnvelopeValid(
    env: DynamicSigmaBftPayloadEnvelope_t,
  ): bool =
    env.topic == CrosslinkDynamicSigmaProposalTopic and
    env.kind == DynamicSigmaBftPayloadEnvelopeKind and
    env.magicByteLen == DynamicSigmaBftPayloadMagicByteLen and
    env.magicHex == DynamicSigmaBftPayloadMagicHex and
    env.evidenceOffset == DynamicSigmaBftPayloadEvidenceOffset and
    env.evidenceByteLen == Evidence::DynamicSigmaProposalEvidenceByteLen and
    env.evidenceBytes == env.evidenceWire.bytes and
    Evidence::ProductionProposalEvidenceWireWellFormed(env.evidenceWire) and
    env.blockOffset == DynamicSigmaBftPayloadBlockOffset and
    env.payloadByteLen == DynamicSigmaBftPayloadExpectedByteLen(env) and
    DynamicSigmaBftBlockFixtureShapeValid(env) and
    env.selectedSigma == EvidenceSelectedSigma(env.evidenceWire) and
    env.headerCount == env.selectedSigma

  action DynamicSigmaBftPayloadTransportInit = all {
    Evidence::Init,
    transportedDynamicSigmaBftPayload' = Set(),
    acceptedDynamicSigmaBftPayload' = Set(),
    dynamicSigmaBftPayloadFiredAction' =
      "DynamicSigmaBftPayloadTransportInit",
  }

  action KeepEvidenceState = all {
    Evidence::acceptedProductionProposalEvidenceWires' =
      Evidence::acceptedProductionProposalEvidenceWires,
    Evidence::firedAction' = Evidence::firedAction,
  }

  action GossipDynamicSigmaBftPayload(
    env: DynamicSigmaBftPayloadEnvelope_t,
  ): bool =
    all {
      DynamicSigmaBftPayloadEnvelopeValid(env),
      Evidence::AcceptProductionProposalEvidenceWire(env.evidenceWire),
      transportedDynamicSigmaBftPayload' =
        transportedDynamicSigmaBftPayload.union(Set(env)),
      acceptedDynamicSigmaBftPayload' = acceptedDynamicSigmaBftPayload,
      dynamicSigmaBftPayloadFiredAction' =
        "GossipDynamicSigmaBftPayload",
    }

  action AcceptTransportedDynamicSigmaBftPayload(
    env: DynamicSigmaBftPayloadEnvelope_t,
  ): bool =
    all {
      DynamicSigmaBftPayloadEnvelopeValid(env),
      transportedDynamicSigmaBftPayload.contains(env),
      KeepEvidenceState,
      transportedDynamicSigmaBftPayload' = transportedDynamicSigmaBftPayload,
      acceptedDynamicSigmaBftPayload' =
        acceptedDynamicSigmaBftPayload.union(Set(env)),
      dynamicSigmaBftPayloadFiredAction' =
        "AcceptTransportedDynamicSigmaBftPayload",
    }

  action RawAcceptDynamicSigmaBftPayloadWithoutTransport(
    env: DynamicSigmaBftPayloadEnvelope_t,
  ): bool =
    all {
      DynamicSigmaBftPayloadEnvelopeValid(env),
      KeepEvidenceState,
      transportedDynamicSigmaBftPayload' = transportedDynamicSigmaBftPayload,
      acceptedDynamicSigmaBftPayload' =
        acceptedDynamicSigmaBftPayload.union(Set(env)),
      dynamicSigmaBftPayloadFiredAction' =
        "RawAcceptDynamicSigmaBftPayloadWithoutTransport",
    }

  action DynamicSigmaBftPayloadTransportStutter: bool =
    all {
      KeepEvidenceState,
      transportedDynamicSigmaBftPayload' = transportedDynamicSigmaBftPayload,
      acceptedDynamicSigmaBftPayload' = acceptedDynamicSigmaBftPayload,
      dynamicSigmaBftPayloadFiredAction' =
        dynamicSigmaBftPayloadFiredAction,
    }

  def MatchingTransportedDynamicSigmaPayload(
    env: DynamicSigmaBftPayloadEnvelope_t,
  ): bool =
    transportedDynamicSigmaBftPayload.contains(env) and
    DynamicSigmaBftPayloadEnvelopeValid(env)

  val TransportedDynamicSigmaPayloadsValid =
    transportedDynamicSigmaBftPayload.forall(
      DynamicSigmaBftPayloadEnvelopeValid
    )

  val AcceptedDynamicSigmaPayloadsHaveTransport =
    acceptedDynamicSigmaBftPayload.forall(
      MatchingTransportedDynamicSigmaPayload
    )

  val AcceptedDynamicSigmaPayloadsUseEvidenceSelectedSigma =
    acceptedDynamicSigmaBftPayload.forall(env =>
      env.selectedSigma == EvidenceSelectedSigma(env.evidenceWire) and
      env.headerCount == env.selectedSigma
    )

  val DynamicSigmaBftPayloadTransportSafety =
    Evidence::ProductionProposalEvidenceFormatSafety and
    BftVectors::Safety and
    DynamicSigmaBftPayloadLayoutPinned and
    TransportedDynamicSigmaPayloadsValid and
    AcceptedDynamicSigmaPayloadsHaveTransport and
    AcceptedDynamicSigmaPayloadsUseEvidenceSelectedSigma
}

module CrosslinkDynamicSigmaBftPayloadTransportTest {
  import CrosslinkDynamicSigmaBftPayloadTransport.* from
    "./CrosslinkDynamicSigmaBftPayloadTransport"
  export CrosslinkDynamicSigmaBftPayloadTransport.*

  pure val DegradedParticipationRawTelemetry = {
    totalHashWork: { low64: 100, high64: 0 },
    crosslinkParticipatingHashWork: { low64: 63, high64: 0 },
    totalTenderlinkRounds: 10,
    failedTenderlinkRounds: 0,
    measuredBlockIntervalVariancePct: 0,
    measuredObservedReorgDepth: 0,
    rollbackRisk: {
      baseSigmaPpm: 80,
      raisedSigmaPpm: 20,
      maxSigmaPpm: 2,
    },
    valueAtRiskUnits: { low64: 1000, high64: 0 },
    maxAcceptableExpectedLossUnits: { low64: 1, high64: 0 },
  }

  pure val DegradedMargins = {
    coverageRiskMarginPct: 2,
    roundFailureMarginPct: 0,
  }

  pure val DegradedParticipationEvidence = {
    rawTelemetry: DegradedParticipationRawTelemetry,
    margins: DegradedMargins,
    selectedSigma: 3,
  }

  pure val BelowRequiredSigmaEvidence = {
    rawTelemetry: DegradedParticipationRawTelemetry,
    margins: DegradedMargins,
    selectedSigma: 1,
  }

  pure val DegradedParticipationEvidenceHex =
    "640000000000000000000000000000003f0000000000000000000000000000000a000000000000000000000000000000000000000000000000500000000000000014000000000000000200000000000000e80300000000000000000000000000000100000000000000000000000000000002000300000000000000"
  pure val BelowRequiredSigmaEvidenceHex =
    "640000000000000000000000000000003f0000000000000000000000000000000a000000000000000000000000000000000000000000000000500000000000000014000000000000000200000000000000e80300000000000000000000000000000100000000000000000000000000000002000100000000000000"
  pure val DegradedParticipationEvidenceTrailingHex =
    "640000000000000000000000000000003f0000000000000000000000000000000a000000000000000000000000000000000000000000000000500000000000000014000000000000000200000000000000e8030000000000000000000000000000010000000000000000000000000000000200030000000000000000"
  pure val WrongEvidenceBytes = "wrong-dynamic-sigma-evidence-bytes"

  pure val DegradedParticipationWire = {
    byteLen: 123,
    evidence: DegradedParticipationEvidence,
    bytes: DegradedParticipationEvidenceHex,
  }

  pure val BelowRequiredSigmaWire = {
    byteLen: 123,
    evidence: BelowRequiredSigmaEvidence,
    bytes: BelowRequiredSigmaEvidenceHex,
  }

  pure val TrailingBytesWire = {
    byteLen: 124,
    evidence: DegradedParticipationEvidence,
    bytes: DegradedParticipationEvidenceTrailingHex,
  }

  pure val WrongBytesWire = {
    byteLen: 123,
    evidence: DegradedParticipationEvidence,
    bytes: WrongEvidenceBytes,
  }

  pure def Env(
    topic: ProposalTopic_t,
    kind: ProposalEnvelopeKind_t,
    magicHex: Bytes_t,
    evidenceWire: ProductionDynamicSigmaProposalEvidenceWire_t,
    evidenceBytes: Bytes_t,
    headerCount: int,
    selectedSigma: int,
  ): DynamicSigmaBftPayloadEnvelope_t = {
    topic: topic,
    kind: kind,
    height: FixtureLaterBftHeight,
    round: 0,
    blockHash: "fixture-dynamic-sigma-bft-block",
    magicByteLen: DynamicSigmaBftPayloadMagicByteLen,
    magicHex: magicHex,
    evidenceOffset: DynamicSigmaBftPayloadEvidenceOffset,
    evidenceByteLen: evidenceWire.byteLen,
    evidenceBytes: evidenceBytes,
    evidenceWire: evidenceWire,
    blockOffset: DynamicSigmaBftPayloadBlockOffset,
    bftBlockByteLen: FixtureLaterBftBlockByteLen,
    payloadByteLen: DynamicSigmaBftPayloadBlockOffset +
      FixtureLaterBftBlockByteLen,
    serializedBftBlockVersion: FixtureLaterBftBlockVersion,
    serializedBftHeight: FixtureLaterBftHeight,
    finalizationCandidateHeight: FixtureLaterFinalizationCandidateHeight,
    finalizationCandidateHeightOffset:
      FixtureLaterFinalizationCandidateHeightOffset,
    headerCountOffset: FixtureLaterHeaderCountOffset,
    headersStartOffset: FixtureLaterHeadersStartOffset,
    previousFatPointerSignatureCount:
      FixtureLaterPreviousFatPointerSignatureCount,
    headerCount: headerCount,
    selectedSigma: selectedSigma,
  }

  pure val DynamicSigmaFixturePayloadEnvelope =
    Env(
      CrosslinkDynamicSigmaProposalTopic,
      DynamicSigmaBftPayloadEnvelopeKind,
      DynamicSigmaBftPayloadMagicHex,
      DegradedParticipationWire,
      DegradedParticipationEvidenceHex,
      3,
      3,
    )

  pure val WrongTopicPayloadEnvelope =
    Env(
      WrongProposalTopic,
      DynamicSigmaBftPayloadEnvelopeKind,
      DynamicSigmaBftPayloadMagicHex,
      DegradedParticipationWire,
      DegradedParticipationEvidenceHex,
      3,
      3,
    )

  pure val WrongKindPayloadEnvelope =
    Env(
      CrosslinkDynamicSigmaProposalTopic,
      WrongDynamicSigmaPayloadKind,
      DynamicSigmaBftPayloadMagicHex,
      DegradedParticipationWire,
      DegradedParticipationEvidenceHex,
      3,
      3,
    )

  pure val WrongMagicPayloadEnvelope =
    Env(
      CrosslinkDynamicSigmaProposalTopic,
      DynamicSigmaBftPayloadEnvelopeKind,
      WrongDynamicSigmaBftPayloadMagicHex,
      DegradedParticipationWire,
      DegradedParticipationEvidenceHex,
      3,
      3,
    )

  pure val BelowRequiredEvidencePayloadEnvelope =
    Env(
      CrosslinkDynamicSigmaProposalTopic,
      DynamicSigmaBftPayloadEnvelopeKind,
      DynamicSigmaBftPayloadMagicHex,
      BelowRequiredSigmaWire,
      BelowRequiredSigmaEvidenceHex,
      1,
      1,
    )

  pure val TrailingEvidencePayloadEnvelope =
    Env(
      CrosslinkDynamicSigmaProposalTopic,
      DynamicSigmaBftPayloadEnvelopeKind,
      DynamicSigmaBftPayloadMagicHex,
      TrailingBytesWire,
      DegradedParticipationEvidenceTrailingHex,
      3,
      3,
    )

  pure val WrongEvidenceBytesPayloadEnvelope =
    Env(
      CrosslinkDynamicSigmaProposalTopic,
      DynamicSigmaBftPayloadEnvelopeKind,
      DynamicSigmaBftPayloadMagicHex,
      WrongBytesWire,
      WrongEvidenceBytes,
      3,
      3,
    )

  pure val EvidenceBytesMismatchPayloadEnvelope =
    Env(
      CrosslinkDynamicSigmaProposalTopic,
      DynamicSigmaBftPayloadEnvelopeKind,
      DynamicSigmaBftPayloadMagicHex,
      DegradedParticipationWire,
      WrongEvidenceBytes,
      3,
      3,
    )

  pure val HeaderCountMismatchPayloadEnvelope =
    Env(
      CrosslinkDynamicSigmaProposalTopic,
      DynamicSigmaBftPayloadEnvelopeKind,
      DynamicSigmaBftPayloadMagicHex,
      DegradedParticipationWire,
      DegradedParticipationEvidenceHex,
      2,
      3,
    )

  pure val SelectedSigmaMismatchPayloadEnvelope =
    Env(
      CrosslinkDynamicSigmaProposalTopic,
      DynamicSigmaBftPayloadEnvelopeKind,
      DynamicSigmaBftPayloadMagicHex,
      DegradedParticipationWire,
      DegradedParticipationEvidenceHex,
      3,
      2,
    )

  pure val TestDynamicSigmaBftPayloadEnvelopes = Set(
    DynamicSigmaFixturePayloadEnvelope,
    WrongTopicPayloadEnvelope,
    WrongKindPayloadEnvelope,
    WrongMagicPayloadEnvelope,
    BelowRequiredEvidencePayloadEnvelope,
    TrailingEvidencePayloadEnvelope,
    WrongEvidenceBytesPayloadEnvelope,
    EvidenceBytesMismatchPayloadEnvelope,
    HeaderCountMismatchPayloadEnvelope,
    SelectedSigmaMismatchPayloadEnvelope,
  )

  action DynamicSigmaBftPayloadTransportNext: bool =
    any {
      nondet env = oneOf(TestDynamicSigmaBftPayloadEnvelopes)
      GossipDynamicSigmaBftPayload(env),
      nondet env = oneOf(TestDynamicSigmaBftPayloadEnvelopes)
      AcceptTransportedDynamicSigmaBftPayload(env),
      DynamicSigmaBftPayloadTransportStutter,
    }

  run dynamicSigmaPayloadLayoutPinnedTest = all {
    assert(DynamicSigmaBftPayloadLayoutPinned),
    assert(DynamicSigmaBftPayloadMagicHex == "434c445349473031"),
    assert(DynamicSigmaBftPayloadEvidenceOffset == 8),
    assert(DynamicSigmaBftPayloadBlockOffset == 131),
    assert(DynamicSigmaFixturePayloadEnvelope.payloadByteLen ==
      131 + FixtureLaterBftBlockByteLen),
  }

  run dynamicSigmaPayloadEnvelopeValidTest = all {
    assert(DynamicSigmaBftBlockFixtureShapeValid(
      DynamicSigmaFixturePayloadEnvelope
    )),
    assert(DynamicSigmaBftPayloadEnvelopeValid(
      DynamicSigmaFixturePayloadEnvelope
    )),
  }

  run acceptsDynamicSigmaPayloadThroughTransportTest = {
    DynamicSigmaBftPayloadTransportInit
      .then(GossipDynamicSigmaBftPayload(DynamicSigmaFixturePayloadEnvelope))
      .then(AcceptTransportedDynamicSigmaBftPayload(
        DynamicSigmaFixturePayloadEnvelope
      ))
      .then(all {
        assert(transportedDynamicSigmaBftPayload.contains(
          DynamicSigmaFixturePayloadEnvelope
        )),
        assert(acceptedDynamicSigmaBftPayload.contains(
          DynamicSigmaFixturePayloadEnvelope
        )),
        assert(DynamicSigmaBftPayloadTransportSafety),
        DynamicSigmaBftPayloadTransportStutter,
      })
  }

  run rawDynamicSigmaPayloadWithoutTransportViolatesSafetyTest = {
    DynamicSigmaBftPayloadTransportInit
      .then(RawAcceptDynamicSigmaBftPayloadWithoutTransport(
        DynamicSigmaFixturePayloadEnvelope
      ))
      .then(all {
        assert(not(DynamicSigmaBftPayloadTransportSafety)),
        DynamicSigmaBftPayloadTransportStutter,
      })
  }

  run wrongTopicPayloadRejectedTest = {
    DynamicSigmaBftPayloadTransportInit
      .then(GossipDynamicSigmaBftPayload(WrongTopicPayloadEnvelope))
      .fail()
  }

  run wrongKindPayloadRejectedTest = {
    DynamicSigmaBftPayloadTransportInit
      .then(GossipDynamicSigmaBftPayload(WrongKindPayloadEnvelope))
      .fail()
  }

  run wrongMagicPayloadRejectedTest = {
    DynamicSigmaBftPayloadTransportInit
      .then(GossipDynamicSigmaBftPayload(WrongMagicPayloadEnvelope))
      .fail()
  }

  run belowRequiredEvidencePayloadRejectedTest = {
    DynamicSigmaBftPayloadTransportInit
      .then(GossipDynamicSigmaBftPayload(
        BelowRequiredEvidencePayloadEnvelope
      ))
      .fail()
  }

  run trailingEvidencePayloadRejectedTest = {
    DynamicSigmaBftPayloadTransportInit
      .then(GossipDynamicSigmaBftPayload(TrailingEvidencePayloadEnvelope))
      .fail()
  }

  run wrongEvidenceBytesPayloadRejectedTest = {
    DynamicSigmaBftPayloadTransportInit
      .then(GossipDynamicSigmaBftPayload(WrongEvidenceBytesPayloadEnvelope))
      .fail()
  }

  run evidenceBytesMismatchPayloadRejectedTest = {
    DynamicSigmaBftPayloadTransportInit
      .then(GossipDynamicSigmaBftPayload(
        EvidenceBytesMismatchPayloadEnvelope
      ))
      .fail()
  }

  run headerCountMismatchPayloadRejectedTest = {
    DynamicSigmaBftPayloadTransportInit
      .then(GossipDynamicSigmaBftPayload(
        HeaderCountMismatchPayloadEnvelope
      ))
      .fail()
  }

  run selectedSigmaMismatchPayloadRejectedTest = {
    DynamicSigmaBftPayloadTransportInit
      .then(GossipDynamicSigmaBftPayload(
        SelectedSigmaMismatchPayloadEnvelope
      ))
      .fail()
  }
}

module CrosslinkDynamicSigmaBftPayloadTransportModel {
  import CrosslinkDynamicSigmaBftPayloadTransportTest.* from
    "./CrosslinkDynamicSigmaBftPayloadTransport"
}
