module CrosslinkProductionFinalityIngressProjectionBridge {
  /*
   Production finality ingress/projection bridge.

   CrosslinkProductionFinalityIngressBridge.qnt keeps a scalar projection of
   the production-finality ingress gates for cheap safety and temporal checks.
   This module composes the node-local production ingress machine with the
   richer production-finality projection contract, so the actual projection
   actions for the checked-in BFT-block proposal, Tenderlink-derived precommit
   evidence, and fat-pointer wire can run only after their matching ingress or
   router prerequisites are accepted or recorded.
   */

  import CrosslinkProductionGossipIngress as Ingress from
    "./CrosslinkProductionGossipIngress"
  import CrosslinkProductionFinalityProjectionContractModel as Projection from
    "./CrosslinkProductionFinalityProjectionContract"

  var bridgeProgress: int
  var bridgeFiredAction: str
  var tenderlinkValuePrecommitCertificateRouted: bool

  def ProductionBftBlockProposalIngressAccepted: bool =
    Ingress::acceptedProductionBftBlockProposal.contains(
      Ingress::ProductionBftBlockProposalEnvelope
    )

  def ProductionFatPointerWireIngressAccepted: bool =
    Ingress::acceptedProductionFatPointerWire.contains(
      Ingress::ProductionFatPointerWireEnvelope
    )

  def TenderlinkValuePrecommitCertificateIngressAccepted: bool =
    Ingress::acceptedTenderlinkConsensus.contains(
      Ingress::TenderlinkValuePrecommitCertificateEnvelope
    )

  def IngressProjectionFixtureMetadataCoherent: bool =
    Ingress::ProductionBftBlockProposalFixtureMetadataCoherent and
    Ingress::ProductionFatPointerWireFixtureMetadataCoherent and
    Projection::ProductionBftBlockFixtureConstantsCoherent and
    Projection::ProductionBftBlockProposalEnvelopeValid(
      Projection::FixtureBftBlockProposalEnvelope
    ) and
    Projection::ProductionBftBlockCandidateValid(
      Projection::FixtureProductionBftBlockCandidate
    )

  val ProjectionProposalTransportRequiresIngress =
    if (Projection::ProductionBftBlockProposalTransportObserved) {
      ProductionBftBlockProposalIngressAccepted
    } else {
      true
    }

  val ProjectionCandidateRequiresIngress =
    if (Projection::productionBftBlockObserved) {
      ProductionBftBlockProposalIngressAccepted and
      Projection::ProductionBftBlockProposalTransportObserved
    } else {
      true
    }

  val TenderlinkRouterRecordRequiresIngress =
    if (tenderlinkValuePrecommitCertificateRouted) {
      TenderlinkValuePrecommitCertificateIngressAccepted
    } else {
      true
    }

  val ProjectionPrecommitEvidenceRequiresRouter =
    if (Projection::ProductionPrecommitEvidenceGossiped) {
      tenderlinkValuePrecommitCertificateRouted
    } else {
      true
    }

  val ProjectionFatPointerWireRequiresIngress =
    if (Projection::ProductionFatPointerWireObserved) {
      ProductionFatPointerWireIngressAccepted
    } else {
      true
    }

  val ProjectionFinalityRequiresIngress =
    if (Projection::finalizedProductionBlock) {
      ProductionBftBlockProposalIngressAccepted and
      ProductionFatPointerWireIngressAccepted and
      TenderlinkValuePrecommitCertificateIngressAccepted and
      tenderlinkValuePrecommitCertificateRouted and
      Projection::productionBftBlockObserved and
      Projection::ProductionFatPointerWireObserved and
      Projection::latestFinalizedProductionBlockHash ==
        Projection::FixtureProductionBftBlockCandidate.blockHash
    } else {
      Projection::latestFinalizedProductionBlockHash ==
        Projection::NoFinalizedBlockHash
    }

  val BridgeStateWellFormed =
    bridgeProgress >= 0 and
    bridgeProgress <= 10 and
    Set(
      "Init",
      "AcceptProductionBftBlockProposalIngress",
      "AcceptProductionFatPointerWireIngress",
      "AcceptTenderlinkValuePrecommitCertificateIngress",
      "RouteTenderlinkValuePrecommitCertificateAfterIngress",
      "GossipProductionBftBlockProposalAfterIngress",
      "ObserveProductionBftBlockCandidateAfterIngress",
      "GossipProductionPrecommitEvidence",
      "GossipProductionFatPointerWireAfterIngress",
      "ObserveProductionFatPointerWireAfterIngress",
      "FinalizeProductionBlockAfterIngressProjection",
      "RawGossipProductionBftBlockProposalWithoutIngress",
      "RawGossipProductionFatPointerWireWithoutIngress",
      "RawObserveProductionFatPointerWireWithoutIngress",
      "RawRouteTenderlinkValuePrecommitCertificateWithoutIngress",
    ).contains(bridgeFiredAction)

  val IngressProjectionBridgeSafety =
    Ingress::IngressSafety and
    Projection::ProductionFinalitySafety and
    IngressProjectionFixtureMetadataCoherent and
    BridgeStateWellFormed and
    ProjectionProposalTransportRequiresIngress and
    ProjectionCandidateRequiresIngress and
    TenderlinkRouterRecordRequiresIngress and
    ProjectionPrecommitEvidenceRequiresRouter and
    ProjectionFatPointerWireRequiresIngress and
    ProjectionFinalityRequiresIngress

  action Init = all {
    Ingress::IngressInit,
    Projection::Init,
    tenderlinkValuePrecommitCertificateRouted' = false,
    bridgeProgress' = 0,
    bridgeFiredAction' = "Init",
  }

  action KeepBridgeState = all {
    tenderlinkValuePrecommitCertificateRouted' =
      tenderlinkValuePrecommitCertificateRouted,
    bridgeProgress' = bridgeProgress,
    bridgeFiredAction' = bridgeFiredAction,
  }

  action AcceptProductionBftBlockProposalIngress: bool =
    all {
      not(ProductionBftBlockProposalIngressAccepted),
      Ingress::AcceptProductionBftBlockProposal(
        Ingress::ProductionBftBlockProposalEnvelope
      ),
      Projection::Unchanged,
      tenderlinkValuePrecommitCertificateRouted' =
        tenderlinkValuePrecommitCertificateRouted,
      bridgeProgress' = bridgeProgress + 1,
      bridgeFiredAction' = "AcceptProductionBftBlockProposalIngress",
    }

  action AcceptProductionFatPointerWireIngress: bool =
    all {
      not(ProductionFatPointerWireIngressAccepted),
      Ingress::AcceptProductionFatPointerWire(
        Ingress::ProductionFatPointerWireEnvelope
      ),
      Projection::Unchanged,
      tenderlinkValuePrecommitCertificateRouted' =
        tenderlinkValuePrecommitCertificateRouted,
      bridgeProgress' = bridgeProgress + 1,
      bridgeFiredAction' = "AcceptProductionFatPointerWireIngress",
    }

  action AcceptTenderlinkValuePrecommitCertificateIngress: bool =
    all {
      not(TenderlinkValuePrecommitCertificateIngressAccepted),
      Ingress::AcceptTenderlinkConsensus(
        Ingress::TenderlinkValuePrecommitCertificateEnvelope
      ),
      Projection::Unchanged,
      tenderlinkValuePrecommitCertificateRouted' =
        tenderlinkValuePrecommitCertificateRouted,
      bridgeProgress' = bridgeProgress + 1,
      bridgeFiredAction' = "AcceptTenderlinkValuePrecommitCertificateIngress",
    }

  action RouteTenderlinkValuePrecommitCertificateAfterIngress: bool =
    all {
      TenderlinkValuePrecommitCertificateIngressAccepted,
      not(tenderlinkValuePrecommitCertificateRouted),
      Ingress::IngressStutter,
      Projection::Unchanged,
      tenderlinkValuePrecommitCertificateRouted' = true,
      bridgeProgress' = bridgeProgress + 1,
      bridgeFiredAction' =
        "RouteTenderlinkValuePrecommitCertificateAfterIngress",
    }

  action AttemptTenderlinkPrecommitAsProductionBftBlockProposalIngress: bool =
    all {
      Ingress::AcceptProductionBftBlockProposal(
        Ingress::TenderlinkMixedPrecommitEnvelope
      ),
      Projection::Unchanged,
      tenderlinkValuePrecommitCertificateRouted' =
        tenderlinkValuePrecommitCertificateRouted,
      bridgeProgress' = bridgeProgress + 1,
      bridgeFiredAction' = "AcceptProductionBftBlockProposalIngress",
    }

  action GossipProductionBftBlockProposalAfterIngress: bool =
    all {
      ProductionBftBlockProposalIngressAccepted,
      not(Projection::ProductionBftBlockProposalTransportObserved),
      Ingress::IngressStutter,
      Projection::GossipFixtureBftBlockProposalForFinality(
        Projection::FixtureBftBlockProposalEnvelope
      ),
      tenderlinkValuePrecommitCertificateRouted' =
        tenderlinkValuePrecommitCertificateRouted,
      bridgeProgress' = bridgeProgress + 1,
      bridgeFiredAction' = "GossipProductionBftBlockProposalAfterIngress",
    }

  action ObserveProductionBftBlockCandidateAfterIngress: bool =
    all {
      ProductionBftBlockProposalIngressAccepted,
      not(Projection::productionBftBlockObserved),
      Ingress::IngressStutter,
      Projection::ObserveProductionBftBlockCandidate(
        Projection::FixtureProductionBftBlockCandidate
      ),
      tenderlinkValuePrecommitCertificateRouted' =
        tenderlinkValuePrecommitCertificateRouted,
      bridgeProgress' = bridgeProgress + 1,
      bridgeFiredAction' = "ObserveProductionBftBlockCandidateAfterIngress",
    }

  action GossipProductionPrecommitEvidence: bool =
    all {
      tenderlinkValuePrecommitCertificateRouted,
      Ingress::IngressStutter,
      Projection::GossipFixturePrecommitForFinality,
      tenderlinkValuePrecommitCertificateRouted' =
        tenderlinkValuePrecommitCertificateRouted,
      bridgeProgress' = bridgeProgress + 1,
      bridgeFiredAction' = "GossipProductionPrecommitEvidence",
    }

  action GossipProductionFatPointerWireAfterIngress: bool =
    all {
      ProductionFatPointerWireIngressAccepted,
      Ingress::IngressStutter,
      Projection::GossipFixtureFatPointerWireForFinality,
      tenderlinkValuePrecommitCertificateRouted' =
        tenderlinkValuePrecommitCertificateRouted,
      bridgeProgress' = bridgeProgress + 1,
      bridgeFiredAction' = "GossipProductionFatPointerWireAfterIngress",
    }

  action ObserveProductionFatPointerWireAfterIngress: bool =
    all {
      ProductionFatPointerWireIngressAccepted,
      not(Projection::ProductionFatPointerWireObserved),
      Ingress::IngressStutter,
      Projection::ObserveFixtureFatPointerWireForFinality,
      tenderlinkValuePrecommitCertificateRouted' =
        tenderlinkValuePrecommitCertificateRouted,
      bridgeProgress' = bridgeProgress + 1,
      bridgeFiredAction' = "ObserveProductionFatPointerWireAfterIngress",
    }

  action FinalizeProductionBlockAfterIngressProjection: bool =
    all {
      ProductionBftBlockProposalIngressAccepted,
      ProductionFatPointerWireIngressAccepted,
      tenderlinkValuePrecommitCertificateRouted,
      not(Projection::finalizedProductionBlock),
      Ingress::IngressStutter,
      Projection::FinalizeProductionBftBlock(
        Projection::FixtureProductionBftBlockCandidate
      ),
      tenderlinkValuePrecommitCertificateRouted' =
        tenderlinkValuePrecommitCertificateRouted,
      bridgeProgress' = bridgeProgress + 1,
      bridgeFiredAction' = "FinalizeProductionBlockAfterIngressProjection",
    }

  action RawGossipProductionBftBlockProposalWithoutIngress: bool =
    all {
      not(ProductionBftBlockProposalIngressAccepted),
      Ingress::IngressStutter,
      Projection::GossipFixtureBftBlockProposalForFinality(
        Projection::FixtureBftBlockProposalEnvelope
      ),
      tenderlinkValuePrecommitCertificateRouted' =
        tenderlinkValuePrecommitCertificateRouted,
      bridgeProgress' = bridgeProgress + 1,
      bridgeFiredAction' = "RawGossipProductionBftBlockProposalWithoutIngress",
    }

  action RawGossipProductionFatPointerWireWithoutIngress: bool =
    all {
      not(ProductionFatPointerWireIngressAccepted),
      Ingress::IngressStutter,
      Projection::GossipFixtureFatPointerWireForFinality,
      tenderlinkValuePrecommitCertificateRouted' =
        tenderlinkValuePrecommitCertificateRouted,
      bridgeProgress' = bridgeProgress + 1,
      bridgeFiredAction' = "RawGossipProductionFatPointerWireWithoutIngress",
    }

  action RawObserveProductionFatPointerWireWithoutIngress: bool =
    all {
      not(ProductionFatPointerWireIngressAccepted),
      Ingress::IngressStutter,
      Projection::ObserveFixtureFatPointerWireForFinality,
      tenderlinkValuePrecommitCertificateRouted' =
        tenderlinkValuePrecommitCertificateRouted,
      bridgeProgress' = bridgeProgress + 1,
      bridgeFiredAction' = "RawObserveProductionFatPointerWireWithoutIngress",
    }

  action RawRouteTenderlinkValuePrecommitCertificateWithoutIngress: bool =
    all {
      not(tenderlinkValuePrecommitCertificateRouted),
      Ingress::IngressStutter,
      Projection::Unchanged,
      tenderlinkValuePrecommitCertificateRouted' = true,
      bridgeProgress' = bridgeProgress + 1,
      bridgeFiredAction' =
        "RawRouteTenderlinkValuePrecommitCertificateWithoutIngress",
    }

  action Stutter: bool =
    all {
      Ingress::IngressStutter,
      Projection::Unchanged,
      KeepBridgeState,
    }

  action Next: bool =
    any {
      AcceptProductionBftBlockProposalIngress,
      AcceptProductionFatPointerWireIngress,
      AcceptTenderlinkValuePrecommitCertificateIngress,
      RouteTenderlinkValuePrecommitCertificateAfterIngress,
      GossipProductionBftBlockProposalAfterIngress,
      ObserveProductionBftBlockCandidateAfterIngress,
      GossipProductionPrecommitEvidence,
      GossipProductionFatPointerWireAfterIngress,
      ObserveProductionFatPointerWireAfterIngress,
      FinalizeProductionBlockAfterIngressProjection,
      Stutter,
    }

  temporal EventuallyIngressProjectionFinalizes =
    Next.weakFair(Set(bridgeProgress)).implies(eventually(
      ProductionBftBlockProposalIngressAccepted and
      ProductionFatPointerWireIngressAccepted and
      TenderlinkValuePrecommitCertificateIngressAccepted and
      tenderlinkValuePrecommitCertificateRouted and
      Projection::productionBftBlockObserved and
      Projection::ProductionFatPointerWireObserved and
      Projection::finalizedProductionBlock and
      Projection::latestFinalizedProductionBlockHash ==
        Projection::FixtureProductionBftBlockCandidate.blockHash
    ))

  run ingressProjectionBridgeCompletesProductionFinalityTest = {
    Init
      .then(AcceptProductionBftBlockProposalIngress)
      .then(GossipProductionBftBlockProposalAfterIngress)
      .then(ObserveProductionBftBlockCandidateAfterIngress)
      .then(AcceptTenderlinkValuePrecommitCertificateIngress)
      .then(RouteTenderlinkValuePrecommitCertificateAfterIngress)
      .then(GossipProductionPrecommitEvidence)
      .then(AcceptProductionFatPointerWireIngress)
      .then(GossipProductionFatPointerWireAfterIngress)
      .then(ObserveProductionFatPointerWireAfterIngress)
      .then(FinalizeProductionBlockAfterIngressProjection)
      .then(all {
        assert(Projection::finalizedProductionBlock),
        assert(
          Projection::latestFinalizedProductionBlockHash ==
            Projection::FixtureProductionBftBlockCandidate.blockHash
        ),
        assert(ProductionBftBlockProposalIngressAccepted),
        assert(ProductionFatPointerWireIngressAccepted),
        assert(tenderlinkValuePrecommitCertificateRouted),
        assert(Projection::ProductionFinalitySafety),
        assert(IngressProjectionBridgeSafety),
        Stutter,
      })
  }

  run precommitEvidenceRequiresTenderlinkRouterTest = {
    Init
      .then(GossipProductionPrecommitEvidence)
      .fail()
  }

  run tenderlinkRouterRequiresTenderlinkIngressTest = {
    Init
      .then(RouteTenderlinkValuePrecommitCertificateAfterIngress)
      .fail()
  }

  run projectionProposalRequiresProductionIngressTest = {
    Init
      .then(GossipProductionBftBlockProposalAfterIngress)
      .fail()
  }

  run projectionCandidateRequiresProductionIngressTest = {
    Init
      .then(RawGossipProductionBftBlockProposalWithoutIngress)
      .then(ObserveProductionBftBlockCandidateAfterIngress)
      .fail()
  }

  run rawProjectionProposalWithoutIngressViolatesBridgeSafetyTest = {
    Init
      .then(RawGossipProductionBftBlockProposalWithoutIngress)
      .then(all {
        assert(Projection::ProductionBftBlockProposalTransportObserved),
        assert(not(ProductionBftBlockProposalIngressAccepted)),
        assert(not(IngressProjectionBridgeSafety)),
        Stutter,
      })
  }

  run fatPointerWireProjectionRequiresProductionIngressTest = {
    Init
      .then(AcceptTenderlinkValuePrecommitCertificateIngress)
      .then(RouteTenderlinkValuePrecommitCertificateAfterIngress)
      .then(GossipProductionPrecommitEvidence)
      .then(GossipProductionFatPointerWireAfterIngress)
      .fail()
  }

  run rawObservedFatPointerWireWithoutIngressViolatesBridgeSafetyTest = {
    Init
      .then(AcceptTenderlinkValuePrecommitCertificateIngress)
      .then(RouteTenderlinkValuePrecommitCertificateAfterIngress)
      .then(GossipProductionPrecommitEvidence)
      .then(RawGossipProductionFatPointerWireWithoutIngress)
      .then(RawObserveProductionFatPointerWireWithoutIngress)
      .then(all {
        assert(Projection::ProductionFatPointerWireObserved),
        assert(not(ProductionFatPointerWireIngressAccepted)),
        assert(not(IngressProjectionBridgeSafety)),
        Stutter,
      })
  }

  run finalityRequiresBothProductionIngressLanesTest = {
    Init
      .then(AcceptProductionBftBlockProposalIngress)
      .then(GossipProductionBftBlockProposalAfterIngress)
      .then(ObserveProductionBftBlockCandidateAfterIngress)
      .then(AcceptTenderlinkValuePrecommitCertificateIngress)
      .then(RouteTenderlinkValuePrecommitCertificateAfterIngress)
      .then(GossipProductionPrecommitEvidence)
      .then(RawGossipProductionFatPointerWireWithoutIngress)
      .then(RawObserveProductionFatPointerWireWithoutIngress)
      .then(FinalizeProductionBlockAfterIngressProjection)
      .fail()
  }

  run tenderlinkPrecommitCannotSatisfyProjectionProposalIngressTest = {
    Init
      .then(AttemptTenderlinkPrecommitAsProductionBftBlockProposalIngress)
      .fail()
  }

  run rawTenderlinkRouterWithoutIngressViolatesBridgeSafetyTest = {
    Init
      .then(RawRouteTenderlinkValuePrecommitCertificateWithoutIngress)
      .then(all {
        assert(not(TenderlinkValuePrecommitCertificateIngressAccepted)),
        assert(tenderlinkValuePrecommitCertificateRouted),
        assert(not(IngressProjectionBridgeSafety)),
        Stutter,
      })
  }

  run ingressProjectionBridgeSafetyInitialTest = {
    Init
      .then(all {
        assert(IngressProjectionFixtureMetadataCoherent),
        assert(IngressProjectionBridgeSafety),
        Stutter,
      })
  }
}

module CrosslinkProductionFinalityIngressProjectionBridgeModel {
  import CrosslinkProductionFinalityIngressProjectionBridge.* from
    "./CrosslinkProductionFinalityIngressProjectionBridge"
  export CrosslinkProductionFinalityIngressProjectionBridge.*
}
