module CrosslinkFinalityProgressContractModel {
  /*
   Temporal finality progress contract.

   CrosslinkSchedulerProgressContractModel proves that a fair post-GST
   scheduler eventually reaches a stable decision. This small extension keeps
   that verifier-friendly scheduler envelope and adds the finality step: once
   the stable decision exists, a fair finality applicator eventually advances
   the Crosslink finality cursor to the decided value.

   This is still a contract, not the full imported protocol state. It narrows
   the remaining liveness gap by checking the decision-to-finality phase under
   the same progress/fairness style as the scheduler contract.
   */

  import CrosslinkSchedulerProgressContractModel.* from "./CrosslinkSchedulerProgressContract"

  type Snapshot_t = str

  pure val Genesis = "g"
  pure val StableDecisionValue = "s2"

  var latestFinal: Snapshot_t
  var finalityDone: bool
  var finalityProgress: int

  action FinalityInit = all {
    Init,
    latestFinal' = Genesis,
    finalityDone' = false,
    finalityProgress' = 0,
  }

  action FinalityUnchanged = all {
    latestFinal' = latestFinal,
    finalityDone' = finalityDone,
    finalityProgress' = finalityProgress,
  }

  action SchedulerStep = all {
    Next,
    FinalityUnchanged,
  }

  action SeedNilSignerF(p: Proc_t): bool =
    all { SeedNilSigner(p), FinalityUnchanged }

  action AdvanceAfterNilCertF(p: Proc_t): bool =
    all { AdvanceAfterNilCert(p), FinalityUnchanged }

  action InsertStableProposalF: bool =
    all { InsertStableProposal, FinalityUnchanged }

  action DeliverStableProposalF: bool =
    all { DeliverStableProposal, FinalityUnchanged }

  action PrevoteStableValueF(p: Proc_t): bool =
    all { PrevoteStableValue(p), FinalityUnchanged }

  action DeliverStablePrevotesF(p: Proc_t): bool =
    all { DeliverStablePrevotes(p), FinalityUnchanged }

  action PrecommitStableValueF(p: Proc_t): bool =
    all { PrecommitStableValue(p), FinalityUnchanged }

  action DeliverStablePrecommitsF: bool =
    all { DeliverStablePrecommits, FinalityUnchanged }

  action DecideStableValueF: bool =
    all { DecideStableValue, FinalityUnchanged }

  action FinalizeStableDecision = all {
    schedulerDone,
    not(finalityDone),
    Unchanged,
    latestFinal' = StableDecisionValue,
    finalityDone' = true,
    finalityProgress' = finalityProgress + 1,
  }

  action StutterAfterFinality = all {
    finalityDone,
    Unchanged,
    FinalityUnchanged,
  }

  action FinalityNext =
    any {
      SchedulerStep,
      FinalizeStableDecision,
      StutterAfterFinality,
    }

  val FinalityPhaseOrder =
    (finalityDone implies schedulerDone) and
    (finalityDone implies latestFinal == StableDecisionValue) and
    (not(finalityDone) implies latestFinal == Genesis) and
    0.to(1).contains(finalityProgress)

  val FinalitySafety =
    Safety and FinalityPhaseOrder

  temporal EventuallyFinalized =
    FinalityNext.weakFair(Set(progress, finalityProgress)).implies(eventually(finalityDone))

  run fairSchedulerEventuallyFinalizesTest = {
    FinalityInit
      .then(SeedNilSignerF("p1"))
      .then(SeedNilSignerF("p2"))
      .then(SeedNilSignerF("p4"))
      .then(AdvanceAfterNilCertF("p2"))
      .then(AdvanceAfterNilCertF("p1"))
      .then(AdvanceAfterNilCertF("p3"))
      .then(SeedNilSignerF("p4"))
      .then(SeedNilSignerF("p2"))
      .then(SeedNilSignerF("p1"))
      .then(AdvanceAfterNilCertF("p3"))
      .then(AdvanceAfterNilCertF("p1"))
      .then(AdvanceAfterNilCertF("p2"))
      .then(InsertStableProposalF)
      .then(DeliverStableProposalF)
      .then(PrevoteStableValueF("p2"))
      .then(PrevoteStableValueF("p3"))
      .then(PrevoteStableValueF("p1"))
      .then(DeliverStablePrevotesF("p3"))
      .then(DeliverStablePrevotesF("p1"))
      .then(DeliverStablePrevotesF("p2"))
      .then(PrecommitStableValueF("p1"))
      .then(PrecommitStableValueF("p3"))
      .then(PrecommitStableValueF("p2"))
      .then(DeliverStablePrecommitsF)
      .then(DecideStableValueF)
      .then(FinalizeStableDecision)
      .then(all {
        assert(finalityDone),
        assert(latestFinal == StableDecisionValue),
        assert(FinalitySafety),
        Unchanged,
        FinalityUnchanged,
      })
  }
}
