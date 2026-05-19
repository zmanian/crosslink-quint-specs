module CrosslinkTenderlinkProposalPolEvidence {
  /*
   Production-shaped Tenderlink proposal/POL evidence bridge.

   The byte-layout source specs pin the exact proposal-chunk and vote-packet
   encodings. This verifier-friendly bridge mirrors the relevant exact vectors
   and checks the cross-object rule: a non-nil validRound proposal chunk is
   accepted only with canonical prevote PacketVotes evidence whose height,
   round, and value id match the proposal chunk.

   The bounded packet fixture carries one canonical signature and models that
   as the minimal quorum threshold. Full validator-set thresholds remain in the
   abstract valid-round and authenticated-evidence specs.
   */

  type Bytes_t = str
  type ProposalId_t = str
  type ValueId_t = str
  type Height_t = int
  type Round_t = int
  type Signature_t = str
  type EntryIndex_t = int

  type ProposalChunkWire_t = {
    byteLen: int,
    chunkIndex: int,
    proposalSize: int,
    round: Round_t,
    validRound: Round_t,
    height: Height_t,
    proposalId: ProposalId_t,
    chunkDataByteLen: int,
    chunkDataHex: Bytes_t,
    hex: Bytes_t,
  }

  type VotePacketEntry_t = {
    rosterIndex: int,
    pubKey: Bytes_t,
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

  type ProposalPolEvidence_t = {
    proposal: ProposalChunkWire_t,
    polPacket: VotePacket_t,
    certifiedVotingPower: int,
    quorumVotingPower: int,
  }

  pure val NilValidRound = -1
  pure val FixtureQuorumVotingPower = 1
  pure val PacketTypePrevoteSignatures = 8
  pure val PacketTypePrecommitSignatures = 9
  pure val TestProposalIdHex =
    "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
  pure val PolEvidenceProposalIdHex =
    "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  pure val TestValueIdHex =
    "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  pure val NilValueId =
    "0000000000000000000000000000000000000000000000000000000000000000"
  pure val TestPubKeyHex =
    "0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20"
  pure val TestVoteSignatureHex =
    "11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111"
  pure val TestChunkDataHex = "cafebabe"

  pure val NilProposalChunkHex =
    "000000000400000000000000ffffffff0100000000000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbcafebabe"
  pure val PolProposalChunkHex =
    "010000000800000002000000010000000200000000000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaacafebabe"
  pure val MismatchedValueProposalChunkHex =
    "010000000800000002000000010000000200000000000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbcafebabe"

  pure val NilPrevotePacketHex =
    "0100000000000100000000000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa000011111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111"
  pure val ValuePrevotePolPacketHex =
    "0001010000000200000000000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa000011111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111"
  pure val ValuePrecommitPacketHex =
    "0001000000000100000000000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa000011111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111"

  pure val NilPrevoteSignBytes =
    "0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f200000000000000000000000000000000000000000000000000000000000000000010000000000000000000000"
  pure val ValuePrevotePolSignBytes =
    "0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa020000000000000001000000"
  pure val ValuePrecommitSignBytes =
    "0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa010000000000000000000080"

  var acceptedNilValidRoundProposals: Set[ProposalChunkWire_t]
  var acceptedProposalPolEvidence: Set[ProposalPolEvidence_t]
  var firedAction: str

  pure def ProposalNeedsPol(proposal: ProposalChunkWire_t): bool =
    proposal.validRound != NilValidRound

  pure def ProposalChunkWireCanonical(proposal: ProposalChunkWire_t): bool =
    if (proposal.byteLen == 60 and proposal.chunkIndex == 0 and
      proposal.proposalSize == 4 and proposal.round == 0 and
      proposal.validRound == NilValidRound and proposal.height == 1 and
      proposal.proposalId == TestProposalIdHex and
      proposal.chunkDataByteLen == 4 and
      proposal.chunkDataHex == TestChunkDataHex) {
      proposal.hex == NilProposalChunkHex
    } else if (proposal.byteLen == 60 and proposal.chunkIndex == 1 and
      proposal.proposalSize == 8 and proposal.round == 2 and
      proposal.validRound == 1 and proposal.height == 2 and
      proposal.proposalId == PolEvidenceProposalIdHex and
      proposal.chunkDataByteLen == 4 and
      proposal.chunkDataHex == TestChunkDataHex) {
      proposal.hex == PolProposalChunkHex
    } else if (proposal.byteLen == 60 and proposal.chunkIndex == 1 and
      proposal.proposalSize == 8 and proposal.round == 2 and
      proposal.validRound == 1 and proposal.height == 2 and
      proposal.proposalId == TestProposalIdHex and
      proposal.chunkDataByteLen == 4 and
      proposal.chunkDataHex == TestChunkDataHex) {
      proposal.hex == MismatchedValueProposalChunkHex
    } else {
      false
    }

  pure def EntryCanonical(packet: VotePacket_t, i: EntryIndex_t): bool = {
    val entry = packet.entries.get(i)
    all {
      entry.rosterIndex == 0,
      entry.pubKey == TestPubKeyHex,
      entry.voteSignature == TestVoteSignatureHex,
      if (packet.noVotes == 1) {
        entry.valueId == NilValueId and entry.signBytes == NilPrevoteSignBytes
      } else if (packet.packetType == PacketTypePrevoteSignatures) {
        entry.valueId == TestValueIdHex and
        entry.signBytes == ValuePrevotePolSignBytes
      } else {
        entry.valueId == TestValueIdHex and
        entry.signBytes == ValuePrecommitSignBytes
      },
    }
  }

  pure def VotePacketCanonical(packet: VotePacket_t): bool =
    if (packet.packetType == PacketTypePrevoteSignatures and
      packet.byteLen == 112 and packet.noVotes == 1 and
      packet.yesVotes == 0 and packet.round == 0 and packet.height == 1 and
      packet.valueId == TestValueIdHex) {
      EntryCanonical(packet, 0) and packet.hex == NilPrevotePacketHex
    } else if (packet.packetType == PacketTypePrevoteSignatures and
      packet.byteLen == 112 and packet.noVotes == 0 and
      packet.yesVotes == 1 and packet.round == 1 and packet.height == 2 and
      packet.valueId == TestValueIdHex) {
      EntryCanonical(packet, 0) and packet.hex == ValuePrevotePolPacketHex
    } else if (packet.packetType == PacketTypePrecommitSignatures and
      packet.byteLen == 112 and packet.noVotes == 0 and
      packet.yesVotes == 1 and packet.round == 0 and packet.height == 1 and
      packet.valueId == TestValueIdHex) {
      EntryCanonical(packet, 0) and packet.hex == ValuePrecommitPacketHex
    } else {
      false
    }

  pure def PolPacketMatchesProposal(
    proposal: ProposalChunkWire_t,
    packet: VotePacket_t,
  ): bool =
    packet.packetType == PacketTypePrevoteSignatures and
    packet.noVotes == 0 and
    packet.yesVotes >= FixtureQuorumVotingPower and
    packet.height == proposal.height and
    packet.round == proposal.validRound and
    packet.valueId == proposal.proposalId

  pure def ProposalPolEvidenceCanonical(
    evidence: ProposalPolEvidence_t,
  ): bool =
    ProposalChunkWireCanonical(evidence.proposal) and
    ProposalNeedsPol(evidence.proposal) and
    VotePacketCanonical(evidence.polPacket) and
    PolPacketMatchesProposal(evidence.proposal, evidence.polPacket) and
    evidence.quorumVotingPower == FixtureQuorumVotingPower and
    evidence.certifiedVotingPower >= evidence.quorumVotingPower

  action Init = all {
    acceptedNilValidRoundProposals' = Set(),
    acceptedProposalPolEvidence' = Set(),
    firedAction' = "Init",
  }

  action AcceptNilValidRoundProposal(proposal: ProposalChunkWire_t): bool =
    all {
      ProposalChunkWireCanonical(proposal),
      not(ProposalNeedsPol(proposal)),
      acceptedNilValidRoundProposals' =
        acceptedNilValidRoundProposals.union(Set(proposal)),
      acceptedProposalPolEvidence' = acceptedProposalPolEvidence,
      firedAction' = "AcceptNilValidRoundProposal",
    }

  action AcceptProposalWithPol(evidence: ProposalPolEvidence_t): bool =
    all {
      ProposalPolEvidenceCanonical(evidence),
      acceptedNilValidRoundProposals' = acceptedNilValidRoundProposals,
      acceptedProposalPolEvidence' =
        acceptedProposalPolEvidence.union(Set(evidence)),
      firedAction' = "AcceptProposalWithPol",
    }

  action Stutter: bool =
    all {
      acceptedNilValidRoundProposals' = acceptedNilValidRoundProposals,
      acceptedProposalPolEvidence' = acceptedProposalPolEvidence,
      firedAction' = firedAction,
    }

  pure def AcceptedNilProposalsNeedNoPol: bool =
    acceptedNilValidRoundProposals.forall(proposal =>
      ProposalChunkWireCanonical(proposal) and
      not(ProposalNeedsPol(proposal))
    )

  pure def AcceptedPolProposalsHaveMatchingEvidence: bool =
    acceptedProposalPolEvidence.forall(ProposalPolEvidenceCanonical)

  val Safety =
    AcceptedNilProposalsNeedNoPol and
    AcceptedPolProposalsHaveMatchingEvidence
}

module CrosslinkTenderlinkProposalPolEvidenceTest {
  import CrosslinkTenderlinkProposalPolEvidence.* from
    "./CrosslinkTenderlinkProposalPolEvidence"
  export CrosslinkTenderlinkProposalPolEvidence.*

  def ChunkWire(
    proposalId: ProposalId_t,
    validRound: Round_t,
    hex: Bytes_t,
  ): ProposalChunkWire_t = {
    byteLen: 60,
    chunkIndex: 1,
    proposalSize: 8,
    round: 2,
    validRound: validRound,
    height: 2,
    proposalId: proposalId,
    chunkDataByteLen: 4,
    chunkDataHex: TestChunkDataHex,
    hex: hex,
  }

  pure val nilValidRoundChunk: ProposalChunkWire_t = {
    byteLen: 60,
    chunkIndex: 0,
    proposalSize: 4,
    round: 0,
    validRound: NilValidRound,
    height: 1,
    proposalId: TestProposalIdHex,
    chunkDataByteLen: 4,
    chunkDataHex: TestChunkDataHex,
    hex: NilProposalChunkHex,
  }

  def Entry(
    valueId: ValueId_t,
    signBytes: Bytes_t,
  ): VotePacketEntry_t = {
    rosterIndex: 0,
    pubKey: TestPubKeyHex,
    valueId: valueId,
    signBytes: signBytes,
    voteSignature: TestVoteSignatureHex,
  }

  def PacketAt(
    packetType: int,
    noVotes: int,
    yesVotes: int,
    round: Round_t,
    height: Height_t,
    valueId: ValueId_t,
    signBytes: Bytes_t,
    hex: Bytes_t,
  ): VotePacket_t = {
    packetType: packetType,
    byteLen: 112,
    noVotes: noVotes,
    yesVotes: yesVotes,
    round: round,
    height: height,
    valueId: valueId,
    entries: Map(0 -> Entry(
      if (noVotes == 1) { NilValueId } else { valueId },
      signBytes,
    )),
    hex: hex,
  }

  pure val matchingPolProposalChunk =
    ChunkWire(PolEvidenceProposalIdHex, 1, PolProposalChunkHex)

  pure val mismatchedValueProposalChunk =
    ChunkWire(TestProposalIdHex, 1, MismatchedValueProposalChunkHex)

  pure val valuePrevotePolPacket =
    PacketAt(
      PacketTypePrevoteSignatures,
      0,
      1,
      1,
      2,
      TestValueIdHex,
      ValuePrevotePolSignBytes,
      ValuePrevotePolPacketHex,
    )

  pure val nilPrevotePacket =
    PacketAt(
      PacketTypePrevoteSignatures,
      1,
      0,
      0,
      1,
      TestValueIdHex,
      NilPrevoteSignBytes,
      NilPrevotePacketHex,
    )

  pure val valuePrecommitPacket =
    PacketAt(
      PacketTypePrecommitSignatures,
      0,
      1,
      0,
      1,
      TestValueIdHex,
      ValuePrecommitSignBytes,
      ValuePrecommitPacketHex,
    )

  def Evidence(
    proposal: ProposalChunkWire_t,
    packet: VotePacket_t,
    certifiedVotingPower: int,
  ): ProposalPolEvidence_t = {
    proposal: proposal,
    polPacket: packet,
    certifiedVotingPower: certifiedVotingPower,
    quorumVotingPower: FixtureQuorumVotingPower,
  }

  pure val matchingPolEvidence =
    Evidence(matchingPolProposalChunk, valuePrevotePolPacket, FixtureQuorumVotingPower)

  pure val mismatchedValueEvidence =
    Evidence(mismatchedValueProposalChunk, valuePrevotePolPacket, FixtureQuorumVotingPower)

  pure val nilPrevoteEvidence =
    Evidence(matchingPolProposalChunk, nilPrevotePacket, FixtureQuorumVotingPower)

  pure val precommitEvidence =
    Evidence(matchingPolProposalChunk, valuePrecommitPacket, FixtureQuorumVotingPower)

  pure val lowPowerEvidence =
    Evidence(matchingPolProposalChunk, valuePrevotePolPacket, 0)

  pure val TestNilProposals = Set(nilValidRoundChunk, matchingPolProposalChunk)
  pure val TestPolEvidence = Set(
    matchingPolEvidence,
    mismatchedValueEvidence,
    nilPrevoteEvidence,
    precommitEvidence,
    lowPowerEvidence,
  )

  action Next: bool =
    any {
      nondet proposal = oneOf(TestNilProposals)
      AcceptNilValidRoundProposal(proposal),
      nondet evidence = oneOf(TestPolEvidence)
      AcceptProposalWithPol(evidence),
      Stutter,
    }

  action unchangedAll = all {
    acceptedNilValidRoundProposals' = acceptedNilValidRoundProposals,
    acceptedProposalPolEvidence' = acceptedProposalPolEvidence,
    firedAction' = firedAction,
  }

  run nilValidRoundAcceptedWithoutPolTest = {
    Init
      .then(AcceptNilValidRoundProposal(nilValidRoundChunk))
      .then(all {
        assert(acceptedNilValidRoundProposals.contains(nilValidRoundChunk)),
        assert(Safety),
        unchangedAll,
      })
  }

  run nonnilValidRoundRejectedWithoutPolTest = {
    Init.then(AcceptNilValidRoundProposal(matchingPolProposalChunk)).fail()
  }

  run matchingPolEvidenceAcceptedTest = {
    Init
      .then(AcceptProposalWithPol(matchingPolEvidence))
      .then(all {
        assert(acceptedProposalPolEvidence.contains(matchingPolEvidence)),
        assert(ProposalPolEvidenceCanonical(matchingPolEvidence)),
        assert(Safety),
        unchangedAll,
      })
  }

  run mismatchedPolValueRejectedTest = {
    Init.then(AcceptProposalWithPol(mismatchedValueEvidence)).fail()
  }

  run nilPrevotePolRejectedTest = {
    Init.then(AcceptProposalWithPol(nilPrevoteEvidence)).fail()
  }

  run precommitPolRejectedTest = {
    Init.then(AcceptProposalWithPol(precommitEvidence)).fail()
  }

  run lowPowerPolRejectedTest = {
    Init.then(AcceptProposalWithPol(lowPowerEvidence)).fail()
  }

  run proposalPolSafetyTest = {
    Init.then(all {
      assert(Safety),
      unchangedAll,
    })
  }
}

module CrosslinkTenderlinkProposalPolEvidenceModel {
  import CrosslinkTenderlinkProposalPolEvidenceTest.* from
    "./CrosslinkTenderlinkProposalPolEvidence"
  export CrosslinkTenderlinkProposalPolEvidenceTest.*
}
