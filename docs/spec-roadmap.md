# Spec Roadmap

The goal is a Crosslink Quint specification with roughly the same completeness
and review quality as the upstream Tendermint Quint specs.

## Baseline Crosslink

The baseline spec should model Crosslink without nil-precommit resampling.

Required pieces:

- Full Tenderlink height/round/step state machine, not only the current focused
  round-recovery fragment.
- Proposal values as PoW-stream snapshots, including `head - sigma` sampling.
- Proposal validity split into structural validity, PoW-chain validity,
  finality-candidate validity, and freshness against the locally observed
  stream.
- Tendermint lock and valid-value rules, including `validRound` handling across
  proposals.
- Baseline behavior when the PoW stream changes between prevote and precommit.
- Finality over a fork tree, including skipped PoW heights and rejection of
  finalizing a fork after an incompatible block is already final.
- Safety invariants for one-value-per-height BFT decisions and one-linearized
  finalized PoW prefix.
- Liveness witnesses that show the known baseline halt or wasted-round behavior
  under stream churn.

## Nil-Precommit Resampling Variant

The resampling spec should layer one explicit rule on top of the baseline:

```text
Only a 2f + 1 PRECOMMIT nil certificate for round r may clear lock/valid state
whose round is exactly r and let the next round resample the moving stream.
```

Required pieces:

- Same-round unlock and cache clearing on a nil-precommit quorum.
- Late nil-precommit certificates that clear abandoned-round state without
  rewinding a validator already in a later round.
- Preservation of older Tendermint locks.
- Explicit negative rule: a mixed precommit set is not unlock evidence unless
  nil itself has quorum.
- Accountability witnesses showing that conflicting commits require either an
  invalid unlock transition or slashable nil/value equivocation.
- Liveness witnesses where repeated stream changes burn rounds but do not
  permanently wedge the protocol once the stream is stable across the
  prevote/precommit window.

## Dynamic-Sigma Variant

The dynamic-sigma spec should be treated as a third Crosslink variant, not just
as parameter-analysis metadata. It layers nil-precommit resampling with a
consensus-visible sigma schedule:

```text
sigma(h) is fixed for BFT height h.
sigma(h + 1) is computed deterministically from committed telemetry for h.
```

Required pieces:

- A per-height sigma schedule included in consensus-visible state.
- A consensus-parameter envelope for the next height's
  `bc_confirmation_depth_sigma`, so the committed parameter bytes activate the
  deterministic controller output rather than a local node preference.
- No same-height or same-lock sigma changes.
- Deterministic updates from committed nil-round failure telemetry and a
  quorum-backed network coverage model.
- The percentage of PoW hash power participating in Crosslink as a separate
  committed telemetry input. Participation below the target should block sigma
  relaxation; participation below a critical floor should raise sigma directly
  because the sampled PoW stream is less representative of total block
  production.
- A classification boundary between sigma-relevant
  long-reorg/low-coverage/low-participation failures and ordinary same-branch
  block-arrival churn, since larger sigma does not mitigate normal head
  progression during the prevote/precommit window.
- Hysteresis: raise on repeated sigma-relevant failures, lower only after
  stable windows with adequate validator/network coverage and adequate
  Crosslink-participating hash power.
- Compatibility witnesses showing that nil-precommit resampling burns rounds
  while dynamic sigma only affects future BFT heights.
- A bridge from the dynamic sigma schedule into concrete `head - sigma(h)`
  proposal-stream sampling, so future BFT heights use updated sigma while the
  active height remains fixed.
- A bridge from that dynamic `head - sigma(h)` stream into the height-indexed
  round machine, so proposals, value precommits, and nil-round resampling use
  the active height's sigma while height transitions use the updated schedule.

## Tendermint-Quality Target

The upstream Tendermint Quint specs are useful because they are not just unit
tests. They provide:

- a small but faithful protocol transition system,
- clear assumptions about validator sets and fault thresholds,
- executable examples,
- invariants suitable for bounded model checking,
- accountability lemmas/witnesses, and
- readable documentation that ties the model back to the paper/protocol rules.

For Crosslink, matching that quality means adding:

- a single shared protocol core with baseline, fixed-sigma resampling, and
  dynamic-sigma variants,
- stronger message-domain modeling for proposals, prevotes, precommits, and
  decided/fat-pointer evidence,
- model-checkable safety invariants beyond scripted witness runs,
- temporal/liveness properties for eventual decision under post-GST stream
  stability,
- an implementation correspondence document for Zebra Crosslink/Tenderlink, and
- CI that runs typecheck, example tests, and bounded verification jobs.

## Near-Term Milestones

1. Split the current focused model into a shared core plus explicit
   `BaselineCrosslink`, `NilPrecommitResamplingCrosslink`, and dynamic-sigma
   variant modules.
2. Import the relevant structure from the upstream Tendermint Quint examples and
   map every Tendermint rule to a Crosslink-specific rule or deviation.
3. Add model-checkable invariants for decision uniqueness, lock safety, finality
   prefix linearity, and nil-certificate unlock safety.
4. Add bounded counterexample searches for mixed-precommit unlocks and stale
   proposal carries.
5. Add a liveness model parameterized by stream-stability windows.
6. Document the accountability model: what evidence proves a bad unlock, what
   evidence proves nil/value equivocation, and what cannot be inferred from a
   mixed precommit set.

## Progress Log

### 2026-05-18

- Milestone 1 has an initial implementation: `CrosslinkResampling.qnt` now has
  explicit `BaselineCrosslink` and `NilPrecommitResamplingCrosslink` modules
  over the shared `CrosslinkResampling` core.
- Milestone 2 has a first mapping document in
  `docs/tendermint-crosslink-map.md`.
- Milestone 3 has named safety obligations in the round-recovery model:
  `DecisionUniqueness`, `DecisionsHaveCommitQuorum`, `LockSafety`, and
  `NilCertificateUnlockSafety`, all included in `Safety`. CI now also runs
  bounded Apalache safety checks for baseline round recovery, nil-precommit
  resampling, fork finality, and the composed resampling/finality model.
- Baseline proposal validity is now split into structural validity,
  PoW-chain validity, finality-candidate validity, and stream freshness.
  `CrosslinkProposalValidityModel` checks that a fresh but structurally invalid
  proposal receives a nil prevote.
- Milestone 4 has an executable negative witness:
  `mixedPrecommitQuorumDoesNotUnlockTest`.
- Milestone 6 has a first accountability document in
  `docs/accountability.md`.
- Accountability now has a first explicit observer-bookkeeping slice:
  `evidencePrecommit` is separate from protocol `msgsPrecommit`, the
  `Observed*` quorum helpers drive conflicting-commit accountability, and
  `CrosslinkEvidenceBookkeepingModel` checks that evidence can be recorded
  without mutating protocol precommit state.
- Quorum checks now use `VotingPowerOf` over explicit validator voting power
  instead of raw signer counts. The default examples remain equal-weight, and
  `CrosslinkWeightedQuorumModel` checks that two high-power validators can form
  a quorum when their summed power reaches the threshold.
- `CrosslinkValidatorSetChange.qnt` adds the first dynamic validator-set
  slice: a BFT decision records the active signer set for that height and
  installs the decided next validator set for the following height. It rejects
  removed validators signing at the next height and signer sets without quorum.
- `CrosslinkHeightedValidatorEvidence.qnt` composes that validator-set rotation
  with heighted evidence. Observed precommits and fat pointers are authorized
  by the validator set active at the evidence height, so old-height evidence
  still uses the old set while next-height evidence uses the rotated set.
- `CrosslinkHeightedAuthenticatedEvidence.qnt` adds the first composed
  authenticated evidence pipeline. A heighted precommit must have canonical
  signed bytes before it can enter gossip or observer evidence, observation
  requires prior gossip, and fat pointers require quorum signer precommits plus
  authenticated fat-pointer signatures authorized by that height's validator
  set.
- `CrosslinkHeightedAuthenticatedGossipTransport.qnt` inserts a
  Crosslink-topic transport boundary before that pipeline. Precommit and
  fat-pointer-signature envelopes must have the expected topic, kind, canonical
  bytes, signature, BFT height, round, and active validator authorization before
  they can enter gossip or observer evidence. The witnesses cover accepted
  precommit/fat-pointer evidence, rotated validator sets, observation before
  transport, raw gossip without a transport envelope, wrong topic/kind/bytes,
  and cross-height replay.
- `CrosslinkSchedulerLiveness.qnt` adds a bounded fair-scheduler liveness
  slice for nil-precommit resampling. It still assumes a bounded post-GST
  window, but it no longer fixes a single validator ordering: unstable rounds
  can burn nil-precommit certificates and advance correct validators in
  nondeterministic order, then a stable round can deliver proposal, prevote,
  and precommit duties until a correct validator decides.
- `CrosslinkSchedulerProgressContract.qnt` adds the first explicit temporal
  liveness check for the scheduler envelope. It abstracts away the protocol
  state from `CrosslinkSchedulerLiveness.qnt`, keeps only progress transitions
  before decision, and TLC checks eventual entry into the stable decision
  phase over the complete finite state graph.
- `CrosslinkFinalityProgressContract.qnt` adds the next temporal handoff:
  once the scheduler contract reaches a stable decision, a fair finality
  applicator eventually advances the Crosslink finality cursor.
- `CrosslinkComposedProgressContract.qnt` adds a stronger self-contained
  temporal contract that combines nil-precommit-burned rounds, stable
  proposal/vote/precommit delivery, finality-candidate validation, fork-prefix
  safety, and eventual finality of the stable candidate.
- `CrosslinkStreamChurnRisk.qnt` adds a bounded integer-risk model for the
  validator-set-size intuition behind nil-precommit resampling. It relates
  linear/quadratic GST growth, the prevote-to-precommit vulnerability window,
  normal PoW head arrivals, sigma's long-reorg-tail mitigation, and the number
  of rounds resampling burns before a stable stream window appears.
- `CrosslinkPowStochasticAssumptions.qnt` turns the stochastic inputs to that
  risk model into an executable assumption profile. It pins Zebra's
  post-Blossom 75-second PoW target spacing, models prevote/precommit window
  growth as the one-block Poisson/union-bound arrival-risk numerator, and
  keeps the long-reorg tail as an explicit geometric-decay profile by sigma.
- `CrosslinkPowReorgStress.qnt` adds a concrete bounded fork-tree witness for
  that risk. A long reorg between prevote and precommit changes the sampled
  `head - sigma` candidate, and an ordinary same-branch block arrival can do
  the same; the resampling path burns those rounds and decides only after a
  stable head-sigma window.
- `CrosslinkDynamicSigma.qnt` adds the third Crosslink variant: dynamic sigma
  layered on nil-precommit resampling. It treats sigma as a per-BFT-height
  consensus schedule, keeps same-height nil-precommit round burns from changing
  sigma, updates sigma only at height boundaries from committed telemetry and a
  coverage model, includes Crosslink-participating PoW hash-power percentage as
  a separate input, refuses to treat same-branch head arrivals as
  sigma-relevant by themselves, and applies hysteresis so
  long-reorg/low-coverage/low-hash participation failures can raise sigma,
  critically low participation can raise sigma directly, and stable covered
  high-participation windows lower it slowly.
- `CrosslinkDynamicSigmaConsensusParams.qnt` adds the consensus-parameter
  boundary for the dynamic controller. It checks that committed per-height
  `bc_confirmation_depth_sigma` wires decode to the deterministic active sigma,
  activation height, and telemetry source height, that nil-precommit round
  burns cannot rewrite params, and that malformed, stale, or out-of-range
  next-height sigma wires are rejected.
- `CrosslinkDynamicSigmaConsensusParamFormat.qnt` pins a compact
  production-shaped byte envelope for those wires: one-byte key tag, u32
  activation height, u32 telemetry source height, and u16 sigma. It routes
  accepted bytes through the abstract consensus-param model, pins exact
  little-endian hex vectors, and rejects wrong-key, stale-activation,
  trailing-byte, and out-of-range-sigma envelopes.
- `CrosslinkDynamicSigmaConsensusParamTransport.qnt` adds the authenticated
  gossip/config-application boundary for those params. It requires quorum-signed
  canonical production param bytes on the Crosslink consensus topic before node
  config follows a committed next-height sigma after format decoding. The
  signed payload is `ProductionConsensusParamWireHex(wire)`, so transport bytes
  are bound directly to the format vectors, while rejecting wrong-topic,
  wrong-kind, wrong-byte, wrong-signature, malformed production envelopes,
  no-quorum, quorum-signed stale activation, and nondeterministic sigma updates.
- `CrosslinkDynamicSigmaHeadSampling.qnt` connects that controller to concrete
  proposal-stream sampling. It imports the dynamic-sigma schedule, samples
  `head - sigma(h)` for the active BFT height, checks that nil-precommit round
  burns preserve same-height sigma and already sampled candidates, and shows
  that telemetry-raised sigma samples a deeper candidate at the next height
  while later stable high-participation telemetry can sample shallower again.
  A low Crosslink-participating hash-power witness prevents that relaxation
  and keeps the future proposal stream at the deeper sampled candidate.
- `CrosslinkDynamicSigmaHeightedRound.qnt` carries the dynamic-sigma schedule
  into the height-indexed Tenderlink round machine. It constrains `Stream(h,r)`
  to `head - sigma(h)`, checks that correct fresh proposals and value
  precommits carry the active height's dynamic candidate, preserves sigma
  across same-height nil-precommit resampling, and shows a decided height-1
  block leading to a height-2 proposal that uses telemetry-raised sigma.
- `CrosslinkDynamicSigmaHeightedFinality.qnt` composes that dynamic stream with
  Crosslink finality. It requires finalized BFT heights to come from local
  heighted decisions, to match the active height's dynamic `head - sigma(h)`
  candidate, and to satisfy the decided height's dynamic sigma tail before the
  finality cursor advances.
- `CrosslinkDynamicSigmaHeightedAuthenticatedEvidence.qnt` carries the dynamic
  candidate rule into the heighted authenticated-evidence pipeline. It keeps
  canonical signature, gossip-before-observe, and validator authorization
  checks, while requiring signed value precommits and fat pointers to name the
  active height/round's `head - sigma(h)` candidate.
- `CrosslinkDynamicSigmaAuthenticatedFinality.qnt` gates dynamic finality on
  observer-local authenticated evidence. The finality cursor advances only after
  authenticated precommit evidence and authenticated fat-pointer signatures
  support the same dynamic height, round, and candidate.
- `CrosslinkHeadSigmaSampling.qnt` makes the source of `Stream(round)`
  explicit. It samples the `head - sigma` ancestor of each locally observed
  PoW head and checks same-branch progress, fork-switch churn, stable-head
  windows, and tail-confirmed candidate validity.
- `CrosslinkHeightedHeadSigmaRound.qnt` connects that concrete `head - sigma`
  stream back into the height-indexed round machine. Fresh correct proposals
  must carry the current fork-tree-derived candidate, value precommits must
  target that current candidate, and a nil-precommit certificate clears the
  cached round-0 candidate so the next round can resample the new head-sigma
  value.
- `CrosslinkBftBlockShape.qnt` adds the first implementation-shaped proposal
  payload model. It captures the fact that Zebra's `FindBlockHeaders` response
  starts after the known candidate hash, so a locally produced proposal can
  carry exactly sigma descendant headers while the finality candidate remains
  the declared `head - sigma` ancestor. It also models the stateless validation
  guards documented on `BftBlock::try_from`: expected version, sigma header
  count, consecutive header order, and valid PoW solutions.
- `CrosslinkBftBlockValidationGap.qnt` makes the current implementation
  correspondence gap executable: the intended constructor boundary rejects bad
  version, header-order, and PoW-solution inputs, while the current prototype
  `BftBlock::try_from` only rejects an incorrect sigma header count. The
  shape model also records that deserialization has only a 2048-header
  envelope cap and bypasses `try_from`.
- `CrosslinkBftBlockProductionVectors.qnt` pins the production BFT-block wire
  prefix from `BftBlock::zcash_serialize`: u32 version, u32 BFT height,
  counted previous-block fat pointer, u32 finalization-candidate height, u32
  header count, and contiguous serialized PoW headers. The witnesses also pin
  the generated `fixtures/production-bft-block-vectors.json` manifest for the
  checked-in `test_pos_block_*.bin` envelopes: the first fixture has a
  zero-signature previous fat pointer, later fixtures have one previous
  signature, all current fixtures carry three version-4 PoW headers, and all
  include one trailing fat-pointer signature. The manifest also pins
  previous/trailing fat-pointer count bytes and first signer-entry byte probes.
  A generated Quint module imports those constants into the production-vector
  specs, and the generated artifacts pin the full payload, pubkey, vote
  signature, and `pubkey || payload` sign-data hex strings. The manifest
  validator verifies those Ed25519 signatures with Node crypto. The model
  still records the deserialization sigma-bypass gap.
- `CrosslinkFatPointerFormat.qnt` adds the first production-shaped fat-pointer
  signer-vector model. It captures the 44-byte vote payload suffix,
  little-endian u16 count, and 96-byte pubkey/signature entries; rejects
  truncated or trailing-byte wire envelopes, wrong byte offsets, and duplicate
  pubkeys that could inflate quorum power; scopes signer authorization to the
  evidence BFT height; checks canonical signed bytes before a fat pointer can
  be accepted; and models derivation from producer round data so missing
  signatures, nil precommit signers, and wrong-height fat pointers are
  rejected.
- `CrosslinkFatPointerProductionVectors.qnt` pins implementation-linked
  fat-pointer byte vectors: count bytes 44..46, exact wire lengths for 0-4
  signatures, contiguous 96-byte entry offsets, streaming
  serializer/deserializer agreement, and the current prototype
  `try_from_bytes` reversed-count-slice gap. It now also imports generated
  `test_pos_block_*.bin` previous and trailing fat-pointer offsets, signer
  entry offsets, count bytes, and byte probes.
- `CrosslinkFatPointerAuthenticatedEvidence.qnt` connects that
  production-shaped signer vector to the authenticated observer pipeline. A
  production fat-pointer wire can only be observed after its counted envelope
  is exact and every active signer entry is backed by a matching gossiped
  precommit at the same BFT height, round, and value; the witnesses reject
  observation before gossip, missing signer precommits, trailing-byte wires,
  duplicate signer entries, and removed-validator next-height precommits.
- `CrosslinkFixtureAuthenticatedEvidence.qnt` bridges generated checked-in
  fixture constants into that authenticated observer pipeline. The
  one-signature fixture wire is accepted only after its matching abstract
  precommit is gossiped, and is rejected before gossip. The generated artifacts
  also carry the real fixture byte strings for later crypto verification.
- `CrosslinkFixtureGossipTransport.qnt` inserts a fixture-level transport
  boundary before that observer path. The generated fixture precommit and
  fat-pointer wire must be gossiped in canonical Crosslink-topic envelopes
  before the observer accepts the wire, and witnesses reject wrong-topic,
  wrong-sign-bytes, wrong-kind, and wrong-wire-length envelopes.
- `CrosslinkHeightedAuthenticatedGossipTransport.qnt` adds the corresponding
  non-fixture transport bridge for heighted authenticated evidence. It keeps
  bytes compact but prevents authenticated precommits or fat-pointer signatures
  from appearing in gossip or observer evidence unless a matching Crosslink-topic
  transport envelope was previously accepted.
- Message-domain evidence now covers proposals, prevotes, precommits, and
  decided/fat-pointer certificates. `MessageEvidenceSoundness` checks that
  protocol messages are mirrored into observer evidence and that fat pointers
  have authorized signer sets with observed precommit quorum power.
- `CrosslinkEvidenceGossip.qnt` adds an explicit gossip/observer-process
  model: observers can only accept gossiped consensus messages, observed
  precommit quorums require corresponding gossip quorums, and observed fat
  pointers must be locally justified by already-observed signer precommits.
- `CrosslinkHeightedEvidenceGossip.qnt` adds the same observer-process shape
  for height-indexed evidence. Observed precommit quorums and fat pointers are
  justified only by gossip and signer precommit evidence at the same BFT
  height, including a cross-height fat-pointer rejection witness.
- `CrosslinkMessageAuth.qnt` adds a first canonical payload/signature boundary:
  proposals, prevotes, precommits, and fat-pointer signatures are only accepted
  when the bytes match the claimed message and the signature verifies for the
  claimed validator.
- `CrosslinkHeightedMessageAuth.qnt` adds the same boundary for height-indexed
  messages. Canonical proposal, vote, and fat-pointer bytes bind the claimed
  BFT height, preventing cross-height replay at the model boundary.
- The model now has a first local-delivery slice: `seenPropose`,
  `seenPrevote`, and `seenPrecommit` track receiver-local messages,
  `DeliverProposal`/`DeliverPrevote`/`DeliverPrecommit` refuse messages that
  were not broadcast, and `CrosslinkLocalDeliveryModel` shows that local quorum
  evidence only appears after delivery.
- The main round machine now uses local receive guards for proposal prevote,
  value precommit, precommit-quorum round advancement, late nil-certificate
  recovery, and decision. Global quorum predicates remain as broadcast-level
  evidence helpers for invariants and witnesses.
- The round model now includes initial Tenderlink timeout transitions:
  propose timeout broadcasts a nil prevote, prevote timeout broadcasts a nil
  precommit, and precommit timeout advances the round without clearing
  lock/valid/cache state unless a nil-precommit certificate exists.
- The heighted round model now distinguishes a cached proposal from a real
  Tendermint `validValue`/`validRound` lock. After a timeout-only round advance
  with no value lock, the next fresh proposal resamples the current
  `head - sigma` stream; older value locks remain preserved across timeout and
  mixed-precommit paths.
- Valid-round handling now has a first Tendermint-style rule: a proposal with a
  non-`-1` `validRound` must be justified by a prevote quorum for that value in
  the referenced round, `CorrectProposalValidRoundSound` makes this a safety
  obligation for correct proposal messages, and an older lock only votes across
  values when that evidence is present. `CrosslinkValidRoundModel` covers
  unjustified rejection, justified unlock, and correct-proposer rejection for
  unjustified valid-round state.
- The implementation-correspondence track has a first document in
  `docs/implementation-correspondence.md`.
- `npm run verify:extended` adds a non-default deeper bounded-check gate for
  the newest finality-progress, composed-progress, stream-churn-risk,
  PoW stochastic-assumption, PoW-reorg-stress, dynamic-sigma,
  dynamic-sigma consensus-params, dynamic-sigma consensus-param-format,
  dynamic-sigma consensus-param-transport, dynamic-sigma head-sampling,
  dynamic-sigma heighted-round,
  dynamic-sigma heighted-finality,
  dynamic-sigma heighted-authenticated-evidence,
  dynamic-sigma authenticated-finality, head-sigma, BFT-block-shape,
  BFT-block validation-gap, BFT-block production-vector, fat-pointer-format,
  fat-pointer production-vector, heighted validator-evidence, heighted
  authenticated-evidence, and heighted authenticated gossip transport models.
  It keeps default CI at bounded depth while
  giving reviewers depth-5 Apalache checks, plus a depth-8 PoW-reorg stress
  check, for the models most likely to hide cross-component state-space
  mistakes.

- Milestone 5 has an initial stream-stability witness:
  `NilPrecommitResamplingStableWindowLiveness` shows two stream-change aborts
  followed by a stable window where resampling reaches a decision. This still
  needs to become a general temporal liveness property rather than a scripted
  executable trace.
- `CrosslinkSchedulerLivenessModel` strengthens that liveness track with a
  bounded fair-scheduler model and a `SchedulerSafety` invariant. It remains a
  bounded scheduler-parametric check, not a full temporal proof.
- `CrosslinkSchedulerProgressContractModel` now supplies a TLC-checked temporal
  contract for that scheduler envelope. It is not yet a full composed protocol
  liveness proof, because current temporal backends have trouble with the full
  imported round-machine state.
- `CrosslinkFinalityProgressContractModel` extends the same TLC-friendly
  envelope from stable decision to finality cursor advancement.
- `CrosslinkComposedProgressContractModel` adds a self-contained composed
  nil-resampling/finality temporal check. It verifies that after finitely many
  nil-precommit-burned rounds, a stable stream window can decide and eventually
  finalize a valid `head - sigma` candidate while preserving a linear finalized
  PoW prefix and rejecting the competing fork candidate.
- `CrosslinkComposedLivenessModel` now has an executable end-to-end liveness
  script that includes explicit local delivery of the proposal, prevotes, and
  precommits before finalizing the fresh candidate.
- `CrosslinkHeadSigmaSamplingModel` closes the first part of the
  `head - sigma` sampling gap by replacing arbitrary stream values with a
  concrete fork-tree-derived stream witness. This is deliberately
  nondeterministic/adversarial rather than probabilistic: it checks bounded
  fork switches and stable-head windows, but it does not yet quantify PoW
  block-arrival rates, propagation races, or long-tail reorg probabilities.
- `CrosslinkStreamChurnRiskModel` now adds the first parameterized bridge from
  those adversarial stream changes to liveness risk: validator count increases
  the vulnerable window through GST, global distribution can add quadratic
  delay, sigma lowers only long-reorg-tail exposure, and resampling converts a
  finite number of churn windows into round increments before decision.
- `CrosslinkPowStochasticAssumptionsModel` adds the first executable
  calibration profile for that bridge. It uses Zebra's post-Blossom target
  spacing as the denominator for normal PoW-arrival exposure, checks that
  global validator distribution raises the vulnerable window, and isolates
  sigma's effect to an explicit long-reorg-tail numerator table.
- `CrosslinkPowReorgStressModel` adds the corresponding concrete fork-tree
  stress trace: a long reorg and a same-branch PoW block arrival both burn
  nil-precommit rounds before a stable head-sigma window decides.
- `CrosslinkDynamicSigmaModel` lifts the sigma-controller idea into the
  variant set. The model checks that the dynamic controller is distinct from
  baseline and fixed-sigma resampling, that nil-precommit round burns do not
  rewrite same-height sigma, that long-reorg or ambiguous low-coverage
  telemetry can raise future-height sigma, that same-branch failures do not
  raise sigma by themselves, that low Crosslink-participating hash power
  prevents sigma relaxation, that critically low participation raises sigma
  directly, and that stable covered high-participation windows lower sigma at
  most one step.
- `CrosslinkDynamicSigmaHeadSamplingModel` composes that controller with
  `head - sigma(h)` sampling. It verifies that height 0 samples with the
  initial sigma, a nil-round burn leaves that sample and same-height sigma
  untouched, long-reorg telemetry raises future sigma and samples a deeper
  candidate, and stable high-participation telemetry lowers future sigma and
  samples a shallower candidate. It also checks that low Crosslink-participating
  hash power prevents future sigma relaxation and preserves the deeper
  `head - sigma(h)` sample.
- `CrosslinkDynamicSigmaHeightedRoundModel` composes the controller with the
  heighted round machine. It verifies that a fresh height-1 proposal uses the
  initial sigma, a nil-precommit certificate advances the round without
  changing height-1 sigma, and a height-2 proposal after a local decision uses
  the telemetry-raised `head - sigma(h)` candidate.
- `CrosslinkDynamicSigmaHeightedFinalityModel` composes dynamic-sigma heighted
  rounds with finality. It verifies nil-resampling followed by dynamic
  finality, a telemetry-raised height-2 finality candidate with sigma 2, and
  rejection of a height-2 finality witness that would only satisfy the older
  fixed-sigma depth.
- `CrosslinkDynamicSigmaConsensusParamsModel` wraps the dynamic-sigma
  controller with consensus-parameter bytes. It verifies canonical initial
  params, nil-round param stability, raised and lowered sigma param commits,
  a low-participation sigma raise, and rejection of malformed keys, stale
  activation heights, or out-of-range sigma values.
- `CrosslinkDynamicSigmaConsensusParamFormatModel` adds a production-shaped byte
  layout for those params. It verifies fixed field offsets, exact envelope
  length, exact little-endian hex vectors, raised/lowered/low-participation
  sigma commits through production bytes, nil-round byte stability, and
  rejection of wrong-key, stale, trailing-byte, and out-of-range envelopes.
- `CrosslinkDynamicSigmaConsensusParamTransportModel` adds a signed gossip and
  node-config application boundary over the production byte format. It verifies
  quorum-gossiped low-participation sigma raises, recovered-participation
  lowering, nil-round config stability, exact production-wire config storage
  beside decoded consensus params, signatures over the format model's exact hex
  bytes, and rejection of wrong-topic, wrong-kind, wrong-byte, wrong-signature,
  malformed production envelopes, no-quorum, quorum-signed stale activation,
  and nondeterministic-sigma updates.
- `CrosslinkDynamicSigmaHeightedAuthenticatedEvidenceModel` composes the
  dynamic-sigma candidate boundary with the heighted authenticated-evidence
  pipeline. It verifies accepted height-1 and telemetry-raised height-2
  precommit/fat-pointer evidence for the dynamic candidate, and rejects
  authenticated evidence whose value would match the wrong sigma sample.
- `CrosslinkDynamicSigmaAuthenticatedFinalityModel` composes dynamic-sigma
  finality with authenticated fat-pointer evidence. It verifies that the
  finality cursor only advances when observer-local authenticated precommit
  evidence and authenticated fat-pointer signatures support the same dynamic
  height/round/candidate.
- The first multi-height finality model is in `CrosslinkMultiHeight.qnt`.
  It makes BFT decision heights sequential, permits a decision to skip PoW
  heights on the same branch, rejects skipped or duplicate BFT-height
  decisions, and keeps the finalized PoW prefix linear across BFT heights.
- `CrosslinkHeightedRound.qnt` adds the first height-indexed
  receive-reactive round-machine slice. Each validator has a sequential BFT
  height cursor, per-height round/step/lock/valid/cache state, per-height
  valid-round/POL evidence, local delivery, timeout transitions, and
  per-height decisions. It checks that nil-precommit resampling clears only
  the same height and same round, that mixed precommit quorums do not unlock
  heighted lock state, that precommit timeout does not unlock heighted lock
  state, that unjustified heighted `validRound` proposals prevote nil, and
  that a validator cannot decide height `h + 1` before height `h`.
- `CrosslinkHeightedFinality.qnt` composes that height-indexed round machine
  with a finality cursor. A BFT height only advances finality after a local
  heighted decision, and the decided snapshot must extend the finalized PoW
  prefix. The witnesses cover nil-precommit resampling followed by finality,
  rejection of undecided-height finality, and rejection of a later fork after
  an earlier BFT height is final.
- The remaining multi-height work is to connect the heighted auth, evidence,
  validator-set, BFT-block-shape, fat-pointer-format, and production-shaped
  fat-pointer observer models to more concrete serialization vectors, real
  signatures, header validity checks, and full production gossip transport.
  The fixture-gossip bridge now covers the checked-in fixture transport boundary,
  the heighted authenticated gossip transport bridge covers the abstract
  precommit/fat-pointer-signature transport envelope boundary, and the
  dynamic-sigma consensus-param/format/transport/heighted-round/
  finality/authenticated evidence bridges cover production-shaped parameter
  bytes, quorum-signed production-byte gossip, node-config application,
  proposals, precommits, fat-pointer evidence, and finality over
  `head - sigma(h)`, but not the broader production message
  transport or real implementation vectors for dynamic-sigma consensus params.
  The remaining work is also to lift the current TLC-friendly progress contracts
  into a full imported-protocol
  temporal proof. A direct TLC run over the current imported composed model is
  blocked by the map-heavy round-machine state in the Quint-to-TLA/TLC path, so
  this likely needs either a TLC-oriented imported-state refactor or improved
  backend support.
  The current stream-churn and PoW-reorg stress models now have an executable
  analytic assumption profile, but the arrival, propagation-race, GST-scaling,
  and long-reorg numerators still need to be calibrated against measured
  distributions.
