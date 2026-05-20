module CrosslinkProductionFinalityIngressBridge {
  /*
   Production finality ingress bridge.

   CrosslinkProductionGossipIngress.qnt proves that production-finality
   proposal and fat-pointer records enter their own node-local lanes.
   CrosslinkProductionFinalityProjectionContract.qnt proves that finality waits
   for a production-shaped BFT-block proposal, precommit evidence, and
   transported fat-pointer evidence. This bridge joins those two boundaries in
   a verifier-friendly scalar graph: the finality projection cannot observe the
   fixture proposal, precommit evidence, or fat-pointer wire until the matching
   production ingress/router prerequisite has accepted or recorded the
   registry-valid prerequisite.
   */

  import CrosslinkProductionGossipIngress.* from
    "./CrosslinkProductionGossipIngress"
  export CrosslinkProductionGossipIngress.*

  pure val FixtureBlockHash = "fixture-bft-block"
  pure val NoFinalizedBlockHash = "none"

  var productionBftBlockProjectionReady: bool
  var productionPrecommitEvidenceProjectionReady: bool
  var tenderlinkValuePrecommitCertificateRouted: bool
  var productionFatPointerWireProjectionReady: bool
  var finalizedProductionBlockFromIngress: bool
  var latestFinalizedProductionBlockHash: str
  var bridgeProgress: int
  var bridgeFiredAction: str

  def ProductionBftBlockProposalIngressAccepted: bool =
    acceptedProductionBftBlockProposal.contains(
      ProductionBftBlockProposalEnvelope
    )

  def ProductionFatPointerWireIngressAccepted: bool =
    acceptedProductionFatPointerWire.contains(
      ProductionFatPointerWireEnvelope
    )

  def TenderlinkValuePrecommitCertificateIngressAccepted: bool =
    acceptedTenderlinkConsensus.contains(
      TenderlinkValuePrecommitCertificateEnvelope
    )

  def ProductionFinalityIngressMetadataCoherent: bool =
    ProductionBftBlockProposalFixtureMetadataCoherent and
    ProductionFatPointerWireFixtureMetadataCoherent

  val ProjectionProposalRequiresIngress =
    if (productionBftBlockProjectionReady) {
      ProductionBftBlockProposalIngressAccepted
    } else {
      true
    }

  val ProjectionFatPointerWireRequiresIngress =
    if (productionFatPointerWireProjectionReady) {
      ProductionFatPointerWireIngressAccepted and
      productionPrecommitEvidenceProjectionReady
    } else {
      true
    }

  val TenderlinkRouterRecordRequiresIngress =
    if (tenderlinkValuePrecommitCertificateRouted) {
      TenderlinkValuePrecommitCertificateIngressAccepted
    } else {
      true
    }

  val ProjectionPrecommitEvidenceRequiresTenderlinkRouter =
    if (productionPrecommitEvidenceProjectionReady) {
      tenderlinkValuePrecommitCertificateRouted
    } else {
      true
    }

  val FinalityRequiresIngressProjection =
    if (finalizedProductionBlockFromIngress) {
      productionBftBlockProjectionReady and
      productionPrecommitEvidenceProjectionReady and
      productionFatPointerWireProjectionReady and
      ProductionBftBlockProposalIngressAccepted and
      TenderlinkValuePrecommitCertificateIngressAccepted and
      tenderlinkValuePrecommitCertificateRouted and
      ProductionFatPointerWireIngressAccepted and
      latestFinalizedProductionBlockHash == FixtureBlockHash
    } else {
      latestFinalizedProductionBlockHash == NoFinalizedBlockHash
    }

  val BridgeStateWellFormed =
    bridgeProgress >= 0 and
    bridgeProgress <= 8 and
    Set(
      "BridgeInit",
      "AcceptProductionBftBlockProposalIngress",
      "AcceptTenderlinkValuePrecommitCertificateIngress",
      "RouteTenderlinkValuePrecommitCertificateAfterIngress",
      "AcceptProductionFatPointerWireIngress",
      "ProjectProductionBftBlockProposalAfterIngress",
      "ProjectProductionPrecommitEvidenceAfterTenderlinkRouter",
      "ProjectProductionFatPointerWireAfterIngress",
      "FinalizeProductionBlockAfterIngress",
      "RawProjectProductionBftBlockProposal",
      "RawRouteTenderlinkValuePrecommitCertificate",
      "RawProjectProductionPrecommitEvidence",
      "RawProjectProductionFatPointerWire",
      "RawFinalizeProductionBlockFromIngress",
    ).contains(bridgeFiredAction)

  val FinalityIngressBridgeSafety =
    IngressSafety and
    ProductionFinalityIngressMetadataCoherent and
    BridgeStateWellFormed and
    ProjectionProposalRequiresIngress and
    TenderlinkRouterRecordRequiresIngress and
    ProjectionPrecommitEvidenceRequiresTenderlinkRouter and
    ProjectionFatPointerWireRequiresIngress and
    FinalityRequiresIngressProjection

  action BridgeInit = all {
    IngressInit,
    productionBftBlockProjectionReady' = false,
    productionPrecommitEvidenceProjectionReady' = false,
    tenderlinkValuePrecommitCertificateRouted' = false,
    productionFatPointerWireProjectionReady' = false,
    finalizedProductionBlockFromIngress' = false,
    latestFinalizedProductionBlockHash' = NoFinalizedBlockHash,
    bridgeProgress' = 0,
    bridgeFiredAction' = "BridgeInit",
  }

  action KeepBridgeState = all {
    productionBftBlockProjectionReady' = productionBftBlockProjectionReady,
    productionPrecommitEvidenceProjectionReady' =
      productionPrecommitEvidenceProjectionReady,
    tenderlinkValuePrecommitCertificateRouted' =
      tenderlinkValuePrecommitCertificateRouted,
    productionFatPointerWireProjectionReady' =
      productionFatPointerWireProjectionReady,
    finalizedProductionBlockFromIngress' = finalizedProductionBlockFromIngress,
    latestFinalizedProductionBlockHash' = latestFinalizedProductionBlockHash,
    bridgeProgress' = bridgeProgress,
    bridgeFiredAction' = bridgeFiredAction,
  }

  action KeepBridgeProjectionState = all {
    productionBftBlockProjectionReady' = productionBftBlockProjectionReady,
    productionPrecommitEvidenceProjectionReady' =
      productionPrecommitEvidenceProjectionReady,
    tenderlinkValuePrecommitCertificateRouted' =
      tenderlinkValuePrecommitCertificateRouted,
    productionFatPointerWireProjectionReady' =
      productionFatPointerWireProjectionReady,
    finalizedProductionBlockFromIngress' = finalizedProductionBlockFromIngress,
    latestFinalizedProductionBlockHash' = latestFinalizedProductionBlockHash,
  }

  action AcceptProductionBftBlockProposalIngress: bool =
    all {
      not(ProductionBftBlockProposalIngressAccepted),
      AcceptProductionBftBlockProposal(ProductionBftBlockProposalEnvelope),
      KeepBridgeProjectionState,
      bridgeProgress' = bridgeProgress + 1,
      bridgeFiredAction' = "AcceptProductionBftBlockProposalIngress",
    }

  action AcceptTenderlinkValuePrecommitCertificateIngress: bool =
    all {
      not(TenderlinkValuePrecommitCertificateIngressAccepted),
      AcceptTenderlinkConsensus(TenderlinkValuePrecommitCertificateEnvelope),
      KeepBridgeProjectionState,
      bridgeProgress' = bridgeProgress + 1,
      bridgeFiredAction' = "AcceptTenderlinkValuePrecommitCertificateIngress",
    }

  action AcceptProductionFatPointerWireIngress: bool =
    all {
      not(ProductionFatPointerWireIngressAccepted),
      AcceptProductionFatPointerWire(ProductionFatPointerWireEnvelope),
      KeepBridgeProjectionState,
      bridgeProgress' = bridgeProgress + 1,
      bridgeFiredAction' = "AcceptProductionFatPointerWireIngress",
    }

  action RouteTenderlinkValuePrecommitCertificateAfterIngress: bool =
    all {
      TenderlinkValuePrecommitCertificateIngressAccepted,
      not(tenderlinkValuePrecommitCertificateRouted),
      IngressStutter,
      productionBftBlockProjectionReady' = productionBftBlockProjectionReady,
      productionPrecommitEvidenceProjectionReady' =
        productionPrecommitEvidenceProjectionReady,
      tenderlinkValuePrecommitCertificateRouted' = true,
      productionFatPointerWireProjectionReady' =
        productionFatPointerWireProjectionReady,
      finalizedProductionBlockFromIngress' = finalizedProductionBlockFromIngress,
      latestFinalizedProductionBlockHash' = latestFinalizedProductionBlockHash,
      bridgeProgress' = bridgeProgress + 1,
      bridgeFiredAction' =
        "RouteTenderlinkValuePrecommitCertificateAfterIngress",
    }

  action AttemptTenderlinkPrecommitAsProductionBftBlockProposalIngress: bool =
    all {
      AcceptProductionBftBlockProposal(TenderlinkMixedPrecommitEnvelope),
      KeepBridgeProjectionState,
      bridgeProgress' = bridgeProgress + 1,
      bridgeFiredAction' = "AcceptProductionBftBlockProposalIngress",
    }

  action ProjectProductionBftBlockProposalAfterIngress: bool =
    all {
      ProductionBftBlockProposalIngressAccepted,
      not(productionBftBlockProjectionReady),
      IngressStutter,
      productionBftBlockProjectionReady' = true,
      productionPrecommitEvidenceProjectionReady' =
        productionPrecommitEvidenceProjectionReady,
      tenderlinkValuePrecommitCertificateRouted' =
        tenderlinkValuePrecommitCertificateRouted,
      productionFatPointerWireProjectionReady' =
        productionFatPointerWireProjectionReady,
      finalizedProductionBlockFromIngress' = finalizedProductionBlockFromIngress,
      latestFinalizedProductionBlockHash' = latestFinalizedProductionBlockHash,
      bridgeProgress' = bridgeProgress + 1,
      bridgeFiredAction' = "ProjectProductionBftBlockProposalAfterIngress",
    }

  action ProjectProductionPrecommitEvidenceAfterTenderlinkRouter: bool =
    all {
      tenderlinkValuePrecommitCertificateRouted,
      not(productionPrecommitEvidenceProjectionReady),
      IngressStutter,
      productionBftBlockProjectionReady' = productionBftBlockProjectionReady,
      productionPrecommitEvidenceProjectionReady' = true,
      tenderlinkValuePrecommitCertificateRouted' =
        tenderlinkValuePrecommitCertificateRouted,
      productionFatPointerWireProjectionReady' =
        productionFatPointerWireProjectionReady,
      finalizedProductionBlockFromIngress' = finalizedProductionBlockFromIngress,
      latestFinalizedProductionBlockHash' = latestFinalizedProductionBlockHash,
      bridgeProgress' = bridgeProgress + 1,
      bridgeFiredAction' =
        "ProjectProductionPrecommitEvidenceAfterTenderlinkRouter",
    }

  action ProjectProductionFatPointerWireAfterIngress: bool =
    all {
      ProductionFatPointerWireIngressAccepted,
      productionPrecommitEvidenceProjectionReady,
      not(productionFatPointerWireProjectionReady),
      IngressStutter,
      productionBftBlockProjectionReady' = productionBftBlockProjectionReady,
      productionPrecommitEvidenceProjectionReady' =
        productionPrecommitEvidenceProjectionReady,
      tenderlinkValuePrecommitCertificateRouted' =
        tenderlinkValuePrecommitCertificateRouted,
      productionFatPointerWireProjectionReady' = true,
      finalizedProductionBlockFromIngress' = finalizedProductionBlockFromIngress,
      latestFinalizedProductionBlockHash' = latestFinalizedProductionBlockHash,
      bridgeProgress' = bridgeProgress + 1,
      bridgeFiredAction' = "ProjectProductionFatPointerWireAfterIngress",
    }

  action FinalizeProductionBlockAfterIngress: bool =
    all {
      productionBftBlockProjectionReady,
      productionPrecommitEvidenceProjectionReady,
      productionFatPointerWireProjectionReady,
      not(finalizedProductionBlockFromIngress),
      IngressStutter,
      productionBftBlockProjectionReady' = productionBftBlockProjectionReady,
      productionPrecommitEvidenceProjectionReady' =
        productionPrecommitEvidenceProjectionReady,
      tenderlinkValuePrecommitCertificateRouted' =
        tenderlinkValuePrecommitCertificateRouted,
      productionFatPointerWireProjectionReady' =
        productionFatPointerWireProjectionReady,
      finalizedProductionBlockFromIngress' = true,
      latestFinalizedProductionBlockHash' = FixtureBlockHash,
      bridgeProgress' = bridgeProgress + 1,
      bridgeFiredAction' = "FinalizeProductionBlockAfterIngress",
    }

  action RawProjectProductionBftBlockProposal: bool =
    all {
      not(productionBftBlockProjectionReady),
      IngressStutter,
      productionBftBlockProjectionReady' = true,
      productionPrecommitEvidenceProjectionReady' =
        productionPrecommitEvidenceProjectionReady,
      tenderlinkValuePrecommitCertificateRouted' =
        tenderlinkValuePrecommitCertificateRouted,
      productionFatPointerWireProjectionReady' =
        productionFatPointerWireProjectionReady,
      finalizedProductionBlockFromIngress' = finalizedProductionBlockFromIngress,
      latestFinalizedProductionBlockHash' = latestFinalizedProductionBlockHash,
      bridgeProgress' = bridgeProgress + 1,
      bridgeFiredAction' = "RawProjectProductionBftBlockProposal",
    }

  action RawProjectProductionPrecommitEvidence: bool =
    all {
      not(productionPrecommitEvidenceProjectionReady),
      IngressStutter,
      productionBftBlockProjectionReady' = productionBftBlockProjectionReady,
      productionPrecommitEvidenceProjectionReady' = true,
      tenderlinkValuePrecommitCertificateRouted' =
        tenderlinkValuePrecommitCertificateRouted,
      productionFatPointerWireProjectionReady' =
        productionFatPointerWireProjectionReady,
      finalizedProductionBlockFromIngress' = finalizedProductionBlockFromIngress,
      latestFinalizedProductionBlockHash' = latestFinalizedProductionBlockHash,
      bridgeProgress' = bridgeProgress + 1,
      bridgeFiredAction' = "RawProjectProductionPrecommitEvidence",
    }

  action RawRouteTenderlinkValuePrecommitCertificate: bool =
    all {
      not(tenderlinkValuePrecommitCertificateRouted),
      IngressStutter,
      productionBftBlockProjectionReady' = productionBftBlockProjectionReady,
      productionPrecommitEvidenceProjectionReady' =
        productionPrecommitEvidenceProjectionReady,
      tenderlinkValuePrecommitCertificateRouted' = true,
      productionFatPointerWireProjectionReady' =
        productionFatPointerWireProjectionReady,
      finalizedProductionBlockFromIngress' = finalizedProductionBlockFromIngress,
      latestFinalizedProductionBlockHash' = latestFinalizedProductionBlockHash,
      bridgeProgress' = bridgeProgress + 1,
      bridgeFiredAction' = "RawRouteTenderlinkValuePrecommitCertificate",
    }

  action RawProjectProductionFatPointerWire: bool =
    all {
      not(productionFatPointerWireProjectionReady),
      IngressStutter,
      productionBftBlockProjectionReady' = productionBftBlockProjectionReady,
      productionPrecommitEvidenceProjectionReady' =
        productionPrecommitEvidenceProjectionReady,
      tenderlinkValuePrecommitCertificateRouted' =
        tenderlinkValuePrecommitCertificateRouted,
      productionFatPointerWireProjectionReady' = true,
      finalizedProductionBlockFromIngress' = finalizedProductionBlockFromIngress,
      latestFinalizedProductionBlockHash' = latestFinalizedProductionBlockHash,
      bridgeProgress' = bridgeProgress + 1,
      bridgeFiredAction' = "RawProjectProductionFatPointerWire",
    }

  action RawFinalizeProductionBlockFromIngress: bool =
    all {
      IngressStutter,
      productionBftBlockProjectionReady' = productionBftBlockProjectionReady,
      productionPrecommitEvidenceProjectionReady' =
        productionPrecommitEvidenceProjectionReady,
      tenderlinkValuePrecommitCertificateRouted' =
        tenderlinkValuePrecommitCertificateRouted,
      productionFatPointerWireProjectionReady' =
        productionFatPointerWireProjectionReady,
      finalizedProductionBlockFromIngress' = true,
      latestFinalizedProductionBlockHash' = FixtureBlockHash,
      bridgeProgress' = bridgeProgress + 1,
      bridgeFiredAction' = "RawFinalizeProductionBlockFromIngress",
    }

  action BridgeStutter: bool =
    all {
      IngressStutter,
      KeepBridgeState,
    }

  action BridgeNext: bool =
    any {
      AcceptProductionBftBlockProposalIngress,
      AcceptTenderlinkValuePrecommitCertificateIngress,
      RouteTenderlinkValuePrecommitCertificateAfterIngress,
      AcceptProductionFatPointerWireIngress,
      ProjectProductionBftBlockProposalAfterIngress,
      ProjectProductionPrecommitEvidenceAfterTenderlinkRouter,
      ProjectProductionFatPointerWireAfterIngress,
      FinalizeProductionBlockAfterIngress,
      BridgeStutter,
    }

  temporal EventuallyFinalityIngressBridgeFinalizes =
    BridgeNext.weakFair(Set(bridgeProgress)).implies(eventually(
      finalizedProductionBlockFromIngress and
      latestFinalizedProductionBlockHash == FixtureBlockHash and
      ProductionBftBlockProposalIngressAccepted and
      TenderlinkValuePrecommitCertificateIngressAccepted and
      tenderlinkValuePrecommitCertificateRouted and
      ProductionFatPointerWireIngressAccepted and
      productionBftBlockProjectionReady and
      productionPrecommitEvidenceProjectionReady and
      productionFatPointerWireProjectionReady
    ))

  run finalityIngressBridgeCompletesFromAcceptedFinalityLanesTest = {
    BridgeInit
      .then(AcceptProductionBftBlockProposalIngress)
      .then(AcceptTenderlinkValuePrecommitCertificateIngress)
      .then(RouteTenderlinkValuePrecommitCertificateAfterIngress)
      .then(AcceptProductionFatPointerWireIngress)
      .then(ProjectProductionBftBlockProposalAfterIngress)
      .then(ProjectProductionPrecommitEvidenceAfterTenderlinkRouter)
      .then(ProjectProductionFatPointerWireAfterIngress)
      .then(FinalizeProductionBlockAfterIngress)
      .then(all {
        assert(finalizedProductionBlockFromIngress),
        assert(latestFinalizedProductionBlockHash == FixtureBlockHash),
        assert(ProductionBftBlockProposalIngressAccepted),
        assert(TenderlinkValuePrecommitCertificateIngressAccepted),
        assert(tenderlinkValuePrecommitCertificateRouted),
        assert(ProductionFatPointerWireIngressAccepted),
        assert(productionPrecommitEvidenceProjectionReady),
        assert(FinalityIngressBridgeSafety),
        BridgeStutter,
      })
  }

  run proposalProjectionRequiresProductionIngressTest = {
    BridgeInit
      .then(ProjectProductionBftBlockProposalAfterIngress)
      .fail()
  }

  run fatPointerProjectionRequiresProductionIngressTest = {
    BridgeInit
      .then(ProjectProductionFatPointerWireAfterIngress)
      .fail()
  }

  run precommitEvidenceProjectionRequiresTenderlinkRouterTest = {
    BridgeInit
      .then(ProjectProductionPrecommitEvidenceAfterTenderlinkRouter)
      .fail()
  }

  run tenderlinkRouterRequiresTenderlinkIngressTest = {
    BridgeInit
      .then(RouteTenderlinkValuePrecommitCertificateAfterIngress)
      .fail()
  }

  run fatPointerProjectionRequiresPrecommitEvidenceTest = {
    BridgeInit
      .then(AcceptProductionFatPointerWireIngress)
      .then(ProjectProductionFatPointerWireAfterIngress)
      .fail()
  }

  run finalityRejectsMissingProposalProjectionTest = {
    BridgeInit
      .then(AcceptTenderlinkValuePrecommitCertificateIngress)
      .then(RouteTenderlinkValuePrecommitCertificateAfterIngress)
      .then(AcceptProductionFatPointerWireIngress)
      .then(ProjectProductionPrecommitEvidenceAfterTenderlinkRouter)
      .then(ProjectProductionFatPointerWireAfterIngress)
      .then(FinalizeProductionBlockAfterIngress)
      .fail()
  }

  run finalityRejectsMissingFatPointerProjectionTest = {
    BridgeInit
      .then(AcceptProductionBftBlockProposalIngress)
      .then(AcceptTenderlinkValuePrecommitCertificateIngress)
      .then(RouteTenderlinkValuePrecommitCertificateAfterIngress)
      .then(ProjectProductionBftBlockProposalAfterIngress)
      .then(ProjectProductionPrecommitEvidenceAfterTenderlinkRouter)
      .then(FinalizeProductionBlockAfterIngress)
      .fail()
  }

  run rawProposalProjectionWithoutIngressViolatesSafetyTest = {
    BridgeInit
      .then(RawProjectProductionBftBlockProposal)
      .then(all {
        assert(not(ProductionBftBlockProposalIngressAccepted)),
        assert(not(FinalityIngressBridgeSafety)),
        BridgeStutter,
      })
  }

  run rawFatPointerProjectionWithoutIngressViolatesSafetyTest = {
    BridgeInit
      .then(AcceptTenderlinkValuePrecommitCertificateIngress)
      .then(RouteTenderlinkValuePrecommitCertificateAfterIngress)
      .then(ProjectProductionPrecommitEvidenceAfterTenderlinkRouter)
      .then(RawProjectProductionFatPointerWire)
      .then(all {
        assert(not(ProductionFatPointerWireIngressAccepted)),
        assert(not(FinalityIngressBridgeSafety)),
        BridgeStutter,
      })
  }

  run rawPrecommitEvidenceProjectionWithoutTenderlinkIngressViolatesSafetyTest = {
    BridgeInit
      .then(RawProjectProductionPrecommitEvidence)
      .then(all {
        assert(not(TenderlinkValuePrecommitCertificateIngressAccepted)),
        assert(not(FinalityIngressBridgeSafety)),
        BridgeStutter,
      })
  }

  run rawTenderlinkRouterWithoutIngressViolatesSafetyTest = {
    BridgeInit
      .then(RawRouteTenderlinkValuePrecommitCertificate)
      .then(all {
        assert(not(TenderlinkValuePrecommitCertificateIngressAccepted)),
        assert(tenderlinkValuePrecommitCertificateRouted),
        assert(not(FinalityIngressBridgeSafety)),
        BridgeStutter,
      })
  }

  run rawFinalizeWithoutProjectionViolatesSafetyTest = {
    BridgeInit
      .then(RawFinalizeProductionBlockFromIngress)
      .then(all {
        assert(not(productionBftBlockProjectionReady)),
        assert(not(productionPrecommitEvidenceProjectionReady)),
        assert(not(productionFatPointerWireProjectionReady)),
        assert(not(FinalityIngressBridgeSafety)),
        BridgeStutter,
      })
  }

  run tenderlinkPrecommitCannotSatisfyFinalityIngressTest = {
    BridgeInit
      .then(AttemptTenderlinkPrecommitAsProductionBftBlockProposalIngress)
      .fail()
  }

  run finalityIngressBridgeSafetyTest = {
    BridgeInit
      .then(all {
        assert(ProductionFinalityIngressMetadataCoherent),
        assert(FinalityIngressBridgeSafety),
        BridgeStutter,
      })
  }
}

module CrosslinkProductionFinalityIngressBridgeModel {
  import CrosslinkProductionFinalityIngressBridge.* from
    "./CrosslinkProductionFinalityIngressBridge"
  export CrosslinkProductionFinalityIngressBridge.*
}
