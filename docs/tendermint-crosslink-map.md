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
| Height/round/step machine | `round`, `step`, `Next` in `CrosslinkResampling.qnt`; `nextBftHeight`, `decision`, and `Next` in `CrosslinkMultiHeight.qnt`; `height`, per-height `round`/`step`, and `Next` in `CrosslinkHeightedRound.qnt`; `CrosslinkDynamicSigmaHeightedRound.qnt`; `CrosslinkDynamicSigmaHeightedFinality.qnt`; `CrosslinkDynamicSigmaHeightedAuthenticatedEvidence.qnt`; `CrosslinkDynamicSigmaAuthenticatedFinality.qnt` | The first height-indexed round-machine slice now exists, including fixed-sigma and dynamic-sigma head-stream bridges, dynamic-sigma finality composition, and dynamic-sigma authenticated-evidence/finality bridges. |
| Proposer by round | `Proposer` constant | Currently explicit finite map; later should model weighted proposer selection or abstract it behind assumptions. |
| Proposal with `validRound` | `Propose_t.validRound`, `ValidRoundJustified`, `AcceptableProposalFor`, `InsertProposal`; heighted equivalents in `CrosslinkHeightedRound.qnt` | A non-`-1` valid round must be below the proposal round and backed by a prevote quorum for the proposed value at the same BFT height. |
| Voting power | `VotingPower`, `TotalVotingPower`, `FaultyVotingPowerBound`, `QuorumVotingPower`, `CrosslinkValidatorSetChange.qnt` | Current examples cover equal-weight, non-uniform power, and a first dynamic validator-set rotation slice. |
| Prevote quorum | `LocalPrevoteQuorum` | Used for the value precommit transition and computed over delivered votes in the receiver's local view. |
| Precommit quorum | `LocalPrecommitQuorum`, `LocalNilPrecommitCert`, `LocalAnyPrecommitQuorum` | Used for decision, nil-certificate recovery, and round advancement over delivered precommits. |
| Local delivery | `seenPropose`, `seenPrevote`, `seenPrecommit`, `DeliverProposal`, `DeliverPrevote`, `DeliverPrecommit` | Main round receive guards now use local delivery state rather than global broadcast state. |
| Lock and valid-value state | `lockedValue`, `lockedRound`, `validValue`, `validRound` | The resampling rule is constrained to same-round state only. |
| Agreement | `DecisionUniqueness`, `DecisionCursorIsSequential`, `DecisionsRespectFinalizedPrefix`, `PerHeightAgreement`, `HeightCursorSequential`, `FinalityCursorSequential` | The finality model prevents skipped/duplicate BFT decisions and preserves a linear finalized PoW prefix; the heighted round model checks per-height agreement and sequential validator cursors; the heighted-finality models require finality to follow local heighted decisions, including the dynamic-sigma tail for the dynamic variant. |
| Accountability | `evidencePropose`, `evidencePrevote`, `evidencePrecommit`, `evidenceFatPointer`, `CrosslinkEvidenceGossip.qnt`, `CrosslinkDynamicSigmaHeightedAuthenticatedEvidence.qnt`, `CrosslinkDynamicSigmaAuthenticatedFinality.qnt`, `CrosslinkFixtureGossipTransport.qnt`, `CrosslinkProductionFinalityProjectionContract.qnt`, `CrosslinkProductionFinalityTenderlinkEvidenceBridge.qnt`, and `ConflictingCommitsAccountable` | Current witnesses cover invalid unlocks, nil/value equivocation, fat-pointer signer validation, an explicit gossip-to-observer evidence pipeline, dynamic-sigma authenticated evidence/finality gating, a fixture-level transport boundary, and a production-fixture finality gate requiring proposal-transported BFT-block prefix-field evidence, a router-recorded Tenderlink value-precommit certificate before precommit evidence, and fat-pointer evidence. |

## Crosslink-Specific Concepts

| Crosslink concept | Model location | Notes |
| --- | --- | --- |
| PoW stream snapshot | `Snapshot_t`, `Stream(round)`, `CrosslinkHeadSigmaSampling.qnt`, `CrosslinkDynamicSigmaHeightedRound.qnt` | Models the sampled `head - sigma` candidate and now has standalone fixed-sigma and dynamic-sigma fork-tree-derived sampling slices. |
| Static proposal validity | `StaticProposalValidity` | Splits validity into structural validity, PoW-chain validity, and finality-candidate validity. |
| Stream freshness | `IsFreshForRound`, `ValidProposalForRound`, `UponStreamChangePrecommitNil`, and `CrosslinkBaselineChurnProgressContract.qnt` | A stream change between prevote and precommit causes nil precommit; the baseline-churn contract isolates the case where stale sticky state halts baseline while resampling burns nil-certified rounds to a fresh stable decision. |
| PoW stochastic assumptions | `CrosslinkPowStochasticAssumptions.qnt`, `CrosslinkStreamChurnRisk.qnt`, `CrosslinkValidatorScaleLivenessEnvelope.qnt`, `CrosslinkValidatorScaleProgressContract.qnt`, `CrosslinkValidatorScaleFinalityProgressContract.qnt`, `CrosslinkPowForkSchedule.qnt`, `CrosslinkPowBranchCompetition.qnt`, `CrosslinkPowReorgStress.qnt` | Separates normal PoW-arrival exposure from long-reorg-tail exposure: the 75-second post-Blossom block target is the denominator, validator-set size and GST shape the vulnerable-window numerator, sigma reduces only the assumed long-reorg-tail numerator, fork schedules and published-tip branch competition derive rollback-depth signals, finite churn burns rounds under nil-precommit resampling, and the validator-scale envelope now has TLC temporal contracts showing that resampling tolerates and finalizes under a larger globally distributed validator set where baseline halts. |
| Dynamic sigma | `CrosslinkDynamicSigma.qnt`, `CrosslinkDynamicSigmaCalibration.qnt`, `CrosslinkDynamicSigmaTelemetry.qnt`, `CrosslinkDynamicSigmaProposalEvidenceFormat.qnt`, `CrosslinkDynamicSigmaBftPayloadTransport.qnt`, `CrosslinkDynamicSigmaPrototypeDecodeGate.qnt`, `CrosslinkProductionDynamicSigmaConsensusParamIngressBridge.qnt`, `CrosslinkProductionDynamicSigmaConsensusParamIngressBridgeSafety.qnt`, `CrosslinkProductionDynamicSigmaPayloadIngressBridge.qnt`, `CrosslinkProductionDynamicSigmaPayloadIngressBridgeSafety.qnt`, `CrosslinkDynamicSigmaForkSchedule.qnt`, `CrosslinkDynamicSigmaBranchCompetition.qnt`, `CrosslinkDynamicSigmaResampling.qnt`, `CrosslinkDynamicSigmaFinality.qnt`, `CrosslinkDynamicSigmaConsensusParams.qnt`, `CrosslinkDynamicSigmaConsensusParamFormat.qnt`, `CrosslinkDynamicSigmaConsensusParamTransport.qnt`, `CrosslinkDynamicSigmaHeadSampling.qnt`, `CrosslinkDynamicSigmaHeightedRound.qnt`, `CrosslinkDynamicSigmaHeightedFinality.qnt`, `CrosslinkDynamicSigmaHeightedAuthenticatedEvidence.qnt`, `CrosslinkDynamicSigmaAuthenticatedFinality.qnt`, `CrosslinkProductionGossipRegistry.qnt`, `CrosslinkProductionGossipIngress.qnt` | A third Crosslink variant: nil-precommit resampling with a consensus-visible per-height sigma schedule. Sigma changes only at BFT-height boundaries from committed failure telemetry, validator/network coverage, and Crosslink-participating PoW hash-power percentage; participation below the target blocks relaxation, while participation below the floor raises sigma. The calibration/telemetry slices check measured-window labels, conservative raw-work/round-failure estimates, rollback-risk curves, and expected-loss budgets before labels are trusted. The proposal-evidence format slice pins Zebra's current 123-byte `DynamicSigmaProposalEvidence` serialization and rejects noncanonical bytes or selected sigma below the deterministic telemetry floor. The BFT-payload transport slice pins the tagged `CLDSIG01 || evidence || BftBlock` boundary and rejects wrong magic/topic/kind, evidence-byte mismatch, selected-sigma mismatch, or header-count mismatch. The prototype decode-gate slice mirrors Zebra's config guard: tagged dynamic-sigma bytes are unsupported by default, never decode as fixed-sigma bytes, and only report evidence-selected confirmation depth when `dynamic_sigma_prototype` is enabled. The production dynamic-sigma consensus-param ingress bridge requires raised/recovered param records to pass the production registry/ingress lane before quorum-signed gossip installs node config, and its safety projection keeps that ordering in the Apalache gate. The production dynamic-sigma payload ingress bridge requires the tagged payload to pass the production registry/ingress lane before transport acceptance or enabled prototype decode, and the direct safety projection keeps that ordering in the Apalache gate. The fork-schedule and branch-competition bridges feed rollback depth derived from best-tip transitions and published-tip work competition into the controller; the resampling/finality bridge checks that the raised sigma composes with nil-precommit recovery and then gates finality through the live dynamic sigma tail. Same-height nil-round burns do not change sigma or committed params. The consensus-param bridges check that next-height `bc_confirmation_depth_sigma` abstract wires, production-shaped bytes, quorum-signed production-byte gossip envelopes, and production registry/ingress lanes decode and route to the controller-selected sigma, including low-participation raises and exact raised/recovered hex vectors. The transport bridge stores the exact production wire beside the decoded abstract config. The other bridges check that proposals, value precommits, authenticated evidence, and finality validation use `head - sigma(h)` for the active BFT height and that the next BFT height uses telemetry-updated sigma. |
| Baseline sticky carry | `BaselineCrosslink`, `CrosslinkBaselineChurnProgressContract.qnt` | The baseline carries stale cached proposal/lock state into the next round; the progress contract makes the resulting sticky-churn halt explicit. |
| Nil-precommit resampling | `NilPrecommitResamplingCrosslink`, `CrosslinkHeightedRound.qnt`, `CrosslinkMixedWaitProgressContract.qnt`, `CrosslinkHeightedProgressProjectionContract.qnt`, `CrosslinkHeightedAuthenticatedProgressProjectionContract.qnt`, `CrosslinkRotatingAuthenticatedProgressProjectionContract.qnt` | A `2f + 1 PRECOMMIT nil` cert clears only same-height/same-round cached/lock/valid state. Mixed precommit quorums can advance waiting, but do not unlock; the mixed-wait contract checks that a later real nil certificate is required before resampling can proceed, the heighted projection checks the same mixed-wait rule before recovery at height 1 while height 2 remains pristine until height 1 decides, and the authenticated projections check that this recovery path does not create observer evidence until the recovered height decides and that later evidence is authorized by the validator set for its height. |
| Fork finality | `CrosslinkForkFinality.qnt`, `CrosslinkBftHeights.qnt`, `CrosslinkMultiHeight.qnt`, `CrosslinkHeightedFinality.qnt`, `CrosslinkFinalityProgressContract.qnt` | Models finalized-prefix linearity over a finite PoW fork tree and across sequential BFT heights; the compact BFT-height harness rejects skipped consensus heights, and the progress contract adds a TLC-checked decision-to-finality handoff. |
| Round recovery plus finality | `CrosslinkComposed.qnt`, `CrosslinkHeightedFinality.qnt`, `CrosslinkDynamicSigmaHeightedFinality.qnt`, `CrosslinkDynamicSigmaAuthenticatedFinality.qnt`, `CrosslinkComposedProgressContract.qnt`, `CrosslinkComposedImportedProgressBridge.qnt`, `CrosslinkHeightedProgressProjectionContract.qnt`, `CrosslinkHeightedAuthenticatedProgressProjectionContract.qnt`, `CrosslinkRotatingAuthenticatedProgressProjectionContract.qnt`, `CrosslinkProductionFinalityProjectionContract.qnt`, `CrosslinkProductionFinalityIngressBridge.qnt`, `CrosslinkProductionFinalityTenderlinkEvidenceBridge.qnt`, `CrosslinkProductionFinalityIngressProjectionBridge.qnt`, `CrosslinkProductionFinalityIngressProjectionBridgeSafety.qnt`, `CrosslinkValidatorScaleFinalityProgressContract.qnt` | Wires a resampled BFT decision into Crosslink finality, including fixed-sigma, dynamic-sigma, authenticated dynamic-sigma height-indexed compositions, a TLC-sized nil-resampling/finality progress contract, an imported-predicate bridge to the composed quorum/lock-scope/finality/fork-prefix checks, a two-height heighted progress projection, authenticated and rotating-validator authenticated two-height progress projections, a production-fixture proposal/finality gate with generated serialized prefix-field checks, a production-finality ingress-to-projection bridge, a scalar Tenderlink-router-to-finality-evidence handoff, a Rust-tested direct ingress/projection action bridge plus verifier-friendly staged proof slice that now gates precommit evidence behind a router-recorded Tenderlink value-precommit certificate, and a validator-scale stress-to-finality contract. |
| Evidence gossip | `CrosslinkEvidenceGossip.qnt`, `CrosslinkHeightedEvidenceGossip.qnt`, `CrosslinkHeightedAuthenticatedProgressProjectionContract.qnt`, `CrosslinkRotatingAuthenticatedProgressProjectionContract.qnt`, `CrosslinkFixtureGossipTransport.qnt`, `CrosslinkProductionFinalityProjectionContract.qnt`, `CrosslinkProductionFinalityIngressBridge.qnt`, `CrosslinkProductionFinalityTenderlinkEvidenceBridge.qnt`, `CrosslinkProductionFinalityIngressProjectionBridge.qnt`, `CrosslinkProductionFinalityIngressProjectionBridgeSafety.qnt` | Separates gossiped evidence from observer-local accepted evidence; the heighted variant requires gossip, observed precommits, and fat pointers to agree on BFT height. The authenticated progress projections gate two-height finality on observed quorum precommits plus matching fat-pointer signatures, with the rotating projection also checking signer authorization against the validator set active at the evidence height. The fixture transport bridge requires canonical Crosslink-topic envelopes before accepting the generated fixture wire, the production-finality projection requires proposal transport for the generated BFT-block candidate with matching serialized version/height/finalization/header-prefix fields plus the transported fat-pointer wire before finality advances, the finality/Tenderlink evidence bridge requires a router-recorded value-precommit certificate before precommit evidence projection, and all finality-ingress bridge forms require accepted production-finality ingress records plus accepted and router-recorded Tenderlink value-precommit-certificate ingress before precommit evidence, fat-pointer observation, or finality can advance. |
| Message authentication | `CrosslinkMessageAuth.qnt`, `CrosslinkHeightedMessageAuth.qnt`, `CrosslinkTenderlinkGossipRouter.qnt`, `CrosslinkTenderlinkGossipRouterSafety.qnt`, `CrosslinkProductionGossipRegistry.qnt`, `CrosslinkProductionGossipIngress.qnt`, `CrosslinkProductionTenderlinkIngressRouterBridge.qnt`, `CrosslinkProductionTenderlinkIngressRouterBridgeSafety.qnt`, `CrosslinkProductionFinalityTenderlinkEvidenceBridge.qnt`, `CrosslinkProductionMalachiteIngressRouterBridge.qnt`, `CrosslinkProductionMalachiteIngressRouterBridgeSafety.qnt`, `CrosslinkProductionDynamicSigmaConsensusParamIngressBridge.qnt`, `CrosslinkProductionDynamicSigmaConsensusParamIngressBridgeSafety.qnt`, `CrosslinkProductionDynamicSigmaPayloadIngressBridge.qnt`, `CrosslinkProductionDynamicSigmaPayloadIngressBridgeSafety.qnt`, `CrosslinkProductionFinalityIngressBridge.qnt`, `CrosslinkProductionFinalityIngressProjectionBridge.qnt`, `CrosslinkProductionFinalityIngressProjectionBridgeSafety.qnt`, `CrosslinkFixtureGossipTransport.qnt` | Requires canonical payload bytes and validator signatures before proposals, votes, or fat-pointer signatures are accepted; the heighted variant binds BFT height into the sign bytes. The Tenderlink router contract keeps proposal/POL packets, nil/value precommit packets and certificates, accountability evidence, known-peer consensus packets, and status packets on separate channel/kind namespaces under the shared Crosslink consensus topic, and its verifier-friendly slice now uses the exact compact proposal/POL packet hex from the consensus packet format model and the exact compact precommit packet hex from the precommit transport model. The production registry/ingress layer then keeps Tenderlink, Malachite, dynamic-sigma consensus-param and BFT-payload records, and production-finality proposal/fat-pointer records on their exact downstream lanes, with exact proposal/POL and precommit bytes on the Tenderlink consensus lane; the production Tenderlink and Malachite ingress/router bridges require matching production ingress before the downstream routers record consensus/evidence/known-peer/status or proposal/liveness/sync traffic, the new finality/Tenderlink evidence bridge requires the Tenderlink router's value-precommit-certificate record before production finality precommit evidence projection, the dynamic-sigma consensus-param ingress bridge and verifier-friendly projection reject Tenderlink or production-finality traffic as a signed-param substitute, the dynamic-sigma payload ingress bridge and verifier-friendly projection reject Tenderlink or production-finality traffic as a tagged payload substitute, and the finality-ingress bridges reject Tenderlink precommit traffic as a production-finality proposal substitute while requiring accepted and router-recorded Tenderlink value-precommit-certificate ingress before production finality precommit evidence is gossiped. The fixture transport bridge checks the generated fixture sign-bytes token and relies on the fixture-manifest gate for real Ed25519 verification. |

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
`CrosslinkTenderlinkProposalPolEvidence.qnt` adds the production-shaped bridge:
non-nil `validRound` proposal chunks must be paired with canonical Tenderlink
prevote packet evidence for the same height, valid round, value id, and
packet-derived quorum power. The bounded bridge covers both a weighted
two-signature quorum and a three-signature f = 1 quorum.
`CrosslinkTenderlinkProposalPolTransport.qnt` adds the adjacent transport
gate: transported POL evidence is accepted only after the matching proposal
chunk and prevote packet have arrived as decrypted exact compact Tenderlink
packets.
`CrosslinkTenderlinkGossipRouter.qnt` and
`CrosslinkTenderlinkGossipRouterSafety.qnt` then add the shared Tenderlink
router namespace contract for the proposal/POL, accountability-evidence,
known-peer, and status lanes, with the safety slice importing the exact compact
proposal/POL packet hex from the consensus packet format model and the exact
compact precommit packet hex used by the precommit transport boundary.

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

`CrosslinkDeliveryFairnessContract.qnt` adds a TLC-checked envelope around this
split. It keeps broadcast, receiver-local delivery, precommit broadcast, and
decision as separate steps, rejects quorum evidence from broadcast-only state,
and checks that fair delivery after GST eventually gives a correct decider a
local precommit quorum.

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

Mixed precommit quorums can end the local precommit wait for the round, but
they remain message evidence only: they neither unlock the nil side nor certify
the value side.

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

`CrosslinkTimeoutProgressContract.qnt` adds a TLC-checked temporal envelope for
this slice. It keeps older Tendermint locks preserved across ordinary timeout
and nil-precommit recovery, clears only same-round recovery state after the nil
certificate, and requires a justified stable proposal before the recovery path
can decide across an older lock.

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

`CrosslinkDynamicSigmaHeightedFinality.qnt` adds the corresponding dynamic-sigma
composition: finality consumes the heighted decision only if the candidate is
the active height's `head - sigma(h)` sample and has the tail required by that
height's consensus-visible sigma.

`CrosslinkDynamicSigmaHeightedAuthenticatedEvidence.qnt` and
`CrosslinkDynamicSigmaAuthenticatedFinality.qnt` add the accountability-facing
dynamic-sigma composition: precommit/fat-pointer evidence and finality cursor
advancement must be backed by authenticated evidence for the same active
height/round dynamic candidate.

`CrosslinkDynamicSigmaConsensusParams.qnt` adds the consensus-parameter
boundary for that dynamic schedule: height transitions install canonical
next-height params matching the deterministic sigma update, while same-height
nil-precommit round burns leave params untouched.
`CrosslinkDynamicSigmaConsensusParamFormat.qnt` pins a first production-shaped
byte envelope for those params and routes accepted bytes through the same
deterministic controller boundary.
`CrosslinkDynamicSigmaConsensusParamTransport.qnt` requires quorum-signed
canonical production param bytes on the Crosslink consensus topic before node
config follows the committed next-height sigma after format decoding, and it
records both the production wire and decoded abstract param installed by node
config.
`CrosslinkProductionDynamicSigmaConsensusParamIngressBridge.qnt` then places those signed param updates behind the production registry/ingress lane, so quorum gossip and node config installation require a matching production dynamic-sigma consensus-param ingress record first.
`CrosslinkProductionDynamicSigmaConsensusParamIngressBridgeSafety.qnt` keeps the same ordering as a direct safety projection for Apalache.
`CrosslinkDynamicSigmaProposalEvidenceFormat.qnt` pins the current
implementation-side proposal evidence bytes carried with a dynamic-sigma BFT
block proposal, so the proposer-selected sigma is accepted only when the exact
raw telemetry/margins payload justifies that sigma.
`CrosslinkDynamicSigmaBftPayloadTransport.qnt` pins the adjacent tagged
dynamic-sigma payload envelope, requiring the `CLDSIG01` magic, canonical
proposal evidence, checked-in BFT-block fixture shape, and header count equal
to the selected sigma before proposal-payload acceptance.
`CrosslinkDynamicSigmaPrototypeDecodeGate.qnt` then pins the implementation
gate around that envelope: default config rejects magic-prefixed dynamic-sigma
bytes as unsupported, enabled config accepts only valid dynamic payloads, and
tagged bytes never fall back to fixed-sigma decoding.
`CrosslinkProductionDynamicSigmaPayloadIngressBridge.qnt` then places that
tagged payload behind the production registry/ingress lane, so transport and
prototype decode acceptance require a matching production dynamic-sigma
BFT-payload ingress record first.
`CrosslinkProductionDynamicSigmaPayloadIngressBridgeSafety.qnt` keeps the same
ordering as a direct safety projection for Apalache.

## Remaining Work To Match Upstream Quality

- Connect the heighted authentication and evidence-gossip models to production
  serialization, signatures, and full production gossip transport. The
  Tenderlink and Malachite imported routers now cover the current compact and
  protobuf transport lanes, and the production Tenderlink/Malachite ingress
  bridges now gate those router records behind node-local production ingress;
  the production finality/Tenderlink evidence bridge also gates finality
  precommit evidence behind a router-recorded Tenderlink
  value-precommit-certificate, and the production finality ingress/projection
  bridges now carry the same router-recorded prerequisite through projection and
  finality.
- Connect the dynamic-sigma consensus-param format/transport models to real
  implementation serialization and gossip vectors once the production format
  exists. The proposal-carried dynamic-sigma evidence payload, tagged
  dynamic-sigma BFT payload, prototype decode gate, production consensus-param
  ingress bridge, production payload ingress bridge, and verifier-friendly
  ingress projections now have
  implementation-linked serialization, payload-shape, config-gate, and
  ingress-to-transport/decode vectors, but still need full concrete node gossip
  integration.
- Connect the abstract message-authentication model to production signature
  verification and serialization code.
- Connect the abstract `StructurallyValid`, `PowChainValid`, and
  `FinalityCandidateValid` predicates, plus the standalone `head - sigma`
  sampler, to concrete Crosslink block/header data.
- Expand validator-set modeling beyond the current finite weighted examples to
  production signer-set formats and implementation-linked test vectors.
- Connect the standalone evidence gossip model to full production gossip
  messages and signature verification.
- Expand bounded verification beyond `Safety` at depth 3.
- Lift the current TLC-friendly progress contracts and imported-predicate bridge
  into temporal liveness checks over the full imported protocol action graph,
  parameterized by stream stability after GST.
- Calibrate the `CrosslinkPowStochasticAssumptions.qnt`,
  `CrosslinkStreamChurnRisk.qnt`, `CrosslinkPowForkSchedule.qnt`,
  `CrosslinkPowBranchCompetition.qnt`, and `CrosslinkPowReorgStress.qnt`
  layers with measured or analysis-backed block-arrival, propagation-race,
  GST-scaling, branch-competition, and long-tail reorg-depth distributions.
