module CrosslinkTenderlinkGossipRouter {
  /*
   Tenderlink gossip router composition.

   The compact proposal/POL transport, precommit transport, accountability
   evidence transport, known-peer nonce/ack transport, and status packet slices
   each prove a local wire boundary. This module composes those accepted
   transport paths behind a shared Tenderlink router contract: every accepted
   message is recorded on the channel for its domain, on the Crosslink consensus
   topic, with the canonical bytes expected by that channel.
   */

  import CrosslinkTenderlinkProposalPolTransportTest as ProposalPolTransport from
    "./CrosslinkTenderlinkProposalPolTransport"
  import CrosslinkTenderlinkPrecommitTransportTest as PrecommitTransport from
    "./CrosslinkTenderlinkPrecommitTransport"
  import CrosslinkTenderlinkVotePacketFormatTest as VotePacketFormat from
    "./CrosslinkTenderlinkVotePacketFormat"
  import CrosslinkTenderlinkAccountabilityEvidenceTransportTest as EvidenceTransport from
    "./CrosslinkTenderlinkAccountabilityEvidenceTransport"
  import CrosslinkTenderlinkNonceAckTransportTest as NonceAckTransport from
    "./CrosslinkTenderlinkNonceAckTransport"
  import CrosslinkTenderlinkStatusPacketFormatTest as StatusFormat from
    "./CrosslinkTenderlinkStatusPacketFormat"

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

  pure val CrosslinkConsensusTopic = EvidenceTransport::CrosslinkGossipTopic

  pure val ProposalChunkKind = "proposal-chunk"
  pure val PolPrevoteKind = "pol-prevote"
  pure val NilPrecommitKind = "nil-precommit"
  pure val ValuePrecommitKind = "value-precommit"
  pure val MixedPrecommitKind = "mixed-precommit"
  pure val NilPrecommitCertificateKind = "nil-precommit-certificate"
  pure val ValuePrecommitCertificateKind = "value-precommit-certificate"
  pure val AccountabilityEvidenceKind =
    EvidenceTransport::AccountabilityEvidenceEnvelopeKind
  pure val KnownPeerPacketKind = "known-peer-consensus-packet"
  pure val StatusPacketKind = "status-packet"
  pure val UnknownKind = "unknown-tenderlink-router-kind"

  pure val PolPrevotePacketBytes = Set(
    ProposalPolTransport::ValuePrevotePolConsensusPacketHex,
    ProposalPolTransport::ValuePrevotePolWeightedConsensusPacketHex,
    ProposalPolTransport::ValuePrevotePolQuorumConsensusPacketHex,
    ProposalPolTransport::ValuePrevotePolLargeConsensusPacketHex,
  )

  pure val PrecommitPacketBytes = Set(
    PrecommitTransport::NilPrecommitConsensusPacketHex,
    PrecommitTransport::ValuePrecommitConsensusPacketHex,
    PrecommitTransport::NilPrecommitQuorumConsensusPacketHex,
    PrecommitTransport::MixedPrecommitQuorumConsensusPacketHex,
    PrecommitTransport::ValuePrecommitQuorumConsensusPacketHex,
  )

  pure val AccountabilityEvidenceBytes = Set(
    EvidenceTransport::NilValuePrecommitEvidenceHex,
    EvidenceTransport::ValueValuePrecommitEvidenceHex,
  )

  pure val KnownPeerPacketBytes = Set(NonceAckTransport::AckedPrevotePacket.hex)

  pure val StatusPacketBytes =
    Set(StatusFormat::ValidStatusPacket.hex, StatusFormat::AckedPrevoteStatusPacket.hex)

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

  def ProposalPolRouteKind(
    env: ProposalPolTransport::TransportEnvelope_t,
  ): RouterKind_t =
    if (env.packetHex == ProposalPolTransport::PolProposalConsensusPacketHex) {
      ProposalChunkKind
    } else if (PolPrevotePacketBytes.contains(env.packetHex)) {
      PolPrevoteKind
    } else {
      UnknownKind
    }

  def ProposalPolRoute(
    env: ProposalPolTransport::TransportEnvelope_t,
  ): RoutedEnvelope_t =
    Routed(
      ConsensusChannel,
      CrosslinkConsensusTopic,
      ProposalPolRouteKind(env),
      env.packetHex,
    )

  def PrecommitRouteKind(
    packet: VotePacketFormat::VotePacket_t,
  ): RouterKind_t =
    if (PrecommitTransport::NilPrecommitCertificatePacket(packet)) {
      NilPrecommitCertificateKind
    } else if (PrecommitTransport::ValuePrecommitCertificatePacket(packet)) {
      ValuePrecommitCertificateKind
    } else if (packet.noVotes > 0 and packet.yesVotes == 0) {
      NilPrecommitKind
    } else if (packet.yesVotes > 0 and packet.noVotes == 0) {
      ValuePrecommitKind
    } else if (packet.noVotes > 0 and packet.yesVotes > 0) {
      MixedPrecommitKind
    } else {
      UnknownKind
    }

  def PrecommitRoute(
    env: PrecommitTransport::TransportEnvelope_t,
    packet: VotePacketFormat::VotePacket_t,
  ): RoutedEnvelope_t =
    Routed(
      ConsensusChannel,
      CrosslinkConsensusTopic,
      PrecommitRouteKind(packet),
      env.packetHex,
    )

  def EvidenceRoute(
    env: EvidenceTransport::AccountabilityEvidenceTransportEnvelope_t,
  ): RoutedEnvelope_t =
    Routed(EvidenceChannel, env.topic, env.kind, env.evidenceHex)

  def KnownPeerRoute(
    packet: NonceAckTransport::KnownPeerTransportPacket_t,
  ): RoutedEnvelope_t =
    Routed(
      KnownPeerChannel,
      CrosslinkConsensusTopic,
      KnownPeerPacketKind,
      packet.consensusPacket.hex,
    )

  def StatusRoute(packet: StatusFormat::StatusPacket_t): RoutedEnvelope_t =
    Routed(StatusChannel, CrosslinkConsensusTopic, StatusPacketKind, packet.hex)

  def ConsensusRouteValid(env: RoutedEnvelope_t): bool =
    env.channel == ConsensusChannel and
    env.topic == CrosslinkConsensusTopic and
    (
      (
        env.kind == ProposalChunkKind and
        env.bytes == ProposalPolTransport::PolProposalConsensusPacketHex
      ) or
      (env.kind == PolPrevoteKind and PolPrevotePacketBytes.contains(env.bytes)) or
      (env.kind == NilPrecommitKind and
        env.bytes == PrecommitTransport::NilPrecommitConsensusPacketHex) or
      (env.kind == ValuePrecommitKind and
        env.bytes == PrecommitTransport::ValuePrecommitConsensusPacketHex) or
      (env.kind == MixedPrecommitKind and
        env.bytes == PrecommitTransport::MixedPrecommitQuorumConsensusPacketHex) or
      (env.kind == NilPrecommitCertificateKind and
        env.bytes == PrecommitTransport::NilPrecommitQuorumConsensusPacketHex) or
      (env.kind == ValuePrecommitCertificateKind and
        env.bytes == PrecommitTransport::ValuePrecommitQuorumConsensusPacketHex)
    )

  def EvidenceRouteValid(env: RoutedEnvelope_t): bool =
    env.channel == EvidenceChannel and
    env.topic == CrosslinkConsensusTopic and
    env.kind == AccountabilityEvidenceKind and
    AccountabilityEvidenceBytes.contains(env.bytes)

  def KnownPeerRouteValid(env: RoutedEnvelope_t): bool =
    env.channel == KnownPeerChannel and
    env.topic == CrosslinkConsensusTopic and
    env.kind == KnownPeerPacketKind and
    KnownPeerPacketBytes.contains(env.bytes)

  def StatusRouteValid(env: RoutedEnvelope_t): bool =
    env.channel == StatusChannel and
    env.topic == CrosslinkConsensusTopic and
    env.kind == StatusPacketKind and
    StatusPacketBytes.contains(env.bytes)

  pure val PolProposalEnvelope = ProposalPolTransport::polProposalEnvelope
  pure val MatchingPolProposalChunk =
    ProposalPolTransport::matchingPolProposalChunk
  pure val WeightedPolVoteEnvelope =
    ProposalPolTransport::weightedPolVoteEnvelope
  pure val WeightedPolVotePacket =
    ProposalPolTransport::valuePrevotePolWeightedPacket
  pure val QuorumPolVoteEnvelope =
    ProposalPolTransport::quorumPolVoteEnvelope
  pure val QuorumPolVotePacket =
    ProposalPolTransport::valuePrevotePolQuorumPacket
  pure val LargePolVoteEnvelope =
    ProposalPolTransport::largePolVoteEnvelope
  pure val LargePolVotePacket =
    ProposalPolTransport::valuePrevotePolLargePacket
  pure val WrongTypeProposalEnvelope =
    ProposalPolTransport::wrongTypeProposalEnvelope

  pure val NilPrecommitEnvelope = PrecommitTransport::nilPrecommitEnvelope
  pure val NilPrecommitPacket = PrecommitTransport::NilPrecommitPacket
  pure val ValuePrecommitEnvelope = PrecommitTransport::valuePrecommitEnvelope
  pure val ValuePrecommitPacket = PrecommitTransport::ValuePrecommitPacket
  pure val NilPrecommitQuorumEnvelope =
    PrecommitTransport::nilPrecommitQuorumEnvelope
  pure val NilPrecommitQuorumPacket =
    PrecommitTransport::NilPrecommitQuorumPacket
  pure val MixedPrecommitQuorumEnvelope =
    PrecommitTransport::mixedPrecommitQuorumEnvelope
  pure val MixedPrecommitQuorumPacket =
    PrecommitTransport::MixedPrecommitQuorumPacket
  pure val ValuePrecommitQuorumEnvelope =
    PrecommitTransport::valuePrecommitQuorumEnvelope
  pure val ValuePrecommitQuorumPacket =
    PrecommitTransport::ValuePrecommitQuorumPacket
  pure val WrongTypePrecommitEnvelope =
    PrecommitTransport::wrongTypePrecommitEnvelope

  pure val NilValueEvidenceEnvelope =
    EvidenceTransport::accountabilityEvidenceEnvelope
  pure val NilValuePrecommitEvidence =
    EvidenceTransport::nilValuePrecommitEvidence
  pure val ValueValueEvidenceEnvelope =
    EvidenceTransport::valueValueEvidenceEnvelope
  pure val ValueValuePrecommitEvidence =
    EvidenceTransport::valueValuePrecommitEvidence
  pure val WrongTopicEvidenceEnvelope = EvidenceTransport::wrongTopicEnvelope

  pure val KnownPeerPacket120 = NonceAckTransport::Packet120
  pure val ValidStatusPacket = StatusFormat::ValidStatusPacket
  pure val AckedPrevoteStatusPacket = StatusFormat::AckedPrevoteStatusPacket

  pure val ProposalRoute = ProposalPolRoute(PolProposalEnvelope)
  pure val WeightedPolRoute = ProposalPolRoute(WeightedPolVoteEnvelope)
  pure val QuorumPolRoute = ProposalPolRoute(QuorumPolVoteEnvelope)
  pure val LargePolRoute = ProposalPolRoute(LargePolVoteEnvelope)
  pure val NilPrecommitRoute =
    PrecommitRoute(NilPrecommitEnvelope, NilPrecommitPacket)
  pure val ValuePrecommitRoute =
    PrecommitRoute(ValuePrecommitEnvelope, ValuePrecommitPacket)
  pure val NilPrecommitCertificateRoute =
    PrecommitRoute(NilPrecommitQuorumEnvelope, NilPrecommitQuorumPacket)
  pure val MixedPrecommitRoute =
    PrecommitRoute(MixedPrecommitQuorumEnvelope, MixedPrecommitQuorumPacket)
  pure val ValuePrecommitCertificateRoute =
    PrecommitRoute(ValuePrecommitQuorumEnvelope, ValuePrecommitQuorumPacket)
  pure val NilValueEvidenceRoute = EvidenceRoute(NilValueEvidenceEnvelope)
  pure val ValueValueEvidenceRoute = EvidenceRoute(ValueValueEvidenceEnvelope)
  pure val KnownPeer120Route = KnownPeerRoute(KnownPeerPacket120)
  pure val StatusRouteRecord = StatusRoute(ValidStatusPacket)
  pure val AckedPrevoteStatusRoute =
    StatusRoute(AckedPrevoteStatusPacket)

  pure val ProposalKindOnEvidenceChannel =
    Routed(
      EvidenceChannel,
      CrosslinkConsensusTopic,
      ProposalChunkKind,
      ProposalRoute.bytes,
    )

  pure val EvidenceKindOnConsensusChannel =
    Routed(
      ConsensusChannel,
      CrosslinkConsensusTopic,
      AccountabilityEvidenceKind,
      NilValueEvidenceRoute.bytes,
    )

  pure val KnownPeerKindOnStatusChannel =
    Routed(
      StatusChannel,
      CrosslinkConsensusTopic,
      KnownPeerPacketKind,
      KnownPeer120Route.bytes,
    )

  pure val UnknownChannelRoute =
    Routed(UnknownChannel, CrosslinkConsensusTopic, ProposalChunkKind, ProposalRoute.bytes)

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
    ProposalPolTransport::TransportSafety and
    PrecommitTransport::PrecommitTransportSafety and
    EvidenceTransport::TransportSafety and
    NonceAckTransport::TransportSafety and
    StatusFormat::Safety and
    TenderlinkChannelsDisjoint and
    RoutedConsensusEnvelopesValid and
    RoutedEvidenceEnvelopesValid and
    RoutedKnownPeerEnvelopesValid and
    RoutedStatusEnvelopesValid

  val MatchingProposalChunkTransported =
    ProposalPolTransport::transportedProposalChunks.contains(
      MatchingPolProposalChunk
    )

  val WeightedPolVoteTransported =
    ProposalPolTransport::transportedPolPackets.contains(WeightedPolVotePacket)

  val NilPrecommitCertificateAccepted =
    PrecommitTransport::acceptedNilPrecommitCertificates.contains(
      NilPrecommitQuorumPacket
    )

  val ValuePrecommitCertificateAccepted =
    PrecommitTransport::acceptedValuePrecommitCertificates.contains(
      ValuePrecommitQuorumPacket
    )

  val NilValueEvidenceTransported =
    EvidenceTransport::transportedAccountabilityEvidence.contains(
      NilValuePrecommitEvidence
    )

  val Nonce120Accepted = NonceAckTransport::acceptedNonces.contains(120)

  val ValidStatusPacketAccepted =
    StatusFormat::acceptedStatusPackets.contains(ValidStatusPacket)

  action RouterInit = all {
    ProposalPolTransport::TransportInit,
    PrecommitTransport::PrecommitTransportInit,
    EvidenceTransport::TransportInit,
    NonceAckTransport::TransportInit,
    StatusFormat::Init,
    routedConsensusEnvelopes' = Set(),
    routedEvidenceEnvelopes' = Set(),
    routedKnownPeerEnvelopes' = Set(),
    routedStatusEnvelopes' = Set(),
    routerFiredAction' = "RouterInit",
  }

  action KeepRouterState = all {
    routedConsensusEnvelopes' = routedConsensusEnvelopes,
    routedEvidenceEnvelopes' = routedEvidenceEnvelopes,
    routedKnownPeerEnvelopes' = routedKnownPeerEnvelopes,
    routedStatusEnvelopes' = routedStatusEnvelopes,
  }

  action RouteProposalChunkTransport(
    env: ProposalPolTransport::TransportEnvelope_t,
    proposal: ProposalPolTransport::ProposalChunkWire_t,
  ): bool =
    all {
      ProposalPolTransport::ReceiveProposalChunkTransport(env, proposal),
      PrecommitTransport::PrecommitTransportStutter,
      EvidenceTransport::TransportStutter,
      NonceAckTransport::TransportStutter,
      StatusFormat::Stutter,
      routedConsensusEnvelopes' =
        routedConsensusEnvelopes.union(Set(ProposalPolRoute(env))),
      routedEvidenceEnvelopes' = routedEvidenceEnvelopes,
      routedKnownPeerEnvelopes' = routedKnownPeerEnvelopes,
      routedStatusEnvelopes' = routedStatusEnvelopes,
      routerFiredAction' = "RouteProposalChunkTransport",
    }

  action RoutePolVoteTransport(
    env: ProposalPolTransport::TransportEnvelope_t,
    packet: ProposalPolTransport::VotePacket_t,
  ): bool =
    all {
      ProposalPolTransport::ReceivePolVoteTransport(env, packet),
      PrecommitTransport::PrecommitTransportStutter,
      EvidenceTransport::TransportStutter,
      NonceAckTransport::TransportStutter,
      StatusFormat::Stutter,
      routedConsensusEnvelopes' =
        routedConsensusEnvelopes.union(Set(ProposalPolRoute(env))),
      routedEvidenceEnvelopes' = routedEvidenceEnvelopes,
      routedKnownPeerEnvelopes' = routedKnownPeerEnvelopes,
      routedStatusEnvelopes' = routedStatusEnvelopes,
      routerFiredAction' = "RoutePolVoteTransport",
    }

  action RoutePrecommitTransport(
    env: PrecommitTransport::TransportEnvelope_t,
    packet: VotePacketFormat::VotePacket_t,
  ): bool =
    all {
      ProposalPolTransport::TransportStutter,
      PrecommitTransport::ReceivePrecommitTransport(env, packet),
      EvidenceTransport::TransportStutter,
      NonceAckTransport::TransportStutter,
      StatusFormat::Stutter,
      routedConsensusEnvelopes' =
        routedConsensusEnvelopes.union(Set(PrecommitRoute(env, packet))),
      routedEvidenceEnvelopes' = routedEvidenceEnvelopes,
      routedKnownPeerEnvelopes' = routedKnownPeerEnvelopes,
      routedStatusEnvelopes' = routedStatusEnvelopes,
      routerFiredAction' = "RoutePrecommitTransport",
    }

  action AcceptNilPrecommitCertificateTransport(
    packet: VotePacketFormat::VotePacket_t,
  ): bool =
    all {
      ProposalPolTransport::TransportStutter,
      PrecommitTransport::AcceptNilPrecommitCertificate(packet),
      EvidenceTransport::TransportStutter,
      NonceAckTransport::TransportStutter,
      StatusFormat::Stutter,
      KeepRouterState,
      routerFiredAction' = "AcceptNilPrecommitCertificateTransport",
    }

  action AcceptValuePrecommitCertificateTransport(
    packet: VotePacketFormat::VotePacket_t,
  ): bool =
    all {
      ProposalPolTransport::TransportStutter,
      PrecommitTransport::AcceptValuePrecommitCertificate(packet),
      EvidenceTransport::TransportStutter,
      NonceAckTransport::TransportStutter,
      StatusFormat::Stutter,
      KeepRouterState,
      routerFiredAction' = "AcceptValuePrecommitCertificateTransport",
    }

  action RouteAccountabilityEvidenceTransport(
    env: EvidenceTransport::AccountabilityEvidenceTransportEnvelope_t,
    evidence: EvidenceTransport::AccountabilityEvidence_t,
  ): bool =
    all {
      ProposalPolTransport::TransportStutter,
      PrecommitTransport::PrecommitTransportStutter,
      EvidenceTransport::ReceiveAccountabilityEvidenceTransport(env, evidence),
      NonceAckTransport::TransportStutter,
      StatusFormat::Stutter,
      routedConsensusEnvelopes' = routedConsensusEnvelopes,
      routedEvidenceEnvelopes' =
        routedEvidenceEnvelopes.union(Set(EvidenceRoute(env))),
      routedKnownPeerEnvelopes' = routedKnownPeerEnvelopes,
      routedStatusEnvelopes' = routedStatusEnvelopes,
      routerFiredAction' = "RouteAccountabilityEvidenceTransport",
    }

  action RouteKnownPeerTransport(
    packet: NonceAckTransport::KnownPeerTransportPacket_t,
  ): bool =
    all {
      ProposalPolTransport::TransportStutter,
      PrecommitTransport::PrecommitTransportStutter,
      EvidenceTransport::TransportStutter,
      NonceAckTransport::AcceptKnownPeerTransportPacket(packet),
      StatusFormat::Stutter,
      routedConsensusEnvelopes' = routedConsensusEnvelopes,
      routedEvidenceEnvelopes' = routedEvidenceEnvelopes,
      routedKnownPeerEnvelopes' =
        routedKnownPeerEnvelopes.union(Set(KnownPeerRoute(packet))),
      routedStatusEnvelopes' = routedStatusEnvelopes,
      routerFiredAction' = "RouteKnownPeerTransport",
    }

  action RouteStatusPacket(packet: StatusFormat::StatusPacket_t): bool =
    all {
      ProposalPolTransport::TransportStutter,
      PrecommitTransport::PrecommitTransportStutter,
      EvidenceTransport::TransportStutter,
      NonceAckTransport::TransportStutter,
      StatusFormat::AcceptStatusPacket(packet),
      routedConsensusEnvelopes' = routedConsensusEnvelopes,
      routedEvidenceEnvelopes' = routedEvidenceEnvelopes,
      routedKnownPeerEnvelopes' = routedKnownPeerEnvelopes,
      routedStatusEnvelopes' =
        routedStatusEnvelopes.union(Set(StatusRoute(packet))),
      routerFiredAction' = "RouteStatusPacket",
    }

  action RawRouteConsensus(record: RoutedEnvelope_t): bool =
    all {
      ProposalPolTransport::TransportStutter,
      PrecommitTransport::PrecommitTransportStutter,
      EvidenceTransport::TransportStutter,
      NonceAckTransport::TransportStutter,
      StatusFormat::Stutter,
      routedConsensusEnvelopes' =
        routedConsensusEnvelopes.union(Set(record)),
      routedEvidenceEnvelopes' = routedEvidenceEnvelopes,
      routedKnownPeerEnvelopes' = routedKnownPeerEnvelopes,
      routedStatusEnvelopes' = routedStatusEnvelopes,
      routerFiredAction' = "RawRouteConsensus",
    }

  action RawRouteEvidence(record: RoutedEnvelope_t): bool =
    all {
      ProposalPolTransport::TransportStutter,
      PrecommitTransport::PrecommitTransportStutter,
      EvidenceTransport::TransportStutter,
      NonceAckTransport::TransportStutter,
      StatusFormat::Stutter,
      routedConsensusEnvelopes' = routedConsensusEnvelopes,
      routedEvidenceEnvelopes' =
        routedEvidenceEnvelopes.union(Set(record)),
      routedKnownPeerEnvelopes' = routedKnownPeerEnvelopes,
      routedStatusEnvelopes' = routedStatusEnvelopes,
      routerFiredAction' = "RawRouteEvidence",
    }

  action RawRouteStatus(record: RoutedEnvelope_t): bool =
    all {
      ProposalPolTransport::TransportStutter,
      PrecommitTransport::PrecommitTransportStutter,
      EvidenceTransport::TransportStutter,
      NonceAckTransport::TransportStutter,
      StatusFormat::Stutter,
      routedConsensusEnvelopes' = routedConsensusEnvelopes,
      routedEvidenceEnvelopes' = routedEvidenceEnvelopes,
      routedKnownPeerEnvelopes' = routedKnownPeerEnvelopes,
      routedStatusEnvelopes' =
        routedStatusEnvelopes.union(Set(record)),
      routerFiredAction' = "RawRouteStatus",
    }

  action RouterStutter: bool =
    all {
      ProposalPolTransport::TransportStutter,
      PrecommitTransport::PrecommitTransportStutter,
      EvidenceTransport::TransportStutter,
      NonceAckTransport::TransportStutter,
      StatusFormat::Stutter,
      KeepRouterState,
      routerFiredAction' = routerFiredAction,
    }

  action RouterUnchangedAll: bool =
    all {
      ProposalPolTransport::TransportStutter,
      PrecommitTransport::PrecommitTransportStutter,
      EvidenceTransport::TransportStutter,
      NonceAckTransport::TransportStutter,
      StatusFormat::Stutter,
      KeepRouterState,
      routerFiredAction' = routerFiredAction,
    }
}

module CrosslinkTenderlinkGossipRouterTest {
  import CrosslinkTenderlinkGossipRouter.* from
    "./CrosslinkTenderlinkGossipRouter"
  export CrosslinkTenderlinkGossipRouter.*

  action RouterNext: bool =
    any {
      RouteProposalChunkTransport(
        PolProposalEnvelope,
        MatchingPolProposalChunk,
      ),
      RoutePolVoteTransport(
        WeightedPolVoteEnvelope,
        WeightedPolVotePacket,
      ),
      RoutePolVoteTransport(
        QuorumPolVoteEnvelope,
        QuorumPolVotePacket,
      ),
      RoutePolVoteTransport(
        LargePolVoteEnvelope,
        LargePolVotePacket,
      ),
      RoutePrecommitTransport(
        NilPrecommitQuorumEnvelope,
        NilPrecommitQuorumPacket,
      ),
      AcceptNilPrecommitCertificateTransport(NilPrecommitQuorumPacket),
      RoutePrecommitTransport(
        ValuePrecommitQuorumEnvelope,
        ValuePrecommitQuorumPacket,
      ),
      AcceptValuePrecommitCertificateTransport(ValuePrecommitQuorumPacket),
      RouteAccountabilityEvidenceTransport(
        NilValueEvidenceEnvelope,
        NilValuePrecommitEvidence,
      ),
      RouteAccountabilityEvidenceTransport(
        ValueValueEvidenceEnvelope,
        ValueValuePrecommitEvidence,
      ),
      RouteKnownPeerTransport(KnownPeerPacket120),
      RouteStatusPacket(ValidStatusPacket),
      RouteStatusPacket(AckedPrevoteStatusPacket),
      RouterStutter,
    }

  action routerUnchangedAll = all {
    RouterUnchangedAll,
  }

  run channelsAreDisjointTest = {
    RouterInit.then(all {
      assert(TenderlinkChannelsDisjoint),
      assert(RouterSafety),
      routerUnchangedAll,
    })
  }

  run routesProposalAndPolTransportThroughConsensusChannelTest = {
    RouterInit
      .then(RouteProposalChunkTransport(
        PolProposalEnvelope,
        MatchingPolProposalChunk,
      ))
      .then(RoutePolVoteTransport(
        WeightedPolVoteEnvelope,
        WeightedPolVotePacket,
      ))
      .then(RoutePolVoteTransport(
        LargePolVoteEnvelope,
        LargePolVotePacket,
      ))
      .then(all {
        assert(routedConsensusEnvelopes.contains(ProposalRoute)),
        assert(routedConsensusEnvelopes.contains(WeightedPolRoute)),
        assert(routedConsensusEnvelopes.contains(LargePolRoute)),
        assert(MatchingProposalChunkTransported),
        assert(WeightedPolVoteTransported),
        assert(RouterSafety),
        routerUnchangedAll,
      })
  }

  run routesNilAndValuePrecommitCertificatesThroughConsensusChannelTest = {
    RouterInit
      .then(RoutePrecommitTransport(
        NilPrecommitQuorumEnvelope,
        NilPrecommitQuorumPacket,
      ))
      .then(AcceptNilPrecommitCertificateTransport(NilPrecommitQuorumPacket))
      .then(RoutePrecommitTransport(
        ValuePrecommitQuorumEnvelope,
        ValuePrecommitQuorumPacket,
      ))
      .then(AcceptValuePrecommitCertificateTransport(
        ValuePrecommitQuorumPacket
      ))
      .then(all {
        assert(routedConsensusEnvelopes.contains(NilPrecommitCertificateRoute)),
        assert(routedConsensusEnvelopes.contains(ValuePrecommitCertificateRoute)),
        assert(NilPrecommitCertificateAccepted),
        assert(ValuePrecommitCertificateAccepted),
        assert(RouterSafety),
        routerUnchangedAll,
      })
  }

  run routesLowPowerPrecommitPacketsWithoutCertificateTest = {
    RouterInit
      .then(RoutePrecommitTransport(
        NilPrecommitEnvelope,
        NilPrecommitPacket,
      ))
      .then(RoutePrecommitTransport(
        ValuePrecommitEnvelope,
        ValuePrecommitPacket,
      ))
      .then(RoutePrecommitTransport(
        MixedPrecommitQuorumEnvelope,
        MixedPrecommitQuorumPacket,
      ))
      .then(all {
        assert(routedConsensusEnvelopes.contains(NilPrecommitRoute)),
        assert(routedConsensusEnvelopes.contains(ValuePrecommitRoute)),
        assert(routedConsensusEnvelopes.contains(MixedPrecommitRoute)),
        assert(not(NilPrecommitCertificateAccepted)),
        assert(not(ValuePrecommitCertificateAccepted)),
        assert(RouterSafety),
        routerUnchangedAll,
      })
  }

  run routesAccountabilityEvidenceThroughEvidenceChannelTest = {
    RouterInit
      .then(RouteAccountabilityEvidenceTransport(
        NilValueEvidenceEnvelope,
        NilValuePrecommitEvidence,
      ))
      .then(RouteAccountabilityEvidenceTransport(
        ValueValueEvidenceEnvelope,
        ValueValuePrecommitEvidence,
      ))
      .then(all {
        assert(routedEvidenceEnvelopes.contains(NilValueEvidenceRoute)),
        assert(routedEvidenceEnvelopes.contains(ValueValueEvidenceRoute)),
        assert(NilValueEvidenceTransported),
        assert(RouterSafety),
        routerUnchangedAll,
      })
  }

  run routesKnownPeerAndStatusThroughSeparateChannelsTest = {
    RouterInit
      .then(RouteKnownPeerTransport(KnownPeerPacket120))
      .then(RouteStatusPacket(ValidStatusPacket))
      .then(RouteStatusPacket(AckedPrevoteStatusPacket))
      .then(all {
        assert(routedKnownPeerEnvelopes.contains(KnownPeer120Route)),
        assert(routedStatusEnvelopes.contains(StatusRouteRecord)),
        assert(routedStatusEnvelopes.contains(AckedPrevoteStatusRoute)),
        assert(Nonce120Accepted),
        assert(ValidStatusPacketAccepted),
        assert(RouterSafety),
        routerUnchangedAll,
      })
  }

  run wrongProposalTransportRejectedBeforeRoutingTest = {
    RouterInit
      .then(RouteProposalChunkTransport(
        WrongTypeProposalEnvelope,
        MatchingPolProposalChunk,
      ))
      .fail()
  }

  run wrongEvidenceTransportRejectedBeforeRoutingTest = {
    RouterInit
      .then(RouteAccountabilityEvidenceTransport(
        WrongTopicEvidenceEnvelope,
        NilValuePrecommitEvidence,
      ))
      .fail()
  }

  run wrongPrecommitTransportRejectedBeforeRoutingTest = {
    RouterInit
      .then(RoutePrecommitTransport(
        WrongTypePrecommitEnvelope,
        ValuePrecommitPacket,
      ))
      .fail()
  }

  run rawProposalKindOnEvidenceChannelViolatesRouterSafetyTest = {
    RouterInit
      .then(RawRouteEvidence(ProposalKindOnEvidenceChannel))
      .then(all {
        assert(not(RouterSafety)),
        routerUnchangedAll,
      })
  }

  run rawEvidenceKindOnConsensusChannelViolatesRouterSafetyTest = {
    RouterInit
      .then(RawRouteConsensus(EvidenceKindOnConsensusChannel))
      .then(all {
        assert(not(RouterSafety)),
        routerUnchangedAll,
      })
  }

  run rawKnownPeerKindOnStatusChannelViolatesRouterSafetyTest = {
    RouterInit
      .then(RawRouteStatus(KnownPeerKindOnStatusChannel))
      .then(all {
        assert(not(RouterSafety)),
        routerUnchangedAll,
      })
  }

  run unknownChannelViolatesRouterSafetyTest = {
    RouterInit
      .then(RawRouteConsensus(UnknownChannelRoute))
      .then(all {
        assert(not(RouterSafety)),
        routerUnchangedAll,
      })
  }
}

module CrosslinkTenderlinkGossipRouterModel {
  import CrosslinkTenderlinkGossipRouterTest.* from
    "./CrosslinkTenderlinkGossipRouter"
  export CrosslinkTenderlinkGossipRouterTest.*
}
