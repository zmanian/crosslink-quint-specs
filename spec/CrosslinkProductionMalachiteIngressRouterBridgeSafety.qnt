module CrosslinkProductionMalachiteIngressRouterBridgeSafety {
  /*
   Verifier-friendly production Malachite ingress-to-router bridge.

   The executable bridge composes the production ingress and Malachite router
   safety actions directly. This scalar projection keeps the same ordering
   obligations in a finite direct state machine for Apalache:

   production ingress -> downstream Malachite router record
   wrong-lane production ingress cannot satisfy a Malachite router prerequisite
   */

  var proposalIngressAccepted: bool
  var signedProposalIngressAccepted: bool
  var streamedProposalIngressAccepted: bool
  var polkaIngressAccepted: bool
  var roundIngressAccepted: bool
  var syncRequestIngressAccepted: bool
  var syncResponseIngressAccepted: bool
  var tenderlinkIngressAccepted: bool
  var dynamicSigmaIngressAccepted: bool
  var productionFinalityIngressAccepted: bool
  var proposalRouted: bool
  var signedProposalRouted: bool
  var streamedProposalRouted: bool
  var polkaRouted: bool
  var roundRouted: bool
  var syncRequestRouted: bool
  var syncResponseRouted: bool
  var bridgeProgress: int
  var bridgeFiredAction: str

  val WrongLaneIngressDoesNotSatisfyMalachiteRouter =
    if (
      (tenderlinkIngressAccepted or dynamicSigmaIngressAccepted or
        productionFinalityIngressAccepted) and
        not(proposalIngressAccepted) and
        not(signedProposalIngressAccepted) and
        not(streamedProposalIngressAccepted) and
        not(polkaIngressAccepted) and
        not(roundIngressAccepted) and
        not(syncRequestIngressAccepted) and
        not(syncResponseIngressAccepted)
    ) {
      not(proposalRouted) and
      not(signedProposalRouted) and
      not(streamedProposalRouted) and
      not(polkaRouted) and
      not(roundRouted) and
      not(syncRequestRouted) and
      not(syncResponseRouted)
    } else {
      true
    }

  val ProposalRoutesRequireProductionIngress =
    (
      not(proposalRouted) or proposalIngressAccepted
    ) and
    (
      not(signedProposalRouted) or signedProposalIngressAccepted
    ) and
    (
      not(streamedProposalRouted) or streamedProposalIngressAccepted
    )

  val LivenessRoutesRequireProductionIngress =
    (
      not(polkaRouted) or polkaIngressAccepted
    ) and
    (
      not(roundRouted) or roundIngressAccepted
    )

  val SyncRoutesRequireProductionIngress =
    (
      not(syncRequestRouted) or syncRequestIngressAccepted
    ) and
    (
      not(syncResponseRouted) or syncResponseIngressAccepted
    )

  val BridgeStateWellFormed =
    bridgeProgress >= 0 and
    bridgeProgress <= 17 and
    Set(
      "Init",
      "AcceptProposalIngress",
      "AcceptSignedProposalIngress",
      "AcceptStreamedProposalIngress",
      "AcceptPolkaIngress",
      "AcceptRoundIngress",
      "AcceptSyncRequestIngress",
      "AcceptSyncResponseIngress",
      "AcceptTenderlinkIngressOnly",
      "AcceptDynamicSigmaIngressOnly",
      "AcceptProductionFinalityIngressOnly",
      "RouteProposalAfterIngress",
      "RouteSignedProposalAfterIngress",
      "RouteStreamedProposalAfterIngress",
      "RoutePolkaAfterIngress",
      "RouteRoundAfterIngress",
      "RouteSyncRequestAfterIngress",
      "RouteSyncResponseAfterIngress",
      "RawRouteSignedProposalWithoutIngress",
      "RawRouteRoundWithoutIngress",
      "RawRouteSyncResponseWithoutIngress",
      "Stutter",
    ).contains(bridgeFiredAction)

  val Safety =
    BridgeStateWellFormed and
    WrongLaneIngressDoesNotSatisfyMalachiteRouter and
    ProposalRoutesRequireProductionIngress and
    LivenessRoutesRequireProductionIngress and
    SyncRoutesRequireProductionIngress

  action Init = all {
    proposalIngressAccepted' = false,
    signedProposalIngressAccepted' = false,
    streamedProposalIngressAccepted' = false,
    polkaIngressAccepted' = false,
    roundIngressAccepted' = false,
    syncRequestIngressAccepted' = false,
    syncResponseIngressAccepted' = false,
    tenderlinkIngressAccepted' = false,
    dynamicSigmaIngressAccepted' = false,
    productionFinalityIngressAccepted' = false,
    proposalRouted' = false,
    signedProposalRouted' = false,
    streamedProposalRouted' = false,
    polkaRouted' = false,
    roundRouted' = false,
    syncRequestRouted' = false,
    syncResponseRouted' = false,
    bridgeProgress' = 0,
    bridgeFiredAction' = "Init",
  }

  action KeepIngressState = all {
    proposalIngressAccepted' = proposalIngressAccepted,
    signedProposalIngressAccepted' = signedProposalIngressAccepted,
    streamedProposalIngressAccepted' = streamedProposalIngressAccepted,
    polkaIngressAccepted' = polkaIngressAccepted,
    roundIngressAccepted' = roundIngressAccepted,
    syncRequestIngressAccepted' = syncRequestIngressAccepted,
    syncResponseIngressAccepted' = syncResponseIngressAccepted,
    tenderlinkIngressAccepted' = tenderlinkIngressAccepted,
    dynamicSigmaIngressAccepted' = dynamicSigmaIngressAccepted,
    productionFinalityIngressAccepted' = productionFinalityIngressAccepted,
  }

  action KeepRouteState = all {
    proposalRouted' = proposalRouted,
    signedProposalRouted' = signedProposalRouted,
    streamedProposalRouted' = streamedProposalRouted,
    polkaRouted' = polkaRouted,
    roundRouted' = roundRouted,
    syncRequestRouted' = syncRequestRouted,
    syncResponseRouted' = syncResponseRouted,
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

  action AcceptProposalIngress: bool =
    all {
      not(proposalIngressAccepted),
      proposalIngressAccepted' = true,
      signedProposalIngressAccepted' = signedProposalIngressAccepted,
      streamedProposalIngressAccepted' = streamedProposalIngressAccepted,
      polkaIngressAccepted' = polkaIngressAccepted,
      roundIngressAccepted' = roundIngressAccepted,
      syncRequestIngressAccepted' = syncRequestIngressAccepted,
      syncResponseIngressAccepted' = syncResponseIngressAccepted,
      tenderlinkIngressAccepted' = tenderlinkIngressAccepted,
      dynamicSigmaIngressAccepted' = dynamicSigmaIngressAccepted,
      productionFinalityIngressAccepted' = productionFinalityIngressAccepted,
      KeepRouteState,
      Mark("AcceptProposalIngress"),
    }

  action AcceptSignedProposalIngress: bool =
    all {
      not(signedProposalIngressAccepted),
      proposalIngressAccepted' = proposalIngressAccepted,
      signedProposalIngressAccepted' = true,
      streamedProposalIngressAccepted' = streamedProposalIngressAccepted,
      polkaIngressAccepted' = polkaIngressAccepted,
      roundIngressAccepted' = roundIngressAccepted,
      syncRequestIngressAccepted' = syncRequestIngressAccepted,
      syncResponseIngressAccepted' = syncResponseIngressAccepted,
      tenderlinkIngressAccepted' = tenderlinkIngressAccepted,
      dynamicSigmaIngressAccepted' = dynamicSigmaIngressAccepted,
      productionFinalityIngressAccepted' = productionFinalityIngressAccepted,
      KeepRouteState,
      Mark("AcceptSignedProposalIngress"),
    }

  action AcceptStreamedProposalIngress: bool =
    all {
      not(streamedProposalIngressAccepted),
      proposalIngressAccepted' = proposalIngressAccepted,
      signedProposalIngressAccepted' = signedProposalIngressAccepted,
      streamedProposalIngressAccepted' = true,
      polkaIngressAccepted' = polkaIngressAccepted,
      roundIngressAccepted' = roundIngressAccepted,
      syncRequestIngressAccepted' = syncRequestIngressAccepted,
      syncResponseIngressAccepted' = syncResponseIngressAccepted,
      tenderlinkIngressAccepted' = tenderlinkIngressAccepted,
      dynamicSigmaIngressAccepted' = dynamicSigmaIngressAccepted,
      productionFinalityIngressAccepted' = productionFinalityIngressAccepted,
      KeepRouteState,
      Mark("AcceptStreamedProposalIngress"),
    }

  action AcceptPolkaIngress: bool =
    all {
      not(polkaIngressAccepted),
      proposalIngressAccepted' = proposalIngressAccepted,
      signedProposalIngressAccepted' = signedProposalIngressAccepted,
      streamedProposalIngressAccepted' = streamedProposalIngressAccepted,
      polkaIngressAccepted' = true,
      roundIngressAccepted' = roundIngressAccepted,
      syncRequestIngressAccepted' = syncRequestIngressAccepted,
      syncResponseIngressAccepted' = syncResponseIngressAccepted,
      tenderlinkIngressAccepted' = tenderlinkIngressAccepted,
      dynamicSigmaIngressAccepted' = dynamicSigmaIngressAccepted,
      productionFinalityIngressAccepted' = productionFinalityIngressAccepted,
      KeepRouteState,
      Mark("AcceptPolkaIngress"),
    }

  action AcceptRoundIngress: bool =
    all {
      not(roundIngressAccepted),
      proposalIngressAccepted' = proposalIngressAccepted,
      signedProposalIngressAccepted' = signedProposalIngressAccepted,
      streamedProposalIngressAccepted' = streamedProposalIngressAccepted,
      polkaIngressAccepted' = polkaIngressAccepted,
      roundIngressAccepted' = true,
      syncRequestIngressAccepted' = syncRequestIngressAccepted,
      syncResponseIngressAccepted' = syncResponseIngressAccepted,
      tenderlinkIngressAccepted' = tenderlinkIngressAccepted,
      dynamicSigmaIngressAccepted' = dynamicSigmaIngressAccepted,
      productionFinalityIngressAccepted' = productionFinalityIngressAccepted,
      KeepRouteState,
      Mark("AcceptRoundIngress"),
    }

  action AcceptSyncRequestIngress: bool =
    all {
      not(syncRequestIngressAccepted),
      proposalIngressAccepted' = proposalIngressAccepted,
      signedProposalIngressAccepted' = signedProposalIngressAccepted,
      streamedProposalIngressAccepted' = streamedProposalIngressAccepted,
      polkaIngressAccepted' = polkaIngressAccepted,
      roundIngressAccepted' = roundIngressAccepted,
      syncRequestIngressAccepted' = true,
      syncResponseIngressAccepted' = syncResponseIngressAccepted,
      tenderlinkIngressAccepted' = tenderlinkIngressAccepted,
      dynamicSigmaIngressAccepted' = dynamicSigmaIngressAccepted,
      productionFinalityIngressAccepted' = productionFinalityIngressAccepted,
      KeepRouteState,
      Mark("AcceptSyncRequestIngress"),
    }

  action AcceptSyncResponseIngress: bool =
    all {
      not(syncResponseIngressAccepted),
      proposalIngressAccepted' = proposalIngressAccepted,
      signedProposalIngressAccepted' = signedProposalIngressAccepted,
      streamedProposalIngressAccepted' = streamedProposalIngressAccepted,
      polkaIngressAccepted' = polkaIngressAccepted,
      roundIngressAccepted' = roundIngressAccepted,
      syncRequestIngressAccepted' = syncRequestIngressAccepted,
      syncResponseIngressAccepted' = true,
      tenderlinkIngressAccepted' = tenderlinkIngressAccepted,
      dynamicSigmaIngressAccepted' = dynamicSigmaIngressAccepted,
      productionFinalityIngressAccepted' = productionFinalityIngressAccepted,
      KeepRouteState,
      Mark("AcceptSyncResponseIngress"),
    }

  action AcceptTenderlinkIngressOnly: bool =
    all {
      not(tenderlinkIngressAccepted),
      proposalIngressAccepted' = proposalIngressAccepted,
      signedProposalIngressAccepted' = signedProposalIngressAccepted,
      streamedProposalIngressAccepted' = streamedProposalIngressAccepted,
      polkaIngressAccepted' = polkaIngressAccepted,
      roundIngressAccepted' = roundIngressAccepted,
      syncRequestIngressAccepted' = syncRequestIngressAccepted,
      syncResponseIngressAccepted' = syncResponseIngressAccepted,
      tenderlinkIngressAccepted' = true,
      dynamicSigmaIngressAccepted' = dynamicSigmaIngressAccepted,
      productionFinalityIngressAccepted' = productionFinalityIngressAccepted,
      KeepRouteState,
      Mark("AcceptTenderlinkIngressOnly"),
    }

  action AcceptDynamicSigmaIngressOnly: bool =
    all {
      not(dynamicSigmaIngressAccepted),
      proposalIngressAccepted' = proposalIngressAccepted,
      signedProposalIngressAccepted' = signedProposalIngressAccepted,
      streamedProposalIngressAccepted' = streamedProposalIngressAccepted,
      polkaIngressAccepted' = polkaIngressAccepted,
      roundIngressAccepted' = roundIngressAccepted,
      syncRequestIngressAccepted' = syncRequestIngressAccepted,
      syncResponseIngressAccepted' = syncResponseIngressAccepted,
      tenderlinkIngressAccepted' = tenderlinkIngressAccepted,
      dynamicSigmaIngressAccepted' = true,
      productionFinalityIngressAccepted' = productionFinalityIngressAccepted,
      KeepRouteState,
      Mark("AcceptDynamicSigmaIngressOnly"),
    }

  action AcceptProductionFinalityIngressOnly: bool =
    all {
      not(productionFinalityIngressAccepted),
      proposalIngressAccepted' = proposalIngressAccepted,
      signedProposalIngressAccepted' = signedProposalIngressAccepted,
      streamedProposalIngressAccepted' = streamedProposalIngressAccepted,
      polkaIngressAccepted' = polkaIngressAccepted,
      roundIngressAccepted' = roundIngressAccepted,
      syncRequestIngressAccepted' = syncRequestIngressAccepted,
      syncResponseIngressAccepted' = syncResponseIngressAccepted,
      tenderlinkIngressAccepted' = tenderlinkIngressAccepted,
      dynamicSigmaIngressAccepted' = dynamicSigmaIngressAccepted,
      productionFinalityIngressAccepted' = true,
      KeepRouteState,
      Mark("AcceptProductionFinalityIngressOnly"),
    }

  action RouteProposalAfterIngress: bool =
    all {
      proposalIngressAccepted,
      KeepIngressState,
      proposalRouted' = true,
      signedProposalRouted' = signedProposalRouted,
      streamedProposalRouted' = streamedProposalRouted,
      polkaRouted' = polkaRouted,
      roundRouted' = roundRouted,
      syncRequestRouted' = syncRequestRouted,
      syncResponseRouted' = syncResponseRouted,
      Mark("RouteProposalAfterIngress"),
    }

  action RouteSignedProposalAfterIngress: bool =
    all {
      signedProposalIngressAccepted,
      KeepIngressState,
      proposalRouted' = proposalRouted,
      signedProposalRouted' = true,
      streamedProposalRouted' = streamedProposalRouted,
      polkaRouted' = polkaRouted,
      roundRouted' = roundRouted,
      syncRequestRouted' = syncRequestRouted,
      syncResponseRouted' = syncResponseRouted,
      Mark("RouteSignedProposalAfterIngress"),
    }

  action RouteStreamedProposalAfterIngress: bool =
    all {
      streamedProposalIngressAccepted,
      KeepIngressState,
      proposalRouted' = proposalRouted,
      signedProposalRouted' = signedProposalRouted,
      streamedProposalRouted' = true,
      polkaRouted' = polkaRouted,
      roundRouted' = roundRouted,
      syncRequestRouted' = syncRequestRouted,
      syncResponseRouted' = syncResponseRouted,
      Mark("RouteStreamedProposalAfterIngress"),
    }

  action RoutePolkaAfterIngress: bool =
    all {
      polkaIngressAccepted,
      KeepIngressState,
      proposalRouted' = proposalRouted,
      signedProposalRouted' = signedProposalRouted,
      streamedProposalRouted' = streamedProposalRouted,
      polkaRouted' = true,
      roundRouted' = roundRouted,
      syncRequestRouted' = syncRequestRouted,
      syncResponseRouted' = syncResponseRouted,
      Mark("RoutePolkaAfterIngress"),
    }

  action RouteRoundAfterIngress: bool =
    all {
      roundIngressAccepted,
      KeepIngressState,
      proposalRouted' = proposalRouted,
      signedProposalRouted' = signedProposalRouted,
      streamedProposalRouted' = streamedProposalRouted,
      polkaRouted' = polkaRouted,
      roundRouted' = true,
      syncRequestRouted' = syncRequestRouted,
      syncResponseRouted' = syncResponseRouted,
      Mark("RouteRoundAfterIngress"),
    }

  action RouteSyncRequestAfterIngress: bool =
    all {
      syncRequestIngressAccepted,
      KeepIngressState,
      proposalRouted' = proposalRouted,
      signedProposalRouted' = signedProposalRouted,
      streamedProposalRouted' = streamedProposalRouted,
      polkaRouted' = polkaRouted,
      roundRouted' = roundRouted,
      syncRequestRouted' = true,
      syncResponseRouted' = syncResponseRouted,
      Mark("RouteSyncRequestAfterIngress"),
    }

  action RouteSyncResponseAfterIngress: bool =
    all {
      syncResponseIngressAccepted,
      KeepIngressState,
      proposalRouted' = proposalRouted,
      signedProposalRouted' = signedProposalRouted,
      streamedProposalRouted' = streamedProposalRouted,
      polkaRouted' = polkaRouted,
      roundRouted' = roundRouted,
      syncRequestRouted' = syncRequestRouted,
      syncResponseRouted' = true,
      Mark("RouteSyncResponseAfterIngress"),
    }

  action RawRouteSignedProposalWithoutIngress: bool =
    all {
      not(signedProposalIngressAccepted),
      KeepIngressState,
      proposalRouted' = proposalRouted,
      signedProposalRouted' = true,
      streamedProposalRouted' = streamedProposalRouted,
      polkaRouted' = polkaRouted,
      roundRouted' = roundRouted,
      syncRequestRouted' = syncRequestRouted,
      syncResponseRouted' = syncResponseRouted,
      Mark("RawRouteSignedProposalWithoutIngress"),
    }

  action RawRouteRoundWithoutIngress: bool =
    all {
      not(roundIngressAccepted),
      KeepIngressState,
      proposalRouted' = proposalRouted,
      signedProposalRouted' = signedProposalRouted,
      streamedProposalRouted' = streamedProposalRouted,
      polkaRouted' = polkaRouted,
      roundRouted' = true,
      syncRequestRouted' = syncRequestRouted,
      syncResponseRouted' = syncResponseRouted,
      Mark("RawRouteRoundWithoutIngress"),
    }

  action RawRouteSyncResponseWithoutIngress: bool =
    all {
      not(syncResponseIngressAccepted),
      KeepIngressState,
      proposalRouted' = proposalRouted,
      signedProposalRouted' = signedProposalRouted,
      streamedProposalRouted' = streamedProposalRouted,
      polkaRouted' = polkaRouted,
      roundRouted' = roundRouted,
      syncRequestRouted' = syncRequestRouted,
      syncResponseRouted' = true,
      Mark("RawRouteSyncResponseWithoutIngress"),
    }

  action Stutter: bool = KeepState

  action Next: bool =
    any {
      AcceptProposalIngress,
      AcceptSignedProposalIngress,
      AcceptStreamedProposalIngress,
      AcceptPolkaIngress,
      AcceptRoundIngress,
      AcceptSyncRequestIngress,
      AcceptSyncResponseIngress,
      AcceptTenderlinkIngressOnly,
      AcceptDynamicSigmaIngressOnly,
      AcceptProductionFinalityIngressOnly,
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
      .then(AcceptProposalIngress)
      .then(AcceptSignedProposalIngress)
      .then(AcceptStreamedProposalIngress)
      .then(RouteProposalAfterIngress)
      .then(RouteSignedProposalAfterIngress)
      .then(RouteStreamedProposalAfterIngress)
      .then(all {
        assert(proposalRouted),
        assert(signedProposalRouted),
        assert(streamedProposalRouted),
        assert(Safety),
        Stutter,
      })
  }

  run routesMalachiteLivenessAndSyncAfterProductionIngressTest = {
    Init
      .then(AcceptPolkaIngress)
      .then(AcceptRoundIngress)
      .then(AcceptSyncRequestIngress)
      .then(AcceptSyncResponseIngress)
      .then(RoutePolkaAfterIngress)
      .then(RouteRoundAfterIngress)
      .then(RouteSyncRequestAfterIngress)
      .then(RouteSyncResponseAfterIngress)
      .then(all {
        assert(polkaRouted),
        assert(roundRouted),
        assert(syncRequestRouted),
        assert(syncResponseRouted),
        assert(Safety),
        Stutter,
      })
  }

  run tenderlinkIngressDoesNotSatisfyMalachiteRouterTest = {
    Init
      .then(AcceptTenderlinkIngressOnly)
      .then(all {
        assert(tenderlinkIngressAccepted),
        assert(not(proposalRouted)),
        assert(not(signedProposalRouted)),
        assert(not(streamedProposalRouted)),
        assert(not(polkaRouted)),
        assert(not(roundRouted)),
        assert(not(syncRequestRouted)),
        assert(not(syncResponseRouted)),
        assert(Safety),
        Stutter,
      })
  }

  run dynamicSigmaIngressDoesNotSatisfyMalachiteRouterTest = {
    Init
      .then(AcceptDynamicSigmaIngressOnly)
      .then(all {
        assert(dynamicSigmaIngressAccepted),
        assert(not(proposalRouted)),
        assert(not(signedProposalRouted)),
        assert(not(streamedProposalRouted)),
        assert(not(polkaRouted)),
        assert(not(roundRouted)),
        assert(not(syncRequestRouted)),
        assert(not(syncResponseRouted)),
        assert(Safety),
        Stutter,
      })
  }

  run productionFinalityIngressDoesNotSatisfyMalachiteRouterTest = {
    Init
      .then(AcceptProductionFinalityIngressOnly)
      .then(all {
        assert(productionFinalityIngressAccepted),
        assert(not(proposalRouted)),
        assert(not(signedProposalRouted)),
        assert(not(streamedProposalRouted)),
        assert(not(polkaRouted)),
        assert(not(roundRouted)),
        assert(not(syncRequestRouted)),
        assert(not(syncResponseRouted)),
        assert(Safety),
        Stutter,
      })
  }

  run rawProposalRouteWithoutIngressViolatesBridgeSafetyTest = {
    Init
      .then(RawRouteSignedProposalWithoutIngress)
      .then(all {
        assert(not(Safety)),
        Stutter,
      })
  }

  run rawLivenessRouteWithoutIngressViolatesBridgeSafetyTest = {
    Init
      .then(RawRouteRoundWithoutIngress)
      .then(all {
        assert(not(Safety)),
        Stutter,
      })
  }

  run rawSyncRouteWithoutIngressViolatesBridgeSafetyTest = {
    Init
      .then(RawRouteSyncResponseWithoutIngress)
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

module CrosslinkProductionMalachiteIngressRouterBridgeSafetyModel {
  import CrosslinkProductionMalachiteIngressRouterBridgeSafety.* from
    "./CrosslinkProductionMalachiteIngressRouterBridgeSafety"
  export CrosslinkProductionMalachiteIngressRouterBridgeSafety.*
}
