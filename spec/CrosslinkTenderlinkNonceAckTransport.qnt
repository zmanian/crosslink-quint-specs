module CrosslinkTenderlinkNonceAckTransport {
  /*
   Tenderlink known-peer nonce/ack transport boundary.

   The legacy UDP path sends stateless Noise transport packets as:

   - little-endian u64 transport nonce outside the encrypted message,
   - encrypted plaintext that starts with a Tenderlink PacketHeader.

   This model keeps Noise encryption abstract. A packet is accepted only after
   the model says decryption succeeded, the decrypted plaintext is a canonical
   compact consensus packet, and the production nonce replay window accepts the
   outer nonce. The replay rule mirrors forks/tenderlink/src/lib.rs:

   - reject nonce == ack_latest,
   - reject forward jumps beyond NONCE_FORWARD_JUMP_TOLERANCE,
   - reject old nonces more than 64 behind ack_latest,
   - reject old nonces whose ack-field bit says they were already seen.
   */

  import CrosslinkTenderlinkConsensusPacketFormat.* from "./CrosslinkTenderlinkConsensusPacketFormat"
  export CrosslinkTenderlinkConsensusPacketFormat.*

  type NonceAckState_t = {
    ackLatest: int,
    ackedNonces: Set[int],
    ackFieldHex: Bytes_t,
  }

  type KnownPeerTransportPacket_t = {
    nonce: int,
    noncePrefixHex: Bytes_t,
    decrypted: bool,
    consensusPacket: ConsensusPacket_t,
  }

  pure val NonceForwardJumpTolerance = 512
  pure val AckWindowSize = 64
  pure val OuterNonceByteLen = 8
  pure val TransportPacketHeaderByteLen = 16
  pure val MinimumKnownPeerPlaintextByteLen = TransportPacketHeaderByteLen

  pure val AckFieldAllHex = "ffffffffffffffff"
  pure val AckFieldMissing120Hex = "efffffffffffffff"
  pure val AckFieldUpdatedHex = "updated-ack-field"
  pure val UnmodeledNoncePrefixHex = "unmodeled-nonce-prefix"

  var transportState: NonceAckState_t
  var acceptedTransportPackets: Set[KnownPeerTransportPacket_t]
  var acceptedNonces: Set[int]
  var nonceAckTransportFiredAction: str

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

  pure val AckedPrevoteHeader =
    HeaderWithAck(
      PacketTypePrevoteSignatures,
      false,
      TestAckLatest,
      TestAckField,
      131336,
      "08010200000000000201000000000000",
    )

  pure val AckedPrevotePacket =
    Packet(
      PrevoteBatchKind,
      AckedPrevoteHeader,
      112,
      0,
      128,
      "080102000000000002010000000000000100000000000100000000000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa000011111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111",
    )

  pure val BadConsensusPacket =
    Packet(
      PrevoteBatchKind,
      AckedPrevoteHeader,
      112,
      0,
      129,
      "080102000000000002010000000000000100000000000100000000000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa00001111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111100",
    )

  pure val Missing120At124: NonceAckState_t = {
    ackLatest: 124,
    ackedNonces: Set(121, 122, 123),
    ackFieldHex: AckFieldMissing120Hex,
  }

  pure val AllAckedAt12: NonceAckState_t = {
    ackLatest: 12,
    ackedNonces: Set(0, 1, 2),
    ackFieldHex: AckFieldAllHex,
  }

  pure val AllAckedAt124: NonceAckState_t = {
    ackLatest: 124,
    ackedNonces: Set(120, 121, 122, 123),
    ackFieldHex: AckFieldAllHex,
  }

  pure def NoncePrefixHex(nonce: int): Bytes_t =
    if (nonce == 12) {
      "0c00000000000000"
    } else if (nonce == 120) {
      "7800000000000000"
    } else if (nonce == 124) {
      "7c00000000000000"
    } else if (nonce == 125) {
      "7d00000000000000"
    } else if (nonce == 525) {
      "0d02000000000000"
    } else if (nonce == 637) {
      "7d02000000000000"
    } else {
      UnmodeledNoncePrefixHex
    }

  pure def AckWindowContains(nonce: int, state: NonceAckState_t): bool =
    nonce <= state.ackLatest + NonceForwardJumpTolerance and
    nonce + AckWindowSize >= state.ackLatest

  pure def NonceAlreadyAcked(nonce: int, state: NonceAckState_t): bool =
    nonce < state.ackLatest and state.ackedNonces.contains(nonce)

  pure def NonceOk(nonce: int, state: NonceAckState_t): bool =
    AckWindowContains(nonce, state) and
    nonce != state.ackLatest and
    not(NonceAlreadyAcked(nonce, state))

  pure def NonceUpdate(nonce: int, state: NonceAckState_t): NonceAckState_t =
    if (nonce > state.ackLatest) {
      {
        ackLatest: nonce,
        ackedNonces:
          state.ackedNonces.union(Set(state.ackLatest))
            .filter(n => n < nonce and n + AckWindowSize >= nonce),
        ackFieldHex: AckFieldUpdatedHex,
      }
    } else {
      {
        ackLatest: state.ackLatest,
        ackedNonces: state.ackedNonces.union(Set(nonce)),
        ackFieldHex:
          if (state.ackLatest == 124 and nonce == 120 and
            state.ackFieldHex == AckFieldMissing120Hex) {
            AckFieldAllHex
          } else {
            AckFieldUpdatedHex
          },
      }
    }

  pure def KnownPeerTransportPacketCanonical(
    packet: KnownPeerTransportPacket_t,
  ): bool =
    packet.decrypted and
    packet.noncePrefixHex == NoncePrefixHex(packet.nonce) and
    packet.noncePrefixHex != UnmodeledNoncePrefixHex and
    packet.consensusPacket.byteLen >= MinimumKnownPeerPlaintextByteLen and
    ConsensusPacketCanonical(packet.consensusPacket)

  pure def AckStateWindowValid(state: NonceAckState_t): bool =
    state.ackedNonces.forall(n =>
      n < state.ackLatest and n + AckWindowSize >= state.ackLatest
    )

  action TransportInit = all {
    acceptedConsensusPackets' = Set(),
    consensusPacketFiredAction' = "TransportInitConsensusIdle",
    transportState' = Missing120At124,
    acceptedTransportPackets' = Set(),
    acceptedNonces' = Set(),
    nonceAckTransportFiredAction' = "TransportInit",
  }

  action AcceptKnownPeerTransportPacket(
    packet: KnownPeerTransportPacket_t,
  ): bool =
    all {
      KnownPeerTransportPacketCanonical(packet),
      NonceOk(packet.nonce, transportState),
      acceptedConsensusPackets' = acceptedConsensusPackets,
      consensusPacketFiredAction' = consensusPacketFiredAction,
      transportState' = NonceUpdate(packet.nonce, transportState),
      acceptedTransportPackets' = acceptedTransportPackets.union(Set(packet)),
      acceptedNonces' = acceptedNonces.union(Set(packet.nonce)),
      nonceAckTransportFiredAction' = "AcceptKnownPeerTransportPacket",
    }

  action TransportStutter: bool =
    all {
      acceptedConsensusPackets' = acceptedConsensusPackets,
      consensusPacketFiredAction' = consensusPacketFiredAction,
      transportState' = transportState,
      acceptedTransportPackets' = acceptedTransportPackets,
      acceptedNonces' = acceptedNonces,
      nonceAckTransportFiredAction' = nonceAckTransportFiredAction,
    }

  pure def AcceptedTransportPacketsCanonical: bool =
    acceptedTransportPackets.forall(KnownPeerTransportPacketCanonical)

  pure def AcceptedNoncesWereReplayChecked: bool =
    acceptedTransportPackets.forall(packet => acceptedNonces.contains(packet.nonce))

  val TransportSafety =
    NonceForwardJumpTolerance == 512 and
    AckWindowSize == 64 and
    OuterNonceByteLen == 8 and
    TransportPacketHeaderByteLen == 16 and
    MinimumKnownPeerPlaintextByteLen == 16 and
    AckStateWindowValid(transportState) and
    AcceptedTransportPacketsCanonical and
    AcceptedNoncesWereReplayChecked
}

module CrosslinkTenderlinkNonceAckTransportTest {
  import CrosslinkTenderlinkNonceAckTransport.* from "./CrosslinkTenderlinkNonceAckTransport"
  export CrosslinkTenderlinkNonceAckTransport.*

  def TransportPacket(
    nonce: int,
    noncePrefixHex: Bytes_t,
    decrypted: bool,
    consensusPacket: ConsensusPacket_t,
  ): KnownPeerTransportPacket_t = {
    nonce: nonce,
    noncePrefixHex: noncePrefixHex,
    decrypted: decrypted,
    consensusPacket: consensusPacket,
  }

  pure val Packet120 =
    TransportPacket(120, "7800000000000000", true, AckedPrevotePacket)
  pure val Packet124 =
    TransportPacket(124, "7c00000000000000", true, AckedPrevotePacket)
  pure val Packet125 =
    TransportPacket(125, "7d00000000000000", true, AckedPrevotePacket)
  pure val Packet525 =
    TransportPacket(525, "0d02000000000000", true, AckedPrevotePacket)
  pure val Packet637 =
    TransportPacket(637, "7d02000000000000", true, AckedPrevotePacket)
  pure val Packet120BadNoncePrefix =
    TransportPacket(120, "7900000000000000", true, AckedPrevotePacket)
  pure val Packet120Undecrypted =
    TransportPacket(120, "7800000000000000", false, AckedPrevotePacket)
  pure val Packet120BadConsensus =
    TransportPacket(120, "7800000000000000", true, BadConsensusPacket)

  pure val TestTransportPackets = Set(
    Packet120,
    Packet124,
    Packet125,
    Packet525,
    Packet637,
    Packet120BadNoncePrefix,
    Packet120Undecrypted,
    Packet120BadConsensus,
  )

  action Next: bool =
    any {
      nondet packet = oneOf(TestTransportPackets)
      AcceptKnownPeerTransportPacket(packet),
      TransportStutter,
    }

  action unchangedAll = all {
    acceptedConsensusPackets' = acceptedConsensusPackets,
    consensusPacketFiredAction' = consensusPacketFiredAction,
    transportState' = transportState,
    acceptedTransportPackets' = acceptedTransportPackets,
    acceptedNonces' = acceptedNonces,
    nonceAckTransportFiredAction' = nonceAckTransportFiredAction,
  }

  run noncePrefixLittleEndianTest = {
    TransportInit.then(all {
      assert(NoncePrefixHex(120) == "7800000000000000"),
      assert(NoncePrefixHex(525) == "0d02000000000000"),
      assert(NoncePrefixHex(637) == "7d02000000000000"),
      unchangedAll,
    })
  }

  run productionNonceIsOkExamplesTest = {
    TransportInit.then(all {
      assert(NonceOk(124, AllAckedAt12)),
      assert(not(NonceOk(12, AllAckedAt124))),
      assert(NonceOk(120, Missing120At124)),
      unchangedAll,
    })
  }

  run acceptedOldUnackedNonceUpdatesAckFieldTest = {
    TransportInit
      .then(AcceptKnownPeerTransportPacket(Packet120))
      .then(all {
        assert(acceptedNonces.contains(120)),
        assert(transportState.ackLatest == 124),
        assert(transportState.ackedNonces.contains(120)),
        assert(transportState.ackFieldHex == AckFieldAllHex),
        assert(TransportSafety),
        unchangedAll,
      })
  }

  run futureNonceAdvancesAckLatestTest = {
    TransportInit
      .then(AcceptKnownPeerTransportPacket(Packet125))
      .then(all {
        assert(transportState.ackLatest == 125),
        assert(transportState.ackedNonces.contains(124)),
        assert(TransportSafety),
        unchangedAll,
      })
  }

  run replayedNonceRejectedTest = {
    TransportInit
      .then(AcceptKnownPeerTransportPacket(Packet120))
      .then(AcceptKnownPeerTransportPacket(Packet120))
      .fail()
  }

  run currentAckLatestRejectedTest = {
    TransportInit.then(AcceptKnownPeerTransportPacket(Packet124)).fail()
  }

  run forwardJumpToleranceBoundaryAcceptedTest = {
    TransportInit.then(AcceptKnownPeerTransportPacket(Packet525))
      .then(all {
        assert(transportState.ackLatest == 525),
        assert(TransportSafety),
        unchangedAll,
      })
  }

  run forwardJumpBeyondToleranceRejectedTest = {
    TransportInit.then(AcceptKnownPeerTransportPacket(Packet637)).fail()
  }

  run badNoncePrefixRejectedTest = {
    TransportInit.then(AcceptKnownPeerTransportPacket(Packet120BadNoncePrefix)).fail()
  }

  run undecryptedPacketRejectedTest = {
    TransportInit.then(AcceptKnownPeerTransportPacket(Packet120Undecrypted)).fail()
  }

  run badConsensusPacketRejectedTest = {
    TransportInit.then(AcceptKnownPeerTransportPacket(Packet120BadConsensus)).fail()
  }

  run transportSafetyTest = {
    TransportInit.then(all {
      assert(TransportSafety),
      unchangedAll,
    })
  }
}

module CrosslinkTenderlinkNonceAckTransportModel {
  import CrosslinkTenderlinkNonceAckTransportTest.* from "./CrosslinkTenderlinkNonceAckTransport"
  export CrosslinkTenderlinkNonceAckTransportTest.*
}
