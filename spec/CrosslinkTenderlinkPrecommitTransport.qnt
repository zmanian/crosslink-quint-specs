module CrosslinkTenderlinkPrecommitTransport {
  /*
   Tenderlink precommit transport bridge.

   CrosslinkTenderlinkVotePacketFormat.qnt pins PacketVotes payloads and
   CrosslinkTenderlinkConsensusPacketFormat.qnt pins the compact consensus
   packet envelope around those payloads. This slice adds the adjacent
   decrypted transport receipt for ordinary nil/value precommit packets.

   In the nil-precommit resampling rule, a single nil precommit is only a
   message. It becomes unlock evidence only when a transported precommit batch
   itself carries quorum voting power for nil. A mixed or low-power precommit
   batch is intentionally not accepted as certificate evidence here.
   */

  import CrosslinkTenderlinkVotePacketFormat as VotePacketFormat from
    "./CrosslinkTenderlinkVotePacketFormat"
  import CrosslinkTenderlinkConsensusPacketFormat as ConsensusPacketFormat from
    "./CrosslinkTenderlinkConsensusPacketFormat"

  type Bytes_t = str
  type TransportEnvelope_t = {
    decrypted: bool,
    nonce: int,
    noncePrefixHex: Bytes_t,
    packetType: int,
    payloadByteLen: int,
    byteLen: int,
    payloadHex: Bytes_t,
    packetHex: Bytes_t,
  }

  pure val FixtureQuorumVotingPower = 3
  pure val UnmodeledTransportPacketHex = "unmodeled-precommit-transport-packet"
  pure val UnmodeledNoncePrefixHex = "unmodeled-precommit-nonce-prefix"

  pure val NilPrecommitConsensusPacketHex =
    "090000000000000000000000000000000100000000000100000000000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa000011111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111"
  pure val ValuePrecommitConsensusPacketHex =
    "090000000000000000000000000000000001000000000100000000000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa000011111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111"
  pure val NilPrecommitQuorumConsensusPacketHex =
    ConsensusPacketFormat::TestNilPrecommitQuorumConsensusPacketHex
  pure val MixedPrecommitQuorumConsensusPacketHex =
    ConsensusPacketFormat::TestMixedPrecommitQuorumConsensusPacketHex
  pure val ValuePrecommitQuorumConsensusPacketHex =
    ConsensusPacketFormat::TestPrecommitQuorumConsensusPacketHex

  pure val NilPrevoteSignBytes =
    "0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f200000000000000000000000000000000000000000000000000000000000000000010000000000000000000000"
  pure val ValuePrecommitSignBytes =
    "0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa010000000000000000000080"
  pure val ValuePrecommitSignBytes2 =
    "2122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f40aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa010000000000000000000080"
  pure val ValuePrecommitSignBytes3 =
    "4142434445464748494a4b4c4d4e4f505152535455565758595a5b5c5d5e5f60aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa010000000000000000000080"
  pure val NilPrecommitSignBytes =
    "0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f200000000000000000000000000000000000000000000000000000000000000000010000000000000000000080"
  pure val NilPrecommitSignBytes2 =
    "2122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f400000000000000000000000000000000000000000000000000000000000000000010000000000000000000080"
  pure val NilPrecommitSignBytes3 =
    "4142434445464748494a4b4c4d4e4f505152535455565758595a5b5c5d5e5f600000000000000000000000000000000000000000000000000000000000000000010000000000000000000080"

  def EntryAt(
    rosterIndex: int,
    valueId: VotePacketFormat::ValueId_t,
    signBytes: Bytes_t,
    voteSignature: VotePacketFormat::Signature_t,
  ): VotePacketFormat::VotePacketEntry_t = {
    rosterIndex: rosterIndex,
    pubKey: VotePacketFormat::RosterPubKey(rosterIndex),
    valueId: valueId,
    signBytes: signBytes,
    voteSignature: voteSignature,
  }

  def Entry(
    valueId: VotePacketFormat::ValueId_t,
    signBytes: Bytes_t,
    voteSignature: VotePacketFormat::Signature_t,
  ): VotePacketFormat::VotePacketEntry_t =
    EntryAt(0, valueId, signBytes, voteSignature)

  def PacketAt(
    packetType: int,
    byteLen: int,
    noVotes: int,
    yesVotes: int,
    round: VotePacketFormat::Round_t,
    height: VotePacketFormat::Height_t,
    valueId: VotePacketFormat::ValueId_t,
    entry: VotePacketFormat::VotePacketEntry_t,
    hex: Bytes_t,
  ): VotePacketFormat::VotePacket_t = {
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
    valueId: VotePacketFormat::ValueId_t,
    entry: VotePacketFormat::VotePacketEntry_t,
    hex: Bytes_t,
  ): VotePacketFormat::VotePacket_t =
    PacketAt(packetType, byteLen, noVotes, yesVotes, 0, 1, valueId, entry, hex)

  pure val NilPrevotePacket =
    Packet(
      VotePacketFormat::PacketTypePrevoteSignatures,
      112,
      1,
      0,
      VotePacketFormat::TestValueIdHex,
      Entry(
        VotePacketFormat::NilValueId,
        NilPrevoteSignBytes,
        VotePacketFormat::TestVoteSignatureHex,
      ),
      "0100000000000100000000000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa000011111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111",
    )

  pure val NilPrecommitPacket =
    Packet(
      VotePacketFormat::PacketTypePrecommitSignatures,
      112,
      1,
      0,
      VotePacketFormat::TestValueIdHex,
      Entry(
        VotePacketFormat::NilValueId,
        NilPrecommitSignBytes,
        VotePacketFormat::TestVoteSignatureHex,
      ),
      "0100000000000100000000000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa000011111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111",
    )

  pure val ValuePrecommitPacket =
    Packet(
      VotePacketFormat::PacketTypePrecommitSignatures,
      112,
      0,
      1,
      VotePacketFormat::TestValueIdHex,
      Entry(
        VotePacketFormat::TestValueIdHex,
        ValuePrecommitSignBytes,
        VotePacketFormat::TestVoteSignatureHex,
      ),
      "0001000000000100000000000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa000011111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111",
    )

  pure val NilPrecommitQuorumPacket: VotePacketFormat::VotePacket_t = {
    packetType: VotePacketFormat::PacketTypePrecommitSignatures,
    byteLen: 244,
    noVotes: 3,
    yesVotes: 0,
    round: 0,
    height: 1,
    valueId: VotePacketFormat::TestValueIdHex,
    entries: Map(
      0 -> EntryAt(
        0,
        VotePacketFormat::NilValueId,
        NilPrecommitSignBytes,
        VotePacketFormat::TestVoteSignatureHex,
      ),
      1 -> EntryAt(
        1,
        VotePacketFormat::NilValueId,
        NilPrecommitSignBytes2,
        VotePacketFormat::TestVoteSignature2Hex,
      ),
      2 -> EntryAt(
        2,
        VotePacketFormat::NilValueId,
        NilPrecommitSignBytes3,
        VotePacketFormat::TestVoteSignature3Hex,
      ),
    ),
    hex: VotePacketFormat::NilPrecommitQuorumPacketHex,
  }

  pure val MixedPrecommitQuorumPacket: VotePacketFormat::VotePacket_t = {
    packetType: VotePacketFormat::PacketTypePrecommitSignatures,
    byteLen: 244,
    noVotes: 1,
    yesVotes: 2,
    round: 0,
    height: 1,
    valueId: VotePacketFormat::TestValueIdHex,
    entries: Map(
      0 -> EntryAt(
        0,
        VotePacketFormat::NilValueId,
        NilPrecommitSignBytes,
        VotePacketFormat::TestVoteSignatureHex,
      ),
      1 -> EntryAt(
        1,
        VotePacketFormat::TestValueIdHex,
        ValuePrecommitSignBytes2,
        VotePacketFormat::TestVoteSignature2Hex,
      ),
      2 -> EntryAt(
        2,
        VotePacketFormat::TestValueIdHex,
        ValuePrecommitSignBytes3,
        VotePacketFormat::TestVoteSignature3Hex,
      ),
    ),
    hex: VotePacketFormat::MixedPrecommitQuorumPacketHex,
  }

  pure val ValuePrecommitQuorumPacket: VotePacketFormat::VotePacket_t = {
    packetType: VotePacketFormat::PacketTypePrecommitSignatures,
    byteLen: 244,
    noVotes: 0,
    yesVotes: 3,
    round: 0,
    height: 1,
    valueId: VotePacketFormat::TestValueIdHex,
    entries: Map(
      0 -> EntryAt(
        0,
        VotePacketFormat::TestValueIdHex,
        ValuePrecommitSignBytes,
        VotePacketFormat::TestVoteSignatureHex,
      ),
      1 -> EntryAt(
        1,
        VotePacketFormat::TestValueIdHex,
        ValuePrecommitSignBytes2,
        VotePacketFormat::TestVoteSignature2Hex,
      ),
      2 -> EntryAt(
        2,
        VotePacketFormat::TestValueIdHex,
        ValuePrecommitSignBytes3,
        VotePacketFormat::TestVoteSignature3Hex,
      ),
    ),
    hex: VotePacketFormat::ValuePrecommitQuorumPacketHex,
  }

  pure val WrongSignBytesPacket =
    Packet(
      VotePacketFormat::PacketTypePrecommitSignatures,
      112,
      0,
      1,
      VotePacketFormat::TestValueIdHex,
      Entry(
        VotePacketFormat::TestValueIdHex,
        NilPrevoteSignBytes,
        VotePacketFormat::TestVoteSignatureHex,
      ),
      "0001000000000100000000000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa000011111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111",
    )

  var transportedPrecommitPackets: Set[VotePacketFormat::VotePacket_t]
  var acceptedNilPrecommitCertificates: Set[VotePacketFormat::VotePacket_t]
  var acceptedValuePrecommitCertificates: Set[VotePacketFormat::VotePacket_t]
  var precommitTransportFiredAction: str

  pure def NoncePrefixHex(nonce: int): Bytes_t =
    if (nonce == 130) {
      "8200000000000000"
    } else if (nonce == 131) {
      "8300000000000000"
    } else if (nonce == 132) {
      "8400000000000000"
    } else if (nonce == 133) {
      "8500000000000000"
    } else if (nonce == 134) {
      "8600000000000000"
    } else {
      UnmodeledNoncePrefixHex
    }

  pure def PrecommitTransportPacketHex(
    packet: VotePacketFormat::VotePacket_t,
  ): Bytes_t =
    if (packet.hex == NilPrecommitPacket.hex) {
      NilPrecommitConsensusPacketHex
    } else if (packet.hex == ValuePrecommitPacket.hex) {
      ValuePrecommitConsensusPacketHex
    } else if (packet.hex == NilPrecommitQuorumPacket.hex) {
      NilPrecommitQuorumConsensusPacketHex
    } else if (packet.hex == MixedPrecommitQuorumPacket.hex) {
      MixedPrecommitQuorumConsensusPacketHex
    } else if (packet.hex == ValuePrecommitQuorumPacket.hex) {
      ValuePrecommitQuorumConsensusPacketHex
    } else {
      UnmodeledTransportPacketHex
    }

  pure def PrecommitTransportEnvelopeValid(
    env: TransportEnvelope_t,
    packet: VotePacketFormat::VotePacket_t,
  ): bool =
    env.decrypted and
    env.noncePrefixHex == NoncePrefixHex(env.nonce) and
    env.noncePrefixHex != UnmodeledNoncePrefixHex and
    env.packetType == ConsensusPacketFormat::PacketTypePrecommitSignatures and
    VotePacketFormat::VotePacketCanonical(packet) and
    packet.packetType == ConsensusPacketFormat::PacketTypePrecommitSignatures and
    env.payloadByteLen == packet.byteLen and
    env.byteLen == ConsensusPacketFormat::PacketHeaderByteLen + packet.byteLen and
    env.payloadHex == packet.hex and
    PrecommitTransportPacketHex(packet) != UnmodeledTransportPacketHex and
    env.packetHex == PrecommitTransportPacketHex(packet)

  pure def NilPrecommitCertificatePacket(
    packet: VotePacketFormat::VotePacket_t,
  ): bool =
    VotePacketFormat::VotePacketCanonical(packet) and
    packet.packetType == ConsensusPacketFormat::PacketTypePrecommitSignatures and
    packet.noVotes >= FixtureQuorumVotingPower and
    packet.yesVotes == 0

  pure def ValuePrecommitCertificatePacket(
    packet: VotePacketFormat::VotePacket_t,
  ): bool =
    VotePacketFormat::VotePacketCanonical(packet) and
    packet.packetType == ConsensusPacketFormat::PacketTypePrecommitSignatures and
    packet.noVotes == 0 and
    packet.yesVotes >= FixtureQuorumVotingPower

  action PrecommitTransportInit = all {
    transportedPrecommitPackets' = Set(),
    acceptedNilPrecommitCertificates' = Set(),
    acceptedValuePrecommitCertificates' = Set(),
    precommitTransportFiredAction' = "PrecommitTransportInit",
  }

  action ReceivePrecommitTransport(
    env: TransportEnvelope_t,
    packet: VotePacketFormat::VotePacket_t,
  ): bool =
    all {
      PrecommitTransportEnvelopeValid(env, packet),
      transportedPrecommitPackets' =
        transportedPrecommitPackets.union(Set(packet)),
      acceptedNilPrecommitCertificates' = acceptedNilPrecommitCertificates,
      acceptedValuePrecommitCertificates' = acceptedValuePrecommitCertificates,
      precommitTransportFiredAction' = "ReceivePrecommitTransport",
    }

  action AcceptNilPrecommitCertificate(
    packet: VotePacketFormat::VotePacket_t,
  ): bool =
    all {
      transportedPrecommitPackets.contains(packet),
      NilPrecommitCertificatePacket(packet),
      transportedPrecommitPackets' = transportedPrecommitPackets,
      acceptedNilPrecommitCertificates' =
        acceptedNilPrecommitCertificates.union(Set(packet)),
      acceptedValuePrecommitCertificates' = acceptedValuePrecommitCertificates,
      precommitTransportFiredAction' = "AcceptNilPrecommitCertificate",
    }

  action AcceptValuePrecommitCertificate(
    packet: VotePacketFormat::VotePacket_t,
  ): bool =
    all {
      transportedPrecommitPackets.contains(packet),
      ValuePrecommitCertificatePacket(packet),
      transportedPrecommitPackets' = transportedPrecommitPackets,
      acceptedNilPrecommitCertificates' = acceptedNilPrecommitCertificates,
      acceptedValuePrecommitCertificates' =
        acceptedValuePrecommitCertificates.union(Set(packet)),
      precommitTransportFiredAction' = "AcceptValuePrecommitCertificate",
    }

  action PrecommitTransportStutter: bool =
    all {
      transportedPrecommitPackets' = transportedPrecommitPackets,
      acceptedNilPrecommitCertificates' = acceptedNilPrecommitCertificates,
      acceptedValuePrecommitCertificates' = acceptedValuePrecommitCertificates,
      precommitTransportFiredAction' = precommitTransportFiredAction,
    }

  pure def TransportedPrecommitPacketsCanonical: bool =
    transportedPrecommitPackets.forall(packet =>
      PrecommitTransportPacketHex(packet) != UnmodeledTransportPacketHex and
      VotePacketFormat::VotePacketCanonical(packet) and
      packet.packetType == ConsensusPacketFormat::PacketTypePrecommitSignatures
    )

  pure def AcceptedNilCertificatesTransported: bool =
    acceptedNilPrecommitCertificates.forall(packet =>
      transportedPrecommitPackets.contains(packet) and
      NilPrecommitCertificatePacket(packet)
    )

  pure def AcceptedValueCertificatesTransported: bool =
    acceptedValuePrecommitCertificates.forall(packet =>
      transportedPrecommitPackets.contains(packet) and
      ValuePrecommitCertificatePacket(packet)
    )

  val PrecommitTransportSafety =
    ConsensusPacketFormat::PacketHeaderByteLen == 16 and
    ConsensusPacketFormat::PacketTypePrecommitSignatures == 9 and
    TransportedPrecommitPacketsCanonical and
    AcceptedNilCertificatesTransported and
    AcceptedValueCertificatesTransported
}

module CrosslinkTenderlinkPrecommitTransportTest {
  import CrosslinkTenderlinkPrecommitTransport.* from
    "./CrosslinkTenderlinkPrecommitTransport"
  export CrosslinkTenderlinkPrecommitTransport.*
  import CrosslinkTenderlinkConsensusPacketFormat as ConsensusPacketFormat from
    "./CrosslinkTenderlinkConsensusPacketFormat"

  def Env(
    decrypted: bool,
    nonce: int,
    noncePrefixHex: Bytes_t,
    packetType: int,
    payloadByteLen: int,
    byteLen: int,
    payloadHex: Bytes_t,
    packetHex: Bytes_t,
  ): TransportEnvelope_t = {
    decrypted: decrypted,
    nonce: nonce,
    noncePrefixHex: noncePrefixHex,
    packetType: packetType,
    payloadByteLen: payloadByteLen,
    byteLen: byteLen,
    payloadHex: payloadHex,
    packetHex: packetHex,
  }

  pure val nilPrecommitEnvelope =
    Env(
      true,
      130,
      "8200000000000000",
      ConsensusPacketFormat::PacketTypePrecommitSignatures,
      NilPrecommitPacket.byteLen,
      128,
      NilPrecommitPacket.hex,
      NilPrecommitConsensusPacketHex,
    )

  pure val valuePrecommitEnvelope =
    Env(
      true,
      131,
      "8300000000000000",
      ConsensusPacketFormat::PacketTypePrecommitSignatures,
      ValuePrecommitPacket.byteLen,
      128,
      ValuePrecommitPacket.hex,
      ValuePrecommitConsensusPacketHex,
    )

  pure val nilPrecommitQuorumEnvelope =
    Env(
      true,
      132,
      "8400000000000000",
      ConsensusPacketFormat::PacketTypePrecommitSignatures,
      NilPrecommitQuorumPacket.byteLen,
      260,
      NilPrecommitQuorumPacket.hex,
      NilPrecommitQuorumConsensusPacketHex,
    )

  pure val mixedPrecommitQuorumEnvelope =
    Env(
      true,
      133,
      "8500000000000000",
      ConsensusPacketFormat::PacketTypePrecommitSignatures,
      MixedPrecommitQuorumPacket.byteLen,
      260,
      MixedPrecommitQuorumPacket.hex,
      MixedPrecommitQuorumConsensusPacketHex,
    )

  pure val valuePrecommitQuorumEnvelope =
    Env(
      true,
      134,
      "8600000000000000",
      ConsensusPacketFormat::PacketTypePrecommitSignatures,
      ValuePrecommitQuorumPacket.byteLen,
      260,
      ValuePrecommitQuorumPacket.hex,
      ValuePrecommitQuorumConsensusPacketHex,
    )

  pure val wrongTypePrecommitEnvelope =
    Env(
      true,
      130,
      "8200000000000000",
      ConsensusPacketFormat::PacketTypePrevoteSignatures,
      ValuePrecommitPacket.byteLen,
      128,
      ValuePrecommitPacket.hex,
      ValuePrecommitConsensusPacketHex,
    )

  pure val wrongPayloadPrecommitEnvelope =
    Env(
      true,
      131,
      "8300000000000000",
      ConsensusPacketFormat::PacketTypePrecommitSignatures,
      ValuePrecommitPacket.byteLen,
      128,
      NilPrecommitPacket.hex,
      ValuePrecommitConsensusPacketHex,
    )

  pure val wrongPacketHexPrecommitEnvelope =
    Env(
      true,
      131,
      "8300000000000000",
      ConsensusPacketFormat::PacketTypePrecommitSignatures,
      ValuePrecommitPacket.byteLen,
      128,
      ValuePrecommitPacket.hex,
      "wrong-precommit-consensus-packet-hex",
    )

  pure val failedDecryptPrecommitEnvelope =
    Env(
      false,
      131,
      "8300000000000000",
      ConsensusPacketFormat::PacketTypePrecommitSignatures,
      ValuePrecommitPacket.byteLen,
      128,
      ValuePrecommitPacket.hex,
      ValuePrecommitConsensusPacketHex,
    )

  pure val TestEnvelopes = Set(
    nilPrecommitEnvelope,
    valuePrecommitEnvelope,
    nilPrecommitQuorumEnvelope,
    mixedPrecommitQuorumEnvelope,
    valuePrecommitQuorumEnvelope,
    wrongTypePrecommitEnvelope,
    wrongPayloadPrecommitEnvelope,
    wrongPacketHexPrecommitEnvelope,
    failedDecryptPrecommitEnvelope,
  )

  pure val TestPackets = Set(
    NilPrecommitPacket,
    ValuePrecommitPacket,
    NilPrecommitQuorumPacket,
    MixedPrecommitQuorumPacket,
    ValuePrecommitQuorumPacket,
    WrongSignBytesPacket,
    NilPrevotePacket,
  )

  action PrecommitTransportNext: bool =
    any {
      nondet env = oneOf(TestEnvelopes)
      nondet packet = oneOf(TestPackets)
      ReceivePrecommitTransport(env, packet),
      nondet packet = oneOf(TestPackets)
      AcceptNilPrecommitCertificate(packet),
      nondet packet = oneOf(TestPackets)
      AcceptValuePrecommitCertificate(packet),
      PrecommitTransportStutter,
    }

  action precommitTransportUnchangedAll = all {
    transportedPrecommitPackets' = transportedPrecommitPackets,
    acceptedNilPrecommitCertificates' = acceptedNilPrecommitCertificates,
    acceptedValuePrecommitCertificates' = acceptedValuePrecommitCertificates,
    precommitTransportFiredAction' = precommitTransportFiredAction,
  }

  run receivesNilAndValuePrecommitPacketsTest = {
    PrecommitTransportInit
      .then(ReceivePrecommitTransport(
        nilPrecommitEnvelope,
        NilPrecommitPacket,
      ))
      .then(ReceivePrecommitTransport(
        valuePrecommitEnvelope,
        ValuePrecommitPacket,
      ))
      .then(all {
        assert(transportedPrecommitPackets.contains(NilPrecommitPacket)),
        assert(transportedPrecommitPackets.contains(ValuePrecommitPacket)),
        assert(PrecommitTransportSafety),
        precommitTransportUnchangedAll,
      })
  }

  run acceptsNilPrecommitCertificateOnlyAfterTransportTest = {
    PrecommitTransportInit
      .then(ReceivePrecommitTransport(
        nilPrecommitQuorumEnvelope,
        NilPrecommitQuorumPacket,
      ))
      .then(AcceptNilPrecommitCertificate(NilPrecommitQuorumPacket))
      .then(all {
        assert(acceptedNilPrecommitCertificates.contains(NilPrecommitQuorumPacket)),
        assert(PrecommitTransportSafety),
        precommitTransportUnchangedAll,
      })
  }

  run acceptsValuePrecommitCertificateOnlyAfterTransportTest = {
    PrecommitTransportInit
      .then(ReceivePrecommitTransport(
        valuePrecommitQuorumEnvelope,
        ValuePrecommitQuorumPacket,
      ))
      .then(AcceptValuePrecommitCertificate(ValuePrecommitQuorumPacket))
      .then(all {
        assert(acceptedValuePrecommitCertificates.contains(
          ValuePrecommitQuorumPacket
        )),
        assert(PrecommitTransportSafety),
        precommitTransportUnchangedAll,
      })
  }

  run missingTransportNilCertificateRejectedTest = {
    PrecommitTransportInit
      .then(AcceptNilPrecommitCertificate(NilPrecommitQuorumPacket))
      .fail()
  }

  run missingTransportValueCertificateRejectedTest = {
    PrecommitTransportInit
      .then(AcceptValuePrecommitCertificate(ValuePrecommitQuorumPacket))
      .fail()
  }

  run lowPowerNilPrecommitDoesNotUnlockTest = {
    PrecommitTransportInit
      .then(ReceivePrecommitTransport(
        nilPrecommitEnvelope,
        NilPrecommitPacket,
      ))
      .then(AcceptNilPrecommitCertificate(NilPrecommitPacket))
      .fail()
  }

  run lowPowerValuePrecommitDoesNotCertifyTest = {
    PrecommitTransportInit
      .then(ReceivePrecommitTransport(
        valuePrecommitEnvelope,
        ValuePrecommitPacket,
      ))
      .then(AcceptValuePrecommitCertificate(ValuePrecommitPacket))
      .fail()
  }

  run mixedPrecommitQuorumDoesNotUnlockTest = {
    PrecommitTransportInit
      .then(ReceivePrecommitTransport(
        mixedPrecommitQuorumEnvelope,
        MixedPrecommitQuorumPacket,
      ))
      .then(AcceptNilPrecommitCertificate(MixedPrecommitQuorumPacket))
      .fail()
  }

  run mixedPrecommitQuorumDoesNotCommitTest = {
    PrecommitTransportInit
      .then(ReceivePrecommitTransport(
        mixedPrecommitQuorumEnvelope,
        MixedPrecommitQuorumPacket,
      ))
      .then(AcceptValuePrecommitCertificate(MixedPrecommitQuorumPacket))
      .fail()
  }

  run wrongTypePrecommitTransportRejectedTest = {
    PrecommitTransportInit
      .then(ReceivePrecommitTransport(
        wrongTypePrecommitEnvelope,
        ValuePrecommitPacket,
      ))
      .fail()
  }

  run wrongPayloadPrecommitTransportRejectedTest = {
    PrecommitTransportInit
      .then(ReceivePrecommitTransport(
        wrongPayloadPrecommitEnvelope,
        ValuePrecommitPacket,
      ))
      .fail()
  }

  run wrongPacketHexPrecommitTransportRejectedTest = {
    PrecommitTransportInit
      .then(ReceivePrecommitTransport(
        wrongPacketHexPrecommitEnvelope,
        ValuePrecommitPacket,
      ))
      .fail()
  }

  run failedDecryptPrecommitTransportRejectedTest = {
    PrecommitTransportInit
      .then(ReceivePrecommitTransport(
        failedDecryptPrecommitEnvelope,
        ValuePrecommitPacket,
      ))
      .fail()
  }

  run prevotePacketRejectedAsPrecommitTransportTest = {
    PrecommitTransportInit
      .then(ReceivePrecommitTransport(
        nilPrecommitEnvelope,
        NilPrevotePacket,
      ))
      .fail()
  }

  run precommitTransportSafetyTest = {
    PrecommitTransportInit.then(all {
      assert(PrecommitTransportSafety),
      precommitTransportUnchangedAll,
    })
  }
}

module CrosslinkTenderlinkPrecommitTransportModel {
  import CrosslinkTenderlinkPrecommitTransportTest.* from
    "./CrosslinkTenderlinkPrecommitTransport"
  export CrosslinkTenderlinkPrecommitTransportTest.*
}
