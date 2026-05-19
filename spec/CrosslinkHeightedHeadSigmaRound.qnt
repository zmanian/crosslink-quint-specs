module CrosslinkHeightedHeadSigmaRound {
  /*
   Height-indexed Tenderlink rounds with concrete head-sigma streams.

   CrosslinkHeightedRound.qnt models Stream(height, round) abstractly. This
   module constrains that stream to the Crosslink proposal source: the ancestor
   at headHeight - sigma of the locally observed PoW head for the active BFT
   height and round.
   */

  import CrosslinkHeightedRound.* from "./CrosslinkHeightedRound"
  export CrosslinkHeightedRound.*

  type PowHeight_t = int
  type Block_t = str

  const MaxPowHeight: PowHeight_t
  const Sigma: int
  const InitialFinalized: Snapshot_t
  const HeightOf: Snapshot_t -> PowHeight_t
  const AncestorAt: Snapshot_t -> PowHeight_t -> Block_t
  const AncestorSnapshotAt: Snapshot_t -> PowHeight_t -> Snapshot_t
  const HeadAt: Height_t -> Round_t -> Snapshot_t

  pure val PowHeights = 0.to(MaxPowHeight)

  assume initial_finalized_is_snapshot =
    Snapshots.contains(InitialFinalized)
  assume sigma_is_positive =
    Sigma >= 1
  assume snapshot_pow_heights_are_in_range =
    Snapshots.forall(v => PowHeights.contains(HeightOf.get(v)))
  assume height_round_heads_are_snapshots =
    Heights.forall(h =>
      Rounds.forall(r => Snapshots.contains(HeadAt.get(h).get(r)))
    )

  pure def PowHeight(v: Snapshot_t): PowHeight_t =
    HeightOf.get(v)

  pure def CandidateHeight(tip: Snapshot_t): PowHeight_t =
    if (PowHeight(tip) >= Sigma) {
      PowHeight(tip) - Sigma
    } else {
      0
    }

  pure def BlockAt(v: Snapshot_t, h: PowHeight_t): Block_t =
    AncestorAt.get(v).get(h)

  pure def AncestorSnapshot(tip: Snapshot_t, h: PowHeight_t): Snapshot_t =
    AncestorSnapshotAt.get(tip).get(h)

  def Extends(newer: Snapshot_t, older: Snapshot_t): bool =
    IsSnapshot(newer) and
    IsSnapshot(older) and
    PowHeight(newer) >= PowHeight(older) and
    PowHeights.forall(h =>
      h > PowHeight(older) or BlockAt(newer, h) == BlockAt(older, h)
    )

  def HeadHasSigmaTail(tip: Snapshot_t): bool =
    IsSnapshot(tip) and PowHeight(tip) >= Sigma

  def HeadSigmaCandidate(tip: Snapshot_t): Snapshot_t =
    AncestorSnapshot(tip, CandidateHeight(tip))

  def TailConfirms(tip: Snapshot_t, candidate: Snapshot_t): bool =
    HeadHasSigmaTail(tip) and
    IsSnapshot(candidate) and
    PowHeight(tip) >= PowHeight(candidate) + Sigma and
    BlockAt(tip, PowHeight(candidate)) == BlockAt(candidate, PowHeight(candidate))

  def HeadSigmaAt(h: Height_t, r: Round_t): Snapshot_t =
    HeadSigmaCandidate(HeadAt.get(h).get(r))

  def ProposalValidAgainstFinalized(
    tip: Snapshot_t,
    candidate: Snapshot_t,
    finalizedPrefix: Snapshot_t,
  ): bool =
    IsSnapshot(tip) and
    IsSnapshot(candidate) and
    candidate == HeadSigmaCandidate(tip) and
    Extends(candidate, finalizedPrefix) and
    TailConfirms(tip, candidate)

  val StreamMatchesHeadSigma =
    Heights.forall(h =>
      Rounds.forall(r =>
        Stream.get(h).get(r) == HeadSigmaAt(h, r)
      )
    )

  val HeadSigmaCandidatesAreValid =
    Heights.forall(h =>
      Rounds.forall(r =>
        ProposalValidAgainstFinalized(
          HeadAt.get(h).get(r),
          Stream.get(h).get(r),
          InitialFinalized,
        )
      )
    )

  val CorrectFreshProposalMessagesCarryHeadSigma =
    Heights.forall(h =>
      Rounds.forall(r =>
        msgsPropose.get(h).get(r).forall(m =>
          not(Corr.contains(m.src)) or
          m.validRound != NilRound or (
            m.proposal == HeadSigmaAt(h, r) and
            ProposalValidAgainstFinalized(
              HeadAt.get(h).get(r),
              m.proposal,
              InitialFinalized,
            )
          )
        )
      )
    )

  val CorrectValuePrecommitsCarryCurrentHeadSigma =
    Heights.forall(h =>
      Rounds.forall(r =>
        msgsPrecommit.get(h).get(r).forall(m =>
          not(Corr.contains(m.src)) or
          m.id == NilSnapshot or
          m.id == HeadSigmaAt(h, r)
        )
      )
    )

  val HeadSigmaSafety =
    Safety and
    StreamMatchesHeadSigma and
    HeadSigmaCandidatesAreValid and
    CorrectFreshProposalMessagesCarryHeadSigma and
    CorrectValuePrecommitsCarryCurrentHeadSigma
}

module CrosslinkHeightedHeadSigmaRoundTest {
  import CrosslinkHeightedHeadSigmaRound.* from "./CrosslinkHeightedHeadSigmaRound"
  export CrosslinkHeightedHeadSigmaRound.*

  action unchangedAll = all {
    height' = height,
    round' = round,
    step' = step,
    decision' = decision,
    lockedValue' = lockedValue,
    lockedRound' = lockedRound,
    validValue' = validValue,
    validRound' = validRound,
    cachedProposal' = cachedProposal,
    cachedProposalRound' = cachedProposalRound,
    msgsPropose' = msgsPropose,
    msgsPrevote' = msgsPrevote,
    msgsPrecommit' = msgsPrecommit,
    seenPropose' = seenPropose,
    seenPrevote' = seenPrevote,
    seenPrecommit' = seenPrecommit,
    firedAction' = firedAction,
  }

  run freshHeightedProposalCarriesHeadSigmaCandidateTest = {
    Init
      .then(InsertProposal("p1"))
      .then(all {
        assert(HeadSigmaAt(1, 0) == "a1"),
        assert(msgsPropose.get(1).get(0).contains({
          src: "p1",
          height: 1,
          round: 0,
          proposal: "a1",
          validRound: NilRound,
        })),
        assert(CorrectFreshProposalMessagesCarryHeadSigma),
        assert(HeadSigmaSafety),
        unchangedAll,
      })
  }

  run streamChangeForHeadSigmaCandidatePrecommitsNilTest = {
    Init
      .then(InsertProposal("p1"))
      .then(DeliverProposal("p1", "p1", 1, 0, "a1", NilRound))
      .then(DeliverProposal("p2", "p1", 1, 0, "a1", NilRound))
      .then(DeliverProposal("p3", "p1", 1, 0, "a1", NilRound))
      .then(Prevote("p1", "a1"))
      .then(Prevote("p2", "a1"))
      .then(Prevote("p3", "a1"))
      .then(DeliverPrevotesTo("p1", 1, 0, "a1", Set("p1", "p2", "p3")))
      .then(PrecommitNilOnStreamChange("p1"))
      .then(all {
        assert(HeadSigmaAt(1, 0) == "a1"),
        assert(HeadSigmaAt(1, 1) == "b1"),
        assert(msgsPrecommit.get(1).get(0).exists(m =>
          m.src == "p1" and m.id == NilSnapshot
        )),
        assert(not(msgsPrecommit.get(1).get(0).exists(m =>
          m.src == "p1" and m.id == "a1"
        ))),
        assert(HeadSigmaSafety),
        unchangedAll,
      })
  }

  run nilCertificateClearsCacheAndNextFreshProposalResamplesTest = {
    Init
      .then(InsertProposal("p1"))
      .then(SeedNilPrecommitCertificateAt(1, 0, Set("p1", "p2", "p3")))
      .then(AdvanceAfterPrecommitQuorum("p1"))
      .then(InsertProposal("p1"))
      .then(all {
        assert(round.get("p1").get(1) == 1),
        assert(cachedProposal.get("p1").get(1) == "b1"),
        assert(msgsPropose.get(1).get(1).contains({
          src: "p1",
          height: 1,
          round: 1,
          proposal: "b1",
          validRound: NilRound,
        })),
        assert(CorrectFreshProposalMessagesCarryHeadSigma),
        assert(HeadSigmaSafety),
        unchangedAll,
      })
  }

  run timeoutWithoutValueLockNextFreshProposalResamplesTest = {
    Init
      .then(InsertProposal("p1"))
      .then(TimeoutProposePrevoteNil("p1"))
      .then(TimeoutPrevotePrecommitNil("p1"))
      .then(TimeoutPrecommitStartNextRound("p1"))
      .then(InsertProposal("p1"))
      .then(all {
        assert(round.get("p1").get(1) == 1),
        assert(lockedValue.get("p1").get(1) == NilSnapshot),
        assert(validValue.get("p1").get(1) == NilSnapshot),
        assert(cachedProposal.get("p1").get(1) == "b1"),
        assert(msgsPropose.get(1).get(1).contains({
          src: "p1",
          height: 1,
          round: 1,
          proposal: "b1",
          validRound: NilRound,
        })),
        assert(CorrectFreshProposalMessagesCarryHeadSigma),
        assert(HeadSigmaSafety),
        unchangedAll,
      })
  }
}

module CrosslinkHeightedHeadSigmaRoundModel {
  import CrosslinkHeightedHeadSigmaRoundTest(
    Corr = Set("p1", "p2", "p3"),
    Faulty = Set("p4"),
    VotingPower = Map("p1" -> 1, "p2" -> 1, "p3" -> 1, "p4" -> 1),
    QuorumVotingPower = 3,
    MaxBftHeight = 1,
    MaxRound = 1,
    Proposer = Map(
      1 -> Map(0 -> "p1", 1 -> "p1"),
    ),
    Stream = Map(
      1 -> Map(0 -> "a1", 1 -> "b1"),
    ),
    Snapshots = Set("g", "a1", "a2", "b1", "b2"),
    ResampleOnNilPrecommit = true,
    MaxPowHeight = 2,
    Sigma = 1,
    InitialFinalized = "g",
    HeightOf = Map(
      "g" -> 0,
      "a1" -> 1,
      "a2" -> 2,
      "b1" -> 1,
      "b2" -> 2,
    ),
    AncestorAt = Map(
      "g" -> Map(0 -> "g", 1 -> "None", 2 -> "None"),
      "a1" -> Map(0 -> "g", 1 -> "a1", 2 -> "None"),
      "a2" -> Map(0 -> "g", 1 -> "a1", 2 -> "a2"),
      "b1" -> Map(0 -> "g", 1 -> "b1", 2 -> "None"),
      "b2" -> Map(0 -> "g", 1 -> "b1", 2 -> "b2"),
    ),
    AncestorSnapshotAt = Map(
      "g" -> Map(0 -> "g", 1 -> "None", 2 -> "None"),
      "a1" -> Map(0 -> "g", 1 -> "a1", 2 -> "None"),
      "a2" -> Map(0 -> "g", 1 -> "a1", 2 -> "a2"),
      "b1" -> Map(0 -> "g", 1 -> "b1", 2 -> "None"),
      "b2" -> Map(0 -> "g", 1 -> "b1", 2 -> "b2"),
    ),
    HeadAt = Map(
      1 -> Map(0 -> "a2", 1 -> "b2"),
    ),
  ).*
}
