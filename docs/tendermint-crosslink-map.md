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
| Height/round/step machine | `round`, `step`, `Next` in `CrosslinkResampling.qnt` | Current model is still a focused one-height fragment. |
| Proposer by round | `Proposer` constant | Currently explicit finite map; later should model weighted proposer selection or abstract it behind assumptions. |
| Proposal with `validRound` | `Propose_t.validRound`, `InsertProposal` | Present, but valid-round rules are not yet as complete as upstream Tendermint. |
| Voting power | `VotingPower`, `TotalVotingPower`, `FaultyVotingPowerBound`, `QuorumVotingPower` | Current main examples are equal-weight; `CrosslinkWeightedQuorumModel` checks non-uniform power. |
| Prevote quorum | `PrevoteQuorum` | Used for value precommit transition and computed over summed voting power. |
| Precommit quorum | `PrecommitQuorum` | Used for decision and nil-certificate recovery and computed over summed voting power. |
| Lock and valid-value state | `lockedValue`, `lockedRound`, `validValue`, `validRound` | The resampling rule is constrained to same-round state only. |
| Agreement | `DecisionUniqueness` | Current value-domain agreement over one height. |
| Accountability | `evidencePrecommit`, `ObservedPrecommitQuorum`, and `ConflictingCommitsAccountable` | Current witnesses cover invalid unlocks and nil/value equivocation over observer evidence. |

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

### Finality Can Skip PoW Heights

Crosslink finality is over a PoW branch prefix, not over every PoW block height.
`CrosslinkForkFinality.qnt` therefore allows finalizing a later tail-confirmed
snapshot on the same branch while rejecting an incompatible fork after finality.

## Remaining Work To Match Upstream Quality

- Replace the focused one-height fragment with a more complete receive/timeout
  transition system.
- Add explicit proposal, prevote, precommit, and decided/fat-pointer message
  validity checks.
- Connect the abstract `StructurallyValid`, `PowChainValid`, and
  `FinalityCandidateValid` predicates to concrete Crosslink block/header data.
- Expand validator-set modeling beyond the current finite weighted examples to
  dynamic set changes and production signer-set formats.
- Extend bookkeeping-only evidence beyond precommits to proposals, prevotes,
  decided/fat-pointer signatures, and evidence gossip.
- Expand bounded verification beyond `Safety` at depth 3.
- Add temporal liveness checks parameterized by stream stability after GST.
