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

### 2026-05-19

- `CrosslinkTenderlinkVoteSignBytes.qnt` pins the concrete vote sign-byte
  boundary shared by `make_vote_sign_datas` and `MalVote::to_bytes`: 32-byte
  validator pubkey, 32-byte value id or all-zero nil value, little-endian BFT
  height, and little-endian round with the precommit high bit. It also checks
  that value precommit bytes expose the same 44-byte value/height/round-type
  suffix used by fat pointers after removing the signer pubkey.
- The new witnesses cover nil prevote, value prevote, nil precommit, and value
  precommit exact hex vectors, plus rejection of trailing bytes, wrong
  precommit flags, and cross-height replay bytes. This narrows the remaining
  concrete-message gap to full-sized Tenderlink packet fixtures and production
  gossip integration.
- `CrosslinkTenderlinkProposalChunkSignBytes.qnt` pins the legacy Tenderlink
  proposal chunk signing bytes: 56-byte little-endian header plus chunk data.
  The header witness covers chunk index, proposal size, round, valid round,
  BFT height, proposal id, `valid_round = -1` as `u32::MAX`, and rejection of
  future valid rounds, trailing bytes, cross-height replay bytes, and chunk
  ranges past the declared proposal size. The Malachite protobuf proposal
  vectors are tracked separately in the dedicated proposal protobuf slice.
- `CrosslinkTenderlinkVotePacketFormat.qnt` pins the legacy `PacketVotes`
  batch format: nil/yes counts, round, height, value id, and
  roster-index/signature entries. It records the struct padding gap separately
  from the variable-length `write_to` bytes and checks that nil prevote,
  value prevote, and value precommit packet entries reconstruct the canonical
  76-byte vote sign payload before signature verification, including a
  two-signature weighted POL packet and a three-signature value-prevote POL
  packet for the smallest f = 1 quorum, plus a five-entry larger-validator-set
  POL packet.
- `CrosslinkTenderlinkProposalPolEvidence.qnt` bridges the valid-round rule to
  those production-shaped bytes: a proposal chunk with a non-`-1` valid round
  is accepted only when paired with a canonical prevote packet for the same
  height, valid round, and value id. The bounded fixture derives certified
  voting power from canonical packet entries, accepts a weighted two-signature
  quorum, rejects forged certified-power sidecars, and still checks the
  three-signature f = 1 quorum. It now also accepts a five-entry larger
  validator-set POL packet against a higher quorum threshold.
- `CrosslinkTenderlinkProposalPolTransport.qnt` adds the transport bridge for
  that rule: the non-nil proposal chunk and the weighted, f = 1, or larger-validator-set POL prevote
  packet must first be received as decrypted, exact compact Tenderlink
  consensus packets before the decoded POL evidence can be accepted. The bridge
  reuses the consensus-packet fixture constants for the proposal and
  112/178/244/376-byte POL prevote envelopes. Witnesses reject missing proposal
  transport, missing POL transport, low-power POL, wrong proposal packet type,
  wrong POL payload, and wrong packet bytes.
- `CrosslinkTenderlinkConsensusPacketFormat.qnt` pins the compact Tenderlink
  consensus packet envelopes around those payloads: a 16-byte little-endian
  `PacketHeader` tag/ack prefix, including a nonzero
  `ack_latest`/`ack_field` vector, complete proposal chunk packet bytes with
  the proposer signature outside the signed payload, and complete
  prevote/precommit vote batch packet bytes. It now records the variable-length
  vote-batch envelope sizes used by POL evidence: 112-byte one-signature,
  178-byte weighted two-signature, 244-byte three-signature, and 376-byte
  five-entry larger-validator-set payloads. The witnesses also reject
  status-flag compact consensus packets, wrong packet types, malformed ack/tag
  fields, missing proposal signatures, and trailing vote bytes.
- `CrosslinkTenderlinkAccountabilityEvidenceFormat.qnt` pins concrete
  slashing-evidence envelopes for the nil-precommit accountability story and
  ordinary Tendermint equivocation: nil/value and value/value precommit
  equivocation by one validator at the same height and round, encoded as a
  51-byte typed header plus two canonical `PacketVotes` payloads. Witnesses
  reject prevote evidence, wrong height/round, wrong length, same-value
  packets, wrong-signer claims, and wrong envelope bytes.
- `CrosslinkTenderlinkAccountabilityEvidenceTransport.qnt` adds the matching
  Crosslink-topic transport boundary for those envelopes. Transported
  accountability evidence cannot be accepted unless an `accountability-evidence`
  envelope first carries exact canonical evidence bytes and matching
  height/round/signer metadata; witnesses reject missing transport, wrong
  topic/kind/length/height/signer/bytes, and non-canonical evidence.
- `CrosslinkTenderlinkAccountabilityObserver.qnt` adds the observer-side bridge
  after that transport boundary. It records abstract precommit-equivocation
  facts only after the exact canonical evidence has been accepted through
  transport, with witnesses for nil/value, value/value, receive-without-accept,
  and non-canonical evidence.
- `CrosslinkTenderlinkAccountabilityObserverBridge.qnt` connects those
  production-shaped observer facts back into `CrosslinkResampling`'s abstract
  `evidencePrecommit` state. The bridge checks value/value evidence reaches the
  same-round equivocation predicate, while nil/value evidence remains
  signer-level until independent nil-certificate and value-quorum context is
  present.
- `CrosslinkTenderlinkAccountabilityObserverBridgeSafety.qnt` is the direct
  Apalache safety projection for that bridge, mirroring the same nil/value and
  value/value accountability obligations without the executable composition's
  alias-heavy import graph.
- `CrosslinkTenderlinkUnlockAccountabilityBoundary.qnt` records the bad-unlock
  accountability boundary around cross-round value switches. The witnesses show
  that a missing nil certificate is an abstract accountability signal, a later
  nil certificate cancels that signal, mixed precommits do not cancel it, and
  absence-based standalone slashing evidence would be unsafe.
- `CrosslinkTenderlinkNonceAckTransport.qnt` adds the known-peer transport
  replay boundary around compact consensus packets. It pins little-endian outer
  nonce prefixes, requires successful abstract Noise decryption before the
  decrypted bytes can be treated as a canonical consensus packet, mirrors
  `nonce_is_ok`'s current/latest, 64-packet ack-window, and 512-packet
  forward-jump checks, and models `nonce_update`-style ack tracking. The
  witnesses include the existing implementation nonce examples, replay
  rejection, current-ack rejection, tolerance-boundary acceptance,
  beyond-tolerance rejection, failed-decrypt rejection, bad nonce-prefix
  rejection, and bad decrypted consensus-packet rejection.
- `CrosslinkTenderlinkStatusPacketFormat.qnt` pins the inline status request
  format read after a status-flagged compact `PacketHeader`. It records the
  28-byte `PacketStatus` body layout for height, round, one proposal chunk
  range, one prevote range, and one precommit range, plus exact status-only and
  acked-status hex vectors. The witnesses reject missing status flags,
  reversed proposal ranges, vote request ranges past the roster, malformed
  ack/tag fields, and truncated status packets.
- `CrosslinkMalachiteProposalProtobufFormat.qnt` adds the first Malachite
  protobuf proposal vectors. It pins exact proto3 bytes for `Value`,
  `Proposal` with and without `pol_round`, `SignedMessage::Proposal`, and
  streamed proposal parts, including field tags, length prefixes, the omitted
  nil POL round, 32-byte validator/proposer keys, and 64-byte signatures. The
  rejection witnesses cover missing values, nil proposal rounds, short
  validator/proposer keys, wrong signed-message oneof tags, and missing
  signatures.
- `CrosslinkMalachiteProposalGossipTransport.qnt` adds a transport-envelope
  bridge for those exact proposal protobuf bytes. It requires a Crosslink
  proposal topic, raw/signed/streamed envelope kinds, and byte equality with
  the canonical protobuf payload before accepting proposal messages; witnesses
  reject raw signed/streamed decoder acceptance, wrong topics/kinds, wrong
  bytes, wrong oneof tags, and short streamed proposers.
- `CrosslinkMalachiteLivenessProtobufFormat.qnt` pins the first Malachite
  liveness protobuf certificate vectors: a polka certificate, a skip-round nil
  certificate, and a value precommit certificate under their `LivenessMessage`
  oneof wrappers. The witnesses cover enum default omission for precommit
  certificates, non-default skip/vote-type encoding, omitted nil value ids,
  included value ids, required validator/signature lengths, and wrong-oneof
  rejection.
- `CrosslinkMalachiteLivenessGossipTransport.qnt` adds a transport-envelope
  bridge for those exact liveness protobuf bytes. It requires a Crosslink
  liveness topic, polka/round envelope kinds, and byte equality with the
  canonical protobuf payload before accepting liveness messages; witnesses
  reject raw decoder acceptance, wrong topics/kinds, wrong bytes, wrong oneof
  tags, missing polka values, precommit-nil round certificates, and skip-value
  round certificates.
- `CrosslinkMalachiteSyncProtobufFormat.qnt` pins the first Malachite sync
  protobuf vectors: `ValueRequest`/`SyncRequest`, `CommitCertificate`,
  `SyncedValue`, and `ValueResponse`/`SyncResponse` with and without an
  attached value. The witnesses include no-value response handling, the same
  raw bytes accepted in request versus response context, and rejection of bad
  heights, wrong oneof tags, missing value ids/certificates, and short signer
  addresses.
- `CrosslinkMalachiteSyncGossipTransport.qnt` adds a transport-envelope bridge
  for those exact sync protobuf bytes. It requires a Crosslink sync topic,
  request/response envelope kinds, and byte equality with the canonical
  protobuf payload before accepting a sync message; witnesses reject raw
  decoder acceptance, wrong topics/kinds, wrong bytes, missing certificates,
  and preserve request/response kind separation for the shared no-value bytes.
- `CrosslinkMalachiteGossipRouter.qnt` composes the Malachite proposal,
  liveness, and sync transport machines behind one shared gossip router. It
  records routed messages per channel, checks that proposal/liveness/sync
  topics and channels stay disjoint, preserves each underlying transport
  safety invariant, and includes wrong-channel/wrong-topic/wrong-kind witnesses.
- `CrosslinkMalachiteGossipRouterSafety.qnt` keeps the same router namespace
  contract in a verifier-friendly direct state machine, so Apalache can check
  the channel/topic/kind invariant without flattening alias-imported transport
  modules.

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
- Accountability also separates signer-level equivocation facts from the
  quorum/certificate context used to explain conflicting commits.
  Value/value same-round equivocation by one correct signer directly witnesses
  `CorrectSameRoundEquivocationEvidence`, while nil/value signer evidence is
  only promoted to `CorrectNilValueEquivocationEvidence` when the round also
  has an observed nil certificate and conflicting value quorum.
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
- `CrosslinkDeliveryFairnessContract.qnt` adds a TLC-sized local-delivery
  fairness envelope. It keeps proposal, prevote, and precommit broadcast
  separate from receiver-local delivery, checks that broadcast alone cannot
  create local quorum evidence, and checks that fair post-GST delivery
  eventually gives a correct decider a local precommit quorum.
- `CrosslinkFinalityProgressContract.qnt` adds the next temporal handoff:
  once the scheduler contract reaches a stable decision, a fair finality
  applicator eventually advances the Crosslink finality cursor.
- `CrosslinkComposedProgressContract.qnt` adds a stronger self-contained
  temporal contract that combines nil-precommit-burned rounds, stable
  proposal/vote/precommit delivery, finality-candidate validation, fork-prefix
  safety, and eventual finality of the stable candidate.
- `CrosslinkBftHeights.qnt` adds a compact scheduled BFT-height finality
  harness. It checks that consecutive consensus-height decisions can advance
  the Crosslink finality cursor, while skipped BFT heights and fork decisions
  after a finalized prefix are rejected.
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
- `CrosslinkPowForkSchedule.qnt` derives rollback depth from a bounded
  sequence of PoW best-tip changes. It makes the fork-switch signal explicit
  before it is consumed by stress or dynamic-sigma models.
- `CrosslinkPowBranchCompetition.qnt` backs those best-tip changes with a
  generated branch-competition fixture. Published tips compete by honest plus
  adversarial work, hidden adversarial work cannot win until it is published,
  and the selected best tip determines the rollback-depth signal.
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
- `CrosslinkDynamicSigmaCalibration.qnt` adds a bounded measured-window
  calibration harness for the controller. Hash participation, round-failure
  rate, block-interval variance, and observed reorg depth are weighted into a
  risk score and checked against expected sigma-floor labels.
- `CrosslinkDynamicSigmaTelemetry.qnt` gives that committed telemetry a
  production-shaped calibration contract. It derives participation from
  Crosslink-participating work over total observed PoW work, requires coverage
  and round-failure estimates to conservatively upper-bound raw samples, checks
  monotone rollback-risk estimates across the sigma ladder, and forces the
  selected sigma to satisfy rollback-risk and expected-loss budgets whenever
  the bounded ladder can satisfy them.
- `CrosslinkDynamicSigmaForkSchedule.qnt` composes the dynamic controller with
  the derived PoW fork schedule, replacing a supplied observed-reorg map with
  rollback depth computed from best-tip transitions.
- `CrosslinkDynamicSigmaBranchCompetition.qnt` feeds generated published-tip
  work competition into the same dynamic controller, including the adversarial
  branch-release witness that raises sigma from a derived rollback signal.
- `CrosslinkDynamicSigmaResampling.qnt` composes the derived fork signal with
  nil-precommit resampling. It checks that sigma can rise before validators
  advance the abandoned Tenderlink round and that the resampling path can still
  decide the fresh stream value.
- `CrosslinkDynamicSigmaFinality.qnt` composes dynamic sigma, nil-precommit
  resampling, generated branch competition, and Crosslink finality. It uses
  the live dynamic sigma as the finality tail-confirmation depth and checks
  that low participation or fork-derived sigma increases can delay finality.
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
  the generated `fixtures/production-bft-block-vectors.json` manifest for both
  checked-in fixture classes. For `test_pos_block_*.bin` envelopes, the first
  fixture has a zero-signature previous fat pointer, later fixtures have one
  previous signature, all current fixtures carry three version-4 PoW headers,
  and all include one trailing fat-pointer signature. For raw
  `test_pow_block_*.bin` blocks, the manifest pins the 24 current samples
  across heights 0..29, their version-4 serialized header length, body length
  split, and header/body byte probes. The generator also records which raw PoW
  fixture headers byte-match the headers embedded in each BFT envelope, so the
  production-vector invariant checks that the BFT header vectors are backed by
  checked-in raw blocks. The manifest also pins previous/trailing fat-pointer
  count bytes and first signer-entry byte probes. A generated Quint module
  imports those constants into the production-vector specs, and the generated
  artifacts pin the full payload, pubkey, vote signature, and
  `pubkey || payload` sign-data hex strings. The manifest validator verifies
  those Ed25519 signatures with Node crypto. The model still records the
  deserialization sigma-bypass gap.
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
- `CrosslinkHeightedMessageGossipTransport.qnt` adds the transport side of that
  boundary. Proposals, prevotes, precommits, and fat-pointer signatures must
  arrive in Crosslink-topic envelopes with the expected kind before the heighted
  authentication model accepts them; witnesses reject raw acceptance without a
  transport envelope, wrong topic/kind, extra valid-round sidecars on votes,
  forged signatures, wrong bytes, and cross-height replay.
- The model now has a first local-delivery slice: `seenPropose`,
  `seenPrevote`, and `seenPrecommit` track receiver-local messages,
  `DeliverProposal`/`DeliverPrevote`/`DeliverPrecommit` refuse messages that
  were not broadcast, and `CrosslinkLocalDeliveryModel` shows that local quorum
  evidence only appears after delivery.
- `CrosslinkDeliveryFairnessContractModel` adds the TLC-friendly fairness
  envelope around that local-delivery split: broadcasted messages do not count
  as local quorum evidence until delivered, precommit broadcast requires the
  signer to have a receiver-local prevote quorum, and weak fairness over the
  finite delivery schedule eventually gives the decider a local precommit
  quorum.
- The main round machine now uses local receive guards for proposal prevote,
  value precommit, precommit-quorum round advancement, late nil-certificate
  recovery, and decision. Global quorum predicates remain as broadcast-level
  evidence helpers for invariants and witnesses.
- The round model now includes initial Tenderlink timeout transitions:
  propose timeout broadcasts a nil prevote, prevote timeout broadcasts a nil
  precommit, and precommit timeout advances the round without clearing
  lock/valid/cache state unless a nil-precommit certificate exists.
- `CrosslinkTimeoutProgressContractModel` adds the first temporal timeout
  recovery contract over that behavior: timeout-only advancement preserves
  older Tendermint locks, nil-precommit certificates clear only same-round
  recovery state, and a stable proposal must carry the justification needed to
  vote across an older lock before the contract can decide.
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
  unjustified valid-round state. `CrosslinkTenderlinkProposalPolEvidence.qnt`
  now pins the production-shaped bridge for this rule by requiring non-nil
  `validRound` proposal chunks to match canonical prevote-packet POL evidence
  by height, round, value id, and packet-derived voting power.
  `CrosslinkTenderlinkProposalPolTransport.qnt` then requires that proposal
  chunk and POL packet to be received through exact decrypted compact
  Tenderlink packet envelopes before transported POL evidence is accepted.
- The implementation-correspondence track has a first document in
  `docs/implementation-correspondence.md`.
- `docs/dynamic-sigma-telemetry-integration.md` maps the dynamic-sigma
  calibration and telemetry model inputs to production counters, consensus
  safety requirements, and acceptance criteria for a future implementation.
- `npm run verify:extended` adds a non-default deeper bounded-check gate for
  the newest finality-progress, composed-progress, stream-churn-risk,
  PoW stochastic-assumption, PoW fork-schedule, PoW branch-competition,
  PoW-reorg-stress, dynamic-sigma, dynamic-sigma calibration,
  dynamic-sigma telemetry,
  dynamic-sigma fork-schedule, dynamic-sigma branch-competition,
  dynamic-sigma resampling, dynamic-sigma finality,
  dynamic-sigma consensus-params, dynamic-sigma consensus-param-format,
  dynamic-sigma consensus-param-transport, dynamic-sigma head-sampling,
  dynamic-sigma heighted-round,
  dynamic-sigma heighted-finality,
  dynamic-sigma heighted-authenticated-evidence,
  dynamic-sigma authenticated-finality, head-sigma, BFT-height finality,
  BFT-block-shape,
  BFT-block validation-gap, BFT-block production-vector, fat-pointer-format,
  fat-pointer production-vector, heighted message gossip transport, heighted
  validator-evidence, heighted authenticated-evidence, and heighted
  authenticated gossip transport models.
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
- `CrosslinkDeliveryFairnessContractModel` supplies a separate TLC-checked
  local-delivery fairness contract. It fills the gap between broadcast-level
  evidence and receiver-local receive guards by requiring delivery before local
  prevote/precommit quorum evidence can drive progress.
- `CrosslinkTimeoutProgressContractModel` supplies the matching TLC-checked
  timeout envelope. It proves that an ordinary timeout round cannot be the
  unlock event, that nil-precommit recovery clears only recovery-round state,
  and that the system can still reach a justified stable decision.
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
- `CrosslinkPowForkScheduleModel` derives the observed rollback-depth signal
  from a bounded sequence of best-tip transitions and checks that sigma can be
  compared against that derived rollback rather than a hand-labelled failure.
- `CrosslinkPowBranchCompetitionModel` generates the same rollback signal from
  published-tip work competition, including the case where hidden adversarial
  work is harmless until it is released and outworks the honest tip.
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
- `CrosslinkDynamicSigmaTelemetryModel` checks a production-shaped telemetry
  calibration harness. It verifies that participating hash-work coverage is
  derived from raw work samples, that coverage and round-failure estimates
  conservatively upper-bound those samples, that rollback-risk estimates are
  monotone across the sigma ladder, and that expected-loss budgets can raise
  sigma even when rollback probability is within the PPM target.
- `CrosslinkDynamicSigmaCalibrationModel` checks the simpler measured-window
  calibration harness that feeds that production-shaped telemetry contract.
- `CrosslinkDynamicSigmaForkScheduleModel` composes the controller with a
  derived best-tip schedule, checking that rollback depth computed from a fork
  switch raises sigma before future rounds consume that value.
- `CrosslinkDynamicSigmaBranchCompetitionModel` composes the controller with
  generated published-tip work competition, checking that released
  adversarial work can become the best tip and raise sigma through the derived
  rollback-depth path.
- `CrosslinkDynamicSigmaResamplingModel` composes that derived signal with
  nil-precommit recovery, checking that a fork-derived sigma raise happens
  before the next round resamples and decides the fresh stream value.
- `CrosslinkDynamicSigmaFinalityModel` extends the same composition through
  Crosslink finality, checking tail confirmation under live dynamic sigma,
  skipped-BFT-height rejection, generated branch competition, and
  low-participation sigma delaying finality.
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
  the heighted message gossip transport bridge covers the abstract
  proposal/vote/fat-pointer-signature envelope boundary, the heighted
  authenticated gossip transport bridge covers the observer-evidence precommit
  and fat-pointer-signature envelope boundary, the Malachite gossip router and
  verifier-friendly router safety slice compose the proposal/liveness/sync
  channel namespaces, and the dynamic-sigma
  consensus-param/format/transport/heighted-round/
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
  The current stream-churn, fork-schedule, branch-competition, and PoW-reorg
  stress models now have an executable analytic assumption profile, but the
  arrival, propagation-race, GST-scaling, branch-competition, and long-reorg
  numerators still need to be calibrated against measured distributions.
