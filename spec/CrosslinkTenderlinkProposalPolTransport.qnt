module CrosslinkTenderlinkProposalPolTransport {
  /*
   Tenderlink proposal/POL transport bridge.

   CrosslinkTenderlinkProposalPolEvidence.qnt checks the decoded proposal and
   POL vote-packet relation. This model adds the adjacent compact Tenderlink
   transport boundary: the non-nil valid-round proposal chunk and its prevote
   POL packet must first arrive as decrypted, canonical consensus packets with
   exact packet-header bytes and payload bytes before the decoded evidence can
   be accepted.

   Nonce replay-window behavior is covered in
   CrosslinkTenderlinkNonceAckTransport.qnt; this slice keeps only the exact
   nonce-prefix/decryption/packet-envelope guard needed to link transport
   receipt to proposal/POL evidence acceptance.
   */

  import CrosslinkTenderlinkProposalPolEvidenceTest.* from
    "./CrosslinkTenderlinkProposalPolEvidence"
  export CrosslinkTenderlinkProposalPolEvidenceTest.*
  import CrosslinkTenderlinkConsensusPacketFormat as ConsensusPacketFormat from
    "./CrosslinkTenderlinkConsensusPacketFormat"

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

  pure val UnmodeledTransportPacketHex = "unmodeled-transport-packet"
  pure val UnmodeledNoncePrefixHex = "unmodeled-nonce-prefix"

  // Reuse the exact compact consensus packet witnesses so POL transport cannot
  // drift from the packet-envelope layout slice.
  pure val PolProposalConsensusPacketHex =
    ConsensusPacketFormat::TestPolProposalConsensusPacketHex

  pure val ValuePrevotePolConsensusPacketHex =
    ConsensusPacketFormat::TestValuePrevotePolConsensusPacketHex

  pure val ValuePrevotePolWeightedConsensusPacketHex =
    ConsensusPacketFormat::TestWeightedPrevoteConsensusPacketHex

  pure val ValuePrevotePolQuorumConsensusPacketHex =
    ConsensusPacketFormat::TestQuorumPrevoteConsensusPacketHex

  var transportedProposalChunks: Set[ProposalChunkWire_t]
  var transportedPolPackets: Set[VotePacket_t]
  var acceptedTransportedPolEvidence: Set[ProposalPolEvidence_t]
  var transportFiredAction: str

  pure def NoncePrefixHex(nonce: int): Bytes_t =
    if (nonce == 120) {
      "7800000000000000"
    } else if (nonce == 125) {
      "7d00000000000000"
    } else if (nonce == 126) {
      "7e00000000000000"
    } else if (nonce == 127) {
      "7f00000000000000"
    } else {
      UnmodeledNoncePrefixHex
    }

  pure def ProposalTransportPacketHex(
    proposal: ProposalChunkWire_t,
  ): Bytes_t =
    if (proposal.hex == PolProposalChunkHex) {
      PolProposalConsensusPacketHex
    } else {
      UnmodeledTransportPacketHex
    }

  pure def PolVoteTransportPacketHex(packet: VotePacket_t): Bytes_t =
    if (packet.hex == ValuePrevotePolPacketHex) {
      ValuePrevotePolConsensusPacketHex
    } else if (packet.hex == ValuePrevotePolWeightedPacketHex) {
      ValuePrevotePolWeightedConsensusPacketHex
    } else if (packet.hex == ValuePrevotePolQuorumPacketHex) {
      ValuePrevotePolQuorumConsensusPacketHex
    } else {
      UnmodeledTransportPacketHex
    }

  pure def ProposalTransportEnvelopeValid(
    env: TransportEnvelope_t,
    proposal: ProposalChunkWire_t,
  ): bool =
    env.decrypted and
    env.noncePrefixHex == NoncePrefixHex(env.nonce) and
    env.noncePrefixHex != UnmodeledNoncePrefixHex and
    env.packetType == ConsensusPacketFormat::PacketTypeProposalChunk and
    ProposalChunkWireCanonical(proposal) and
    ProposalNeedsPol(proposal) and
    env.payloadByteLen == proposal.byteLen and
    env.byteLen == ConsensusPacketFormat::PacketHeaderByteLen + proposal.byteLen +
      ConsensusPacketFormat::ProposalSignatureByteLen and
    env.payloadHex == proposal.hex and
    ProposalTransportPacketHex(proposal) != UnmodeledTransportPacketHex and
    env.packetHex == ProposalTransportPacketHex(proposal)

  pure def PolVoteTransportEnvelopeValid(
    env: TransportEnvelope_t,
    packet: VotePacket_t,
  ): bool =
    env.decrypted and
    env.noncePrefixHex == NoncePrefixHex(env.nonce) and
    env.noncePrefixHex != UnmodeledNoncePrefixHex and
    env.packetType == ConsensusPacketFormat::PacketTypePrevoteSignatures and
    VotePacketCanonical(packet) and
    packet.packetType == ConsensusPacketFormat::PacketTypePrevoteSignatures and
    packet.noVotes == 0 and
    env.payloadByteLen == packet.byteLen and
    env.byteLen == ConsensusPacketFormat::PacketHeaderByteLen + packet.byteLen and
    env.payloadHex == packet.hex and
    PolVoteTransportPacketHex(packet) != UnmodeledTransportPacketHex and
    env.packetHex == PolVoteTransportPacketHex(packet)

  action TransportInit = all {
    Init,
    transportedProposalChunks' = Set(),
    transportedPolPackets' = Set(),
    acceptedTransportedPolEvidence' = Set(),
    transportFiredAction' = "TransportInit",
  }

  action KeepEvidenceState = all {
    acceptedNilValidRoundProposals' = acceptedNilValidRoundProposals,
    acceptedProposalPolEvidence' = acceptedProposalPolEvidence,
    firedAction' = firedAction,
  }

  action ReceiveProposalChunkTransport(
    env: TransportEnvelope_t,
    proposal: ProposalChunkWire_t,
  ): bool =
    all {
      ProposalTransportEnvelopeValid(env, proposal),
      KeepEvidenceState,
      transportedProposalChunks' = transportedProposalChunks.union(Set(proposal)),
      transportedPolPackets' = transportedPolPackets,
      acceptedTransportedPolEvidence' = acceptedTransportedPolEvidence,
      transportFiredAction' = "ReceiveProposalChunkTransport",
    }

  action ReceivePolVoteTransport(
    env: TransportEnvelope_t,
    packet: VotePacket_t,
  ): bool =
    all {
      PolVoteTransportEnvelopeValid(env, packet),
      KeepEvidenceState,
      transportedProposalChunks' = transportedProposalChunks,
      transportedPolPackets' = transportedPolPackets.union(Set(packet)),
      acceptedTransportedPolEvidence' = acceptedTransportedPolEvidence,
      transportFiredAction' = "ReceivePolVoteTransport",
    }

  action AcceptTransportedProposalWithPol(
    evidence: ProposalPolEvidence_t,
  ): bool =
    all {
      ProposalPolEvidenceCanonical(evidence),
      transportedProposalChunks.contains(evidence.proposal),
      transportedPolPackets.contains(evidence.polPacket),
      KeepEvidenceState,
      transportedProposalChunks' = transportedProposalChunks,
      transportedPolPackets' = transportedPolPackets,
      acceptedTransportedPolEvidence' =
        acceptedTransportedPolEvidence.union(Set(evidence)),
      transportFiredAction' = "AcceptTransportedProposalWithPol",
    }

  action TransportStutter: bool =
    all {
      KeepEvidenceState,
      transportedProposalChunks' = transportedProposalChunks,
      transportedPolPackets' = transportedPolPackets,
      acceptedTransportedPolEvidence' = acceptedTransportedPolEvidence,
      transportFiredAction' = transportFiredAction,
    }

  pure def TransportedProposalsCanonical: bool =
    transportedProposalChunks.forall(proposal =>
      ProposalTransportPacketHex(proposal) != UnmodeledTransportPacketHex and
      ProposalChunkWireCanonical(proposal) and
      ProposalNeedsPol(proposal)
    )

  pure def TransportedPolPacketsCanonical: bool =
    transportedPolPackets.forall(packet =>
      PolVoteTransportPacketHex(packet) != UnmodeledTransportPacketHex and
      VotePacketCanonical(packet) and
      packet.packetType == ConsensusPacketFormat::PacketTypePrevoteSignatures and
      packet.noVotes == 0
    )

  pure def AcceptedTransportedPolEvidenceCanonical: bool =
    acceptedTransportedPolEvidence.forall(evidence =>
      ProposalPolEvidenceCanonical(evidence) and
      transportedProposalChunks.contains(evidence.proposal) and
      transportedPolPackets.contains(evidence.polPacket)
    )

  val TransportSafety =
    ConsensusPacketFormat::PacketHeaderByteLen == 16 and
    ConsensusPacketFormat::ProposalSignatureByteLen == 64 and
    TransportedProposalsCanonical and
    TransportedPolPacketsCanonical and
    AcceptedTransportedPolEvidenceCanonical
}

module CrosslinkTenderlinkProposalPolTransportTest {
  import CrosslinkTenderlinkProposalPolTransport.* from
    "./CrosslinkTenderlinkProposalPolTransport"
  export CrosslinkTenderlinkProposalPolTransport.*
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

  pure val polProposalEnvelope =
    Env(
      true,
      120,
      "7800000000000000",
      ConsensusPacketFormat::PacketTypeProposalChunk,
      matchingPolProposalChunk.byteLen,
      140,
      matchingPolProposalChunk.hex,
      PolProposalConsensusPacketHex,
    )

  pure val weightedPolVoteEnvelope =
    Env(
      true,
      125,
      "7d00000000000000",
      ConsensusPacketFormat::PacketTypePrevoteSignatures,
      valuePrevotePolWeightedPacket.byteLen,
      194,
      valuePrevotePolWeightedPacket.hex,
      ValuePrevotePolWeightedConsensusPacketHex,
    )

  pure val quorumPolVoteEnvelope =
    Env(
      true,
      126,
      "7e00000000000000",
      ConsensusPacketFormat::PacketTypePrevoteSignatures,
      valuePrevotePolQuorumPacket.byteLen,
      260,
      valuePrevotePolQuorumPacket.hex,
      ValuePrevotePolQuorumConsensusPacketHex,
    )

  pure val lowPowerPolVoteEnvelope =
    Env(
      true,
      127,
      "7f00000000000000",
      ConsensusPacketFormat::PacketTypePrevoteSignatures,
      valuePrevotePolPacket.byteLen,
      128,
      valuePrevotePolPacket.hex,
      ValuePrevotePolConsensusPacketHex,
    )

  pure val wrongTypeProposalEnvelope =
    Env(
      true,
      120,
      "7800000000000000",
      ConsensusPacketFormat::PacketTypePrevoteSignatures,
      matchingPolProposalChunk.byteLen,
      140,
      matchingPolProposalChunk.hex,
      PolProposalConsensusPacketHex,
    )

  pure val wrongPayloadPolVoteEnvelope =
    Env(
      true,
      125,
      "7d00000000000000",
      ConsensusPacketFormat::PacketTypePrevoteSignatures,
      valuePrevotePolWeightedPacket.byteLen,
      194,
      valuePrevotePolQuorumPacket.hex,
      ValuePrevotePolWeightedConsensusPacketHex,
    )

  pure val wrongPacketHexPolVoteEnvelope =
    Env(
      true,
      125,
      "7d00000000000000",
      ConsensusPacketFormat::PacketTypePrevoteSignatures,
      valuePrevotePolWeightedPacket.byteLen,
      194,
      valuePrevotePolWeightedPacket.hex,
      "wrong-pol-consensus-packet-hex",
    )

  pure val TestProposalEnvelopes = Set(polProposalEnvelope, wrongTypeProposalEnvelope)
  pure val TestVoteEnvelopes = Set(
    weightedPolVoteEnvelope,
    quorumPolVoteEnvelope,
    lowPowerPolVoteEnvelope,
    wrongPayloadPolVoteEnvelope,
    wrongPacketHexPolVoteEnvelope,
  )
  pure val TestEvidence = Set(weightedPolEvidence, matchingPolEvidence, lowPowerEvidence)

  action TransportNext: bool =
    any {
      nondet env = oneOf(TestProposalEnvelopes)
      ReceiveProposalChunkTransport(env, matchingPolProposalChunk),
      nondet voteEnv = oneOf(TestVoteEnvelopes)
      nondet packet = oneOf(Set(
        valuePrevotePolWeightedPacket,
        valuePrevotePolQuorumPacket,
        valuePrevotePolPacket,
      ))
      ReceivePolVoteTransport(voteEnv, packet),
      nondet evidence = oneOf(TestEvidence)
      AcceptTransportedProposalWithPol(evidence),
      TransportStutter,
    }

  action unchangedTransport = all {
    acceptedNilValidRoundProposals' = acceptedNilValidRoundProposals,
    acceptedProposalPolEvidence' = acceptedProposalPolEvidence,
    firedAction' = firedAction,
    transportedProposalChunks' = transportedProposalChunks,
    transportedPolPackets' = transportedPolPackets,
    acceptedTransportedPolEvidence' = acceptedTransportedPolEvidence,
    transportFiredAction' = transportFiredAction,
  }

  run proposalTransportEnvelopeAcceptedTest = {
    TransportInit
      .then(ReceiveProposalChunkTransport(
        polProposalEnvelope,
        matchingPolProposalChunk,
      ))
      .then(all {
        assert(transportedProposalChunks.contains(matchingPolProposalChunk)),
        assert(TransportSafety),
        unchangedTransport,
      })
  }

  run weightedPolTransportedEvidenceAcceptedTest = {
    TransportInit
      .then(ReceiveProposalChunkTransport(
        polProposalEnvelope,
        matchingPolProposalChunk,
      ))
      .then(ReceivePolVoteTransport(
        weightedPolVoteEnvelope,
        valuePrevotePolWeightedPacket,
      ))
      .then(AcceptTransportedProposalWithPol(weightedPolEvidence))
      .then(all {
        assert(acceptedTransportedPolEvidence.contains(weightedPolEvidence)),
        assert(TransportSafety),
        unchangedTransport,
      })
  }

  run quorumPolTransportedEvidenceAcceptedTest = {
    TransportInit
      .then(ReceiveProposalChunkTransport(
        polProposalEnvelope,
        matchingPolProposalChunk,
      ))
      .then(ReceivePolVoteTransport(
        quorumPolVoteEnvelope,
        valuePrevotePolQuorumPacket,
      ))
      .then(AcceptTransportedProposalWithPol(matchingPolEvidence))
      .then(all {
        assert(acceptedTransportedPolEvidence.contains(matchingPolEvidence)),
        assert(TransportSafety),
        unchangedTransport,
      })
  }

  run missingProposalTransportRejectedTest = {
    TransportInit
      .then(ReceivePolVoteTransport(
        weightedPolVoteEnvelope,
        valuePrevotePolWeightedPacket,
      ))
      .then(AcceptTransportedProposalWithPol(weightedPolEvidence))
      .fail()
  }

  run missingPolTransportRejectedTest = {
    TransportInit
      .then(ReceiveProposalChunkTransport(
        polProposalEnvelope,
        matchingPolProposalChunk,
      ))
      .then(AcceptTransportedProposalWithPol(weightedPolEvidence))
      .fail()
  }

  run lowPowerTransportedPolRejectedTest = {
    TransportInit
      .then(ReceiveProposalChunkTransport(
        polProposalEnvelope,
        matchingPolProposalChunk,
      ))
      .then(ReceivePolVoteTransport(lowPowerPolVoteEnvelope, valuePrevotePolPacket))
      .then(AcceptTransportedProposalWithPol(lowPowerEvidence))
      .fail()
  }

  run wrongProposalTransportTypeRejectedTest = {
    TransportInit
      .then(ReceiveProposalChunkTransport(
        wrongTypeProposalEnvelope,
        matchingPolProposalChunk,
      ))
      .fail()
  }

  run wrongPolTransportPayloadRejectedTest = {
    TransportInit
      .then(ReceivePolVoteTransport(
        wrongPayloadPolVoteEnvelope,
        valuePrevotePolWeightedPacket,
      ))
      .fail()
  }

  run wrongPolTransportPacketHexRejectedTest = {
    TransportInit
      .then(ReceivePolVoteTransport(
        wrongPacketHexPolVoteEnvelope,
        valuePrevotePolWeightedPacket,
      ))
      .fail()
  }

  run proposalPolTransportSafetyTest = {
    TransportInit.then(all {
      assert(TransportSafety),
      unchangedTransport,
    })
  }
}

module CrosslinkTenderlinkProposalPolTransportModel {
  import CrosslinkTenderlinkProposalPolTransportTest.* from
    "./CrosslinkTenderlinkProposalPolTransport"
  export CrosslinkTenderlinkProposalPolTransportTest.*
}
