module CrosslinkHeadSigmaSampling {
  /*
   Concrete head-sigma sampling for Crosslink proposal streams.

   The main round-machine models use Stream(round) as an abstract input. This
   module makes the intended source explicit: for a locally observed PoW head,
   the proposal candidate is the ancestor at height headHeight - Sigma.
   */

  type Snapshot_t = str
  type Block_t = str
  type Height_t = int
  type Round_t = int

  type Proposal_t = {
    tip: Snapshot_t,
    candidate: Snapshot_t,
    declaredHeight: Height_t,
  }

  const Snapshots: Set[Snapshot_t]
  const MaxHeight: Height_t
  const MaxRound: Round_t
  const Sigma: int
  const InitialFinalized: Snapshot_t
  const HeightOf: Snapshot_t -> Height_t
  const AncestorAt: Snapshot_t -> Height_t -> Block_t
  const AncestorSnapshotAt: Snapshot_t -> Height_t -> Snapshot_t
  const HeadAtRound: Round_t -> Snapshot_t

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
    Rounds.forall(r => Snapshots.contains(HeadAtRound.get(r)))

  var nextRound: Round_t
  var sampled: Round_t -> Snapshot_t
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

  def Agrees(a: Snapshot_t, b: Snapshot_t): bool =
    Extends(a, b) or Extends(b, a)

  def HeadHasSigmaTail(tip: Snapshot_t): bool =
    IsSnapshot(tip) and Height(tip) >= Sigma

  def HeadSigmaCandidate(tip: Snapshot_t): Snapshot_t =
    AncestorSnapshot(tip, CandidateHeight(tip))

  def TailConfirms(tip: Snapshot_t, candidate: Snapshot_t): bool =
    HeadHasSigmaTail(tip) and
    IsSnapshot(candidate) and
    Height(tip) >= Height(candidate) + Sigma and
    BlockAt(tip, Height(candidate)) == BlockAt(candidate, Height(candidate))

  def HeadSigmaAtRound(r: Round_t): Snapshot_t =
    HeadSigmaCandidate(HeadAtRound.get(r))

  def SampleChangedAfter(r: Round_t): bool =
    (r + 1).in(Rounds) and HeadSigmaAtRound(r + 1) != HeadSigmaAtRound(r)

  def HeadSigmaCandidateValid(r: Round_t): bool = {
    val tip = HeadAtRound.get(r)
    val candidate = HeadSigmaAtRound(r)
    Rounds.contains(r) and
    Extends(candidate, InitialFinalized) and
    TailConfirms(tip, candidate)
  }

  def ProposalValidAgainstFinalized(
    proposal: Proposal_t,
    finalizedPrefix: Snapshot_t,
  ): bool =
    IsSnapshot(proposal.tip) and
    IsSnapshot(proposal.candidate) and
    proposal.declaredHeight == Height(proposal.candidate) and
    proposal.candidate == HeadSigmaCandidate(proposal.tip) and
    Extends(proposal.candidate, finalizedPrefix) and
    TailConfirms(proposal.tip, proposal.candidate)

  def ProposalValid(proposal: Proposal_t): bool =
    ProposalValidAgainstFinalized(proposal, InitialFinalized)

  action Init = all {
    nextRound' = 0,
    sampled' = Rounds.mapBy(_ => NilSnapshot),
    firedAction' = "Init",
  }

  action SampleCurrentRound: bool = {
    val r = nextRound
    val tip = HeadAtRound.get(r)
    all {
      r.in(Rounds),
      sampled.get(r) == NilSnapshot,
      HeadHasSigmaTail(tip),
      sampled' = sampled.set(r, HeadSigmaCandidate(tip)),
      nextRound' = r + 1,
      firedAction' = "SampleCurrentRound",
    }
  }

  action Stutter = all {
    nextRound' = nextRound,
    sampled' = sampled,
    firedAction' = "Stutter",
  }

  action Next =
    any {
      SampleCurrentRound,
      Stutter,
    }

  def Sampled(r: Round_t): bool =
    Rounds.contains(r) and sampled.get(r) != NilSnapshot

  val SamplingCursorSequential =
    CursorRounds.contains(nextRound) and
    Rounds.forall(r =>
      if (r < nextRound) {
        Sampled(r)
      } else {
        sampled.get(r) == NilSnapshot
      }
    )

  val SampledValuesMatchHeadSigma =
    Rounds.forall(r =>
      sampled.get(r) == NilSnapshot or sampled.get(r) == HeadSigmaAtRound(r)
    )

  val SampledValuesAreValidCandidates =
    Rounds.forall(r =>
      sampled.get(r) == NilSnapshot or HeadSigmaCandidateValid(r)
    )

  val Safety =
    SamplingCursorSequential and
    SampledValuesMatchHeadSigma and
    SampledValuesAreValidCandidates
}

module CrosslinkHeadSigmaSamplingTest {
  import CrosslinkHeadSigmaSampling.* from "./CrosslinkHeadSigmaSampling"
  export CrosslinkHeadSigmaSampling.*

  action unchangedAll = all {
    nextRound' = nextRound,
    sampled' = sampled,
    firedAction' = firedAction,
  }

  run sameBranchHeadAdvanceProgressesSampledStreamTest = {
    Init
      .then(SampleCurrentRound)
      .then(SampleCurrentRound)
      .then(all {
        assert(sampled.get(0) == "a1"),
        assert(sampled.get(1) == "a2"),
        assert(Extends(sampled.get(1), sampled.get(0))),
        assert(SampleChangedAfter(0)),
        assert(Safety),
        unchangedAll,
      })
  }

  run forkSwitchChangesSampledCandidateTest = {
    Init
      .then(SampleCurrentRound)
      .then(SampleCurrentRound)
      .then(SampleCurrentRound)
      .then(all {
        assert(sampled.get(1) == "a2"),
        assert(sampled.get(2) == "b2"),
        assert(not(Agrees(sampled.get(1), sampled.get(2)))),
        assert(SampleChangedAfter(1)),
        assert(Safety),
        unchangedAll,
      })
  }

  run stableHeadKeepsSampledCandidateTest = {
    Init
      .then(SampleCurrentRound)
      .then(SampleCurrentRound)
      .then(SampleCurrentRound)
      .then(SampleCurrentRound)
      .then(all {
        assert(sampled.get(2) == "b2"),
        assert(sampled.get(3) == "b2"),
        assert(not(SampleChangedAfter(2))),
        assert(Safety),
        unchangedAll,
      })
  }

  run acceptsValidHeadSigmaProposalTest = {
    Init
      .then(all {
        assert(ProposalValid({
          tip: "a3",
          candidate: "a2",
          declaredHeight: 2,
        })),
        unchangedAll,
      })
  }

  run rejectsWrongCandidateForHeadTest = {
    Init
      .then(all {
        assert(not(ProposalValid({
          tip: "a3",
          candidate: "a1",
          declaredHeight: 1,
        }))),
        unchangedAll,
      })
  }

  run rejectsWrongDeclaredHeightTest = {
    Init
      .then(all {
        assert(not(ProposalValid({
          tip: "a3",
          candidate: "a2",
          declaredHeight: 3,
        }))),
        unchangedAll,
      })
  }

  run rejectsCandidateNotExtendingFinalizedPrefixTest = {
    Init
      .then(all {
        assert(not(ProposalValidAgainstFinalized({
          tip: "b3",
          candidate: "b2",
          declaredHeight: 2,
        }, "a1"))),
        unchangedAll,
      })
  }
}

module CrosslinkHeadSigmaSamplingModel {
  import CrosslinkHeadSigmaSamplingTest(
    Snapshots = Set("g", "a1", "a2", "a3", "b1", "b2", "b3"),
    MaxHeight = 3,
    MaxRound = 3,
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
    AncestorSnapshotAt = Map(
      "g" -> Map(0 -> "g", 1 -> "None", 2 -> "None", 3 -> "None"),
      "a1" -> Map(0 -> "g", 1 -> "a1", 2 -> "None", 3 -> "None"),
      "a2" -> Map(0 -> "g", 1 -> "a1", 2 -> "a2", 3 -> "None"),
      "a3" -> Map(0 -> "g", 1 -> "a1", 2 -> "a2", 3 -> "a3"),
      "b1" -> Map(0 -> "g", 1 -> "b1", 2 -> "None", 3 -> "None"),
      "b2" -> Map(0 -> "g", 1 -> "b1", 2 -> "b2", 3 -> "None"),
      "b3" -> Map(0 -> "g", 1 -> "b1", 2 -> "b2", 3 -> "b3"),
    ),
    HeadAtRound = Map(
      0 -> "a2",
      1 -> "a3",
      2 -> "b3",
      3 -> "b3",
    ),
  ).*
}
