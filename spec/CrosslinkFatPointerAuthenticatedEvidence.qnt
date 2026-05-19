module CrosslinkFatPointerAuthenticatedEvidence {
  /*
   Production fat-pointer evidence composition.

   CrosslinkFatPointerFormat.qnt checks that a fat pointer is well-shaped and
   signature-authentic. This model adds the observer/evidence side: a production
   fat pointer can only be observed after every active signer entry is backed by
   a matching gossiped precommit at the same BFT height, round, and value.
   */

  import CrosslinkFatPointerFormat.* from "./CrosslinkFatPointerFormat"
  export CrosslinkFatPointerFormat.*

  var gossipedPrecommit: Height_t -> Round_t -> Set[RoundCommit_t]
  var observedProductionFatPointer: Set[FatPointer_t]
  var observedProductionFatPointerWire: Set[FatPointerWire_t]

  def ProductionPrecommitAuthentic(
    h: Height_t,
    r: Round_t,
    commit: RoundCommit_t,
  ): bool =
    Heights.contains(h) and
    Rounds.contains(r) and
    commit.blockHash != NilBlockHash and
    PubKeys.contains(commit.pubKey) and
    AuthorizedAt.get(h).contains(PubKeyOwner.get(commit.pubKey)) and
    commit.signedBytes ==
      FatPointerSignBytes.get(h).get(r).get(commit.blockHash).get(commit.pubKey) and
    commit.voteSignature == SignatureVerifier.get(commit.pubKey).get(commit.signedBytes)

  def GossipedMatchingPrecommitForSignature(
    fp: FatPointer_t,
    sig: FatPointerSignature_t,
  ): bool =
    gossipedPrecommit.get(fp.height).get(fp.round).exists(commit =>
      ProductionPrecommitAuthentic(fp.height, fp.round, commit) and
      commit.blockHash == fp.blockHash and
      commit.pubKey == sig.pubKey and
      commit.signedBytes == sig.signedBytes and
      commit.voteSignature == sig.voteSignature
    )

  def ProductionFatPointerEvidenceValid(fp: FatPointer_t): bool =
    FatPointerFormatValid(fp) and
    ActiveSigIndexes(fp).forall(i =>
      GossipedMatchingPrecommitForSignature(fp, fp.signatures.get(i))
    )

  def ProductionFatPointerWireEvidenceValid(wire: FatPointerWire_t): bool =
    FatPointerWireEnvelopeValid(wire) and
    ProductionFatPointerEvidenceValid(wire.fatPointer)

  action PipelineInit = all {
    acceptedFatPointers' = Set(),
    acceptedFatPointerWires' = Set(),
    gossipedPrecommit' = Heights.mapBy(_ => Rounds.mapBy(_ => Set())),
    observedProductionFatPointer' = Set(),
    observedProductionFatPointerWire' = Set(),
    firedAction' = "PipelineInit",
  }

  action KeepFormatState = all {
    acceptedFatPointers' = acceptedFatPointers,
    acceptedFatPointerWires' = acceptedFatPointerWires,
  }

  action KeepPipelineEvidence = all {
    gossipedPrecommit' = gossipedPrecommit,
    observedProductionFatPointer' = observedProductionFatPointer,
    observedProductionFatPointerWire' = observedProductionFatPointerWire,
  }

  action GossipProductionPrecommit(
    h: Height_t,
    r: Round_t,
    commit: RoundCommit_t,
  ): bool =
    all {
      ProductionPrecommitAuthentic(h, r, commit),
      KeepFormatState,
      gossipedPrecommit' =
        gossipedPrecommit.setBy(h, byRound =>
          byRound.setBy(r, old => old.union(Set(commit)))
        ),
      observedProductionFatPointer' = observedProductionFatPointer,
      observedProductionFatPointerWire' = observedProductionFatPointerWire,
      firedAction' = "GossipProductionPrecommit",
    }

  action ObserveProductionFatPointer(fp: FatPointer_t): bool =
    all {
      ProductionFatPointerEvidenceValid(fp),
      acceptedFatPointers' = acceptedFatPointers.union(Set(fp)),
      acceptedFatPointerWires' = acceptedFatPointerWires,
      gossipedPrecommit' = gossipedPrecommit,
      observedProductionFatPointer' = observedProductionFatPointer.union(Set(fp)),
      observedProductionFatPointerWire' = observedProductionFatPointerWire,
      firedAction' = "ObserveProductionFatPointer",
    }

  action ObserveProductionFatPointerWire(wire: FatPointerWire_t): bool =
    all {
      ProductionFatPointerWireEvidenceValid(wire),
      acceptedFatPointers' = acceptedFatPointers.union(Set(wire.fatPointer)),
      acceptedFatPointerWires' = acceptedFatPointerWires.union(Set(wire)),
      gossipedPrecommit' = gossipedPrecommit,
      observedProductionFatPointer' =
        observedProductionFatPointer.union(Set(wire.fatPointer)),
      observedProductionFatPointerWire' =
        observedProductionFatPointerWire.union(Set(wire)),
      firedAction' = "ObserveProductionFatPointerWire",
    }

  action PipelineStutter: bool =
    all {
      KeepFormatState,
      KeepPipelineEvidence,
      firedAction' = firedAction,
    }

  val GossipedPrecommitsAuthentic =
    Heights.forall(h =>
      Rounds.forall(r =>
        gossipedPrecommit.get(h).get(r).forall(commit =>
          ProductionPrecommitAuthentic(h, r, commit)
        )
      )
    )

  val ObservedProductionFatPointersValid =
    observedProductionFatPointer.forall(ProductionFatPointerEvidenceValid)

  val ObservedProductionFatPointerWiresValid =
    observedProductionFatPointerWire.forall(ProductionFatPointerWireEvidenceValid)

  val ObservedFatPointersAlsoAcceptedByFormat =
    observedProductionFatPointer.subseteq(acceptedFatPointers)

  val ObservedFatPointerWiresAlsoAcceptedByFormat =
    observedProductionFatPointerWire.subseteq(acceptedFatPointerWires)

  val PipelineSafety =
    AcceptedFatPointersValid and
    AcceptedFatPointerWiresValid and
    GossipedPrecommitsAuthentic and
    ObservedProductionFatPointersValid and
    ObservedProductionFatPointerWiresValid and
    ObservedFatPointersAlsoAcceptedByFormat and
    ObservedFatPointerWiresAlsoAcceptedByFormat
}

module CrosslinkFatPointerAuthenticatedEvidenceTest {
  import CrosslinkFatPointerAuthenticatedEvidence.* from "./CrosslinkFatPointerAuthenticatedEvidence"
  export CrosslinkFatPointerAuthenticatedEvidence.*

  type PrecommitEnvelope_t = {
    height: Height_t,
    round: Round_t,
    commit: RoundCommit_t,
  }

  def Sig(
    pubKey: PubKey_t,
    signedBytes: Bytes_t,
    voteSignature: Signature_t,
  ): FatPointerSignature_t = {
    pubKey: pubKey,
    signedBytes: signedBytes,
    voteSignature: voteSignature,
  }

  def Fp(
    height: Height_t,
    blockHash: BlockHash_t,
    signatureCount: int,
    s0: FatPointerSignature_t,
    s1: FatPointerSignature_t,
    s2: FatPointerSignature_t,
    s3: FatPointerSignature_t,
  ): FatPointer_t = {
    height: height,
    round: 0,
    blockHash: blockHash,
    signatureCount: signatureCount,
    signatures: Map(0 -> s0, 1 -> s1, 2 -> s2, 3 -> s3),
  }

  def Wire(fatPointer: FatPointer_t, byteLen: int): FatPointerWire_t = {
    fatPointer: fatPointer,
    byteLen: byteLen,
  }

  def Commit(
    pubKey: PubKey_t,
    blockHash: BlockHash_t,
    signedBytes: Bytes_t,
    voteSignature: Signature_t,
  ): RoundCommit_t = {
    pubKey: pubKey,
    blockHash: blockHash,
    signedBytes: signedBytes,
    voteSignature: voteSignature,
  }

  def Env(
    height: Height_t,
    commit: RoundCommit_t,
  ): PrecommitEnvelope_t = {
    height: height,
    round: 0,
    commit: commit,
  }

  pure val blankSig = Sig("k1", "blank", "blank-sig")

  pure val k1h1 =
    Commit("k1", "bft1", "h1-r0-bft1-k1", "sig-k1-h1-bft1")
  pure val k2h1 =
    Commit("k2", "bft1", "h1-r0-bft1-k2", "sig-k2-h1-bft1")
  pure val k3h1 =
    Commit("k3", "bft1", "h1-r0-bft1-k3", "sig-k3-h1-bft1")
  pure val k1h2 =
    Commit("k1", "bft2", "h2-r0-bft2-k1", "sig-k1-h2-bft2")
  pure val k2h2 =
    Commit("k2", "bft2", "h2-r0-bft2-k2", "sig-k2-h2-bft2")
  pure val k3h2 =
    Commit("k3", "bft2", "h2-r0-bft2-k3", "sig-k3-h2-bft2")
  pure val k4h2 =
    Commit("k4", "bft2", "h2-r0-bft2-k4", "sig-k4-h2-bft2")

  pure val validHeight2FatPointer =
    Fp(
      2,
      "bft2",
      3,
      Sig("k2", "h2-r0-bft2-k2", "sig-k2-h2-bft2"),
      Sig("k3", "h2-r0-bft2-k3", "sig-k3-h2-bft2"),
      Sig("k4", "h2-r0-bft2-k4", "sig-k4-h2-bft2"),
      blankSig,
    )

  pure val duplicatePubKeyFatPointer =
    Fp(
      2,
      "bft2",
      3,
      Sig("k2", "h2-r0-bft2-k2", "sig-k2-h2-bft2"),
      Sig("k2", "h2-r0-bft2-k2", "sig-k2-h2-bft2"),
      Sig("k3", "h2-r0-bft2-k3", "sig-k3-h2-bft2"),
      blankSig,
    )

  pure val oldHeightFatPointer =
    Fp(
      1,
      "bft1",
      3,
      Sig("k1", "h1-r0-bft1-k1", "sig-k1-h1-bft1"),
      Sig("k2", "h1-r0-bft1-k2", "sig-k2-h1-bft1"),
      Sig("k3", "h1-r0-bft1-k3", "sig-k3-h1-bft1"),
      blankSig,
    )

  pure val validHeight2Wire =
    Wire(validHeight2FatPointer, 334)

  pure val trailingByteWire =
    Wire(validHeight2FatPointer, 335)

  pure val oldHeightWire =
    Wire(oldHeightFatPointer, 334)

  pure val TestFatPointers = Set(
    validHeight2FatPointer,
    duplicatePubKeyFatPointer,
    oldHeightFatPointer,
  )

  pure val TestFatPointerWires = Set(
    validHeight2Wire,
    trailingByteWire,
    oldHeightWire,
  )

  pure val TestPrecommitEnvelopes = Set(
    Env(1, k1h1),
    Env(1, k2h1),
    Env(1, k3h1),
    Env(2, k1h2),
    Env(2, k2h2),
    Env(2, k3h2),
    Env(2, k4h2),
  )

  action PipelineNext: bool =
    any {
      nondet env = oneOf(TestPrecommitEnvelopes)
      GossipProductionPrecommit(env.height, env.round, env.commit),
      nondet fp = oneOf(TestFatPointers)
      ObserveProductionFatPointer(fp),
      nondet wire = oneOf(TestFatPointerWires)
      ObserveProductionFatPointerWire(wire),
      PipelineStutter,
    }

  action unchangedAll = all {
    acceptedFatPointers' = acceptedFatPointers,
    acceptedFatPointerWires' = acceptedFatPointerWires,
    gossipedPrecommit' = gossipedPrecommit,
    observedProductionFatPointer' = observedProductionFatPointer,
    observedProductionFatPointerWire' = observedProductionFatPointerWire,
    firedAction' = firedAction,
  }

  run observesProductionFatPointerAfterGossipedPrecommitsTest = {
    PipelineInit
      .then(GossipProductionPrecommit(2, 0, k2h2))
      .then(GossipProductionPrecommit(2, 0, k3h2))
      .then(GossipProductionPrecommit(2, 0, k4h2))
      .then(ObserveProductionFatPointer(validHeight2FatPointer))
      .then(all {
        assert(observedProductionFatPointer.contains(validHeight2FatPointer)),
        assert(acceptedFatPointers.contains(validHeight2FatPointer)),
        assert(PipelineSafety),
        unchangedAll,
      })
  }

  run cannotObserveFatPointerBeforeGossipedPrecommitsTest = {
    PipelineInit
      .then(ObserveProductionFatPointer(validHeight2FatPointer))
      .fail()
  }

  run observesProductionFatPointerWireAfterGossipedPrecommitsTest = {
    PipelineInit
      .then(GossipProductionPrecommit(2, 0, k2h2))
      .then(GossipProductionPrecommit(2, 0, k3h2))
      .then(GossipProductionPrecommit(2, 0, k4h2))
      .then(ObserveProductionFatPointerWire(validHeight2Wire))
      .then(all {
        assert(observedProductionFatPointerWire.contains(validHeight2Wire)),
        assert(observedProductionFatPointer.contains(validHeight2FatPointer)),
        assert(acceptedFatPointerWires.contains(validHeight2Wire)),
        assert(acceptedFatPointers.contains(validHeight2FatPointer)),
        assert(PipelineSafety),
        unchangedAll,
      })
  }

  run cannotObserveFatPointerWireBeforeGossipedPrecommitsTest = {
    PipelineInit
      .then(ObserveProductionFatPointerWire(validHeight2Wire))
      .fail()
  }

  run trailingByteFatPointerWireRejectedDespiteGossipTest = {
    PipelineInit
      .then(GossipProductionPrecommit(2, 0, k2h2))
      .then(GossipProductionPrecommit(2, 0, k3h2))
      .then(GossipProductionPrecommit(2, 0, k4h2))
      .then(ObserveProductionFatPointerWire(trailingByteWire))
      .fail()
  }

  run missingSignerPrecommitRejectsFatPointerObservationTest = {
    PipelineInit
      .then(GossipProductionPrecommit(2, 0, k2h2))
      .then(GossipProductionPrecommit(2, 0, k3h2))
      .then(ObserveProductionFatPointer(validHeight2FatPointer))
      .fail()
  }

  run removedValidatorCannotGossipNextHeightPrecommitTest = {
    PipelineInit
      .then(GossipProductionPrecommit(2, 0, k1h2))
      .fail()
  }

  run duplicateSignerFatPointerRejectedDespiteGossipTest = {
    PipelineInit
      .then(GossipProductionPrecommit(2, 0, k2h2))
      .then(GossipProductionPrecommit(2, 0, k3h2))
      .then(ObserveProductionFatPointer(duplicatePubKeyFatPointer))
      .fail()
  }

  run oldHeightFatPointerUsesOldAuthorizedSetTest = {
    PipelineInit
      .then(GossipProductionPrecommit(1, 0, k1h1))
      .then(GossipProductionPrecommit(1, 0, k2h1))
      .then(GossipProductionPrecommit(1, 0, k3h1))
      .then(ObserveProductionFatPointer(oldHeightFatPointer))
      .then(all {
        assert(observedProductionFatPointer.contains(oldHeightFatPointer)),
        assert(PipelineSafety),
        unchangedAll,
      })
  }
}

module CrosslinkFatPointerAuthenticatedEvidenceModel {
  import CrosslinkFatPointerAuthenticatedEvidenceTest(
    Validators = Set("p1", "p2", "p3", "p4"),
    PubKeys = Set("k1", "k2", "k3", "k4"),
    VotingPower = Map("p1" -> 1, "p2" -> 1, "p3" -> 1, "p4" -> 1),
    QuorumVotingPower = 3,
    MaxBftHeight = 2,
    MaxRound = 0,
    MaxSignatures = 4,
    NilBlockHash = "nil",
    AuthorizedAt = Map(
      1 -> Set("p1", "p2", "p3", "p4"),
      2 -> Set("p2", "p3", "p4"),
    ),
    PubKeyOwner = Map(
      "k1" -> "p1",
      "k2" -> "p2",
      "k3" -> "p3",
      "k4" -> "p4",
    ),
    FatPointerSignBytes = Map(
      1 -> Map(
        0 -> Map(
          "bft1" -> Map(
            "k1" -> "h1-r0-bft1-k1",
            "k2" -> "h1-r0-bft1-k2",
            "k3" -> "h1-r0-bft1-k3",
            "k4" -> "h1-r0-bft1-k4",
          ),
        ),
      ),
      2 -> Map(
        0 -> Map(
          "bft2" -> Map(
            "k1" -> "h2-r0-bft2-k1",
            "k2" -> "h2-r0-bft2-k2",
            "k3" -> "h2-r0-bft2-k3",
            "k4" -> "h2-r0-bft2-k4",
          ),
        ),
      ),
    ),
    SignatureVerifier = Map(
      "k1" -> Map(
        "blank" -> "blank-sig",
        "h1-r0-bft1-k1" -> "sig-k1-h1-bft1",
        "h2-r0-bft2-k1" -> "sig-k1-h2-bft2",
      ),
      "k2" -> Map(
        "h1-r0-bft1-k2" -> "sig-k2-h1-bft1",
        "h2-r0-bft2-k2" -> "sig-k2-h2-bft2",
      ),
      "k3" -> Map(
        "h1-r0-bft1-k3" -> "sig-k3-h1-bft1",
        "h2-r0-bft2-k3" -> "sig-k3-h2-bft2",
      ),
      "k4" -> Map(
        "h1-r0-bft1-k4" -> "sig-k4-h1-bft1",
        "h2-r0-bft2-k4" -> "sig-k4-h2-bft2",
      ),
    ),
  ).*
}
