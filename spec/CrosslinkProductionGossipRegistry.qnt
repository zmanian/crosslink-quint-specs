module CrosslinkProductionGossipRegistry {
  /*
   Direct production gossip registry safety slice.

   The Tenderlink and Malachite router models already keep their own channels
   separated. This model adds one production-level registry above both protocol
   families, checking that Tenderlink compact-consensus lanes cannot be routed
   through Malachite proposal/liveness/sync lanes, and that Malachite protobuf
   lanes cannot be routed through Tenderlink's consensus-topic registry.
   */

  type Protocol_t = str
  type Channel_t = str
  type Topic_t = str
  type Kind_t = str
  type Bytes_t = str
  type ProductionEnvelope_t = {
    protocol: Protocol_t,
    channel: Channel_t,
    topic: Topic_t,
    kind: Kind_t,
    bytes: Bytes_t,
  }

  pure val TenderlinkProtocol = "tenderlink"
  pure val MalachiteProtocol = "malachite"
  pure val UnknownProtocol = "unknown-protocol"

  pure val TenderlinkConsensusChannel = "tenderlink-consensus-channel"
  pure val TenderlinkEvidenceChannel = "tenderlink-evidence-channel"
  pure val TenderlinkKnownPeerChannel = "tenderlink-known-peer-channel"
  pure val TenderlinkStatusChannel = "tenderlink-status-channel"

  pure val MalachiteProposalChannel = "malachite-proposal-channel"
  pure val MalachiteLivenessChannel = "malachite-liveness-channel"
  pure val MalachiteSyncChannel = "malachite-sync-channel"

  pure val CrosslinkConsensusTopic = "crosslink-consensus-v1"
  pure val MalachiteProposalTopic = "crosslink-proposal-v1"
  pure val MalachiteLivenessTopic = "crosslink-liveness-v1"
  pure val MalachiteSyncTopic = "crosslink-sync-v1"
  pure val WrongTopic = "zcash-blocks-v1"

  pure val TenderlinkProposalChunkKind = "proposal-chunk"
  pure val TenderlinkPolPrevoteKind = "pol-prevote"
  pure val TenderlinkNilPrecommitKind = "nil-precommit"
  pure val TenderlinkValuePrecommitKind = "value-precommit"
  pure val TenderlinkMixedPrecommitKind = "mixed-precommit"
  pure val TenderlinkNilPrecommitCertificateKind =
    "nil-precommit-certificate"
  pure val TenderlinkValuePrecommitCertificateKind =
    "value-precommit-certificate"
  pure val TenderlinkAccountabilityEvidenceKind = "accountability-evidence"
  pure val TenderlinkKnownPeerPacketKind = "known-peer-consensus-packet"
  pure val TenderlinkStatusPacketKind = "status-packet"

  pure val MalachiteProposalKind = "proposal"
  pure val MalachiteSignedProposalKind = "signed-proposal"
  pure val MalachiteStreamedProposalKind = "streamed-proposal"
  pure val MalachitePolkaKind = "liveness-polka"
  pure val MalachiteRoundKind = "liveness-round"
  pure val MalachiteSyncRequestKind = "sync-request"
  pure val MalachiteSyncResponseKind = "sync-response"

  pure val TenderlinkProposalChunkBytes =
    "tenderlink-proposal-pol-packet-bytes"
  pure val TenderlinkPolPrevoteBytes =
    "tenderlink-pol-prevote-packet-bytes"
  pure val TenderlinkNilPrecommitBytes =
    "tenderlink-nil-precommit-packet-bytes"
  pure val TenderlinkValuePrecommitBytes =
    "tenderlink-value-precommit-packet-bytes"
  pure val TenderlinkMixedPrecommitBytes =
    "tenderlink-mixed-precommit-packet-bytes"
  pure val TenderlinkNilPrecommitCertificateBytes =
    "tenderlink-nil-precommit-certificate-packet-bytes"
  pure val TenderlinkValuePrecommitCertificateBytes =
    "tenderlink-value-precommit-certificate-packet-bytes"
  pure val TenderlinkAccountabilityEvidenceBytes =
    "tenderlink-accountability-evidence-bytes"
  pure val TenderlinkKnownPeerPacketBytes =
    "tenderlink-known-peer-packet-bytes"
  pure val TenderlinkStatusPacketBytes = "tenderlink-status-packet-bytes"

  pure val MalachiteProposalBytes = "malachite-proposal-proto-bytes"
  pure val MalachiteSignedProposalBytes =
    "malachite-signed-proposal-proto-bytes"
  pure val MalachiteStreamedProposalBytes =
    "malachite-streamed-proposal-proto-bytes"
  pure val MalachitePolkaBytes = "malachite-polka-proto-bytes"
  pure val MalachiteRoundBytes = "malachite-round-proto-bytes"
  pure val MalachiteSyncRequestBytes =
    "malachite-sync-request-proto-bytes"
  pure val MalachiteSyncResponseBytes =
    "malachite-sync-response-proto-bytes"

  pure val WrongBytes = "wrong-production-gossip-bytes"

  def Envelope(
    protocol: Protocol_t,
    channel: Channel_t,
    topic: Topic_t,
    kind: Kind_t,
    bytes: Bytes_t,
  ): ProductionEnvelope_t = {
    protocol: protocol,
    channel: channel,
    topic: topic,
    kind: kind,
    bytes: bytes,
  }

  pure def ProductionTopicsDisjoint: bool =
    CrosslinkConsensusTopic != MalachiteProposalTopic and
    CrosslinkConsensusTopic != MalachiteLivenessTopic and
    CrosslinkConsensusTopic != MalachiteSyncTopic and
    MalachiteProposalTopic != MalachiteLivenessTopic and
    MalachiteProposalTopic != MalachiteSyncTopic and
    MalachiteLivenessTopic != MalachiteSyncTopic

  pure def ProductionChannelsDisjoint: bool =
    TenderlinkConsensusChannel != TenderlinkEvidenceChannel and
    TenderlinkConsensusChannel != TenderlinkKnownPeerChannel and
    TenderlinkConsensusChannel != TenderlinkStatusChannel and
    TenderlinkConsensusChannel != MalachiteProposalChannel and
    TenderlinkConsensusChannel != MalachiteLivenessChannel and
    TenderlinkConsensusChannel != MalachiteSyncChannel and
    TenderlinkEvidenceChannel != TenderlinkKnownPeerChannel and
    TenderlinkEvidenceChannel != TenderlinkStatusChannel and
    TenderlinkEvidenceChannel != MalachiteProposalChannel and
    TenderlinkEvidenceChannel != MalachiteLivenessChannel and
    TenderlinkEvidenceChannel != MalachiteSyncChannel and
    TenderlinkKnownPeerChannel != TenderlinkStatusChannel and
    TenderlinkKnownPeerChannel != MalachiteProposalChannel and
    TenderlinkKnownPeerChannel != MalachiteLivenessChannel and
    TenderlinkKnownPeerChannel != MalachiteSyncChannel and
    TenderlinkStatusChannel != MalachiteProposalChannel and
    TenderlinkStatusChannel != MalachiteLivenessChannel and
    TenderlinkStatusChannel != MalachiteSyncChannel and
    MalachiteProposalChannel != MalachiteLivenessChannel and
    MalachiteProposalChannel != MalachiteSyncChannel and
    MalachiteLivenessChannel != MalachiteSyncChannel

  def TenderlinkConsensusRouteValid(env: ProductionEnvelope_t): bool =
    env.protocol == TenderlinkProtocol and
    env.channel == TenderlinkConsensusChannel and
    env.topic == CrosslinkConsensusTopic and
    (
      (
        env.kind == TenderlinkProposalChunkKind and
        env.bytes == TenderlinkProposalChunkBytes
      ) or
      (
        env.kind == TenderlinkPolPrevoteKind and
        env.bytes == TenderlinkPolPrevoteBytes
      ) or
      (
        env.kind == TenderlinkNilPrecommitKind and
        env.bytes == TenderlinkNilPrecommitBytes
      ) or
      (
        env.kind == TenderlinkValuePrecommitKind and
        env.bytes == TenderlinkValuePrecommitBytes
      ) or
      (
        env.kind == TenderlinkMixedPrecommitKind and
        env.bytes == TenderlinkMixedPrecommitBytes
      ) or
      (
        env.kind == TenderlinkNilPrecommitCertificateKind and
        env.bytes == TenderlinkNilPrecommitCertificateBytes
      ) or
      (
        env.kind == TenderlinkValuePrecommitCertificateKind and
        env.bytes == TenderlinkValuePrecommitCertificateBytes
      )
    )

  def TenderlinkEvidenceRouteValid(env: ProductionEnvelope_t): bool =
    env.protocol == TenderlinkProtocol and
    env.channel == TenderlinkEvidenceChannel and
    env.topic == CrosslinkConsensusTopic and
    env.kind == TenderlinkAccountabilityEvidenceKind and
    env.bytes == TenderlinkAccountabilityEvidenceBytes

  def TenderlinkKnownPeerRouteValid(env: ProductionEnvelope_t): bool =
    env.protocol == TenderlinkProtocol and
    env.channel == TenderlinkKnownPeerChannel and
    env.topic == CrosslinkConsensusTopic and
    env.kind == TenderlinkKnownPeerPacketKind and
    env.bytes == TenderlinkKnownPeerPacketBytes

  def TenderlinkStatusRouteValid(env: ProductionEnvelope_t): bool =
    env.protocol == TenderlinkProtocol and
    env.channel == TenderlinkStatusChannel and
    env.topic == CrosslinkConsensusTopic and
    env.kind == TenderlinkStatusPacketKind and
    env.bytes == TenderlinkStatusPacketBytes

  def MalachiteProposalRouteValid(env: ProductionEnvelope_t): bool =
    env.protocol == MalachiteProtocol and
    env.channel == MalachiteProposalChannel and
    env.topic == MalachiteProposalTopic and
    (
      (
        env.kind == MalachiteProposalKind and
        env.bytes == MalachiteProposalBytes
      ) or
      (
        env.kind == MalachiteSignedProposalKind and
        env.bytes == MalachiteSignedProposalBytes
      ) or
      (
        env.kind == MalachiteStreamedProposalKind and
        env.bytes == MalachiteStreamedProposalBytes
      )
    )

  def MalachiteLivenessRouteValid(env: ProductionEnvelope_t): bool =
    env.protocol == MalachiteProtocol and
    env.channel == MalachiteLivenessChannel and
    env.topic == MalachiteLivenessTopic and
    (
      (
        env.kind == MalachitePolkaKind and
        env.bytes == MalachitePolkaBytes
      ) or
      (
        env.kind == MalachiteRoundKind and
        env.bytes == MalachiteRoundBytes
      )
    )

  def MalachiteSyncRouteValid(env: ProductionEnvelope_t): bool =
    env.protocol == MalachiteProtocol and
    env.channel == MalachiteSyncChannel and
    env.topic == MalachiteSyncTopic and
    (
      (
        env.kind == MalachiteSyncRequestKind and
        env.bytes == MalachiteSyncRequestBytes
      ) or
      (
        env.kind == MalachiteSyncResponseKind and
        env.bytes == MalachiteSyncResponseBytes
      )
    )

  def ProductionRouteValid(env: ProductionEnvelope_t): bool =
    TenderlinkConsensusRouteValid(env) or
    TenderlinkEvidenceRouteValid(env) or
    TenderlinkKnownPeerRouteValid(env) or
    TenderlinkStatusRouteValid(env) or
    MalachiteProposalRouteValid(env) or
    MalachiteLivenessRouteValid(env) or
    MalachiteSyncRouteValid(env)

  pure val TenderlinkMixedPrecommitEnvelope =
    Envelope(
      TenderlinkProtocol,
      TenderlinkConsensusChannel,
      CrosslinkConsensusTopic,
      TenderlinkMixedPrecommitKind,
      TenderlinkMixedPrecommitBytes,
    )
  pure val TenderlinkNilPrecommitCertificateEnvelope =
    Envelope(
      TenderlinkProtocol,
      TenderlinkConsensusChannel,
      CrosslinkConsensusTopic,
      TenderlinkNilPrecommitCertificateKind,
      TenderlinkNilPrecommitCertificateBytes,
    )
  pure val TenderlinkValuePrecommitCertificateEnvelope =
    Envelope(
      TenderlinkProtocol,
      TenderlinkConsensusChannel,
      CrosslinkConsensusTopic,
      TenderlinkValuePrecommitCertificateKind,
      TenderlinkValuePrecommitCertificateBytes,
    )
  pure val TenderlinkEvidenceEnvelope =
    Envelope(
      TenderlinkProtocol,
      TenderlinkEvidenceChannel,
      CrosslinkConsensusTopic,
      TenderlinkAccountabilityEvidenceKind,
      TenderlinkAccountabilityEvidenceBytes,
    )
  pure val TenderlinkKnownPeerEnvelope =
    Envelope(
      TenderlinkProtocol,
      TenderlinkKnownPeerChannel,
      CrosslinkConsensusTopic,
      TenderlinkKnownPeerPacketKind,
      TenderlinkKnownPeerPacketBytes,
    )
  pure val TenderlinkStatusEnvelope =
    Envelope(
      TenderlinkProtocol,
      TenderlinkStatusChannel,
      CrosslinkConsensusTopic,
      TenderlinkStatusPacketKind,
      TenderlinkStatusPacketBytes,
    )

  pure val MalachiteSignedProposalEnvelope =
    Envelope(
      MalachiteProtocol,
      MalachiteProposalChannel,
      MalachiteProposalTopic,
      MalachiteSignedProposalKind,
      MalachiteSignedProposalBytes,
    )
  pure val MalachiteRoundEnvelope =
    Envelope(
      MalachiteProtocol,
      MalachiteLivenessChannel,
      MalachiteLivenessTopic,
      MalachiteRoundKind,
      MalachiteRoundBytes,
    )
  pure val MalachiteSyncResponseEnvelope =
    Envelope(
      MalachiteProtocol,
      MalachiteSyncChannel,
      MalachiteSyncTopic,
      MalachiteSyncResponseKind,
      MalachiteSyncResponseBytes,
    )

  pure val MalachiteProposalOnTenderlinkConsensus =
    Envelope(
      MalachiteProtocol,
      TenderlinkConsensusChannel,
      CrosslinkConsensusTopic,
      MalachiteSignedProposalKind,
      MalachiteSignedProposalBytes,
    )
  pure val TenderlinkPrecommitOnMalachiteLiveness =
    Envelope(
      TenderlinkProtocol,
      MalachiteLivenessChannel,
      MalachiteLivenessTopic,
      TenderlinkMixedPrecommitKind,
      TenderlinkMixedPrecommitBytes,
    )
  pure val TenderlinkKindOnMalachiteProposal =
    Envelope(
      MalachiteProtocol,
      MalachiteProposalChannel,
      MalachiteProposalTopic,
      TenderlinkProposalChunkKind,
      TenderlinkProposalChunkBytes,
    )
  pure val MalachiteRoundOnTenderlinkConsensus =
    Envelope(
      TenderlinkProtocol,
      TenderlinkConsensusChannel,
      CrosslinkConsensusTopic,
      MalachiteRoundKind,
      MalachiteRoundBytes,
    )
  pure val WrongTopicTenderlinkEnvelope =
    Envelope(
      TenderlinkProtocol,
      TenderlinkConsensusChannel,
      WrongTopic,
      TenderlinkMixedPrecommitKind,
      TenderlinkMixedPrecommitBytes,
    )
  pure val WrongBytesMalachiteEnvelope =
    Envelope(
      MalachiteProtocol,
      MalachiteSyncChannel,
      MalachiteSyncTopic,
      MalachiteSyncResponseKind,
      WrongBytes,
    )
  pure val UnknownProtocolEnvelope =
    Envelope(
      UnknownProtocol,
      TenderlinkConsensusChannel,
      CrosslinkConsensusTopic,
      TenderlinkProposalChunkKind,
      TenderlinkProposalChunkBytes,
    )

  pure val ProductionFixtures =
    Set(
      TenderlinkMixedPrecommitEnvelope,
      TenderlinkNilPrecommitCertificateEnvelope,
      TenderlinkValuePrecommitCertificateEnvelope,
      TenderlinkEvidenceEnvelope,
      TenderlinkKnownPeerEnvelope,
      TenderlinkStatusEnvelope,
      MalachiteSignedProposalEnvelope,
      MalachiteRoundEnvelope,
      MalachiteSyncResponseEnvelope,
    )

  var routedProductionEnvelopes: Set[ProductionEnvelope_t]
  var registryFiredAction: str

  val RoutedProductionEnvelopesValid =
    routedProductionEnvelopes.forall(ProductionRouteValid)

  val RegistrySafety =
    ProductionTopicsDisjoint and
    ProductionChannelsDisjoint and
    RoutedProductionEnvelopesValid

  action RegistryInit = all {
    routedProductionEnvelopes' = Set(),
    registryFiredAction' = "RegistryInit",
  }

  action RouteProduction(env: ProductionEnvelope_t): bool =
    all {
      ProductionRouteValid(env),
      routedProductionEnvelopes' =
        routedProductionEnvelopes.union(Set(env)),
      registryFiredAction' = "RouteProduction",
    }

  action RawRouteProduction(env: ProductionEnvelope_t): bool =
    all {
      routedProductionEnvelopes' =
        routedProductionEnvelopes.union(Set(env)),
      registryFiredAction' = "RawRouteProduction",
    }

  action RegistryStutter: bool =
    all {
      routedProductionEnvelopes' = routedProductionEnvelopes,
      registryFiredAction' = registryFiredAction,
    }
}

module CrosslinkProductionGossipRegistryTest {
  import CrosslinkProductionGossipRegistry.* from
    "./CrosslinkProductionGossipRegistry"
  export CrosslinkProductionGossipRegistry.*

  action RegistryNext: bool =
    any {
      nondet env = oneOf(ProductionFixtures)
      RouteProduction(env),
      RegistryStutter,
    }

  action registryUnchangedAll: bool =
    all {
      routedProductionEnvelopes' = routedProductionEnvelopes,
      registryFiredAction' = registryFiredAction,
    }

  run routesTenderlinkAndMalachiteTogetherTest = {
    RegistryInit
      .then(RouteProduction(TenderlinkMixedPrecommitEnvelope))
      .then(RouteProduction(TenderlinkNilPrecommitCertificateEnvelope))
      .then(RouteProduction(TenderlinkEvidenceEnvelope))
      .then(RouteProduction(TenderlinkKnownPeerEnvelope))
      .then(RouteProduction(TenderlinkStatusEnvelope))
      .then(RouteProduction(MalachiteSignedProposalEnvelope))
      .then(RouteProduction(MalachiteRoundEnvelope))
      .then(RouteProduction(MalachiteSyncResponseEnvelope))
      .then(all {
        assert(RegistrySafety),
        assert(routedProductionEnvelopes.contains(TenderlinkMixedPrecommitEnvelope)),
        assert(
          routedProductionEnvelopes.contains(
            TenderlinkNilPrecommitCertificateEnvelope
          )
        ),
        assert(routedProductionEnvelopes.contains(TenderlinkEvidenceEnvelope)),
        assert(routedProductionEnvelopes.contains(TenderlinkKnownPeerEnvelope)),
        assert(routedProductionEnvelopes.contains(TenderlinkStatusEnvelope)),
        assert(routedProductionEnvelopes.contains(MalachiteSignedProposalEnvelope)),
        assert(routedProductionEnvelopes.contains(MalachiteRoundEnvelope)),
        assert(routedProductionEnvelopes.contains(MalachiteSyncResponseEnvelope)),
        registryUnchangedAll,
      })
  }

  run productionNamespacesDisjointTest = {
    RegistryInit.then(all {
      assert(ProductionTopicsDisjoint),
      assert(ProductionChannelsDisjoint),
      assert(RegistrySafety),
      registryUnchangedAll,
    })
  }

  run malachiteProposalOnTenderlinkConsensusRejectedTest = {
    RegistryInit.then(RouteProduction(MalachiteProposalOnTenderlinkConsensus)).fail()
  }

  run tenderlinkPrecommitOnMalachiteLivenessRejectedTest = {
    RegistryInit.then(RouteProduction(TenderlinkPrecommitOnMalachiteLiveness)).fail()
  }

  run wrongTopicTenderlinkRejectedTest = {
    RegistryInit.then(RouteProduction(WrongTopicTenderlinkEnvelope)).fail()
  }

  run wrongBytesMalachiteRejectedTest = {
    RegistryInit.then(RouteProduction(WrongBytesMalachiteEnvelope)).fail()
  }

  run unknownProtocolRejectedTest = {
    RegistryInit.then(RouteProduction(UnknownProtocolEnvelope)).fail()
  }

  run rawTenderlinkKindOnMalachiteProposalViolatesSafetyTest = {
    RegistryInit
      .then(RawRouteProduction(TenderlinkKindOnMalachiteProposal))
      .then(all {
        assert(not(RegistrySafety)),
        registryUnchangedAll,
      })
  }

  run rawMalachiteRoundOnTenderlinkConsensusViolatesSafetyTest = {
    RegistryInit
      .then(RawRouteProduction(MalachiteRoundOnTenderlinkConsensus))
      .then(all {
        assert(not(RegistrySafety)),
        registryUnchangedAll,
      })
  }

  run rawUnknownProtocolViolatesSafetyTest = {
    RegistryInit
      .then(RawRouteProduction(UnknownProtocolEnvelope))
      .then(all {
        assert(not(RegistrySafety)),
        registryUnchangedAll,
      })
  }
}

module CrosslinkProductionGossipRegistryModel {
  import CrosslinkProductionGossipRegistryTest.* from
    "./CrosslinkProductionGossipRegistry"
  export CrosslinkProductionGossipRegistryTest.*
}
