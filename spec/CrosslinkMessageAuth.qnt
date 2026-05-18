module CrosslinkMessageAuth {
  /*
   Authentication and canonical-payload boundary model.

   This is not a cryptographic model. It records the protocol rule the
   implementation must enforce before any proposal, vote, or fat-pointer
   signature becomes evidence: the signature must verify for the validator and
   the bytes must be the canonical bytes for exactly the claimed message.
   */

  type Proc_t = str
  type Snapshot_t = str
  type Round_t = int
  type Bytes_t = str
  type Sig_t = str

  const Corr: Set[Proc_t]
  const Faulty: Set[Proc_t]
  const VotingPower: Proc_t -> int
  const QuorumVotingPower: int
  const MaxRound: Round_t
  const Snapshots: Set[Snapshot_t]
  const Bytes: Set[Bytes_t]
  const Signatures: Set[Sig_t]
  const SignatureOwner: Sig_t -> Proc_t
  const SignatureBytes: Sig_t -> Bytes_t
  const ProposalPayload: Round_t -> Snapshot_t -> Round_t -> Bytes_t
  const PrevotePayload: Round_t -> Snapshot_t -> Bytes_t
  const PrecommitPayload: Round_t -> Snapshot_t -> Bytes_t
  const FatPointerPayload: Round_t -> Snapshot_t -> Bytes_t

  pure val Rounds = 0.to(MaxRound)
  pure val NilSnapshot = "None"
  pure val ProposalValidRounds = Rounds.union(Set(-1))
  pure val VoteValues = Snapshots.union(Set(NilSnapshot))

  pure def VotingPowerOf(voters: Set[Proc_t]): int =
    voters.fold(0, (acc, p) => acc + VotingPower.get(p))

  assume corr_and_faulty_disjoint =
    Corr.intersect(Faulty) == Set()
  assume validator_power_is_positive =
    Corr.union(Faulty).forall(p => VotingPower.get(p) > 0)
  assume quorum_intersection_has_correct_power =
    2 * QuorumVotingPower > VotingPowerOf(Corr.union(Faulty))
  assume nil_is_not_snapshot =
    not(Snapshots.contains(NilSnapshot))
  assume signature_metadata_is_in_domain =
    Signatures.forall(s =>
      Corr.union(Faulty).contains(SignatureOwner.get(s)) and
      Bytes.contains(SignatureBytes.get(s))
    )
  assume proposal_payloads_are_bytes =
    Rounds.forall(r =>
      Snapshots.forall(v =>
        ProposalValidRounds.forall(vr =>
          Bytes.contains(ProposalPayload.get(r).get(v).get(vr))
        )
      )
    )
  assume vote_payloads_are_bytes =
    Rounds.forall(r =>
      VoteValues.forall(v =>
        Bytes.contains(PrevotePayload.get(r).get(v)) and
        Bytes.contains(PrecommitPayload.get(r).get(v))
      )
    )
  assume fat_pointer_payloads_are_bytes =
    Rounds.forall(r =>
      Snapshots.forall(v =>
        Bytes.contains(FatPointerPayload.get(r).get(v))
      )
    )

  type SignedProposal_t = {
    src: Proc_t,
    round: Round_t,
    proposal: Snapshot_t,
    validRound: Round_t,
    bytes: Bytes_t,
    sig: Sig_t,
  }

  type SignedVote_t = {
    src: Proc_t,
    round: Round_t,
    id: Snapshot_t,
    bytes: Bytes_t,
    sig: Sig_t,
  }

  type SignedFatPointerSig_t = {
    src: Proc_t,
    round: Round_t,
    id: Snapshot_t,
    bytes: Bytes_t,
    sig: Sig_t,
  }

  var acceptedPropose: Round_t -> Set[SignedProposal_t]
  var acceptedPrevote: Round_t -> Set[SignedVote_t]
  var acceptedPrecommit: Round_t -> Set[SignedVote_t]
  var acceptedFatPointerSig: Round_t -> Set[SignedFatPointerSig_t]
  var firedAction: str

  pure def IsValidator(p: Proc_t): bool =
    Corr.union(Faulty).contains(p)

  pure def IsSnapshot(v: Snapshot_t): bool =
    Snapshots.contains(v)

  pure def VoteValueValid(v: Snapshot_t): bool =
    v == NilSnapshot or IsSnapshot(v)

  pure def Verify(p: Proc_t, bytes: Bytes_t, sig: Sig_t): bool =
    Signatures.contains(sig) and
    SignatureOwner.get(sig) == p and
    SignatureBytes.get(sig) == bytes

  def ProposalAuthentic(m: SignedProposal_t): bool =
    IsValidator(m.src) and
    m.round.in(Rounds) and
    IsSnapshot(m.proposal) and
    m.validRound.in(ProposalValidRounds) and
    m.bytes == ProposalPayload.get(m.round).get(m.proposal).get(m.validRound) and
    Verify(m.src, m.bytes, m.sig)

  def VoteAuthentic(
    m: SignedVote_t,
    payload: Round_t -> Snapshot_t -> Bytes_t,
  ): bool =
    IsValidator(m.src) and
    m.round.in(Rounds) and
    VoteValueValid(m.id) and
    m.bytes == payload.get(m.round).get(m.id) and
    Verify(m.src, m.bytes, m.sig)

  def FatPointerSigAuthentic(m: SignedFatPointerSig_t): bool =
    IsValidator(m.src) and
    m.round.in(Rounds) and
    IsSnapshot(m.id) and
    m.bytes == FatPointerPayload.get(m.round).get(m.id) and
    Verify(m.src, m.bytes, m.sig)

  pure def Voters(votes: Set[SignedFatPointerSig_t]): Set[Proc_t] =
    votes.map(m => m.src)

  def AcceptedFatPointerQuorum(r: Round_t, v: Snapshot_t): bool =
    VotingPowerOf(Voters(acceptedFatPointerSig.get(r).filter(m => m.id == v))) >=
    QuorumVotingPower

  action Init = all {
    acceptedPropose' = Rounds.mapBy(_ => Set()),
    acceptedPrevote' = Rounds.mapBy(_ => Set()),
    acceptedPrecommit' = Rounds.mapBy(_ => Set()),
    acceptedFatPointerSig' = Rounds.mapBy(_ => Set()),
    firedAction' = "Init",
  }

  action AcceptProposal(
    p: Proc_t,
    r: Round_t,
    v: Snapshot_t,
    vr: Round_t,
    bytes: Bytes_t,
    sig: Sig_t,
  ): bool = {
    val msg = {
      src: p,
      round: r,
      proposal: v,
      validRound: vr,
      bytes: bytes,
      sig: sig,
    }
    all {
      ProposalAuthentic(msg),
      acceptedPropose' = acceptedPropose.setBy(r, old => old.union(Set(msg))),
      acceptedPrevote' = acceptedPrevote,
      acceptedPrecommit' = acceptedPrecommit,
      acceptedFatPointerSig' = acceptedFatPointerSig,
      firedAction' = "AcceptProposal",
    }
  }

  action AcceptPrevote(
    p: Proc_t,
    r: Round_t,
    v: Snapshot_t,
    bytes: Bytes_t,
    sig: Sig_t,
  ): bool = {
    val msg = { src: p, round: r, id: v, bytes: bytes, sig: sig }
    all {
      VoteAuthentic(msg, PrevotePayload),
      acceptedPropose' = acceptedPropose,
      acceptedPrevote' = acceptedPrevote.setBy(r, old => old.union(Set(msg))),
      acceptedPrecommit' = acceptedPrecommit,
      acceptedFatPointerSig' = acceptedFatPointerSig,
      firedAction' = "AcceptPrevote",
    }
  }

  action AcceptPrecommit(
    p: Proc_t,
    r: Round_t,
    v: Snapshot_t,
    bytes: Bytes_t,
    sig: Sig_t,
  ): bool = {
    val msg = { src: p, round: r, id: v, bytes: bytes, sig: sig }
    all {
      VoteAuthentic(msg, PrecommitPayload),
      acceptedPropose' = acceptedPropose,
      acceptedPrevote' = acceptedPrevote,
      acceptedPrecommit' =
        acceptedPrecommit.setBy(r, old => old.union(Set(msg))),
      acceptedFatPointerSig' = acceptedFatPointerSig,
      firedAction' = "AcceptPrecommit",
    }
  }

  action AcceptFatPointerSig(
    p: Proc_t,
    r: Round_t,
    v: Snapshot_t,
    bytes: Bytes_t,
    sig: Sig_t,
  ): bool = {
    val msg = { src: p, round: r, id: v, bytes: bytes, sig: sig }
    all {
      FatPointerSigAuthentic(msg),
      acceptedPropose' = acceptedPropose,
      acceptedPrevote' = acceptedPrevote,
      acceptedPrecommit' = acceptedPrecommit,
      acceptedFatPointerSig' =
        acceptedFatPointerSig.setBy(r, old => old.union(Set(msg))),
      firedAction' = "AcceptFatPointerSig",
    }
  }

  action Stutter = all {
    acceptedPropose' = acceptedPropose,
    acceptedPrevote' = acceptedPrevote,
    acceptedPrecommit' = acceptedPrecommit,
    acceptedFatPointerSig' = acceptedFatPointerSig,
    firedAction' = "Stutter",
  }

  action Next =
    any {
      nondet p = oneOf(Corr.union(Faulty))
      nondet r = oneOf(Rounds)
      nondet v = oneOf(Snapshots)
      nondet vr = oneOf(ProposalValidRounds)
      nondet bytes = oneOf(Bytes)
      nondet sig = oneOf(Signatures)
      AcceptProposal(p, r, v, vr, bytes, sig),
      nondet p = oneOf(Corr.union(Faulty))
      nondet r = oneOf(Rounds)
      nondet v = oneOf(VoteValues)
      nondet bytes = oneOf(Bytes)
      nondet sig = oneOf(Signatures)
      AcceptPrevote(p, r, v, bytes, sig),
      nondet p = oneOf(Corr.union(Faulty))
      nondet r = oneOf(Rounds)
      nondet v = oneOf(VoteValues)
      nondet bytes = oneOf(Bytes)
      nondet sig = oneOf(Signatures)
      AcceptPrecommit(p, r, v, bytes, sig),
      nondet p = oneOf(Corr.union(Faulty))
      nondet r = oneOf(Rounds)
      nondet v = oneOf(Snapshots)
      nondet bytes = oneOf(Bytes)
      nondet sig = oneOf(Signatures)
      AcceptFatPointerSig(p, r, v, bytes, sig),
      Stutter,
    }

  val AcceptedProposalsAuthentic =
    Rounds.forall(r =>
      acceptedPropose.get(r).forall(ProposalAuthentic)
    )

  val AcceptedPrevotesAuthentic =
    Rounds.forall(r =>
      acceptedPrevote.get(r).forall(m => VoteAuthentic(m, PrevotePayload))
    )

  val AcceptedPrecommitsAuthentic =
    Rounds.forall(r =>
      acceptedPrecommit.get(r).forall(m => VoteAuthentic(m, PrecommitPayload))
    )

  val AcceptedFatPointerSigsAuthentic =
    Rounds.forall(r =>
      acceptedFatPointerSig.get(r).forall(FatPointerSigAuthentic)
    )

  val Safety =
    AcceptedProposalsAuthentic and
    AcceptedPrevotesAuthentic and
    AcceptedPrecommitsAuthentic and
    AcceptedFatPointerSigsAuthentic
}

module CrosslinkMessageAuthTest {
  import CrosslinkMessageAuth.* from "./CrosslinkMessageAuth"
  export CrosslinkMessageAuth.*

  action unchangedAll = all {
    acceptedPropose' = acceptedPropose,
    acceptedPrevote' = acceptedPrevote,
    acceptedPrecommit' = acceptedPrecommit,
    acceptedFatPointerSig' = acceptedFatPointerSig,
    firedAction' = firedAction,
  }

  run acceptsCanonicalProposalSignatureTest = {
    Init
      .then(AcceptProposal("p1", 0, "s0", -1, "proposal_s0_nil", "sig_p1_proposal_s0_nil"))
      .then(all {
        assert(acceptedPropose.get(0).exists(m =>
          m.src == "p1" and m.proposal == "s0"
        )),
        assert(Safety),
        unchangedAll,
      })
  }

  run rejectsMismatchedPrecommitBytesTest = {
    Init
      .then(AcceptPrecommit("p1", 0, "s0", "precommit_s1", "sig_p1_precommit_s1"))
      .fail()
  }

  run rejectsForgedSignatureTest = {
    Init
      .then(AcceptPrevote("p1", 0, "s0", "prevote_s0", "sig_bad"))
      .fail()
  }

  run acceptsFatPointerSignatureQuorumTest = {
    Init
      .then(AcceptFatPointerSig("p1", 0, "s0", "fat_pointer_s0", "sig_p1_fp_s0"))
      .then(AcceptFatPointerSig("p2", 0, "s0", "fat_pointer_s0", "sig_p2_fp_s0"))
      .then(AcceptFatPointerSig("p3", 0, "s0", "fat_pointer_s0", "sig_p3_fp_s0"))
      .then(all {
        assert(AcceptedFatPointerQuorum(0, "s0")),
        assert(Safety),
        unchangedAll,
      })
  }

  run rejectsFatPointerSignatureOnWrongPayloadTest = {
    Init
      .then(AcceptFatPointerSig("p1", 0, "s0", "fat_pointer_s1", "sig_p1_fp_s1"))
      .fail()
  }
}

module CrosslinkMessageAuthModel {
  import CrosslinkMessageAuthTest(
    Corr = Set("p1", "p2", "p3"),
    Faulty = Set("p4"),
    VotingPower = Map("p1" -> 1, "p2" -> 1, "p3" -> 1, "p4" -> 1),
    QuorumVotingPower = 3,
    MaxRound = 0,
    Snapshots = Set("s0", "s1"),
    Bytes = Set(
      "proposal_s0_nil",
      "proposal_s0_r0",
      "proposal_s1_nil",
      "proposal_s1_r0",
      "prevote_s0",
      "prevote_s1",
      "prevote_nil",
      "precommit_s0",
      "precommit_s1",
      "precommit_nil",
      "fat_pointer_s0",
      "fat_pointer_s1",
      "bad_bytes",
    ),
    Signatures = Set(
      "sig_p1_proposal_s0_nil",
      "sig_p1_precommit_s1",
      "sig_p1_prevote_s0",
      "sig_p1_fp_s0",
      "sig_p2_fp_s0",
      "sig_p3_fp_s0",
      "sig_p1_fp_s1",
      "sig_bad",
    ),
    SignatureOwner = Map(
      "sig_p1_proposal_s0_nil" -> "p1",
      "sig_p1_precommit_s1" -> "p1",
      "sig_p1_prevote_s0" -> "p1",
      "sig_p1_fp_s0" -> "p1",
      "sig_p2_fp_s0" -> "p2",
      "sig_p3_fp_s0" -> "p3",
      "sig_p1_fp_s1" -> "p1",
      "sig_bad" -> "p4",
    ),
    SignatureBytes = Map(
      "sig_p1_proposal_s0_nil" -> "proposal_s0_nil",
      "sig_p1_precommit_s1" -> "precommit_s1",
      "sig_p1_prevote_s0" -> "prevote_s0",
      "sig_p1_fp_s0" -> "fat_pointer_s0",
      "sig_p2_fp_s0" -> "fat_pointer_s0",
      "sig_p3_fp_s0" -> "fat_pointer_s0",
      "sig_p1_fp_s1" -> "fat_pointer_s1",
      "sig_bad" -> "bad_bytes",
    ),
    ProposalPayload = Map(
      0 -> Map(
        "s0" -> Map(-1 -> "proposal_s0_nil", 0 -> "proposal_s0_r0"),
        "s1" -> Map(-1 -> "proposal_s1_nil", 0 -> "proposal_s1_r0"),
      ),
    ),
    PrevotePayload = Map(
      0 -> Map("s0" -> "prevote_s0", "s1" -> "prevote_s1", "None" -> "prevote_nil"),
    ),
    PrecommitPayload = Map(
      0 -> Map("s0" -> "precommit_s0", "s1" -> "precommit_s1", "None" -> "precommit_nil"),
    ),
    FatPointerPayload = Map(
      0 -> Map("s0" -> "fat_pointer_s0", "s1" -> "fat_pointer_s1"),
    ),
  ).*
}
