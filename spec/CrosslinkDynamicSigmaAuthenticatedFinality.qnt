module CrosslinkDynamicSigmaAuthenticatedFinality {
  /*
   Dynamic-sigma finality with authenticated evidence.

   CrosslinkDynamicSigmaHeightedFinality.qnt checks that the finality cursor
   consumes only local heighted decisions whose candidates satisfy the active
   BFT height's `head - sigma(h)` tail. This slice adds the next composition
   boundary: dynamic finality may advance only after observer-local authenticated
   precommit evidence and authenticated fat-pointer signatures support the same
   height, round, and dynamic candidate.
   */

  import CrosslinkDynamicSigmaHeightedFinality.* from "./CrosslinkDynamicSigmaHeightedFinality"
  export CrosslinkDynamicSigmaHeightedFinality.*

  type Bytes_t = str
  type Sig_t = str

  const Bytes: Set[Bytes_t]
  const Signatures: Set[Sig_t]
  const SignatureOwner: Sig_t -> Proc_t
  const SignatureBytes: Sig_t -> Bytes_t
  const PrecommitPayload: Height_t -> Round_t -> Snapshot_t -> Bytes_t
  const FatPointerPayload: Height_t -> Round_t -> Snapshot_t -> Bytes_t

  type SignedVote_t = {
    src: Proc_t,
    height: Height_t,
    round: Round_t,
    id: Snapshot_t,
    bytes: Bytes_t,
    sig: Sig_t,
  }

  type SignedFatPointerSig_t = {
    src: Proc_t,
    height: Height_t,
    round: Round_t,
    id: Snapshot_t,
    bytes: Bytes_t,
    sig: Sig_t,
  }

  type FatPointer_t = {
    height: Height_t,
    round: Round_t,
    id: Snapshot_t,
    signers: Set[Proc_t],
  }

  var authGossipPrecommit: Height_t -> Round_t -> Set[SignedVote_t]
  var authObservedPrecommit: Height_t -> Round_t -> Set[SignedVote_t]
  var authGossipFatPointerSig: Height_t -> Round_t -> Set[SignedFatPointerSig_t]
  var authObservedFatPointer: Set[FatPointer_t]

  assume signature_metadata_is_in_domain =
    Signatures.forall(s =>
      Corr.union(Faulty).contains(SignatureOwner.get(s)) and
      Bytes.contains(SignatureBytes.get(s))
    )

  assume precommit_payloads_are_bytes =
    Heights.forall(h =>
      Rounds.forall(r =>
        Snapshots.forall(v =>
          Bytes.contains(PrecommitPayload.get(h).get(r).get(v))
        )
      )
    )

  assume fat_pointer_payloads_are_bytes =
    Heights.forall(h =>
      Rounds.forall(r =>
        Snapshots.forall(v =>
          Bytes.contains(FatPointerPayload.get(h).get(r).get(v))
        )
      )
    )

  pure val ValidatorUniverse =
    Corr.union(Faulty)

  pure def SignerSetHasAuthQuorum(signers: Set[Proc_t]): bool =
    signers.subseteq(ValidatorUniverse) and
    VotingPowerOf(signers) >= QuorumVotingPower

  pure def Verify(p: Proc_t, bytes: Bytes_t, sig: Sig_t): bool =
    Signatures.contains(sig) and
    SignatureOwner.get(sig) == p and
    SignatureBytes.get(sig) == bytes

  def PrecommitAuthentic(m: SignedVote_t): bool =
    ValidatorUniverse.contains(m.src) and
    m.height.in(Heights) and
    m.round.in(Rounds) and
    IsSnapshot(m.id) and
    m.bytes == PrecommitPayload.get(m.height).get(m.round).get(m.id) and
    Verify(m.src, m.bytes, m.sig)

  def FatPointerSigAuthentic(m: SignedFatPointerSig_t): bool =
    ValidatorUniverse.contains(m.src) and
    m.height.in(Heights) and
    m.round.in(Rounds) and
    IsSnapshot(m.id) and
    m.bytes == FatPointerPayload.get(m.height).get(m.round).get(m.id) and
    Verify(m.src, m.bytes, m.sig)

  def AuthGossipedPrecommit(m: SignedVote_t): bool =
    authGossipPrecommit.get(m.height).get(m.round).contains(m)

  def AuthObservedPrecommitFrom(
    p: Proc_t,
    h: Height_t,
    r: Round_t,
    v: Snapshot_t,
  ): bool =
    authObservedPrecommit.get(h).get(r).exists(m =>
      m.src == p and m.height == h and m.round == r and m.id == v and
      PrecommitAuthentic(m)
    )

  def AuthGossipedFatPointerSigFrom(
    p: Proc_t,
    h: Height_t,
    r: Round_t,
    v: Snapshot_t,
  ): bool =
    authGossipFatPointerSig.get(h).get(r).exists(m =>
      m.src == p and m.height == h and m.round == r and m.id == v and
      FatPointerSigAuthentic(m)
    )

  def AuthenticatedFatPointerValid(fp: FatPointer_t): bool =
    fp.height.in(Heights) and
    fp.round.in(Rounds) and
    IsSnapshot(fp.id) and
    SignerSetHasAuthQuorum(fp.signers) and
    fp.signers.forall(p =>
      AuthObservedPrecommitFrom(p, fp.height, fp.round, fp.id) and
      AuthGossipedFatPointerSigFrom(p, fp.height, fp.round, fp.id)
    )

  def AuthenticatedFatPointerObserved(
    h: Height_t,
    r: Round_t,
    v: Snapshot_t,
    signers: Set[Proc_t],
  ): bool = {
    val fp = { height: h, round: r, id: v, signers: signers }
    authObservedFatPointer.contains(fp) and AuthenticatedFatPointerValid(fp)
  }

  action AuthenticatedInit = all {
    ComposedInit,
    authGossipPrecommit' = Heights.mapBy(_ => Rounds.mapBy(_ => Set())),
    authObservedPrecommit' = Heights.mapBy(_ => Rounds.mapBy(_ => Set())),
    authGossipFatPointerSig' = Heights.mapBy(_ => Rounds.mapBy(_ => Set())),
    authObservedFatPointer' = Set(),
  }

  action AuthEvidenceUnchanged = all {
    authGossipPrecommit' = authGossipPrecommit,
    authObservedPrecommit' = authObservedPrecommit,
    authGossipFatPointerSig' = authGossipFatPointerSig,
    authObservedFatPointer' = authObservedFatPointer,
  }

  action ProposeAuth(p: Proc_t): bool =
    all { Propose(p), AuthEvidenceUnchanged }

  action DeliverProposalToAllAuth(
    from: Proc_t,
    h: Height_t,
    r: Round_t,
    v: Snapshot_t,
    vr: Round_t,
  ): bool =
    all { DeliverProposalToAll(from, h, r, v, vr), AuthEvidenceUnchanged }

  action PrevoteValueAuth(p: Proc_t, v: Snapshot_t): bool =
    all { PrevoteValue(p, v), AuthEvidenceUnchanged }

  action DeliverPrevoteQuorumToAllAuth(
    h: Height_t,
    r: Round_t,
    v: Snapshot_t,
    signers: Set[Proc_t],
  ): bool =
    all { DeliverPrevoteQuorumToAll(h, r, v, signers), AuthEvidenceUnchanged }

  action PrecommitValueAtAuth(p: Proc_t, v: Snapshot_t): bool =
    all { PrecommitValueAt(p, v), AuthEvidenceUnchanged }

  action DeliverPrecommitQuorumToAllAuth(
    h: Height_t,
    r: Round_t,
    v: Snapshot_t,
    signers: Set[Proc_t],
  ): bool =
    all { DeliverPrecommitQuorumToAll(h, r, v, signers), AuthEvidenceUnchanged }

  action DecideValueAuth(p: Proc_t, v: Snapshot_t): bool =
    all { DecideValue(p, v), AuthEvidenceUnchanged }

  action GossipPrecommit(
    p: Proc_t,
    h: Height_t,
    r: Round_t,
    v: Snapshot_t,
    bytes: Bytes_t,
    sig: Sig_t,
  ): bool = {
    val msg = { src: p, height: h, round: r, id: v, bytes: bytes, sig: sig }
    all {
      PrecommitAuthentic(msg),
      ComposedStutter,
      authGossipPrecommit' =
        authGossipPrecommit.setBy(h, byRound =>
          byRound.setBy(r, old => old.union(Set(msg)))
        ),
      authObservedPrecommit' = authObservedPrecommit,
      authGossipFatPointerSig' = authGossipFatPointerSig,
      authObservedFatPointer' = authObservedFatPointer,
    }
  }

  action ObservePrecommit(
    p: Proc_t,
    h: Height_t,
    r: Round_t,
    v: Snapshot_t,
    bytes: Bytes_t,
    sig: Sig_t,
  ): bool = {
    val msg = { src: p, height: h, round: r, id: v, bytes: bytes, sig: sig }
    all {
      PrecommitAuthentic(msg),
      AuthGossipedPrecommit(msg),
      ComposedStutter,
      authGossipPrecommit' = authGossipPrecommit,
      authObservedPrecommit' =
        authObservedPrecommit.setBy(h, byRound =>
          byRound.setBy(r, old => old.union(Set(msg)))
      ),
      authGossipFatPointerSig' = authGossipFatPointerSig,
      authObservedFatPointer' = authObservedFatPointer,
    }
  }

  action GossipFatPointerSig(
    p: Proc_t,
    h: Height_t,
    r: Round_t,
    v: Snapshot_t,
    bytes: Bytes_t,
    sig: Sig_t,
  ): bool = {
    val msg = { src: p, height: h, round: r, id: v, bytes: bytes, sig: sig }
    all {
      FatPointerSigAuthentic(msg),
      ComposedStutter,
      authGossipPrecommit' = authGossipPrecommit,
      authObservedPrecommit' = authObservedPrecommit,
      authGossipFatPointerSig' =
        authGossipFatPointerSig.setBy(h, byRound =>
          byRound.setBy(r, old => old.union(Set(msg)))
        ),
      authObservedFatPointer' = authObservedFatPointer,
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
      AuthenticatedFatPointerValid(fp),
      ComposedStutter,
      authGossipPrecommit' = authGossipPrecommit,
      authObservedPrecommit' = authObservedPrecommit,
      authGossipFatPointerSig' = authGossipFatPointerSig,
      authObservedFatPointer' = authObservedFatPointer.union(Set(fp)),
    }
  }

  action ProtocolStep: bool =
    all { ProtocolNext, AuthEvidenceUnchanged }

  action FinalizeNextDynamicAuthenticated(
    p: Proc_t,
    candidate: Snapshot_t,
    tip: Snapshot_t,
    r: Round_t,
    signers: Set[Proc_t],
  ): bool = {
    val h = nextFinalityHeight
    all {
      AuthenticatedFatPointerObserved(h, r, candidate, signers),
      FinalizeNextDynamicDecided(p, candidate, tip),
      AuthEvidenceUnchanged,
    }
  }

  action AuthenticatedStutter = all {
    ComposedStutter,
    AuthEvidenceUnchanged,
  }

  action AuthenticatedNext =
    any {
      ProtocolStep,
      nondet p = oneOf(ValidatorUniverse)
      nondet h = oneOf(Heights)
      nondet r = oneOf(Rounds)
      nondet v = oneOf(Snapshots)
      nondet bytes = oneOf(Bytes)
      nondet sig = oneOf(Signatures)
      GossipPrecommit(p, h, r, v, bytes, sig),
      nondet p = oneOf(ValidatorUniverse)
      nondet h = oneOf(Heights)
      nondet r = oneOf(Rounds)
      nondet v = oneOf(Snapshots)
      nondet bytes = oneOf(Bytes)
      nondet sig = oneOf(Signatures)
      ObservePrecommit(p, h, r, v, bytes, sig),
      nondet p = oneOf(ValidatorUniverse)
      nondet h = oneOf(Heights)
      nondet r = oneOf(Rounds)
      nondet v = oneOf(Snapshots)
      nondet bytes = oneOf(Bytes)
      nondet sig = oneOf(Signatures)
      GossipFatPointerSig(p, h, r, v, bytes, sig),
      nondet h = oneOf(Heights)
      nondet r = oneOf(Rounds)
      nondet v = oneOf(Snapshots)
      nondet signers = oneOf(powerset(ValidatorUniverse))
      ObserveFatPointer(h, r, v, signers),
      nondet p = oneOf(Corr)
      nondet candidate = oneOf(Snapshots)
      nondet tip = oneOf(Snapshots)
      nondet r = oneOf(Rounds)
      nondet signers = oneOf(powerset(ValidatorUniverse))
      FinalizeNextDynamicAuthenticated(p, candidate, tip, r, signers),
      AuthenticatedStutter,
    }

  val GossipedPrecommitsAuthentic =
    Heights.forall(h =>
      Rounds.forall(r =>
        authGossipPrecommit.get(h).get(r).forall(PrecommitAuthentic)
      )
    )

  val ObservedPrecommitsWereGossiped =
    Heights.forall(h =>
      Rounds.forall(r =>
        authObservedPrecommit.get(h).get(r).forall(AuthGossipedPrecommit)
      )
    )

  val ObservedPrecommitsAuthentic =
    Heights.forall(h =>
      Rounds.forall(r =>
        authObservedPrecommit.get(h).get(r).forall(PrecommitAuthentic)
      )
    )

  val GossipedFatPointerSigsAuthentic =
    Heights.forall(h =>
      Rounds.forall(r =>
        authGossipFatPointerSig.get(h).get(r).forall(FatPointerSigAuthentic)
      )
    )

  val ObservedFatPointersValid =
    authObservedFatPointer.forall(AuthenticatedFatPointerValid)

  val FinalityDecisionsHaveAuthenticatedEvidence =
    Heights.forall(h =>
      finalityDecision.get(h) == NilSnapshot or
      authObservedFatPointer.exists(fp =>
        fp.height == h and
        fp.id == finalityDecision.get(h) and
        AuthenticatedFatPointerValid(fp)
      )
    )

  val AuthenticatedDynamicFinalitySafety =
    DynamicHeightedFinalitySafety and
    GossipedPrecommitsAuthentic and
    ObservedPrecommitsWereGossiped and
    ObservedPrecommitsAuthentic and
    GossipedFatPointerSigsAuthentic and
    ObservedFatPointersValid and
    FinalityDecisionsHaveAuthenticatedEvidence
}

module CrosslinkDynamicSigmaAuthenticatedFinalityTest {
  import CrosslinkDynamicSigmaAuthenticatedFinality.* from "./CrosslinkDynamicSigmaAuthenticatedFinality"
  export CrosslinkDynamicSigmaAuthenticatedFinality.*

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
    nextFinalityHeight' = nextFinalityHeight,
    finalityDecision' = finalityDecision,
    latestFinal' = latestFinal,
    finalized' = finalized,
    finalityAction' = finalityAction,
    authGossipPrecommit' = authGossipPrecommit,
    authObservedPrecommit' = authObservedPrecommit,
    authGossipFatPointerSig' = authGossipFatPointerSig,
    authObservedFatPointer' = authObservedFatPointer,
  }

  action CommitHeightOneForAll = all {
    ProposeAuth("p1")
      .then(DeliverProposalToAllAuth("p1", 1, 0, "a1", NilRound))
      .then(PrevoteValueAuth("p1", "a1"))
      .then(PrevoteValueAuth("p2", "a1"))
      .then(PrevoteValueAuth("p3", "a1"))
      .then(DeliverPrevoteQuorumToAllAuth(1, 0, "a1", Corr))
      .then(PrecommitValueAtAuth("p1", "a1"))
      .then(PrecommitValueAtAuth("p2", "a1"))
      .then(PrecommitValueAtAuth("p3", "a1"))
      .then(DeliverPrecommitQuorumToAllAuth(1, 0, "a1", Corr))
      .then(DecideValueAuth("p1", "a1"))
      .then(DecideValueAuth("p2", "a1"))
      .then(DecideValueAuth("p3", "a1"))
  }

  action CommitHeightTwoForAll = all {
    ProposeAuth("p1")
      .then(DeliverProposalToAllAuth("p1", 2, 0, "a2", NilRound))
      .then(PrevoteValueAuth("p1", "a2"))
      .then(PrevoteValueAuth("p2", "a2"))
      .then(PrevoteValueAuth("p3", "a2"))
      .then(DeliverPrevoteQuorumToAllAuth(2, 0, "a2", Corr))
      .then(PrecommitValueAtAuth("p1", "a2"))
      .then(PrecommitValueAtAuth("p2", "a2"))
      .then(PrecommitValueAtAuth("p3", "a2"))
      .then(DeliverPrecommitQuorumToAllAuth(2, 0, "a2", Corr))
      .then(DecideValueAuth("p1", "a2"))
      .then(DecideValueAuth("p2", "a2"))
      .then(DecideValueAuth("p3", "a2"))
  }

  action AuthenticateHeightOneA1 = all {
    GossipPrecommit("p1", 1, 0, "a1", "pc-1-0-a1", "sig-p1-pc-1-0-a1")
      .then(GossipPrecommit("p2", 1, 0, "a1", "pc-1-0-a1", "sig-p2-pc-1-0-a1"))
      .then(GossipPrecommit("p3", 1, 0, "a1", "pc-1-0-a1", "sig-p3-pc-1-0-a1"))
      .then(ObservePrecommit("p1", 1, 0, "a1", "pc-1-0-a1", "sig-p1-pc-1-0-a1"))
      .then(ObservePrecommit("p2", 1, 0, "a1", "pc-1-0-a1", "sig-p2-pc-1-0-a1"))
      .then(ObservePrecommit("p3", 1, 0, "a1", "pc-1-0-a1", "sig-p3-pc-1-0-a1"))
      .then(GossipFatPointerSig("p1", 1, 0, "a1", "fp-1-0-a1", "sig-p1-fp-1-0-a1"))
      .then(GossipFatPointerSig("p2", 1, 0, "a1", "fp-1-0-a1", "sig-p2-fp-1-0-a1"))
      .then(GossipFatPointerSig("p3", 1, 0, "a1", "fp-1-0-a1", "sig-p3-fp-1-0-a1"))
      .then(ObserveFatPointer(1, 0, "a1", Corr))
  }

  action AuthenticateHeightTwoA2 = all {
    GossipPrecommit("p1", 2, 0, "a2", "pc-2-0-a2", "sig-p1-pc-2-0-a2")
      .then(GossipPrecommit("p2", 2, 0, "a2", "pc-2-0-a2", "sig-p2-pc-2-0-a2"))
      .then(GossipPrecommit("p3", 2, 0, "a2", "pc-2-0-a2", "sig-p3-pc-2-0-a2"))
      .then(ObservePrecommit("p1", 2, 0, "a2", "pc-2-0-a2", "sig-p1-pc-2-0-a2"))
      .then(ObservePrecommit("p2", 2, 0, "a2", "pc-2-0-a2", "sig-p2-pc-2-0-a2"))
      .then(ObservePrecommit("p3", 2, 0, "a2", "pc-2-0-a2", "sig-p3-pc-2-0-a2"))
      .then(GossipFatPointerSig("p1", 2, 0, "a2", "fp-2-0-a2", "sig-p1-fp-2-0-a2"))
      .then(GossipFatPointerSig("p2", 2, 0, "a2", "fp-2-0-a2", "sig-p2-fp-2-0-a2"))
      .then(GossipFatPointerSig("p3", 2, 0, "a2", "fp-2-0-a2", "sig-p3-fp-2-0-a2"))
      .then(ObserveFatPointer(2, 0, "a2", Corr))
  }

  run authenticatedDynamicSigmaFinalityAcceptedTest = {
    AuthenticatedInit
      .then(CommitHeightOneForAll)
      .then(AuthenticateHeightOneA1)
      .then(FinalizeNextDynamicAuthenticated("p1", "a1", "a2", 0, Corr))
      .then(all {
        assert(finalityDecision.get(1) == "a1"),
        assert(FinalityDecisionsHaveAuthenticatedEvidence),
        assert(AuthenticatedDynamicFinalitySafety),
        unchangedAll,
      })
  }

  run telemetryRaisedSigmaFinalityRequiresAuthenticatedDynamicTailTest = {
    AuthenticatedInit
      .then(CommitHeightOneForAll)
      .then(AuthenticateHeightOneA1)
      .then(FinalizeNextDynamicAuthenticated("p1", "a1", "a2", 0, Corr))
      .then(CommitHeightTwoForAll)
      .then(AuthenticateHeightTwoA2)
      .then(FinalizeNextDynamicAuthenticated("p1", "a2", "a4", 0, Corr))
      .then(all {
        assert(SigmaForHeight(2) == 2),
        assert(finalityDecision.get(2) == "a2"),
        assert(AuthenticatedDynamicFinalitySafety),
        unchangedAll,
      })
  }

  run rejectsDynamicFinalityWithoutAuthenticatedFatPointerTest = {
    AuthenticatedInit
      .then(CommitHeightOneForAll)
      .then(FinalizeNextDynamicAuthenticated("p1", "a1", "a2", 0, Corr))
      .fail()
  }

  run rejectsWrongAuthenticatedCandidateForDynamicFinalityTest = {
    AuthenticatedInit
      .then(CommitHeightOneForAll)
      .then(AuthenticateHeightOneA1)
      .then(FinalizeNextDynamicAuthenticated("p1", "a2", "a2", 0, Corr))
      .fail()
  }

  run rejectsUngossipedAuthenticatedPrecommitObservationTest = {
    AuthenticatedInit
      .then(ObservePrecommit("p1", 1, 0, "a1", "pc-1-0-a1", "sig-p1-pc-1-0-a1"))
      .fail()
  }

  run authenticatedDynamicFinalitySafetyTest = {
    AuthenticatedInit
      .then(all {
        assert(AuthenticatedDynamicFinalitySafety),
        unchangedAll,
      })
  }
}

module CrosslinkDynamicSigmaAuthenticatedFinalityModel {
  import CrosslinkDynamicSigmaAuthenticatedFinalityTest(
    Corr = Set("p1", "p2", "p3"),
    Faulty = Set("p4"),
    VotingPower = Map("p1" -> 1, "p2" -> 1, "p3" -> 1, "p4" -> 1),
    QuorumVotingPower = 3,
    MaxBftHeight = 2,
    MaxRound = 0,
    Proposer = Map(
      1 -> Map(0 -> "p1"),
      2 -> Map(0 -> "p1"),
    ),
    Stream = Map(
      1 -> Map(0 -> "a1"),
      2 -> Map(0 -> "a2"),
    ),
    Snapshots = Set("g", "a1", "a2", "a3", "a4"),
    ResampleOnNilPrecommit = true,
    MaxPowHeight = 4,
    MinSigma = 1,
    MaxSigma = 3,
    InitialSigma = 1,
    FailureThreshold = 2,
    StableWindowThreshold = 2,
    CoverageTarget = 3,
    MaxCoverageScore = 4,
    HashPowerParticipationTargetPercent = 67,
    HashPowerParticipationFloorPercent = 25,
    MaxHashPowerParticipationPercent = 100,
    SigmaAtHeight = Map(
      1 -> 1,
      2 -> 2,
    ),
    CommittedFailureKind = Map(
      1 -> "long-reorg-tail",
      2 -> "none",
    ),
    CommittedFailureCount = Map(
      1 -> 2,
      2 -> 0,
    ),
    CommittedStableWindowCount = Map(
      1 -> 0,
      2 -> 2,
    ),
    CommittedCoverageScore = Map(
      1 -> 4,
      2 -> 4,
    ),
    CommittedHashPowerParticipationPercent = Map(
      1 -> 80,
      2 -> 80,
    ),
    InitialFinalized = "g",
    HeightOf = Map(
      "g" -> 0,
      "a1" -> 1,
      "a2" -> 2,
      "a3" -> 3,
      "a4" -> 4,
    ),
    AncestorAt = Map(
      "g" -> Map(0 -> "g", 1 -> "None", 2 -> "None", 3 -> "None", 4 -> "None"),
      "a1" -> Map(0 -> "g", 1 -> "a1", 2 -> "None", 3 -> "None", 4 -> "None"),
      "a2" -> Map(0 -> "g", 1 -> "a1", 2 -> "a2", 3 -> "None", 4 -> "None"),
      "a3" -> Map(0 -> "g", 1 -> "a1", 2 -> "a2", 3 -> "a3", 4 -> "None"),
      "a4" -> Map(0 -> "g", 1 -> "a1", 2 -> "a2", 3 -> "a3", 4 -> "a4"),
    ),
    AncestorSnapshotAt = Map(
      "g" -> Map(0 -> "g", 1 -> "None", 2 -> "None", 3 -> "None", 4 -> "None"),
      "a1" -> Map(0 -> "g", 1 -> "a1", 2 -> "None", 3 -> "None", 4 -> "None"),
      "a2" -> Map(0 -> "g", 1 -> "a1", 2 -> "a2", 3 -> "None", 4 -> "None"),
      "a3" -> Map(0 -> "g", 1 -> "a1", 2 -> "a2", 3 -> "a3", 4 -> "None"),
      "a4" -> Map(0 -> "g", 1 -> "a1", 2 -> "a2", 3 -> "a3", 4 -> "a4"),
    ),
    HeadAt = Map(
      1 -> Map(0 -> "a2"),
      2 -> Map(0 -> "a4"),
    ),
    Bytes = Set(
      "pc-1-0-g",
      "pc-1-0-a1",
      "pc-1-0-a2",
      "pc-1-0-a3",
      "pc-1-0-a4",
      "pc-2-0-g",
      "pc-2-0-a1",
      "pc-2-0-a2",
      "pc-2-0-a3",
      "pc-2-0-a4",
      "fp-1-0-g",
      "fp-1-0-a1",
      "fp-1-0-a2",
      "fp-1-0-a3",
      "fp-1-0-a4",
      "fp-2-0-g",
      "fp-2-0-a1",
      "fp-2-0-a2",
      "fp-2-0-a3",
      "fp-2-0-a4",
    ),
    Signatures = Set(
      "sig-p1-pc-1-0-a1",
      "sig-p2-pc-1-0-a1",
      "sig-p3-pc-1-0-a1",
      "sig-p1-fp-1-0-a1",
      "sig-p2-fp-1-0-a1",
      "sig-p3-fp-1-0-a1",
      "sig-p1-pc-2-0-a2",
      "sig-p2-pc-2-0-a2",
      "sig-p3-pc-2-0-a2",
      "sig-p1-fp-2-0-a2",
      "sig-p2-fp-2-0-a2",
      "sig-p3-fp-2-0-a2",
    ),
    SignatureOwner = Map(
      "sig-p1-pc-1-0-a1" -> "p1",
      "sig-p2-pc-1-0-a1" -> "p2",
      "sig-p3-pc-1-0-a1" -> "p3",
      "sig-p1-fp-1-0-a1" -> "p1",
      "sig-p2-fp-1-0-a1" -> "p2",
      "sig-p3-fp-1-0-a1" -> "p3",
      "sig-p1-pc-2-0-a2" -> "p1",
      "sig-p2-pc-2-0-a2" -> "p2",
      "sig-p3-pc-2-0-a2" -> "p3",
      "sig-p1-fp-2-0-a2" -> "p1",
      "sig-p2-fp-2-0-a2" -> "p2",
      "sig-p3-fp-2-0-a2" -> "p3",
    ),
    SignatureBytes = Map(
      "sig-p1-pc-1-0-a1" -> "pc-1-0-a1",
      "sig-p2-pc-1-0-a1" -> "pc-1-0-a1",
      "sig-p3-pc-1-0-a1" -> "pc-1-0-a1",
      "sig-p1-fp-1-0-a1" -> "fp-1-0-a1",
      "sig-p2-fp-1-0-a1" -> "fp-1-0-a1",
      "sig-p3-fp-1-0-a1" -> "fp-1-0-a1",
      "sig-p1-pc-2-0-a2" -> "pc-2-0-a2",
      "sig-p2-pc-2-0-a2" -> "pc-2-0-a2",
      "sig-p3-pc-2-0-a2" -> "pc-2-0-a2",
      "sig-p1-fp-2-0-a2" -> "fp-2-0-a2",
      "sig-p2-fp-2-0-a2" -> "fp-2-0-a2",
      "sig-p3-fp-2-0-a2" -> "fp-2-0-a2",
    ),
    PrecommitPayload = Map(
      1 -> Map(0 -> Map(
        "g" -> "pc-1-0-g",
        "a1" -> "pc-1-0-a1",
        "a2" -> "pc-1-0-a2",
        "a3" -> "pc-1-0-a3",
        "a4" -> "pc-1-0-a4",
      )),
      2 -> Map(0 -> Map(
        "g" -> "pc-2-0-g",
        "a1" -> "pc-2-0-a1",
        "a2" -> "pc-2-0-a2",
        "a3" -> "pc-2-0-a3",
        "a4" -> "pc-2-0-a4",
      )),
    ),
    FatPointerPayload = Map(
      1 -> Map(0 -> Map(
        "g" -> "fp-1-0-g",
        "a1" -> "fp-1-0-a1",
        "a2" -> "fp-1-0-a2",
        "a3" -> "fp-1-0-a3",
        "a4" -> "fp-1-0-a4",
      )),
      2 -> Map(0 -> Map(
        "g" -> "fp-2-0-g",
        "a1" -> "fp-2-0-a1",
        "a2" -> "fp-2-0-a2",
        "a3" -> "fp-2-0-a3",
        "a4" -> "fp-2-0-a4",
      )),
    ),
  ).*
}
