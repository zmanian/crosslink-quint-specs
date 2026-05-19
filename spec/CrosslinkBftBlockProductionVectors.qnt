module CrosslinkBftBlockProductionVectors {
  /*
   Production BFT-block byte-vector layout.

   This pins the field-order and small offset vectors implemented by
   zebra-crosslink/src/chain.rs::BftBlock::{zcash_serialize, zcash_deserialize}.
   The block prefix is:
   - u32 version,
   - u32 BFT height,
   - FatPointerToBftBlock2,
   - u32 finalization_candidate_height,
   - u32 header_count,
   - then header_count serialized PoW headers.

   The deserializer currently accepts any header_count up to 2048 and builds a
   BftBlock directly. It does not delegate through BftBlock::try_from, so this
   model records the current sigma-bypass gap separately from the intended
   constructor rule.
   */

  const MaxPreviousFatPointerSignatures: int
  const MaxHeaderCountVector: int
  const Sigma: int
  const DeserializerHeaderCountCap: int

  pure val U32ByteLen = 4
  pure val FatPointerVotePayloadByteLen = 44
  pure val FatPointerCountByteLen = 2
  pure val FatPointerSignatureEntryByteLen = 96

  pure val HeaderInputByteLen = 4 + 32 * 3 + 4 * 2
  pure val HeaderNonceByteLen = 32
  pure val CommonSolutionByteLen = 1344
  pure val CompactCommonSolutionLenByteLen = 3
  pure val HeaderWithoutCrosslinkFatPointerByteLen =
    HeaderInputByteLen +
    HeaderNonceByteLen +
    CompactCommonSolutionLenByteLen +
    CommonSolutionByteLen
  pure val FixtureHeaderLogicalVersion = 4
  pure val FixturePreviousFatPointerSignatureCount = 1
  pure val FixtureTrailingFatPointerSignatureCount = 1
  pure val FixtureHeaderCount = 3
  pure val FixtureBftBlockByteLen = 4619
  pure val FixtureBftBlockAndFatPointerByteLen = 4761

  pure val VersionOffset = 0
  pure val BftHeightOffset = VersionOffset + U32ByteLen
  pure val PreviousFatPointerOffset = BftHeightOffset + U32ByteLen

  pure val PreviousFatPointerSignatureCounts = 0.to(MaxPreviousFatPointerSignatures)
  pure val HeaderCounts = 0.to(MaxHeaderCountVector)

  assume signature_vector_domain_is_nonempty =
    MaxPreviousFatPointerSignatures >= 2
  assume header_count_vector_covers_sigma =
    MaxHeaderCountVector >= Sigma + 1
  assume sigma_is_positive =
    Sigma >= 1
  assume deserializer_cap_matches_current_code =
    DeserializerHeaderCountCap == 2048
  assume deserializer_cap_covers_examples =
    DeserializerHeaderCountCap >= MaxHeaderCountVector

  pure def PreviousFatPointerByteLen(signatureCount: int): int =
    FatPointerVotePayloadByteLen +
    FatPointerCountByteLen +
    signatureCount * FatPointerSignatureEntryByteLen

  pure def FinalizationCandidateHeightOffset(signatureCount: int): int =
    PreviousFatPointerOffset + PreviousFatPointerByteLen(signatureCount)

  pure def HeaderCountOffset(signatureCount: int): int =
    FinalizationCandidateHeightOffset(signatureCount) + U32ByteLen

  pure def HeadersStartOffset(signatureCount: int): int =
    HeaderCountOffset(signatureCount) + U32ByteLen

  pure def CrosslinkHeaderWireByteLen(headerFatPointerSignatureCount: int): int =
    HeaderWithoutCrosslinkFatPointerByteLen +
    PreviousFatPointerByteLen(headerFatPointerSignatureCount)

  pure def HeaderWireByteLen(
    logicalVersion: int,
    headerFatPointerSignatureCount: int,
  ): int =
    if (logicalVersion >= 5) {
      CrosslinkHeaderWireByteLen(headerFatPointerSignatureCount)
    } else {
      HeaderWithoutCrosslinkFatPointerByteLen
    }

  pure def BftBlockWireByteLen(
    previousFatPointerSignatureCount: int,
    headerCount: int,
    headerFatPointerSignatureCount: int,
  ): int =
    HeadersStartOffset(previousFatPointerSignatureCount) +
    headerCount * CrosslinkHeaderWireByteLen(headerFatPointerSignatureCount)

  pure def BftBlockWireByteLenForHeaderVersion(
    previousFatPointerSignatureCount: int,
    headerCount: int,
    headerFatPointerSignatureCount: int,
    logicalVersion: int,
  ): int =
    HeadersStartOffset(previousFatPointerSignatureCount) +
    headerCount *
      HeaderWireByteLen(logicalVersion, headerFatPointerSignatureCount)

  pure def BftBlockAndFatPointerWireByteLenForHeaderVersion(
    previousFatPointerSignatureCount: int,
    headerCount: int,
    headerFatPointerSignatureCount: int,
    logicalVersion: int,
    trailingFatPointerSignatureCount: int,
  ): int =
    BftBlockWireByteLenForHeaderVersion(
      previousFatPointerSignatureCount,
      headerCount,
      headerFatPointerSignatureCount,
      logicalVersion,
    ) +
    PreviousFatPointerByteLen(trailingFatPointerSignatureCount)

  pure def HeaderStartOffset(
    previousFatPointerSignatureCount: int,
    headerFatPointerSignatureCount: int,
    headerIndex: int,
  ): int =
    HeadersStartOffset(previousFatPointerSignatureCount) +
    headerIndex * CrosslinkHeaderWireByteLen(headerFatPointerSignatureCount)

  pure def HeaderEndOffset(
    previousFatPointerSignatureCount: int,
    headerFatPointerSignatureCount: int,
    headerIndex: int,
  ): int =
    HeaderStartOffset(
      previousFatPointerSignatureCount,
      headerFatPointerSignatureCount,
      headerIndex,
    ) +
    CrosslinkHeaderWireByteLen(headerFatPointerSignatureCount)

  pure def HeaderStartOffsetForHeaderVersion(
    previousFatPointerSignatureCount: int,
    headerFatPointerSignatureCount: int,
    logicalVersion: int,
    headerIndex: int,
  ): int =
    HeadersStartOffset(previousFatPointerSignatureCount) +
    headerIndex *
      HeaderWireByteLen(logicalVersion, headerFatPointerSignatureCount)

  pure def HeaderEndOffsetForHeaderVersion(
    previousFatPointerSignatureCount: int,
    headerFatPointerSignatureCount: int,
    logicalVersion: int,
    headerIndex: int,
  ): int =
    HeaderStartOffsetForHeaderVersion(
      previousFatPointerSignatureCount,
      headerFatPointerSignatureCount,
      logicalVersion,
      headerIndex,
    ) +
    HeaderWireByteLen(logicalVersion, headerFatPointerSignatureCount)

  def SerializerHeaderCountMatchesVector(headerCount: int): bool =
    HeaderCounts.contains(headerCount)

  def DeserializerEnvelopeAccepts(headerCount: int): bool =
    headerCount <= DeserializerHeaderCountCap

  def TryFromWouldAcceptHeaderCount(headerCount: int): bool =
    headerCount == Sigma

  def DeserializationBypassesTryFromSigma(headerCount: int): bool =
    DeserializerEnvelopeAccepts(headerCount) and
    not(TryFromWouldAcceptHeaderCount(headerCount))

  val FixedPrefixOffsetsMatchCode =
    VersionOffset == 0 and
    BftHeightOffset == 4 and
    PreviousFatPointerOffset == 8 and
    FatPointerVotePayloadByteLen == 44 and
    FatPointerCountByteLen == 2 and
    FatPointerSignatureEntryByteLen == 96

  val PreviousFatPointerVectorsPinned =
    PreviousFatPointerSignatureCounts.forall(n =>
      PreviousFatPointerByteLen(n) == 46 + n * 96 and
      FinalizationCandidateHeightOffset(n) == 54 + n * 96 and
      HeaderCountOffset(n) == 58 + n * 96 and
      HeadersStartOffset(n) == 62 + n * 96
    )

  val CommonCrosslinkHeaderVectorsPinned =
    PreviousFatPointerSignatureCounts.forall(n =>
      CrosslinkHeaderWireByteLen(n) == 1533 + n * 96
    )

  val HeaderVersionVectorsPinned =
    HeaderWireByteLen(4, 0) == 1487 and
    HeaderWireByteLen(4, 1) == 1487 and
    HeaderWireByteLen(5, 0) == 1533 and
    HeaderWireByteLen(5, 1) == 1629

  val HeaderVectorsAreContiguous =
    PreviousFatPointerSignatureCounts.forall(previousSigCount =>
      PreviousFatPointerSignatureCounts.forall(headerSigCount =>
        0.to(MaxHeaderCountVector - 1).forall(i =>
          HeaderEndOffset(previousSigCount, headerSigCount, i) ==
            HeaderStartOffset(previousSigCount, headerSigCount, i + 1)
        )
      )
    )

  val DeserializerCountCapMatchesImplementation =
    DeserializerHeaderCountCap == 2048

  val DeserializationSigmaBypassGapRecorded =
    DeserializationBypassesTryFromSigma(0) and
    DeserializationBypassesTryFromSigma(Sigma + 1)

  val CheckedInFixtureEnvelopePinned =
    BftBlockWireByteLenForHeaderVersion(
      FixturePreviousFatPointerSignatureCount,
      FixtureHeaderCount,
      0,
      FixtureHeaderLogicalVersion,
    ) == FixtureBftBlockByteLen and
    BftBlockAndFatPointerWireByteLenForHeaderVersion(
      FixturePreviousFatPointerSignatureCount,
      FixtureHeaderCount,
      0,
      FixtureHeaderLogicalVersion,
      FixtureTrailingFatPointerSignatureCount,
    ) == FixtureBftBlockAndFatPointerByteLen and
    HeaderStartOffsetForHeaderVersion(
      FixturePreviousFatPointerSignatureCount,
      0,
      FixtureHeaderLogicalVersion,
      0,
    ) == 158 and
    HeaderStartOffsetForHeaderVersion(
      FixturePreviousFatPointerSignatureCount,
      0,
      FixtureHeaderLogicalVersion,
      1,
    ) == 1645 and
    HeaderStartOffsetForHeaderVersion(
      FixturePreviousFatPointerSignatureCount,
      0,
      FixtureHeaderLogicalVersion,
      2,
    ) == 3132 and
    HeaderEndOffsetForHeaderVersion(
      FixturePreviousFatPointerSignatureCount,
      0,
      FixtureHeaderLogicalVersion,
      2,
    ) == FixtureBftBlockByteLen

  val Safety =
    FixedPrefixOffsetsMatchCode and
    PreviousFatPointerVectorsPinned and
    CommonCrosslinkHeaderVectorsPinned and
    HeaderVersionVectorsPinned and
    HeaderVectorsAreContiguous and
    DeserializerCountCapMatchesImplementation and
    DeserializationSigmaBypassGapRecorded and
    CheckedInFixtureEnvelopePinned

  var checked: bool

  action Init = all {
    checked' = false,
  }

  action Next = all {
    checked' = checked,
  }
}

module CrosslinkBftBlockProductionVectorsTest {
  import CrosslinkBftBlockProductionVectors.* from "./CrosslinkBftBlockProductionVectors"
  export CrosslinkBftBlockProductionVectors.*

  action unchangedAll = all {
    checked' = checked,
  }

  run bftBlockPrefixOffsetsForNullPreviousFatPointerTest = {
    Init
      .then(all {
        assert(PreviousFatPointerByteLen(0) == 46),
        assert(FinalizationCandidateHeightOffset(0) == 54),
        assert(HeaderCountOffset(0) == 58),
        assert(HeadersStartOffset(0) == 62),
        unchangedAll,
      })
  }

  run bftBlockPrefixOffsetsForOnePreviousSignatureTest = {
    Init
      .then(all {
        assert(PreviousFatPointerByteLen(1) == 142),
        assert(FinalizationCandidateHeightOffset(1) == 150),
        assert(HeaderCountOffset(1) == 154),
        assert(HeadersStartOffset(1) == 158),
        unchangedAll,
      })
  }

  run crosslinkHeaderLengthsForFatPointerSignatureCountsTest = {
    Init
      .then(all {
        assert(HeaderWithoutCrosslinkFatPointerByteLen == 1487),
        assert(HeaderWireByteLen(4, 0) == 1487),
        assert(CrosslinkHeaderWireByteLen(0) == 1533),
        assert(CrosslinkHeaderWireByteLen(1) == 1629),
        assert(CrosslinkHeaderWireByteLen(2) == 1725),
        unchangedAll,
      })
  }

  run bftBlockWireLengthVectorsTest = {
    Init
      .then(all {
        assert(BftBlockWireByteLen(0, 3, 0) == 4661),
        assert(BftBlockWireByteLen(1, 3, 0) == 4757),
        assert(BftBlockWireByteLen(0, 3, 1) == 4949),
        unchangedAll,
      })
  }

  run headerEntriesAreContiguousTest = {
    Init
      .then(all {
        assert(HeaderStartOffset(0, 0, 0) == 62),
        assert(HeaderEndOffset(0, 0, 0) == 1595),
        assert(HeaderStartOffset(0, 0, 1) == 1595),
        assert(HeaderStartOffset(0, 1, 1) == 1691),
        unchangedAll,
      })
  }

  run checkedInBftBlockAndFatPointerFixtureEnvelopeTest = {
    Init
      .then(all {
        assert(BftBlockWireByteLenForHeaderVersion(1, 3, 0, 4) == 4619),
        assert(BftBlockAndFatPointerWireByteLenForHeaderVersion(
          1,
          3,
          0,
          4,
          1,
        ) == 4761),
        assert(HeaderStartOffsetForHeaderVersion(1, 0, 4, 0) == 158),
        assert(HeaderStartOffsetForHeaderVersion(1, 0, 4, 1) == 1645),
        assert(HeaderStartOffsetForHeaderVersion(1, 0, 4, 2) == 3132),
        assert(HeaderEndOffsetForHeaderVersion(1, 0, 4, 2) == 4619),
        unchangedAll,
      })
  }

  run deserializationBypassesTryFromSigmaGapRecordedTest = {
    Init
      .then(all {
        assert(DeserializerEnvelopeAccepts(0)),
        assert(not(TryFromWouldAcceptHeaderCount(0))),
        assert(DeserializationBypassesTryFromSigma(0)),
        assert(DeserializerEnvelopeAccepts(4)),
        assert(not(TryFromWouldAcceptHeaderCount(4))),
        assert(DeserializationBypassesTryFromSigma(4)),
        assert(DeserializerCountCapMatchesImplementation),
        unchangedAll,
      })
  }

  run bftBlockProductionVectorSafetyTest = {
    Init
      .then(all {
        assert(Safety),
        unchangedAll,
      })
  }
}

module CrosslinkBftBlockProductionVectorsModel {
  import CrosslinkBftBlockProductionVectorsTest(
    MaxPreviousFatPointerSignatures = 2,
    MaxHeaderCountVector = 4,
    Sigma = 3,
    DeserializerHeaderCountCap = 2048,
  ).*
}
