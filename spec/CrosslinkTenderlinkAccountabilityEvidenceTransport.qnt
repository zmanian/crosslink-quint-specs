module CrosslinkTenderlinkAccountabilityEvidenceTransport {
  /*
   Tenderlink accountability evidence transport bridge.

   CrosslinkTenderlinkAccountabilityEvidenceFormat.qnt pins concrete
   precommit equivocation envelopes. This model adds the adjacent gossip
   boundary: accountability evidence cannot be accepted through this path
   unless the exact canonical evidence bytes first arrive in a Crosslink
   consensus-topic transport envelope with the expected kind and envelope
   metadata.
   */

  import CrosslinkTenderlinkAccountabilityEvidenceFormatTest.* from
    "./CrosslinkTenderlinkAccountabilityEvidenceFormat"
  export CrosslinkTenderlinkAccountabilityEvidenceFormatTest.*

  type Topic_t = str
  type TransportKind_t = str
  type AccountabilityEvidenceTransportEnvelope_t = {
    topic: Topic_t,
    kind: TransportKind_t,
    height: int,
    round: int,
    validatorPubKey: str,
    evidenceByteLen: int,
    evidenceHex: str,
  }

  pure val CrosslinkGossipTopic = "crosslink-consensus-v1"
  pure val WrongGossipTopic = "zcash-blocks-v1"
  pure val AccountabilityEvidenceEnvelopeKind = "accountability-evidence"
  pure val WrongEnvelopeKind = "precommit"

  var transportedAccountabilityEvidence: Set[AccountabilityEvidence_t]
  var acceptedTransportedAccountabilityEvidence: Set[AccountabilityEvidence_t]
  var accountabilityEvidenceTransportFiredAction: str

  def Env(
    topic: Topic_t,
    kind: TransportKind_t,
    height: int,
    round: int,
    validatorPubKey: str,
    evidenceByteLen: int,
    evidenceHex: str,
  ): AccountabilityEvidenceTransportEnvelope_t = {
    topic: topic,
    kind: kind,
    height: height,
    round: round,
    validatorPubKey: validatorPubKey,
    evidenceByteLen: evidenceByteLen,
    evidenceHex: evidenceHex,
  }

  pure def AccountabilityEvidenceEnvelopeMatches(
    env: AccountabilityEvidenceTransportEnvelope_t,
    evidence: AccountabilityEvidence_t,
  ): bool =
    env.height == evidence.height and
    env.round == evidence.round and
    env.validatorPubKey == evidence.validatorPubKey and
    env.evidenceByteLen == evidence.byteLen and
    env.evidenceHex == evidence.hex

  pure def AccountabilityEvidenceTransportEnvelopeValid(
    env: AccountabilityEvidenceTransportEnvelope_t,
    evidence: AccountabilityEvidence_t,
  ): bool =
    env.topic == CrosslinkGossipTopic and
    env.kind == AccountabilityEvidenceEnvelopeKind and
    AccountabilityEvidenceCanonical(evidence) and
    AccountabilityEvidenceEnvelopeMatches(env, evidence)

  action TransportInit = all {
    Init,
    transportedAccountabilityEvidence' = Set(),
    acceptedTransportedAccountabilityEvidence' = Set(),
    accountabilityEvidenceTransportFiredAction' = "TransportInit",
  }

  action KeepFormatState = all {
    acceptedAccountabilityEvidence' = acceptedAccountabilityEvidence,
    accountabilityEvidenceFormatFiredAction' = accountabilityEvidenceFormatFiredAction,
  }

  action ReceiveAccountabilityEvidenceTransport(
    env: AccountabilityEvidenceTransportEnvelope_t,
    evidence: AccountabilityEvidence_t,
  ): bool =
    all {
      AccountabilityEvidenceTransportEnvelopeValid(env, evidence),
      KeepFormatState,
      transportedAccountabilityEvidence' =
        transportedAccountabilityEvidence.union(Set(evidence)),
      acceptedTransportedAccountabilityEvidence' =
        acceptedTransportedAccountabilityEvidence,
      accountabilityEvidenceTransportFiredAction' = "ReceiveAccountabilityEvidenceTransport",
    }

  action AcceptTransportedAccountabilityEvidence(
    evidence: AccountabilityEvidence_t,
  ): bool =
    all {
      AccountabilityEvidenceCanonical(evidence),
      transportedAccountabilityEvidence.contains(evidence),
      KeepFormatState,
      transportedAccountabilityEvidence' = transportedAccountabilityEvidence,
      acceptedTransportedAccountabilityEvidence' =
        acceptedTransportedAccountabilityEvidence.union(Set(evidence)),
      accountabilityEvidenceTransportFiredAction' = "AcceptTransportedAccountabilityEvidence",
    }

  action TransportStutter: bool =
    all {
      KeepFormatState,
      transportedAccountabilityEvidence' = transportedAccountabilityEvidence,
      acceptedTransportedAccountabilityEvidence' =
        acceptedTransportedAccountabilityEvidence,
      accountabilityEvidenceTransportFiredAction' = accountabilityEvidenceTransportFiredAction,
    }

  pure def TransportedAccountabilityEvidenceCanonical: bool =
    transportedAccountabilityEvidence.forall(AccountabilityEvidenceCanonical)

  pure def AcceptedTransportedAccountabilityEvidenceCanonical: bool =
    acceptedTransportedAccountabilityEvidence.forall(evidence =>
      AccountabilityEvidenceCanonical(evidence) and
      transportedAccountabilityEvidence.contains(evidence)
    )

  val TransportSafety =
    TransportedAccountabilityEvidenceCanonical and
    AcceptedTransportedAccountabilityEvidenceCanonical
}

module CrosslinkTenderlinkAccountabilityEvidenceTransportTest {
  import CrosslinkTenderlinkAccountabilityEvidenceTransport.* from
    "./CrosslinkTenderlinkAccountabilityEvidenceTransport"
  export CrosslinkTenderlinkAccountabilityEvidenceTransport.*

  pure val accountabilityEvidenceEnvelope =
    Env(
      CrosslinkGossipTopic,
      AccountabilityEvidenceEnvelopeKind,
      1,
      0,
      TestPubKeyHex,
      nilValuePrecommitEvidence.byteLen,
      NilValuePrecommitEvidenceHex,
    )

  pure val valueValueEvidenceEnvelope =
    Env(
      CrosslinkGossipTopic,
      AccountabilityEvidenceEnvelopeKind,
      1,
      0,
      TestPubKeyHex,
      valueValuePrecommitEvidence.byteLen,
      ValueValuePrecommitEvidenceHex,
    )

  pure val wrongTopicEnvelope =
    Env(
      WrongGossipTopic,
      AccountabilityEvidenceEnvelopeKind,
      1,
      0,
      TestPubKeyHex,
      nilValuePrecommitEvidence.byteLen,
      NilValuePrecommitEvidenceHex,
    )

  pure val wrongKindEnvelope =
    Env(
      CrosslinkGossipTopic,
      WrongEnvelopeKind,
      1,
      0,
      TestPubKeyHex,
      nilValuePrecommitEvidence.byteLen,
      NilValuePrecommitEvidenceHex,
    )

  pure val wrongLengthEnvelope =
    Env(
      CrosslinkGossipTopic,
      AccountabilityEvidenceEnvelopeKind,
      1,
      0,
      TestPubKeyHex,
      nilValuePrecommitEvidence.byteLen + 1,
      NilValuePrecommitEvidenceHex,
    )

  pure val wrongHeightEnvelope =
    Env(
      CrosslinkGossipTopic,
      AccountabilityEvidenceEnvelopeKind,
      2,
      0,
      TestPubKeyHex,
      nilValuePrecommitEvidence.byteLen,
      NilValuePrecommitEvidenceHex,
    )

  pure val wrongSignerEnvelope =
    Env(
      CrosslinkGossipTopic,
      AccountabilityEvidenceEnvelopeKind,
      1,
      0,
      TestPubKey2Hex,
      nilValuePrecommitEvidence.byteLen,
      NilValuePrecommitEvidenceHex,
    )

  pure val wrongBytesEnvelope =
    Env(
      CrosslinkGossipTopic,
      AccountabilityEvidenceEnvelopeKind,
      1,
      0,
      TestPubKeyHex,
      nilValuePrecommitEvidence.byteLen,
      "wrong-accountability-evidence-bytes",
    )

  pure val prevoteEvidenceEnvelope =
    Env(
      CrosslinkGossipTopic,
      AccountabilityEvidenceEnvelopeKind,
      1,
      0,
      TestPubKeyHex,
      prevoteEvidence.byteLen,
      prevoteEvidence.hex,
    )

  pure val TestTransportEnvelopes = Set(
    accountabilityEvidenceEnvelope,
    valueValueEvidenceEnvelope,
    wrongTopicEnvelope,
    wrongKindEnvelope,
    wrongLengthEnvelope,
    wrongHeightEnvelope,
    wrongSignerEnvelope,
    wrongBytesEnvelope,
    prevoteEvidenceEnvelope,
  )

  pure val TestTransportEvidence = Set(
    nilValuePrecommitEvidence,
    valueValuePrecommitEvidence,
    prevoteEvidence,
    wrongRoundEvidence,
    wrongHeightEvidence,
  )

  action TransportNext: bool =
    any {
      nondet env = oneOf(TestTransportEnvelopes)
      nondet evidence = oneOf(TestTransportEvidence)
      ReceiveAccountabilityEvidenceTransport(env, evidence),
      nondet acceptedEvidence = oneOf(TestTransportEvidence)
      AcceptTransportedAccountabilityEvidence(acceptedEvidence),
      TransportStutter,
    }

  action unchangedTransport = all {
    acceptedAccountabilityEvidence' = acceptedAccountabilityEvidence,
    accountabilityEvidenceFormatFiredAction' = accountabilityEvidenceFormatFiredAction,
    transportedAccountabilityEvidence' = transportedAccountabilityEvidence,
    acceptedTransportedAccountabilityEvidence' =
      acceptedTransportedAccountabilityEvidence,
    accountabilityEvidenceTransportFiredAction' = accountabilityEvidenceTransportFiredAction,
  }

  run accountabilityEvidenceTransportEnvelopeAcceptedTest = {
    TransportInit
      .then(ReceiveAccountabilityEvidenceTransport(
        accountabilityEvidenceEnvelope,
        nilValuePrecommitEvidence,
      ))
      .then(all {
        assert(transportedAccountabilityEvidence.contains(
          nilValuePrecommitEvidence)),
        assert(TransportSafety),
        unchangedTransport,
      })
  }

  run valueValueAccountabilityEvidenceTransportEnvelopeAcceptedTest = {
    TransportInit
      .then(ReceiveAccountabilityEvidenceTransport(
        valueValueEvidenceEnvelope,
        valueValuePrecommitEvidence,
      ))
      .then(all {
        assert(transportedAccountabilityEvidence.contains(
          valueValuePrecommitEvidence)),
        assert(TransportSafety),
        unchangedTransport,
      })
  }

  run transportedAccountabilityEvidenceAcceptedTest = {
    TransportInit
      .then(ReceiveAccountabilityEvidenceTransport(
        accountabilityEvidenceEnvelope,
        nilValuePrecommitEvidence,
      ))
      .then(AcceptTransportedAccountabilityEvidence(nilValuePrecommitEvidence))
      .then(all {
        assert(acceptedTransportedAccountabilityEvidence.contains(
          nilValuePrecommitEvidence)),
        assert(TransportSafety),
        unchangedTransport,
      })
  }

  run valueValueTransportedAccountabilityEvidenceAcceptedTest = {
    TransportInit
      .then(ReceiveAccountabilityEvidenceTransport(
        valueValueEvidenceEnvelope,
        valueValuePrecommitEvidence,
      ))
      .then(AcceptTransportedAccountabilityEvidence(
        valueValuePrecommitEvidence,
      ))
      .then(all {
        assert(acceptedTransportedAccountabilityEvidence.contains(
          valueValuePrecommitEvidence)),
        assert(TransportSafety),
        unchangedTransport,
      })
  }

  run missingTransportRejectedTest = {
    TransportInit
      .then(AcceptTransportedAccountabilityEvidence(nilValuePrecommitEvidence))
      .fail()
  }

  run wrongTopicTransportRejectedTest = {
    TransportInit
      .then(ReceiveAccountabilityEvidenceTransport(
        wrongTopicEnvelope,
        nilValuePrecommitEvidence,
      ))
      .fail()
  }

  run wrongKindTransportRejectedTest = {
    TransportInit
      .then(ReceiveAccountabilityEvidenceTransport(
        wrongKindEnvelope,
        nilValuePrecommitEvidence,
      ))
      .fail()
  }

  run wrongLengthTransportRejectedTest = {
    TransportInit
      .then(ReceiveAccountabilityEvidenceTransport(
        wrongLengthEnvelope,
        nilValuePrecommitEvidence,
      ))
      .fail()
  }

  run wrongHeightTransportRejectedTest = {
    TransportInit
      .then(ReceiveAccountabilityEvidenceTransport(
        wrongHeightEnvelope,
        nilValuePrecommitEvidence,
      ))
      .fail()
  }

  run wrongSignerTransportRejectedTest = {
    TransportInit
      .then(ReceiveAccountabilityEvidenceTransport(
        wrongSignerEnvelope,
        nilValuePrecommitEvidence,
      ))
      .fail()
  }

  run wrongBytesTransportRejectedTest = {
    TransportInit
      .then(ReceiveAccountabilityEvidenceTransport(
        wrongBytesEnvelope,
        nilValuePrecommitEvidence,
      ))
      .fail()
  }

  run nonCanonicalEvidenceTransportRejectedTest = {
    TransportInit
      .then(ReceiveAccountabilityEvidenceTransport(
        prevoteEvidenceEnvelope,
        prevoteEvidence,
      ))
      .fail()
  }

  run accountabilityEvidenceTransportSafetyTest = {
    TransportInit.then(all {
      assert(TransportSafety),
      unchangedTransport,
    })
  }
}

module CrosslinkTenderlinkAccountabilityEvidenceTransportModel {
  import CrosslinkTenderlinkAccountabilityEvidenceTransportTest.* from
    "./CrosslinkTenderlinkAccountabilityEvidenceTransport"
  export CrosslinkTenderlinkAccountabilityEvidenceTransportTest.*
}
