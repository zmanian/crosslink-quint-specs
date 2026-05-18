module CrosslinkEvidenceGossip {
  /*
   Evidence gossip and observer-process model.

   Crosslink accountability evidence should not appear from thin air. This
   model separates:

   - gossiped signed consensus messages and fat pointers, and
   - observer-local evidence accepted from that gossip.

   A fat pointer can be gossiped once its signer set is authorized by gossiped
   precommits. An observer only accepts that fat pointer after it has also
   observed the signer precommits locally.
   */

  type Proc_t = str
  type Snapshot_t = str
  type Round_t = int

  const Corr: Set[Proc_t]
  const Faulty: Set[Proc_t]
  const VotingPower: Proc_t -> int
  const TotalVotingPower: int
  const FaultyVotingPowerBound: int
  const QuorumVotingPower: int
  const MaxRound: Round_t
  const Snapshots: Set[Snapshot_t]

  pure val Rounds = 0.to(MaxRound)
  pure val NilSnapshot = "None"
  pure val VoteValues = Snapshots.union(Set(NilSnapshot))

  pure def VotingPowerOf(voters: Set[Proc_t]): int =
    voters.fold(0, (acc, p) => acc + VotingPower.get(p))

  assume corr_and_faulty_disjoint =
    Corr.intersect(Faulty) == Set()
  assume validator_power_is_positive =
    Corr.union(Faulty).forall(p => VotingPower.get(p) > 0)
  assume total_voting_power_matches_validator_set =
    TotalVotingPower == VotingPowerOf(Corr.union(Faulty))
  assume faulty_power_at_threshold =
    VotingPowerOf(Faulty) <= FaultyVotingPowerBound
  assume quorum_intersection_has_correct_power =
    2 * QuorumVotingPower - TotalVotingPower > FaultyVotingPowerBound
  assume nil_is_not_snapshot =
    not(Snapshots.contains(NilSnapshot))

  type Propose_t = {
    src: Proc_t,
    round: Round_t,
    proposal: Snapshot_t,
    validRound: Round_t,
  }

  type Vote_t = {
    src: Proc_t,
    round: Round_t,
    id: Snapshot_t,
  }

  type FatPointer_t = {
    round: Round_t,
    id: Snapshot_t,
    signers: Set[Proc_t],
  }

  var gossipPropose: Round_t -> Set[Propose_t]
  var gossipPrevote: Round_t -> Set[Vote_t]
  var gossipPrecommit: Round_t -> Set[Vote_t]
  var gossipFatPointer: Set[FatPointer_t]
  var observedPropose: Round_t -> Set[Propose_t]
  var observedPrevote: Round_t -> Set[Vote_t]
  var observedPrecommit: Round_t -> Set[Vote_t]
  var observedFatPointer: Set[FatPointer_t]
  var firedAction: str

  pure def IsValidator(p: Proc_t): bool =
    Corr.union(Faulty).contains(p)

  pure def IsSnapshot(v: Snapshot_t): bool =
    Snapshots.contains(v)

  pure def VoteValueValid(v: Snapshot_t): bool =
    v == NilSnapshot or IsSnapshot(v)

  pure def Voters(votes: Set[Vote_t]): Set[Proc_t] =
    votes.map(m => m.src)

  def GossipedValuePrecommitFrom(
    p: Proc_t,
    r: Round_t,
    v: Snapshot_t,
  ): bool =
    gossipPrecommit.get(r).exists(m => m.src == p and m.id == v)

  def ObservedValuePrecommitFrom(
    p: Proc_t,
    r: Round_t,
    v: Snapshot_t,
  ): bool =
    observedPrecommit.get(r).exists(m => m.src == p and m.id == v)

  def GossipedPrecommitQuorum(r: Round_t, v: Snapshot_t): bool =
    VotingPowerOf(Voters(gossipPrecommit.get(r).filter(m => m.id == v))) >=
    QuorumVotingPower

  def ObservedPrecommitQuorum(r: Round_t, v: Snapshot_t): bool =
    VotingPowerOf(Voters(observedPrecommit.get(r).filter(m => m.id == v))) >=
    QuorumVotingPower

  def GossipedFatPointerValid(fp: FatPointer_t): bool =
    fp.round.in(Rounds) and
    IsSnapshot(fp.id) and
    fp.signers.forall(IsValidator) and
    VotingPowerOf(fp.signers) >= QuorumVotingPower and
    fp.signers.forall(p => GossipedValuePrecommitFrom(p, fp.round, fp.id))

  def ObservedFatPointerValid(fp: FatPointer_t): bool =
    fp.round.in(Rounds) and
    IsSnapshot(fp.id) and
    fp.signers.forall(IsValidator) and
    VotingPowerOf(fp.signers) >= QuorumVotingPower and
    fp.signers.forall(p => ObservedValuePrecommitFrom(p, fp.round, fp.id))

  action Init = all {
    gossipPropose' = Rounds.mapBy(_ => Set()),
    gossipPrevote' = Rounds.mapBy(_ => Set()),
    gossipPrecommit' = Rounds.mapBy(_ => Set()),
    gossipFatPointer' = Set(),
    observedPropose' = Rounds.mapBy(_ => Set()),
    observedPrevote' = Rounds.mapBy(_ => Set()),
    observedPrecommit' = Rounds.mapBy(_ => Set()),
    observedFatPointer' = Set(),
    firedAction' = "Init",
  }

  action KeepGossip = all {
    gossipPropose' = gossipPropose,
    gossipPrevote' = gossipPrevote,
    gossipPrecommit' = gossipPrecommit,
    gossipFatPointer' = gossipFatPointer,
  }

  action KeepObserved = all {
    observedPropose' = observedPropose,
    observedPrevote' = observedPrevote,
    observedPrecommit' = observedPrecommit,
    observedFatPointer' = observedFatPointer,
  }

  action PublishProposal(
    p: Proc_t,
    r: Round_t,
    v: Snapshot_t,
    vr: Round_t,
  ): bool = {
    val msg = { src: p, round: r, proposal: v, validRound: vr }
    all {
      IsValidator(p),
      r.in(Rounds),
      IsSnapshot(v),
      vr == -1 or vr.in(Rounds),
      gossipPropose' = gossipPropose.setBy(r, old => old.union(Set(msg))),
      gossipPrevote' = gossipPrevote,
      gossipPrecommit' = gossipPrecommit,
      gossipFatPointer' = gossipFatPointer,
      KeepObserved,
      firedAction' = "PublishProposal",
    }
  }

  action PublishPrevote(p: Proc_t, r: Round_t, v: Snapshot_t): bool = {
    val msg = { src: p, round: r, id: v }
    all {
      IsValidator(p),
      r.in(Rounds),
      VoteValueValid(v),
      gossipPropose' = gossipPropose,
      gossipPrevote' = gossipPrevote.setBy(r, old => old.union(Set(msg))),
      gossipPrecommit' = gossipPrecommit,
      gossipFatPointer' = gossipFatPointer,
      KeepObserved,
      firedAction' = "PublishPrevote",
    }
  }

  action PublishPrecommit(p: Proc_t, r: Round_t, v: Snapshot_t): bool = {
    val msg = { src: p, round: r, id: v }
    all {
      IsValidator(p),
      r.in(Rounds),
      VoteValueValid(v),
      gossipPropose' = gossipPropose,
      gossipPrevote' = gossipPrevote,
      gossipPrecommit' = gossipPrecommit.setBy(r, old => old.union(Set(msg))),
      gossipFatPointer' = gossipFatPointer,
      KeepObserved,
      firedAction' = "PublishPrecommit",
    }
  }

  action PublishFatPointer(
    r: Round_t,
    v: Snapshot_t,
    signers: Set[Proc_t],
  ): bool = {
    val fp = { round: r, id: v, signers: signers }
    all {
      GossipedFatPointerValid(fp),
      gossipFatPointer' = gossipFatPointer.union(Set(fp)),
      gossipPropose' = gossipPropose,
      gossipPrevote' = gossipPrevote,
      gossipPrecommit' = gossipPrecommit,
      KeepObserved,
      firedAction' = "PublishFatPointer",
    }
  }

  action ObserveProposal(
    p: Proc_t,
    r: Round_t,
    v: Snapshot_t,
    vr: Round_t,
  ): bool = {
    val msg = { src: p, round: r, proposal: v, validRound: vr }
    all {
      r.in(Rounds),
      gossipPropose.get(r).contains(msg),
      observedPropose' = observedPropose.setBy(r, old => old.union(Set(msg))),
      observedPrevote' = observedPrevote,
      observedPrecommit' = observedPrecommit,
      observedFatPointer' = observedFatPointer,
      KeepGossip,
      firedAction' = "ObserveProposal",
    }
  }

  action ObservePrevote(p: Proc_t, r: Round_t, v: Snapshot_t): bool = {
    val msg = { src: p, round: r, id: v }
    all {
      r.in(Rounds),
      gossipPrevote.get(r).contains(msg),
      observedPropose' = observedPropose,
      observedPrevote' = observedPrevote.setBy(r, old => old.union(Set(msg))),
      observedPrecommit' = observedPrecommit,
      observedFatPointer' = observedFatPointer,
      KeepGossip,
      firedAction' = "ObservePrevote",
    }
  }

  action ObservePrecommit(p: Proc_t, r: Round_t, v: Snapshot_t): bool = {
    val msg = { src: p, round: r, id: v }
    all {
      r.in(Rounds),
      gossipPrecommit.get(r).contains(msg),
      observedPropose' = observedPropose,
      observedPrevote' = observedPrevote,
      observedPrecommit' =
        observedPrecommit.setBy(r, old => old.union(Set(msg))),
      observedFatPointer' = observedFatPointer,
      KeepGossip,
      firedAction' = "ObservePrecommit",
    }
  }

  action ObserveFatPointer(
    r: Round_t,
    v: Snapshot_t,
    signers: Set[Proc_t],
  ): bool = {
    val fp = { round: r, id: v, signers: signers }
    all {
      gossipFatPointer.contains(fp),
      ObservedFatPointerValid(fp),
      observedFatPointer' = observedFatPointer.union(Set(fp)),
      observedPropose' = observedPropose,
      observedPrevote' = observedPrevote,
      observedPrecommit' = observedPrecommit,
      KeepGossip,
      firedAction' = "ObserveFatPointer",
    }
  }

  action Stutter = all {
    KeepGossip,
    KeepObserved,
    firedAction' = "Stutter",
  }

  action Next =
    any {
      nondet p = oneOf(Corr.union(Faulty))
      nondet r = oneOf(Rounds)
      nondet v = oneOf(VoteValues)
      nondet vr = oneOf(Rounds.union(Set(-1)))
      PublishProposal(p, r, v, vr),
      nondet p = oneOf(Corr.union(Faulty))
      nondet r = oneOf(Rounds)
      nondet v = oneOf(VoteValues)
      PublishPrevote(p, r, v),
      nondet p = oneOf(Corr.union(Faulty))
      nondet r = oneOf(Rounds)
      nondet v = oneOf(VoteValues)
      PublishPrecommit(p, r, v),
      nondet r = oneOf(Rounds)
      nondet v = oneOf(VoteValues)
      nondet signers = oneOf(powerset(Corr.union(Faulty)))
      PublishFatPointer(r, v, signers),
      nondet p = oneOf(Corr.union(Faulty))
      nondet r = oneOf(Rounds)
      nondet v = oneOf(VoteValues)
      nondet vr = oneOf(Rounds.union(Set(-1)))
      ObserveProposal(p, r, v, vr),
      nondet p = oneOf(Corr.union(Faulty))
      nondet r = oneOf(Rounds)
      nondet v = oneOf(VoteValues)
      ObservePrevote(p, r, v),
      nondet p = oneOf(Corr.union(Faulty))
      nondet r = oneOf(Rounds)
      nondet v = oneOf(VoteValues)
      ObservePrecommit(p, r, v),
      nondet r = oneOf(Rounds)
      nondet v = oneOf(VoteValues)
      nondet signers = oneOf(powerset(Corr.union(Faulty)))
      ObserveFatPointer(r, v, signers),
      Stutter,
    }

  val ObservedMessagesWereGossiped =
    Rounds.forall(r =>
      observedPropose.get(r).subseteq(gossipPropose.get(r)) and
      observedPrevote.get(r).subseteq(gossipPrevote.get(r)) and
      observedPrecommit.get(r).subseteq(gossipPrecommit.get(r))
    )

  val ObservedFatPointersWereGossiped =
    observedFatPointer.subseteq(gossipFatPointer)

  val ObservedFatPointersAreLocallyJustified =
    observedFatPointer.forall(fp => ObservedFatPointerValid(fp))

  val ObservedQuorumRequiresGossipedQuorum =
    Rounds.forall(r =>
      VoteValues.forall(v =>
        not(ObservedPrecommitQuorum(r, v)) or GossipedPrecommitQuorum(r, v)
      )
    )

  val Safety =
    ObservedMessagesWereGossiped and
    ObservedFatPointersWereGossiped and
    ObservedFatPointersAreLocallyJustified and
    ObservedQuorumRequiresGossipedQuorum
}

module CrosslinkEvidenceGossipTest {
  import CrosslinkEvidenceGossip.* from "./CrosslinkEvidenceGossip"
  export CrosslinkEvidenceGossip.*

  action unchangedAll = all {
    gossipPropose' = gossipPropose,
    gossipPrevote' = gossipPrevote,
    gossipPrecommit' = gossipPrecommit,
    gossipFatPointer' = gossipFatPointer,
    observedPropose' = observedPropose,
    observedPrevote' = observedPrevote,
    observedPrecommit' = observedPrecommit,
    observedFatPointer' = observedFatPointer,
    firedAction' = firedAction,
  }

  run cannotObserveUngossipedPrecommitTest = {
    Init
      .then(ObservePrecommit("p1", 0, "s0"))
      .fail()
  }

  run observedPrecommitQuorumRequiresGossipTest = {
    Init
      .then(PublishPrecommit("p1", 0, "s0"))
      .then(PublishPrecommit("p2", 0, "s0"))
      .then(PublishPrecommit("p3", 0, "s0"))
      .then(ObservePrecommit("p1", 0, "s0"))
      .then(ObservePrecommit("p2", 0, "s0"))
      .then(ObservePrecommit("p3", 0, "s0"))
      .then(all {
        assert(GossipedPrecommitQuorum(0, "s0")),
        assert(ObservedPrecommitQuorum(0, "s0")),
        assert(ObservedQuorumRequiresGossipedQuorum),
        assert(Safety),
        unchangedAll,
      })
  }

  run cannotObserveFatPointerBeforeSignerPrecommitsObservedTest = {
    Init
      .then(PublishPrecommit("p1", 0, "s0"))
      .then(PublishPrecommit("p2", 0, "s0"))
      .then(PublishPrecommit("p3", 0, "s0"))
      .then(PublishFatPointer(0, "s0", Set("p1", "p2", "p3")))
      .then(ObserveFatPointer(0, "s0", Set("p1", "p2", "p3")))
      .fail()
  }

  run observesFatPointerAfterSignerPrecommitsTest = {
    Init
      .then(PublishPrecommit("p1", 0, "s0"))
      .then(PublishPrecommit("p2", 0, "s0"))
      .then(PublishPrecommit("p3", 0, "s0"))
      .then(PublishFatPointer(0, "s0", Set("p1", "p2", "p3")))
      .then(ObservePrecommit("p1", 0, "s0"))
      .then(ObservePrecommit("p2", 0, "s0"))
      .then(ObservePrecommit("p3", 0, "s0"))
      .then(ObserveFatPointer(0, "s0", Set("p1", "p2", "p3")))
      .then(all {
        assert(observedFatPointer.contains({
          round: 0,
          id: "s0",
          signers: Set("p1", "p2", "p3"),
        })),
        assert(ObservedFatPointersAreLocallyJustified),
        assert(Safety),
        unchangedAll,
      })
  }

  run observationDoesNotMutateGossipTest = {
    Init
      .then(PublishPrevote("p1", 0, "s0"))
      .then(ObservePrevote("p1", 0, "s0"))
      .then(all {
        assert(gossipPrevote.get(0).contains({ src: "p1", round: 0, id: "s0" })),
        assert(observedPrevote.get(0).contains({ src: "p1", round: 0, id: "s0" })),
        assert(Safety),
        unchangedAll,
      })
  }
}

module CrosslinkEvidenceGossipModel {
  import CrosslinkEvidenceGossipTest(
    Corr = Set("p1", "p2", "p3"),
    Faulty = Set("p4"),
    VotingPower = Map("p1" -> 1, "p2" -> 1, "p3" -> 1, "p4" -> 1),
    TotalVotingPower = 4,
    FaultyVotingPowerBound = 1,
    QuorumVotingPower = 3,
    MaxRound = 1,
    Snapshots = Set("s0", "s1"),
  ).*
}
