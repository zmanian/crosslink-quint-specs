module CrosslinkProductionGossipIngress {
  /*
   Production node gossip ingress safety.

   CrosslinkProductionGossipRegistry.qnt records the production channel
   registry across Tenderlink compact packets, Malachite protobuf packets,
   dynamic-sigma consensus-param packets, and production-finality
   proposal/fat-pointer packets. This slice models the next node-local gate:
   an accepted ingress record must enter the exact downstream lane selected by
   the registry. A registry-valid accountability evidence envelope is still
   unsafe if it is handed to the Tenderlink consensus packet lane, and a
   dynamic-sigma consensus-param or production-finality envelope is still
   unsafe if it reaches any unrelated lane.
   */

  import CrosslinkProductionGossipRegistry.* from
    "./CrosslinkProductionGossipRegistry"
  export CrosslinkProductionGossipRegistry.*

  var acceptedTenderlinkConsensus: Set[ProductionEnvelope_t]
  var acceptedTenderlinkEvidence: Set[ProductionEnvelope_t]
  var acceptedTenderlinkKnownPeer: Set[ProductionEnvelope_t]
  var acceptedTenderlinkStatus: Set[ProductionEnvelope_t]
  var acceptedMalachiteProposal: Set[ProductionEnvelope_t]
  var acceptedMalachiteLiveness: Set[ProductionEnvelope_t]
  var acceptedMalachiteSync: Set[ProductionEnvelope_t]
  var acceptedDynamicSigmaConsensusParam: Set[ProductionEnvelope_t]
  var acceptedProductionBftBlockProposal: Set[ProductionEnvelope_t]
  var acceptedProductionFatPointerWire: Set[ProductionEnvelope_t]
  var ingressFiredAction: str

  pure val TenderlinkConsensusIngressFixtures =
    Set(
      TenderlinkMixedPrecommitEnvelope,
      TenderlinkNilPrecommitCertificateEnvelope,
      TenderlinkValuePrecommitCertificateEnvelope,
    )
  pure val TenderlinkEvidenceIngressFixtures = Set(TenderlinkEvidenceEnvelope)
  pure val TenderlinkKnownPeerIngressFixtures = Set(TenderlinkKnownPeerEnvelope)
  pure val TenderlinkStatusIngressFixtures = Set(TenderlinkStatusEnvelope)
  pure val MalachiteProposalIngressFixtures = Set(MalachiteSignedProposalEnvelope)
  pure val MalachiteLivenessIngressFixtures = Set(MalachiteRoundEnvelope)
  pure val MalachiteSyncIngressFixtures = Set(MalachiteSyncResponseEnvelope)
  pure val DynamicSigmaConsensusParamIngressFixtures =
    Set(
      DynamicSigmaConsensusParamEnvelope,
      DynamicSigmaConsensusParamRecoveredEnvelope,
    )
  pure val ProductionBftBlockProposalIngressFixtures =
    Set(ProductionBftBlockProposalEnvelope)
  pure val ProductionFatPointerWireIngressFixtures =
    Set(ProductionFatPointerWireEnvelope)

  val AcceptedTenderlinkConsensusValid =
    acceptedTenderlinkConsensus.forall(TenderlinkConsensusRouteValid)

  val AcceptedTenderlinkEvidenceValid =
    acceptedTenderlinkEvidence.forall(TenderlinkEvidenceRouteValid)

  val AcceptedTenderlinkKnownPeerValid =
    acceptedTenderlinkKnownPeer.forall(TenderlinkKnownPeerRouteValid)

  val AcceptedTenderlinkStatusValid =
    acceptedTenderlinkStatus.forall(TenderlinkStatusRouteValid)

  val AcceptedMalachiteProposalValid =
    acceptedMalachiteProposal.forall(MalachiteProposalRouteValid)

  val AcceptedMalachiteLivenessValid =
    acceptedMalachiteLiveness.forall(MalachiteLivenessRouteValid)

  val AcceptedMalachiteSyncValid =
    acceptedMalachiteSync.forall(MalachiteSyncRouteValid)

  val AcceptedDynamicSigmaConsensusParamValid =
    acceptedDynamicSigmaConsensusParam.forall(
      DynamicSigmaConsensusParamRouteValid
    )

  val AcceptedProductionBftBlockProposalValid =
    acceptedProductionBftBlockProposal.forall(
      ProductionBftBlockProposalRouteValid
    )

  val AcceptedProductionFatPointerWireValid =
    acceptedProductionFatPointerWire.forall(ProductionFatPointerWireRouteValid)

  val IngressSafety =
    ProductionTopicsDisjoint and
    ProductionChannelsDisjoint and
    AcceptedTenderlinkConsensusValid and
    AcceptedTenderlinkEvidenceValid and
    AcceptedTenderlinkKnownPeerValid and
    AcceptedTenderlinkStatusValid and
    AcceptedMalachiteProposalValid and
    AcceptedMalachiteLivenessValid and
    AcceptedMalachiteSyncValid and
    AcceptedDynamicSigmaConsensusParamValid and
    AcceptedProductionBftBlockProposalValid and
    AcceptedProductionFatPointerWireValid

  action IngressInit = all {
    routedProductionEnvelopes' = Set(),
    registryFiredAction' = "IngressInit",
    acceptedTenderlinkConsensus' = Set(),
    acceptedTenderlinkEvidence' = Set(),
    acceptedTenderlinkKnownPeer' = Set(),
    acceptedTenderlinkStatus' = Set(),
    acceptedMalachiteProposal' = Set(),
    acceptedMalachiteLiveness' = Set(),
    acceptedMalachiteSync' = Set(),
    acceptedDynamicSigmaConsensusParam' = Set(),
    acceptedProductionBftBlockProposal' = Set(),
    acceptedProductionFatPointerWire' = Set(),
    ingressFiredAction' = "IngressInit",
  }

  action KeepRegistryState: bool =
    all {
      routedProductionEnvelopes' = routedProductionEnvelopes,
      registryFiredAction' = registryFiredAction,
    }

  action AcceptTenderlinkConsensus(env: ProductionEnvelope_t): bool =
    all {
      TenderlinkConsensusRouteValid(env),
      KeepRegistryState,
      acceptedTenderlinkConsensus' =
        acceptedTenderlinkConsensus.union(Set(env)),
      acceptedTenderlinkEvidence' = acceptedTenderlinkEvidence,
      acceptedTenderlinkKnownPeer' = acceptedTenderlinkKnownPeer,
      acceptedTenderlinkStatus' = acceptedTenderlinkStatus,
      acceptedMalachiteProposal' = acceptedMalachiteProposal,
      acceptedMalachiteLiveness' = acceptedMalachiteLiveness,
      acceptedMalachiteSync' = acceptedMalachiteSync,
      acceptedDynamicSigmaConsensusParam' =
        acceptedDynamicSigmaConsensusParam,
      acceptedProductionBftBlockProposal' =
        acceptedProductionBftBlockProposal,
      acceptedProductionFatPointerWire' =
        acceptedProductionFatPointerWire,
      ingressFiredAction' = "AcceptTenderlinkConsensus",
    }

  action AcceptTenderlinkEvidence(env: ProductionEnvelope_t): bool =
    all {
      TenderlinkEvidenceRouteValid(env),
      KeepRegistryState,
      acceptedTenderlinkConsensus' = acceptedTenderlinkConsensus,
      acceptedTenderlinkEvidence' = acceptedTenderlinkEvidence.union(Set(env)),
      acceptedTenderlinkKnownPeer' = acceptedTenderlinkKnownPeer,
      acceptedTenderlinkStatus' = acceptedTenderlinkStatus,
      acceptedMalachiteProposal' = acceptedMalachiteProposal,
      acceptedMalachiteLiveness' = acceptedMalachiteLiveness,
      acceptedMalachiteSync' = acceptedMalachiteSync,
      acceptedDynamicSigmaConsensusParam' =
        acceptedDynamicSigmaConsensusParam,
      acceptedProductionBftBlockProposal' =
        acceptedProductionBftBlockProposal,
      acceptedProductionFatPointerWire' =
        acceptedProductionFatPointerWire,
      ingressFiredAction' = "AcceptTenderlinkEvidence",
    }

  action AcceptTenderlinkKnownPeer(env: ProductionEnvelope_t): bool =
    all {
      TenderlinkKnownPeerRouteValid(env),
      KeepRegistryState,
      acceptedTenderlinkConsensus' = acceptedTenderlinkConsensus,
      acceptedTenderlinkEvidence' = acceptedTenderlinkEvidence,
      acceptedTenderlinkKnownPeer' =
        acceptedTenderlinkKnownPeer.union(Set(env)),
      acceptedTenderlinkStatus' = acceptedTenderlinkStatus,
      acceptedMalachiteProposal' = acceptedMalachiteProposal,
      acceptedMalachiteLiveness' = acceptedMalachiteLiveness,
      acceptedMalachiteSync' = acceptedMalachiteSync,
      acceptedDynamicSigmaConsensusParam' =
        acceptedDynamicSigmaConsensusParam,
      acceptedProductionBftBlockProposal' =
        acceptedProductionBftBlockProposal,
      acceptedProductionFatPointerWire' =
        acceptedProductionFatPointerWire,
      ingressFiredAction' = "AcceptTenderlinkKnownPeer",
    }

  action AcceptTenderlinkStatus(env: ProductionEnvelope_t): bool =
    all {
      TenderlinkStatusRouteValid(env),
      KeepRegistryState,
      acceptedTenderlinkConsensus' = acceptedTenderlinkConsensus,
      acceptedTenderlinkEvidence' = acceptedTenderlinkEvidence,
      acceptedTenderlinkKnownPeer' = acceptedTenderlinkKnownPeer,
      acceptedTenderlinkStatus' = acceptedTenderlinkStatus.union(Set(env)),
      acceptedMalachiteProposal' = acceptedMalachiteProposal,
      acceptedMalachiteLiveness' = acceptedMalachiteLiveness,
      acceptedMalachiteSync' = acceptedMalachiteSync,
      acceptedDynamicSigmaConsensusParam' =
        acceptedDynamicSigmaConsensusParam,
      acceptedProductionBftBlockProposal' =
        acceptedProductionBftBlockProposal,
      acceptedProductionFatPointerWire' =
        acceptedProductionFatPointerWire,
      ingressFiredAction' = "AcceptTenderlinkStatus",
    }

  action AcceptMalachiteProposal(env: ProductionEnvelope_t): bool =
    all {
      MalachiteProposalRouteValid(env),
      KeepRegistryState,
      acceptedTenderlinkConsensus' = acceptedTenderlinkConsensus,
      acceptedTenderlinkEvidence' = acceptedTenderlinkEvidence,
      acceptedTenderlinkKnownPeer' = acceptedTenderlinkKnownPeer,
      acceptedTenderlinkStatus' = acceptedTenderlinkStatus,
      acceptedMalachiteProposal' = acceptedMalachiteProposal.union(Set(env)),
      acceptedMalachiteLiveness' = acceptedMalachiteLiveness,
      acceptedMalachiteSync' = acceptedMalachiteSync,
      acceptedDynamicSigmaConsensusParam' =
        acceptedDynamicSigmaConsensusParam,
      acceptedProductionBftBlockProposal' =
        acceptedProductionBftBlockProposal,
      acceptedProductionFatPointerWire' =
        acceptedProductionFatPointerWire,
      ingressFiredAction' = "AcceptMalachiteProposal",
    }

  action AcceptMalachiteLiveness(env: ProductionEnvelope_t): bool =
    all {
      MalachiteLivenessRouteValid(env),
      KeepRegistryState,
      acceptedTenderlinkConsensus' = acceptedTenderlinkConsensus,
      acceptedTenderlinkEvidence' = acceptedTenderlinkEvidence,
      acceptedTenderlinkKnownPeer' = acceptedTenderlinkKnownPeer,
      acceptedTenderlinkStatus' = acceptedTenderlinkStatus,
      acceptedMalachiteProposal' = acceptedMalachiteProposal,
      acceptedMalachiteLiveness' = acceptedMalachiteLiveness.union(Set(env)),
      acceptedMalachiteSync' = acceptedMalachiteSync,
      acceptedDynamicSigmaConsensusParam' =
        acceptedDynamicSigmaConsensusParam,
      acceptedProductionBftBlockProposal' =
        acceptedProductionBftBlockProposal,
      acceptedProductionFatPointerWire' =
        acceptedProductionFatPointerWire,
      ingressFiredAction' = "AcceptMalachiteLiveness",
    }

  action AcceptMalachiteSync(env: ProductionEnvelope_t): bool =
    all {
      MalachiteSyncRouteValid(env),
      KeepRegistryState,
      acceptedTenderlinkConsensus' = acceptedTenderlinkConsensus,
      acceptedTenderlinkEvidence' = acceptedTenderlinkEvidence,
      acceptedTenderlinkKnownPeer' = acceptedTenderlinkKnownPeer,
      acceptedTenderlinkStatus' = acceptedTenderlinkStatus,
      acceptedMalachiteProposal' = acceptedMalachiteProposal,
      acceptedMalachiteLiveness' = acceptedMalachiteLiveness,
      acceptedMalachiteSync' = acceptedMalachiteSync.union(Set(env)),
      acceptedDynamicSigmaConsensusParam' =
        acceptedDynamicSigmaConsensusParam,
      acceptedProductionBftBlockProposal' =
        acceptedProductionBftBlockProposal,
      acceptedProductionFatPointerWire' =
        acceptedProductionFatPointerWire,
      ingressFiredAction' = "AcceptMalachiteSync",
    }

  action AcceptDynamicSigmaConsensusParam(
    env: ProductionEnvelope_t,
  ): bool =
    all {
      DynamicSigmaConsensusParamRouteValid(env),
      KeepRegistryState,
      acceptedTenderlinkConsensus' = acceptedTenderlinkConsensus,
      acceptedTenderlinkEvidence' = acceptedTenderlinkEvidence,
      acceptedTenderlinkKnownPeer' = acceptedTenderlinkKnownPeer,
      acceptedTenderlinkStatus' = acceptedTenderlinkStatus,
      acceptedMalachiteProposal' = acceptedMalachiteProposal,
      acceptedMalachiteLiveness' = acceptedMalachiteLiveness,
      acceptedMalachiteSync' = acceptedMalachiteSync,
      acceptedDynamicSigmaConsensusParam' =
        acceptedDynamicSigmaConsensusParam.union(Set(env)),
      acceptedProductionBftBlockProposal' =
        acceptedProductionBftBlockProposal,
      acceptedProductionFatPointerWire' =
        acceptedProductionFatPointerWire,
      ingressFiredAction' = "AcceptDynamicSigmaConsensusParam",
    }

  action AcceptProductionBftBlockProposal(
    env: ProductionEnvelope_t,
  ): bool =
    all {
      ProductionBftBlockProposalRouteValid(env),
      KeepRegistryState,
      acceptedTenderlinkConsensus' = acceptedTenderlinkConsensus,
      acceptedTenderlinkEvidence' = acceptedTenderlinkEvidence,
      acceptedTenderlinkKnownPeer' = acceptedTenderlinkKnownPeer,
      acceptedTenderlinkStatus' = acceptedTenderlinkStatus,
      acceptedMalachiteProposal' = acceptedMalachiteProposal,
      acceptedMalachiteLiveness' = acceptedMalachiteLiveness,
      acceptedMalachiteSync' = acceptedMalachiteSync,
      acceptedDynamicSigmaConsensusParam' =
        acceptedDynamicSigmaConsensusParam,
      acceptedProductionBftBlockProposal' =
        acceptedProductionBftBlockProposal.union(Set(env)),
      acceptedProductionFatPointerWire' =
        acceptedProductionFatPointerWire,
      ingressFiredAction' = "AcceptProductionBftBlockProposal",
    }

  action AcceptProductionFatPointerWire(
    env: ProductionEnvelope_t,
  ): bool =
    all {
      ProductionFatPointerWireRouteValid(env),
      KeepRegistryState,
      acceptedTenderlinkConsensus' = acceptedTenderlinkConsensus,
      acceptedTenderlinkEvidence' = acceptedTenderlinkEvidence,
      acceptedTenderlinkKnownPeer' = acceptedTenderlinkKnownPeer,
      acceptedTenderlinkStatus' = acceptedTenderlinkStatus,
      acceptedMalachiteProposal' = acceptedMalachiteProposal,
      acceptedMalachiteLiveness' = acceptedMalachiteLiveness,
      acceptedMalachiteSync' = acceptedMalachiteSync,
      acceptedDynamicSigmaConsensusParam' =
        acceptedDynamicSigmaConsensusParam,
      acceptedProductionBftBlockProposal' =
        acceptedProductionBftBlockProposal,
      acceptedProductionFatPointerWire' =
        acceptedProductionFatPointerWire.union(Set(env)),
      ingressFiredAction' = "AcceptProductionFatPointerWire",
    }

  action RawAcceptTenderlinkConsensus(env: ProductionEnvelope_t): bool =
    all {
      KeepRegistryState,
      acceptedTenderlinkConsensus' =
        acceptedTenderlinkConsensus.union(Set(env)),
      acceptedTenderlinkEvidence' = acceptedTenderlinkEvidence,
      acceptedTenderlinkKnownPeer' = acceptedTenderlinkKnownPeer,
      acceptedTenderlinkStatus' = acceptedTenderlinkStatus,
      acceptedMalachiteProposal' = acceptedMalachiteProposal,
      acceptedMalachiteLiveness' = acceptedMalachiteLiveness,
      acceptedMalachiteSync' = acceptedMalachiteSync,
      acceptedDynamicSigmaConsensusParam' =
        acceptedDynamicSigmaConsensusParam,
      acceptedProductionBftBlockProposal' =
        acceptedProductionBftBlockProposal,
      acceptedProductionFatPointerWire' =
        acceptedProductionFatPointerWire,
      ingressFiredAction' = "RawAcceptTenderlinkConsensus",
    }

  action RawAcceptMalachiteLiveness(env: ProductionEnvelope_t): bool =
    all {
      KeepRegistryState,
      acceptedTenderlinkConsensus' = acceptedTenderlinkConsensus,
      acceptedTenderlinkEvidence' = acceptedTenderlinkEvidence,
      acceptedTenderlinkKnownPeer' = acceptedTenderlinkKnownPeer,
      acceptedTenderlinkStatus' = acceptedTenderlinkStatus,
      acceptedMalachiteProposal' = acceptedMalachiteProposal,
      acceptedMalachiteLiveness' = acceptedMalachiteLiveness.union(Set(env)),
      acceptedMalachiteSync' = acceptedMalachiteSync,
      acceptedDynamicSigmaConsensusParam' =
        acceptedDynamicSigmaConsensusParam,
      acceptedProductionBftBlockProposal' =
        acceptedProductionBftBlockProposal,
      acceptedProductionFatPointerWire' =
        acceptedProductionFatPointerWire,
      ingressFiredAction' = "RawAcceptMalachiteLiveness",
    }

  action RawAcceptDynamicSigmaConsensusParam(
    env: ProductionEnvelope_t,
  ): bool =
    all {
      KeepRegistryState,
      acceptedTenderlinkConsensus' = acceptedTenderlinkConsensus,
      acceptedTenderlinkEvidence' = acceptedTenderlinkEvidence,
      acceptedTenderlinkKnownPeer' = acceptedTenderlinkKnownPeer,
      acceptedTenderlinkStatus' = acceptedTenderlinkStatus,
      acceptedMalachiteProposal' = acceptedMalachiteProposal,
      acceptedMalachiteLiveness' = acceptedMalachiteLiveness,
      acceptedMalachiteSync' = acceptedMalachiteSync,
      acceptedDynamicSigmaConsensusParam' =
        acceptedDynamicSigmaConsensusParam.union(Set(env)),
      acceptedProductionBftBlockProposal' =
        acceptedProductionBftBlockProposal,
      acceptedProductionFatPointerWire' =
        acceptedProductionFatPointerWire,
      ingressFiredAction' = "RawAcceptDynamicSigmaConsensusParam",
    }

  action RawAcceptProductionBftBlockProposal(
    env: ProductionEnvelope_t,
  ): bool =
    all {
      KeepRegistryState,
      acceptedTenderlinkConsensus' = acceptedTenderlinkConsensus,
      acceptedTenderlinkEvidence' = acceptedTenderlinkEvidence,
      acceptedTenderlinkKnownPeer' = acceptedTenderlinkKnownPeer,
      acceptedTenderlinkStatus' = acceptedTenderlinkStatus,
      acceptedMalachiteProposal' = acceptedMalachiteProposal,
      acceptedMalachiteLiveness' = acceptedMalachiteLiveness,
      acceptedMalachiteSync' = acceptedMalachiteSync,
      acceptedDynamicSigmaConsensusParam' =
        acceptedDynamicSigmaConsensusParam,
      acceptedProductionBftBlockProposal' =
        acceptedProductionBftBlockProposal.union(Set(env)),
      acceptedProductionFatPointerWire' =
        acceptedProductionFatPointerWire,
      ingressFiredAction' = "RawAcceptProductionBftBlockProposal",
    }

  action IngressStutter: bool =
    all {
      KeepRegistryState,
      acceptedTenderlinkConsensus' = acceptedTenderlinkConsensus,
      acceptedTenderlinkEvidence' = acceptedTenderlinkEvidence,
      acceptedTenderlinkKnownPeer' = acceptedTenderlinkKnownPeer,
      acceptedTenderlinkStatus' = acceptedTenderlinkStatus,
      acceptedMalachiteProposal' = acceptedMalachiteProposal,
      acceptedMalachiteLiveness' = acceptedMalachiteLiveness,
      acceptedMalachiteSync' = acceptedMalachiteSync,
      acceptedDynamicSigmaConsensusParam' =
        acceptedDynamicSigmaConsensusParam,
      acceptedProductionBftBlockProposal' =
        acceptedProductionBftBlockProposal,
      acceptedProductionFatPointerWire' =
        acceptedProductionFatPointerWire,
      ingressFiredAction' = ingressFiredAction,
    }
}

module CrosslinkProductionGossipIngressTest {
  import CrosslinkProductionGossipIngress.* from
    "./CrosslinkProductionGossipIngress"
  export CrosslinkProductionGossipIngress.*

  action IngressNext: bool =
    any {
      nondet env = oneOf(TenderlinkConsensusIngressFixtures)
      AcceptTenderlinkConsensus(env),
      nondet env = oneOf(TenderlinkEvidenceIngressFixtures)
      AcceptTenderlinkEvidence(env),
      nondet env = oneOf(TenderlinkKnownPeerIngressFixtures)
      AcceptTenderlinkKnownPeer(env),
      nondet env = oneOf(TenderlinkStatusIngressFixtures)
      AcceptTenderlinkStatus(env),
      nondet env = oneOf(MalachiteProposalIngressFixtures)
      AcceptMalachiteProposal(env),
      nondet env = oneOf(MalachiteLivenessIngressFixtures)
      AcceptMalachiteLiveness(env),
      nondet env = oneOf(MalachiteSyncIngressFixtures)
      AcceptMalachiteSync(env),
      nondet env = oneOf(DynamicSigmaConsensusParamIngressFixtures)
      AcceptDynamicSigmaConsensusParam(env),
      nondet env = oneOf(ProductionBftBlockProposalIngressFixtures)
      AcceptProductionBftBlockProposal(env),
      nondet env = oneOf(ProductionFatPointerWireIngressFixtures)
      AcceptProductionFatPointerWire(env),
      IngressStutter,
    }

  action ingressUnchangedAll: bool =
    all {
      KeepRegistryState,
      acceptedTenderlinkConsensus' = acceptedTenderlinkConsensus,
      acceptedTenderlinkEvidence' = acceptedTenderlinkEvidence,
      acceptedTenderlinkKnownPeer' = acceptedTenderlinkKnownPeer,
      acceptedTenderlinkStatus' = acceptedTenderlinkStatus,
      acceptedMalachiteProposal' = acceptedMalachiteProposal,
      acceptedMalachiteLiveness' = acceptedMalachiteLiveness,
      acceptedMalachiteSync' = acceptedMalachiteSync,
      acceptedDynamicSigmaConsensusParam' =
        acceptedDynamicSigmaConsensusParam,
      acceptedProductionBftBlockProposal' =
        acceptedProductionBftBlockProposal,
      acceptedProductionFatPointerWire' =
        acceptedProductionFatPointerWire,
      ingressFiredAction' = ingressFiredAction,
    }

  run acceptsAllProductionIngressLanesTest = {
    IngressInit
      .then(AcceptTenderlinkConsensus(TenderlinkMixedPrecommitEnvelope))
      .then(AcceptTenderlinkEvidence(TenderlinkEvidenceEnvelope))
      .then(AcceptTenderlinkKnownPeer(TenderlinkKnownPeerEnvelope))
      .then(AcceptTenderlinkStatus(TenderlinkStatusEnvelope))
      .then(AcceptMalachiteProposal(MalachiteSignedProposalEnvelope))
      .then(AcceptMalachiteLiveness(MalachiteRoundEnvelope))
      .then(AcceptMalachiteSync(MalachiteSyncResponseEnvelope))
      .then(AcceptDynamicSigmaConsensusParam(DynamicSigmaConsensusParamEnvelope))
      .then(AcceptDynamicSigmaConsensusParam(
        DynamicSigmaConsensusParamRecoveredEnvelope
      ))
      .then(AcceptProductionBftBlockProposal(ProductionBftBlockProposalEnvelope))
      .then(AcceptProductionFatPointerWire(ProductionFatPointerWireEnvelope))
      .then(all {
        assert(IngressSafety),
        assert(acceptedTenderlinkConsensus.contains(TenderlinkMixedPrecommitEnvelope)),
        assert(acceptedTenderlinkEvidence.contains(TenderlinkEvidenceEnvelope)),
        assert(acceptedTenderlinkKnownPeer.contains(TenderlinkKnownPeerEnvelope)),
        assert(acceptedTenderlinkStatus.contains(TenderlinkStatusEnvelope)),
        assert(acceptedMalachiteProposal.contains(MalachiteSignedProposalEnvelope)),
        assert(acceptedMalachiteLiveness.contains(MalachiteRoundEnvelope)),
        assert(acceptedMalachiteSync.contains(MalachiteSyncResponseEnvelope)),
        assert(
          acceptedDynamicSigmaConsensusParam.contains(
            DynamicSigmaConsensusParamEnvelope
          )
        ),
        assert(
          acceptedDynamicSigmaConsensusParam.contains(
            DynamicSigmaConsensusParamRecoveredEnvelope
          )
        ),
        assert(
          acceptedProductionBftBlockProposal.contains(
            ProductionBftBlockProposalEnvelope
          )
        ),
        assert(
          acceptedProductionFatPointerWire.contains(
            ProductionFatPointerWireEnvelope
          )
        ),
        ingressUnchangedAll,
      })
  }

  run registryValidEvidenceRejectedByConsensusIngressTest = {
    IngressInit
      .then(AcceptTenderlinkConsensus(TenderlinkEvidenceEnvelope))
      .fail()
  }

  run registryValidMalachiteRejectedByTenderlinkIngressTest = {
    IngressInit
      .then(AcceptTenderlinkConsensus(MalachiteSignedProposalEnvelope))
      .fail()
  }

  run registryInvalidCrossProtocolRejectedByIngressTest = {
    IngressInit
      .then(AcceptMalachiteLiveness(TenderlinkPrecommitOnMalachiteLiveness))
      .fail()
  }

  run dynamicSigmaParamRejectedByTenderlinkConsensusIngressTest = {
    IngressInit
      .then(AcceptTenderlinkConsensus(DynamicSigmaConsensusParamEnvelope))
      .fail()
  }

  run tenderlinkPrecommitRejectedByDynamicSigmaParamIngressTest = {
    IngressInit
      .then(AcceptDynamicSigmaConsensusParam(TenderlinkMixedPrecommitEnvelope))
      .fail()
  }

  run malachiteRoundRejectedByDynamicSigmaParamIngressTest = {
    IngressInit
      .then(AcceptDynamicSigmaConsensusParam(MalachiteRoundEnvelope))
      .fail()
  }

  run productionFinalityProposalRejectedByTenderlinkConsensusIngressTest = {
    IngressInit
      .then(AcceptTenderlinkConsensus(ProductionBftBlockProposalEnvelope))
      .fail()
  }

  run productionFinalityFatPointerRejectedByDynamicSigmaParamIngressTest = {
    IngressInit
      .then(AcceptDynamicSigmaConsensusParam(ProductionFatPointerWireEnvelope))
      .fail()
  }

  run tenderlinkPrecommitRejectedByProductionFinalityProposalIngressTest = {
    IngressInit
      .then(AcceptProductionBftBlockProposal(TenderlinkMixedPrecommitEnvelope))
      .fail()
  }

  run rawValidRegistryEnvelopeOnWrongLaneViolatesIngressSafetyTest = {
    IngressInit
      .then(RawAcceptTenderlinkConsensus(TenderlinkEvidenceEnvelope))
      .then(all {
        assert(ProductionRouteValid(TenderlinkEvidenceEnvelope)),
        assert(not(IngressSafety)),
        ingressUnchangedAll,
      })
  }

  run rawDynamicSigmaParamOnTenderlinkConsensusViolatesIngressSafetyTest = {
    IngressInit
      .then(RawAcceptTenderlinkConsensus(DynamicSigmaConsensusParamEnvelope))
      .then(all {
        assert(ProductionRouteValid(DynamicSigmaConsensusParamEnvelope)),
        assert(not(IngressSafety)),
        ingressUnchangedAll,
      })
  }

  run rawTenderlinkPrecommitOnDynamicSigmaParamViolatesIngressSafetyTest = {
    IngressInit
      .then(RawAcceptDynamicSigmaConsensusParam(TenderlinkMixedPrecommitEnvelope))
      .then(all {
        assert(ProductionRouteValid(TenderlinkMixedPrecommitEnvelope)),
        assert(not(IngressSafety)),
        ingressUnchangedAll,
      })
  }

  run rawProductionFinalityProposalOnTenderlinkConsensusViolatesIngressSafetyTest = {
    IngressInit
      .then(RawAcceptTenderlinkConsensus(ProductionBftBlockProposalEnvelope))
      .then(all {
        assert(ProductionRouteValid(ProductionBftBlockProposalEnvelope)),
        assert(not(IngressSafety)),
        ingressUnchangedAll,
      })
  }

  run rawTenderlinkPrecommitOnProductionFinalityProposalViolatesIngressSafetyTest = {
    IngressInit
      .then(RawAcceptProductionBftBlockProposal(TenderlinkMixedPrecommitEnvelope))
      .then(all {
        assert(ProductionRouteValid(TenderlinkMixedPrecommitEnvelope)),
        assert(not(IngressSafety)),
        ingressUnchangedAll,
      })
  }

  run rawCrossProtocolEnvelopeViolatesIngressSafetyTest = {
    IngressInit
      .then(RawAcceptMalachiteLiveness(TenderlinkPrecommitOnMalachiteLiveness))
      .then(all {
        assert(not(ProductionRouteValid(TenderlinkPrecommitOnMalachiteLiveness))),
        assert(not(IngressSafety)),
        ingressUnchangedAll,
      })
  }

  run productionIngressSafetyTest = {
    IngressInit
      .then(all {
        assert(IngressSafety),
        ingressUnchangedAll,
      })
  }
}

module CrosslinkProductionGossipIngressModel {
  import CrosslinkProductionGossipIngressTest.* from
    "./CrosslinkProductionGossipIngress"
  export CrosslinkProductionGossipIngressTest.*
}
