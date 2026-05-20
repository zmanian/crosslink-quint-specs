module CrosslinkProductionDynamicSigmaConsensusParamIngressBridge {
  /*
   Production dynamic-sigma consensus-param ingress bridge.

   CrosslinkDynamicSigmaConsensusParamTransport.qnt pins the authenticated
   transport/config-application boundary for production-shaped
   `bc_confirmation_depth_sigma` wires. This bridge connects that transport
   path to the production gossip registry/ingress lane: quorum-signed dynamic
   sigma params may be gossiped and installed only after the node-local
   production ingress accepts the matching registry-valid consensus-param
   envelope.
   */

  import CrosslinkProductionGossipIngress as Ingress from
    "./CrosslinkProductionGossipIngress"
  import CrosslinkDynamicSigmaConsensusParamTransportTest(
    MaxHeight = 2,
    MinSigma = 1,
    MaxSigma = 4,
    InitialSigma = 2,
    FailureThreshold = 2,
    StableWindowThreshold = 2,
    CoverageTarget = 3,
    MaxCoverageScore = 4,
    HashPowerParticipationTargetPercent = 67,
    HashPowerParticipationFloorPercent = 25,
    MaxHashPowerParticipationPercent = 100,
    CommittedFailureKind = Map(
      0 -> "none",
      1 -> "none",
      2 -> "none",
    ),
    CommittedFailureCount = Map(
      0 -> 0,
      1 -> 0,
      2 -> 0,
    ),
    CommittedStableWindowCount = Map(
      0 -> 0,
      1 -> 2,
      2 -> 2,
    ),
    CommittedCoverageScore = Map(
      0 -> 4,
      1 -> 4,
      2 -> 4,
    ),
    CommittedHashPowerParticipationPercent = Map(
      0 -> 10,
      1 -> 80,
      2 -> 80,
    ),
    ConsensusParamWires = Set(
      {
        paramKey: "bc_confirmation_depth_sigma",
        activationHeight: 0,
        telemetryHeight: 0,
        bcConfirmationDepthSigma: 2,
      },
      {
        paramKey: "bc_confirmation_depth_sigma",
        activationHeight: 1,
        telemetryHeight: 0,
        bcConfirmationDepthSigma: 3,
      },
      {
        paramKey: "bc_confirmation_depth_sigma",
        activationHeight: 1,
        telemetryHeight: 0,
        bcConfirmationDepthSigma: 2,
      },
      {
        paramKey: "bc_confirmation_depth_sigma",
        activationHeight: 0,
        telemetryHeight: 0,
        bcConfirmationDepthSigma: 3,
      },
      {
        paramKey: "bc_confirmation_depth_sigma",
        activationHeight: 2,
        telemetryHeight: 1,
        bcConfirmationDepthSigma: 2,
      },
    ),
    ProductionConsensusParamWires = Set(
      {
        byteLen: 11,
        keyTag: 1,
        activationHeight: 0,
        telemetryHeight: 0,
        bcConfirmationDepthSigma: 2,
      },
      {
        byteLen: 11,
        keyTag: 1,
        activationHeight: 1,
        telemetryHeight: 0,
        bcConfirmationDepthSigma: 3,
      },
      {
        byteLen: 11,
        keyTag: 1,
        activationHeight: 1,
        telemetryHeight: 0,
        bcConfirmationDepthSigma: 2,
      },
      {
        byteLen: 12,
        keyTag: 1,
        activationHeight: 1,
        telemetryHeight: 0,
        bcConfirmationDepthSigma: 3,
      },
      {
        byteLen: 11,
        keyTag: 1,
        activationHeight: 1,
        telemetryHeight: 0,
        bcConfirmationDepthSigma: 99,
      },
      {
        byteLen: 11,
        keyTag: 1,
        activationHeight: 0,
        telemetryHeight: 0,
        bcConfirmationDepthSigma: 3,
      },
      {
        byteLen: 11,
        keyTag: 1,
        activationHeight: 2,
        telemetryHeight: 1,
        bcConfirmationDepthSigma: 2,
      },
    ),
    ParamSigners = Set("alice", "bob"),
    ParamVotingPower = Map(
      "alice" -> 1,
      "bob" -> 1,
    ),
    ParamQuorumVotingPower = 2,
    ParamBytes = Set(
      "0100000000000000000200",
      "0101000000000000000300",
      "0101000000000000000200",
      "6301000000000000000300",
      "010100000000000000030000",
      "0101000000000000006300",
      "0100000000000000000300",
      "0102000000010000000200",
      "wrong-param-bytes",
    ),
    ParamSignatures = Set(
      "sig-alice-h1",
      "sig-bob-h1",
      "sig-alice-h2",
      "sig-bob-h2",
      "sig-alice-h1-wrong-sigma",
      "sig-bob-h1-wrong-sigma",
      "sig-alice-h1-wrong-key",
      "sig-alice-h1-trailing",
      "sig-alice-h1-sigma-99",
      "sig-alice-h0-stale",
      "sig-bob-h0-stale",
      "sig-alice-wrong-bytes",
    ),
    ParamSignatureOwner = Map(
      "sig-alice-h1" -> "alice",
      "sig-bob-h1" -> "bob",
      "sig-alice-h2" -> "alice",
      "sig-bob-h2" -> "bob",
      "sig-alice-h1-wrong-sigma" -> "alice",
      "sig-bob-h1-wrong-sigma" -> "bob",
      "sig-alice-h1-wrong-key" -> "alice",
      "sig-alice-h1-trailing" -> "alice",
      "sig-alice-h1-sigma-99" -> "alice",
      "sig-alice-h0-stale" -> "alice",
      "sig-bob-h0-stale" -> "bob",
      "sig-alice-wrong-bytes" -> "alice",
    ),
    ParamSignatureBytes = Map(
      "sig-alice-h1" -> "0101000000000000000300",
      "sig-bob-h1" -> "0101000000000000000300",
      "sig-alice-h2" -> "0102000000010000000200",
      "sig-bob-h2" -> "0102000000010000000200",
      "sig-alice-h1-wrong-sigma" -> "0101000000000000000200",
      "sig-bob-h1-wrong-sigma" -> "0101000000000000000200",
      "sig-alice-h1-wrong-key" -> "6301000000000000000300",
      "sig-alice-h1-trailing" -> "010100000000000000030000",
      "sig-alice-h1-sigma-99" -> "0101000000000000006300",
      "sig-alice-h0-stale" -> "0100000000000000000300",
      "sig-bob-h0-stale" -> "0100000000000000000300",
      "sig-alice-wrong-bytes" -> "wrong-param-bytes",
    ),
  ) as Param from "./CrosslinkDynamicSigmaConsensusParamTransport"

  var bridgeProgress: int
  var bridgeFiredAction: str

  def H1ParamIngressAccepted: bool =
    Ingress::acceptedDynamicSigmaConsensusParam.contains(
      Ingress::DynamicSigmaConsensusParamEnvelope
    )

  def H2ParamIngressAccepted: bool =
    Ingress::acceptedDynamicSigmaConsensusParam.contains(
      Ingress::DynamicSigmaConsensusParamRecoveredEnvelope
    )

  def IngressAcceptedForParamWire(
    wire: Param::ProductionConsensusParamWire_t,
  ): bool =
    if (wire == Param::H1LowParticipationWire) {
      H1ParamIngressAccepted
    } else if (wire == Param::H2RecoveredParticipationWire) {
      H2ParamIngressAccepted
    } else {
      false
    }

  def DynamicSigmaParamIngressMatchesTransportFixture: bool =
    Ingress::CrosslinkConsensusTopic == Param::CrosslinkConsensusParamTopic and
    Ingress::DynamicSigmaConsensusParamKind ==
      Param::ConsensusParamEnvelopeKind and
    Ingress::DynamicSigmaConsensusParamH1RaisedBytes ==
      Param::H1ParamBytes and
    Ingress::DynamicSigmaConsensusParamH2StableBytes == Param::H2ParamBytes

  val GossipedParamsRequireProductionIngress =
    Param::gossipedConsensusParamEnvelope.forall(env =>
      IngressAcceptedForParamWire(env.wire)
    )

  val ConfiguredParamsRequireProductionIngress =
    Param::committedConsensusParamHeights.forall(h =>
      if (h == 1) {
        H1ParamIngressAccepted
      } else if (h == 2) {
        H2ParamIngressAccepted
      } else {
        true
      }
    )

  val NodeConfigMatchesIngressedParamBytes =
    Param::committedConsensusParamHeights.forall(h =>
      if (h == 1) {
        Param::nodeConfiguredProductionConsensusParamWire.get(1) ==
          Param::H1LowParticipationWire
      } else if (h == 2) {
        Param::nodeConfiguredProductionConsensusParamWire.get(2) ==
          Param::H2RecoveredParticipationWire
      } else {
        true
      }
    )

  val BridgeStateWellFormed =
    bridgeProgress >= 0 and
    bridgeProgress <= 8 and
    Set(
      "Init",
      "AcceptH1DynamicSigmaParamIngress",
      "AcceptH2DynamicSigmaParamIngress",
      "GossipH1AliceParamAfterIngress",
      "GossipH1BobParamAfterIngress",
      "GossipH2AliceParamAfterIngress",
      "GossipH2BobParamAfterIngress",
      "CommitH1ParamAfterIngressAndQuorum",
      "CommitH2ParamAfterIngressAndQuorum",
      "AttemptDynamicSigmaParamAsTenderlinkConsensusIngress",
      "AttemptTenderlinkPrecommitAsDynamicSigmaParamIngress",
      "RawGossipH1AliceParamWithoutIngress",
      "RawGossipH1BobParamWithoutIngress",
      "RawCommitH1ParamWithoutIngress",
      "Stutter",
    ).contains(bridgeFiredAction)

  val DynamicSigmaConsensusParamIngressBridgeSafety =
    Ingress::IngressSafety and
    Param::ParamTransportSafety and
    DynamicSigmaParamIngressMatchesTransportFixture and
    GossipedParamsRequireProductionIngress and
    ConfiguredParamsRequireProductionIngress and
    NodeConfigMatchesIngressedParamBytes and
    BridgeStateWellFormed

  action Init = all {
    Ingress::IngressInit,
    Param::ParamTransportInit,
    bridgeProgress' = 0,
    bridgeFiredAction' = "Init",
  }

  action KeepBridgeState = all {
    bridgeProgress' = bridgeProgress,
    bridgeFiredAction' = bridgeFiredAction,
  }

  action AcceptH1DynamicSigmaParamIngress: bool =
    all {
      not(H1ParamIngressAccepted),
      Ingress::AcceptDynamicSigmaConsensusParam(
        Ingress::DynamicSigmaConsensusParamEnvelope
      ),
      Param::ParamTransportStutter,
      bridgeProgress' = bridgeProgress + 1,
      bridgeFiredAction' = "AcceptH1DynamicSigmaParamIngress",
    }

  action AcceptH2DynamicSigmaParamIngress: bool =
    all {
      not(H2ParamIngressAccepted),
      Ingress::AcceptDynamicSigmaConsensusParam(
        Ingress::DynamicSigmaConsensusParamRecoveredEnvelope
      ),
      Param::ParamTransportStutter,
      bridgeProgress' = bridgeProgress + 1,
      bridgeFiredAction' = "AcceptH2DynamicSigmaParamIngress",
    }

  action GossipH1AliceParamAfterIngress: bool =
    all {
      H1ParamIngressAccepted,
      Ingress::IngressStutter,
      Param::GossipConsensusParamEnvelope(Param::H1AliceEnvelope),
      bridgeProgress' = bridgeProgress + 1,
      bridgeFiredAction' = "GossipH1AliceParamAfterIngress",
    }

  action GossipH1BobParamAfterIngress: bool =
    all {
      H1ParamIngressAccepted,
      Ingress::IngressStutter,
      Param::GossipConsensusParamEnvelope(Param::H1BobEnvelope),
      bridgeProgress' = bridgeProgress + 1,
      bridgeFiredAction' = "GossipH1BobParamAfterIngress",
    }

  action GossipH2AliceParamAfterIngress: bool =
    all {
      H2ParamIngressAccepted,
      Ingress::IngressStutter,
      Param::GossipConsensusParamEnvelope(Param::H2AliceEnvelope),
      bridgeProgress' = bridgeProgress + 1,
      bridgeFiredAction' = "GossipH2AliceParamAfterIngress",
    }

  action GossipH2BobParamAfterIngress: bool =
    all {
      H2ParamIngressAccepted,
      Ingress::IngressStutter,
      Param::GossipConsensusParamEnvelope(Param::H2BobEnvelope),
      bridgeProgress' = bridgeProgress + 1,
      bridgeFiredAction' = "GossipH2BobParamAfterIngress",
    }

  action CommitH1ParamAfterIngressAndQuorum: bool =
    all {
      H1ParamIngressAccepted,
      Ingress::IngressStutter,
      Param::CommitHeightFromGossipedConsensusParam(
        Param::H1LowParticipationWire
      ),
      bridgeProgress' = bridgeProgress + 1,
      bridgeFiredAction' = "CommitH1ParamAfterIngressAndQuorum",
    }

  action CommitH2ParamAfterIngressAndQuorum: bool =
    all {
      H2ParamIngressAccepted,
      Ingress::IngressStutter,
      Param::CommitHeightFromGossipedConsensusParam(
        Param::H2RecoveredParticipationWire
      ),
      bridgeProgress' = bridgeProgress + 1,
      bridgeFiredAction' = "CommitH2ParamAfterIngressAndQuorum",
    }

  action AttemptDynamicSigmaParamAsTenderlinkConsensusIngress: bool =
    all {
      Ingress::AcceptTenderlinkConsensus(
        Ingress::DynamicSigmaConsensusParamEnvelope
      ),
      Param::ParamTransportStutter,
      bridgeProgress' = bridgeProgress + 1,
      bridgeFiredAction' =
        "AttemptDynamicSigmaParamAsTenderlinkConsensusIngress",
    }

  action AttemptTenderlinkPrecommitAsDynamicSigmaParamIngress: bool =
    all {
      Ingress::AcceptDynamicSigmaConsensusParam(
        Ingress::TenderlinkMixedPrecommitEnvelope
      ),
      Param::ParamTransportStutter,
      bridgeProgress' = bridgeProgress + 1,
      bridgeFiredAction' =
        "AttemptTenderlinkPrecommitAsDynamicSigmaParamIngress",
    }

  action RawGossipH1AliceParamWithoutIngress: bool =
    all {
      not(H1ParamIngressAccepted),
      Ingress::IngressStutter,
      Param::GossipConsensusParamEnvelope(Param::H1AliceEnvelope),
      bridgeProgress' = bridgeProgress + 1,
      bridgeFiredAction' = "RawGossipH1AliceParamWithoutIngress",
    }

  action RawGossipH1BobParamWithoutIngress: bool =
    all {
      not(H1ParamIngressAccepted),
      Ingress::IngressStutter,
      Param::GossipConsensusParamEnvelope(Param::H1BobEnvelope),
      bridgeProgress' = bridgeProgress + 1,
      bridgeFiredAction' = "RawGossipH1BobParamWithoutIngress",
    }

  action RawCommitH1ParamWithoutIngress: bool =
    all {
      not(H1ParamIngressAccepted),
      Ingress::IngressStutter,
      Param::CommitHeightFromGossipedConsensusParam(
        Param::H1LowParticipationWire
      ),
      bridgeProgress' = bridgeProgress + 1,
      bridgeFiredAction' = "RawCommitH1ParamWithoutIngress",
    }

  action Stutter: bool =
    all {
      Ingress::IngressStutter,
      Param::ParamTransportStutter,
      KeepBridgeState,
    }

  action Next: bool =
    any {
      AcceptH1DynamicSigmaParamIngress,
      AcceptH2DynamicSigmaParamIngress,
      GossipH1AliceParamAfterIngress,
      GossipH1BobParamAfterIngress,
      GossipH2AliceParamAfterIngress,
      GossipH2BobParamAfterIngress,
      CommitH1ParamAfterIngressAndQuorum,
      CommitH2ParamAfterIngressAndQuorum,
      Stutter,
    }

  run productionIngressQuorumGossipedParamConfiguresRaiseTest = {
    Init
      .then(AcceptH1DynamicSigmaParamIngress)
      .then(GossipH1AliceParamAfterIngress)
      .then(GossipH1BobParamAfterIngress)
      .then(CommitH1ParamAfterIngressAndQuorum)
      .then(all {
        assert(H1ParamIngressAccepted),
        assert(Param::height == 1),
        assert(Param::sigma == 3),
        assert(Param::nodeConfiguredSigmaAtHeight.get(1) == 3),
        assert(Param::nodeConfiguredProductionConsensusParamWire.get(1) ==
          Param::H1LowParticipationWire),
        assert(DynamicSigmaConsensusParamIngressBridgeSafety),
        Stutter,
      })
  }

  run productionIngressRecoveredParamCanLowerConfiguredSigmaTest = {
    Init
      .then(AcceptH1DynamicSigmaParamIngress)
      .then(GossipH1AliceParamAfterIngress)
      .then(GossipH1BobParamAfterIngress)
      .then(CommitH1ParamAfterIngressAndQuorum)
      .then(AcceptH2DynamicSigmaParamIngress)
      .then(GossipH2AliceParamAfterIngress)
      .then(GossipH2BobParamAfterIngress)
      .then(CommitH2ParamAfterIngressAndQuorum)
      .then(all {
        assert(H2ParamIngressAccepted),
        assert(Param::height == 2),
        assert(Param::sigma == 2),
        assert(Param::nodeConfiguredSigmaAtHeight.get(2) == 2),
        assert(Param::nodeConfiguredProductionConsensusParamWire.get(2) ==
          Param::H2RecoveredParticipationWire),
        assert(DynamicSigmaConsensusParamIngressBridgeSafety),
        Stutter,
      })
  }

  run dynamicSigmaParamRejectedByTenderlinkConsensusIngressTest = {
    Init
      .then(AttemptDynamicSigmaParamAsTenderlinkConsensusIngress)
      .fail()
  }

  run tenderlinkPrecommitRejectedByDynamicSigmaParamIngressTest = {
    Init
      .then(AttemptTenderlinkPrecommitAsDynamicSigmaParamIngress)
      .fail()
  }

  run rawParamGossipWithoutIngressViolatesBridgeSafetyTest = {
    Init
      .then(RawGossipH1AliceParamWithoutIngress)
      .then(all {
        assert(not(DynamicSigmaConsensusParamIngressBridgeSafety)),
        Stutter,
      })
  }

  run rawParamCommitWithoutIngressViolatesBridgeSafetyTest = {
    Init
      .then(RawGossipH1AliceParamWithoutIngress)
      .then(RawGossipH1BobParamWithoutIngress)
      .then(RawCommitH1ParamWithoutIngress)
      .then(all {
        assert(Param::height == 1),
        assert(not(DynamicSigmaConsensusParamIngressBridgeSafety)),
        Stutter,
      })
  }

  run productionDynamicSigmaConsensusParamIngressBridgeSafetyTest = {
    Init
      .then(all {
        assert(DynamicSigmaConsensusParamIngressBridgeSafety),
        Stutter,
      })
  }
}

module CrosslinkProductionDynamicSigmaConsensusParamIngressBridgeModel {
  import CrosslinkProductionDynamicSigmaConsensusParamIngressBridge.* from
    "./CrosslinkProductionDynamicSigmaConsensusParamIngressBridge"
  export CrosslinkProductionDynamicSigmaConsensusParamIngressBridge.*
}
