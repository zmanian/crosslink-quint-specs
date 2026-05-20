module CrosslinkProductionFinalityIngressProjectionBridge {
  /*
   Production finality ingress/projection bridge.

   CrosslinkProductionFinalityIngressBridge.qnt keeps a scalar projection of
   the production-finality ingress gates for cheap safety and temporal checks.
   This module composes the node-local production ingress machine with the
   richer production-finality projection contract, so the actual projection
   actions for the checked-in BFT-block proposal and fat-pointer wire can run
   only after their matching production-finality ingress records are accepted.
   */

  import CrosslinkProductionGossipIngress as Ingress from
    "./CrosslinkProductionGossipIngress"
  import CrosslinkProductionFinalityProjectionContractModel as Projection from
    "./CrosslinkProductionFinalityProjectionContract"

  var bridgeProgress: int
  var bridgeFiredAction: str

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

  val ProjectionPrecommitEvidenceRequiresIngress =
    if (Projection::ProductionPrecommitEvidenceGossiped) {
      TenderlinkValuePrecommitCertificateIngressAccepted
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
    bridgeProgress <= 9 and
    Set(
      "Init",
      "AcceptProductionBftBlockProposalIngress",
      "AcceptProductionFatPointerWireIngress",
      "AcceptTenderlinkValuePrecommitCertificateIngress",
      "GossipProductionBftBlockProposalAfterIngress",
      "ObserveProductionBftBlockCandidateAfterIngress",
      "GossipProductionPrecommitEvidence",
      "GossipProductionFatPointerWireAfterIngress",
      "ObserveProductionFatPointerWireAfterIngress",
      "FinalizeProductionBlockAfterIngressProjection",
      "RawGossipProductionBftBlockProposalWithoutIngress",
      "RawGossipProductionFatPointerWireWithoutIngress",
      "RawObserveProductionFatPointerWireWithoutIngress",
    ).contains(bridgeFiredAction)

  val IngressProjectionBridgeSafety =
    Ingress::IngressSafety and
    Projection::ProductionFinalitySafety and
    IngressProjectionFixtureMetadataCoherent and
    BridgeStateWellFormed and
    ProjectionProposalTransportRequiresIngress and
    ProjectionCandidateRequiresIngress and
    ProjectionPrecommitEvidenceRequiresIngress and
    ProjectionFatPointerWireRequiresIngress and
    ProjectionFinalityRequiresIngress

  action Init = all {
    Ingress::IngressInit,
    Projection::Init,
    bridgeProgress' = 0,
    bridgeFiredAction' = "Init",
  }

  action KeepBridgeState = all {
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
      bridgeProgress' = bridgeProgress + 1,
      bridgeFiredAction' = "AcceptTenderlinkValuePrecommitCertificateIngress",
    }

  action AttemptTenderlinkPrecommitAsProductionBftBlockProposalIngress: bool =
    all {
      Ingress::AcceptProductionBftBlockProposal(
        Ingress::TenderlinkMixedPrecommitEnvelope
      ),
      Projection::Unchanged,
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
      bridgeProgress' = bridgeProgress + 1,
      bridgeFiredAction' = "ObserveProductionBftBlockCandidateAfterIngress",
    }

  action GossipProductionPrecommitEvidence: bool =
    all {
      TenderlinkValuePrecommitCertificateIngressAccepted,
      Ingress::IngressStutter,
      Projection::GossipFixturePrecommitForFinality,
      bridgeProgress' = bridgeProgress + 1,
      bridgeFiredAction' = "GossipProductionPrecommitEvidence",
    }

  action GossipProductionFatPointerWireAfterIngress: bool =
    all {
      ProductionFatPointerWireIngressAccepted,
      Ingress::IngressStutter,
      Projection::GossipFixtureFatPointerWireForFinality,
      bridgeProgress' = bridgeProgress + 1,
      bridgeFiredAction' = "GossipProductionFatPointerWireAfterIngress",
    }

  action ObserveProductionFatPointerWireAfterIngress: bool =
    all {
      ProductionFatPointerWireIngressAccepted,
      not(Projection::ProductionFatPointerWireObserved),
      Ingress::IngressStutter,
      Projection::ObserveFixtureFatPointerWireForFinality,
      bridgeProgress' = bridgeProgress + 1,
      bridgeFiredAction' = "ObserveProductionFatPointerWireAfterIngress",
    }

  action FinalizeProductionBlockAfterIngressProjection: bool =
    all {
      ProductionBftBlockProposalIngressAccepted,
      ProductionFatPointerWireIngressAccepted,
      not(Projection::finalizedProductionBlock),
      Ingress::IngressStutter,
      Projection::FinalizeProductionBftBlock(
        Projection::FixtureProductionBftBlockCandidate
      ),
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
      bridgeProgress' = bridgeProgress + 1,
      bridgeFiredAction' = "RawGossipProductionBftBlockProposalWithoutIngress",
    }

  action RawGossipProductionFatPointerWireWithoutIngress: bool =
    all {
      not(ProductionFatPointerWireIngressAccepted),
      Ingress::IngressStutter,
      Projection::GossipFixtureFatPointerWireForFinality,
      bridgeProgress' = bridgeProgress + 1,
      bridgeFiredAction' = "RawGossipProductionFatPointerWireWithoutIngress",
    }

  action RawObserveProductionFatPointerWireWithoutIngress: bool =
    all {
      not(ProductionFatPointerWireIngressAccepted),
      Ingress::IngressStutter,
      Projection::ObserveFixtureFatPointerWireForFinality,
      bridgeProgress' = bridgeProgress + 1,
      bridgeFiredAction' = "RawObserveProductionFatPointerWireWithoutIngress",
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
        assert(Projection::ProductionFinalitySafety),
        assert(IngressProjectionBridgeSafety),
        Stutter,
      })
  }

  run precommitEvidenceRequiresTenderlinkIngressTest = {
    Init
      .then(GossipProductionPrecommitEvidence)
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
      .then(GossipProductionPrecommitEvidence)
      .then(GossipProductionFatPointerWireAfterIngress)
      .fail()
  }

  run rawObservedFatPointerWireWithoutIngressViolatesBridgeSafetyTest = {
    Init
      .then(AcceptTenderlinkValuePrecommitCertificateIngress)
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
