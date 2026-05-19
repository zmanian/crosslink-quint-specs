module CrosslinkBftBlockProductionVectors {
  /*
   Production BFT-block byte-vector layout.

   This pins the field-order and small offset vectors implemented by
   zebra-crosslink/src/chain.rs::BftBlock::{zcash_serialize, zcash_deserialize}.
   The checked-in fixture constants are generated into
   fixtures/production-bft-block-vectors.json from zebra-crosslink's
   crosslink-test-data/test_pos_block_*.bin and test_pow_block_*.bin files.
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

  import CrosslinkProductionFixtureVectorsGenerated.* from "./CrosslinkProductionFixtureVectorsGenerated"
  export CrosslinkProductionFixtureVectorsGenerated.*

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

  val CheckedInFixtureSequencePinned =
    GeneratedFixtureCount == 7 and
    GeneratedBftHeightMin == 1 and
    GeneratedBftHeightMax == 7 and
    GeneratedBftHeightSum == 28 and
    GeneratedBftHeightSquareSum == 140 and
    GeneratedZeroPreviousFatPointerFixtureCount == 1 and
    GeneratedOnePreviousFatPointerFixtureCount == 6 and
    GeneratedEmbeddedBftHeaderCount == GeneratedFixtureCount * FixtureHeaderCount and
    GeneratedEmbeddedBftHeaderCount == 21 and
    GeneratedEmbeddedRawPowHeaderMatchCount == 22 and
    GeneratedAllBftBlockVersionsZero and
    GeneratedAllFinalizationCandidateHeightsZero and
    GeneratedAllHeaderCountsMatchFixtureHeaderCount and
    GeneratedAllTrailingFatPointerSignatureCountsOne and
    GeneratedAllPreviousPointersLinkToPriorTrailingPointers

  val CheckedInFirstFixtureEnvelopePinned =
    FixtureFirstBftBlockVersion == 0 and
    FixtureFirstBftHeight == 1 and
    FixtureFirstFinalizationCandidateHeightOffset ==
      FinalizationCandidateHeightOffset(FixtureFirstPreviousFatPointerSignatureCount) and
    FixtureFirstFinalizationCandidateHeightOffset == 54 and
    FixtureFirstFinalizationCandidateHeight == 0 and
    FixtureFirstHeaderCountOffset ==
      HeaderCountOffset(FixtureFirstPreviousFatPointerSignatureCount) and
    FixtureFirstHeaderCountOffset == 58 and
    FixtureFirstHeadersStartOffset ==
      HeadersStartOffset(FixtureFirstPreviousFatPointerSignatureCount) and
    FixtureFirstHeadersStartOffset == FixtureFirstHeader0StartOffset and
    BftBlockWireByteLenForHeaderVersion(
      FixtureFirstPreviousFatPointerSignatureCount,
      FixtureHeaderCount,
      0,
      FixtureHeaderLogicalVersion,
    ) == FixtureFirstBftBlockByteLen and
    BftBlockAndFatPointerWireByteLenForHeaderVersion(
      FixtureFirstPreviousFatPointerSignatureCount,
      FixtureHeaderCount,
      0,
      FixtureHeaderLogicalVersion,
      FixtureTrailingFatPointerSignatureCount,
    ) == FixtureFirstBftBlockAndFatPointerByteLen and
    HeaderStartOffsetForHeaderVersion(
      FixtureFirstPreviousFatPointerSignatureCount,
      0,
      FixtureHeaderLogicalVersion,
      0,
    ) == FixtureFirstHeader0StartOffset and
    HeaderStartOffsetForHeaderVersion(
      FixtureFirstPreviousFatPointerSignatureCount,
      0,
      FixtureHeaderLogicalVersion,
      1,
    ) == FixtureFirstHeader1StartOffset and
    HeaderStartOffsetForHeaderVersion(
      FixtureFirstPreviousFatPointerSignatureCount,
      0,
      FixtureHeaderLogicalVersion,
      2,
    ) == FixtureFirstHeader2StartOffset and
    HeaderEndOffsetForHeaderVersion(
      FixtureFirstPreviousFatPointerSignatureCount,
      0,
      FixtureHeaderLogicalVersion,
      2,
    ) == FixtureFirstHeader2EndOffset

  val CheckedInLaterFixtureEnvelopePinned =
    FixtureLaterBftBlockVersion == 0 and
    FixtureLaterBftHeight == 2 and
    FixtureLaterFinalizationCandidateHeightOffset ==
      FinalizationCandidateHeightOffset(FixtureLaterPreviousFatPointerSignatureCount) and
    FixtureLaterFinalizationCandidateHeightOffset == 150 and
    FixtureLaterFinalizationCandidateHeight == 0 and
    FixtureLaterHeaderCountOffset ==
      HeaderCountOffset(FixtureLaterPreviousFatPointerSignatureCount) and
    FixtureLaterHeaderCountOffset == 154 and
    FixtureLaterHeadersStartOffset ==
      HeadersStartOffset(FixtureLaterPreviousFatPointerSignatureCount) and
    FixtureLaterHeadersStartOffset == FixtureLaterHeader0StartOffset and
    BftBlockWireByteLenForHeaderVersion(
      FixtureLaterPreviousFatPointerSignatureCount,
      FixtureHeaderCount,
      0,
      FixtureHeaderLogicalVersion,
    ) == FixtureLaterBftBlockByteLen and
    BftBlockAndFatPointerWireByteLenForHeaderVersion(
      FixtureLaterPreviousFatPointerSignatureCount,
      FixtureHeaderCount,
      0,
      FixtureHeaderLogicalVersion,
      FixtureTrailingFatPointerSignatureCount,
    ) == FixtureLaterBftBlockAndFatPointerByteLen and
    HeaderStartOffsetForHeaderVersion(
      FixtureLaterPreviousFatPointerSignatureCount,
      0,
      FixtureHeaderLogicalVersion,
      0,
    ) == FixtureLaterHeader0StartOffset and
    HeaderStartOffsetForHeaderVersion(
      FixtureLaterPreviousFatPointerSignatureCount,
      0,
      FixtureHeaderLogicalVersion,
      1,
    ) == FixtureLaterHeader1StartOffset and
    HeaderStartOffsetForHeaderVersion(
      FixtureLaterPreviousFatPointerSignatureCount,
      0,
      FixtureHeaderLogicalVersion,
      2,
    ) == FixtureLaterHeader2StartOffset and
    HeaderEndOffsetForHeaderVersion(
      FixtureLaterPreviousFatPointerSignatureCount,
      0,
      FixtureHeaderLogicalVersion,
      2,
    ) == FixtureLaterHeader2EndOffset

  val CheckedInPowBlockFixturesPinned =
    GeneratedPowBlockFixtureCount == 24 and
    FixtureFirstPowBlockHeight == 0 and
    FixtureLastPowBlockHeight == 29 and
    FixtureFirstPowBlockLogicalVersion == 4 and
    FixtureLaterPowBlockLogicalVersion == 4 and
    FixtureFirstPowBlockHeaderByteLen ==
      HeaderWireByteLen(FixtureFirstPowBlockLogicalVersion, 0) and
    FixtureLaterPowBlockHeaderByteLen ==
      HeaderWireByteLen(FixtureLaterPowBlockLogicalVersion, 0) and
    FixtureFirstPowBlockBodyByteLen ==
      FixtureFirstPowBlockByteLen - FixtureFirstPowBlockHeaderByteLen and
    FixtureLaterPowBlockBodyByteLen ==
      FixtureLaterPowBlockByteLen - FixtureLaterPowBlockHeaderByteLen and
    FixtureFirstPowBlockByteLen == 1592 and
    FixtureLaterPowBlockByteLen == 1593 and
    FixtureFirstPowBlockBodyByteLen == 105 and
    FixtureLaterPowBlockBodyByteLen == 106 and
    FixtureFirstPowBlockHeaderFirstByte == 4 and
    FixtureLaterPowBlockHeaderFirstByte == 4 and
    FixtureFirstPowBlockHeaderLastByte == 8 and
    FixtureLaterPowBlockHeaderLastByte == 190 and
    FixtureFirstPowBlockBodyFirstByte == 1 and
    FixtureLaterPowBlockBodyFirstByte == 1 and
    FixtureFirstPowBlockBodyLastByte == 0 and
    FixtureLaterPowBlockBodyLastByte == 0

  val CheckedInBftHeadersBackedByRawPowFixtures =
    FixtureFirstHeader0RawPowHeight == 1 and
    FixtureFirstHeader1RawPowHeight == 3 and
    FixtureFirstHeader2RawPowHeight == 4 and
    FixtureLaterHeader0RawPowHeight == 4 and
    FixtureLaterHeader1RawPowHeight == 5 and
    FixtureLaterHeader2RawPowHeight == 7 and
    FixtureFirstHeader0RawPowMatchCount == 1 and
    FixtureFirstHeader1RawPowMatchCount == 1 and
    FixtureFirstHeader2RawPowMatchCount == 1 and
    FixtureLaterHeader0RawPowMatchCount == 1 and
    FixtureLaterHeader1RawPowMatchCount == 2 and
    FixtureLaterHeader2RawPowMatchCount == 1

  val Safety =
    FixedPrefixOffsetsMatchCode and
    PreviousFatPointerVectorsPinned and
    CommonCrosslinkHeaderVectorsPinned and
    HeaderVersionVectorsPinned and
    HeaderVectorsAreContiguous and
    DeserializerCountCapMatchesImplementation and
    DeserializationSigmaBypassGapRecorded and
    CheckedInFixtureSequencePinned and
    CheckedInFirstFixtureEnvelopePinned and
    CheckedInLaterFixtureEnvelopePinned and
    CheckedInPowBlockFixturesPinned and
    CheckedInBftHeadersBackedByRawPowFixtures

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

  run checkedInFirstBftBlockAndFatPointerFixtureEnvelopeTest = {
    Init
      .then(all {
        assert(FixtureFirstBftBlockVersion == 0),
        assert(FixtureFirstBftHeight == 1),
        assert(FixtureFirstFinalizationCandidateHeightOffset == 54),
        assert(FixtureFirstFinalizationCandidateHeight == 0),
        assert(FixtureFirstHeaderCountOffset == 58),
        assert(FixtureFirstHeadersStartOffset == FixtureFirstHeader0StartOffset),
        assert(BftBlockWireByteLenForHeaderVersion(0, 3, 0, 4) == FixtureFirstBftBlockByteLen),
        assert(BftBlockAndFatPointerWireByteLenForHeaderVersion(
          0,
          3,
          0,
          4,
          1,
        ) == FixtureFirstBftBlockAndFatPointerByteLen),
        assert(HeaderStartOffsetForHeaderVersion(0, 0, 4, 0) == FixtureFirstHeader0StartOffset),
        assert(HeaderStartOffsetForHeaderVersion(0, 0, 4, 1) == FixtureFirstHeader1StartOffset),
        assert(HeaderStartOffsetForHeaderVersion(0, 0, 4, 2) == FixtureFirstHeader2StartOffset),
        assert(HeaderEndOffsetForHeaderVersion(0, 0, 4, 2) == FixtureFirstHeader2EndOffset),
        unchangedAll,
      })
  }

  run checkedInBftBlockFixtureSequenceTest = {
    Init
      .then(all {
        assert(GeneratedFixtureCount == 7),
        assert(GeneratedBftHeightMin == 1),
        assert(GeneratedBftHeightMax == 7),
        assert(GeneratedBftHeightSum == 28),
        assert(GeneratedBftHeightSquareSum == 140),
        assert(GeneratedZeroPreviousFatPointerFixtureCount == 1),
        assert(GeneratedOnePreviousFatPointerFixtureCount == 6),
        assert(GeneratedEmbeddedBftHeaderCount == 21),
        assert(GeneratedEmbeddedBftHeaderCount == GeneratedFixtureCount * FixtureHeaderCount),
        assert(GeneratedEmbeddedRawPowHeaderMatchCount == 22),
        assert(GeneratedAllBftBlockVersionsZero),
        assert(GeneratedAllFinalizationCandidateHeightsZero),
        assert(GeneratedAllHeaderCountsMatchFixtureHeaderCount),
        assert(GeneratedAllTrailingFatPointerSignatureCountsOne),
        assert(GeneratedAllPreviousPointersLinkToPriorTrailingPointers),
        assert(CheckedInFixtureSequencePinned),
        unchangedAll,
      })
  }

  run checkedInLaterBftBlockAndFatPointerFixtureEnvelopeTest = {
    Init
      .then(all {
        assert(FixtureLaterBftBlockVersion == 0),
        assert(FixtureLaterBftHeight == 2),
        assert(FixtureLaterFinalizationCandidateHeightOffset == 150),
        assert(FixtureLaterFinalizationCandidateHeight == 0),
        assert(FixtureLaterHeaderCountOffset == 154),
        assert(FixtureLaterHeadersStartOffset == FixtureLaterHeader0StartOffset),
        assert(BftBlockWireByteLenForHeaderVersion(1, 3, 0, 4) == FixtureLaterBftBlockByteLen),
        assert(BftBlockAndFatPointerWireByteLenForHeaderVersion(
          1,
          3,
          0,
          4,
          1,
        ) == FixtureLaterBftBlockAndFatPointerByteLen),
        assert(HeaderStartOffsetForHeaderVersion(1, 0, 4, 0) == FixtureLaterHeader0StartOffset),
        assert(HeaderStartOffsetForHeaderVersion(1, 0, 4, 1) == FixtureLaterHeader1StartOffset),
        assert(HeaderStartOffsetForHeaderVersion(1, 0, 4, 2) == FixtureLaterHeader2StartOffset),
        assert(HeaderEndOffsetForHeaderVersion(1, 0, 4, 2) == FixtureLaterHeader2EndOffset),
        unchangedAll,
      })
  }

  run checkedInPowBlockFixtureVectorsTest = {
    Init
      .then(all {
        assert(GeneratedPowBlockFixtureCount == 24),
        assert(FixtureFirstPowBlockHeight == 0),
        assert(FixtureLastPowBlockHeight == 29),
        assert(FixtureFirstPowBlockHeaderByteLen == HeaderWireByteLen(4, 0)),
        assert(FixtureLaterPowBlockHeaderByteLen == HeaderWireByteLen(4, 0)),
        assert(FixtureFirstPowBlockBodyByteLen == 105),
        assert(FixtureLaterPowBlockBodyByteLen == 106),
        assert(FixtureFirstPowBlockHeaderFirstByte == 4),
        assert(FixtureLaterPowBlockHeaderFirstByte == 4),
        assert(FixtureFirstPowBlockHeaderLastByte == 8),
        assert(FixtureLaterPowBlockHeaderLastByte == 190),
        assert(FixtureFirstPowBlockBodyFirstByte == 1),
        assert(FixtureLaterPowBlockBodyFirstByte == 1),
        assert(FixtureFirstPowBlockBodyLastByte == 0),
        assert(FixtureLaterPowBlockBodyLastByte == 0),
        assert(CheckedInPowBlockFixturesPinned),
        unchangedAll,
      })
  }

  run checkedInBftHeadersBackedByRawPowFixturesTest = {
    Init
      .then(all {
        assert(FixtureFirstHeader0RawPowHeight == 1),
        assert(FixtureFirstHeader1RawPowHeight == 3),
        assert(FixtureFirstHeader2RawPowHeight == 4),
        assert(FixtureLaterHeader0RawPowHeight == 4),
        assert(FixtureLaterHeader1RawPowHeight == 5),
        assert(FixtureLaterHeader2RawPowHeight == 7),
        assert(FixtureFirstHeader0RawPowMatchCount == 1),
        assert(FixtureFirstHeader1RawPowMatchCount == 1),
        assert(FixtureFirstHeader2RawPowMatchCount == 1),
        assert(FixtureLaterHeader0RawPowMatchCount == 1),
        assert(FixtureLaterHeader1RawPowMatchCount == 2),
        assert(FixtureLaterHeader2RawPowMatchCount == 1),
        assert(CheckedInBftHeadersBackedByRawPowFixtures),
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
