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
| Height/round/step machine | `round`, `step`, `Next` in `CrosslinkResampling.qnt`; `nextBftHeight`, `decision`, and `Next` in `CrosslinkMultiHeight.qnt` | The round machine is still one-height, but the finality layer now has sequential BFT heights. |
| Proposer by round | `Proposer` constant | Currently explicit finite map; later should model weighted proposer selection or abstract it behind assumptions. |
| Proposal with `validRound` | `Propose_t.validRound`, `ValidRoundJustified`, `AcceptableProposalFor`, `InsertProposal` | A non-`-1` valid round must be below the proposal round and backed by a prevote quorum for the proposed value. |
| Voting power | `VotingPower`, `TotalVotingPower`, `FaultyVotingPowerBound`, `QuorumVotingPower` | Current main examples are equal-weight; `CrosslinkWeightedQuorumModel` checks non-uniform power. |
| Prevote quorum | `LocalPrevoteQuorum` | Used for the value precommit transition and computed over delivered votes in the receiver's local view. |
| Precommit quorum | `LocalPrecommitQuorum`, `LocalNilPrecommitCert`, `LocalAnyPrecommitQuorum` | Used for decision, nil-certificate recovery, and round advancement over delivered precommits. |
| Local delivery | `seenPropose`, `seenPrevote`, `seenPrecommit`, `DeliverProposal`, `DeliverPrevote`, `DeliverPrecommit` | Main round receive guards now use local delivery state rather than global broadcast state. |
| Lock and valid-value state | `lockedValue`, `lockedRound`, `validValue`, `validRound` | The resampling rule is constrained to same-round state only. |
| Agreement | `DecisionUniqueness`, `DecisionCursorIsSequential`, `DecisionsRespectFinalizedPrefix` | Current round-machine agreement is one-height; the multi-height layer prevents skipped/duplicate BFT decisions and preserves a linear finalized PoW prefix across BFT heights. |
| Accountability | `evidencePropose`, `evidencePrevote`, `evidencePrecommit`, `evidenceFatPointer`, `CrosslinkEvidenceGossip.qnt`, and `ConflictingCommitsAccountable` | Current witnesses cover invalid unlocks, nil/value equivocation, fat-pointer signer validation, and an explicit gossip-to-observer evidence pipeline. |

## Crosslink-Specific Concepts

| Crosslink concept | Model location | Notes |
| --- | --- | --- |
| PoW stream snapshot | `Snapshot_t`, `Stream(round)` | Models the sampled `head - sigma` candidate abstractly. |
| Static proposal validity | `StaticProposalValidity` | Splits validity into structural validity, PoW-chain validity, and finality-candidate validity. |
| Stream freshness | `IsFreshForRound`, `ValidProposalForRound`, and `UponStreamChangePrecommitNil` | A stream change between prevote and precommit causes nil precommit. |
| Baseline sticky carry | `BaselineCrosslink` | The baseline carries stale cached proposal/lock state into the next round. |
| Nil-precommit resampling | `NilPrecommitResamplingCrosslink` | A `2f + 1 PRECOMMIT nil` cert clears only same-round cached/lock/valid state. |
| Fork finality | `CrosslinkForkFinality.qnt`, `CrosslinkMultiHeight.qnt` | Models finalized-prefix linearity over a finite PoW fork tree and across sequential BFT heights. |
| Round recovery plus finality | `CrosslinkComposed.qnt` | Wires a resampled BFT decision into Crosslink finality. |
| Evidence gossip | `CrosslinkEvidenceGossip.qnt` | Separates gossiped evidence from observer-local accepted evidence. |

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

The active receive rules now use this local state:

```text
UponProposalPrevote           requires SeenProposal
UponValuePrevoteQuorum        requires LocalPrevoteQuorum
StartNextRoundAfterPrecommit  requires LocalAnyPrecommitQuorum
Decide                        requires LocalPrecommitQuorum
```

The global quorum helpers remain useful as broadcast-level evidence predicates
for invariants and scripted assertions, but they are no longer the main
validator-local receive guards.

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

`CrosslinkMultiHeight.qnt` lifts that obligation across sequential BFT heights:
height `h + 1` cannot decide before height `h`, a decided BFT height cannot be
decided again, and every later decision must extend earlier decisions. A BFT
height may still finalize a later PoW snapshot such as `a2` directly from
genesis when the candidate is tail-confirmed by `a3`.

## Remaining Work To Match Upstream Quality

- Instantiate the local receive/timeout round machine per BFT height, building
  on the standalone multi-height finality model.
- Connect the abstract proposal, prevote, precommit, and fat-pointer evidence
  checks to production message authentication and serialization.
- Connect the abstract `StructurallyValid`, `PowChainValid`, and
  `FinalityCandidateValid` predicates to concrete Crosslink block/header data.
- Expand validator-set modeling beyond the current finite weighted examples to
  dynamic set changes and production signer-set formats.
- Connect the standalone evidence gossip model to production gossip messages
  and signature verification.
- Expand bounded verification beyond `Safety` at depth 3.
- Add temporal liveness checks parameterized by stream stability after GST.
