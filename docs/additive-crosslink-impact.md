# Additive Crosslink: Impact on the Formal Description

This doc maps the [Additive Opt-In
Crosslink](https://gist.github.com/zmanian/4f5ceee5e430a5c3f2e67af25a69582b)
proposal onto the current Quint spec surface. It is a design analysis, not a
commitment to ship any of the modeling work it identifies.

## Summary

The proposal does not invalidate the bytewise / transport / round-machine
modeling already in this repo. Instead it introduces a new orthogonal axis —
**finality binding mode** — that the current spec implicitly fixes at
`ConsensusBinding`. The Phase 1 deployment ships at `Advisory`; Phase 1b at
`MinerPolicy`; Phase 2 (conditional) at `ConsensusBinding`.

Most existing models stay valid. A handful need re-statement to make the
binding-mode assumption explicit, and a small set of new models is needed to
cover Phase 1 / Phase 1b behaviors that have no current analog.

## The new axis: finality binding mode

| Mode | What it means | Phase |
| --- | --- | --- |
| `Advisory` | Finality certificates exist and are gossiped. PoW block validity ignores them. A reorg across a "finalized" block produces a valid PoW chain and a publicly observable finalizer-roster failure event. | Phase 1 |
| `MinerPolicy` | Certificates filter miner fork-choice: a finality-respecting miner declines to extend candidate tips whose ancestry does not include the latest known cert. PoW *validity* is unchanged; the policy is a fork-choice layer. Consensus-binding economically if hashrate adoption is high enough. | Phase 1b |
| `ConsensusBinding` | A PoW block that reorgs across a finalized block is invalid. The roster is height-immediate ledger state. Finality evidence gates proposal validity. | Phase 2 (current Quint default) |

This axis is **orthogonal** to the round-machine axis (`BaselineCrosslink` /
`NilPrecommitResamplingCrosslink` / `CrosslinkDynamicSigmaModel`) and to the σ
policy axis (fixed vs dynamic). Conceptually the variant lattice expands from
three first-class variants to a 3 × 3 grid (or 3 × 2 if `MinerPolicy` is
treated as a transient between phases rather than a long-lived deployment
mode).

## What stays valid as-is

The following surfaces are binding-mode-independent. They apply unchanged at
all three modes:

- **Round-machine variants**:
  `BaselineCrosslink`, `NilPrecommitResamplingCrosslink`, and
  `CrosslinkDynamicSigmaModel`. Phase 1 still runs a BFT gadget that
  produces finality certificates; the gadget's internal rules don't depend
  on whether PoW validity reads them.
- **Wire-format and signing layers**:
  `CrosslinkTenderlinkVoteSignBytes`, `CrosslinkTenderlinkProposalChunkSignBytes`,
  `CrosslinkTenderlinkVotePacketFormat`, `CrosslinkTenderlinkConsensusPacketFormat`,
  `CrosslinkTenderlinkPrecommitTransport(Safety)`,
  `CrosslinkTenderlinkProposalPolEvidence`,
  `CrosslinkTenderlinkProposalPolTransport`,
  `CrosslinkTenderlinkNonceAckTransport`,
  `CrosslinkTenderlinkStatusPacketFormat`,
  `CrosslinkTenderlinkGossipRouter(Safety)`. The certs are bytes-on-the-wire
  regardless of how downstream consensus uses them.
- **Malachite transport**:
  `CrosslinkMalachiteProposalProtobufFormat`,
  `CrosslinkMalachiteProposalGossipTransport`,
  `CrosslinkMalachiteLivenessProtobufFormat`,
  `CrosslinkMalachiteLivenessGossipTransport`,
  `CrosslinkMalachiteSyncProtobufFormat`,
  `CrosslinkMalachiteSyncGossipTransport`,
  `CrosslinkMalachiteGossipRouter(Safety)`.
- **BFT-block and fat-pointer shape**:
  `CrosslinkBftBlockShape`, `CrosslinkBftBlockValidationGap`,
  `CrosslinkBftBlockProductionVectors`, `CrosslinkFatPointerFormat`,
  `CrosslinkFatPointerProductionVectors`,
  `CrosslinkFatPointerAuthenticatedEvidence`.
- **σ choice (fixed and dynamic)** plus the full dynamic-sigma controller
  and telemetry surface: `CrosslinkDynamicSigma`,
  `CrosslinkDynamicSigmaCalibration`, `CrosslinkDynamicSigmaTelemetry`,
  `CrosslinkDynamicSigmaConsensusParams(*)`,
  `CrosslinkDynamicSigmaHeadSampling`, `CrosslinkHeadSigmaSampling`. Phase 1
  still needs to decide which PoW snapshot to finalize. (Caveat: the
  *consensus-binding consensus-param transport* path becomes Phase-2-only —
  see below.)
- **Accountability evidence format**:
  `CrosslinkTenderlinkAccountabilityEvidenceFormat`,
  `CrosslinkTenderlinkAccountabilityEvidenceTransport`,
  `CrosslinkTenderlinkAccountabilityObserver(Bridge)(Safety)`,
  `CrosslinkTenderlinkUnlockAccountabilityBoundary`. Equivocation evidence
  is detectable in Phase 1; its on-chain consequence differs by mode (none
  in Phase 1, slashing in Phase 2) but the format is unchanged.

## What gets affected

These models implicitly assume `ConsensusBinding` and need either a
re-statement that exposes the assumption or a companion variant.

### Models that need a binding-mode re-statement

- **`CrosslinkForkFinality.qnt`** — currently encodes "fork *rejection*
  after finality" as a consensus rule. Under `Advisory`, the same shape
  becomes "fork *detection* after finality" — an observable
  finalizer-roster failure event, not a PoW invalidity. Needs an
  `Advisory` companion that decouples cert observation from PoW validity.

- **`CrosslinkBftHeights.qnt`, `CrosslinkMultiHeight.qnt`, and the
  inductive-finality decomposition in `docs/inductive-finality.md`** — the
  seven `Safety` lemmas still hold *in cert space* (the linearity of the
  finalized prefix is a property of the BFT layer regardless of binding
  mode). The implication "PoW chain respects the cert space prefix" is a
  consensus rule only under `ConsensusBinding`; under `Advisory` it is a
  desired property of honest miners. The lemma statements need to make
  the cert-space vs PoW-validity-space distinction explicit so the
  inductive argument carries cleanly across binding modes.

- **`CrosslinkProductionFinalityIngressBridge.qnt`,
  `CrosslinkProductionFinalityIngressProjectionBridge(Safety).qnt`,
  `CrosslinkProductionFinalityTenderlinkEvidenceBridge.qnt`,
  `CrosslinkProductionFinalityProjectionContract.qnt`** — currently gate
  consensus action on finality evidence. Under `Advisory` these are
  descriptively useful (wallets and explorers still want to see the
  evidence before they display `bft-final`) but not validity-gating.
  Become Phase-2-only consensus gates. Phase 1 needs descriptive analogs
  that record the same observations without binding them to validity.

- **`CrosslinkValidatorSetChange.qnt`,
  `CrosslinkHeightedValidatorEvidence.qnt`,
  `CrosslinkHeightedAuthenticatedEvidence.qnt`,
  `CrosslinkHeightedAuthenticatedGossipTransport.qnt`** — assume the
  roster is ledger state (height-immediate, derived from PoW block
  contents). Phase 1 puts the roster in an off-chain published manifest
  with off-chain governance. The validity story changes: a verifying
  node fetches the manifest, the manifest is not derived from the chain.
  These models need an `OffChainRoster` companion that swaps the
  on-chain derivation for a manifest-fetch + signature-check.

- **`CrosslinkDynamicSigmaConsensusParams(*).qnt`,
  `CrosslinkDynamicSigmaConsensusParamFormat.qnt`,
  `CrosslinkDynamicSigmaConsensusParamTransport.qnt`,
  `CrosslinkProductionDynamicSigmaConsensusParamIngressBridge(Safety).qnt`** —
  these encode "the next-height σ is installed through a quorum-signed
  consensus-param envelope that all validating nodes apply." That is a
  consensus rule. Phase 1 cannot ship a consensus-binding σ schedule.
  These models stay valid for Phase 2 but Phase 1 needs an alternative
  where σ is either fixed at protocol-parameter time (simplest Phase 1
  deployment) or carried as an *advisory* signal that
  finality-respecting miners use but PoW validity does not check.

- **`CrosslinkProductionDynamicSigmaPayloadIngressBridge(Safety).qnt`** —
  similar story for the tagged dynamic-sigma BFT payload transport.
  Phase 1 still emits BFT-block payloads; the question is whether
  payload acceptance is a consensus rule or a finalizer-side acceptance
  rule.

### Models that don't exist yet

The proposal calls for behaviors that have no current Quint counterpart.
The minimum set of new models for a faithful Phase 1 / Phase 1b spec:

- **`CrosslinkOffChainRoster.qnt`** — manifest-based roster semantics:
  published, signed by a governance multisig, version-bumped through
  off-chain governance, replicated to all verifying nodes. Validators
  verify cert signatures against the *currently published* roster, not
  against ledger state. Captures the proposal's property that "any
  verifying node can fetch the current roster" — the manifest must be
  consistently observable, which is non-trivial in a permissionless p2p
  setting and is itself a modelable safety question (manifest fork,
  manifest replay, manifest authority compromise).

- **`CrosslinkAdvisoryFinality.qnt`** — top-level Advisory variant.
  Composes the round machine + cert format + gossip transport, with the
  safety story shifted from *consensus-binding reorg prevention* to
  *roster honesty*. Different safety budget: trust model is 2/3 honest
  roster (off-chain governance), strictly weaker than 2/3 honest stake
  with slashing. The proposal calls this trade-off out explicitly.

- **`CrosslinkFinalityRespectingMinerPolicy.qnt`** — Phase 1b. A miner
  that augments standard PoW longest-chain fork-choice with a filter:
  discard candidate tips whose ancestry does not include the latest
  known finality certificate. Not a consensus rule; a protocol-economic
  equilibrium. Key analyses the model should expose:
  - Below 50% hashrate adoption: finality-respecting miners
    occasionally forgo block rewards on chains they decline to extend.
    The cost is real, measurable, and absorbed by the operator.
  - At ~50%: contested. Subject to local-view differences and
    cert-propagation latency.
  - Above 50%: finality becomes consensus-binding economically without
    being consensus-binding in rules. Any reorg attempt loses the
    longest-chain race because the honest majority of miners declines
    to extend it.
  - Adversarial: a compromised roster can issue a fraudulent cert that
    causes finality-respecting miners to refuse the honest PoW chain.
    The proposal calls this out as a failure mode requiring operator
    override or roster-manifest pinning.

- **`CrosslinkGracefulDeprecation.qnt`** — the proposal makes
  reversibility a design goal: "if Phase 1 fails to attract use, the
  roster stops signing, no consensus or monetary unwind." Worth
  modeling explicitly: cert stream halts → all verifying nodes observe
  the halt → PoW chain liveness is preserved → no protocol-level
  cleanup needed. Equivalently: a Phase 1 deployment that never
  graduates leaves no dead consensus-rule debt.

- **`CrosslinkPhase2Migration.qnt`** — if Phase 1 graduates, the
  transition itself is a hard fork. The model would need to specify
  what historical finality means across the boundary: do Phase 1
  certificates count as proof of historical finality after Phase 2
  activates? How does the roster transition from off-chain manifest to
  on-chain stake registry deterministically? Properties to check:
  - Pre-activation certs are not silently invalidated.
  - Post-activation, Phase 2's consensus rules treat the
    Phase-1-finalized prefix as already-finalized (no double-finalize,
    no fork around it).
  - The manifest → on-chain roster mapping is deterministic, not
    operator-chosen at activation time.

## How the variant comparison would change

The 12-axis table in [`README.md`](../README.md#variant-comparison)
currently compares the three first-class variants on round-machine and σ
axes. Under the additive proposal it gains new rows that the table
currently leaves implicit:

| Axis | Baseline | NilPrecommit | DynamicSigma |
| --- | --- | --- | --- |
| Finality binding mode (current implicit) | `ConsensusBinding` | `ConsensusBinding` | `ConsensusBinding` |
| Roster source (current implicit) | On-chain validator set, height-immediate | Same | Same |
| Reorg across finalized blocks (current implicit) | Invalid (consensus rule) | Same | Same |
| Roster compromise consequence (current implicit) | Slashable equivocation | Same | Same |

Under additive, these implicit assumptions become explicit. A row of the
expanded table might read:

| Axis | Baseline + Advisory | Baseline + ConsensusBinding |
| --- | --- | --- |
| Finality binding mode | Advisory | ConsensusBinding |
| Roster source | Off-chain manifest | On-chain validator set |
| Reorg across "finalized" blocks | Valid PoW chain + observable roster failure event | Invalid PoW block |
| Roster compromise consequence | Reputational + contractual; removal from manifest | Slashable equivocation |
| New consensus rules required | None | Reorg-bounding, coinbase rewards, staking actions, stake registry, slashing |
| Reversibility | Roster stops signing; no cleanup | Hard fork required |
| Trust budget | 2/3 honest off-chain roster | 2/3 honest stake with slashing |

## Tradeoffs reconsidered under additive

The current `README.md` § "Tradeoffs" recommends
`CrosslinkDynamicSigmaModel` as the deployment of choice "if the
consensus-visible telemetry surface is acceptable." Under additive that
recommendation is conditional on binding mode:

- **Phase 1 deployment.** The dynamic-sigma machinery is
  consensus-binding state (per-height σ schedule, telemetry envelopes,
  signed ingress) — exactly the kind of surface Phase 1 is built to
  avoid. The minimum viable Phase 1 deployment is therefore
  `BaselineCrosslink` (or `NilPrecommitResamplingCrosslink`) at
  `Advisory`, with σ fixed at protocol-parameter time. The dynamic-σ
  machinery becomes deployable as the binding mode escalates.
- **Phase 1b deployment.** Same round-machine choice. The new piece is
  the `FinalityRespectingMinerPolicy` deployed as a miner build flag.
  Still no consensus-rule changes; σ can stay fixed.
- **Phase 2 deployment.** Now the full current Quint surface applies:
  `CrosslinkDynamicSigmaModel` with consensus-binding finality, on-chain
  roster, slashing, and the full consensus-param ingress chain.

So additive doesn't deprecate the existing modeling — it sequences it.
The current spec covers what Phase 2 needs; additive identifies which
pieces ship later vs sooner.

## Cost of doing this modeling

The new-model list is non-trivial. As a rough ordering by value:

1. **`CrosslinkOffChainRoster.qnt`** — foundational; every Phase 1 model
   needs it. The manifest semantics are subtle (replication, fork,
   replay, authority compromise) and they directly affect the trust
   budget claim. High value, medium effort.
2. **`CrosslinkAdvisoryFinality.qnt`** — top-level Advisory composition.
   Mostly composes existing pieces with the binding-mode assumption made
   explicit. Medium value, low-to-medium effort.
3. **`CrosslinkFinalityRespectingMinerPolicy.qnt`** — Phase 1b. The most
   interesting *new* safety/liveness analysis (the
   hashrate-adoption-percentage equilibrium). High value if Phase 1b is
   on the roadmap, low value otherwise.
4. **`CrosslinkAdvisoryForkFinality.qnt`** — companion to
   `CrosslinkForkFinality.qnt`. Small, mostly mechanical.
5. **`CrosslinkGracefulDeprecation.qnt`** — small. Mostly worth doing as
   a property check rather than a new model.
6. **`CrosslinkPhase2Migration.qnt`** — only needed if/when Phase 2 is
   committed to. Defer until then.

Items (1)–(4) plus a re-statement pass over the existing fork-finality
and ingress-bridge models would cover Phase 1 + Phase 1b at the same
level of completeness the current repo achieves for Phase 2.

## Decision point

Adopting the additive proposal is a roadmap decision, not a modeling
decision. The Quint spec can support either rollout shape. What the
modeling work would record is:

- the explicit binding-mode assumption in every safety lemma that
  currently leaves it implicit, so the proofs carry cleanly across
  modes;
- the off-chain roster as a first-class concept with its own safety
  budget;
- the finality-respecting miner policy as a separate equilibrium model
  whose analysis informs the Phase 1b adoption decision.

If the project commits to additive, the modeling work above is a
~4–6 week effort spread across the new files. If the project stays on
the current nutshell trajectory, none of this work is needed and the
existing spec is the right artifact.
