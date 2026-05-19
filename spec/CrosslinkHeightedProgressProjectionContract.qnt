module CrosslinkHeightedProgressProjectionContractModel {
  /*
   TLC-friendly heighted progress projection.

   The imported heighted round/finality models carry map-heavy per-validator
   state that is useful for executable correspondence but currently awkward for
   full temporal TLC checks. This projection keeps the heighted obligations
   explicit and finite: height 1 burns an unstable round with a nil-precommit
   certificate, decides after resampling, height 2 remains pristine until height
   1 decides, and the finality applicator advances the finalized prefix in
   height order.
   */

  type Proc_t = str

  pure val P1 = "p1"
  pure val P2 = "p2"
  pure val P3 = "p3"
  pure val P4 = "p4"
  pure val Corr = Set(P1, P2, P3)
  pure val NilCertSigners = Set(P1, P2, P4)
  pure val Validators = Set(P1, P2, P3, P4)
  pure val QuorumPower = 3
  pure val H1 = 1
  pure val H2 = 2

  var activeHeight: int

  var h1Round: int
  var h1NilPrecommits: Set[Proc_t]
  var h1NilCertObserved: bool
  var h1Advanced: Set[Proc_t]
  var h1SameRoundCleared: bool
  var h1ProposalInserted: bool
  var h1ProposalDelivered: bool
  var h1Prevoted: Set[Proc_t]
  var h1PrevotesDelivered: Set[Proc_t]
  var h1Precommitted: Set[Proc_t]
  var h1PrecommitsDelivered: bool
  var h1DecisionMade: bool

  var h2Round: int
  var h2ProposalInserted: bool
  var h2ProposalDelivered: bool
  var h2Prevoted: Set[Proc_t]
  var h2PrevotesDelivered: Set[Proc_t]
  var h2Precommitted: Set[Proc_t]
  var h2PrecommitsDelivered: bool
  var h2DecisionMade: bool

  var nextFinalityHeight: int
  var latestFinalHeight: int
  var finalizedHeights: Set[int]
  var progress: int

  pure def VotingPowerOf(voters: Set[Proc_t]): int =
    size(voters)

  def H1NilCertificate: bool =
    VotingPowerOf(h1NilPrecommits.intersect(NilCertSigners)) >= QuorumPower

  def H2Pristine: bool =
    h2Round == 0 and
    not(h2ProposalInserted) and
    not(h2ProposalDelivered) and
    h2Prevoted == Set() and
    h2PrevotesDelivered == Set() and
    h2Precommitted == Set() and
    not(h2PrecommitsDelivered) and
    not(h2DecisionMade)

  def H2Touched: bool =
    h2ProposalInserted or
    h2ProposalDelivered or
    h2Prevoted != Set() or
    h2PrevotesDelivered != Set() or
    h2Precommitted != Set() or
    h2PrecommitsDelivered or
    h2DecisionMade

  action KeepH1 = all {
    h1Round' = h1Round,
    h1NilPrecommits' = h1NilPrecommits,
    h1NilCertObserved' = h1NilCertObserved,
    h1Advanced' = h1Advanced,
    h1SameRoundCleared' = h1SameRoundCleared,
    h1ProposalInserted' = h1ProposalInserted,
    h1ProposalDelivered' = h1ProposalDelivered,
    h1Prevoted' = h1Prevoted,
    h1PrevotesDelivered' = h1PrevotesDelivered,
    h1Precommitted' = h1Precommitted,
    h1PrecommitsDelivered' = h1PrecommitsDelivered,
    h1DecisionMade' = h1DecisionMade,
  }

  action KeepH2 = all {
    h2Round' = h2Round,
    h2ProposalInserted' = h2ProposalInserted,
    h2ProposalDelivered' = h2ProposalDelivered,
    h2Prevoted' = h2Prevoted,
    h2PrevotesDelivered' = h2PrevotesDelivered,
    h2Precommitted' = h2Precommitted,
    h2PrecommitsDelivered' = h2PrecommitsDelivered,
    h2DecisionMade' = h2DecisionMade,
  }

  action KeepFinality = all {
    nextFinalityHeight' = nextFinalityHeight,
    latestFinalHeight' = latestFinalHeight,
    finalizedHeights' = finalizedHeights,
  }

  action Init = all {
    activeHeight' = H1,
    h1Round' = 0,
    h1NilPrecommits' = Set(),
    h1NilCertObserved' = false,
    h1Advanced' = Set(),
    h1SameRoundCleared' = false,
    h1ProposalInserted' = false,
    h1ProposalDelivered' = false,
    h1Prevoted' = Set(),
    h1PrevotesDelivered' = Set(),
    h1Precommitted' = Set(),
    h1PrecommitsDelivered' = false,
    h1DecisionMade' = false,
    h2Round' = 0,
    h2ProposalInserted' = false,
    h2ProposalDelivered' = false,
    h2Prevoted' = Set(),
    h2PrevotesDelivered' = Set(),
    h2Precommitted' = Set(),
    h2PrecommitsDelivered' = false,
    h2DecisionMade' = false,
    nextFinalityHeight' = H1,
    latestFinalHeight' = 0,
    finalizedHeights' = Set(),
    progress' = 0,
  }

  action Unchanged = all {
    activeHeight' = activeHeight,
    KeepH1,
    KeepH2,
    KeepFinality,
    progress' = progress,
  }

  action SeedHeight1NilPrecommit(p: Proc_t): bool = {
    val nextNilPrecommits = h1NilPrecommits.union(Set(p))
    all {
      activeHeight == H1,
      h1Round == 0,
      not(h1SameRoundCleared),
      NilCertSigners.contains(p),
      not(h1NilPrecommits.contains(p)),
      h1Round' = h1Round,
      h1NilPrecommits' = nextNilPrecommits,
      h1NilCertObserved' =
        (h1NilCertObserved or VotingPowerOf(nextNilPrecommits.intersect(NilCertSigners)) >= QuorumPower),
      h1Advanced' = h1Advanced,
      h1SameRoundCleared' = h1SameRoundCleared,
      h1ProposalInserted' = h1ProposalInserted,
      h1ProposalDelivered' = h1ProposalDelivered,
      h1Prevoted' = h1Prevoted,
      h1PrevotesDelivered' = h1PrevotesDelivered,
      h1Precommitted' = h1Precommitted,
      h1PrecommitsDelivered' = h1PrecommitsDelivered,
      h1DecisionMade' = h1DecisionMade,
      KeepH2,
      KeepFinality,
      activeHeight' = activeHeight,
      progress' = progress + 1,
    }
  }

  action AdvanceHeight1AfterNilCert(p: Proc_t): bool = {
    val advancedNow = h1Advanced.union(Set(p))
    val roundDone = advancedNow == Corr
    all {
      activeHeight == H1,
      h1Round == 0,
      H1NilCertificate,
      Corr.contains(p),
      not(h1Advanced.contains(p)),
      h1Round' = if (roundDone) { 1 } else { h1Round },
      h1NilPrecommits' = if (roundDone) { Set() } else { h1NilPrecommits },
      h1NilCertObserved' = true,
      h1Advanced' = if (roundDone) { Set() } else { advancedNow },
      h1SameRoundCleared' = if (roundDone) { true } else { h1SameRoundCleared },
      h1ProposalInserted' = h1ProposalInserted,
      h1ProposalDelivered' = h1ProposalDelivered,
      h1Prevoted' = h1Prevoted,
      h1PrevotesDelivered' = h1PrevotesDelivered,
      h1Precommitted' = h1Precommitted,
      h1PrecommitsDelivered' = h1PrecommitsDelivered,
      h1DecisionMade' = h1DecisionMade,
      KeepH2,
      KeepFinality,
      activeHeight' = activeHeight,
      progress' = progress + 1,
    }
  }

  action InsertHeight1StableProposal: bool =
    all {
      activeHeight == H1,
      h1Round == 1,
      h1SameRoundCleared,
      not(h1ProposalInserted),
      h1Round' = h1Round,
      h1NilPrecommits' = h1NilPrecommits,
      h1NilCertObserved' = h1NilCertObserved,
      h1Advanced' = h1Advanced,
      h1SameRoundCleared' = h1SameRoundCleared,
      h1ProposalInserted' = true,
      h1ProposalDelivered' = h1ProposalDelivered,
      h1Prevoted' = h1Prevoted,
      h1PrevotesDelivered' = h1PrevotesDelivered,
      h1Precommitted' = h1Precommitted,
      h1PrecommitsDelivered' = h1PrecommitsDelivered,
      h1DecisionMade' = h1DecisionMade,
      KeepH2,
      KeepFinality,
      activeHeight' = activeHeight,
      progress' = progress + 1,
    }

  action DeliverHeight1StableProposal: bool =
    all {
      activeHeight == H1,
      h1ProposalInserted,
      not(h1ProposalDelivered),
      h1Round' = h1Round,
      h1NilPrecommits' = h1NilPrecommits,
      h1NilCertObserved' = h1NilCertObserved,
      h1Advanced' = h1Advanced,
      h1SameRoundCleared' = h1SameRoundCleared,
      h1ProposalInserted' = h1ProposalInserted,
      h1ProposalDelivered' = true,
      h1Prevoted' = h1Prevoted,
      h1PrevotesDelivered' = h1PrevotesDelivered,
      h1Precommitted' = h1Precommitted,
      h1PrecommitsDelivered' = h1PrecommitsDelivered,
      h1DecisionMade' = h1DecisionMade,
      KeepH2,
      KeepFinality,
      activeHeight' = activeHeight,
      progress' = progress + 1,
    }

  action PrevoteHeight1StableValue(p: Proc_t): bool =
    all {
      activeHeight == H1,
      h1ProposalDelivered,
      Corr.contains(p),
      not(h1Prevoted.contains(p)),
      h1Round' = h1Round,
      h1NilPrecommits' = h1NilPrecommits,
      h1NilCertObserved' = h1NilCertObserved,
      h1Advanced' = h1Advanced,
      h1SameRoundCleared' = h1SameRoundCleared,
      h1ProposalInserted' = h1ProposalInserted,
      h1ProposalDelivered' = h1ProposalDelivered,
      h1Prevoted' = h1Prevoted.union(Set(p)),
      h1PrevotesDelivered' = h1PrevotesDelivered,
      h1Precommitted' = h1Precommitted,
      h1PrecommitsDelivered' = h1PrecommitsDelivered,
      h1DecisionMade' = h1DecisionMade,
      KeepH2,
      KeepFinality,
      activeHeight' = activeHeight,
      progress' = progress + 1,
    }

  action DeliverHeight1Prevotes(p: Proc_t): bool =
    all {
      activeHeight == H1,
      Corr.subseteq(h1Prevoted),
      Corr.contains(p),
      not(h1PrevotesDelivered.contains(p)),
      h1Round' = h1Round,
      h1NilPrecommits' = h1NilPrecommits,
      h1NilCertObserved' = h1NilCertObserved,
      h1Advanced' = h1Advanced,
      h1SameRoundCleared' = h1SameRoundCleared,
      h1ProposalInserted' = h1ProposalInserted,
      h1ProposalDelivered' = h1ProposalDelivered,
      h1Prevoted' = h1Prevoted,
      h1PrevotesDelivered' = h1PrevotesDelivered.union(Set(p)),
      h1Precommitted' = h1Precommitted,
      h1PrecommitsDelivered' = h1PrecommitsDelivered,
      h1DecisionMade' = h1DecisionMade,
      KeepH2,
      KeepFinality,
      activeHeight' = activeHeight,
      progress' = progress + 1,
    }

  action PrecommitHeight1StableValue(p: Proc_t): bool =
    all {
      activeHeight == H1,
      h1PrevotesDelivered.contains(p),
      Corr.contains(p),
      not(h1Precommitted.contains(p)),
      h1Round' = h1Round,
      h1NilPrecommits' = h1NilPrecommits,
      h1NilCertObserved' = h1NilCertObserved,
      h1Advanced' = h1Advanced,
      h1SameRoundCleared' = h1SameRoundCleared,
      h1ProposalInserted' = h1ProposalInserted,
      h1ProposalDelivered' = h1ProposalDelivered,
      h1Prevoted' = h1Prevoted,
      h1PrevotesDelivered' = h1PrevotesDelivered,
      h1Precommitted' = h1Precommitted.union(Set(p)),
      h1PrecommitsDelivered' = h1PrecommitsDelivered,
      h1DecisionMade' = h1DecisionMade,
      KeepH2,
      KeepFinality,
      activeHeight' = activeHeight,
      progress' = progress + 1,
    }

  action DeliverHeight1Precommits: bool =
    all {
      activeHeight == H1,
      Corr.subseteq(h1Precommitted),
      not(h1PrecommitsDelivered),
      h1Round' = h1Round,
      h1NilPrecommits' = h1NilPrecommits,
      h1NilCertObserved' = h1NilCertObserved,
      h1Advanced' = h1Advanced,
      h1SameRoundCleared' = h1SameRoundCleared,
      h1ProposalInserted' = h1ProposalInserted,
      h1ProposalDelivered' = h1ProposalDelivered,
      h1Prevoted' = h1Prevoted,
      h1PrevotesDelivered' = h1PrevotesDelivered,
      h1Precommitted' = h1Precommitted,
      h1PrecommitsDelivered' = true,
      h1DecisionMade' = h1DecisionMade,
      KeepH2,
      KeepFinality,
      activeHeight' = activeHeight,
      progress' = progress + 1,
    }

  action DecideHeight1: bool =
    all {
      activeHeight == H1,
      h1PrecommitsDelivered,
      not(h1DecisionMade),
      h1Round' = h1Round,
      h1NilPrecommits' = h1NilPrecommits,
      h1NilCertObserved' = h1NilCertObserved,
      h1Advanced' = h1Advanced,
      h1SameRoundCleared' = h1SameRoundCleared,
      h1ProposalInserted' = h1ProposalInserted,
      h1ProposalDelivered' = h1ProposalDelivered,
      h1Prevoted' = h1Prevoted,
      h1PrevotesDelivered' = h1PrevotesDelivered,
      h1Precommitted' = h1Precommitted,
      h1PrecommitsDelivered' = h1PrecommitsDelivered,
      h1DecisionMade' = true,
      KeepH2,
      KeepFinality,
      activeHeight' = activeHeight,
      progress' = progress + 1,
    }

  action AdvanceToHeight2: bool =
    all {
      activeHeight == H1,
      h1DecisionMade,
      H2Pristine,
      KeepH1,
      KeepH2,
      KeepFinality,
      activeHeight' = H2,
      progress' = progress + 1,
    }

  action InsertHeight2StableProposal: bool =
    all {
      activeHeight == H2,
      h1DecisionMade,
      not(h2ProposalInserted),
      KeepH1,
      h2Round' = h2Round,
      h2ProposalInserted' = true,
      h2ProposalDelivered' = h2ProposalDelivered,
      h2Prevoted' = h2Prevoted,
      h2PrevotesDelivered' = h2PrevotesDelivered,
      h2Precommitted' = h2Precommitted,
      h2PrecommitsDelivered' = h2PrecommitsDelivered,
      h2DecisionMade' = h2DecisionMade,
      KeepFinality,
      activeHeight' = activeHeight,
      progress' = progress + 1,
    }

  action DeliverHeight2StableProposal: bool =
    all {
      activeHeight == H2,
      h2ProposalInserted,
      not(h2ProposalDelivered),
      KeepH1,
      h2Round' = h2Round,
      h2ProposalInserted' = h2ProposalInserted,
      h2ProposalDelivered' = true,
      h2Prevoted' = h2Prevoted,
      h2PrevotesDelivered' = h2PrevotesDelivered,
      h2Precommitted' = h2Precommitted,
      h2PrecommitsDelivered' = h2PrecommitsDelivered,
      h2DecisionMade' = h2DecisionMade,
      KeepFinality,
      activeHeight' = activeHeight,
      progress' = progress + 1,
    }

  action PrevoteHeight2StableValue(p: Proc_t): bool =
    all {
      activeHeight == H2,
      h2ProposalDelivered,
      Corr.contains(p),
      not(h2Prevoted.contains(p)),
      KeepH1,
      h2Round' = h2Round,
      h2ProposalInserted' = h2ProposalInserted,
      h2ProposalDelivered' = h2ProposalDelivered,
      h2Prevoted' = h2Prevoted.union(Set(p)),
      h2PrevotesDelivered' = h2PrevotesDelivered,
      h2Precommitted' = h2Precommitted,
      h2PrecommitsDelivered' = h2PrecommitsDelivered,
      h2DecisionMade' = h2DecisionMade,
      KeepFinality,
      activeHeight' = activeHeight,
      progress' = progress + 1,
    }

  action DeliverHeight2Prevotes(p: Proc_t): bool =
    all {
      activeHeight == H2,
      Corr.subseteq(h2Prevoted),
      Corr.contains(p),
      not(h2PrevotesDelivered.contains(p)),
      KeepH1,
      h2Round' = h2Round,
      h2ProposalInserted' = h2ProposalInserted,
      h2ProposalDelivered' = h2ProposalDelivered,
      h2Prevoted' = h2Prevoted,
      h2PrevotesDelivered' = h2PrevotesDelivered.union(Set(p)),
      h2Precommitted' = h2Precommitted,
      h2PrecommitsDelivered' = h2PrecommitsDelivered,
      h2DecisionMade' = h2DecisionMade,
      KeepFinality,
      activeHeight' = activeHeight,
      progress' = progress + 1,
    }

  action PrecommitHeight2StableValue(p: Proc_t): bool =
    all {
      activeHeight == H2,
      h2PrevotesDelivered.contains(p),
      Corr.contains(p),
      not(h2Precommitted.contains(p)),
      KeepH1,
      h2Round' = h2Round,
      h2ProposalInserted' = h2ProposalInserted,
      h2ProposalDelivered' = h2ProposalDelivered,
      h2Prevoted' = h2Prevoted,
      h2PrevotesDelivered' = h2PrevotesDelivered,
      h2Precommitted' = h2Precommitted.union(Set(p)),
      h2PrecommitsDelivered' = h2PrecommitsDelivered,
      h2DecisionMade' = h2DecisionMade,
      KeepFinality,
      activeHeight' = activeHeight,
      progress' = progress + 1,
    }

  action DeliverHeight2Precommits: bool =
    all {
      activeHeight == H2,
      Corr.subseteq(h2Precommitted),
      not(h2PrecommitsDelivered),
      KeepH1,
      h2Round' = h2Round,
      h2ProposalInserted' = h2ProposalInserted,
      h2ProposalDelivered' = h2ProposalDelivered,
      h2Prevoted' = h2Prevoted,
      h2PrevotesDelivered' = h2PrevotesDelivered,
      h2Precommitted' = h2Precommitted,
      h2PrecommitsDelivered' = true,
      h2DecisionMade' = h2DecisionMade,
      KeepFinality,
      activeHeight' = activeHeight,
      progress' = progress + 1,
    }

  action DecideHeight2: bool =
    all {
      activeHeight == H2,
      h1DecisionMade,
      h2PrecommitsDelivered,
      not(h2DecisionMade),
      KeepH1,
      h2Round' = h2Round,
      h2ProposalInserted' = h2ProposalInserted,
      h2ProposalDelivered' = h2ProposalDelivered,
      h2Prevoted' = h2Prevoted,
      h2PrevotesDelivered' = h2PrevotesDelivered,
      h2Precommitted' = h2Precommitted,
      h2PrecommitsDelivered' = h2PrecommitsDelivered,
      h2DecisionMade' = true,
      KeepFinality,
      activeHeight' = activeHeight,
      progress' = progress + 1,
    }

  action FinalizeHeight1: bool =
    all {
      h1DecisionMade,
      nextFinalityHeight == H1,
      latestFinalHeight == 0,
      not(finalizedHeights.contains(H1)),
      KeepH1,
      KeepH2,
      nextFinalityHeight' = H2,
      latestFinalHeight' = H1,
      finalizedHeights' = finalizedHeights.union(Set(H1)),
      activeHeight' = activeHeight,
      progress' = progress + 1,
    }

  action FinalizeHeight2: bool =
    all {
      h2DecisionMade,
      nextFinalityHeight == H2,
      latestFinalHeight == H1,
      finalizedHeights.contains(H1),
      not(finalizedHeights.contains(H2)),
      KeepH1,
      KeepH2,
      nextFinalityHeight' = 3,
      latestFinalHeight' = H2,
      finalizedHeights' = finalizedHeights.union(Set(H2)),
      activeHeight' = activeHeight,
      progress' = progress + 1,
    }

  action StutterAfterFinality: bool =
    all {
      latestFinalHeight == H2,
      finalizedHeights == Set(H1, H2),
      Unchanged,
    }

  action Next: bool =
    any {
      nondet p = oneOf(NilCertSigners)
      SeedHeight1NilPrecommit(p),
      nondet p = oneOf(Corr)
      AdvanceHeight1AfterNilCert(p),
      InsertHeight1StableProposal,
      DeliverHeight1StableProposal,
      nondet p = oneOf(Corr)
      PrevoteHeight1StableValue(p),
      nondet p = oneOf(Corr)
      DeliverHeight1Prevotes(p),
      nondet p = oneOf(Corr)
      PrecommitHeight1StableValue(p),
      DeliverHeight1Precommits,
      DecideHeight1,
      AdvanceToHeight2,
      InsertHeight2StableProposal,
      DeliverHeight2StableProposal,
      nondet p = oneOf(Corr)
      PrevoteHeight2StableValue(p),
      nondet p = oneOf(Corr)
      DeliverHeight2Prevotes(p),
      nondet p = oneOf(Corr)
      PrecommitHeight2StableValue(p),
      DeliverHeight2Precommits,
      DecideHeight2,
      FinalizeHeight1,
      FinalizeHeight2,
      StutterAfterFinality,
    }

  val StateWellFormed =
    Set(H1, H2).contains(activeHeight) and
    0.to(1).contains(h1Round) and
    h2Round == 0 and
    h1NilPrecommits.subseteq(Validators) and
    h1Advanced.subseteq(Corr) and
    h1Prevoted.subseteq(Corr) and
    h1PrevotesDelivered.subseteq(Corr) and
    h1Precommitted.subseteq(Corr) and
    h2Prevoted.subseteq(Corr) and
    h2PrevotesDelivered.subseteq(Corr) and
    h2Precommitted.subseteq(Corr) and
    1.to(3).contains(nextFinalityHeight) and
    0.to(2).contains(latestFinalHeight) and
    finalizedHeights.subseteq(Set(H1, H2)) and
    0.to(60).contains(progress)

  val HeightCursorSequentialProjection =
    (activeHeight == H2 implies h1DecisionMade) and
    (H2Touched implies activeHeight == H2 and h1DecisionMade) and
    (h2DecisionMade implies h1DecisionMade) and
    (finalizedHeights.contains(H2) implies finalizedHeights.contains(H1))

  val FutureHeightPristineUntilTransition =
    (activeHeight == H1 implies H2Pristine and not(finalizedHeights.contains(H2))) and
    (h1SameRoundCleared and not(h1DecisionMade) implies H2Pristine)

  val NilResamplingClearsOnlyActiveHeight =
    (h1SameRoundCleared implies h1NilCertObserved and h1Round == 1) and
    (h1SameRoundCleared and activeHeight == H1 implies H2Pristine) and
    (h1ProposalInserted implies h1SameRoundCleared)

  val DecisionRequiresLocalPrecommitQuorumProjection =
    (h1DecisionMade implies h1PrecommitsDelivered and Corr.subseteq(h1Precommitted)) and
    (h2DecisionMade implies h2PrecommitsDelivered and Corr.subseteq(h2Precommitted))

  val FinalityInOrder =
    nextFinalityHeight == latestFinalHeight + 1 and
    (latestFinalHeight == 0 implies finalizedHeights == Set()) and
    (finalizedHeights == Set() implies latestFinalHeight == 0) and
    (latestFinalHeight == H1 implies finalizedHeights == Set(H1)) and
    (finalizedHeights == Set(H1) implies latestFinalHeight == H1) and
    (latestFinalHeight == H2 implies finalizedHeights == Set(H1, H2)) and
    (finalizedHeights == Set(H1, H2) implies latestFinalHeight == H2) and
    (finalizedHeights.contains(H1) implies h1DecisionMade) and
    (finalizedHeights.contains(H2) implies h2DecisionMade)

  val PhaseOrder =
    (h1NilCertObserved implies h1SameRoundCleared or H1NilCertificate) and
    (h1ProposalDelivered implies h1ProposalInserted) and
    (h1Prevoted != Set() implies h1ProposalDelivered) and
    (h1PrevotesDelivered != Set() implies Corr.subseteq(h1Prevoted)) and
    h1Precommitted.forall(p => h1PrevotesDelivered.contains(p)) and
    (h1PrecommitsDelivered implies Corr.subseteq(h1Precommitted)) and
    (h1DecisionMade implies h1PrecommitsDelivered) and
    (h2ProposalDelivered implies h2ProposalInserted) and
    (h2Prevoted != Set() implies h2ProposalDelivered) and
    (h2PrevotesDelivered != Set() implies Corr.subseteq(h2Prevoted)) and
    h2Precommitted.forall(p => h2PrevotesDelivered.contains(p)) and
    (h2PrecommitsDelivered implies Corr.subseteq(h2Precommitted)) and
    (h2DecisionMade implies h2PrecommitsDelivered)

  val Safety =
    StateWellFormed and
    HeightCursorSequentialProjection and
    FutureHeightPristineUntilTransition and
    NilResamplingClearsOnlyActiveHeight and
    DecisionRequiresLocalPrecommitQuorumProjection and
    FinalityInOrder and
    PhaseOrder

  temporal EventuallyHeightedProgressFinalizesTwoHeights =
    Next.weakFair(Set(progress)).implies(eventually(
      latestFinalHeight == H2 and finalizedHeights == Set(H1, H2)
    ))

  run nilResamplingClearsOnlyHeight1Test = {
    Init
      .then(SeedHeight1NilPrecommit(P1))
      .then(SeedHeight1NilPrecommit(P2))
      .then(SeedHeight1NilPrecommit(P4))
      .then(AdvanceHeight1AfterNilCert(P1))
      .then(AdvanceHeight1AfterNilCert(P2))
      .then(AdvanceHeight1AfterNilCert(P3))
      .then(all {
        assert(h1SameRoundCleared),
        assert(h1NilCertObserved),
        assert(H2Pristine),
        assert(Safety),
        Unchanged,
      })
  }

  run height2WaitsForHeight1DecisionTest = {
    Init
      .then(SeedHeight1NilPrecommit(P2))
      .then(SeedHeight1NilPrecommit(P1))
      .then(SeedHeight1NilPrecommit(P4))
      .then(AdvanceHeight1AfterNilCert(P3))
      .then(AdvanceHeight1AfterNilCert(P1))
      .then(AdvanceHeight1AfterNilCert(P2))
      .then(InsertHeight1StableProposal)
      .then(DeliverHeight1StableProposal)
      .then(PrevoteHeight1StableValue(P1))
      .then(all {
        assert(not(h1DecisionMade)),
        assert(activeHeight == H1),
        assert(H2Pristine),
        assert(Safety),
        Unchanged,
      })
  }

  run heightedProgressFinalizesTwoHeightsTest = {
    Init
      .then(SeedHeight1NilPrecommit(P1))
      .then(SeedHeight1NilPrecommit(P4))
      .then(SeedHeight1NilPrecommit(P2))
      .then(AdvanceHeight1AfterNilCert(P2))
      .then(AdvanceHeight1AfterNilCert(P3))
      .then(AdvanceHeight1AfterNilCert(P1))
      .then(InsertHeight1StableProposal)
      .then(DeliverHeight1StableProposal)
      .then(PrevoteHeight1StableValue(P1))
      .then(PrevoteHeight1StableValue(P2))
      .then(PrevoteHeight1StableValue(P3))
      .then(DeliverHeight1Prevotes(P3))
      .then(DeliverHeight1Prevotes(P1))
      .then(DeliverHeight1Prevotes(P2))
      .then(PrecommitHeight1StableValue(P2))
      .then(PrecommitHeight1StableValue(P1))
      .then(PrecommitHeight1StableValue(P3))
      .then(DeliverHeight1Precommits)
      .then(DecideHeight1)
      .then(AdvanceToHeight2)
      .then(InsertHeight2StableProposal)
      .then(DeliverHeight2StableProposal)
      .then(PrevoteHeight2StableValue(P3))
      .then(PrevoteHeight2StableValue(P1))
      .then(PrevoteHeight2StableValue(P2))
      .then(DeliverHeight2Prevotes(P2))
      .then(DeliverHeight2Prevotes(P3))
      .then(DeliverHeight2Prevotes(P1))
      .then(PrecommitHeight2StableValue(P1))
      .then(PrecommitHeight2StableValue(P3))
      .then(PrecommitHeight2StableValue(P2))
      .then(DeliverHeight2Precommits)
      .then(DecideHeight2)
      .then(FinalizeHeight1)
      .then(FinalizeHeight2)
      .then(all {
        assert(activeHeight == H2),
        assert(h1DecisionMade),
        assert(h2DecisionMade),
        assert(latestFinalHeight == H2),
        assert(finalizedHeights == Set(H1, H2)),
        assert(Safety),
        Unchanged,
      })
  }
}
