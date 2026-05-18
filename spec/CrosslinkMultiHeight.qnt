module CrosslinkMultiHeight {
  /*
   A first multi-height Crosslink finality model.

   Crosslink finality is not "finalize every PoW height". Each BFT height may
   finalize a later PoW snapshot, skipping intermediate PoW heights on the same
   branch. BFT heights themselves remain sequential: height h + 1 cannot decide
   before height h, and an already-decided BFT height cannot be decided again.

   This module is intentionally independent from the one-height Tenderlink round
   machine. It captures the cross-height finality obligations that the round
   machine must preserve once every BFT height has its own instance.
   */

  type Snapshot_t = str
  type Block_t = str
  type PowHeight_t = int
  type BftHeight_t = int

  const Snapshots: Set[Snapshot_t]
  const MaxPowHeight: PowHeight_t
  const MaxBftHeight: BftHeight_t
  const Sigma: int
  const InitialFinalized: Snapshot_t
  const HeightOf: Snapshot_t -> PowHeight_t
  const AncestorAt: Snapshot_t -> PowHeight_t -> Block_t

  assume initial_is_snapshot =
    Snapshots.contains(InitialFinalized)
  assume max_bft_height_is_positive =
    MaxBftHeight >= 1
  assume sigma_is_positive =
    Sigma >= 1

  pure val NilSnapshot = "None"
  pure val PowHeights = 0.to(MaxPowHeight)
  pure val DecisionHeights = 1.to(MaxBftHeight)
  pure val CursorHeights = 1.to(MaxBftHeight + 1)

  assume snapshot_heights_are_in_range =
    Snapshots.forall(v => PowHeights.contains(HeightOf.get(v)))

  var nextBftHeight: BftHeight_t
  var decision: BftHeight_t -> Snapshot_t
  var latestFinal: Snapshot_t
  var finalized: Set[Snapshot_t]
  var firedAction: str

  pure def IsSnapshot(v: Snapshot_t): bool =
    Snapshots.contains(v)

  pure def Height(v: Snapshot_t): PowHeight_t =
    HeightOf.get(v)

  pure def BlockAt(v: Snapshot_t, h: PowHeight_t): Block_t =
    AncestorAt.get(v).get(h)

  def Extends(newer: Snapshot_t, older: Snapshot_t): bool =
    IsSnapshot(newer) and
    IsSnapshot(older) and
    Height(newer) >= Height(older) and
    PowHeights.forall(h =>
      h > Height(older) or BlockAt(newer, h) == BlockAt(older, h)
    )

  def Agrees(a: Snapshot_t, b: Snapshot_t): bool =
    Extends(a, b) or Extends(b, a)

  def TailConfirms(tip: Snapshot_t, candidate: Snapshot_t): bool =
    IsSnapshot(tip) and
    IsSnapshot(candidate) and
    Height(tip) >= Height(candidate) + Sigma and
    BlockAt(tip, Height(candidate)) == BlockAt(candidate, Height(candidate))

  def ValidFinalityCandidate(candidate: Snapshot_t, tip: Snapshot_t): bool =
    Extends(candidate, latestFinal) and
    Height(candidate) > Height(latestFinal) and
    TailConfirms(tip, candidate)

  action Init = all {
    nextBftHeight' = 1,
    decision' = DecisionHeights.mapBy(h => NilSnapshot),
    latestFinal' = InitialFinalized,
    finalized' = Set(InitialFinalized),
    firedAction' = "Init",
  }

  action DecideAt(
    h: BftHeight_t,
    candidate: Snapshot_t,
    tip: Snapshot_t,
  ): bool =
    all {
      h == nextBftHeight,
      h.in(DecisionHeights),
      decision.get(h) == NilSnapshot,
      ValidFinalityCandidate(candidate, tip),
      decision' = decision.set(h, candidate),
      nextBftHeight' = h + 1,
      latestFinal' = candidate,
      finalized' = finalized.union(Set(candidate)),
      firedAction' = "DecideAt",
    }

  action DecideNext(candidate: Snapshot_t, tip: Snapshot_t): bool =
    DecideAt(nextBftHeight, candidate, tip)

  action Stutter = all {
    nextBftHeight' = nextBftHeight,
    decision' = decision,
    latestFinal' = latestFinal,
    finalized' = finalized,
    firedAction' = "Stutter",
  }

  action Next =
    any {
      nondet candidate = oneOf(Snapshots)
      nondet tip = oneOf(Snapshots)
      DecideNext(candidate, tip),
      Stutter,
    }

  def Decided(h: BftHeight_t): bool =
    DecisionHeights.contains(h) and decision.get(h) != NilSnapshot

  val DecisionsAreSnapshots =
    DecisionHeights.forall(h =>
      decision.get(h) == NilSnapshot or IsSnapshot(decision.get(h))
    )

  val DecisionCursorIsSequential =
    CursorHeights.contains(nextBftHeight) and
    DecisionHeights.forall(h =>
      if (h < nextBftHeight) {
        Decided(h)
      } else {
        decision.get(h) == NilSnapshot
      }
    )

  val DecisionsRespectFinalizedPrefix =
    DecisionHeights.forall(h1 =>
      DecisionHeights.forall(h2 =>
        not(Decided(h1) and Decided(h2) and h1 < h2) or
        Extends(decision.get(h2), decision.get(h1))
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

  val LatestFinalMatchesDecisionCursor =
    if (nextBftHeight == 1) {
      latestFinal == InitialFinalized
    } else {
      DecisionHeights.contains(nextBftHeight - 1) and
      decision.get(nextBftHeight - 1) == latestFinal
    }

  val Safety =
    DecisionsAreSnapshots and
    DecisionCursorIsSequential and
    DecisionsRespectFinalizedPrefix and
    FinalizedPrefixLinear and
    LatestFinalExtendsAllFinalized and
    InitialFinalizedRemainsFinalized and
    LatestFinalMatchesDecisionCursor
}

module CrosslinkMultiHeightTest {
  import CrosslinkMultiHeight.* from "./CrosslinkMultiHeight"
  export CrosslinkMultiHeight.*

  action unchangedAll = all {
    nextBftHeight' = nextBftHeight,
    decision' = decision,
    latestFinal' = latestFinal,
    finalized' = finalized,
    firedAction' = firedAction,
  }

  run canSkipPowHeightsAtOneBftHeightTest = {
    Init
      .then(DecideAt(1, "a2", "a3"))
      .then(all {
        assert(nextBftHeight == 2),
        assert(decision.get(1) == "a2"),
        assert(latestFinal == "a2"),
        assert(Safety),
        unchangedAll,
      })
  }

  run consecutiveBftHeightsExtendFinalizedPrefixTest = {
    Init
      .then(DecideAt(1, "a1", "a2"))
      .then(DecideAt(2, "a2", "a3"))
      .then(all {
        assert(nextBftHeight == 3),
        assert(decision.get(1) == "a1"),
        assert(decision.get(2) == "a2"),
        assert(FinalizedPrefixLinear),
        assert(Safety),
        unchangedAll,
      })
  }

  run rejectsForkAfterEarlierBftHeightTest = {
    Init
      .then(DecideAt(1, "a1", "a2"))
      .then(DecideAt(2, "b2", "b3"))
      .fail()
  }

  run rejectsSkippingBftHeightTest = {
    Init
      .then(DecideAt(2, "a1", "a2"))
      .fail()
  }

  run rejectsSecondDecisionForSameBftHeightTest = {
    Init
      .then(DecideAt(1, "a1", "a2"))
      .then(DecideAt(1, "a2", "a3"))
      .fail()
  }

  run rejectsUnconfirmedCandidateTest = {
    Init
      .then(DecideAt(1, "a2", "a2"))
      .fail()
  }
}

module CrosslinkMultiHeightModel {
  import CrosslinkMultiHeightTest(
    Snapshots = Set("g", "a1", "a2", "a3", "b1", "b2", "b3"),
    MaxPowHeight = 3,
    MaxBftHeight = 2,
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
