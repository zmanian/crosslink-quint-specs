module CrosslinkHeightedAuthenticatedGossipTransport {
  /*
   Heighted authenticated gossip transport bridge.

   CrosslinkHeightedAuthenticatedEvidence.qnt already checks canonical bytes,
   signatures, active validator-set authorization, gossip-before-observe, and
   fat-pointer quorum evidence. This module inserts a production-shaped gossip
   envelope boundary in front of that pipeline: precommits and fat-pointer
   signatures must be carried on the Crosslink consensus topic with the expected
   envelope kind before the observer accepts them.
   */

  import CrosslinkHeightedAuthenticatedEvidence.* from "./CrosslinkHeightedAuthenticatedEvidence"
  export CrosslinkHeightedAuthenticatedEvidence.*

  type Topic_t = str
  type TransportKind_t = str
  type HeightedTransportEnvelope_t = {
    topic: Topic_t,
    kind: TransportKind_t,
    src: Proc_t,
    height: Height_t,
    round: Round_t,
    id: Snapshot_t,
    bytes: Bytes_t,
    sig: Sig_t,
  }

  pure val CrosslinkGossipTopic = "crosslink-consensus-v1"
  pure val WrongGossipTopic = "zcash-blocks-v1"
  pure val PrecommitEnvelopeKind = "precommit"
  pure val FatPointerSigEnvelopeKind = "fat-pointer-signature"
  pure val WrongEnvelopeKind = "headers"

  var gossipedPrecommitTransportEnvelope:
    Height_t -> Round_t -> Set[HeightedTransportEnvelope_t]
  var gossipedFatPointerSigTransportEnvelope:
    Height_t -> Round_t -> Set[HeightedTransportEnvelope_t]
  var transportFiredAction: str

  def Env(
    topic: Topic_t,
    kind: TransportKind_t,
    src: Proc_t,
    height: Height_t,
    round: Round_t,
    id: Snapshot_t,
    bytes: Bytes_t,
    sig: Sig_t,
  ): HeightedTransportEnvelope_t = {
    topic: topic,
    kind: kind,
    src: src,
    height: height,
    round: round,
    id: id,
    bytes: bytes,
    sig: sig,
  }

  def PrecommitFromEnvelope(env: HeightedTransportEnvelope_t): SignedVote_t = {
    src: env.src,
    height: env.height,
    round: env.round,
    id: env.id,
    bytes: env.bytes,
    sig: env.sig,
  }

  def FatPointerSigFromEnvelope(
    env: HeightedTransportEnvelope_t,
  ): SignedFatPointerSig_t = {
    src: env.src,
    height: env.height,
    round: env.round,
    id: env.id,
    bytes: env.bytes,
    sig: env.sig,
  }

  def PrecommitTransportEnvelopeValid(
    env: HeightedTransportEnvelope_t,
  ): bool =
    env.topic == CrosslinkGossipTopic and
    env.kind == PrecommitEnvelopeKind and
    PrecommitAuthentic(PrecommitFromEnvelope(env)) and
    AuthorizedAtHeight(env.src, env.height)

  def FatPointerSigTransportEnvelopeValid(
    env: HeightedTransportEnvelope_t,
  ): bool =
    env.topic == CrosslinkGossipTopic and
    env.kind == FatPointerSigEnvelopeKind and
    FatPointerSigAuthentic(FatPointerSigFromEnvelope(env)) and
    AuthorizedAtHeight(env.src, env.height)

  def PrecommitEnvelopeMatches(
    env: HeightedTransportEnvelope_t,
    msg: SignedVote_t,
  ): bool =
    env.src == msg.src and
    env.height == msg.height and
    env.round == msg.round and
    env.id == msg.id and
    env.bytes == msg.bytes and
    env.sig == msg.sig

  def FatPointerSigEnvelopeMatches(
    env: HeightedTransportEnvelope_t,
    msg: SignedFatPointerSig_t,
  ): bool =
    env.src == msg.src and
    env.height == msg.height and
    env.round == msg.round and
    env.id == msg.id and
    env.bytes == msg.bytes and
    env.sig == msg.sig

  def MatchingPrecommitTransportEnvelope(msg: SignedVote_t): bool =
    gossipedPrecommitTransportEnvelope
      .get(msg.height)
      .get(msg.round)
      .exists(env =>
        PrecommitTransportEnvelopeValid(env) and
        PrecommitEnvelopeMatches(env, msg)
      )

  def MatchingFatPointerSigTransportEnvelope(
    msg: SignedFatPointerSig_t,
  ): bool =
    gossipedFatPointerSigTransportEnvelope
      .get(msg.height)
      .get(msg.round)
      .exists(env =>
        FatPointerSigTransportEnvelopeValid(env) and
        FatPointerSigEnvelopeMatches(env, msg)
      )

  def MatchingPrecommitTransportEnvelopeFrom(
    p: Proc_t,
    h: Height_t,
    r: Round_t,
    v: Snapshot_t,
  ): bool =
    gossipedPrecommitTransportEnvelope.get(h).get(r).exists(env =>
      PrecommitTransportEnvelopeValid(env) and
      env.src == p and
      env.height == h and
      env.round == r and
      env.id == v
    )

  def MatchingFatPointerSigTransportEnvelopeFrom(
    p: Proc_t,
    h: Height_t,
    r: Round_t,
    v: Snapshot_t,
  ): bool =
    gossipedFatPointerSigTransportEnvelope.get(h).get(r).exists(env =>
      FatPointerSigTransportEnvelopeValid(env) and
      env.src == p and
      env.height == h and
      env.round == r and
      env.id == v
    )

  action TransportInit = all {
    Init,
    gossipedPrecommitTransportEnvelope' =
      Heights.mapBy(_ => Rounds.mapBy(_ => Set())),
    gossipedFatPointerSigTransportEnvelope' =
      Heights.mapBy(_ => Rounds.mapBy(_ => Set())),
    transportFiredAction' = "TransportInit",
  }

  action KeepTransportState = all {
    gossipedPrecommitTransportEnvelope' = gossipedPrecommitTransportEnvelope,
    gossipedFatPointerSigTransportEnvelope' =
      gossipedFatPointerSigTransportEnvelope,
  }

  action DecideAtTransport(
    h: Height_t,
    candidate: Snapshot_t,
    signers: Set[Proc_t],
  ): bool =
    all {
      DecideAt(h, candidate, signers),
      KeepTransportState,
      transportFiredAction' = "DecideAtTransport",
    }

  action GossipPrecommitTransport(env: HeightedTransportEnvelope_t): bool =
    all {
      PrecommitTransportEnvelopeValid(env),
      GossipPrecommit(
        env.src,
        env.height,
        env.round,
        env.id,
        env.bytes,
        env.sig,
      ),
      gossipedPrecommitTransportEnvelope' =
        gossipedPrecommitTransportEnvelope.setBy(env.height, byRound =>
          byRound.setBy(env.round, old => old.union(Set(env)))
        ),
      gossipedFatPointerSigTransportEnvelope' =
        gossipedFatPointerSigTransportEnvelope,
      transportFiredAction' = "GossipPrecommitTransport",
    }

  action ObservePrecommitFromTransport(
    env: HeightedTransportEnvelope_t,
  ): bool =
    all {
      gossipedPrecommitTransportEnvelope
        .get(env.height)
        .get(env.round)
        .contains(env),
      PrecommitTransportEnvelopeValid(env),
      ObservePrecommit(
        env.src,
        env.height,
        env.round,
        env.id,
        env.bytes,
        env.sig,
      ),
      KeepTransportState,
      transportFiredAction' = "ObservePrecommitFromTransport",
    }

  action GossipFatPointerSigTransport(
    env: HeightedTransportEnvelope_t,
  ): bool =
    all {
      FatPointerSigTransportEnvelopeValid(env),
      GossipFatPointerSig(
        env.src,
        env.height,
        env.round,
        env.id,
        env.bytes,
        env.sig,
      ),
      gossipedPrecommitTransportEnvelope' =
        gossipedPrecommitTransportEnvelope,
      gossipedFatPointerSigTransportEnvelope' =
        gossipedFatPointerSigTransportEnvelope.setBy(env.height, byRound =>
          byRound.setBy(env.round, old => old.union(Set(env)))
        ),
      transportFiredAction' = "GossipFatPointerSigTransport",
    }

  action ObserveFatPointerFromTransport(
    h: Height_t,
    r: Round_t,
    v: Snapshot_t,
    signers: Set[Proc_t],
  ): bool =
    all {
      signers.forall(p =>
        MatchingPrecommitTransportEnvelopeFrom(p, h, r, v) and
        MatchingFatPointerSigTransportEnvelopeFrom(p, h, r, v)
      ),
      ObserveFatPointer(h, r, v, signers),
      KeepTransportState,
      transportFiredAction' = "ObserveFatPointerFromTransport",
    }

  action RawGossipPrecommitWithoutTransport(
    p: Proc_t,
    h: Height_t,
    r: Round_t,
    v: Snapshot_t,
    bytes: Bytes_t,
    sig: Sig_t,
  ): bool =
    all {
      GossipPrecommit(p, h, r, v, bytes, sig),
      KeepTransportState,
      transportFiredAction' = "RawGossipPrecommitWithoutTransport",
    }

  action RawGossipFatPointerSigWithoutTransport(
    p: Proc_t,
    h: Height_t,
    r: Round_t,
    v: Snapshot_t,
    bytes: Bytes_t,
    sig: Sig_t,
  ): bool =
    all {
      GossipFatPointerSig(p, h, r, v, bytes, sig),
      KeepTransportState,
      transportFiredAction' = "RawGossipFatPointerSigWithoutTransport",
    }

  action TransportStutter: bool =
    all {
      Stutter,
      KeepTransportState,
      transportFiredAction' = transportFiredAction,
    }

  val GossipedPrecommitTransportEnvelopesValid =
    Heights.forall(h =>
      Rounds.forall(r =>
        gossipedPrecommitTransportEnvelope.get(h).get(r).forall(
          PrecommitTransportEnvelopeValid
        )
      )
    )

  val GossipedFatPointerSigTransportEnvelopesValid =
    Heights.forall(h =>
      Rounds.forall(r =>
        gossipedFatPointerSigTransportEnvelope.get(h).get(r).forall(
          FatPointerSigTransportEnvelopeValid
        )
      )
    )

  val GossipedPrecommitsHaveTransportEnvelope =
    Heights.forall(h =>
      Rounds.forall(r =>
        gossipPrecommit.get(h).get(r).forall(MatchingPrecommitTransportEnvelope)
      )
    )

  val ObservedPrecommitsHaveTransportEnvelope =
    Heights.forall(h =>
      Rounds.forall(r =>
        observedPrecommit
          .get(h)
          .get(r)
          .forall(MatchingPrecommitTransportEnvelope)
      )
    )

  val GossipedFatPointerSigsHaveTransportEnvelope =
    Heights.forall(h =>
      Rounds.forall(r =>
        gossipFatPointerSig
          .get(h)
          .get(r)
          .forall(MatchingFatPointerSigTransportEnvelope)
      )
    )

  val ObservedFatPointersHaveTransportEvidence =
    observedFatPointer.forall(fp =>
      fp.signers.forall(p =>
        MatchingPrecommitTransportEnvelopeFrom(p, fp.height, fp.round, fp.id) and
        MatchingFatPointerSigTransportEnvelopeFrom(p, fp.height, fp.round, fp.id)
      )
    )

  val TransportSafety =
    Safety and
    GossipedPrecommitTransportEnvelopesValid and
    GossipedFatPointerSigTransportEnvelopesValid and
    GossipedPrecommitsHaveTransportEnvelope and
    ObservedPrecommitsHaveTransportEnvelope and
    GossipedFatPointerSigsHaveTransportEnvelope and
    ObservedFatPointersHaveTransportEvidence
}

module CrosslinkHeightedAuthenticatedGossipTransportTest {
  import CrosslinkHeightedAuthenticatedGossipTransport.* from "./CrosslinkHeightedAuthenticatedGossipTransport"
  export CrosslinkHeightedAuthenticatedGossipTransport.*

  pure val P1H1RotatePrecommitEnvelope = Env(
    CrosslinkGossipTopic,
    PrecommitEnvelopeKind,
    "p1",
    1,
    0,
    "rotate",
    "pc-1-0-rotate",
    "sig-p1-pc-1-0-rotate",
  )

  pure val P2H1RotatePrecommitEnvelope = Env(
    CrosslinkGossipTopic,
    PrecommitEnvelopeKind,
    "p2",
    1,
    0,
    "rotate",
    "pc-1-0-rotate",
    "sig-p2-pc-1-0-rotate",
  )

  pure val P2H2StayPrecommitEnvelope = Env(
    CrosslinkGossipTopic,
    PrecommitEnvelopeKind,
    "p2",
    2,
    0,
    "stay",
    "pc-2-0-stay",
    "sig-p2-pc-2-0-stay",
  )

  pure val P4H2StayPrecommitEnvelope = Env(
    CrosslinkGossipTopic,
    PrecommitEnvelopeKind,
    "p4",
    2,
    0,
    "stay",
    "pc-2-0-stay",
    "sig-p4-pc-2-0-stay",
  )

  pure val P1H1RotateFatPointerSigEnvelope = Env(
    CrosslinkGossipTopic,
    FatPointerSigEnvelopeKind,
    "p1",
    1,
    0,
    "rotate",
    "fp-1-0-rotate",
    "sig-p1-fp-1-0-rotate",
  )

  pure val P2H1RotateFatPointerSigEnvelope = Env(
    CrosslinkGossipTopic,
    FatPointerSigEnvelopeKind,
    "p2",
    1,
    0,
    "rotate",
    "fp-1-0-rotate",
    "sig-p2-fp-1-0-rotate",
  )

  pure val P2H2StayFatPointerSigEnvelope = Env(
    CrosslinkGossipTopic,
    FatPointerSigEnvelopeKind,
    "p2",
    2,
    0,
    "stay",
    "fp-2-0-stay",
    "sig-p2-fp-2-0-stay",
  )

  pure val P4H2StayFatPointerSigEnvelope = Env(
    CrosslinkGossipTopic,
    FatPointerSigEnvelopeKind,
    "p4",
    2,
    0,
    "stay",
    "fp-2-0-stay",
    "sig-p4-fp-2-0-stay",
  )

  pure val WrongTopicPrecommitEnvelope = Env(
    WrongGossipTopic,
    PrecommitEnvelopeKind,
    "p1",
    1,
    0,
    "rotate",
    "pc-1-0-rotate",
    "sig-p1-pc-1-0-rotate",
  )

  pure val WrongKindPrecommitEnvelope = Env(
    CrosslinkGossipTopic,
    WrongEnvelopeKind,
    "p1",
    1,
    0,
    "rotate",
    "pc-1-0-rotate",
    "sig-p1-pc-1-0-rotate",
  )

  pure val WrongBytesPrecommitEnvelope = Env(
    CrosslinkGossipTopic,
    PrecommitEnvelopeKind,
    "p1",
    1,
    0,
    "rotate",
    "pc-2-0-stay",
    "sig-p1-pc-1-0-rotate",
  )

  pure val CrossHeightReplayPrecommitEnvelope = Env(
    CrosslinkGossipTopic,
    PrecommitEnvelopeKind,
    "p2",
    2,
    0,
    "stay",
    "pc-1-0-stay",
    "sig-p2-pc-1-0-stay",
  )

  pure val WrongKindFatPointerSigEnvelope = Env(
    CrosslinkGossipTopic,
    WrongEnvelopeKind,
    "p1",
    1,
    0,
    "rotate",
    "fp-1-0-rotate",
    "sig-p1-fp-1-0-rotate",
  )

  pure val WrongBytesFatPointerSigEnvelope = Env(
    CrosslinkGossipTopic,
    FatPointerSigEnvelopeKind,
    "p1",
    1,
    0,
    "rotate",
    "fp-2-0-stay",
    "sig-p1-fp-1-0-rotate",
  )

  pure val TestTransportEnvelopes = Set(
    P1H1RotatePrecommitEnvelope,
    P2H1RotatePrecommitEnvelope,
    P2H2StayPrecommitEnvelope,
    P4H2StayPrecommitEnvelope,
    P1H1RotateFatPointerSigEnvelope,
    P2H1RotateFatPointerSigEnvelope,
    P2H2StayFatPointerSigEnvelope,
    P4H2StayFatPointerSigEnvelope,
    WrongTopicPrecommitEnvelope,
    WrongKindPrecommitEnvelope,
    WrongBytesPrecommitEnvelope,
    CrossHeightReplayPrecommitEnvelope,
    WrongKindFatPointerSigEnvelope,
    WrongBytesFatPointerSigEnvelope,
  )

  action TransportNext: bool =
    any {
      nondet h = oneOf(Heights)
      nondet candidate = oneOf(Snapshots)
      nondet signers = oneOf(powerset(ValidatorUniverse))
      DecideAtTransport(h, candidate, signers),
      nondet env = oneOf(TestTransportEnvelopes)
      GossipPrecommitTransport(env),
      nondet env = oneOf(TestTransportEnvelopes)
      ObservePrecommitFromTransport(env),
      nondet env = oneOf(TestTransportEnvelopes)
      GossipFatPointerSigTransport(env),
      nondet h = oneOf(Heights)
      nondet r = oneOf(Rounds)
      nondet v = oneOf(Snapshots)
      nondet signers = oneOf(powerset(ValidatorUniverse))
      ObserveFatPointerFromTransport(h, r, v, signers),
      TransportStutter,
    }

  action transportUnchangedAll = all {
    nextBftHeight' = nextBftHeight,
    currentValidatorSet' = currentValidatorSet,
    validatorSetAtHeight' = validatorSetAtHeight,
    decision' = decision,
    commitSigners' = commitSigners,
    gossipPrecommit' = gossipPrecommit,
    gossipFatPointerSig' = gossipFatPointerSig,
    observedPrecommit' = observedPrecommit,
    observedFatPointer' = observedFatPointer,
    gossipedPrecommitTransportEnvelope' =
      gossipedPrecommitTransportEnvelope,
    gossipedFatPointerSigTransportEnvelope' =
      gossipedFatPointerSigTransportEnvelope,
    firedAction' = firedAction,
    transportFiredAction' = transportFiredAction,
  }

  run precommitObservedThroughTransportTest = {
    TransportInit
      .then(GossipPrecommitTransport(P1H1RotatePrecommitEnvelope))
      .then(ObservePrecommitFromTransport(P1H1RotatePrecommitEnvelope))
      .then(all {
        assert(observedPrecommit.get(1).get(0).contains(PrecommitFromEnvelope(P1H1RotatePrecommitEnvelope))),
        assert(TransportSafety),
        transportUnchangedAll,
      })
  }

  run fatPointerObservedAfterTransportedEvidenceTest = {
    TransportInit
      .then(GossipPrecommitTransport(P1H1RotatePrecommitEnvelope))
      .then(GossipPrecommitTransport(P2H1RotatePrecommitEnvelope))
      .then(ObservePrecommitFromTransport(P1H1RotatePrecommitEnvelope))
      .then(ObservePrecommitFromTransport(P2H1RotatePrecommitEnvelope))
      .then(GossipFatPointerSigTransport(P1H1RotateFatPointerSigEnvelope))
      .then(GossipFatPointerSigTransport(P2H1RotateFatPointerSigEnvelope))
      .then(ObserveFatPointerFromTransport(1, 0, "rotate", Set("p1", "p2")))
      .then(all {
        assert(observedFatPointer.contains({
          height: 1,
          round: 0,
          id: "rotate",
          signers: Set("p1", "p2"),
        })),
        assert(TransportSafety),
        transportUnchangedAll,
      })
  }

  run rotatedSetFatPointerObservedThroughTransportTest = {
    TransportInit
      .then(DecideAtTransport(1, "rotate", Set("p1", "p2")))
      .then(GossipPrecommitTransport(P2H2StayPrecommitEnvelope))
      .then(GossipPrecommitTransport(P4H2StayPrecommitEnvelope))
      .then(ObservePrecommitFromTransport(P2H2StayPrecommitEnvelope))
      .then(ObservePrecommitFromTransport(P4H2StayPrecommitEnvelope))
      .then(GossipFatPointerSigTransport(P2H2StayFatPointerSigEnvelope))
      .then(GossipFatPointerSigTransport(P4H2StayFatPointerSigEnvelope))
      .then(ObserveFatPointerFromTransport(2, 0, "stay", Set("p2", "p4")))
      .then(all {
        assert(currentValidatorSet == Set("p2", "p3", "p4")),
        assert(observedFatPointer.contains({
          height: 2,
          round: 0,
          id: "stay",
          signers: Set("p2", "p4"),
        })),
        assert(TransportSafety),
        transportUnchangedAll,
      })
  }

  run precommitRejectedBeforeTransportTest = {
    TransportInit
      .then(RawGossipPrecommitWithoutTransport(
        "p1",
        1,
        0,
        "rotate",
        "pc-1-0-rotate",
        "sig-p1-pc-1-0-rotate",
      ))
      .then(ObservePrecommitFromTransport(P1H1RotatePrecommitEnvelope))
      .fail()
  }

  run fatPointerRejectedWithoutFatPointerSigTransportTest = {
    TransportInit
      .then(GossipPrecommitTransport(P1H1RotatePrecommitEnvelope))
      .then(GossipPrecommitTransport(P2H1RotatePrecommitEnvelope))
      .then(ObservePrecommitFromTransport(P1H1RotatePrecommitEnvelope))
      .then(ObservePrecommitFromTransport(P2H1RotatePrecommitEnvelope))
      .then(RawGossipFatPointerSigWithoutTransport(
        "p1",
        1,
        0,
        "rotate",
        "fp-1-0-rotate",
        "sig-p1-fp-1-0-rotate",
      ))
      .then(RawGossipFatPointerSigWithoutTransport(
        "p2",
        1,
        0,
        "rotate",
        "fp-1-0-rotate",
        "sig-p2-fp-1-0-rotate",
      ))
      .then(ObserveFatPointerFromTransport(1, 0, "rotate", Set("p1", "p2")))
      .fail()
  }

  run wrongTopicPrecommitEnvelopeRejectedTest = {
    TransportInit
      .then(GossipPrecommitTransport(WrongTopicPrecommitEnvelope))
      .fail()
  }

  run wrongKindPrecommitEnvelopeRejectedTest = {
    TransportInit
      .then(GossipPrecommitTransport(WrongKindPrecommitEnvelope))
      .fail()
  }

  run wrongBytesPrecommitEnvelopeRejectedTest = {
    TransportInit
      .then(GossipPrecommitTransport(WrongBytesPrecommitEnvelope))
      .fail()
  }

  run crossHeightReplayPrecommitEnvelopeRejectedTest = {
    TransportInit
      .then(DecideAtTransport(1, "rotate", Set("p1", "p2")))
      .then(GossipPrecommitTransport(CrossHeightReplayPrecommitEnvelope))
      .fail()
  }

  run wrongKindFatPointerSigEnvelopeRejectedTest = {
    TransportInit
      .then(GossipFatPointerSigTransport(WrongKindFatPointerSigEnvelope))
      .fail()
  }

  run wrongBytesFatPointerSigEnvelopeRejectedTest = {
    TransportInit
      .then(GossipFatPointerSigTransport(WrongBytesFatPointerSigEnvelope))
      .fail()
  }

  run transportSafetyTest = {
    TransportInit
      .then(all {
        assert(TransportSafety),
        transportUnchangedAll,
      })
  }
}

module CrosslinkHeightedAuthenticatedGossipTransportModel {
  import CrosslinkHeightedAuthenticatedGossipTransportTest(
    ValidatorUniverse = Set("p1", "p2", "p3", "p4"),
    VotingPower = Map("p1" -> 1, "p2" -> 1, "p3" -> 1, "p4" -> 1),
    QuorumVotingPower = 2,
    MaxBftHeight = 2,
    MaxRound = 0,
    Snapshots = Set("rotate", "stay"),
    Bytes = Set(
      "pc-1-0-rotate",
      "pc-1-0-stay",
      "pc-1-0-None",
      "pc-2-0-rotate",
      "pc-2-0-stay",
      "pc-2-0-None",
      "fp-1-0-rotate",
      "fp-1-0-stay",
      "fp-2-0-rotate",
      "fp-2-0-stay",
    ),
    Signatures = Set(
      "sig-p1-pc-1-0-rotate",
      "sig-p1-pc-2-0-stay",
      "sig-p1-fp-1-0-rotate",
      "sig-p2-pc-1-0-rotate",
      "sig-p2-pc-1-0-stay",
      "sig-p2-pc-2-0-stay",
      "sig-p2-fp-1-0-rotate",
      "sig-p2-fp-2-0-stay",
      "sig-p4-pc-2-0-stay",
      "sig-p4-fp-2-0-stay",
    ),
    SignatureOwner = Map(
      "sig-p1-pc-1-0-rotate" -> "p1",
      "sig-p1-pc-2-0-stay" -> "p1",
      "sig-p1-fp-1-0-rotate" -> "p1",
      "sig-p2-pc-1-0-rotate" -> "p2",
      "sig-p2-pc-1-0-stay" -> "p2",
      "sig-p2-pc-2-0-stay" -> "p2",
      "sig-p2-fp-1-0-rotate" -> "p2",
      "sig-p2-fp-2-0-stay" -> "p2",
      "sig-p4-pc-2-0-stay" -> "p4",
      "sig-p4-fp-2-0-stay" -> "p4",
    ),
    SignatureBytes = Map(
      "sig-p1-pc-1-0-rotate" -> "pc-1-0-rotate",
      "sig-p1-pc-2-0-stay" -> "pc-2-0-stay",
      "sig-p1-fp-1-0-rotate" -> "fp-1-0-rotate",
      "sig-p2-pc-1-0-rotate" -> "pc-1-0-rotate",
      "sig-p2-pc-1-0-stay" -> "pc-1-0-stay",
      "sig-p2-pc-2-0-stay" -> "pc-2-0-stay",
      "sig-p2-fp-1-0-rotate" -> "fp-1-0-rotate",
      "sig-p2-fp-2-0-stay" -> "fp-2-0-stay",
      "sig-p4-pc-2-0-stay" -> "pc-2-0-stay",
      "sig-p4-fp-2-0-stay" -> "fp-2-0-stay",
    ),
    PrecommitPayload = Map(
      1 -> Map(0 -> Map(
        "rotate" -> "pc-1-0-rotate",
        "stay" -> "pc-1-0-stay",
        "None" -> "pc-1-0-None",
      )),
      2 -> Map(0 -> Map(
        "rotate" -> "pc-2-0-rotate",
        "stay" -> "pc-2-0-stay",
        "None" -> "pc-2-0-None",
      )),
    ),
    FatPointerPayload = Map(
      1 -> Map(0 -> Map(
        "rotate" -> "fp-1-0-rotate",
        "stay" -> "fp-1-0-stay",
      )),
      2 -> Map(0 -> Map(
        "rotate" -> "fp-2-0-rotate",
        "stay" -> "fp-2-0-stay",
      )),
    ),
    InitialValidatorSet = Set("p1", "p2", "p3"),
    NextValidatorSetOf = Map(
      "rotate" -> Set("p2", "p3", "p4"),
      "stay" -> Set("p2", "p3", "p4"),
    ),
  ).*
}
