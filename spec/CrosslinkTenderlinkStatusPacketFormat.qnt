module CrosslinkTenderlinkStatusPacketFormat {
  /*
   Tenderlink status packet wire format.

   PacketHeader::has_status() causes the receiver to read an inline
   PacketStatus immediately after the 16-byte PacketHeader and before any
   packet-specific local payload. This slice pins the current status-only
   packet shape used by periodic empty/status messages:

   - 16-byte PacketHeader with the status flag set,
   - u64 height,
   - u32 round,
   - one proposal chunk range [u32 lo, u32 hi),
   - one prevote range [u16 lo, u16 hi),
   - one precommit range [u16 lo, u16 hi).
   */

  type Bytes_t = str

  type StatusRange32_t = { lo: int, hi: int }
  type StatusRange16_t = { lo: int, hi: int }

  type StatusHeader_t = {
    byteLen: int,
    packetType: int,
    hasStatus: bool,
    ackLatest: int,
    ackField: int,
    tagAndAck: int,
    hex: Bytes_t,
  }

  type StatusPacket_t = {
    header: StatusHeader_t,
    height: int,
    round: int,
    proposalChunkRange: StatusRange32_t,
    prevoteRange: StatusRange16_t,
    precommitRange: StatusRange16_t,
    rosterLen: int,
    byteLen: int,
    hex: Bytes_t,
  }

  pure val PacketTypeEmpty = 0
  pure val PacketTypePrevoteSignatures = 8
  pure val PacketTypeBits = 7
  pure val PacketTypeMask = 127
  pure val PacketTagStatusFlag = 128
  pure val PacketTagBits = 8
  pure val PacketHeaderByteLen = 16
  pure val StatusBodyByteLen = 28
  pure val StatusPacketByteLen = PacketHeaderByteLen + StatusBodyByteLen
  pure val StatusProposalRangesN = 1
  pure val StatusVoteRangesN = 1

  pure val HeightOffset = 16
  pure val RoundOffset = 24
  pure val ProposalRangeOffset = 28
  pure val PrevoteRangeOffset = 36
  pure val PrecommitRangeOffset = 40
  pure val StatusPacketEndOffset = 44

  pure val UnmodeledStatusHeaderHex = "unmodeled-status-header"
  pure val UnmodeledStatusPacketHex = "unmodeled-status-packet"
  pure val EmptyStatusHeaderHex = "80000000000000000000000000000000"
  pure val AckedPrevoteStatusHeaderHex =
    "88010200000000000201000000000000"
  pure val ValidStatusPacketHex =
    "8000000000000000000000000000000001000000000000000200000003000000050000000000040002000400"
  pure val AckedPrevoteStatusPacketHex =
    "8801020000000000020100000000000001000000000000000200000003000000050000000000040002000400"

  var acceptedStatusPackets: Set[StatusPacket_t]
  var statusFiredAction: str

  pure def StatusTagAndAck(
    packetType: int,
    hasStatus: bool,
    ackLatest: int,
  ): int =
    packetType + (if (hasStatus) { PacketTagStatusFlag } else { 0 }) +
    ackLatest * 256

  pure def HeaderPacketType(header: StatusHeader_t): int =
    header.tagAndAck % 128

  pure def HeaderHasStatus(header: StatusHeader_t): bool =
    (header.tagAndAck % 256) >= PacketTagStatusFlag

  pure def HeaderAckLatest(header: StatusHeader_t): int =
    (header.tagAndAck - (header.tagAndAck % 256)) / 256

  pure def StatusHeaderFieldsValid(header: StatusHeader_t): bool =
    header.byteLen == PacketHeaderByteLen and
    header.packetType >= 0 and
    header.packetType <= PacketTypeMask and
    header.ackLatest >= 0 and
    header.ackField >= 0 and
    header.tagAndAck ==
      StatusTagAndAck(header.packetType, header.hasStatus, header.ackLatest) and
    HeaderPacketType(header) == header.packetType and
    HeaderHasStatus(header) == header.hasStatus and
    HeaderAckLatest(header) == header.ackLatest

  pure def CanonicalStatusHeaderHex(header: StatusHeader_t): Bytes_t =
    if (header.byteLen == 16 and header.packetType == PacketTypeEmpty and
      header.hasStatus and header.ackLatest == 0 and header.ackField == 0 and
      header.tagAndAck == 128) {
      EmptyStatusHeaderHex
    } else if (header.byteLen == 16 and
      header.packetType == PacketTypePrevoteSignatures and header.hasStatus and
      header.ackLatest == 513 and header.ackField == 258 and
      header.tagAndAck == 131464) {
      AckedPrevoteStatusHeaderHex
    } else {
      UnmodeledStatusHeaderHex
    }

  pure def StatusHeaderCanonical(header: StatusHeader_t): bool =
    StatusHeaderFieldsValid(header) and
    CanonicalStatusHeaderHex(header) != UnmodeledStatusHeaderHex and
    header.hex == CanonicalStatusHeaderHex(header)

  pure def Range32Valid(rng: StatusRange32_t): bool =
    rng.lo >= 0 and rng.hi >= rng.lo

  pure def Range16Valid(rng: StatusRange16_t, rosterLen: int): bool =
    rng.lo >= 0 and rng.hi >= rng.lo and rng.hi <= rosterLen

  pure def StatusPacketFieldsValid(packet: StatusPacket_t): bool =
    StatusHeaderCanonical(packet.header) and
    packet.header.hasStatus and
    packet.height >= 0 and
    packet.round >= 0 and
    packet.rosterLen >= 0 and
    Range32Valid(packet.proposalChunkRange) and
    Range16Valid(packet.prevoteRange, packet.rosterLen) and
    Range16Valid(packet.precommitRange, packet.rosterLen) and
    packet.byteLen == StatusPacketByteLen

  pure def CanonicalStatusPacketHex(packet: StatusPacket_t): Bytes_t =
    if (StatusPacketFieldsValid(packet) and
      packet.header.packetType == PacketTypeEmpty and packet.height == 1 and
      packet.round == 2 and packet.proposalChunkRange.lo == 3 and
      packet.proposalChunkRange.hi == 5 and packet.prevoteRange.lo == 0 and
      packet.prevoteRange.hi == 4 and packet.precommitRange.lo == 2 and
      packet.precommitRange.hi == 4 and packet.rosterLen == 4) {
      ValidStatusPacketHex
    } else if (StatusPacketFieldsValid(packet) and
      packet.header.packetType == PacketTypePrevoteSignatures and
      packet.height == 1 and packet.round == 2 and
      packet.proposalChunkRange.lo == 3 and
      packet.proposalChunkRange.hi == 5 and packet.prevoteRange.lo == 0 and
      packet.prevoteRange.hi == 4 and packet.precommitRange.lo == 2 and
      packet.precommitRange.hi == 4 and packet.rosterLen == 4) {
      AckedPrevoteStatusPacketHex
    } else {
      UnmodeledStatusPacketHex
    }

  pure def StatusPacketCanonical(packet: StatusPacket_t): bool =
    StatusPacketFieldsValid(packet) and
    CanonicalStatusPacketHex(packet) != UnmodeledStatusPacketHex and
    packet.hex == CanonicalStatusPacketHex(packet)

  pure def StatusLayoutConstantsPinned: bool =
    PacketHeaderByteLen == 16 and
    StatusBodyByteLen == 28 and
    StatusPacketByteLen == 44 and
    StatusProposalRangesN == 1 and
    StatusVoteRangesN == 1 and
    HeightOffset == 16 and
    RoundOffset == 24 and
    ProposalRangeOffset == 28 and
    PrevoteRangeOffset == 36 and
    PrecommitRangeOffset == 40 and
    StatusPacketEndOffset == 44

  action Init = all {
    acceptedStatusPackets' = Set(),
    statusFiredAction' = "Init",
  }

  action AcceptStatusPacket(packet: StatusPacket_t): bool =
    all {
      StatusPacketCanonical(packet),
      acceptedStatusPackets' = acceptedStatusPackets.union(Set(packet)),
      statusFiredAction' = "AcceptStatusPacket",
    }

  action Stutter: bool =
    all {
      acceptedStatusPackets' = acceptedStatusPackets,
      statusFiredAction' = statusFiredAction,
    }

  pure def AcceptedStatusPacketsCanonical: bool =
    acceptedStatusPackets.forall(StatusPacketCanonical)

  val Safety =
    StatusLayoutConstantsPinned and
    AcceptedStatusPacketsCanonical
}

module CrosslinkTenderlinkStatusPacketFormatTest {
  import CrosslinkTenderlinkStatusPacketFormat.* from "./CrosslinkTenderlinkStatusPacketFormat"
  export CrosslinkTenderlinkStatusPacketFormat.*

  def Range32(lo: int, hi: int): StatusRange32_t = { lo: lo, hi: hi }
  def Range16(lo: int, hi: int): StatusRange16_t = { lo: lo, hi: hi }

  def Header(
    packetType: int,
    hasStatus: bool,
    ackLatest: int,
    ackField: int,
    tagAndAck: int,
    hex: Bytes_t,
  ): StatusHeader_t = {
    byteLen: 16,
    packetType: packetType,
    hasStatus: hasStatus,
    ackLatest: ackLatest,
    ackField: ackField,
    tagAndAck: tagAndAck,
    hex: hex,
  }

  def StatusPacket(
    header: StatusHeader_t,
    proposalRange: StatusRange32_t,
    prevoteRange: StatusRange16_t,
    precommitRange: StatusRange16_t,
    rosterLen: int,
    byteLen: int,
    hex: Bytes_t,
  ): StatusPacket_t = {
    header: header,
    height: 1,
    round: 2,
    proposalChunkRange: proposalRange,
    prevoteRange: prevoteRange,
    precommitRange: precommitRange,
    rosterLen: rosterLen,
    byteLen: byteLen,
    hex: hex,
  }

  pure val EmptyStatusHeader =
    Header(PacketTypeEmpty, true, 0, 0, 128, EmptyStatusHeaderHex)
  pure val AckedPrevoteStatusHeader =
    Header(
      PacketTypePrevoteSignatures,
      true,
      513,
      258,
      131464,
      AckedPrevoteStatusHeaderHex,
    )
  pure val MissingStatusFlagHeader =
    Header(PacketTypeEmpty, false, 0, 0, 0, "00000000000000000000000000000000")
  pure val WrongAckStatusHeader =
    Header(
      PacketTypePrevoteSignatures,
      true,
      513,
      258,
      136,
      "88010200000000000201000000000000",
    )

  pure val ValidStatusPacket =
    StatusPacket(
      EmptyStatusHeader,
      Range32(3, 5),
      Range16(0, 4),
      Range16(2, 4),
      4,
      44,
      ValidStatusPacketHex,
    )

  pure val AckedPrevoteStatusPacket =
    StatusPacket(
      AckedPrevoteStatusHeader,
      Range32(3, 5),
      Range16(0, 4),
      Range16(2, 4),
      4,
      44,
      AckedPrevoteStatusPacketHex,
    )

  pure val MissingStatusFlagPacket =
    StatusPacket(
      MissingStatusFlagHeader,
      Range32(3, 5),
      Range16(0, 4),
      Range16(2, 4),
      4,
      44,
      "0000000000000000000000000000000001000000000000000200000003000000050000000000040002000400",
    )

  pure val ReversedProposalRangePacket =
    StatusPacket(
      EmptyStatusHeader,
      Range32(5, 3),
      Range16(0, 4),
      Range16(2, 4),
      4,
      44,
      "8000000000000000000000000000000001000000000000000200000005000000030000000000040002000400",
    )

  pure val VoteRangePastRosterPacket =
    StatusPacket(
      EmptyStatusHeader,
      Range32(3, 5),
      Range16(0, 5),
      Range16(2, 4),
      4,
      44,
      "8000000000000000000000000000000001000000000000000200000003000000050000000000050002000400",
    )

  pure val WrongAckStatusPacket =
    StatusPacket(
      WrongAckStatusHeader,
      Range32(3, 5),
      Range16(0, 4),
      Range16(2, 4),
      4,
      44,
      "8801020000000000020100000000000001000000000000000200000003000000050000000000040002000400",
    )

  pure val TruncatedStatusPacket =
    StatusPacket(
      EmptyStatusHeader,
      Range32(3, 5),
      Range16(0, 4),
      Range16(2, 4),
      4,
      43,
      "80000000000000000000000000000000010000000000000002000000030000000500000000000400020004",
    )

  pure val TestStatusPackets = Set(
    ValidStatusPacket,
    AckedPrevoteStatusPacket,
    MissingStatusFlagPacket,
    ReversedProposalRangePacket,
    VoteRangePastRosterPacket,
    WrongAckStatusPacket,
    TruncatedStatusPacket,
  )

  action Next: bool =
    any {
      nondet packet = oneOf(TestStatusPackets)
      AcceptStatusPacket(packet),
      Stutter,
    }

  action unchangedAll = all {
    acceptedStatusPackets' = acceptedStatusPackets,
    statusFiredAction' = statusFiredAction,
  }

  run statusLayoutPinnedTest = {
    Init.then(all {
      assert(StatusLayoutConstantsPinned),
      assert(StatusBodyByteLen == 28),
      assert(StatusPacketByteLen == 44),
      unchangedAll,
    })
  }

  run statusHeaderExactHexTest = {
    Init.then(all {
      assert(StatusHeaderCanonical(EmptyStatusHeader)),
      assert(StatusHeaderCanonical(AckedPrevoteStatusHeader)),
      assert(HeaderHasStatus(AckedPrevoteStatusHeader)),
      assert(HeaderAckLatest(AckedPrevoteStatusHeader) == 513),
      unchangedAll,
    })
  }

  run statusPacketExactHexTest = {
    Init.then(all {
      assert(CanonicalStatusPacketHex(ValidStatusPacket) ==
        ValidStatusPacket.hex),
      assert(CanonicalStatusPacketHex(AckedPrevoteStatusPacket) ==
        AckedPrevoteStatusPacket.hex),
      unchangedAll,
    })
  }

  run acceptStatusPacketsTest = {
    Init
      .then(AcceptStatusPacket(ValidStatusPacket))
      .then(AcceptStatusPacket(AckedPrevoteStatusPacket))
      .then(all {
        assert(acceptedStatusPackets.contains(ValidStatusPacket)),
        assert(acceptedStatusPackets.contains(AckedPrevoteStatusPacket)),
        assert(Safety),
        unchangedAll,
      })
  }

  run missingStatusFlagRejectedTest = {
    Init.then(AcceptStatusPacket(MissingStatusFlagPacket)).fail()
  }

  run reversedProposalRangeRejectedTest = {
    Init.then(AcceptStatusPacket(ReversedProposalRangePacket)).fail()
  }

  run voteRangePastRosterRejectedTest = {
    Init.then(AcceptStatusPacket(VoteRangePastRosterPacket)).fail()
  }

  run wrongAckStatusRejectedTest = {
    Init.then(AcceptStatusPacket(WrongAckStatusPacket)).fail()
  }

  run truncatedStatusRejectedTest = {
    Init.then(AcceptStatusPacket(TruncatedStatusPacket)).fail()
  }

  run statusSafetyTest = {
    Init.then(all {
      assert(Safety),
      unchangedAll,
    })
  }
}

module CrosslinkTenderlinkStatusPacketFormatModel {
  import CrosslinkTenderlinkStatusPacketFormatTest.* from "./CrosslinkTenderlinkStatusPacketFormat"
  export CrosslinkTenderlinkStatusPacketFormatTest.*
}
