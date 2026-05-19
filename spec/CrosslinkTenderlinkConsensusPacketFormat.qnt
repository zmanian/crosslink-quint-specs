module CrosslinkTenderlinkConsensusPacketFormat {
  /*
   Tenderlink consensus packet wire format.

   The earlier byte-layout slices pin the signed payloads and the vote batch
   payload. This slice pins the legacy packet header and the complete compact
   consensus packets that carry those payloads on the Tenderlink UDP transport.

   PacketHeader is 16 bytes:
   - little-endian u64 tag_and_ack, where the low 8 bits are packet tag/status
     and the remaining high bits are ack_latest,
   - little-endian u64 ack_field.

   Compact consensus packets modeled here use no inline status body:
   - proposal chunk: header + signed proposal chunk bytes + 64-byte signature,
   - prevote/precommit batch: header + PacketVotes payload.
   */

  type Bytes_t = str
  type ConsensusPacketKind_t = str

  type PacketHeader_t = {
    byteLen: int,
    packetType: int,
    hasStatus: bool,
    ackLatest: int,
    ackField: int,
    tagAndAck: int,
    hex: Bytes_t,
  }

  type ConsensusPacket_t = {
    kind: ConsensusPacketKind_t,
    header: PacketHeader_t,
    payloadByteLen: int,
    signatureByteLen: int,
    byteLen: int,
    hex: Bytes_t,
  }

  pure val ProposalChunkKind = "proposal-chunk"
  pure val PrevoteBatchKind = "prevote-batch"
  pure val PrecommitBatchKind = "precommit-batch"
  pure val ConsensusPacketKinds = Set(
    ProposalChunkKind,
    PrevoteBatchKind,
    PrecommitBatchKind,
  )

  pure val PacketTypeProposalChunk = 7
  pure val PacketTypePrevoteSignatures = 8
  pure val PacketTypePrecommitSignatures = 9
  pure val PacketTypeBits = 7
  pure val PacketTypeMask = 127
  pure val PacketTagStatusShift = PacketTypeBits
  pure val PacketTagStatusFlag = 128
  pure val PacketTagBits = 8
  pure val PacketTagMask = 255
  pure val PacketHeaderByteLen = 16
  pure val TagAndAckByteLen = 8
  pure val AckFieldByteLen = 8
  pure val TestAckLatest = 513
  pure val TestAckField = 258

  pure val ProposalChunkSignedPayloadByteLen = 60
  pure val ProposalSignatureByteLen = 64
  pure val VotePacketPayloadByteLen = 112
  pure val ProposalPacketByteLen =
    PacketHeaderByteLen + ProposalChunkSignedPayloadByteLen + ProposalSignatureByteLen
  pure val VoteBatchPacketByteLen = PacketHeaderByteLen + VotePacketPayloadByteLen

  pure val ProposalPacketExtraByteLen =
    PacketHeaderByteLen + 56 + ProposalSignatureByteLen

  pure val TagAndAckOffset = 0
  pure val AckFieldOffset = TagAndAckOffset + TagAndAckByteLen
  pure val ConsensusPayloadOffset = AckFieldOffset + AckFieldByteLen
  pure val ProposalSignatureOffset =
    ConsensusPayloadOffset + ProposalChunkSignedPayloadByteLen
  pure val ProposalPacketEndOffset = ProposalSignatureOffset + ProposalSignatureByteLen
  pure val VoteBatchPacketEndOffset = ConsensusPayloadOffset + VotePacketPayloadByteLen

  pure val TestProposalChunkSignedPayloadHex =
    "000000000400000000000000ffffffff0100000000000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbcafebabe"
  pure val TestProposalSignatureHex =
    "22222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222"
  pure val TestPrevotePacketPayloadHex =
    "0100000000000100000000000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa000011111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111"
  pure val TestPrecommitPacketPayloadHex =
    "0001000000000100000000000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa000011111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111"

  pure val UnmodeledPacketHeaderHex = "unmodeled-packet-header"
  pure val UnmodeledConsensusPacketHex = "unmodeled-consensus-packet"

  var acceptedConsensusPackets: Set[ConsensusPacket_t]
  var firedAction: str

  pure def FieldEndOffset(offset: int, width: int): int =
    offset + width

  pure def PacketTypeForKind(kind: ConsensusPacketKind_t): int =
    if (kind == ProposalChunkKind) {
      PacketTypeProposalChunk
    } else if (kind == PrevoteBatchKind) {
      PacketTypePrevoteSignatures
    } else {
      PacketTypePrecommitSignatures
    }

  pure def PacketTagByte(packetType: int, hasStatus: bool): int =
    packetType + (if (hasStatus) { PacketTagStatusFlag } else { 0 })

  pure def PacketTagAndAck(packetType: int, hasStatus: bool, ackLatest: int): int =
    PacketTagByte(packetType, hasStatus) + ackLatest * 256

  pure def HeaderPacketType(header: PacketHeader_t): int =
    header.tagAndAck % 128

  pure def HeaderHasStatus(header: PacketHeader_t): bool =
    (header.tagAndAck % 256) >= PacketTagStatusFlag

  pure def HeaderAckLatest(header: PacketHeader_t): int =
    (header.tagAndAck - (header.tagAndAck % 256)) / 256

  pure def PacketHeaderFieldsValid(header: PacketHeader_t): bool =
    header.byteLen == PacketHeaderByteLen and
    header.packetType >= 0 and
    header.packetType <= PacketTypeMask and
    header.ackLatest >= 0 and
    header.ackField >= 0 and
    header.tagAndAck ==
      PacketTagAndAck(header.packetType, header.hasStatus, header.ackLatest) and
    HeaderPacketType(header) == header.packetType and
    HeaderHasStatus(header) == header.hasStatus and
    HeaderAckLatest(header) == header.ackLatest

  pure def PacketHeaderLayoutConstantsPinned: bool =
    PacketHeaderByteLen == 16 and
    TagAndAckByteLen == 8 and
    AckFieldByteLen == 8 and
    TagAndAckOffset == 0 and
    AckFieldOffset == 8 and
    ConsensusPayloadOffset == 16 and
    PacketTypeBits == 7 and
    PacketTypeMask == 127 and
    PacketTagStatusShift == 7 and
    PacketTagStatusFlag == 128 and
    PacketTagBits == 8 and
    PacketTagMask == 255

  pure def ConsensusPacketLayoutConstantsPinned: bool =
    PacketTypeProposalChunk == 7 and
    PacketTypePrevoteSignatures == 8 and
    PacketTypePrecommitSignatures == 9 and
    ProposalChunkSignedPayloadByteLen == 60 and
    ProposalSignatureByteLen == 64 and
    VotePacketPayloadByteLen == 112 and
    ProposalPacketByteLen == 140 and
    VoteBatchPacketByteLen == 128 and
    ProposalPacketExtraByteLen == 136 and
    ProposalSignatureOffset == 76 and
    ProposalPacketEndOffset == 140 and
    VoteBatchPacketEndOffset == 128

  pure def ConsensusPacketFieldOffsetsContiguous: bool =
    FieldEndOffset(TagAndAckOffset, TagAndAckByteLen) == AckFieldOffset and
    FieldEndOffset(AckFieldOffset, AckFieldByteLen) == ConsensusPayloadOffset and
    FieldEndOffset(
      ConsensusPayloadOffset,
      ProposalChunkSignedPayloadByteLen,
    ) == ProposalSignatureOffset and
    FieldEndOffset(ProposalSignatureOffset, ProposalSignatureByteLen) ==
      ProposalPacketEndOffset and
    FieldEndOffset(ConsensusPayloadOffset, VotePacketPayloadByteLen) ==
      VoteBatchPacketEndOffset

  pure def CanonicalPacketHeaderHex(header: PacketHeader_t): Bytes_t =
    if (header.byteLen == 16 and header.packetType == 7 and
      not(header.hasStatus) and header.ackLatest == 0 and header.ackField == 0 and
      header.tagAndAck == 7) {
      "07000000000000000000000000000000"
    } else if (header.byteLen == 16 and header.packetType == 8 and
      not(header.hasStatus) and header.ackLatest == 0 and header.ackField == 0 and
      header.tagAndAck == 8) {
      "08000000000000000000000000000000"
    } else if (header.byteLen == 16 and header.packetType == 8 and
      not(header.hasStatus) and header.ackLatest == TestAckLatest and
      header.ackField == TestAckField and header.tagAndAck == 131336) {
      "08010200000000000201000000000000"
    } else if (header.byteLen == 16 and header.packetType == 9 and
      not(header.hasStatus) and header.ackLatest == 0 and header.ackField == 0 and
      header.tagAndAck == 9) {
      "09000000000000000000000000000000"
    } else if (header.byteLen == 16 and header.packetType == 7 and
      header.hasStatus and header.ackLatest == 0 and header.ackField == 0 and
      header.tagAndAck == 135) {
      "87000000000000000000000000000000"
    } else {
      UnmodeledPacketHeaderHex
    }

  pure def PacketHeaderCanonical(header: PacketHeader_t): bool =
    PacketHeaderFieldsValid(header) and
    CanonicalPacketHeaderHex(header) != UnmodeledPacketHeaderHex and
    header.hex == CanonicalPacketHeaderHex(header)

  pure def ConsensusPacketFieldsValid(packet: ConsensusPacket_t): bool =
    ConsensusPacketKinds.contains(packet.kind) and
    PacketHeaderCanonical(packet.header) and
    not(packet.header.hasStatus) and
    packet.header.packetType == PacketTypeForKind(packet.kind) and
    (
      if (packet.kind == ProposalChunkKind) {
        packet.payloadByteLen == ProposalChunkSignedPayloadByteLen and
        packet.signatureByteLen == ProposalSignatureByteLen and
        packet.byteLen == ProposalPacketByteLen
      } else {
        packet.payloadByteLen == VotePacketPayloadByteLen and
        packet.signatureByteLen == 0 and
        packet.byteLen == VoteBatchPacketByteLen
      }
    )

  pure def CanonicalConsensusPacketHex(packet: ConsensusPacket_t): Bytes_t =
    if (packet.kind == ProposalChunkKind and
      ConsensusPacketFieldsValid(packet)) {
      "07000000000000000000000000000000000000000400000000000000ffffffff0100000000000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbcafebabe22222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222"
    } else if (packet.kind == PrevoteBatchKind and
      ConsensusPacketFieldsValid(packet)) {
      if (packet.header.ackLatest == TestAckLatest and
        packet.header.ackField == TestAckField) {
        "080102000000000002010000000000000100000000000100000000000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa000011111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111"
      } else {
        "080000000000000000000000000000000100000000000100000000000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa000011111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111"
      }
    } else if (packet.kind == PrecommitBatchKind and
      ConsensusPacketFieldsValid(packet)) {
      "090000000000000000000000000000000001000000000100000000000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa000011111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111"
    } else {
      UnmodeledConsensusPacketHex
    }

  pure def ConsensusPacketCanonical(packet: ConsensusPacket_t): bool =
    ConsensusPacketFieldsValid(packet) and
    CanonicalConsensusPacketHex(packet) != UnmodeledConsensusPacketHex and
    packet.hex == CanonicalConsensusPacketHex(packet)

  action Init = all {
    acceptedConsensusPackets' = Set(),
    firedAction' = "Init",
  }

  action AcceptConsensusPacket(packet: ConsensusPacket_t): bool =
    all {
      ConsensusPacketCanonical(packet),
      acceptedConsensusPackets' = acceptedConsensusPackets.union(Set(packet)),
      firedAction' = "AcceptConsensusPacket",
    }

  action Stutter: bool =
    all {
      acceptedConsensusPackets' = acceptedConsensusPackets,
      firedAction' = firedAction,
    }

  pure def AcceptedConsensusPacketsCanonical: bool =
    acceptedConsensusPackets.forall(ConsensusPacketCanonical)

  val Safety =
    PacketHeaderLayoutConstantsPinned and
    ConsensusPacketLayoutConstantsPinned and
    ConsensusPacketFieldOffsetsContiguous and
    AcceptedConsensusPacketsCanonical
}

module CrosslinkTenderlinkConsensusPacketFormatTest {
  import CrosslinkTenderlinkConsensusPacketFormat.* from "./CrosslinkTenderlinkConsensusPacketFormat"
  export CrosslinkTenderlinkConsensusPacketFormat.*

  def Header(
    packetType: int,
    hasStatus: bool,
    tagAndAck: int,
    hex: Bytes_t,
  ): PacketHeader_t = {
    byteLen: 16,
    packetType: packetType,
    hasStatus: hasStatus,
    ackLatest: 0,
    ackField: 0,
    tagAndAck: tagAndAck,
    hex: hex,
  }

  def HeaderWithAck(
    packetType: int,
    hasStatus: bool,
    ackLatest: int,
    ackField: int,
    tagAndAck: int,
    hex: Bytes_t,
  ): PacketHeader_t = {
    byteLen: 16,
    packetType: packetType,
    hasStatus: hasStatus,
    ackLatest: ackLatest,
    ackField: ackField,
    tagAndAck: tagAndAck,
    hex: hex,
  }

  def Packet(
    kind: ConsensusPacketKind_t,
    header: PacketHeader_t,
    payloadByteLen: int,
    signatureByteLen: int,
    byteLen: int,
    hex: Bytes_t,
  ): ConsensusPacket_t = {
    kind: kind,
    header: header,
    payloadByteLen: payloadByteLen,
    signatureByteLen: signatureByteLen,
    byteLen: byteLen,
    hex: hex,
  }

  pure val proposalHeader =
    Header(PacketTypeProposalChunk, false, 7, "07000000000000000000000000000000")
  pure val prevoteHeader =
    Header(PacketTypePrevoteSignatures, false, 8, "08000000000000000000000000000000")
  pure val ackedPrevoteHeader =
    HeaderWithAck(
      PacketTypePrevoteSignatures,
      false,
      TestAckLatest,
      TestAckField,
      131336,
      "08010200000000000201000000000000",
    )
  pure val wrongAckPrevoteHeader =
    HeaderWithAck(
      PacketTypePrevoteSignatures,
      false,
      TestAckLatest,
      TestAckField,
      520,
      "08010200000000000201000000000000",
    )
  pure val precommitHeader =
    Header(PacketTypePrecommitSignatures, false, 9, "09000000000000000000000000000000")
  pure val statusProposalHeader =
    Header(PacketTypeProposalChunk, true, 135, "87000000000000000000000000000000")

  pure val proposalPacket =
    Packet(
      ProposalChunkKind,
      proposalHeader,
      60,
      64,
      140,
      "07000000000000000000000000000000000000000400000000000000ffffffff0100000000000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbcafebabe22222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222",
    )

  pure val prevotePacket =
    Packet(
      PrevoteBatchKind,
      prevoteHeader,
      112,
      0,
      128,
      "080000000000000000000000000000000100000000000100000000000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa000011111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111",
    )

  pure val precommitPacket =
    Packet(
      PrecommitBatchKind,
      precommitHeader,
      112,
      0,
      128,
      "090000000000000000000000000000000001000000000100000000000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa000011111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111",
    )

  pure val ackedPrevotePacket =
    Packet(
      PrevoteBatchKind,
      ackedPrevoteHeader,
      112,
      0,
      128,
      "080102000000000002010000000000000100000000000100000000000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa000011111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111",
    )

  pure val statusFlagProposalPacket =
    Packet(
      ProposalChunkKind,
      statusProposalHeader,
      60,
      64,
      140,
      "87000000000000000000000000000000000000000400000000000000ffffffff0100000000000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbcafebabe22222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222",
    )

  pure val wrongTypeProposalPacket =
    Packet(
      ProposalChunkKind,
      prevoteHeader,
      60,
      64,
      140,
      "08000000000000000000000000000000000000000400000000000000ffffffff0100000000000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbcafebabe22222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222",
    )

  pure val missingProposalSignaturePacket =
    Packet(
      ProposalChunkKind,
      proposalHeader,
      60,
      0,
      76,
      "07000000000000000000000000000000000000000400000000000000ffffffff0100000000000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbcafebabe",
    )

  pure val trailingVotePacket =
    Packet(
      PrecommitBatchKind,
      precommitHeader,
      112,
      0,
      129,
      "090000000000000000000000000000000001000000000100000000000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa00001111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111100",
    )

  pure val wrongAckPrevotePacket =
    Packet(
      PrevoteBatchKind,
      wrongAckPrevoteHeader,
      112,
      0,
      128,
      "080102000000000002010000000000000100000000000100000000000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa000011111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111",
    )

  pure val TestConsensusPackets = Set(
    proposalPacket,
    prevotePacket,
    precommitPacket,
    ackedPrevotePacket,
    statusFlagProposalPacket,
    wrongTypeProposalPacket,
    missingProposalSignaturePacket,
    trailingVotePacket,
    wrongAckPrevotePacket,
  )

  action Next: bool =
    any {
      nondet packet = oneOf(TestConsensusPackets)
      AcceptConsensusPacket(packet),
      Stutter,
    }

  action unchangedAll = all {
    acceptedConsensusPackets' = acceptedConsensusPackets,
    firedAction' = firedAction,
  }

  run packetHeaderLayoutPinnedTest = {
    Init.then(all {
      assert(PacketHeaderLayoutConstantsPinned),
      assert(ConsensusPacketLayoutConstantsPinned),
      assert(ConsensusPacketFieldOffsetsContiguous),
      assert(ConsensusPayloadOffset == 16),
      assert(ProposalSignatureOffset == 76),
      unchangedAll,
    })
  }

  run packetHeaderExactHexTest = {
    Init.then(all {
      assert(PacketHeaderCanonical(proposalHeader)),
      assert(PacketHeaderCanonical(prevoteHeader)),
      assert(PacketHeaderCanonical(precommitHeader)),
      assert(PacketHeaderCanonical(statusProposalHeader)),
      assert(HeaderPacketType(statusProposalHeader) == PacketTypeProposalChunk),
      assert(HeaderHasStatus(statusProposalHeader)),
      unchangedAll,
    })
  }

  run ackHeaderExactHexTest = {
    Init.then(all {
      assert(PacketHeaderCanonical(ackedPrevoteHeader)),
      assert(HeaderPacketType(ackedPrevoteHeader) ==
        PacketTypePrevoteSignatures),
      assert(not(HeaderHasStatus(ackedPrevoteHeader))),
      assert(HeaderAckLatest(ackedPrevoteHeader) == TestAckLatest),
      assert(ackedPrevoteHeader.hex == "08010200000000000201000000000000"),
      unchangedAll,
    })
  }

  run fullConsensusPacketExactHexTest = {
    Init.then(all {
      assert(CanonicalConsensusPacketHex(proposalPacket) == proposalPacket.hex),
      assert(CanonicalConsensusPacketHex(prevotePacket) == prevotePacket.hex),
      assert(CanonicalConsensusPacketHex(precommitPacket) ==
        precommitPacket.hex),
      assert(CanonicalConsensusPacketHex(ackedPrevotePacket) ==
        ackedPrevotePacket.hex),
      unchangedAll,
    })
  }

  run acceptConsensusPacketsTest = {
    Init
      .then(AcceptConsensusPacket(proposalPacket))
      .then(AcceptConsensusPacket(prevotePacket))
      .then(AcceptConsensusPacket(precommitPacket))
      .then(AcceptConsensusPacket(ackedPrevotePacket))
      .then(all {
        assert(acceptedConsensusPackets.contains(proposalPacket)),
        assert(acceptedConsensusPackets.contains(prevotePacket)),
        assert(acceptedConsensusPackets.contains(precommitPacket)),
        assert(acceptedConsensusPackets.contains(ackedPrevotePacket)),
        assert(Safety),
        unchangedAll,
      })
  }

  run statusFlagCompactConsensusPacketRejectedTest = {
    Init.then(AcceptConsensusPacket(statusFlagProposalPacket)).fail()
  }

  run wrongPacketTypeRejectedTest = {
    Init.then(AcceptConsensusPacket(wrongTypeProposalPacket)).fail()
  }

  run missingProposalSignatureRejectedTest = {
    Init.then(AcceptConsensusPacket(missingProposalSignaturePacket)).fail()
  }

  run trailingVotePacketRejectedTest = {
    Init.then(AcceptConsensusPacket(trailingVotePacket)).fail()
  }

  run wrongAckHeaderRejectedTest = {
    Init.then(AcceptConsensusPacket(wrongAckPrevotePacket)).fail()
  }

  run consensusPacketSafetyTest = {
    Init.then(all {
      assert(Safety),
      unchangedAll,
    })
  }
}

module CrosslinkTenderlinkConsensusPacketFormatModel {
  import CrosslinkTenderlinkConsensusPacketFormatTest.* from "./CrosslinkTenderlinkConsensusPacketFormat"
  export CrosslinkTenderlinkConsensusPacketFormatTest.*
}
