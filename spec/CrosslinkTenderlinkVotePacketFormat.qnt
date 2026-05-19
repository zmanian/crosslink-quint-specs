module CrosslinkTenderlinkVotePacketFormat {
  /*
   Tenderlink vote packet format.

   PacketVotes carries batches of prevote or precommit signatures. The packet
   itself is not the signed payload: receivers reconstruct the canonical
   76-byte vote sign data with make_vote_sign_datas using the packet height,
   round, value id, packet type, roster index, and the roster member pubkey.
   This model pins the packet offsets and links each carried signature back to
   CrosslinkTenderlinkVoteSignBytes.qnt.
   */

  type PubKey_t = str
  type ValueId_t = str
  type Height_t = int
  type Round_t = int
  type VoteKind_t = str
  type Bytes_t = str
  type Signature_t = str
  type EntryIndex_t = int

  type VoteSignWire_t = {
    byteLen: int,
    pubKey: PubKey_t,
    valueId: ValueId_t,
    height: Height_t,
    round: Round_t,
    voteKind: VoteKind_t,
    roundFlag: int,
    hex: Bytes_t,
  }

  type VotePacketEntry_t = {
    rosterIndex: int,
    pubKey: PubKey_t,
    valueId: ValueId_t,
    signBytes: Bytes_t,
    voteSignature: Signature_t,
  }

  type VotePacket_t = {
    packetType: int,
    byteLen: int,
    noVotes: int,
    yesVotes: int,
    round: Round_t,
    height: Height_t,
    valueId: ValueId_t,
    entries: EntryIndex_t -> VotePacketEntry_t,
    hex: Bytes_t,
  }

  pure val PacketTypePrevoteSignatures = 8
  pure val PacketTypePrecommitSignatures = 9
  pure val VotePacketTypes = Set(PacketTypePrevoteSignatures, PacketTypePrecommitSignatures)

  pure val TestPubKeyHex =
    "0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20"
  pure val TestPubKey2Hex =
    "2122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f40"
  pure val TestPubKey3Hex =
    "4142434445464748494a4b4c4d4e4f505152535455565758595a5b5c5d5e5f60"
  pure val TestPubKey4Hex =
    "6162636465666768696a6b6c6d6e6f707172737475767778797a7b7c7d7e7f80"
  pure val TestPubKey5Hex =
    "8182838485868788898a8b8c8d8e8f909192939495969798999a9b9c9d9e9fa0"
  pure val NilValueId =
    "0000000000000000000000000000000000000000000000000000000000000000"
  pure val TestValueIdHex =
    "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  pure val TestValue2IdHex =
    "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
  pure val PrevoteKind = "prevote"
  pure val PrecommitKind = "precommit"
  pure val Heights = 1.to(2)
  pure val Rounds = 0.to(1)
  pure val VoteValues = Set(NilValueId, TestValueIdHex, TestValue2IdHex)
  pure val VoteSignByteLen = 76
  pure val RoundFlagByteLen = 4
  pure val HeightByteLen = 8
  pure val ValueIdByteLen = 32
  pure val PrecommitRoundFlag = 2147483648
  pure val UnmodeledVoteSignWireHex = "unmodeled-vote-sign-wire"

  pure val CountByteLen = 1
  pure val RosterIndexByteLen = 2
  pure val VoteSignatureByteLen = 64
  pure val VotePacketEntryByteLen = RosterIndexByteLen + VoteSignatureByteLen
  pure val VotePacketHeaderByteLen =
    CountByteLen + CountByteLen + RoundFlagByteLen + HeightByteLen + ValueIdByteLen

  pure val NoVotesOffset = 0
  pure val YesVotesOffset = NoVotesOffset + CountByteLen
  pure val PacketRoundOffset = YesVotesOffset + CountByteLen
  pure val PacketHeightOffset = PacketRoundOffset + RoundFlagByteLen
  pure val PacketValueIdOffset = PacketHeightOffset + HeightByteLen
  pure val VoteEntriesOffset = PacketValueIdOffset + ValueIdByteLen

  pure val MaxPacketVoteEntries = 18
  pure val PacketVotesStructByteLen = 1240
  pure val PacketVotesMaxSerializedByteLen =
    VotePacketHeaderByteLen + MaxPacketVoteEntries * VotePacketEntryByteLen
  pure val PacketVotesStructPaddingBytes =
    PacketVotesStructByteLen - PacketVotesMaxSerializedByteLen

  pure val EntryIndexes = 0.to(4)
  pure val TestVoteSignatureHex =
    "11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111"
  pure val TestVoteSignature2Hex =
    "22222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222"
  pure val TestVoteSignature3Hex =
    "33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333"
  pure val TestVoteSignature4Hex =
    "44444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444"
  pure val TestVoteSignature5Hex =
    "55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555"
  pure val ValuePrevotePolLargePacketHex =
    "0005010000000200000000000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa000011111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111010022222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222020033333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333030044444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444040055555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555"
  pure val ValuePrecommitQuorumPacketHex =
    "0003000000000100000000000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa000011111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111010022222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222020033333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333"
  pure val NilPrecommitQuorumPacketHex =
    "0300000000000100000000000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa000011111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111010022222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222020033333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333"
  pure val MixedPrecommitQuorumPacketHex =
    "0102000000000100000000000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa000011111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111010022222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222020033333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333"
  pure val UnmodeledVotePacketHex = "unmodeled-vote-packet"

  var acceptedVotePackets: Set[VotePacket_t]
  var firedAction: str

  pure def MergedRoundFlag(kind: VoteKind_t, round: Round_t): int =
    if (kind == PrecommitKind) {
      round + PrecommitRoundFlag
    } else {
      round
    }

  pure def VoteSignWireCanonical(vote: VoteSignWire_t): bool =
    if (vote.byteLen == 76 and vote.pubKey == TestPubKeyHex and
      vote.valueId == NilValueId and vote.height == 1 and vote.round == 0 and
      vote.voteKind == PrevoteKind and vote.roundFlag == 0) {
      vote.hex ==
        "0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f200000000000000000000000000000000000000000000000000000000000000000010000000000000000000000"
    } else if (vote.byteLen == 76 and vote.valueId == NilValueId and
      vote.height == 1 and vote.round == 0 and
      vote.voteKind == PrecommitKind and vote.roundFlag == PrecommitRoundFlag) {
      if (vote.pubKey == TestPubKeyHex) {
        vote.hex ==
          "0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f200000000000000000000000000000000000000000000000000000000000000000010000000000000000000080"
      } else if (vote.pubKey == TestPubKey2Hex) {
        vote.hex ==
          "2122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f400000000000000000000000000000000000000000000000000000000000000000010000000000000000000080"
      } else if (vote.pubKey == TestPubKey3Hex) {
        vote.hex ==
          "4142434445464748494a4b4c4d4e4f505152535455565758595a5b5c5d5e5f600000000000000000000000000000000000000000000000000000000000000000010000000000000000000080"
      } else {
        false
      }
    } else if (vote.byteLen == 76 and vote.valueId == TestValueIdHex and
      vote.height == 2 and vote.round == 1 and
      vote.voteKind == PrevoteKind and vote.roundFlag == 1) {
      if (vote.pubKey == TestPubKeyHex) {
        vote.hex ==
          "0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa020000000000000001000000"
      } else if (vote.pubKey == TestPubKey2Hex) {
        vote.hex ==
          "2122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f40aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa020000000000000001000000"
      } else if (vote.pubKey == TestPubKey3Hex) {
        vote.hex ==
          "4142434445464748494a4b4c4d4e4f505152535455565758595a5b5c5d5e5f60aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa020000000000000001000000"
      } else if (vote.pubKey == TestPubKey4Hex) {
        vote.hex ==
          "6162636465666768696a6b6c6d6e6f707172737475767778797a7b7c7d7e7f80aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa020000000000000001000000"
      } else if (vote.pubKey == TestPubKey5Hex) {
        vote.hex ==
          "8182838485868788898a8b8c8d8e8f909192939495969798999a9b9c9d9e9fa0aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa020000000000000001000000"
      } else {
        false
      }
    } else if (vote.byteLen == 76 and vote.valueId == TestValueIdHex and
      vote.height == 1 and vote.round == 0 and
      vote.voteKind == PrecommitKind and vote.roundFlag == PrecommitRoundFlag) {
      if (vote.pubKey == TestPubKeyHex) {
        vote.hex ==
          "0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa010000000000000000000080"
      } else if (vote.pubKey == TestPubKey2Hex) {
        vote.hex ==
          "2122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f40aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa010000000000000000000080"
      } else if (vote.pubKey == TestPubKey3Hex) {
        vote.hex ==
          "4142434445464748494a4b4c4d4e4f505152535455565758595a5b5c5d5e5f60aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa010000000000000000000080"
      } else {
        false
      }
    } else if (vote.byteLen == 76 and vote.pubKey == TestPubKeyHex and
      vote.valueId == TestValue2IdHex and vote.height == 1 and vote.round == 0 and
      vote.voteKind == PrecommitKind and vote.roundFlag == PrecommitRoundFlag) {
      vote.hex ==
        "0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb010000000000000000000080"
    } else {
      false
    }

  pure def FieldEndOffset(offset: int, width: int): int =
    offset + width

  pure def RosterPubKey(rosterIndex: int): PubKey_t =
    if (rosterIndex == 0) {
      TestPubKeyHex
    } else if (rosterIndex == 1) {
      TestPubKey2Hex
    } else if (rosterIndex == 2) {
      TestPubKey3Hex
    } else if (rosterIndex == 3) {
      TestPubKey4Hex
    } else if (rosterIndex == 4) {
      TestPubKey5Hex
    } else {
      "unknown-pubkey"
    }

  pure def SignatureFor(pubKey: PubKey_t, signBytes: Bytes_t): Signature_t =
    if (pubKey == TestPubKeyHex and
      signBytes != UnmodeledVoteSignWireHex) {
      TestVoteSignatureHex
    } else if (pubKey == TestPubKey2Hex and
      signBytes != UnmodeledVoteSignWireHex) {
      TestVoteSignature2Hex
    } else if (pubKey == TestPubKey3Hex and
      signBytes != UnmodeledVoteSignWireHex) {
      TestVoteSignature3Hex
    } else if (pubKey == TestPubKey4Hex and
      signBytes != UnmodeledVoteSignWireHex) {
      TestVoteSignature4Hex
    } else if (pubKey == TestPubKey5Hex and
      signBytes != UnmodeledVoteSignWireHex) {
      TestVoteSignature5Hex
    } else {
      "invalid-signature"
    }

  pure def VotePacketLayoutConstantsPinned: bool =
    PacketTypePrevoteSignatures == 8 and
    PacketTypePrecommitSignatures == 9 and
    CountByteLen == 1 and
    RoundFlagByteLen == 4 and
    HeightByteLen == 8 and
    ValueIdByteLen == 32 and
    RosterIndexByteLen == 2 and
    VoteSignatureByteLen == 64 and
    VotePacketEntryByteLen == 66 and
    VotePacketHeaderByteLen == 46 and
    NoVotesOffset == 0 and
    YesVotesOffset == 1 and
    PacketRoundOffset == 2 and
    PacketHeightOffset == 6 and
    PacketValueIdOffset == 14 and
    VoteEntriesOffset == 46 and
    MaxPacketVoteEntries == 18 and
    PacketVotesMaxSerializedByteLen == 1234 and
    PacketVotesStructByteLen == 1240 and
    PacketVotesStructPaddingBytes == 6

  pure def VotePacketFieldOffsetsContiguous: bool =
    FieldEndOffset(NoVotesOffset, CountByteLen) == YesVotesOffset and
    FieldEndOffset(YesVotesOffset, CountByteLen) == PacketRoundOffset and
    FieldEndOffset(PacketRoundOffset, RoundFlagByteLen) == PacketHeightOffset and
    FieldEndOffset(PacketHeightOffset, HeightByteLen) == PacketValueIdOffset and
    FieldEndOffset(PacketValueIdOffset, ValueIdByteLen) == VoteEntriesOffset

  pure def VotePacketWireByteLen(packet: VotePacket_t): int =
    VotePacketHeaderByteLen + (packet.noVotes + packet.yesVotes) * VotePacketEntryByteLen

  pure def PacketVoteKind(packet: VotePacket_t): VoteKind_t =
    if (packet.packetType == PacketTypePrecommitSignatures) {
      PrecommitKind
    } else {
      PrevoteKind
    }

  pure def EntryValueFor(packet: VotePacket_t, i: EntryIndex_t): ValueId_t =
    if (i < packet.noVotes) {
      NilValueId
    } else {
      packet.valueId
    }

  pure def EntryVoteSignWire(
    packet: VotePacket_t,
    entry: VotePacketEntry_t,
  ): VoteSignWire_t = {
    byteLen: VoteSignByteLen,
    pubKey: entry.pubKey,
    valueId: entry.valueId,
    height: packet.height,
    round: packet.round,
    voteKind: PacketVoteKind(packet),
    roundFlag: MergedRoundFlag(PacketVoteKind(packet), packet.round),
    hex: entry.signBytes,
  }

  pure def ActiveEntryIndexes(packet: VotePacket_t): Set[EntryIndex_t] =
    EntryIndexes.filter(i => i < packet.noVotes + packet.yesVotes)

  pure def VotePacketFieldsValid(packet: VotePacket_t): bool =
    VotePacketTypes.contains(packet.packetType) and
    packet.byteLen == VotePacketWireByteLen(packet) and
    packet.noVotes >= 0 and
    packet.yesVotes >= 0 and
    packet.noVotes + packet.yesVotes >= 1 and
    packet.noVotes + packet.yesVotes <= MaxPacketVoteEntries and
    packet.noVotes + packet.yesVotes <= EntryIndexes.size() and
    Rounds.contains(packet.round) and
    Heights.contains(packet.height) and
    VoteValues.contains(packet.valueId)

  pure def VotePacketEntryCanonical(
    packet: VotePacket_t,
    i: EntryIndex_t,
  ): bool = {
    val entry = packet.entries.get(i)
    all {
      entry.rosterIndex == i,
      entry.pubKey == RosterPubKey(entry.rosterIndex),
      entry.valueId == EntryValueFor(packet, i),
      VoteSignWireCanonical(EntryVoteSignWire(packet, entry)),
      entry.voteSignature == SignatureFor(entry.pubKey, entry.signBytes),
    }
  }

  pure def CanonicalVotePacketHex(packet: VotePacket_t): Bytes_t =
    if (packet.packetType == PacketTypePrevoteSignatures and
      packet.byteLen == 112 and packet.noVotes == 1 and packet.yesVotes == 0 and
      packet.round == 0 and packet.height == 1 and
      packet.valueId == TestValueIdHex) {
      "0100000000000100000000000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa000011111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111"
    } else if (packet.packetType == PacketTypePrevoteSignatures and
      packet.byteLen == 112 and packet.noVotes == 0 and packet.yesVotes == 1 and
      packet.round == 1 and packet.height == 2 and
      packet.valueId == TestValueIdHex) {
      "0001010000000200000000000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa000011111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111"
    } else if (packet.packetType == PacketTypePrevoteSignatures and
      packet.byteLen == 178 and packet.noVotes == 0 and packet.yesVotes == 2 and
      packet.round == 1 and packet.height == 2 and
      packet.valueId == TestValueIdHex) {
      "0002010000000200000000000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa000011111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111010022222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222"
    } else if (packet.packetType == PacketTypePrevoteSignatures and
      packet.byteLen == 244 and packet.noVotes == 0 and packet.yesVotes == 3 and
      packet.round == 1 and packet.height == 2 and
      packet.valueId == TestValueIdHex) {
      "0003010000000200000000000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa000011111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111010022222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222020033333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333"
    } else if (packet.packetType == PacketTypePrevoteSignatures and
      packet.byteLen == 376 and packet.noVotes == 0 and packet.yesVotes == 5 and
      packet.round == 1 and packet.height == 2 and
      packet.valueId == TestValueIdHex) {
      ValuePrevotePolLargePacketHex
    } else if (packet.packetType == PacketTypePrecommitSignatures and
      packet.byteLen == 112 and packet.noVotes == 1 and packet.yesVotes == 0 and
      packet.round == 0 and packet.height == 1 and
      packet.valueId == TestValueIdHex) {
      "0100000000000100000000000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa000011111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111"
    } else if (packet.packetType == PacketTypePrecommitSignatures and
      packet.byteLen == 244 and packet.noVotes == 3 and packet.yesVotes == 0 and
      packet.round == 0 and packet.height == 1 and
      packet.valueId == TestValueIdHex) {
      NilPrecommitQuorumPacketHex
    } else if (packet.packetType == PacketTypePrecommitSignatures and
      packet.byteLen == 244 and packet.noVotes == 1 and packet.yesVotes == 2 and
      packet.round == 0 and packet.height == 1 and
      packet.valueId == TestValueIdHex) {
      MixedPrecommitQuorumPacketHex
    } else if (packet.packetType == PacketTypePrecommitSignatures and
      packet.byteLen == 112 and packet.noVotes == 0 and packet.yesVotes == 1 and
      packet.round == 0 and packet.height == 1 and
      packet.valueId == TestValueIdHex) {
      "0001000000000100000000000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa000011111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111"
    } else if (packet.packetType == PacketTypePrecommitSignatures and
      packet.byteLen == 244 and packet.noVotes == 0 and packet.yesVotes == 3 and
      packet.round == 0 and packet.height == 1 and
      packet.valueId == TestValueIdHex) {
      ValuePrecommitQuorumPacketHex
    } else if (packet.packetType == PacketTypePrecommitSignatures and
      packet.byteLen == 112 and packet.noVotes == 0 and packet.yesVotes == 1 and
      packet.round == 0 and packet.height == 1 and
      packet.valueId == TestValue2IdHex) {
      "0001000000000100000000000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb000011111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111"
    } else {
      UnmodeledVotePacketHex
    }

  pure def VotePacketCanonical(packet: VotePacket_t): bool =
    VotePacketFieldsValid(packet) and
    ActiveEntryIndexes(packet).forall(i => VotePacketEntryCanonical(packet, i)) and
    CanonicalVotePacketHex(packet) != UnmodeledVotePacketHex and
    packet.hex == CanonicalVotePacketHex(packet)

  action Init = all {
    acceptedVotePackets' = Set(),
    firedAction' = "Init",
  }

  action AcceptVotePacket(packet: VotePacket_t): bool =
    all {
      VotePacketCanonical(packet),
      acceptedVotePackets' = acceptedVotePackets.union(Set(packet)),
      firedAction' = "AcceptVotePacket",
    }

  action Stutter: bool =
    all {
      acceptedVotePackets' = acceptedVotePackets,
      firedAction' = firedAction,
    }

  pure def AcceptedVotePacketsCanonical: bool =
    acceptedVotePackets.forall(VotePacketCanonical)

  val Safety =
    VotePacketLayoutConstantsPinned and
    VotePacketFieldOffsetsContiguous and
    AcceptedVotePacketsCanonical
}

module CrosslinkTenderlinkVotePacketFormatTest {
  import CrosslinkTenderlinkVotePacketFormat.* from "./CrosslinkTenderlinkVotePacketFormat"
  export CrosslinkTenderlinkVotePacketFormat.*

  def Entry(
    valueId: ValueId_t,
    signBytes: Bytes_t,
    voteSignature: Signature_t,
  ): VotePacketEntry_t =
    EntryAt(0, valueId, signBytes, voteSignature)

  def EntryAt(
    rosterIndex: int,
    valueId: ValueId_t,
    signBytes: Bytes_t,
    voteSignature: Signature_t,
  ): VotePacketEntry_t = {
    rosterIndex: rosterIndex,
    pubKey: RosterPubKey(rosterIndex),
    valueId: valueId,
    signBytes: signBytes,
    voteSignature: voteSignature,
  }

  def PacketAt(
    packetType: int,
    byteLen: int,
    noVotes: int,
    yesVotes: int,
    round: Round_t,
    height: Height_t,
    valueId: ValueId_t,
    entry: VotePacketEntry_t,
    hex: Bytes_t,
  ): VotePacket_t = {
    packetType: packetType,
    byteLen: byteLen,
    noVotes: noVotes,
    yesVotes: yesVotes,
    round: round,
    height: height,
    valueId: valueId,
    entries: Map(0 -> entry),
    hex: hex,
  }

  def Packet(
    packetType: int,
    byteLen: int,
    noVotes: int,
    yesVotes: int,
    valueId: ValueId_t,
    entry: VotePacketEntry_t,
    hex: Bytes_t,
  ): VotePacket_t =
    PacketAt(packetType, byteLen, noVotes, yesVotes, 0, 1, valueId, entry, hex)

  pure val NilPrevoteSignBytes =
    "0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f200000000000000000000000000000000000000000000000000000000000000000010000000000000000000000"

  pure val ValuePrevotePolSignBytes =
    "0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa020000000000000001000000"

  pure val ValuePrevotePolSignBytes2 =
    "2122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f40aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa020000000000000001000000"

  pure val ValuePrevotePolSignBytes3 =
    "4142434445464748494a4b4c4d4e4f505152535455565758595a5b5c5d5e5f60aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa020000000000000001000000"

  pure val ValuePrevotePolSignBytes4 =
    "6162636465666768696a6b6c6d6e6f707172737475767778797a7b7c7d7e7f80aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa020000000000000001000000"

  pure val ValuePrevotePolSignBytes5 =
    "8182838485868788898a8b8c8d8e8f909192939495969798999a9b9c9d9e9fa0aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa020000000000000001000000"

  pure val ValuePrecommitSignBytes =
    "0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa010000000000000000000080"

  pure val ValuePrecommitSignBytes2 =
    "2122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f40aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa010000000000000000000080"

  pure val ValuePrecommitSignBytes3 =
    "4142434445464748494a4b4c4d4e4f505152535455565758595a5b5c5d5e5f60aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa010000000000000000000080"

  pure val Value2PrecommitSignBytes =
    "0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb010000000000000000000080"

  pure val NilPrecommitSignBytes =
    "0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f200000000000000000000000000000000000000000000000000000000000000000010000000000000000000080"

  pure val NilPrecommitSignBytes2 =
    "2122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f400000000000000000000000000000000000000000000000000000000000000000010000000000000000000080"

  pure val NilPrecommitSignBytes3 =
    "4142434445464748494a4b4c4d4e4f505152535455565758595a5b5c5d5e5f600000000000000000000000000000000000000000000000000000000000000000010000000000000000000080"

  pure val nilPrevotePacket =
    Packet(
      PacketTypePrevoteSignatures,
      112,
      1,
      0,
      TestValueIdHex,
      Entry(NilValueId, NilPrevoteSignBytes, TestVoteSignatureHex),
      "0100000000000100000000000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa000011111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111",
    )

  pure val valuePrevotePolPacket =
    PacketAt(
      PacketTypePrevoteSignatures,
      112,
      0,
      1,
      1,
      2,
      TestValueIdHex,
      Entry(TestValueIdHex, ValuePrevotePolSignBytes, TestVoteSignatureHex),
      "0001010000000200000000000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa000011111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111",
    )

  pure val valuePrevotePolQuorumPacket: VotePacket_t = {
    packetType: PacketTypePrevoteSignatures,
    byteLen: 244,
    noVotes: 0,
    yesVotes: 3,
    round: 1,
    height: 2,
    valueId: TestValueIdHex,
    entries: Map(
      0 -> EntryAt(0, TestValueIdHex, ValuePrevotePolSignBytes, TestVoteSignatureHex),
      1 -> EntryAt(1, TestValueIdHex, ValuePrevotePolSignBytes2, TestVoteSignature2Hex),
      2 -> EntryAt(2, TestValueIdHex, ValuePrevotePolSignBytes3, TestVoteSignature3Hex),
    ),
    hex:
      "0003010000000200000000000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa000011111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111010022222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222020033333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333",
  }

  pure val valuePrevotePolWeightedPacket: VotePacket_t = {
    packetType: PacketTypePrevoteSignatures,
    byteLen: 178,
    noVotes: 0,
    yesVotes: 2,
    round: 1,
    height: 2,
    valueId: TestValueIdHex,
    entries: Map(
      0 -> EntryAt(0, TestValueIdHex, ValuePrevotePolSignBytes, TestVoteSignatureHex),
      1 -> EntryAt(1, TestValueIdHex, ValuePrevotePolSignBytes2, TestVoteSignature2Hex),
    ),
    hex:
      "0002010000000200000000000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa000011111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111010022222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222",
  }

  pure val valuePrevotePolLargePacket: VotePacket_t = {
    packetType: PacketTypePrevoteSignatures,
    byteLen: 376,
    noVotes: 0,
    yesVotes: 5,
    round: 1,
    height: 2,
    valueId: TestValueIdHex,
    entries: Map(
      0 -> EntryAt(0, TestValueIdHex, ValuePrevotePolSignBytes, TestVoteSignatureHex),
      1 -> EntryAt(1, TestValueIdHex, ValuePrevotePolSignBytes2, TestVoteSignature2Hex),
      2 -> EntryAt(2, TestValueIdHex, ValuePrevotePolSignBytes3, TestVoteSignature3Hex),
      3 -> EntryAt(3, TestValueIdHex, ValuePrevotePolSignBytes4, TestVoteSignature4Hex),
      4 -> EntryAt(4, TestValueIdHex, ValuePrevotePolSignBytes5, TestVoteSignature5Hex),
    ),
    hex: ValuePrevotePolLargePacketHex,
  }

  pure val valuePrecommitPacket =
    Packet(
      PacketTypePrecommitSignatures,
      112,
      0,
      1,
      TestValueIdHex,
      Entry(TestValueIdHex, ValuePrecommitSignBytes, TestVoteSignatureHex),
      "0001000000000100000000000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa000011111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111",
    )

  pure val valuePrecommitQuorumPacket: VotePacket_t = {
    packetType: PacketTypePrecommitSignatures,
    byteLen: 244,
    noVotes: 0,
    yesVotes: 3,
    round: 0,
    height: 1,
    valueId: TestValueIdHex,
    entries: Map(
      0 -> EntryAt(0, TestValueIdHex, ValuePrecommitSignBytes, TestVoteSignatureHex),
      1 -> EntryAt(1, TestValueIdHex, ValuePrecommitSignBytes2, TestVoteSignature2Hex),
      2 -> EntryAt(2, TestValueIdHex, ValuePrecommitSignBytes3, TestVoteSignature3Hex),
    ),
    hex: ValuePrecommitQuorumPacketHex,
  }

  pure val value2PrecommitPacket =
    Packet(
      PacketTypePrecommitSignatures,
      112,
      0,
      1,
      TestValue2IdHex,
      Entry(TestValue2IdHex, Value2PrecommitSignBytes, TestVoteSignatureHex),
      "0001000000000100000000000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb000011111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111",
    )

  pure val nilPrecommitPacket =
    Packet(
      PacketTypePrecommitSignatures,
      112,
      1,
      0,
      TestValueIdHex,
      Entry(NilValueId, NilPrecommitSignBytes, TestVoteSignatureHex),
      "0100000000000100000000000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa000011111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111",
    )

  pure val nilPrecommitQuorumPacket: VotePacket_t = {
    packetType: PacketTypePrecommitSignatures,
    byteLen: 244,
    noVotes: 3,
    yesVotes: 0,
    round: 0,
    height: 1,
    valueId: TestValueIdHex,
    entries: Map(
      0 -> EntryAt(0, NilValueId, NilPrecommitSignBytes, TestVoteSignatureHex),
      1 -> EntryAt(1, NilValueId, NilPrecommitSignBytes2, TestVoteSignature2Hex),
      2 -> EntryAt(2, NilValueId, NilPrecommitSignBytes3, TestVoteSignature3Hex),
    ),
    hex: NilPrecommitQuorumPacketHex,
  }

  pure val mixedPrecommitQuorumPacket: VotePacket_t = {
    packetType: PacketTypePrecommitSignatures,
    byteLen: 244,
    noVotes: 1,
    yesVotes: 2,
    round: 0,
    height: 1,
    valueId: TestValueIdHex,
    entries: Map(
      0 -> EntryAt(0, NilValueId, NilPrecommitSignBytes, TestVoteSignatureHex),
      1 -> EntryAt(1, TestValueIdHex, ValuePrecommitSignBytes2, TestVoteSignature2Hex),
      2 -> EntryAt(2, TestValueIdHex, ValuePrecommitSignBytes3, TestVoteSignature3Hex),
    ),
    hex: MixedPrecommitQuorumPacketHex,
  }

  pure val wrongSignBytesPacket =
    Packet(
      PacketTypePrecommitSignatures,
      112,
      0,
      1,
      TestValueIdHex,
      Entry(TestValueIdHex, NilPrevoteSignBytes, TestVoteSignatureHex),
      "0001000000000100000000000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa000011111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111",
    )

  pure val trailingBytePacket =
    Packet(
      PacketTypePrecommitSignatures,
      113,
      0,
      1,
      TestValueIdHex,
      Entry(TestValueIdHex, ValuePrecommitSignBytes, TestVoteSignatureHex),
      "0001000000000100000000000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa00001111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111100",
    )

  pure val wrongPacketType =
    Packet(
      7,
      112,
      0,
      1,
      TestValueIdHex,
      Entry(TestValueIdHex, ValuePrecommitSignBytes, TestVoteSignatureHex),
      "0001000000000100000000000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa000011111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111",
    )

  pure val TestVotePackets = Set(
    nilPrevotePacket,
    valuePrevotePolPacket,
    valuePrevotePolWeightedPacket,
    valuePrevotePolQuorumPacket,
    valuePrevotePolLargePacket,
    nilPrecommitPacket,
    nilPrecommitQuorumPacket,
    mixedPrecommitQuorumPacket,
    valuePrecommitPacket,
    valuePrecommitQuorumPacket,
    value2PrecommitPacket,
    wrongSignBytesPacket,
    trailingBytePacket,
    wrongPacketType,
  )

  action Next: bool =
    any {
      nondet packet = oneOf(TestVotePackets)
      AcceptVotePacket(packet),
      Stutter,
    }

  action unchangedAll = all {
    acceptedVotePackets' = acceptedVotePackets,
    firedAction' = firedAction,
  }

  run votePacketLayoutPinnedTest = {
    Init.then(all {
      assert(VotePacketLayoutConstantsPinned),
      assert(VotePacketFieldOffsetsContiguous),
      assert(NoVotesOffset == 0),
      assert(YesVotesOffset == 1),
      assert(PacketRoundOffset == 2),
      assert(PacketHeightOffset == 6),
      assert(PacketValueIdOffset == 14),
      assert(VoteEntriesOffset == 46),
      assert(VotePacketEntryByteLen == 66),
      unchangedAll,
    })
  }

  run votePacketExactHexVectorsTest = {
    Init.then(all {
      assert(CanonicalVotePacketHex(nilPrevotePacket) == nilPrevotePacket.hex),
      assert(CanonicalVotePacketHex(valuePrevotePolPacket) ==
        valuePrevotePolPacket.hex),
      assert(CanonicalVotePacketHex(valuePrevotePolWeightedPacket) ==
        valuePrevotePolWeightedPacket.hex),
      assert(CanonicalVotePacketHex(valuePrevotePolQuorumPacket) ==
        valuePrevotePolQuorumPacket.hex),
      assert(CanonicalVotePacketHex(valuePrevotePolLargePacket) ==
        valuePrevotePolLargePacket.hex),
      assert(CanonicalVotePacketHex(nilPrecommitPacket) ==
        nilPrecommitPacket.hex),
      assert(CanonicalVotePacketHex(nilPrecommitQuorumPacket) ==
        nilPrecommitQuorumPacket.hex),
      assert(CanonicalVotePacketHex(mixedPrecommitQuorumPacket) ==
        mixedPrecommitQuorumPacket.hex),
      assert(CanonicalVotePacketHex(valuePrecommitPacket) ==
        valuePrecommitPacket.hex),
      assert(CanonicalVotePacketHex(valuePrecommitQuorumPacket) ==
        valuePrecommitQuorumPacket.hex),
      assert(CanonicalVotePacketHex(value2PrecommitPacket) ==
        value2PrecommitPacket.hex),
      assert(VotePacketWireByteLen(nilPrevotePacket) == 112),
      assert(VotePacketWireByteLen(valuePrevotePolWeightedPacket) == 178),
      assert(VotePacketWireByteLen(valuePrevotePolQuorumPacket) == 244),
      assert(VotePacketWireByteLen(valuePrevotePolLargePacket) == 376),
      assert(VotePacketWireByteLen(nilPrecommitQuorumPacket) == 244),
      assert(VotePacketWireByteLen(mixedPrecommitQuorumPacket) == 244),
      assert(VotePacketWireByteLen(valuePrecommitQuorumPacket) == 244),
      assert(PacketVotesStructPaddingBytes == 6),
      unchangedAll,
    })
  }

  run votePacketEntriesReconstructCanonicalSignBytesTest = {
    Init.then(all {
      assert(VotePacketEntryCanonical(nilPrevotePacket, 0)),
      assert(VotePacketEntryCanonical(valuePrevotePolPacket, 0)),
      assert(VotePacketEntryCanonical(valuePrevotePolWeightedPacket, 0)),
      assert(VotePacketEntryCanonical(valuePrevotePolWeightedPacket, 1)),
      assert(VotePacketEntryCanonical(valuePrevotePolQuorumPacket, 0)),
      assert(VotePacketEntryCanonical(valuePrevotePolQuorumPacket, 1)),
      assert(VotePacketEntryCanonical(valuePrevotePolQuorumPacket, 2)),
      assert(VotePacketEntryCanonical(valuePrevotePolLargePacket, 0)),
      assert(VotePacketEntryCanonical(valuePrevotePolLargePacket, 1)),
      assert(VotePacketEntryCanonical(valuePrevotePolLargePacket, 2)),
      assert(VotePacketEntryCanonical(valuePrevotePolLargePacket, 3)),
      assert(VotePacketEntryCanonical(valuePrevotePolLargePacket, 4)),
      assert(VotePacketEntryCanonical(nilPrecommitPacket, 0)),
      assert(VotePacketEntryCanonical(nilPrecommitQuorumPacket, 0)),
      assert(VotePacketEntryCanonical(nilPrecommitQuorumPacket, 1)),
      assert(VotePacketEntryCanonical(nilPrecommitQuorumPacket, 2)),
      assert(VotePacketEntryCanonical(mixedPrecommitQuorumPacket, 0)),
      assert(VotePacketEntryCanonical(mixedPrecommitQuorumPacket, 1)),
      assert(VotePacketEntryCanonical(mixedPrecommitQuorumPacket, 2)),
      assert(VotePacketEntryCanonical(valuePrecommitPacket, 0)),
      assert(VotePacketEntryCanonical(valuePrecommitQuorumPacket, 0)),
      assert(VotePacketEntryCanonical(valuePrecommitQuorumPacket, 1)),
      assert(VotePacketEntryCanonical(valuePrecommitQuorumPacket, 2)),
      assert(VotePacketEntryCanonical(value2PrecommitPacket, 0)),
      assert(EntryValueFor(nilPrevotePacket, 0) == NilValueId),
      assert(EntryValueFor(valuePrevotePolPacket, 0) == TestValueIdHex),
      assert(EntryValueFor(valuePrevotePolWeightedPacket, 1) == TestValueIdHex),
      assert(EntryValueFor(valuePrevotePolQuorumPacket, 2) == TestValueIdHex),
      assert(EntryValueFor(valuePrevotePolLargePacket, 4) == TestValueIdHex),
      assert(EntryValueFor(nilPrecommitQuorumPacket, 2) == NilValueId),
      assert(EntryValueFor(mixedPrecommitQuorumPacket, 0) == NilValueId),
      assert(EntryValueFor(mixedPrecommitQuorumPacket, 1) == TestValueIdHex),
      assert(EntryValueFor(mixedPrecommitQuorumPacket, 2) == TestValueIdHex),
      assert(EntryValueFor(valuePrecommitPacket, 0) == TestValueIdHex),
      assert(EntryValueFor(valuePrecommitQuorumPacket, 2) == TestValueIdHex),
      assert(EntryValueFor(value2PrecommitPacket, 0) == TestValue2IdHex),
      unchangedAll,
    })
  }

  run acceptVotePacketsTest = {
    Init
      .then(AcceptVotePacket(nilPrevotePacket))
      .then(AcceptVotePacket(valuePrevotePolPacket))
      .then(AcceptVotePacket(valuePrevotePolWeightedPacket))
      .then(AcceptVotePacket(valuePrevotePolQuorumPacket))
      .then(AcceptVotePacket(valuePrevotePolLargePacket))
      .then(AcceptVotePacket(nilPrecommitPacket))
      .then(AcceptVotePacket(nilPrecommitQuorumPacket))
      .then(AcceptVotePacket(mixedPrecommitQuorumPacket))
      .then(AcceptVotePacket(valuePrecommitPacket))
      .then(AcceptVotePacket(valuePrecommitQuorumPacket))
      .then(AcceptVotePacket(value2PrecommitPacket))
      .then(all {
        assert(acceptedVotePackets.contains(nilPrevotePacket)),
        assert(acceptedVotePackets.contains(valuePrevotePolPacket)),
        assert(acceptedVotePackets.contains(valuePrevotePolWeightedPacket)),
        assert(acceptedVotePackets.contains(valuePrevotePolQuorumPacket)),
        assert(acceptedVotePackets.contains(valuePrevotePolLargePacket)),
        assert(acceptedVotePackets.contains(nilPrecommitPacket)),
        assert(acceptedVotePackets.contains(nilPrecommitQuorumPacket)),
        assert(acceptedVotePackets.contains(mixedPrecommitQuorumPacket)),
        assert(acceptedVotePackets.contains(valuePrecommitPacket)),
        assert(acceptedVotePackets.contains(valuePrecommitQuorumPacket)),
        assert(acceptedVotePackets.contains(value2PrecommitPacket)),
        assert(Safety),
        unchangedAll,
      })
  }

  run wrongSignBytesRejectedTest = {
    Init.then(AcceptVotePacket(wrongSignBytesPacket)).fail()
  }

  run trailingByteVotePacketRejectedTest = {
    Init.then(AcceptVotePacket(trailingBytePacket)).fail()
  }

  run wrongPacketTypeRejectedTest = {
    Init.then(AcceptVotePacket(wrongPacketType)).fail()
  }

  run votePacketSafetyTest = {
    Init.then(all {
      assert(Safety),
      unchangedAll,
    })
  }
}

module CrosslinkTenderlinkVotePacketFormatModel {
  import CrosslinkTenderlinkVotePacketFormatTest.* from "./CrosslinkTenderlinkVotePacketFormat"
  export CrosslinkTenderlinkVotePacketFormatTest.*
}
