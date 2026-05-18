module CrosslinkHeightedFinality {
  /*
   Composition of the height-indexed round machine with Crosslink finality.

   CrosslinkHeightedRound.qnt gives each validator a BFT-height cursor and
   per-height Tenderlink state. This module adds a finality cursor over those
   BFT heights: height h can only advance Crosslink finality after some correct
   validator has locally decided h, and the decided snapshot must extend the
   already-finalized PoW prefix.
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

  assume initial_finalized_is_snapshot =
    Snapshots.contains(InitialFinalized)
  assume sigma_is_positive =
    Sigma >= 1

  pure val PowHeights = 0.to(MaxPowHeight)

  assume snapshot_pow_heights_are_in_range =
    Snapshots.forall(v => PowHeights.contains(HeightOf.get(v)))

  var nextFinalityHeight: Height_t
  var finalityDecision: Height_t -> Snapshot_t
  var latestFinal: Snapshot_t
  var finalized: Set[Snapshot_t]
  var finalityAction: str

  pure def PowHeight(v: Snapshot_t): PowHeight_t =
    HeightOf.get(v)

  pure def BlockAt(v: Snapshot_t, h: PowHeight_t): Block_t =
    AncestorAt.get(v).get(h)

  def Extends(newer: Snapshot_t, older: Snapshot_t): bool =
    IsSnapshot(newer) and
    IsSnapshot(older) and
    PowHeight(newer) >= PowHeight(older) and
    PowHeights.forall(h =>
      h > PowHeight(older) or BlockAt(newer, h) == BlockAt(older, h)
    )

  def Agrees(a: Snapshot_t, b: Snapshot_t): bool =
    Extends(a, b) or Extends(b, a)

  def TailConfirms(tip: Snapshot_t, candidate: Snapshot_t): bool =
    IsSnapshot(tip) and
    IsSnapshot(candidate) and
    PowHeight(tip) >= PowHeight(candidate) + Sigma and
    BlockAt(tip, PowHeight(candidate)) == BlockAt(candidate, PowHeight(candidate))

  def ValidFinalityCandidate(candidate: Snapshot_t, tip: Snapshot_t): bool =
    Extends(candidate, latestFinal) and
    PowHeight(candidate) > PowHeight(latestFinal) and
    TailConfirms(tip, candidate)

  action ComposedInit = all {
    Init,
    nextFinalityHeight' = 1,
    finalityDecision' = Heights.mapBy(_ => NilSnapshot),
    latestFinal' = InitialFinalized,
    finalized' = Set(InitialFinalized),
    finalityAction' = "ComposedInit",
  }

  action FinalityUnchanged = all {
    nextFinalityHeight' = nextFinalityHeight,
    finalityDecision' = finalityDecision,
    latestFinal' = latestFinal,
    finalized' = finalized,
    finalityAction' = finalityAction,
  }

  action ProtocolUnchanged = all {
    KeepValidatorState,
    KeepMessages,
    firedAction' = firedAction,
  }

  action Propose(p: Proc_t): bool =
    all { InsertProposal(p), FinalityUnchanged }

  action PrevoteValue(p: Proc_t, v: Snapshot_t): bool =
    all { Prevote(p, v), FinalityUnchanged }

  action PrecommitValueAt(p: Proc_t, v: Snapshot_t): bool =
    all { PrecommitValue(p, v), FinalityUnchanged }

  action PrecommitNilForStreamChange(p: Proc_t): bool =
    all { PrecommitNilOnStreamChange(p), FinalityUnchanged }

  action AdvanceRound(p: Proc_t): bool =
    all { AdvanceAfterPrecommitQuorum(p), FinalityUnchanged }

  action DecideValue(p: Proc_t, v: Snapshot_t): bool =
    all { Decide(p, v), FinalityUnchanged }

  action DeliverProposalToAll(
    from: Proc_t,
    h: Height_t,
    r: Round_t,
    v: Snapshot_t,
    vr: Round_t,
  ): bool = {
    val msg = { src: from, height: h, round: r, proposal: v, validRound: vr }
    all {
      h.in(Heights),
      r.in(Rounds),
      vr.in(ProposalValidRounds),
      msgsPropose.get(h).get(r).contains(msg),
      seenPropose' =
        Corr.mapBy(dst =>
          seenPropose.get(dst).setBy(h, byRound =>
            byRound.setBy(r, old => old.union(Set(msg)))
          )
        ),
      seenPrevote' = seenPrevote,
      seenPrecommit' = seenPrecommit,
      msgsPropose' = msgsPropose,
      msgsPrevote' = msgsPrevote,
      msgsPrecommit' = msgsPrecommit,
      KeepValidatorState,
      firedAction' = "DeliverProposalToAll",
      FinalityUnchanged,
    }
  }

  action DeliverPrevoteQuorumToAll(
    h: Height_t,
    r: Round_t,
    v: Snapshot_t,
    signers: Set[Proc_t],
  ): bool =
    all {
      h.in(Heights),
      r.in(Rounds),
      VoteValues.contains(v),
      signers.forall(s => Corr.union(Faulty).contains(s)),
      signers.forall(s => msgsPrevote.get(h).get(r).contains({
        src: s,
        height: h,
        round: r,
        id: v,
      })),
      seenPropose' = seenPropose,
      seenPrevote' =
        Corr.mapBy(dst =>
          seenPrevote.get(dst).setBy(h, byRound =>
            byRound.setBy(r, old => old.union(signers.map(s => {
              src: s,
              height: h,
              round: r,
              id: v,
            })))
          )
        ),
      seenPrecommit' = seenPrecommit,
      msgsPropose' = msgsPropose,
      msgsPrevote' = msgsPrevote,
      msgsPrecommit' = msgsPrecommit,
      KeepValidatorState,
      firedAction' = "DeliverPrevoteQuorumToAll",
      FinalityUnchanged,
    }

  action DeliverPrecommitQuorumToAll(
    h: Height_t,
    r: Round_t,
    v: Snapshot_t,
    signers: Set[Proc_t],
  ): bool =
    all {
      h.in(Heights),
      r.in(Rounds),
      VoteValues.contains(v),
      signers.forall(s => Corr.union(Faulty).contains(s)),
      signers.forall(s => msgsPrecommit.get(h).get(r).contains({
        src: s,
        height: h,
        round: r,
        id: v,
      })),
      seenPropose' = seenPropose,
      seenPrevote' = seenPrevote,
      seenPrecommit' =
        Corr.mapBy(dst =>
          seenPrecommit.get(dst).setBy(h, byRound =>
            byRound.setBy(r, old => old.union(signers.map(s => {
              src: s,
              height: h,
              round: r,
              id: v,
            })))
          )
        ),
      msgsPropose' = msgsPropose,
      msgsPrevote' = msgsPrevote,
      msgsPrecommit' = msgsPrecommit,
      KeepValidatorState,
      firedAction' = "DeliverPrecommitQuorumToAll",
      FinalityUnchanged,
    }

  action FinalizeNextDecided(
    p: Proc_t,
    candidate: Snapshot_t,
    tip: Snapshot_t,
  ): bool = {
    val h = nextFinalityHeight
    all {
      p.in(Corr),
      h.in(Heights),
      finalityDecision.get(h) == NilSnapshot,
      decision.get(p).get(h) == candidate,
      ValidFinalityCandidate(candidate, tip),
      ProtocolUnchanged,
      nextFinalityHeight' = h + 1,
      finalityDecision' = finalityDecision.set(h, candidate),
      latestFinal' = candidate,
      finalized' = finalized.union(Set(candidate)),
      finalityAction' = "FinalizeNextDecided",
    }
  }

  action ProtocolNext =
    all { Next, FinalityUnchanged }

  action ComposedStutter = all {
    ProtocolUnchanged,
    FinalityUnchanged,
  }

  action ComposedNext =
    any {
      ProtocolNext,
      nondet p = oneOf(Corr)
      nondet candidate = oneOf(Snapshots)
      nondet tip = oneOf(Snapshots)
      FinalizeNextDecided(p, candidate, tip),
      ComposedStutter,
    }

  def FinalityHeightDecided(h: Height_t): bool =
    Heights.contains(h) and finalityDecision.get(h) != NilSnapshot

  val FinalityCursorSequential =
    CursorHeights.contains(nextFinalityHeight) and
    Heights.forall(h =>
      if (h < nextFinalityHeight) {
        FinalityHeightDecided(h)
      } else {
        finalityDecision.get(h) == NilSnapshot
      }
    )

  val FinalityDecisionsWereLocallyDecided =
    Heights.forall(h =>
      finalityDecision.get(h) == NilSnapshot or
      Corr.exists(p => decision.get(p).get(h) == finalityDecision.get(h))
    )

  val FinalityDecisionsRespectFinalizedPrefix =
    Heights.forall(h1 =>
      Heights.forall(h2 =>
        not(FinalityHeightDecided(h1) and FinalityHeightDecided(h2) and h1 < h2) or
        Extends(finalityDecision.get(h2), finalityDecision.get(h1))
      )
    )

  val FinalizedPrefixLinear =
    tuples(finalized, finalized).forall(((a, b)) =>
      Agrees(a, b)
    )

  val LatestFinalExtendsAllFinalized =
    finalized.forall(v => Extends(latestFinal, v))

  val InitialFinalizedRemainsFinalized =
    finalized.contains(InitialFinalized)

  val LatestFinalMatchesFinalityCursor =
    if (nextFinalityHeight == 1) {
      latestFinal == InitialFinalized
    } else {
      Heights.contains(nextFinalityHeight - 1) and
      finalityDecision.get(nextFinalityHeight - 1) == latestFinal
    }

  val FinalitySafety =
    FinalityCursorSequential and
    FinalityDecisionsWereLocallyDecided and
    FinalityDecisionsRespectFinalizedPrefix and
    FinalizedPrefixLinear and
    LatestFinalExtendsAllFinalized and
    InitialFinalizedRemainsFinalized and
    LatestFinalMatchesFinalityCursor

  val ComposedSafety =
    Safety and FinalitySafety
}

module CrosslinkHeightedFinalityTest {
  import CrosslinkHeightedFinality.* from "./CrosslinkHeightedFinality"
  export CrosslinkHeightedFinality.*

  action unchangedAll = all {
    ProtocolUnchanged,
    nextFinalityHeight' = nextFinalityHeight,
    finalityDecision' = finalityDecision,
    latestFinal' = latestFinal,
    finalized' = finalized,
    finalityAction' = finalityAction,
  }

  run resamplingAtHeightFinalizesFreshCandidateTest = {
    ComposedInit
      .then(Propose("p1"))
      .then(DeliverProposalToAll("p1", 1, 0, "a1", NilRound))
      .then(PrevoteValue("p1", "a1"))
      .then(PrevoteValue("p2", "a1"))
      .then(PrevoteValue("p3", "a1"))
      .then(DeliverPrevoteQuorumToAll(1, 0, "a1", Corr))
      .then(PrecommitNilForStreamChange("p1"))
      .then(PrecommitNilForStreamChange("p2"))
      .then(PrecommitNilForStreamChange("p3"))
      .then(DeliverPrecommitQuorumToAll(1, 0, NilSnapshot, Corr))
      .then(AdvanceRound("p1"))
      .then(AdvanceRound("p2"))
      .then(AdvanceRound("p3"))
      .then(Propose("p2"))
      .then(DeliverProposalToAll("p2", 1, 1, "a2", NilRound))
      .then(PrevoteValue("p1", "a2"))
      .then(PrevoteValue("p2", "a2"))
      .then(PrevoteValue("p3", "a2"))
      .then(DeliverPrevoteQuorumToAll(1, 1, "a2", Corr))
      .then(PrecommitValueAt("p1", "a2"))
      .then(PrecommitValueAt("p2", "a2"))
      .then(PrecommitValueAt("p3", "a2"))
      .then(DeliverPrecommitQuorumToAll(1, 1, "a2", Corr))
      .then(DecideValue("p1", "a2"))
      .then(FinalizeNextDecided("p1", "a2", "a3"))
      .then(all {
        assert(nextFinalityHeight == 2),
        assert(latestFinal == "a2"),
        assert(finalityDecision.get(1) == "a2"),
        assert(ComposedSafety),
        unchangedAll,
      })
  }

  run rejectsUndecidedHeightFinalizationTest = {
    ComposedInit
      .then(FinalizeNextDecided("p1", "a1", "a2"))
      .fail()
  }

  run rejectsForkFinalityAfterPriorHeightTest = {
    ComposedInit
      .then(Propose("p1"))
      .then(DeliverProposalToAll("p1", 1, 0, "a1", NilRound))
      .then(PrevoteValue("p1", "a1"))
      .then(PrevoteValue("p2", "a1"))
      .then(PrevoteValue("p3", "a1"))
      .then(DeliverPrevoteQuorumToAll(1, 0, "a1", Corr))
      .then(PrecommitValueAt("p1", "a1"))
      .then(PrecommitValueAt("p2", "a1"))
      .then(PrecommitValueAt("p3", "a1"))
      .then(DeliverPrecommitQuorumToAll(1, 0, "a1", Corr))
      .then(DecideValue("p1", "a1"))
      .then(DecideValue("p2", "a1"))
      .then(DecideValue("p3", "a1"))
      .then(FinalizeNextDecided("p1", "a1", "a2"))
      .then(Propose("p1"))
      .then(DeliverProposalToAll("p1", 2, 0, "b2", NilRound))
      .then(PrevoteValue("p1", "b2"))
      .then(PrevoteValue("p2", "b2"))
      .then(PrevoteValue("p3", "b2"))
      .then(DeliverPrevoteQuorumToAll(2, 0, "b2", Corr))
      .then(PrecommitValueAt("p1", "b2"))
      .then(PrecommitValueAt("p2", "b2"))
      .then(PrecommitValueAt("p3", "b2"))
      .then(DeliverPrecommitQuorumToAll(2, 0, "b2", Corr))
      .then(DecideValue("p1", "b2"))
      .then(FinalizeNextDecided("p1", "b2", "b3"))
      .fail()
  }
}

module CrosslinkHeightedFinalityModel {
  import CrosslinkHeightedFinalityTest(
    Corr = Set("p1", "p2", "p3"),
    Faulty = Set("p4"),
    VotingPower = Map("p1" -> 1, "p2" -> 1, "p3" -> 1, "p4" -> 1),
    QuorumVotingPower = 3,
    MaxBftHeight = 2,
    MaxRound = 1,
    Proposer = Map(
      1 -> Map(0 -> "p1", 1 -> "p2"),
      2 -> Map(0 -> "p1", 1 -> "p2"),
    ),
    Stream = Map(
      1 -> Map(0 -> "a1", 1 -> "a2"),
      2 -> Map(0 -> "b2", 1 -> "b2"),
    ),
    Snapshots = Set("g", "a1", "a2", "a3", "b1", "b2", "b3"),
    ResampleOnNilPrecommit = true,
    MaxPowHeight = 3,
    Sigma = 1,
    InitialFinalized = "g",
    HeightOf = Map(
      "g" -> 0,
      "a1" -> 1,
      "a2" -> 2,
      "a3" -> 3,
      "b1" -> 1,
      "b2" -> 2,
      "b3" -> 3,
    ),
    AncestorAt = Map(
      "g" -> Map(0 -> "g", 1 -> "None", 2 -> "None", 3 -> "None"),
      "a1" -> Map(0 -> "g", 1 -> "a1", 2 -> "None", 3 -> "None"),
      "a2" -> Map(0 -> "g", 1 -> "a1", 2 -> "a2", 3 -> "None"),
      "a3" -> Map(0 -> "g", 1 -> "a1", 2 -> "a2", 3 -> "a3"),
      "b1" -> Map(0 -> "g", 1 -> "b1", 2 -> "None", 3 -> "None"),
      "b2" -> Map(0 -> "g", 1 -> "b1", 2 -> "b2", 3 -> "None"),
      "b3" -> Map(0 -> "g", 1 -> "b1", 2 -> "b2", 3 -> "b3"),
    ),
  ).*
}
