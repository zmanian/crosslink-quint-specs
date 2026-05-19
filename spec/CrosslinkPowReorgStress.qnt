module CrosslinkPowReorgStress {
  /*
   Bounded PoW churn and long-reorg stress model.

   This is not a probabilistic PoW model. It is the conservative companion to
   one: within a round, the locally observed PoW head can change between the
   prevote and precommit phases. That change may be an ordinary same-branch
   block arrival or a long reorg. Nil-precommit resampling treats either as a
   burned round and only decides once the head-sigma candidate is stable across
   the round.
   */

  type Snapshot_t = str
  type Block_t = str
  type Height_t = int
  type Round_t = int

  const Snapshots: Set[Snapshot_t]
  const MaxHeight: Height_t
  const MaxRound: Round_t
  const Sigma: int
  const InitialFinalized: Snapshot_t
  const HeightOf: Snapshot_t -> Height_t
  const AncestorAt: Snapshot_t -> Height_t -> Block_t
  const AncestorSnapshotAt: Snapshot_t -> Height_t -> Snapshot_t
  const HeadAtPrevote: Round_t -> Snapshot_t
  const HeadAtPrecommit: Round_t -> Snapshot_t
  const CommonAncestorHeightAtRound: Round_t -> Height_t

  pure val NilSnapshot = "None"
  pure val Heights = 0.to(MaxHeight)
  pure val Rounds = 0.to(MaxRound)
  pure val CursorRounds = 0.to(MaxRound + 1)

  assume initial_finalized_is_snapshot =
    Snapshots.contains(InitialFinalized)
  assume sigma_is_positive =
    Sigma >= 1
  assume nil_is_not_snapshot =
    not(Snapshots.contains(NilSnapshot))
  assume snapshot_heights_are_in_range =
    Snapshots.forall(v => Heights.contains(HeightOf.get(v)))
  assume round_heads_are_snapshots =
    Rounds.forall(r =>
      Snapshots.contains(HeadAtPrevote.get(r)) and
      Snapshots.contains(HeadAtPrecommit.get(r))
    )
  assume common_ancestors_are_in_range =
    Rounds.forall(r => Heights.contains(CommonAncestorHeightAtRound.get(r)))

  var round: Round_t
  var aborted: Set[Round_t]
  var decided: bool
  var decision: Snapshot_t
  var firedAction: str

  pure def IsSnapshot(v: Snapshot_t): bool =
    Snapshots.contains(v)

  pure def Height(v: Snapshot_t): Height_t =
    HeightOf.get(v)

  pure def CandidateHeight(tip: Snapshot_t): Height_t =
    if (Height(tip) >= Sigma) {
      Height(tip) - Sigma
    } else {
      0
    }

  pure def BlockAt(v: Snapshot_t, h: Height_t): Block_t =
    AncestorAt.get(v).get(h)

  pure def AncestorSnapshot(tip: Snapshot_t, h: Height_t): Snapshot_t =
    AncestorSnapshotAt.get(tip).get(h)

  def Extends(newer: Snapshot_t, older: Snapshot_t): bool =
    IsSnapshot(newer) and
    IsSnapshot(older) and
    Height(newer) >= Height(older) and
    Heights.forall(h =>
      h > Height(older) or BlockAt(newer, h) == BlockAt(older, h)
    )

  def HeadHasSigmaTail(tip: Snapshot_t): bool =
    IsSnapshot(tip) and Height(tip) >= Sigma

  def HeadSigmaCandidate(tip: Snapshot_t): Snapshot_t =
    AncestorSnapshot(tip, CandidateHeight(tip))

  def HeadSigmaAtPrevote(r: Round_t): Snapshot_t =
    HeadSigmaCandidate(HeadAtPrevote.get(r))

  def HeadSigmaAtPrecommit(r: Round_t): Snapshot_t =
    HeadSigmaCandidate(HeadAtPrecommit.get(r))

  def TailConfirms(tip: Snapshot_t, candidate: Snapshot_t): bool =
    HeadHasSigmaTail(tip) and
    IsSnapshot(candidate) and
    Height(tip) >= Height(candidate) + Sigma and
    BlockAt(tip, Height(candidate)) == BlockAt(candidate, Height(candidate))

  def HeadSigmaCandidateValidAtPrecommit(r: Round_t): bool = {
    val tip = HeadAtPrecommit.get(r)
    val candidate = HeadSigmaAtPrecommit(r)
    Rounds.contains(r) and
    Extends(candidate, InitialFinalized) and
    TailConfirms(tip, candidate)
  }

  def StreamChurnWithinRound(r: Round_t): bool =
    Rounds.contains(r) and
    HeadSigmaAtPrevote(r) != HeadSigmaAtPrecommit(r)

  def SameBranchBlockArrivalChurn(r: Round_t): bool =
    Rounds.contains(r) and
    Extends(HeadAtPrecommit.get(r), HeadAtPrevote.get(r)) and
    StreamChurnWithinRound(r)

  def ReorgDepthAtRound(r: Round_t): int =
    Height(HeadAtPrevote.get(r)) - CommonAncestorHeightAtRound.get(r)

  def LongReorgWithinRound(r: Round_t): bool =
    Rounds.contains(r) and
    not(Extends(HeadAtPrecommit.get(r), HeadAtPrevote.get(r))) and
    ReorgDepthAtRound(r) > Sigma

  def BaselineWouldHaltOnChurn(r: Round_t): bool =
    StreamChurnWithinRound(r)

  pure def ChurnExposureProxy(
    validatorCount: int,
    gstTicks: int,
    roundsObserved: int,
  ): int =
    validatorCount * gstTicks * roundsObserved

  action Init = all {
    round' = 0,
    aborted' = Set(),
    decided' = false,
    decision' = NilSnapshot,
    firedAction' = "Init",
  }

  action ProcessRound: bool = {
    val r = round
    all {
      not(decided),
      r.in(Rounds),
      HeadHasSigmaTail(HeadAtPrevote.get(r)),
      HeadHasSigmaTail(HeadAtPrecommit.get(r)),
      if (StreamChurnWithinRound(r)) {
        all {
          round' = r + 1,
          aborted' = aborted.union(Set(r)),
          decided' = false,
          decision' = NilSnapshot,
          firedAction' = "AbortRoundForChurn",
        }
      } else {
        all {
          HeadSigmaCandidateValidAtPrecommit(r),
          round' = r,
          aborted' = aborted,
          decided' = true,
          decision' = HeadSigmaAtPrecommit(r),
          firedAction' = "DecideStableHeadSigma",
        }
      },
    }
  }

  action Stutter = all {
    round' = round,
    aborted' = aborted,
    decided' = decided,
    decision' = decision,
    firedAction' = "Stutter",
  }

  action Next =
    any {
      ProcessRound,
      Stutter,
    }

  val AbortedRoundsHadStreamChurn =
    aborted.forall(r => StreamChurnWithinRound(r))

  val CursorPassedOnlyAbortedChurnRounds =
    Rounds.forall(r =>
      if (r < round) {
        aborted.contains(r) and StreamChurnWithinRound(r)
      } else {
        true
      }
    )

  val DecisionOnlyOnStableHeadSigma =
    not(decided) or (
      Rounds.contains(round) and
      not(StreamChurnWithinRound(round)) and
      decision == HeadSigmaAtPrecommit(round) and
      HeadSigmaCandidateValidAtPrecommit(round)
    )

  val LongReorgsForceStreamChurn =
    Rounds.forall(r =>
      LongReorgWithinRound(r) implies StreamChurnWithinRound(r)
    )

  val Safety =
    CursorRounds.contains(round) and
    AbortedRoundsHadStreamChurn and
    CursorPassedOnlyAbortedChurnRounds and
    DecisionOnlyOnStableHeadSigma and
    LongReorgsForceStreamChurn
}

module CrosslinkPowReorgStressTest {
  import CrosslinkPowReorgStress.* from "./CrosslinkPowReorgStress"
  export CrosslinkPowReorgStress.*

  action unchangedAll = all {
    round' = round,
    aborted' = aborted,
    decided' = decided,
    decision' = decision,
    firedAction' = firedAction,
  }

  run longReorgBetweenPrevoteAndPrecommitAbortsRoundTest = {
    Init
      .then(ProcessRound)
      .then(all {
        assert(LongReorgWithinRound(0)),
        assert(StreamChurnWithinRound(0)),
        assert(aborted.contains(0)),
        assert(round == 1),
        assert(not(decided)),
        assert(Safety),
        unchangedAll,
      })
  }

  run sameBranchBlockArrivalCanStillChurnTest = {
    Init
      .then(ProcessRound)
      .then(ProcessRound)
      .then(all {
        assert(SameBranchBlockArrivalChurn(1)),
        assert(BaselineWouldHaltOnChurn(1)),
        assert(aborted.contains(1)),
        assert(round == 2),
        assert(not(decided)),
        assert(Safety),
        unchangedAll,
      })
  }

  run resamplingDecidesAfterStableHeadSigmaWindowTest = {
    Init
      .then(ProcessRound)
      .then(ProcessRound)
      .then(ProcessRound)
      .then(all {
        assert(not(StreamChurnWithinRound(2))),
        assert(decided),
        assert(decision == "b3"),
        assert(Safety),
        unchangedAll,
      })
  }

  run largerValidatorSetRaisesChurnExposureProxyTest = {
    Init
      .then(all {
        assert(ChurnExposureProxy(20, 3, 2) > ChurnExposureProxy(10, 3, 2)),
        unchangedAll,
      })
  }
}

module CrosslinkPowReorgStressModel {
  import CrosslinkPowReorgStressTest(
    Snapshots = Set("g", "a1", "a2", "a3", "a4", "b1", "b2", "b3", "b4", "b5"),
    MaxHeight = 5,
    MaxRound = 3,
    Sigma = 2,
    InitialFinalized = "g",
    HeightOf = Map(
      "g" -> 0,
      "a1" -> 1,
      "a2" -> 2,
      "a3" -> 3,
      "a4" -> 4,
      "b1" -> 1,
      "b2" -> 2,
      "b3" -> 3,
      "b4" -> 4,
      "b5" -> 5,
    ),
    AncestorAt = Map(
      "g" -> Map(0 -> "g", 1 -> "None", 2 -> "None", 3 -> "None", 4 -> "None", 5 -> "None"),
      "a1" -> Map(0 -> "g", 1 -> "a1", 2 -> "None", 3 -> "None", 4 -> "None", 5 -> "None"),
      "a2" -> Map(0 -> "g", 1 -> "a1", 2 -> "a2", 3 -> "None", 4 -> "None", 5 -> "None"),
      "a3" -> Map(0 -> "g", 1 -> "a1", 2 -> "a2", 3 -> "a3", 4 -> "None", 5 -> "None"),
      "a4" -> Map(0 -> "g", 1 -> "a1", 2 -> "a2", 3 -> "a3", 4 -> "a4", 5 -> "None"),
      "b1" -> Map(0 -> "g", 1 -> "b1", 2 -> "None", 3 -> "None", 4 -> "None", 5 -> "None"),
      "b2" -> Map(0 -> "g", 1 -> "b1", 2 -> "b2", 3 -> "None", 4 -> "None", 5 -> "None"),
      "b3" -> Map(0 -> "g", 1 -> "b1", 2 -> "b2", 3 -> "b3", 4 -> "None", 5 -> "None"),
      "b4" -> Map(0 -> "g", 1 -> "b1", 2 -> "b2", 3 -> "b3", 4 -> "b4", 5 -> "None"),
      "b5" -> Map(0 -> "g", 1 -> "b1", 2 -> "b2", 3 -> "b3", 4 -> "b4", 5 -> "b5"),
    ),
    AncestorSnapshotAt = Map(
      "g" -> Map(0 -> "g", 1 -> "None", 2 -> "None", 3 -> "None", 4 -> "None", 5 -> "None"),
      "a1" -> Map(0 -> "g", 1 -> "a1", 2 -> "None", 3 -> "None", 4 -> "None", 5 -> "None"),
      "a2" -> Map(0 -> "g", 1 -> "a1", 2 -> "a2", 3 -> "None", 4 -> "None", 5 -> "None"),
      "a3" -> Map(0 -> "g", 1 -> "a1", 2 -> "a2", 3 -> "a3", 4 -> "None", 5 -> "None"),
      "a4" -> Map(0 -> "g", 1 -> "a1", 2 -> "a2", 3 -> "a3", 4 -> "a4", 5 -> "None"),
      "b1" -> Map(0 -> "g", 1 -> "b1", 2 -> "None", 3 -> "None", 4 -> "None", 5 -> "None"),
      "b2" -> Map(0 -> "g", 1 -> "b1", 2 -> "b2", 3 -> "None", 4 -> "None", 5 -> "None"),
      "b3" -> Map(0 -> "g", 1 -> "b1", 2 -> "b2", 3 -> "b3", 4 -> "None", 5 -> "None"),
      "b4" -> Map(0 -> "g", 1 -> "b1", 2 -> "b2", 3 -> "b3", 4 -> "b4", 5 -> "None"),
      "b5" -> Map(0 -> "g", 1 -> "b1", 2 -> "b2", 3 -> "b3", 4 -> "b4", 5 -> "b5"),
    ),
    HeadAtPrevote = Map(
      0 -> "a4",
      1 -> "b4",
      2 -> "b5",
      3 -> "b5",
    ),
    HeadAtPrecommit = Map(
      0 -> "b4",
      1 -> "b5",
      2 -> "b5",
      3 -> "b5",
    ),
    CommonAncestorHeightAtRound = Map(
      0 -> 0,
      1 -> 4,
      2 -> 5,
      3 -> 5,
    ),
  ).*
}
