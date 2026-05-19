module CrosslinkMalachiteGossipRouter {
  /*
   Malachite gossip router composition.

   The proposal, liveness, and sync transport slices each prove a local
   topic/kind/canonical-bytes envelope boundary. This module composes those
   three transport machines behind one Malachite gossip router contract:
   messages accepted by a channel-specific decoder must be recorded on that
   channel's namespace, and records injected on the wrong channel violate the
   shared router safety invariant.
   */

  import CrosslinkMalachiteProposalGossipTransport as ProposalTransport from
    "./CrosslinkMalachiteProposalGossipTransport"
  import CrosslinkMalachiteLivenessGossipTransport as LivenessTransport from
    "./CrosslinkMalachiteLivenessGossipTransport"
  import CrosslinkMalachiteSyncGossipTransport as SyncTransport from
    "./CrosslinkMalachiteSyncGossipTransport"

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

  def ProposalRoute(
    env: ProposalTransport::ProposalTransportEnvelope_t,
  ): RoutedEnvelope_t =
    Routed(ProposalChannel, env.topic, env.kind, env.bytes)

  def LivenessRoute(
    env: LivenessTransport::LivenessTransportEnvelope_t,
  ): RoutedEnvelope_t =
    Routed(LivenessChannel, env.topic, env.kind, env.bytes)

  def SyncRoute(
    env: SyncTransport::SyncTransportEnvelope_t,
  ): RoutedEnvelope_t =
    Routed(SyncChannel, env.topic, env.kind, env.bytes)

  def ProposalRouteValid(env: RoutedEnvelope_t): bool =
    env.channel == ProposalChannel and
    env.topic == ProposalTransport::CrosslinkProposalTopic and
    (
      env.kind == ProposalTransport::ProposalEnvelopeKind or
      env.kind == ProposalTransport::SignedProposalEnvelopeKind or
      env.kind == ProposalTransport::StreamedProposalEnvelopeKind
    )

  def LivenessRouteValid(env: RoutedEnvelope_t): bool =
    env.channel == LivenessChannel and
    env.topic == LivenessTransport::CrosslinkLivenessTopic and
    (
      env.kind == LivenessTransport::LivenessPolkaEnvelopeKind or
      env.kind == LivenessTransport::LivenessRoundEnvelopeKind
    )

  def SyncRouteValid(env: RoutedEnvelope_t): bool =
    env.channel == SyncChannel and
    env.topic == SyncTransport::CrosslinkSyncTopic and
    (
      env.kind == SyncTransport::SyncRequestEnvelopeKind or
      env.kind == SyncTransport::SyncResponseEnvelopeKind
    )

  pure val ProposalEnvelope =
    ProposalTransport::Env(
      ProposalTransport::CrosslinkProposalTopic,
      ProposalTransport::ProposalEnvelopeKind,
      ProposalTransport::ProposalWithPol,
      ProposalTransport::SignedProposal,
      ProposalTransport::StreamedProposal,
      ProposalTransport::ProposalWithPol.hex,
    )

  pure val SignedProposalEnvelope =
    ProposalTransport::Env(
      ProposalTransport::CrosslinkProposalTopic,
      ProposalTransport::SignedProposalEnvelopeKind,
      ProposalTransport::ProposalWithPol,
      ProposalTransport::SignedProposal,
      ProposalTransport::StreamedProposal,
      ProposalTransport::SignedProposal.hex,
    )

  pure val StreamedProposalEnvelope =
    ProposalTransport::Env(
      ProposalTransport::CrosslinkProposalTopic,
      ProposalTransport::StreamedProposalEnvelopeKind,
      ProposalTransport::ProposalWithPol,
      ProposalTransport::SignedProposal,
      ProposalTransport::StreamedProposal,
      ProposalTransport::StreamedProposal.hex,
    )

  pure val WrongTopicSignedProposalEnvelope =
    ProposalTransport::Env(
      ProposalTransport::WrongProposalTopic,
      ProposalTransport::SignedProposalEnvelopeKind,
      ProposalTransport::ProposalWithPol,
      ProposalTransport::SignedProposal,
      ProposalTransport::StreamedProposal,
      ProposalTransport::SignedProposal.hex,
    )

  pure val WrongBytesSignedProposalEnvelope =
    ProposalTransport::Env(
      ProposalTransport::CrosslinkProposalTopic,
      ProposalTransport::SignedProposalEnvelopeKind,
      ProposalTransport::ProposalWithPol,
      ProposalTransport::SignedProposal,
      ProposalTransport::StreamedProposal,
      "wrong-signed-proposal-bytes",
    )

  pure val PolkaEnvelope =
    LivenessTransport::Env(
      LivenessTransport::CrosslinkLivenessTopic,
      LivenessTransport::LivenessPolkaEnvelopeKind,
      LivenessTransport::LivenessPolkaMessage,
      LivenessTransport::LivenessRoundSkipMessage,
      LivenessTransport::LivenessPolkaMessage.hex,
    )

  pure val RoundSkipEnvelope =
    LivenessTransport::Env(
      LivenessTransport::CrosslinkLivenessTopic,
      LivenessTransport::LivenessRoundEnvelopeKind,
      LivenessTransport::LivenessPolkaMessage,
      LivenessTransport::LivenessRoundSkipMessage,
      LivenessTransport::LivenessRoundSkipMessage.hex,
    )

  pure val RoundPrecommitEnvelope =
    LivenessTransport::Env(
      LivenessTransport::CrosslinkLivenessTopic,
      LivenessTransport::LivenessRoundEnvelopeKind,
      LivenessTransport::LivenessPolkaMessage,
      LivenessTransport::LivenessRoundPrecommitMessage,
      LivenessTransport::LivenessRoundPrecommitMessage.hex,
    )

  pure val WrongTopicRoundEnvelope =
    LivenessTransport::Env(
      LivenessTransport::WrongLivenessTopic,
      LivenessTransport::LivenessRoundEnvelopeKind,
      LivenessTransport::LivenessPolkaMessage,
      LivenessTransport::LivenessRoundSkipMessage,
      LivenessTransport::LivenessRoundSkipMessage.hex,
    )

  pure val SyncRequestEnvelope =
    SyncTransport::Env(
      SyncTransport::CrosslinkSyncTopic,
      SyncTransport::SyncRequestEnvelopeKind,
      SyncTransport::SyncRequest,
      SyncTransport::SyncResponseNoValue,
      SyncTransport::SyncRequest.hex,
    )

  pure val SyncResponseWithValueEnvelope =
    SyncTransport::Env(
      SyncTransport::CrosslinkSyncTopic,
      SyncTransport::SyncResponseEnvelopeKind,
      SyncTransport::SyncRequest,
      SyncTransport::SyncResponseWithValue,
      SyncTransport::SyncResponseWithValue.hex,
    )

  pure val SyncResponseNoValueEnvelope =
    SyncTransport::Env(
      SyncTransport::CrosslinkSyncTopic,
      SyncTransport::SyncResponseEnvelopeKind,
      SyncTransport::SyncRequest,
      SyncTransport::SyncResponseNoValue,
      SyncTransport::SyncResponseNoValue.hex,
    )

  pure val WrongKindSyncRequestEnvelope =
    SyncTransport::Env(
      SyncTransport::CrosslinkSyncTopic,
      SyncTransport::WrongEnvelopeKind,
      SyncTransport::SyncRequest,
      SyncTransport::SyncResponseNoValue,
      SyncTransport::SyncRequest.hex,
    )

  pure val ProposalTransportFixtures =
    Set(
      ProposalEnvelope,
      SignedProposalEnvelope,
      StreamedProposalEnvelope,
      WrongTopicSignedProposalEnvelope,
      WrongBytesSignedProposalEnvelope,
    )

  pure val LivenessTransportFixtures =
    Set(PolkaEnvelope, RoundSkipEnvelope, RoundPrecommitEnvelope, WrongTopicRoundEnvelope)

  pure val SyncTransportFixtures =
    Set(
      SyncRequestEnvelope,
      SyncResponseWithValueEnvelope,
      SyncResponseNoValueEnvelope,
      WrongKindSyncRequestEnvelope,
    )

  var routedProposalEnvelopes: Set[RoutedEnvelope_t]
  var routedLivenessEnvelopes: Set[RoutedEnvelope_t]
  var routedSyncEnvelopes: Set[RoutedEnvelope_t]
  var routerFiredAction: str

  pure def MalachiteTopicsDisjoint: bool =
    ProposalTransport::CrosslinkProposalTopic !=
      LivenessTransport::CrosslinkLivenessTopic and
    ProposalTransport::CrosslinkProposalTopic !=
      SyncTransport::CrosslinkSyncTopic and
    LivenessTransport::CrosslinkLivenessTopic !=
      SyncTransport::CrosslinkSyncTopic

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
    ProposalTransport::TransportSafety and
    LivenessTransport::TransportSafety and
    SyncTransport::TransportSafety and
    MalachiteTopicsDisjoint and
    MalachiteChannelsDisjoint and
    RoutedProposalEnvelopesValid and
    RoutedLivenessEnvelopesValid and
    RoutedSyncEnvelopesValid

  val ProposalAccepted =
    ProposalTransport::acceptedProposals.contains(
      ProposalTransport::ProposalWithPol
    )

  val SignedProposalAccepted =
    ProposalTransport::acceptedSignedProposals.contains(
      ProposalTransport::SignedProposal
    )

  val StreamedProposalAccepted =
    ProposalTransport::acceptedStreamedProposals.contains(
      ProposalTransport::StreamedProposal
    )

  val PolkaAccepted =
    LivenessTransport::acceptedPolkaMessages.contains(
      LivenessTransport::LivenessPolkaMessage
    )

  val RoundSkipAccepted =
    LivenessTransport::acceptedRoundMessages.contains(
      LivenessTransport::LivenessRoundSkipMessage
    )

  val RoundPrecommitAccepted =
    LivenessTransport::acceptedRoundMessages.contains(
      LivenessTransport::LivenessRoundPrecommitMessage
    )

  val SyncRequestAccepted =
    SyncTransport::acceptedSyncRequests.contains(SyncTransport::SyncRequest)

  val SyncResponseWithValueAccepted =
    SyncTransport::acceptedSyncResponses.contains(
      SyncTransport::SyncResponseWithValue
    )

  val SyncResponseNoValueAccepted =
    SyncTransport::acceptedSyncResponses.contains(
      SyncTransport::SyncResponseNoValue
    )

  action RouterInit = all {
    ProposalTransport::TransportInit,
    LivenessTransport::TransportInit,
    SyncTransport::TransportInit,
    routedProposalEnvelopes' = Set(),
    routedLivenessEnvelopes' = Set(),
    routedSyncEnvelopes' = Set(),
    routerFiredAction' = "RouterInit",
  }

  action KeepRouterState = all {
    routedProposalEnvelopes' = routedProposalEnvelopes,
    routedLivenessEnvelopes' = routedLivenessEnvelopes,
    routedSyncEnvelopes' = routedSyncEnvelopes,
  }

  action RouteProposal(
    env: ProposalTransport::ProposalTransportEnvelope_t,
  ): bool =
    all {
      ProposalTransport::AcceptProposalTransport(env),
      LivenessTransport::TransportStutter,
      SyncTransport::TransportStutter,
      routedProposalEnvelopes' =
        routedProposalEnvelopes.union(Set(ProposalRoute(env))),
      routedLivenessEnvelopes' = routedLivenessEnvelopes,
      routedSyncEnvelopes' = routedSyncEnvelopes,
      routerFiredAction' = "RouteProposal",
    }

  action RouteSignedProposal(
    env: ProposalTransport::ProposalTransportEnvelope_t,
  ): bool =
    all {
      ProposalTransport::AcceptSignedProposalTransport(env),
      LivenessTransport::TransportStutter,
      SyncTransport::TransportStutter,
      routedProposalEnvelopes' =
        routedProposalEnvelopes.union(Set(ProposalRoute(env))),
      routedLivenessEnvelopes' = routedLivenessEnvelopes,
      routedSyncEnvelopes' = routedSyncEnvelopes,
      routerFiredAction' = "RouteSignedProposal",
    }

  action RouteStreamedProposal(
    env: ProposalTransport::ProposalTransportEnvelope_t,
  ): bool =
    all {
      ProposalTransport::AcceptStreamedProposalTransport(env),
      LivenessTransport::TransportStutter,
      SyncTransport::TransportStutter,
      routedProposalEnvelopes' =
        routedProposalEnvelopes.union(Set(ProposalRoute(env))),
      routedLivenessEnvelopes' = routedLivenessEnvelopes,
      routedSyncEnvelopes' = routedSyncEnvelopes,
      routerFiredAction' = "RouteStreamedProposal",
    }

  action RoutePolka(
    env: LivenessTransport::LivenessTransportEnvelope_t,
  ): bool =
    all {
      ProposalTransport::TransportStutter,
      LivenessTransport::AcceptPolkaTransport(env),
      SyncTransport::TransportStutter,
      routedProposalEnvelopes' = routedProposalEnvelopes,
      routedLivenessEnvelopes' =
        routedLivenessEnvelopes.union(Set(LivenessRoute(env))),
      routedSyncEnvelopes' = routedSyncEnvelopes,
      routerFiredAction' = "RoutePolka",
    }

  action RouteRound(
    env: LivenessTransport::LivenessTransportEnvelope_t,
  ): bool =
    all {
      ProposalTransport::TransportStutter,
      LivenessTransport::AcceptRoundTransport(env),
      SyncTransport::TransportStutter,
      routedProposalEnvelopes' = routedProposalEnvelopes,
      routedLivenessEnvelopes' =
        routedLivenessEnvelopes.union(Set(LivenessRoute(env))),
      routedSyncEnvelopes' = routedSyncEnvelopes,
      routerFiredAction' = "RouteRound",
    }

  action RouteSyncRequest(env: SyncTransport::SyncTransportEnvelope_t): bool =
    all {
      ProposalTransport::TransportStutter,
      LivenessTransport::TransportStutter,
      SyncTransport::AcceptSyncRequestTransport(env),
      routedProposalEnvelopes' = routedProposalEnvelopes,
      routedLivenessEnvelopes' = routedLivenessEnvelopes,
      routedSyncEnvelopes' =
        routedSyncEnvelopes.union(Set(SyncRoute(env))),
      routerFiredAction' = "RouteSyncRequest",
    }

  action RouteSyncResponse(env: SyncTransport::SyncTransportEnvelope_t): bool =
    all {
      ProposalTransport::TransportStutter,
      LivenessTransport::TransportStutter,
      SyncTransport::AcceptSyncResponseTransport(env),
      routedProposalEnvelopes' = routedProposalEnvelopes,
      routedLivenessEnvelopes' = routedLivenessEnvelopes,
      routedSyncEnvelopes' =
        routedSyncEnvelopes.union(Set(SyncRoute(env))),
      routerFiredAction' = "RouteSyncResponse",
    }

  action RawRouteProposal(record: RoutedEnvelope_t): bool =
    all {
      ProposalTransport::TransportStutter,
      LivenessTransport::TransportStutter,
      SyncTransport::TransportStutter,
      routedProposalEnvelopes' =
        routedProposalEnvelopes.union(Set(record)),
      routedLivenessEnvelopes' = routedLivenessEnvelopes,
      routedSyncEnvelopes' = routedSyncEnvelopes,
      routerFiredAction' = "RawRouteProposal",
    }

  action RawRouteLiveness(record: RoutedEnvelope_t): bool =
    all {
      ProposalTransport::TransportStutter,
      LivenessTransport::TransportStutter,
      SyncTransport::TransportStutter,
      routedProposalEnvelopes' = routedProposalEnvelopes,
      routedLivenessEnvelopes' =
        routedLivenessEnvelopes.union(Set(record)),
      routedSyncEnvelopes' = routedSyncEnvelopes,
      routerFiredAction' = "RawRouteLiveness",
    }

  action RawRouteSync(record: RoutedEnvelope_t): bool =
    all {
      ProposalTransport::TransportStutter,
      LivenessTransport::TransportStutter,
      SyncTransport::TransportStutter,
      routedProposalEnvelopes' = routedProposalEnvelopes,
      routedLivenessEnvelopes' = routedLivenessEnvelopes,
      routedSyncEnvelopes' =
        routedSyncEnvelopes.union(Set(record)),
      routerFiredAction' = "RawRouteSync",
    }

  action RouterStutter: bool =
    all {
      ProposalTransport::TransportStutter,
      LivenessTransport::TransportStutter,
      SyncTransport::TransportStutter,
      KeepRouterState,
      routerFiredAction' = routerFiredAction,
    }

  action RouterUnchangedAll: bool =
    all {
      ProposalTransport::TransportStutter,
      LivenessTransport::TransportStutter,
      SyncTransport::TransportStutter,
      KeepRouterState,
      routerFiredAction' = routerFiredAction,
    }
}

module CrosslinkMalachiteGossipRouterTest {
  import CrosslinkMalachiteGossipRouter.* from "./CrosslinkMalachiteGossipRouter"
  export CrosslinkMalachiteGossipRouter.*

  pure val ProposalRecord = ProposalRoute(ProposalEnvelope)
  pure val SignedProposalRecord = ProposalRoute(SignedProposalEnvelope)
  pure val StreamedProposalRecord = ProposalRoute(StreamedProposalEnvelope)
  pure val PolkaRecord = LivenessRoute(PolkaEnvelope)
  pure val RoundSkipRecord = LivenessRoute(RoundSkipEnvelope)
  pure val RoundPrecommitRecord = LivenessRoute(RoundPrecommitEnvelope)
  pure val SyncRequestRecord = SyncRoute(SyncRequestEnvelope)
  pure val SyncResponseWithValueRecord = SyncRoute(SyncResponseWithValueEnvelope)
  pure val SyncResponseNoValueRecord = SyncRoute(SyncResponseNoValueEnvelope)

  pure val ProposalTopicOnLivenessChannel =
    Routed(
      LivenessChannel,
      ProposalRecord.topic,
      SignedProposalRecord.kind,
      SignedProposalRecord.bytes,
    )

  pure val LivenessKindOnSyncChannel =
    Routed(
      SyncChannel,
      SyncRequestRecord.topic,
      RoundSkipRecord.kind,
      RoundSkipRecord.bytes,
    )

  pure val UnknownChannelRecord =
    Routed(
      UnknownChannel,
      ProposalRecord.topic,
      SignedProposalRecord.kind,
      SignedProposalRecord.bytes,
    )

  action RouterNext: bool =
    any {
      nondet env = oneOf(ProposalTransportFixtures)
      RouteProposal(env),
      nondet env = oneOf(ProposalTransportFixtures)
      RouteSignedProposal(env),
      nondet env = oneOf(ProposalTransportFixtures)
      RouteStreamedProposal(env),
      nondet env = oneOf(LivenessTransportFixtures)
      RoutePolka(env),
      nondet env = oneOf(LivenessTransportFixtures)
      RouteRound(env),
      nondet env = oneOf(SyncTransportFixtures)
      RouteSyncRequest(env),
      nondet env = oneOf(SyncTransportFixtures)
      RouteSyncResponse(env),
      RouterStutter,
    }

  action routerUnchangedAll = all {
    RouterUnchangedAll,
  }

  run topicsAndChannelsAreDisjointTest = {
    RouterInit.then(all {
      assert(MalachiteTopicsDisjoint),
      assert(MalachiteChannelsDisjoint),
      assert(RouterSafety),
      routerUnchangedAll,
    })
  }

  run routesProposalMessagesThroughProposalChannelTest = {
    RouterInit
      .then(RouteProposal(ProposalEnvelope))
      .then(RouteSignedProposal(SignedProposalEnvelope))
      .then(RouteStreamedProposal(StreamedProposalEnvelope))
      .then(all {
        assert(routedProposalEnvelopes.contains(ProposalRecord)),
        assert(routedProposalEnvelopes.contains(SignedProposalRecord)),
        assert(routedProposalEnvelopes.contains(StreamedProposalRecord)),
        assert(ProposalAccepted),
        assert(SignedProposalAccepted),
        assert(StreamedProposalAccepted),
        assert(RouterSafety),
        routerUnchangedAll,
      })
  }

  run routesLivenessMessagesThroughLivenessChannelTest = {
    RouterInit
      .then(RoutePolka(PolkaEnvelope))
      .then(RouteRound(RoundSkipEnvelope))
      .then(RouteRound(RoundPrecommitEnvelope))
      .then(all {
        assert(routedLivenessEnvelopes.contains(PolkaRecord)),
        assert(routedLivenessEnvelopes.contains(RoundSkipRecord)),
        assert(routedLivenessEnvelopes.contains(RoundPrecommitRecord)),
        assert(PolkaAccepted),
        assert(RoundSkipAccepted),
        assert(RoundPrecommitAccepted),
        assert(RouterSafety),
        routerUnchangedAll,
      })
  }

  run routesSyncMessagesThroughSyncChannelTest = {
    RouterInit
      .then(RouteSyncRequest(SyncRequestEnvelope))
      .then(RouteSyncResponse(SyncResponseWithValueEnvelope))
      .then(RouteSyncResponse(SyncResponseNoValueEnvelope))
      .then(all {
        assert(routedSyncEnvelopes.contains(SyncRequestRecord)),
        assert(routedSyncEnvelopes.contains(SyncResponseWithValueRecord)),
        assert(routedSyncEnvelopes.contains(SyncResponseNoValueRecord)),
        assert(SyncRequestAccepted),
        assert(SyncResponseWithValueAccepted),
        assert(SyncResponseNoValueAccepted),
        assert(RouterSafety),
        routerUnchangedAll,
      })
  }

  run wrongTopicOnLivenessChannelViolatesRouterSafetyTest = {
    RouterInit
      .then(RawRouteLiveness(ProposalTopicOnLivenessChannel))
      .then(all {
        assert(not(RouterSafety)),
        routerUnchangedAll,
      })
  }

  run livenessKindOnSyncChannelViolatesRouterSafetyTest = {
    RouterInit
      .then(RawRouteSync(LivenessKindOnSyncChannel))
      .then(all {
        assert(not(RouterSafety)),
        routerUnchangedAll,
      })
  }

  run unknownChannelViolatesRouterSafetyTest = {
    RouterInit
      .then(RawRouteProposal(UnknownChannelRecord))
      .then(all {
        assert(not(RouterSafety)),
        routerUnchangedAll,
      })
  }

  run invalidProposalTopicRejectedBeforeRouterRecordsItTest = {
    RouterInit
      .then(RouteSignedProposal(WrongTopicSignedProposalEnvelope))
      .fail()
  }

  run invalidProposalBytesRejectedBeforeRouterRecordsItTest = {
    RouterInit
      .then(RouteSignedProposal(WrongBytesSignedProposalEnvelope))
      .fail()
  }

  run invalidLivenessTopicRejectedBeforeRouterRecordsItTest = {
    RouterInit
      .then(RouteRound(WrongTopicRoundEnvelope))
      .fail()
  }

  run invalidSyncKindRejectedBeforeRouterRecordsItTest = {
    RouterInit
      .then(RouteSyncRequest(WrongKindSyncRequestEnvelope))
      .fail()
  }

  run malachiteRouterSafetyTest = {
    RouterInit.then(all {
      assert(RouterSafety),
      routerUnchangedAll,
    })
  }
}

module CrosslinkMalachiteGossipRouterModel {
  import CrosslinkMalachiteGossipRouterTest.* from "./CrosslinkMalachiteGossipRouter"
  export CrosslinkMalachiteGossipRouterTest.*
}
