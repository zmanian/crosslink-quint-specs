module CrosslinkProductionDynamicSigmaPayloadIngressBridge {
  /*
   Production dynamic-sigma payload ingress bridge.

   CrosslinkDynamicSigmaBftPayloadTransport.qnt pins the tagged dynamic-sigma
   BFT payload boundary, and CrosslinkDynamicSigmaPrototypeDecodeGate.qnt pins
   Zebra's prototype decode gate for those bytes. This bridge connects that
   payload path to the production gossip registry/ingress lane: a dynamic-sigma
   payload may be transported or decoded only after the node-local production
   ingress accepts the registry-valid dynamic-sigma BFT-payload envelope.
   */

  import CrosslinkProductionGossipIngress as Ingress from
    "./CrosslinkProductionGossipIngress"
  import CrosslinkDynamicSigmaPrototypeDecodeGateTest as Decode from
    "./CrosslinkDynamicSigmaPrototypeDecodeGate"

  var bridgeProgress: int
  var bridgeFiredAction: str

  def DynamicSigmaPayloadIngressAccepted: bool =
    Ingress::acceptedProductionDynamicSigmaBftPayload.contains(
      Ingress::DynamicSigmaBftPayloadEnvelope
    )

  def DynamicSigmaPayloadTransportAccepted: bool =
    Decode::acceptedDynamicSigmaBftPayload.contains(
      Decode::DynamicSigmaFixturePayloadEnvelope
    )

  def DynamicSigmaPayloadIngressMatchesDecodeFixture: bool =
    Ingress::DynamicSigmaBftPayloadFixtureMetadataCoherent and
    Decode::DynamicSigmaBftPayloadLayoutPinned and
    Ingress::DynamicSigmaProposalTopic ==
      Decode::CrosslinkDynamicSigmaProposalTopic and
    Ingress::DynamicSigmaBftPayloadKind ==
      Decode::DynamicSigmaBftPayloadEnvelopeKind and
    Ingress::DynamicSigmaBftPayloadFixtureMagicHex ==
      Decode::DynamicSigmaBftPayloadMagicHex and
    Ingress::DynamicSigmaBftPayloadFixtureEvidenceOffset ==
      Decode::DynamicSigmaBftPayloadEvidenceOffset and
    Ingress::DynamicSigmaBftPayloadFixtureEvidenceByteLen ==
      Decode::DynamicSigmaFixturePayloadEnvelope.evidenceByteLen and
    Ingress::DynamicSigmaBftPayloadFixtureBlockOffset ==
      Decode::DynamicSigmaBftPayloadBlockOffset and
    Ingress::DynamicSigmaBftPayloadFixtureBftBlockByteLen ==
      Decode::DynamicSigmaFixturePayloadEnvelope.bftBlockByteLen and
    Ingress::DynamicSigmaBftPayloadFixturePayloadByteLen ==
      Decode::DynamicSigmaFixturePayloadEnvelope.payloadByteLen and
    Ingress::DynamicSigmaBftPayloadFixtureHeaderCount ==
      Decode::DynamicSigmaFixturePayloadEnvelope.headerCount and
    Ingress::DynamicSigmaBftPayloadFixtureSelectedSigma ==
      Decode::DynamicSigmaFixturePayloadEnvelope.selectedSigma

  val TransportRequiresProductionIngress =
    Decode::transportedDynamicSigmaBftPayload == Set() or
    DynamicSigmaPayloadIngressAccepted

  val AcceptedTransportRequiresProductionIngress =
    Decode::acceptedDynamicSigmaBftPayload == Set() or
    (
      DynamicSigmaPayloadIngressAccepted and
      DynamicSigmaPayloadTransportAccepted
    )

  val DecodedDynamicPayloadRequiresIngressAndTransport =
    Decode::decodedTenderlinkPayloads.forall(decoded =>
      decoded.decodedKind != Decode::DecodedDynamicSigmaKind or
      (
        DynamicSigmaPayloadIngressAccepted and
        DynamicSigmaPayloadTransportAccepted and
        decoded.confirmationDepth ==
          Ingress::DynamicSigmaBftPayloadFixtureSelectedSigma
      )
    )

  val TaggedDynamicRejectionsRequireProductionIngress =
    Decode::rejectedTenderlinkPayloads.forall(rejected =>
      not(rejected.startsWithDynamicSigmaMagic) or
      DynamicSigmaPayloadIngressAccepted
    )

  val BridgeStateWellFormed =
    bridgeProgress >= 0 and
    bridgeProgress <= 5 and
    Set(
      "Init",
      "AcceptDynamicSigmaPayloadIngress",
      "GossipDynamicSigmaPayloadAfterIngress",
      "AcceptTransportedDynamicSigmaPayloadAfterIngress",
      "DecodeEnabledDynamicSigmaPayloadAfterIngressAndTransport",
      "RejectDisabledDynamicSigmaPayloadAfterIngress",
      "RawGossipDynamicSigmaPayloadWithoutIngress",
      "RawDecodeEnabledDynamicSigmaPayloadWithoutIngress",
      "RawDecodeEnabledDynamicSigmaPayloadWithoutTransport",
      "RawRejectDisabledDynamicSigmaPayloadWithoutIngress",
      "Stutter",
    ).contains(bridgeFiredAction)

  val DynamicSigmaPayloadIngressBridgeSafety =
    Ingress::IngressSafety and
    Decode::DecodeGateSafety and
    DynamicSigmaPayloadIngressMatchesDecodeFixture and
    BridgeStateWellFormed and
    TransportRequiresProductionIngress and
    AcceptedTransportRequiresProductionIngress and
    DecodedDynamicPayloadRequiresIngressAndTransport and
    TaggedDynamicRejectionsRequireProductionIngress

  action Init = all {
    Ingress::IngressInit,
    Decode::DecodeGateInit,
    bridgeProgress' = 0,
    bridgeFiredAction' = "Init",
  }

  action KeepBridgeState = all {
    bridgeProgress' = bridgeProgress,
    bridgeFiredAction' = bridgeFiredAction,
  }

  action KeepDecodePayloadState = all {
    Decode::decodedTenderlinkPayloads' = Decode::decodedTenderlinkPayloads,
    Decode::rejectedTenderlinkPayloads' = Decode::rejectedTenderlinkPayloads,
    Decode::decodeGateFiredAction' = Decode::decodeGateFiredAction,
  }

  action AcceptDynamicSigmaPayloadIngress: bool =
    all {
      not(DynamicSigmaPayloadIngressAccepted),
      Ingress::AcceptDynamicSigmaBftPayload(
        Ingress::DynamicSigmaBftPayloadEnvelope
      ),
      Decode::DecodeGateStutter,
      bridgeProgress' = bridgeProgress + 1,
      bridgeFiredAction' = "AcceptDynamicSigmaPayloadIngress",
    }

  action GossipDynamicSigmaPayloadAfterIngress: bool =
    all {
      DynamicSigmaPayloadIngressAccepted,
      not(Decode::transportedDynamicSigmaBftPayload.contains(
        Decode::DynamicSigmaFixturePayloadEnvelope
      )),
      Ingress::IngressStutter,
      Decode::GossipDynamicSigmaBftPayload(
        Decode::DynamicSigmaFixturePayloadEnvelope
      ),
      KeepDecodePayloadState,
      bridgeProgress' = bridgeProgress + 1,
      bridgeFiredAction' = "GossipDynamicSigmaPayloadAfterIngress",
    }

  action AcceptTransportedDynamicSigmaPayloadAfterIngress: bool =
    all {
      DynamicSigmaPayloadIngressAccepted,
      not(DynamicSigmaPayloadTransportAccepted),
      Ingress::IngressStutter,
      Decode::AcceptTransportedDynamicSigmaBftPayload(
        Decode::DynamicSigmaFixturePayloadEnvelope
      ),
      KeepDecodePayloadState,
      bridgeProgress' = bridgeProgress + 1,
      bridgeFiredAction' =
        "AcceptTransportedDynamicSigmaPayloadAfterIngress",
    }

  action DecodeEnabledDynamicSigmaPayloadAfterIngressAndTransport: bool =
    all {
      DynamicSigmaPayloadIngressAccepted,
      DynamicSigmaPayloadTransportAccepted,
      Ingress::IngressStutter,
      Decode::DecodeTenderlinkPayload(
        Decode::PrototypeEnabled,
        Decode::DynamicSigmaFixtureWire,
      ),
      bridgeProgress' = bridgeProgress + 1,
      bridgeFiredAction' =
        "DecodeEnabledDynamicSigmaPayloadAfterIngressAndTransport",
    }

  action RejectDisabledDynamicSigmaPayloadAfterIngress: bool =
    all {
      DynamicSigmaPayloadIngressAccepted,
      Ingress::IngressStutter,
      Decode::DecodeTenderlinkPayload(
        Decode::PrototypeDisabled,
        Decode::DynamicSigmaFixtureWire,
      ),
      bridgeProgress' = bridgeProgress + 1,
      bridgeFiredAction' = "RejectDisabledDynamicSigmaPayloadAfterIngress",
    }

  action AttemptDynamicSigmaPayloadAsTenderlinkConsensusIngress: bool =
    all {
      Ingress::AcceptTenderlinkConsensus(
        Ingress::DynamicSigmaBftPayloadEnvelope
      ),
      Decode::DecodeGateStutter,
      bridgeProgress' = bridgeProgress + 1,
      bridgeFiredAction' = "AcceptDynamicSigmaPayloadIngress",
    }

  action RawGossipDynamicSigmaPayloadWithoutIngress: bool =
    all {
      not(DynamicSigmaPayloadIngressAccepted),
      Ingress::IngressStutter,
      Decode::GossipDynamicSigmaBftPayload(
        Decode::DynamicSigmaFixturePayloadEnvelope
      ),
      KeepDecodePayloadState,
      bridgeProgress' = bridgeProgress + 1,
      bridgeFiredAction' = "RawGossipDynamicSigmaPayloadWithoutIngress",
    }

  action RawDecodeEnabledDynamicSigmaPayloadWithoutIngress: bool =
    all {
      not(DynamicSigmaPayloadIngressAccepted),
      Ingress::IngressStutter,
      Decode::DecodeTenderlinkPayload(
        Decode::PrototypeEnabled,
        Decode::DynamicSigmaFixtureWire,
      ),
      bridgeProgress' = bridgeProgress + 1,
      bridgeFiredAction' = "RawDecodeEnabledDynamicSigmaPayloadWithoutIngress",
    }

  action RawDecodeEnabledDynamicSigmaPayloadWithoutTransport: bool =
    all {
      DynamicSigmaPayloadIngressAccepted,
      not(DynamicSigmaPayloadTransportAccepted),
      Ingress::IngressStutter,
      Decode::DecodeTenderlinkPayload(
        Decode::PrototypeEnabled,
        Decode::DynamicSigmaFixtureWire,
      ),
      bridgeProgress' = bridgeProgress + 1,
      bridgeFiredAction' =
        "RawDecodeEnabledDynamicSigmaPayloadWithoutTransport",
    }

  action RawRejectDisabledDynamicSigmaPayloadWithoutIngress: bool =
    all {
      not(DynamicSigmaPayloadIngressAccepted),
      Ingress::IngressStutter,
      Decode::DecodeTenderlinkPayload(
        Decode::PrototypeDisabled,
        Decode::DynamicSigmaFixtureWire,
      ),
      bridgeProgress' = bridgeProgress + 1,
      bridgeFiredAction' = "RawRejectDisabledDynamicSigmaPayloadWithoutIngress",
    }

  action Stutter: bool =
    all {
      Ingress::IngressStutter,
      Decode::DecodeGateStutter,
      KeepBridgeState,
    }

  action Next: bool =
    any {
      AcceptDynamicSigmaPayloadIngress,
      GossipDynamicSigmaPayloadAfterIngress,
      AcceptTransportedDynamicSigmaPayloadAfterIngress,
      DecodeEnabledDynamicSigmaPayloadAfterIngressAndTransport,
      RejectDisabledDynamicSigmaPayloadAfterIngress,
      Stutter,
    }

  run acceptsDynamicSigmaPayloadFromProductionIngressToDecodeTest = {
    Init
      .then(AcceptDynamicSigmaPayloadIngress)
      .then(GossipDynamicSigmaPayloadAfterIngress)
      .then(AcceptTransportedDynamicSigmaPayloadAfterIngress)
      .then(DecodeEnabledDynamicSigmaPayloadAfterIngressAndTransport)
      .then(all {
        assert(DynamicSigmaPayloadIngressAccepted),
        assert(DynamicSigmaPayloadTransportAccepted),
        assert(Decode::decodedTenderlinkPayloads.contains(
          Decode::DecodedDynamicPayload(
            Decode::PrototypeEnabled,
            Decode::DynamicSigmaFixtureWire,
          )
        )),
        assert(DynamicSigmaPayloadIngressBridgeSafety),
        Stutter,
      })
  }

  run disabledPrototypeRejectsIngressedDynamicSigmaPayloadTest = {
    Init
      .then(AcceptDynamicSigmaPayloadIngress)
      .then(RejectDisabledDynamicSigmaPayloadAfterIngress)
      .then(all {
        assert(Decode::rejectedTenderlinkPayloads.contains(
          Decode::RejectedPayload(
            Decode::PrototypeDisabled,
            Decode::DynamicSigmaFixtureWire,
            Decode::DynamicSigmaUnsupportedReason,
          )
        )),
        assert(DynamicSigmaPayloadIngressBridgeSafety),
        Stutter,
      })
  }

  run dynamicSigmaPayloadRejectedByTenderlinkConsensusIngressTest = {
    Init
      .then(AttemptDynamicSigmaPayloadAsTenderlinkConsensusIngress)
      .fail()
  }

  run rawGossipWithoutIngressViolatesBridgeSafetyTest = {
    Init
      .then(RawGossipDynamicSigmaPayloadWithoutIngress)
      .then(all {
        assert(not(DynamicSigmaPayloadIngressBridgeSafety)),
        Stutter,
      })
  }

  run rawDecodeWithoutIngressViolatesBridgeSafetyTest = {
    Init
      .then(RawDecodeEnabledDynamicSigmaPayloadWithoutIngress)
      .then(all {
        assert(not(DynamicSigmaPayloadIngressBridgeSafety)),
        Stutter,
      })
  }

  run rawDecodeAfterIngressWithoutTransportViolatesBridgeSafetyTest = {
    Init
      .then(AcceptDynamicSigmaPayloadIngress)
      .then(RawDecodeEnabledDynamicSigmaPayloadWithoutTransport)
      .then(all {
        assert(not(DynamicSigmaPayloadIngressBridgeSafety)),
        Stutter,
      })
  }

  run rawUnsupportedRejectWithoutIngressViolatesBridgeSafetyTest = {
    Init
      .then(RawRejectDisabledDynamicSigmaPayloadWithoutIngress)
      .then(all {
        assert(not(DynamicSigmaPayloadIngressBridgeSafety)),
        Stutter,
      })
  }

  run productionDynamicSigmaPayloadIngressBridgeSafetyTest = {
    Init
      .then(all {
        assert(DynamicSigmaPayloadIngressBridgeSafety),
        Stutter,
      })
  }
}

module CrosslinkProductionDynamicSigmaPayloadIngressBridgeModel {
  import CrosslinkProductionDynamicSigmaPayloadIngressBridge.* from
    "./CrosslinkProductionDynamicSigmaPayloadIngressBridge"
  export CrosslinkProductionDynamicSigmaPayloadIngressBridge.*
}
