module CrosslinkHeightedRound {
  /*
   First height-indexed round-machine slice.

   Crosslink has two dimensions:

   - BFT heights are sequential.
   - Inside each BFT height, Tenderlink runs rounds over a moving PoW stream.

   The older focused round model is one-height. This model adds the missing
   height dimension around a compact receive-reactive round machine. It checks
   that decisions advance validator height cursors sequentially and that
   nil-precommit resampling clears only same-height/same-round state.
   */

  type Proc_t = str
  type Snapshot_t = str
  type Height_t = int
  type Round_t = int
  type Step_t = str

  const Corr: Set[Proc_t]
  const Faulty: Set[Proc_t]
  const VotingPower: Proc_t -> int
  const QuorumVotingPower: int
  const MaxBftHeight: Height_t
  const MaxRound: Round_t
  const Proposer: Height_t -> Round_t -> Proc_t
  const Stream: Height_t -> Round_t -> Snapshot_t
  const Snapshots: Set[Snapshot_t]
  const ResampleOnNilPrecommit: bool

  pure val Heights = 1.to(MaxBftHeight)
  pure val CursorHeights = 1.to(MaxBftHeight + 1)
  pure val Rounds = 0.to(MaxRound)
  pure val NilRound = -1
  pure val NilSnapshot = "None"
  pure val VoteValues = Snapshots.union(Set(NilSnapshot))

  assume corr_and_faulty_disjoint =
    Corr.intersect(Faulty) == Set()
  assume validator_power_is_positive =
    Corr.union(Faulty).forall(p => VotingPower.get(p) > 0)
  assume quorum_intersection_has_correct_power =
    2 * QuorumVotingPower > VotingPowerOf(Corr.union(Faulty))
  assume nil_is_not_snapshot =
    not(Snapshots.contains(NilSnapshot))
  assume streams_are_snapshots =
    Heights.forall(h =>
      Rounds.forall(r => Snapshots.contains(Stream.get(h).get(r)))
    )

  pure def VotingPowerOf(voters: Set[Proc_t]): int =
    voters.fold(0, (acc, p) => acc + VotingPower.get(p))

  type Propose_t = {
    src: Proc_t,
    height: Height_t,
    round: Round_t,
    proposal: Snapshot_t,
  }

  type Vote_t = {
    src: Proc_t,
    height: Height_t,
    round: Round_t,
    id: Snapshot_t,
  }

  var height: Proc_t -> Height_t
  var round: Proc_t -> Height_t -> Round_t
  var step: Proc_t -> Height_t -> Step_t
  var decision: Proc_t -> Height_t -> Snapshot_t
  var lockedValue: Proc_t -> Height_t -> Snapshot_t
  var lockedRound: Proc_t -> Height_t -> Round_t
  var validValue: Proc_t -> Height_t -> Snapshot_t
  var validRound: Proc_t -> Height_t -> Round_t
  var cachedProposal: Proc_t -> Height_t -> Snapshot_t
  var cachedProposalRound: Proc_t -> Height_t -> Round_t
  var msgsPropose: Height_t -> Round_t -> Set[Propose_t]
  var msgsPrevote: Height_t -> Round_t -> Set[Vote_t]
  var msgsPrecommit: Height_t -> Round_t -> Set[Vote_t]
  var seenPropose: Proc_t -> Height_t -> Round_t -> Set[Propose_t]
  var seenPrevote: Proc_t -> Height_t -> Round_t -> Set[Vote_t]
  var seenPrecommit: Proc_t -> Height_t -> Round_t -> Set[Vote_t]
  var firedAction: str

  pure def IsSnapshot(v: Snapshot_t): bool =
    Snapshots.contains(v)

  pure def Voters(votes: Set[Vote_t]): Set[Proc_t] =
    votes.map(m => m.src)

  def ActiveHeight(p: Proc_t, h: Height_t): bool =
    h.in(Heights) and height.get(p) == h

  def ProposalFor(p: Proc_t, h: Height_t, r: Round_t): Snapshot_t =
    if (cachedProposal.get(p).get(h) == NilSnapshot) {
      Stream.get(h).get(r)
    } else {
      cachedProposal.get(p).get(h)
    }

  def HasPrecommitFrom(p: Proc_t, h: Height_t, r: Round_t): bool =
    msgsPrecommit.get(h).get(r).exists(m => m.src == p)

  def SeenProposal(p: Proc_t, h: Height_t, r: Round_t, v: Snapshot_t): bool =
    seenPropose.get(p).get(h).get(r).exists(m =>
      m.src == Proposer.get(h).get(r) and
      m.height == h and
      m.round == r and
      m.proposal == v
    )

  def LockAllows(p: Proc_t, h: Height_t, v: Snapshot_t): bool =
    lockedValue.get(p).get(h) == NilSnapshot or lockedValue.get(p).get(h) == v

  def LocalPrevoteQuorum(
    p: Proc_t,
    h: Height_t,
    r: Round_t,
    v: Snapshot_t,
  ): bool =
    VotingPowerOf(Voters(seenPrevote.get(p).get(h).get(r).filter(m => m.id == v))) >=
    QuorumVotingPower

  def LocalPrecommitQuorum(
    p: Proc_t,
    h: Height_t,
    r: Round_t,
    v: Snapshot_t,
  ): bool =
    VotingPowerOf(Voters(seenPrecommit.get(p).get(h).get(r).filter(m => m.id == v))) >=
    QuorumVotingPower

  def LocalAnyPrecommitQuorum(p: Proc_t, h: Height_t, r: Round_t): bool =
    VotingPowerOf(Voters(seenPrecommit.get(p).get(h).get(r))) >= QuorumVotingPower

  def LocalNilPrecommitCert(p: Proc_t, h: Height_t, r: Round_t): bool =
    LocalPrecommitQuorum(p, h, r, NilSnapshot)

  action Init = all {
    height' = Corr.mapBy(_ => 1),
    round' = Corr.mapBy(_ => Heights.mapBy(_ => 0)),
    step' = Corr.mapBy(_ => Heights.mapBy(_ => "propose")),
    decision' = Corr.mapBy(_ => Heights.mapBy(_ => NilSnapshot)),
    lockedValue' = Corr.mapBy(_ => Heights.mapBy(_ => NilSnapshot)),
    lockedRound' = Corr.mapBy(_ => Heights.mapBy(_ => NilRound)),
    validValue' = Corr.mapBy(_ => Heights.mapBy(_ => NilSnapshot)),
    validRound' = Corr.mapBy(_ => Heights.mapBy(_ => NilRound)),
    cachedProposal' = Corr.mapBy(_ => Heights.mapBy(_ => NilSnapshot)),
    cachedProposalRound' = Corr.mapBy(_ => Heights.mapBy(_ => NilRound)),
    msgsPropose' = Heights.mapBy(_ => Rounds.mapBy(_ => Set())),
    msgsPrevote' = Heights.mapBy(_ => Rounds.mapBy(_ => Set())),
    msgsPrecommit' = Heights.mapBy(_ => Rounds.mapBy(_ => Set())),
    seenPropose' = Corr.mapBy(_ => Heights.mapBy(_ => Rounds.mapBy(_ => Set()))),
    seenPrevote' = Corr.mapBy(_ => Heights.mapBy(_ => Rounds.mapBy(_ => Set()))),
    seenPrecommit' = Corr.mapBy(_ => Heights.mapBy(_ => Rounds.mapBy(_ => Set()))),
    firedAction' = "Init",
  }

  action KeepMessages = all {
    msgsPropose' = msgsPropose,
    msgsPrevote' = msgsPrevote,
    msgsPrecommit' = msgsPrecommit,
    seenPropose' = seenPropose,
    seenPrevote' = seenPrevote,
    seenPrecommit' = seenPrecommit,
  }

  action KeepValidatorState = all {
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
  }

  action InsertProposal(p: Proc_t): bool = {
    val h = height.get(p)
    val r = round.get(p).get(h)
    val v = ProposalFor(p, h, r)
    val msg = { src: p, height: h, round: r, proposal: v }
    all {
      ActiveHeight(p, h),
      r.in(Rounds),
      step.get(p).get(h) == "propose",
      p == Proposer.get(h).get(r),
      IsSnapshot(v),
      msgsPropose.get(h).get(r).forall(m => m.src != p),
      msgsPropose' =
        msgsPropose.setBy(h, byRound =>
          byRound.setBy(r, old => old.union(Set(msg)))
        ),
      msgsPrevote' = msgsPrevote,
      msgsPrecommit' = msgsPrecommit,
      seenPropose' = seenPropose,
      seenPrevote' = seenPrevote,
      seenPrecommit' = seenPrecommit,
      height' = height,
      round' = round,
      step' = step,
      decision' = decision,
      lockedValue' = lockedValue,
      lockedRound' = lockedRound,
      validValue' = validValue,
      validRound' = validRound,
      cachedProposal' =
        cachedProposal.setBy(p, byHeight => byHeight.set(h, v)),
      cachedProposalRound' =
        cachedProposalRound.setBy(p, byHeight => byHeight.set(h, r)),
      firedAction' = "InsertProposal",
    }
  }

  action DeliverProposal(
    dst: Proc_t,
    from: Proc_t,
    h: Height_t,
    r: Round_t,
    v: Snapshot_t,
  ): bool = {
    val msg = { src: from, height: h, round: r, proposal: v }
    all {
      dst.in(Corr),
      h.in(Heights),
      r.in(Rounds),
      msgsPropose.get(h).get(r).contains(msg),
      seenPropose' =
        seenPropose.setBy(dst, byHeight =>
          byHeight.setBy(h, byRound =>
            byRound.setBy(r, old => old.union(Set(msg)))
          )
        ),
      seenPrevote' = seenPrevote,
      seenPrecommit' = seenPrecommit,
      msgsPropose' = msgsPropose,
      msgsPrevote' = msgsPrevote,
      msgsPrecommit' = msgsPrecommit,
      KeepValidatorState,
      firedAction' = "DeliverProposal",
    }
  }

  action DeliverPrevotesTo(
    dst: Proc_t,
    h: Height_t,
    r: Round_t,
    v: Snapshot_t,
    signers: Set[Proc_t],
  ): bool =
    all {
      dst.in(Corr),
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
        seenPrevote.setBy(dst, byHeight =>
          byHeight.setBy(h, byRound =>
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
      firedAction' = "DeliverPrevotesTo",
    }

  action DeliverPrecommitsTo(
    dst: Proc_t,
    h: Height_t,
    r: Round_t,
    v: Snapshot_t,
    signers: Set[Proc_t],
  ): bool =
    all {
      dst.in(Corr),
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
        seenPrecommit.setBy(dst, byHeight =>
          byHeight.setBy(h, byRound =>
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
      firedAction' = "DeliverPrecommitsTo",
    }

  action Prevote(p: Proc_t, v: Snapshot_t): bool = {
    val h = height.get(p)
    val r = round.get(p).get(h)
    val vote = if (SeenProposal(p, h, r, v) and LockAllows(p, h, v)) {
      v
    } else {
      NilSnapshot
    }
    val msg = { src: p, height: h, round: r, id: vote }
    all {
      ActiveHeight(p, h),
      r.in(Rounds),
      step.get(p).get(h) == "propose",
      IsSnapshot(v),
      msgsPrevote.get(h).get(r).forall(m => m.src != p),
      msgsPropose' = msgsPropose,
      msgsPrevote' =
        msgsPrevote.setBy(h, byRound =>
          byRound.setBy(r, old => old.union(Set(msg)))
        ),
      msgsPrecommit' = msgsPrecommit,
      seenPropose' = seenPropose,
      seenPrevote' = seenPrevote,
      seenPrecommit' = seenPrecommit,
      height' = height,
      round' = round,
      step' = step.setBy(p, byHeight => byHeight.set(h, "prevote")),
      decision' = decision,
      lockedValue' = lockedValue,
      lockedRound' = lockedRound,
      validValue' = validValue,
      validRound' = validRound,
      cachedProposal' = cachedProposal,
      cachedProposalRound' = cachedProposalRound,
      firedAction' = "Prevote",
    }
  }

  action PrecommitValue(p: Proc_t, v: Snapshot_t): bool = {
    val h = height.get(p)
    val r = round.get(p).get(h)
    val msg = { src: p, height: h, round: r, id: v }
    all {
      ActiveHeight(p, h),
      r.in(Rounds),
      step.get(p).get(h).in(Set("prevote", "precommit")),
      SeenProposal(p, h, r, v),
      Stream.get(h).get(r) == v,
      LocalPrevoteQuorum(p, h, r, v),
      not(HasPrecommitFrom(p, h, r)),
      msgsPropose' = msgsPropose,
      msgsPrevote' = msgsPrevote,
      msgsPrecommit' =
        msgsPrecommit.setBy(h, byRound =>
          byRound.setBy(r, old => old.union(Set(msg)))
        ),
      seenPropose' = seenPropose,
      seenPrevote' = seenPrevote,
      seenPrecommit' = seenPrecommit,
      height' = height,
      round' = round,
      step' = step.setBy(p, byHeight => byHeight.set(h, "precommit")),
      decision' = decision,
      lockedValue' = lockedValue.setBy(p, byHeight => byHeight.set(h, v)),
      lockedRound' = lockedRound.setBy(p, byHeight => byHeight.set(h, r)),
      validValue' = validValue.setBy(p, byHeight => byHeight.set(h, v)),
      validRound' = validRound.setBy(p, byHeight => byHeight.set(h, r)),
      cachedProposal' = cachedProposal,
      cachedProposalRound' = cachedProposalRound,
      firedAction' = "PrecommitValue",
    }
  }

  action PrecommitNilOnStreamChange(p: Proc_t): bool = {
    val h = height.get(p)
    val r = round.get(p).get(h)
    val stale = Stream.get(h).get(r)
    val msg = { src: p, height: h, round: r, id: NilSnapshot }
    all {
      ActiveHeight(p, h),
      (r + 1).in(Rounds),
      step.get(p).get(h).in(Set("prevote", "precommit")),
      LocalPrevoteQuorum(p, h, r, stale),
      Stream.get(h).get(r + 1) != stale,
      not(HasPrecommitFrom(p, h, r)),
      msgsPropose' = msgsPropose,
      msgsPrevote' = msgsPrevote,
      msgsPrecommit' =
        msgsPrecommit.setBy(h, byRound =>
          byRound.setBy(r, old => old.union(Set(msg)))
        ),
      seenPropose' = seenPropose,
      seenPrevote' = seenPrevote,
      seenPrecommit' = seenPrecommit,
      height' = height,
      round' = round,
      step' = step.setBy(p, byHeight => byHeight.set(h, "precommit")),
      decision' = decision,
      lockedValue' = lockedValue,
      lockedRound' = lockedRound,
      validValue' = validValue,
      validRound' = validRound,
      cachedProposal' = cachedProposal,
      cachedProposalRound' = cachedProposalRound,
      firedAction' = "PrecommitNilOnStreamChange",
    }
  }

  action AdvanceAfterPrecommitQuorum(p: Proc_t): bool = {
    val h = height.get(p)
    val oldRound = round.get(p).get(h)
    val nextRound = oldRound + 1
    val clear = ResampleOnNilPrecommit and LocalNilPrecommitCert(p, h, oldRound)
    all {
      ActiveHeight(p, h),
      nextRound.in(Rounds),
      LocalAnyPrecommitQuorum(p, h, oldRound),
      KeepMessages,
      height' = height,
      round' =
        round.setBy(p, byHeight => byHeight.set(h, nextRound)),
      step' = step.setBy(p, byHeight => byHeight.set(h, "propose")),
      decision' = decision,
      lockedValue' =
        lockedValue.setBy(p, byHeight =>
          byHeight.set(h, if (clear and lockedRound.get(p).get(h) == oldRound) {
            NilSnapshot
          } else {
            lockedValue.get(p).get(h)
          })
        ),
      lockedRound' =
        lockedRound.setBy(p, byHeight =>
          byHeight.set(h, if (clear and lockedRound.get(p).get(h) == oldRound) {
            NilRound
          } else {
            lockedRound.get(p).get(h)
          })
        ),
      validValue' =
        validValue.setBy(p, byHeight =>
          byHeight.set(h, if (clear and validRound.get(p).get(h) == oldRound) {
            NilSnapshot
          } else {
            validValue.get(p).get(h)
          })
        ),
      validRound' =
        validRound.setBy(p, byHeight =>
          byHeight.set(h, if (clear and validRound.get(p).get(h) == oldRound) {
            NilRound
          } else {
            validRound.get(p).get(h)
          })
        ),
      cachedProposal' =
        cachedProposal.setBy(p, byHeight =>
          byHeight.set(h, if (clear and cachedProposalRound.get(p).get(h) == oldRound) {
            NilSnapshot
          } else {
            cachedProposal.get(p).get(h)
          })
        ),
      cachedProposalRound' =
        cachedProposalRound.setBy(p, byHeight =>
          byHeight.set(h, if (clear and cachedProposalRound.get(p).get(h) == oldRound) {
            NilRound
          } else {
            cachedProposalRound.get(p).get(h)
          })
        ),
      firedAction' = "AdvanceAfterPrecommitQuorum",
    }
  }

  action Decide(p: Proc_t, v: Snapshot_t): bool = {
    val h = height.get(p)
    val r = round.get(p).get(h)
    all {
      ActiveHeight(p, h),
      IsSnapshot(v),
      decision.get(p).get(h) == NilSnapshot,
      SeenProposal(p, h, r, v),
      LocalPrecommitQuorum(p, h, r, v),
      KeepMessages,
      height' = height.set(p, h + 1),
      round' = round,
      step' = step.setBy(p, byHeight => byHeight.set(h, "decided")),
      decision' = decision.setBy(p, byHeight => byHeight.set(h, v)),
      lockedValue' = lockedValue,
      lockedRound' = lockedRound,
      validValue' = validValue,
      validRound' = validRound,
      cachedProposal' = cachedProposal,
      cachedProposalRound' = cachedProposalRound,
      firedAction' = "Decide",
    }
  }

  action SeedValueLockAt(
    p: Proc_t,
    h: Height_t,
    r: Round_t,
    v: Snapshot_t,
  ): bool =
    all {
      p.in(Corr),
      h.in(Heights),
      r.in(Rounds),
      IsSnapshot(v),
      KeepMessages,
      height' = height,
      round' = round,
      step' = step,
      decision' = decision,
      lockedValue' = lockedValue.setBy(p, byHeight => byHeight.set(h, v)),
      lockedRound' = lockedRound.setBy(p, byHeight => byHeight.set(h, r)),
      validValue' = validValue.setBy(p, byHeight => byHeight.set(h, v)),
      validRound' = validRound.setBy(p, byHeight => byHeight.set(h, r)),
      cachedProposal' = cachedProposal.setBy(p, byHeight => byHeight.set(h, v)),
      cachedProposalRound' = cachedProposalRound.setBy(p, byHeight => byHeight.set(h, r)),
      firedAction' = "SeedValueLockAt",
    }

  action SeedNilPrecommitCertificateAt(
    h: Height_t,
    r: Round_t,
    signers: Set[Proc_t],
  ): bool =
    all {
      h.in(Heights),
      r.in(Rounds),
      signers.forall(s => Corr.union(Faulty).contains(s)),
      msgsPropose' = msgsPropose,
      msgsPrevote' = msgsPrevote,
      msgsPrecommit' =
        msgsPrecommit.setBy(h, byRound =>
          byRound.setBy(r, old => old.union(signers.map(s => {
            src: s,
            height: h,
            round: r,
            id: NilSnapshot,
          })))
        ),
      seenPropose' = seenPropose,
      seenPrevote' = seenPrevote,
      seenPrecommit' =
        Corr.mapBy(dst =>
          seenPrecommit.get(dst).setBy(h, byRound =>
            byRound.setBy(r, old => old.union(signers.map(s => {
              src: s,
              height: h,
              round: r,
              id: NilSnapshot,
            })))
          )
        ),
      KeepValidatorState,
      firedAction' = "SeedNilPrecommitCertificateAt",
    }

  action Stutter = all {
    KeepValidatorState,
    KeepMessages,
    firedAction' = "Stutter",
  }

  action Next =
    nondet p = oneOf(Corr)
    any {
      InsertProposal(p),
      nondet v = oneOf(Snapshots)
      Prevote(p, v),
      nondet v = oneOf(Snapshots)
      PrecommitValue(p, v),
      PrecommitNilOnStreamChange(p),
      AdvanceAfterPrecommitQuorum(p),
      nondet v = oneOf(Snapshots)
      Decide(p, v),
      nondet from = oneOf(Corr.union(Faulty))
      nondet h = oneOf(Heights)
      nondet r = oneOf(Rounds)
      nondet v = oneOf(Snapshots)
      DeliverProposal(p, from, h, r, v),
      nondet h = oneOf(Heights)
      nondet r = oneOf(Rounds)
      nondet v = oneOf(VoteValues)
      nondet signers = oneOf(powerset(Corr.union(Faulty)))
      DeliverPrevotesTo(p, h, r, v, signers),
      nondet h = oneOf(Heights)
      nondet r = oneOf(Rounds)
      nondet v = oneOf(VoteValues)
      nondet signers = oneOf(powerset(Corr.union(Faulty)))
      DeliverPrecommitsTo(p, h, r, v, signers),
      Stutter,
    }

  val PerHeightAgreement =
    Heights.forall(h =>
      tuples(Corr, Corr).forall(((p, q)) =>
        decision.get(p).get(h) == NilSnapshot or
        decision.get(q).get(h) == NilSnapshot or
        decision.get(p).get(h) == decision.get(q).get(h)
      )
    )

  val HeightCursorSequential =
    Corr.forall(p =>
      CursorHeights.contains(height.get(p)) and
      Heights.forall(h =>
        if (h < height.get(p)) {
          decision.get(p).get(h) != NilSnapshot
        } else {
          decision.get(p).get(h) == NilSnapshot
        }
      )
    )

  val FutureHeightsRemainPristine =
    Corr.forall(p =>
      Heights.forall(h =>
        h <= height.get(p) or (
          round.get(p).get(h) == 0 and
          step.get(p).get(h) == "propose" and
          lockedValue.get(p).get(h) == NilSnapshot and
          lockedRound.get(p).get(h) == NilRound and
          validValue.get(p).get(h) == NilSnapshot and
          validRound.get(p).get(h) == NilRound and
          cachedProposal.get(p).get(h) == NilSnapshot and
          cachedProposalRound.get(p).get(h) == NilRound
        )
      )
    )

  val DecisionsHaveLocalCommitQuorum =
    Corr.forall(p =>
      Heights.forall(h =>
        decision.get(p).get(h) == NilSnapshot or
        Rounds.exists(r =>
          LocalPrecommitQuorum(p, h, r, decision.get(p).get(h))
        )
      )
    )

  val Safety =
    PerHeightAgreement and
    HeightCursorSequential and
    FutureHeightsRemainPristine and
    DecisionsHaveLocalCommitQuorum
}

module CrosslinkHeightedRoundTest {
  import CrosslinkHeightedRound.* from "./CrosslinkHeightedRound"
  export CrosslinkHeightedRound.*

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

  action SeedMixedPrecommitSetAt(
    h: Height_t,
    r: Round_t,
    valueSigners: Set[Proc_t],
    nilSigners: Set[Proc_t],
    v: Snapshot_t,
  ): bool = {
    val allSigners = valueSigners.union(nilSigners)
    val votes =
      valueSigners.map(s => { src: s, height: h, round: r, id: v })
        .union(nilSigners.map(s => {
          src: s,
          height: h,
          round: r,
          id: NilSnapshot,
        }))
    all {
      h.in(Heights),
      r.in(Rounds),
      IsSnapshot(v),
      valueSigners.intersect(nilSigners) == Set(),
      allSigners.forall(s => Corr.union(Faulty).contains(s)),
      msgsPropose' = msgsPropose,
      msgsPrevote' = msgsPrevote,
      msgsPrecommit' =
        msgsPrecommit.setBy(h, byRound =>
          byRound.setBy(r, old => old.union(votes))
        ),
      seenPropose' = seenPropose,
      seenPrevote' = seenPrevote,
      seenPrecommit' =
        Corr.mapBy(dst =>
          seenPrecommit.get(dst).setBy(h, byRound =>
            byRound.setBy(r, old => old.union(votes))
          )
        ),
      KeepValidatorState,
      firedAction' = "SeedMixedPrecommitSetAt",
    }
  }

  run nilResamplingDoesNotClearOtherHeightStateTest = {
    Init
      .then(SeedValueLockAt("p1", 1, 0, "h1r0"))
      .then(SeedValueLockAt("p1", 2, 0, "h2r0"))
      .then(SeedNilPrecommitCertificateAt(1, 0, Set("p1", "p2", "p3")))
      .then(AdvanceAfterPrecommitQuorum("p1"))
      .then(all {
        assert(round.get("p1").get(1) == 1),
        assert(lockedValue.get("p1").get(1) == NilSnapshot),
        assert(cachedProposal.get("p1").get(1) == NilSnapshot),
        assert(lockedValue.get("p1").get(2) == "h2r0"),
        assert(cachedProposal.get("p1").get(2) == "h2r0"),
        unchangedAll,
      })
  }

  run mixedPrecommitQuorumDoesNotClearHeightedLockTest = {
    Init
      .then(SeedValueLockAt("p1", 1, 0, "h1r0"))
      .then(SeedMixedPrecommitSetAt(1, 0, Set("p1", "p2"), Set("p3"), "h1r0"))
      .then(AdvanceAfterPrecommitQuorum("p1"))
      .then(all {
        assert(round.get("p1").get(1) == 1),
        assert(lockedValue.get("p1").get(1) == "h1r0"),
        assert(validValue.get("p1").get(1) == "h1r0"),
        assert(cachedProposal.get("p1").get(1) == "h1r0"),
        assert(cachedProposalRound.get("p1").get(1) == 0),
        unchangedAll,
      })
  }

  run cannotDecideSecondHeightBeforeFirstHeightTest = {
    Init
      .then(SeedValueLockAt("p1", 2, 0, "h2r0"))
      .then(Decide("p1", "h2r0"))
      .fail()
  }

  run oneHeightDecisionAdvancesOnlyDecidingValidatorTest = {
    Init
      .then(InsertProposal("p1"))
      .then(DeliverProposal("p1", "p1", 1, 0, "h1r0"))
      .then(DeliverProposal("p2", "p1", 1, 0, "h1r0"))
      .then(DeliverProposal("p3", "p1", 1, 0, "h1r0"))
      .then(Prevote("p1", "h1r0"))
      .then(Prevote("p2", "h1r0"))
      .then(Prevote("p3", "h1r0"))
      .then(DeliverPrevotesTo("p1", 1, 0, "h1r0", Set("p1", "p2", "p3")))
      .then(DeliverPrevotesTo("p2", 1, 0, "h1r0", Set("p1", "p2", "p3")))
      .then(DeliverPrevotesTo("p3", 1, 0, "h1r0", Set("p1", "p2", "p3")))
      .then(PrecommitValue("p1", "h1r0"))
      .then(PrecommitValue("p2", "h1r0"))
      .then(PrecommitValue("p3", "h1r0"))
      .then(DeliverPrecommitsTo("p1", 1, 0, "h1r0", Set("p1", "p2", "p3")))
      .then(Decide("p1", "h1r0"))
      .then(all {
        assert(height.get("p1") == 2),
        assert(height.get("p2") == 1),
        assert(decision.get("p1").get(1) == "h1r0"),
        assert(Safety),
        unchangedAll,
      })
  }
}

module CrosslinkHeightedRoundModel {
  import CrosslinkHeightedRoundTest(
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
      1 -> Map(0 -> "h1r0", 1 -> "h1r1"),
      2 -> Map(0 -> "h2r0", 1 -> "h2r1"),
    ),
    Snapshots = Set("h1r0", "h1r1", "h2r0", "h2r1"),
    ResampleOnNilPrecommit = true,
  ).*
}
