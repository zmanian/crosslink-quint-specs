module CrosslinkProductionDynamicSigmaPayloadIngressBridgeSafety {
  /*
   Verifier-friendly dynamic-sigma payload ingress bridge.

   CrosslinkProductionDynamicSigmaPayloadIngressBridge.qnt composes the
   production ingress and prototype decode actions directly, which the Rust
   backend can execute but Apalache cannot currently flatten. This scalar
   projection keeps the same bridge obligations in a direct state machine:

   ingress -> payload transport -> transported-payload acceptance -> decode
   ingress -> disabled-prototype rejection
   */

  pure val SelectedSigma = 3
  pure val NoDecodedConfirmationDepth = -1

  var dynamicSigmaPayloadIngressAccepted: bool
  var tenderlinkConsensusIngressAccepted: bool
  var productionFinalityIngressAccepted: bool
  var dynamicSigmaPayloadTransportObserved: bool
  var dynamicSigmaPayloadAccepted: bool
  var prototypeEnabledDynamicPayloadDecoded: bool
  var disabledDynamicPayloadRejected: bool
  var decodedConfirmationDepth: int
  var bridgeProgress: int
  var bridgeFiredAction: str

  val WrongLaneIngressDoesNotSatisfyDynamicPayloadIngress =
    if (
      (tenderlinkConsensusIngressAccepted or productionFinalityIngressAccepted)
        and not(dynamicSigmaPayloadIngressAccepted)
    ) {
      not(dynamicSigmaPayloadTransportObserved) and
      not(dynamicSigmaPayloadAccepted) and
      not(prototypeEnabledDynamicPayloadDecoded) and
      not(disabledDynamicPayloadRejected)
    } else {
      true
    }

  val TransportRequiresProductionIngress =
    if (dynamicSigmaPayloadTransportObserved) {
      dynamicSigmaPayloadIngressAccepted
    } else {
      true
    }

  val AcceptedTransportRequiresProductionIngress =
    if (dynamicSigmaPayloadAccepted) {
      dynamicSigmaPayloadIngressAccepted and
      dynamicSigmaPayloadTransportObserved
    } else {
      true
    }

  val DecodeRequiresIngressAndAcceptedTransport =
    if (prototypeEnabledDynamicPayloadDecoded) {
      dynamicSigmaPayloadIngressAccepted and
      dynamicSigmaPayloadTransportObserved and
      dynamicSigmaPayloadAccepted and
      decodedConfirmationDepth == SelectedSigma
    } else {
      decodedConfirmationDepth == NoDecodedConfirmationDepth or
      decodedConfirmationDepth == SelectedSigma
    }

  val DisabledPrototypeRejectionRequiresIngress =
    if (disabledDynamicPayloadRejected) {
      dynamicSigmaPayloadIngressAccepted
    } else {
      true
    }

  val BridgeStateWellFormed =
    bridgeProgress >= 0 and
    bridgeProgress <= 7 and
    Set(
      "Init",
      "AcceptDynamicSigmaPayloadIngress",
      "AcceptTenderlinkConsensusIngressOnly",
      "AcceptProductionFinalityIngressOnly",
      "GossipDynamicSigmaPayloadAfterIngress",
      "AcceptTransportedDynamicSigmaPayloadAfterIngress",
      "DecodeEnabledDynamicSigmaPayloadAfterIngressAndTransport",
      "RejectDisabledDynamicSigmaPayloadAfterIngress",
      "RawGossipDynamicSigmaPayloadWithoutIngress",
      "RawAcceptDynamicSigmaPayloadWithoutTransport",
      "RawDecodeEnabledDynamicSigmaPayloadWithoutIngress",
      "RawDecodeEnabledDynamicSigmaPayloadWithoutTransport",
      "RawRejectDisabledDynamicSigmaPayloadWithoutIngress",
      "Stutter",
    ).contains(bridgeFiredAction)

  val Safety =
    BridgeStateWellFormed and
    WrongLaneIngressDoesNotSatisfyDynamicPayloadIngress and
    TransportRequiresProductionIngress and
    AcceptedTransportRequiresProductionIngress and
    DecodeRequiresIngressAndAcceptedTransport and
    DisabledPrototypeRejectionRequiresIngress

  action Init = all {
    dynamicSigmaPayloadIngressAccepted' = false,
    tenderlinkConsensusIngressAccepted' = false,
    productionFinalityIngressAccepted' = false,
    dynamicSigmaPayloadTransportObserved' = false,
    dynamicSigmaPayloadAccepted' = false,
    prototypeEnabledDynamicPayloadDecoded' = false,
    disabledDynamicPayloadRejected' = false,
    decodedConfirmationDepth' = NoDecodedConfirmationDepth,
    bridgeProgress' = 0,
    bridgeFiredAction' = "Init",
  }

  action KeepIngressState = all {
    dynamicSigmaPayloadIngressAccepted' = dynamicSigmaPayloadIngressAccepted,
    tenderlinkConsensusIngressAccepted' = tenderlinkConsensusIngressAccepted,
    productionFinalityIngressAccepted' = productionFinalityIngressAccepted,
  }

  action KeepTransportState = all {
    dynamicSigmaPayloadTransportObserved' =
      dynamicSigmaPayloadTransportObserved,
    dynamicSigmaPayloadAccepted' = dynamicSigmaPayloadAccepted,
  }

  action KeepDecodeState = all {
    prototypeEnabledDynamicPayloadDecoded' =
      prototypeEnabledDynamicPayloadDecoded,
    disabledDynamicPayloadRejected' = disabledDynamicPayloadRejected,
    decodedConfirmationDepth' = decodedConfirmationDepth,
  }

  action KeepState = all {
    KeepIngressState,
    KeepTransportState,
    KeepDecodeState,
    bridgeProgress' = bridgeProgress,
    bridgeFiredAction' = bridgeFiredAction,
  }

  action Mark(actionName: str): bool = all {
    bridgeProgress' = bridgeProgress + 1,
    bridgeFiredAction' = actionName,
  }

  action AcceptDynamicSigmaPayloadIngress: bool =
    all {
      not(dynamicSigmaPayloadIngressAccepted),
      dynamicSigmaPayloadIngressAccepted' = true,
      tenderlinkConsensusIngressAccepted' = tenderlinkConsensusIngressAccepted,
      productionFinalityIngressAccepted' = productionFinalityIngressAccepted,
      KeepTransportState,
      KeepDecodeState,
      Mark("AcceptDynamicSigmaPayloadIngress"),
    }

  action AcceptTenderlinkConsensusIngressOnly: bool =
    all {
      not(tenderlinkConsensusIngressAccepted),
      dynamicSigmaPayloadIngressAccepted' = dynamicSigmaPayloadIngressAccepted,
      tenderlinkConsensusIngressAccepted' = true,
      productionFinalityIngressAccepted' = productionFinalityIngressAccepted,
      KeepTransportState,
      KeepDecodeState,
      Mark("AcceptTenderlinkConsensusIngressOnly"),
    }

  action AcceptProductionFinalityIngressOnly: bool =
    all {
      not(productionFinalityIngressAccepted),
      dynamicSigmaPayloadIngressAccepted' = dynamicSigmaPayloadIngressAccepted,
      tenderlinkConsensusIngressAccepted' = tenderlinkConsensusIngressAccepted,
      productionFinalityIngressAccepted' = true,
      KeepTransportState,
      KeepDecodeState,
      Mark("AcceptProductionFinalityIngressOnly"),
    }

  action GossipDynamicSigmaPayloadAfterIngress: bool =
    all {
      dynamicSigmaPayloadIngressAccepted,
      not(dynamicSigmaPayloadTransportObserved),
      KeepIngressState,
      dynamicSigmaPayloadTransportObserved' = true,
      dynamicSigmaPayloadAccepted' = dynamicSigmaPayloadAccepted,
      KeepDecodeState,
      Mark("GossipDynamicSigmaPayloadAfterIngress"),
    }

  action AcceptTransportedDynamicSigmaPayloadAfterIngress: bool =
    all {
      dynamicSigmaPayloadIngressAccepted,
      dynamicSigmaPayloadTransportObserved,
      not(dynamicSigmaPayloadAccepted),
      KeepIngressState,
      dynamicSigmaPayloadTransportObserved' =
        dynamicSigmaPayloadTransportObserved,
      dynamicSigmaPayloadAccepted' = true,
      KeepDecodeState,
      Mark("AcceptTransportedDynamicSigmaPayloadAfterIngress"),
    }

  action DecodeEnabledDynamicSigmaPayloadAfterIngressAndTransport: bool =
    all {
      dynamicSigmaPayloadIngressAccepted,
      dynamicSigmaPayloadTransportObserved,
      dynamicSigmaPayloadAccepted,
      not(prototypeEnabledDynamicPayloadDecoded),
      KeepIngressState,
      KeepTransportState,
      prototypeEnabledDynamicPayloadDecoded' = true,
      disabledDynamicPayloadRejected' = disabledDynamicPayloadRejected,
      decodedConfirmationDepth' = SelectedSigma,
      Mark("DecodeEnabledDynamicSigmaPayloadAfterIngressAndTransport"),
    }

  action RejectDisabledDynamicSigmaPayloadAfterIngress: bool =
    all {
      dynamicSigmaPayloadIngressAccepted,
      not(disabledDynamicPayloadRejected),
      KeepIngressState,
      KeepTransportState,
      prototypeEnabledDynamicPayloadDecoded' =
        prototypeEnabledDynamicPayloadDecoded,
      disabledDynamicPayloadRejected' = true,
      decodedConfirmationDepth' = decodedConfirmationDepth,
      Mark("RejectDisabledDynamicSigmaPayloadAfterIngress"),
    }

  action RawGossipDynamicSigmaPayloadWithoutIngress: bool =
    all {
      not(dynamicSigmaPayloadIngressAccepted),
      KeepIngressState,
      dynamicSigmaPayloadTransportObserved' = true,
      dynamicSigmaPayloadAccepted' = dynamicSigmaPayloadAccepted,
      KeepDecodeState,
      Mark("RawGossipDynamicSigmaPayloadWithoutIngress"),
    }

  action RawAcceptDynamicSigmaPayloadWithoutTransport: bool =
    all {
      not(dynamicSigmaPayloadTransportObserved),
      KeepIngressState,
      dynamicSigmaPayloadTransportObserved' =
        dynamicSigmaPayloadTransportObserved,
      dynamicSigmaPayloadAccepted' = true,
      KeepDecodeState,
      Mark("RawAcceptDynamicSigmaPayloadWithoutTransport"),
    }

  action RawDecodeEnabledDynamicSigmaPayloadWithoutIngress: bool =
    all {
      not(dynamicSigmaPayloadIngressAccepted),
      KeepIngressState,
      KeepTransportState,
      prototypeEnabledDynamicPayloadDecoded' = true,
      disabledDynamicPayloadRejected' = disabledDynamicPayloadRejected,
      decodedConfirmationDepth' = SelectedSigma,
      Mark("RawDecodeEnabledDynamicSigmaPayloadWithoutIngress"),
    }

  action RawDecodeEnabledDynamicSigmaPayloadWithoutTransport: bool =
    all {
      not(dynamicSigmaPayloadTransportObserved) or
        not(dynamicSigmaPayloadAccepted),
      KeepIngressState,
      KeepTransportState,
      prototypeEnabledDynamicPayloadDecoded' = true,
      disabledDynamicPayloadRejected' = disabledDynamicPayloadRejected,
      decodedConfirmationDepth' = SelectedSigma,
      Mark("RawDecodeEnabledDynamicSigmaPayloadWithoutTransport"),
    }

  action RawRejectDisabledDynamicSigmaPayloadWithoutIngress: bool =
    all {
      not(dynamicSigmaPayloadIngressAccepted),
      KeepIngressState,
      KeepTransportState,
      prototypeEnabledDynamicPayloadDecoded' =
        prototypeEnabledDynamicPayloadDecoded,
      disabledDynamicPayloadRejected' = true,
      decodedConfirmationDepth' = decodedConfirmationDepth,
      Mark("RawRejectDisabledDynamicSigmaPayloadWithoutIngress"),
    }

  action Stutter: bool =
    KeepState

  action Next: bool =
    any {
      AcceptDynamicSigmaPayloadIngress,
      AcceptTenderlinkConsensusIngressOnly,
      AcceptProductionFinalityIngressOnly,
      GossipDynamicSigmaPayloadAfterIngress,
      AcceptTransportedDynamicSigmaPayloadAfterIngress,
      DecodeEnabledDynamicSigmaPayloadAfterIngressAndTransport,
      RejectDisabledDynamicSigmaPayloadAfterIngress,
      Stutter,
    }

  run acceptedDynamicPayloadIngressCanDecodeTest = {
    Init
      .then(AcceptDynamicSigmaPayloadIngress)
      .then(GossipDynamicSigmaPayloadAfterIngress)
      .then(AcceptTransportedDynamicSigmaPayloadAfterIngress)
      .then(DecodeEnabledDynamicSigmaPayloadAfterIngressAndTransport)
      .then(all {
        assert(dynamicSigmaPayloadIngressAccepted),
        assert(dynamicSigmaPayloadTransportObserved),
        assert(dynamicSigmaPayloadAccepted),
        assert(prototypeEnabledDynamicPayloadDecoded),
        assert(Safety),
        Stutter,
      })
  }

  run disabledPrototypeRejectionRequiresIngressTest = {
    Init
      .then(AcceptDynamicSigmaPayloadIngress)
      .then(RejectDisabledDynamicSigmaPayloadAfterIngress)
      .then(all {
        assert(disabledDynamicPayloadRejected),
        assert(Safety),
        Stutter,
      })
  }

  run tenderlinkIngressDoesNotSatisfyDynamicPayloadTest = {
    Init
      .then(AcceptTenderlinkConsensusIngressOnly)
      .then(all {
        assert(not(dynamicSigmaPayloadIngressAccepted)),
        assert(Safety),
        Stutter,
      })
  }

  run productionFinalityIngressDoesNotSatisfyDynamicPayloadTest = {
    Init
      .then(AcceptProductionFinalityIngressOnly)
      .then(all {
        assert(not(dynamicSigmaPayloadIngressAccepted)),
        assert(Safety),
        Stutter,
      })
  }

  run rawGossipWithoutIngressViolatesSafetyTest = {
    Init
      .then(RawGossipDynamicSigmaPayloadWithoutIngress)
      .then(all {
        assert(not(Safety)),
        Stutter,
      })
  }

  run rawAcceptWithoutTransportViolatesSafetyTest = {
    Init
      .then(AcceptDynamicSigmaPayloadIngress)
      .then(RawAcceptDynamicSigmaPayloadWithoutTransport)
      .then(all {
        assert(not(Safety)),
        Stutter,
      })
  }

  run rawDecodeWithoutIngressViolatesSafetyTest = {
    Init
      .then(RawDecodeEnabledDynamicSigmaPayloadWithoutIngress)
      .then(all {
        assert(not(Safety)),
        Stutter,
      })
  }

  run rawDecodeWithoutTransportViolatesSafetyTest = {
    Init
      .then(AcceptDynamicSigmaPayloadIngress)
      .then(RawDecodeEnabledDynamicSigmaPayloadWithoutTransport)
      .then(all {
        assert(not(Safety)),
        Stutter,
      })
  }

  run rawDisabledRejectionWithoutIngressViolatesSafetyTest = {
    Init
      .then(RawRejectDisabledDynamicSigmaPayloadWithoutIngress)
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

module CrosslinkProductionDynamicSigmaPayloadIngressBridgeSafetyModel {
  import CrosslinkProductionDynamicSigmaPayloadIngressBridgeSafety.* from
    "./CrosslinkProductionDynamicSigmaPayloadIngressBridgeSafety"
  export CrosslinkProductionDynamicSigmaPayloadIngressBridgeSafety.*
}
