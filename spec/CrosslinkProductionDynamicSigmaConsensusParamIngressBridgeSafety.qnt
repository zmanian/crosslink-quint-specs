module CrosslinkProductionDynamicSigmaConsensusParamIngressBridgeSafety {
  /*
   Verifier-friendly dynamic-sigma consensus-param ingress bridge.

   CrosslinkProductionDynamicSigmaConsensusParamIngressBridge.qnt composes the
   production ingress and authenticated param transport actions directly. This
   scalar projection keeps the same bridge obligations in a direct state
   machine that Apalache can flatten:

   ingress -> signed param gossip -> quorum config installation
   wrong-lane ingress cannot satisfy the dynamic-sigma param prerequisite
   */

  pure val InitialSigma = 2
  pure val H1RaisedSigma = 3
  pure val H2RecoveredSigma = 2

  var h1DynamicSigmaParamIngressAccepted: bool
  var h2DynamicSigmaParamIngressAccepted: bool
  var tenderlinkConsensusIngressAccepted: bool
  var productionFinalityIngressAccepted: bool
  var h1AliceParamGossiped: bool
  var h1BobParamGossiped: bool
  var h2AliceParamGossiped: bool
  var h2BobParamGossiped: bool
  var h1ParamConfigInstalled: bool
  var h2ParamConfigInstalled: bool
  var configuredHeight: int
  var configuredSigmaAtH1: int
  var configuredSigmaAtH2: int
  var bridgeProgress: int
  var bridgeFiredAction: str

  val WrongLaneIngressDoesNotSatisfyDynamicSigmaParam =
    if (
      (tenderlinkConsensusIngressAccepted or productionFinalityIngressAccepted)
        and
        not(h1DynamicSigmaParamIngressAccepted) and
        not(h2DynamicSigmaParamIngressAccepted)
    ) {
      not(h1AliceParamGossiped) and
      not(h1BobParamGossiped) and
      not(h2AliceParamGossiped) and
      not(h2BobParamGossiped) and
      not(h1ParamConfigInstalled) and
      not(h2ParamConfigInstalled)
    } else {
      true
    }

  val H1ParamGossipRequiresIngress =
    if (h1AliceParamGossiped or h1BobParamGossiped) {
      h1DynamicSigmaParamIngressAccepted
    } else {
      true
    }

  val H2ParamGossipRequiresIngress =
    if (h2AliceParamGossiped or h2BobParamGossiped) {
      h2DynamicSigmaParamIngressAccepted
    } else {
      true
    }

  val H1ParamConfigRequiresIngressAndQuorum =
    if (h1ParamConfigInstalled) {
      h1DynamicSigmaParamIngressAccepted and
      h1AliceParamGossiped and
      h1BobParamGossiped and
      configuredHeight >= 1 and
      configuredSigmaAtH1 == H1RaisedSigma
    } else {
      configuredSigmaAtH1 == InitialSigma or
      configuredSigmaAtH1 == H1RaisedSigma
    }

  val H2ParamConfigRequiresIngressAndQuorum =
    if (h2ParamConfigInstalled) {
      h1ParamConfigInstalled and
      h2DynamicSigmaParamIngressAccepted and
      h2AliceParamGossiped and
      h2BobParamGossiped and
      configuredHeight >= 2 and
      configuredSigmaAtH2 == H2RecoveredSigma
    } else {
      configuredSigmaAtH2 == InitialSigma or
      configuredSigmaAtH2 == H2RecoveredSigma
    }

  val BridgeStateWellFormed =
    bridgeProgress >= 0 and
    bridgeProgress <= 8 and
    configuredHeight >= 0 and
    configuredHeight <= 2 and
    Set(
      "Init",
      "AcceptH1DynamicSigmaParamIngress",
      "AcceptH2DynamicSigmaParamIngress",
      "AcceptTenderlinkConsensusIngressOnly",
      "AcceptProductionFinalityIngressOnly",
      "GossipH1AliceParamAfterIngress",
      "GossipH1BobParamAfterIngress",
      "GossipH2AliceParamAfterIngress",
      "GossipH2BobParamAfterIngress",
      "InstallH1ParamConfigAfterIngressQuorum",
      "InstallH2ParamConfigAfterIngressQuorum",
      "RawGossipH1AliceParamWithoutIngress",
      "RawInstallH1ParamConfigWithoutIngress",
      "RawInstallH1ParamConfigWithoutQuorum",
      "RawInstallH2ParamConfigWithoutH1",
      "Stutter",
    ).contains(bridgeFiredAction)

  val Safety =
    BridgeStateWellFormed and
    WrongLaneIngressDoesNotSatisfyDynamicSigmaParam and
    H1ParamGossipRequiresIngress and
    H2ParamGossipRequiresIngress and
    H1ParamConfigRequiresIngressAndQuorum and
    H2ParamConfigRequiresIngressAndQuorum

  action Init = all {
    h1DynamicSigmaParamIngressAccepted' = false,
    h2DynamicSigmaParamIngressAccepted' = false,
    tenderlinkConsensusIngressAccepted' = false,
    productionFinalityIngressAccepted' = false,
    h1AliceParamGossiped' = false,
    h1BobParamGossiped' = false,
    h2AliceParamGossiped' = false,
    h2BobParamGossiped' = false,
    h1ParamConfigInstalled' = false,
    h2ParamConfigInstalled' = false,
    configuredHeight' = 0,
    configuredSigmaAtH1' = InitialSigma,
    configuredSigmaAtH2' = InitialSigma,
    bridgeProgress' = 0,
    bridgeFiredAction' = "Init",
  }

  action KeepIngressState = all {
    h1DynamicSigmaParamIngressAccepted' =
      h1DynamicSigmaParamIngressAccepted,
    h2DynamicSigmaParamIngressAccepted' =
      h2DynamicSigmaParamIngressAccepted,
    tenderlinkConsensusIngressAccepted' = tenderlinkConsensusIngressAccepted,
    productionFinalityIngressAccepted' = productionFinalityIngressAccepted,
  }

  action KeepGossipState = all {
    h1AliceParamGossiped' = h1AliceParamGossiped,
    h1BobParamGossiped' = h1BobParamGossiped,
    h2AliceParamGossiped' = h2AliceParamGossiped,
    h2BobParamGossiped' = h2BobParamGossiped,
  }

  action KeepConfigState = all {
    h1ParamConfigInstalled' = h1ParamConfigInstalled,
    h2ParamConfigInstalled' = h2ParamConfigInstalled,
    configuredHeight' = configuredHeight,
    configuredSigmaAtH1' = configuredSigmaAtH1,
    configuredSigmaAtH2' = configuredSigmaAtH2,
  }

  action KeepState = all {
    KeepIngressState,
    KeepGossipState,
    KeepConfigState,
    bridgeProgress' = bridgeProgress,
    bridgeFiredAction' = bridgeFiredAction,
  }

  action Mark(actionName: str): bool = all {
    bridgeProgress' = bridgeProgress + 1,
    bridgeFiredAction' = actionName,
  }

  action AcceptH1DynamicSigmaParamIngress: bool =
    all {
      not(h1DynamicSigmaParamIngressAccepted),
      h1DynamicSigmaParamIngressAccepted' = true,
      h2DynamicSigmaParamIngressAccepted' =
        h2DynamicSigmaParamIngressAccepted,
      tenderlinkConsensusIngressAccepted' = tenderlinkConsensusIngressAccepted,
      productionFinalityIngressAccepted' = productionFinalityIngressAccepted,
      KeepGossipState,
      KeepConfigState,
      Mark("AcceptH1DynamicSigmaParamIngress"),
    }

  action AcceptH2DynamicSigmaParamIngress: bool =
    all {
      not(h2DynamicSigmaParamIngressAccepted),
      h1DynamicSigmaParamIngressAccepted' =
        h1DynamicSigmaParamIngressAccepted,
      h2DynamicSigmaParamIngressAccepted' = true,
      tenderlinkConsensusIngressAccepted' = tenderlinkConsensusIngressAccepted,
      productionFinalityIngressAccepted' = productionFinalityIngressAccepted,
      KeepGossipState,
      KeepConfigState,
      Mark("AcceptH2DynamicSigmaParamIngress"),
    }

  action AcceptTenderlinkConsensusIngressOnly: bool =
    all {
      not(tenderlinkConsensusIngressAccepted),
      h1DynamicSigmaParamIngressAccepted' =
        h1DynamicSigmaParamIngressAccepted,
      h2DynamicSigmaParamIngressAccepted' =
        h2DynamicSigmaParamIngressAccepted,
      tenderlinkConsensusIngressAccepted' = true,
      productionFinalityIngressAccepted' = productionFinalityIngressAccepted,
      KeepGossipState,
      KeepConfigState,
      Mark("AcceptTenderlinkConsensusIngressOnly"),
    }

  action AcceptProductionFinalityIngressOnly: bool =
    all {
      not(productionFinalityIngressAccepted),
      h1DynamicSigmaParamIngressAccepted' =
        h1DynamicSigmaParamIngressAccepted,
      h2DynamicSigmaParamIngressAccepted' =
        h2DynamicSigmaParamIngressAccepted,
      tenderlinkConsensusIngressAccepted' = tenderlinkConsensusIngressAccepted,
      productionFinalityIngressAccepted' = true,
      KeepGossipState,
      KeepConfigState,
      Mark("AcceptProductionFinalityIngressOnly"),
    }

  action GossipH1AliceParamAfterIngress: bool =
    all {
      h1DynamicSigmaParamIngressAccepted,
      not(h1AliceParamGossiped),
      KeepIngressState,
      h1AliceParamGossiped' = true,
      h1BobParamGossiped' = h1BobParamGossiped,
      h2AliceParamGossiped' = h2AliceParamGossiped,
      h2BobParamGossiped' = h2BobParamGossiped,
      KeepConfigState,
      Mark("GossipH1AliceParamAfterIngress"),
    }

  action GossipH1BobParamAfterIngress: bool =
    all {
      h1DynamicSigmaParamIngressAccepted,
      not(h1BobParamGossiped),
      KeepIngressState,
      h1AliceParamGossiped' = h1AliceParamGossiped,
      h1BobParamGossiped' = true,
      h2AliceParamGossiped' = h2AliceParamGossiped,
      h2BobParamGossiped' = h2BobParamGossiped,
      KeepConfigState,
      Mark("GossipH1BobParamAfterIngress"),
    }

  action GossipH2AliceParamAfterIngress: bool =
    all {
      h2DynamicSigmaParamIngressAccepted,
      not(h2AliceParamGossiped),
      KeepIngressState,
      h1AliceParamGossiped' = h1AliceParamGossiped,
      h1BobParamGossiped' = h1BobParamGossiped,
      h2AliceParamGossiped' = true,
      h2BobParamGossiped' = h2BobParamGossiped,
      KeepConfigState,
      Mark("GossipH2AliceParamAfterIngress"),
    }

  action GossipH2BobParamAfterIngress: bool =
    all {
      h2DynamicSigmaParamIngressAccepted,
      not(h2BobParamGossiped),
      KeepIngressState,
      h1AliceParamGossiped' = h1AliceParamGossiped,
      h1BobParamGossiped' = h1BobParamGossiped,
      h2AliceParamGossiped' = h2AliceParamGossiped,
      h2BobParamGossiped' = true,
      KeepConfigState,
      Mark("GossipH2BobParamAfterIngress"),
    }

  action InstallH1ParamConfigAfterIngressQuorum: bool =
    all {
      h1DynamicSigmaParamIngressAccepted,
      h1AliceParamGossiped,
      h1BobParamGossiped,
      not(h1ParamConfigInstalled),
      KeepIngressState,
      KeepGossipState,
      h1ParamConfigInstalled' = true,
      h2ParamConfigInstalled' = h2ParamConfigInstalled,
      configuredHeight' = 1,
      configuredSigmaAtH1' = H1RaisedSigma,
      configuredSigmaAtH2' = configuredSigmaAtH2,
      Mark("InstallH1ParamConfigAfterIngressQuorum"),
    }

  action InstallH2ParamConfigAfterIngressQuorum: bool =
    all {
      h1ParamConfigInstalled,
      h2DynamicSigmaParamIngressAccepted,
      h2AliceParamGossiped,
      h2BobParamGossiped,
      not(h2ParamConfigInstalled),
      KeepIngressState,
      KeepGossipState,
      h1ParamConfigInstalled' = h1ParamConfigInstalled,
      h2ParamConfigInstalled' = true,
      configuredHeight' = 2,
      configuredSigmaAtH1' = configuredSigmaAtH1,
      configuredSigmaAtH2' = H2RecoveredSigma,
      Mark("InstallH2ParamConfigAfterIngressQuorum"),
    }

  action RawGossipH1AliceParamWithoutIngress: bool =
    all {
      not(h1DynamicSigmaParamIngressAccepted),
      KeepIngressState,
      h1AliceParamGossiped' = true,
      h1BobParamGossiped' = h1BobParamGossiped,
      h2AliceParamGossiped' = h2AliceParamGossiped,
      h2BobParamGossiped' = h2BobParamGossiped,
      KeepConfigState,
      Mark("RawGossipH1AliceParamWithoutIngress"),
    }

  action RawInstallH1ParamConfigWithoutIngress: bool =
    all {
      not(h1DynamicSigmaParamIngressAccepted),
      KeepIngressState,
      KeepGossipState,
      h1ParamConfigInstalled' = true,
      h2ParamConfigInstalled' = h2ParamConfigInstalled,
      configuredHeight' = 1,
      configuredSigmaAtH1' = H1RaisedSigma,
      configuredSigmaAtH2' = configuredSigmaAtH2,
      Mark("RawInstallH1ParamConfigWithoutIngress"),
    }

  action RawInstallH1ParamConfigWithoutQuorum: bool =
    all {
      h1DynamicSigmaParamIngressAccepted,
      not(h1AliceParamGossiped and h1BobParamGossiped),
      KeepIngressState,
      KeepGossipState,
      h1ParamConfigInstalled' = true,
      h2ParamConfigInstalled' = h2ParamConfigInstalled,
      configuredHeight' = 1,
      configuredSigmaAtH1' = H1RaisedSigma,
      configuredSigmaAtH2' = configuredSigmaAtH2,
      Mark("RawInstallH1ParamConfigWithoutQuorum"),
    }

  action RawInstallH2ParamConfigWithoutH1: bool =
    all {
      not(h1ParamConfigInstalled),
      h2DynamicSigmaParamIngressAccepted,
      h2AliceParamGossiped,
      h2BobParamGossiped,
      KeepIngressState,
      KeepGossipState,
      h1ParamConfigInstalled' = h1ParamConfigInstalled,
      h2ParamConfigInstalled' = true,
      configuredHeight' = 2,
      configuredSigmaAtH1' = configuredSigmaAtH1,
      configuredSigmaAtH2' = H2RecoveredSigma,
      Mark("RawInstallH2ParamConfigWithoutH1"),
    }

  action Stutter: bool =
    KeepState

  action Next: bool =
    any {
      AcceptH1DynamicSigmaParamIngress,
      AcceptH2DynamicSigmaParamIngress,
      AcceptTenderlinkConsensusIngressOnly,
      AcceptProductionFinalityIngressOnly,
      GossipH1AliceParamAfterIngress,
      GossipH1BobParamAfterIngress,
      GossipH2AliceParamAfterIngress,
      GossipH2BobParamAfterIngress,
      InstallH1ParamConfigAfterIngressQuorum,
      InstallH2ParamConfigAfterIngressQuorum,
      Stutter,
    }

  run acceptedH1ParamIngressCanInstallRaisedConfigTest = {
    Init
      .then(AcceptH1DynamicSigmaParamIngress)
      .then(GossipH1AliceParamAfterIngress)
      .then(GossipH1BobParamAfterIngress)
      .then(InstallH1ParamConfigAfterIngressQuorum)
      .then(all {
        assert(h1DynamicSigmaParamIngressAccepted),
        assert(h1ParamConfigInstalled),
        assert(configuredSigmaAtH1 == H1RaisedSigma),
        assert(Safety),
        Stutter,
      })
  }

  run acceptedH2ParamIngressCanInstallRecoveredConfigTest = {
    Init
      .then(AcceptH1DynamicSigmaParamIngress)
      .then(GossipH1AliceParamAfterIngress)
      .then(GossipH1BobParamAfterIngress)
      .then(InstallH1ParamConfigAfterIngressQuorum)
      .then(AcceptH2DynamicSigmaParamIngress)
      .then(GossipH2AliceParamAfterIngress)
      .then(GossipH2BobParamAfterIngress)
      .then(InstallH2ParamConfigAfterIngressQuorum)
      .then(all {
        assert(h2DynamicSigmaParamIngressAccepted),
        assert(h2ParamConfigInstalled),
        assert(configuredHeight == 2),
        assert(configuredSigmaAtH2 == H2RecoveredSigma),
        assert(Safety),
        Stutter,
      })
  }

  run tenderlinkIngressDoesNotSatisfyDynamicSigmaParamTest = {
    Init
      .then(AcceptTenderlinkConsensusIngressOnly)
      .then(all {
        assert(not(h1DynamicSigmaParamIngressAccepted)),
        assert(Safety),
        Stutter,
      })
  }

  run productionFinalityIngressDoesNotSatisfyDynamicSigmaParamTest = {
    Init
      .then(AcceptProductionFinalityIngressOnly)
      .then(all {
        assert(not(h1DynamicSigmaParamIngressAccepted)),
        assert(Safety),
        Stutter,
      })
  }

  run rawGossipWithoutIngressViolatesSafetyTest = {
    Init
      .then(RawGossipH1AliceParamWithoutIngress)
      .then(all {
        assert(not(Safety)),
        Stutter,
      })
  }

  run rawInstallWithoutIngressViolatesSafetyTest = {
    Init
      .then(RawInstallH1ParamConfigWithoutIngress)
      .then(all {
        assert(not(Safety)),
        Stutter,
      })
  }

  run rawInstallWithoutQuorumViolatesSafetyTest = {
    Init
      .then(AcceptH1DynamicSigmaParamIngress)
      .then(RawInstallH1ParamConfigWithoutQuorum)
      .then(all {
        assert(not(Safety)),
        Stutter,
      })
  }

  run rawH2InstallWithoutH1ViolatesSafetyTest = {
    Init
      .then(AcceptH2DynamicSigmaParamIngress)
      .then(GossipH2AliceParamAfterIngress)
      .then(GossipH2BobParamAfterIngress)
      .then(RawInstallH2ParamConfigWithoutH1)
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

module CrosslinkProductionDynamicSigmaConsensusParamIngressBridgeSafetyModel {
  import CrosslinkProductionDynamicSigmaConsensusParamIngressBridgeSafety.* from
    "./CrosslinkProductionDynamicSigmaConsensusParamIngressBridgeSafety"
  export CrosslinkProductionDynamicSigmaConsensusParamIngressBridgeSafety.*
}
