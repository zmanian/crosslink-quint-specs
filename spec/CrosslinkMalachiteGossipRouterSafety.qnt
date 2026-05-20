module CrosslinkMalachiteGossipRouterSafety {
  /*
   Verifier-friendly Malachite gossip router safety slice.

   CrosslinkMalachiteGossipRouter.qnt composes the proposal, liveness, and sync
   transport machines with alias imports. The Apalache flattener currently does
   not handle that imported shape reliably, so this module keeps the shared
   router namespace contract as a small direct state machine for bounded safety
   verification.
   */

  import CrosslinkMalachiteProposalProtobufFormat as ProposalFormat from
    "./CrosslinkMalachiteProposalProtobufFormat"
  import CrosslinkMalachiteLivenessProtobufFormat as LivenessFormat from
    "./CrosslinkMalachiteLivenessProtobufFormat"
  import CrosslinkMalachiteSyncProtobufFormat as SyncFormat from
    "./CrosslinkMalachiteSyncProtobufFormat"

  type RouterChannel_t = str
  type RouterTopic_t = str
  type RouterKind_t = str
  type RouterBytes_t = str
  type RoutedEnvelope_t = {
    channel: RouterChannel_t,
    topic: RouterTopic_t,
    kind: RouterKind_t,
    bytes: RouterBytes_t,
  }

  pure val ProposalChannel = "malachite-proposal-channel"
  pure val LivenessChannel = "malachite-liveness-channel"
  pure val SyncChannel = "malachite-sync-channel"
  pure val UnknownChannel = "malachite-unknown-channel"

  pure val ProposalTopic = "crosslink-proposal-v1"
  pure val LivenessTopic = "crosslink-liveness-v1"
  pure val SyncTopic = "crosslink-sync-v1"
  pure val WrongTopic = "zcash-blocks-v1"

  pure val ProposalKind = "proposal"
  pure val SignedProposalKind = "signed-proposal"
  pure val StreamedProposalKind = "streamed-proposal"
  pure val PolkaKind = "liveness-polka"
  pure val RoundKind = "liveness-round"
  pure val SyncRequestKind = "sync-request"
  pure val SyncResponseKind = "sync-response"
  pure val WrongKind = "headers"

  pure val ProposalBytes = ProposalFormat::ProposalWithPolHex
  pure val SignedProposalBytes = ProposalFormat::SignedProposalHex
  pure val StreamedProposalBytes = ProposalFormat::StreamedProposalHex
  pure val PolkaBytes = LivenessFormat::LivenessPolkaMessageHex
  pure val RoundBytes = LivenessFormat::LivenessRoundSkipMessageHex
  pure val SyncRequestBytes = SyncFormat::SyncRequestHex
  pure val SyncResponseBytes = SyncFormat::SyncResponseWithValueHex
  pure val WrongBytes = "wrong-malachite-router-bytes"

  def Routed(
    channel: RouterChannel_t,
    topic: RouterTopic_t,
    kind: RouterKind_t,
    bytes: RouterBytes_t,
  ): RoutedEnvelope_t = {
    channel: channel,
    topic: topic,
    kind: kind,
    bytes: bytes,
  }

  def ProposalRouteValid(env: RoutedEnvelope_t): bool =
    env.channel == ProposalChannel and
    env.topic == ProposalTopic and
    (
      (env.kind == ProposalKind and env.bytes == ProposalBytes) or
      (env.kind == SignedProposalKind and env.bytes == SignedProposalBytes) or
      (
        env.kind == StreamedProposalKind and
        env.bytes == StreamedProposalBytes
      )
    )

  def LivenessRouteValid(env: RoutedEnvelope_t): bool =
    env.channel == LivenessChannel and
    env.topic == LivenessTopic and
    (
      (env.kind == PolkaKind and env.bytes == PolkaBytes) or
      (env.kind == RoundKind and env.bytes == RoundBytes)
    )

  def SyncRouteValid(env: RoutedEnvelope_t): bool =
    env.channel == SyncChannel and
    env.topic == SyncTopic and
    (
      (env.kind == SyncRequestKind and env.bytes == SyncRequestBytes) or
      (env.kind == SyncResponseKind and env.bytes == SyncResponseBytes)
    )

  pure val ProposalEnvelope =
    Routed(ProposalChannel, ProposalTopic, ProposalKind, ProposalBytes)
  pure val SignedProposalEnvelope =
    Routed(ProposalChannel, ProposalTopic, SignedProposalKind, SignedProposalBytes)
  pure val StreamedProposalEnvelope =
    Routed(ProposalChannel, ProposalTopic, StreamedProposalKind, StreamedProposalBytes)
  pure val PolkaEnvelope =
    Routed(LivenessChannel, LivenessTopic, PolkaKind, PolkaBytes)
  pure val RoundEnvelope =
    Routed(LivenessChannel, LivenessTopic, RoundKind, RoundBytes)
  pure val SyncRequestEnvelope =
    Routed(SyncChannel, SyncTopic, SyncRequestKind, SyncRequestBytes)
  pure val SyncResponseEnvelope =
    Routed(SyncChannel, SyncTopic, SyncResponseKind, SyncResponseBytes)

  pure val ProposalTopicOnLivenessChannel =
    Routed(LivenessChannel, ProposalTopic, SignedProposalKind, SignedProposalBytes)
  pure val LivenessKindOnSyncChannel =
    Routed(SyncChannel, SyncTopic, RoundKind, RoundBytes)
  pure val SyncKindOnProposalChannel =
    Routed(ProposalChannel, ProposalTopic, SyncRequestKind, SyncRequestBytes)
  pure val WrongTopicProposalEnvelope =
    Routed(ProposalChannel, WrongTopic, ProposalKind, ProposalBytes)
  pure val WrongKindSyncEnvelope =
    Routed(SyncChannel, SyncTopic, WrongKind, SyncRequestBytes)
  pure val WrongBytesLivenessEnvelope =
    Routed(LivenessChannel, LivenessTopic, RoundKind, WrongBytes)
  pure val UnknownChannelEnvelope =
    Routed(UnknownChannel, ProposalTopic, SignedProposalKind, SignedProposalBytes)

  pure val ProposalFixtures =
    Set(ProposalEnvelope, SignedProposalEnvelope, StreamedProposalEnvelope)
  pure val LivenessFixtures = Set(PolkaEnvelope, RoundEnvelope)
  pure val SyncFixtures = Set(SyncRequestEnvelope, SyncResponseEnvelope)

  var routedProposalEnvelopes: Set[RoutedEnvelope_t]
  var routedLivenessEnvelopes: Set[RoutedEnvelope_t]
  var routedSyncEnvelopes: Set[RoutedEnvelope_t]
  var routerFiredAction: str

  pure def MalachiteTopicsDisjoint: bool =
    ProposalTopic != LivenessTopic and
    ProposalTopic != SyncTopic and
    LivenessTopic != SyncTopic

  pure def MalachiteChannelsDisjoint: bool =
    ProposalChannel != LivenessChannel and
    ProposalChannel != SyncChannel and
    LivenessChannel != SyncChannel

  val RoutedProposalEnvelopesValid =
    routedProposalEnvelopes.forall(ProposalRouteValid)

  val RoutedLivenessEnvelopesValid =
    routedLivenessEnvelopes.forall(LivenessRouteValid)

  val RoutedSyncEnvelopesValid =
    routedSyncEnvelopes.forall(SyncRouteValid)

  val RouterSafety =
    MalachiteTopicsDisjoint and
    MalachiteChannelsDisjoint and
    RoutedProposalEnvelopesValid and
    RoutedLivenessEnvelopesValid and
    RoutedSyncEnvelopesValid

  action RouterInit = all {
    routedProposalEnvelopes' = Set(),
    routedLivenessEnvelopes' = Set(),
    routedSyncEnvelopes' = Set(),
    routerFiredAction' = "RouterInit",
  }

  action RouteProposal(env: RoutedEnvelope_t): bool =
    all {
      ProposalRouteValid(env),
      routedProposalEnvelopes' =
        routedProposalEnvelopes.union(Set(env)),
      routedLivenessEnvelopes' = routedLivenessEnvelopes,
      routedSyncEnvelopes' = routedSyncEnvelopes,
      routerFiredAction' = "RouteProposal",
    }

  action RouteLiveness(env: RoutedEnvelope_t): bool =
    all {
      LivenessRouteValid(env),
      routedProposalEnvelopes' = routedProposalEnvelopes,
      routedLivenessEnvelopes' =
        routedLivenessEnvelopes.union(Set(env)),
      routedSyncEnvelopes' = routedSyncEnvelopes,
      routerFiredAction' = "RouteLiveness",
    }

  action RouteSync(env: RoutedEnvelope_t): bool =
    all {
      SyncRouteValid(env),
      routedProposalEnvelopes' = routedProposalEnvelopes,
      routedLivenessEnvelopes' = routedLivenessEnvelopes,
      routedSyncEnvelopes' =
        routedSyncEnvelopes.union(Set(env)),
      routerFiredAction' = "RouteSync",
    }

  action RawRouteProposal(env: RoutedEnvelope_t): bool =
    all {
      routedProposalEnvelopes' =
        routedProposalEnvelopes.union(Set(env)),
      routedLivenessEnvelopes' = routedLivenessEnvelopes,
      routedSyncEnvelopes' = routedSyncEnvelopes,
      routerFiredAction' = "RawRouteProposal",
    }

  action RawRouteLiveness(env: RoutedEnvelope_t): bool =
    all {
      routedProposalEnvelopes' = routedProposalEnvelopes,
      routedLivenessEnvelopes' =
        routedLivenessEnvelopes.union(Set(env)),
      routedSyncEnvelopes' = routedSyncEnvelopes,
      routerFiredAction' = "RawRouteLiveness",
    }

  action RawRouteSync(env: RoutedEnvelope_t): bool =
    all {
      routedProposalEnvelopes' = routedProposalEnvelopes,
      routedLivenessEnvelopes' = routedLivenessEnvelopes,
      routedSyncEnvelopes' =
        routedSyncEnvelopes.union(Set(env)),
      routerFiredAction' = "RawRouteSync",
    }

  action RouterStutter: bool =
    all {
      routedProposalEnvelopes' = routedProposalEnvelopes,
      routedLivenessEnvelopes' = routedLivenessEnvelopes,
      routedSyncEnvelopes' = routedSyncEnvelopes,
      routerFiredAction' = routerFiredAction,
    }
}

module CrosslinkMalachiteGossipRouterSafetyTest {
  import CrosslinkMalachiteGossipRouterSafety.* from
    "./CrosslinkMalachiteGossipRouterSafety"
  export CrosslinkMalachiteGossipRouterSafety.*
  import CrosslinkMalachiteProposalProtobufFormat as ProposalFormat from
    "./CrosslinkMalachiteProposalProtobufFormat"
  import CrosslinkMalachiteLivenessProtobufFormat as LivenessFormat from
    "./CrosslinkMalachiteLivenessProtobufFormat"
  import CrosslinkMalachiteSyncProtobufFormat as SyncFormat from
    "./CrosslinkMalachiteSyncProtobufFormat"

  action RouterNext: bool =
    any {
      nondet env = oneOf(ProposalFixtures)
      RouteProposal(env),
      nondet env = oneOf(LivenessFixtures)
      RouteLiveness(env),
      nondet env = oneOf(SyncFixtures)
      RouteSync(env),
      RouterStutter,
    }

  action routerUnchangedAll: bool =
    all {
      routedProposalEnvelopes' = routedProposalEnvelopes,
      routedLivenessEnvelopes' = routedLivenessEnvelopes,
      routedSyncEnvelopes' = routedSyncEnvelopes,
      routerFiredAction' = routerFiredAction,
    }

  run routedNamespacesRemainSeparatedTest = {
    RouterInit
      .then(RouteProposal(SignedProposalEnvelope))
      .then(RouteLiveness(RoundEnvelope))
      .then(RouteSync(SyncResponseEnvelope))
      .then(all {
        assert(RouterSafety),
        assert(routedProposalEnvelopes.contains(SignedProposalEnvelope)),
        assert(routedLivenessEnvelopes.contains(RoundEnvelope)),
        assert(routedSyncEnvelopes.contains(SyncResponseEnvelope)),
        routerUnchangedAll,
      })
  }

  run malachiteRouterBytesMatchProtobufVectorsTest = {
    RouterInit
      .then(RouteProposal(ProposalEnvelope))
      .then(RouteProposal(SignedProposalEnvelope))
      .then(RouteProposal(StreamedProposalEnvelope))
      .then(RouteLiveness(PolkaEnvelope))
      .then(RouteLiveness(RoundEnvelope))
      .then(RouteSync(SyncRequestEnvelope))
      .then(RouteSync(SyncResponseEnvelope))
      .then(all {
        assert(ProposalBytes == ProposalFormat::ProposalWithPolHex),
        assert(SignedProposalBytes == ProposalFormat::SignedProposalHex),
        assert(StreamedProposalBytes == ProposalFormat::StreamedProposalHex),
        assert(PolkaBytes == LivenessFormat::LivenessPolkaMessageHex),
        assert(RoundBytes == LivenessFormat::LivenessRoundSkipMessageHex),
        assert(SyncRequestBytes == SyncFormat::SyncRequestHex),
        assert(SyncResponseBytes == SyncFormat::SyncResponseWithValueHex),
        assert(RouterSafety),
        routerUnchangedAll,
      })
  }

  run wrongTopicOnProposalChannelRejectedTest = {
    RouterInit.then(RouteProposal(WrongTopicProposalEnvelope)).fail()
  }

  run wrongKindOnSyncChannelRejectedTest = {
    RouterInit.then(RouteSync(WrongKindSyncEnvelope)).fail()
  }

  run wrongBytesOnLivenessChannelRejectedTest = {
    RouterInit.then(RouteLiveness(WrongBytesLivenessEnvelope)).fail()
  }

  run rawProposalTopicOnLivenessChannelViolatesSafetyTest = {
    RouterInit
      .then(RawRouteLiveness(ProposalTopicOnLivenessChannel))
      .then(all {
        assert(not(RouterSafety)),
        routerUnchangedAll,
      })
  }

  run rawLivenessKindOnSyncChannelViolatesSafetyTest = {
    RouterInit
      .then(RawRouteSync(LivenessKindOnSyncChannel))
      .then(all {
        assert(not(RouterSafety)),
        routerUnchangedAll,
      })
  }

  run rawSyncKindOnProposalChannelViolatesSafetyTest = {
    RouterInit
      .then(RawRouteProposal(SyncKindOnProposalChannel))
      .then(all {
        assert(not(RouterSafety)),
        routerUnchangedAll,
      })
  }

  run rawUnknownChannelViolatesSafetyTest = {
    RouterInit
      .then(RawRouteProposal(UnknownChannelEnvelope))
      .then(all {
        assert(not(RouterSafety)),
        routerUnchangedAll,
      })
  }
}

module CrosslinkMalachiteGossipRouterSafetyModel {
  import CrosslinkMalachiteGossipRouterSafetyTest.* from
    "./CrosslinkMalachiteGossipRouterSafety"
  export CrosslinkMalachiteGossipRouterSafetyTest.*
}
