module CrosslinkTenderlinkPrecommitTransportSafety {
  /*
   Verifier-friendly Tenderlink precommit transport safety slice.

   CrosslinkTenderlinkPrecommitTransport.qnt imports the production-shaped
   vote-packet format and pins exact compact consensus packet bytes. Quint's
   Apalache flattener currently struggles with that imported fixture graph, so
   this direct slice keeps the same transport/certificate boundary in a compact
   state machine: precommit packets may be transported only through exact
   decrypted consensus-topic envelopes, and nil/value certificate evidence is
   accepted only for non-mixed quorum precommit batches.
   */

  type Bytes_t = str
  type PrecommitKind_t = str
  type PrecommitPacket_t = {
    kind: PrecommitKind_t,
    packetType: int,
    noVotes: int,
    yesVotes: int,
    payloadByteLen: int,
    payloadHex: Bytes_t,
    consensusPacketHex: Bytes_t,
  }
  type TransportEnvelope_t = {
    decrypted: bool,
    nonce: int,
    noncePrefixHex: Bytes_t,
    topic: str,
    packetType: int,
    payloadByteLen: int,
    byteLen: int,
    payloadHex: Bytes_t,
    packetHex: Bytes_t,
  }

  pure val CrosslinkConsensusTopic = "crosslink-consensus-v1"
  pure val WrongTopic = "zcash-blocks-v1"
  pure val PacketTypePrecommitSignatures = 9
  pure val PacketTypePrevoteSignatures = 8
  pure val PacketHeaderByteLen = 16
  pure val FixtureQuorumVotingPower = 3

  pure val NilPrecommitKind = "nil-precommit"
  pure val ValuePrecommitKind = "value-precommit"
  pure val NilPrecommitCertificateKind = "nil-precommit-certificate"
  pure val ValuePrecommitCertificateKind = "value-precommit-certificate"
  pure val MixedPrecommitQuorumKind = "mixed-precommit-quorum"
  pure val WrongKind = "prevote"

  pure val NilPrecommitPacketHex =
    "0100000000000100000000000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa000011111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111"
  pure val ValuePrecommitPacketHex =
    "0001000000000100000000000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa000011111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111"
  pure val NilPrecommitQuorumPacketHex =
    "0300000000000100000000000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa000011111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111010022222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222020033333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333"
  pure val MixedPrecommitQuorumPacketHex =
    "0102000000000100000000000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa000011111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111010022222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222020033333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333"
  pure val ValuePrecommitQuorumPacketHex =
    "0003000000000100000000000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa000011111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111010022222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222020033333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333"

  pure val NilPrecommitConsensusPacketHex =
    "090000000000000000000000000000000100000000000100000000000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa000011111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111"
  pure val ValuePrecommitConsensusPacketHex =
    "090000000000000000000000000000000001000000000100000000000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa000011111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111"
  pure val NilPrecommitQuorumConsensusPacketHex =
    "090000000000000000000000000000000300000000000100000000000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa000011111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111010022222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222020033333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333"
  pure val MixedPrecommitQuorumConsensusPacketHex =
    "090000000000000000000000000000000102000000000100000000000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa000011111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111010022222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222020033333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333"
  pure val ValuePrecommitQuorumConsensusPacketHex =
    "090000000000000000000000000000000003000000000100000000000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa000011111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111010022222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222020033333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333"

  var transportedPrecommitPackets: Set[PrecommitPacket_t]
  var acceptedNilPrecommitCertificates: Set[PrecommitPacket_t]
  var acceptedValuePrecommitCertificates: Set[PrecommitPacket_t]
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
      "unmodeled-nonce-prefix"
    }

  def Packet(
    kind: PrecommitKind_t,
    noVotes: int,
    yesVotes: int,
    payloadByteLen: int,
    payloadHex: Bytes_t,
    consensusPacketHex: Bytes_t,
  ): PrecommitPacket_t = {
    kind: kind,
    packetType: PacketTypePrecommitSignatures,
    noVotes: noVotes,
    yesVotes: yesVotes,
    payloadByteLen: payloadByteLen,
    payloadHex: payloadHex,
    consensusPacketHex: consensusPacketHex,
  }

  def Envelope(
    decrypted: bool,
    nonce: int,
    noncePrefixHex: Bytes_t,
    topic: str,
    packetType: int,
    payloadByteLen: int,
    byteLen: int,
    payloadHex: Bytes_t,
    packetHex: Bytes_t,
  ): TransportEnvelope_t = {
    decrypted: decrypted,
    nonce: nonce,
    noncePrefixHex: noncePrefixHex,
    topic: topic,
    packetType: packetType,
    payloadByteLen: payloadByteLen,
    byteLen: byteLen,
    payloadHex: payloadHex,
    packetHex: packetHex,
  }

  pure val NilPrecommitPacket =
    Packet(NilPrecommitKind, 1, 0, 112, NilPrecommitPacketHex, NilPrecommitConsensusPacketHex)
  pure val ValuePrecommitPacket =
    Packet(ValuePrecommitKind, 0, 1, 112, ValuePrecommitPacketHex, ValuePrecommitConsensusPacketHex)
  pure val NilPrecommitCertificatePacket =
    Packet(
      NilPrecommitCertificateKind,
      3,
      0,
      244,
      NilPrecommitQuorumPacketHex,
      NilPrecommitQuorumConsensusPacketHex,
    )
  pure val MixedPrecommitQuorumPacket =
    Packet(
      MixedPrecommitQuorumKind,
      1,
      2,
      244,
      MixedPrecommitQuorumPacketHex,
      MixedPrecommitQuorumConsensusPacketHex,
    )
  pure val ValuePrecommitCertificatePacket =
    Packet(
      ValuePrecommitCertificateKind,
      0,
      3,
      244,
      ValuePrecommitQuorumPacketHex,
      ValuePrecommitQuorumConsensusPacketHex,
    )
  pure val WrongKindPacket =
    Packet(WrongKind, 0, 1, 112, ValuePrecommitPacketHex, ValuePrecommitConsensusPacketHex)

  pure val NilPrecommitEnvelope =
    Envelope(
      true,
      130,
      "8200000000000000",
      CrosslinkConsensusTopic,
      PacketTypePrecommitSignatures,
      112,
      128,
      NilPrecommitPacketHex,
      NilPrecommitConsensusPacketHex,
    )
  pure val ValuePrecommitEnvelope =
    Envelope(
      true,
      131,
      "8300000000000000",
      CrosslinkConsensusTopic,
      PacketTypePrecommitSignatures,
      112,
      128,
      ValuePrecommitPacketHex,
      ValuePrecommitConsensusPacketHex,
    )
  pure val NilPrecommitCertificateEnvelope =
    Envelope(
      true,
      132,
      "8400000000000000",
      CrosslinkConsensusTopic,
      PacketTypePrecommitSignatures,
      244,
      260,
      NilPrecommitQuorumPacketHex,
      NilPrecommitQuorumConsensusPacketHex,
    )
  pure val MixedPrecommitQuorumEnvelope =
    Envelope(
      true,
      133,
      "8500000000000000",
      CrosslinkConsensusTopic,
      PacketTypePrecommitSignatures,
      244,
      260,
      MixedPrecommitQuorumPacketHex,
      MixedPrecommitQuorumConsensusPacketHex,
    )
  pure val ValuePrecommitCertificateEnvelope =
    Envelope(
      true,
      134,
      "8600000000000000",
      CrosslinkConsensusTopic,
      PacketTypePrecommitSignatures,
      244,
      260,
      ValuePrecommitQuorumPacketHex,
      ValuePrecommitQuorumConsensusPacketHex,
    )

  pure val WrongTopicEnvelope =
    Envelope(
      true,
      131,
      "8300000000000000",
      WrongTopic,
      PacketTypePrecommitSignatures,
      112,
      128,
      ValuePrecommitPacketHex,
      ValuePrecommitConsensusPacketHex,
    )
  pure val WrongTypeEnvelope =
    Envelope(
      true,
      131,
      "8300000000000000",
      CrosslinkConsensusTopic,
      PacketTypePrevoteSignatures,
      112,
      128,
      ValuePrecommitPacketHex,
      ValuePrecommitConsensusPacketHex,
    )
  pure val WrongPayloadEnvelope =
    Envelope(
      true,
      131,
      "8300000000000000",
      CrosslinkConsensusTopic,
      PacketTypePrecommitSignatures,
      112,
      128,
      NilPrecommitPacketHex,
      ValuePrecommitConsensusPacketHex,
    )
  pure val WrongPacketHexEnvelope =
    Envelope(
      true,
      131,
      "8300000000000000",
      CrosslinkConsensusTopic,
      PacketTypePrecommitSignatures,
      112,
      128,
      ValuePrecommitPacketHex,
      "wrong-precommit-consensus-packet-hex",
    )
  pure val FailedDecryptEnvelope =
    Envelope(
      false,
      131,
      "8300000000000000",
      CrosslinkConsensusTopic,
      PacketTypePrecommitSignatures,
      112,
      128,
      ValuePrecommitPacketHex,
      ValuePrecommitConsensusPacketHex,
    )

  pure val TestPackets = Set(
    NilPrecommitPacket,
    ValuePrecommitPacket,
    NilPrecommitCertificatePacket,
    MixedPrecommitQuorumPacket,
    ValuePrecommitCertificatePacket,
    WrongKindPacket,
  )

  pure val TestEnvelopes = Set(
    NilPrecommitEnvelope,
    ValuePrecommitEnvelope,
    NilPrecommitCertificateEnvelope,
    MixedPrecommitQuorumEnvelope,
    ValuePrecommitCertificateEnvelope,
    WrongTopicEnvelope,
    WrongTypeEnvelope,
    WrongPayloadEnvelope,
    WrongPacketHexEnvelope,
    FailedDecryptEnvelope,
  )

  pure def PrecommitPacketCanonical(packet: PrecommitPacket_t): bool =
    packet.packetType == PacketTypePrecommitSignatures and
    (
      packet == NilPrecommitPacket or
      packet == ValuePrecommitPacket or
      packet == NilPrecommitCertificatePacket or
      packet == MixedPrecommitQuorumPacket or
      packet == ValuePrecommitCertificatePacket
    )

  pure def NilPrecommitCertificate(packet: PrecommitPacket_t): bool =
    PrecommitPacketCanonical(packet) and
    packet.noVotes >= FixtureQuorumVotingPower and
    packet.yesVotes == 0

  pure def ValuePrecommitCertificate(packet: PrecommitPacket_t): bool =
    PrecommitPacketCanonical(packet) and
    packet.noVotes == 0 and
    packet.yesVotes >= FixtureQuorumVotingPower

  pure def PrecommitTransportEnvelopeValid(
    env: TransportEnvelope_t,
    packet: PrecommitPacket_t,
  ): bool =
    PrecommitPacketCanonical(packet) and
    env.decrypted and
    env.topic == CrosslinkConsensusTopic and
    env.noncePrefixHex == NoncePrefixHex(env.nonce) and
    env.packetType == PacketTypePrecommitSignatures and
    env.payloadByteLen == packet.payloadByteLen and
    env.byteLen == PacketHeaderByteLen + packet.payloadByteLen and
    env.payloadHex == packet.payloadHex and
    env.packetHex == packet.consensusPacketHex

  action TransportInit = all {
    transportedPrecommitPackets' = Set(),
    acceptedNilPrecommitCertificates' = Set(),
    acceptedValuePrecommitCertificates' = Set(),
    precommitTransportFiredAction' = "TransportInit",
  }

  action ReceivePrecommitTransport(
    env: TransportEnvelope_t,
    packet: PrecommitPacket_t,
  ): bool =
    all {
      PrecommitTransportEnvelopeValid(env, packet),
      transportedPrecommitPackets' =
        transportedPrecommitPackets.union(Set(packet)),
      acceptedNilPrecommitCertificates' = acceptedNilPrecommitCertificates,
      acceptedValuePrecommitCertificates' = acceptedValuePrecommitCertificates,
      precommitTransportFiredAction' = "ReceivePrecommitTransport",
    }

  action AcceptNilPrecommitCertificate(packet: PrecommitPacket_t): bool =
    all {
      transportedPrecommitPackets.contains(packet),
      NilPrecommitCertificate(packet),
      transportedPrecommitPackets' = transportedPrecommitPackets,
      acceptedNilPrecommitCertificates' =
        acceptedNilPrecommitCertificates.union(Set(packet)),
      acceptedValuePrecommitCertificates' = acceptedValuePrecommitCertificates,
      precommitTransportFiredAction' = "AcceptNilPrecommitCertificate",
    }

  action AcceptValuePrecommitCertificate(packet: PrecommitPacket_t): bool =
    all {
      transportedPrecommitPackets.contains(packet),
      ValuePrecommitCertificate(packet),
      transportedPrecommitPackets' = transportedPrecommitPackets,
      acceptedNilPrecommitCertificates' = acceptedNilPrecommitCertificates,
      acceptedValuePrecommitCertificates' =
        acceptedValuePrecommitCertificates.union(Set(packet)),
      precommitTransportFiredAction' = "AcceptValuePrecommitCertificate",
    }

  action TransportStutter: bool =
    all {
      transportedPrecommitPackets' = transportedPrecommitPackets,
      acceptedNilPrecommitCertificates' = acceptedNilPrecommitCertificates,
      acceptedValuePrecommitCertificates' = acceptedValuePrecommitCertificates,
      precommitTransportFiredAction' = precommitTransportFiredAction,
    }

  action TransportNext: bool =
    any {
      nondet env = oneOf(TestEnvelopes)
      nondet packet = oneOf(TestPackets)
      ReceivePrecommitTransport(env, packet),
      nondet packet = oneOf(TestPackets)
      AcceptNilPrecommitCertificate(packet),
      nondet packet = oneOf(TestPackets)
      AcceptValuePrecommitCertificate(packet),
      TransportStutter,
    }

  pure def TransportedPacketsCanonical: bool =
    transportedPrecommitPackets.forall(PrecommitPacketCanonical)

  pure def AcceptedNilCertificatesTransported: bool =
    acceptedNilPrecommitCertificates.forall(packet =>
      transportedPrecommitPackets.contains(packet) and
      NilPrecommitCertificate(packet)
    )

  pure def AcceptedValueCertificatesTransported: bool =
    acceptedValuePrecommitCertificates.forall(packet =>
      transportedPrecommitPackets.contains(packet) and
      ValuePrecommitCertificate(packet)
    )

  val TransportSafety =
    TransportedPacketsCanonical and
    AcceptedNilCertificatesTransported and
    AcceptedValueCertificatesTransported
}

module CrosslinkTenderlinkPrecommitTransportSafetyTest {
  import CrosslinkTenderlinkPrecommitTransportSafety.* from
    "./CrosslinkTenderlinkPrecommitTransportSafety"
  export CrosslinkTenderlinkPrecommitTransportSafety.*

  action transportUnchangedAll: bool =
    all {
      transportedPrecommitPackets' = transportedPrecommitPackets,
      acceptedNilPrecommitCertificates' = acceptedNilPrecommitCertificates,
      acceptedValuePrecommitCertificates' = acceptedValuePrecommitCertificates,
      precommitTransportFiredAction' = precommitTransportFiredAction,
    }

  run receivesAllValidPrecommitPacketsTest = {
    TransportInit
      .then(ReceivePrecommitTransport(NilPrecommitEnvelope, NilPrecommitPacket))
      .then(ReceivePrecommitTransport(ValuePrecommitEnvelope, ValuePrecommitPacket))
      .then(ReceivePrecommitTransport(
        MixedPrecommitQuorumEnvelope,
        MixedPrecommitQuorumPacket,
      ))
      .then(all {
        assert(transportedPrecommitPackets.contains(NilPrecommitPacket)),
        assert(transportedPrecommitPackets.contains(ValuePrecommitPacket)),
        assert(transportedPrecommitPackets.contains(MixedPrecommitQuorumPacket)),
        assert(TransportSafety),
        transportUnchangedAll,
      })
  }

  run acceptsNilCertificateOnlyAfterTransportTest = {
    TransportInit
      .then(ReceivePrecommitTransport(
        NilPrecommitCertificateEnvelope,
        NilPrecommitCertificatePacket,
      ))
      .then(AcceptNilPrecommitCertificate(NilPrecommitCertificatePacket))
      .then(all {
        assert(acceptedNilPrecommitCertificates.contains(
          NilPrecommitCertificatePacket
        )),
        assert(TransportSafety),
        transportUnchangedAll,
      })
  }

  run acceptsValueCertificateOnlyAfterTransportTest = {
    TransportInit
      .then(ReceivePrecommitTransport(
        ValuePrecommitCertificateEnvelope,
        ValuePrecommitCertificatePacket,
      ))
      .then(AcceptValuePrecommitCertificate(ValuePrecommitCertificatePacket))
      .then(all {
        assert(acceptedValuePrecommitCertificates.contains(
          ValuePrecommitCertificatePacket
        )),
        assert(TransportSafety),
        transportUnchangedAll,
      })
  }

  run missingTransportNilCertificateRejectedTest = {
    TransportInit
      .then(AcceptNilPrecommitCertificate(NilPrecommitCertificatePacket))
      .fail()
  }

  run missingTransportValueCertificateRejectedTest = {
    TransportInit
      .then(AcceptValuePrecommitCertificate(ValuePrecommitCertificatePacket))
      .fail()
  }

  run lowPowerNilPrecommitDoesNotUnlockTest = {
    TransportInit
      .then(ReceivePrecommitTransport(NilPrecommitEnvelope, NilPrecommitPacket))
      .then(AcceptNilPrecommitCertificate(NilPrecommitPacket))
      .fail()
  }

  run lowPowerValuePrecommitDoesNotCertifyTest = {
    TransportInit
      .then(ReceivePrecommitTransport(ValuePrecommitEnvelope, ValuePrecommitPacket))
      .then(AcceptValuePrecommitCertificate(ValuePrecommitPacket))
      .fail()
  }

  run mixedPrecommitQuorumDoesNotUnlockTest = {
    TransportInit
      .then(ReceivePrecommitTransport(
        MixedPrecommitQuorumEnvelope,
        MixedPrecommitQuorumPacket,
      ))
      .then(AcceptNilPrecommitCertificate(MixedPrecommitQuorumPacket))
      .fail()
  }

  run mixedPrecommitQuorumDoesNotCommitTest = {
    TransportInit
      .then(ReceivePrecommitTransport(
        MixedPrecommitQuorumEnvelope,
        MixedPrecommitQuorumPacket,
      ))
      .then(AcceptValuePrecommitCertificate(MixedPrecommitQuorumPacket))
      .fail()
  }

  run wrongTopicPrecommitTransportRejectedTest = {
    TransportInit
      .then(ReceivePrecommitTransport(WrongTopicEnvelope, ValuePrecommitPacket))
      .fail()
  }

  run wrongTypePrecommitTransportRejectedTest = {
    TransportInit
      .then(ReceivePrecommitTransport(WrongTypeEnvelope, ValuePrecommitPacket))
      .fail()
  }

  run wrongPayloadPrecommitTransportRejectedTest = {
    TransportInit
      .then(ReceivePrecommitTransport(WrongPayloadEnvelope, ValuePrecommitPacket))
      .fail()
  }

  run wrongPacketHexPrecommitTransportRejectedTest = {
    TransportInit
      .then(ReceivePrecommitTransport(WrongPacketHexEnvelope, ValuePrecommitPacket))
      .fail()
  }

  run failedDecryptPrecommitTransportRejectedTest = {
    TransportInit
      .then(ReceivePrecommitTransport(FailedDecryptEnvelope, ValuePrecommitPacket))
      .fail()
  }

  run wrongKindPacketRejectedAsPrecommitTransportTest = {
    TransportInit
      .then(ReceivePrecommitTransport(ValuePrecommitEnvelope, WrongKindPacket))
      .fail()
  }

  run transportSafetyTest = {
    TransportInit.then(all {
      assert(TransportSafety),
      transportUnchangedAll,
    })
  }
}

module CrosslinkTenderlinkPrecommitTransportSafetyModel {
  import CrosslinkTenderlinkPrecommitTransportSafetyTest.* from
    "./CrosslinkTenderlinkPrecommitTransportSafety"
  export CrosslinkTenderlinkPrecommitTransportSafetyTest.*
}
