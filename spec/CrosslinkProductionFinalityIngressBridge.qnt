module CrosslinkProductionFinalityIngressBridge {
  /*
   Production finality ingress bridge.

   CrosslinkProductionGossipIngress.qnt proves that production-finality
   proposal and fat-pointer records enter their own node-local lanes.
   CrosslinkProductionFinalityProjectionContract.qnt proves that finality waits
   for a production-shaped BFT-block proposal and transported fat-pointer
   evidence. This bridge joins those two boundaries in a verifier-friendly
   scalar graph: the finality projection cannot observe the fixture proposal or
   fat-pointer wire until the matching production ingress lane has accepted the
   registry-valid record.
   */

  import CrosslinkProductionGossipIngress.* from
    "./CrosslinkProductionGossipIngress"
  export CrosslinkProductionGossipIngress.*

  pure val FixtureBlockHash = "fixture-bft-block"
  pure val NoFinalizedBlockHash = "none"

  var productionBftBlockProjectionReady: bool
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
      ProductionFatPointerWireIngressAccepted
    } else {
      true
    }

  val FinalityRequiresIngressProjection =
    if (finalizedProductionBlockFromIngress) {
      productionBftBlockProjectionReady and
      productionFatPointerWireProjectionReady and
      ProductionBftBlockProposalIngressAccepted and
      ProductionFatPointerWireIngressAccepted and
      latestFinalizedProductionBlockHash == FixtureBlockHash
    } else {
      latestFinalizedProductionBlockHash == NoFinalizedBlockHash
    }

  val BridgeStateWellFormed =
    bridgeProgress >= 0 and
    bridgeProgress <= 5 and
    Set(
      "BridgeInit",
      "AcceptProductionBftBlockProposalIngress",
      "AcceptProductionFatPointerWireIngress",
      "ProjectProductionBftBlockProposalAfterIngress",
      "ProjectProductionFatPointerWireAfterIngress",
      "FinalizeProductionBlockAfterIngress",
      "RawProjectProductionBftBlockProposal",
      "RawProjectProductionFatPointerWire",
      "RawFinalizeProductionBlockFromIngress",
    ).contains(bridgeFiredAction)

  val FinalityIngressBridgeSafety =
    IngressSafety and
    ProductionFinalityIngressMetadataCoherent and
    BridgeStateWellFormed and
    ProjectionProposalRequiresIngress and
    ProjectionFatPointerWireRequiresIngress and
    FinalityRequiresIngressProjection

  action BridgeInit = all {
    IngressInit,
    productionBftBlockProjectionReady' = false,
    productionFatPointerWireProjectionReady' = false,
    finalizedProductionBlockFromIngress' = false,
    latestFinalizedProductionBlockHash' = NoFinalizedBlockHash,
    bridgeProgress' = 0,
    bridgeFiredAction' = "BridgeInit",
  }

  action KeepBridgeState = all {
    productionBftBlockProjectionReady' = productionBftBlockProjectionReady,
    productionFatPointerWireProjectionReady' =
      productionFatPointerWireProjectionReady,
    finalizedProductionBlockFromIngress' = finalizedProductionBlockFromIngress,
    latestFinalizedProductionBlockHash' = latestFinalizedProductionBlockHash,
    bridgeProgress' = bridgeProgress,
    bridgeFiredAction' = bridgeFiredAction,
  }

  action KeepBridgeProjectionState = all {
    productionBftBlockProjectionReady' = productionBftBlockProjectionReady,
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
      productionFatPointerWireProjectionReady' =
        productionFatPointerWireProjectionReady,
      finalizedProductionBlockFromIngress' = finalizedProductionBlockFromIngress,
      latestFinalizedProductionBlockHash' = latestFinalizedProductionBlockHash,
      bridgeProgress' = bridgeProgress + 1,
      bridgeFiredAction' = "ProjectProductionBftBlockProposalAfterIngress",
    }

  action ProjectProductionFatPointerWireAfterIngress: bool =
    all {
      ProductionFatPointerWireIngressAccepted,
      not(productionFatPointerWireProjectionReady),
      IngressStutter,
      productionBftBlockProjectionReady' = productionBftBlockProjectionReady,
      productionFatPointerWireProjectionReady' = true,
      finalizedProductionBlockFromIngress' = finalizedProductionBlockFromIngress,
      latestFinalizedProductionBlockHash' = latestFinalizedProductionBlockHash,
      bridgeProgress' = bridgeProgress + 1,
      bridgeFiredAction' = "ProjectProductionFatPointerWireAfterIngress",
    }

  action FinalizeProductionBlockAfterIngress: bool =
    all {
      productionBftBlockProjectionReady,
      productionFatPointerWireProjectionReady,
      not(finalizedProductionBlockFromIngress),
      IngressStutter,
      productionBftBlockProjectionReady' = productionBftBlockProjectionReady,
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
      productionFatPointerWireProjectionReady' =
        productionFatPointerWireProjectionReady,
      finalizedProductionBlockFromIngress' = finalizedProductionBlockFromIngress,
      latestFinalizedProductionBlockHash' = latestFinalizedProductionBlockHash,
      bridgeProgress' = bridgeProgress + 1,
      bridgeFiredAction' = "RawProjectProductionBftBlockProposal",
    }

  action RawProjectProductionFatPointerWire: bool =
    all {
      not(productionFatPointerWireProjectionReady),
      IngressStutter,
      productionBftBlockProjectionReady' = productionBftBlockProjectionReady,
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
      AcceptProductionFatPointerWireIngress,
      ProjectProductionBftBlockProposalAfterIngress,
      ProjectProductionFatPointerWireAfterIngress,
      FinalizeProductionBlockAfterIngress,
      BridgeStutter,
    }

  temporal EventuallyFinalityIngressBridgeFinalizes =
    BridgeNext.weakFair(Set(bridgeProgress)).implies(eventually(
      finalizedProductionBlockFromIngress and
      latestFinalizedProductionBlockHash == FixtureBlockHash and
      ProductionBftBlockProposalIngressAccepted and
      ProductionFatPointerWireIngressAccepted and
      productionBftBlockProjectionReady and
      productionFatPointerWireProjectionReady
    ))

  run finalityIngressBridgeCompletesFromAcceptedFinalityLanesTest = {
    BridgeInit
      .then(AcceptProductionBftBlockProposalIngress)
      .then(AcceptProductionFatPointerWireIngress)
      .then(ProjectProductionBftBlockProposalAfterIngress)
      .then(ProjectProductionFatPointerWireAfterIngress)
      .then(FinalizeProductionBlockAfterIngress)
      .then(all {
        assert(finalizedProductionBlockFromIngress),
        assert(latestFinalizedProductionBlockHash == FixtureBlockHash),
        assert(ProductionBftBlockProposalIngressAccepted),
        assert(ProductionFatPointerWireIngressAccepted),
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

  run finalityRejectsMissingProposalProjectionTest = {
    BridgeInit
      .then(AcceptProductionFatPointerWireIngress)
      .then(ProjectProductionFatPointerWireAfterIngress)
      .then(FinalizeProductionBlockAfterIngress)
      .fail()
  }

  run finalityRejectsMissingFatPointerProjectionTest = {
    BridgeInit
      .then(AcceptProductionBftBlockProposalIngress)
      .then(ProjectProductionBftBlockProposalAfterIngress)
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
      .then(RawProjectProductionFatPointerWire)
      .then(all {
        assert(not(ProductionFatPointerWireIngressAccepted)),
        assert(not(FinalityIngressBridgeSafety)),
        BridgeStutter,
      })
  }

  run rawFinalizeWithoutProjectionViolatesSafetyTest = {
    BridgeInit
      .then(RawFinalizeProductionBlockFromIngress)
      .then(all {
        assert(not(productionBftBlockProjectionReady)),
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
