module CrosslinkRotatingAuthenticatedProgressProjectionContractModel {
  /*
   TLC-friendly rotating-validator authenticated progress projection.

   This is the next finite projection after
   CrosslinkHeightedAuthenticatedProgressProjectionContract.qnt. It keeps the
   same mixed-precommit/nil-certificate recovery shape, but makes the height-1
   decision rotate the validator set from {p1, p2, p3} to {p2, p3, p4}. Height
   2 can then decide and finalize only with authenticated evidence from the
   rotated validator set; removed height-1 validators cannot contribute to
   height-2 observer evidence.
   */

  type Proc_t = str

  pure val P1 = "p1"
  pure val P2 = "p2"
  pure val P3 = "p3"
  pure val P4 = "p4"
  pure val Validators = Set(P1, P2, P3, P4)
  pure val H1ValidatorSet = Set(P1, P2, P3)
  pure val H2ValidatorSet = Set(P2, P3, P4)
  pure val H1DecisionSigners = Set(P1, P2)
  pure val H2DecisionSigners = Set(P2, P4)
  pure val H1InitialNilSigners = Set(P1)
  pure val H1ValuePrecommitSigner = P2
  pure val H1NilCertCompleter = P3
  pure val QuorumPower = 2
  pure val H1 = 1
  pure val H2 = 2

  var activeHeight: int
  var currentValidatorSet: Set[Proc_t]

  var h1Round: int
  var h1NilPrecommits: Set[Proc_t]
  var h1ValuePrecommits: Set[Proc_t]
  var h1NilCertObserved: bool
  var h1WaitedOnMixed: bool
  var h1Advanced: Set[Proc_t]
  var h1SameRoundCleared: bool
  var h1CurrentRoundLock: Set[Proc_t]
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

  var h1AuthPrecommitGossiped: Set[Proc_t]
  var h1AuthPrecommitObserved: Set[Proc_t]
  var h1FatPointerSigGossiped: Set[Proc_t]
  var h1FatPointerObserved: bool

  var h2AuthPrecommitGossiped: Set[Proc_t]
  var h2AuthPrecommitObserved: Set[Proc_t]
  var h2FatPointerSigGossiped: Set[Proc_t]
  var h2FatPointerObserved: bool

  var nextFinalityHeight: int
  var latestFinalHeight: int
  var finalizedHeights: Set[int]
  var progress: int
  var authProgress: int

  pure def VotingPowerOf(voters: Set[Proc_t]): int =
    size(voters)

  pure def SignerSetHasQuorum(
    signers: Set[Proc_t],
    validatorSet: Set[Proc_t],
  ): bool =
    signers.subseteq(validatorSet) and VotingPowerOf(signers) >= QuorumPower

  pure def AuthorizedAtHeight(p: Proc_t, h: int): bool =
    if (h == H1) {
      H1ValidatorSet.contains(p)
    } else {
      h == H2 and H2ValidatorSet.contains(p)
    }

  def H1NilCertificate: bool =
    VotingPowerOf(h1NilPrecommits) >= QuorumPower

  def H1AnyPrecommitQuorum: bool =
    VotingPowerOf(h1NilPrecommits.union(h1ValuePrecommits)) >= QuorumPower

  def H1ValuePrecommitCertificate: bool =
    VotingPowerOf(h1ValuePrecommits) >= QuorumPower

  def H1MixedPrecommitQuorumWithoutNilCert: bool =
    H1AnyPrecommitQuorum and
    not(H1NilCertificate) and
    not(H1ValuePrecommitCertificate) and
    h1NilPrecommits != Set() and
    h1ValuePrecommits != Set()

  def H2ConsensusPristine: bool =
    h2Round == 0 and
    not(h2ProposalInserted) and
    not(h2ProposalDelivered) and
    h2Prevoted == Set() and
    h2PrevotesDelivered == Set() and
    h2Precommitted == Set() and
    not(h2PrecommitsDelivered) and
    not(h2DecisionMade)

  def H2AuthPristine: bool =
    h2AuthPrecommitGossiped == Set() and
    h2AuthPrecommitObserved == Set() and
    h2FatPointerSigGossiped == Set() and
    not(h2FatPointerObserved)

  def H2Pristine: bool =
    H2ConsensusPristine and H2AuthPristine

  def H2Touched: bool =
    not(H2ConsensusPristine)

  def H1AuthenticatedEvidenceComplete: bool =
    H1DecisionSigners.subseteq(h1AuthPrecommitObserved) and
    H1DecisionSigners.subseteq(h1FatPointerSigGossiped)

  def H2AuthenticatedEvidenceComplete: bool =
    H2DecisionSigners.subseteq(h2AuthPrecommitObserved) and
    H2DecisionSigners.subseteq(h2FatPointerSigGossiped)

  def H1AuthenticatedFatPointerObserved: bool =
    h1FatPointerObserved and H1AuthenticatedEvidenceComplete

  def H2AuthenticatedFatPointerObserved: bool =
    h2FatPointerObserved and H2AuthenticatedEvidenceComplete

  action KeepH1 = all {
    h1Round' = h1Round,
    h1NilPrecommits' = h1NilPrecommits,
    h1ValuePrecommits' = h1ValuePrecommits,
    h1NilCertObserved' = h1NilCertObserved,
    h1WaitedOnMixed' = h1WaitedOnMixed,
    h1Advanced' = h1Advanced,
    h1SameRoundCleared' = h1SameRoundCleared,
    h1CurrentRoundLock' = h1CurrentRoundLock,
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

  action KeepAuth = all {
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

  action KeepFinality = all {
    nextFinalityHeight' = nextFinalityHeight,
    latestFinalHeight' = latestFinalHeight,
    finalizedHeights' = finalizedHeights,
  }

  action Init = all {
    activeHeight' = H1,
    currentValidatorSet' = H1ValidatorSet,
    h1Round' = 0,
    h1NilPrecommits' = Set(),
    h1ValuePrecommits' = Set(),
    h1NilCertObserved' = false,
    h1WaitedOnMixed' = false,
    h1Advanced' = Set(),
    h1SameRoundCleared' = false,
    h1CurrentRoundLock' = H1ValidatorSet,
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
    h1AuthPrecommitGossiped' = Set(),
    h1AuthPrecommitObserved' = Set(),
    h1FatPointerSigGossiped' = Set(),
    h1FatPointerObserved' = false,
    h2AuthPrecommitGossiped' = Set(),
    h2AuthPrecommitObserved' = Set(),
    h2FatPointerSigGossiped' = Set(),
    h2FatPointerObserved' = false,
    nextFinalityHeight' = H1,
    latestFinalHeight' = 0,
    finalizedHeights' = Set(),
    progress' = 0,
    authProgress' = 0,
  }

  action Unchanged = all {
    activeHeight' = activeHeight,
    currentValidatorSet' = currentValidatorSet,
    KeepH1,
    KeepH2,
    KeepAuth,
    KeepFinality,
    progress' = progress,
  }

  action SeedHeight1NilPrecommit: bool =
    all {
      activeHeight == H1,
      h1Round == 0,
      not(h1SameRoundCleared),
      h1NilPrecommits == Set(),
      h1Round' = h1Round,
      h1NilPrecommits' = h1NilPrecommits.union(H1InitialNilSigners),
      h1ValuePrecommits' = h1ValuePrecommits,
      h1NilCertObserved' = false,
      h1WaitedOnMixed' = h1WaitedOnMixed,
      h1Advanced' = h1Advanced,
      h1SameRoundCleared' = h1SameRoundCleared,
      h1CurrentRoundLock' = h1CurrentRoundLock,
      h1ProposalInserted' = h1ProposalInserted,
      h1ProposalDelivered' = h1ProposalDelivered,
      h1Prevoted' = h1Prevoted,
      h1PrevotesDelivered' = h1PrevotesDelivered,
      h1Precommitted' = h1Precommitted,
      h1PrecommitsDelivered' = h1PrecommitsDelivered,
      h1DecisionMade' = h1DecisionMade,
      KeepH2,
      KeepAuth,
      KeepFinality,
      activeHeight' = activeHeight,
      currentValidatorSet' = currentValidatorSet,
      progress' = progress + 1,
    }

  action ObserveHeight1ValuePrecommit: bool =
    all {
      activeHeight == H1,
      h1Round == 0,
      not(h1SameRoundCleared),
      not(h1ValuePrecommits.contains(H1ValuePrecommitSigner)),
      h1Round' = h1Round,
      h1NilPrecommits' = h1NilPrecommits,
      h1ValuePrecommits' = h1ValuePrecommits.union(Set(H1ValuePrecommitSigner)),
      h1NilCertObserved' = h1NilCertObserved,
      h1WaitedOnMixed' = h1WaitedOnMixed,
      h1Advanced' = h1Advanced,
      h1SameRoundCleared' = h1SameRoundCleared,
      h1CurrentRoundLock' = h1CurrentRoundLock,
      h1ProposalInserted' = h1ProposalInserted,
      h1ProposalDelivered' = h1ProposalDelivered,
      h1Prevoted' = h1Prevoted,
      h1PrevotesDelivered' = h1PrevotesDelivered,
      h1Precommitted' = h1Precommitted,
      h1PrecommitsDelivered' = h1PrecommitsDelivered,
      h1DecisionMade' = h1DecisionMade,
      KeepH2,
      KeepAuth,
      KeepFinality,
      activeHeight' = activeHeight,
      currentValidatorSet' = currentValidatorSet,
      progress' = progress + 1,
    }

  action WaitOnHeight1MixedPrecommitQuorum: bool =
    all {
      activeHeight == H1,
      h1Round == 0,
      H1MixedPrecommitQuorumWithoutNilCert,
      not(h1WaitedOnMixed),
      h1Round' = h1Round,
      h1NilPrecommits' = h1NilPrecommits,
      h1ValuePrecommits' = h1ValuePrecommits,
      h1NilCertObserved' = h1NilCertObserved,
      h1WaitedOnMixed' = true,
      h1Advanced' = h1Advanced,
      h1SameRoundCleared' = false,
      h1CurrentRoundLock' = h1CurrentRoundLock,
      h1ProposalInserted' = h1ProposalInserted,
      h1ProposalDelivered' = h1ProposalDelivered,
      h1Prevoted' = h1Prevoted,
      h1PrevotesDelivered' = h1PrevotesDelivered,
      h1Precommitted' = h1Precommitted,
      h1PrecommitsDelivered' = h1PrecommitsDelivered,
      h1DecisionMade' = h1DecisionMade,
      KeepH2,
      KeepAuth,
      KeepFinality,
      activeHeight' = activeHeight,
      currentValidatorSet' = currentValidatorSet,
      progress' = progress + 1,
    }

  action ObserveHeight1NilCertCompleter: bool = {
    val nextNilPrecommits = h1NilPrecommits.union(Set(H1NilCertCompleter))
    all {
      activeHeight == H1,
      h1Round == 0,
      h1WaitedOnMixed,
      not(h1NilPrecommits.contains(H1NilCertCompleter)),
      h1Round' = h1Round,
      h1NilPrecommits' = nextNilPrecommits,
      h1ValuePrecommits' = h1ValuePrecommits,
      h1NilCertObserved' = VotingPowerOf(nextNilPrecommits) >= QuorumPower,
      h1WaitedOnMixed' = h1WaitedOnMixed,
      h1Advanced' = h1Advanced,
      h1SameRoundCleared' = h1SameRoundCleared,
      h1CurrentRoundLock' = h1CurrentRoundLock,
      h1ProposalInserted' = h1ProposalInserted,
      h1ProposalDelivered' = h1ProposalDelivered,
      h1Prevoted' = h1Prevoted,
      h1PrevotesDelivered' = h1PrevotesDelivered,
      h1Precommitted' = h1Precommitted,
      h1PrecommitsDelivered' = h1PrecommitsDelivered,
      h1DecisionMade' = h1DecisionMade,
      KeepH2,
      KeepAuth,
      KeepFinality,
      activeHeight' = activeHeight,
      currentValidatorSet' = currentValidatorSet,
      progress' = progress + 1,
    }
  }

  action AdvanceHeight1AfterNilCert(p: Proc_t): bool = {
    val advancedNow = h1Advanced.union(Set(p))
    val roundDone = advancedNow == H1ValidatorSet
    all {
      activeHeight == H1,
      h1Round == 0,
      h1WaitedOnMixed,
      H1NilCertificate,
      H1ValidatorSet.contains(p),
      not(h1Advanced.contains(p)),
      h1Round' = if (roundDone) { 1 } else { h1Round },
      h1NilPrecommits' = if (roundDone) { Set() } else { h1NilPrecommits },
      h1ValuePrecommits' = h1ValuePrecommits,
      h1NilCertObserved' = true,
      h1WaitedOnMixed' = h1WaitedOnMixed,
      h1Advanced' = if (roundDone) { Set() } else { advancedNow },
      h1SameRoundCleared' = if (roundDone) { true } else { h1SameRoundCleared },
      h1CurrentRoundLock' = if (roundDone) { Set() } else { h1CurrentRoundLock },
      h1ProposalInserted' = h1ProposalInserted,
      h1ProposalDelivered' = h1ProposalDelivered,
      h1Prevoted' = h1Prevoted,
      h1PrevotesDelivered' = h1PrevotesDelivered,
      h1Precommitted' = h1Precommitted,
      h1PrecommitsDelivered' = h1PrecommitsDelivered,
      h1DecisionMade' = h1DecisionMade,
      KeepH2,
      KeepAuth,
      KeepFinality,
      activeHeight' = activeHeight,
      currentValidatorSet' = currentValidatorSet,
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
      h1ValuePrecommits' = h1ValuePrecommits,
      h1NilCertObserved' = h1NilCertObserved,
      h1WaitedOnMixed' = h1WaitedOnMixed,
      h1Advanced' = h1Advanced,
      h1SameRoundCleared' = h1SameRoundCleared,
      h1CurrentRoundLock' = h1CurrentRoundLock,
      h1ProposalInserted' = true,
      h1ProposalDelivered' = h1ProposalDelivered,
      h1Prevoted' = h1Prevoted,
      h1PrevotesDelivered' = h1PrevotesDelivered,
      h1Precommitted' = h1Precommitted,
      h1PrecommitsDelivered' = h1PrecommitsDelivered,
      h1DecisionMade' = h1DecisionMade,
      KeepH2,
      KeepAuth,
      KeepFinality,
      activeHeight' = activeHeight,
      currentValidatorSet' = currentValidatorSet,
      progress' = progress + 1,
    }

  action DeliverHeight1StableProposal: bool =
    all {
      activeHeight == H1,
      h1ProposalInserted,
      not(h1ProposalDelivered),
      h1Round' = h1Round,
      h1NilPrecommits' = h1NilPrecommits,
      h1ValuePrecommits' = h1ValuePrecommits,
      h1NilCertObserved' = h1NilCertObserved,
      h1WaitedOnMixed' = h1WaitedOnMixed,
      h1Advanced' = h1Advanced,
      h1SameRoundCleared' = h1SameRoundCleared,
      h1CurrentRoundLock' = h1CurrentRoundLock,
      h1ProposalInserted' = h1ProposalInserted,
      h1ProposalDelivered' = true,
      h1Prevoted' = h1Prevoted,
      h1PrevotesDelivered' = h1PrevotesDelivered,
      h1Precommitted' = h1Precommitted,
      h1PrecommitsDelivered' = h1PrecommitsDelivered,
      h1DecisionMade' = h1DecisionMade,
      KeepH2,
      KeepAuth,
      KeepFinality,
      activeHeight' = activeHeight,
      currentValidatorSet' = currentValidatorSet,
      progress' = progress + 1,
    }

  action PrevoteHeight1StableValue(p: Proc_t): bool =
    all {
      activeHeight == H1,
      h1ProposalDelivered,
      H1DecisionSigners.contains(p),
      not(h1Prevoted.contains(p)),
      h1Round' = h1Round,
      h1NilPrecommits' = h1NilPrecommits,
      h1ValuePrecommits' = h1ValuePrecommits,
      h1NilCertObserved' = h1NilCertObserved,
      h1WaitedOnMixed' = h1WaitedOnMixed,
      h1Advanced' = h1Advanced,
      h1SameRoundCleared' = h1SameRoundCleared,
      h1CurrentRoundLock' = h1CurrentRoundLock,
      h1ProposalInserted' = h1ProposalInserted,
      h1ProposalDelivered' = h1ProposalDelivered,
      h1Prevoted' = h1Prevoted.union(Set(p)),
      h1PrevotesDelivered' = h1PrevotesDelivered,
      h1Precommitted' = h1Precommitted,
      h1PrecommitsDelivered' = h1PrecommitsDelivered,
      h1DecisionMade' = h1DecisionMade,
      KeepH2,
      KeepAuth,
      KeepFinality,
      activeHeight' = activeHeight,
      currentValidatorSet' = currentValidatorSet,
      progress' = progress + 1,
    }

  action DeliverHeight1Prevotes(p: Proc_t): bool =
    all {
      activeHeight == H1,
      H1DecisionSigners.subseteq(h1Prevoted),
      H1DecisionSigners.contains(p),
      not(h1PrevotesDelivered.contains(p)),
      h1Round' = h1Round,
      h1NilPrecommits' = h1NilPrecommits,
      h1ValuePrecommits' = h1ValuePrecommits,
      h1NilCertObserved' = h1NilCertObserved,
      h1WaitedOnMixed' = h1WaitedOnMixed,
      h1Advanced' = h1Advanced,
      h1SameRoundCleared' = h1SameRoundCleared,
      h1CurrentRoundLock' = h1CurrentRoundLock,
      h1ProposalInserted' = h1ProposalInserted,
      h1ProposalDelivered' = h1ProposalDelivered,
      h1Prevoted' = h1Prevoted,
      h1PrevotesDelivered' = h1PrevotesDelivered.union(Set(p)),
      h1Precommitted' = h1Precommitted,
      h1PrecommitsDelivered' = h1PrecommitsDelivered,
      h1DecisionMade' = h1DecisionMade,
      KeepH2,
      KeepAuth,
      KeepFinality,
      activeHeight' = activeHeight,
      currentValidatorSet' = currentValidatorSet,
      progress' = progress + 1,
    }

  action PrecommitHeight1StableValue(p: Proc_t): bool =
    all {
      activeHeight == H1,
      h1PrevotesDelivered.contains(p),
      H1DecisionSigners.contains(p),
      not(h1Precommitted.contains(p)),
      h1Round' = h1Round,
      h1NilPrecommits' = h1NilPrecommits,
      h1ValuePrecommits' = h1ValuePrecommits,
      h1NilCertObserved' = h1NilCertObserved,
      h1WaitedOnMixed' = h1WaitedOnMixed,
      h1Advanced' = h1Advanced,
      h1SameRoundCleared' = h1SameRoundCleared,
      h1CurrentRoundLock' = h1CurrentRoundLock,
      h1ProposalInserted' = h1ProposalInserted,
      h1ProposalDelivered' = h1ProposalDelivered,
      h1Prevoted' = h1Prevoted,
      h1PrevotesDelivered' = h1PrevotesDelivered,
      h1Precommitted' = h1Precommitted.union(Set(p)),
      h1PrecommitsDelivered' = h1PrecommitsDelivered,
      h1DecisionMade' = h1DecisionMade,
      KeepH2,
      KeepAuth,
      KeepFinality,
      activeHeight' = activeHeight,
      currentValidatorSet' = currentValidatorSet,
      progress' = progress + 1,
    }

  action DeliverHeight1Precommits: bool =
    all {
      activeHeight == H1,
      H1DecisionSigners.subseteq(h1Precommitted),
      not(h1PrecommitsDelivered),
      h1Round' = h1Round,
      h1NilPrecommits' = h1NilPrecommits,
      h1ValuePrecommits' = h1ValuePrecommits,
      h1NilCertObserved' = h1NilCertObserved,
      h1WaitedOnMixed' = h1WaitedOnMixed,
      h1Advanced' = h1Advanced,
      h1SameRoundCleared' = h1SameRoundCleared,
      h1CurrentRoundLock' = h1CurrentRoundLock,
      h1ProposalInserted' = h1ProposalInserted,
      h1ProposalDelivered' = h1ProposalDelivered,
      h1Prevoted' = h1Prevoted,
      h1PrevotesDelivered' = h1PrevotesDelivered,
      h1Precommitted' = h1Precommitted,
      h1PrecommitsDelivered' = true,
      h1DecisionMade' = h1DecisionMade,
      KeepH2,
      KeepAuth,
      KeepFinality,
      activeHeight' = activeHeight,
      currentValidatorSet' = currentValidatorSet,
      progress' = progress + 1,
    }

  action DecideHeight1RotateValidatorSet: bool =
    all {
      activeHeight == H1,
      h1PrecommitsDelivered,
      not(h1DecisionMade),
      h1Round' = h1Round,
      h1NilPrecommits' = h1NilPrecommits,
      h1ValuePrecommits' = h1ValuePrecommits,
      h1NilCertObserved' = h1NilCertObserved,
      h1WaitedOnMixed' = h1WaitedOnMixed,
      h1Advanced' = h1Advanced,
      h1SameRoundCleared' = h1SameRoundCleared,
      h1CurrentRoundLock' = h1CurrentRoundLock,
      h1ProposalInserted' = h1ProposalInserted,
      h1ProposalDelivered' = h1ProposalDelivered,
      h1Prevoted' = h1Prevoted,
      h1PrevotesDelivered' = h1PrevotesDelivered,
      h1Precommitted' = h1Precommitted,
      h1PrecommitsDelivered' = h1PrecommitsDelivered,
      h1DecisionMade' = true,
      KeepH2,
      KeepAuth,
      KeepFinality,
      activeHeight' = activeHeight,
      currentValidatorSet' = H2ValidatorSet,
      progress' = progress + 1,
    }

  action AdvanceToHeight2: bool =
    all {
      activeHeight == H1,
      h1DecisionMade,
      currentValidatorSet == H2ValidatorSet,
      H2Pristine,
      KeepH1,
      KeepH2,
      KeepAuth,
      KeepFinality,
      activeHeight' = H2,
      currentValidatorSet' = currentValidatorSet,
      progress' = progress + 1,
    }

  action InsertHeight2StableProposal: bool =
    all {
      activeHeight == H2,
      h1DecisionMade,
      currentValidatorSet == H2ValidatorSet,
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
      KeepAuth,
      KeepFinality,
      activeHeight' = activeHeight,
      currentValidatorSet' = currentValidatorSet,
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
      KeepAuth,
      KeepFinality,
      activeHeight' = activeHeight,
      currentValidatorSet' = currentValidatorSet,
      progress' = progress + 1,
    }

  action PrevoteHeight2StableValue(p: Proc_t): bool =
    all {
      activeHeight == H2,
      h2ProposalDelivered,
      H2DecisionSigners.contains(p),
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
      KeepAuth,
      KeepFinality,
      activeHeight' = activeHeight,
      currentValidatorSet' = currentValidatorSet,
      progress' = progress + 1,
    }

  action DeliverHeight2Prevotes(p: Proc_t): bool =
    all {
      activeHeight == H2,
      H2DecisionSigners.subseteq(h2Prevoted),
      H2DecisionSigners.contains(p),
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
      KeepAuth,
      KeepFinality,
      activeHeight' = activeHeight,
      currentValidatorSet' = currentValidatorSet,
      progress' = progress + 1,
    }

  action PrecommitHeight2StableValue(p: Proc_t): bool =
    all {
      activeHeight == H2,
      h2PrevotesDelivered.contains(p),
      H2DecisionSigners.contains(p),
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
      KeepAuth,
      KeepFinality,
      activeHeight' = activeHeight,
      currentValidatorSet' = currentValidatorSet,
      progress' = progress + 1,
    }

  action DeliverHeight2Precommits: bool =
    all {
      activeHeight == H2,
      H2DecisionSigners.subseteq(h2Precommitted),
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
      KeepAuth,
      KeepFinality,
      activeHeight' = activeHeight,
      currentValidatorSet' = currentValidatorSet,
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
      KeepAuth,
      KeepFinality,
      activeHeight' = activeHeight,
      currentValidatorSet' = currentValidatorSet,
      progress' = progress + 1,
    }

  action GossipHeight1AuthenticatedPrecommit(p: Proc_t): bool =
    all {
      h1DecisionMade,
      h1Round == 1,
      AuthorizedAtHeight(p, H1),
      not(h1AuthPrecommitGossiped.contains(p)),
      activeHeight' = activeHeight,
      currentValidatorSet' = currentValidatorSet,
      KeepH1,
      KeepH2,
      h1AuthPrecommitGossiped' = h1AuthPrecommitGossiped.union(Set(p)),
      h1AuthPrecommitObserved' = h1AuthPrecommitObserved,
      h1FatPointerSigGossiped' = h1FatPointerSigGossiped,
      h1FatPointerObserved' = h1FatPointerObserved,
      h2AuthPrecommitGossiped' = h2AuthPrecommitGossiped,
      h2AuthPrecommitObserved' = h2AuthPrecommitObserved,
      h2FatPointerSigGossiped' = h2FatPointerSigGossiped,
      h2FatPointerObserved' = h2FatPointerObserved,
      KeepFinality,
      progress' = progress,
      authProgress' = authProgress + 1,
    }

  action ObserveHeight1AuthenticatedPrecommit(p: Proc_t): bool =
    all {
      h1AuthPrecommitGossiped.contains(p),
      not(h1AuthPrecommitObserved.contains(p)),
      activeHeight' = activeHeight,
      currentValidatorSet' = currentValidatorSet,
      KeepH1,
      KeepH2,
      h1AuthPrecommitGossiped' = h1AuthPrecommitGossiped,
      h1AuthPrecommitObserved' = h1AuthPrecommitObserved.union(Set(p)),
      h1FatPointerSigGossiped' = h1FatPointerSigGossiped,
      h1FatPointerObserved' = h1FatPointerObserved,
      h2AuthPrecommitGossiped' = h2AuthPrecommitGossiped,
      h2AuthPrecommitObserved' = h2AuthPrecommitObserved,
      h2FatPointerSigGossiped' = h2FatPointerSigGossiped,
      h2FatPointerObserved' = h2FatPointerObserved,
      KeepFinality,
      progress' = progress,
      authProgress' = authProgress + 1,
    }

  action GossipHeight1FatPointerSig(p: Proc_t): bool =
    all {
      h1DecisionMade,
      h1Round == 1,
      AuthorizedAtHeight(p, H1),
      not(h1FatPointerSigGossiped.contains(p)),
      activeHeight' = activeHeight,
      currentValidatorSet' = currentValidatorSet,
      KeepH1,
      KeepH2,
      h1AuthPrecommitGossiped' = h1AuthPrecommitGossiped,
      h1AuthPrecommitObserved' = h1AuthPrecommitObserved,
      h1FatPointerSigGossiped' = h1FatPointerSigGossiped.union(Set(p)),
      h1FatPointerObserved' = h1FatPointerObserved,
      h2AuthPrecommitGossiped' = h2AuthPrecommitGossiped,
      h2AuthPrecommitObserved' = h2AuthPrecommitObserved,
      h2FatPointerSigGossiped' = h2FatPointerSigGossiped,
      h2FatPointerObserved' = h2FatPointerObserved,
      KeepFinality,
      progress' = progress,
      authProgress' = authProgress + 1,
    }

  action ObserveHeight1FatPointer: bool =
    all {
      H1AuthenticatedEvidenceComplete,
      not(h1FatPointerObserved),
      activeHeight' = activeHeight,
      currentValidatorSet' = currentValidatorSet,
      KeepH1,
      KeepH2,
      h1AuthPrecommitGossiped' = h1AuthPrecommitGossiped,
      h1AuthPrecommitObserved' = h1AuthPrecommitObserved,
      h1FatPointerSigGossiped' = h1FatPointerSigGossiped,
      h1FatPointerObserved' = true,
      h2AuthPrecommitGossiped' = h2AuthPrecommitGossiped,
      h2AuthPrecommitObserved' = h2AuthPrecommitObserved,
      h2FatPointerSigGossiped' = h2FatPointerSigGossiped,
      h2FatPointerObserved' = h2FatPointerObserved,
      KeepFinality,
      progress' = progress,
      authProgress' = authProgress + 1,
    }

  action GossipHeight2AuthenticatedPrecommit(p: Proc_t): bool =
    all {
      activeHeight == H2,
      h2DecisionMade,
      h2Round == 0,
      AuthorizedAtHeight(p, H2),
      not(h2AuthPrecommitGossiped.contains(p)),
      activeHeight' = activeHeight,
      currentValidatorSet' = currentValidatorSet,
      KeepH1,
      KeepH2,
      h1AuthPrecommitGossiped' = h1AuthPrecommitGossiped,
      h1AuthPrecommitObserved' = h1AuthPrecommitObserved,
      h1FatPointerSigGossiped' = h1FatPointerSigGossiped,
      h1FatPointerObserved' = h1FatPointerObserved,
      h2AuthPrecommitGossiped' = h2AuthPrecommitGossiped.union(Set(p)),
      h2AuthPrecommitObserved' = h2AuthPrecommitObserved,
      h2FatPointerSigGossiped' = h2FatPointerSigGossiped,
      h2FatPointerObserved' = h2FatPointerObserved,
      KeepFinality,
      progress' = progress,
      authProgress' = authProgress + 1,
    }

  action ObserveHeight2AuthenticatedPrecommit(p: Proc_t): bool =
    all {
      h2AuthPrecommitGossiped.contains(p),
      not(h2AuthPrecommitObserved.contains(p)),
      activeHeight' = activeHeight,
      currentValidatorSet' = currentValidatorSet,
      KeepH1,
      KeepH2,
      h1AuthPrecommitGossiped' = h1AuthPrecommitGossiped,
      h1AuthPrecommitObserved' = h1AuthPrecommitObserved,
      h1FatPointerSigGossiped' = h1FatPointerSigGossiped,
      h1FatPointerObserved' = h1FatPointerObserved,
      h2AuthPrecommitGossiped' = h2AuthPrecommitGossiped,
      h2AuthPrecommitObserved' = h2AuthPrecommitObserved.union(Set(p)),
      h2FatPointerSigGossiped' = h2FatPointerSigGossiped,
      h2FatPointerObserved' = h2FatPointerObserved,
      KeepFinality,
      progress' = progress,
      authProgress' = authProgress + 1,
    }

  action GossipHeight2FatPointerSig(p: Proc_t): bool =
    all {
      activeHeight == H2,
      h2DecisionMade,
      h2Round == 0,
      AuthorizedAtHeight(p, H2),
      not(h2FatPointerSigGossiped.contains(p)),
      activeHeight' = activeHeight,
      currentValidatorSet' = currentValidatorSet,
      KeepH1,
      KeepH2,
      h1AuthPrecommitGossiped' = h1AuthPrecommitGossiped,
      h1AuthPrecommitObserved' = h1AuthPrecommitObserved,
      h1FatPointerSigGossiped' = h1FatPointerSigGossiped,
      h1FatPointerObserved' = h1FatPointerObserved,
      h2AuthPrecommitGossiped' = h2AuthPrecommitGossiped,
      h2AuthPrecommitObserved' = h2AuthPrecommitObserved,
      h2FatPointerSigGossiped' = h2FatPointerSigGossiped.union(Set(p)),
      h2FatPointerObserved' = h2FatPointerObserved,
      KeepFinality,
      progress' = progress,
      authProgress' = authProgress + 1,
    }

  action ObserveHeight2FatPointer: bool =
    all {
      activeHeight == H2,
      H2AuthenticatedEvidenceComplete,
      not(h2FatPointerObserved),
      activeHeight' = activeHeight,
      currentValidatorSet' = currentValidatorSet,
      KeepH1,
      KeepH2,
      h1AuthPrecommitGossiped' = h1AuthPrecommitGossiped,
      h1AuthPrecommitObserved' = h1AuthPrecommitObserved,
      h1FatPointerSigGossiped' = h1FatPointerSigGossiped,
      h1FatPointerObserved' = h1FatPointerObserved,
      h2AuthPrecommitGossiped' = h2AuthPrecommitGossiped,
      h2AuthPrecommitObserved' = h2AuthPrecommitObserved,
      h2FatPointerSigGossiped' = h2FatPointerSigGossiped,
      h2FatPointerObserved' = true,
      KeepFinality,
      progress' = progress,
      authProgress' = authProgress + 1,
    }

  action FinalizeHeight1Authenticated: bool =
    all {
      H1AuthenticatedFatPointerObserved,
      h1DecisionMade,
      nextFinalityHeight == H1,
      latestFinalHeight == 0,
      not(finalizedHeights.contains(H1)),
      KeepH1,
      KeepH2,
      KeepAuth,
      nextFinalityHeight' = H2,
      latestFinalHeight' = H1,
      finalizedHeights' = finalizedHeights.union(Set(H1)),
      activeHeight' = activeHeight,
      currentValidatorSet' = currentValidatorSet,
      progress' = progress + 1,
    }

  action FinalizeHeight2Authenticated: bool =
    all {
      H2AuthenticatedFatPointerObserved,
      h2DecisionMade,
      nextFinalityHeight == H2,
      latestFinalHeight == H1,
      finalizedHeights.contains(H1),
      not(finalizedHeights.contains(H2)),
      KeepH1,
      KeepH2,
      KeepAuth,
      nextFinalityHeight' = 3,
      latestFinalHeight' = H2,
      finalizedHeights' = finalizedHeights.union(Set(H2)),
      activeHeight' = activeHeight,
      currentValidatorSet' = currentValidatorSet,
      progress' = progress + 1,
    }

  action StutterAfterFinality: bool =
    all {
      latestFinalHeight == H2,
      finalizedHeights == Set(H1, H2),
      H1AuthenticatedFatPointerObserved,
      H2AuthenticatedFatPointerObserved,
      Unchanged,
    }

  action Next: bool =
    any {
      SeedHeight1NilPrecommit,
      ObserveHeight1ValuePrecommit,
      WaitOnHeight1MixedPrecommitQuorum,
      ObserveHeight1NilCertCompleter,
      nondet p = oneOf(H1ValidatorSet)
      AdvanceHeight1AfterNilCert(p),
      InsertHeight1StableProposal,
      DeliverHeight1StableProposal,
      nondet p = oneOf(H1DecisionSigners)
      PrevoteHeight1StableValue(p),
      nondet p = oneOf(H1DecisionSigners)
      DeliverHeight1Prevotes(p),
      nondet p = oneOf(H1DecisionSigners)
      PrecommitHeight1StableValue(p),
      DeliverHeight1Precommits,
      DecideHeight1RotateValidatorSet,
      AdvanceToHeight2,
      InsertHeight2StableProposal,
      DeliverHeight2StableProposal,
      nondet p = oneOf(H2DecisionSigners)
      PrevoteHeight2StableValue(p),
      nondet p = oneOf(H2DecisionSigners)
      DeliverHeight2Prevotes(p),
      nondet p = oneOf(H2DecisionSigners)
      PrecommitHeight2StableValue(p),
      DeliverHeight2Precommits,
      DecideHeight2,
      nondet p = oneOf(Validators)
      GossipHeight1AuthenticatedPrecommit(p),
      nondet p = oneOf(Validators)
      ObserveHeight1AuthenticatedPrecommit(p),
      nondet p = oneOf(Validators)
      GossipHeight1FatPointerSig(p),
      ObserveHeight1FatPointer,
      nondet p = oneOf(Validators)
      GossipHeight2AuthenticatedPrecommit(p),
      nondet p = oneOf(Validators)
      ObserveHeight2AuthenticatedPrecommit(p),
      nondet p = oneOf(Validators)
      GossipHeight2FatPointerSig(p),
      ObserveHeight2FatPointer,
      FinalizeHeight1Authenticated,
      FinalizeHeight2Authenticated,
      StutterAfterFinality,
    }

  val StateWellFormed =
    Set(H1, H2).contains(activeHeight) and
    0.to(1).contains(h1Round) and
    h2Round == 0 and
    Set(H1ValidatorSet, H2ValidatorSet).contains(currentValidatorSet) and
    h1NilPrecommits.subseteq(H1ValidatorSet) and
    h1ValuePrecommits.subseteq(H1ValidatorSet) and
    h1NilPrecommits.intersect(h1ValuePrecommits) == Set() and
    h1Advanced.subseteq(H1ValidatorSet) and
    h1CurrentRoundLock.subseteq(H1ValidatorSet) and
    h1Prevoted.subseteq(H1DecisionSigners) and
    h1PrevotesDelivered.subseteq(H1DecisionSigners) and
    h1Precommitted.subseteq(H1DecisionSigners) and
    h2Prevoted.subseteq(H2DecisionSigners) and
    h2PrevotesDelivered.subseteq(H2DecisionSigners) and
    h2Precommitted.subseteq(H2DecisionSigners) and
    h1AuthPrecommitGossiped.subseteq(H1ValidatorSet) and
    h1AuthPrecommitObserved.subseteq(h1AuthPrecommitGossiped) and
    h1FatPointerSigGossiped.subseteq(H1ValidatorSet) and
    h2AuthPrecommitGossiped.subseteq(H2ValidatorSet) and
    h2AuthPrecommitObserved.subseteq(h2AuthPrecommitGossiped) and
    h2FatPointerSigGossiped.subseteq(H2ValidatorSet) and
    1.to(3).contains(nextFinalityHeight) and
    0.to(2).contains(latestFinalHeight) and
    finalizedHeights.subseteq(Set(H1, H2)) and
    0.to(60).contains(progress) and
    0.to(40).contains(authProgress)

  val ValidatorRotationDiscipline =
    (not(h1DecisionMade) implies currentValidatorSet == H1ValidatorSet) and
    (h1DecisionMade implies currentValidatorSet == H2ValidatorSet) and
    SignerSetHasQuorum(H1DecisionSigners, H1ValidatorSet) and
    SignerSetHasQuorum(H2DecisionSigners, H2ValidatorSet) and
    not(H2ValidatorSet.contains(P1)) and
    not(H1ValidatorSet.contains(P4))

  val HeightCursorSequentialProjection =
    (activeHeight == H2 implies h1DecisionMade and currentValidatorSet == H2ValidatorSet) and
    (H2Touched implies activeHeight == H2 and h1DecisionMade) and
    (h2DecisionMade implies h1DecisionMade) and
    (finalizedHeights.contains(H2) implies finalizedHeights.contains(H1))

  val MixedWaitDoesNotUnlockHeightedState =
    (h1WaitedOnMixed and not(h1NilCertObserved) implies
      activeHeight == H1 and
      h1Round == 0 and
      not(h1SameRoundCleared) and
      h1CurrentRoundLock == H1ValidatorSet and
      H2Pristine) and
    (h1WaitedOnMixed and not(h1NilCertObserved) implies H1MixedPrecommitQuorumWithoutNilCert)

  val NilResamplingClearsOnlyActiveHeight =
    (h1SameRoundCleared implies h1NilCertObserved and h1WaitedOnMixed and h1Round == 1) and
    (h1SameRoundCleared implies h1CurrentRoundLock == Set()) and
    (h1SameRoundCleared and not(h1DecisionMade) implies H2Pristine) and
    (h1ProposalInserted implies h1SameRoundCleared)

  val DecisionRequiresAuthorizedPrecommitQuorum =
    (h1DecisionMade implies h1PrecommitsDelivered and H1DecisionSigners.subseteq(h1Precommitted)) and
    (h2DecisionMade implies h2PrecommitsDelivered and H2DecisionSigners.subseteq(h2Precommitted))

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

  val AuthEvidenceUsesValidatorSetAtHeight =
    h1AuthPrecommitGossiped.forall(p => AuthorizedAtHeight(p, H1)) and
    h1AuthPrecommitObserved.forall(p => AuthorizedAtHeight(p, H1)) and
    h1FatPointerSigGossiped.forall(p => AuthorizedAtHeight(p, H1)) and
    h2AuthPrecommitGossiped.forall(p => AuthorizedAtHeight(p, H2)) and
    h2AuthPrecommitObserved.forall(p => AuthorizedAtHeight(p, H2)) and
    h2FatPointerSigGossiped.forall(p => AuthorizedAtHeight(p, H2))

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
      H2AuthPristine
    )

  val Height2WaitsForRotatedHeight =
    (activeHeight == H1).implies(H2Pristine and not(finalizedHeights.contains(H2))) and
    (not(h2DecisionMade)).implies(H2AuthPristine)

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
    (h1WaitedOnMixed implies h1NilCertObserved or H1MixedPrecommitQuorumWithoutNilCert) and
    (h1SameRoundCleared implies h1WaitedOnMixed) and
    (h1ProposalDelivered implies h1ProposalInserted) and
    (h1Prevoted != Set() implies h1ProposalDelivered) and
    (h1PrevotesDelivered != Set() implies H1DecisionSigners.subseteq(h1Prevoted)) and
    h1Precommitted.forall(p => h1PrevotesDelivered.contains(p)) and
    (h1PrecommitsDelivered implies H1DecisionSigners.subseteq(h1Precommitted)) and
    (h1DecisionMade implies h1PrecommitsDelivered) and
    (h2ProposalDelivered implies h2ProposalInserted) and
    (h2Prevoted != Set() implies h2ProposalDelivered) and
    (h2PrevotesDelivered != Set() implies H2DecisionSigners.subseteq(h2Prevoted)) and
    h2Precommitted.forall(p => h2PrevotesDelivered.contains(p)) and
    (h2PrecommitsDelivered implies H2DecisionSigners.subseteq(h2Precommitted)) and
    (h2DecisionMade implies h2PrecommitsDelivered)

  val Safety =
    StateWellFormed and
    ValidatorRotationDiscipline and
    HeightCursorSequentialProjection and
    MixedWaitDoesNotUnlockHeightedState and
    NilResamplingClearsOnlyActiveHeight and
    DecisionRequiresAuthorizedPrecommitQuorum and
    AuthEvidenceHeightDiscipline and
    AuthEvidenceUsesValidatorSetAtHeight and
    FatPointersRequireAuthenticatedEvidence and
    FinalityRequiresAuthenticatedFatPointer and
    MixedWaitDoesNotCreateAuthenticatedEvidence and
    Height2WaitsForRotatedHeight and
    FinalityInOrder and
    PhaseOrder

  temporal EventuallyRotatingAuthenticatedProgressFinalizesTwoHeights =
    Next.weakFair(Set(progress, authProgress)).implies(eventually(
      h1WaitedOnMixed and
      currentValidatorSet == H2ValidatorSet and
      H1AuthenticatedFatPointerObserved and
      H2AuthenticatedFatPointerObserved and
      latestFinalHeight == H2 and
      finalizedHeights == Set(H1, H2)
    ))

  action RecoverAndDecideHeight1 = all {
    SeedHeight1NilPrecommit
      .then(ObserveHeight1ValuePrecommit)
      .then(WaitOnHeight1MixedPrecommitQuorum)
      .then(ObserveHeight1NilCertCompleter)
      .then(AdvanceHeight1AfterNilCert(P1))
      .then(AdvanceHeight1AfterNilCert(P2))
      .then(AdvanceHeight1AfterNilCert(P3))
      .then(InsertHeight1StableProposal)
      .then(DeliverHeight1StableProposal)
      .then(PrevoteHeight1StableValue(P1))
      .then(PrevoteHeight1StableValue(P2))
      .then(DeliverHeight1Prevotes(P2))
      .then(DeliverHeight1Prevotes(P1))
      .then(PrecommitHeight1StableValue(P1))
      .then(PrecommitHeight1StableValue(P2))
      .then(DeliverHeight1Precommits)
      .then(DecideHeight1RotateValidatorSet)
  }

  action DecideHeight2FromRotatedSet = all {
    AdvanceToHeight2
      .then(InsertHeight2StableProposal)
      .then(DeliverHeight2StableProposal)
      .then(PrevoteHeight2StableValue(P2))
      .then(PrevoteHeight2StableValue(P4))
      .then(DeliverHeight2Prevotes(P4))
      .then(DeliverHeight2Prevotes(P2))
      .then(PrecommitHeight2StableValue(P2))
      .then(PrecommitHeight2StableValue(P4))
      .then(DeliverHeight2Precommits)
      .then(DecideHeight2)
  }

  action AuthenticateHeight1FatPointer = all {
    GossipHeight1AuthenticatedPrecommit(P1)
      .then(GossipHeight1AuthenticatedPrecommit(P2))
      .then(ObserveHeight1AuthenticatedPrecommit(P2))
      .then(ObserveHeight1AuthenticatedPrecommit(P1))
      .then(GossipHeight1FatPointerSig(P1))
      .then(GossipHeight1FatPointerSig(P2))
      .then(ObserveHeight1FatPointer)
  }

  action AuthenticateHeight2FatPointer = all {
    GossipHeight2AuthenticatedPrecommit(P2)
      .then(GossipHeight2AuthenticatedPrecommit(P4))
      .then(ObserveHeight2AuthenticatedPrecommit(P4))
      .then(ObserveHeight2AuthenticatedPrecommit(P2))
      .then(GossipHeight2FatPointerSig(P4))
      .then(GossipHeight2FatPointerSig(P2))
      .then(ObserveHeight2FatPointer)
  }

  run mixedWaitDoesNotUnlockOrRotateTest = {
    Init
      .then(SeedHeight1NilPrecommit)
      .then(ObserveHeight1ValuePrecommit)
      .then(WaitOnHeight1MixedPrecommitQuorum)
      .then(all {
        assert(h1WaitedOnMixed),
        assert(not(h1NilCertObserved)),
        assert(h1CurrentRoundLock == H1ValidatorSet),
        assert(currentValidatorSet == H1ValidatorSet),
        assert(H2Pristine),
        assert(Safety),
        Unchanged,
      })
  }

  run height1DecisionRotatesValidatorSetTest = {
    Init
      .then(RecoverAndDecideHeight1)
      .then(all {
        assert(h1DecisionMade),
        assert(currentValidatorSet == H2ValidatorSet),
        assert(H2Pristine),
        assert(Safety),
        Unchanged,
      })
  }

  run removedValidatorCannotPrevoteAtHeight2Test = {
    Init
      .then(RecoverAndDecideHeight1)
      .then(AdvanceToHeight2)
      .then(InsertHeight2StableProposal)
      .then(DeliverHeight2StableProposal)
      .then(PrevoteHeight2StableValue(P1))
      .fail()
  }

  run removedValidatorCannotPrecommitAtHeight2Test = {
    Init
      .then(RecoverAndDecideHeight1)
      .then(AdvanceToHeight2)
      .then(InsertHeight2StableProposal)
      .then(DeliverHeight2StableProposal)
      .then(PrevoteHeight2StableValue(P2))
      .then(PrevoteHeight2StableValue(P4))
      .then(DeliverHeight2Prevotes(P2))
      .then(PrecommitHeight2StableValue(P1))
      .fail()
  }

  run removedValidatorCannotGossipHeight2EvidenceTest = {
    Init
      .then(RecoverAndDecideHeight1)
      .then(DecideHeight2FromRotatedSet)
      .then(GossipHeight2AuthenticatedPrecommit(P1))
      .fail()
  }

  run newValidatorCannotGossipHeight1EvidenceTest = {
    Init
      .then(RecoverAndDecideHeight1)
      .then(GossipHeight1AuthenticatedPrecommit(P4))
      .fail()
  }

  run finalityRequiresRotatedAuthenticatedEvidenceTest = {
    Init
      .then(RecoverAndDecideHeight1)
      .then(AuthenticateHeight1FatPointer)
      .then(FinalizeHeight1Authenticated)
      .then(DecideHeight2FromRotatedSet)
      .then(FinalizeHeight2Authenticated)
      .fail()
  }

  run rotatingAuthenticatedProgressFinalizesTwoHeightsTest = {
    Init
      .then(RecoverAndDecideHeight1)
      .then(AuthenticateHeight1FatPointer)
      .then(FinalizeHeight1Authenticated)
      .then(DecideHeight2FromRotatedSet)
      .then(AuthenticateHeight2FatPointer)
      .then(FinalizeHeight2Authenticated)
      .then(all {
        assert(h1WaitedOnMixed),
        assert(currentValidatorSet == H2ValidatorSet),
        assert(H1AuthenticatedFatPointerObserved),
        assert(H2AuthenticatedFatPointerObserved),
        assert(latestFinalHeight == H2),
        assert(finalizedHeights == Set(H1, H2)),
        assert(Safety),
        Unchanged,
      })
  }
}
