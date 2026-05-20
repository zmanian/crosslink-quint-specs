module CrosslinkProductionGossipRegistry {
  /*
   Direct production gossip registry safety slice.

   The Tenderlink, Malachite, dynamic-sigma, and production-finality router
   models already keep their own channels separated. This model adds one
   production-level registry above all protocol families, checking that
   Tenderlink compact-consensus lanes cannot be routed through Malachite
   proposal/liveness/sync lanes, that Malachite protobuf lanes cannot be
   routed through Tenderlink's consensus-topic registry, that dynamic-sigma
   consensus-param and BFT-payload envelopes do not share either protocol's
   ingress lane, and that production-finality proposal/fat-pointer envelopes
   stay in their finality lanes before the richer projection contract validates
   payload semantics.
   */

  import CrosslinkProductionFixtureVectorsGenerated.* from
    "./CrosslinkProductionFixtureVectorsGenerated"
  export CrosslinkProductionFixtureVectorsGenerated.*
  import CrosslinkTenderlinkPrecommitTransportSafety as PrecommitTransport from
    "./CrosslinkTenderlinkPrecommitTransportSafety"
  import CrosslinkTenderlinkConsensusPacketFormat as ConsensusPacketFormat from
    "./CrosslinkTenderlinkConsensusPacketFormat"
  import CrosslinkTenderlinkAccountabilityEvidenceFormat as AccountabilityFormat from
    "./CrosslinkTenderlinkAccountabilityEvidenceFormat"
  import CrosslinkTenderlinkNonceAckTransport as NonceAckTransport from
    "./CrosslinkTenderlinkNonceAckTransport"
  import CrosslinkTenderlinkStatusPacketFormat as StatusFormat from
    "./CrosslinkTenderlinkStatusPacketFormat"
  import CrosslinkMalachiteProposalProtobufFormat as MalachiteProposalFormat from
    "./CrosslinkMalachiteProposalProtobufFormat"
  import CrosslinkMalachiteLivenessProtobufFormat as MalachiteLivenessFormat from
    "./CrosslinkMalachiteLivenessProtobufFormat"
  import CrosslinkMalachiteSyncProtobufFormat as MalachiteSyncFormat from
    "./CrosslinkMalachiteSyncProtobufFormat"

  type Protocol_t = str
  type Channel_t = str
  type Topic_t = str
  type Kind_t = str
  type Bytes_t = str
  type ProductionEnvelope_t = {
    protocol: Protocol_t,
    channel: Channel_t,
    topic: Topic_t,
    kind: Kind_t,
    bytes: Bytes_t,
  }

  pure val TenderlinkProtocol = "tenderlink"
  pure val MalachiteProtocol = "malachite"
  pure val DynamicSigmaProtocol = "dynamic-sigma"
  pure val ProductionFinalityProtocol = "production-finality"
  pure val UnknownProtocol = "unknown-protocol"

  pure val TenderlinkConsensusChannel = "tenderlink-consensus-channel"
  pure val TenderlinkEvidenceChannel = "tenderlink-evidence-channel"
  pure val TenderlinkKnownPeerChannel = "tenderlink-known-peer-channel"
  pure val TenderlinkStatusChannel = "tenderlink-status-channel"

  pure val MalachiteProposalChannel = "malachite-proposal-channel"
  pure val MalachiteLivenessChannel = "malachite-liveness-channel"
  pure val MalachiteSyncChannel = "malachite-sync-channel"

  pure val DynamicSigmaConsensusParamChannel =
    "dynamic-sigma-consensus-param-channel"
  pure val DynamicSigmaBftPayloadChannel =
    "dynamic-sigma-bft-payload-channel"
  pure val ProductionBftBlockProposalChannel =
    "production-bft-block-proposal-channel"
  pure val ProductionFatPointerWireChannel =
    "production-fat-pointer-wire-channel"

  pure val CrosslinkConsensusTopic = "crosslink-consensus-v1"
  pure val DynamicSigmaProposalTopic =
    "crosslink-dynamic-sigma-proposal-v1"
  pure val MalachiteProposalTopic = "crosslink-proposal-v1"
  pure val MalachiteLivenessTopic = "crosslink-liveness-v1"
  pure val MalachiteSyncTopic = "crosslink-sync-v1"
  pure val WrongTopic = "zcash-blocks-v1"

  pure val TenderlinkProposalChunkKind = "proposal-chunk"
  pure val TenderlinkPolPrevoteKind = "pol-prevote"
  pure val TenderlinkNilPrecommitKind = "nil-precommit"
  pure val TenderlinkValuePrecommitKind = "value-precommit"
  pure val TenderlinkMixedPrecommitKind = "mixed-precommit"
  pure val TenderlinkNilPrecommitCertificateKind =
    "nil-precommit-certificate"
  pure val TenderlinkValuePrecommitCertificateKind =
    "value-precommit-certificate"
  pure val TenderlinkAccountabilityEvidenceKind = "accountability-evidence"
  pure val TenderlinkKnownPeerPacketKind = "known-peer-consensus-packet"
  pure val TenderlinkStatusPacketKind = "status-packet"

  pure val MalachiteProposalKind = "proposal"
  pure val MalachiteSignedProposalKind = "signed-proposal"
  pure val MalachiteStreamedProposalKind = "streamed-proposal"
  pure val MalachitePolkaKind = "liveness-polka"
  pure val MalachiteRoundKind = "liveness-round"
  pure val MalachiteSyncRequestKind = "sync-request"
  pure val MalachiteSyncResponseKind = "sync-response"

  pure val DynamicSigmaConsensusParamKind = "consensus-param"
  pure val DynamicSigmaBftPayloadKind = "dynamic-sigma-bft-payload"
  pure val ProductionBftBlockProposalKind = "bft-block-proposal"
  pure val ProductionFatPointerWireKind = "fat-pointer-wire"

  pure val TenderlinkProposalChunkBytes =
    ConsensusPacketFormat::TestPolProposalConsensusPacketHex
  pure val TenderlinkPolPrevoteBytes =
    ConsensusPacketFormat::TestWeightedPrevoteConsensusPacketHex
  pure val TenderlinkNilPrecommitBytes =
    PrecommitTransport::NilPrecommitConsensusPacketHex
  pure val TenderlinkValuePrecommitBytes =
    PrecommitTransport::ValuePrecommitConsensusPacketHex
  pure val TenderlinkMixedPrecommitBytes =
    PrecommitTransport::MixedPrecommitQuorumConsensusPacketHex
  pure val TenderlinkNilPrecommitCertificateBytes =
    PrecommitTransport::NilPrecommitQuorumConsensusPacketHex
  pure val TenderlinkValuePrecommitCertificateBytes =
    PrecommitTransport::ValuePrecommitQuorumConsensusPacketHex
  pure val TenderlinkAccountabilityEvidenceBytes =
    AccountabilityFormat::NilValuePrecommitEvidenceHex
  pure val TenderlinkKnownPeerPacketBytes =
    NonceAckTransport::AckedPrevotePacketHex
  pure val TenderlinkStatusPacketBytes = StatusFormat::ValidStatusPacketHex

  pure val MalachiteProposalBytes =
    MalachiteProposalFormat::ProposalWithPolHex
  pure val MalachiteSignedProposalBytes =
    MalachiteProposalFormat::SignedProposalHex
  pure val MalachiteStreamedProposalBytes =
    MalachiteProposalFormat::StreamedProposalHex
  pure val MalachitePolkaBytes =
    MalachiteLivenessFormat::LivenessPolkaMessageHex
  pure val MalachiteRoundBytes =
    MalachiteLivenessFormat::LivenessRoundSkipMessageHex
  pure val MalachiteSyncRequestBytes =
    MalachiteSyncFormat::SyncRequestHex
  pure val MalachiteSyncResponseBytes =
    MalachiteSyncFormat::SyncResponseWithValueHex

  // Exact production-shaped consensus-param bytes pinned in
  // CrosslinkDynamicSigmaConsensusParamFormat.qnt.
  pure val DynamicSigmaConsensusParamH1RaisedBytes =
    "0101000000000000000300"
  pure val DynamicSigmaConsensusParamH2StableBytes =
    "0102000000010000000200"
  pure val DynamicSigmaConsensusParamH2RaisedBytes =
    "0102000000010000000300"

  pure val DynamicSigmaConsensusParamBytes =
    Set(
      DynamicSigmaConsensusParamH1RaisedBytes,
      DynamicSigmaConsensusParamH2StableBytes,
      DynamicSigmaConsensusParamH2RaisedBytes,
    )

  pure val DynamicSigmaBftPayloadFixtureBytes =
    "dynamic-sigma-bft-payload-magic434c445349473031-evidence123-block4619-headers3-selected3"
  pure val DynamicSigmaBftPayloadFixtureMagicHex = "434c445349473031"
  pure val DynamicSigmaBftPayloadFixtureEvidenceByteLen = 123
  pure val DynamicSigmaBftPayloadFixtureEvidenceOffset = 8
  pure val DynamicSigmaBftPayloadFixtureBlockOffset = 131
  pure val DynamicSigmaBftPayloadFixtureBftBlockByteLen = 4619
  pure val DynamicSigmaBftPayloadFixturePayloadByteLen = 4750
  pure val DynamicSigmaBftPayloadFixtureHeaderCount = 3
  pure val DynamicSigmaBftPayloadFixtureSelectedSigma = 3

  pure val ProductionBftBlockProposalFixtureBytes =
    "bft-block-v0-h2-finality0-len4619-total4761-headers3-offset150-154-158"
  pure val ProductionFatPointerWireFixtureBytes =
    CheckedInFixtureTrailingFatPointerWireHex

  pure val ProductionBftBlockProposalFixtureVersion = 0
  pure val ProductionBftBlockProposalFixtureHeight = 2
  pure val ProductionBftBlockProposalFixtureFinalityCandidateHeight = 0
  pure val ProductionBftBlockProposalFixtureFinalityOffset = 150
  pure val ProductionBftBlockProposalFixtureHeaderCountOffset = 154
  pure val ProductionBftBlockProposalFixtureHeadersStartOffset = 158
  pure val ProductionBftBlockProposalFixturePayloadByteLen = 4619
  pure val ProductionBftBlockProposalFixtureBlockAndFatPointerByteLen = 4761
  pure val ProductionBftBlockProposalFixtureHeaderCount = 3
  pure val ProductionFatPointerWireFixtureByteLen = 142

  pure val WrongBytes = "wrong-production-gossip-bytes"

  def Envelope(
    protocol: Protocol_t,
    channel: Channel_t,
    topic: Topic_t,
    kind: Kind_t,
    bytes: Bytes_t,
  ): ProductionEnvelope_t = {
    protocol: protocol,
    channel: channel,
    topic: topic,
    kind: kind,
    bytes: bytes,
  }

  pure def ProductionTopicsDisjoint: bool =
    CrosslinkConsensusTopic != MalachiteProposalTopic and
    CrosslinkConsensusTopic != MalachiteLivenessTopic and
    CrosslinkConsensusTopic != MalachiteSyncTopic and
    CrosslinkConsensusTopic != DynamicSigmaProposalTopic and
    DynamicSigmaProposalTopic != MalachiteProposalTopic and
    DynamicSigmaProposalTopic != MalachiteLivenessTopic and
    DynamicSigmaProposalTopic != MalachiteSyncTopic and
    MalachiteProposalTopic != MalachiteLivenessTopic and
    MalachiteProposalTopic != MalachiteSyncTopic and
    MalachiteLivenessTopic != MalachiteSyncTopic

  pure val ProductionChannels =
    Set(
      TenderlinkConsensusChannel,
      TenderlinkEvidenceChannel,
      TenderlinkKnownPeerChannel,
      TenderlinkStatusChannel,
      MalachiteProposalChannel,
      MalachiteLivenessChannel,
      MalachiteSyncChannel,
      DynamicSigmaConsensusParamChannel,
      DynamicSigmaBftPayloadChannel,
      ProductionBftBlockProposalChannel,
      ProductionFatPointerWireChannel,
    )

  pure def ProductionChannelsDisjoint: bool =
    ProductionChannels.size() == 11

  def TenderlinkConsensusRouteValid(env: ProductionEnvelope_t): bool =
    env.protocol == TenderlinkProtocol and
    env.channel == TenderlinkConsensusChannel and
    env.topic == CrosslinkConsensusTopic and
    (
      (
        env.kind == TenderlinkProposalChunkKind and
        env.bytes == TenderlinkProposalChunkBytes
      ) or
      (
        env.kind == TenderlinkPolPrevoteKind and
        env.bytes == TenderlinkPolPrevoteBytes
      ) or
      (
        env.kind == TenderlinkNilPrecommitKind and
        env.bytes == TenderlinkNilPrecommitBytes
      ) or
      (
        env.kind == TenderlinkValuePrecommitKind and
        env.bytes == TenderlinkValuePrecommitBytes
      ) or
      (
        env.kind == TenderlinkMixedPrecommitKind and
        env.bytes == TenderlinkMixedPrecommitBytes
      ) or
      (
        env.kind == TenderlinkNilPrecommitCertificateKind and
        env.bytes == TenderlinkNilPrecommitCertificateBytes
      ) or
      (
        env.kind == TenderlinkValuePrecommitCertificateKind and
        env.bytes == TenderlinkValuePrecommitCertificateBytes
      )
    )

  def TenderlinkEvidenceRouteValid(env: ProductionEnvelope_t): bool =
    env.protocol == TenderlinkProtocol and
    env.channel == TenderlinkEvidenceChannel and
    env.topic == CrosslinkConsensusTopic and
    env.kind == TenderlinkAccountabilityEvidenceKind and
    env.bytes == TenderlinkAccountabilityEvidenceBytes

  def TenderlinkKnownPeerRouteValid(env: ProductionEnvelope_t): bool =
    env.protocol == TenderlinkProtocol and
    env.channel == TenderlinkKnownPeerChannel and
    env.topic == CrosslinkConsensusTopic and
    env.kind == TenderlinkKnownPeerPacketKind and
    env.bytes == TenderlinkKnownPeerPacketBytes

  def TenderlinkStatusRouteValid(env: ProductionEnvelope_t): bool =
    env.protocol == TenderlinkProtocol and
    env.channel == TenderlinkStatusChannel and
    env.topic == CrosslinkConsensusTopic and
    env.kind == TenderlinkStatusPacketKind and
    env.bytes == TenderlinkStatusPacketBytes

  def MalachiteProposalRouteValid(env: ProductionEnvelope_t): bool =
    env.protocol == MalachiteProtocol and
    env.channel == MalachiteProposalChannel and
    env.topic == MalachiteProposalTopic and
    (
      (
        env.kind == MalachiteProposalKind and
        env.bytes == MalachiteProposalBytes
      ) or
      (
        env.kind == MalachiteSignedProposalKind and
        env.bytes == MalachiteSignedProposalBytes
      ) or
      (
        env.kind == MalachiteStreamedProposalKind and
        env.bytes == MalachiteStreamedProposalBytes
      )
    )

  def MalachiteLivenessRouteValid(env: ProductionEnvelope_t): bool =
    env.protocol == MalachiteProtocol and
    env.channel == MalachiteLivenessChannel and
    env.topic == MalachiteLivenessTopic and
    (
      (
        env.kind == MalachitePolkaKind and
        env.bytes == MalachitePolkaBytes
      ) or
      (
        env.kind == MalachiteRoundKind and
        env.bytes == MalachiteRoundBytes
      )
    )

  def MalachiteSyncRouteValid(env: ProductionEnvelope_t): bool =
    env.protocol == MalachiteProtocol and
    env.channel == MalachiteSyncChannel and
    env.topic == MalachiteSyncTopic and
    (
      (
        env.kind == MalachiteSyncRequestKind and
        env.bytes == MalachiteSyncRequestBytes
      ) or
      (
        env.kind == MalachiteSyncResponseKind and
        env.bytes == MalachiteSyncResponseBytes
      )
    )

  def DynamicSigmaConsensusParamRouteValid(env: ProductionEnvelope_t): bool =
    env.protocol == DynamicSigmaProtocol and
    env.channel == DynamicSigmaConsensusParamChannel and
    env.topic == CrosslinkConsensusTopic and
    env.kind == DynamicSigmaConsensusParamKind and
    DynamicSigmaConsensusParamBytes.contains(env.bytes)

  def DynamicSigmaBftPayloadFixtureMetadataCoherent: bool =
    DynamicSigmaBftPayloadFixtureMagicHex == "434c445349473031" and
    DynamicSigmaBftPayloadFixtureEvidenceOffset == 8 and
    DynamicSigmaBftPayloadFixtureEvidenceByteLen == 123 and
    DynamicSigmaBftPayloadFixtureBlockOffset ==
      DynamicSigmaBftPayloadFixtureEvidenceOffset +
        DynamicSigmaBftPayloadFixtureEvidenceByteLen and
    DynamicSigmaBftPayloadFixtureBftBlockByteLen ==
      FixtureLaterBftBlockByteLen and
    DynamicSigmaBftPayloadFixturePayloadByteLen ==
      DynamicSigmaBftPayloadFixtureBlockOffset +
        DynamicSigmaBftPayloadFixtureBftBlockByteLen and
    DynamicSigmaBftPayloadFixtureHeaderCount == FixtureHeaderCount and
    DynamicSigmaBftPayloadFixtureSelectedSigma ==
      DynamicSigmaBftPayloadFixtureHeaderCount

  def DynamicSigmaBftPayloadRouteValid(env: ProductionEnvelope_t): bool =
    DynamicSigmaBftPayloadFixtureMetadataCoherent and
    env.protocol == DynamicSigmaProtocol and
    env.channel == DynamicSigmaBftPayloadChannel and
    env.topic == DynamicSigmaProposalTopic and
    env.kind == DynamicSigmaBftPayloadKind and
    env.bytes == DynamicSigmaBftPayloadFixtureBytes

  def ProductionBftBlockProposalFixtureMetadataCoherent: bool =
    GeneratedAllBftBlockVersionsZero and
    GeneratedAllFinalizationCandidateHeightsZero and
    FixtureLaterBftBlockVersion ==
      ProductionBftBlockProposalFixtureVersion and
    FixtureLaterBftHeight == ProductionBftBlockProposalFixtureHeight and
    FixtureLaterFinalizationCandidateHeight ==
      ProductionBftBlockProposalFixtureFinalityCandidateHeight and
    FixtureLaterFinalizationCandidateHeightOffset ==
      ProductionBftBlockProposalFixtureFinalityOffset and
    FixtureLaterHeaderCountOffset ==
      ProductionBftBlockProposalFixtureHeaderCountOffset and
    FixtureLaterHeadersStartOffset ==
      ProductionBftBlockProposalFixtureHeadersStartOffset and
    FixtureLaterBftBlockByteLen ==
      ProductionBftBlockProposalFixturePayloadByteLen and
    FixtureLaterBftBlockAndFatPointerByteLen ==
      ProductionBftBlockProposalFixtureBlockAndFatPointerByteLen and
    FixtureHeaderCount == ProductionBftBlockProposalFixtureHeaderCount and
    CheckedInFixtureTrailingFatPointerOffset ==
      FixtureLaterBftBlockByteLen and
    FixtureLaterHeader2EndOffset == FixtureLaterBftBlockByteLen

  def ProductionFatPointerWireFixtureMetadataCoherent: bool =
    GeneratedAllTrailingFatPointerSignatureCountsOne and
    FixtureTrailingFatPointerSignatureCount == 1 and
    ProductionFatPointerWireFixtureByteLen ==
      FixtureLaterBftBlockAndFatPointerByteLen -
        FixtureLaterBftBlockByteLen and
    CheckedInFixtureTrailingFatPointerOffset ==
      FixtureLaterBftBlockByteLen

  def ProductionBftBlockProposalRouteValid(
    env: ProductionEnvelope_t,
  ): bool =
    ProductionBftBlockProposalFixtureMetadataCoherent and
    env.protocol == ProductionFinalityProtocol and
    env.channel == ProductionBftBlockProposalChannel and
    env.topic == CrosslinkConsensusTopic and
    env.kind == ProductionBftBlockProposalKind and
    env.bytes == ProductionBftBlockProposalFixtureBytes

  def ProductionFatPointerWireRouteValid(env: ProductionEnvelope_t): bool =
    ProductionFatPointerWireFixtureMetadataCoherent and
    env.protocol == ProductionFinalityProtocol and
    env.channel == ProductionFatPointerWireChannel and
    env.topic == CrosslinkConsensusTopic and
    env.kind == ProductionFatPointerWireKind and
    env.bytes == ProductionFatPointerWireFixtureBytes

  def ProductionRouteValid(env: ProductionEnvelope_t): bool =
    TenderlinkConsensusRouteValid(env) or
    TenderlinkEvidenceRouteValid(env) or
    TenderlinkKnownPeerRouteValid(env) or
    TenderlinkStatusRouteValid(env) or
    MalachiteProposalRouteValid(env) or
    MalachiteLivenessRouteValid(env) or
    MalachiteSyncRouteValid(env) or
    DynamicSigmaConsensusParamRouteValid(env) or
    DynamicSigmaBftPayloadRouteValid(env) or
    ProductionBftBlockProposalRouteValid(env) or
    ProductionFatPointerWireRouteValid(env)

  pure val TenderlinkMixedPrecommitEnvelope =
    Envelope(
      TenderlinkProtocol,
      TenderlinkConsensusChannel,
      CrosslinkConsensusTopic,
      TenderlinkMixedPrecommitKind,
      TenderlinkMixedPrecommitBytes,
    )
  pure val TenderlinkNilPrecommitCertificateEnvelope =
    Envelope(
      TenderlinkProtocol,
      TenderlinkConsensusChannel,
      CrosslinkConsensusTopic,
      TenderlinkNilPrecommitCertificateKind,
      TenderlinkNilPrecommitCertificateBytes,
    )
  pure val TenderlinkValuePrecommitCertificateEnvelope =
    Envelope(
      TenderlinkProtocol,
      TenderlinkConsensusChannel,
      CrosslinkConsensusTopic,
      TenderlinkValuePrecommitCertificateKind,
      TenderlinkValuePrecommitCertificateBytes,
    )
  pure val TenderlinkEvidenceEnvelope =
    Envelope(
      TenderlinkProtocol,
      TenderlinkEvidenceChannel,
      CrosslinkConsensusTopic,
      TenderlinkAccountabilityEvidenceKind,
      TenderlinkAccountabilityEvidenceBytes,
    )
  pure val TenderlinkKnownPeerEnvelope =
    Envelope(
      TenderlinkProtocol,
      TenderlinkKnownPeerChannel,
      CrosslinkConsensusTopic,
      TenderlinkKnownPeerPacketKind,
      TenderlinkKnownPeerPacketBytes,
    )
  pure val TenderlinkStatusEnvelope =
    Envelope(
      TenderlinkProtocol,
      TenderlinkStatusChannel,
      CrosslinkConsensusTopic,
      TenderlinkStatusPacketKind,
      TenderlinkStatusPacketBytes,
    )

  pure val MalachiteProposalEnvelope =
    Envelope(
      MalachiteProtocol,
      MalachiteProposalChannel,
      MalachiteProposalTopic,
      MalachiteProposalKind,
      MalachiteProposalBytes,
    )
  pure val MalachiteSignedProposalEnvelope =
    Envelope(
      MalachiteProtocol,
      MalachiteProposalChannel,
      MalachiteProposalTopic,
      MalachiteSignedProposalKind,
      MalachiteSignedProposalBytes,
    )
  pure val MalachiteStreamedProposalEnvelope =
    Envelope(
      MalachiteProtocol,
      MalachiteProposalChannel,
      MalachiteProposalTopic,
      MalachiteStreamedProposalKind,
      MalachiteStreamedProposalBytes,
    )
  pure val MalachitePolkaEnvelope =
    Envelope(
      MalachiteProtocol,
      MalachiteLivenessChannel,
      MalachiteLivenessTopic,
      MalachitePolkaKind,
      MalachitePolkaBytes,
    )
  pure val MalachiteRoundEnvelope =
    Envelope(
      MalachiteProtocol,
      MalachiteLivenessChannel,
      MalachiteLivenessTopic,
      MalachiteRoundKind,
      MalachiteRoundBytes,
    )
  pure val MalachiteSyncRequestEnvelope =
    Envelope(
      MalachiteProtocol,
      MalachiteSyncChannel,
      MalachiteSyncTopic,
      MalachiteSyncRequestKind,
      MalachiteSyncRequestBytes,
    )
  pure val MalachiteSyncResponseEnvelope =
    Envelope(
      MalachiteProtocol,
      MalachiteSyncChannel,
      MalachiteSyncTopic,
      MalachiteSyncResponseKind,
      MalachiteSyncResponseBytes,
    )

  pure val DynamicSigmaConsensusParamEnvelope =
    Envelope(
      DynamicSigmaProtocol,
      DynamicSigmaConsensusParamChannel,
      CrosslinkConsensusTopic,
      DynamicSigmaConsensusParamKind,
      DynamicSigmaConsensusParamH1RaisedBytes,
    )
  pure val DynamicSigmaConsensusParamRecoveredEnvelope =
    Envelope(
      DynamicSigmaProtocol,
      DynamicSigmaConsensusParamChannel,
      CrosslinkConsensusTopic,
      DynamicSigmaConsensusParamKind,
      DynamicSigmaConsensusParamH2StableBytes,
    )
  pure val DynamicSigmaBftPayloadEnvelope =
    Envelope(
      DynamicSigmaProtocol,
      DynamicSigmaBftPayloadChannel,
      DynamicSigmaProposalTopic,
      DynamicSigmaBftPayloadKind,
      DynamicSigmaBftPayloadFixtureBytes,
    )

  pure val ProductionBftBlockProposalEnvelope =
    Envelope(
      ProductionFinalityProtocol,
      ProductionBftBlockProposalChannel,
      CrosslinkConsensusTopic,
      ProductionBftBlockProposalKind,
      ProductionBftBlockProposalFixtureBytes,
    )
  pure val ProductionFatPointerWireEnvelope =
    Envelope(
      ProductionFinalityProtocol,
      ProductionFatPointerWireChannel,
      CrosslinkConsensusTopic,
      ProductionFatPointerWireKind,
      ProductionFatPointerWireFixtureBytes,
    )

  pure val MalachiteProposalOnTenderlinkConsensus =
    Envelope(
      MalachiteProtocol,
      TenderlinkConsensusChannel,
      CrosslinkConsensusTopic,
      MalachiteSignedProposalKind,
      MalachiteSignedProposalBytes,
    )
  pure val TenderlinkPrecommitOnMalachiteLiveness =
    Envelope(
      TenderlinkProtocol,
      MalachiteLivenessChannel,
      MalachiteLivenessTopic,
      TenderlinkMixedPrecommitKind,
      TenderlinkMixedPrecommitBytes,
    )
  pure val TenderlinkKindOnMalachiteProposal =
    Envelope(
      MalachiteProtocol,
      MalachiteProposalChannel,
      MalachiteProposalTopic,
      TenderlinkProposalChunkKind,
      TenderlinkProposalChunkBytes,
    )
  pure val MalachiteRoundOnTenderlinkConsensus =
    Envelope(
      TenderlinkProtocol,
      TenderlinkConsensusChannel,
      CrosslinkConsensusTopic,
      MalachiteRoundKind,
      MalachiteRoundBytes,
    )
  pure val DynamicSigmaParamOnTenderlinkConsensus =
    Envelope(
      DynamicSigmaProtocol,
      TenderlinkConsensusChannel,
      CrosslinkConsensusTopic,
      DynamicSigmaConsensusParamKind,
      DynamicSigmaConsensusParamH1RaisedBytes,
    )
  pure val TenderlinkPrecommitOnDynamicSigmaParam =
    Envelope(
      TenderlinkProtocol,
      DynamicSigmaConsensusParamChannel,
      CrosslinkConsensusTopic,
      TenderlinkMixedPrecommitKind,
      TenderlinkMixedPrecommitBytes,
    )
  pure val TenderlinkPrecommitOnDynamicSigmaBftPayload =
    Envelope(
      TenderlinkProtocol,
      DynamicSigmaBftPayloadChannel,
      DynamicSigmaProposalTopic,
      TenderlinkMixedPrecommitKind,
      TenderlinkMixedPrecommitBytes,
    )
  pure val MalachiteRoundOnDynamicSigmaParam =
    Envelope(
      MalachiteProtocol,
      DynamicSigmaConsensusParamChannel,
      CrosslinkConsensusTopic,
      MalachiteRoundKind,
      MalachiteRoundBytes,
    )
  pure val DynamicSigmaPayloadOnTenderlinkConsensus =
    Envelope(
      DynamicSigmaProtocol,
      TenderlinkConsensusChannel,
      CrosslinkConsensusTopic,
      DynamicSigmaBftPayloadKind,
      DynamicSigmaBftPayloadFixtureBytes,
    )
  pure val WrongBytesDynamicSigmaParamEnvelope =
    Envelope(
      DynamicSigmaProtocol,
      DynamicSigmaConsensusParamChannel,
      CrosslinkConsensusTopic,
      DynamicSigmaConsensusParamKind,
      WrongBytes,
    )
  pure val WrongBytesDynamicSigmaBftPayloadEnvelope =
    Envelope(
      DynamicSigmaProtocol,
      DynamicSigmaBftPayloadChannel,
      DynamicSigmaProposalTopic,
      DynamicSigmaBftPayloadKind,
      WrongBytes,
    )
  pure val ProductionBftBlockProposalOnTenderlinkConsensus =
    Envelope(
      ProductionFinalityProtocol,
      TenderlinkConsensusChannel,
      CrosslinkConsensusTopic,
      ProductionBftBlockProposalKind,
      ProductionBftBlockProposalFixtureBytes,
    )
  pure val ProductionFatPointerWireOnDynamicSigmaParam =
    Envelope(
      ProductionFinalityProtocol,
      DynamicSigmaConsensusParamChannel,
      CrosslinkConsensusTopic,
      ProductionFatPointerWireKind,
      ProductionFatPointerWireFixtureBytes,
    )
  pure val TenderlinkPrecommitOnProductionFinalityProposal =
    Envelope(
      TenderlinkProtocol,
      ProductionBftBlockProposalChannel,
      CrosslinkConsensusTopic,
      TenderlinkMixedPrecommitKind,
      TenderlinkMixedPrecommitBytes,
    )
  pure val WrongBytesProductionBftBlockProposalEnvelope =
    Envelope(
      ProductionFinalityProtocol,
      ProductionBftBlockProposalChannel,
      CrosslinkConsensusTopic,
      ProductionBftBlockProposalKind,
      WrongBytes,
    )
  pure val WrongTopicTenderlinkEnvelope =
    Envelope(
      TenderlinkProtocol,
      TenderlinkConsensusChannel,
      WrongTopic,
      TenderlinkMixedPrecommitKind,
      TenderlinkMixedPrecommitBytes,
    )
  pure val WrongBytesMalachiteEnvelope =
    Envelope(
      MalachiteProtocol,
      MalachiteSyncChannel,
      MalachiteSyncTopic,
      MalachiteSyncResponseKind,
      WrongBytes,
    )
  pure val UnknownProtocolEnvelope =
    Envelope(
      UnknownProtocol,
      TenderlinkConsensusChannel,
      CrosslinkConsensusTopic,
      TenderlinkProposalChunkKind,
      TenderlinkProposalChunkBytes,
    )

  pure val ProductionFixtures =
    Set(
      TenderlinkMixedPrecommitEnvelope,
      TenderlinkNilPrecommitCertificateEnvelope,
      TenderlinkValuePrecommitCertificateEnvelope,
      TenderlinkEvidenceEnvelope,
      TenderlinkKnownPeerEnvelope,
      TenderlinkStatusEnvelope,
      MalachiteProposalEnvelope,
      MalachiteSignedProposalEnvelope,
      MalachiteStreamedProposalEnvelope,
      MalachitePolkaEnvelope,
      MalachiteRoundEnvelope,
      MalachiteSyncRequestEnvelope,
      MalachiteSyncResponseEnvelope,
      DynamicSigmaConsensusParamEnvelope,
      DynamicSigmaConsensusParamRecoveredEnvelope,
      DynamicSigmaBftPayloadEnvelope,
      ProductionBftBlockProposalEnvelope,
      ProductionFatPointerWireEnvelope,
    )

  var routedProductionEnvelopes: Set[ProductionEnvelope_t]
  var registryFiredAction: str

  val RoutedProductionEnvelopesValid =
    routedProductionEnvelopes.forall(ProductionRouteValid)

  val RegistrySafety =
    ProductionTopicsDisjoint and
    ProductionChannelsDisjoint and
    RoutedProductionEnvelopesValid

  action RegistryInit = all {
    routedProductionEnvelopes' = Set(),
    registryFiredAction' = "RegistryInit",
  }

  action RouteProduction(env: ProductionEnvelope_t): bool =
    all {
      ProductionRouteValid(env),
      routedProductionEnvelopes' =
        routedProductionEnvelopes.union(Set(env)),
      registryFiredAction' = "RouteProduction",
    }

  action RawRouteProduction(env: ProductionEnvelope_t): bool =
    all {
      routedProductionEnvelopes' =
        routedProductionEnvelopes.union(Set(env)),
      registryFiredAction' = "RawRouteProduction",
    }

  action RegistryStutter: bool =
    all {
      routedProductionEnvelopes' = routedProductionEnvelopes,
      registryFiredAction' = registryFiredAction,
    }
}

module CrosslinkProductionGossipRegistryTest {
  import CrosslinkProductionGossipRegistry.* from
    "./CrosslinkProductionGossipRegistry"
  export CrosslinkProductionGossipRegistry.*
  import CrosslinkTenderlinkPrecommitTransportSafety as PrecommitTransport from
    "./CrosslinkTenderlinkPrecommitTransportSafety"
  import CrosslinkTenderlinkConsensusPacketFormat as ConsensusPacketFormat from
    "./CrosslinkTenderlinkConsensusPacketFormat"
  import CrosslinkTenderlinkAccountabilityEvidenceFormat as AccountabilityFormat from
    "./CrosslinkTenderlinkAccountabilityEvidenceFormat"
  import CrosslinkTenderlinkNonceAckTransport as NonceAckTransport from
    "./CrosslinkTenderlinkNonceAckTransport"
  import CrosslinkTenderlinkStatusPacketFormat as StatusFormat from
    "./CrosslinkTenderlinkStatusPacketFormat"
  import CrosslinkMalachiteProposalProtobufFormat as MalachiteProposalFormat from
    "./CrosslinkMalachiteProposalProtobufFormat"
  import CrosslinkMalachiteLivenessProtobufFormat as MalachiteLivenessFormat from
    "./CrosslinkMalachiteLivenessProtobufFormat"
  import CrosslinkMalachiteSyncProtobufFormat as MalachiteSyncFormat from
    "./CrosslinkMalachiteSyncProtobufFormat"

  action RegistryNext: bool =
    any {
      nondet env = oneOf(ProductionFixtures)
      RouteProduction(env),
      RegistryStutter,
    }

  action registryUnchangedAll: bool =
    all {
      routedProductionEnvelopes' = routedProductionEnvelopes,
      registryFiredAction' = registryFiredAction,
    }

  run routesAllProductionFamiliesTogetherTest = {
    RegistryInit
      .then(RouteProduction(TenderlinkMixedPrecommitEnvelope))
      .then(RouteProduction(TenderlinkNilPrecommitCertificateEnvelope))
      .then(RouteProduction(TenderlinkEvidenceEnvelope))
      .then(RouteProduction(TenderlinkKnownPeerEnvelope))
      .then(RouteProduction(TenderlinkStatusEnvelope))
      .then(RouteProduction(MalachiteSignedProposalEnvelope))
      .then(RouteProduction(MalachiteRoundEnvelope))
      .then(RouteProduction(MalachiteSyncResponseEnvelope))
      .then(RouteProduction(DynamicSigmaConsensusParamEnvelope))
      .then(RouteProduction(DynamicSigmaConsensusParamRecoveredEnvelope))
      .then(RouteProduction(DynamicSigmaBftPayloadEnvelope))
      .then(RouteProduction(ProductionBftBlockProposalEnvelope))
      .then(RouteProduction(ProductionFatPointerWireEnvelope))
      .then(all {
        assert(RegistrySafety),
        assert(routedProductionEnvelopes.contains(TenderlinkMixedPrecommitEnvelope)),
        assert(
          routedProductionEnvelopes.contains(
            TenderlinkNilPrecommitCertificateEnvelope
          )
        ),
        assert(routedProductionEnvelopes.contains(TenderlinkEvidenceEnvelope)),
        assert(routedProductionEnvelopes.contains(TenderlinkKnownPeerEnvelope)),
        assert(routedProductionEnvelopes.contains(TenderlinkStatusEnvelope)),
        assert(routedProductionEnvelopes.contains(MalachiteSignedProposalEnvelope)),
        assert(routedProductionEnvelopes.contains(MalachiteRoundEnvelope)),
        assert(routedProductionEnvelopes.contains(MalachiteSyncResponseEnvelope)),
        assert(
          routedProductionEnvelopes.contains(
            DynamicSigmaConsensusParamEnvelope
          )
        ),
        assert(
          routedProductionEnvelopes.contains(
            DynamicSigmaConsensusParamRecoveredEnvelope
          )
        ),
        assert(
          routedProductionEnvelopes.contains(
            DynamicSigmaBftPayloadEnvelope
          )
        ),
        assert(
          routedProductionEnvelopes.contains(
            ProductionBftBlockProposalEnvelope
          )
        ),
        assert(
          routedProductionEnvelopes.contains(
            ProductionFatPointerWireEnvelope
          )
        ),
        registryUnchangedAll,
      })
  }

  run productionFinalityFixtureBytesBridgeTest = {
    RegistryInit
      .then(RouteProduction(ProductionBftBlockProposalEnvelope))
      .then(RouteProduction(ProductionFatPointerWireEnvelope))
      .then(all {
        assert(ProductionBftBlockProposalFixtureBytes ==
          "bft-block-v0-h2-finality0-len4619-total4761-headers3-offset150-154-158"),
        assert(ProductionFatPointerWireFixtureBytes ==
          CheckedInFixtureTrailingFatPointerWireHex),
        assert(ProductionBftBlockProposalFixtureMetadataCoherent),
        assert(ProductionFatPointerWireFixtureMetadataCoherent),
        assert(
          ProductionBftBlockProposalFixturePayloadByteLen == 4619
        ),
        assert(
          ProductionBftBlockProposalFixtureBlockAndFatPointerByteLen == 4761
        ),
        assert(ProductionFatPointerWireFixtureByteLen == 142),
        assert(RegistrySafety),
        registryUnchangedAll,
      })
  }

  run tenderlinkPrecommitProductionBytesMatchTransportBridgeTest = {
    RegistryInit
      .then(RouteProduction(TenderlinkNilPrecommitCertificateEnvelope))
      .then(RouteProduction(TenderlinkValuePrecommitCertificateEnvelope))
      .then(RouteProduction(TenderlinkMixedPrecommitEnvelope))
      .then(all {
        assert(TenderlinkNilPrecommitCertificateBytes ==
          PrecommitTransport::NilPrecommitQuorumConsensusPacketHex),
        assert(TenderlinkValuePrecommitCertificateBytes ==
          PrecommitTransport::ValuePrecommitQuorumConsensusPacketHex),
        assert(TenderlinkMixedPrecommitBytes ==
          PrecommitTransport::MixedPrecommitQuorumConsensusPacketHex),
        assert(TenderlinkConsensusRouteValid(
          TenderlinkValuePrecommitCertificateEnvelope
        )),
        assert(RegistrySafety),
        registryUnchangedAll,
      })
  }

  run tenderlinkProposalPolProductionBytesMatchPacketFormatBridgeTest = {
    RegistryInit
      .then(RouteProduction(Envelope(
        TenderlinkProtocol,
        TenderlinkConsensusChannel,
        CrosslinkConsensusTopic,
        TenderlinkProposalChunkKind,
        TenderlinkProposalChunkBytes,
      )))
      .then(RouteProduction(Envelope(
        TenderlinkProtocol,
        TenderlinkConsensusChannel,
        CrosslinkConsensusTopic,
        TenderlinkPolPrevoteKind,
        TenderlinkPolPrevoteBytes,
      )))
      .then(all {
        assert(TenderlinkProposalChunkBytes ==
          ConsensusPacketFormat::TestPolProposalConsensusPacketHex),
        assert(TenderlinkPolPrevoteBytes ==
          ConsensusPacketFormat::TestWeightedPrevoteConsensusPacketHex),
        assert(RegistrySafety),
        registryUnchangedAll,
      })
  }

  run tenderlinkSideLaneProductionBytesMatchFormatBridgeTest = {
    RegistryInit
      .then(RouteProduction(TenderlinkEvidenceEnvelope))
      .then(RouteProduction(TenderlinkKnownPeerEnvelope))
      .then(RouteProduction(TenderlinkStatusEnvelope))
      .then(all {
        assert(TenderlinkAccountabilityEvidenceBytes ==
          AccountabilityFormat::NilValuePrecommitEvidenceHex),
        assert(TenderlinkKnownPeerPacketBytes ==
          NonceAckTransport::AckedPrevotePacketHex),
        assert(TenderlinkStatusPacketBytes ==
          StatusFormat::ValidStatusPacketHex),
        assert(TenderlinkEvidenceRouteValid(TenderlinkEvidenceEnvelope)),
        assert(TenderlinkKnownPeerRouteValid(TenderlinkKnownPeerEnvelope)),
        assert(TenderlinkStatusRouteValid(TenderlinkStatusEnvelope)),
        assert(RegistrySafety),
        registryUnchangedAll,
      })
  }

  run malachiteProductionBytesMatchProtobufFormatBridgeTest = {
    RegistryInit
      .then(RouteProduction(MalachiteProposalEnvelope))
      .then(RouteProduction(MalachiteSignedProposalEnvelope))
      .then(RouteProduction(MalachiteStreamedProposalEnvelope))
      .then(RouteProduction(MalachitePolkaEnvelope))
      .then(RouteProduction(MalachiteRoundEnvelope))
      .then(RouteProduction(MalachiteSyncRequestEnvelope))
      .then(RouteProduction(MalachiteSyncResponseEnvelope))
      .then(all {
        assert(MalachiteProposalBytes ==
          MalachiteProposalFormat::ProposalWithPolHex),
        assert(MalachiteSignedProposalBytes ==
          MalachiteProposalFormat::SignedProposalHex),
        assert(MalachiteStreamedProposalBytes ==
          MalachiteProposalFormat::StreamedProposalHex),
        assert(MalachitePolkaBytes ==
          MalachiteLivenessFormat::LivenessPolkaMessageHex),
        assert(MalachiteRoundBytes ==
          MalachiteLivenessFormat::LivenessRoundSkipMessageHex),
        assert(MalachiteSyncRequestBytes ==
          MalachiteSyncFormat::SyncRequestHex),
        assert(MalachiteSyncResponseBytes ==
          MalachiteSyncFormat::SyncResponseWithValueHex),
        assert(RegistrySafety),
        registryUnchangedAll,
      })
  }

  run dynamicSigmaProductionBytesMatchFormatBridgeTest = {
    RegistryInit
      .then(RouteProduction(DynamicSigmaConsensusParamEnvelope))
      .then(RouteProduction(DynamicSigmaConsensusParamRecoveredEnvelope))
      .then(RouteProduction(DynamicSigmaBftPayloadEnvelope))
      .then(all {
        assert(
          DynamicSigmaConsensusParamH1RaisedBytes ==
            "0101000000000000000300"
        ),
        assert(
          DynamicSigmaConsensusParamH2StableBytes ==
            "0102000000010000000200"
        ),
        assert(
          DynamicSigmaConsensusParamH2RaisedBytes ==
            "0102000000010000000300"
        ),
        assert(
          DynamicSigmaBftPayloadFixtureBytes ==
            "dynamic-sigma-bft-payload-magic434c445349473031-evidence123-block4619-headers3-selected3"
        ),
        assert(DynamicSigmaBftPayloadFixtureMetadataCoherent),
        assert(DynamicSigmaBftPayloadFixturePayloadByteLen == 4750),
        assert(DynamicSigmaBftPayloadFixtureSelectedSigma == 3),
        assert(RegistrySafety),
        registryUnchangedAll,
      })
  }

  run productionNamespacesDisjointTest = {
    RegistryInit.then(all {
      assert(ProductionTopicsDisjoint),
      assert(ProductionChannelsDisjoint),
      assert(RegistrySafety),
      registryUnchangedAll,
    })
  }

  run malachiteProposalOnTenderlinkConsensusRejectedTest = {
    RegistryInit.then(RouteProduction(MalachiteProposalOnTenderlinkConsensus)).fail()
  }

  run tenderlinkPrecommitOnMalachiteLivenessRejectedTest = {
    RegistryInit.then(RouteProduction(TenderlinkPrecommitOnMalachiteLiveness)).fail()
  }

  run dynamicSigmaParamOnTenderlinkConsensusRejectedTest = {
    RegistryInit.then(RouteProduction(DynamicSigmaParamOnTenderlinkConsensus)).fail()
  }

  run dynamicSigmaPayloadOnTenderlinkConsensusRejectedTest = {
    RegistryInit
      .then(RouteProduction(DynamicSigmaPayloadOnTenderlinkConsensus))
      .fail()
  }

  run tenderlinkPrecommitOnDynamicSigmaParamRejectedTest = {
    RegistryInit.then(RouteProduction(TenderlinkPrecommitOnDynamicSigmaParam)).fail()
  }

  run tenderlinkPrecommitOnDynamicSigmaPayloadRejectedTest = {
    RegistryInit
      .then(RouteProduction(TenderlinkPrecommitOnDynamicSigmaBftPayload))
      .fail()
  }

  run malachiteRoundOnDynamicSigmaParamRejectedTest = {
    RegistryInit.then(RouteProduction(MalachiteRoundOnDynamicSigmaParam)).fail()
  }

  run productionFinalityProposalOnTenderlinkConsensusRejectedTest = {
    RegistryInit
      .then(RouteProduction(ProductionBftBlockProposalOnTenderlinkConsensus))
      .fail()
  }

  run productionFatPointerWireOnDynamicSigmaParamRejectedTest = {
    RegistryInit
      .then(RouteProduction(ProductionFatPointerWireOnDynamicSigmaParam))
      .fail()
  }

  run tenderlinkPrecommitOnProductionFinalityProposalRejectedTest = {
    RegistryInit
      .then(RouteProduction(TenderlinkPrecommitOnProductionFinalityProposal))
      .fail()
  }

  run wrongTopicTenderlinkRejectedTest = {
    RegistryInit.then(RouteProduction(WrongTopicTenderlinkEnvelope)).fail()
  }

  run wrongBytesDynamicSigmaParamRejectedTest = {
    RegistryInit.then(RouteProduction(WrongBytesDynamicSigmaParamEnvelope)).fail()
  }

  run wrongBytesDynamicSigmaBftPayloadRejectedTest = {
    RegistryInit
      .then(RouteProduction(WrongBytesDynamicSigmaBftPayloadEnvelope))
      .fail()
  }

  run wrongBytesProductionFinalityProposalRejectedTest = {
    RegistryInit
      .then(RouteProduction(WrongBytesProductionBftBlockProposalEnvelope))
      .fail()
  }

  run wrongBytesMalachiteRejectedTest = {
    RegistryInit.then(RouteProduction(WrongBytesMalachiteEnvelope)).fail()
  }

  run unknownProtocolRejectedTest = {
    RegistryInit.then(RouteProduction(UnknownProtocolEnvelope)).fail()
  }

  run rawTenderlinkKindOnMalachiteProposalViolatesSafetyTest = {
    RegistryInit
      .then(RawRouteProduction(TenderlinkKindOnMalachiteProposal))
      .then(all {
        assert(not(RegistrySafety)),
        registryUnchangedAll,
      })
  }

  run rawMalachiteRoundOnTenderlinkConsensusViolatesSafetyTest = {
    RegistryInit
      .then(RawRouteProduction(MalachiteRoundOnTenderlinkConsensus))
      .then(all {
        assert(not(RegistrySafety)),
        registryUnchangedAll,
      })
  }

  run rawDynamicSigmaParamOnTenderlinkConsensusViolatesSafetyTest = {
    RegistryInit
      .then(RawRouteProduction(DynamicSigmaParamOnTenderlinkConsensus))
      .then(all {
        assert(not(RegistrySafety)),
        registryUnchangedAll,
      })
  }

  run rawDynamicSigmaPayloadOnTenderlinkConsensusViolatesSafetyTest = {
    RegistryInit
      .then(RawRouteProduction(DynamicSigmaPayloadOnTenderlinkConsensus))
      .then(all {
        assert(not(RegistrySafety)),
        registryUnchangedAll,
      })
  }

  run rawProductionFinalityProposalOnTenderlinkConsensusViolatesSafetyTest = {
    RegistryInit
      .then(RawRouteProduction(ProductionBftBlockProposalOnTenderlinkConsensus))
      .then(all {
        assert(not(RegistrySafety)),
        registryUnchangedAll,
      })
  }

  run rawTenderlinkPrecommitOnDynamicSigmaParamViolatesSafetyTest = {
    RegistryInit
      .then(RawRouteProduction(TenderlinkPrecommitOnDynamicSigmaParam))
      .then(all {
        assert(not(RegistrySafety)),
        registryUnchangedAll,
      })
  }

  run rawTenderlinkPrecommitOnDynamicSigmaPayloadViolatesSafetyTest = {
    RegistryInit
      .then(RawRouteProduction(TenderlinkPrecommitOnDynamicSigmaBftPayload))
      .then(all {
        assert(not(RegistrySafety)),
        registryUnchangedAll,
      })
  }

  run rawUnknownProtocolViolatesSafetyTest = {
    RegistryInit
      .then(RawRouteProduction(UnknownProtocolEnvelope))
      .then(all {
        assert(not(RegistrySafety)),
        registryUnchangedAll,
      })
  }
}

module CrosslinkProductionGossipRegistryModel {
  import CrosslinkProductionGossipRegistryTest.* from
    "./CrosslinkProductionGossipRegistry"
  export CrosslinkProductionGossipRegistryTest.*
}
