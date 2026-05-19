module CrosslinkFatPointerProductionVectors {
  /*
   Production fat-pointer byte vectors and implementation correspondence.

   This model pins the small byte-level constants that appear in the current
   Zebra Crosslink and Tenderlink prototype:
   - 44 bytes of vote payload after removing the finalizer public key,
   - a little-endian u16 signature count at bytes 44..46,
   - then one 96-byte public-key/signature entry per signer.

   It also records a current implementation gap: the helper `try_from_bytes`
   in the prototype reads the count with a reversed range (`bytes[44..2]`).
   The streaming `ZcashSerialize`/`ZcashDeserialize` path uses the intended
   count position, so the protocol-shaped vector remains bytes 44..46.
   */

  const MaxVectorSignatures: int

  pure val VotePayloadWithoutSignerByteLen = 44
  pure val SignatureCountByteLen = 2
  pure val PubKeyByteLen = 32
  pure val VoteSignatureByteLen = 64
  pure val SignatureEntryByteLen = PubKeyByteLen + VoteSignatureByteLen

  pure val VotePayloadOffset = 0
  pure val SignatureCountOffset = VotePayloadWithoutSignerByteLen
  pure val SignatureEntriesOffset = SignatureCountOffset + SignatureCountByteLen
  pure val MinFatPointerWireByteLen = SignatureEntriesOffset

  pure val SerializerCountStart = SignatureCountOffset
  pure val SerializerCountEndExclusive = SignatureEntriesOffset
  pure val StreamingDeserializerCountStart = SignatureCountOffset
  pure val StreamingDeserializerCountEndExclusive = SignatureEntriesOffset

  pure val PrototypeTryFromBytesCountStart = VotePayloadWithoutSignerByteLen
  pure val PrototypeTryFromBytesCountEndExclusive = SignatureCountByteLen

  pure val SignatureCounts = 0.to(MaxVectorSignatures)

  assume max_vector_signatures_covers_current_examples =
    MaxVectorSignatures >= 4

  pure def SliceRangeWellFormed(start: int, endExclusive: int): bool =
    start <= endExclusive

  pure def SliceWidth(start: int, endExclusive: int): int =
    endExclusive - start

  pure def SliceReadsExactlyU16(start: int, endExclusive: int): bool =
    SliceRangeWellFormed(start, endExclusive) and
    SliceWidth(start, endExclusive) == SignatureCountByteLen

  pure def SignatureEntryOffset(i: int): int =
    SignatureEntriesOffset + i * SignatureEntryByteLen

  pure def SignatureEntryPubKeyOffset(i: int): int =
    SignatureEntryOffset(i)

  pure def SignatureEntryVoteSignatureOffset(i: int): int =
    SignatureEntryOffset(i) + PubKeyByteLen

  pure def SignatureEntryEndOffset(i: int): int =
    SignatureEntryOffset(i) + SignatureEntryByteLen

  pure def FatPointerWireByteLen(signatureCount: int): int =
    VotePayloadWithoutSignerByteLen +
    SignatureCountByteLen +
    signatureCount * SignatureEntryByteLen

  pure def CountedWireEnvelopeExact(signatureCount: int, byteLen: int): bool =
    SignatureCounts.contains(signatureCount) and
    byteLen == FatPointerWireByteLen(signatureCount)

  val ProductionLayoutConstantsMatchCode =
    VotePayloadOffset == 0 and
    VotePayloadWithoutSignerByteLen == 44 and
    SignatureCountByteLen == 2 and
    SignatureCountOffset == 44 and
    SignatureEntriesOffset == 46 and
    PubKeyByteLen == 32 and
    VoteSignatureByteLen == 64 and
    SignatureEntryByteLen == 96

  val SerializerCountSliceIsBytes44To46 =
    SerializerCountStart == 44 and
    SerializerCountEndExclusive == 46 and
    SliceReadsExactlyU16(SerializerCountStart, SerializerCountEndExclusive)

  val StreamingDeserializerMatchesSerializer =
    StreamingDeserializerCountStart == SerializerCountStart and
    StreamingDeserializerCountEndExclusive == SerializerCountEndExclusive and
    SliceReadsExactlyU16(
      StreamingDeserializerCountStart,
      StreamingDeserializerCountEndExclusive
    )

  val PrototypeTryFromBytesGapRecorded =
    PrototypeTryFromBytesCountStart == 44 and
    PrototypeTryFromBytesCountEndExclusive == 2 and
    not(SliceRangeWellFormed(
      PrototypeTryFromBytesCountStart,
      PrototypeTryFromBytesCountEndExclusive
    ))

  val ProductionWireLengthVectorPinned =
    SignatureCounts.forall(n =>
      CountedWireEnvelopeExact(n, 46 + n * 96)
    )

  val SignatureEntryOffsetsAreContiguous =
    0.to(MaxVectorSignatures - 1).forall(i =>
      SignatureEntryPubKeyOffset(i) == SignatureEntryOffset(i) and
      SignatureEntryVoteSignatureOffset(i) == SignatureEntryOffset(i) + 32 and
      SignatureEntryEndOffset(i) == SignatureEntryOffset(i) + 96 and
      SignatureEntryEndOffset(i) == SignatureEntryOffset(i + 1)
    )

  val Safety =
    ProductionLayoutConstantsMatchCode and
    SerializerCountSliceIsBytes44To46 and
    StreamingDeserializerMatchesSerializer and
    PrototypeTryFromBytesGapRecorded and
    ProductionWireLengthVectorPinned and
    SignatureEntryOffsetsAreContiguous

  var checked: bool

  action Init = all {
    checked' = false,
  }

  action Next = all {
    checked' = checked,
  }
}

module CrosslinkFatPointerProductionVectorsTest {
  import CrosslinkFatPointerProductionVectors.* from "./CrosslinkFatPointerProductionVectors"
  export CrosslinkFatPointerProductionVectors.*

  action unchangedAll = all {
    checked' = checked,
  }

  run productionWireLengthsForZeroThroughFourSignaturesTest = {
    Init
      .then(all {
        assert(FatPointerWireByteLen(0) == 46),
        assert(FatPointerWireByteLen(1) == 142),
        assert(FatPointerWireByteLen(2) == 238),
        assert(FatPointerWireByteLen(3) == 334),
        assert(FatPointerWireByteLen(4) == 430),
        unchangedAll,
      })
  }

  run signatureEntryOffsetsArePinnedTest = {
    Init
      .then(all {
        assert(SignatureEntryOffset(0) == 46),
        assert(SignatureEntryPubKeyOffset(0) == 46),
        assert(SignatureEntryVoteSignatureOffset(0) == 78),
        assert(SignatureEntryEndOffset(0) == 142),
        assert(SignatureEntryOffset(1) == 142),
        unchangedAll,
      })
  }

  run streamingSerializerDeserializerCountSliceMatchesTest = {
    Init
      .then(all {
        assert(SerializerCountSliceIsBytes44To46),
        assert(StreamingDeserializerMatchesSerializer),
        unchangedAll,
      })
  }

  run prototypeTryFromBytesCountSliceGapRecordedTest = {
    Init
      .then(all {
        assert(PrototypeTryFromBytesGapRecorded),
        assert(not(SliceReadsExactlyU16(
          PrototypeTryFromBytesCountStart,
          PrototypeTryFromBytesCountEndExclusive
        ))),
        unchangedAll,
      })
  }

  run productionVectorSafetyTest = {
    Init
      .then(all {
        assert(Safety),
        unchangedAll,
      })
  }
}

module CrosslinkFatPointerProductionVectorsModel {
  import CrosslinkFatPointerProductionVectorsTest(
    MaxVectorSignatures = 4,
  ).*
}
