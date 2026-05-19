module CrosslinkDeliveryFairnessContractModel {
  /*
   TLC-friendly temporal contract for receiver-local delivery fairness.

   CrosslinkResampling.qnt contains the concrete local-delivery actions. This
   model keeps only the network-progress envelope around one stable round:
   broadcast messages do not create local quorum evidence by themselves, every
   local quorum is backed by receiver-local delivery, and a post-GST fair
   delivery schedule eventually gives a correct decider a local precommit
   quorum.
   */

  type Proc_t = str

  pure val Corr = Set("p1", "p2", "p3")
  pure val Faulty = Set("p4")
  pure val Validators = Corr.union(Faulty)
  pure val Decider = "p1"
  pure val QuorumPower = 3

  var proposalBroadcast: bool
  var proposalDelivered: Set[Proc_t]
  var prevoteBroadcast: Set[Proc_t]
  var prevoteDelivered: Proc_t -> Set[Proc_t]
  var precommitBroadcast: Set[Proc_t]
  var precommitDelivered: Proc_t -> Set[Proc_t]
  var decided: Set[Proc_t]
  var progress: int

  action Init = all {
    proposalBroadcast' = false,
    proposalDelivered' = Set(),
    prevoteBroadcast' = Set(),
    prevoteDelivered' = Corr.mapBy(_ => Set()),
    precommitBroadcast' = Set(),
    precommitDelivered' = Corr.mapBy(_ => Set()),
    decided' = Set(),
    progress' = 0,
  }

  action Unchanged = all {
    proposalBroadcast' = proposalBroadcast,
    proposalDelivered' = proposalDelivered,
    prevoteBroadcast' = prevoteBroadcast,
    prevoteDelivered' = prevoteDelivered,
    precommitBroadcast' = precommitBroadcast,
    precommitDelivered' = precommitDelivered,
    decided' = decided,
    progress' = progress,
  }

  pure def VotingPowerOf(signers: Set[Proc_t]): int =
    signers.intersect(Validators).size()

  def LocalPrevoteQuorum(receiver: Proc_t): bool =
    VotingPowerOf(prevoteDelivered.get(receiver)) >= QuorumPower

  def LocalPrecommitQuorum(receiver: Proc_t): bool =
    VotingPowerOf(precommitDelivered.get(receiver)) >= QuorumPower

  action BroadcastProposal: bool =
    all {
      not(proposalBroadcast),
      proposalBroadcast' = true,
      proposalDelivered' = proposalDelivered,
      prevoteBroadcast' = prevoteBroadcast,
      prevoteDelivered' = prevoteDelivered,
      precommitBroadcast' = precommitBroadcast,
      precommitDelivered' = precommitDelivered,
      decided' = decided,
      progress' = progress + 1,
    }

  action DeliverProposal(p: Proc_t): bool =
    all {
      proposalBroadcast,
      Corr.contains(p),
      not(proposalDelivered.contains(p)),
      proposalBroadcast' = proposalBroadcast,
      proposalDelivered' = proposalDelivered.union(Set(p)),
      prevoteBroadcast' = prevoteBroadcast,
      prevoteDelivered' = prevoteDelivered,
      precommitBroadcast' = precommitBroadcast,
      precommitDelivered' = precommitDelivered,
      decided' = decided,
      progress' = progress + 1,
    }

  action BroadcastPrevote(p: Proc_t): bool =
    all {
      Corr.contains(p),
      proposalDelivered.contains(p),
      not(prevoteBroadcast.contains(p)),
      proposalBroadcast' = proposalBroadcast,
      proposalDelivered' = proposalDelivered,
      prevoteBroadcast' = prevoteBroadcast.union(Set(p)),
      prevoteDelivered' = prevoteDelivered,
      precommitBroadcast' = precommitBroadcast,
      precommitDelivered' = precommitDelivered,
      decided' = decided,
      progress' = progress + 1,
    }

  action DeliverPrevote(receiver: Proc_t, signer: Proc_t): bool =
    all {
      Corr.contains(receiver),
      Corr.contains(signer),
      prevoteBroadcast.contains(signer),
      not(prevoteDelivered.get(receiver).contains(signer)),
      proposalBroadcast' = proposalBroadcast,
      proposalDelivered' = proposalDelivered,
      prevoteBroadcast' = prevoteBroadcast,
      prevoteDelivered' =
        prevoteDelivered.set(
          receiver,
          prevoteDelivered.get(receiver).union(Set(signer))
        ),
      precommitBroadcast' = precommitBroadcast,
      precommitDelivered' = precommitDelivered,
      decided' = decided,
      progress' = progress + 1,
    }

  action BroadcastPrecommit(p: Proc_t): bool =
    all {
      Corr.contains(p),
      LocalPrevoteQuorum(p),
      not(precommitBroadcast.contains(p)),
      proposalBroadcast' = proposalBroadcast,
      proposalDelivered' = proposalDelivered,
      prevoteBroadcast' = prevoteBroadcast,
      prevoteDelivered' = prevoteDelivered,
      precommitBroadcast' = precommitBroadcast.union(Set(p)),
      precommitDelivered' = precommitDelivered,
      decided' = decided,
      progress' = progress + 1,
    }

  action DeliverPrecommit(receiver: Proc_t, signer: Proc_t): bool =
    all {
      Corr.contains(receiver),
      Corr.contains(signer),
      precommitBroadcast.contains(signer),
      not(precommitDelivered.get(receiver).contains(signer)),
      proposalBroadcast' = proposalBroadcast,
      proposalDelivered' = proposalDelivered,
      prevoteBroadcast' = prevoteBroadcast,
      prevoteDelivered' = prevoteDelivered,
      precommitBroadcast' = precommitBroadcast,
      precommitDelivered' =
        precommitDelivered.set(
          receiver,
          precommitDelivered.get(receiver).union(Set(signer))
        ),
      decided' = decided,
      progress' = progress + 1,
    }

  action Decide(p: Proc_t): bool =
    all {
      Corr.contains(p),
      LocalPrecommitQuorum(p),
      not(decided.contains(p)),
      proposalBroadcast' = proposalBroadcast,
      proposalDelivered' = proposalDelivered,
      prevoteBroadcast' = prevoteBroadcast,
      prevoteDelivered' = prevoteDelivered,
      precommitBroadcast' = precommitBroadcast,
      precommitDelivered' = precommitDelivered,
      decided' = decided.union(Set(p)),
      progress' = progress + 1,
    }

  action StutterAfterDeciderDone: bool =
    all {
      decided.contains(Decider),
      Unchanged,
    }

  /*
   Keep the TLC temporal action free of nested nondeterministic binders. The
   model is deliberately tiny, so explicit receiver/signer scheduling keeps
   the generated TLA+ simple and easier for TLC to exhaust.
   */
  action DeliverAnyProposal: bool =
    any {
      DeliverProposal("p1"),
      DeliverProposal("p2"),
      DeliverProposal("p3"),
    }

  action BroadcastAnyPrevote: bool =
    any {
      BroadcastPrevote("p1"),
      BroadcastPrevote("p2"),
      BroadcastPrevote("p3"),
    }

  action DeliverAnyPrevote: bool =
    any {
      DeliverPrevote("p1", "p1"),
      DeliverPrevote("p1", "p2"),
      DeliverPrevote("p1", "p3"),
      DeliverPrevote("p2", "p1"),
      DeliverPrevote("p2", "p2"),
      DeliverPrevote("p2", "p3"),
      DeliverPrevote("p3", "p1"),
      DeliverPrevote("p3", "p2"),
      DeliverPrevote("p3", "p3"),
    }

  action BroadcastAnyPrecommit: bool =
    any {
      BroadcastPrecommit("p1"),
      BroadcastPrecommit("p2"),
      BroadcastPrecommit("p3"),
    }

  action DeliverAnyPrecommit: bool =
    any {
      DeliverPrecommit("p1", "p1"),
      DeliverPrecommit("p1", "p2"),
      DeliverPrecommit("p1", "p3"),
      DeliverPrecommit("p2", "p1"),
      DeliverPrecommit("p2", "p2"),
      DeliverPrecommit("p2", "p3"),
      DeliverPrecommit("p3", "p1"),
      DeliverPrecommit("p3", "p2"),
      DeliverPrecommit("p3", "p3"),
    }

  action DecideAny: bool =
    any {
      Decide("p1"),
      Decide("p2"),
      Decide("p3"),
    }

  action Next: bool =
    any {
      BroadcastProposal,
      DeliverAnyProposal,
      BroadcastAnyPrevote,
      DeliverAnyPrevote,
      BroadcastAnyPrecommit,
      DeliverAnyPrecommit,
      DecideAny,
      StutterAfterDeciderDone,
    }

  val StateWellFormed =
    0.to(35).contains(progress) and
    proposalDelivered.subseteq(Corr) and
    prevoteBroadcast.subseteq(Corr) and
    precommitBroadcast.subseteq(Corr) and
    decided.subseteq(Corr) and
    Corr.forall(p =>
      prevoteDelivered.get(p).subseteq(prevoteBroadcast) and
      precommitDelivered.get(p).subseteq(precommitBroadcast)
    )

  val DeliveryBeforeEvidence =
    prevoteBroadcast.subseteq(proposalDelivered) and
    precommitBroadcast.forall(p => LocalPrevoteQuorum(p)) and
    decided.forall(p => LocalPrecommitQuorum(p))

  val BroadcastDoesNotCreateLocalQuorum =
    Corr.forall(p =>
      (LocalPrevoteQuorum(p) implies
        VotingPowerOf(prevoteDelivered.get(p)) >= QuorumPower) and
      (LocalPrecommitQuorum(p) implies
        VotingPowerOf(precommitDelivered.get(p)) >= QuorumPower)
    )

  val PhaseOrder =
    (proposalDelivered != Set() implies proposalBroadcast) and
    (prevoteBroadcast != Set() implies proposalBroadcast) and
    (precommitBroadcast != Set() implies Corr.exists(p => LocalPrevoteQuorum(p))) and
    (decided != Set() implies Corr.exists(p => LocalPrecommitQuorum(p)))

  val Safety =
    StateWellFormed and
    DeliveryBeforeEvidence and
    BroadcastDoesNotCreateLocalQuorum and
    PhaseOrder

  temporal EventuallyLocalDecision =
    Next.weakFair(Set(progress)).implies(eventually(decided.contains(Decider)))

  run broadcastVotesWithoutDeliveryDoNotCreateLocalQuorumTest = {
    Init
      .then(BroadcastProposal)
      .then(DeliverProposal("p1"))
      .then(DeliverProposal("p2"))
      .then(DeliverProposal("p3"))
      .then(BroadcastPrevote("p1"))
      .then(BroadcastPrevote("p2"))
      .then(BroadcastPrevote("p3"))
      .then(all {
        assert(not(LocalPrevoteQuorum(Decider))),
        assert(not(decided.contains(Decider))),
        assert(Safety),
        Unchanged,
      })
  }

  run precommitNeedsReceiverLocalPrevoteQuorumTest = {
    Init
      .then(BroadcastProposal)
      .then(DeliverProposal("p1"))
      .then(DeliverProposal("p2"))
      .then(DeliverProposal("p3"))
      .then(BroadcastPrevote("p1"))
      .then(BroadcastPrevote("p2"))
      .then(BroadcastPrevote("p3"))
      .then(DeliverPrevote("p2", "p1"))
      .then(DeliverPrevote("p2", "p2"))
      .then(DeliverPrevote("p2", "p3"))
      .then(BroadcastPrecommit("p1"))
      .fail()
  }

  run fairDeliveryCreatesLocalDecisionTest = {
    Init
      .then(BroadcastProposal)
      .then(DeliverProposal("p2"))
      .then(DeliverProposal("p1"))
      .then(DeliverProposal("p3"))
      .then(BroadcastPrevote("p3"))
      .then(BroadcastPrevote("p1"))
      .then(BroadcastPrevote("p2"))
      .then(DeliverPrevote("p1", "p2"))
      .then(DeliverPrevote("p1", "p3"))
      .then(DeliverPrevote("p1", "p1"))
      .then(DeliverPrevote("p2", "p1"))
      .then(DeliverPrevote("p2", "p3"))
      .then(DeliverPrevote("p2", "p2"))
      .then(DeliverPrevote("p3", "p2"))
      .then(DeliverPrevote("p3", "p1"))
      .then(DeliverPrevote("p3", "p3"))
      .then(BroadcastPrecommit("p2"))
      .then(BroadcastPrecommit("p3"))
      .then(BroadcastPrecommit("p1"))
      .then(DeliverPrecommit("p1", "p3"))
      .then(DeliverPrecommit("p1", "p2"))
      .then(DeliverPrecommit("p1", "p1"))
      .then(Decide("p1"))
      .then(all {
        assert(decided.contains(Decider)),
        assert(LocalPrecommitQuorum(Decider)),
        assert(Safety),
        Unchanged,
      })
  }
}
