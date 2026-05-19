module CrosslinkHeightedValidatorEvidence {
  /*
   Height-indexed evidence under dynamic validator sets.

   CrosslinkValidatorSetChange.qnt records which validator set is active at
   each decided BFT height. CrosslinkHeightedEvidenceGossip.qnt checks that
   observed fat pointers are backed by same-height precommits. This module
   composes those obligations: precommit and fat-pointer evidence must be
   authorized by the validator set active at the evidence height.
   */

  type Proc_t = str
  type Snapshot_t = str
  type Height_t = int
  type Round_t = int

  const ValidatorUniverse: Set[Proc_t]
  const VotingPower: Proc_t -> int
  const QuorumVotingPower: int
  const MaxBftHeight: Height_t
  const MaxRound: Round_t
  const Snapshots: Set[Snapshot_t]
  const InitialValidatorSet: Set[Proc_t]
  const NextValidatorSetOf: Snapshot_t -> Set[Proc_t]

  pure val Heights = 1.to(MaxBftHeight)
  pure val CursorHeights = 1.to(MaxBftHeight + 1)
  pure val Rounds = 0.to(MaxRound)
  pure val NilSnapshot = "None"

  pure def VotingPowerOf(voters: Set[Proc_t]): int =
    voters.fold(0, (acc, p) => acc + VotingPower.get(p))

  assume validator_power_is_positive =
    ValidatorUniverse.forall(p => VotingPower.get(p) > 0)
  assume initial_validator_set_is_valid =
    ValidValidatorSet(InitialValidatorSet)
  assume next_validator_sets_are_valid =
    Snapshots.forall(v => ValidValidatorSet(NextValidatorSetOf.get(v)))
  assume nil_is_not_snapshot =
    not(Snapshots.contains(NilSnapshot))

  type Vote_t = {
    src: Proc_t,
    height: Height_t,
    round: Round_t,
    id: Snapshot_t,
  }

  type FatPointer_t = {
    height: Height_t,
    round: Round_t,
    id: Snapshot_t,
    signers: Set[Proc_t],
  }

  var nextBftHeight: Height_t
  var currentValidatorSet: Set[Proc_t]
  var validatorSetAtHeight: Height_t -> Set[Proc_t]
  var decision: Height_t -> Snapshot_t
  var commitSigners: Height_t -> Set[Proc_t]
  var observedPrecommit: Height_t -> Round_t -> Set[Vote_t]
  var observedFatPointer: Set[FatPointer_t]
  var firedAction: str

  pure def IsSnapshot(v: Snapshot_t): bool =
    Snapshots.contains(v)

  pure def ValidValidatorSet(vs: Set[Proc_t]): bool =
    vs.size() > 0 and
    vs.subseteq(ValidatorUniverse) and
    VotingPowerOf(vs) >= QuorumVotingPower and
    2 * QuorumVotingPower > VotingPowerOf(vs)

  pure def SignerSetHasQuorum(
    signers: Set[Proc_t],
    validatorSet: Set[Proc_t],
  ): bool =
    signers.subseteq(validatorSet) and
    VotingPowerOf(signers) >= QuorumVotingPower

  def Decided(h: Height_t): bool =
    Heights.contains(h) and decision.get(h) != NilSnapshot

  def ValidatorSetKnownAt(h: Height_t): bool =
    h.in(Heights) and (
      h == nextBftHeight or
      (h < nextBftHeight and Decided(h))
    )

  def ValidatorSetFor(h: Height_t): Set[Proc_t] =
    if (h == nextBftHeight) {
      currentValidatorSet
    } else {
      validatorSetAtHeight.get(h)
    }

  def AuthorizedAtHeight(p: Proc_t, h: Height_t): bool =
    ValidatorSetKnownAt(h) and ValidatorSetFor(h).contains(p)

  def ObservedPrecommitFrom(
    p: Proc_t,
    h: Height_t,
    r: Round_t,
    v: Snapshot_t,
  ): bool =
    observedPrecommit.get(h).get(r).exists(m =>
      m.src == p and m.height == h and m.round == r and m.id == v
    )

  def ObservedFatPointerValid(fp: FatPointer_t): bool =
    ValidatorSetKnownAt(fp.height) and
    fp.round.in(Rounds) and
    IsSnapshot(fp.id) and
    SignerSetHasQuorum(fp.signers, ValidatorSetFor(fp.height)) and
    fp.signers.forall(p =>
      ObservedPrecommitFrom(p, fp.height, fp.round, fp.id)
    )

  action Init = all {
    nextBftHeight' = 1,
    currentValidatorSet' = InitialValidatorSet,
    validatorSetAtHeight' = Heights.mapBy(_ => Set()),
    decision' = Heights.mapBy(_ => NilSnapshot),
    commitSigners' = Heights.mapBy(_ => Set()),
    observedPrecommit' = Heights.mapBy(_ => Rounds.mapBy(_ => Set())),
    observedFatPointer' = Set(),
    firedAction' = "Init",
  }

  action KeepValidatorSchedule = all {
    nextBftHeight' = nextBftHeight,
    currentValidatorSet' = currentValidatorSet,
    validatorSetAtHeight' = validatorSetAtHeight,
    decision' = decision,
    commitSigners' = commitSigners,
  }

  action KeepEvidence = all {
    observedPrecommit' = observedPrecommit,
    observedFatPointer' = observedFatPointer,
  }

  action DecideAt(
    h: Height_t,
    candidate: Snapshot_t,
    signers: Set[Proc_t],
  ): bool =
    all {
      h == nextBftHeight,
      h.in(Heights),
      IsSnapshot(candidate),
      decision.get(h) == NilSnapshot,
      SignerSetHasQuorum(signers, currentValidatorSet),
      decision' = decision.set(h, candidate),
      commitSigners' = commitSigners.set(h, signers),
      validatorSetAtHeight' = validatorSetAtHeight.set(h, currentValidatorSet),
      currentValidatorSet' = NextValidatorSetOf.get(candidate),
      nextBftHeight' = h + 1,
      KeepEvidence,
      firedAction' = "DecideAt",
    }

  action ObservePrecommit(
    p: Proc_t,
    h: Height_t,
    r: Round_t,
    v: Snapshot_t,
  ): bool = {
    val msg = { src: p, height: h, round: r, id: v }
    all {
      ValidatorSetKnownAt(h),
      r.in(Rounds),
      IsSnapshot(v),
      AuthorizedAtHeight(p, h),
      KeepValidatorSchedule,
      observedPrecommit' =
        observedPrecommit.setBy(h, byRound =>
          byRound.setBy(r, old => old.union(Set(msg)))
        ),
      observedFatPointer' = observedFatPointer,
      firedAction' = "ObservePrecommit",
    }
  }

  action ObserveFatPointer(
    h: Height_t,
    r: Round_t,
    v: Snapshot_t,
    signers: Set[Proc_t],
  ): bool = {
    val fp = { height: h, round: r, id: v, signers: signers }
    all {
      ObservedFatPointerValid(fp),
      KeepValidatorSchedule,
      observedPrecommit' = observedPrecommit,
      observedFatPointer' = observedFatPointer.union(Set(fp)),
      firedAction' = "ObserveFatPointer",
    }
  }

  action Stutter = all {
    KeepValidatorSchedule,
    KeepEvidence,
    firedAction' = "Stutter",
  }

  action Next =
    any {
      nondet h = oneOf(Heights)
      nondet candidate = oneOf(Snapshots)
      nondet signers = oneOf(powerset(ValidatorUniverse))
      DecideAt(h, candidate, signers),
      nondet p = oneOf(ValidatorUniverse)
      nondet h = oneOf(Heights)
      nondet r = oneOf(Rounds)
      nondet v = oneOf(Snapshots)
      ObservePrecommit(p, h, r, v),
      nondet h = oneOf(Heights)
      nondet r = oneOf(Rounds)
      nondet v = oneOf(Snapshots)
      nondet signers = oneOf(powerset(ValidatorUniverse))
      ObserveFatPointer(h, r, v, signers),
      Stutter,
    }

  val DecisionCursorSequential =
    CursorHeights.contains(nextBftHeight) and
    Heights.forall(h =>
      if (h < nextBftHeight) {
        Decided(h)
      } else {
        decision.get(h) == NilSnapshot
      }
    )

  val CommitSignersAuthorizedAtHeight =
    Heights.forall(h =>
      not(Decided(h)) or
      SignerSetHasQuorum(commitSigners.get(h), validatorSetAtHeight.get(h))
    )

  val ObservedPrecommitsAuthorizedAtHeight =
    Heights.forall(h =>
      Rounds.forall(r =>
        observedPrecommit.get(h).get(r).forall(m =>
          AuthorizedAtHeight(m.src, h)
        )
      )
    )

  val ObservedFatPointersAuthorizedAtHeight =
    observedFatPointer.forall(ObservedFatPointerValid)

  val CurrentValidatorSetMatchesCursor =
    if (nextBftHeight == 1) {
      currentValidatorSet == InitialValidatorSet
    } else {
      Heights.contains(nextBftHeight - 1) and
      currentValidatorSet == NextValidatorSetOf.get(decision.get(nextBftHeight - 1))
    }

  val Safety =
    DecisionCursorSequential and
    CommitSignersAuthorizedAtHeight and
    ObservedPrecommitsAuthorizedAtHeight and
    ObservedFatPointersAuthorizedAtHeight and
    CurrentValidatorSetMatchesCursor
}

module CrosslinkHeightedValidatorEvidenceTest {
  import CrosslinkHeightedValidatorEvidence.* from "./CrosslinkHeightedValidatorEvidence"
  export CrosslinkHeightedValidatorEvidence.*

  action unchangedAll = all {
    nextBftHeight' = nextBftHeight,
    currentValidatorSet' = currentValidatorSet,
    validatorSetAtHeight' = validatorSetAtHeight,
    decision' = decision,
    commitSigners' = commitSigners,
    observedPrecommit' = observedPrecommit,
    observedFatPointer' = observedFatPointer,
    firedAction' = firedAction,
  }

  run rotatedSetAuthorizesNextHeightEvidenceTest = {
    Init
      .then(DecideAt(1, "rotate", Set("p1", "p2")))
      .then(ObservePrecommit("p2", 2, 0, "stay"))
      .then(ObservePrecommit("p4", 2, 0, "stay"))
      .then(ObserveFatPointer(2, 0, "stay", Set("p2", "p4")))
      .then(all {
        assert(currentValidatorSet == Set("p2", "p3", "p4")),
        assert(observedFatPointer.contains({
          height: 2,
          round: 0,
          id: "stay",
          signers: Set("p2", "p4"),
        })),
        assert(Safety),
        unchangedAll,
      })
  }

  run removedValidatorPrecommitRejectedAtNextHeightTest = {
    Init
      .then(DecideAt(1, "rotate", Set("p1", "p2")))
      .then(ObservePrecommit("p1", 2, 0, "stay"))
      .fail()
  }

  run oldHeightEvidenceUsesRecordedOldSetTest = {
    Init
      .then(DecideAt(1, "rotate", Set("p1", "p2")))
      .then(ObservePrecommit("p1", 1, 0, "rotate"))
      .then(ObservePrecommit("p2", 1, 0, "rotate"))
      .then(ObserveFatPointer(1, 0, "rotate", Set("p1", "p2")))
      .then(all {
        assert(validatorSetAtHeight.get(1) == Set("p1", "p2", "p3")),
        assert(observedFatPointer.contains({
          height: 1,
          round: 0,
          id: "rotate",
          signers: Set("p1", "p2"),
        })),
        assert(Safety),
        unchangedAll,
      })
  }

  run futureValidatorCannotSignOldHeightEvidenceTest = {
    Init
      .then(DecideAt(1, "rotate", Set("p1", "p2")))
      .then(ObservePrecommit("p4", 1, 0, "rotate"))
      .fail()
  }

  run removedValidatorFatPointerRejectedAtNextHeightTest = {
    Init
      .then(DecideAt(1, "rotate", Set("p1", "p2")))
      .then(ObservePrecommit("p2", 2, 0, "stay"))
      .then(ObserveFatPointer(2, 0, "stay", Set("p1", "p2")))
      .fail()
  }
}

module CrosslinkHeightedValidatorEvidenceModel {
  import CrosslinkHeightedValidatorEvidenceTest(
    ValidatorUniverse = Set("p1", "p2", "p3", "p4"),
    VotingPower = Map("p1" -> 1, "p2" -> 1, "p3" -> 1, "p4" -> 1),
    QuorumVotingPower = 2,
    MaxBftHeight = 2,
    MaxRound = 0,
    Snapshots = Set("rotate", "stay"),
    InitialValidatorSet = Set("p1", "p2", "p3"),
    NextValidatorSetOf = Map(
      "rotate" -> Set("p2", "p3", "p4"),
      "stay" -> Set("p2", "p3", "p4"),
    ),
  ).*
}
