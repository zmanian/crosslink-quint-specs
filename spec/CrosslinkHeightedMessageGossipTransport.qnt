module CrosslinkHeightedMessageGossipTransport {
  /*
   Heighted message-authentication gossip transport bridge.

   CrosslinkHeightedMessageAuth.qnt models the canonical bytes and signature
   checks for proposals, prevotes, precommits, and fat-pointer signatures. This
   module adds the transport boundary in front of that authentication slice:
   before a signed message is accepted, it must be carried in a Crosslink
   consensus-topic envelope with the expected message kind.
   */

  import CrosslinkHeightedMessageAuth.* from "./CrosslinkHeightedMessageAuth"
  export CrosslinkHeightedMessageAuth.*

  type Topic_t = str
  type TransportKind_t = str
  type HeightedMessageEnvelope_t = {
    topic: Topic_t,
    kind: TransportKind_t,
    src: Proc_t,
    height: Height_t,
    round: Round_t,
    id: Snapshot_t,
    validRound: Round_t,
    bytes: Bytes_t,
    sig: Sig_t,
  }

  pure val CrosslinkGossipTopic = "crosslink-consensus-v1"
  pure val WrongGossipTopic = "zcash-blocks-v1"
  pure val ProposalEnvelopeKind = "proposal"
  pure val PrevoteEnvelopeKind = "prevote"
  pure val PrecommitEnvelopeKind = "precommit"
  pure val FatPointerSigEnvelopeKind = "fat-pointer-signature"
  pure val WrongEnvelopeKind = "headers"

  var gossipedProposalEnvelope:
    Height_t -> Round_t -> Set[HeightedMessageEnvelope_t]
  var gossipedPrevoteEnvelope:
    Height_t -> Round_t -> Set[HeightedMessageEnvelope_t]
  var gossipedPrecommitEnvelope:
    Height_t -> Round_t -> Set[HeightedMessageEnvelope_t]
  var gossipedFatPointerSigEnvelope:
    Height_t -> Round_t -> Set[HeightedMessageEnvelope_t]
  var transportFiredAction: str

  def Env(
    topic: Topic_t,
    kind: TransportKind_t,
    src: Proc_t,
    height: Height_t,
    round: Round_t,
    id: Snapshot_t,
    validRound: Round_t,
    bytes: Bytes_t,
    sig: Sig_t,
  ): HeightedMessageEnvelope_t = {
    topic: topic,
    kind: kind,
    src: src,
    height: height,
    round: round,
    id: id,
    validRound: validRound,
    bytes: bytes,
    sig: sig,
  }

  def ProposalFromEnvelope(env: HeightedMessageEnvelope_t): SignedProposal_t = {
    src: env.src,
    height: env.height,
    round: env.round,
    proposal: env.id,
    validRound: env.validRound,
    bytes: env.bytes,
    sig: env.sig,
  }

  def VoteFromEnvelope(env: HeightedMessageEnvelope_t): SignedVote_t = {
    src: env.src,
    height: env.height,
    round: env.round,
    id: env.id,
    bytes: env.bytes,
    sig: env.sig,
  }

  def FatPointerSigFromEnvelope(
    env: HeightedMessageEnvelope_t,
  ): SignedFatPointerSig_t = {
    src: env.src,
    height: env.height,
    round: env.round,
    id: env.id,
    bytes: env.bytes,
    sig: env.sig,
  }

  def ProposalEnvelopeValid(env: HeightedMessageEnvelope_t): bool =
    env.topic == CrosslinkGossipTopic and
    env.kind == ProposalEnvelopeKind and
    ProposalAuthentic(ProposalFromEnvelope(env))

  def PrevoteEnvelopeValid(env: HeightedMessageEnvelope_t): bool =
    env.topic == CrosslinkGossipTopic and
    env.kind == PrevoteEnvelopeKind and
    env.validRound == NilRound and
    VoteAuthentic(VoteFromEnvelope(env), PrevotePayload)

  def PrecommitEnvelopeValid(env: HeightedMessageEnvelope_t): bool =
    env.topic == CrosslinkGossipTopic and
    env.kind == PrecommitEnvelopeKind and
    env.validRound == NilRound and
    VoteAuthentic(VoteFromEnvelope(env), PrecommitPayload)

  def FatPointerSigEnvelopeValid(env: HeightedMessageEnvelope_t): bool =
    env.topic == CrosslinkGossipTopic and
    env.kind == FatPointerSigEnvelopeKind and
    env.validRound == NilRound and
    FatPointerSigAuthentic(FatPointerSigFromEnvelope(env))

  def ProposalEnvelopeMatches(
    env: HeightedMessageEnvelope_t,
    msg: SignedProposal_t,
  ): bool =
    env.src == msg.src and
    env.height == msg.height and
    env.round == msg.round and
    env.id == msg.proposal and
    env.validRound == msg.validRound and
    env.bytes == msg.bytes and
    env.sig == msg.sig

  def VoteEnvelopeMatches(
    env: HeightedMessageEnvelope_t,
    msg: SignedVote_t,
  ): bool =
    env.src == msg.src and
    env.height == msg.height and
    env.round == msg.round and
    env.id == msg.id and
    env.validRound == NilRound and
    env.bytes == msg.bytes and
    env.sig == msg.sig

  def FatPointerSigEnvelopeMatches(
    env: HeightedMessageEnvelope_t,
    msg: SignedFatPointerSig_t,
  ): bool =
    env.src == msg.src and
    env.height == msg.height and
    env.round == msg.round and
    env.id == msg.id and
    env.validRound == NilRound and
    env.bytes == msg.bytes and
    env.sig == msg.sig

  def MatchingProposalEnvelope(msg: SignedProposal_t): bool =
    gossipedProposalEnvelope
      .get(msg.height)
      .get(msg.round)
      .exists(env =>
        ProposalEnvelopeValid(env) and ProposalEnvelopeMatches(env, msg)
      )

  def MatchingPrevoteEnvelope(msg: SignedVote_t): bool =
    gossipedPrevoteEnvelope
      .get(msg.height)
      .get(msg.round)
      .exists(env =>
        PrevoteEnvelopeValid(env) and VoteEnvelopeMatches(env, msg)
      )

  def MatchingPrecommitEnvelope(msg: SignedVote_t): bool =
    gossipedPrecommitEnvelope
      .get(msg.height)
      .get(msg.round)
      .exists(env =>
        PrecommitEnvelopeValid(env) and VoteEnvelopeMatches(env, msg)
      )

  def MatchingFatPointerSigEnvelope(msg: SignedFatPointerSig_t): bool =
    gossipedFatPointerSigEnvelope
      .get(msg.height)
      .get(msg.round)
      .exists(env =>
        FatPointerSigEnvelopeValid(env) and
        FatPointerSigEnvelopeMatches(env, msg)
      )

  action TransportInit = all {
    Init,
    gossipedProposalEnvelope' =
      Heights.mapBy(_ => Rounds.mapBy(_ => Set())),
    gossipedPrevoteEnvelope' =
      Heights.mapBy(_ => Rounds.mapBy(_ => Set())),
    gossipedPrecommitEnvelope' =
      Heights.mapBy(_ => Rounds.mapBy(_ => Set())),
    gossipedFatPointerSigEnvelope' =
      Heights.mapBy(_ => Rounds.mapBy(_ => Set())),
    transportFiredAction' = "TransportInit",
  }

  action KeepTransportState = all {
    gossipedProposalEnvelope' = gossipedProposalEnvelope,
    gossipedPrevoteEnvelope' = gossipedPrevoteEnvelope,
    gossipedPrecommitEnvelope' = gossipedPrecommitEnvelope,
    gossipedFatPointerSigEnvelope' = gossipedFatPointerSigEnvelope,
  }

  action AcceptProposalTransport(env: HeightedMessageEnvelope_t): bool =
    all {
      ProposalEnvelopeValid(env),
      AcceptProposal(
        env.src,
        env.height,
        env.round,
        env.id,
        env.validRound,
        env.bytes,
        env.sig,
      ),
      gossipedProposalEnvelope' =
        gossipedProposalEnvelope.setBy(env.height, byRound =>
          byRound.setBy(env.round, old => old.union(Set(env)))
        ),
      gossipedPrevoteEnvelope' = gossipedPrevoteEnvelope,
      gossipedPrecommitEnvelope' = gossipedPrecommitEnvelope,
      gossipedFatPointerSigEnvelope' = gossipedFatPointerSigEnvelope,
      transportFiredAction' = "AcceptProposalTransport",
    }

  action AcceptPrevoteTransport(env: HeightedMessageEnvelope_t): bool =
    all {
      PrevoteEnvelopeValid(env),
      AcceptPrevote(
        env.src,
        env.height,
        env.round,
        env.id,
        env.bytes,
        env.sig,
      ),
      gossipedProposalEnvelope' = gossipedProposalEnvelope,
      gossipedPrevoteEnvelope' =
        gossipedPrevoteEnvelope.setBy(env.height, byRound =>
          byRound.setBy(env.round, old => old.union(Set(env)))
        ),
      gossipedPrecommitEnvelope' = gossipedPrecommitEnvelope,
      gossipedFatPointerSigEnvelope' = gossipedFatPointerSigEnvelope,
      transportFiredAction' = "AcceptPrevoteTransport",
    }

  action AcceptPrecommitTransport(env: HeightedMessageEnvelope_t): bool =
    all {
      PrecommitEnvelopeValid(env),
      AcceptPrecommit(
        env.src,
        env.height,
        env.round,
        env.id,
        env.bytes,
        env.sig,
      ),
      gossipedProposalEnvelope' = gossipedProposalEnvelope,
      gossipedPrevoteEnvelope' = gossipedPrevoteEnvelope,
      gossipedPrecommitEnvelope' =
        gossipedPrecommitEnvelope.setBy(env.height, byRound =>
          byRound.setBy(env.round, old => old.union(Set(env)))
        ),
      gossipedFatPointerSigEnvelope' = gossipedFatPointerSigEnvelope,
      transportFiredAction' = "AcceptPrecommitTransport",
    }

  action AcceptFatPointerSigTransport(env: HeightedMessageEnvelope_t): bool =
    all {
      FatPointerSigEnvelopeValid(env),
      AcceptFatPointerSig(
        env.src,
        env.height,
        env.round,
        env.id,
        env.bytes,
        env.sig,
      ),
      gossipedProposalEnvelope' = gossipedProposalEnvelope,
      gossipedPrevoteEnvelope' = gossipedPrevoteEnvelope,
      gossipedPrecommitEnvelope' = gossipedPrecommitEnvelope,
      gossipedFatPointerSigEnvelope' =
        gossipedFatPointerSigEnvelope.setBy(env.height, byRound =>
          byRound.setBy(env.round, old => old.union(Set(env)))
        ),
      transportFiredAction' = "AcceptFatPointerSigTransport",
    }

  action RawAcceptProposalWithoutTransport(
    p: Proc_t,
    h: Height_t,
    r: Round_t,
    v: Snapshot_t,
    vr: Round_t,
    bytes: Bytes_t,
    sig: Sig_t,
  ): bool =
    all {
      AcceptProposal(p, h, r, v, vr, bytes, sig),
      KeepTransportState,
      transportFiredAction' = "RawAcceptProposalWithoutTransport",
    }

  action TransportStutter: bool =
    all {
      Stutter,
      KeepTransportState,
      transportFiredAction' = transportFiredAction,
    }

  val GossipedProposalEnvelopesValid =
    Heights.forall(h =>
      Rounds.forall(r =>
        gossipedProposalEnvelope.get(h).get(r).forall(ProposalEnvelopeValid)
      )
    )

  val GossipedPrevoteEnvelopesValid =
    Heights.forall(h =>
      Rounds.forall(r =>
        gossipedPrevoteEnvelope.get(h).get(r).forall(PrevoteEnvelopeValid)
      )
    )

  val GossipedPrecommitEnvelopesValid =
    Heights.forall(h =>
      Rounds.forall(r =>
        gossipedPrecommitEnvelope.get(h).get(r).forall(PrecommitEnvelopeValid)
      )
    )

  val GossipedFatPointerSigEnvelopesValid =
    Heights.forall(h =>
      Rounds.forall(r =>
        gossipedFatPointerSigEnvelope
          .get(h)
          .get(r)
          .forall(FatPointerSigEnvelopeValid)
      )
    )

  val AcceptedProposalsHaveTransportEnvelope =
    Heights.forall(h =>
      Rounds.forall(r =>
        acceptedPropose.get(h).get(r).forall(MatchingProposalEnvelope)
      )
    )

  val AcceptedPrevotesHaveTransportEnvelope =
    Heights.forall(h =>
      Rounds.forall(r =>
        acceptedPrevote.get(h).get(r).forall(MatchingPrevoteEnvelope)
      )
    )

  val AcceptedPrecommitsHaveTransportEnvelope =
    Heights.forall(h =>
      Rounds.forall(r =>
        acceptedPrecommit.get(h).get(r).forall(MatchingPrecommitEnvelope)
      )
    )

  val AcceptedFatPointerSigsHaveTransportEnvelope =
    Heights.forall(h =>
      Rounds.forall(r =>
        acceptedFatPointerSig
          .get(h)
          .get(r)
          .forall(MatchingFatPointerSigEnvelope)
      )
    )

  val TransportSafety =
    Safety and
    GossipedProposalEnvelopesValid and
    GossipedPrevoteEnvelopesValid and
    GossipedPrecommitEnvelopesValid and
    GossipedFatPointerSigEnvelopesValid and
    AcceptedProposalsHaveTransportEnvelope and
    AcceptedPrevotesHaveTransportEnvelope and
    AcceptedPrecommitsHaveTransportEnvelope and
    AcceptedFatPointerSigsHaveTransportEnvelope
}

module CrosslinkHeightedMessageGossipTransportTest {
  import CrosslinkHeightedMessageGossipTransport.* from "./CrosslinkHeightedMessageGossipTransport"
  export CrosslinkHeightedMessageGossipTransport.*

  pure val P1H1ProposalEnvelope = Env(
    CrosslinkGossipTopic,
    ProposalEnvelopeKind,
    "p1",
    1,
    0,
    "h1r0",
    NilRound,
    "h1r0_proposal_nil",
    "sig_p1_h1r0_proposal_nil",
  )

  pure val P1H1PrevoteEnvelope = Env(
    CrosslinkGossipTopic,
    PrevoteEnvelopeKind,
    "p1",
    1,
    0,
    "h1r0",
    NilRound,
    "h1r0_prevote",
    "sig_p1_h1r0_prevote",
  )

  pure val P1H1PrecommitEnvelope = Env(
    CrosslinkGossipTopic,
    PrecommitEnvelopeKind,
    "p1",
    1,
    0,
    "h1r0",
    NilRound,
    "h1r0_precommit",
    "sig_p1_h1r0_precommit",
  )

  pure val P1H1FatPointerSigEnvelope = Env(
    CrosslinkGossipTopic,
    FatPointerSigEnvelopeKind,
    "p1",
    1,
    0,
    "h1r0",
    NilRound,
    "h1r0_fat_pointer",
    "sig_p1_h1r0_fp",
  )

  pure val P2H1FatPointerSigEnvelope = Env(
    CrosslinkGossipTopic,
    FatPointerSigEnvelopeKind,
    "p2",
    1,
    0,
    "h1r0",
    NilRound,
    "h1r0_fat_pointer",
    "sig_p2_h1r0_fp",
  )

  pure val P3H1FatPointerSigEnvelope = Env(
    CrosslinkGossipTopic,
    FatPointerSigEnvelopeKind,
    "p3",
    1,
    0,
    "h1r0",
    NilRound,
    "h1r0_fat_pointer",
    "sig_p3_h1r0_fp",
  )

  pure val WrongTopicProposalEnvelope = Env(
    WrongGossipTopic,
    ProposalEnvelopeKind,
    "p1",
    1,
    0,
    "h1r0",
    NilRound,
    "h1r0_proposal_nil",
    "sig_p1_h1r0_proposal_nil",
  )

  pure val WrongKindPrevoteEnvelope = Env(
    CrosslinkGossipTopic,
    WrongEnvelopeKind,
    "p1",
    1,
    0,
    "h1r0",
    NilRound,
    "h1r0_prevote",
    "sig_p1_h1r0_prevote",
  )

  pure val ExtraValidRoundPrevoteEnvelope = Env(
    CrosslinkGossipTopic,
    PrevoteEnvelopeKind,
    "p1",
    1,
    0,
    "h1r0",
    0,
    "h1r0_prevote",
    "sig_p1_h1r0_prevote",
  )

  pure val CrossHeightPrecommitReplayEnvelope = Env(
    CrosslinkGossipTopic,
    PrecommitEnvelopeKind,
    "p1",
    2,
    0,
    "h2r0",
    NilRound,
    "h1r0_precommit",
    "sig_p1_h1r0_precommit",
  )

  pure val ForgedPrevoteEnvelope = Env(
    CrosslinkGossipTopic,
    PrevoteEnvelopeKind,
    "p1",
    1,
    0,
    "h1r0",
    NilRound,
    "h1r0_prevote",
    "sig_bad",
  )

  pure val WrongBytesFatPointerSigEnvelope = Env(
    CrosslinkGossipTopic,
    FatPointerSigEnvelopeKind,
    "p1",
    1,
    0,
    "h1r0",
    NilRound,
    "h2r0_fat_pointer",
    "sig_p1_h1r0_fp",
  )

  pure val TestTransportEnvelopes = Set(
    P1H1ProposalEnvelope,
    P1H1PrevoteEnvelope,
    P1H1PrecommitEnvelope,
    P1H1FatPointerSigEnvelope,
    P2H1FatPointerSigEnvelope,
    P3H1FatPointerSigEnvelope,
    WrongTopicProposalEnvelope,
    WrongKindPrevoteEnvelope,
    ExtraValidRoundPrevoteEnvelope,
    CrossHeightPrecommitReplayEnvelope,
    ForgedPrevoteEnvelope,
    WrongBytesFatPointerSigEnvelope,
  )

  action TransportNext: bool =
    any {
      nondet env = oneOf(TestTransportEnvelopes)
      AcceptProposalTransport(env),
      nondet env = oneOf(TestTransportEnvelopes)
      AcceptPrevoteTransport(env),
      nondet env = oneOf(TestTransportEnvelopes)
      AcceptPrecommitTransport(env),
      nondet env = oneOf(TestTransportEnvelopes)
      AcceptFatPointerSigTransport(env),
      TransportStutter,
    }

  action transportUnchangedAll = all {
    acceptedPropose' = acceptedPropose,
    acceptedPrevote' = acceptedPrevote,
    acceptedPrecommit' = acceptedPrecommit,
    acceptedFatPointerSig' = acceptedFatPointerSig,
    gossipedProposalEnvelope' = gossipedProposalEnvelope,
    gossipedPrevoteEnvelope' = gossipedPrevoteEnvelope,
    gossipedPrecommitEnvelope' = gossipedPrecommitEnvelope,
    gossipedFatPointerSigEnvelope' = gossipedFatPointerSigEnvelope,
    firedAction' = firedAction,
    transportFiredAction' = transportFiredAction,
  }

  run acceptsProposalThroughTransportTest = {
    TransportInit
      .then(AcceptProposalTransport(P1H1ProposalEnvelope))
      .then(all {
        assert(acceptedPropose.get(1).get(0).contains(ProposalFromEnvelope(P1H1ProposalEnvelope))),
        assert(TransportSafety),
        transportUnchangedAll,
      })
  }

  run acceptsVotesThroughTransportTest = {
    TransportInit
      .then(AcceptPrevoteTransport(P1H1PrevoteEnvelope))
      .then(AcceptPrecommitTransport(P1H1PrecommitEnvelope))
      .then(all {
        assert(acceptedPrevote.get(1).get(0).contains(VoteFromEnvelope(P1H1PrevoteEnvelope))),
        assert(acceptedPrecommit.get(1).get(0).contains(VoteFromEnvelope(P1H1PrecommitEnvelope))),
        assert(TransportSafety),
        transportUnchangedAll,
      })
  }

  run acceptsFatPointerSignatureQuorumThroughTransportTest = {
    TransportInit
      .then(AcceptFatPointerSigTransport(P1H1FatPointerSigEnvelope))
      .then(AcceptFatPointerSigTransport(P2H1FatPointerSigEnvelope))
      .then(AcceptFatPointerSigTransport(P3H1FatPointerSigEnvelope))
      .then(all {
        assert(AcceptedFatPointerQuorum(1, 0, "h1r0")),
        assert(TransportSafety),
        transportUnchangedAll,
      })
  }

  run rawProposalWithoutTransportViolatesTransportSafetyTest = {
    TransportInit
      .then(RawAcceptProposalWithoutTransport(
        "p1",
        1,
        0,
        "h1r0",
        NilRound,
        "h1r0_proposal_nil",
        "sig_p1_h1r0_proposal_nil",
      ))
      .then(all {
        assert(not(TransportSafety)),
        transportUnchangedAll,
      })
  }

  run wrongTopicProposalEnvelopeRejectedTest = {
    TransportInit
      .then(AcceptProposalTransport(WrongTopicProposalEnvelope))
      .fail()
  }

  run wrongKindPrevoteEnvelopeRejectedTest = {
    TransportInit
      .then(AcceptPrevoteTransport(WrongKindPrevoteEnvelope))
      .fail()
  }

  run extraValidRoundPrevoteEnvelopeRejectedTest = {
    TransportInit
      .then(AcceptPrevoteTransport(ExtraValidRoundPrevoteEnvelope))
      .fail()
  }

  run crossHeightPrecommitReplayEnvelopeRejectedTest = {
    TransportInit
      .then(AcceptPrecommitTransport(CrossHeightPrecommitReplayEnvelope))
      .fail()
  }

  run forgedPrevoteEnvelopeRejectedTest = {
    TransportInit
      .then(AcceptPrevoteTransport(ForgedPrevoteEnvelope))
      .fail()
  }

  run wrongBytesFatPointerSigEnvelopeRejectedTest = {
    TransportInit
      .then(AcceptFatPointerSigTransport(WrongBytesFatPointerSigEnvelope))
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

module CrosslinkHeightedMessageGossipTransportModel {
  import CrosslinkHeightedMessageGossipTransportTest(
    Corr = Set("p1", "p2", "p3"),
    Faulty = Set("p4"),
    VotingPower = Map("p1" -> 1, "p2" -> 1, "p3" -> 1, "p4" -> 1),
    QuorumVotingPower = 3,
    MaxBftHeight = 2,
    MaxRound = 0,
    Snapshots = Set("h1r0", "h2r0"),
    Bytes = Set(
      "h1r0_proposal_nil",
      "h1r0_proposal_r0",
      "h2r0_proposal_nil",
      "h2r0_proposal_r0",
      "h1r0_prevote",
      "h2r0_prevote",
      "h1_nil_prevote",
      "h2_nil_prevote",
      "h1r0_precommit",
      "h2r0_precommit",
      "h1_nil_precommit",
      "h2_nil_precommit",
      "h1r0_fat_pointer",
      "h2r0_fat_pointer",
      "bad_bytes",
    ),
    Signatures = Set(
      "sig_p1_h1r0_proposal_nil",
      "sig_p1_h1r0_precommit",
      "sig_p1_h1r0_prevote",
      "sig_p1_h1r0_fp",
      "sig_p2_h1r0_fp",
      "sig_p3_h1r0_fp",
      "sig_bad",
    ),
    SignatureOwner = Map(
      "sig_p1_h1r0_proposal_nil" -> "p1",
      "sig_p1_h1r0_precommit" -> "p1",
      "sig_p1_h1r0_prevote" -> "p1",
      "sig_p1_h1r0_fp" -> "p1",
      "sig_p2_h1r0_fp" -> "p2",
      "sig_p3_h1r0_fp" -> "p3",
      "sig_bad" -> "p4",
    ),
    SignatureBytes = Map(
      "sig_p1_h1r0_proposal_nil" -> "h1r0_proposal_nil",
      "sig_p1_h1r0_precommit" -> "h1r0_precommit",
      "sig_p1_h1r0_prevote" -> "h1r0_prevote",
      "sig_p1_h1r0_fp" -> "h1r0_fat_pointer",
      "sig_p2_h1r0_fp" -> "h1r0_fat_pointer",
      "sig_p3_h1r0_fp" -> "h1r0_fat_pointer",
      "sig_bad" -> "bad_bytes",
    ),
    ProposalPayload = Map(
      1 -> Map(
        0 -> Map(
          "h1r0" -> Map(-1 -> "h1r0_proposal_nil", 0 -> "h1r0_proposal_r0"),
          "h2r0" -> Map(-1 -> "h2r0_proposal_nil", 0 -> "h2r0_proposal_r0"),
        ),
      ),
      2 -> Map(
        0 -> Map(
          "h1r0" -> Map(-1 -> "h1r0_proposal_nil", 0 -> "h1r0_proposal_r0"),
          "h2r0" -> Map(-1 -> "h2r0_proposal_nil", 0 -> "h2r0_proposal_r0"),
        ),
      ),
    ),
    PrevotePayload = Map(
      1 -> Map(0 -> Map(
        "h1r0" -> "h1r0_prevote",
        "h2r0" -> "h2r0_prevote",
        "None" -> "h1_nil_prevote",
      )),
      2 -> Map(0 -> Map(
        "h1r0" -> "h1r0_prevote",
        "h2r0" -> "h2r0_prevote",
        "None" -> "h2_nil_prevote",
      )),
    ),
    PrecommitPayload = Map(
      1 -> Map(0 -> Map(
        "h1r0" -> "h1r0_precommit",
        "h2r0" -> "h2r0_precommit",
        "None" -> "h1_nil_precommit",
      )),
      2 -> Map(0 -> Map(
        "h1r0" -> "h1r0_precommit",
        "h2r0" -> "h2r0_precommit",
        "None" -> "h2_nil_precommit",
      )),
    ),
    FatPointerPayload = Map(
      1 -> Map(0 -> Map(
        "h1r0" -> "h1r0_fat_pointer",
        "h2r0" -> "h2r0_fat_pointer",
      )),
      2 -> Map(0 -> Map(
        "h1r0" -> "h1r0_fat_pointer",
        "h2r0" -> "h2r0_fat_pointer",
      )),
    ),
  ).*
}
