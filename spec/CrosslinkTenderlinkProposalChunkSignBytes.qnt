module CrosslinkTenderlinkProposalChunkSignBytes {
  /*
   Tenderlink proposal chunk sign-byte layout.

   This model pins the legacy Tenderlink proposal chunk bytes from
   forks/tenderlink/src/lib.rs::PacketProposalChunkHeader::write_to and the
   proposal signing path around TMMsgData::Proposal.

   The signed bytes are:
   - a 56-byte chunk header,
   - followed immediately by the proposal chunk data.

   The transport packet header and trailing 64-byte Ed25519 signature are not
   part of the signed payload. The current Malachite proposal path signs
   protobuf-encoded proposals, so it needs separate generated protobuf vectors.
   */

  type ProposalId_t = str
  type ChunkData_t = str
  type Bytes_t = str
  type Height_t = int
  type Round_t = int
  type ChunkIndex_t = int

  type ProposalChunkWire_t = {
    byteLen: int,
    chunkIndex: ChunkIndex_t,
    proposalSize: int,
    round: Round_t,
    validRound: Round_t,
    height: Height_t,
    proposalId: ProposalId_t,
    chunkDataByteLen: int,
    chunkDataHex: ChunkData_t,
    hex: Bytes_t,
  }

  pure val TestProposalIdHex =
    "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
  pure val TestChunkDataHex = "cafebabe"
  pure val NilValidRound = -1

  pure val Heights = 1.to(2)
  pure val Rounds = 0.to(2)
  pure val ChunkIndexes = 0.to(1)
  pure val ProposalIds = Set(TestProposalIdHex)
  pure val ChunkDatas = Set(TestChunkDataHex)

  pure val U32ByteLen = 4
  pure val HeightByteLen = 8
  pure val ProposalIdByteLen = 32
  pure val ProposalChunkHeaderByteLen = 4 * U32ByteLen + HeightByteLen + ProposalIdByteLen
  pure val ModelChunkDataByteLen = 4
  pure val MaxU32 = 4294967295

  pure val ChunkIndexOffset = 0
  pure val ProposalSizeOffset = ChunkIndexOffset + U32ByteLen
  pure val RoundOffset = ProposalSizeOffset + U32ByteLen
  pure val ValidRoundOffset = RoundOffset + U32ByteLen
  pure val HeightOffset = ValidRoundOffset + U32ByteLen
  pure val ProposalIdOffset = HeightOffset + HeightByteLen
  pure val ChunkDataOffset = ProposalIdOffset + ProposalIdByteLen

  pure val ProposalChunkHeaderHexCharLen = ProposalChunkHeaderByteLen * 2
  pure val ProposalChunkSignBytesHexCharLen =
    (ProposalChunkHeaderByteLen + ModelChunkDataByteLen) * 2

  pure val UnmodeledProposalChunkHeaderHex = "unmodeled-proposal-chunk-header"
  pure val UnmodeledProposalChunkSignBytesHex =
    "unmodeled-proposal-chunk-sign-bytes"

  var acceptedProposalChunks: Set[ProposalChunkWire_t]
  var firedAction: str

  pure def FieldEndOffset(offset: int, width: int): int =
    offset + width

  pure def ValidRoundWireValue(validRound: Round_t): int =
    if (validRound == NilValidRound) {
      MaxU32
    } else {
      validRound
    }

  pure def ValidRoundAllowed(round: Round_t, validRound: Round_t): bool =
    validRound == NilValidRound or
    (Rounds.contains(validRound) and validRound < round)

  pure def ChunkDataEndOffset(wire: ProposalChunkWire_t): int =
    ChunkDataOffset + wire.chunkDataByteLen

  pure def ChunkStartsAt(wire: ProposalChunkWire_t): int =
    wire.chunkIndex * ModelChunkDataByteLen

  pure def ChunkEndsAt(wire: ProposalChunkWire_t): int =
    ChunkStartsAt(wire) + wire.chunkDataByteLen

  pure def ProposalChunkLayoutConstantsPinned: bool =
    U32ByteLen == 4 and
    HeightByteLen == 8 and
    ProposalIdByteLen == 32 and
    ProposalChunkHeaderByteLen == 56 and
    ChunkIndexOffset == 0 and
    ProposalSizeOffset == 4 and
    RoundOffset == 8 and
    ValidRoundOffset == 12 and
    HeightOffset == 16 and
    ProposalIdOffset == 24 and
    ChunkDataOffset == 56 and
    ProposalChunkHeaderHexCharLen == 112 and
    ProposalChunkSignBytesHexCharLen == 120

  pure def ProposalChunkFieldOffsetsContiguous: bool =
    FieldEndOffset(ChunkIndexOffset, U32ByteLen) == ProposalSizeOffset and
    FieldEndOffset(ProposalSizeOffset, U32ByteLen) == RoundOffset and
    FieldEndOffset(RoundOffset, U32ByteLen) == ValidRoundOffset and
    FieldEndOffset(ValidRoundOffset, U32ByteLen) == HeightOffset and
    FieldEndOffset(HeightOffset, HeightByteLen) == ProposalIdOffset and
    FieldEndOffset(ProposalIdOffset, ProposalIdByteLen) == ChunkDataOffset

  pure def ProposalChunkWireFieldsValid(wire: ProposalChunkWire_t): bool =
    wire.byteLen == ProposalChunkHeaderByteLen + wire.chunkDataByteLen and
    ChunkIndexes.contains(wire.chunkIndex) and
    wire.proposalSize > 0 and
    wire.proposalSize <= 2 * ModelChunkDataByteLen and
    Rounds.contains(wire.round) and
    ValidRoundAllowed(wire.round, wire.validRound) and
    Heights.contains(wire.height) and
    ProposalIds.contains(wire.proposalId) and
    wire.chunkDataByteLen > 0 and
    wire.chunkDataByteLen <= ModelChunkDataByteLen and
    ChunkDatas.contains(wire.chunkDataHex) and
    ChunkEndsAt(wire) <= wire.proposalSize

  pure def CanonicalProposalChunkHeaderHex(wire: ProposalChunkWire_t): Bytes_t =
    if (wire.chunkIndex == 0 and wire.proposalSize == 4 and
      wire.round == 0 and wire.validRound == NilValidRound and
      wire.height == 1 and wire.proposalId == TestProposalIdHex) {
      "000000000400000000000000ffffffff0100000000000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
    } else if (wire.chunkIndex == 1 and wire.proposalSize == 8 and
      wire.round == 2 and wire.validRound == 1 and
      wire.height == 2 and wire.proposalId == TestProposalIdHex) {
      "010000000800000002000000010000000200000000000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
    } else {
      UnmodeledProposalChunkHeaderHex
    }

  pure def CanonicalProposalChunkSignBytesHex(wire: ProposalChunkWire_t): Bytes_t =
    if (wire.byteLen == 60 and wire.chunkIndex == 0 and wire.proposalSize == 4 and
      wire.round == 0 and wire.validRound == NilValidRound and
      wire.height == 1 and wire.proposalId == TestProposalIdHex and
      wire.chunkDataByteLen == 4 and wire.chunkDataHex == TestChunkDataHex) {
      "000000000400000000000000ffffffff0100000000000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbcafebabe"
    } else if (wire.byteLen == 60 and wire.chunkIndex == 1 and
      wire.proposalSize == 8 and wire.round == 2 and wire.validRound == 1 and
      wire.height == 2 and wire.proposalId == TestProposalIdHex and
      wire.chunkDataByteLen == 4 and wire.chunkDataHex == TestChunkDataHex) {
      "010000000800000002000000010000000200000000000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbcafebabe"
    } else {
      UnmodeledProposalChunkSignBytesHex
    }

  pure def ProposalChunkWireCanonical(wire: ProposalChunkWire_t): bool =
    ProposalChunkWireFieldsValid(wire) and
    CanonicalProposalChunkHeaderHex(wire) != UnmodeledProposalChunkHeaderHex and
    CanonicalProposalChunkSignBytesHex(wire) != UnmodeledProposalChunkSignBytesHex and
    wire.hex == CanonicalProposalChunkSignBytesHex(wire)

  action Init = all {
    acceptedProposalChunks' = Set(),
    firedAction' = "Init",
  }

  action AcceptProposalChunk(wire: ProposalChunkWire_t): bool =
    all {
      ProposalChunkWireCanonical(wire),
      acceptedProposalChunks' = acceptedProposalChunks.union(Set(wire)),
      firedAction' = "AcceptProposalChunk",
    }

  action Stutter: bool =
    all {
      acceptedProposalChunks' = acceptedProposalChunks,
      firedAction' = firedAction,
    }

  pure def AcceptedProposalChunksCanonical: bool =
    acceptedProposalChunks.forall(ProposalChunkWireCanonical)

  val Safety =
    ProposalChunkLayoutConstantsPinned and
    ProposalChunkFieldOffsetsContiguous and
    AcceptedProposalChunksCanonical
}

module CrosslinkTenderlinkProposalChunkSignBytesTest {
  import CrosslinkTenderlinkProposalChunkSignBytes.* from "./CrosslinkTenderlinkProposalChunkSignBytes"
  export CrosslinkTenderlinkProposalChunkSignBytes.*

  def ChunkWire(
    byteLen: int,
    chunkIndex: ChunkIndex_t,
    proposalSize: int,
    round: Round_t,
    validRound: Round_t,
    height: Height_t,
    chunkDataByteLen: int,
    hex: Bytes_t,
  ): ProposalChunkWire_t = {
    byteLen: byteLen,
    chunkIndex: chunkIndex,
    proposalSize: proposalSize,
    round: round,
    validRound: validRound,
    height: height,
    proposalId: TestProposalIdHex,
    chunkDataByteLen: chunkDataByteLen,
    chunkDataHex: TestChunkDataHex,
    hex: hex,
  }

  pure val nilValidRoundChunk =
    ChunkWire(
      60,
      0,
      4,
      0,
      NilValidRound,
      1,
      4,
      "000000000400000000000000ffffffff0100000000000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbcafebabe",
    )

  pure val polValidRoundChunk =
    ChunkWire(
      60,
      1,
      8,
      2,
      1,
      2,
      4,
      "010000000800000002000000010000000200000000000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbcafebabe",
    )

  pure val futureValidRoundChunk =
    ChunkWire(
      60,
      1,
      8,
      2,
      2,
      2,
      4,
      "010000000800000002000000020000000200000000000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbcafebabe",
    )

  pure val trailingByteChunk =
    ChunkWire(
      61,
      0,
      4,
      0,
      NilValidRound,
      1,
      4,
      "000000000400000000000000ffffffff0100000000000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbcafebabe00",
    )

  pure val crossHeightReplayChunk =
    ChunkWire(
      60,
      0,
      4,
      0,
      NilValidRound,
      2,
      4,
      "000000000400000000000000ffffffff0100000000000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbcafebabe",
    )

  pure val chunkPastProposalEnd =
    ChunkWire(
      60,
      1,
      4,
      2,
      1,
      2,
      4,
      "010000000800000002000000010000000200000000000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbcafebabe",
    )

  pure val TestProposalChunks = Set(
    nilValidRoundChunk,
    polValidRoundChunk,
    futureValidRoundChunk,
    trailingByteChunk,
    crossHeightReplayChunk,
    chunkPastProposalEnd,
  )

  action Next: bool =
    any {
      nondet wire = oneOf(TestProposalChunks)
      AcceptProposalChunk(wire),
      Stutter,
    }

  action unchangedAll = all {
    acceptedProposalChunks' = acceptedProposalChunks,
    firedAction' = firedAction,
  }

  run proposalChunkLayoutPinnedTest = {
    Init.then(all {
      assert(ProposalChunkLayoutConstantsPinned),
      assert(ProposalChunkFieldOffsetsContiguous),
      assert(ChunkIndexOffset == 0),
      assert(ProposalSizeOffset == 4),
      assert(RoundOffset == 8),
      assert(ValidRoundOffset == 12),
      assert(HeightOffset == 16),
      assert(ProposalIdOffset == 24),
      assert(ChunkDataOffset == 56),
      unchangedAll,
    })
  }

  run nilValidRoundHeaderExactHexTest = {
    Init.then(all {
      assert(ValidRoundWireValue(NilValidRound) == MaxU32),
      assert(CanonicalProposalChunkHeaderHex(nilValidRoundChunk) ==
        "000000000400000000000000ffffffff0100000000000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"),
      assert(CanonicalProposalChunkSignBytesHex(nilValidRoundChunk) ==
        nilValidRoundChunk.hex),
      unchangedAll,
    })
  }

  run polValidRoundHeaderExactHexTest = {
    Init.then(all {
      assert(ValidRoundWireValue(1) == 1),
      assert(ValidRoundAllowed(2, 1)),
      assert(CanonicalProposalChunkHeaderHex(polValidRoundChunk) ==
        "010000000800000002000000010000000200000000000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"),
      assert(CanonicalProposalChunkSignBytesHex(polValidRoundChunk) ==
        polValidRoundChunk.hex),
      unchangedAll,
    })
  }

  run acceptProposalChunkSignBytesTest = {
    Init
      .then(AcceptProposalChunk(nilValidRoundChunk))
      .then(AcceptProposalChunk(polValidRoundChunk))
      .then(all {
        assert(acceptedProposalChunks.contains(nilValidRoundChunk)),
        assert(acceptedProposalChunks.contains(polValidRoundChunk)),
        assert(Safety),
        unchangedAll,
      })
  }

  run futureValidRoundRejectedTest = {
    Init.then(AcceptProposalChunk(futureValidRoundChunk)).fail()
  }

  run trailingByteProposalChunkRejectedTest = {
    Init.then(AcceptProposalChunk(trailingByteChunk)).fail()
  }

  run crossHeightProposalChunkReplayRejectedTest = {
    Init.then(AcceptProposalChunk(crossHeightReplayChunk)).fail()
  }

  run chunkPastProposalEndRejectedTest = {
    Init.then(AcceptProposalChunk(chunkPastProposalEnd)).fail()
  }

  run proposalChunkSafetyTest = {
    Init.then(all {
      assert(Safety),
      unchangedAll,
    })
  }
}

module CrosslinkTenderlinkProposalChunkSignBytesModel {
  import CrosslinkTenderlinkProposalChunkSignBytesTest.* from "./CrosslinkTenderlinkProposalChunkSignBytes"
  export CrosslinkTenderlinkProposalChunkSignBytesTest.*
}
