module CrosslinkMalachiteProposalGossipTransport {
  /*
   Malachite proposal protobuf gossip transport boundary.

   CrosslinkMalachiteProposalProtobufFormat.qnt pins exact proto3 bytes for
   raw proposals, signed proposal messages, and streamed proposal parts. This
   slice adds a Crosslink proposal-topic envelope before those decoder
   surfaces: accepted messages must have the expected envelope kind and exact
   canonical protobuf bytes.
   */

  import CrosslinkMalachiteProposalProtobufFormatTest.* from
    "./CrosslinkMalachiteProposalProtobufFormat"
  export CrosslinkMalachiteProposalProtobufFormatTest.*

  type ProposalTopic_t = str
  type ProposalEnvelopeKind_t = str
  type ProposalTransportEnvelope_t = {
    topic: ProposalTopic_t,
    kind: ProposalEnvelopeKind_t,
    proposal: MalProposalProto_t,
    signed: SignedProposalProto_t,
    streamed: StreamedProposalProto_t,
    bytes: Bytes_t,
  }

  pure val CrosslinkProposalTopic = "crosslink-proposal-v1"
  pure val WrongProposalTopic = "zcash-blocks-v1"
  pure val ProposalEnvelopeKind = "proposal"
  pure val SignedProposalEnvelopeKind = "signed-proposal"
  pure val StreamedProposalEnvelopeKind = "streamed-proposal"
  pure val WrongEnvelopeKind = "headers"

  var gossipedProposalEnvelope: Set[ProposalTransportEnvelope_t]
  var gossipedSignedProposalEnvelope: Set[ProposalTransportEnvelope_t]
  var gossipedStreamedProposalEnvelope: Set[ProposalTransportEnvelope_t]
  var proposalTransportFiredAction: str

  def Env(
    topic: ProposalTopic_t,
    kind: ProposalEnvelopeKind_t,
    proposal: MalProposalProto_t,
    signed: SignedProposalProto_t,
    streamed: StreamedProposalProto_t,
    bytes: Bytes_t,
  ): ProposalTransportEnvelope_t = {
    topic: topic,
    kind: kind,
    proposal: proposal,
    signed: signed,
    streamed: streamed,
    bytes: bytes,
  }

  def ProposalEnvelopeValid(env: ProposalTransportEnvelope_t): bool =
    env.topic == CrosslinkProposalTopic and
    env.kind == ProposalEnvelopeKind and
    ProposalProtoCanonical(env.proposal) and
    env.bytes == env.proposal.hex

  def SignedProposalEnvelopeValid(
    env: ProposalTransportEnvelope_t,
  ): bool =
    env.topic == CrosslinkProposalTopic and
    env.kind == SignedProposalEnvelopeKind and
    SignedProposalProtoCanonical(env.signed) and
    env.bytes == env.signed.hex

  def StreamedProposalEnvelopeValid(
    env: ProposalTransportEnvelope_t,
  ): bool =
    env.topic == CrosslinkProposalTopic and
    env.kind == StreamedProposalEnvelopeKind and
    StreamedProposalProtoCanonical(env.streamed) and
    env.bytes == env.streamed.hex

  def ProposalEnvelopeMatches(
    env: ProposalTransportEnvelope_t,
    proposal: MalProposalProto_t,
  ): bool =
    env.proposal == proposal and
    env.bytes == proposal.hex

  def SignedProposalEnvelopeMatches(
    env: ProposalTransportEnvelope_t,
    signed: SignedProposalProto_t,
  ): bool =
    env.signed == signed and
    env.bytes == signed.hex

  def StreamedProposalEnvelopeMatches(
    env: ProposalTransportEnvelope_t,
    streamed: StreamedProposalProto_t,
  ): bool =
    env.streamed == streamed and
    env.bytes == streamed.hex

  def MatchingProposalEnvelope(proposal: MalProposalProto_t): bool =
    gossipedProposalEnvelope.exists(env =>
      ProposalEnvelopeValid(env) and ProposalEnvelopeMatches(env, proposal)
    )

  def MatchingSignedProposalEnvelope(
    signed: SignedProposalProto_t,
  ): bool =
    gossipedSignedProposalEnvelope.exists(env =>
      SignedProposalEnvelopeValid(env) and
      SignedProposalEnvelopeMatches(env, signed)
    )

  def MatchingStreamedProposalEnvelope(
    streamed: StreamedProposalProto_t,
  ): bool =
    gossipedStreamedProposalEnvelope.exists(env =>
      StreamedProposalEnvelopeValid(env) and
      StreamedProposalEnvelopeMatches(env, streamed)
    )

  action TransportInit = all {
    Init,
    gossipedProposalEnvelope' = Set(),
    gossipedSignedProposalEnvelope' = Set(),
    gossipedStreamedProposalEnvelope' = Set(),
    proposalTransportFiredAction' = "TransportInit",
  }

  action KeepTransportState = all {
    gossipedProposalEnvelope' = gossipedProposalEnvelope,
    gossipedSignedProposalEnvelope' = gossipedSignedProposalEnvelope,
    gossipedStreamedProposalEnvelope' = gossipedStreamedProposalEnvelope,
  }

  action AcceptProposalTransport(
    env: ProposalTransportEnvelope_t,
  ): bool =
    all {
      ProposalEnvelopeValid(env),
      AcceptProposal(env.proposal),
      gossipedProposalEnvelope' = gossipedProposalEnvelope.union(Set(env)),
      gossipedSignedProposalEnvelope' = gossipedSignedProposalEnvelope,
      gossipedStreamedProposalEnvelope' = gossipedStreamedProposalEnvelope,
      proposalTransportFiredAction' = "AcceptProposalTransport",
    }

  action AcceptSignedProposalTransport(
    env: ProposalTransportEnvelope_t,
  ): bool =
    all {
      SignedProposalEnvelopeValid(env),
      AcceptSignedProposal(env.signed),
      gossipedProposalEnvelope' = gossipedProposalEnvelope,
      gossipedSignedProposalEnvelope' =
        gossipedSignedProposalEnvelope.union(Set(env)),
      gossipedStreamedProposalEnvelope' = gossipedStreamedProposalEnvelope,
      proposalTransportFiredAction' = "AcceptSignedProposalTransport",
    }

  action AcceptStreamedProposalTransport(
    env: ProposalTransportEnvelope_t,
  ): bool =
    all {
      StreamedProposalEnvelopeValid(env),
      AcceptStreamedProposal(env.streamed),
      gossipedProposalEnvelope' = gossipedProposalEnvelope,
      gossipedSignedProposalEnvelope' = gossipedSignedProposalEnvelope,
      gossipedStreamedProposalEnvelope' =
        gossipedStreamedProposalEnvelope.union(Set(env)),
      proposalTransportFiredAction' = "AcceptStreamedProposalTransport",
    }

  action RawAcceptSignedProposalWithoutTransport(
    signed: SignedProposalProto_t,
  ): bool =
    all {
      AcceptSignedProposal(signed),
      KeepTransportState,
      proposalTransportFiredAction' =
        "RawAcceptSignedProposalWithoutTransport",
    }

  action RawAcceptStreamedProposalWithoutTransport(
    streamed: StreamedProposalProto_t,
  ): bool =
    all {
      AcceptStreamedProposal(streamed),
      KeepTransportState,
      proposalTransportFiredAction' =
        "RawAcceptStreamedProposalWithoutTransport",
    }

  action TransportStutter: bool =
    all {
      Stutter,
      KeepTransportState,
      proposalTransportFiredAction' = proposalTransportFiredAction,
    }

  val GossipedProposalEnvelopesValid =
    gossipedProposalEnvelope.forall(ProposalEnvelopeValid)

  val GossipedSignedProposalEnvelopesValid =
    gossipedSignedProposalEnvelope.forall(SignedProposalEnvelopeValid)

  val GossipedStreamedProposalEnvelopesValid =
    gossipedStreamedProposalEnvelope.forall(StreamedProposalEnvelopeValid)

  val AcceptedProposalsHaveTransportEnvelope =
    acceptedProposals.forall(MatchingProposalEnvelope)

  val AcceptedSignedProposalsHaveTransportEnvelope =
    acceptedSignedProposals.forall(MatchingSignedProposalEnvelope)

  val AcceptedStreamedProposalsHaveTransportEnvelope =
    acceptedStreamedProposals.forall(MatchingStreamedProposalEnvelope)

  val TransportSafety =
    Safety and
    GossipedProposalEnvelopesValid and
    GossipedSignedProposalEnvelopesValid and
    GossipedStreamedProposalEnvelopesValid and
    AcceptedProposalsHaveTransportEnvelope and
    AcceptedSignedProposalsHaveTransportEnvelope and
    AcceptedStreamedProposalsHaveTransportEnvelope
}

module CrosslinkMalachiteProposalGossipTransportTest {
  import CrosslinkMalachiteProposalGossipTransport.* from
    "./CrosslinkMalachiteProposalGossipTransport"
  export CrosslinkMalachiteProposalGossipTransport.*

  pure val ProposalEnvelope =
    Env(
      CrosslinkProposalTopic,
      ProposalEnvelopeKind,
      ProposalWithPol,
      SignedProposal,
      StreamedProposal,
      ProposalWithPol.hex,
    )

  pure val SignedProposalEnvelope =
    Env(
      CrosslinkProposalTopic,
      SignedProposalEnvelopeKind,
      ProposalWithPol,
      SignedProposal,
      StreamedProposal,
      SignedProposal.hex,
    )

  pure val StreamedProposalEnvelope =
    Env(
      CrosslinkProposalTopic,
      StreamedProposalEnvelopeKind,
      ProposalWithPol,
      SignedProposal,
      StreamedProposal,
      StreamedProposal.hex,
    )

  pure val WrongTopicSignedProposalEnvelope =
    Env(
      WrongProposalTopic,
      SignedProposalEnvelopeKind,
      ProposalWithPol,
      SignedProposal,
      StreamedProposal,
      SignedProposal.hex,
    )

  pure val WrongKindSignedProposalEnvelope =
    Env(
      CrosslinkProposalTopic,
      WrongEnvelopeKind,
      ProposalWithPol,
      SignedProposal,
      StreamedProposal,
      SignedProposal.hex,
    )

  pure val WrongBytesSignedProposalEnvelope =
    Env(
      CrosslinkProposalTopic,
      SignedProposalEnvelopeKind,
      ProposalWithPol,
      SignedProposal,
      StreamedProposal,
      "wrong-signed-proposal-bytes",
    )

  pure val VoteOneofSignedProposalEnvelope =
    Env(
      CrosslinkProposalTopic,
      SignedProposalEnvelopeKind,
      ProposalWithPol,
      SignedProposalWithVoteOneofTag,
      StreamedProposal,
      SignedProposalWithVoteOneofTag.hex,
    )

  pure val WrongKindStreamedProposalEnvelope =
    Env(
      CrosslinkProposalTopic,
      WrongEnvelopeKind,
      ProposalWithPol,
      SignedProposal,
      StreamedProposal,
      StreamedProposal.hex,
    )

  pure val WrongBytesStreamedProposalEnvelope =
    Env(
      CrosslinkProposalTopic,
      StreamedProposalEnvelopeKind,
      ProposalWithPol,
      SignedProposal,
      StreamedProposal,
      "wrong-streamed-proposal-bytes",
    )

  pure val ShortProposerStreamedProposalEnvelope =
    Env(
      CrosslinkProposalTopic,
      StreamedProposalEnvelopeKind,
      ProposalWithPol,
      SignedProposal,
      StreamedProposalShortProposer,
      StreamedProposalShortProposer.hex,
    )

  pure val TestProposalTransportEnvelopes = Set(
    ProposalEnvelope,
    SignedProposalEnvelope,
    StreamedProposalEnvelope,
    WrongTopicSignedProposalEnvelope,
    WrongKindSignedProposalEnvelope,
    WrongBytesSignedProposalEnvelope,
    VoteOneofSignedProposalEnvelope,
    WrongKindStreamedProposalEnvelope,
    WrongBytesStreamedProposalEnvelope,
    ShortProposerStreamedProposalEnvelope,
  )

  action TransportNext: bool =
    any {
      nondet env = oneOf(TestProposalTransportEnvelopes)
      AcceptProposalTransport(env),
      nondet env = oneOf(TestProposalTransportEnvelopes)
      AcceptSignedProposalTransport(env),
      nondet env = oneOf(TestProposalTransportEnvelopes)
      AcceptStreamedProposalTransport(env),
      TransportStutter,
    }

  action transportUnchangedAll = all {
    acceptedProposals' = acceptedProposals,
    acceptedSignedProposals' = acceptedSignedProposals,
    acceptedStreamedProposals' = acceptedStreamedProposals,
    gossipedProposalEnvelope' = gossipedProposalEnvelope,
    gossipedSignedProposalEnvelope' = gossipedSignedProposalEnvelope,
    gossipedStreamedProposalEnvelope' = gossipedStreamedProposalEnvelope,
    malProposalFiredAction' = malProposalFiredAction,
    proposalTransportFiredAction' = proposalTransportFiredAction,
  }

  run acceptsProposalThroughTransportTest = {
    TransportInit
      .then(AcceptProposalTransport(ProposalEnvelope))
      .then(all {
        assert(acceptedProposals.contains(ProposalWithPol)),
        assert(TransportSafety),
        transportUnchangedAll,
      })
  }

  run acceptsSignedAndStreamedProposalsThroughTransportTest = {
    TransportInit
      .then(AcceptSignedProposalTransport(SignedProposalEnvelope))
      .then(AcceptStreamedProposalTransport(StreamedProposalEnvelope))
      .then(all {
        assert(acceptedSignedProposals.contains(SignedProposal)),
        assert(acceptedStreamedProposals.contains(StreamedProposal)),
        assert(TransportSafety),
        transportUnchangedAll,
      })
  }

  run rawSignedProposalWithoutTransportViolatesTransportSafetyTest = {
    TransportInit
      .then(RawAcceptSignedProposalWithoutTransport(SignedProposal))
      .then(all {
        assert(not(TransportSafety)),
        transportUnchangedAll,
      })
  }

  run rawStreamedProposalWithoutTransportViolatesTransportSafetyTest = {
    TransportInit
      .then(RawAcceptStreamedProposalWithoutTransport(StreamedProposal))
      .then(all {
        assert(not(TransportSafety)),
        transportUnchangedAll,
      })
  }

  run wrongTopicSignedProposalEnvelopeRejectedTest = {
    TransportInit
      .then(AcceptSignedProposalTransport(WrongTopicSignedProposalEnvelope))
      .fail()
  }

  run wrongKindSignedProposalEnvelopeRejectedTest = {
    TransportInit
      .then(AcceptSignedProposalTransport(WrongKindSignedProposalEnvelope))
      .fail()
  }

  run wrongBytesSignedProposalEnvelopeRejectedTest = {
    TransportInit
      .then(AcceptSignedProposalTransport(WrongBytesSignedProposalEnvelope))
      .fail()
  }

  run voteOneofSignedProposalEnvelopeRejectedTest = {
    TransportInit
      .then(AcceptSignedProposalTransport(VoteOneofSignedProposalEnvelope))
      .fail()
  }

  run wrongKindStreamedProposalEnvelopeRejectedTest = {
    TransportInit
      .then(AcceptStreamedProposalTransport(WrongKindStreamedProposalEnvelope))
      .fail()
  }

  run wrongBytesStreamedProposalEnvelopeRejectedTest = {
    TransportInit
      .then(AcceptStreamedProposalTransport(WrongBytesStreamedProposalEnvelope))
      .fail()
  }

  run shortProposerStreamedProposalEnvelopeRejectedTest = {
    TransportInit
      .then(AcceptStreamedProposalTransport(ShortProposerStreamedProposalEnvelope))
      .fail()
  }

  run proposalTransportSafetyTest = {
    TransportInit.then(all {
      assert(TransportSafety),
      transportUnchangedAll,
    })
  }
}

module CrosslinkMalachiteProposalGossipTransportModel {
  import CrosslinkMalachiteProposalGossipTransportTest.* from
    "./CrosslinkMalachiteProposalGossipTransport"
  export CrosslinkMalachiteProposalGossipTransportTest.*
}
