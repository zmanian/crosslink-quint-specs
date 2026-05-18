// -*- mode: Bluespec; -*-
module CrosslinkResampling {
  /*
   A small Crosslink/Tenderlink model derived from the current Quint
   Tendermint examples, focused on one question:

     What changes when a 2f+1 PRECOMMIT nil certificate lets the next
     round resample Crosslink's moving PoW stream?

   This is not yet a full Tendermint accountability model. It intentionally
   isolates the Crosslink-specific moving-value part while keeping observer
   evidence separate from protocol message state:

   - BFT values are PoW snapshots sampled from Stream(round), modelling the
     implementation's current "head - sigma" proposal.
   - A nil-precommit quorum for round r is a round-abandon certificate.
   - In the resampling variant, that certificate clears Crosslink's proposal
     cache and same-round Tendermint valid/lock state for r, allowing the next
     proposer to sample Stream(r + 1).
   - In the current/sticky variant, the proposal cache continues to carry the
     stale sample into the next round, and same-round valid/lock state blocks
     fresh voting.
   - Older Tendermint validValue/lockedValue state is preserved; the nil
     precommit certificate is only an unlock certificate for its own round.
   - The unlock rule keeps Tendermint's value-lock safety argument: retained
     locks are backed by value precommits, and a nil certificate can coexist
     with at most f correct same-round value locks, not a commit-capable quorum.
   */

  type Proc_t = str
  type Snapshot_t = str
  type Round_t = int
  type Step_t = str

  const Corr: Set[Proc_t]
  const Faulty: Set[Proc_t]
  const N: int
  const T: int
  const VotingPower: Proc_t -> int
  const TotalVotingPower: int
  const FaultyVotingPowerBound: int
  const QuorumVotingPower: int
  const MaxRound: Round_t
  const Proposer: Round_t -> Proc_t
  const Stream: Round_t -> Snapshot_t
  const Snapshots: Set[Snapshot_t]
  const StructurallyValid: Snapshot_t -> bool
  const PowChainValid: Snapshot_t -> bool
  const FinalityCandidateValid: Snapshot_t -> bool
  const ResampleOnNilPrecommit: bool

  pure val Rounds = 0.to(MaxRound)
  pure val NilRound = -1
  pure val NilSnapshot = "None"
  pure val THRESHOLD2 = QuorumVotingPower

  pure def VotingPowerOf(voters: Set[Proc_t]): int =
    voters.fold(0, (acc, p) => acc + VotingPower.get(p))

  assume corr_and_faulty_disjoint = Corr.intersect(Faulty) == Set()
  assume corr_and_faulty_make_n = N == size(Corr.union(Faulty))
  assume faulty_at_threshold = size(Faulty) <= T
  assume validator_power_is_positive =
    Corr.union(Faulty).forall(p => VotingPower.get(p) > 0)
  assume total_voting_power_matches_validator_set =
    TotalVotingPower == VotingPowerOf(Corr.union(Faulty))
  assume faulty_power_at_threshold =
    VotingPowerOf(Faulty) <= FaultyVotingPowerBound
  assume quorum_intersection_has_correct_power =
    2 * QuorumVotingPower - TotalVotingPower > FaultyVotingPowerBound
  assume nil_is_not_snapshot = not(Snapshots.contains(NilSnapshot))
  assume streams_are_snapshots =
    Rounds.forall(r => Snapshots.contains(Stream.get(r)))

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

  var round: Proc_t -> Round_t
  var step: Proc_t -> Step_t
  var decision: Proc_t -> Snapshot_t
  var lockedValue: Proc_t -> Snapshot_t
  var lockedRound: Proc_t -> Round_t
  var validValue: Proc_t -> Snapshot_t
  var validRound: Proc_t -> Round_t
  var cachedProposal: Proc_t -> Snapshot_t
  var cachedProposalRound: Proc_t -> Round_t
  var msgsPropose: Round_t -> Set[Propose_t]
  var msgsPrevote: Round_t -> Set[Vote_t]
  var msgsPrecommit: Round_t -> Set[Vote_t]
  var evidencePropose: Round_t -> Set[Propose_t]
  var evidencePrevote: Round_t -> Set[Vote_t]
  var evidencePrecommit: Round_t -> Set[Vote_t]
  var evidenceFatPointer: Set[FatPointer_t]
  var firedAction: str

  pure def IsValidSnapshot(v: Snapshot_t): bool =
    Snapshots.contains(v)

  pure def StaticProposalValidity(v: Snapshot_t): bool =
    IsValidSnapshot(v) and
    StructurallyValid.get(v) and
    PowChainValid.get(v) and
    FinalityCandidateValid.get(v)

  pure def IsFreshForRound(r: Round_t, v: Snapshot_t): bool =
    Stream.get(r) == v

  pure def ValidProposalForRound(r: Round_t, v: Snapshot_t): bool =
    StaticProposalValidity(v) and IsFreshForRound(r, v)

  pure def StreamChangedAfter(r: Round_t): bool =
    (r + 1).in(Rounds) and Stream.get(r + 1) != Stream.get(r)

  pure def Voters(votes: Set[Vote_t]): Set[Proc_t] =
    votes.map(m => m.src)

  def PrevoteQuorum(r: Round_t, v: Snapshot_t): bool =
    VotingPowerOf(Voters(msgsPrevote.get(r).filter(m => m.id == v))) >= THRESHOLD2

  def PrecommitQuorum(r: Round_t, v: Snapshot_t): bool =
    VotingPowerOf(Voters(msgsPrecommit.get(r).filter(m => m.id == v))) >= THRESHOLD2

  def NilPrecommitCert(r: Round_t): bool =
    PrecommitQuorum(r, NilSnapshot)

  def ObservedPrecommitQuorum(r: Round_t, v: Snapshot_t): bool =
    VotingPowerOf(Voters(evidencePrecommit.get(r).filter(m => m.id == v))) >= THRESHOLD2

  def ObservedNilPrecommitCert(r: Round_t): bool =
    ObservedPrecommitQuorum(r, NilSnapshot)

  def HasPrecommitFrom(p: Proc_t, r: Round_t): bool =
    msgsPrecommit.get(r).exists(m => m.src == p)

  def HasValuePrecommitFrom(p: Proc_t, r: Round_t, v: Snapshot_t): bool =
    msgsPrecommit.get(r).exists(m => m.src == p and m.id == v)

  def HasNilPrecommitFrom(p: Proc_t, r: Round_t): bool =
    msgsPrecommit.get(r).exists(m => m.src == p and m.id == NilSnapshot)

  def ObservedValuePrecommitFrom(p: Proc_t, r: Round_t, v: Snapshot_t): bool =
    evidencePrecommit.get(r).exists(m => m.src == p and m.id == v)

  def ObservedNilPrecommitFrom(p: Proc_t, r: Round_t): bool =
    evidencePrecommit.get(r).exists(m => m.src == p and m.id == NilSnapshot)

  def ValidFatPointer(fp: FatPointer_t): bool =
    fp.round.in(Rounds) and
    IsValidSnapshot(fp.id) and
    fp.signers.forall(p => Corr.union(Faulty).contains(p)) and
    VotingPowerOf(fp.signers) >= QuorumVotingPower and
    fp.signers.forall(p => ObservedValuePrecommitFrom(p, fp.round, fp.id))

  def ObservedFatPointerQuorum(r: Round_t, v: Snapshot_t): bool =
    evidenceFatPointer.exists(fp =>
      fp.round == r and fp.id == v and ValidFatPointer(fp)
    )

  def CorrectValueLocks(r: Round_t, v: Snapshot_t): Set[Proc_t] =
    Corr.filter(p => lockedRound.get(p) == r and lockedValue.get(p) == v)

  def HasProposal(r: Round_t, v: Snapshot_t): bool =
    msgsPropose.get(r).exists(m =>
      m.src == Proposer.get(r) and m.round == r and m.proposal == v
    )

  def StickyOrStreamProposal(p: Proc_t): Snapshot_t =
    if (validValue.get(p) == NilSnapshot) {
      if (cachedProposal.get(p) == NilSnapshot) {
        Stream.get(round.get(p))
      } else {
        cachedProposal.get(p)
      }
    } else {
      validValue.get(p)
    }

  action Init = all {
    round' = Corr.mapBy(_ => 0),
    step' = Corr.mapBy(_ => "propose"),
    decision' = Corr.mapBy(_ => NilSnapshot),
    lockedValue' = Corr.mapBy(_ => NilSnapshot),
    lockedRound' = Corr.mapBy(_ => NilRound),
    validValue' = Corr.mapBy(_ => NilSnapshot),
    validRound' = Corr.mapBy(_ => NilRound),
    cachedProposal' = Corr.mapBy(_ => NilSnapshot),
    cachedProposalRound' = Corr.mapBy(_ => NilRound),
    msgsPropose' = Rounds.mapBy(_ => Set()),
    msgsPrevote' = Rounds.mapBy(_ => Set()),
    msgsPrecommit' = Rounds.mapBy(_ => Set()),
    evidencePropose' = Rounds.mapBy(_ => Set()),
    evidencePrevote' = Rounds.mapBy(_ => Set()),
    evidencePrecommit' = Rounds.mapBy(_ => Set()),
    evidenceFatPointer' = Set(),
    firedAction' = "Init",
  }

  action BroadcastProposal(p: Proc_t, r: Round_t, v: Snapshot_t, vr: Round_t): bool =
    all {
      msgsPropose' = msgsPropose.setBy(r, old => old.union(Set({
        src: p,
        round: r,
        proposal: v,
        validRound: vr,
      }))),
      evidencePropose' = evidencePropose.setBy(r, old => old.union(Set({
        src: p,
        round: r,
        proposal: v,
        validRound: vr,
      }))),
    }

  action BroadcastPrevote(p: Proc_t, r: Round_t, v: Snapshot_t): bool =
    all {
      msgsPrevote' = msgsPrevote.setBy(r, old => old.union(Set({
        src: p,
        round: r,
        id: v,
      }))),
      evidencePrevote' = evidencePrevote.setBy(r, old => old.union(Set({
        src: p,
        round: r,
        id: v,
      }))),
    }

  action BroadcastPrecommit(p: Proc_t, r: Round_t, v: Snapshot_t): bool =
    all {
      msgsPrecommit' = msgsPrecommit.setBy(r, old => old.union(Set({
        src: p,
        round: r,
        id: v,
      }))),
      evidencePrecommit' = evidencePrecommit.setBy(r, old => old.union(Set({
        src: p,
        round: r,
        id: v,
      }))),
    }

  action ObservePrecommitEvidence(p: Proc_t, r: Round_t, v: Snapshot_t): bool =
    all {
      p.in(Corr.union(Faulty)),
      r.in(Rounds),
      v == NilSnapshot or IsValidSnapshot(v),
      evidencePrecommit' = evidencePrecommit.setBy(r, old => old.union(Set({
        src: p,
        round: r,
        id: v,
      }))),
    }

  action ObserveFatPointerEvidence(
    r: Round_t,
    v: Snapshot_t,
    signers: Set[Proc_t],
  ): bool = {
    val fp = { round: r, id: v, signers: signers }
    all {
      ValidFatPointer(fp),
      evidenceFatPointer' = evidenceFatPointer.union(Set(fp)),
    }
  }

  action InsertProposal(p: Proc_t): bool = {
    val r = round.get(p)
    val proposal = StickyOrStreamProposal(p)
    all {
      p == Proposer.get(r),
      step.get(p) == "propose",
      msgsPropose.get(r).forall(m => m.src != p),
      BroadcastProposal(p, r, proposal, validRound.get(p)),
      firedAction' = "InsertProposal",
      round' = round,
      step' = step,
      decision' = decision,
      lockedValue' = lockedValue,
      lockedRound' = lockedRound,
      validValue' = validValue,
      validRound' = validRound,
      cachedProposal' = cachedProposal,
      cachedProposalRound' = cachedProposalRound,
      msgsPrevote' = msgsPrevote,
      msgsPrecommit' = msgsPrecommit,
      evidencePrevote' = evidencePrevote,
      evidencePrecommit' = evidencePrecommit,
      evidenceFatPointer' = evidenceFatPointer,
    }
  }

  action UponProposalPrevote(p: Proc_t, v: Snapshot_t): bool = {
    val r = round.get(p)
    val vote = if (
      ValidProposalForRound(r, v) and
      (lockedRound.get(p) == NilRound or lockedValue.get(p) == v)
    ) {
      v
    } else {
      NilSnapshot
    }
    all {
      step.get(p) == "propose",
      HasProposal(r, v),
      BroadcastPrevote(p, r, vote),
      step' = step.set(p, "prevote"),
      firedAction' = "UponProposalPrevote",
      round' = round,
      decision' = decision,
      lockedValue' = lockedValue,
      lockedRound' = lockedRound,
      validValue' = validValue,
      validRound' = validRound,
      cachedProposal' = cachedProposal,
      cachedProposalRound' = cachedProposalRound,
      msgsPropose' = msgsPropose,
      msgsPrecommit' = msgsPrecommit,
      evidencePropose' = evidencePropose,
      evidencePrecommit' = evidencePrecommit,
      evidenceFatPointer' = evidenceFatPointer,
    }
  }

  action UponValuePrevoteQuorum(p: Proc_t, v: Snapshot_t): bool = {
    val r = round.get(p)
    all {
      step.get(p).in(Set("prevote", "precommit")),
      HasProposal(r, v),
      ValidProposalForRound(r, v),
      PrevoteQuorum(r, v),
      not(HasPrecommitFrom(p, r)),
      BroadcastPrecommit(p, r, v),
      step' = step.set(p, "precommit"),
      lockedValue' = lockedValue.set(p, v),
      lockedRound' = lockedRound.set(p, r),
      validValue' = validValue.set(p, v),
      validRound' = validRound.set(p, r),
      cachedProposal' = cachedProposal,
      cachedProposalRound' = cachedProposalRound,
      firedAction' = "UponValuePrevoteQuorum",
      round' = round,
      decision' = decision,
      msgsPropose' = msgsPropose,
      msgsPrevote' = msgsPrevote,
      evidencePropose' = evidencePropose,
      evidencePrevote' = evidencePrevote,
      evidenceFatPointer' = evidenceFatPointer,
    }
  }

  action UponStreamChangePrecommitNil(p: Proc_t): bool = {
    val r = round.get(p)
    all {
      step.get(p).in(Set("prevote", "precommit")),
      StreamChangedAfter(r),
      not(HasPrecommitFrom(p, r)),
      BroadcastPrecommit(p, r, NilSnapshot),
      step' = step.set(p, "precommit"),
      firedAction' = "UponStreamChangePrecommitNil",
      round' = round,
      decision' = decision,
      lockedValue' = lockedValue,
      lockedRound' = lockedRound,
      validValue' = validValue,
      validRound' = validRound,
      cachedProposal' = cachedProposal,
      cachedProposalRound' = cachedProposalRound,
      msgsPropose' = msgsPropose,
      msgsPrevote' = msgsPrevote,
      evidencePropose' = evidencePropose,
      evidencePrevote' = evidencePrevote,
      evidenceFatPointer' = evidenceFatPointer,
    }
  }

  action TimeoutProposePrevoteNil(p: Proc_t): bool = {
    val r = round.get(p)
    all {
      step.get(p) == "propose",
      not(HasPrecommitFrom(p, r)),
      BroadcastPrevote(p, r, NilSnapshot),
      step' = step.set(p, "prevote"),
      firedAction' = "TimeoutProposePrevoteNil",
      round' = round,
      decision' = decision,
      lockedValue' = lockedValue,
      lockedRound' = lockedRound,
      validValue' = validValue,
      validRound' = validRound,
      cachedProposal' = cachedProposal,
      cachedProposalRound' = cachedProposalRound,
      msgsPropose' = msgsPropose,
      msgsPrecommit' = msgsPrecommit,
      evidencePropose' = evidencePropose,
      evidencePrecommit' = evidencePrecommit,
      evidenceFatPointer' = evidenceFatPointer,
    }
  }

  action TimeoutPrevotePrecommitNil(p: Proc_t): bool = {
    val r = round.get(p)
    all {
      step.get(p) == "prevote",
      not(HasPrecommitFrom(p, r)),
      BroadcastPrecommit(p, r, NilSnapshot),
      step' = step.set(p, "precommit"),
      firedAction' = "TimeoutPrevotePrecommitNil",
      round' = round,
      decision' = decision,
      lockedValue' = lockedValue,
      lockedRound' = lockedRound,
      validValue' = validValue,
      validRound' = validRound,
      cachedProposal' = cachedProposal,
      cachedProposalRound' = cachedProposalRound,
      msgsPropose' = msgsPropose,
      msgsPrevote' = msgsPrevote,
      evidencePropose' = evidencePropose,
      evidencePrevote' = evidencePrevote,
      evidenceFatPointer' = evidenceFatPointer,
    }
  }

  action TimeoutPrecommitStartNextRound(p: Proc_t): bool = {
    val oldRound = round.get(p)
    val nextRound = oldRound + 1
    all {
      nextRound.in(Rounds),
      step.get(p) == "precommit",
      round' = round.set(p, nextRound),
      step' = step.set(p, "propose"),
      firedAction' = "TimeoutPrecommitStartNextRound",
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
      evidencePropose' = evidencePropose,
      evidencePrevote' = evidencePrevote,
      evidencePrecommit' = evidencePrecommit,
      evidenceFatPointer' = evidenceFatPointer,
    }
  }

  action StartNextRoundAfterPrecommitQuorum(p: Proc_t): bool = {
    val oldRound = round.get(p)
    val nextRound = oldRound + 1
    val clearSameRoundCache = ResampleOnNilPrecommit and NilPrecommitCert(oldRound)
    all {
      nextRound.in(Rounds),
      VotingPowerOf(Voters(msgsPrecommit.get(oldRound))) >= THRESHOLD2,
      round' = round.set(p, nextRound),
      step' = step.set(p, "propose"),
      validValue' =
        if (clearSameRoundCache and validRound.get(p) == oldRound) {
          validValue.set(p, NilSnapshot)
        } else {
          validValue
        },
      validRound' =
        if (clearSameRoundCache and validRound.get(p) == oldRound) {
          validRound.set(p, NilRound)
        } else {
          validRound
        },
      lockedValue' =
        if (clearSameRoundCache and lockedRound.get(p) == oldRound) {
          lockedValue.set(p, NilSnapshot)
        } else {
          lockedValue
        },
      lockedRound' =
        if (clearSameRoundCache and lockedRound.get(p) == oldRound) {
          lockedRound.set(p, NilRound)
        } else {
          lockedRound
        },
      cachedProposal' =
        if (clearSameRoundCache and cachedProposalRound.get(p) == oldRound) {
          cachedProposal.set(p, NilSnapshot)
        } else {
          cachedProposal
        },
      cachedProposalRound' =
        if (clearSameRoundCache and cachedProposalRound.get(p) == oldRound) {
          cachedProposalRound.set(p, NilRound)
        } else {
          cachedProposalRound
        },
      firedAction' = "StartNextRoundAfterPrecommitQuorum",
      decision' = decision,
      msgsPropose' = msgsPropose,
      msgsPrevote' = msgsPrevote,
      msgsPrecommit' = msgsPrecommit,
      evidencePropose' = evidencePropose,
      evidencePrevote' = evidencePrevote,
      evidencePrecommit' = evidencePrecommit,
      evidenceFatPointer' = evidenceFatPointer,
    }
  }

  action ApplyLateNilPrecommitCertificate(p: Proc_t, certRound: Round_t): bool = {
    all {
      certRound.in(Rounds),
      certRound < round.get(p),
      ResampleOnNilPrecommit,
      NilPrecommitCert(certRound),
      round' = round,
      step' = step,
      validValue' =
        if (validRound.get(p) == certRound) {
          validValue.set(p, NilSnapshot)
        } else {
          validValue
        },
      validRound' =
        if (validRound.get(p) == certRound) {
          validRound.set(p, NilRound)
        } else {
          validRound
        },
      lockedValue' =
        if (lockedRound.get(p) == certRound) {
          lockedValue.set(p, NilSnapshot)
        } else {
          lockedValue
        },
      lockedRound' =
        if (lockedRound.get(p) == certRound) {
          lockedRound.set(p, NilRound)
        } else {
          lockedRound
        },
      cachedProposal' =
        if (cachedProposalRound.get(p) == certRound) {
          cachedProposal.set(p, NilSnapshot)
        } else {
          cachedProposal
        },
      cachedProposalRound' =
        if (cachedProposalRound.get(p) == certRound) {
          cachedProposalRound.set(p, NilRound)
        } else {
          cachedProposalRound
        },
      firedAction' = "ApplyLateNilPrecommitCertificate",
      decision' = decision,
      msgsPropose' = msgsPropose,
      msgsPrevote' = msgsPrevote,
      msgsPrecommit' = msgsPrecommit,
      evidencePropose' = evidencePropose,
      evidencePrevote' = evidencePrevote,
      evidencePrecommit' = evidencePrecommit,
      evidenceFatPointer' = evidenceFatPointer,
    }
  }

  action Decide(p: Proc_t, r: Round_t, v: Snapshot_t): bool = all {
    decision.get(p) == NilSnapshot,
    HasProposal(r, v),
    ValidProposalForRound(r, v),
    PrecommitQuorum(r, v),
    decision' = decision.set(p, v),
    step' = step.set(p, "decided"),
    firedAction' = "Decide",
    round' = round,
    lockedValue' = lockedValue,
    lockedRound' = lockedRound,
    validValue' = validValue,
    validRound' = validRound,
    cachedProposal' = cachedProposal,
    cachedProposalRound' = cachedProposalRound,
    msgsPropose' = msgsPropose,
    msgsPrevote' = msgsPrevote,
    msgsPrecommit' = msgsPrecommit,
    evidencePropose' = evidencePropose,
    evidencePrevote' = evidencePrevote,
    evidencePrecommit' = evidencePrecommit,
    evidenceFatPointer' = evidenceFatPointer,
  }

  action SeedAbandonedRoundStateAt(p: Proc_t, r: Round_t): bool = {
    val stale = Stream.get(r)
    all {
      r.in(Rounds),
      p.in(Corr),
      round' = round.set(p, r),
      step' = step.set(p, "precommit"),
      lockedValue' = lockedValue,
      lockedRound' = lockedRound,
      validValue' = validValue,
      validRound' = validRound,
      cachedProposal' = cachedProposal.set(p, stale),
      cachedProposalRound' = cachedProposalRound.set(p, r),
      BroadcastPrecommit(p, r, NilSnapshot),
      firedAction' = "SeedAbandonedRoundState",
      decision' = decision,
      msgsPropose' = msgsPropose,
      msgsPrevote' = msgsPrevote,
      evidencePropose' = evidencePropose,
      evidencePrevote' = evidencePrevote,
      evidenceFatPointer' = evidenceFatPointer,
    }
  }

  action SeedAbandonedRoundState(p: Proc_t): bool =
    SeedAbandonedRoundStateAt(p, 0)

  action SeedValidNilPrecommitStateAt(p: Proc_t, r: Round_t): bool = {
    val stale = Stream.get(r)
    all {
      r.in(Rounds),
      p.in(Corr),
      round' = round.set(p, r),
      step' = step.set(p, "precommit"),
      lockedValue' = lockedValue,
      lockedRound' = lockedRound,
      validValue' = validValue.set(p, stale),
      validRound' = validRound.set(p, r),
      cachedProposal' = cachedProposal.set(p, stale),
      cachedProposalRound' = cachedProposalRound.set(p, r),
      BroadcastPrecommit(p, r, NilSnapshot),
      firedAction' = "SeedValidNilPrecommitState",
      decision' = decision,
      msgsPropose' = msgsPropose,
      msgsPrevote' = msgsPrevote,
      evidencePropose' = evidencePropose,
      evidencePrevote' = evidencePrevote,
      evidenceFatPointer' = evidenceFatPointer,
    }
  }

  action SeedValidNilPrecommitState(p: Proc_t): bool =
    SeedValidNilPrecommitStateAt(p, 0)

  action SeedSameRoundValueLockAt(p: Proc_t, r: Round_t): bool = {
    val locked = Stream.get(r)
    all {
      r.in(Rounds),
      p.in(Corr),
      round' = round.set(p, r),
      step' = step.set(p, "precommit"),
      lockedValue' = lockedValue.set(p, locked),
      lockedRound' = lockedRound.set(p, r),
      validValue' = validValue.set(p, locked),
      validRound' = validRound.set(p, r),
      cachedProposal' = cachedProposal,
      cachedProposalRound' = cachedProposalRound,
      BroadcastPrecommit(p, r, locked),
      firedAction' = "SeedSameRoundValueLock",
      decision' = decision,
      msgsPropose' = msgsPropose,
      msgsPrevote' = msgsPrevote,
      evidencePropose' = evidencePropose,
      evidencePrevote' = evidencePrevote,
      evidenceFatPointer' = evidenceFatPointer,
    }
  }

  action SeedSameRoundValueLock(p: Proc_t): bool =
    SeedSameRoundValueLockAt(p, 0)

  action SeedTimedOutSameRoundValueLock(p: Proc_t): bool = {
    val r = 0
    val nextRound = 1
    val locked = Stream.get(r)
    all {
      r.in(Rounds),
      nextRound.in(Rounds),
      p.in(Corr),
      round' = round.set(p, nextRound),
      step' = step.set(p, "propose"),
      lockedValue' = lockedValue.set(p, locked),
      lockedRound' = lockedRound.set(p, r),
      validValue' = validValue.set(p, locked),
      validRound' = validRound.set(p, r),
      cachedProposal' = cachedProposal,
      cachedProposalRound' = cachedProposalRound,
      BroadcastPrecommit(p, r, locked),
      firedAction' = "SeedTimedOutSameRoundValueLock",
      decision' = decision,
      msgsPropose' = msgsPropose,
      msgsPrevote' = msgsPrevote,
      evidencePropose' = evidencePropose,
      evidencePrevote' = evidencePrevote,
      evidenceFatPointer' = evidenceFatPointer,
    }
  }

  action SeedFaultyNilPrecommitAt(p: Proc_t, r: Round_t): bool = {
    all {
      r.in(Rounds),
      p.in(Faulty),
      round' = round,
      step' = step,
      lockedValue' = lockedValue,
      lockedRound' = lockedRound,
      validValue' = validValue,
      validRound' = validRound,
      cachedProposal' = cachedProposal,
      cachedProposalRound' = cachedProposalRound,
      BroadcastPrecommit(p, r, NilSnapshot),
      firedAction' = "SeedFaultyNilPrecommit",
      decision' = decision,
      msgsPropose' = msgsPropose,
      msgsPrevote' = msgsPrevote,
      evidencePropose' = evidencePropose,
      evidencePrevote' = evidencePrevote,
      evidenceFatPointer' = evidenceFatPointer,
    }
  }

  action SeedFaultyNilPrecommit(p: Proc_t): bool =
    SeedFaultyNilPrecommitAt(p, 0)

  action SeedOlderLockWithNilPrecommit(p: Proc_t): bool = {
    val activeRound = 1
    val lockRound = 0
    val locked = Stream.get(lockRound)
    all {
      activeRound.in(Rounds),
      lockRound.in(Rounds),
      p.in(Corr),
      round' = round.set(p, activeRound),
      step' = step.set(p, "precommit"),
      lockedValue' = lockedValue.set(p, locked),
      lockedRound' = lockedRound.set(p, lockRound),
      validValue' = validValue.set(p, locked),
      validRound' = validRound.set(p, lockRound),
      cachedProposal' = cachedProposal,
      cachedProposalRound' = cachedProposalRound,
      msgsPrecommit' = msgsPrecommit
        .setBy(lockRound, old => old.union(Set({
          src: p,
          round: lockRound,
          id: locked,
        })))
        .setBy(activeRound, old => old.union(Set({
          src: p,
          round: activeRound,
          id: NilSnapshot,
        }))),
      evidencePrecommit' = evidencePrecommit
        .setBy(lockRound, old => old.union(Set({
          src: p,
          round: lockRound,
          id: locked,
        })))
        .setBy(activeRound, old => old.union(Set({
          src: p,
          round: activeRound,
          id: NilSnapshot,
        }))),
      firedAction' = "SeedOlderLockWithNilPrecommit",
      decision' = decision,
      msgsPropose' = msgsPropose,
      msgsPrevote' = msgsPrevote,
      evidencePropose' = evidencePropose,
      evidencePrevote' = evidencePrevote,
      evidenceFatPointer' = evidenceFatPointer,
    }
  }

  action SeedCorrectPrecommitEvidence(p: Proc_t, r: Round_t, v: Snapshot_t): bool =
    all {
      p.in(Corr),
      r.in(Rounds),
      IsValidSnapshot(v),
      ObservePrecommitEvidence(p, r, v),
      firedAction' = "SeedCorrectPrecommitEvidence",
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
      evidencePropose' = evidencePropose,
      evidencePrevote' = evidencePrevote,
      evidenceFatPointer' = evidenceFatPointer,
    }

  action SeedFaultyPrecommitEvidence(p: Proc_t, r: Round_t, v: Snapshot_t): bool =
    all {
      p.in(Faulty),
      r.in(Rounds),
      IsValidSnapshot(v),
      ObservePrecommitEvidence(p, r, v),
      firedAction' = "SeedFaultyPrecommitEvidence",
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
      evidencePropose' = evidencePropose,
      evidencePrevote' = evidencePrevote,
      evidenceFatPointer' = evidenceFatPointer,
    }

  action SeedFatPointerEvidence(
    r: Round_t,
    v: Snapshot_t,
    signers: Set[Proc_t],
  ): bool =
    all {
      ObserveFatPointerEvidence(r, v, signers),
      firedAction' = "SeedFatPointerEvidence",
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
      evidencePropose' = evidencePropose,
      evidencePrevote' = evidencePrevote,
      evidencePrecommit' = evidencePrecommit,
    }

  action Next =
    nondet p = oneOf(Corr)
    any {
      InsertProposal(p),
      nondet v = oneOf(Snapshots)
      UponProposalPrevote(p, v),
      nondet v = oneOf(Snapshots)
      UponValuePrevoteQuorum(p, v),
      UponStreamChangePrecommitNil(p),
      TimeoutProposePrevoteNil(p),
      TimeoutPrevotePrecommitNil(p),
      TimeoutPrecommitStartNextRound(p),
      StartNextRoundAfterPrecommitQuorum(p),
      nondet r = oneOf(Rounds)
      nondet v = oneOf(Snapshots)
      Decide(p, r, v),
    }

  val Agreement =
    tuples(Corr, Corr).forall(((p, q)) =>
      decision.get(p) == NilSnapshot or
      decision.get(q) == NilSnapshot or
      decision.get(p) == decision.get(q)
    )

  val DecisionUniqueness =
    Agreement

  val DecisionsHaveCommitQuorum =
    Corr.forall(p =>
      decision.get(p) == NilSnapshot or
      Rounds.exists(r => PrecommitQuorum(r, decision.get(p)))
    )

  val NoCorrectPrecommitEquivocation =
    Corr.forall(p =>
      Rounds.forall(r =>
        msgsPrecommit.get(r).filter(m => m.src == p).map(m => m.id).size() <= 1
      )
    )

  val ProtocolMessagesAreObserved =
    Rounds.forall(r =>
      msgsPropose.get(r).subseteq(evidencePropose.get(r)) and
      msgsPrevote.get(r).subseteq(evidencePrevote.get(r)) and
      msgsPrecommit.get(r).subseteq(evidencePrecommit.get(r))
    )

  val FatPointerEvidenceSound =
    evidenceFatPointer.forall(fp => ValidFatPointer(fp))

  val MessageEvidenceSoundness =
    ProtocolMessagesAreObserved and FatPointerEvidenceSound

  val SameRoundNilAndValueCommitExcluded =
    Rounds.forall(r =>
      NilPrecommitCert(r) implies
        Snapshots.forall(v => not(PrecommitQuorum(r, v)))
    )

  val LockedValueHasMatchingValidValue =
    Corr.forall(p =>
      lockedValue.get(p) == NilSnapshot or (
        validValue.get(p) == lockedValue.get(p) and
        validRound.get(p) >= lockedRound.get(p)
      )
    )

  val CorrectValueLocksHavePrecommitEvidence =
    Corr.forall(p =>
      lockedValue.get(p) == NilSnapshot or (
        lockedRound.get(p).in(Rounds) and
        IsValidSnapshot(lockedValue.get(p)) and
        ObservedValuePrecommitFrom(p, lockedRound.get(p), lockedValue.get(p))
      )
    )

  val LockSafety =
    LockedValueHasMatchingValidValue and
    CorrectValueLocksHavePrecommitEvidence

  val NilCertLeavesAtMostFCurrentRoundLocks =
    Rounds.forall(r =>
      NilPrecommitCert(r) implies
        Snapshots.forall(v =>
          VotingPowerOf(CorrectValueLocks(r, v)) <= FaultyVotingPowerBound
        )
    )

  def MixedPrecommitQuorumWithoutNilCert(r: Round_t): bool =
    VotingPowerOf(Voters(msgsPrecommit.get(r))) >= THRESHOLD2 and
    not(NilPrecommitCert(r)) and
    msgsPrecommit.get(r).exists(m => m.id == NilSnapshot) and
    msgsPrecommit.get(r).exists(m => IsValidSnapshot(m.id))

  val NilCertificateUnlockSafety =
    SameRoundNilAndValueCommitExcluded and
    NilCertLeavesAtMostFCurrentRoundLocks

  def ConflictingValueCommits(
    r1: Round_t,
    v1: Snapshot_t,
    r2: Round_t,
    v2: Snapshot_t,
  ): bool =
    IsValidSnapshot(v1) and
    IsValidSnapshot(v2) and
    v1 != v2 and
    ObservedPrecommitQuorum(r1, v1) and
    ObservedPrecommitQuorum(r2, v2)

  def CorrectSameRoundEquivocationEvidence(
    r: Round_t,
    v1: Snapshot_t,
    v2: Snapshot_t,
  ): bool =
    v1 != v2 and
    Corr.exists(p =>
      ObservedValuePrecommitFrom(p, r, v1) and
      ObservedValuePrecommitFrom(p, r, v2)
    )

  def CorrectNilValueEquivocationEvidence(r: Round_t, v: Snapshot_t): bool =
    IsValidSnapshot(v) and
    ObservedNilPrecommitCert(r) and
    ObservedPrecommitQuorum(r, v) and
    Corr.exists(p =>
      ObservedNilPrecommitFrom(p, r) and ObservedValuePrecommitFrom(p, r, v)
    )

  def CorrectValueSwitchWithoutUnlock(
    p: Proc_t,
    fromRound: Round_t,
    fromValue: Snapshot_t,
    toRound: Round_t,
    toValue: Snapshot_t,
  ): bool =
    p.in(Corr) and
    fromRound < toRound and
    IsValidSnapshot(fromValue) and
    IsValidSnapshot(toValue) and
    fromValue != toValue and
    ObservedValuePrecommitFrom(p, fromRound, fromValue) and
    ObservedValuePrecommitFrom(p, toRound, toValue) and
    not(ObservedNilPrecommitCert(fromRound))

  def ConflictHasAccountabilityEvidence(
    r1: Round_t,
    v1: Snapshot_t,
    r2: Round_t,
    v2: Snapshot_t,
  ): bool =
    ConflictingValueCommits(r1, v1, r2, v2) and
    if (r1 == r2) {
      CorrectSameRoundEquivocationEvidence(r1, v1, v2)
    } else if (r1 < r2) {
      CorrectNilValueEquivocationEvidence(r1, v1) or
      Corr.exists(p => CorrectValueSwitchWithoutUnlock(p, r1, v1, r2, v2))
    } else {
      CorrectNilValueEquivocationEvidence(r2, v2) or
      Corr.exists(p => CorrectValueSwitchWithoutUnlock(p, r2, v2, r1, v1))
    }

  val ConflictingCommitsAccountable =
    Rounds.forall(r1 =>
      Rounds.forall(r2 =>
        Snapshots.forall(v1 =>
          Snapshots.forall(v2 =>
            ConflictingValueCommits(r1, v1, r2, v2) implies
              ConflictHasAccountabilityEvidence(r1, v1, r2, v2)
          )
        )
      )
    )

  val Safety =
    DecisionUniqueness and
    DecisionsHaveCommitQuorum and
    NoCorrectPrecommitEquivocation and
    MessageEvidenceSoundness and
    LockSafety and
    NilCertificateUnlockSafety and
    ConflictingCommitsAccountable
}

module CrosslinkResamplingTest {
  import CrosslinkResampling.* from "./CrosslinkResampling"
  export CrosslinkResampling.*

  const ExpectedRound1Proposal: Snapshot_t

  action unchangedAll = all {
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
    evidencePropose' = evidencePropose,
    evidencePrevote' = evidencePrevote,
    evidencePrecommit' = evidencePrecommit,
    evidenceFatPointer' = evidenceFatPointer,
    firedAction' = firedAction,
  }

  run abandonedRoundProposalTest = {
    Init
      .then(SeedAbandonedRoundState("p1"))
      .then(SeedAbandonedRoundState("p2"))
      .then(SeedAbandonedRoundState("p3"))
      .then(StartNextRoundAfterPrecommitQuorum("p2"))
      .then(InsertProposal("p2"))
      .then(all {
        assert(msgsPropose.get(1).exists(m =>
          m.src == "p2" and m.round == 1 and m.proposal == ExpectedRound1Proposal
        )),
        unchangedAll,
      })
  }
}

module BaselineCrosslink {
  import CrosslinkResamplingTest(
    Corr = Set("p1", "p2", "p3"),
    Faulty = Set("p4"),
    N = 4,
    T = 1,
    VotingPower = Map("p1" -> 1, "p2" -> 1, "p3" -> 1, "p4" -> 1),
    TotalVotingPower = 4,
    FaultyVotingPowerBound = 1,
    QuorumVotingPower = 3,
    MaxRound = 2,
    Proposer = Map(0 -> "p1", 1 -> "p2", 2 -> "p3"),
    Stream = Map(0 -> "s0", 1 -> "s1", 2 -> "s2"),
    Snapshots = Set("s0", "s1", "s2"),
    StructurallyValid = Map("s0" -> true, "s1" -> true, "s2" -> true),
    PowChainValid = Map("s0" -> true, "s1" -> true, "s2" -> true),
    FinalityCandidateValid = Map("s0" -> true, "s1" -> true, "s2" -> true),
    ResampleOnNilPrecommit = false,
    ExpectedRound1Proposal = "s0",
  ).*

  run baselineCarriesStaleSampleTest = {
    Init
      .then(SeedAbandonedRoundState("p1"))
      .then(SeedAbandonedRoundState("p2"))
      .then(SeedAbandonedRoundState("p3"))
      .then(StartNextRoundAfterPrecommitQuorum("p2"))
      .then(InsertProposal("p2"))
      .then(all {
        assert(msgsPropose.get(1).exists(m =>
          m.src == "p2" and m.round == 1 and m.proposal == "s0"
        )),
        unchangedAll,
      })
  }

  run baselineSameRoundLockBlocksFreshDecisionTest = {
    Init
      .then(SeedValidNilPrecommitState("p1"))
      .then(SeedValidNilPrecommitState("p2"))
      .then(SeedFaultyNilPrecommit("p4"))
      .then(SeedSameRoundValueLock("p3"))
      .then(StartNextRoundAfterPrecommitQuorum("p1"))
      .then(StartNextRoundAfterPrecommitQuorum("p2"))
      .then(StartNextRoundAfterPrecommitQuorum("p3"))
      .then(InsertProposal("p2"))
      .then(UponProposalPrevote("p1", "s1"))
      .fail()
  }
}

module NilPrecommitResamplingCrosslink {
  import CrosslinkResamplingTest(
    Corr = Set("p1", "p2", "p3"),
    Faulty = Set("p4"),
    N = 4,
    T = 1,
    VotingPower = Map("p1" -> 1, "p2" -> 1, "p3" -> 1, "p4" -> 1),
    TotalVotingPower = 4,
    FaultyVotingPowerBound = 1,
    QuorumVotingPower = 3,
    MaxRound = 2,
    Proposer = Map(0 -> "p1", 1 -> "p2", 2 -> "p3"),
    Stream = Map(0 -> "s0", 1 -> "s1", 2 -> "s2"),
    Snapshots = Set("s0", "s1", "s2"),
    StructurallyValid = Map("s0" -> true, "s1" -> true, "s2" -> true),
    PowChainValid = Map("s0" -> true, "s1" -> true, "s2" -> true),
    FinalityCandidateValid = Map("s0" -> true, "s1" -> true, "s2" -> true),
    ResampleOnNilPrecommit = true,
    ExpectedRound1Proposal = "s1",
  ).*

  run nilPrecommitResamplesFreshStreamTest = {
    Init
      .then(SeedAbandonedRoundState("p1"))
      .then(SeedAbandonedRoundState("p2"))
      .then(SeedAbandonedRoundState("p3"))
      .then(StartNextRoundAfterPrecommitQuorum("p2"))
      .then(InsertProposal("p2"))
      .then(all {
        assert(msgsPropose.get(1).exists(m =>
          m.src == "p2" and m.round == 1 and m.proposal == "s1"
        )),
        unchangedAll,
      })
  }

  run nilPrecommitPreservesOlderTendermintValueLockTest = {
    Init
      .then(SeedOlderLockWithNilPrecommit("p1"))
      .then(SeedOlderLockWithNilPrecommit("p2"))
      .then(SeedOlderLockWithNilPrecommit("p3"))
      .then(StartNextRoundAfterPrecommitQuorum("p2"))
      .then(all {
        assert(lockedValue.get("p2") == "s0"),
        assert(lockedRound.get("p2") == 0),
        assert(validValue.get("p2") == "s0"),
        assert(validRound.get("p2") == 0),
        unchangedAll,
      })
  }

  run nilPrecommitUnlocksSameRoundTendermintStateTest = {
    Init
      .then(SeedValidNilPrecommitState("p1"))
      .then(SeedValidNilPrecommitState("p2"))
      .then(SeedFaultyNilPrecommit("p4"))
      .then(SeedSameRoundValueLock("p3"))
      .then(StartNextRoundAfterPrecommitQuorum("p2"))
      .then(StartNextRoundAfterPrecommitQuorum("p3"))
      .then(all {
        assert(validValue.get("p2") == "None"),
        assert(validRound.get("p2") == -1),
        assert(lockedValue.get("p2") == "None"),
        assert(lockedRound.get("p2") == -1),
        assert(lockedValue.get("p3") == "None"),
        assert(lockedRound.get("p3") == -1),
        assert(validValue.get("p3") == "None"),
        assert(validRound.get("p3") == -1),
        assert(NilPrecommitCert(0)),
        assert(not(PrecommitQuorum(0, "s0"))),
        unchangedAll,
      })
  }

  run lateNilPrecommitCertificateUnlocksAbandonedRoundTest = {
    Init
      .then(SeedValidNilPrecommitState("p1"))
      .then(SeedValidNilPrecommitState("p2"))
      .then(SeedFaultyNilPrecommit("p4"))
      .then(SeedTimedOutSameRoundValueLock("p3"))
      .then(ApplyLateNilPrecommitCertificate("p3", 0))
      .then(all {
        assert(round.get("p3") == 1),
        assert(validValue.get("p3") == "None"),
        assert(validRound.get("p3") == -1),
        assert(lockedValue.get("p3") == "None"),
        assert(lockedRound.get("p3") == -1),
        assert(NilPrecommitCert(0)),
        assert(not(PrecommitQuorum(0, "s0"))),
        unchangedAll,
      })
  }

  run nilPrecommitUnlockResamplesAndDecidesFreshValueTest = {
    Init
      .then(SeedValidNilPrecommitState("p1"))
      .then(SeedValidNilPrecommitState("p2"))
      .then(SeedFaultyNilPrecommit("p4"))
      .then(SeedSameRoundValueLock("p3"))
      .then(StartNextRoundAfterPrecommitQuorum("p1"))
      .then(StartNextRoundAfterPrecommitQuorum("p2"))
      .then(StartNextRoundAfterPrecommitQuorum("p3"))
      .then(InsertProposal("p2"))
      .then(UponProposalPrevote("p1", "s1"))
      .then(UponProposalPrevote("p2", "s1"))
      .then(UponProposalPrevote("p3", "s1"))
      .then(UponValuePrevoteQuorum("p1", "s1"))
      .then(UponValuePrevoteQuorum("p2", "s1"))
      .then(UponValuePrevoteQuorum("p3", "s1"))
      .then(Decide("p1", 1, "s1"))
      .then(all {
        assert(decision.get("p1") == "s1"),
        unchangedAll,
      })
  }

  run conflictingCommitsExposeInvalidUnlockEvidenceTest = {
    Init
      .then(SeedCorrectPrecommitEvidence("p1", 0, "s0"))
      .then(SeedCorrectPrecommitEvidence("p2", 0, "s0"))
      .then(SeedFaultyPrecommitEvidence("p4", 0, "s0"))
      .then(SeedCorrectPrecommitEvidence("p2", 1, "s1"))
      .then(SeedCorrectPrecommitEvidence("p3", 1, "s1"))
      .then(SeedFaultyPrecommitEvidence("p4", 1, "s1"))
      .then(all {
        assert(ObservedPrecommitQuorum(0, "s0")),
        assert(ObservedPrecommitQuorum(1, "s1")),
        assert(not(PrecommitQuorum(0, "s0"))),
        assert(not(PrecommitQuorum(1, "s1"))),
        assert(ConflictHasAccountabilityEvidence(0, "s0", 1, "s1")),
        assert(ConflictingCommitsAccountable),
        unchangedAll,
      })
  }

  run conflictWithBogusNilUnlockExposesEquivocationEvidenceTest = {
    Init
      .then(SeedValidNilPrecommitState("p2"))
      .then(SeedValidNilPrecommitState("p3"))
      .then(SeedFaultyNilPrecommit("p4"))
      .then(SeedCorrectPrecommitEvidence("p1", 0, "s0"))
      .then(SeedCorrectPrecommitEvidence("p2", 0, "s0"))
      .then(SeedFaultyPrecommitEvidence("p4", 0, "s0"))
      .then(SeedCorrectPrecommitEvidence("p2", 1, "s1"))
      .then(SeedCorrectPrecommitEvidence("p3", 1, "s1"))
      .then(SeedFaultyPrecommitEvidence("p4", 1, "s1"))
      .then(all {
        assert(NilPrecommitCert(0)),
        assert(ObservedPrecommitQuorum(0, "s0")),
        assert(ObservedPrecommitQuorum(1, "s1")),
        assert(CorrectNilValueEquivocationEvidence(0, "s0")),
        assert(ConflictHasAccountabilityEvidence(0, "s0", 1, "s1")),
        assert(ConflictingCommitsAccountable),
        unchangedAll,
      })
  }

  run nilPrecommitCertificateJustifiesSameRoundSwitchTest = {
    Init
      .then(SeedValidNilPrecommitState("p1"))
      .then(SeedValidNilPrecommitState("p2"))
      .then(SeedFaultyNilPrecommit("p4"))
      .then(SeedSameRoundValueLock("p3"))
      .then(StartNextRoundAfterPrecommitQuorum("p3"))
      .then(SeedCorrectPrecommitEvidence("p1", 1, "s1"))
      .then(SeedCorrectPrecommitEvidence("p2", 1, "s1"))
      .then(SeedCorrectPrecommitEvidence("p3", 1, "s1"))
      .then(all {
        assert(NilPrecommitCert(0)),
        assert(not(PrecommitQuorum(0, "s0"))),
        assert(ObservedPrecommitQuorum(1, "s1")),
        assert(not(CorrectValueSwitchWithoutUnlock("p3", 0, "s0", 1, "s1"))),
        assert(ConflictingCommitsAccountable),
        unchangedAll,
      })
  }

  run laterNilCertificateDoesNotUnlockOlderValueLockTest = {
    Init
      .then(SeedOlderLockWithNilPrecommit("p1"))
      .then(SeedOlderLockWithNilPrecommit("p2"))
      .then(SeedOlderLockWithNilPrecommit("p3"))
      .then(SeedCorrectPrecommitEvidence("p2", 2, "s2"))
      .then(SeedCorrectPrecommitEvidence("p3", 2, "s2"))
      .then(SeedFaultyPrecommitEvidence("p4", 2, "s2"))
      .then(all {
        assert(ObservedPrecommitQuorum(0, "s0")),
        assert(ObservedNilPrecommitCert(1)),
        assert(ObservedPrecommitQuorum(2, "s2")),
        assert(CorrectValueSwitchWithoutUnlock("p2", 0, "s0", 2, "s2")),
        assert(ConflictHasAccountabilityEvidence(0, "s0", 2, "s2")),
        assert(ConflictingCommitsAccountable),
        unchangedAll,
      })
  }

  run mixedPrecommitQuorumDoesNotUnlockTest = {
    Init
      .then(SeedSameRoundValueLock("p1"))
      .then(SeedSameRoundValueLock("p2"))
      .then(SeedValidNilPrecommitState("p3"))
      .then(StartNextRoundAfterPrecommitQuorum("p1"))
      .then(all {
        assert(MixedPrecommitQuorumWithoutNilCert(0)),
        assert(not(NilPrecommitCert(0))),
        assert(lockedValue.get("p1") == "s0"),
        assert(lockedRound.get("p1") == 0),
        assert(validValue.get("p1") == "s0"),
        assert(validRound.get("p1") == 0),
        assert(Safety),
        unchangedAll,
      })
  }
}

module CrosslinkEvidenceBookkeepingModel {
  import CrosslinkResamplingTest(
    Corr = Set("p1", "p2", "p3"),
    Faulty = Set("p4"),
    N = 4,
    T = 1,
    VotingPower = Map("p1" -> 1, "p2" -> 1, "p3" -> 1, "p4" -> 1),
    TotalVotingPower = 4,
    FaultyVotingPowerBound = 1,
    QuorumVotingPower = 3,
    MaxRound = 2,
    Proposer = Map(0 -> "p1", 1 -> "p2", 2 -> "p3"),
    Stream = Map(0 -> "s0", 1 -> "s1", 2 -> "s2"),
    Snapshots = Set("s0", "s1", "s2"),
    StructurallyValid = Map("s0" -> true, "s1" -> true, "s2" -> true),
    PowChainValid = Map("s0" -> true, "s1" -> true, "s2" -> true),
    FinalityCandidateValid = Map("s0" -> true, "s1" -> true, "s2" -> true),
    ResampleOnNilPrecommit = true,
    ExpectedRound1Proposal = "s1",
  ).*

  run observedEvidenceDoesNotMutateProtocolMessagesTest = {
    Init
      .then(SeedCorrectPrecommitEvidence("p1", 0, "s0"))
      .then(all {
        assert(ObservedValuePrecommitFrom("p1", 0, "s0")),
        assert(not(HasValuePrecommitFrom("p1", 0, "s0"))),
        assert(not(ObservedPrecommitQuorum(0, "s0"))),
        assert(not(PrecommitQuorum(0, "s0"))),
        unchangedAll,
      })
  }

  run evidenceOnlyConflictStillHasAccountabilityWitnessTest = {
    Init
      .then(SeedCorrectPrecommitEvidence("p1", 0, "s0"))
      .then(SeedCorrectPrecommitEvidence("p2", 0, "s0"))
      .then(SeedFaultyPrecommitEvidence("p4", 0, "s0"))
      .then(SeedCorrectPrecommitEvidence("p2", 1, "s1"))
      .then(SeedCorrectPrecommitEvidence("p3", 1, "s1"))
      .then(SeedFaultyPrecommitEvidence("p4", 1, "s1"))
      .then(all {
        assert(ObservedPrecommitQuorum(0, "s0")),
        assert(ObservedPrecommitQuorum(1, "s1")),
        assert(not(PrecommitQuorum(0, "s0"))),
        assert(not(PrecommitQuorum(1, "s1"))),
        assert(CorrectValueSwitchWithoutUnlock("p2", 0, "s0", 1, "s1")),
        assert(ConflictHasAccountabilityEvidence(0, "s0", 1, "s1")),
        assert(ConflictingCommitsAccountable),
        unchangedAll,
      })
  }
}

module CrosslinkWeightedQuorumModel {
  import CrosslinkResamplingTest(
    Corr = Set("p1", "p2", "p3"),
    Faulty = Set("p4"),
    N = 4,
    T = 1,
    VotingPower = Map("p1" -> 2, "p2" -> 2, "p3" -> 1, "p4" -> 1),
    TotalVotingPower = 6,
    FaultyVotingPowerBound = 1,
    QuorumVotingPower = 4,
    MaxRound = 1,
    Proposer = Map(0 -> "p1", 1 -> "p2"),
    Stream = Map(0 -> "s0", 1 -> "s0"),
    Snapshots = Set("s0", "s1"),
    StructurallyValid = Map("s0" -> true, "s1" -> true),
    PowChainValid = Map("s0" -> true, "s1" -> true),
    FinalityCandidateValid = Map("s0" -> true, "s1" -> true),
    ResampleOnNilPrecommit = true,
    ExpectedRound1Proposal = "s0",
  ).*

  run twoHighPowerValidatorsCanCommitTest = {
    Init
      .then(InsertProposal("p1"))
      .then(UponProposalPrevote("p1", "s0"))
      .then(UponProposalPrevote("p2", "s0"))
      .then(UponValuePrevoteQuorum("p1", "s0"))
      .then(UponValuePrevoteQuorum("p2", "s0"))
      .then(Decide("p1", 0, "s0"))
      .then(all {
        assert(PrevoteQuorum(0, "s0")),
        assert(PrecommitQuorum(0, "s0")),
        assert(size(Voters(msgsPrecommit.get(0).filter(m => m.id == "s0"))) == 2),
        assert(decision.get("p1") == "s0"),
        assert(Safety),
        unchangedAll,
      })
  }
}

module CrosslinkMessageEvidenceModel {
  import CrosslinkResamplingTest(
    Corr = Set("p1", "p2", "p3"),
    Faulty = Set("p4"),
    N = 4,
    T = 1,
    VotingPower = Map("p1" -> 1, "p2" -> 1, "p3" -> 1, "p4" -> 1),
    TotalVotingPower = 4,
    FaultyVotingPowerBound = 1,
    QuorumVotingPower = 3,
    MaxRound = 1,
    Proposer = Map(0 -> "p1", 1 -> "p2"),
    Stream = Map(0 -> "s0", 1 -> "s0"),
    Snapshots = Set("s0", "s1"),
    StructurallyValid = Map("s0" -> true, "s1" -> true),
    PowChainValid = Map("s0" -> true, "s1" -> true),
    FinalityCandidateValid = Map("s0" -> true, "s1" -> true),
    ResampleOnNilPrecommit = true,
    ExpectedRound1Proposal = "s0",
  ).*

  run protocolMessagesAreMirroredIntoEvidenceTest = {
    Init
      .then(InsertProposal("p1"))
      .then(UponProposalPrevote("p1", "s0"))
      .then(all {
        assert(msgsPropose.get(0).subseteq(evidencePropose.get(0))),
        assert(msgsPrevote.get(0).subseteq(evidencePrevote.get(0))),
        assert(ProtocolMessagesAreObserved),
        assert(MessageEvidenceSoundness),
        unchangedAll,
      })
  }

  run validFatPointerEvidenceWitnessTest = {
    Init
      .then(SeedCorrectPrecommitEvidence("p1", 0, "s0"))
      .then(SeedCorrectPrecommitEvidence("p2", 0, "s0"))
      .then(SeedFaultyPrecommitEvidence("p4", 0, "s0"))
      .then(SeedFatPointerEvidence(0, "s0", Set("p1", "p2", "p4")))
      .then(all {
        assert(ObservedPrecommitQuorum(0, "s0")),
        assert(ObservedFatPointerQuorum(0, "s0")),
        assert(not(PrecommitQuorum(0, "s0"))),
        assert(FatPointerEvidenceSound),
        unchangedAll,
      })
  }

  run fatPointerRequiresSignerPrecommitEvidenceTest = {
    Init
      .then(SeedCorrectPrecommitEvidence("p1", 0, "s0"))
      .then(SeedCorrectPrecommitEvidence("p2", 0, "s0"))
      .then(SeedFatPointerEvidence(0, "s0", Set("p1", "p2", "p4")))
      .fail()
  }

  run fatPointerRequiresQuorumVotingPowerTest = {
    Init
      .then(SeedCorrectPrecommitEvidence("p1", 0, "s0"))
      .then(SeedCorrectPrecommitEvidence("p2", 0, "s0"))
      .then(SeedFatPointerEvidence(0, "s0", Set("p1", "p2")))
      .fail()
  }
}

module CrosslinkTimeoutModel {
  import CrosslinkResamplingTest(
    Corr = Set("p1", "p2", "p3"),
    Faulty = Set("p4"),
    N = 4,
    T = 1,
    VotingPower = Map("p1" -> 1, "p2" -> 1, "p3" -> 1, "p4" -> 1),
    TotalVotingPower = 4,
    FaultyVotingPowerBound = 1,
    QuorumVotingPower = 3,
    MaxRound = 2,
    Proposer = Map(0 -> "p1", 1 -> "p2", 2 -> "p3"),
    Stream = Map(0 -> "s0", 1 -> "s1", 2 -> "s2"),
    Snapshots = Set("s0", "s1", "s2"),
    StructurallyValid = Map("s0" -> true, "s1" -> true, "s2" -> true),
    PowChainValid = Map("s0" -> true, "s1" -> true, "s2" -> true),
    FinalityCandidateValid = Map("s0" -> true, "s1" -> true, "s2" -> true),
    ResampleOnNilPrecommit = true,
    ExpectedRound1Proposal = "s1",
  ).*

  run proposeTimeoutBroadcastsNilPrevoteTest = {
    Init
      .then(TimeoutProposePrevoteNil("p2"))
      .then(all {
        assert(step.get("p2") == "prevote"),
        assert(msgsPrevote.get(0).exists(m =>
          m.src == "p2" and m.id == NilSnapshot
        )),
        assert(ProtocolMessagesAreObserved),
        unchangedAll,
      })
  }

  run prevoteTimeoutBroadcastsNilPrecommitTest = {
    Init
      .then(TimeoutProposePrevoteNil("p1"))
      .then(TimeoutPrevotePrecommitNil("p1"))
      .then(all {
        assert(step.get("p1") == "precommit"),
        assert(msgsPrecommit.get(0).exists(m =>
          m.src == "p1" and m.id == NilSnapshot
        )),
        assert(ProtocolMessagesAreObserved),
        unchangedAll,
      })
  }

  run precommitTimeoutDoesNotUnlockWithoutNilCertificateTest = {
    Init
      .then(SeedSameRoundValueLock("p1"))
      .then(TimeoutPrecommitStartNextRound("p1"))
      .then(all {
        assert(round.get("p1") == 1),
        assert(step.get("p1") == "propose"),
        assert(lockedValue.get("p1") == "s0"),
        assert(lockedRound.get("p1") == 0),
        assert(validValue.get("p1") == "s0"),
        assert(validRound.get("p1") == 0),
        assert(not(NilPrecommitCert(0))),
        assert(Safety),
        unchangedAll,
      })
  }

  run nilTimeoutCertificateUnlocksSameRoundStateTest = {
    Init
      .then(SeedSameRoundValueLock("p1"))
      .then(TimeoutProposePrevoteNil("p2"))
      .then(TimeoutProposePrevoteNil("p3"))
      .then(TimeoutPrevotePrecommitNil("p2"))
      .then(TimeoutPrevotePrecommitNil("p3"))
      .then(SeedFaultyNilPrecommit("p4"))
      .then(StartNextRoundAfterPrecommitQuorum("p1"))
      .then(all {
        assert(NilPrecommitCert(0)),
        assert(not(PrecommitQuorum(0, "s0"))),
        assert(lockedValue.get("p1") == "None"),
        assert(lockedRound.get("p1") == -1),
        assert(validValue.get("p1") == "None"),
        assert(validRound.get("p1") == -1),
        assert(Safety),
        unchangedAll,
      })
  }
}

module CrosslinkNilResamplingLivenessModel {
  import CrosslinkResamplingTest(
    Corr = Set("p1", "p2", "p3"),
    Faulty = Set("p4"),
    N = 4,
    T = 1,
    VotingPower = Map("p1" -> 1, "p2" -> 1, "p3" -> 1, "p4" -> 1),
    TotalVotingPower = 4,
    FaultyVotingPowerBound = 1,
    QuorumVotingPower = 3,
    MaxRound = 2,
    Proposer = Map(0 -> "p1", 1 -> "p2", 2 -> "p3"),
    Stream = Map(0 -> "s0", 1 -> "s1", 2 -> "s2"),
    Snapshots = Set("s0", "s1", "s2"),
    StructurallyValid = Map("s0" -> true, "s1" -> true, "s2" -> true),
    PowChainValid = Map("s0" -> true, "s1" -> true, "s2" -> true),
    FinalityCandidateValid = Map("s0" -> true, "s1" -> true, "s2" -> true),
    ResampleOnNilPrecommit = true,
    ExpectedRound1Proposal = "s1",
  ).*

  var phase: int

  action LivenessInit = all {
    Init,
    phase' = 0,
  }

  action LivenessStep = any {
    all { phase == 0, SeedValidNilPrecommitState("p1"), phase' = 1 },
    all { phase == 1, SeedValidNilPrecommitState("p2"), phase' = 2 },
    all { phase == 2, SeedFaultyNilPrecommit("p4"), phase' = 3 },
    all { phase == 3, SeedSameRoundValueLock("p3"), phase' = 4 },
    all { phase == 4, StartNextRoundAfterPrecommitQuorum("p1"), phase' = 5 },
    all { phase == 5, StartNextRoundAfterPrecommitQuorum("p2"), phase' = 6 },
    all { phase == 6, StartNextRoundAfterPrecommitQuorum("p3"), phase' = 7 },
    all { phase == 7, InsertProposal("p2"), phase' = 8 },
    all { phase == 8, UponProposalPrevote("p1", "s1"), phase' = 9 },
    all { phase == 9, UponProposalPrevote("p2", "s1"), phase' = 10 },
    all { phase == 10, UponProposalPrevote("p3", "s1"), phase' = 11 },
    all { phase == 11, UponValuePrevoteQuorum("p1", "s1"), phase' = 12 },
    all { phase == 12, UponValuePrevoteQuorum("p2", "s1"), phase' = 13 },
    all { phase == 13, UponValuePrevoteQuorum("p3", "s1"), phase' = 14 },
    all { phase == 14, Decide("p1", 1, "s1"), phase' = 15 },
    all { phase == 15, unchangedAll, phase' = 15 },
  }

  val FreshDecisionByEnd =
    phase < 15 or decision.get("p1") == "s1"

  val LivenessSafety =
    Safety and FreshDecisionByEnd
}

module NilPrecommitResamplingStableWindowLiveness {
  import CrosslinkResamplingTest(
    Corr = Set("p1", "p2", "p3"),
    Faulty = Set("p4"),
    N = 4,
    T = 1,
    VotingPower = Map("p1" -> 1, "p2" -> 1, "p3" -> 1, "p4" -> 1),
    TotalVotingPower = 4,
    FaultyVotingPowerBound = 1,
    QuorumVotingPower = 3,
    MaxRound = 3,
    Proposer = Map(0 -> "p1", 1 -> "p2", 2 -> "p3", 3 -> "p1"),
    Stream = Map(0 -> "s0", 1 -> "s1", 2 -> "s2", 3 -> "s2"),
    Snapshots = Set("s0", "s1", "s2"),
    StructurallyValid = Map("s0" -> true, "s1" -> true, "s2" -> true),
    PowChainValid = Map("s0" -> true, "s1" -> true, "s2" -> true),
    FinalityCandidateValid = Map("s0" -> true, "s1" -> true, "s2" -> true),
    ResampleOnNilPrecommit = true,
    ExpectedRound1Proposal = "s1",
  ).*

  run repeatedStreamChangesBurnRoundsUntilStableDecisionTest = {
    Init
      .then(SeedValidNilPrecommitStateAt("p1", 0))
      .then(SeedValidNilPrecommitStateAt("p2", 0))
      .then(SeedFaultyNilPrecommitAt("p4", 0))
      .then(SeedSameRoundValueLockAt("p3", 0))
      .then(StartNextRoundAfterPrecommitQuorum("p1"))
      .then(StartNextRoundAfterPrecommitQuorum("p2"))
      .then(StartNextRoundAfterPrecommitQuorum("p3"))
      .then(SeedValidNilPrecommitStateAt("p1", 1))
      .then(SeedValidNilPrecommitStateAt("p2", 1))
      .then(SeedFaultyNilPrecommitAt("p4", 1))
      .then(SeedSameRoundValueLockAt("p3", 1))
      .then(StartNextRoundAfterPrecommitQuorum("p1"))
      .then(StartNextRoundAfterPrecommitQuorum("p2"))
      .then(StartNextRoundAfterPrecommitQuorum("p3"))
      .then(InsertProposal("p3"))
      .then(UponProposalPrevote("p1", "s2"))
      .then(UponProposalPrevote("p2", "s2"))
      .then(UponProposalPrevote("p3", "s2"))
      .then(UponValuePrevoteQuorum("p1", "s2"))
      .then(UponValuePrevoteQuorum("p2", "s2"))
      .then(UponValuePrevoteQuorum("p3", "s2"))
      .then(Decide("p1", 2, "s2"))
      .then(all {
        assert(NilPrecommitCert(0)),
        assert(NilPrecommitCert(1)),
        assert(not(StreamChangedAfter(2))),
        assert(decision.get("p1") == "s2"),
        assert(Safety),
        unchangedAll,
      })
  }
}

module CrosslinkProposalValidityModel {
  import CrosslinkResamplingTest(
    Corr = Set("p1", "p2", "p3"),
    Faulty = Set("p4"),
    N = 4,
    T = 1,
    VotingPower = Map("p1" -> 1, "p2" -> 1, "p3" -> 1, "p4" -> 1),
    TotalVotingPower = 4,
    FaultyVotingPowerBound = 1,
    QuorumVotingPower = 3,
    MaxRound = 1,
    Proposer = Map(0 -> "p1", 1 -> "p2"),
    Stream = Map(0 -> "s0", 1 -> "s1"),
    Snapshots = Set("s0", "s1"),
    StructurallyValid = Map("s0" -> false, "s1" -> true),
    PowChainValid = Map("s0" -> true, "s1" -> true),
    FinalityCandidateValid = Map("s0" -> true, "s1" -> true),
    ResampleOnNilPrecommit = true,
    ExpectedRound1Proposal = "s1",
  ).*

  run freshButStructurallyInvalidProposalPrevotesNilTest = {
    Init
      .then(InsertProposal("p1"))
      .then(UponProposalPrevote("p1", "s0"))
      .then(all {
        assert(IsFreshForRound(0, "s0")),
        assert(not(StaticProposalValidity("s0"))),
        assert(not(ValidProposalForRound(0, "s0"))),
        assert(msgsPrevote.get(0).exists(m =>
          m.src == "p1" and m.id == NilSnapshot
        )),
        unchangedAll,
      })
  }
}

module CrosslinkResamplingModels {
  import CrosslinkResamplingTest(
    Corr = Set("p1", "p2", "p3"),
    Faulty = Set("p4"),
    N = 4,
    T = 1,
    VotingPower = Map("p1" -> 1, "p2" -> 1, "p3" -> 1, "p4" -> 1),
    TotalVotingPower = 4,
    FaultyVotingPowerBound = 1,
    QuorumVotingPower = 3,
    MaxRound = 2,
    Proposer = Map(0 -> "p1", 1 -> "p2", 2 -> "p3"),
    Stream = Map(0 -> "s0", 1 -> "s1", 2 -> "s2"),
    Snapshots = Set("s0", "s1", "s2"),
    StructurallyValid = Map("s0" -> true, "s1" -> true, "s2" -> true),
    PowChainValid = Map("s0" -> true, "s1" -> true, "s2" -> true),
    FinalityCandidateValid = Map("s0" -> true, "s1" -> true, "s2" -> true),
    ResampleOnNilPrecommit = false,
    ExpectedRound1Proposal = "s0",
  ) as sticky

  import CrosslinkResamplingTest(
    Corr = Set("p1", "p2", "p3"),
    Faulty = Set("p4"),
    N = 4,
    T = 1,
    VotingPower = Map("p1" -> 1, "p2" -> 1, "p3" -> 1, "p4" -> 1),
    TotalVotingPower = 4,
    FaultyVotingPowerBound = 1,
    QuorumVotingPower = 3,
    MaxRound = 2,
    Proposer = Map(0 -> "p1", 1 -> "p2", 2 -> "p3"),
    Stream = Map(0 -> "s0", 1 -> "s1", 2 -> "s2"),
    Snapshots = Set("s0", "s1", "s2"),
    StructurallyValid = Map("s0" -> true, "s1" -> true, "s2" -> true),
    PowChainValid = Map("s0" -> true, "s1" -> true, "s2" -> true),
    FinalityCandidateValid = Map("s0" -> true, "s1" -> true, "s2" -> true),
    ResampleOnNilPrecommit = true,
    ExpectedRound1Proposal = "s1",
  ) as resampling
}
