module CrosslinkMalachiteLivenessGossipTransport {
  /*
   Malachite liveness protobuf gossip transport boundary.

   CrosslinkMalachiteLivenessProtobufFormat.qnt pins exact proto3 bytes for
   polka certificates, skip-round nil certificates, and value precommit round
   certificates. This slice adds the Crosslink liveness-topic envelope before
   those decoder surfaces: accepted liveness messages must have the expected
   envelope kind and exact canonical protobuf bytes.
   */

  import CrosslinkMalachiteLivenessProtobufFormatTest.* from "./CrosslinkMalachiteLivenessProtobufFormat"
  export CrosslinkMalachiteLivenessProtobufFormatTest.*

  type LivenessTopic_t = str
  type LivenessEnvelopeKind_t = str
  type LivenessTransportEnvelope_t = {
    topic: LivenessTopic_t,
    kind: LivenessEnvelopeKind_t,
    polka: LivenessPolkaMessageProto_t,
    roundMessage: LivenessRoundMessageProto_t,
    bytes: Bytes_t,
  }

  pure val CrosslinkLivenessTopic = "crosslink-liveness-v1"
  pure val WrongLivenessTopic = "zcash-blocks-v1"
  pure val LivenessPolkaEnvelopeKind = "liveness-polka"
  pure val LivenessRoundEnvelopeKind = "liveness-round"
  pure val WrongEnvelopeKind = "headers"

  var gossipedPolkaEnvelope: Set[LivenessTransportEnvelope_t]
  var gossipedRoundEnvelope: Set[LivenessTransportEnvelope_t]
  var livenessTransportFiredAction: str

  def Env(
    topic: LivenessTopic_t,
    kind: LivenessEnvelopeKind_t,
    polka: LivenessPolkaMessageProto_t,
    roundMessage: LivenessRoundMessageProto_t,
    bytes: Bytes_t,
  ): LivenessTransportEnvelope_t = {
    topic: topic,
    kind: kind,
    polka: polka,
    roundMessage: roundMessage,
    bytes: bytes,
  }

  def PolkaEnvelopeValid(env: LivenessTransportEnvelope_t): bool =
    env.topic == CrosslinkLivenessTopic and
    env.kind == LivenessPolkaEnvelopeKind and
    LivenessPolkaMessageProtoCanonical(env.polka) and
    env.bytes == env.polka.hex

  def RoundEnvelopeValid(env: LivenessTransportEnvelope_t): bool =
    env.topic == CrosslinkLivenessTopic and
    env.kind == LivenessRoundEnvelopeKind and
    LivenessRoundMessageProtoCanonical(env.roundMessage) and
    env.bytes == env.roundMessage.hex

  def PolkaEnvelopeMatches(
    env: LivenessTransportEnvelope_t,
    polka: LivenessPolkaMessageProto_t,
  ): bool =
    env.polka == polka and
    env.bytes == polka.hex

  def RoundEnvelopeMatches(
    env: LivenessTransportEnvelope_t,
    roundMessage: LivenessRoundMessageProto_t,
  ): bool =
    env.roundMessage == roundMessage and
    env.bytes == roundMessage.hex

  def MatchingPolkaEnvelope(polka: LivenessPolkaMessageProto_t): bool =
    gossipedPolkaEnvelope.exists(env =>
      PolkaEnvelopeValid(env) and PolkaEnvelopeMatches(env, polka)
    )

  def MatchingRoundEnvelope(
    roundMessage: LivenessRoundMessageProto_t,
  ): bool =
    gossipedRoundEnvelope.exists(env =>
      RoundEnvelopeValid(env) and RoundEnvelopeMatches(env, roundMessage)
    )

  action TransportInit = all {
    Init,
    gossipedPolkaEnvelope' = Set(),
    gossipedRoundEnvelope' = Set(),
    livenessTransportFiredAction' = "TransportInit",
  }

  action KeepTransportState = all {
    gossipedPolkaEnvelope' = gossipedPolkaEnvelope,
    gossipedRoundEnvelope' = gossipedRoundEnvelope,
  }

  action AcceptPolkaTransport(
    env: LivenessTransportEnvelope_t,
  ): bool =
    all {
      PolkaEnvelopeValid(env),
      AcceptPolkaMessage(env.polka),
      gossipedPolkaEnvelope' = gossipedPolkaEnvelope.union(Set(env)),
      gossipedRoundEnvelope' = gossipedRoundEnvelope,
      livenessTransportFiredAction' = "AcceptPolkaTransport",
    }

  action AcceptRoundTransport(
    env: LivenessTransportEnvelope_t,
  ): bool =
    all {
      RoundEnvelopeValid(env),
      AcceptRoundMessage(env.roundMessage),
      gossipedPolkaEnvelope' = gossipedPolkaEnvelope,
      gossipedRoundEnvelope' = gossipedRoundEnvelope.union(Set(env)),
      livenessTransportFiredAction' = "AcceptRoundTransport",
    }

  action RawAcceptPolkaWithoutTransport(
    polka: LivenessPolkaMessageProto_t,
  ): bool =
    all {
      AcceptPolkaMessage(polka),
      KeepTransportState,
      livenessTransportFiredAction' = "RawAcceptPolkaWithoutTransport",
    }

  action RawAcceptRoundWithoutTransport(
    roundMessage: LivenessRoundMessageProto_t,
  ): bool =
    all {
      AcceptRoundMessage(roundMessage),
      KeepTransportState,
      livenessTransportFiredAction' = "RawAcceptRoundWithoutTransport",
    }

  action TransportStutter: bool =
    all {
      Stutter,
      KeepTransportState,
      livenessTransportFiredAction' = livenessTransportFiredAction,
    }

  val GossipedPolkaEnvelopesValid =
    gossipedPolkaEnvelope.forall(PolkaEnvelopeValid)

  val GossipedRoundEnvelopesValid =
    gossipedRoundEnvelope.forall(RoundEnvelopeValid)

  val AcceptedPolkaMessagesHaveTransportEnvelope =
    acceptedPolkaMessages.forall(MatchingPolkaEnvelope)

  val AcceptedRoundMessagesHaveTransportEnvelope =
    acceptedRoundMessages.forall(MatchingRoundEnvelope)

  val TransportSafety =
    Safety and
    GossipedPolkaEnvelopesValid and
    GossipedRoundEnvelopesValid and
    AcceptedPolkaMessagesHaveTransportEnvelope and
    AcceptedRoundMessagesHaveTransportEnvelope
}

module CrosslinkMalachiteLivenessGossipTransportTest {
  import CrosslinkMalachiteLivenessGossipTransport.* from "./CrosslinkMalachiteLivenessGossipTransport"
  export CrosslinkMalachiteLivenessGossipTransport.*

  pure val PolkaEnvelope =
    Env(
      CrosslinkLivenessTopic,
      LivenessPolkaEnvelopeKind,
      LivenessPolkaMessage,
      LivenessRoundSkipMessage,
      LivenessPolkaMessage.hex,
    )

  pure val RoundSkipEnvelope =
    Env(
      CrosslinkLivenessTopic,
      LivenessRoundEnvelopeKind,
      LivenessPolkaMessage,
      LivenessRoundSkipMessage,
      LivenessRoundSkipMessage.hex,
    )

  pure val RoundPrecommitEnvelope =
    Env(
      CrosslinkLivenessTopic,
      LivenessRoundEnvelopeKind,
      LivenessPolkaMessage,
      LivenessRoundPrecommitMessage,
      LivenessRoundPrecommitMessage.hex,
    )

  pure val WrongTopicPolkaEnvelope =
    Env(
      WrongLivenessTopic,
      LivenessPolkaEnvelopeKind,
      LivenessPolkaMessage,
      LivenessRoundSkipMessage,
      LivenessPolkaMessage.hex,
    )

  pure val WrongKindPolkaEnvelope =
    Env(
      CrosslinkLivenessTopic,
      WrongEnvelopeKind,
      LivenessPolkaMessage,
      LivenessRoundSkipMessage,
      LivenessPolkaMessage.hex,
    )

  pure val WrongBytesPolkaEnvelope =
    Env(
      CrosslinkLivenessTopic,
      LivenessPolkaEnvelopeKind,
      LivenessPolkaMessage,
      LivenessRoundSkipMessage,
      "wrong-liveness-polka-bytes",
    )

  pure val VoteOneofPolkaEnvelope =
    Env(
      CrosslinkLivenessTopic,
      LivenessPolkaEnvelopeKind,
      LivenessPolkaWithVoteTag,
      LivenessRoundSkipMessage,
      LivenessPolkaWithVoteTag.hex,
    )

  pure val MissingValuePolkaEnvelope =
    Env(
      CrosslinkLivenessTopic,
      LivenessPolkaEnvelopeKind,
      LivenessPolkaMessageProto(
        111,
        LivenessMessagePolkaCertificateTag,
        PolkaCertificateMissingValue,
        "126c0801100222660a20000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f12420a40404142434445464748494a4b4c4d4e4f505152535455565758595a5b5c5d5e5f606162636465666768696a6b6c6d6e6f707172737475767778797a7b7c7d7e7f",
      ),
      LivenessRoundSkipMessage,
      "126c0801100222660a20000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f12420a40404142434445464748494a4b4c4d4e4f505152535455565758595a5b5c5d5e5f606162636465666768696a6b6c6d6e6f707172737475767778797a7b7c7d7e7f",
    )

  pure val WrongKindRoundEnvelope =
    Env(
      CrosslinkLivenessTopic,
      WrongEnvelopeKind,
      LivenessPolkaMessage,
      LivenessRoundSkipMessage,
      LivenessRoundSkipMessage.hex,
    )

  pure val WrongBytesRoundEnvelope =
    Env(
      CrosslinkLivenessTopic,
      LivenessRoundEnvelopeKind,
      LivenessPolkaMessage,
      LivenessRoundSkipMessage,
      "wrong-liveness-round-bytes",
    )

  pure val PolkaOneofRoundEnvelope =
    Env(
      CrosslinkLivenessTopic,
      LivenessRoundEnvelopeKind,
      LivenessPolkaMessage,
      LivenessRoundWithPolkaTag,
      LivenessRoundWithPolkaTag.hex,
    )

  pure val PrecommitNilRoundEnvelope =
    Env(
      CrosslinkLivenessTopic,
      LivenessRoundEnvelopeKind,
      LivenessPolkaMessage,
      LivenessRoundMessageProto(
        110,
        LivenessMessageRoundCertificateTag,
        RoundCertificatePrecommitNil,
        "1a6c08011002226808011220000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f1a420a40404142434445464748494a4b4c4d4e4f505152535455565758595a5b5c5d5e5f606162636465666768696a6b6c6d6e6f707172737475767778797a7b7c7d7e7f",
      ),
      "1a6c08011002226808011220000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f1a420a40404142434445464748494a4b4c4d4e4f505152535455565758595a5b5c5d5e5f606162636465666768696a6b6c6d6e6f707172737475767778797a7b7c7d7e7f",
    )

  pure val SkipValueRoundEnvelope =
    Env(
      CrosslinkLivenessTopic,
      LivenessRoundEnvelopeKind,
      LivenessPolkaMessage,
      LivenessRoundMessageProto(
        151,
        LivenessMessageRoundCertificateTag,
        RoundCertificateSkipValue,
        "1a9401080110021801228c0108011220000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f1a420a40404142434445464748494a4b4c4d4e4f505152535455565758595a5b5c5d5e5f606162636465666768696a6b6c6d6e6f707172737475767778797a7b7c7d7e7f22220a20808182838485868788898a8b8c8d8e8f909192939495969798999a9b9c9d9e9f",
      ),
      "1a9401080110021801228c0108011220000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f1a420a40404142434445464748494a4b4c4d4e4f505152535455565758595a5b5c5d5e5f606162636465666768696a6b6c6d6e6f707172737475767778797a7b7c7d7e7f22220a20808182838485868788898a8b8c8d8e8f909192939495969798999a9b9c9d9e9f",
    )

  pure val TestLivenessTransportEnvelopes = Set(
    PolkaEnvelope,
    RoundSkipEnvelope,
    RoundPrecommitEnvelope,
    WrongTopicPolkaEnvelope,
    WrongKindPolkaEnvelope,
    WrongBytesPolkaEnvelope,
    VoteOneofPolkaEnvelope,
    MissingValuePolkaEnvelope,
    WrongKindRoundEnvelope,
    WrongBytesRoundEnvelope,
    PolkaOneofRoundEnvelope,
    PrecommitNilRoundEnvelope,
    SkipValueRoundEnvelope,
  )

  action TransportNext: bool =
    any {
      nondet env = oneOf(TestLivenessTransportEnvelopes)
      AcceptPolkaTransport(env),
      nondet env = oneOf(TestLivenessTransportEnvelopes)
      AcceptRoundTransport(env),
      TransportStutter,
    }

  action transportUnchangedAll = all {
    acceptedPolkaMessages' = acceptedPolkaMessages,
    acceptedRoundMessages' = acceptedRoundMessages,
    gossipedPolkaEnvelope' = gossipedPolkaEnvelope,
    gossipedRoundEnvelope' = gossipedRoundEnvelope,
    livenessFiredAction' = livenessFiredAction,
    livenessTransportFiredAction' = livenessTransportFiredAction,
  }

  run acceptsPolkaThroughTransportTest = {
    TransportInit
      .then(AcceptPolkaTransport(PolkaEnvelope))
      .then(all {
        assert(acceptedPolkaMessages.contains(LivenessPolkaMessage)),
        assert(TransportSafety),
        transportUnchangedAll,
      })
  }

  run acceptsRoundMessagesThroughTransportTest = {
    TransportInit
      .then(AcceptRoundTransport(RoundSkipEnvelope))
      .then(AcceptRoundTransport(RoundPrecommitEnvelope))
      .then(all {
        assert(acceptedRoundMessages.contains(LivenessRoundSkipMessage)),
        assert(acceptedRoundMessages.contains(LivenessRoundPrecommitMessage)),
        assert(TransportSafety),
        transportUnchangedAll,
      })
  }

  run rawPolkaWithoutTransportViolatesTransportSafetyTest = {
    TransportInit
      .then(RawAcceptPolkaWithoutTransport(LivenessPolkaMessage))
      .then(all {
        assert(not(TransportSafety)),
        transportUnchangedAll,
      })
  }

  run rawRoundWithoutTransportViolatesTransportSafetyTest = {
    TransportInit
      .then(RawAcceptRoundWithoutTransport(LivenessRoundSkipMessage))
      .then(all {
        assert(not(TransportSafety)),
        transportUnchangedAll,
      })
  }

  run wrongTopicPolkaEnvelopeRejectedTest = {
    TransportInit
      .then(AcceptPolkaTransport(WrongTopicPolkaEnvelope))
      .fail()
  }

  run wrongKindPolkaEnvelopeRejectedTest = {
    TransportInit
      .then(AcceptPolkaTransport(WrongKindPolkaEnvelope))
      .fail()
  }

  run wrongBytesPolkaEnvelopeRejectedTest = {
    TransportInit
      .then(AcceptPolkaTransport(WrongBytesPolkaEnvelope))
      .fail()
  }

  run voteOneofPolkaEnvelopeRejectedTest = {
    TransportInit
      .then(AcceptPolkaTransport(VoteOneofPolkaEnvelope))
      .fail()
  }

  run missingValuePolkaEnvelopeRejectedTest = {
    TransportInit
      .then(AcceptPolkaTransport(MissingValuePolkaEnvelope))
      .fail()
  }

  run wrongKindRoundEnvelopeRejectedTest = {
    TransportInit
      .then(AcceptRoundTransport(WrongKindRoundEnvelope))
      .fail()
  }

  run wrongBytesRoundEnvelopeRejectedTest = {
    TransportInit
      .then(AcceptRoundTransport(WrongBytesRoundEnvelope))
      .fail()
  }

  run polkaOneofRoundEnvelopeRejectedTest = {
    TransportInit
      .then(AcceptRoundTransport(PolkaOneofRoundEnvelope))
      .fail()
  }

  run precommitNilRoundEnvelopeRejectedTest = {
    TransportInit
      .then(AcceptRoundTransport(PrecommitNilRoundEnvelope))
      .fail()
  }

  run skipValueRoundEnvelopeRejectedTest = {
    TransportInit
      .then(AcceptRoundTransport(SkipValueRoundEnvelope))
      .fail()
  }

  run livenessTransportSafetyTest = {
    TransportInit.then(all {
      assert(TransportSafety),
      transportUnchangedAll,
    })
  }
}

module CrosslinkMalachiteLivenessGossipTransportModel {
  import CrosslinkMalachiteLivenessGossipTransportTest.* from
    "./CrosslinkMalachiteLivenessGossipTransport"
  export CrosslinkMalachiteLivenessGossipTransportTest.*
}
