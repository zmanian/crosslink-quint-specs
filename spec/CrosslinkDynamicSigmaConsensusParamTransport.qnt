module CrosslinkDynamicSigmaConsensusParamTransport {
  /*
   Dynamic-sigma consensus-parameter transport boundary.

   CrosslinkDynamicSigmaConsensusParams.qnt models the deterministic
   `bc_confirmation_depth_sigma` envelope that is committed at BFT-height
   boundaries. This slice adds the production-facing transport/authentication
   obligation around that envelope: before a node installs a next-height sigma
   parameter, it must see quorum-signed canonical param bytes on the Crosslink
   consensus gossip topic.

   Crypto and bytes remain compact tokens, following the other authentication
   models in this repo. The important shape is that the signature signs the
   exact canonical payload for the claimed param wire, and the node config only
   follows wires that were both gossiped with quorum and committed by the
   deterministic controller.
   */

  import CrosslinkDynamicSigmaConsensusParams.* from "./CrosslinkDynamicSigmaConsensusParams"
  export CrosslinkDynamicSigmaConsensusParams.*

  type ParamSigner_t = str
  type ParamBytes_t = str
  type ParamSignature_t = str
  type ParamTopic_t = str
  type ParamEnvelopeKind_t = str

  type ConsensusParamTransportEnvelope_t = {
    topic: ParamTopic_t,
    kind: ParamEnvelopeKind_t,
    signer: ParamSigner_t,
    wire: ConsensusParamWire_t,
    bytes: ParamBytes_t,
    signature: ParamSignature_t,
  }

  const ParamSigners: Set[ParamSigner_t]
  const ParamVotingPower: ParamSigner_t -> int
  const ParamQuorumVotingPower: int
  const ParamBytes: Set[ParamBytes_t]
  const ParamSignatures: Set[ParamSignature_t]
  const ParamSignatureOwner: ParamSignature_t -> ParamSigner_t
  const ParamSignatureBytes: ParamSignature_t -> ParamBytes_t
  const ConsensusParamPayload:
    Height_t -> Height_t -> Sigma_t -> ParamBytes_t

  pure val CrosslinkConsensusParamTopic = "crosslink-consensus-v1"
  pure val ConsensusParamEnvelopeKind = "consensus-param"

  pure def ParamVotingPowerOf(signers: Set[ParamSigner_t]): int =
    signers.fold(0, (acc, p) => acc + ParamVotingPower.get(p))

  assume param_signer_power_is_positive =
    ParamSigners.forall(p => ParamVotingPower.get(p) > 0)

  assume param_quorum_intersects =
    2 * ParamQuorumVotingPower > ParamVotingPowerOf(ParamSigners)

  assume param_signature_metadata_is_in_domain =
    ParamSignatures.forall(sig =>
      ParamSigners.contains(ParamSignatureOwner.get(sig)) and
      ParamBytes.contains(ParamSignatureBytes.get(sig))
    )

  assume consensus_param_payloads_are_bytes =
    ConsensusParamWires.forall(wire =>
      ParamBytes.contains(
        ConsensusParamPayload
          .get(wire.activationHeight)
          .get(wire.telemetryHeight)
          .get(wire.bcConfirmationDepthSigma)
      )
    )

  var gossipedConsensusParamEnvelope: Set[ConsensusParamTransportEnvelope_t]
  var nodeConfiguredConsensusParamWire: Height_t -> ConsensusParamWire_t
  var nodeConfiguredSigmaAtHeight: Height_t -> Sigma_t
  var paramTransportFiredAction: str

  pure def ParamPayloadBytes(wire: ConsensusParamWire_t): ParamBytes_t =
    ConsensusParamPayload
      .get(wire.activationHeight)
      .get(wire.telemetryHeight)
      .get(wire.bcConfirmationDepthSigma)

  pure def VerifyParamSignature(
    signer: ParamSigner_t,
    bytes: ParamBytes_t,
    signature: ParamSignature_t,
  ): bool =
    ParamSignatures.contains(signature) and
    ParamSignatureOwner.get(signature) == signer and
    ParamSignatureBytes.get(signature) == bytes

  def ConsensusParamEnvelopeAuthentic(
    env: ConsensusParamTransportEnvelope_t,
  ): bool =
    env.topic == CrosslinkConsensusParamTopic and
    env.kind == ConsensusParamEnvelopeKind and
    ParamSigners.contains(env.signer) and
    ConsensusParamWires.contains(env.wire) and
    ConsensusParamWireWellFormed(env.wire) and
    env.bytes == ParamPayloadBytes(env.wire) and
    VerifyParamSignature(env.signer, env.bytes, env.signature)

  def GossipedParamSignersFor(
    wire: ConsensusParamWire_t,
  ): Set[ParamSigner_t] =
    gossipedConsensusParamEnvelope
      .filter(env => env.wire == wire and ConsensusParamEnvelopeAuthentic(env))
      .map(env => env.signer)

  def GossipedParamQuorumFor(wire: ConsensusParamWire_t): bool =
    ParamVotingPowerOf(GossipedParamSignersFor(wire)) >=
      ParamQuorumVotingPower

  action ParamTransportInit = all {
    ConsensusParamInit,
    gossipedConsensusParamEnvelope' = Set(),
    nodeConfiguredConsensusParamWire' =
      Heights.mapBy(h => EncodeConsensusParams(h, 0, InitialSigma)),
    nodeConfiguredSigmaAtHeight' = Heights.mapBy(_ => InitialSigma),
    paramTransportFiredAction' = "ParamTransportInit",
  }

  action KeepConsensusParamControllerState = all {
    height' = height,
    sigma' = sigma,
    sigmaAtHeight' = sigmaAtHeight,
    committedTelemetryHeights' = committedTelemetryHeights,
    burnedNilRounds' = burnedNilRounds,
    lastHeightBefore' = lastHeightBefore,
    lastSigmaBefore' = lastSigmaBefore,
    firedAction' = firedAction,
    consensusParamsAtHeight' = consensusParamsAtHeight,
    acceptedConsensusParamWire' = acceptedConsensusParamWire,
    committedConsensusParamHeights' = committedConsensusParamHeights,
    lastConsensusParamHeightBefore' = lastConsensusParamHeightBefore,
    lastConsensusParamSigmaBefore' = lastConsensusParamSigmaBefore,
    lastConsensusParamWireBefore' = lastConsensusParamWireBefore,
  }

  action KeepParamTransportState = all {
    gossipedConsensusParamEnvelope' = gossipedConsensusParamEnvelope,
    nodeConfiguredConsensusParamWire' = nodeConfiguredConsensusParamWire,
    nodeConfiguredSigmaAtHeight' = nodeConfiguredSigmaAtHeight,
  }

  action GossipConsensusParamEnvelope(
    env: ConsensusParamTransportEnvelope_t,
  ): bool =
    all {
      ConsensusParamEnvelopeAuthentic(env),
      KeepConsensusParamControllerState,
      gossipedConsensusParamEnvelope' =
        gossipedConsensusParamEnvelope.union(Set(env)),
      nodeConfiguredConsensusParamWire' = nodeConfiguredConsensusParamWire,
      nodeConfiguredSigmaAtHeight' = nodeConfiguredSigmaAtHeight,
      paramTransportFiredAction' = "GossipConsensusParamEnvelope",
    }

  action CommitHeightFromGossipedConsensusParam(
    wire: ConsensusParamWire_t,
  ): bool =
    all {
      GossipedParamQuorumFor(wire),
      CommitHeightWithConsensusParams(wire),
      gossipedConsensusParamEnvelope' = gossipedConsensusParamEnvelope,
      nodeConfiguredConsensusParamWire' =
        nodeConfiguredConsensusParamWire.set(wire.activationHeight, wire),
      nodeConfiguredSigmaAtHeight' =
        nodeConfiguredSigmaAtHeight.set(
          wire.activationHeight,
          wire.bcConfirmationDepthSigma
        ),
      paramTransportFiredAction' = "CommitHeightFromGossipedConsensusParam",
    }

  action BurnNilPrecommitRoundWithTransport: bool =
    all {
      BurnNilPrecommitRoundWithParams,
      KeepParamTransportState,
      paramTransportFiredAction' = "BurnNilPrecommitRoundWithTransport",
    }

  action ParamTransportStutter: bool =
    all {
      ParamStutter,
      KeepParamTransportState,
      paramTransportFiredAction' = paramTransportFiredAction,
    }

  val GossipedConsensusParamEnvelopesAuthentic =
    gossipedConsensusParamEnvelope.forall(ConsensusParamEnvelopeAuthentic)

  val CommittedParamsHaveTransportQuorum =
    committedConsensusParamHeights.forall(h =>
      GossipedParamQuorumFor(acceptedConsensusParamWire.get(h))
    )

  val NodeConfigMatchesAcceptedConsensusParams =
    Heights.forall(h =>
      if (h <= height) {
        nodeConfiguredConsensusParamWire.get(h) ==
          acceptedConsensusParamWire.get(h) and
        nodeConfiguredSigmaAtHeight.get(h) == sigmaAtHeight.get(h)
      } else {
        true
      }
    )

  val NodeConfigOnlyFollowsCommittedOrInitialParams =
    Heights.forall(h =>
      if (h <= height and h != 0) {
        committedConsensusParamHeights.contains(h) and
        GossipedParamQuorumFor(nodeConfiguredConsensusParamWire.get(h))
      } else {
        true
      }
    )

  val ParamTransportSafety =
    ConsensusParamSafety and
    GossipedConsensusParamEnvelopesAuthentic and
    CommittedParamsHaveTransportQuorum and
    NodeConfigMatchesAcceptedConsensusParams and
    NodeConfigOnlyFollowsCommittedOrInitialParams
}

module CrosslinkDynamicSigmaConsensusParamTransportTest {
  import CrosslinkDynamicSigmaConsensusParamTransport.* from
    "./CrosslinkDynamicSigmaConsensusParamTransport"
  export CrosslinkDynamicSigmaConsensusParamTransport.*

  pure val WrongConsensusParamTopic = "zcash-blocks-v1"
  pure val WrongConsensusParamKind = "headers"

  pure val H1LowParticipationWire = EncodeConsensusParams(1, 0, 3)
  pure val H1WrongSigmaWire = EncodeConsensusParams(1, 0, 2)
  pure val H2RecoveredParticipationWire = EncodeConsensusParams(2, 1, 2)

  pure val H1ParamBytes = "param-bytes-h1-sigma-3"
  pure val H1WrongSigmaParamBytes = "param-bytes-h1-sigma-2"
  pure val H2ParamBytes = "param-bytes-h2-sigma-2"
  pure val WrongParamBytes = "wrong-param-bytes"

  pure val Alice = "alice"
  pure val Bob = "bob"

  pure def Env(
    topic: ParamTopic_t,
    kind: ParamEnvelopeKind_t,
    signer: ParamSigner_t,
    wire: ConsensusParamWire_t,
    bytes: ParamBytes_t,
    signature: ParamSignature_t,
  ): ConsensusParamTransportEnvelope_t = {
    topic: topic,
    kind: kind,
    signer: signer,
    wire: wire,
    bytes: bytes,
    signature: signature,
  }

  pure val H1AliceEnvelope =
    Env(
      CrosslinkConsensusParamTopic,
      ConsensusParamEnvelopeKind,
      Alice,
      H1LowParticipationWire,
      H1ParamBytes,
      "sig-alice-h1",
    )

  pure val H1BobEnvelope =
    Env(
      CrosslinkConsensusParamTopic,
      ConsensusParamEnvelopeKind,
      Bob,
      H1LowParticipationWire,
      H1ParamBytes,
      "sig-bob-h1",
    )

  pure val H2AliceEnvelope =
    Env(
      CrosslinkConsensusParamTopic,
      ConsensusParamEnvelopeKind,
      Alice,
      H2RecoveredParticipationWire,
      H2ParamBytes,
      "sig-alice-h2",
    )

  pure val H2BobEnvelope =
    Env(
      CrosslinkConsensusParamTopic,
      ConsensusParamEnvelopeKind,
      Bob,
      H2RecoveredParticipationWire,
      H2ParamBytes,
      "sig-bob-h2",
    )

  pure val H1WrongSigmaAliceEnvelope =
    Env(
      CrosslinkConsensusParamTopic,
      ConsensusParamEnvelopeKind,
      Alice,
      H1WrongSigmaWire,
      H1WrongSigmaParamBytes,
      "sig-alice-h1-wrong-sigma",
    )

  pure val H1WrongSigmaBobEnvelope =
    Env(
      CrosslinkConsensusParamTopic,
      ConsensusParamEnvelopeKind,
      Bob,
      H1WrongSigmaWire,
      H1WrongSigmaParamBytes,
      "sig-bob-h1-wrong-sigma",
    )

  pure val WrongTopicEnvelope =
    Env(
      WrongConsensusParamTopic,
      ConsensusParamEnvelopeKind,
      Alice,
      H1LowParticipationWire,
      H1ParamBytes,
      "sig-alice-h1",
    )

  pure val WrongKindEnvelope =
    Env(
      CrosslinkConsensusParamTopic,
      WrongConsensusParamKind,
      Alice,
      H1LowParticipationWire,
      H1ParamBytes,
      "sig-alice-h1",
    )

  pure val WrongBytesEnvelope =
    Env(
      CrosslinkConsensusParamTopic,
      ConsensusParamEnvelopeKind,
      Alice,
      H1LowParticipationWire,
      WrongParamBytes,
      "sig-alice-h1",
    )

  pure val WrongSignatureEnvelope =
    Env(
      CrosslinkConsensusParamTopic,
      ConsensusParamEnvelopeKind,
      Alice,
      H1LowParticipationWire,
      H1ParamBytes,
      "sig-alice-wrong-bytes",
    )

  pure val TestParamTransportEnvelopes = Set(
    H1AliceEnvelope,
    H1BobEnvelope,
    H2AliceEnvelope,
    H2BobEnvelope,
    H1WrongSigmaAliceEnvelope,
    H1WrongSigmaBobEnvelope,
    WrongTopicEnvelope,
    WrongKindEnvelope,
    WrongBytesEnvelope,
    WrongSignatureEnvelope,
  )

  pure val ModelParamTransportEnvelopes = Set(
    H1AliceEnvelope,
    H1BobEnvelope,
    H2AliceEnvelope,
    H2BobEnvelope,
  )

  pure val ModelConsensusParamWires = Set(
    H1LowParticipationWire,
    H2RecoveredParticipationWire,
  )

  action ParamTransportNext =
    any {
      nondet env = oneOf(ModelParamTransportEnvelopes)
      GossipConsensusParamEnvelope(env),
      nondet wire = oneOf(ModelConsensusParamWires)
      CommitHeightFromGossipedConsensusParam(wire),
      BurnNilPrecommitRoundWithTransport,
      ParamTransportStutter,
    }

  action transportUnchangedAll = all {
    height' = height,
    sigma' = sigma,
    sigmaAtHeight' = sigmaAtHeight,
    committedTelemetryHeights' = committedTelemetryHeights,
    burnedNilRounds' = burnedNilRounds,
    lastHeightBefore' = lastHeightBefore,
    lastSigmaBefore' = lastSigmaBefore,
    firedAction' = firedAction,
    consensusParamsAtHeight' = consensusParamsAtHeight,
    acceptedConsensusParamWire' = acceptedConsensusParamWire,
    committedConsensusParamHeights' = committedConsensusParamHeights,
    lastConsensusParamHeightBefore' = lastConsensusParamHeightBefore,
    lastConsensusParamSigmaBefore' = lastConsensusParamSigmaBefore,
    lastConsensusParamWireBefore' = lastConsensusParamWireBefore,
    gossipedConsensusParamEnvelope' = gossipedConsensusParamEnvelope,
    nodeConfiguredConsensusParamWire' = nodeConfiguredConsensusParamWire,
    nodeConfiguredSigmaAtHeight' = nodeConfiguredSigmaAtHeight,
    paramTransportFiredAction' = paramTransportFiredAction,
  }

  run quorumGossipedParamConfiguresLowParticipationRaiseTest = {
    ParamTransportInit
      .then(GossipConsensusParamEnvelope(H1AliceEnvelope))
      .then(GossipConsensusParamEnvelope(H1BobEnvelope))
      .then(CommitHeightFromGossipedConsensusParam(H1LowParticipationWire))
      .then(all {
        assert(height == 1),
        assert(HashPowerParticipationFloorBreachedAt(0)),
        assert(sigma == 3),
        assert(nodeConfiguredSigmaAtHeight.get(1) == 3),
        assert(nodeConfiguredConsensusParamWire.get(1) ==
          H1LowParticipationWire),
        assert(ParamTransportSafety),
        transportUnchangedAll,
      })
  }

  run recoveredParticipationCanLowerConfiguredSigmaTest = {
    ParamTransportInit
      .then(GossipConsensusParamEnvelope(H1AliceEnvelope))
      .then(GossipConsensusParamEnvelope(H1BobEnvelope))
      .then(CommitHeightFromGossipedConsensusParam(H1LowParticipationWire))
      .then(GossipConsensusParamEnvelope(H2AliceEnvelope))
      .then(GossipConsensusParamEnvelope(H2BobEnvelope))
      .then(CommitHeightFromGossipedConsensusParam(H2RecoveredParticipationWire))
      .then(all {
        assert(height == 2),
        assert(HashPowerParticipationCompleteAt(1)),
        assert(ShouldLowerSigma(1)),
        assert(sigma == 2),
        assert(nodeConfiguredSigmaAtHeight.get(2) == 2),
        assert(ParamTransportSafety),
        transportUnchangedAll,
      })
  }

  run commitRejectedWithoutTransportQuorumTest = {
    ParamTransportInit
      .then(GossipConsensusParamEnvelope(H1AliceEnvelope))
      .then(CommitHeightFromGossipedConsensusParam(H1LowParticipationWire))
      .fail()
  }

  run wrongTopicParamEnvelopeRejectedTest = {
    ParamTransportInit
      .then(GossipConsensusParamEnvelope(WrongTopicEnvelope))
      .fail()
  }

  run wrongKindParamEnvelopeRejectedTest = {
    ParamTransportInit
      .then(GossipConsensusParamEnvelope(WrongKindEnvelope))
      .fail()
  }

  run wrongBytesParamEnvelopeRejectedTest = {
    ParamTransportInit
      .then(GossipConsensusParamEnvelope(WrongBytesEnvelope))
      .fail()
  }

  run wrongSignatureParamEnvelopeRejectedTest = {
    ParamTransportInit
      .then(GossipConsensusParamEnvelope(WrongSignatureEnvelope))
      .fail()
  }

  run quorumForNondeterministicSigmaStillRejectedTest = {
    ParamTransportInit
      .then(GossipConsensusParamEnvelope(H1WrongSigmaAliceEnvelope))
      .then(GossipConsensusParamEnvelope(H1WrongSigmaBobEnvelope))
      .then(CommitHeightFromGossipedConsensusParam(H1WrongSigmaWire))
      .fail()
  }

  run nilRoundDoesNotRewriteTransportConfigTest = {
    ParamTransportInit
      .then(BurnNilPrecommitRoundWithTransport)
      .then(all {
        assert(height == 0),
        assert(burnedNilRounds.get(0) == 1),
        assert(nodeConfiguredSigmaAtHeight.get(0) == InitialSigma),
        assert(ParamTransportSafety),
        transportUnchangedAll,
      })
  }

  run paramTransportSafetyTest = {
    ParamTransportInit
      .then(all {
        assert(ParamTransportSafety),
        transportUnchangedAll,
      })
  }
}

module CrosslinkDynamicSigmaConsensusParamTransportModel {
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
      "param-bytes-h0-sigma-2",
      "param-bytes-h1-sigma-3",
      "param-bytes-h1-sigma-2",
      "param-bytes-h2-sigma-2",
      "wrong-param-bytes",
    ),
    ParamSignatures = Set(
      "sig-alice-h1",
      "sig-bob-h1",
      "sig-alice-h2",
      "sig-bob-h2",
      "sig-alice-h1-wrong-sigma",
      "sig-bob-h1-wrong-sigma",
      "sig-alice-wrong-bytes",
    ),
    ParamSignatureOwner = Map(
      "sig-alice-h1" -> "alice",
      "sig-bob-h1" -> "bob",
      "sig-alice-h2" -> "alice",
      "sig-bob-h2" -> "bob",
      "sig-alice-h1-wrong-sigma" -> "alice",
      "sig-bob-h1-wrong-sigma" -> "bob",
      "sig-alice-wrong-bytes" -> "alice",
    ),
    ParamSignatureBytes = Map(
      "sig-alice-h1" -> "param-bytes-h1-sigma-3",
      "sig-bob-h1" -> "param-bytes-h1-sigma-3",
      "sig-alice-h2" -> "param-bytes-h2-sigma-2",
      "sig-bob-h2" -> "param-bytes-h2-sigma-2",
      "sig-alice-h1-wrong-sigma" -> "param-bytes-h1-sigma-2",
      "sig-bob-h1-wrong-sigma" -> "param-bytes-h1-sigma-2",
      "sig-alice-wrong-bytes" -> "wrong-param-bytes",
    ),
    ConsensusParamPayload = Map(
      0 -> Map(
        0 -> Map(
          2 -> "param-bytes-h0-sigma-2",
        ),
      ),
      1 -> Map(
        0 -> Map(
          2 -> "param-bytes-h1-sigma-2",
          3 -> "param-bytes-h1-sigma-3",
        ),
      ),
      2 -> Map(
        1 -> Map(
          2 -> "param-bytes-h2-sigma-2",
        ),
      ),
    ),
  ).*
}
