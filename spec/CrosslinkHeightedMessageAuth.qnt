module CrosslinkHeightedMessageAuth {
  /*
   Height-aware authentication boundary model.

   This extends the standalone message-authentication slice with the BFT height
   dimension used by CrosslinkHeightedRound.qnt and CrosslinkHeightedFinality.qnt.
   The rule is intentionally narrow: a signed proposal, vote, or fat-pointer
   signature is accepted only when the signature verifies for the claimed
   validator and the bytes are exactly the canonical bytes for the claimed
   height, round, value, and validRound.
   */

  type Proc_t = str
  type Snapshot_t = str
  type Height_t = int
  type Round_t = int
  type Bytes_t = str
  type Sig_t = str

  const Corr: Set[Proc_t]
  const Faulty: Set[Proc_t]
  const VotingPower: Proc_t -> int
  const QuorumVotingPower: int
  const MaxBftHeight: Height_t
  const MaxRound: Round_t
  const Snapshots: Set[Snapshot_t]
  const Bytes: Set[Bytes_t]
  const Signatures: Set[Sig_t]
  const SignatureOwner: Sig_t -> Proc_t
  const SignatureBytes: Sig_t -> Bytes_t
  const ProposalPayload: Height_t -> Round_t -> Snapshot_t -> Round_t -> Bytes_t
  const PrevotePayload: Height_t -> Round_t -> Snapshot_t -> Bytes_t
  const PrecommitPayload: Height_t -> Round_t -> Snapshot_t -> Bytes_t
  const FatPointerPayload: Height_t -> Round_t -> Snapshot_t -> Bytes_t

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
    Heights.forall(h =>
      Rounds.forall(r =>
        Snapshots.forall(v =>
          ProposalValidRounds.forall(vr =>
            Bytes.contains(ProposalPayload.get(h).get(r).get(v).get(vr))
          )
        )
      )
    )
  assume vote_payloads_are_bytes =
    Heights.forall(h =>
      Rounds.forall(r =>
        VoteValues.forall(v =>
          Bytes.contains(PrevotePayload.get(h).get(r).get(v)) and
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

  type SignedProposal_t = {
    src: Proc_t,
    height: Height_t,
    round: Round_t,
    proposal: Snapshot_t,
    validRound: Round_t,
    bytes: Bytes_t,
    sig: Sig_t,
  }

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

  var acceptedPropose: Height_t -> Round_t -> Set[SignedProposal_t]
  var acceptedPrevote: Height_t -> Round_t -> Set[SignedVote_t]
  var acceptedPrecommit: Height_t -> Round_t -> Set[SignedVote_t]
  var acceptedFatPointerSig: Height_t -> Round_t -> Set[SignedFatPointerSig_t]
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
    m.height.in(Heights) and
    m.round.in(Rounds) and
    IsSnapshot(m.proposal) and
    m.validRound.in(ProposalValidRounds) and
    m.bytes ==
      ProposalPayload.get(m.height).get(m.round).get(m.proposal).get(m.validRound) and
    Verify(m.src, m.bytes, m.sig)

  def VoteAuthentic(
    m: SignedVote_t,
    payload: Height_t -> Round_t -> Snapshot_t -> Bytes_t,
  ): bool =
    IsValidator(m.src) and
    m.height.in(Heights) and
    m.round.in(Rounds) and
    VoteValueValid(m.id) and
    m.bytes == payload.get(m.height).get(m.round).get(m.id) and
    Verify(m.src, m.bytes, m.sig)

  def FatPointerSigAuthentic(m: SignedFatPointerSig_t): bool =
    IsValidator(m.src) and
    m.height.in(Heights) and
    m.round.in(Rounds) and
    IsSnapshot(m.id) and
    m.bytes == FatPointerPayload.get(m.height).get(m.round).get(m.id) and
    Verify(m.src, m.bytes, m.sig)

  pure def FatPointerSigners(votes: Set[SignedFatPointerSig_t]): Set[Proc_t] =
    votes.map(m => m.src)

  def AcceptedFatPointerQuorum(
    h: Height_t,
    r: Round_t,
    v: Snapshot_t,
  ): bool =
    VotingPowerOf(FatPointerSigners(acceptedFatPointerSig.get(h).get(r).filter(m =>
      m.id == v
    ))) >= QuorumVotingPower

  action Init = all {
    acceptedPropose' = Heights.mapBy(_ => Rounds.mapBy(_ => Set())),
    acceptedPrevote' = Heights.mapBy(_ => Rounds.mapBy(_ => Set())),
    acceptedPrecommit' = Heights.mapBy(_ => Rounds.mapBy(_ => Set())),
    acceptedFatPointerSig' = Heights.mapBy(_ => Rounds.mapBy(_ => Set())),
    firedAction' = "Init",
  }

  action AcceptProposal(
    p: Proc_t,
    h: Height_t,
    r: Round_t,
    v: Snapshot_t,
    vr: Round_t,
    bytes: Bytes_t,
    sig: Sig_t,
  ): bool = {
    val msg = {
      src: p,
      height: h,
      round: r,
      proposal: v,
      validRound: vr,
      bytes: bytes,
      sig: sig,
    }
    all {
      ProposalAuthentic(msg),
      acceptedPropose' =
        acceptedPropose.setBy(h, byRound =>
          byRound.setBy(r, old => old.union(Set(msg)))
        ),
      acceptedPrevote' = acceptedPrevote,
      acceptedPrecommit' = acceptedPrecommit,
      acceptedFatPointerSig' = acceptedFatPointerSig,
      firedAction' = "AcceptProposal",
    }
  }

  action AcceptPrevote(
    p: Proc_t,
    h: Height_t,
    r: Round_t,
    v: Snapshot_t,
    bytes: Bytes_t,
    sig: Sig_t,
  ): bool = {
    val msg = { src: p, height: h, round: r, id: v, bytes: bytes, sig: sig }
    all {
      VoteAuthentic(msg, PrevotePayload),
      acceptedPropose' = acceptedPropose,
      acceptedPrevote' =
        acceptedPrevote.setBy(h, byRound =>
          byRound.setBy(r, old => old.union(Set(msg)))
        ),
      acceptedPrecommit' = acceptedPrecommit,
      acceptedFatPointerSig' = acceptedFatPointerSig,
      firedAction' = "AcceptPrevote",
    }
  }

  action AcceptPrecommit(
    p: Proc_t,
    h: Height_t,
    r: Round_t,
    v: Snapshot_t,
    bytes: Bytes_t,
    sig: Sig_t,
  ): bool = {
    val msg = { src: p, height: h, round: r, id: v, bytes: bytes, sig: sig }
    all {
      VoteAuthentic(msg, PrecommitPayload),
      acceptedPropose' = acceptedPropose,
      acceptedPrevote' = acceptedPrevote,
      acceptedPrecommit' =
        acceptedPrecommit.setBy(h, byRound =>
          byRound.setBy(r, old => old.union(Set(msg)))
        ),
      acceptedFatPointerSig' = acceptedFatPointerSig,
      firedAction' = "AcceptPrecommit",
    }
  }

  action AcceptFatPointerSig(
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
      acceptedPropose' = acceptedPropose,
      acceptedPrevote' = acceptedPrevote,
      acceptedPrecommit' = acceptedPrecommit,
      acceptedFatPointerSig' =
        acceptedFatPointerSig.setBy(h, byRound =>
          byRound.setBy(r, old => old.union(Set(msg)))
        ),
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
      nondet h = oneOf(Heights)
      nondet r = oneOf(Rounds)
      nondet v = oneOf(Snapshots)
      nondet vr = oneOf(ProposalValidRounds)
      nondet bytes = oneOf(Bytes)
      nondet sig = oneOf(Signatures)
      AcceptProposal(p, h, r, v, vr, bytes, sig),
      nondet p = oneOf(Corr.union(Faulty))
      nondet h = oneOf(Heights)
      nondet r = oneOf(Rounds)
      nondet v = oneOf(VoteValues)
      nondet bytes = oneOf(Bytes)
      nondet sig = oneOf(Signatures)
      AcceptPrevote(p, h, r, v, bytes, sig),
      nondet p = oneOf(Corr.union(Faulty))
      nondet h = oneOf(Heights)
      nondet r = oneOf(Rounds)
      nondet v = oneOf(VoteValues)
      nondet bytes = oneOf(Bytes)
      nondet sig = oneOf(Signatures)
      AcceptPrecommit(p, h, r, v, bytes, sig),
      nondet p = oneOf(Corr.union(Faulty))
      nondet h = oneOf(Heights)
      nondet r = oneOf(Rounds)
      nondet v = oneOf(Snapshots)
      nondet bytes = oneOf(Bytes)
      nondet sig = oneOf(Signatures)
      AcceptFatPointerSig(p, h, r, v, bytes, sig),
      Stutter,
    }

  val AcceptedProposalsAuthentic =
    Heights.forall(h =>
      Rounds.forall(r =>
        acceptedPropose.get(h).get(r).forall(ProposalAuthentic)
      )
    )

  val AcceptedPrevotesAuthentic =
    Heights.forall(h =>
      Rounds.forall(r =>
        acceptedPrevote.get(h).get(r).forall(m => VoteAuthentic(m, PrevotePayload))
      )
    )

  val AcceptedPrecommitsAuthentic =
    Heights.forall(h =>
      Rounds.forall(r =>
        acceptedPrecommit.get(h).get(r).forall(m =>
          VoteAuthentic(m, PrecommitPayload)
        )
      )
    )

  val AcceptedFatPointerSigsAuthentic =
    Heights.forall(h =>
      Rounds.forall(r =>
        acceptedFatPointerSig.get(h).get(r).forall(FatPointerSigAuthentic)
      )
    )

  val Safety =
    AcceptedProposalsAuthentic and
    AcceptedPrevotesAuthentic and
    AcceptedPrecommitsAuthentic and
    AcceptedFatPointerSigsAuthentic
}

module CrosslinkHeightedMessageAuthTest {
  import CrosslinkHeightedMessageAuth.* from "./CrosslinkHeightedMessageAuth"
  export CrosslinkHeightedMessageAuth.*

  action unchangedAll = all {
    acceptedPropose' = acceptedPropose,
    acceptedPrevote' = acceptedPrevote,
    acceptedPrecommit' = acceptedPrecommit,
    acceptedFatPointerSig' = acceptedFatPointerSig,
    firedAction' = firedAction,
  }

  run acceptsCanonicalHeightedProposalSignatureTest = {
    Init
      .then(AcceptProposal(
        "p1",
        1,
        0,
        "h1r0",
        NilRound,
        "h1r0_proposal_nil",
        "sig_p1_h1r0_proposal_nil",
      ))
      .then(all {
        assert(acceptedPropose.get(1).get(0).exists(m =>
          m.src == "p1" and m.proposal == "h1r0"
        )),
        assert(Safety),
        unchangedAll,
      })
  }

  run rejectsCrossHeightPrecommitReplayTest = {
    Init
      .then(AcceptPrecommit(
        "p1",
        2,
        0,
        "h2r0",
        "h1r0_precommit",
        "sig_p1_h1r0_precommit",
      ))
      .fail()
  }

  run rejectsForgedHeightedPrevoteSignatureTest = {
    Init
      .then(AcceptPrevote(
        "p1",
        1,
        0,
        "h1r0",
        "h1r0_prevote",
        "sig_bad",
      ))
      .fail()
  }

  run acceptsHeightedFatPointerSignatureQuorumTest = {
    Init
      .then(AcceptFatPointerSig("p1", 1, 0, "h1r0", "h1r0_fat_pointer", "sig_p1_h1r0_fp"))
      .then(AcceptFatPointerSig("p2", 1, 0, "h1r0", "h1r0_fat_pointer", "sig_p2_h1r0_fp"))
      .then(AcceptFatPointerSig("p3", 1, 0, "h1r0", "h1r0_fat_pointer", "sig_p3_h1r0_fp"))
      .then(all {
        assert(AcceptedFatPointerQuorum(1, 0, "h1r0")),
        assert(Safety),
        unchangedAll,
      })
  }
}

module CrosslinkHeightedMessageAuthModel {
  import CrosslinkHeightedMessageAuthTest(
    Corr = Set("p1", "p2", "p3"),
    Faulty = Set("p4"),
    VotingPower = Map("p1" -> 1, "p2" -> 1, "p3" -> 1, "p4" -> 1),
    QuorumVotingPower = 3,
    MaxBftHeight = 2,
    MaxRound = 0,
    Snapshots = Set("h1r0", "h2r0"),
    Bytes = Set(
      "h1r0_proposal_nil",
      "h1r0_proposal_r0",
      "h2r0_proposal_nil",
      "h2r0_proposal_r0",
      "h1r0_prevote",
      "h2r0_prevote",
      "h1_nil_prevote",
      "h2_nil_prevote",
      "h1r0_precommit",
      "h2r0_precommit",
      "h1_nil_precommit",
      "h2_nil_precommit",
      "h1r0_fat_pointer",
      "h2r0_fat_pointer",
      "bad_bytes",
    ),
    Signatures = Set(
      "sig_p1_h1r0_proposal_nil",
      "sig_p1_h1r0_precommit",
      "sig_p1_h1r0_prevote",
      "sig_p1_h1r0_fp",
      "sig_p2_h1r0_fp",
      "sig_p3_h1r0_fp",
      "sig_bad",
    ),
    SignatureOwner = Map(
      "sig_p1_h1r0_proposal_nil" -> "p1",
      "sig_p1_h1r0_precommit" -> "p1",
      "sig_p1_h1r0_prevote" -> "p1",
      "sig_p1_h1r0_fp" -> "p1",
      "sig_p2_h1r0_fp" -> "p2",
      "sig_p3_h1r0_fp" -> "p3",
      "sig_bad" -> "p4",
    ),
    SignatureBytes = Map(
      "sig_p1_h1r0_proposal_nil" -> "h1r0_proposal_nil",
      "sig_p1_h1r0_precommit" -> "h1r0_precommit",
      "sig_p1_h1r0_prevote" -> "h1r0_prevote",
      "sig_p1_h1r0_fp" -> "h1r0_fat_pointer",
      "sig_p2_h1r0_fp" -> "h1r0_fat_pointer",
      "sig_p3_h1r0_fp" -> "h1r0_fat_pointer",
      "sig_bad" -> "bad_bytes",
    ),
    ProposalPayload = Map(
      1 -> Map(
        0 -> Map(
          "h1r0" -> Map(-1 -> "h1r0_proposal_nil", 0 -> "h1r0_proposal_r0"),
          "h2r0" -> Map(-1 -> "h2r0_proposal_nil", 0 -> "h2r0_proposal_r0"),
        ),
      ),
      2 -> Map(
        0 -> Map(
          "h1r0" -> Map(-1 -> "h1r0_proposal_nil", 0 -> "h1r0_proposal_r0"),
          "h2r0" -> Map(-1 -> "h2r0_proposal_nil", 0 -> "h2r0_proposal_r0"),
        ),
      ),
    ),
    PrevotePayload = Map(
      1 -> Map(0 -> Map("h1r0" -> "h1r0_prevote", "h2r0" -> "h2r0_prevote", "None" -> "h1_nil_prevote")),
      2 -> Map(0 -> Map("h1r0" -> "h1r0_prevote", "h2r0" -> "h2r0_prevote", "None" -> "h2_nil_prevote")),
    ),
    PrecommitPayload = Map(
      1 -> Map(0 -> Map("h1r0" -> "h1r0_precommit", "h2r0" -> "h2r0_precommit", "None" -> "h1_nil_precommit")),
      2 -> Map(0 -> Map("h1r0" -> "h1r0_precommit", "h2r0" -> "h2r0_precommit", "None" -> "h2_nil_precommit")),
    ),
    FatPointerPayload = Map(
      1 -> Map(0 -> Map("h1r0" -> "h1r0_fat_pointer", "h2r0" -> "h2r0_fat_pointer")),
      2 -> Map(0 -> Map("h1r0" -> "h1r0_fat_pointer", "h2r0" -> "h2r0_fat_pointer")),
    ),
  ).*
}
