module CrosslinkBftBlockShape {
  /*
   Concrete Crosslink BFT block/header shape model.

   The abstract head-sigma model says the proposal candidate is the PoW
   ancestor at `head - sigma`. The current Zebra prototype builds a BftBlock by
   asking state for `FindBlockHeaders { known_blocks: [candidate], stop: None }`.
   Zebra's Find protocol returns headers after the intersection, so this model
   makes that boundary explicit: a proposal can carry exactly sigma descendant
   headers while the finality candidate remains the declared `head - sigma`
   ancestor, not necessarily `headers[0]`.
   */

  type Snapshot_t = str
  type Block_t = str
  type Height_t = int
  type HeaderIndex_t = int

  type Proposal_t = {
    version: int,
    tip: Snapshot_t,
    declaredCandidateHeight: Height_t,
    headerCount: int,
    headers: HeaderIndex_t -> Snapshot_t,
  }

  const Snapshots: Set[Snapshot_t]
  const MaxHeight: Height_t
  const Sigma: int
  const ExpectedVersion: int
  const InitialFinalized: Snapshot_t
  const HeightOf: Snapshot_t -> Height_t
  const AncestorAt: Snapshot_t -> Height_t -> Block_t
  const AncestorSnapshotAt: Snapshot_t -> Height_t -> Snapshot_t
  const HeaderVersionKnown: Snapshot_t -> bool
  const HeaderPowValid: Snapshot_t -> bool

  pure val NilSnapshot = "None"
  pure val Heights = 0.to(MaxHeight)
  pure val HeaderIndices = 0.to(Sigma - 1)

  assume initial_finalized_is_snapshot =
    Snapshots.contains(InitialFinalized)
  assume sigma_is_positive =
    Sigma >= 1
  assume expected_version_is_positive =
    ExpectedVersion >= 1
  assume nil_is_not_snapshot =
    not(Snapshots.contains(NilSnapshot))
  assume snapshot_heights_are_in_range =
    Snapshots.forall(v => Heights.contains(HeightOf.get(v)))

  var firedAction: str

  pure def IsSnapshot(v: Snapshot_t): bool =
    Snapshots.contains(v)

  pure def Height(v: Snapshot_t): Height_t =
    HeightOf.get(v)

  pure def CandidateHeight(tip: Snapshot_t): Height_t =
    if (Height(tip) >= Sigma) {
      Height(tip) - Sigma
    } else {
      0
    }

  pure def BlockAt(v: Snapshot_t, h: Height_t): Block_t =
    AncestorAt.get(v).get(h)

  pure def AncestorSnapshot(tip: Snapshot_t, h: Height_t): Snapshot_t =
    AncestorSnapshotAt.get(tip).get(h)

  def Extends(newer: Snapshot_t, older: Snapshot_t): bool =
    IsSnapshot(newer) and
    IsSnapshot(older) and
    Height(newer) >= Height(older) and
    Heights.forall(h =>
      h > Height(older) or BlockAt(newer, h) == BlockAt(older, h)
    )

  def HeadHasFullSigmaWindow(tip: Snapshot_t): bool =
    IsSnapshot(tip) and
    Height(tip) >= Sigma and
    CandidateHeight(tip) + Sigma <= MaxHeight

  def HeadSigmaCandidate(tip: Snapshot_t): Snapshot_t =
    AncestorSnapshot(tip, CandidateHeight(tip))

  def TailConfirms(tip: Snapshot_t, candidate: Snapshot_t): bool =
    HeadHasFullSigmaWindow(tip) and
    IsSnapshot(candidate) and
    Height(tip) >= Height(candidate) + Sigma and
    BlockAt(tip, Height(candidate)) == BlockAt(candidate, Height(candidate))

  pure def HeaderAt(proposal: Proposal_t, i: HeaderIndex_t): Snapshot_t =
    proposal.headers.get(i)

  pure def FindHeadersAfter(known: Snapshot_t, tip: Snapshot_t): HeaderIndex_t -> Snapshot_t =
    HeaderIndices.mapBy(i => AncestorSnapshot(tip, Height(known) + 1 + i))

  pure def BuildFindHeadersProposal(tip: Snapshot_t): Proposal_t = {
    val candidate = HeadSigmaCandidate(tip)
    {
      version: ExpectedVersion,
      tip: tip,
      declaredCandidateHeight: CandidateHeight(tip),
      headerCount: Sigma,
      headers: FindHeadersAfter(candidate, tip),
    }
  }

  def HeaderCountMatchesSigma(proposal: Proposal_t): bool =
    proposal.headerCount == Sigma

  def HeadersAreKnownSnapshots(proposal: Proposal_t): bool =
    HeaderIndices.forall(i => IsSnapshot(HeaderAt(proposal, i)))

  def HeaderVersionsAreKnown(proposal: Proposal_t): bool =
    HeaderIndices.forall(i => HeaderVersionKnown.get(HeaderAt(proposal, i)))

  def HeaderPowSolutionsAreValid(proposal: Proposal_t): bool =
    HeaderIndices.forall(i => HeaderPowValid.get(HeaderAt(proposal, i)))

  def HeadersMatchFindHeadersAfterDeclaredCandidate(proposal: Proposal_t): bool =
    HeaderIndices.forall(i =>
      HeaderAt(proposal, i) ==
        AncestorSnapshot(proposal.tip, proposal.declaredCandidateHeight + 1 + i)
    )

  def HeadersAreConsecutiveDescendants(proposal: Proposal_t): bool =
    HeaderIndices.forall(i =>
      i == 0 or (
        Height(HeaderAt(proposal, i)) == Height(HeaderAt(proposal, i - 1)) + 1 and
        Extends(HeaderAt(proposal, i), HeaderAt(proposal, i - 1))
      )
    )

  def StatelessBftBlockShapeValid(proposal: Proposal_t): bool =
    proposal.version == ExpectedVersion and
    HeaderCountMatchesSigma(proposal) and
    HeadersAreKnownSnapshots(proposal) and
    HeaderVersionsAreKnown(proposal) and
    HeaderPowSolutionsAreValid(proposal) and
    HeadersAreConsecutiveDescendants(proposal)

  def FirstHeader(proposal: Proposal_t): Snapshot_t =
    HeaderAt(proposal, 0)

  def LastHeader(proposal: Proposal_t): Snapshot_t =
    HeaderAt(proposal, Sigma - 1)

  def AccessorFinalizationCandidate(proposal: Proposal_t): Snapshot_t =
    LastHeader(proposal)

  def VotingPathFinalizationCandidate(proposal: Proposal_t): Snapshot_t =
    FirstHeader(proposal)

  def AccessorCandidateMatchesHeadSigmaCandidate(proposal: Proposal_t): bool =
    HeadersAreKnownSnapshots(proposal) and
    AccessorFinalizationCandidate(proposal) == HeadSigmaCandidate(proposal.tip)

  def VotingPathCandidateMatchesHeadSigmaCandidate(proposal: Proposal_t): bool =
    HeadersAreKnownSnapshots(proposal) and
    VotingPathFinalizationCandidate(proposal) == HeadSigmaCandidate(proposal.tip)

  def FirstHeaderHeightMatchesDeclaredCandidate(proposal: Proposal_t): bool =
    HeadersAreKnownSnapshots(proposal) and
    Height(FirstHeader(proposal)) == proposal.declaredCandidateHeight

  def FirstHeaderMatchesHeadSigmaCandidate(proposal: Proposal_t): bool =
    HeadersAreKnownSnapshots(proposal) and
    FirstHeader(proposal) == HeadSigmaCandidate(proposal.tip)

  def CurrentFirstHeaderVotingCheckPasses(proposal: Proposal_t): bool =
    HeaderCountMatchesSigma(proposal) and
    FirstHeaderHeightMatchesDeclaredCandidate(proposal) and
    FirstHeaderMatchesHeadSigmaCandidate(proposal)

  def DeclaredHeadSigmaCheckPasses(proposal: Proposal_t): bool =
    StatelessBftBlockShapeValid(proposal) and
    HeadHasFullSigmaWindow(proposal.tip) and
    proposal.declaredCandidateHeight == CandidateHeight(proposal.tip) and
    Extends(HeadSigmaCandidate(proposal.tip), InitialFinalized) and
    TailConfirms(proposal.tip, HeadSigmaCandidate(proposal.tip)) and
    HeadersMatchFindHeadersAfterDeclaredCandidate(proposal) and
    LastHeader(proposal) == proposal.tip

  val FindHeadersProposalsPassDeclaredHeadSigmaCheck =
    Snapshots.forall(tip =>
      not(HeadHasFullSigmaWindow(tip)) or
      DeclaredHeadSigmaCheckPasses(BuildFindHeadersProposal(tip))
    )

  val FindHeadersProposalsFailFirstHeaderVotingCheck =
    Snapshots.forall(tip =>
      not(HeadHasFullSigmaWindow(tip)) or
      not(CurrentFirstHeaderVotingCheckPasses(BuildFindHeadersProposal(tip)))
    )

  val FindHeadersProposalsExposeAccessorTipNotCandidate =
    Snapshots.forall(tip =>
      not(HeadHasFullSigmaWindow(tip)) or (
        AccessorFinalizationCandidate(BuildFindHeadersProposal(tip)) == tip and
        not(AccessorCandidateMatchesHeadSigmaCandidate(BuildFindHeadersProposal(tip)))
      )
    )

  val FindHeadersProposalsExposeVotingChildNotCandidate =
    Snapshots.forall(tip =>
      not(HeadHasFullSigmaWindow(tip)) or
      not(VotingPathCandidateMatchesHeadSigmaCandidate(BuildFindHeadersProposal(tip)))
    )

  val Safety =
    FindHeadersProposalsPassDeclaredHeadSigmaCheck and
    FindHeadersProposalsFailFirstHeaderVotingCheck and
    FindHeadersProposalsExposeAccessorTipNotCandidate and
    FindHeadersProposalsExposeVotingChildNotCandidate

  action Init = all {
    firedAction' = "Init",
  }

  action Stutter = all {
    firedAction' = "Stutter",
  }

  action Next =
    Stutter
}

module CrosslinkBftBlockShapeTest {
  import CrosslinkBftBlockShape.* from "./CrosslinkBftBlockShape"
  export CrosslinkBftBlockShape.*

  action unchangedAll = all {
    firedAction' = firedAction,
  }

  run findHeadersAfterCandidateStartsAtChildTest = {
    Init
      .then({
        val proposal = BuildFindHeadersProposal("a4")
        all {
          assert(proposal.declaredCandidateHeight == 1),
          assert(HeadSigmaCandidate(proposal.tip) == "a1"),
          assert(HeaderAt(proposal, 0) == "a2"),
          assert(HeaderAt(proposal, 1) == "a3"),
          assert(HeaderAt(proposal, 2) == "a4"),
          assert(LastHeader(proposal) == proposal.tip),
          unchangedAll,
        }
      })
  }

  run producedProposalPassesDeclaredHeadSigmaCheckTest = {
    Init
      .then({
        val proposal = BuildFindHeadersProposal("a4")
        all {
          assert(DeclaredHeadSigmaCheckPasses(proposal)),
          unchangedAll,
        }
      })
  }

  run producedProposalFailsCurrentFirstHeaderCandidateCheckTest = {
    Init
      .then({
        val proposal = BuildFindHeadersProposal("a4")
        all {
          assert(not(CurrentFirstHeaderVotingCheckPasses(proposal))),
          assert(not(FirstHeaderHeightMatchesDeclaredCandidate(proposal))),
          assert(not(FirstHeaderMatchesHeadSigmaCandidate(proposal))),
          unchangedAll,
        }
      })
  }

  run producedProposalExposesAccessorAndVotingCandidateMismatchTest = {
    Init
      .then({
        val proposal = BuildFindHeadersProposal("a4")
        all {
          assert(AccessorFinalizationCandidate(proposal) == "a4"),
          assert(VotingPathFinalizationCandidate(proposal) == "a2"),
          assert(HeadSigmaCandidate(proposal.tip) == "a1"),
          assert(not(AccessorCandidateMatchesHeadSigmaCandidate(proposal))),
          assert(not(VotingPathCandidateMatchesHeadSigmaCandidate(proposal))),
          unchangedAll,
        }
      })
  }

  run declaringFirstHeaderStillFailsHeadSigmaFreshnessTest = {
    Init
      .then({
        val proposal = {
          version: 1,
          tip: "a4",
          declaredCandidateHeight: 2,
          headerCount: 3,
          headers: FindHeadersAfter("a1", "a4"),
        }
        all {
          assert(FirstHeaderHeightMatchesDeclaredCandidate(proposal)),
          assert(not(FirstHeaderMatchesHeadSigmaCandidate(proposal))),
          assert(not(CurrentFirstHeaderVotingCheckPasses(proposal))),
          assert(not(DeclaredHeadSigmaCheckPasses(proposal))),
          unchangedAll,
        }
      })
  }

  run wrongHeaderCountRejectedTest = {
    Init
      .then({
        val proposal = {
          version: 1,
          tip: "a4",
          declaredCandidateHeight: 1,
          headerCount: 2,
          headers: FindHeadersAfter("a1", "a4"),
        }
        all {
          assert(not(DeclaredHeadSigmaCheckPasses(proposal))),
          unchangedAll,
        }
      })
  }

  run wrongVersionRejectedTest = {
    Init
      .then({
        val proposal = {
          version: 2,
          tip: "a4",
          declaredCandidateHeight: 1,
          headerCount: 3,
          headers: FindHeadersAfter("a1", "a4"),
        }
        all {
          assert(not(StatelessBftBlockShapeValid(proposal))),
          assert(not(DeclaredHeadSigmaCheckPasses(proposal))),
          unchangedAll,
        }
      })
  }

  run invalidPowHeaderRejectedTest = {
    Init
      .then({
        val proposal = {
          version: 1,
          tip: "a4",
          declaredCandidateHeight: 1,
          headerCount: 3,
          headers: Map(0 -> "bad2", 1 -> "a3", 2 -> "a4"),
        }
        all {
          assert(not(HeaderPowSolutionsAreValid(proposal))),
          assert(not(StatelessBftBlockShapeValid(proposal))),
          assert(not(DeclaredHeadSigmaCheckPasses(proposal))),
          unchangedAll,
        }
      })
  }
}

module CrosslinkBftBlockShapeModel {
  import CrosslinkBftBlockShapeTest(
    Snapshots = Set("g", "a1", "a2", "bad2", "a3", "a4", "b1", "b2", "b3", "b4"),
    MaxHeight = 4,
    Sigma = 3,
    ExpectedVersion = 1,
    InitialFinalized = "g",
    HeightOf = Map(
      "g" -> 0,
      "a1" -> 1,
      "a2" -> 2,
      "bad2" -> 2,
      "a3" -> 3,
      "a4" -> 4,
      "b1" -> 1,
      "b2" -> 2,
      "b3" -> 3,
      "b4" -> 4,
    ),
    AncestorAt = Map(
      "g" -> Map(0 -> "g", 1 -> "None", 2 -> "None", 3 -> "None", 4 -> "None"),
      "a1" -> Map(0 -> "g", 1 -> "a1", 2 -> "None", 3 -> "None", 4 -> "None"),
      "a2" -> Map(0 -> "g", 1 -> "a1", 2 -> "a2", 3 -> "None", 4 -> "None"),
      "bad2" -> Map(0 -> "g", 1 -> "a1", 2 -> "bad2", 3 -> "None", 4 -> "None"),
      "a3" -> Map(0 -> "g", 1 -> "a1", 2 -> "a2", 3 -> "a3", 4 -> "None"),
      "a4" -> Map(0 -> "g", 1 -> "a1", 2 -> "a2", 3 -> "a3", 4 -> "a4"),
      "b1" -> Map(0 -> "g", 1 -> "b1", 2 -> "None", 3 -> "None", 4 -> "None"),
      "b2" -> Map(0 -> "g", 1 -> "b1", 2 -> "b2", 3 -> "None", 4 -> "None"),
      "b3" -> Map(0 -> "g", 1 -> "b1", 2 -> "b2", 3 -> "b3", 4 -> "None"),
      "b4" -> Map(0 -> "g", 1 -> "b1", 2 -> "b2", 3 -> "b3", 4 -> "b4"),
    ),
    AncestorSnapshotAt = Map(
      "g" -> Map(0 -> "g", 1 -> "None", 2 -> "None", 3 -> "None", 4 -> "None"),
      "a1" -> Map(0 -> "g", 1 -> "a1", 2 -> "None", 3 -> "None", 4 -> "None"),
      "a2" -> Map(0 -> "g", 1 -> "a1", 2 -> "a2", 3 -> "None", 4 -> "None"),
      "bad2" -> Map(0 -> "g", 1 -> "a1", 2 -> "bad2", 3 -> "None", 4 -> "None"),
      "a3" -> Map(0 -> "g", 1 -> "a1", 2 -> "a2", 3 -> "a3", 4 -> "None"),
      "a4" -> Map(0 -> "g", 1 -> "a1", 2 -> "a2", 3 -> "a3", 4 -> "a4"),
      "b1" -> Map(0 -> "g", 1 -> "b1", 2 -> "None", 3 -> "None", 4 -> "None"),
      "b2" -> Map(0 -> "g", 1 -> "b1", 2 -> "b2", 3 -> "None", 4 -> "None"),
      "b3" -> Map(0 -> "g", 1 -> "b1", 2 -> "b2", 3 -> "b3", 4 -> "None"),
      "b4" -> Map(0 -> "g", 1 -> "b1", 2 -> "b2", 3 -> "b3", 4 -> "b4"),
    ),
    HeaderVersionKnown = Map(
      "g" -> true,
      "a1" -> true,
      "a2" -> true,
      "bad2" -> true,
      "a3" -> true,
      "a4" -> true,
      "b1" -> true,
      "b2" -> true,
      "b3" -> true,
      "b4" -> true,
    ),
    HeaderPowValid = Map(
      "g" -> true,
      "a1" -> true,
      "a2" -> true,
      "bad2" -> false,
      "a3" -> true,
      "a4" -> true,
      "b1" -> true,
      "b2" -> true,
      "b3" -> true,
      "b4" -> true,
    ),
  ).*
}
