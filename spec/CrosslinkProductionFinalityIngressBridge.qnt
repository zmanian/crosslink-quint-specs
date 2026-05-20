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
   production ingress lane has accepted the registry-valid prerequisite.
   */

  import CrosslinkProductionGossipIngress.* from
    "./CrosslinkProductionGossipIngress"
  export CrosslinkProductionGossipIngress.*

  pure val FixtureBlockHash = "fixture-bft-block"
  pure val NoFinalizedBlockHash = "none"

  var productionBftBlockProjectionReady: bool
  var productionPrecommitEvidenceProjectionReady: bool
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

  val ProjectionPrecommitEvidenceRequiresTenderlinkIngress =
    if (productionPrecommitEvidenceProjectionReady) {
      TenderlinkValuePrecommitCertificateIngressAccepted
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
      ProductionFatPointerWireIngressAccepted and
      latestFinalizedProductionBlockHash == FixtureBlockHash
    } else {
      latestFinalizedProductionBlockHash == NoFinalizedBlockHash
    }

  val BridgeStateWellFormed =
    bridgeProgress >= 0 and
    bridgeProgress <= 7 and
    Set(
      "BridgeInit",
      "AcceptProductionBftBlockProposalIngress",
      "AcceptTenderlinkValuePrecommitCertificateIngress",
      "AcceptProductionFatPointerWireIngress",
      "ProjectProductionBftBlockProposalAfterIngress",
      "ProjectProductionPrecommitEvidenceAfterTenderlinkIngress",
      "ProjectProductionFatPointerWireAfterIngress",
      "FinalizeProductionBlockAfterIngress",
      "RawProjectProductionBftBlockProposal",
      "RawProjectProductionPrecommitEvidence",
      "RawProjectProductionFatPointerWire",
      "RawFinalizeProductionBlockFromIngress",
    ).contains(bridgeFiredAction)

  val FinalityIngressBridgeSafety =
    IngressSafety and
    ProductionFinalityIngressMetadataCoherent and
    BridgeStateWellFormed and
    ProjectionProposalRequiresIngress and
    ProjectionPrecommitEvidenceRequiresTenderlinkIngress and
    ProjectionFatPointerWireRequiresIngress and
    FinalityRequiresIngressProjection

  action BridgeInit = all {
    IngressInit,
    productionBftBlockProjectionReady' = false,
    productionPrecommitEvidenceProjectionReady' = false,
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
      productionFatPointerWireProjectionReady' =
        productionFatPointerWireProjectionReady,
      finalizedProductionBlockFromIngress' = finalizedProductionBlockFromIngress,
      latestFinalizedProductionBlockHash' = latestFinalizedProductionBlockHash,
      bridgeProgress' = bridgeProgress + 1,
      bridgeFiredAction' = "ProjectProductionBftBlockProposalAfterIngress",
    }

  action ProjectProductionPrecommitEvidenceAfterTenderlinkIngress: bool =
    all {
      TenderlinkValuePrecommitCertificateIngressAccepted,
      not(productionPrecommitEvidenceProjectionReady),
      IngressStutter,
      productionBftBlockProjectionReady' = productionBftBlockProjectionReady,
      productionPrecommitEvidenceProjectionReady' = true,
      productionFatPointerWireProjectionReady' =
        productionFatPointerWireProjectionReady,
      finalizedProductionBlockFromIngress' = finalizedProductionBlockFromIngress,
      latestFinalizedProductionBlockHash' = latestFinalizedProductionBlockHash,
      bridgeProgress' = bridgeProgress + 1,
      bridgeFiredAction' =
        "ProjectProductionPrecommitEvidenceAfterTenderlinkIngress",
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
      productionFatPointerWireProjectionReady' =
        productionFatPointerWireProjectionReady,
      finalizedProductionBlockFromIngress' = finalizedProductionBlockFromIngress,
      latestFinalizedProductionBlockHash' = latestFinalizedProductionBlockHash,
      bridgeProgress' = bridgeProgress + 1,
      bridgeFiredAction' = "RawProjectProductionPrecommitEvidence",
    }

  action RawProjectProductionFatPointerWire: bool =
    all {
      not(productionFatPointerWireProjectionReady),
      IngressStutter,
      productionBftBlockProjectionReady' = productionBftBlockProjectionReady,
      productionPrecommitEvidenceProjectionReady' =
        productionPrecommitEvidenceProjectionReady,
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
      AcceptProductionFatPointerWireIngress,
      ProjectProductionBftBlockProposalAfterIngress,
      ProjectProductionPrecommitEvidenceAfterTenderlinkIngress,
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
      ProductionFatPointerWireIngressAccepted and
      productionBftBlockProjectionReady and
      productionPrecommitEvidenceProjectionReady and
      productionFatPointerWireProjectionReady
    ))

  run finalityIngressBridgeCompletesFromAcceptedFinalityLanesTest = {
    BridgeInit
      .then(AcceptProductionBftBlockProposalIngress)
      .then(AcceptTenderlinkValuePrecommitCertificateIngress)
      .then(AcceptProductionFatPointerWireIngress)
      .then(ProjectProductionBftBlockProposalAfterIngress)
      .then(ProjectProductionPrecommitEvidenceAfterTenderlinkIngress)
      .then(ProjectProductionFatPointerWireAfterIngress)
      .then(FinalizeProductionBlockAfterIngress)
      .then(all {
        assert(finalizedProductionBlockFromIngress),
        assert(latestFinalizedProductionBlockHash == FixtureBlockHash),
        assert(ProductionBftBlockProposalIngressAccepted),
        assert(TenderlinkValuePrecommitCertificateIngressAccepted),
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

  run precommitEvidenceProjectionRequiresTenderlinkIngressTest = {
    BridgeInit
      .then(ProjectProductionPrecommitEvidenceAfterTenderlinkIngress)
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
      .then(AcceptProductionFatPointerWireIngress)
      .then(ProjectProductionPrecommitEvidenceAfterTenderlinkIngress)
      .then(ProjectProductionFatPointerWireAfterIngress)
      .then(FinalizeProductionBlockAfterIngress)
      .fail()
  }

  run finalityRejectsMissingFatPointerProjectionTest = {
    BridgeInit
      .then(AcceptProductionBftBlockProposalIngress)
      .then(AcceptTenderlinkValuePrecommitCertificateIngress)
      .then(ProjectProductionBftBlockProposalAfterIngress)
      .then(ProjectProductionPrecommitEvidenceAfterTenderlinkIngress)
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
      .then(ProjectProductionPrecommitEvidenceAfterTenderlinkIngress)
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
