module CrosslinkProductionTenderlinkIngressRouterBridgeSafety {
  /*
   Verifier-friendly production Tenderlink ingress-to-router bridge.

   The executable bridge composes the production ingress and Tenderlink router
   safety actions directly. This scalar projection keeps the same ordering
   obligations in a finite direct state machine for Apalache:

   production ingress -> downstream Tenderlink router record
   wrong-lane production ingress cannot satisfy a Tenderlink router prerequisite
   */

  var proposalChunkIngressAccepted: bool
  var polPrevoteIngressAccepted: bool
  var mixedPrecommitIngressAccepted: bool
  var nilPrecommitCertificateIngressAccepted: bool
  var valuePrecommitCertificateIngressAccepted: bool
  var evidenceIngressAccepted: bool
  var knownPeerIngressAccepted: bool
  var statusIngressAccepted: bool
  var dynamicSigmaIngressAccepted: bool
  var productionFinalityIngressAccepted: bool
  var proposalChunkRouted: bool
  var polPrevoteRouted: bool
  var mixedPrecommitRouted: bool
  var nilPrecommitCertificateRouted: bool
  var valuePrecommitCertificateRouted: bool
  var evidenceRouted: bool
  var knownPeerRouted: bool
  var statusRouted: bool
  var bridgeProgress: int
  var bridgeFiredAction: str

  val WrongLaneIngressDoesNotSatisfyTenderlinkRouter =
    if (
      (dynamicSigmaIngressAccepted or productionFinalityIngressAccepted) and
        not(proposalChunkIngressAccepted) and
        not(polPrevoteIngressAccepted) and
        not(mixedPrecommitIngressAccepted) and
        not(nilPrecommitCertificateIngressAccepted) and
        not(valuePrecommitCertificateIngressAccepted) and
        not(evidenceIngressAccepted) and
        not(knownPeerIngressAccepted) and
        not(statusIngressAccepted)
    ) {
      not(proposalChunkRouted) and
      not(polPrevoteRouted) and
      not(mixedPrecommitRouted) and
      not(nilPrecommitCertificateRouted) and
      not(valuePrecommitCertificateRouted) and
      not(evidenceRouted) and
      not(knownPeerRouted) and
      not(statusRouted)
    } else {
      true
    }

  val ConsensusRoutesRequireProductionIngress =
    (
      not(proposalChunkRouted) or proposalChunkIngressAccepted
    ) and
    (
      not(polPrevoteRouted) or polPrevoteIngressAccepted
    ) and
    (
      not(mixedPrecommitRouted) or mixedPrecommitIngressAccepted
    ) and
    (
      not(nilPrecommitCertificateRouted) or
        nilPrecommitCertificateIngressAccepted
    ) and
    (
      not(valuePrecommitCertificateRouted) or
        valuePrecommitCertificateIngressAccepted
    )

  val NonConsensusRoutesRequireProductionIngress =
    (
      not(evidenceRouted) or evidenceIngressAccepted
    ) and
    (
      not(knownPeerRouted) or knownPeerIngressAccepted
    ) and
    (
      not(statusRouted) or statusIngressAccepted
    )

  val BridgeStateWellFormed =
    bridgeProgress >= 0 and
    bridgeProgress <= 18 and
    Set(
      "Init",
      "AcceptProposalChunkIngress",
      "AcceptPolPrevoteIngress",
      "AcceptMixedPrecommitIngress",
      "AcceptNilPrecommitCertificateIngress",
      "AcceptValuePrecommitCertificateIngress",
      "AcceptEvidenceIngress",
      "AcceptKnownPeerIngress",
      "AcceptStatusIngress",
      "AcceptDynamicSigmaIngressOnly",
      "AcceptProductionFinalityIngressOnly",
      "RouteProposalChunkAfterIngress",
      "RoutePolPrevoteAfterIngress",
      "RouteMixedPrecommitAfterIngress",
      "RouteNilPrecommitCertificateAfterIngress",
      "RouteValuePrecommitCertificateAfterIngress",
      "RouteEvidenceAfterIngress",
      "RouteKnownPeerAfterIngress",
      "RouteStatusAfterIngress",
      "RawRouteMixedPrecommitWithoutIngress",
      "RawRouteEvidenceWithoutIngress",
      "RawRouteKnownPeerWithoutIngress",
      "RawRouteStatusWithoutIngress",
      "Stutter",
    ).contains(bridgeFiredAction)

  val Safety =
    BridgeStateWellFormed and
    WrongLaneIngressDoesNotSatisfyTenderlinkRouter and
    ConsensusRoutesRequireProductionIngress and
    NonConsensusRoutesRequireProductionIngress

  action Init = all {
    proposalChunkIngressAccepted' = false,
    polPrevoteIngressAccepted' = false,
    mixedPrecommitIngressAccepted' = false,
    nilPrecommitCertificateIngressAccepted' = false,
    valuePrecommitCertificateIngressAccepted' = false,
    evidenceIngressAccepted' = false,
    knownPeerIngressAccepted' = false,
    statusIngressAccepted' = false,
    dynamicSigmaIngressAccepted' = false,
    productionFinalityIngressAccepted' = false,
    proposalChunkRouted' = false,
    polPrevoteRouted' = false,
    mixedPrecommitRouted' = false,
    nilPrecommitCertificateRouted' = false,
    valuePrecommitCertificateRouted' = false,
    evidenceRouted' = false,
    knownPeerRouted' = false,
    statusRouted' = false,
    bridgeProgress' = 0,
    bridgeFiredAction' = "Init",
  }

  action KeepIngressState = all {
    proposalChunkIngressAccepted' = proposalChunkIngressAccepted,
    polPrevoteIngressAccepted' = polPrevoteIngressAccepted,
    mixedPrecommitIngressAccepted' = mixedPrecommitIngressAccepted,
    nilPrecommitCertificateIngressAccepted' =
      nilPrecommitCertificateIngressAccepted,
    valuePrecommitCertificateIngressAccepted' =
      valuePrecommitCertificateIngressAccepted,
    evidenceIngressAccepted' = evidenceIngressAccepted,
    knownPeerIngressAccepted' = knownPeerIngressAccepted,
    statusIngressAccepted' = statusIngressAccepted,
    dynamicSigmaIngressAccepted' = dynamicSigmaIngressAccepted,
    productionFinalityIngressAccepted' = productionFinalityIngressAccepted,
  }

  action KeepRouteState = all {
    proposalChunkRouted' = proposalChunkRouted,
    polPrevoteRouted' = polPrevoteRouted,
    mixedPrecommitRouted' = mixedPrecommitRouted,
    nilPrecommitCertificateRouted' = nilPrecommitCertificateRouted,
    valuePrecommitCertificateRouted' = valuePrecommitCertificateRouted,
    evidenceRouted' = evidenceRouted,
    knownPeerRouted' = knownPeerRouted,
    statusRouted' = statusRouted,
  }

  action KeepState = all {
    KeepIngressState,
    KeepRouteState,
    bridgeProgress' = bridgeProgress,
    bridgeFiredAction' = bridgeFiredAction,
  }

  action Mark(actionName: str): bool = all {
    bridgeProgress' = bridgeProgress + 1,
    bridgeFiredAction' = actionName,
  }

  action AcceptProposalChunkIngress: bool =
    all {
      not(proposalChunkIngressAccepted),
      proposalChunkIngressAccepted' = true,
      polPrevoteIngressAccepted' = polPrevoteIngressAccepted,
      mixedPrecommitIngressAccepted' = mixedPrecommitIngressAccepted,
      nilPrecommitCertificateIngressAccepted' =
        nilPrecommitCertificateIngressAccepted,
      valuePrecommitCertificateIngressAccepted' =
        valuePrecommitCertificateIngressAccepted,
      evidenceIngressAccepted' = evidenceIngressAccepted,
      knownPeerIngressAccepted' = knownPeerIngressAccepted,
      statusIngressAccepted' = statusIngressAccepted,
      dynamicSigmaIngressAccepted' = dynamicSigmaIngressAccepted,
      productionFinalityIngressAccepted' = productionFinalityIngressAccepted,
      KeepRouteState,
      Mark("AcceptProposalChunkIngress"),
    }

  action AcceptPolPrevoteIngress: bool =
    all {
      not(polPrevoteIngressAccepted),
      proposalChunkIngressAccepted' = proposalChunkIngressAccepted,
      polPrevoteIngressAccepted' = true,
      mixedPrecommitIngressAccepted' = mixedPrecommitIngressAccepted,
      nilPrecommitCertificateIngressAccepted' =
        nilPrecommitCertificateIngressAccepted,
      valuePrecommitCertificateIngressAccepted' =
        valuePrecommitCertificateIngressAccepted,
      evidenceIngressAccepted' = evidenceIngressAccepted,
      knownPeerIngressAccepted' = knownPeerIngressAccepted,
      statusIngressAccepted' = statusIngressAccepted,
      dynamicSigmaIngressAccepted' = dynamicSigmaIngressAccepted,
      productionFinalityIngressAccepted' = productionFinalityIngressAccepted,
      KeepRouteState,
      Mark("AcceptPolPrevoteIngress"),
    }

  action AcceptMixedPrecommitIngress: bool =
    all {
      not(mixedPrecommitIngressAccepted),
      proposalChunkIngressAccepted' = proposalChunkIngressAccepted,
      polPrevoteIngressAccepted' = polPrevoteIngressAccepted,
      mixedPrecommitIngressAccepted' = true,
      nilPrecommitCertificateIngressAccepted' =
        nilPrecommitCertificateIngressAccepted,
      valuePrecommitCertificateIngressAccepted' =
        valuePrecommitCertificateIngressAccepted,
      evidenceIngressAccepted' = evidenceIngressAccepted,
      knownPeerIngressAccepted' = knownPeerIngressAccepted,
      statusIngressAccepted' = statusIngressAccepted,
      dynamicSigmaIngressAccepted' = dynamicSigmaIngressAccepted,
      productionFinalityIngressAccepted' = productionFinalityIngressAccepted,
      KeepRouteState,
      Mark("AcceptMixedPrecommitIngress"),
    }

  action AcceptNilPrecommitCertificateIngress: bool =
    all {
      not(nilPrecommitCertificateIngressAccepted),
      proposalChunkIngressAccepted' = proposalChunkIngressAccepted,
      polPrevoteIngressAccepted' = polPrevoteIngressAccepted,
      mixedPrecommitIngressAccepted' = mixedPrecommitIngressAccepted,
      nilPrecommitCertificateIngressAccepted' = true,
      valuePrecommitCertificateIngressAccepted' =
        valuePrecommitCertificateIngressAccepted,
      evidenceIngressAccepted' = evidenceIngressAccepted,
      knownPeerIngressAccepted' = knownPeerIngressAccepted,
      statusIngressAccepted' = statusIngressAccepted,
      dynamicSigmaIngressAccepted' = dynamicSigmaIngressAccepted,
      productionFinalityIngressAccepted' = productionFinalityIngressAccepted,
      KeepRouteState,
      Mark("AcceptNilPrecommitCertificateIngress"),
    }

  action AcceptValuePrecommitCertificateIngress: bool =
    all {
      not(valuePrecommitCertificateIngressAccepted),
      proposalChunkIngressAccepted' = proposalChunkIngressAccepted,
      polPrevoteIngressAccepted' = polPrevoteIngressAccepted,
      mixedPrecommitIngressAccepted' = mixedPrecommitIngressAccepted,
      nilPrecommitCertificateIngressAccepted' =
        nilPrecommitCertificateIngressAccepted,
      valuePrecommitCertificateIngressAccepted' = true,
      evidenceIngressAccepted' = evidenceIngressAccepted,
      knownPeerIngressAccepted' = knownPeerIngressAccepted,
      statusIngressAccepted' = statusIngressAccepted,
      dynamicSigmaIngressAccepted' = dynamicSigmaIngressAccepted,
      productionFinalityIngressAccepted' = productionFinalityIngressAccepted,
      KeepRouteState,
      Mark("AcceptValuePrecommitCertificateIngress"),
    }

  action AcceptEvidenceIngress: bool =
    all {
      not(evidenceIngressAccepted),
      proposalChunkIngressAccepted' = proposalChunkIngressAccepted,
      polPrevoteIngressAccepted' = polPrevoteIngressAccepted,
      mixedPrecommitIngressAccepted' = mixedPrecommitIngressAccepted,
      nilPrecommitCertificateIngressAccepted' =
        nilPrecommitCertificateIngressAccepted,
      valuePrecommitCertificateIngressAccepted' =
        valuePrecommitCertificateIngressAccepted,
      evidenceIngressAccepted' = true,
      knownPeerIngressAccepted' = knownPeerIngressAccepted,
      statusIngressAccepted' = statusIngressAccepted,
      dynamicSigmaIngressAccepted' = dynamicSigmaIngressAccepted,
      productionFinalityIngressAccepted' = productionFinalityIngressAccepted,
      KeepRouteState,
      Mark("AcceptEvidenceIngress"),
    }

  action AcceptKnownPeerIngress: bool =
    all {
      not(knownPeerIngressAccepted),
      proposalChunkIngressAccepted' = proposalChunkIngressAccepted,
      polPrevoteIngressAccepted' = polPrevoteIngressAccepted,
      mixedPrecommitIngressAccepted' = mixedPrecommitIngressAccepted,
      nilPrecommitCertificateIngressAccepted' =
        nilPrecommitCertificateIngressAccepted,
      valuePrecommitCertificateIngressAccepted' =
        valuePrecommitCertificateIngressAccepted,
      evidenceIngressAccepted' = evidenceIngressAccepted,
      knownPeerIngressAccepted' = true,
      statusIngressAccepted' = statusIngressAccepted,
      dynamicSigmaIngressAccepted' = dynamicSigmaIngressAccepted,
      productionFinalityIngressAccepted' = productionFinalityIngressAccepted,
      KeepRouteState,
      Mark("AcceptKnownPeerIngress"),
    }

  action AcceptStatusIngress: bool =
    all {
      not(statusIngressAccepted),
      proposalChunkIngressAccepted' = proposalChunkIngressAccepted,
      polPrevoteIngressAccepted' = polPrevoteIngressAccepted,
      mixedPrecommitIngressAccepted' = mixedPrecommitIngressAccepted,
      nilPrecommitCertificateIngressAccepted' =
        nilPrecommitCertificateIngressAccepted,
      valuePrecommitCertificateIngressAccepted' =
        valuePrecommitCertificateIngressAccepted,
      evidenceIngressAccepted' = evidenceIngressAccepted,
      knownPeerIngressAccepted' = knownPeerIngressAccepted,
      statusIngressAccepted' = true,
      dynamicSigmaIngressAccepted' = dynamicSigmaIngressAccepted,
      productionFinalityIngressAccepted' = productionFinalityIngressAccepted,
      KeepRouteState,
      Mark("AcceptStatusIngress"),
    }

  action AcceptDynamicSigmaIngressOnly: bool =
    all {
      not(dynamicSigmaIngressAccepted),
      proposalChunkIngressAccepted' = proposalChunkIngressAccepted,
      polPrevoteIngressAccepted' = polPrevoteIngressAccepted,
      mixedPrecommitIngressAccepted' = mixedPrecommitIngressAccepted,
      nilPrecommitCertificateIngressAccepted' =
        nilPrecommitCertificateIngressAccepted,
      valuePrecommitCertificateIngressAccepted' =
        valuePrecommitCertificateIngressAccepted,
      evidenceIngressAccepted' = evidenceIngressAccepted,
      knownPeerIngressAccepted' = knownPeerIngressAccepted,
      statusIngressAccepted' = statusIngressAccepted,
      dynamicSigmaIngressAccepted' = true,
      productionFinalityIngressAccepted' = productionFinalityIngressAccepted,
      KeepRouteState,
      Mark("AcceptDynamicSigmaIngressOnly"),
    }

  action AcceptProductionFinalityIngressOnly: bool =
    all {
      not(productionFinalityIngressAccepted),
      proposalChunkIngressAccepted' = proposalChunkIngressAccepted,
      polPrevoteIngressAccepted' = polPrevoteIngressAccepted,
      mixedPrecommitIngressAccepted' = mixedPrecommitIngressAccepted,
      nilPrecommitCertificateIngressAccepted' =
        nilPrecommitCertificateIngressAccepted,
      valuePrecommitCertificateIngressAccepted' =
        valuePrecommitCertificateIngressAccepted,
      evidenceIngressAccepted' = evidenceIngressAccepted,
      knownPeerIngressAccepted' = knownPeerIngressAccepted,
      statusIngressAccepted' = statusIngressAccepted,
      dynamicSigmaIngressAccepted' = dynamicSigmaIngressAccepted,
      productionFinalityIngressAccepted' = true,
      KeepRouteState,
      Mark("AcceptProductionFinalityIngressOnly"),
    }

  action RouteProposalChunkAfterIngress: bool =
    all {
      proposalChunkIngressAccepted,
      KeepIngressState,
      proposalChunkRouted' = true,
      polPrevoteRouted' = polPrevoteRouted,
      mixedPrecommitRouted' = mixedPrecommitRouted,
      nilPrecommitCertificateRouted' = nilPrecommitCertificateRouted,
      valuePrecommitCertificateRouted' = valuePrecommitCertificateRouted,
      evidenceRouted' = evidenceRouted,
      knownPeerRouted' = knownPeerRouted,
      statusRouted' = statusRouted,
      Mark("RouteProposalChunkAfterIngress"),
    }

  action RoutePolPrevoteAfterIngress: bool =
    all {
      polPrevoteIngressAccepted,
      KeepIngressState,
      proposalChunkRouted' = proposalChunkRouted,
      polPrevoteRouted' = true,
      mixedPrecommitRouted' = mixedPrecommitRouted,
      nilPrecommitCertificateRouted' = nilPrecommitCertificateRouted,
      valuePrecommitCertificateRouted' = valuePrecommitCertificateRouted,
      evidenceRouted' = evidenceRouted,
      knownPeerRouted' = knownPeerRouted,
      statusRouted' = statusRouted,
      Mark("RoutePolPrevoteAfterIngress"),
    }

  action RouteMixedPrecommitAfterIngress: bool =
    all {
      mixedPrecommitIngressAccepted,
      KeepIngressState,
      proposalChunkRouted' = proposalChunkRouted,
      polPrevoteRouted' = polPrevoteRouted,
      mixedPrecommitRouted' = true,
      nilPrecommitCertificateRouted' = nilPrecommitCertificateRouted,
      valuePrecommitCertificateRouted' = valuePrecommitCertificateRouted,
      evidenceRouted' = evidenceRouted,
      knownPeerRouted' = knownPeerRouted,
      statusRouted' = statusRouted,
      Mark("RouteMixedPrecommitAfterIngress"),
    }

  action RouteNilPrecommitCertificateAfterIngress: bool =
    all {
      nilPrecommitCertificateIngressAccepted,
      KeepIngressState,
      proposalChunkRouted' = proposalChunkRouted,
      polPrevoteRouted' = polPrevoteRouted,
      mixedPrecommitRouted' = mixedPrecommitRouted,
      nilPrecommitCertificateRouted' = true,
      valuePrecommitCertificateRouted' = valuePrecommitCertificateRouted,
      evidenceRouted' = evidenceRouted,
      knownPeerRouted' = knownPeerRouted,
      statusRouted' = statusRouted,
      Mark("RouteNilPrecommitCertificateAfterIngress"),
    }

  action RouteValuePrecommitCertificateAfterIngress: bool =
    all {
      valuePrecommitCertificateIngressAccepted,
      KeepIngressState,
      proposalChunkRouted' = proposalChunkRouted,
      polPrevoteRouted' = polPrevoteRouted,
      mixedPrecommitRouted' = mixedPrecommitRouted,
      nilPrecommitCertificateRouted' = nilPrecommitCertificateRouted,
      valuePrecommitCertificateRouted' = true,
      evidenceRouted' = evidenceRouted,
      knownPeerRouted' = knownPeerRouted,
      statusRouted' = statusRouted,
      Mark("RouteValuePrecommitCertificateAfterIngress"),
    }

  action RouteEvidenceAfterIngress: bool =
    all {
      evidenceIngressAccepted,
      KeepIngressState,
      proposalChunkRouted' = proposalChunkRouted,
      polPrevoteRouted' = polPrevoteRouted,
      mixedPrecommitRouted' = mixedPrecommitRouted,
      nilPrecommitCertificateRouted' = nilPrecommitCertificateRouted,
      valuePrecommitCertificateRouted' = valuePrecommitCertificateRouted,
      evidenceRouted' = true,
      knownPeerRouted' = knownPeerRouted,
      statusRouted' = statusRouted,
      Mark("RouteEvidenceAfterIngress"),
    }

  action RouteKnownPeerAfterIngress: bool =
    all {
      knownPeerIngressAccepted,
      KeepIngressState,
      proposalChunkRouted' = proposalChunkRouted,
      polPrevoteRouted' = polPrevoteRouted,
      mixedPrecommitRouted' = mixedPrecommitRouted,
      nilPrecommitCertificateRouted' = nilPrecommitCertificateRouted,
      valuePrecommitCertificateRouted' = valuePrecommitCertificateRouted,
      evidenceRouted' = evidenceRouted,
      knownPeerRouted' = true,
      statusRouted' = statusRouted,
      Mark("RouteKnownPeerAfterIngress"),
    }

  action RouteStatusAfterIngress: bool =
    all {
      statusIngressAccepted,
      KeepIngressState,
      proposalChunkRouted' = proposalChunkRouted,
      polPrevoteRouted' = polPrevoteRouted,
      mixedPrecommitRouted' = mixedPrecommitRouted,
      nilPrecommitCertificateRouted' = nilPrecommitCertificateRouted,
      valuePrecommitCertificateRouted' = valuePrecommitCertificateRouted,
      evidenceRouted' = evidenceRouted,
      knownPeerRouted' = knownPeerRouted,
      statusRouted' = true,
      Mark("RouteStatusAfterIngress"),
    }

  action RawRouteMixedPrecommitWithoutIngress: bool =
    all {
      not(mixedPrecommitIngressAccepted),
      KeepIngressState,
      proposalChunkRouted' = proposalChunkRouted,
      polPrevoteRouted' = polPrevoteRouted,
      mixedPrecommitRouted' = true,
      nilPrecommitCertificateRouted' = nilPrecommitCertificateRouted,
      valuePrecommitCertificateRouted' = valuePrecommitCertificateRouted,
      evidenceRouted' = evidenceRouted,
      knownPeerRouted' = knownPeerRouted,
      statusRouted' = statusRouted,
      Mark("RawRouteMixedPrecommitWithoutIngress"),
    }

  action RawRouteEvidenceWithoutIngress: bool =
    all {
      not(evidenceIngressAccepted),
      KeepIngressState,
      proposalChunkRouted' = proposalChunkRouted,
      polPrevoteRouted' = polPrevoteRouted,
      mixedPrecommitRouted' = mixedPrecommitRouted,
      nilPrecommitCertificateRouted' = nilPrecommitCertificateRouted,
      valuePrecommitCertificateRouted' = valuePrecommitCertificateRouted,
      evidenceRouted' = true,
      knownPeerRouted' = knownPeerRouted,
      statusRouted' = statusRouted,
      Mark("RawRouteEvidenceWithoutIngress"),
    }

  action RawRouteKnownPeerWithoutIngress: bool =
    all {
      not(knownPeerIngressAccepted),
      KeepIngressState,
      proposalChunkRouted' = proposalChunkRouted,
      polPrevoteRouted' = polPrevoteRouted,
      mixedPrecommitRouted' = mixedPrecommitRouted,
      nilPrecommitCertificateRouted' = nilPrecommitCertificateRouted,
      valuePrecommitCertificateRouted' = valuePrecommitCertificateRouted,
      evidenceRouted' = evidenceRouted,
      knownPeerRouted' = true,
      statusRouted' = statusRouted,
      Mark("RawRouteKnownPeerWithoutIngress"),
    }

  action RawRouteStatusWithoutIngress: bool =
    all {
      not(statusIngressAccepted),
      KeepIngressState,
      proposalChunkRouted' = proposalChunkRouted,
      polPrevoteRouted' = polPrevoteRouted,
      mixedPrecommitRouted' = mixedPrecommitRouted,
      nilPrecommitCertificateRouted' = nilPrecommitCertificateRouted,
      valuePrecommitCertificateRouted' = valuePrecommitCertificateRouted,
      evidenceRouted' = evidenceRouted,
      knownPeerRouted' = knownPeerRouted,
      statusRouted' = true,
      Mark("RawRouteStatusWithoutIngress"),
    }

  action Stutter: bool = KeepState

  action Next: bool =
    any {
      AcceptProposalChunkIngress,
      AcceptPolPrevoteIngress,
      AcceptMixedPrecommitIngress,
      AcceptNilPrecommitCertificateIngress,
      AcceptValuePrecommitCertificateIngress,
      AcceptEvidenceIngress,
      AcceptKnownPeerIngress,
      AcceptStatusIngress,
      AcceptDynamicSigmaIngressOnly,
      AcceptProductionFinalityIngressOnly,
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
      .then(AcceptProposalChunkIngress)
      .then(AcceptPolPrevoteIngress)
      .then(AcceptMixedPrecommitIngress)
      .then(AcceptNilPrecommitCertificateIngress)
      .then(AcceptValuePrecommitCertificateIngress)
      .then(RouteProposalChunkAfterIngress)
      .then(RoutePolPrevoteAfterIngress)
      .then(RouteMixedPrecommitAfterIngress)
      .then(RouteNilPrecommitCertificateAfterIngress)
      .then(RouteValuePrecommitCertificateAfterIngress)
      .then(all {
        assert(proposalChunkRouted),
        assert(polPrevoteRouted),
        assert(mixedPrecommitRouted),
        assert(nilPrecommitCertificateRouted),
        assert(valuePrecommitCertificateRouted),
        assert(Safety),
        Stutter,
      })
  }

  run routesTenderlinkEvidenceKnownPeerAndStatusAfterProductionIngressTest = {
    Init
      .then(AcceptEvidenceIngress)
      .then(AcceptKnownPeerIngress)
      .then(AcceptStatusIngress)
      .then(RouteEvidenceAfterIngress)
      .then(RouteKnownPeerAfterIngress)
      .then(RouteStatusAfterIngress)
      .then(all {
        assert(evidenceRouted),
        assert(knownPeerRouted),
        assert(statusRouted),
        assert(Safety),
        Stutter,
      })
  }

  run dynamicSigmaIngressDoesNotSatisfyTenderlinkRouterTest = {
    Init
      .then(AcceptDynamicSigmaIngressOnly)
      .then(all {
        assert(dynamicSigmaIngressAccepted),
        assert(not(proposalChunkRouted)),
        assert(not(polPrevoteRouted)),
        assert(not(mixedPrecommitRouted)),
        assert(not(nilPrecommitCertificateRouted)),
        assert(not(valuePrecommitCertificateRouted)),
        assert(not(evidenceRouted)),
        assert(not(knownPeerRouted)),
        assert(not(statusRouted)),
        assert(Safety),
        Stutter,
      })
  }

  run productionFinalityIngressDoesNotSatisfyTenderlinkRouterTest = {
    Init
      .then(AcceptProductionFinalityIngressOnly)
      .then(all {
        assert(productionFinalityIngressAccepted),
        assert(not(proposalChunkRouted)),
        assert(not(polPrevoteRouted)),
        assert(not(mixedPrecommitRouted)),
        assert(not(nilPrecommitCertificateRouted)),
        assert(not(valuePrecommitCertificateRouted)),
        assert(not(evidenceRouted)),
        assert(not(knownPeerRouted)),
        assert(not(statusRouted)),
        assert(Safety),
        Stutter,
      })
  }

  run rawConsensusRouteWithoutIngressViolatesBridgeSafetyTest = {
    Init
      .then(RawRouteMixedPrecommitWithoutIngress)
      .then(all {
        assert(not(Safety)),
        Stutter,
      })
  }

  run rawEvidenceRouteWithoutIngressViolatesBridgeSafetyTest = {
    Init
      .then(RawRouteEvidenceWithoutIngress)
      .then(all {
        assert(not(Safety)),
        Stutter,
      })
  }

  run rawKnownPeerRouteWithoutIngressViolatesBridgeSafetyTest = {
    Init
      .then(RawRouteKnownPeerWithoutIngress)
      .then(all {
        assert(not(Safety)),
        Stutter,
      })
  }

  run rawStatusRouteWithoutIngressViolatesBridgeSafetyTest = {
    Init
      .then(RawRouteStatusWithoutIngress)
      .then(all {
        assert(not(Safety)),
        Stutter,
      })
  }

  run safetyInitialTest = {
    Init
      .then(all {
        assert(Safety),
        Stutter,
      })
  }
}

module CrosslinkProductionTenderlinkIngressRouterBridgeSafetyModel {
  import CrosslinkProductionTenderlinkIngressRouterBridgeSafety.* from
    "./CrosslinkProductionTenderlinkIngressRouterBridgeSafety"
  export CrosslinkProductionTenderlinkIngressRouterBridgeSafety.*
}
