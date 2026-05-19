module CrosslinkTenderlinkGossipRouterSafety {
  /*
   Verifier-friendly Tenderlink gossip router safety slice.

   Tenderlink's current transport specs cover several adjacent wire domains:
   compact proposal/POL consensus packets, nil/value precommit packets,
   accountability-evidence gossip, known-peer nonce/ack packets, and status
   packets. This direct model records the shared namespace contract: every
   routed record must stay on the Crosslink consensus topic, keep its message
   kind on the expected router channel, and carry the canonical bytes for that
   lane.
   */

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

  pure val ConsensusChannel = "tenderlink-consensus-channel"
  pure val EvidenceChannel = "tenderlink-evidence-channel"
  pure val KnownPeerChannel = "tenderlink-known-peer-channel"
  pure val StatusChannel = "tenderlink-status-channel"
  pure val UnknownChannel = "tenderlink-unknown-channel"

  pure val CrosslinkConsensusTopic = "crosslink-consensus-v1"
  pure val WrongTopic = "zcash-blocks-v1"

  pure val ProposalChunkKind = "proposal-chunk"
  pure val PolPrevoteKind = "pol-prevote"
  pure val NilPrecommitKind = "nil-precommit"
  pure val ValuePrecommitKind = "value-precommit"
  pure val MixedPrecommitKind = "mixed-precommit"
  pure val NilPrecommitCertificateKind = "nil-precommit-certificate"
  pure val ValuePrecommitCertificateKind = "value-precommit-certificate"
  pure val AccountabilityEvidenceKind = "accountability-evidence"
  pure val KnownPeerPacketKind = "known-peer-consensus-packet"
  pure val StatusPacketKind = "status-packet"
  pure val WrongKind = "headers"

  pure val ProposalChunkBytes = "tenderlink-proposal-pol-packet-bytes"
  pure val PolPrevoteBytes = "tenderlink-pol-prevote-packet-bytes"
  pure val NilPrecommitBytes = "tenderlink-nil-precommit-packet-bytes"
  pure val ValuePrecommitBytes = "tenderlink-value-precommit-packet-bytes"
  pure val MixedPrecommitBytes = "tenderlink-mixed-precommit-packet-bytes"
  pure val NilPrecommitCertificateBytes =
    "tenderlink-nil-precommit-certificate-packet-bytes"
  pure val ValuePrecommitCertificateBytes =
    "tenderlink-value-precommit-certificate-packet-bytes"
  pure val AccountabilityEvidenceBytes =
    "tenderlink-accountability-evidence-bytes"
  pure val KnownPeerPacketBytes = "tenderlink-known-peer-packet-bytes"
  pure val StatusPacketBytes = "tenderlink-status-packet-bytes"
  pure val WrongBytes = "wrong-tenderlink-router-bytes"

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

  def ConsensusRouteValid(env: RoutedEnvelope_t): bool =
    env.channel == ConsensusChannel and
    env.topic == CrosslinkConsensusTopic and
    (
      (env.kind == ProposalChunkKind and env.bytes == ProposalChunkBytes) or
      (env.kind == PolPrevoteKind and env.bytes == PolPrevoteBytes) or
      (env.kind == NilPrecommitKind and env.bytes == NilPrecommitBytes) or
      (env.kind == ValuePrecommitKind and env.bytes == ValuePrecommitBytes) or
      (env.kind == MixedPrecommitKind and env.bytes == MixedPrecommitBytes) or
      (env.kind == NilPrecommitCertificateKind and
        env.bytes == NilPrecommitCertificateBytes) or
      (env.kind == ValuePrecommitCertificateKind and
        env.bytes == ValuePrecommitCertificateBytes)
    )

  def EvidenceRouteValid(env: RoutedEnvelope_t): bool =
    env.channel == EvidenceChannel and
    env.topic == CrosslinkConsensusTopic and
    env.kind == AccountabilityEvidenceKind and
    env.bytes == AccountabilityEvidenceBytes

  def KnownPeerRouteValid(env: RoutedEnvelope_t): bool =
    env.channel == KnownPeerChannel and
    env.topic == CrosslinkConsensusTopic and
    env.kind == KnownPeerPacketKind and
    env.bytes == KnownPeerPacketBytes

  def StatusRouteValid(env: RoutedEnvelope_t): bool =
    env.channel == StatusChannel and
    env.topic == CrosslinkConsensusTopic and
    env.kind == StatusPacketKind and
    env.bytes == StatusPacketBytes

  pure val ProposalChunkEnvelope =
    Routed(
      ConsensusChannel,
      CrosslinkConsensusTopic,
      ProposalChunkKind,
      ProposalChunkBytes,
    )
  pure val PolPrevoteEnvelope =
    Routed(ConsensusChannel, CrosslinkConsensusTopic, PolPrevoteKind, PolPrevoteBytes)
  pure val NilPrecommitEnvelope =
    Routed(ConsensusChannel, CrosslinkConsensusTopic, NilPrecommitKind, NilPrecommitBytes)
  pure val ValuePrecommitEnvelope =
    Routed(
      ConsensusChannel,
      CrosslinkConsensusTopic,
      ValuePrecommitKind,
      ValuePrecommitBytes,
    )
  pure val MixedPrecommitEnvelope =
    Routed(
      ConsensusChannel,
      CrosslinkConsensusTopic,
      MixedPrecommitKind,
      MixedPrecommitBytes,
    )
  pure val NilPrecommitCertificateEnvelope =
    Routed(
      ConsensusChannel,
      CrosslinkConsensusTopic,
      NilPrecommitCertificateKind,
      NilPrecommitCertificateBytes,
    )
  pure val ValuePrecommitCertificateEnvelope =
    Routed(
      ConsensusChannel,
      CrosslinkConsensusTopic,
      ValuePrecommitCertificateKind,
      ValuePrecommitCertificateBytes,
    )
  pure val AccountabilityEvidenceEnvelope =
    Routed(
      EvidenceChannel,
      CrosslinkConsensusTopic,
      AccountabilityEvidenceKind,
      AccountabilityEvidenceBytes,
    )
  pure val KnownPeerEnvelope =
    Routed(
      KnownPeerChannel,
      CrosslinkConsensusTopic,
      KnownPeerPacketKind,
      KnownPeerPacketBytes,
    )
  pure val StatusEnvelope =
    Routed(StatusChannel, CrosslinkConsensusTopic, StatusPacketKind, StatusPacketBytes)

  pure val ProposalKindOnEvidenceChannel =
    Routed(EvidenceChannel, CrosslinkConsensusTopic, ProposalChunkKind, ProposalChunkBytes)
  pure val EvidenceKindOnConsensusChannel =
    Routed(
      ConsensusChannel,
      CrosslinkConsensusTopic,
      AccountabilityEvidenceKind,
      AccountabilityEvidenceBytes,
    )
  pure val NilPrecommitKindOnEvidenceChannel =
    Routed(
      EvidenceChannel,
      CrosslinkConsensusTopic,
      NilPrecommitCertificateKind,
      NilPrecommitCertificateBytes,
    )
  pure val NilPrecommitKindWrongBytes =
    Routed(
      ConsensusChannel,
      CrosslinkConsensusTopic,
      NilPrecommitCertificateKind,
      ValuePrecommitCertificateBytes,
    )
  pure val KnownPeerKindOnStatusChannel =
    Routed(
      StatusChannel,
      CrosslinkConsensusTopic,
      KnownPeerPacketKind,
      KnownPeerPacketBytes,
    )
  pure val StatusKindOnKnownPeerChannel =
    Routed(KnownPeerChannel, CrosslinkConsensusTopic, StatusPacketKind, StatusPacketBytes)
  pure val WrongTopicConsensusEnvelope =
    Routed(ConsensusChannel, WrongTopic, ProposalChunkKind, ProposalChunkBytes)
  pure val WrongKindEvidenceEnvelope =
    Routed(EvidenceChannel, CrosslinkConsensusTopic, WrongKind, AccountabilityEvidenceBytes)
  pure val WrongBytesStatusEnvelope =
    Routed(StatusChannel, CrosslinkConsensusTopic, StatusPacketKind, WrongBytes)
  pure val UnknownChannelEnvelope =
    Routed(
      UnknownChannel,
      CrosslinkConsensusTopic,
      ProposalChunkKind,
      ProposalChunkBytes,
    )

  pure val ConsensusFixtures = Set(
    ProposalChunkEnvelope,
    PolPrevoteEnvelope,
    NilPrecommitEnvelope,
    ValuePrecommitEnvelope,
    MixedPrecommitEnvelope,
    NilPrecommitCertificateEnvelope,
    ValuePrecommitCertificateEnvelope,
  )
  pure val EvidenceFixtures = Set(AccountabilityEvidenceEnvelope)
  pure val KnownPeerFixtures = Set(KnownPeerEnvelope)
  pure val StatusFixtures = Set(StatusEnvelope)

  var routedConsensusEnvelopes: Set[RoutedEnvelope_t]
  var routedEvidenceEnvelopes: Set[RoutedEnvelope_t]
  var routedKnownPeerEnvelopes: Set[RoutedEnvelope_t]
  var routedStatusEnvelopes: Set[RoutedEnvelope_t]
  var routerFiredAction: str

  pure def TenderlinkChannelsDisjoint: bool =
    ConsensusChannel != EvidenceChannel and
    ConsensusChannel != KnownPeerChannel and
    ConsensusChannel != StatusChannel and
    EvidenceChannel != KnownPeerChannel and
    EvidenceChannel != StatusChannel and
    KnownPeerChannel != StatusChannel

  val RoutedConsensusEnvelopesValid =
    routedConsensusEnvelopes.forall(ConsensusRouteValid)

  val RoutedEvidenceEnvelopesValid =
    routedEvidenceEnvelopes.forall(EvidenceRouteValid)

  val RoutedKnownPeerEnvelopesValid =
    routedKnownPeerEnvelopes.forall(KnownPeerRouteValid)

  val RoutedStatusEnvelopesValid =
    routedStatusEnvelopes.forall(StatusRouteValid)

  val RouterSafety =
    TenderlinkChannelsDisjoint and
    RoutedConsensusEnvelopesValid and
    RoutedEvidenceEnvelopesValid and
    RoutedKnownPeerEnvelopesValid and
    RoutedStatusEnvelopesValid

  action RouterInit = all {
    routedConsensusEnvelopes' = Set(),
    routedEvidenceEnvelopes' = Set(),
    routedKnownPeerEnvelopes' = Set(),
    routedStatusEnvelopes' = Set(),
    routerFiredAction' = "RouterInit",
  }

  action RouteConsensus(env: RoutedEnvelope_t): bool =
    all {
      ConsensusRouteValid(env),
      routedConsensusEnvelopes' = routedConsensusEnvelopes.union(Set(env)),
      routedEvidenceEnvelopes' = routedEvidenceEnvelopes,
      routedKnownPeerEnvelopes' = routedKnownPeerEnvelopes,
      routedStatusEnvelopes' = routedStatusEnvelopes,
      routerFiredAction' = "RouteConsensus",
    }

  action RouteEvidence(env: RoutedEnvelope_t): bool =
    all {
      EvidenceRouteValid(env),
      routedConsensusEnvelopes' = routedConsensusEnvelopes,
      routedEvidenceEnvelopes' = routedEvidenceEnvelopes.union(Set(env)),
      routedKnownPeerEnvelopes' = routedKnownPeerEnvelopes,
      routedStatusEnvelopes' = routedStatusEnvelopes,
      routerFiredAction' = "RouteEvidence",
    }

  action RouteKnownPeer(env: RoutedEnvelope_t): bool =
    all {
      KnownPeerRouteValid(env),
      routedConsensusEnvelopes' = routedConsensusEnvelopes,
      routedEvidenceEnvelopes' = routedEvidenceEnvelopes,
      routedKnownPeerEnvelopes' = routedKnownPeerEnvelopes.union(Set(env)),
      routedStatusEnvelopes' = routedStatusEnvelopes,
      routerFiredAction' = "RouteKnownPeer",
    }

  action RouteStatus(env: RoutedEnvelope_t): bool =
    all {
      StatusRouteValid(env),
      routedConsensusEnvelopes' = routedConsensusEnvelopes,
      routedEvidenceEnvelopes' = routedEvidenceEnvelopes,
      routedKnownPeerEnvelopes' = routedKnownPeerEnvelopes,
      routedStatusEnvelopes' = routedStatusEnvelopes.union(Set(env)),
      routerFiredAction' = "RouteStatus",
    }

  action RawRouteConsensus(env: RoutedEnvelope_t): bool =
    all {
      routedConsensusEnvelopes' = routedConsensusEnvelopes.union(Set(env)),
      routedEvidenceEnvelopes' = routedEvidenceEnvelopes,
      routedKnownPeerEnvelopes' = routedKnownPeerEnvelopes,
      routedStatusEnvelopes' = routedStatusEnvelopes,
      routerFiredAction' = "RawRouteConsensus",
    }

  action RawRouteEvidence(env: RoutedEnvelope_t): bool =
    all {
      routedConsensusEnvelopes' = routedConsensusEnvelopes,
      routedEvidenceEnvelopes' = routedEvidenceEnvelopes.union(Set(env)),
      routedKnownPeerEnvelopes' = routedKnownPeerEnvelopes,
      routedStatusEnvelopes' = routedStatusEnvelopes,
      routerFiredAction' = "RawRouteEvidence",
    }

  action RawRouteKnownPeer(env: RoutedEnvelope_t): bool =
    all {
      routedConsensusEnvelopes' = routedConsensusEnvelopes,
      routedEvidenceEnvelopes' = routedEvidenceEnvelopes,
      routedKnownPeerEnvelopes' = routedKnownPeerEnvelopes.union(Set(env)),
      routedStatusEnvelopes' = routedStatusEnvelopes,
      routerFiredAction' = "RawRouteKnownPeer",
    }

  action RawRouteStatus(env: RoutedEnvelope_t): bool =
    all {
      routedConsensusEnvelopes' = routedConsensusEnvelopes,
      routedEvidenceEnvelopes' = routedEvidenceEnvelopes,
      routedKnownPeerEnvelopes' = routedKnownPeerEnvelopes,
      routedStatusEnvelopes' = routedStatusEnvelopes.union(Set(env)),
      routerFiredAction' = "RawRouteStatus",
    }

  action RouterStutter: bool =
    all {
      routedConsensusEnvelopes' = routedConsensusEnvelopes,
      routedEvidenceEnvelopes' = routedEvidenceEnvelopes,
      routedKnownPeerEnvelopes' = routedKnownPeerEnvelopes,
      routedStatusEnvelopes' = routedStatusEnvelopes,
      routerFiredAction' = routerFiredAction,
    }
}

module CrosslinkTenderlinkGossipRouterSafetyTest {
  import CrosslinkTenderlinkGossipRouterSafety.* from
    "./CrosslinkTenderlinkGossipRouterSafety"
  export CrosslinkTenderlinkGossipRouterSafety.*

  action RouterNext: bool =
    any {
      nondet env = oneOf(ConsensusFixtures)
      RouteConsensus(env),
      nondet env = oneOf(EvidenceFixtures)
      RouteEvidence(env),
      nondet env = oneOf(KnownPeerFixtures)
      RouteKnownPeer(env),
      nondet env = oneOf(StatusFixtures)
      RouteStatus(env),
      RouterStutter,
    }

  action routerUnchangedAll: bool =
    all {
      routedConsensusEnvelopes' = routedConsensusEnvelopes,
      routedEvidenceEnvelopes' = routedEvidenceEnvelopes,
      routedKnownPeerEnvelopes' = routedKnownPeerEnvelopes,
      routedStatusEnvelopes' = routedStatusEnvelopes,
      routerFiredAction' = routerFiredAction,
    }

  run routedNamespacesRemainSeparatedTest = {
    RouterInit
      .then(RouteConsensus(ProposalChunkEnvelope))
      .then(RouteConsensus(PolPrevoteEnvelope))
      .then(RouteConsensus(MixedPrecommitEnvelope))
      .then(RouteConsensus(NilPrecommitCertificateEnvelope))
      .then(RouteConsensus(ValuePrecommitCertificateEnvelope))
      .then(RouteEvidence(AccountabilityEvidenceEnvelope))
      .then(RouteKnownPeer(KnownPeerEnvelope))
      .then(RouteStatus(StatusEnvelope))
      .then(all {
        assert(RouterSafety),
        assert(routedConsensusEnvelopes.contains(ProposalChunkEnvelope)),
        assert(routedConsensusEnvelopes.contains(PolPrevoteEnvelope)),
        assert(routedConsensusEnvelopes.contains(MixedPrecommitEnvelope)),
        assert(routedConsensusEnvelopes.contains(NilPrecommitCertificateEnvelope)),
        assert(routedConsensusEnvelopes.contains(ValuePrecommitCertificateEnvelope)),
        assert(routedEvidenceEnvelopes.contains(AccountabilityEvidenceEnvelope)),
        assert(routedKnownPeerEnvelopes.contains(KnownPeerEnvelope)),
        assert(routedStatusEnvelopes.contains(StatusEnvelope)),
        routerUnchangedAll,
      })
  }

  run wrongTopicOnConsensusChannelRejectedTest = {
    RouterInit.then(RouteConsensus(WrongTopicConsensusEnvelope)).fail()
  }

  run wrongKindOnEvidenceChannelRejectedTest = {
    RouterInit.then(RouteEvidence(WrongKindEvidenceEnvelope)).fail()
  }

  run wrongBytesOnStatusChannelRejectedTest = {
    RouterInit.then(RouteStatus(WrongBytesStatusEnvelope)).fail()
  }

  run wrongPrecommitCertificateBytesRejectedTest = {
    RouterInit.then(RouteConsensus(NilPrecommitKindWrongBytes)).fail()
  }

  run rawProposalKindOnEvidenceChannelViolatesSafetyTest = {
    RouterInit
      .then(RawRouteEvidence(ProposalKindOnEvidenceChannel))
      .then(all {
        assert(not(RouterSafety)),
        routerUnchangedAll,
      })
  }

  run rawEvidenceKindOnConsensusChannelViolatesSafetyTest = {
    RouterInit
      .then(RawRouteConsensus(EvidenceKindOnConsensusChannel))
      .then(all {
        assert(not(RouterSafety)),
        routerUnchangedAll,
      })
  }

  run rawNilPrecommitKindOnEvidenceChannelViolatesSafetyTest = {
    RouterInit
      .then(RawRouteEvidence(NilPrecommitKindOnEvidenceChannel))
      .then(all {
        assert(not(RouterSafety)),
        routerUnchangedAll,
      })
  }

  run rawKnownPeerKindOnStatusChannelViolatesSafetyTest = {
    RouterInit
      .then(RawRouteStatus(KnownPeerKindOnStatusChannel))
      .then(all {
        assert(not(RouterSafety)),
        routerUnchangedAll,
      })
  }

  run rawStatusKindOnKnownPeerChannelViolatesSafetyTest = {
    RouterInit
      .then(RawRouteKnownPeer(StatusKindOnKnownPeerChannel))
      .then(all {
        assert(not(RouterSafety)),
        routerUnchangedAll,
      })
  }

  run rawUnknownChannelViolatesSafetyTest = {
    RouterInit
      .then(RawRouteConsensus(UnknownChannelEnvelope))
      .then(all {
        assert(not(RouterSafety)),
        routerUnchangedAll,
      })
  }
}

module CrosslinkTenderlinkGossipRouterSafetyModel {
  import CrosslinkTenderlinkGossipRouterSafetyTest.* from
    "./CrosslinkTenderlinkGossipRouterSafety"
  export CrosslinkTenderlinkGossipRouterSafetyTest.*
}
