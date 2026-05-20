module CrosslinkProductionTenderlinkIngressRouterBridge {
  /*
   Production Tenderlink ingress-to-router bridge.

   CrosslinkProductionGossipIngress.qnt accepts production-level Tenderlink
   records after the shared registry checks protocol/topic/channel/kind/bytes.
   CrosslinkTenderlinkGossipRouterSafety.qnt records the downstream Tenderlink
   router namespace. This bridge connects those surfaces: a downstream
   Tenderlink router record may be routed only after the matching production
   Tenderlink ingress lane has accepted that record.
   */

  import CrosslinkProductionGossipIngress as Ingress from
    "./CrosslinkProductionGossipIngress"
  import CrosslinkTenderlinkGossipRouterSafety as Router from
    "./CrosslinkTenderlinkGossipRouterSafety"

  var bridgeProgress: int
  var bridgeFiredAction: str

  pure val ProductionProposalChunkEnvelope =
    Ingress::Envelope(
      Ingress::TenderlinkProtocol,
      Ingress::TenderlinkConsensusChannel,
      Ingress::CrosslinkConsensusTopic,
      Ingress::TenderlinkProposalChunkKind,
      Ingress::TenderlinkProposalChunkBytes,
    )

  pure val ProductionPolPrevoteEnvelope =
    Ingress::Envelope(
      Ingress::TenderlinkProtocol,
      Ingress::TenderlinkConsensusChannel,
      Ingress::CrosslinkConsensusTopic,
      Ingress::TenderlinkPolPrevoteKind,
      Ingress::TenderlinkPolPrevoteBytes,
    )

  def ProposalChunkIngressAccepted: bool =
    Ingress::acceptedTenderlinkConsensus.contains(ProductionProposalChunkEnvelope)

  def PolPrevoteIngressAccepted: bool =
    Ingress::acceptedTenderlinkConsensus.contains(ProductionPolPrevoteEnvelope)

  def MixedPrecommitIngressAccepted: bool =
    Ingress::acceptedTenderlinkConsensus.contains(
      Ingress::TenderlinkMixedPrecommitEnvelope
    )

  def NilPrecommitCertificateIngressAccepted: bool =
    Ingress::acceptedTenderlinkConsensus.contains(
      Ingress::TenderlinkNilPrecommitCertificateEnvelope
    )

  def ValuePrecommitCertificateIngressAccepted: bool =
    Ingress::acceptedTenderlinkConsensus.contains(
      Ingress::TenderlinkValuePrecommitCertificateEnvelope
    )

  def EvidenceIngressAccepted: bool =
    Ingress::acceptedTenderlinkEvidence.contains(
      Ingress::TenderlinkEvidenceEnvelope
    )

  def KnownPeerIngressAccepted: bool =
    Ingress::acceptedTenderlinkKnownPeer.contains(
      Ingress::TenderlinkKnownPeerEnvelope
    )

  def StatusIngressAccepted: bool =
    Ingress::acceptedTenderlinkStatus.contains(
      Ingress::TenderlinkStatusEnvelope
    )

  def IngressAcceptedForConsensusRecord(
    record: Router::RoutedEnvelope_t,
  ): bool =
    if (record == Router::ProposalChunkEnvelope) {
      ProposalChunkIngressAccepted
    } else if (record == Router::PolPrevoteEnvelope) {
      PolPrevoteIngressAccepted
    } else if (record == Router::MixedPrecommitEnvelope) {
      MixedPrecommitIngressAccepted
    } else if (record == Router::NilPrecommitCertificateEnvelope) {
      NilPrecommitCertificateIngressAccepted
    } else if (record == Router::ValuePrecommitCertificateEnvelope) {
      ValuePrecommitCertificateIngressAccepted
    } else {
      false
    }

  def TenderlinkProductionIngressMatchesRouterFixtures: bool =
    Ingress::TenderlinkConsensusChannel == Router::ConsensusChannel and
    Ingress::TenderlinkEvidenceChannel == Router::EvidenceChannel and
    Ingress::TenderlinkKnownPeerChannel == Router::KnownPeerChannel and
    Ingress::TenderlinkStatusChannel == Router::StatusChannel and
    Ingress::CrosslinkConsensusTopic == Router::CrosslinkConsensusTopic and
    Ingress::TenderlinkProposalChunkKind == Router::ProposalChunkKind and
    Ingress::TenderlinkPolPrevoteKind == Router::PolPrevoteKind and
    Ingress::TenderlinkMixedPrecommitKind == Router::MixedPrecommitKind and
    Ingress::TenderlinkNilPrecommitCertificateKind ==
      Router::NilPrecommitCertificateKind and
    Ingress::TenderlinkValuePrecommitCertificateKind ==
      Router::ValuePrecommitCertificateKind and
    Ingress::TenderlinkAccountabilityEvidenceKind ==
      Router::AccountabilityEvidenceKind and
    Ingress::TenderlinkKnownPeerPacketKind == Router::KnownPeerPacketKind and
    Ingress::TenderlinkStatusPacketKind == Router::StatusPacketKind and
    Ingress::TenderlinkProposalChunkBytes == Router::ProposalChunkBytes and
    Ingress::TenderlinkPolPrevoteBytes == Router::PolPrevoteBytes and
    Ingress::TenderlinkMixedPrecommitBytes == Router::MixedPrecommitBytes and
    Ingress::TenderlinkNilPrecommitCertificateBytes ==
      Router::NilPrecommitCertificateBytes and
    Ingress::TenderlinkValuePrecommitCertificateBytes ==
      Router::ValuePrecommitCertificateBytes and
    Ingress::TenderlinkAccountabilityEvidenceBytes ==
      Router::AccountabilityEvidenceBytes and
    Ingress::TenderlinkKnownPeerPacketBytes == Router::KnownPeerPacketBytes and
    Ingress::TenderlinkStatusPacketBytes == Router::StatusPacketBytes

  val RoutedConsensusRequiresProductionIngress =
    Router::routedConsensusEnvelopes.forall(IngressAcceptedForConsensusRecord)

  val RoutedEvidenceRequiresProductionIngress =
    Router::routedEvidenceEnvelopes.forall(record =>
      record == Router::AccountabilityEvidenceEnvelope and
      EvidenceIngressAccepted
    )

  val RoutedKnownPeerRequiresProductionIngress =
    Router::routedKnownPeerEnvelopes.forall(record =>
      record == Router::KnownPeerEnvelope and
      KnownPeerIngressAccepted
    )

  val RoutedStatusRequiresProductionIngress =
    Router::routedStatusEnvelopes.forall(record =>
      record == Router::StatusEnvelope and
      StatusIngressAccepted
    )

  val BridgeStateWellFormed =
    bridgeProgress >= 0 and
    bridgeProgress <= 16 and
    Set(
      "Init",
      "AcceptProductionProposalChunkIngress",
      "AcceptProductionPolPrevoteIngress",
      "AcceptProductionMixedPrecommitIngress",
      "AcceptProductionNilPrecommitCertificateIngress",
      "AcceptProductionValuePrecommitCertificateIngress",
      "AcceptProductionEvidenceIngress",
      "AcceptProductionKnownPeerIngress",
      "AcceptProductionStatusIngress",
      "RouteProposalChunkAfterIngress",
      "RoutePolPrevoteAfterIngress",
      "RouteMixedPrecommitAfterIngress",
      "RouteNilPrecommitCertificateAfterIngress",
      "RouteValuePrecommitCertificateAfterIngress",
      "RouteEvidenceAfterIngress",
      "RouteKnownPeerAfterIngress",
      "RouteStatusAfterIngress",
      "AttemptDynamicSigmaAsTenderlinkConsensusIngress",
      "AttemptProductionFinalityAsTenderlinkConsensusIngress",
      "RawRouteMixedPrecommitWithoutIngress",
      "RawRouteEvidenceWithoutIngress",
      "RawRouteKnownPeerWithoutIngress",
      "RawRouteStatusWithoutIngress",
      "Stutter",
    ).contains(bridgeFiredAction)

  val ProductionTenderlinkIngressRouterBridgeSafety =
    Ingress::IngressSafety and
    Router::RouterSafety and
    TenderlinkProductionIngressMatchesRouterFixtures and
    RoutedConsensusRequiresProductionIngress and
    RoutedEvidenceRequiresProductionIngress and
    RoutedKnownPeerRequiresProductionIngress and
    RoutedStatusRequiresProductionIngress and
    BridgeStateWellFormed

  action Init = all {
    Ingress::IngressInit,
    Router::RouterInit,
    bridgeProgress' = 0,
    bridgeFiredAction' = "Init",
  }

  action KeepBridgeState = all {
    bridgeProgress' = bridgeProgress,
    bridgeFiredAction' = bridgeFiredAction,
  }

  action AcceptProductionProposalChunkIngress: bool =
    all {
      not(ProposalChunkIngressAccepted),
      Ingress::AcceptTenderlinkConsensus(ProductionProposalChunkEnvelope),
      Router::RouterStutter,
      bridgeProgress' = bridgeProgress + 1,
      bridgeFiredAction' = "AcceptProductionProposalChunkIngress",
    }

  action AcceptProductionPolPrevoteIngress: bool =
    all {
      not(PolPrevoteIngressAccepted),
      Ingress::AcceptTenderlinkConsensus(ProductionPolPrevoteEnvelope),
      Router::RouterStutter,
      bridgeProgress' = bridgeProgress + 1,
      bridgeFiredAction' = "AcceptProductionPolPrevoteIngress",
    }

  action AcceptProductionMixedPrecommitIngress: bool =
    all {
      not(MixedPrecommitIngressAccepted),
      Ingress::AcceptTenderlinkConsensus(
        Ingress::TenderlinkMixedPrecommitEnvelope
      ),
      Router::RouterStutter,
      bridgeProgress' = bridgeProgress + 1,
      bridgeFiredAction' = "AcceptProductionMixedPrecommitIngress",
    }

  action AcceptProductionNilPrecommitCertificateIngress: bool =
    all {
      not(NilPrecommitCertificateIngressAccepted),
      Ingress::AcceptTenderlinkConsensus(
        Ingress::TenderlinkNilPrecommitCertificateEnvelope
      ),
      Router::RouterStutter,
      bridgeProgress' = bridgeProgress + 1,
      bridgeFiredAction' =
        "AcceptProductionNilPrecommitCertificateIngress",
    }

  action AcceptProductionValuePrecommitCertificateIngress: bool =
    all {
      not(ValuePrecommitCertificateIngressAccepted),
      Ingress::AcceptTenderlinkConsensus(
        Ingress::TenderlinkValuePrecommitCertificateEnvelope
      ),
      Router::RouterStutter,
      bridgeProgress' = bridgeProgress + 1,
      bridgeFiredAction' =
        "AcceptProductionValuePrecommitCertificateIngress",
    }

  action AcceptProductionEvidenceIngress: bool =
    all {
      not(EvidenceIngressAccepted),
      Ingress::AcceptTenderlinkEvidence(Ingress::TenderlinkEvidenceEnvelope),
      Router::RouterStutter,
      bridgeProgress' = bridgeProgress + 1,
      bridgeFiredAction' = "AcceptProductionEvidenceIngress",
    }

  action AcceptProductionKnownPeerIngress: bool =
    all {
      not(KnownPeerIngressAccepted),
      Ingress::AcceptTenderlinkKnownPeer(
        Ingress::TenderlinkKnownPeerEnvelope
      ),
      Router::RouterStutter,
      bridgeProgress' = bridgeProgress + 1,
      bridgeFiredAction' = "AcceptProductionKnownPeerIngress",
    }

  action AcceptProductionStatusIngress: bool =
    all {
      not(StatusIngressAccepted),
      Ingress::AcceptTenderlinkStatus(Ingress::TenderlinkStatusEnvelope),
      Router::RouterStutter,
      bridgeProgress' = bridgeProgress + 1,
      bridgeFiredAction' = "AcceptProductionStatusIngress",
    }

  action RouteProposalChunkAfterIngress: bool =
    all {
      ProposalChunkIngressAccepted,
      Ingress::IngressStutter,
      Router::RouteConsensus(Router::ProposalChunkEnvelope),
      bridgeProgress' = bridgeProgress + 1,
      bridgeFiredAction' = "RouteProposalChunkAfterIngress",
    }

  action RoutePolPrevoteAfterIngress: bool =
    all {
      PolPrevoteIngressAccepted,
      Ingress::IngressStutter,
      Router::RouteConsensus(Router::PolPrevoteEnvelope),
      bridgeProgress' = bridgeProgress + 1,
      bridgeFiredAction' = "RoutePolPrevoteAfterIngress",
    }

  action RouteMixedPrecommitAfterIngress: bool =
    all {
      MixedPrecommitIngressAccepted,
      Ingress::IngressStutter,
      Router::RouteConsensus(Router::MixedPrecommitEnvelope),
      bridgeProgress' = bridgeProgress + 1,
      bridgeFiredAction' = "RouteMixedPrecommitAfterIngress",
    }

  action RouteNilPrecommitCertificateAfterIngress: bool =
    all {
      NilPrecommitCertificateIngressAccepted,
      Ingress::IngressStutter,
      Router::RouteConsensus(Router::NilPrecommitCertificateEnvelope),
      bridgeProgress' = bridgeProgress + 1,
      bridgeFiredAction' = "RouteNilPrecommitCertificateAfterIngress",
    }

  action RouteValuePrecommitCertificateAfterIngress: bool =
    all {
      ValuePrecommitCertificateIngressAccepted,
      Ingress::IngressStutter,
      Router::RouteConsensus(Router::ValuePrecommitCertificateEnvelope),
      bridgeProgress' = bridgeProgress + 1,
      bridgeFiredAction' = "RouteValuePrecommitCertificateAfterIngress",
    }

  action RouteEvidenceAfterIngress: bool =
    all {
      EvidenceIngressAccepted,
      Ingress::IngressStutter,
      Router::RouteEvidence(Router::AccountabilityEvidenceEnvelope),
      bridgeProgress' = bridgeProgress + 1,
      bridgeFiredAction' = "RouteEvidenceAfterIngress",
    }

  action RouteKnownPeerAfterIngress: bool =
    all {
      KnownPeerIngressAccepted,
      Ingress::IngressStutter,
      Router::RouteKnownPeer(Router::KnownPeerEnvelope),
      bridgeProgress' = bridgeProgress + 1,
      bridgeFiredAction' = "RouteKnownPeerAfterIngress",
    }

  action RouteStatusAfterIngress: bool =
    all {
      StatusIngressAccepted,
      Ingress::IngressStutter,
      Router::RouteStatus(Router::StatusEnvelope),
      bridgeProgress' = bridgeProgress + 1,
      bridgeFiredAction' = "RouteStatusAfterIngress",
    }

  action AttemptDynamicSigmaAsTenderlinkConsensusIngress: bool =
    all {
      Ingress::AcceptTenderlinkConsensus(
        Ingress::DynamicSigmaConsensusParamEnvelope
      ),
      Router::RouterStutter,
      bridgeProgress' = bridgeProgress + 1,
      bridgeFiredAction' = "AttemptDynamicSigmaAsTenderlinkConsensusIngress",
    }

  action AttemptProductionFinalityAsTenderlinkConsensusIngress: bool =
    all {
      Ingress::AcceptTenderlinkConsensus(
        Ingress::ProductionBftBlockProposalEnvelope
      ),
      Router::RouterStutter,
      bridgeProgress' = bridgeProgress + 1,
      bridgeFiredAction' =
        "AttemptProductionFinalityAsTenderlinkConsensusIngress",
    }

  action RawRouteMixedPrecommitWithoutIngress: bool =
    all {
      not(MixedPrecommitIngressAccepted),
      Ingress::IngressStutter,
      Router::RawRouteConsensus(Router::MixedPrecommitEnvelope),
      bridgeProgress' = bridgeProgress + 1,
      bridgeFiredAction' = "RawRouteMixedPrecommitWithoutIngress",
    }

  action RawRouteEvidenceWithoutIngress: bool =
    all {
      not(EvidenceIngressAccepted),
      Ingress::IngressStutter,
      Router::RawRouteEvidence(Router::AccountabilityEvidenceEnvelope),
      bridgeProgress' = bridgeProgress + 1,
      bridgeFiredAction' = "RawRouteEvidenceWithoutIngress",
    }

  action RawRouteKnownPeerWithoutIngress: bool =
    all {
      not(KnownPeerIngressAccepted),
      Ingress::IngressStutter,
      Router::RawRouteKnownPeer(Router::KnownPeerEnvelope),
      bridgeProgress' = bridgeProgress + 1,
      bridgeFiredAction' = "RawRouteKnownPeerWithoutIngress",
    }

  action RawRouteStatusWithoutIngress: bool =
    all {
      not(StatusIngressAccepted),
      Ingress::IngressStutter,
      Router::RawRouteStatus(Router::StatusEnvelope),
      bridgeProgress' = bridgeProgress + 1,
      bridgeFiredAction' = "RawRouteStatusWithoutIngress",
    }

  action Stutter: bool =
    all {
      Ingress::IngressStutter,
      Router::RouterStutter,
      KeepBridgeState,
    }

  action Next: bool =
    any {
      AcceptProductionProposalChunkIngress,
      AcceptProductionPolPrevoteIngress,
      AcceptProductionMixedPrecommitIngress,
      AcceptProductionNilPrecommitCertificateIngress,
      AcceptProductionValuePrecommitCertificateIngress,
      AcceptProductionEvidenceIngress,
      AcceptProductionKnownPeerIngress,
      AcceptProductionStatusIngress,
      RouteProposalChunkAfterIngress,
      RoutePolPrevoteAfterIngress,
      RouteMixedPrecommitAfterIngress,
      RouteNilPrecommitCertificateAfterIngress,
      RouteValuePrecommitCertificateAfterIngress,
      RouteEvidenceAfterIngress,
      RouteKnownPeerAfterIngress,
      RouteStatusAfterIngress,
      Stutter,
    }

  run routesTenderlinkConsensusAfterProductionIngressTest = {
    Init
      .then(AcceptProductionProposalChunkIngress)
      .then(AcceptProductionPolPrevoteIngress)
      .then(AcceptProductionMixedPrecommitIngress)
      .then(AcceptProductionNilPrecommitCertificateIngress)
      .then(AcceptProductionValuePrecommitCertificateIngress)
      .then(RouteProposalChunkAfterIngress)
      .then(RoutePolPrevoteAfterIngress)
      .then(RouteMixedPrecommitAfterIngress)
      .then(RouteNilPrecommitCertificateAfterIngress)
      .then(RouteValuePrecommitCertificateAfterIngress)
      .then(all {
        assert(Router::routedConsensusEnvelopes.contains(
          Router::ProposalChunkEnvelope
        )),
        assert(Router::routedConsensusEnvelopes.contains(
          Router::PolPrevoteEnvelope
        )),
        assert(Router::routedConsensusEnvelopes.contains(
          Router::MixedPrecommitEnvelope
        )),
        assert(Router::routedConsensusEnvelopes.contains(
          Router::NilPrecommitCertificateEnvelope
        )),
        assert(Router::routedConsensusEnvelopes.contains(
          Router::ValuePrecommitCertificateEnvelope
        )),
        assert(ProductionTenderlinkIngressRouterBridgeSafety),
        Stutter,
      })
  }

  run routesTenderlinkEvidenceKnownPeerAndStatusAfterProductionIngressTest = {
    Init
      .then(AcceptProductionEvidenceIngress)
      .then(AcceptProductionKnownPeerIngress)
      .then(AcceptProductionStatusIngress)
      .then(RouteEvidenceAfterIngress)
      .then(RouteKnownPeerAfterIngress)
      .then(RouteStatusAfterIngress)
      .then(all {
        assert(Router::routedEvidenceEnvelopes.contains(
          Router::AccountabilityEvidenceEnvelope
        )),
        assert(Router::routedKnownPeerEnvelopes.contains(
          Router::KnownPeerEnvelope
        )),
        assert(Router::routedStatusEnvelopes.contains(Router::StatusEnvelope)),
        assert(ProductionTenderlinkIngressRouterBridgeSafety),
        Stutter,
      })
  }

  run dynamicSigmaRejectedByTenderlinkIngressTest = {
    Init
      .then(AttemptDynamicSigmaAsTenderlinkConsensusIngress)
      .fail()
  }

  run productionFinalityRejectedByTenderlinkIngressTest = {
    Init
      .then(AttemptProductionFinalityAsTenderlinkConsensusIngress)
      .fail()
  }

  run rawConsensusRouteWithoutIngressViolatesBridgeSafetyTest = {
    Init
      .then(RawRouteMixedPrecommitWithoutIngress)
      .then(all {
        assert(not(ProductionTenderlinkIngressRouterBridgeSafety)),
        Stutter,
      })
  }

  run rawEvidenceRouteWithoutIngressViolatesBridgeSafetyTest = {
    Init
      .then(RawRouteEvidenceWithoutIngress)
      .then(all {
        assert(not(ProductionTenderlinkIngressRouterBridgeSafety)),
        Stutter,
      })
  }

  run rawKnownPeerRouteWithoutIngressViolatesBridgeSafetyTest = {
    Init
      .then(RawRouteKnownPeerWithoutIngress)
      .then(all {
        assert(not(ProductionTenderlinkIngressRouterBridgeSafety)),
        Stutter,
      })
  }

  run rawStatusRouteWithoutIngressViolatesBridgeSafetyTest = {
    Init
      .then(RawRouteStatusWithoutIngress)
      .then(all {
        assert(not(ProductionTenderlinkIngressRouterBridgeSafety)),
        Stutter,
      })
  }

  run productionTenderlinkIngressRouterBridgeSafetyTest = {
    Init
      .then(all {
        assert(ProductionTenderlinkIngressRouterBridgeSafety),
        Stutter,
      })
  }
}

module CrosslinkProductionTenderlinkIngressRouterBridgeModel {
  import CrosslinkProductionTenderlinkIngressRouterBridge.* from
    "./CrosslinkProductionTenderlinkIngressRouterBridge"
  export CrosslinkProductionTenderlinkIngressRouterBridge.*
}
