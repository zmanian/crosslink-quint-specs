# Tendermint to Crosslink Mapping

This document maps the upstream Tendermint Quint-spec shape to the Crosslink
models in this repository.

The relevant upstream target is Informal Systems' Tendermint Quint
specification:

```text
https://github.com/informalsystems/tendermint-spec
```

That model is message-reactive, models receive/timeout events, tracks evidence
outside the protocol state for accountability checks, and organizes properties
around agreement, validity, and accountability. Crosslink should keep that
shape, but replace the value domain and validity predicate with PoW-stream and
finality semantics.

## Directly Inherited Tendermint Concepts

| Tendermint concept | Crosslink model location | Notes |
| --- | --- | --- |
| Height/round/step machine | `round`, `step`, `Next` in `CrosslinkResampling.qnt` | Current model is still one-height, but now includes proposal, vote, precommit, and timeout transitions. |
| Proposer by round | `Proposer` constant | Currently explicit finite map; later should model weighted proposer selection or abstract it behind assumptions. |
| Proposal with `validRound` | `Propose_t.validRound`, `ValidRoundJustified`, `AcceptableProposalFor`, `InsertProposal` | A non-`-1` valid round must be below the proposal round and backed by a prevote quorum for the proposed value. |
| Voting power | `VotingPower`, `TotalVotingPower`, `FaultyVotingPowerBound`, `QuorumVotingPower` | Current main examples are equal-weight; `CrosslinkWeightedQuorumModel` checks non-uniform power. |
| Prevote quorum | `PrevoteQuorum` | Used for value precommit transition and computed over summed voting power. |
| Precommit quorum | `PrecommitQuorum` | Used for decision and nil-certificate recovery and computed over summed voting power. |
| Local delivery | `seenPropose`, `seenPrevote`, `seenPrecommit`, `DeliverProposal`, `DeliverPrevote`, `DeliverPrecommit` | First receive-reactive slice: local delivery is separate from global broadcast, and local quorums only exist after delivery. |
| Lock and valid-value state | `lockedValue`, `lockedRound`, `validValue`, `validRound` | The resampling rule is constrained to same-round state only. |
| Agreement | `DecisionUniqueness` | Current value-domain agreement over one height. |
| Accountability | `evidencePropose`, `evidencePrevote`, `evidencePrecommit`, `evidenceFatPointer`, and `ConflictingCommitsAccountable` | Current witnesses cover invalid unlocks, nil/value equivocation, and fat-pointer signer validation over observer evidence. |

## Crosslink-Specific Concepts

| Crosslink concept | Model location | Notes |
| --- | --- | --- |
| PoW stream snapshot | `Snapshot_t`, `Stream(round)` | Models the sampled `head - sigma` candidate abstractly. |
| Static proposal validity | `StaticProposalValidity` | Splits validity into structural validity, PoW-chain validity, and finality-candidate validity. |
| Stream freshness | `IsFreshForRound`, `ValidProposalForRound`, and `UponStreamChangePrecommitNil` | A stream change between prevote and precommit causes nil precommit. |
| Baseline sticky carry | `BaselineCrosslink` | The baseline carries stale cached proposal/lock state into the next round. |
| Nil-precommit resampling | `NilPrecommitResamplingCrosslink` | A `2f + 1 PRECOMMIT nil` cert clears only same-round cached/lock/valid state. |
| Fork finality | `CrosslinkForkFinality.qnt` | Models finalized-prefix linearity over a finite PoW fork tree. |
| Round recovery plus finality | `CrosslinkComposed.qnt` | Wires a resampled BFT decision into Crosslink finality. |

## Deliberate Deviations From Tendermint

### Valid-Round Evidence

Tendermint's `validRound` field is only useful when it is backed by a prevote
quorum for the proposal value. The Crosslink model now makes that justification
explicit:

```text
validRound = -1
  or
validRound < proposal.round and 2f + 1 PREVOTE value at validRound
```

`InsertProposal` prevents a correct proposer from broadcasting an unjustified
non-`-1` valid round, `CorrectProposalValidRoundSound` makes that a safety
obligation over reachable correct proposal messages, and `UponProposalPrevote`
only lets an older lock vote for a different value when the proposal carries
justified valid-round evidence. `CrosslinkValidRoundModel` has executable
witnesses for both the nil-prevote rejection path and the justified unlock path.

### Moving Values

Tendermint assumes application validity is stable enough for the consensus
value. Crosslink proposals are snapshots of an external PoW stream. A value that
was valid at prevote time can become stale before precommit if the stream moves.

The model captures this with:

```text
UponStreamChangePrecommitNil
```

That action is the Crosslink-specific reason correct validators precommit nil
after seeing a value-prevote quorum.

### Local Delivery

The model now separates protocol broadcast from local delivery. Broadcast
messages enter `msgsPropose`, `msgsPrevote`, or `msgsPrecommit`; delivery
actions copy those messages into the receiver's `seen*` state. The local quorum
predicates (`LocalPrevoteQuorum` and `LocalPrecommitQuorum`) only use delivered
messages.

This is still a first slice: the legacy round actions continue to use global
quorum helpers, while `CrosslinkLocalDeliveryModel` captures the intended
receive-reactive semantics and guards against delivering messages that were not
broadcast. The next step is to replace the global guards in the main round
machine with local receive guards.

### Nil Certificate as Round-Abandon Evidence

Plain Tendermint nil precommits do not normally unlock a value lock. The
resampling variant adds a narrow Crosslink rule:

```text
2f + 1 PRECOMMIT nil for round r
  => clear only state whose round is exactly r
  => do not clear older lock/valid state
  => do not treat mixed precommits as unlock evidence
```

The relevant transitions are:

```text
StartNextRoundAfterPrecommitQuorum
ApplyLateNilPrecommitCertificate
```

### Timeout Transitions

The model now includes the first timeout slice:

```text
TimeoutProposePrevoteNil
TimeoutPrevotePrecommitNil
TimeoutPrecommitStartNextRound
```

A timeout can advance the local height/round/step machine, but it does not clear
same-round lock, valid, or cached proposal state by itself. Only
`StartNextRoundAfterPrecommitQuorum` with a nil-precommit certificate performs
the resampling unlock.

### Finality Can Skip PoW Heights

Crosslink finality is over a PoW branch prefix, not over every PoW block height.
`CrosslinkForkFinality.qnt` therefore allows finalizing a later tail-confirmed
snapshot on the same branch while rejecting an incompatible fork after finality.

## Remaining Work To Match Upstream Quality

- Replace the remaining global round guards with the local receive/delivery
  transition system and then lift the focused one-height fragment to a fuller
  multi-height model.
- Connect the abstract proposal, prevote, precommit, and fat-pointer evidence
  checks to production message authentication and serialization.
- Connect the abstract `StructurallyValid`, `PowChainValid`, and
  `FinalityCandidateValid` predicates to concrete Crosslink block/header data.
- Expand validator-set modeling beyond the current finite weighted examples to
  dynamic set changes and production signer-set formats.
- Add evidence gossip and observer-process transitions around the bookkeeping
  state.
- Expand bounded verification beyond `Safety` at depth 3.
- Add temporal liveness checks parameterized by stream stability after GST.
