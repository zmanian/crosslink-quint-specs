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
| Height/round/step machine | `round`, `step`, `Next` in `CrosslinkResampling.qnt`; `nextBftHeight`, `decision`, and `Next` in `CrosslinkMultiHeight.qnt`; `height`, per-height `round`/`step`, and `Next` in `CrosslinkHeightedRound.qnt` | The first height-indexed round-machine slice now exists, but it is not yet composed with every richer one-height rule. |
| Proposer by round | `Proposer` constant | Currently explicit finite map; later should model weighted proposer selection or abstract it behind assumptions. |
| Proposal with `validRound` | `Propose_t.validRound`, `ValidRoundJustified`, `AcceptableProposalFor`, `InsertProposal`; heighted equivalents in `CrosslinkHeightedRound.qnt` | A non-`-1` valid round must be below the proposal round and backed by a prevote quorum for the proposed value at the same BFT height. |
| Voting power | `VotingPower`, `TotalVotingPower`, `FaultyVotingPowerBound`, `QuorumVotingPower`, `CrosslinkValidatorSetChange.qnt` | Current examples cover equal-weight, non-uniform power, and a first dynamic validator-set rotation slice. |
| Prevote quorum | `LocalPrevoteQuorum` | Used for the value precommit transition and computed over delivered votes in the receiver's local view. |
| Precommit quorum | `LocalPrecommitQuorum`, `LocalNilPrecommitCert`, `LocalAnyPrecommitQuorum` | Used for decision, nil-certificate recovery, and round advancement over delivered precommits. |
| Local delivery | `seenPropose`, `seenPrevote`, `seenPrecommit`, `DeliverProposal`, `DeliverPrevote`, `DeliverPrecommit` | Main round receive guards now use local delivery state rather than global broadcast state. |
| Lock and valid-value state | `lockedValue`, `lockedRound`, `validValue`, `validRound` | The resampling rule is constrained to same-round state only. |
| Agreement | `DecisionUniqueness`, `DecisionCursorIsSequential`, `DecisionsRespectFinalizedPrefix`, `PerHeightAgreement`, `HeightCursorSequential`, `FinalityCursorSequential` | The finality model prevents skipped/duplicate BFT decisions and preserves a linear finalized PoW prefix; the heighted round model checks per-height agreement and sequential validator cursors; the heighted-finality model requires finality to follow local heighted decisions. |
| Accountability | `evidencePropose`, `evidencePrevote`, `evidencePrecommit`, `evidenceFatPointer`, `CrosslinkEvidenceGossip.qnt`, `CrosslinkFixtureGossipTransport.qnt`, and `ConflictingCommitsAccountable` | Current witnesses cover invalid unlocks, nil/value equivocation, fat-pointer signer validation, an explicit gossip-to-observer evidence pipeline, and a fixture-level transport boundary. |

## Crosslink-Specific Concepts

| Crosslink concept | Model location | Notes |
| --- | --- | --- |
| PoW stream snapshot | `Snapshot_t`, `Stream(round)`, `CrosslinkHeadSigmaSampling.qnt` | Models the sampled `head - sigma` candidate and now has a standalone fork-tree-derived sampling slice. |
| Static proposal validity | `StaticProposalValidity` | Splits validity into structural validity, PoW-chain validity, and finality-candidate validity. |
| Stream freshness | `IsFreshForRound`, `ValidProposalForRound`, and `UponStreamChangePrecommitNil` | A stream change between prevote and precommit causes nil precommit. |
| PoW stochastic assumptions | `CrosslinkPowStochasticAssumptions.qnt`, `CrosslinkStreamChurnRisk.qnt`, `CrosslinkPowReorgStress.qnt` | Separates normal PoW-arrival exposure from long-reorg-tail exposure: the 75-second post-Blossom block target is the denominator, validator-set size and GST shape the vulnerable-window numerator, sigma reduces only the assumed long-reorg-tail numerator, and finite churn burns rounds under nil-precommit resampling. |
| Dynamic sigma | `CrosslinkDynamicSigma.qnt`, `CrosslinkDynamicSigmaHeadSampling.qnt` | A third Crosslink variant: nil-precommit resampling with a consensus-visible per-height sigma schedule. Sigma changes only at BFT-height boundaries from committed failure telemetry, validator/network coverage, and Crosslink-participating PoW hash-power percentage; same-height nil-round burns do not change sigma. The head-sampling bridge checks that proposals use `head - sigma(h)` for the active BFT height. |
| Baseline sticky carry | `BaselineCrosslink` | The baseline carries stale cached proposal/lock state into the next round. |
| Nil-precommit resampling | `NilPrecommitResamplingCrosslink`, `CrosslinkHeightedRound.qnt` | A `2f + 1 PRECOMMIT nil` cert clears only same-height/same-round cached/lock/valid state. Mixed precommit quorums can advance waiting, but do not unlock. |
| Fork finality | `CrosslinkForkFinality.qnt`, `CrosslinkMultiHeight.qnt`, `CrosslinkHeightedFinality.qnt`, `CrosslinkFinalityProgressContract.qnt` | Models finalized-prefix linearity over a finite PoW fork tree and across sequential BFT heights; the progress contract adds a TLC-checked decision-to-finality handoff. |
| Round recovery plus finality | `CrosslinkComposed.qnt`, `CrosslinkHeightedFinality.qnt`, `CrosslinkComposedProgressContract.qnt` | Wires a resampled BFT decision into Crosslink finality, including a first height-indexed composition and a TLC-sized nil-resampling/finality progress contract. |
| Evidence gossip | `CrosslinkEvidenceGossip.qnt`, `CrosslinkHeightedEvidenceGossip.qnt`, `CrosslinkFixtureGossipTransport.qnt` | Separates gossiped evidence from observer-local accepted evidence; the heighted variant requires gossip, observed precommits, and fat pointers to agree on BFT height. The fixture transport bridge requires canonical Crosslink-topic envelopes before accepting the generated fixture wire. |
| Message authentication | `CrosslinkMessageAuth.qnt`, `CrosslinkHeightedMessageAuth.qnt`, `CrosslinkFixtureGossipTransport.qnt` | Requires canonical payload bytes and validator signatures before proposals, votes, or fat-pointer signatures are accepted; the heighted variant binds BFT height into the sign bytes. The fixture transport bridge checks the generated fixture sign-bytes token and relies on the fixture-manifest gate for real Ed25519 verification. |

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

`CrosslinkHeightedRound.qnt` adds the corresponding BFT-height dimension around
a compact Tenderlink round machine: each validator has a height cursor, each
height has its own round/step/lock/valid/cache state, valid-round/POL evidence
is scoped to the same BFT height, timeout transitions are scoped to the active
height, and nil-precommit resampling only clears state for the active height
and abandoned round.

`CrosslinkHeightedFinality.qnt` then requires the finality cursor to consume
local heighted decisions in BFT-height order. This catches the Crosslink
composition obligation that a later heighted decision on an incompatible PoW
fork is not finalizable after an earlier BFT height has finalized a different
branch.

## Remaining Work To Match Upstream Quality

- Connect the heighted authentication and evidence-gossip models to production
  serialization, signatures, and gossip transport.
- Connect the abstract message-authentication model to production signature
  verification and serialization code.
- Connect the abstract `StructurallyValid`, `PowChainValid`, and
  `FinalityCandidateValid` predicates, plus the standalone `head - sigma`
  sampler, to concrete Crosslink block/header data.
- Expand validator-set modeling beyond the current finite weighted examples to
  production signer-set formats and implementation-linked test vectors.
- Connect the standalone evidence gossip model to production gossip messages
  and signature verification.
- Expand bounded verification beyond `Safety` at depth 3.
- Lift the current TLC-friendly progress contracts into temporal liveness
  checks over the full imported protocol state, parameterized by stream
  stability after GST.
- Calibrate the `CrosslinkPowStochasticAssumptions.qnt`,
  `CrosslinkStreamChurnRisk.qnt`, and `CrosslinkPowReorgStress.qnt` layers
  with measured or analysis-backed block-arrival, propagation-race, GST-scaling,
  and long-tail reorg-depth distributions.
