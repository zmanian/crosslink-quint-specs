module CrosslinkProductionFinalityTenderlinkEvidenceBridge {
  /*
   Production finality precommit-evidence handoff.

   This is a verifier-friendly scalar projection of the handoff between:

   - CrosslinkProductionTenderlinkIngressRouterBridgeSafety.qnt, which routes
     accepted production Tenderlink value-precommit-certificate ingress to the
     downstream Tenderlink router consensus lane; and
   - CrosslinkProductionFinalityIngressBridge.qnt /
     CrosslinkProductionFinalityIngressProjectionBridgeSafety.qnt, which consume
     that certificate before production finality precommit evidence appears.

   The checked ordering is:

   production Tenderlink ingress -> Tenderlink router value-precommit certificate
     -> production finality precommit evidence
   */

  var valuePrecommitCertificateIngressAccepted: bool
  var valuePrecommitCertificateRouted: bool
  var productionFinalityIngressAccepted: bool
  var finalityPrecommitEvidenceProjected: bool
  var evidenceBridgeProgress: int
  var evidenceBridgeFiredAction: str

  val RouterRouteRequiresTenderlinkIngress =
    if (valuePrecommitCertificateRouted) {
      valuePrecommitCertificateIngressAccepted
    } else {
      true
    }

  val FinalityPrecommitEvidenceRequiresTenderlinkRouter =
    if (finalityPrecommitEvidenceProjected) {
      valuePrecommitCertificateRouted
    } else {
      true
    }

  val WrongLaneIngressDoesNotProjectFinalityEvidence =
    if (
      productionFinalityIngressAccepted and
      not(valuePrecommitCertificateRouted)
    ) {
      not(finalityPrecommitEvidenceProjected)
    } else {
      true
    }

  val EvidenceBridgeStateWellFormed =
    evidenceBridgeProgress >= 0 and
    evidenceBridgeProgress <= 4 and
    Set(
      "Init",
      "AcceptTenderlinkValuePrecommitCertificateIngress",
      "RouteTenderlinkValuePrecommitCertificate",
      "ProjectFinalityPrecommitEvidenceAfterTenderlinkRouter",
      "AcceptProductionFinalityIngressOnly",
      "RawRouteTenderlinkValuePrecommitCertificate",
      "RawProjectFinalityPrecommitEvidence",
      "Stutter",
    ).contains(evidenceBridgeFiredAction)

  val Safety =
    EvidenceBridgeStateWellFormed and
    RouterRouteRequiresTenderlinkIngress and
    FinalityPrecommitEvidenceRequiresTenderlinkRouter and
    WrongLaneIngressDoesNotProjectFinalityEvidence

  action Init = all {
    valuePrecommitCertificateIngressAccepted' = false,
    valuePrecommitCertificateRouted' = false,
    productionFinalityIngressAccepted' = false,
    finalityPrecommitEvidenceProjected' = false,
    evidenceBridgeProgress' = 0,
    evidenceBridgeFiredAction' = "Init",
  }

  action KeepState = all {
    valuePrecommitCertificateIngressAccepted' =
      valuePrecommitCertificateIngressAccepted,
    valuePrecommitCertificateRouted' = valuePrecommitCertificateRouted,
    productionFinalityIngressAccepted' = productionFinalityIngressAccepted,
    finalityPrecommitEvidenceProjected' = finalityPrecommitEvidenceProjected,
    evidenceBridgeProgress' = evidenceBridgeProgress,
    evidenceBridgeFiredAction' = evidenceBridgeFiredAction,
  }

  action Mark(actionName: str): bool = all {
    evidenceBridgeProgress' = evidenceBridgeProgress + 1,
    evidenceBridgeFiredAction' = actionName,
  }

  action AcceptTenderlinkValuePrecommitCertificateIngress: bool =
    all {
      not(valuePrecommitCertificateIngressAccepted),
      valuePrecommitCertificateIngressAccepted' = true,
      valuePrecommitCertificateRouted' = valuePrecommitCertificateRouted,
      productionFinalityIngressAccepted' = productionFinalityIngressAccepted,
      finalityPrecommitEvidenceProjected' = finalityPrecommitEvidenceProjected,
      Mark("AcceptTenderlinkValuePrecommitCertificateIngress"),
    }

  action RouteTenderlinkValuePrecommitCertificate: bool =
    all {
      valuePrecommitCertificateIngressAccepted,
      not(valuePrecommitCertificateRouted),
      valuePrecommitCertificateIngressAccepted' =
        valuePrecommitCertificateIngressAccepted,
      valuePrecommitCertificateRouted' = true,
      productionFinalityIngressAccepted' = productionFinalityIngressAccepted,
      finalityPrecommitEvidenceProjected' = finalityPrecommitEvidenceProjected,
      Mark("RouteTenderlinkValuePrecommitCertificate"),
    }

  action AcceptProductionFinalityIngressOnly: bool =
    all {
      not(productionFinalityIngressAccepted),
      valuePrecommitCertificateIngressAccepted' =
        valuePrecommitCertificateIngressAccepted,
      valuePrecommitCertificateRouted' = valuePrecommitCertificateRouted,
      productionFinalityIngressAccepted' = true,
      finalityPrecommitEvidenceProjected' = finalityPrecommitEvidenceProjected,
      Mark("AcceptProductionFinalityIngressOnly"),
    }

  action ProjectFinalityPrecommitEvidenceAfterTenderlinkRouter: bool =
    all {
      valuePrecommitCertificateRouted,
      not(finalityPrecommitEvidenceProjected),
      valuePrecommitCertificateIngressAccepted' =
        valuePrecommitCertificateIngressAccepted,
      valuePrecommitCertificateRouted' = valuePrecommitCertificateRouted,
      productionFinalityIngressAccepted' = productionFinalityIngressAccepted,
      finalityPrecommitEvidenceProjected' = true,
      Mark("ProjectFinalityPrecommitEvidenceAfterTenderlinkRouter"),
    }

  action RawRouteTenderlinkValuePrecommitCertificate: bool =
    all {
      not(valuePrecommitCertificateRouted),
      valuePrecommitCertificateIngressAccepted' =
        valuePrecommitCertificateIngressAccepted,
      valuePrecommitCertificateRouted' = true,
      productionFinalityIngressAccepted' = productionFinalityIngressAccepted,
      finalityPrecommitEvidenceProjected' = finalityPrecommitEvidenceProjected,
      Mark("RawRouteTenderlinkValuePrecommitCertificate"),
    }

  action RawProjectFinalityPrecommitEvidence: bool =
    all {
      not(finalityPrecommitEvidenceProjected),
      valuePrecommitCertificateIngressAccepted' =
        valuePrecommitCertificateIngressAccepted,
      valuePrecommitCertificateRouted' = valuePrecommitCertificateRouted,
      productionFinalityIngressAccepted' = productionFinalityIngressAccepted,
      finalityPrecommitEvidenceProjected' = true,
      Mark("RawProjectFinalityPrecommitEvidence"),
    }

  action Stutter: bool = KeepState

  action Next: bool =
    any {
      AcceptTenderlinkValuePrecommitCertificateIngress,
      RouteTenderlinkValuePrecommitCertificate,
      AcceptProductionFinalityIngressOnly,
      ProjectFinalityPrecommitEvidenceAfterTenderlinkRouter,
      Stutter,
    }

  temporal EventuallyProjectsFinalityPrecommitEvidence =
    Next.weakFair(Set(evidenceBridgeProgress)).implies(eventually(
      valuePrecommitCertificateIngressAccepted and
      valuePrecommitCertificateRouted and
      finalityPrecommitEvidenceProjected
    ))
}

module CrosslinkProductionFinalityTenderlinkEvidenceBridgeTest {
  import CrosslinkProductionFinalityTenderlinkEvidenceBridge.* from
    "./CrosslinkProductionFinalityTenderlinkEvidenceBridge"
  export CrosslinkProductionFinalityTenderlinkEvidenceBridge.*

  run finalityPrecommitEvidenceFollowsTenderlinkRouterTest = {
    Init
      .then(AcceptTenderlinkValuePrecommitCertificateIngress)
      .then(RouteTenderlinkValuePrecommitCertificate)
      .then(ProjectFinalityPrecommitEvidenceAfterTenderlinkRouter)
      .then(all {
        assert(valuePrecommitCertificateIngressAccepted),
        assert(valuePrecommitCertificateRouted),
        assert(finalityPrecommitEvidenceProjected),
        assert(Safety),
        Stutter,
      })
  }

  run routerRouteRequiresTenderlinkIngressTest = {
    Init
      .then(RouteTenderlinkValuePrecommitCertificate)
      .fail()
  }

  run precommitEvidenceRequiresTenderlinkRouterRouteTest = {
    Init
      .then(AcceptTenderlinkValuePrecommitCertificateIngress)
      .then(ProjectFinalityPrecommitEvidenceAfterTenderlinkRouter)
      .fail()
  }

  run productionFinalityIngressDoesNotProjectTenderlinkEvidenceTest = {
    Init
      .then(AcceptProductionFinalityIngressOnly)
      .then(ProjectFinalityPrecommitEvidenceAfterTenderlinkRouter)
      .fail()
  }

  run rawRouterRouteWithoutTenderlinkIngressViolatesSafetyTest = {
    Init
      .then(RawRouteTenderlinkValuePrecommitCertificate)
      .then(all {
        assert(not(valuePrecommitCertificateIngressAccepted)),
        assert(not(Safety)),
        Stutter,
      })
  }

  run rawPrecommitEvidenceWithoutTenderlinkRouterViolatesSafetyTest = {
    Init
      .then(RawProjectFinalityPrecommitEvidence)
      .then(all {
        assert(not(valuePrecommitCertificateRouted)),
        assert(not(Safety)),
        Stutter,
      })
  }

  run wrongLaneIngressKeepsFinalityEvidenceUnprojectedTest = {
    Init
      .then(AcceptProductionFinalityIngressOnly)
      .then(all {
        assert(productionFinalityIngressAccepted),
        assert(not(valuePrecommitCertificateRouted)),
        assert(not(finalityPrecommitEvidenceProjected)),
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

module CrosslinkProductionFinalityTenderlinkEvidenceBridgeModel {
  import CrosslinkProductionFinalityTenderlinkEvidenceBridgeTest.* from
    "./CrosslinkProductionFinalityTenderlinkEvidenceBridge"
  export CrosslinkProductionFinalityTenderlinkEvidenceBridgeTest.*
}
