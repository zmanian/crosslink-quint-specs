module CrosslinkHeightedAuthenticatedProgressProjectionContractModel {
  /*
   TLC-friendly authenticated heighted progress projection.

   CrosslinkHeightedProgressProjectionContract.qnt checks the two-height
   nil-precommit recovery path and ordered finality with abstract decisions.
   This projection reuses that finite heighted path but replaces bare finality
   with authenticated finality: a height can be finalized only after observer
   evidence has seen matching value precommits and fat-pointer signatures from
   a quorum of correct validators for that same height and round.
   */

  import CrosslinkHeightedProgressProjectionContractModel.* from "./CrosslinkHeightedProgressProjectionContract"
  export CrosslinkHeightedProgressProjectionContractModel.*

  var h1AuthPrecommitGossiped: Set[Proc_t]
  var h1AuthPrecommitObserved: Set[Proc_t]
  var h1FatPointerSigGossiped: Set[Proc_t]
  var h1FatPointerObserved: bool

  var h2AuthPrecommitGossiped: Set[Proc_t]
  var h2AuthPrecommitObserved: Set[Proc_t]
  var h2FatPointerSigGossiped: Set[Proc_t]
  var h2FatPointerObserved: bool

  var authProgress: int

  pure val AuthQuorumSigners = Corr

  def H1AuthenticatedEvidenceComplete: bool =
    AuthQuorumSigners.subseteq(h1AuthPrecommitObserved) and
    AuthQuorumSigners.subseteq(h1FatPointerSigGossiped)

  def H2AuthenticatedEvidenceComplete: bool =
    AuthQuorumSigners.subseteq(h2AuthPrecommitObserved) and
    AuthQuorumSigners.subseteq(h2FatPointerSigGossiped)

  def H1AuthenticatedFatPointerObserved: bool =
    h1FatPointerObserved and H1AuthenticatedEvidenceComplete

  def H2AuthenticatedFatPointerObserved: bool =
    h2FatPointerObserved and H2AuthenticatedEvidenceComplete

  action AuthInit = all {
    Init,
    h1AuthPrecommitGossiped' = Set(),
    h1AuthPrecommitObserved' = Set(),
    h1FatPointerSigGossiped' = Set(),
    h1FatPointerObserved' = false,
    h2AuthPrecommitGossiped' = Set(),
    h2AuthPrecommitObserved' = Set(),
    h2FatPointerSigGossiped' = Set(),
    h2FatPointerObserved' = false,
    authProgress' = 0,
  }

  action AuthEvidenceUnchanged = all {
    h1AuthPrecommitGossiped' = h1AuthPrecommitGossiped,
    h1AuthPrecommitObserved' = h1AuthPrecommitObserved,
    h1FatPointerSigGossiped' = h1FatPointerSigGossiped,
    h1FatPointerObserved' = h1FatPointerObserved,
    h2AuthPrecommitGossiped' = h2AuthPrecommitGossiped,
    h2AuthPrecommitObserved' = h2AuthPrecommitObserved,
    h2FatPointerSigGossiped' = h2FatPointerSigGossiped,
    h2FatPointerObserved' = h2FatPointerObserved,
    authProgress' = authProgress,
  }

  action AuthProjectionUnchanged = all {
    Unchanged,
    AuthEvidenceUnchanged,
  }

  action SeedHeight1NilPrecommitAuth(p: Proc_t): bool =
    all { SeedHeight1NilPrecommit(p), AuthEvidenceUnchanged }

  action ObserveHeight1ValuePrecommitAuth: bool =
    all { ObserveHeight1ValuePrecommit, AuthEvidenceUnchanged }

  action WaitOnHeight1MixedPrecommitQuorumAuth: bool =
    all { WaitOnHeight1MixedPrecommitQuorum, AuthEvidenceUnchanged }

  action ObserveHeight1NilCertCompleterAuth: bool =
    all { ObserveHeight1NilCertCompleter, AuthEvidenceUnchanged }

  action AdvanceHeight1AfterNilCertAuth(p: Proc_t): bool =
    all { AdvanceHeight1AfterNilCert(p), AuthEvidenceUnchanged }

  action InsertHeight1StableProposalAuth: bool =
    all { InsertHeight1StableProposal, AuthEvidenceUnchanged }

  action DeliverHeight1StableProposalAuth: bool =
    all { DeliverHeight1StableProposal, AuthEvidenceUnchanged }

  action PrevoteHeight1StableValueAuth(p: Proc_t): bool =
    all { PrevoteHeight1StableValue(p), AuthEvidenceUnchanged }

  action DeliverHeight1PrevotesAuth(p: Proc_t): bool =
    all { DeliverHeight1Prevotes(p), AuthEvidenceUnchanged }

  action PrecommitHeight1StableValueAuth(p: Proc_t): bool =
    all { PrecommitHeight1StableValue(p), AuthEvidenceUnchanged }

  action DeliverHeight1PrecommitsAuth: bool =
    all { DeliverHeight1Precommits, AuthEvidenceUnchanged }

  action DecideHeight1Auth: bool =
    all { DecideHeight1, AuthEvidenceUnchanged }

  action AdvanceToHeight2Auth: bool =
    all { AdvanceToHeight2, AuthEvidenceUnchanged }

  action InsertHeight2StableProposalAuth: bool =
    all { InsertHeight2StableProposal, AuthEvidenceUnchanged }

  action DeliverHeight2StableProposalAuth: bool =
    all { DeliverHeight2StableProposal, AuthEvidenceUnchanged }

  action PrevoteHeight2StableValueAuth(p: Proc_t): bool =
    all { PrevoteHeight2StableValue(p), AuthEvidenceUnchanged }

  action DeliverHeight2PrevotesAuth(p: Proc_t): bool =
    all { DeliverHeight2Prevotes(p), AuthEvidenceUnchanged }

  action PrecommitHeight2StableValueAuth(p: Proc_t): bool =
    all { PrecommitHeight2StableValue(p), AuthEvidenceUnchanged }

  action DeliverHeight2PrecommitsAuth: bool =
    all { DeliverHeight2Precommits, AuthEvidenceUnchanged }

  action DecideHeight2Auth: bool =
    all { DecideHeight2, AuthEvidenceUnchanged }

  action GossipHeight1AuthenticatedPrecommit(p: Proc_t): bool =
    all {
      h1DecisionMade,
      h1Round == 1,
      AuthQuorumSigners.contains(p),
      not(h1AuthPrecommitGossiped.contains(p)),
      Unchanged,
      h1AuthPrecommitGossiped' = h1AuthPrecommitGossiped.union(Set(p)),
      h1AuthPrecommitObserved' = h1AuthPrecommitObserved,
      h1FatPointerSigGossiped' = h1FatPointerSigGossiped,
      h1FatPointerObserved' = h1FatPointerObserved,
      h2AuthPrecommitGossiped' = h2AuthPrecommitGossiped,
      h2AuthPrecommitObserved' = h2AuthPrecommitObserved,
      h2FatPointerSigGossiped' = h2FatPointerSigGossiped,
      h2FatPointerObserved' = h2FatPointerObserved,
      authProgress' = authProgress + 1,
    }

  action ObserveHeight1AuthenticatedPrecommit(p: Proc_t): bool =
    all {
      h1AuthPrecommitGossiped.contains(p),
      not(h1AuthPrecommitObserved.contains(p)),
      Unchanged,
      h1AuthPrecommitGossiped' = h1AuthPrecommitGossiped,
      h1AuthPrecommitObserved' = h1AuthPrecommitObserved.union(Set(p)),
      h1FatPointerSigGossiped' = h1FatPointerSigGossiped,
      h1FatPointerObserved' = h1FatPointerObserved,
      h2AuthPrecommitGossiped' = h2AuthPrecommitGossiped,
      h2AuthPrecommitObserved' = h2AuthPrecommitObserved,
      h2FatPointerSigGossiped' = h2FatPointerSigGossiped,
      h2FatPointerObserved' = h2FatPointerObserved,
      authProgress' = authProgress + 1,
    }

  action GossipHeight1FatPointerSig(p: Proc_t): bool =
    all {
      h1DecisionMade,
      h1Round == 1,
      AuthQuorumSigners.contains(p),
      not(h1FatPointerSigGossiped.contains(p)),
      Unchanged,
      h1AuthPrecommitGossiped' = h1AuthPrecommitGossiped,
      h1AuthPrecommitObserved' = h1AuthPrecommitObserved,
      h1FatPointerSigGossiped' = h1FatPointerSigGossiped.union(Set(p)),
      h1FatPointerObserved' = h1FatPointerObserved,
      h2AuthPrecommitGossiped' = h2AuthPrecommitGossiped,
      h2AuthPrecommitObserved' = h2AuthPrecommitObserved,
      h2FatPointerSigGossiped' = h2FatPointerSigGossiped,
      h2FatPointerObserved' = h2FatPointerObserved,
      authProgress' = authProgress + 1,
    }

  action ObserveHeight1FatPointer: bool =
    all {
      H1AuthenticatedEvidenceComplete,
      not(h1FatPointerObserved),
      Unchanged,
      h1AuthPrecommitGossiped' = h1AuthPrecommitGossiped,
      h1AuthPrecommitObserved' = h1AuthPrecommitObserved,
      h1FatPointerSigGossiped' = h1FatPointerSigGossiped,
      h1FatPointerObserved' = true,
      h2AuthPrecommitGossiped' = h2AuthPrecommitGossiped,
      h2AuthPrecommitObserved' = h2AuthPrecommitObserved,
      h2FatPointerSigGossiped' = h2FatPointerSigGossiped,
      h2FatPointerObserved' = h2FatPointerObserved,
      authProgress' = authProgress + 1,
    }

  action GossipHeight2AuthenticatedPrecommit(p: Proc_t): bool =
    all {
      activeHeight == H2,
      h2DecisionMade,
      h2Round == 0,
      AuthQuorumSigners.contains(p),
      not(h2AuthPrecommitGossiped.contains(p)),
      Unchanged,
      h1AuthPrecommitGossiped' = h1AuthPrecommitGossiped,
      h1AuthPrecommitObserved' = h1AuthPrecommitObserved,
      h1FatPointerSigGossiped' = h1FatPointerSigGossiped,
      h1FatPointerObserved' = h1FatPointerObserved,
      h2AuthPrecommitGossiped' = h2AuthPrecommitGossiped.union(Set(p)),
      h2AuthPrecommitObserved' = h2AuthPrecommitObserved,
      h2FatPointerSigGossiped' = h2FatPointerSigGossiped,
      h2FatPointerObserved' = h2FatPointerObserved,
      authProgress' = authProgress + 1,
    }

  action ObserveHeight2AuthenticatedPrecommit(p: Proc_t): bool =
    all {
      h2AuthPrecommitGossiped.contains(p),
      not(h2AuthPrecommitObserved.contains(p)),
      Unchanged,
      h1AuthPrecommitGossiped' = h1AuthPrecommitGossiped,
      h1AuthPrecommitObserved' = h1AuthPrecommitObserved,
      h1FatPointerSigGossiped' = h1FatPointerSigGossiped,
      h1FatPointerObserved' = h1FatPointerObserved,
      h2AuthPrecommitGossiped' = h2AuthPrecommitGossiped,
      h2AuthPrecommitObserved' = h2AuthPrecommitObserved.union(Set(p)),
      h2FatPointerSigGossiped' = h2FatPointerSigGossiped,
      h2FatPointerObserved' = h2FatPointerObserved,
      authProgress' = authProgress + 1,
    }

  action GossipHeight2FatPointerSig(p: Proc_t): bool =
    all {
      activeHeight == H2,
      h2DecisionMade,
      h2Round == 0,
      AuthQuorumSigners.contains(p),
      not(h2FatPointerSigGossiped.contains(p)),
      Unchanged,
      h1AuthPrecommitGossiped' = h1AuthPrecommitGossiped,
      h1AuthPrecommitObserved' = h1AuthPrecommitObserved,
      h1FatPointerSigGossiped' = h1FatPointerSigGossiped,
      h1FatPointerObserved' = h1FatPointerObserved,
      h2AuthPrecommitGossiped' = h2AuthPrecommitGossiped,
      h2AuthPrecommitObserved' = h2AuthPrecommitObserved,
      h2FatPointerSigGossiped' = h2FatPointerSigGossiped.union(Set(p)),
      h2FatPointerObserved' = h2FatPointerObserved,
      authProgress' = authProgress + 1,
    }

  action ObserveHeight2FatPointer: bool =
    all {
      activeHeight == H2,
      H2AuthenticatedEvidenceComplete,
      not(h2FatPointerObserved),
      Unchanged,
      h1AuthPrecommitGossiped' = h1AuthPrecommitGossiped,
      h1AuthPrecommitObserved' = h1AuthPrecommitObserved,
      h1FatPointerSigGossiped' = h1FatPointerSigGossiped,
      h1FatPointerObserved' = h1FatPointerObserved,
      h2AuthPrecommitGossiped' = h2AuthPrecommitGossiped,
      h2AuthPrecommitObserved' = h2AuthPrecommitObserved,
      h2FatPointerSigGossiped' = h2FatPointerSigGossiped,
      h2FatPointerObserved' = true,
      authProgress' = authProgress + 1,
    }

  action FinalizeHeight1Authenticated: bool =
    all {
      H1AuthenticatedFatPointerObserved,
      FinalizeHeight1,
      AuthEvidenceUnchanged,
    }

  action FinalizeHeight2Authenticated: bool =
    all {
      H2AuthenticatedFatPointerObserved,
      FinalizeHeight2,
      AuthEvidenceUnchanged,
    }

  action StutterAfterAuthenticatedFinality: bool =
    all {
      H1AuthenticatedFatPointerObserved,
      H2AuthenticatedFatPointerObserved,
      StutterAfterFinality,
      AuthEvidenceUnchanged,
    }

  action AuthenticatedNext: bool =
    any {
      nondet p = oneOf(InitialNilSigners)
      SeedHeight1NilPrecommitAuth(p),
      ObserveHeight1ValuePrecommitAuth,
      WaitOnHeight1MixedPrecommitQuorumAuth,
      ObserveHeight1NilCertCompleterAuth,
      nondet p = oneOf(Corr)
      AdvanceHeight1AfterNilCertAuth(p),
      InsertHeight1StableProposalAuth,
      DeliverHeight1StableProposalAuth,
      nondet p = oneOf(Corr)
      PrevoteHeight1StableValueAuth(p),
      nondet p = oneOf(Corr)
      DeliverHeight1PrevotesAuth(p),
      nondet p = oneOf(Corr)
      PrecommitHeight1StableValueAuth(p),
      DeliverHeight1PrecommitsAuth,
      DecideHeight1Auth,
      AdvanceToHeight2Auth,
      InsertHeight2StableProposalAuth,
      DeliverHeight2StableProposalAuth,
      nondet p = oneOf(Corr)
      PrevoteHeight2StableValueAuth(p),
      nondet p = oneOf(Corr)
      DeliverHeight2PrevotesAuth(p),
      nondet p = oneOf(Corr)
      PrecommitHeight2StableValueAuth(p),
      DeliverHeight2PrecommitsAuth,
      DecideHeight2Auth,
      nondet p = oneOf(Corr)
      GossipHeight1AuthenticatedPrecommit(p),
      nondet p = oneOf(Corr)
      ObserveHeight1AuthenticatedPrecommit(p),
      nondet p = oneOf(Corr)
      GossipHeight1FatPointerSig(p),
      ObserveHeight1FatPointer,
      nondet p = oneOf(Corr)
      GossipHeight2AuthenticatedPrecommit(p),
      nondet p = oneOf(Corr)
      ObserveHeight2AuthenticatedPrecommit(p),
      nondet p = oneOf(Corr)
      GossipHeight2FatPointerSig(p),
      ObserveHeight2FatPointer,
      FinalizeHeight1Authenticated,
      FinalizeHeight2Authenticated,
      StutterAfterAuthenticatedFinality,
    }

  val AuthStateWellFormed =
    h1AuthPrecommitGossiped.subseteq(Corr) and
    h1AuthPrecommitObserved.subseteq(Corr) and
    h1AuthPrecommitObserved.subseteq(h1AuthPrecommitGossiped) and
    h1FatPointerSigGossiped.subseteq(Corr) and
    h2AuthPrecommitGossiped.subseteq(Corr) and
    h2AuthPrecommitObserved.subseteq(Corr) and
    h2AuthPrecommitObserved.subseteq(h2AuthPrecommitGossiped) and
    h2FatPointerSigGossiped.subseteq(Corr) and
    0.to(40).contains(authProgress)

  val AuthEvidenceHeightDiscipline =
    (
      h1AuthPrecommitGossiped != Set() or
      h1AuthPrecommitObserved != Set() or
      h1FatPointerSigGossiped != Set() or
      h1FatPointerObserved
    ).implies(h1DecisionMade and h1Round == 1) and
    (
      h2AuthPrecommitGossiped != Set() or
      h2AuthPrecommitObserved != Set() or
      h2FatPointerSigGossiped != Set() or
      h2FatPointerObserved
    ).implies(activeHeight == H2 and h2DecisionMade and h1DecisionMade)

  val FatPointersRequireAuthenticatedEvidence =
    (h1FatPointerObserved implies H1AuthenticatedEvidenceComplete) and
    (h2FatPointerObserved implies H2AuthenticatedEvidenceComplete)

  val FinalityRequiresAuthenticatedFatPointer =
    (finalizedHeights.contains(H1) implies H1AuthenticatedFatPointerObserved) and
    (finalizedHeights.contains(H2) implies H2AuthenticatedFatPointerObserved)

  val MixedWaitDoesNotCreateAuthenticatedEvidence =
    (h1WaitedOnMixed and not(h1DecisionMade)).implies(
      h1AuthPrecommitGossiped == Set() and
      h1AuthPrecommitObserved == Set() and
      h1FatPointerSigGossiped == Set() and
      not(h1FatPointerObserved) and
      h2AuthPrecommitGossiped == Set() and
      h2AuthPrecommitObserved == Set() and
      h2FatPointerSigGossiped == Set() and
      not(h2FatPointerObserved)
    )

  val Height2AuthWaitsForHeight2Decision =
    (activeHeight == H1).implies(
      h2AuthPrecommitGossiped == Set() and
      h2AuthPrecommitObserved == Set() and
      h2FatPointerSigGossiped == Set() and
      not(h2FatPointerObserved)
    ) and
    (not(h2DecisionMade)).implies(
      h2AuthPrecommitGossiped == Set() and
      h2AuthPrecommitObserved == Set() and
      h2FatPointerSigGossiped == Set() and
      not(h2FatPointerObserved)
    )

  val AuthenticatedSafety =
    Safety and
    AuthStateWellFormed and
    AuthEvidenceHeightDiscipline and
    FatPointersRequireAuthenticatedEvidence and
    FinalityRequiresAuthenticatedFatPointer and
    MixedWaitDoesNotCreateAuthenticatedEvidence and
    Height2AuthWaitsForHeight2Decision

  temporal EventuallyHeightedAuthenticatedProgressFinalizesTwoHeights =
    AuthenticatedNext.weakFair(Set(progress, authProgress)).implies(eventually(
      h1WaitedOnMixed and
      H1AuthenticatedFatPointerObserved and
      H2AuthenticatedFatPointerObserved and
      latestFinalHeight == H2 and
      finalizedHeights == Set(H1, H2)
    ))

  action RecoverAndDecideHeight1 = all {
    SeedHeight1NilPrecommitAuth(P1)
      .then(SeedHeight1NilPrecommitAuth(P2))
      .then(ObserveHeight1ValuePrecommitAuth)
      .then(WaitOnHeight1MixedPrecommitQuorumAuth)
      .then(ObserveHeight1NilCertCompleterAuth)
      .then(AdvanceHeight1AfterNilCertAuth(P2))
      .then(AdvanceHeight1AfterNilCertAuth(P3))
      .then(AdvanceHeight1AfterNilCertAuth(P1))
      .then(InsertHeight1StableProposalAuth)
      .then(DeliverHeight1StableProposalAuth)
      .then(PrevoteHeight1StableValueAuth(P1))
      .then(PrevoteHeight1StableValueAuth(P2))
      .then(PrevoteHeight1StableValueAuth(P3))
      .then(DeliverHeight1PrevotesAuth(P3))
      .then(DeliverHeight1PrevotesAuth(P1))
      .then(DeliverHeight1PrevotesAuth(P2))
      .then(PrecommitHeight1StableValueAuth(P2))
      .then(PrecommitHeight1StableValueAuth(P1))
      .then(PrecommitHeight1StableValueAuth(P3))
      .then(DeliverHeight1PrecommitsAuth)
      .then(DecideHeight1Auth)
  }

  action DecideHeight2FromStableRound = all {
    AdvanceToHeight2Auth
      .then(InsertHeight2StableProposalAuth)
      .then(DeliverHeight2StableProposalAuth)
      .then(PrevoteHeight2StableValueAuth(P3))
      .then(PrevoteHeight2StableValueAuth(P1))
      .then(PrevoteHeight2StableValueAuth(P2))
      .then(DeliverHeight2PrevotesAuth(P2))
      .then(DeliverHeight2PrevotesAuth(P1))
      .then(DeliverHeight2PrevotesAuth(P3))
      .then(PrecommitHeight2StableValueAuth(P1))
      .then(PrecommitHeight2StableValueAuth(P3))
      .then(PrecommitHeight2StableValueAuth(P2))
      .then(DeliverHeight2PrecommitsAuth)
      .then(DecideHeight2Auth)
  }

  action AuthenticateHeight1FatPointer = all {
    GossipHeight1AuthenticatedPrecommit(P1)
      .then(GossipHeight1AuthenticatedPrecommit(P2))
      .then(GossipHeight1AuthenticatedPrecommit(P3))
      .then(ObserveHeight1AuthenticatedPrecommit(P2))
      .then(ObserveHeight1AuthenticatedPrecommit(P1))
      .then(ObserveHeight1AuthenticatedPrecommit(P3))
      .then(GossipHeight1FatPointerSig(P3))
      .then(GossipHeight1FatPointerSig(P1))
      .then(GossipHeight1FatPointerSig(P2))
      .then(ObserveHeight1FatPointer)
  }

  action AuthenticateHeight2FatPointer = all {
    GossipHeight2AuthenticatedPrecommit(P1)
      .then(GossipHeight2AuthenticatedPrecommit(P2))
      .then(GossipHeight2AuthenticatedPrecommit(P3))
      .then(ObserveHeight2AuthenticatedPrecommit(P1))
      .then(ObserveHeight2AuthenticatedPrecommit(P3))
      .then(ObserveHeight2AuthenticatedPrecommit(P2))
      .then(GossipHeight2FatPointerSig(P2))
      .then(GossipHeight2FatPointerSig(P1))
      .then(GossipHeight2FatPointerSig(P3))
      .then(ObserveHeight2FatPointer)
  }

  run mixedWaitHasNoAuthenticatedEvidenceTest = {
    AuthInit
      .then(SeedHeight1NilPrecommitAuth(P1))
      .then(SeedHeight1NilPrecommitAuth(P2))
      .then(ObserveHeight1ValuePrecommitAuth)
      .then(WaitOnHeight1MixedPrecommitQuorumAuth)
      .then(all {
        assert(h1WaitedOnMixed),
        assert(not(h1NilCertObserved)),
        assert(MixedWaitDoesNotCreateAuthenticatedEvidence),
        assert(AuthenticatedSafety),
        AuthProjectionUnchanged,
      })
  }

  run finalityRequiresAuthenticatedFatPointerTest = {
    AuthInit
      .then(RecoverAndDecideHeight1)
      .then(FinalizeHeight1Authenticated)
      .fail()
  }

  run missingObservedPrecommitRejectsFatPointerTest = {
    AuthInit
      .then(RecoverAndDecideHeight1)
      .then(GossipHeight1AuthenticatedPrecommit(P1))
      .then(GossipHeight1AuthenticatedPrecommit(P2))
      .then(GossipHeight1AuthenticatedPrecommit(P3))
      .then(GossipHeight1FatPointerSig(P1))
      .then(GossipHeight1FatPointerSig(P2))
      .then(GossipHeight1FatPointerSig(P3))
      .then(ObserveHeight1FatPointer)
      .fail()
  }

  run height2AuthenticatedEvidenceWaitsForHeight2DecisionTest = {
    AuthInit
      .then(RecoverAndDecideHeight1)
      .then(GossipHeight2AuthenticatedPrecommit(P1))
      .fail()
  }

  run heightedAuthenticatedProgressFinalizesTwoHeightsTest = {
    AuthInit
      .then(RecoverAndDecideHeight1)
      .then(AuthenticateHeight1FatPointer)
      .then(FinalizeHeight1Authenticated)
      .then(DecideHeight2FromStableRound)
      .then(AuthenticateHeight2FatPointer)
      .then(FinalizeHeight2Authenticated)
      .then(all {
        assert(h1WaitedOnMixed),
        assert(H1AuthenticatedFatPointerObserved),
        assert(H2AuthenticatedFatPointerObserved),
        assert(latestFinalHeight == H2),
        assert(finalizedHeights == Set(H1, H2)),
        assert(AuthenticatedSafety),
        AuthProjectionUnchanged,
      })
  }
}
