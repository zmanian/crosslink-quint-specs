module CrosslinkProductionFinalityProjectionContractModel {
  /*
   TLC-friendly production finality projection.

   The authenticated progress projections prove that finality waits for
   height-scoped precommit/fat-pointer evidence. The fixture transport models
   prove that a checked-in production fat-pointer wire can pass through a
   production-shaped gossip boundary. The BFT-block production-vector model
   pins the checked-in block byte lengths, header offsets, PoW-header backing,
   and trailing fat-pointer offset.

   This finite projection composes those pieces at the finality boundary:
   finality can advance only after the exact generated BFT-block fixture shape
   and the exact authenticated fat-pointer wire have both been observed.
   */

  import CrosslinkFixtureGossipTransport(
    Validators = Set("fixture-validator"),
    PubKeys = Set("fixture-pubkey"),
    VotingPower = Map("fixture-validator" -> 3),
    QuorumVotingPower = 3,
    MaxBftHeight = 1,
    MaxRound = 0,
    MaxSignatures = 1,
    NilBlockHash = "nil",
    AuthorizedAt = Map(1 -> Set("fixture-validator")),
    PubKeyOwner = Map("fixture-pubkey" -> "fixture-validator"),
    FatPointerSignBytes = Map(
      1 -> Map(
        0 -> Map(
          "fixture-bft-block" -> Map(
            "fixture-pubkey" -> "fixture-sign-bytes",
          ),
        ),
      ),
    ),
    SignatureVerifier = Map(
      "fixture-pubkey" -> Map(
        "fixture-sign-bytes" -> "fixture-vote-signature",
      ),
    ),
  ) as Transport from "./CrosslinkFixtureGossipTransport"

  import CrosslinkBftBlockProductionVectors(
    MaxPreviousFatPointerSignatures = 2,
    MaxHeaderCountVector = 4,
    Sigma = 3,
    DeserializerHeaderCountCap = 2048,
  ) as BftVectors from "./CrosslinkBftBlockProductionVectors"

  type ProductionBftBlockCandidate_t = {
    height: int,
    blockHash: str,
    bftBlockByteLen: int,
    blockAndFatPointerByteLen: int,
    headerCount: int,
    previousFatPointerSignatureCount: int,
    trailingFatPointerOffset: int,
    trailingFatPointerWireByteLen: int,
    header0RawPowHeight: int,
    header1RawPowHeight: int,
    header2RawPowHeight: int,
    header0RawPowMatchCount: int,
    header1RawPowMatchCount: int,
    header2RawPowMatchCount: int,
  }

  pure val NoFinalizedBlockHash = "none"

  var productionBftBlockObserved: bool
  var finalizedProductionBlock: bool
  var latestFinalizedProductionBlockHash: str
  var productionFinalityProgress: int
  var productionFiredAction: str

  pure def Candidate(
    height: int,
    blockHash: str,
    bftBlockByteLen: int,
    blockAndFatPointerByteLen: int,
    headerCount: int,
    previousFatPointerSignatureCount: int,
    trailingFatPointerOffset: int,
    trailingFatPointerWireByteLen: int,
    header0RawPowHeight: int,
    header1RawPowHeight: int,
    header2RawPowHeight: int,
    header0RawPowMatchCount: int,
    header1RawPowMatchCount: int,
    header2RawPowMatchCount: int,
  ): ProductionBftBlockCandidate_t = {
    height: height,
    blockHash: blockHash,
    bftBlockByteLen: bftBlockByteLen,
    blockAndFatPointerByteLen: blockAndFatPointerByteLen,
    headerCount: headerCount,
    previousFatPointerSignatureCount: previousFatPointerSignatureCount,
    trailingFatPointerOffset: trailingFatPointerOffset,
    trailingFatPointerWireByteLen: trailingFatPointerWireByteLen,
    header0RawPowHeight: header0RawPowHeight,
    header1RawPowHeight: header1RawPowHeight,
    header2RawPowHeight: header2RawPowHeight,
    header0RawPowMatchCount: header0RawPowMatchCount,
    header1RawPowMatchCount: header1RawPowMatchCount,
    header2RawPowMatchCount: header2RawPowMatchCount,
  }

  pure val FixtureProductionBftBlockCandidate =
    Candidate(
      Transport::FixtureBftHeight,
      Transport::FixtureBlockHash,
      BftVectors::FixtureLaterBftBlockByteLen,
      BftVectors::FixtureLaterBftBlockAndFatPointerByteLen,
      BftVectors::FixtureHeaderCount,
      BftVectors::FixtureLaterPreviousFatPointerSignatureCount,
      BftVectors::CheckedInFixtureTrailingFatPointerOffset,
      Transport::FixtureWire.byteLen,
      BftVectors::FixtureLaterHeader0RawPowHeight,
      BftVectors::FixtureLaterHeader1RawPowHeight,
      BftVectors::FixtureLaterHeader2RawPowHeight,
      BftVectors::FixtureLaterHeader0RawPowMatchCount,
      BftVectors::FixtureLaterHeader1RawPowMatchCount,
      BftVectors::FixtureLaterHeader2RawPowMatchCount,
    )

  pure val WrongBlockByteLenCandidate =
    Candidate(
      Transport::FixtureBftHeight,
      Transport::FixtureBlockHash,
      BftVectors::FixtureLaterBftBlockByteLen + 1,
      BftVectors::FixtureLaterBftBlockAndFatPointerByteLen,
      BftVectors::FixtureHeaderCount,
      BftVectors::FixtureLaterPreviousFatPointerSignatureCount,
      BftVectors::CheckedInFixtureTrailingFatPointerOffset,
      Transport::FixtureWire.byteLen,
      BftVectors::FixtureLaterHeader0RawPowHeight,
      BftVectors::FixtureLaterHeader1RawPowHeight,
      BftVectors::FixtureLaterHeader2RawPowHeight,
      BftVectors::FixtureLaterHeader0RawPowMatchCount,
      BftVectors::FixtureLaterHeader1RawPowMatchCount,
      BftVectors::FixtureLaterHeader2RawPowMatchCount,
    )

  pure val WrongHeaderCountCandidate =
    Candidate(
      Transport::FixtureBftHeight,
      Transport::FixtureBlockHash,
      BftVectors::FixtureLaterBftBlockByteLen,
      BftVectors::FixtureLaterBftBlockAndFatPointerByteLen,
      BftVectors::FixtureHeaderCount + 1,
      BftVectors::FixtureLaterPreviousFatPointerSignatureCount,
      BftVectors::CheckedInFixtureTrailingFatPointerOffset,
      Transport::FixtureWire.byteLen,
      BftVectors::FixtureLaterHeader0RawPowHeight,
      BftVectors::FixtureLaterHeader1RawPowHeight,
      BftVectors::FixtureLaterHeader2RawPowHeight,
      BftVectors::FixtureLaterHeader0RawPowMatchCount,
      BftVectors::FixtureLaterHeader1RawPowMatchCount,
      BftVectors::FixtureLaterHeader2RawPowMatchCount,
    )

  pure val WrongTrailingFatPointerOffsetCandidate =
    Candidate(
      Transport::FixtureBftHeight,
      Transport::FixtureBlockHash,
      BftVectors::FixtureLaterBftBlockByteLen,
      BftVectors::FixtureLaterBftBlockAndFatPointerByteLen,
      BftVectors::FixtureHeaderCount,
      BftVectors::FixtureLaterPreviousFatPointerSignatureCount,
      BftVectors::CheckedInFixtureTrailingFatPointerOffset + 1,
      Transport::FixtureWire.byteLen,
      BftVectors::FixtureLaterHeader0RawPowHeight,
      BftVectors::FixtureLaterHeader1RawPowHeight,
      BftVectors::FixtureLaterHeader2RawPowHeight,
      BftVectors::FixtureLaterHeader0RawPowMatchCount,
      BftVectors::FixtureLaterHeader1RawPowMatchCount,
      BftVectors::FixtureLaterHeader2RawPowMatchCount,
    )

  pure val WrongPowBackingCandidate =
    Candidate(
      Transport::FixtureBftHeight,
      Transport::FixtureBlockHash,
      BftVectors::FixtureLaterBftBlockByteLen,
      BftVectors::FixtureLaterBftBlockAndFatPointerByteLen,
      BftVectors::FixtureHeaderCount,
      BftVectors::FixtureLaterPreviousFatPointerSignatureCount,
      BftVectors::CheckedInFixtureTrailingFatPointerOffset,
      Transport::FixtureWire.byteLen,
      BftVectors::FixtureLaterHeader0RawPowHeight,
      BftVectors::FixtureLaterHeader1RawPowHeight,
      BftVectors::FixtureLaterHeader2RawPowHeight + 1,
      BftVectors::FixtureLaterHeader0RawPowMatchCount,
      BftVectors::FixtureLaterHeader1RawPowMatchCount,
      BftVectors::FixtureLaterHeader2RawPowMatchCount,
    )

  pure val ProductionBftBlockCandidateFixtures =
    Set(
      FixtureProductionBftBlockCandidate,
      WrongBlockByteLenCandidate,
      WrongHeaderCountCandidate,
      WrongTrailingFatPointerOffsetCandidate,
      WrongPowBackingCandidate,
    )

  def ProductionBftBlockFixtureConstantsCoherent: bool =
    BftVectors::Safety and
    Transport::GeneratedFixtureWireConstantsCoherent and
    BftVectors::CheckedInFixtureTrailingFatPointerOffset ==
      BftVectors::FixtureLaterBftBlockByteLen and
    BftVectors::FixtureLaterBftBlockAndFatPointerByteLen ==
      BftVectors::FixtureLaterBftBlockByteLen +
        Transport::FixtureWire.byteLen and
    Transport::FixtureTrailingFatPointerWireByteLen ==
      BftVectors::FixtureLaterBftBlockAndFatPointerByteLen -
        BftVectors::CheckedInFixtureTrailingFatPointerOffset and
    BftVectors::FixtureLaterHeader2EndOffset ==
      BftVectors::FixtureLaterBftBlockByteLen and
    BftVectors::FixtureHeaderCount == 3 and
    BftVectors::FixtureLaterPreviousFatPointerSignatureCount == 1 and
    BftVectors::FixtureTrailingFatPointerSignatureCount == 1

  pure def ProductionBftBlockCandidateValid(
    candidate: ProductionBftBlockCandidate_t,
  ): bool =
    ProductionBftBlockFixtureConstantsCoherent and
    candidate.height == Transport::FixtureBftHeight and
    candidate.blockHash == Transport::FixtureBlockHash and
    candidate.bftBlockByteLen == BftVectors::FixtureLaterBftBlockByteLen and
    candidate.blockAndFatPointerByteLen ==
      BftVectors::FixtureLaterBftBlockAndFatPointerByteLen and
    candidate.headerCount == BftVectors::FixtureHeaderCount and
    candidate.previousFatPointerSignatureCount ==
      BftVectors::FixtureLaterPreviousFatPointerSignatureCount and
    candidate.trailingFatPointerOffset ==
      BftVectors::CheckedInFixtureTrailingFatPointerOffset and
    candidate.trailingFatPointerWireByteLen == Transport::FixtureWire.byteLen and
    candidate.header0RawPowHeight ==
      BftVectors::FixtureLaterHeader0RawPowHeight and
    candidate.header1RawPowHeight ==
      BftVectors::FixtureLaterHeader1RawPowHeight and
    candidate.header2RawPowHeight ==
      BftVectors::FixtureLaterHeader2RawPowHeight and
    candidate.header0RawPowMatchCount ==
      BftVectors::FixtureLaterHeader0RawPowMatchCount and
    candidate.header1RawPowMatchCount ==
      BftVectors::FixtureLaterHeader1RawPowMatchCount and
    candidate.header2RawPowMatchCount ==
      BftVectors::FixtureLaterHeader2RawPowMatchCount

  def ProductionFatPointerWireObserved: bool =
    Transport::observedProductionFatPointerWire.contains(Transport::FixtureWire) and
    Transport::observedProductionFatPointer.contains(Transport::FixtureFatPointer)

  action KeepProductionFinalityState = all {
    productionBftBlockObserved' = productionBftBlockObserved,
    finalizedProductionBlock' = finalizedProductionBlock,
    latestFinalizedProductionBlockHash' = latestFinalizedProductionBlockHash,
    productionFinalityProgress' = productionFinalityProgress,
    productionFiredAction' = productionFiredAction,
  }

  action MarkProductionFinalityAction(actionName: str): bool = all {
    productionFinalityProgress' = productionFinalityProgress + 1,
    productionFiredAction' = actionName,
  }

  action Init = all {
    Transport::TransportPipelineInit,
    BftVectors::Init,
    productionBftBlockObserved' = false,
    finalizedProductionBlock' = false,
    latestFinalizedProductionBlockHash' = NoFinalizedBlockHash,
    productionFinalityProgress' = 0,
    productionFiredAction' = "Init",
  }

  action Unchanged = all {
    Transport::TransportPipelineStutter,
    BftVectors::Next,
    KeepProductionFinalityState,
  }

  action GossipFixturePrecommitForFinality: bool =
    all {
      not(Transport::gossipedFixturePrecommitEnvelope.contains(
        Transport::FixturePrecommitEnvelope
      )),
      Transport::GossipFixturePrecommitTransport(Transport::FixturePrecommitEnvelope),
      BftVectors::Next,
      productionBftBlockObserved' = productionBftBlockObserved,
      finalizedProductionBlock' = finalizedProductionBlock,
      latestFinalizedProductionBlockHash' = latestFinalizedProductionBlockHash,
      MarkProductionFinalityAction("GossipFixturePrecommitForFinality"),
    }

  action GossipFixtureFatPointerWireForFinality: bool =
    all {
      not(Transport::gossipedFixtureFatPointerWireEnvelope.contains(
        Transport::FixtureFatPointerWireEnvelope
      )),
      Transport::GossipFixtureFatPointerWireTransport(
        Transport::FixtureFatPointerWireEnvelope
      ),
      BftVectors::Next,
      productionBftBlockObserved' = productionBftBlockObserved,
      finalizedProductionBlock' = finalizedProductionBlock,
      latestFinalizedProductionBlockHash' = latestFinalizedProductionBlockHash,
      MarkProductionFinalityAction("GossipFixtureFatPointerWireForFinality"),
    }

  action ObserveFixtureFatPointerWireForFinality: bool =
    all {
      not(Transport::observedProductionFatPointerWire.contains(Transport::FixtureWire)),
      Transport::ObserveFixtureFatPointerWireFromTransport(
        Transport::FixtureFatPointerWireEnvelope
      ),
      BftVectors::Next,
      productionBftBlockObserved' = productionBftBlockObserved,
      finalizedProductionBlock' = finalizedProductionBlock,
      latestFinalizedProductionBlockHash' = latestFinalizedProductionBlockHash,
      MarkProductionFinalityAction("ObserveFixtureFatPointerWireForFinality"),
    }

  action ObserveProductionBftBlockCandidate(
    candidate: ProductionBftBlockCandidate_t,
  ): bool =
    all {
      not(productionBftBlockObserved),
      ProductionBftBlockCandidateValid(candidate),
      Transport::TransportPipelineStutter,
      BftVectors::Next,
      productionBftBlockObserved' = true,
      finalizedProductionBlock' = finalizedProductionBlock,
      latestFinalizedProductionBlockHash' = latestFinalizedProductionBlockHash,
      MarkProductionFinalityAction("ObserveProductionBftBlockCandidate"),
    }

  action FinalizeProductionBftBlock(
    candidate: ProductionBftBlockCandidate_t,
  ): bool =
    all {
      productionBftBlockObserved,
      not(finalizedProductionBlock),
      ProductionBftBlockCandidateValid(candidate),
      ProductionFatPointerWireObserved,
      Transport::TransportSafety,
      Transport::TransportPipelineStutter,
      BftVectors::Next,
      productionBftBlockObserved' = productionBftBlockObserved,
      finalizedProductionBlock' = true,
      latestFinalizedProductionBlockHash' = candidate.blockHash,
      MarkProductionFinalityAction("FinalizeProductionBftBlock"),
    }

  action StutterAfterProductionFinality: bool =
    Unchanged

  action Next: bool =
    any {
      GossipFixturePrecommitForFinality,
      GossipFixtureFatPointerWireForFinality,
      ObserveFixtureFatPointerWireForFinality,
      nondet candidate = oneOf(ProductionBftBlockCandidateFixtures)
      ObserveProductionBftBlockCandidate(candidate),
      nondet candidate = oneOf(ProductionBftBlockCandidateFixtures)
      FinalizeProductionBftBlock(candidate),
      StutterAfterProductionFinality,
    }

  val ProductionStateWellFormed =
    productionFinalityProgress >= 0 and
    Set(
      "Init",
      "GossipFixturePrecommitForFinality",
      "GossipFixtureFatPointerWireForFinality",
      "ObserveFixtureFatPointerWireForFinality",
      "ObserveProductionBftBlockCandidate",
      "FinalizeProductionBftBlock",
    ).contains(productionFiredAction)

  val ProductionFinalityRequiresCandidateAndWire =
    if (finalizedProductionBlock) {
      productionBftBlockObserved and
      ProductionFatPointerWireObserved and
      latestFinalizedProductionBlockHash == Transport::FixtureBlockHash and
      ProductionBftBlockCandidateValid(FixtureProductionBftBlockCandidate)
    } else {
      latestFinalizedProductionBlockHash == NoFinalizedBlockHash
    }

  val ProductionFinalityRequiresTransportedEvidence =
    if (finalizedProductionBlock) {
      Transport::gossipedFixturePrecommitEnvelope.contains(
        Transport::FixturePrecommitEnvelope
      ) and
      Transport::gossipedFixtureFatPointerWireEnvelope.contains(
        Transport::FixtureFatPointerWireEnvelope
      )
    } else {
      true
    }

  val ProductionFinalitySafety =
    Transport::TransportSafety and
    BftVectors::Safety and
    ProductionStateWellFormed and
    ProductionBftBlockFixtureConstantsCoherent and
    ProductionFinalityRequiresCandidateAndWire and
    ProductionFinalityRequiresTransportedEvidence

  run productionBftBlockCandidateConstantsAreCoherentTest = {
    Init
      .then(all {
        assert(ProductionBftBlockFixtureConstantsCoherent),
        assert(ProductionBftBlockCandidateValid(FixtureProductionBftBlockCandidate)),
        assert(not(ProductionBftBlockCandidateValid(WrongBlockByteLenCandidate))),
        assert(not(ProductionBftBlockCandidateValid(WrongHeaderCountCandidate))),
        assert(not(ProductionBftBlockCandidateValid(WrongTrailingFatPointerOffsetCandidate))),
        assert(not(ProductionBftBlockCandidateValid(WrongPowBackingCandidate))),
        assert(ProductionFinalitySafety),
        Unchanged,
      })
  }

  run productionFinalityRejectsBadBftBlockCandidateTest = {
    Init
      .then(ObserveProductionBftBlockCandidate(WrongBlockByteLenCandidate))
      .fail()
  }

  run productionFinalityRequiresBftBlockCandidateTest = {
    Init
      .then(GossipFixturePrecommitForFinality)
      .then(GossipFixtureFatPointerWireForFinality)
      .then(ObserveFixtureFatPointerWireForFinality)
      .then(FinalizeProductionBftBlock(FixtureProductionBftBlockCandidate))
      .fail()
  }

  run productionFinalityRequiresFatPointerWireTest = {
    Init
      .then(ObserveProductionBftBlockCandidate(FixtureProductionBftBlockCandidate))
      .then(FinalizeProductionBftBlock(FixtureProductionBftBlockCandidate))
      .fail()
  }

  run productionFinalityRequiresTransportedPrecommitTest = {
    Init
      .then(GossipFixtureFatPointerWireForFinality)
      .then(ObserveProductionBftBlockCandidate(FixtureProductionBftBlockCandidate))
      .then(ObserveFixtureFatPointerWireForFinality)
      .fail()
  }

  run productionFinalityCompletesFromFixtureTransportAndBftBlockTest = {
    Init
      .then(ObserveProductionBftBlockCandidate(FixtureProductionBftBlockCandidate))
      .then(GossipFixturePrecommitForFinality)
      .then(GossipFixtureFatPointerWireForFinality)
      .then(ObserveFixtureFatPointerWireForFinality)
      .then(FinalizeProductionBftBlock(FixtureProductionBftBlockCandidate))
      .then(all {
        assert(finalizedProductionBlock),
        assert(latestFinalizedProductionBlockHash == Transport::FixtureBlockHash),
        assert(productionBftBlockObserved),
        assert(ProductionFatPointerWireObserved),
        assert(ProductionFinalitySafety),
        Unchanged,
      })
  }
}

module CrosslinkProductionFinalityTemporalProjectionModel {
  /*
   Scalar TLC temporal projection for the same production-finality gates.

   TLC currently trips over the alias-composed authenticated transport actions
   in CrosslinkProductionFinalityProjectionContractModel. This module keeps the
   same finite obligations as scalar gates: a generated production BFT-block
   fixture, a transported precommit envelope, a transported fat-pointer wire
   envelope, and an observed fat-pointer wire must all precede finality.
   */

  import CrosslinkProductionFixtureVectorsGenerated.* from
    "./CrosslinkProductionFixtureVectorsGenerated"

  pure val FixtureBftHeight = 1
  pure val FixtureBlockHash = "fixture-bft-block"
  pure val NoFinalizedBlockHash = "none"
  pure val FixtureTrailingFatPointerWireByteLen =
    FixtureLaterBftBlockAndFatPointerByteLen -
    CheckedInFixtureTrailingFatPointerOffset

  var productionBftBlockObserved: bool
  var precommitEnvelopeTransported: bool
  var fatPointerWireEnvelopeTransported: bool
  var fatPointerWireObserved: bool
  var finalizedProductionBlock: bool
  var latestFinalizedProductionBlockHash: str
  var progress: int
  var firedAction: str

  def ProductionFixtureConstantsCoherent: bool =
    GeneratedFixtureCount == 7 and
    GeneratedPowBlockFixtureCount == 24 and
    FixtureBftHeight == 1 and
    FixtureHeaderLogicalVersion == 4 and
    FixtureHeaderCount == 3 and
    FixtureLaterPreviousFatPointerSignatureCount == 1 and
    FixtureTrailingFatPointerSignatureCount == 1 and
    FixtureLaterBftBlockByteLen == 4619 and
    FixtureLaterBftBlockAndFatPointerByteLen == 4761 and
    CheckedInFixtureTrailingFatPointerOffset == FixtureLaterBftBlockByteLen and
    FixtureTrailingFatPointerWireByteLen == 142 and
    FixtureLaterBftBlockAndFatPointerByteLen ==
      FixtureLaterBftBlockByteLen + FixtureTrailingFatPointerWireByteLen and
    FixtureLaterHeader0StartOffset == 158 and
    FixtureLaterHeader1StartOffset == 1645 and
    FixtureLaterHeader2StartOffset == 3132 and
    FixtureLaterHeader2EndOffset == FixtureLaterBftBlockByteLen and
    FixtureLaterHeader0RawPowHeight == 4 and
    FixtureLaterHeader1RawPowHeight == 5 and
    FixtureLaterHeader2RawPowHeight == 7 and
    FixtureLaterHeader0RawPowMatchCount == 1 and
    FixtureLaterHeader1RawPowMatchCount == 2 and
    FixtureLaterHeader2RawPowMatchCount == 1 and
    CheckedInFixtureSignatureCount == 1 and
    CheckedInFixtureTrailingSignatureCountByte0 == 1 and
    CheckedInFixtureTrailingSignatureCountByte1 == 0 and
    CheckedInFixtureTrailingPayloadFirstByte == 253 and
    CheckedInFixtureTrailingPayloadLastByte == 128 and
    CheckedInFixtureSignerPubKeyFirstByte == 240 and
    CheckedInFixtureTrailingSignatureFirstByte == 60 and
    CheckedInFixtureTrailingSignatureLastByte == 15

  def ProductionFatPointerWireEvidenceObserved: bool =
    precommitEnvelopeTransported and
    fatPointerWireEnvelopeTransported and
    fatPointerWireObserved

  action Init = all {
    productionBftBlockObserved' = false,
    precommitEnvelopeTransported' = false,
    fatPointerWireEnvelopeTransported' = false,
    fatPointerWireObserved' = false,
    finalizedProductionBlock' = false,
    latestFinalizedProductionBlockHash' = NoFinalizedBlockHash,
    progress' = 0,
    firedAction' = "Init",
  }

  action Unchanged = all {
    productionBftBlockObserved' = productionBftBlockObserved,
    precommitEnvelopeTransported' = precommitEnvelopeTransported,
    fatPointerWireEnvelopeTransported' = fatPointerWireEnvelopeTransported,
    fatPointerWireObserved' = fatPointerWireObserved,
    finalizedProductionBlock' = finalizedProductionBlock,
    latestFinalizedProductionBlockHash' = latestFinalizedProductionBlockHash,
    progress' = progress,
    firedAction' = firedAction,
  }

  action ObserveProductionBftBlockCandidate: bool =
    all {
      ProductionFixtureConstantsCoherent,
      not(productionBftBlockObserved),
      productionBftBlockObserved' = true,
      precommitEnvelopeTransported' = precommitEnvelopeTransported,
      fatPointerWireEnvelopeTransported' = fatPointerWireEnvelopeTransported,
      fatPointerWireObserved' = fatPointerWireObserved,
      finalizedProductionBlock' = finalizedProductionBlock,
      latestFinalizedProductionBlockHash' = latestFinalizedProductionBlockHash,
      progress' = progress + 1,
      firedAction' = "ObserveProductionBftBlockCandidate",
    }

  action TransportPrecommitEnvelope: bool =
    all {
      not(precommitEnvelopeTransported),
      productionBftBlockObserved' = productionBftBlockObserved,
      precommitEnvelopeTransported' = true,
      fatPointerWireEnvelopeTransported' = fatPointerWireEnvelopeTransported,
      fatPointerWireObserved' = fatPointerWireObserved,
      finalizedProductionBlock' = finalizedProductionBlock,
      latestFinalizedProductionBlockHash' = latestFinalizedProductionBlockHash,
      progress' = progress + 1,
      firedAction' = "TransportPrecommitEnvelope",
    }

  action TransportFatPointerWireEnvelope: bool =
    all {
      not(fatPointerWireEnvelopeTransported),
      productionBftBlockObserved' = productionBftBlockObserved,
      precommitEnvelopeTransported' = precommitEnvelopeTransported,
      fatPointerWireEnvelopeTransported' = true,
      fatPointerWireObserved' = fatPointerWireObserved,
      finalizedProductionBlock' = finalizedProductionBlock,
      latestFinalizedProductionBlockHash' = latestFinalizedProductionBlockHash,
      progress' = progress + 1,
      firedAction' = "TransportFatPointerWireEnvelope",
    }

  action ObserveFatPointerWire: bool =
    all {
      precommitEnvelopeTransported,
      fatPointerWireEnvelopeTransported,
      not(fatPointerWireObserved),
      productionBftBlockObserved' = productionBftBlockObserved,
      precommitEnvelopeTransported' = precommitEnvelopeTransported,
      fatPointerWireEnvelopeTransported' = fatPointerWireEnvelopeTransported,
      fatPointerWireObserved' = true,
      finalizedProductionBlock' = finalizedProductionBlock,
      latestFinalizedProductionBlockHash' = latestFinalizedProductionBlockHash,
      progress' = progress + 1,
      firedAction' = "ObserveFatPointerWire",
    }

  action FinalizeProductionBftBlock: bool =
    all {
      productionBftBlockObserved,
      ProductionFatPointerWireEvidenceObserved,
      not(finalizedProductionBlock),
      productionBftBlockObserved' = productionBftBlockObserved,
      precommitEnvelopeTransported' = precommitEnvelopeTransported,
      fatPointerWireEnvelopeTransported' = fatPointerWireEnvelopeTransported,
      fatPointerWireObserved' = fatPointerWireObserved,
      finalizedProductionBlock' = true,
      latestFinalizedProductionBlockHash' = FixtureBlockHash,
      progress' = progress + 1,
      firedAction' = "FinalizeProductionBftBlock",
    }

  action Next: bool =
    any {
      ObserveProductionBftBlockCandidate,
      TransportPrecommitEnvelope,
      TransportFatPointerWireEnvelope,
      ObserveFatPointerWire,
      FinalizeProductionBftBlock,
      Unchanged,
    }

  val StateWellFormed =
    progress >= 0 and
    Set(
      "Init",
      "ObserveProductionBftBlockCandidate",
      "TransportPrecommitEnvelope",
      "TransportFatPointerWireEnvelope",
      "ObserveFatPointerWire",
      "FinalizeProductionBftBlock",
    ).contains(firedAction)

  val FinalityRequiresProductionInputs =
    if (finalizedProductionBlock) {
      productionBftBlockObserved and
      ProductionFatPointerWireEvidenceObserved and
      latestFinalizedProductionBlockHash == FixtureBlockHash
    } else {
      latestFinalizedProductionBlockHash == NoFinalizedBlockHash
    }

  val Safety =
    ProductionFixtureConstantsCoherent and
    StateWellFormed and
    FinalityRequiresProductionInputs

  temporal EventuallyProductionFixtureFinalized =
    Next.weakFair(Set(progress)).implies(eventually(
      finalizedProductionBlock and
      latestFinalizedProductionBlockHash == FixtureBlockHash and
      productionBftBlockObserved and
      ProductionFatPointerWireEvidenceObserved
    ))

  run temporalProjectionCompletesProductionFinalityTest = {
    Init
      .then(ObserveProductionBftBlockCandidate)
      .then(TransportPrecommitEnvelope)
      .then(TransportFatPointerWireEnvelope)
      .then(ObserveFatPointerWire)
      .then(FinalizeProductionBftBlock)
      .then(all {
        assert(finalizedProductionBlock),
        assert(latestFinalizedProductionBlockHash == FixtureBlockHash),
        assert(Safety),
        Unchanged,
      })
  }
}
