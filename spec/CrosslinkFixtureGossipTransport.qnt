module CrosslinkFixtureGossipTransport {
  /*
   Fixture transport-gossip bridge.

   CrosslinkFixtureAuthenticatedEvidence.qnt routes a generated fixture fat
   pointer through the authenticated observer pipeline, but it gossips the
   matching precommit directly. This model inserts a small production-shaped
   transport boundary: the fixture precommit and fixture fat-pointer wire must
   first appear in canonical Crosslink gossip envelopes, on the Crosslink topic,
   before the observer can accept the fat-pointer wire.

   The bytes remain compact Quint tokens here. The generated fixture manifest
   and fixture-manifest script pin and verify the real payload/pubkey/signature
   bytes outside the model.
   */

  import CrosslinkFixtureAuthenticatedEvidence.* from "./CrosslinkFixtureAuthenticatedEvidence"
  export CrosslinkFixtureAuthenticatedEvidence.*

  type Topic_t = str
  type TransportKind_t = str
  type FixtureTransportEnvelope_t = {
    topic: Topic_t,
    kind: TransportKind_t,
    height: Height_t,
    round: Round_t,
    blockHash: BlockHash_t,
    pubKey: PubKey_t,
    signBytes: Bytes_t,
    voteSignature: Signature_t,
    wireByteLen: int,
  }

  pure val CrosslinkGossipTopic = "crosslink-consensus-v1"
  pure val WrongGossipTopic = "zcash-blocks-v1"
  pure val PrecommitEnvelopeKind = "precommit"
  pure val FatPointerWireEnvelopeKind = "fat-pointer-wire"
  pure val WrongEnvelopeKind = "headers"

  var gossipedFixturePrecommitEnvelope: Set[FixtureTransportEnvelope_t]
  var gossipedFixtureFatPointerWireEnvelope: Set[FixtureTransportEnvelope_t]
  var transportFiredAction: str

  def Env(
    topic: Topic_t,
    kind: TransportKind_t,
    height: Height_t,
    round: Round_t,
    blockHash: BlockHash_t,
    pubKey: PubKey_t,
    signBytes: Bytes_t,
    voteSignature: Signature_t,
    wireByteLen: int,
  ): FixtureTransportEnvelope_t = {
    topic: topic,
    kind: kind,
    height: height,
    round: round,
    blockHash: blockHash,
    pubKey: pubKey,
    signBytes: signBytes,
    voteSignature: voteSignature,
    wireByteLen: wireByteLen,
  }

  pure val FixturePrecommitEnvelope =
    Env(
      CrosslinkGossipTopic,
      PrecommitEnvelopeKind,
      FixtureBftHeight,
      FixtureRound,
      FixtureBlockHash,
      FixturePubKey,
      FixtureSignBytes,
      FixtureVoteSignature,
      0,
    )

  pure val FixtureFatPointerWireEnvelope =
    Env(
      CrosslinkGossipTopic,
      FatPointerWireEnvelopeKind,
      FixtureBftHeight,
      FixtureRound,
      FixtureBlockHash,
      FixturePubKey,
      FixtureSignBytes,
      FixtureVoteSignature,
      FixtureWire.byteLen,
    )

  pure val WrongTopicPrecommitEnvelope =
    Env(
      WrongGossipTopic,
      PrecommitEnvelopeKind,
      FixtureBftHeight,
      FixtureRound,
      FixtureBlockHash,
      FixturePubKey,
      FixtureSignBytes,
      FixtureVoteSignature,
      0,
    )

  pure val WrongSignBytesPrecommitEnvelope =
    Env(
      CrosslinkGossipTopic,
      PrecommitEnvelopeKind,
      FixtureBftHeight,
      FixtureRound,
      FixtureBlockHash,
      FixturePubKey,
      "wrong-sign-bytes",
      FixtureVoteSignature,
      0,
    )

  pure val WrongWireLengthFatPointerEnvelope =
    Env(
      CrosslinkGossipTopic,
      FatPointerWireEnvelopeKind,
      FixtureBftHeight,
      FixtureRound,
      FixtureBlockHash,
      FixturePubKey,
      FixtureSignBytes,
      FixtureVoteSignature,
      FixtureWire.byteLen + 1,
    )

  pure val WrongKindFatPointerEnvelope =
    Env(
      CrosslinkGossipTopic,
      WrongEnvelopeKind,
      FixtureBftHeight,
      FixtureRound,
      FixtureBlockHash,
      FixturePubKey,
      FixtureSignBytes,
      FixtureVoteSignature,
      FixtureWire.byteLen,
    )

  def PrecommitEnvelopeMatchesFixture(env: FixtureTransportEnvelope_t): bool =
    env.topic == CrosslinkGossipTopic and
    env.kind == PrecommitEnvelopeKind and
    env.height == FixtureBftHeight and
    env.round == FixtureRound and
    env.blockHash == FixtureBlockHash and
    env.pubKey == FixturePubKey and
    env.signBytes == FixtureSignBytes and
    env.voteSignature == FixtureVoteSignature and
    env.wireByteLen == 0

  def FatPointerWireEnvelopeMatchesFixture(
    env: FixtureTransportEnvelope_t,
  ): bool =
    env.topic == CrosslinkGossipTopic and
    env.kind == FatPointerWireEnvelopeKind and
    env.height == FixtureBftHeight and
    env.round == FixtureRound and
    env.blockHash == FixtureBlockHash and
    env.pubKey == FixturePubKey and
    env.signBytes == FixtureSignBytes and
    env.voteSignature == FixtureVoteSignature and
    env.wireByteLen == FixtureWire.byteLen and
    GeneratedFixtureWireConstantsCoherent

  def FixturePrecommitTransportEnvelopeValid(
    env: FixtureTransportEnvelope_t,
  ): bool =
    PrecommitEnvelopeMatchesFixture(env) and
    ProductionPrecommitAuthentic(FixtureBftHeight, FixtureRound, FixtureCommit)

  def FixtureFatPointerWireTransportEnvelopeValid(
    env: FixtureTransportEnvelope_t,
  ): bool =
    FatPointerWireEnvelopeMatchesFixture(env) and
    FatPointerWireEnvelopeValid(FixtureWire)

  action TransportPipelineInit = all {
    PipelineInit,
    gossipedFixturePrecommitEnvelope' = Set(),
    gossipedFixtureFatPointerWireEnvelope' = Set(),
    transportFiredAction' = "TransportPipelineInit",
  }

  action KeepTransportState = all {
    gossipedFixturePrecommitEnvelope' = gossipedFixturePrecommitEnvelope,
    gossipedFixtureFatPointerWireEnvelope' = gossipedFixtureFatPointerWireEnvelope,
  }

  action GossipFixturePrecommitTransport(
    env: FixtureTransportEnvelope_t,
  ): bool =
    all {
      FixturePrecommitTransportEnvelopeValid(env),
      KeepFormatState,
      gossipedPrecommit' =
        gossipedPrecommit.setBy(FixtureBftHeight, byRound =>
          byRound.setBy(FixtureRound, old => old.union(Set(FixtureCommit)))
        ),
      observedProductionFatPointer' = observedProductionFatPointer,
      observedProductionFatPointerWire' = observedProductionFatPointerWire,
      gossipedFixturePrecommitEnvelope' =
        gossipedFixturePrecommitEnvelope.union(Set(env)),
      gossipedFixtureFatPointerWireEnvelope' = gossipedFixtureFatPointerWireEnvelope,
      firedAction' = "GossipFixturePrecommitTransport",
      transportFiredAction' = "GossipFixturePrecommitTransport",
    }

  action GossipFixtureFatPointerWireTransport(
    env: FixtureTransportEnvelope_t,
  ): bool =
    all {
      FixtureFatPointerWireTransportEnvelopeValid(env),
      KeepFormatState,
      gossipedPrecommit' = gossipedPrecommit,
      observedProductionFatPointer' = observedProductionFatPointer,
      observedProductionFatPointerWire' = observedProductionFatPointerWire,
      gossipedFixturePrecommitEnvelope' = gossipedFixturePrecommitEnvelope,
      gossipedFixtureFatPointerWireEnvelope' =
        gossipedFixtureFatPointerWireEnvelope.union(Set(env)),
      firedAction' = "GossipFixtureFatPointerWireTransport",
      transportFiredAction' = "GossipFixtureFatPointerWireTransport",
    }

  action ObserveFixtureFatPointerWireFromTransport(
    env: FixtureTransportEnvelope_t,
  ): bool =
    all {
      gossipedFixtureFatPointerWireEnvelope.contains(env),
      FixtureFatPointerWireTransportEnvelopeValid(env),
      ProductionFatPointerWireEvidenceValid(FixtureWire),
      acceptedFatPointers' = acceptedFatPointers.union(Set(FixtureFatPointer)),
      acceptedFatPointerWires' = acceptedFatPointerWires.union(Set(FixtureWire)),
      gossipedPrecommit' = gossipedPrecommit,
      observedProductionFatPointer' =
        observedProductionFatPointer.union(Set(FixtureFatPointer)),
      observedProductionFatPointerWire' =
        observedProductionFatPointerWire.union(Set(FixtureWire)),
      KeepTransportState,
      firedAction' = "ObserveFixtureFatPointerWireFromTransport",
      transportFiredAction' = "ObserveFixtureFatPointerWireFromTransport",
    }

  action TransportPipelineStutter: bool =
    all {
      PipelineStutter,
      KeepTransportState,
      transportFiredAction' = transportFiredAction,
    }

  val GossipedPrecommitTransportEnvelopesValid =
    gossipedFixturePrecommitEnvelope.forall(
      FixturePrecommitTransportEnvelopeValid
    )

  val GossipedFatPointerWireTransportEnvelopesValid =
    gossipedFixtureFatPointerWireEnvelope.forall(
      FixtureFatPointerWireTransportEnvelopeValid
    )

  val ObservedWireHasTransportEnvelope =
    if (observedProductionFatPointerWire.contains(FixtureWire)) {
      gossipedFixtureFatPointerWireEnvelope.exists(
        FixtureFatPointerWireTransportEnvelopeValid
      )
    } else {
      true
    }

  val GossipedFixturePrecommitHasTransportEnvelope =
    if (
      gossipedPrecommit
        .get(FixtureBftHeight)
        .get(FixtureRound)
        .contains(FixtureCommit)
    ) {
      gossipedFixturePrecommitEnvelope.exists(
        FixturePrecommitTransportEnvelopeValid
      )
    } else {
      true
    }

  val TransportSafety =
    FixtureSafety and
    GossipedPrecommitTransportEnvelopesValid and
    GossipedFatPointerWireTransportEnvelopesValid and
    ObservedWireHasTransportEnvelope and
    GossipedFixturePrecommitHasTransportEnvelope
}

module CrosslinkFixtureGossipTransportTest {
  import CrosslinkFixtureGossipTransport.* from "./CrosslinkFixtureGossipTransport"
  export CrosslinkFixtureGossipTransport.*

  pure val TestTransportEnvelopes = Set(
    FixturePrecommitEnvelope,
    FixtureFatPointerWireEnvelope,
    WrongTopicPrecommitEnvelope,
    WrongSignBytesPrecommitEnvelope,
    WrongWireLengthFatPointerEnvelope,
    WrongKindFatPointerEnvelope,
  )

  action TransportNext: bool =
    any {
      nondet env = oneOf(TestTransportEnvelopes)
      GossipFixturePrecommitTransport(env),
      nondet env = oneOf(TestTransportEnvelopes)
      GossipFixtureFatPointerWireTransport(env),
      nondet env = oneOf(TestTransportEnvelopes)
      ObserveFixtureFatPointerWireFromTransport(env),
      TransportPipelineStutter,
    }

  action transportUnchangedAll = all {
    acceptedFatPointers' = acceptedFatPointers,
    acceptedFatPointerWires' = acceptedFatPointerWires,
    gossipedPrecommit' = gossipedPrecommit,
    observedProductionFatPointer' = observedProductionFatPointer,
    observedProductionFatPointerWire' = observedProductionFatPointerWire,
    gossipedFixturePrecommitEnvelope' = gossipedFixturePrecommitEnvelope,
    gossipedFixtureFatPointerWireEnvelope' = gossipedFixtureFatPointerWireEnvelope,
    firedAction' = firedAction,
    transportFiredAction' = transportFiredAction,
  }

  run fixtureWireObservedThroughTransportTest = {
    TransportPipelineInit
      .then(GossipFixturePrecommitTransport(FixturePrecommitEnvelope))
      .then(GossipFixtureFatPointerWireTransport(FixtureFatPointerWireEnvelope))
      .then(ObserveFixtureFatPointerWireFromTransport(FixtureFatPointerWireEnvelope))
      .then(all {
        assert(gossipedFixturePrecommitEnvelope.contains(FixturePrecommitEnvelope)),
        assert(gossipedFixtureFatPointerWireEnvelope.contains(FixtureFatPointerWireEnvelope)),
        assert(observedProductionFatPointerWire.contains(FixtureWire)),
        assert(TransportSafety),
        transportUnchangedAll,
      })
  }

  run fixtureWireRejectedBeforeWireTransportTest = {
    TransportPipelineInit
      .then(GossipFixturePrecommitTransport(FixturePrecommitEnvelope))
      .then(ObserveFixtureFatPointerWireFromTransport(FixtureFatPointerWireEnvelope))
      .fail()
  }

  run fixtureWireRejectedBeforePrecommitTransportTest = {
    TransportPipelineInit
      .then(GossipFixtureFatPointerWireTransport(FixtureFatPointerWireEnvelope))
      .then(ObserveFixtureFatPointerWireFromTransport(FixtureFatPointerWireEnvelope))
      .fail()
  }

  run wrongTopicPrecommitEnvelopeRejectedTest = {
    TransportPipelineInit
      .then(GossipFixturePrecommitTransport(WrongTopicPrecommitEnvelope))
      .fail()
  }

  run wrongSignBytesPrecommitEnvelopeRejectedTest = {
    TransportPipelineInit
      .then(GossipFixturePrecommitTransport(WrongSignBytesPrecommitEnvelope))
      .fail()
  }

  run wrongWireLengthFatPointerEnvelopeRejectedTest = {
    TransportPipelineInit
      .then(GossipFixtureFatPointerWireTransport(WrongWireLengthFatPointerEnvelope))
      .fail()
  }

  run wrongKindFatPointerEnvelopeRejectedTest = {
    TransportPipelineInit
      .then(GossipFixtureFatPointerWireTransport(WrongKindFatPointerEnvelope))
      .fail()
  }

  run transportSafetyTest = {
    TransportPipelineInit
      .then(all {
        assert(TransportSafety),
        transportUnchangedAll,
      })
  }
}

module CrosslinkFixtureGossipTransportModel {
  import CrosslinkFixtureGossipTransportTest(
    Validators = Set("fixture-validator"),
    PubKeys = Set("fixture-pubkey"),
    VotingPower = Map("fixture-validator" -> 3),
    QuorumVotingPower = 3,
    MaxBftHeight = 1,
    MaxRound = 0,
    MaxSignatures = 1,
    NilBlockHash = "nil",
    AuthorizedAt = Map(1 -> Set("fixture-validator")),
    PubKeyOwner = Map("fixture-pubkey" -> "fixture-validator"),
    FatPointerSignBytes = Map(
      1 -> Map(
        0 -> Map(
          "fixture-bft-block" -> Map(
            "fixture-pubkey" -> "fixture-sign-bytes",
          ),
        ),
      ),
    ),
    SignatureVerifier = Map(
      "fixture-pubkey" -> Map(
        "fixture-sign-bytes" -> "fixture-vote-signature",
      ),
    ),
  ).*
}
