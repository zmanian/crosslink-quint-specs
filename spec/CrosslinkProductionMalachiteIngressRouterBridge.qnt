module CrosslinkProductionMalachiteIngressRouterBridge {
  /*
   Production Malachite ingress-to-router bridge.

   CrosslinkProductionGossipIngress.qnt accepts production-level Malachite
   records after the shared registry checks protocol/topic/channel/kind/bytes.
   CrosslinkMalachiteGossipRouterSafety.qnt records the downstream Malachite
   router namespace. This bridge connects those surfaces: a downstream
   Malachite router record may be routed only after the matching production
   Malachite ingress lane has accepted that record.
   */

  import CrosslinkProductionGossipIngress as Ingress from
    "./CrosslinkProductionGossipIngress"
  import CrosslinkMalachiteGossipRouterSafety as Router from
    "./CrosslinkMalachiteGossipRouterSafety"

  var bridgeProgress: int
  var bridgeFiredAction: str

  pure val ProductionProposalEnvelope =
    Ingress::Envelope(
      Ingress::MalachiteProtocol,
      Ingress::MalachiteProposalChannel,
      Ingress::MalachiteProposalTopic,
      Ingress::MalachiteProposalKind,
      Ingress::MalachiteProposalBytes,
    )

  pure val ProductionSignedProposalEnvelope =
    Ingress::MalachiteSignedProposalEnvelope

  pure val ProductionStreamedProposalEnvelope =
    Ingress::Envelope(
      Ingress::MalachiteProtocol,
      Ingress::MalachiteProposalChannel,
      Ingress::MalachiteProposalTopic,
      Ingress::MalachiteStreamedProposalKind,
      Ingress::MalachiteStreamedProposalBytes,
    )

  pure val ProductionPolkaEnvelope =
    Ingress::Envelope(
      Ingress::MalachiteProtocol,
      Ingress::MalachiteLivenessChannel,
      Ingress::MalachiteLivenessTopic,
      Ingress::MalachitePolkaKind,
      Ingress::MalachitePolkaBytes,
    )

  pure val ProductionRoundEnvelope =
    Ingress::MalachiteRoundEnvelope

  pure val ProductionSyncRequestEnvelope =
    Ingress::Envelope(
      Ingress::MalachiteProtocol,
      Ingress::MalachiteSyncChannel,
      Ingress::MalachiteSyncTopic,
      Ingress::MalachiteSyncRequestKind,
      Ingress::MalachiteSyncRequestBytes,
    )

  pure val ProductionSyncResponseEnvelope =
    Ingress::MalachiteSyncResponseEnvelope

  def ProposalIngressAccepted: bool =
    Ingress::acceptedMalachiteProposal.contains(ProductionProposalEnvelope)

  def SignedProposalIngressAccepted: bool =
    Ingress::acceptedMalachiteProposal.contains(
      ProductionSignedProposalEnvelope
    )

  def StreamedProposalIngressAccepted: bool =
    Ingress::acceptedMalachiteProposal.contains(
      ProductionStreamedProposalEnvelope
    )

  def PolkaIngressAccepted: bool =
    Ingress::acceptedMalachiteLiveness.contains(ProductionPolkaEnvelope)

  def RoundIngressAccepted: bool =
    Ingress::acceptedMalachiteLiveness.contains(ProductionRoundEnvelope)

  def SyncRequestIngressAccepted: bool =
    Ingress::acceptedMalachiteSync.contains(ProductionSyncRequestEnvelope)

  def SyncResponseIngressAccepted: bool =
    Ingress::acceptedMalachiteSync.contains(ProductionSyncResponseEnvelope)

  def IngressAcceptedForProposalRecord(
    record: Router::RoutedEnvelope_t,
  ): bool =
    if (record == Router::ProposalEnvelope) {
      ProposalIngressAccepted
    } else if (record == Router::SignedProposalEnvelope) {
      SignedProposalIngressAccepted
    } else if (record == Router::StreamedProposalEnvelope) {
      StreamedProposalIngressAccepted
    } else {
      false
    }

  def IngressAcceptedForLivenessRecord(
    record: Router::RoutedEnvelope_t,
  ): bool =
    if (record == Router::PolkaEnvelope) {
      PolkaIngressAccepted
    } else if (record == Router::RoundEnvelope) {
      RoundIngressAccepted
    } else {
      false
    }

  def IngressAcceptedForSyncRecord(record: Router::RoutedEnvelope_t): bool =
    if (record == Router::SyncRequestEnvelope) {
      SyncRequestIngressAccepted
    } else if (record == Router::SyncResponseEnvelope) {
      SyncResponseIngressAccepted
    } else {
      false
    }

  def MalachiteProductionIngressMatchesRouterFixtures: bool =
    Ingress::MalachiteProposalChannel == Router::ProposalChannel and
    Ingress::MalachiteLivenessChannel == Router::LivenessChannel and
    Ingress::MalachiteSyncChannel == Router::SyncChannel and
    Ingress::MalachiteProposalTopic == Router::ProposalTopic and
    Ingress::MalachiteLivenessTopic == Router::LivenessTopic and
    Ingress::MalachiteSyncTopic == Router::SyncTopic and
    Ingress::MalachiteProposalKind == Router::ProposalKind and
    Ingress::MalachiteSignedProposalKind == Router::SignedProposalKind and
    Ingress::MalachiteStreamedProposalKind ==
      Router::StreamedProposalKind and
    Ingress::MalachitePolkaKind == Router::PolkaKind and
    Ingress::MalachiteRoundKind == Router::RoundKind and
    Ingress::MalachiteSyncRequestKind == Router::SyncRequestKind and
    Ingress::MalachiteSyncResponseKind == Router::SyncResponseKind and
    Ingress::MalachiteProposalBytes == Router::ProposalBytes and
    Ingress::MalachiteSignedProposalBytes == Router::SignedProposalBytes and
    Ingress::MalachiteStreamedProposalBytes ==
      Router::StreamedProposalBytes and
    Ingress::MalachitePolkaBytes == Router::PolkaBytes and
    Ingress::MalachiteRoundBytes == Router::RoundBytes and
    Ingress::MalachiteSyncRequestBytes == Router::SyncRequestBytes and
    Ingress::MalachiteSyncResponseBytes == Router::SyncResponseBytes

  val RoutedProposalRequiresProductionIngress =
    Router::routedProposalEnvelopes.forall(
      IngressAcceptedForProposalRecord
    )

  val RoutedLivenessRequiresProductionIngress =
    Router::routedLivenessEnvelopes.forall(
      IngressAcceptedForLivenessRecord
    )

  val RoutedSyncRequiresProductionIngress =
    Router::routedSyncEnvelopes.forall(IngressAcceptedForSyncRecord)

  val BridgeStateWellFormed =
    bridgeProgress >= 0 and
    bridgeProgress <= 14 and
    Set(
      "Init",
      "AcceptProductionProposalIngress",
      "AcceptProductionSignedProposalIngress",
      "AcceptProductionStreamedProposalIngress",
      "AcceptProductionPolkaIngress",
      "AcceptProductionRoundIngress",
      "AcceptProductionSyncRequestIngress",
      "AcceptProductionSyncResponseIngress",
      "RouteProposalAfterIngress",
      "RouteSignedProposalAfterIngress",
      "RouteStreamedProposalAfterIngress",
      "RoutePolkaAfterIngress",
      "RouteRoundAfterIngress",
      "RouteSyncRequestAfterIngress",
      "RouteSyncResponseAfterIngress",
      "AttemptTenderlinkAsMalachiteProposalIngress",
      "AttemptDynamicSigmaAsMalachiteProposalIngress",
      "AttemptProductionFinalityAsMalachiteProposalIngress",
      "RawRouteSignedProposalWithoutIngress",
      "RawRouteRoundWithoutIngress",
      "RawRouteSyncResponseWithoutIngress",
      "Stutter",
    ).contains(bridgeFiredAction)

  val ProductionMalachiteIngressRouterBridgeSafety =
    Ingress::IngressSafety and
    Router::RouterSafety and
    MalachiteProductionIngressMatchesRouterFixtures and
    RoutedProposalRequiresProductionIngress and
    RoutedLivenessRequiresProductionIngress and
    RoutedSyncRequiresProductionIngress and
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

  action AcceptProductionProposalIngress: bool =
    all {
      not(ProposalIngressAccepted),
      Ingress::AcceptMalachiteProposal(ProductionProposalEnvelope),
      Router::RouterStutter,
      bridgeProgress' = bridgeProgress + 1,
      bridgeFiredAction' = "AcceptProductionProposalIngress",
    }

  action AcceptProductionSignedProposalIngress: bool =
    all {
      not(SignedProposalIngressAccepted),
      Ingress::AcceptMalachiteProposal(ProductionSignedProposalEnvelope),
      Router::RouterStutter,
      bridgeProgress' = bridgeProgress + 1,
      bridgeFiredAction' = "AcceptProductionSignedProposalIngress",
    }

  action AcceptProductionStreamedProposalIngress: bool =
    all {
      not(StreamedProposalIngressAccepted),
      Ingress::AcceptMalachiteProposal(ProductionStreamedProposalEnvelope),
      Router::RouterStutter,
      bridgeProgress' = bridgeProgress + 1,
      bridgeFiredAction' = "AcceptProductionStreamedProposalIngress",
    }

  action AcceptProductionPolkaIngress: bool =
    all {
      not(PolkaIngressAccepted),
      Ingress::AcceptMalachiteLiveness(ProductionPolkaEnvelope),
      Router::RouterStutter,
      bridgeProgress' = bridgeProgress + 1,
      bridgeFiredAction' = "AcceptProductionPolkaIngress",
    }

  action AcceptProductionRoundIngress: bool =
    all {
      not(RoundIngressAccepted),
      Ingress::AcceptMalachiteLiveness(ProductionRoundEnvelope),
      Router::RouterStutter,
      bridgeProgress' = bridgeProgress + 1,
      bridgeFiredAction' = "AcceptProductionRoundIngress",
    }

  action AcceptProductionSyncRequestIngress: bool =
    all {
      not(SyncRequestIngressAccepted),
      Ingress::AcceptMalachiteSync(ProductionSyncRequestEnvelope),
      Router::RouterStutter,
      bridgeProgress' = bridgeProgress + 1,
      bridgeFiredAction' = "AcceptProductionSyncRequestIngress",
    }

  action AcceptProductionSyncResponseIngress: bool =
    all {
      not(SyncResponseIngressAccepted),
      Ingress::AcceptMalachiteSync(ProductionSyncResponseEnvelope),
      Router::RouterStutter,
      bridgeProgress' = bridgeProgress + 1,
      bridgeFiredAction' = "AcceptProductionSyncResponseIngress",
    }

  action RouteProposalAfterIngress: bool =
    all {
      ProposalIngressAccepted,
      Ingress::IngressStutter,
      Router::RouteProposal(Router::ProposalEnvelope),
      bridgeProgress' = bridgeProgress + 1,
      bridgeFiredAction' = "RouteProposalAfterIngress",
    }

  action RouteSignedProposalAfterIngress: bool =
    all {
      SignedProposalIngressAccepted,
      Ingress::IngressStutter,
      Router::RouteProposal(Router::SignedProposalEnvelope),
      bridgeProgress' = bridgeProgress + 1,
      bridgeFiredAction' = "RouteSignedProposalAfterIngress",
    }

  action RouteStreamedProposalAfterIngress: bool =
    all {
      StreamedProposalIngressAccepted,
      Ingress::IngressStutter,
      Router::RouteProposal(Router::StreamedProposalEnvelope),
      bridgeProgress' = bridgeProgress + 1,
      bridgeFiredAction' = "RouteStreamedProposalAfterIngress",
    }

  action RoutePolkaAfterIngress: bool =
    all {
      PolkaIngressAccepted,
      Ingress::IngressStutter,
      Router::RouteLiveness(Router::PolkaEnvelope),
      bridgeProgress' = bridgeProgress + 1,
      bridgeFiredAction' = "RoutePolkaAfterIngress",
    }

  action RouteRoundAfterIngress: bool =
    all {
      RoundIngressAccepted,
      Ingress::IngressStutter,
      Router::RouteLiveness(Router::RoundEnvelope),
      bridgeProgress' = bridgeProgress + 1,
      bridgeFiredAction' = "RouteRoundAfterIngress",
    }

  action RouteSyncRequestAfterIngress: bool =
    all {
      SyncRequestIngressAccepted,
      Ingress::IngressStutter,
      Router::RouteSync(Router::SyncRequestEnvelope),
      bridgeProgress' = bridgeProgress + 1,
      bridgeFiredAction' = "RouteSyncRequestAfterIngress",
    }

  action RouteSyncResponseAfterIngress: bool =
    all {
      SyncResponseIngressAccepted,
      Ingress::IngressStutter,
      Router::RouteSync(Router::SyncResponseEnvelope),
      bridgeProgress' = bridgeProgress + 1,
      bridgeFiredAction' = "RouteSyncResponseAfterIngress",
    }

  action AttemptTenderlinkAsMalachiteProposalIngress: bool =
    all {
      Ingress::AcceptMalachiteProposal(
        Ingress::TenderlinkMixedPrecommitEnvelope
      ),
      Router::RouterStutter,
      bridgeProgress' = bridgeProgress + 1,
      bridgeFiredAction' = "AttemptTenderlinkAsMalachiteProposalIngress",
    }

  action AttemptDynamicSigmaAsMalachiteProposalIngress: bool =
    all {
      Ingress::AcceptMalachiteProposal(
        Ingress::DynamicSigmaBftPayloadEnvelope
      ),
      Router::RouterStutter,
      bridgeProgress' = bridgeProgress + 1,
      bridgeFiredAction' = "AttemptDynamicSigmaAsMalachiteProposalIngress",
    }

  action AttemptProductionFinalityAsMalachiteProposalIngress: bool =
    all {
      Ingress::AcceptMalachiteProposal(
        Ingress::ProductionBftBlockProposalEnvelope
      ),
      Router::RouterStutter,
      bridgeProgress' = bridgeProgress + 1,
      bridgeFiredAction' = "AttemptProductionFinalityAsMalachiteProposalIngress",
    }

  action RawRouteSignedProposalWithoutIngress: bool =
    all {
      not(SignedProposalIngressAccepted),
      Ingress::IngressStutter,
      Router::RawRouteProposal(Router::SignedProposalEnvelope),
      bridgeProgress' = bridgeProgress + 1,
      bridgeFiredAction' = "RawRouteSignedProposalWithoutIngress",
    }

  action RawRouteRoundWithoutIngress: bool =
    all {
      not(RoundIngressAccepted),
      Ingress::IngressStutter,
      Router::RawRouteLiveness(Router::RoundEnvelope),
      bridgeProgress' = bridgeProgress + 1,
      bridgeFiredAction' = "RawRouteRoundWithoutIngress",
    }

  action RawRouteSyncResponseWithoutIngress: bool =
    all {
      not(SyncResponseIngressAccepted),
      Ingress::IngressStutter,
      Router::RawRouteSync(Router::SyncResponseEnvelope),
      bridgeProgress' = bridgeProgress + 1,
      bridgeFiredAction' = "RawRouteSyncResponseWithoutIngress",
    }

  action Stutter: bool =
    all {
      Ingress::IngressStutter,
      Router::RouterStutter,
      KeepBridgeState,
    }

  action Next: bool =
    any {
      AcceptProductionProposalIngress,
      AcceptProductionSignedProposalIngress,
      AcceptProductionStreamedProposalIngress,
      AcceptProductionPolkaIngress,
      AcceptProductionRoundIngress,
      AcceptProductionSyncRequestIngress,
      AcceptProductionSyncResponseIngress,
      RouteProposalAfterIngress,
      RouteSignedProposalAfterIngress,
      RouteStreamedProposalAfterIngress,
      RoutePolkaAfterIngress,
      RouteRoundAfterIngress,
      RouteSyncRequestAfterIngress,
      RouteSyncResponseAfterIngress,
      Stutter,
    }

  run routesMalachiteProposalAfterProductionIngressTest = {
    Init
      .then(AcceptProductionProposalIngress)
      .then(AcceptProductionSignedProposalIngress)
      .then(AcceptProductionStreamedProposalIngress)
      .then(RouteProposalAfterIngress)
      .then(RouteSignedProposalAfterIngress)
      .then(RouteStreamedProposalAfterIngress)
      .then(all {
        assert(Router::routedProposalEnvelopes.contains(
          Router::ProposalEnvelope
        )),
        assert(Router::routedProposalEnvelopes.contains(
          Router::SignedProposalEnvelope
        )),
        assert(Router::routedProposalEnvelopes.contains(
          Router::StreamedProposalEnvelope
        )),
        assert(ProductionMalachiteIngressRouterBridgeSafety),
        Stutter,
      })
  }

  run routesMalachiteLivenessAndSyncAfterProductionIngressTest = {
    Init
      .then(AcceptProductionPolkaIngress)
      .then(AcceptProductionRoundIngress)
      .then(AcceptProductionSyncRequestIngress)
      .then(AcceptProductionSyncResponseIngress)
      .then(RoutePolkaAfterIngress)
      .then(RouteRoundAfterIngress)
      .then(RouteSyncRequestAfterIngress)
      .then(RouteSyncResponseAfterIngress)
      .then(all {
        assert(Router::routedLivenessEnvelopes.contains(
          Router::PolkaEnvelope
        )),
        assert(Router::routedLivenessEnvelopes.contains(
          Router::RoundEnvelope
        )),
        assert(Router::routedSyncEnvelopes.contains(
          Router::SyncRequestEnvelope
        )),
        assert(Router::routedSyncEnvelopes.contains(
          Router::SyncResponseEnvelope
        )),
        assert(ProductionMalachiteIngressRouterBridgeSafety),
        Stutter,
      })
  }

  run tenderlinkRejectedByMalachiteIngressTest = {
    Init
      .then(AttemptTenderlinkAsMalachiteProposalIngress)
      .fail()
  }

  run dynamicSigmaRejectedByMalachiteIngressTest = {
    Init
      .then(AttemptDynamicSigmaAsMalachiteProposalIngress)
      .fail()
  }

  run productionFinalityRejectedByMalachiteIngressTest = {
    Init
      .then(AttemptProductionFinalityAsMalachiteProposalIngress)
      .fail()
  }

  run rawProposalRouteWithoutIngressViolatesBridgeSafetyTest = {
    Init
      .then(RawRouteSignedProposalWithoutIngress)
      .then(all {
        assert(not(ProductionMalachiteIngressRouterBridgeSafety)),
        Stutter,
      })
  }

  run rawLivenessRouteWithoutIngressViolatesBridgeSafetyTest = {
    Init
      .then(RawRouteRoundWithoutIngress)
      .then(all {
        assert(not(ProductionMalachiteIngressRouterBridgeSafety)),
        Stutter,
      })
  }

  run rawSyncRouteWithoutIngressViolatesBridgeSafetyTest = {
    Init
      .then(RawRouteSyncResponseWithoutIngress)
      .then(all {
        assert(not(ProductionMalachiteIngressRouterBridgeSafety)),
        Stutter,
      })
  }

  run productionMalachiteIngressRouterBridgeSafetyTest = {
    Init
      .then(all {
        assert(ProductionMalachiteIngressRouterBridgeSafety),
        Stutter,
      })
  }
}

module CrosslinkProductionMalachiteIngressRouterBridgeModel {
  import CrosslinkProductionMalachiteIngressRouterBridge.* from
    "./CrosslinkProductionMalachiteIngressRouterBridge"
  export CrosslinkProductionMalachiteIngressRouterBridge.*
}
