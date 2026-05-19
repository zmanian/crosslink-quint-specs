module CrosslinkComposedImportedProgressBridgeModel {
  /*
   TLC-friendly imported-predicate bridge for composed nil-resampling finality.

   CrosslinkComposedLivenessModel exposes the end-to-end imported round-machine
   path, but the current Quint-to-TLA/TLC path fails before state exploration on
   that map-heavy imported action graph. This bridge keeps the temporal graph
   scalar while importing the composed quorum, lock-scope, finality predicate,
   and concrete fork tree logic: after a quorum-checked nil-precommit
   certificate resamples the round, it can clear only same-round recovery state,
   older locks remain outside the nil-certificate scope, and a quorum-checked
   stable decision can finalize only through the same Extends/Agrees/TailConfirms
   checks used by CrosslinkComposed.qnt.
   */

  import CrosslinkComposed(
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
    Stream = Map(0 -> "a1", 1 -> "a2", 2 -> "a2"),
    Snapshots = Set("g", "a1", "a2", "a3", "b1", "b2", "b3"),
    StructurallyValid = Map(
      "g" -> true,
      "a1" -> true,
      "a2" -> true,
      "a3" -> true,
      "b1" -> true,
      "b2" -> true,
      "b3" -> true,
    ),
    PowChainValid = Map(
      "g" -> true,
      "a1" -> true,
      "a2" -> true,
      "a3" -> true,
      "b1" -> true,
      "b2" -> true,
      "b3" -> true,
    ),
    FinalityCandidateValid = Map(
      "g" -> true,
      "a1" -> true,
      "a2" -> true,
      "a3" -> true,
      "b1" -> true,
      "b2" -> true,
      "b3" -> true,
    ),
    ResampleOnNilPrecommit = true,
    MaxHeight = 3,
    Sigma = 1,
    InitialFinalized = "g",
    HeightOf = Map(
      "g" -> 0,
      "a1" -> 1,
      "a2" -> 2,
      "a3" -> 3,
      "b1" -> 1,
      "b2" -> 2,
      "b3" -> 3,
    ),
    AncestorAt = Map(
      "g" -> Map(0 -> "g", 1 -> "None", 2 -> "None", 3 -> "None"),
      "a1" -> Map(0 -> "g", 1 -> "a1", 2 -> "None", 3 -> "None"),
      "a2" -> Map(0 -> "g", 1 -> "a1", 2 -> "a2", 3 -> "None"),
      "a3" -> Map(0 -> "g", 1 -> "a1", 2 -> "a2", 3 -> "a3"),
      "b1" -> Map(0 -> "g", 1 -> "b1", 2 -> "None", 3 -> "None"),
      "b2" -> Map(0 -> "g", 1 -> "b1", 2 -> "b2", 3 -> "None"),
      "b3" -> Map(0 -> "g", 1 -> "b1", 2 -> "b2", 3 -> "b3"),
    ),
  ) as Composed from "./CrosslinkComposed"

  type Snapshot_t = str

  pure val NilSnapshot = "nil"
  pure val InitialFinalized = "g"
  pure val StableValue = "a2"
  pure val StableTip = "a3"
  pure val ForkValue = "b2"
  pure val ForkTip = "b3"
  pure val CorrectQuorum = Set("p1", "p2", "p3")
  pure val SameRoundResidualValueLockers = Set("p1")
  pure val OlderRoundValueLockers = CorrectQuorum
  pure val OlderLockRound = 0
  pure val AbandonedRound = 1
  pure val StableProposalValidRound = AbandonedRound
  pure val StableRound = 2

  var nilCertificateReady: bool
  var roundResampled: bool
  var sameRoundRecoveryStateCleared: bool
  var olderLockPreserved: bool
  var stableProposalDelivered: bool
  var stablePrevoteQuorumDelivered: bool
  var stablePrecommitQuorumDelivered: bool
  var decidedValue: Snapshot_t
  var bridgeLatestFinal: Snapshot_t
  var bridgeFinalized: Set[Snapshot_t]
  var progress: int
  var firedAction: str

  def BridgeValidFinalityCandidate(candidate: Snapshot_t, tip: Snapshot_t): bool =
    Composed::Extends(candidate, bridgeLatestFinal) and
    Composed::Height(candidate) > Composed::Height(bridgeLatestFinal) and
    Composed::TailConfirms(tip, candidate)

  def StableCandidateValidFromInitial: bool =
    Composed::Extends(StableValue, InitialFinalized) and
    Composed::Height(StableValue) > Composed::Height(InitialFinalized) and
    Composed::TailConfirms(StableTip, StableValue)

  def ImportedQuorum(signers: Set[str]): bool =
    signers.forall(p => Composed::Corr.union(Composed::Faulty).contains(p)) and
    Composed::VotingPowerOf(signers) >= Composed::QuorumVotingPower

  def ImportedCorrectQuorum(signers: Set[str]): bool =
    signers.forall(p => Composed::Corr.contains(p)) and
    ImportedQuorum(signers)

  def ImportedNilPrecommitCertificate: bool =
    AbandonedRound == OlderLockRound + 1 and
    ImportedCorrectQuorum(CorrectQuorum)

  def ImportedStableValidRoundPrevoteQuorum: bool =
    StableProposalValidRound == AbandonedRound and
    ImportedCorrectQuorum(CorrectQuorum)

  def ImportedStablePrevoteQuorum: bool =
    StableRound == AbandonedRound + 1 and
    ImportedCorrectQuorum(CorrectQuorum)

  def ImportedStablePrecommitQuorum: bool =
    StableRound == AbandonedRound + 1 and
    ImportedCorrectQuorum(CorrectQuorum)

  def ImportedCurrentRoundLockPowerAtMostF(lockers: Set[str]): bool =
    lockers.forall(p => Composed::Corr.contains(p)) and
    Composed::VotingPowerOf(lockers) <= Composed::FaultyVotingPowerBound

  def ImportedOlderLockQuorum(lockers: Set[str]): bool =
    lockers.forall(p => Composed::Corr.contains(p)) and
    Composed::VotingPowerOf(lockers) >= Composed::QuorumVotingPower

  def ImportedSameRoundResidualLocksAtMostF: bool =
    ImportedCurrentRoundLockPowerAtMostF(SameRoundResidualValueLockers)

  def ImportedOlderLockOutsideNilCertScope: bool =
    OlderLockRound < AbandonedRound and
    ImportedOlderLockQuorum(OlderRoundValueLockers)

  def ImportedStableProposalJustifiesOlderLock: bool =
    OlderLockRound < StableProposalValidRound and
    StableProposalValidRound < StableRound and
    ImportedStableValidRoundPrevoteQuorum

  action Init = all {
    nilCertificateReady' = false,
    roundResampled' = false,
    sameRoundRecoveryStateCleared' = false,
    olderLockPreserved' = false,
    stableProposalDelivered' = false,
    stablePrevoteQuorumDelivered' = false,
    stablePrecommitQuorumDelivered' = false,
    decidedValue' = NilSnapshot,
    bridgeLatestFinal' = InitialFinalized,
    bridgeFinalized' = Set(InitialFinalized),
    progress' = 0,
    firedAction' = "Init",
  }

  action Unchanged = all {
    nilCertificateReady' = nilCertificateReady,
    roundResampled' = roundResampled,
    sameRoundRecoveryStateCleared' = sameRoundRecoveryStateCleared,
    olderLockPreserved' = olderLockPreserved,
    stableProposalDelivered' = stableProposalDelivered,
    stablePrevoteQuorumDelivered' = stablePrevoteQuorumDelivered,
    stablePrecommitQuorumDelivered' = stablePrecommitQuorumDelivered,
    decidedValue' = decidedValue,
    bridgeLatestFinal' = bridgeLatestFinal,
    bridgeFinalized' = bridgeFinalized,
    progress' = progress,
    firedAction' = firedAction,
  }

  action MarkProgress(actionName: str): bool = all {
    progress' = progress + 1,
    firedAction' = actionName,
  }

  action RecordNilPrecommitCertificate: bool =
    all {
      not(nilCertificateReady),
      ImportedNilPrecommitCertificate,
      nilCertificateReady' = true,
      roundResampled' = roundResampled,
      sameRoundRecoveryStateCleared' = sameRoundRecoveryStateCleared,
      olderLockPreserved' = olderLockPreserved,
      stableProposalDelivered' = stableProposalDelivered,
      stablePrevoteQuorumDelivered' = stablePrevoteQuorumDelivered,
      stablePrecommitQuorumDelivered' = stablePrecommitQuorumDelivered,
      decidedValue' = decidedValue,
      bridgeLatestFinal' = bridgeLatestFinal,
      bridgeFinalized' = bridgeFinalized,
      MarkProgress("RecordNilPrecommitCertificate"),
    }

  action ResampleRoundAfterNilCertificate: bool =
    all {
      nilCertificateReady,
      not(roundResampled),
      ImportedSameRoundResidualLocksAtMostF,
      ImportedOlderLockOutsideNilCertScope,
      nilCertificateReady' = nilCertificateReady,
      roundResampled' = true,
      sameRoundRecoveryStateCleared' = true,
      olderLockPreserved' = true,
      stableProposalDelivered' = stableProposalDelivered,
      stablePrevoteQuorumDelivered' = stablePrevoteQuorumDelivered,
      stablePrecommitQuorumDelivered' = stablePrecommitQuorumDelivered,
      decidedValue' = decidedValue,
      bridgeLatestFinal' = bridgeLatestFinal,
      bridgeFinalized' = bridgeFinalized,
      MarkProgress("ResampleRoundAfterNilCertificate"),
    }

  action DeliverStableProposal: bool =
    all {
      roundResampled,
      sameRoundRecoveryStateCleared,
      olderLockPreserved,
      ImportedStableProposalJustifiesOlderLock,
      not(stableProposalDelivered),
      nilCertificateReady' = nilCertificateReady,
      roundResampled' = roundResampled,
      sameRoundRecoveryStateCleared' = sameRoundRecoveryStateCleared,
      olderLockPreserved' = olderLockPreserved,
      stableProposalDelivered' = true,
      stablePrevoteQuorumDelivered' = stablePrevoteQuorumDelivered,
      stablePrecommitQuorumDelivered' = stablePrecommitQuorumDelivered,
      decidedValue' = decidedValue,
      bridgeLatestFinal' = bridgeLatestFinal,
      bridgeFinalized' = bridgeFinalized,
      MarkProgress("DeliverStableProposal"),
    }

  action DeliverStablePrevoteQuorum: bool =
    all {
      stableProposalDelivered,
      not(stablePrevoteQuorumDelivered),
      ImportedStablePrevoteQuorum,
      nilCertificateReady' = nilCertificateReady,
      roundResampled' = roundResampled,
      sameRoundRecoveryStateCleared' = sameRoundRecoveryStateCleared,
      olderLockPreserved' = olderLockPreserved,
      stableProposalDelivered' = stableProposalDelivered,
      stablePrevoteQuorumDelivered' = true,
      stablePrecommitQuorumDelivered' = stablePrecommitQuorumDelivered,
      decidedValue' = decidedValue,
      bridgeLatestFinal' = bridgeLatestFinal,
      bridgeFinalized' = bridgeFinalized,
      MarkProgress("DeliverStablePrevoteQuorum"),
    }

  action DeliverStablePrecommitQuorum: bool =
    all {
      stablePrevoteQuorumDelivered,
      not(stablePrecommitQuorumDelivered),
      ImportedStablePrecommitQuorum,
      nilCertificateReady' = nilCertificateReady,
      roundResampled' = roundResampled,
      sameRoundRecoveryStateCleared' = sameRoundRecoveryStateCleared,
      olderLockPreserved' = olderLockPreserved,
      stableProposalDelivered' = stableProposalDelivered,
      stablePrevoteQuorumDelivered' = stablePrevoteQuorumDelivered,
      stablePrecommitQuorumDelivered' = true,
      decidedValue' = decidedValue,
      bridgeLatestFinal' = bridgeLatestFinal,
      bridgeFinalized' = bridgeFinalized,
      MarkProgress("DeliverStablePrecommitQuorum"),
    }

  action DecideStableValue: bool =
    all {
      stablePrecommitQuorumDelivered,
      decidedValue == NilSnapshot,
      nilCertificateReady' = nilCertificateReady,
      roundResampled' = roundResampled,
      sameRoundRecoveryStateCleared' = sameRoundRecoveryStateCleared,
      olderLockPreserved' = olderLockPreserved,
      stableProposalDelivered' = stableProposalDelivered,
      stablePrevoteQuorumDelivered' = stablePrevoteQuorumDelivered,
      stablePrecommitQuorumDelivered' = stablePrecommitQuorumDelivered,
      decidedValue' = StableValue,
      bridgeLatestFinal' = bridgeLatestFinal,
      bridgeFinalized' = bridgeFinalized,
      MarkProgress("DecideStableValue"),
    }

  action FinalizeDecision(candidate: Snapshot_t, tip: Snapshot_t): bool =
    all {
      decidedValue == candidate,
      not(bridgeFinalized.contains(candidate)),
      BridgeValidFinalityCandidate(candidate, tip),
      nilCertificateReady' = nilCertificateReady,
      roundResampled' = roundResampled,
      sameRoundRecoveryStateCleared' = sameRoundRecoveryStateCleared,
      olderLockPreserved' = olderLockPreserved,
      stableProposalDelivered' = stableProposalDelivered,
      stablePrevoteQuorumDelivered' = stablePrevoteQuorumDelivered,
      stablePrecommitQuorumDelivered' = stablePrecommitQuorumDelivered,
      decidedValue' = decidedValue,
      bridgeLatestFinal' = candidate,
      bridgeFinalized' = bridgeFinalized.union(Set(candidate)),
      MarkProgress("FinalizeDecision"),
    }

  action StutterAfterStableFinality: bool =
    all {
      bridgeFinalized.contains(StableValue),
      Unchanged,
    }

  action Next: bool =
    any {
      RecordNilPrecommitCertificate,
      ResampleRoundAfterNilCertificate,
      DeliverStableProposal,
      DeliverStablePrevoteQuorum,
      DeliverStablePrecommitQuorum,
      DecideStableValue,
      FinalizeDecision(StableValue, StableTip),
      StutterAfterStableFinality,
    }

  val ImportedPredicatesCoherent =
    Composed::Extends(StableValue, InitialFinalized) and
    Composed::TailConfirms(StableTip, StableValue) and
    Composed::Extends(ForkValue, InitialFinalized) and
    Composed::TailConfirms(ForkTip, ForkValue) and
    not(Composed::Agrees(StableValue, ForkValue))

  val ImportedQuorumPredicatesCoherent =
    ImportedNilPrecommitCertificate and
    ImportedStablePrevoteQuorum and
    ImportedStablePrecommitQuorum and
    ImportedCorrectQuorum(CorrectQuorum) and
    (2 * Composed::QuorumVotingPower - Composed::TotalVotingPower >
      Composed::FaultyVotingPowerBound)

  val ImportedLockScopePredicatesCoherent =
    ImportedSameRoundResidualLocksAtMostF and
    ImportedOlderLockOutsideNilCertScope and
    ImportedStableValidRoundPrevoteQuorum and
    ImportedStableProposalJustifiesOlderLock and
    not(ImportedCurrentRoundLockPowerAtMostF(CorrectQuorum))

  val StateWellFormed =
    0.to(10).contains(progress) and
    Set(
      "Init",
      "RecordNilPrecommitCertificate",
      "ResampleRoundAfterNilCertificate",
      "DeliverStableProposal",
      "DeliverStablePrevoteQuorum",
      "DeliverStablePrecommitQuorum",
      "DecideStableValue",
      "FinalizeDecision",
    ).contains(firedAction) and
    Set(NilSnapshot, StableValue).contains(decidedValue)

  val PhaseOrder =
    (roundResampled implies nilCertificateReady) and
    (sameRoundRecoveryStateCleared implies roundResampled) and
    (olderLockPreserved implies roundResampled) and
    (stableProposalDelivered implies
      sameRoundRecoveryStateCleared and olderLockPreserved) and
    (stableProposalDelivered implies roundResampled) and
    (stablePrevoteQuorumDelivered implies stableProposalDelivered) and
    (stablePrecommitQuorumDelivered implies stablePrevoteQuorumDelivered) and
    (decidedValue == StableValue implies stablePrecommitQuorumDelivered) and
    (bridgeFinalized.contains(StableValue) implies decidedValue == StableValue)

  val FinalizedPrefixLinear =
    tuples(bridgeFinalized, bridgeFinalized).forall(((a, b)) =>
      Composed::Agrees(a, b)
    )

  val LatestFinalExtendsAllFinalized =
    bridgeFinalized.forall(v => Composed::Extends(bridgeLatestFinal, v))

  val StableFinalityUsesImportedCandidateCheck =
    not(bridgeFinalized.contains(StableValue)) or
    StableCandidateValidFromInitial

  val DeliveredCertificatesUseImportedQuorumChecks =
    (not(nilCertificateReady) or ImportedNilPrecommitCertificate) and
    (not(stablePrevoteQuorumDelivered) or ImportedStablePrevoteQuorum) and
    (not(stablePrecommitQuorumDelivered) or ImportedStablePrecommitQuorum)

  val NilResamplingUsesImportedLockScope =
    (not(sameRoundRecoveryStateCleared) or (
      nilCertificateReady and
      ImportedNilPrecommitCertificate and
      ImportedSameRoundResidualLocksAtMostF and
      olderLockPreserved and
      ImportedOlderLockOutsideNilCertScope
    )) and
    (not(stableProposalDelivered) or
      ImportedStableProposalJustifiesOlderLock)

  val ForkValueNotFinalized =
    not(bridgeFinalized.contains(ForkValue))

  val Safety =
    ImportedPredicatesCoherent and
    ImportedQuorumPredicatesCoherent and
    ImportedLockScopePredicatesCoherent and
    StateWellFormed and
    PhaseOrder and
    FinalizedPrefixLinear and
    LatestFinalExtendsAllFinalized and
    StableFinalityUsesImportedCandidateCheck and
    DeliveredCertificatesUseImportedQuorumChecks and
    NilResamplingUsesImportedLockScope and
    ForkValueNotFinalized

  temporal EventuallyImportedPredicateBridgeFinalizes =
    Next.weakFair(Set(progress)).implies(eventually(
      bridgeFinalized.contains(StableValue) and bridgeLatestFinal == StableValue
    ))

  run importedComposedPredicatesAreCoherentTest = {
    Init.then(all {
      assert(ImportedPredicatesCoherent),
      assert(ImportedQuorumPredicatesCoherent),
      assert(ImportedNilPrecommitCertificate),
      assert(ImportedStableValidRoundPrevoteQuorum),
      assert(ImportedStablePrevoteQuorum),
      assert(ImportedStablePrecommitQuorum),
      assert(ImportedLockScopePredicatesCoherent),
      assert(ImportedSameRoundResidualLocksAtMostF),
      assert(ImportedOlderLockOutsideNilCertScope),
      assert(ImportedStableProposalJustifiesOlderLock),
      assert(StableCandidateValidFromInitial),
      assert(BridgeValidFinalityCandidate(StableValue, StableTip)),
      assert(BridgeValidFinalityCandidate(ForkValue, ForkTip)),
      assert(not(Composed::Agrees(StableValue, ForkValue))),
      assert(Safety),
      Unchanged,
    })
  }

  run importedQuorumBridgeRejectsInsufficientOrFaultyStableQuorumTest = {
    Init.then(all {
      assert(not(ImportedQuorum(Set("p1", "p2")))),
      assert(ImportedQuorum(Set("p1", "p2", "p4"))),
      assert(not(ImportedCorrectQuorum(Set("p1", "p2", "p4")))),
      assert(Safety),
      Unchanged,
    })
  }

  run importedLockScopeRejectsOverFCurrentRoundLocksTest = {
    Init.then(all {
      assert(ImportedCurrentRoundLockPowerAtMostF(Set("p1"))),
      assert(not(ImportedCurrentRoundLockPowerAtMostF(CorrectQuorum))),
      assert(ImportedOlderLockQuorum(CorrectQuorum)),
      assert(Safety),
      Unchanged,
    })
  }

  run importedNilResamplingPreservesOlderLockScopeTest = {
    Init
      .then(RecordNilPrecommitCertificate)
      .then(ResampleRoundAfterNilCertificate)
      .then(all {
        assert(sameRoundRecoveryStateCleared),
        assert(olderLockPreserved),
        assert(ImportedSameRoundResidualLocksAtMostF),
        assert(ImportedOlderLockOutsideNilCertScope),
        assert(NilResamplingUsesImportedLockScope),
        assert(Safety),
        Unchanged,
      })
  }

  run importedPredicateBridgeFinalizesStableDecisionTest = {
    Init
      .then(RecordNilPrecommitCertificate)
      .then(ResampleRoundAfterNilCertificate)
      .then(DeliverStableProposal)
      .then(DeliverStablePrevoteQuorum)
      .then(DeliverStablePrecommitQuorum)
      .then(DecideStableValue)
      .then(FinalizeDecision(StableValue, StableTip))
      .then(all {
        assert(bridgeFinalized.contains(StableValue)),
        assert(bridgeLatestFinal == StableValue),
        assert(Safety),
        Unchanged,
      })
  }

  run importedPredicateBridgeRejectsForkFinalityAfterStableDecisionTest = {
    Init
      .then(RecordNilPrecommitCertificate)
      .then(ResampleRoundAfterNilCertificate)
      .then(DeliverStableProposal)
      .then(DeliverStablePrevoteQuorum)
      .then(DeliverStablePrecommitQuorum)
      .then(DecideStableValue)
      .then(FinalizeDecision(ForkValue, ForkTip))
      .fail()
  }
}
