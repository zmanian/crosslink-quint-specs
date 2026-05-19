module CrosslinkHeightedAuthenticatedEvidence {
  /*
   Heighted evidence pipeline with authentication and validator-set rotation.

   This composes three standalone slices at a smaller boundary:
   - heighted canonical sign bytes,
   - evidence gossip before observer acceptance, and
   - validator-set authorization at the evidence BFT height.

   The model is intentionally focused on precommit/fat-pointer evidence because
   that is the accountability-critical data path.
   */

  type Proc_t = str
  type Snapshot_t = str
  type Height_t = int
  type Round_t = int
  type Bytes_t = str
  type Sig_t = str

  const ValidatorUniverse: Set[Proc_t]
  const VotingPower: Proc_t -> int
  const QuorumVotingPower: int
  const MaxBftHeight: Height_t
  const MaxRound: Round_t
  const Snapshots: Set[Snapshot_t]
  const Bytes: Set[Bytes_t]
  const Signatures: Set[Sig_t]
  const SignatureOwner: Sig_t -> Proc_t
  const SignatureBytes: Sig_t -> Bytes_t
  const PrecommitPayload: Height_t -> Round_t -> Snapshot_t -> Bytes_t
  const FatPointerPayload: Height_t -> Round_t -> Snapshot_t -> Bytes_t
  const InitialValidatorSet: Set[Proc_t]
  const NextValidatorSetOf: Snapshot_t -> Set[Proc_t]

  pure val Heights = 1.to(MaxBftHeight)
  pure val CursorHeights = 1.to(MaxBftHeight + 1)
  pure val Rounds = 0.to(MaxRound)
  pure val NilSnapshot = "None"
  pure val VoteValues = Snapshots.union(Set(NilSnapshot))

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
  assume signature_metadata_is_in_domain =
    Signatures.forall(s =>
      ValidatorUniverse.contains(SignatureOwner.get(s)) and
      Bytes.contains(SignatureBytes.get(s))
    )
  assume precommit_payloads_are_bytes =
    Heights.forall(h =>
      Rounds.forall(r =>
        VoteValues.forall(v =>
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

  var nextBftHeight: Height_t
  var currentValidatorSet: Set[Proc_t]
  var validatorSetAtHeight: Height_t -> Set[Proc_t]
  var decision: Height_t -> Snapshot_t
  var commitSigners: Height_t -> Set[Proc_t]
  var gossipPrecommit: Height_t -> Round_t -> Set[SignedVote_t]
  var gossipFatPointerSig: Height_t -> Round_t -> Set[SignedFatPointerSig_t]
  var observedPrecommit: Height_t -> Round_t -> Set[SignedVote_t]
  var observedFatPointer: Set[FatPointer_t]
  var firedAction: str

  pure def IsSnapshot(v: Snapshot_t): bool =
    Snapshots.contains(v)

  pure def VoteValueValid(v: Snapshot_t): bool =
    v == NilSnapshot or IsSnapshot(v)

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

  pure def Verify(p: Proc_t, bytes: Bytes_t, sig: Sig_t): bool =
    Signatures.contains(sig) and
    SignatureOwner.get(sig) == p and
    SignatureBytes.get(sig) == bytes

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

  def PrecommitAuthentic(m: SignedVote_t): bool =
    ValidatorUniverse.contains(m.src) and
    m.height.in(Heights) and
    m.round.in(Rounds) and
    VoteValueValid(m.id) and
    m.bytes == PrecommitPayload.get(m.height).get(m.round).get(m.id) and
    Verify(m.src, m.bytes, m.sig)

  def FatPointerSigAuthentic(m: SignedFatPointerSig_t): bool =
    ValidatorUniverse.contains(m.src) and
    m.height.in(Heights) and
    m.round.in(Rounds) and
    IsSnapshot(m.id) and
    m.bytes == FatPointerPayload.get(m.height).get(m.round).get(m.id) and
    Verify(m.src, m.bytes, m.sig)

  def GossipedPrecommit(m: SignedVote_t): bool =
    gossipPrecommit.get(m.height).get(m.round).contains(m)

  def ObservedPrecommit(m: SignedVote_t): bool =
    observedPrecommit.get(m.height).get(m.round).contains(m)

  def ObservedPrecommitFrom(
    p: Proc_t,
    h: Height_t,
    r: Round_t,
    v: Snapshot_t,
  ): bool =
    observedPrecommit.get(h).get(r).exists(m =>
      m.src == p and m.height == h and m.round == r and m.id == v
    )

  def GossipedFatPointerSigFrom(
    p: Proc_t,
    h: Height_t,
    r: Round_t,
    v: Snapshot_t,
  ): bool =
    gossipFatPointerSig.get(h).get(r).exists(m =>
      m.src == p and m.height == h and m.round == r and m.id == v and
      FatPointerSigAuthentic(m)
    )

  def ObservedFatPointerValid(fp: FatPointer_t): bool =
    ValidatorSetKnownAt(fp.height) and
    fp.round.in(Rounds) and
    IsSnapshot(fp.id) and
    SignerSetHasQuorum(fp.signers, ValidatorSetFor(fp.height)) and
    fp.signers.forall(p =>
      ObservedPrecommitFrom(p, fp.height, fp.round, fp.id) and
      GossipedFatPointerSigFrom(p, fp.height, fp.round, fp.id)
    )

  action Init = all {
    nextBftHeight' = 1,
    currentValidatorSet' = InitialValidatorSet,
    validatorSetAtHeight' = Heights.mapBy(_ => Set()),
    decision' = Heights.mapBy(_ => NilSnapshot),
    commitSigners' = Heights.mapBy(_ => Set()),
    gossipPrecommit' = Heights.mapBy(_ => Rounds.mapBy(_ => Set())),
    gossipFatPointerSig' = Heights.mapBy(_ => Rounds.mapBy(_ => Set())),
    observedPrecommit' = Heights.mapBy(_ => Rounds.mapBy(_ => Set())),
    observedFatPointer' = Set(),
    firedAction' = "Init",
  }

  action KeepSchedule = all {
    nextBftHeight' = nextBftHeight,
    currentValidatorSet' = currentValidatorSet,
    validatorSetAtHeight' = validatorSetAtHeight,
    decision' = decision,
    commitSigners' = commitSigners,
  }

  action KeepGossip = all {
    gossipPrecommit' = gossipPrecommit,
    gossipFatPointerSig' = gossipFatPointerSig,
  }

  action KeepObserved = all {
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
      KeepGossip,
      KeepObserved,
      firedAction' = "DecideAt",
    }

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
      ValidatorSetKnownAt(h),
      AuthorizedAtHeight(p, h),
      PrecommitAuthentic(msg),
      KeepSchedule,
      gossipPrecommit' =
        gossipPrecommit.setBy(h, byRound =>
          byRound.setBy(r, old => old.union(Set(msg)))
        ),
      gossipFatPointerSig' = gossipFatPointerSig,
      KeepObserved,
      firedAction' = "GossipPrecommit",
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
      AuthorizedAtHeight(p, h),
      GossipedPrecommit(msg),
      KeepSchedule,
      KeepGossip,
      observedPrecommit' =
        observedPrecommit.setBy(h, byRound =>
          byRound.setBy(r, old => old.union(Set(msg)))
        ),
      observedFatPointer' = observedFatPointer,
      firedAction' = "ObservePrecommit",
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
      ValidatorSetKnownAt(h),
      AuthorizedAtHeight(p, h),
      FatPointerSigAuthentic(msg),
      KeepSchedule,
      gossipPrecommit' = gossipPrecommit,
      gossipFatPointerSig' =
        gossipFatPointerSig.setBy(h, byRound =>
          byRound.setBy(r, old => old.union(Set(msg)))
        ),
      KeepObserved,
      firedAction' = "GossipFatPointerSig",
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
      KeepSchedule,
      KeepGossip,
      observedPrecommit' = observedPrecommit,
      observedFatPointer' = observedFatPointer.union(Set(fp)),
      firedAction' = "ObserveFatPointer",
    }
  }

  action Stutter = all {
    KeepSchedule,
    KeepGossip,
    KeepObserved,
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
      nondet v = oneOf(VoteValues)
      nondet bytes = oneOf(Bytes)
      nondet sig = oneOf(Signatures)
      GossipPrecommit(p, h, r, v, bytes, sig),
      nondet p = oneOf(ValidatorUniverse)
      nondet h = oneOf(Heights)
      nondet r = oneOf(Rounds)
      nondet v = oneOf(VoteValues)
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

  val GossipedPrecommitsAuthenticAndAuthorized =
    Heights.forall(h =>
      Rounds.forall(r =>
        gossipPrecommit.get(h).get(r).forall(m =>
          PrecommitAuthentic(m) and AuthorizedAtHeight(m.src, h)
        )
      )
    )

  val ObservedPrecommitsWereGossiped =
    Heights.forall(h =>
      Rounds.forall(r =>
        observedPrecommit.get(h).get(r).forall(m =>
          GossipedPrecommit(m)
        )
      )
    )

  val ObservedPrecommitsAuthenticAndAuthorized =
    Heights.forall(h =>
      Rounds.forall(r =>
        observedPrecommit.get(h).get(r).forall(m =>
          PrecommitAuthentic(m) and AuthorizedAtHeight(m.src, h)
        )
      )
    )

  val GossipedFatPointerSigsAuthenticAndAuthorized =
    Heights.forall(h =>
      Rounds.forall(r =>
        gossipFatPointerSig.get(h).get(r).forall(m =>
          FatPointerSigAuthentic(m) and AuthorizedAtHeight(m.src, h)
        )
      )
    )

  val ObservedFatPointersValid =
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
    GossipedPrecommitsAuthenticAndAuthorized and
    ObservedPrecommitsWereGossiped and
    ObservedPrecommitsAuthenticAndAuthorized and
    GossipedFatPointerSigsAuthenticAndAuthorized and
    ObservedFatPointersValid and
    CurrentValidatorSetMatchesCursor
}

module CrosslinkHeightedAuthenticatedEvidenceTest {
  import CrosslinkHeightedAuthenticatedEvidence.* from "./CrosslinkHeightedAuthenticatedEvidence"
  export CrosslinkHeightedAuthenticatedEvidence.*

  action unchangedAll = all {
    nextBftHeight' = nextBftHeight,
    currentValidatorSet' = currentValidatorSet,
    validatorSetAtHeight' = validatorSetAtHeight,
    decision' = decision,
    commitSigners' = commitSigners,
    gossipPrecommit' = gossipPrecommit,
    gossipFatPointerSig' = gossipFatPointerSig,
    observedPrecommit' = observedPrecommit,
    observedFatPointer' = observedFatPointer,
    firedAction' = firedAction,
  }

  run authenticatedRotatedSetEvidenceAcceptedTest = {
    Init
      .then(DecideAt(1, "rotate", Set("p1", "p2")))
      .then(GossipPrecommit("p2", 2, 0, "stay", "pc-2-0-stay", "sig-p2-pc-2-0-stay"))
      .then(GossipPrecommit("p4", 2, 0, "stay", "pc-2-0-stay", "sig-p4-pc-2-0-stay"))
      .then(ObservePrecommit("p2", 2, 0, "stay", "pc-2-0-stay", "sig-p2-pc-2-0-stay"))
      .then(ObservePrecommit("p4", 2, 0, "stay", "pc-2-0-stay", "sig-p4-pc-2-0-stay"))
      .then(GossipFatPointerSig("p2", 2, 0, "stay", "fp-2-0-stay", "sig-p2-fp-2-0-stay"))
      .then(GossipFatPointerSig("p4", 2, 0, "stay", "fp-2-0-stay", "sig-p4-fp-2-0-stay"))
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

  run removedValidatorSignedPrecommitRejectedAtNextHeightTest = {
    Init
      .then(DecideAt(1, "rotate", Set("p1", "p2")))
      .then(GossipPrecommit("p1", 2, 0, "stay", "pc-2-0-stay", "sig-p1-pc-2-0-stay"))
      .fail()
  }

  run wrongBytesPrecommitRejectedTest = {
    Init
      .then(GossipPrecommit("p1", 1, 0, "rotate", "pc-2-0-stay", "sig-p1-pc-2-0-stay"))
      .fail()
  }

  run crossHeightSignatureReplayRejectedTest = {
    Init
      .then(DecideAt(1, "rotate", Set("p1", "p2")))
      .then(GossipPrecommit("p2", 2, 0, "stay", "pc-1-0-stay", "sig-p2-pc-1-0-stay"))
      .fail()
  }

  run observationRequiresPriorGossipTest = {
    Init
      .then(ObservePrecommit("p1", 1, 0, "rotate", "pc-1-0-rotate", "sig-p1-pc-1-0-rotate"))
      .fail()
  }

  run oldHeightEvidenceUsesRecordedOldSetTest = {
    Init
      .then(DecideAt(1, "rotate", Set("p1", "p2")))
      .then(GossipPrecommit("p1", 1, 0, "rotate", "pc-1-0-rotate", "sig-p1-pc-1-0-rotate"))
      .then(GossipPrecommit("p2", 1, 0, "rotate", "pc-1-0-rotate", "sig-p2-pc-1-0-rotate"))
      .then(ObservePrecommit("p1", 1, 0, "rotate", "pc-1-0-rotate", "sig-p1-pc-1-0-rotate"))
      .then(ObservePrecommit("p2", 1, 0, "rotate", "pc-1-0-rotate", "sig-p2-pc-1-0-rotate"))
      .then(GossipFatPointerSig("p1", 1, 0, "rotate", "fp-1-0-rotate", "sig-p1-fp-1-0-rotate"))
      .then(GossipFatPointerSig("p2", 1, 0, "rotate", "fp-1-0-rotate", "sig-p2-fp-1-0-rotate"))
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

  run fatPointerRequiresObservedPrecommitsTest = {
    Init
      .then(GossipFatPointerSig("p1", 1, 0, "rotate", "fp-1-0-rotate", "sig-p1-fp-1-0-rotate"))
      .then(GossipFatPointerSig("p2", 1, 0, "rotate", "fp-1-0-rotate", "sig-p2-fp-1-0-rotate"))
      .then(ObserveFatPointer(1, 0, "rotate", Set("p1", "p2")))
      .fail()
  }
}

module CrosslinkHeightedAuthenticatedEvidenceModel {
  import CrosslinkHeightedAuthenticatedEvidenceTest(
    ValidatorUniverse = Set("p1", "p2", "p3", "p4"),
    VotingPower = Map("p1" -> 1, "p2" -> 1, "p3" -> 1, "p4" -> 1),
    QuorumVotingPower = 2,
    MaxBftHeight = 2,
    MaxRound = 0,
    Snapshots = Set("rotate", "stay"),
    Bytes = Set(
      "pc-1-0-rotate",
      "pc-1-0-stay",
      "pc-1-0-None",
      "pc-2-0-rotate",
      "pc-2-0-stay",
      "pc-2-0-None",
      "fp-1-0-rotate",
      "fp-1-0-stay",
      "fp-2-0-rotate",
      "fp-2-0-stay",
    ),
    Signatures = Set(
      "sig-p1-pc-1-0-rotate",
      "sig-p1-pc-2-0-stay",
      "sig-p1-fp-1-0-rotate",
      "sig-p2-pc-1-0-rotate",
      "sig-p2-pc-1-0-stay",
      "sig-p2-pc-2-0-stay",
      "sig-p2-fp-1-0-rotate",
      "sig-p2-fp-2-0-stay",
      "sig-p4-pc-2-0-stay",
      "sig-p4-fp-2-0-stay",
    ),
    SignatureOwner = Map(
      "sig-p1-pc-1-0-rotate" -> "p1",
      "sig-p1-pc-2-0-stay" -> "p1",
      "sig-p1-fp-1-0-rotate" -> "p1",
      "sig-p2-pc-1-0-rotate" -> "p2",
      "sig-p2-pc-1-0-stay" -> "p2",
      "sig-p2-pc-2-0-stay" -> "p2",
      "sig-p2-fp-1-0-rotate" -> "p2",
      "sig-p2-fp-2-0-stay" -> "p2",
      "sig-p4-pc-2-0-stay" -> "p4",
      "sig-p4-fp-2-0-stay" -> "p4",
    ),
    SignatureBytes = Map(
      "sig-p1-pc-1-0-rotate" -> "pc-1-0-rotate",
      "sig-p1-pc-2-0-stay" -> "pc-2-0-stay",
      "sig-p1-fp-1-0-rotate" -> "fp-1-0-rotate",
      "sig-p2-pc-1-0-rotate" -> "pc-1-0-rotate",
      "sig-p2-pc-1-0-stay" -> "pc-1-0-stay",
      "sig-p2-pc-2-0-stay" -> "pc-2-0-stay",
      "sig-p2-fp-1-0-rotate" -> "fp-1-0-rotate",
      "sig-p2-fp-2-0-stay" -> "fp-2-0-stay",
      "sig-p4-pc-2-0-stay" -> "pc-2-0-stay",
      "sig-p4-fp-2-0-stay" -> "fp-2-0-stay",
    ),
    PrecommitPayload = Map(
      1 -> Map(0 -> Map(
        "rotate" -> "pc-1-0-rotate",
        "stay" -> "pc-1-0-stay",
        "None" -> "pc-1-0-None",
      )),
      2 -> Map(0 -> Map(
        "rotate" -> "pc-2-0-rotate",
        "stay" -> "pc-2-0-stay",
        "None" -> "pc-2-0-None",
      )),
    ),
    FatPointerPayload = Map(
      1 -> Map(0 -> Map(
        "rotate" -> "fp-1-0-rotate",
        "stay" -> "fp-1-0-stay",
      )),
      2 -> Map(0 -> Map(
        "rotate" -> "fp-2-0-rotate",
        "stay" -> "fp-2-0-stay",
      )),
    ),
    InitialValidatorSet = Set("p1", "p2", "p3"),
    NextValidatorSetOf = Map(
      "rotate" -> Set("p2", "p3", "p4"),
      "stay" -> Set("p2", "p3", "p4"),
    ),
  ).*
}
