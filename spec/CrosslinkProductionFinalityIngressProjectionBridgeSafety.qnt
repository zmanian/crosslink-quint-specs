module CrosslinkProductionFinalityIngressProjectionBridgeSafety {
  /*
   Verifier-friendly production finality ingress/projection bridge.

   CrosslinkProductionFinalityIngressProjectionBridge.qnt composes the actual
   production ingress and production finality projection actions, but that
   imported-action graph currently hits Quint's Apalache flattener limits. This
   module keeps the same stage ordering as a direct scalar state machine so the
   bridge obligations remain covered by Apalache and TLC:

   ingress -> proposal transport -> candidate observation
   Tenderlink precommit ingress -> precommit evidence
   ingress -> fat-pointer transport -> precommit evidence -> fat-pointer observe
   both observed -> finality
   */

  pure val FixtureBlockHash = "fixture-bft-block"
  pure val NoFinalizedBlockHash = "none"

  var productionBftBlockProposalIngressAccepted: bool
  var productionFatPointerWireIngressAccepted: bool
  var tenderlinkPrecommitIngressAccepted: bool
  var productionBftBlockProposalTransportObserved: bool
  var productionBftBlockObserved: bool
  var productionPrecommitEvidenceGossiped: bool
  var productionFatPointerWireTransportObserved: bool
  var productionFatPointerWireObserved: bool
  var finalizedProductionBlock: bool
  var latestFinalizedProductionBlockHash: str
  var bridgeProgress: int
  var bridgeFiredAction: str

  val TenderlinkPrecommitDoesNotSatisfyProductionProposalIngress =
    if (tenderlinkPrecommitIngressAccepted and
        not(productionBftBlockProposalIngressAccepted)) {
      not(productionBftBlockProposalTransportObserved) and
      not(productionBftBlockObserved)
    } else {
      true
    }

  val ProposalTransportRequiresIngress =
    if (productionBftBlockProposalTransportObserved) {
      productionBftBlockProposalIngressAccepted
    } else {
      true
    }

  val CandidateObservationRequiresProposalTransport =
    if (productionBftBlockObserved) {
      productionBftBlockProposalIngressAccepted and
      productionBftBlockProposalTransportObserved
    } else {
      true
    }

  val FatPointerTransportRequiresIngress =
    if (productionFatPointerWireTransportObserved) {
      productionFatPointerWireIngressAccepted
    } else {
      true
    }

  val FatPointerObservationRequiresTransportAndPrecommitEvidence =
    if (productionFatPointerWireObserved) {
      productionFatPointerWireIngressAccepted and
      productionFatPointerWireTransportObserved and
      tenderlinkPrecommitIngressAccepted and
      productionPrecommitEvidenceGossiped
    } else {
      true
    }

  val PrecommitEvidenceRequiresTenderlinkIngress =
    if (productionPrecommitEvidenceGossiped) {
      tenderlinkPrecommitIngressAccepted
    } else {
      true
    }

  val FinalityRequiresCompleteIngressProjection =
    if (finalizedProductionBlock) {
      productionBftBlockProposalIngressAccepted and
      productionFatPointerWireIngressAccepted and
      tenderlinkPrecommitIngressAccepted and
      productionBftBlockProposalTransportObserved and
      productionBftBlockObserved and
      productionPrecommitEvidenceGossiped and
      productionFatPointerWireTransportObserved and
      productionFatPointerWireObserved and
      latestFinalizedProductionBlockHash == FixtureBlockHash
    } else {
      latestFinalizedProductionBlockHash == NoFinalizedBlockHash
    }

  val BridgeStateWellFormed =
    bridgeProgress >= 0 and
    bridgeProgress <= 9 and
    Set(
      "Init",
      "AcceptProductionBftBlockProposalIngress",
      "AcceptProductionFatPointerWireIngress",
      "AcceptTenderlinkPrecommitIngressOnly",
      "GossipProductionBftBlockProposalAfterIngress",
      "ObserveProductionBftBlockCandidateAfterTransport",
      "GossipProductionPrecommitEvidence",
      "GossipProductionFatPointerWireAfterIngress",
      "ObserveProductionFatPointerWireAfterTransport",
      "FinalizeProductionBlockAfterIngressProjection",
      "RawGossipProductionBftBlockProposalWithoutIngress",
      "RawObserveProductionBftBlockCandidateWithoutTransport",
      "RawGossipProductionFatPointerWireWithoutIngress",
      "RawObserveProductionFatPointerWireWithoutTransport",
      "RawFinalizeProductionBlockWithoutProjection",
    ).contains(bridgeFiredAction)

  val Safety =
    BridgeStateWellFormed and
    TenderlinkPrecommitDoesNotSatisfyProductionProposalIngress and
    ProposalTransportRequiresIngress and
    CandidateObservationRequiresProposalTransport and
    FatPointerTransportRequiresIngress and
    PrecommitEvidenceRequiresTenderlinkIngress and
    FatPointerObservationRequiresTransportAndPrecommitEvidence and
    FinalityRequiresCompleteIngressProjection

  action Init = all {
    productionBftBlockProposalIngressAccepted' = false,
    productionFatPointerWireIngressAccepted' = false,
    tenderlinkPrecommitIngressAccepted' = false,
    productionBftBlockProposalTransportObserved' = false,
    productionBftBlockObserved' = false,
    productionPrecommitEvidenceGossiped' = false,
    productionFatPointerWireTransportObserved' = false,
    productionFatPointerWireObserved' = false,
    finalizedProductionBlock' = false,
    latestFinalizedProductionBlockHash' = NoFinalizedBlockHash,
    bridgeProgress' = 0,
    bridgeFiredAction' = "Init",
  }

  action KeepState = all {
    productionBftBlockProposalIngressAccepted' =
      productionBftBlockProposalIngressAccepted,
    productionFatPointerWireIngressAccepted' =
      productionFatPointerWireIngressAccepted,
    tenderlinkPrecommitIngressAccepted' = tenderlinkPrecommitIngressAccepted,
    productionBftBlockProposalTransportObserved' =
      productionBftBlockProposalTransportObserved,
    productionBftBlockObserved' = productionBftBlockObserved,
    productionPrecommitEvidenceGossiped' = productionPrecommitEvidenceGossiped,
    productionFatPointerWireTransportObserved' =
      productionFatPointerWireTransportObserved,
    productionFatPointerWireObserved' = productionFatPointerWireObserved,
    finalizedProductionBlock' = finalizedProductionBlock,
    latestFinalizedProductionBlockHash' = latestFinalizedProductionBlockHash,
    bridgeProgress' = bridgeProgress,
    bridgeFiredAction' = bridgeFiredAction,
  }

  action Mark(actionName: str): bool = all {
    bridgeProgress' = bridgeProgress + 1,
    bridgeFiredAction' = actionName,
  }

  action AcceptProductionBftBlockProposalIngress: bool =
    all {
      not(productionBftBlockProposalIngressAccepted),
      productionBftBlockProposalIngressAccepted' = true,
      productionFatPointerWireIngressAccepted' =
        productionFatPointerWireIngressAccepted,
      tenderlinkPrecommitIngressAccepted' = tenderlinkPrecommitIngressAccepted,
      productionBftBlockProposalTransportObserved' =
        productionBftBlockProposalTransportObserved,
      productionBftBlockObserved' = productionBftBlockObserved,
      productionPrecommitEvidenceGossiped' = productionPrecommitEvidenceGossiped,
      productionFatPointerWireTransportObserved' =
        productionFatPointerWireTransportObserved,
      productionFatPointerWireObserved' = productionFatPointerWireObserved,
      finalizedProductionBlock' = finalizedProductionBlock,
      latestFinalizedProductionBlockHash' = latestFinalizedProductionBlockHash,
      Mark("AcceptProductionBftBlockProposalIngress"),
    }

  action AcceptProductionFatPointerWireIngress: bool =
    all {
      not(productionFatPointerWireIngressAccepted),
      productionBftBlockProposalIngressAccepted' =
        productionBftBlockProposalIngressAccepted,
      productionFatPointerWireIngressAccepted' = true,
      tenderlinkPrecommitIngressAccepted' = tenderlinkPrecommitIngressAccepted,
      productionBftBlockProposalTransportObserved' =
        productionBftBlockProposalTransportObserved,
      productionBftBlockObserved' = productionBftBlockObserved,
      productionPrecommitEvidenceGossiped' = productionPrecommitEvidenceGossiped,
      productionFatPointerWireTransportObserved' =
        productionFatPointerWireTransportObserved,
      productionFatPointerWireObserved' = productionFatPointerWireObserved,
      finalizedProductionBlock' = finalizedProductionBlock,
      latestFinalizedProductionBlockHash' = latestFinalizedProductionBlockHash,
      Mark("AcceptProductionFatPointerWireIngress"),
    }

  action AcceptTenderlinkPrecommitIngressOnly: bool =
    all {
      not(tenderlinkPrecommitIngressAccepted),
      productionBftBlockProposalIngressAccepted' =
        productionBftBlockProposalIngressAccepted,
      productionFatPointerWireIngressAccepted' =
        productionFatPointerWireIngressAccepted,
      tenderlinkPrecommitIngressAccepted' = true,
      productionBftBlockProposalTransportObserved' =
        productionBftBlockProposalTransportObserved,
      productionBftBlockObserved' = productionBftBlockObserved,
      productionPrecommitEvidenceGossiped' = productionPrecommitEvidenceGossiped,
      productionFatPointerWireTransportObserved' =
        productionFatPointerWireTransportObserved,
      productionFatPointerWireObserved' = productionFatPointerWireObserved,
      finalizedProductionBlock' = finalizedProductionBlock,
      latestFinalizedProductionBlockHash' = latestFinalizedProductionBlockHash,
      Mark("AcceptTenderlinkPrecommitIngressOnly"),
    }

  action GossipProductionBftBlockProposalAfterIngress: bool =
    all {
      productionBftBlockProposalIngressAccepted,
      not(productionBftBlockProposalTransportObserved),
      productionBftBlockProposalIngressAccepted' =
        productionBftBlockProposalIngressAccepted,
      productionFatPointerWireIngressAccepted' =
        productionFatPointerWireIngressAccepted,
      tenderlinkPrecommitIngressAccepted' = tenderlinkPrecommitIngressAccepted,
      productionBftBlockProposalTransportObserved' = true,
      productionBftBlockObserved' = productionBftBlockObserved,
      productionPrecommitEvidenceGossiped' = productionPrecommitEvidenceGossiped,
      productionFatPointerWireTransportObserved' =
        productionFatPointerWireTransportObserved,
      productionFatPointerWireObserved' = productionFatPointerWireObserved,
      finalizedProductionBlock' = finalizedProductionBlock,
      latestFinalizedProductionBlockHash' = latestFinalizedProductionBlockHash,
      Mark("GossipProductionBftBlockProposalAfterIngress"),
    }

  action ObserveProductionBftBlockCandidateAfterTransport: bool =
    all {
      productionBftBlockProposalTransportObserved,
      not(productionBftBlockObserved),
      productionBftBlockProposalIngressAccepted' =
        productionBftBlockProposalIngressAccepted,
      productionFatPointerWireIngressAccepted' =
        productionFatPointerWireIngressAccepted,
      tenderlinkPrecommitIngressAccepted' = tenderlinkPrecommitIngressAccepted,
      productionBftBlockProposalTransportObserved' =
        productionBftBlockProposalTransportObserved,
      productionBftBlockObserved' = true,
      productionPrecommitEvidenceGossiped' = productionPrecommitEvidenceGossiped,
      productionFatPointerWireTransportObserved' =
        productionFatPointerWireTransportObserved,
      productionFatPointerWireObserved' = productionFatPointerWireObserved,
      finalizedProductionBlock' = finalizedProductionBlock,
      latestFinalizedProductionBlockHash' = latestFinalizedProductionBlockHash,
      Mark("ObserveProductionBftBlockCandidateAfterTransport"),
    }

  action GossipProductionPrecommitEvidence: bool =
    all {
      tenderlinkPrecommitIngressAccepted,
      not(productionPrecommitEvidenceGossiped),
      productionBftBlockProposalIngressAccepted' =
        productionBftBlockProposalIngressAccepted,
      productionFatPointerWireIngressAccepted' =
        productionFatPointerWireIngressAccepted,
      tenderlinkPrecommitIngressAccepted' = tenderlinkPrecommitIngressAccepted,
      productionBftBlockProposalTransportObserved' =
        productionBftBlockProposalTransportObserved,
      productionBftBlockObserved' = productionBftBlockObserved,
      productionPrecommitEvidenceGossiped' = true,
      productionFatPointerWireTransportObserved' =
        productionFatPointerWireTransportObserved,
      productionFatPointerWireObserved' = productionFatPointerWireObserved,
      finalizedProductionBlock' = finalizedProductionBlock,
      latestFinalizedProductionBlockHash' = latestFinalizedProductionBlockHash,
      Mark("GossipProductionPrecommitEvidence"),
    }

  action GossipProductionFatPointerWireAfterIngress: bool =
    all {
      productionFatPointerWireIngressAccepted,
      not(productionFatPointerWireTransportObserved),
      productionBftBlockProposalIngressAccepted' =
        productionBftBlockProposalIngressAccepted,
      productionFatPointerWireIngressAccepted' =
        productionFatPointerWireIngressAccepted,
      tenderlinkPrecommitIngressAccepted' = tenderlinkPrecommitIngressAccepted,
      productionBftBlockProposalTransportObserved' =
        productionBftBlockProposalTransportObserved,
      productionBftBlockObserved' = productionBftBlockObserved,
      productionPrecommitEvidenceGossiped' = productionPrecommitEvidenceGossiped,
      productionFatPointerWireTransportObserved' = true,
      productionFatPointerWireObserved' = productionFatPointerWireObserved,
      finalizedProductionBlock' = finalizedProductionBlock,
      latestFinalizedProductionBlockHash' = latestFinalizedProductionBlockHash,
      Mark("GossipProductionFatPointerWireAfterIngress"),
    }

  action ObserveProductionFatPointerWireAfterTransport: bool =
    all {
      productionFatPointerWireTransportObserved,
      productionPrecommitEvidenceGossiped,
      not(productionFatPointerWireObserved),
      productionBftBlockProposalIngressAccepted' =
        productionBftBlockProposalIngressAccepted,
      productionFatPointerWireIngressAccepted' =
        productionFatPointerWireIngressAccepted,
      tenderlinkPrecommitIngressAccepted' = tenderlinkPrecommitIngressAccepted,
      productionBftBlockProposalTransportObserved' =
        productionBftBlockProposalTransportObserved,
      productionBftBlockObserved' = productionBftBlockObserved,
      productionPrecommitEvidenceGossiped' = productionPrecommitEvidenceGossiped,
      productionFatPointerWireTransportObserved' =
        productionFatPointerWireTransportObserved,
      productionFatPointerWireObserved' = true,
      finalizedProductionBlock' = finalizedProductionBlock,
      latestFinalizedProductionBlockHash' = latestFinalizedProductionBlockHash,
      Mark("ObserveProductionFatPointerWireAfterTransport"),
    }

  action FinalizeProductionBlockAfterIngressProjection: bool =
    all {
      productionBftBlockObserved,
      productionFatPointerWireObserved,
      not(finalizedProductionBlock),
      productionBftBlockProposalIngressAccepted' =
        productionBftBlockProposalIngressAccepted,
      productionFatPointerWireIngressAccepted' =
        productionFatPointerWireIngressAccepted,
      tenderlinkPrecommitIngressAccepted' = tenderlinkPrecommitIngressAccepted,
      productionBftBlockProposalTransportObserved' =
        productionBftBlockProposalTransportObserved,
      productionBftBlockObserved' = productionBftBlockObserved,
      productionPrecommitEvidenceGossiped' = productionPrecommitEvidenceGossiped,
      productionFatPointerWireTransportObserved' =
        productionFatPointerWireTransportObserved,
      productionFatPointerWireObserved' = productionFatPointerWireObserved,
      finalizedProductionBlock' = true,
      latestFinalizedProductionBlockHash' = FixtureBlockHash,
      Mark("FinalizeProductionBlockAfterIngressProjection"),
    }

  action RawGossipProductionBftBlockProposalWithoutIngress: bool =
    all {
      not(productionBftBlockProposalIngressAccepted),
      productionBftBlockProposalIngressAccepted' =
        productionBftBlockProposalIngressAccepted,
      productionFatPointerWireIngressAccepted' =
        productionFatPointerWireIngressAccepted,
      tenderlinkPrecommitIngressAccepted' = tenderlinkPrecommitIngressAccepted,
      productionBftBlockProposalTransportObserved' = true,
      productionBftBlockObserved' = productionBftBlockObserved,
      productionPrecommitEvidenceGossiped' = productionPrecommitEvidenceGossiped,
      productionFatPointerWireTransportObserved' =
        productionFatPointerWireTransportObserved,
      productionFatPointerWireObserved' = productionFatPointerWireObserved,
      finalizedProductionBlock' = finalizedProductionBlock,
      latestFinalizedProductionBlockHash' = latestFinalizedProductionBlockHash,
      Mark("RawGossipProductionBftBlockProposalWithoutIngress"),
    }

  action RawObserveProductionBftBlockCandidateWithoutTransport: bool =
    all {
      not(productionBftBlockProposalTransportObserved),
      productionBftBlockProposalIngressAccepted' =
        productionBftBlockProposalIngressAccepted,
      productionFatPointerWireIngressAccepted' =
        productionFatPointerWireIngressAccepted,
      tenderlinkPrecommitIngressAccepted' = tenderlinkPrecommitIngressAccepted,
      productionBftBlockProposalTransportObserved' =
        productionBftBlockProposalTransportObserved,
      productionBftBlockObserved' = true,
      productionPrecommitEvidenceGossiped' = productionPrecommitEvidenceGossiped,
      productionFatPointerWireTransportObserved' =
        productionFatPointerWireTransportObserved,
      productionFatPointerWireObserved' = productionFatPointerWireObserved,
      finalizedProductionBlock' = finalizedProductionBlock,
      latestFinalizedProductionBlockHash' = latestFinalizedProductionBlockHash,
      Mark("RawObserveProductionBftBlockCandidateWithoutTransport"),
    }

  action RawGossipProductionFatPointerWireWithoutIngress: bool =
    all {
      not(productionFatPointerWireIngressAccepted),
      productionBftBlockProposalIngressAccepted' =
        productionBftBlockProposalIngressAccepted,
      productionFatPointerWireIngressAccepted' =
        productionFatPointerWireIngressAccepted,
      tenderlinkPrecommitIngressAccepted' = tenderlinkPrecommitIngressAccepted,
      productionBftBlockProposalTransportObserved' =
        productionBftBlockProposalTransportObserved,
      productionBftBlockObserved' = productionBftBlockObserved,
      productionPrecommitEvidenceGossiped' = productionPrecommitEvidenceGossiped,
      productionFatPointerWireTransportObserved' = true,
      productionFatPointerWireObserved' = productionFatPointerWireObserved,
      finalizedProductionBlock' = finalizedProductionBlock,
      latestFinalizedProductionBlockHash' = latestFinalizedProductionBlockHash,
      Mark("RawGossipProductionFatPointerWireWithoutIngress"),
    }

  action RawObserveProductionFatPointerWireWithoutTransport: bool =
    all {
      not(productionFatPointerWireTransportObserved) or
        not(productionPrecommitEvidenceGossiped),
      productionBftBlockProposalIngressAccepted' =
        productionBftBlockProposalIngressAccepted,
      productionFatPointerWireIngressAccepted' =
        productionFatPointerWireIngressAccepted,
      tenderlinkPrecommitIngressAccepted' = tenderlinkPrecommitIngressAccepted,
      productionBftBlockProposalTransportObserved' =
        productionBftBlockProposalTransportObserved,
      productionBftBlockObserved' = productionBftBlockObserved,
      productionPrecommitEvidenceGossiped' = productionPrecommitEvidenceGossiped,
      productionFatPointerWireTransportObserved' =
        productionFatPointerWireTransportObserved,
      productionFatPointerWireObserved' = true,
      finalizedProductionBlock' = finalizedProductionBlock,
      latestFinalizedProductionBlockHash' = latestFinalizedProductionBlockHash,
      Mark("RawObserveProductionFatPointerWireWithoutTransport"),
    }

  action RawFinalizeProductionBlockWithoutProjection: bool =
    all {
      not(productionBftBlockObserved) or not(productionFatPointerWireObserved),
      productionBftBlockProposalIngressAccepted' =
        productionBftBlockProposalIngressAccepted,
      productionFatPointerWireIngressAccepted' =
        productionFatPointerWireIngressAccepted,
      tenderlinkPrecommitIngressAccepted' = tenderlinkPrecommitIngressAccepted,
      productionBftBlockProposalTransportObserved' =
        productionBftBlockProposalTransportObserved,
      productionBftBlockObserved' = productionBftBlockObserved,
      productionPrecommitEvidenceGossiped' = productionPrecommitEvidenceGossiped,
      productionFatPointerWireTransportObserved' =
        productionFatPointerWireTransportObserved,
      productionFatPointerWireObserved' = productionFatPointerWireObserved,
      finalizedProductionBlock' = true,
      latestFinalizedProductionBlockHash' = FixtureBlockHash,
      Mark("RawFinalizeProductionBlockWithoutProjection"),
    }

  action Stutter: bool =
    KeepState

  action Next: bool =
    any {
      AcceptProductionBftBlockProposalIngress,
      AcceptProductionFatPointerWireIngress,
      AcceptTenderlinkPrecommitIngressOnly,
      GossipProductionBftBlockProposalAfterIngress,
      ObserveProductionBftBlockCandidateAfterTransport,
      GossipProductionPrecommitEvidence,
      GossipProductionFatPointerWireAfterIngress,
      ObserveProductionFatPointerWireAfterTransport,
      FinalizeProductionBlockAfterIngressProjection,
      Stutter,
    }

  temporal EventuallyProductionIngressProjectionFinalizes =
    Next.weakFair(Set(bridgeProgress)).implies(eventually(
      productionBftBlockProposalIngressAccepted and
      tenderlinkPrecommitIngressAccepted and
      productionFatPointerWireIngressAccepted and
      productionBftBlockProposalTransportObserved and
      productionBftBlockObserved and
      productionPrecommitEvidenceGossiped and
      productionFatPointerWireTransportObserved and
      productionFatPointerWireObserved and
      finalizedProductionBlock and
      latestFinalizedProductionBlockHash == FixtureBlockHash
    ))

  run ingressProjectionSafetyCompletesProductionFinalityTest = {
    Init
      .then(AcceptTenderlinkPrecommitIngressOnly)
      .then(AcceptProductionBftBlockProposalIngress)
      .then(GossipProductionBftBlockProposalAfterIngress)
      .then(ObserveProductionBftBlockCandidateAfterTransport)
      .then(GossipProductionPrecommitEvidence)
      .then(AcceptProductionFatPointerWireIngress)
      .then(GossipProductionFatPointerWireAfterIngress)
      .then(ObserveProductionFatPointerWireAfterTransport)
      .then(FinalizeProductionBlockAfterIngressProjection)
      .then(all {
        assert(tenderlinkPrecommitIngressAccepted),
        assert(productionBftBlockProposalIngressAccepted),
        assert(productionFatPointerWireIngressAccepted),
        assert(productionBftBlockObserved),
        assert(productionFatPointerWireObserved),
        assert(finalizedProductionBlock),
        assert(latestFinalizedProductionBlockHash == FixtureBlockHash),
        assert(Safety),
        Stutter,
      })
  }

  run proposalTransportRequiresProductionIngressTest = {
    Init
      .then(GossipProductionBftBlockProposalAfterIngress)
      .fail()
  }

  run rawProposalTransportWithoutIngressViolatesSafetyTest = {
    Init
      .then(RawGossipProductionBftBlockProposalWithoutIngress)
      .then(all {
        assert(productionBftBlockProposalTransportObserved),
        assert(not(productionBftBlockProposalIngressAccepted)),
        assert(not(Safety)),
        Stutter,
      })
  }

  run candidateRequiresProposalTransportTest = {
    Init
      .then(AcceptProductionBftBlockProposalIngress)
      .then(ObserveProductionBftBlockCandidateAfterTransport)
      .fail()
  }

  run rawCandidateWithoutTransportViolatesSafetyTest = {
    Init
      .then(RawObserveProductionBftBlockCandidateWithoutTransport)
      .then(all {
        assert(productionBftBlockObserved),
        assert(not(productionBftBlockProposalTransportObserved)),
        assert(not(Safety)),
        Stutter,
      })
  }

  run fatPointerTransportRequiresProductionIngressTest = {
    Init
      .then(GossipProductionFatPointerWireAfterIngress)
      .fail()
  }

  run rawFatPointerTransportWithoutIngressViolatesSafetyTest = {
    Init
      .then(RawGossipProductionFatPointerWireWithoutIngress)
      .then(all {
        assert(productionFatPointerWireTransportObserved),
        assert(not(productionFatPointerWireIngressAccepted)),
        assert(not(Safety)),
        Stutter,
      })
  }

  run fatPointerObservationRequiresTransportAndPrecommitTest = {
    Init
      .then(AcceptProductionFatPointerWireIngress)
      .then(GossipProductionFatPointerWireAfterIngress)
      .then(ObserveProductionFatPointerWireAfterTransport)
      .fail()
  }

  run rawFatPointerObservationWithoutPrecommitViolatesSafetyTest = {
    Init
      .then(AcceptProductionFatPointerWireIngress)
      .then(GossipProductionFatPointerWireAfterIngress)
      .then(RawObserveProductionFatPointerWireWithoutTransport)
      .then(all {
        assert(productionFatPointerWireObserved),
        assert(not(productionPrecommitEvidenceGossiped)),
        assert(not(Safety)),
        Stutter,
      })
  }

  run precommitEvidenceRequiresTenderlinkIngressTest = {
    Init
      .then(GossipProductionPrecommitEvidence)
      .fail()
  }

  run finalityRequiresCompleteProjectionTest = {
    Init
      .then(AcceptProductionBftBlockProposalIngress)
      .then(GossipProductionBftBlockProposalAfterIngress)
      .then(ObserveProductionBftBlockCandidateAfterTransport)
      .then(AcceptTenderlinkPrecommitIngressOnly)
      .then(AcceptProductionFatPointerWireIngress)
      .then(GossipProductionFatPointerWireAfterIngress)
      .then(GossipProductionPrecommitEvidence)
      .then(FinalizeProductionBlockAfterIngressProjection)
      .fail()
  }

  run rawFinalityWithoutProjectionViolatesSafetyTest = {
    Init
      .then(RawFinalizeProductionBlockWithoutProjection)
      .then(all {
        assert(finalizedProductionBlock),
        assert(not(productionBftBlockObserved)),
        assert(not(productionFatPointerWireObserved)),
        assert(not(Safety)),
        Stutter,
      })
  }

  run tenderlinkPrecommitDoesNotSatisfyProposalIngressTest = {
    Init
      .then(AcceptTenderlinkPrecommitIngressOnly)
      .then(all {
        assert(tenderlinkPrecommitIngressAccepted),
        assert(not(productionBftBlockProposalIngressAccepted)),
        assert(Safety),
        Stutter,
      })
  }

  run initialStateIsSafeTest = {
    Init
      .then(all {
        assert(Safety),
        Stutter,
      })
  }
}

module CrosslinkProductionFinalityIngressProjectionBridgeSafetyModel {
  import CrosslinkProductionFinalityIngressProjectionBridgeSafety.* from
    "./CrosslinkProductionFinalityIngressProjectionBridgeSafety"
  export CrosslinkProductionFinalityIngressProjectionBridgeSafety.*
}
