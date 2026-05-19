module CrosslinkValidatorSetChange {
  /*
   Validator-set changes across BFT heights.

   This is a small standalone model for the validator-set part of Crosslink's
   multi-height story. Each BFT height is decided by the currently active
   validator set. The decided value carries the validator set for the next BFT
   height, so a validator that was removed at height h cannot contribute to a
   quorum at height h + 1.
   */

  type Proc_t = str
  type Snapshot_t = str
  type Height_t = int

  const ValidatorUniverse: Set[Proc_t]
  const VotingPower: Proc_t -> int
  const QuorumVotingPower: int
  const MaxBftHeight: Height_t
  const Snapshots: Set[Snapshot_t]
  const InitialValidatorSet: Set[Proc_t]
  const NextValidatorSetOf: Snapshot_t -> Set[Proc_t]

  pure val Heights = 1.to(MaxBftHeight)
  pure val CursorHeights = 1.to(MaxBftHeight + 1)
  pure val NilSnapshot = "None"

  pure def VotingPowerOf(voters: Set[Proc_t]): int =
    voters.fold(0, (acc, p) => acc + VotingPower.get(p))

  assume max_bft_height_is_positive =
    MaxBftHeight >= 1
  assume validator_power_is_positive =
    ValidatorUniverse.forall(p => VotingPower.get(p) > 0)
  assume initial_validator_set_is_valid =
    ValidValidatorSet(InitialValidatorSet)
  assume next_validator_sets_are_valid =
    Snapshots.forall(v => ValidValidatorSet(NextValidatorSetOf.get(v)))
  assume nil_is_not_snapshot =
    not(Snapshots.contains(NilSnapshot))

  var nextBftHeight: Height_t
  var currentValidatorSet: Set[Proc_t]
  var validatorSetAtHeight: Height_t -> Set[Proc_t]
  var decision: Height_t -> Snapshot_t
  var commitSigners: Height_t -> Set[Proc_t]
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

  action Init = all {
    nextBftHeight' = 1,
    currentValidatorSet' = InitialValidatorSet,
    validatorSetAtHeight' = Heights.mapBy(_ => Set()),
    decision' = Heights.mapBy(_ => NilSnapshot),
    commitSigners' = Heights.mapBy(_ => Set()),
    firedAction' = "Init",
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
      firedAction' = "DecideAt",
    }

  action Stutter = all {
    nextBftHeight' = nextBftHeight,
    currentValidatorSet' = currentValidatorSet,
    validatorSetAtHeight' = validatorSetAtHeight,
    decision' = decision,
    commitSigners' = commitSigners,
    firedAction' = "Stutter",
  }

  action Next =
    any {
      nondet h = oneOf(Heights)
      nondet candidate = oneOf(Snapshots)
      nondet signers = oneOf(powerset(ValidatorUniverse))
      DecideAt(h, candidate, signers),
      Stutter,
    }

  def Decided(h: Height_t): bool =
    Heights.contains(h) and decision.get(h) != NilSnapshot

  val DecisionCursorSequential =
    CursorHeights.contains(nextBftHeight) and
    Heights.forall(h =>
      if (h < nextBftHeight) {
        Decided(h)
      } else {
        decision.get(h) == NilSnapshot
      }
    )

  val RecordedValidatorSetsAreValid =
    Heights.forall(h =>
      not(Decided(h)) or ValidValidatorSet(validatorSetAtHeight.get(h))
    )

  val CommitSignersAuthorizedAtHeight =
    Heights.forall(h =>
      not(Decided(h)) or
      SignerSetHasQuorum(commitSigners.get(h), validatorSetAtHeight.get(h))
    )

  val CurrentValidatorSetMatchesCursor =
    if (nextBftHeight == 1) {
      currentValidatorSet == InitialValidatorSet
    } else {
      Heights.contains(nextBftHeight - 1) and
      currentValidatorSet == NextValidatorSetOf.get(decision.get(nextBftHeight - 1))
    }

  val Safety =
    DecisionCursorSequential and
    RecordedValidatorSetsAreValid and
    CommitSignersAuthorizedAtHeight and
    CurrentValidatorSetMatchesCursor
}

module CrosslinkValidatorSetChangeTest {
  import CrosslinkValidatorSetChange.* from "./CrosslinkValidatorSetChange"
  export CrosslinkValidatorSetChange.*

  action unchangedAll = all {
    nextBftHeight' = nextBftHeight,
    currentValidatorSet' = currentValidatorSet,
    validatorSetAtHeight' = validatorSetAtHeight,
    decision' = decision,
    commitSigners' = commitSigners,
    firedAction' = firedAction,
  }

  run rotatesValidatorSetAfterDecisionTest = {
    Init
      .then(DecideAt(1, "rotate", Set("p1", "p2")))
      .then(all {
        assert(nextBftHeight == 2),
        assert(validatorSetAtHeight.get(1) == Set("p1", "p2", "p3")),
        assert(currentValidatorSet == Set("p2", "p3", "p4")),
        assert(Safety),
        unchangedAll,
      })
  }

  run rejectsRemovedValidatorAtNextHeightTest = {
    Init
      .then(DecideAt(1, "rotate", Set("p1", "p2")))
      .then(DecideAt(2, "stay", Set("p1", "p2")))
      .fail()
  }

  run acceptsNewValidatorSetAtNextHeightTest = {
    Init
      .then(DecideAt(1, "rotate", Set("p1", "p2")))
      .then(DecideAt(2, "stay", Set("p2", "p4")))
      .then(all {
        assert(nextBftHeight == 3),
        assert(validatorSetAtHeight.get(2) == Set("p2", "p3", "p4")),
        assert(commitSigners.get(2) == Set("p2", "p4")),
        assert(Safety),
        unchangedAll,
      })
  }

  run rejectsSignerSetWithoutQuorumTest = {
    Init
      .then(DecideAt(1, "rotate", Set("p1")))
      .fail()
  }
}

module CrosslinkValidatorSetChangeModel {
  import CrosslinkValidatorSetChangeTest(
    ValidatorUniverse = Set("p1", "p2", "p3", "p4"),
    VotingPower = Map("p1" -> 1, "p2" -> 1, "p3" -> 1, "p4" -> 1),
    QuorumVotingPower = 2,
    MaxBftHeight = 2,
    Snapshots = Set("rotate", "stay"),
    InitialValidatorSet = Set("p1", "p2", "p3"),
    NextValidatorSetOf = Map(
      "rotate" -> Set("p2", "p3", "p4"),
      "stay" -> Set("p2", "p3", "p4"),
    ),
  ).*
}
