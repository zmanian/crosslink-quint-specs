module CrosslinkHeightedEvidenceGossip {
  /*
   Height-aware evidence gossip and observer-process model.

   This extends CrosslinkEvidenceGossip.qnt with the BFT height dimension used by
   the height-indexed round/finality models. Observer-local evidence for height
   h can only be accepted from gossip for height h, and a heighted fat pointer
   is only observed after its signer precommits have also been observed at that
   same height.
   */

  type Proc_t = str
  type Snapshot_t = str
  type Height_t = int
  type Round_t = int

  const Corr: Set[Proc_t]
  const Faulty: Set[Proc_t]
  const VotingPower: Proc_t -> int
  const TotalVotingPower: int
  const FaultyVotingPowerBound: int
  const QuorumVotingPower: int
  const MaxBftHeight: Height_t
  const MaxRound: Round_t
  const Snapshots: Set[Snapshot_t]

  pure val Heights = 1.to(MaxBftHeight)
  pure val Rounds = 0.to(MaxRound)
  pure val NilRound = -1
  pure val NilSnapshot = "None"
  pure val ProposalValidRounds = Rounds.union(Set(NilRound))
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
    height: Height_t,
    round: Round_t,
    proposal: Snapshot_t,
    validRound: Round_t,
  }

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

  var gossipPropose: Height_t -> Round_t -> Set[Propose_t]
  var gossipPrevote: Height_t -> Round_t -> Set[Vote_t]
  var gossipPrecommit: Height_t -> Round_t -> Set[Vote_t]
  var gossipFatPointer: Set[FatPointer_t]
  var observedPropose: Height_t -> Round_t -> Set[Propose_t]
  var observedPrevote: Height_t -> Round_t -> Set[Vote_t]
  var observedPrecommit: Height_t -> Round_t -> Set[Vote_t]
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
    h: Height_t,
    r: Round_t,
    v: Snapshot_t,
  ): bool =
    gossipPrecommit.get(h).get(r).exists(m =>
      m.src == p and m.height == h and m.round == r and m.id == v
    )

  def ObservedValuePrecommitFrom(
    p: Proc_t,
    h: Height_t,
    r: Round_t,
    v: Snapshot_t,
  ): bool =
    observedPrecommit.get(h).get(r).exists(m =>
      m.src == p and m.height == h and m.round == r and m.id == v
    )

  def GossipedPrecommitQuorum(
    h: Height_t,
    r: Round_t,
    v: Snapshot_t,
  ): bool =
    VotingPowerOf(Voters(gossipPrecommit.get(h).get(r).filter(m => m.id == v))) >=
    QuorumVotingPower

  def ObservedPrecommitQuorum(
    h: Height_t,
    r: Round_t,
    v: Snapshot_t,
  ): bool =
    VotingPowerOf(Voters(observedPrecommit.get(h).get(r).filter(m => m.id == v))) >=
    QuorumVotingPower

  def GossipedFatPointerValid(fp: FatPointer_t): bool =
    fp.height.in(Heights) and
    fp.round.in(Rounds) and
    IsSnapshot(fp.id) and
    fp.signers.forall(IsValidator) and
    VotingPowerOf(fp.signers) >= QuorumVotingPower and
    fp.signers.forall(p =>
      GossipedValuePrecommitFrom(p, fp.height, fp.round, fp.id)
    )

  def ObservedFatPointerValid(fp: FatPointer_t): bool =
    fp.height.in(Heights) and
    fp.round.in(Rounds) and
    IsSnapshot(fp.id) and
    fp.signers.forall(IsValidator) and
    VotingPowerOf(fp.signers) >= QuorumVotingPower and
    fp.signers.forall(p =>
      ObservedValuePrecommitFrom(p, fp.height, fp.round, fp.id)
    )

  action Init = all {
    gossipPropose' = Heights.mapBy(_ => Rounds.mapBy(_ => Set())),
    gossipPrevote' = Heights.mapBy(_ => Rounds.mapBy(_ => Set())),
    gossipPrecommit' = Heights.mapBy(_ => Rounds.mapBy(_ => Set())),
    gossipFatPointer' = Set(),
    observedPropose' = Heights.mapBy(_ => Rounds.mapBy(_ => Set())),
    observedPrevote' = Heights.mapBy(_ => Rounds.mapBy(_ => Set())),
    observedPrecommit' = Heights.mapBy(_ => Rounds.mapBy(_ => Set())),
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
    h: Height_t,
    r: Round_t,
    v: Snapshot_t,
    vr: Round_t,
  ): bool = {
    val msg = { src: p, height: h, round: r, proposal: v, validRound: vr }
    all {
      IsValidator(p),
      h.in(Heights),
      r.in(Rounds),
      IsSnapshot(v),
      vr.in(ProposalValidRounds),
      gossipPropose' =
        gossipPropose.setBy(h, byRound =>
          byRound.setBy(r, old => old.union(Set(msg)))
        ),
      gossipPrevote' = gossipPrevote,
      gossipPrecommit' = gossipPrecommit,
      gossipFatPointer' = gossipFatPointer,
      KeepObserved,
      firedAction' = "PublishProposal",
    }
  }

  action PublishPrevote(p: Proc_t, h: Height_t, r: Round_t, v: Snapshot_t): bool = {
    val msg = { src: p, height: h, round: r, id: v }
    all {
      IsValidator(p),
      h.in(Heights),
      r.in(Rounds),
      VoteValueValid(v),
      gossipPropose' = gossipPropose,
      gossipPrevote' =
        gossipPrevote.setBy(h, byRound =>
          byRound.setBy(r, old => old.union(Set(msg)))
        ),
      gossipPrecommit' = gossipPrecommit,
      gossipFatPointer' = gossipFatPointer,
      KeepObserved,
      firedAction' = "PublishPrevote",
    }
  }

  action PublishPrecommit(
    p: Proc_t,
    h: Height_t,
    r: Round_t,
    v: Snapshot_t,
  ): bool = {
    val msg = { src: p, height: h, round: r, id: v }
    all {
      IsValidator(p),
      h.in(Heights),
      r.in(Rounds),
      VoteValueValid(v),
      gossipPropose' = gossipPropose,
      gossipPrevote' = gossipPrevote,
      gossipPrecommit' =
        gossipPrecommit.setBy(h, byRound =>
          byRound.setBy(r, old => old.union(Set(msg)))
        ),
      gossipFatPointer' = gossipFatPointer,
      KeepObserved,
      firedAction' = "PublishPrecommit",
    }
  }

  action PublishFatPointer(
    h: Height_t,
    r: Round_t,
    v: Snapshot_t,
    signers: Set[Proc_t],
  ): bool = {
    val fp = { height: h, round: r, id: v, signers: signers }
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
    h: Height_t,
    r: Round_t,
    v: Snapshot_t,
    vr: Round_t,
  ): bool = {
    val msg = { src: p, height: h, round: r, proposal: v, validRound: vr }
    all {
      h.in(Heights),
      r.in(Rounds),
      gossipPropose.get(h).get(r).contains(msg),
      observedPropose' =
        observedPropose.setBy(h, byRound =>
          byRound.setBy(r, old => old.union(Set(msg)))
        ),
      observedPrevote' = observedPrevote,
      observedPrecommit' = observedPrecommit,
      observedFatPointer' = observedFatPointer,
      KeepGossip,
      firedAction' = "ObserveProposal",
    }
  }

  action ObservePrevote(p: Proc_t, h: Height_t, r: Round_t, v: Snapshot_t): bool = {
    val msg = { src: p, height: h, round: r, id: v }
    all {
      h.in(Heights),
      r.in(Rounds),
      gossipPrevote.get(h).get(r).contains(msg),
      observedPropose' = observedPropose,
      observedPrevote' =
        observedPrevote.setBy(h, byRound =>
          byRound.setBy(r, old => old.union(Set(msg)))
        ),
      observedPrecommit' = observedPrecommit,
      observedFatPointer' = observedFatPointer,
      KeepGossip,
      firedAction' = "ObservePrevote",
    }
  }

  action ObservePrecommit(
    p: Proc_t,
    h: Height_t,
    r: Round_t,
    v: Snapshot_t,
  ): bool = {
    val msg = { src: p, height: h, round: r, id: v }
    all {
      h.in(Heights),
      r.in(Rounds),
      gossipPrecommit.get(h).get(r).contains(msg),
      observedPropose' = observedPropose,
      observedPrevote' = observedPrevote,
      observedPrecommit' =
        observedPrecommit.setBy(h, byRound =>
          byRound.setBy(r, old => old.union(Set(msg)))
        ),
      observedFatPointer' = observedFatPointer,
      KeepGossip,
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
      nondet h = oneOf(Heights)
      nondet r = oneOf(Rounds)
      nondet v = oneOf(Snapshots)
      nondet vr = oneOf(ProposalValidRounds)
      PublishProposal(p, h, r, v, vr),
      nondet p = oneOf(Corr.union(Faulty))
      nondet h = oneOf(Heights)
      nondet r = oneOf(Rounds)
      nondet v = oneOf(VoteValues)
      PublishPrevote(p, h, r, v),
      nondet p = oneOf(Corr.union(Faulty))
      nondet h = oneOf(Heights)
      nondet r = oneOf(Rounds)
      nondet v = oneOf(VoteValues)
      PublishPrecommit(p, h, r, v),
      nondet h = oneOf(Heights)
      nondet r = oneOf(Rounds)
      nondet v = oneOf(Snapshots)
      nondet signers = oneOf(powerset(Corr.union(Faulty)))
      PublishFatPointer(h, r, v, signers),
      nondet p = oneOf(Corr.union(Faulty))
      nondet h = oneOf(Heights)
      nondet r = oneOf(Rounds)
      nondet v = oneOf(Snapshots)
      nondet vr = oneOf(ProposalValidRounds)
      ObserveProposal(p, h, r, v, vr),
      nondet p = oneOf(Corr.union(Faulty))
      nondet h = oneOf(Heights)
      nondet r = oneOf(Rounds)
      nondet v = oneOf(VoteValues)
      ObservePrevote(p, h, r, v),
      nondet p = oneOf(Corr.union(Faulty))
      nondet h = oneOf(Heights)
      nondet r = oneOf(Rounds)
      nondet v = oneOf(VoteValues)
      ObservePrecommit(p, h, r, v),
      nondet h = oneOf(Heights)
      nondet r = oneOf(Rounds)
      nondet v = oneOf(Snapshots)
      nondet signers = oneOf(powerset(Corr.union(Faulty)))
      ObserveFatPointer(h, r, v, signers),
      Stutter,
    }

  val ObservedMessagesWereGossiped =
    Heights.forall(h =>
      Rounds.forall(r =>
        observedPropose.get(h).get(r).subseteq(gossipPropose.get(h).get(r)) and
        observedPrevote.get(h).get(r).subseteq(gossipPrevote.get(h).get(r)) and
        observedPrecommit.get(h).get(r).subseteq(gossipPrecommit.get(h).get(r))
      )
    )

  val ObservedFatPointersWereGossiped =
    observedFatPointer.subseteq(gossipFatPointer)

  val ObservedFatPointersAreLocallyJustified =
    observedFatPointer.forall(fp => ObservedFatPointerValid(fp))

  val ObservedQuorumRequiresGossipedQuorum =
    Heights.forall(h =>
      Rounds.forall(r =>
        VoteValues.forall(v =>
          not(ObservedPrecommitQuorum(h, r, v)) or
          GossipedPrecommitQuorum(h, r, v)
        )
      )
    )

  val Safety =
    ObservedMessagesWereGossiped and
    ObservedFatPointersWereGossiped and
    ObservedFatPointersAreLocallyJustified and
    ObservedQuorumRequiresGossipedQuorum
}

module CrosslinkHeightedEvidenceGossipTest {
  import CrosslinkHeightedEvidenceGossip.* from "./CrosslinkHeightedEvidenceGossip"
  export CrosslinkHeightedEvidenceGossip.*

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

  run cannotObserveUngossipedHeightedPrecommitTest = {
    Init
      .then(ObservePrecommit("p1", 1, 0, "h1r0"))
      .fail()
  }

  run observedHeightedPrecommitQuorumRequiresGossipTest = {
    Init
      .then(PublishPrecommit("p1", 1, 0, "h1r0"))
      .then(PublishPrecommit("p2", 1, 0, "h1r0"))
      .then(PublishPrecommit("p3", 1, 0, "h1r0"))
      .then(ObservePrecommit("p1", 1, 0, "h1r0"))
      .then(ObservePrecommit("p2", 1, 0, "h1r0"))
      .then(ObservePrecommit("p3", 1, 0, "h1r0"))
      .then(all {
        assert(GossipedPrecommitQuorum(1, 0, "h1r0")),
        assert(ObservedPrecommitQuorum(1, 0, "h1r0")),
        assert(ObservedQuorumRequiresGossipedQuorum),
        assert(Safety),
        unchangedAll,
      })
  }

  run rejectsCrossHeightFatPointerSignerEvidenceTest = {
    Init
      .then(PublishPrecommit("p1", 1, 0, "h1r0"))
      .then(PublishPrecommit("p2", 1, 0, "h1r0"))
      .then(PublishPrecommit("p3", 1, 0, "h1r0"))
      .then(PublishFatPointer(2, 0, "h1r0", Set("p1", "p2", "p3")))
      .fail()
  }

  run cannotObserveHeightedFatPointerBeforeSignerPrecommitsObservedTest = {
    Init
      .then(PublishPrecommit("p1", 1, 0, "h1r0"))
      .then(PublishPrecommit("p2", 1, 0, "h1r0"))
      .then(PublishPrecommit("p3", 1, 0, "h1r0"))
      .then(PublishFatPointer(1, 0, "h1r0", Set("p1", "p2", "p3")))
      .then(ObserveFatPointer(1, 0, "h1r0", Set("p1", "p2", "p3")))
      .fail()
  }

  run observesHeightedFatPointerAfterSignerPrecommitsTest = {
    Init
      .then(PublishPrecommit("p1", 1, 0, "h1r0"))
      .then(PublishPrecommit("p2", 1, 0, "h1r0"))
      .then(PublishPrecommit("p3", 1, 0, "h1r0"))
      .then(PublishFatPointer(1, 0, "h1r0", Set("p1", "p2", "p3")))
      .then(ObservePrecommit("p1", 1, 0, "h1r0"))
      .then(ObservePrecommit("p2", 1, 0, "h1r0"))
      .then(ObservePrecommit("p3", 1, 0, "h1r0"))
      .then(ObserveFatPointer(1, 0, "h1r0", Set("p1", "p2", "p3")))
      .then(all {
        assert(observedFatPointer.contains({
          height: 1,
          round: 0,
          id: "h1r0",
          signers: Set("p1", "p2", "p3"),
        })),
        assert(ObservedFatPointersAreLocallyJustified),
        assert(Safety),
        unchangedAll,
      })
  }
}

module CrosslinkHeightedEvidenceGossipModel {
  import CrosslinkHeightedEvidenceGossipTest(
    Corr = Set("p1", "p2", "p3"),
    Faulty = Set("p4"),
    VotingPower = Map("p1" -> 1, "p2" -> 1, "p3" -> 1, "p4" -> 1),
    TotalVotingPower = 4,
    FaultyVotingPowerBound = 1,
    QuorumVotingPower = 3,
    MaxBftHeight = 2,
    MaxRound = 0,
    Snapshots = Set("h1r0", "h2r0"),
  ).*
}
