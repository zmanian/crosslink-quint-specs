module CrosslinkMalachiteSyncGossipTransport {
  /*
   Malachite sync protobuf gossip transport boundary.

   CrosslinkMalachiteSyncProtobufFormat.qnt pins exact proto3 bytes for sync
   requests, sync responses, commit certificates, and synced values. This slice
   adds the transport obligation in front of that decoder boundary: a sync
   message can only be accepted after it appears in a Crosslink sync-topic
   envelope with the expected message kind and the exact canonical protobuf
   bytes for that request or response.
   */

  import CrosslinkMalachiteSyncProtobufFormatTest.* from "./CrosslinkMalachiteSyncProtobufFormat"
  export CrosslinkMalachiteSyncProtobufFormatTest.*

  type SyncTopic_t = str
  type SyncEnvelopeKind_t = str
  type SyncTransportEnvelope_t = {
    topic: SyncTopic_t,
    kind: SyncEnvelopeKind_t,
    request: SyncRequestProto_t,
    response: SyncResponseProto_t,
    bytes: Bytes_t,
  }

  pure val CrosslinkSyncTopic = "crosslink-sync-v1"
  pure val WrongSyncTopic = "zcash-blocks-v1"
  pure val SyncRequestEnvelopeKind = "sync-request"
  pure val SyncResponseEnvelopeKind = "sync-response"
  pure val WrongEnvelopeKind = "headers"

  var gossipedSyncRequestEnvelope: Set[SyncTransportEnvelope_t]
  var gossipedSyncResponseEnvelope: Set[SyncTransportEnvelope_t]
  var syncTransportFiredAction: str

  def Env(
    topic: SyncTopic_t,
    kind: SyncEnvelopeKind_t,
    request: SyncRequestProto_t,
    response: SyncResponseProto_t,
    bytes: Bytes_t,
  ): SyncTransportEnvelope_t = {
    topic: topic,
    kind: kind,
    request: request,
    response: response,
    bytes: bytes,
  }

  def SyncRequestEnvelopeValid(env: SyncTransportEnvelope_t): bool =
    env.topic == CrosslinkSyncTopic and
    env.kind == SyncRequestEnvelopeKind and
    SyncRequestProtoCanonical(env.request) and
    env.bytes == env.request.hex

  def SyncResponseEnvelopeValid(env: SyncTransportEnvelope_t): bool =
    env.topic == CrosslinkSyncTopic and
    env.kind == SyncResponseEnvelopeKind and
    SyncResponseProtoCanonical(env.response) and
    env.bytes == env.response.hex

  def SyncRequestEnvelopeMatches(
    env: SyncTransportEnvelope_t,
    request: SyncRequestProto_t,
  ): bool =
    env.request == request and
    env.bytes == request.hex

  def SyncResponseEnvelopeMatches(
    env: SyncTransportEnvelope_t,
    response: SyncResponseProto_t,
  ): bool =
    env.response == response and
    env.bytes == response.hex

  def MatchingSyncRequestEnvelope(request: SyncRequestProto_t): bool =
    gossipedSyncRequestEnvelope.exists(env =>
      SyncRequestEnvelopeValid(env) and
      SyncRequestEnvelopeMatches(env, request)
    )

  def MatchingSyncResponseEnvelope(response: SyncResponseProto_t): bool =
    gossipedSyncResponseEnvelope.exists(env =>
      SyncResponseEnvelopeValid(env) and
      SyncResponseEnvelopeMatches(env, response)
    )

  action TransportInit = all {
    Init,
    gossipedSyncRequestEnvelope' = Set(),
    gossipedSyncResponseEnvelope' = Set(),
    syncTransportFiredAction' = "TransportInit",
  }

  action KeepTransportState = all {
    gossipedSyncRequestEnvelope' = gossipedSyncRequestEnvelope,
    gossipedSyncResponseEnvelope' = gossipedSyncResponseEnvelope,
  }

  action AcceptSyncRequestTransport(
    env: SyncTransportEnvelope_t,
  ): bool =
    all {
      SyncRequestEnvelopeValid(env),
      AcceptSyncRequest(env.request),
      gossipedSyncRequestEnvelope' =
        gossipedSyncRequestEnvelope.union(Set(env)),
      gossipedSyncResponseEnvelope' = gossipedSyncResponseEnvelope,
      syncTransportFiredAction' = "AcceptSyncRequestTransport",
    }

  action AcceptSyncResponseTransport(
    env: SyncTransportEnvelope_t,
  ): bool =
    all {
      SyncResponseEnvelopeValid(env),
      AcceptSyncResponse(env.response),
      gossipedSyncRequestEnvelope' = gossipedSyncRequestEnvelope,
      gossipedSyncResponseEnvelope' =
        gossipedSyncResponseEnvelope.union(Set(env)),
      syncTransportFiredAction' = "AcceptSyncResponseTransport",
    }

  action RawAcceptSyncRequestWithoutTransport(
    request: SyncRequestProto_t,
  ): bool =
    all {
      AcceptSyncRequest(request),
      KeepTransportState,
      syncTransportFiredAction' = "RawAcceptSyncRequestWithoutTransport",
    }

  action RawAcceptSyncResponseWithoutTransport(
    response: SyncResponseProto_t,
  ): bool =
    all {
      AcceptSyncResponse(response),
      KeepTransportState,
      syncTransportFiredAction' = "RawAcceptSyncResponseWithoutTransport",
    }

  action TransportStutter: bool =
    all {
      Stutter,
      KeepTransportState,
      syncTransportFiredAction' = syncTransportFiredAction,
    }

  val GossipedSyncRequestEnvelopesValid =
    gossipedSyncRequestEnvelope.forall(SyncRequestEnvelopeValid)

  val GossipedSyncResponseEnvelopesValid =
    gossipedSyncResponseEnvelope.forall(SyncResponseEnvelopeValid)

  val AcceptedSyncRequestsHaveTransportEnvelope =
    acceptedSyncRequests.forall(MatchingSyncRequestEnvelope)

  val AcceptedSyncResponsesHaveTransportEnvelope =
    acceptedSyncResponses.forall(MatchingSyncResponseEnvelope)

  val TransportSafety =
    Safety and
    GossipedSyncRequestEnvelopesValid and
    GossipedSyncResponseEnvelopesValid and
    AcceptedSyncRequestsHaveTransportEnvelope and
    AcceptedSyncResponsesHaveTransportEnvelope
}

module CrosslinkMalachiteSyncGossipTransportTest {
  import CrosslinkMalachiteSyncGossipTransport.* from "./CrosslinkMalachiteSyncGossipTransport"
  export CrosslinkMalachiteSyncGossipTransport.*

  pure val SyncRequestEnvelope =
    Env(
      CrosslinkSyncTopic,
      SyncRequestEnvelopeKind,
      SyncRequest,
      SyncResponseNoValue,
      SyncRequest.hex,
    )

  pure val SyncResponseWithValueEnvelope =
    Env(
      CrosslinkSyncTopic,
      SyncResponseEnvelopeKind,
      SyncRequest,
      SyncResponseWithValue,
      SyncResponseWithValue.hex,
    )

  pure val SyncResponseNoValueEnvelope =
    Env(
      CrosslinkSyncTopic,
      SyncResponseEnvelopeKind,
      SyncRequest,
      SyncResponseNoValue,
      SyncResponseNoValue.hex,
    )

  pure val WrongTopicRequestEnvelope =
    Env(
      WrongSyncTopic,
      SyncRequestEnvelopeKind,
      SyncRequest,
      SyncResponseNoValue,
      SyncRequest.hex,
    )

  pure val WrongKindRequestEnvelope =
    Env(
      CrosslinkSyncTopic,
      WrongEnvelopeKind,
      SyncRequest,
      SyncResponseNoValue,
      SyncRequest.hex,
    )

  pure val WrongBytesRequestEnvelope =
    Env(
      CrosslinkSyncTopic,
      SyncRequestEnvelopeKind,
      SyncRequest,
      SyncResponseNoValue,
      "wrong-sync-request-bytes",
    )

  pure val WrongKindResponseEnvelope =
    Env(
      CrosslinkSyncTopic,
      WrongEnvelopeKind,
      SyncRequest,
      SyncResponseWithValue,
      SyncResponseWithValue.hex,
    )

  pure val WrongBytesResponseEnvelope =
    Env(
      CrosslinkSyncTopic,
      SyncResponseEnvelopeKind,
      SyncRequest,
      SyncResponseWithValue,
      "wrong-sync-response-bytes",
    )

  pure val MissingCertificateResponse =
    SyncResponseProto(
      9,
      SyncResponseValueResponseTag,
      ValueResponseMissingCertificate,
      "0a07080112050a03aabbcc",
    )

  pure val MissingCertificateResponseEnvelope =
    Env(
      CrosslinkSyncTopic,
      SyncResponseEnvelopeKind,
      SyncRequest,
      MissingCertificateResponse,
      MissingCertificateResponse.hex,
    )

  pure val TestSyncTransportEnvelopes = Set(
    SyncRequestEnvelope,
    SyncResponseWithValueEnvelope,
    SyncResponseNoValueEnvelope,
    WrongTopicRequestEnvelope,
    WrongKindRequestEnvelope,
    WrongBytesRequestEnvelope,
    WrongKindResponseEnvelope,
    WrongBytesResponseEnvelope,
    MissingCertificateResponseEnvelope,
  )

  action TransportNext: bool =
    any {
      nondet env = oneOf(TestSyncTransportEnvelopes)
      AcceptSyncRequestTransport(env),
      nondet env = oneOf(TestSyncTransportEnvelopes)
      AcceptSyncResponseTransport(env),
      TransportStutter,
    }

  action transportUnchangedAll = all {
    acceptedSyncRequests' = acceptedSyncRequests,
    acceptedSyncResponses' = acceptedSyncResponses,
    gossipedSyncRequestEnvelope' = gossipedSyncRequestEnvelope,
    gossipedSyncResponseEnvelope' = gossipedSyncResponseEnvelope,
    syncFiredAction' = syncFiredAction,
    syncTransportFiredAction' = syncTransportFiredAction,
  }

  run acceptsSyncRequestThroughTransportTest = {
    TransportInit
      .then(AcceptSyncRequestTransport(SyncRequestEnvelope))
      .then(all {
        assert(acceptedSyncRequests.contains(SyncRequest)),
        assert(TransportSafety),
        transportUnchangedAll,
      })
  }

  run acceptsSyncResponsesThroughTransportTest = {
    TransportInit
      .then(AcceptSyncResponseTransport(SyncResponseWithValueEnvelope))
      .then(AcceptSyncResponseTransport(SyncResponseNoValueEnvelope))
      .then(all {
        assert(acceptedSyncResponses.contains(SyncResponseWithValue)),
        assert(acceptedSyncResponses.contains(SyncResponseNoValue)),
        assert(TransportSafety),
        transportUnchangedAll,
      })
  }

  run requestResponseSameBytesStayKindSeparatedTest = {
    TransportInit.then(all {
      assert(SyncRequestEnvelope.bytes == SyncResponseNoValueEnvelope.bytes),
      assert(SyncRequestEnvelopeValid(SyncRequestEnvelope)),
      assert(SyncResponseEnvelopeValid(SyncResponseNoValueEnvelope)),
      transportUnchangedAll,
    })
  }

  run rawRequestWithoutTransportViolatesTransportSafetyTest = {
    TransportInit
      .then(RawAcceptSyncRequestWithoutTransport(SyncRequest))
      .then(all {
        assert(not(TransportSafety)),
        transportUnchangedAll,
      })
  }

  run rawResponseWithoutTransportViolatesTransportSafetyTest = {
    TransportInit
      .then(RawAcceptSyncResponseWithoutTransport(SyncResponseWithValue))
      .then(all {
        assert(not(TransportSafety)),
        transportUnchangedAll,
      })
  }

  run wrongTopicRequestEnvelopeRejectedTest = {
    TransportInit
      .then(AcceptSyncRequestTransport(WrongTopicRequestEnvelope))
      .fail()
  }

  run wrongKindRequestEnvelopeRejectedTest = {
    TransportInit
      .then(AcceptSyncRequestTransport(WrongKindRequestEnvelope))
      .fail()
  }

  run wrongBytesRequestEnvelopeRejectedTest = {
    TransportInit
      .then(AcceptSyncRequestTransport(WrongBytesRequestEnvelope))
      .fail()
  }

  run wrongKindResponseEnvelopeRejectedTest = {
    TransportInit
      .then(AcceptSyncResponseTransport(WrongKindResponseEnvelope))
      .fail()
  }

  run wrongBytesResponseEnvelopeRejectedTest = {
    TransportInit
      .then(AcceptSyncResponseTransport(WrongBytesResponseEnvelope))
      .fail()
  }

  run missingCertificateResponseEnvelopeRejectedTest = {
    TransportInit
      .then(AcceptSyncResponseTransport(MissingCertificateResponseEnvelope))
      .fail()
  }

  run syncTransportSafetyTest = {
    TransportInit.then(all {
      assert(TransportSafety),
      transportUnchangedAll,
    })
  }
}

module CrosslinkMalachiteSyncGossipTransportModel {
  import CrosslinkMalachiteSyncGossipTransportTest.* from
    "./CrosslinkMalachiteSyncGossipTransport"
  export CrosslinkMalachiteSyncGossipTransportTest.*
}
