# Implementation Correspondence

This document records the intended correspondence between the Quint model and
the current Zebra Crosslink/Tenderlink prototype.

The model is intentionally abstract. It should still stay close enough to the
implementation that each rule has a clear code counterpart.

## Tenderlink Round Recovery

| Quint rule | Implementation counterpart | Notes |
| --- | --- | --- |
| `UponValuePrevoteQuorum` | Tenderlink `bft_update` handling of locally received `2f + 1` prevotes for the proposal id | The implementation freshly validates the proposal before precommitting a value. |
| `UponStreamChangePrecommitNil` | Tenderlink stale validation path that broadcasts `Precommit(ValueId::NIL)` | This is the Crosslink-specific moving-stream hook. |
| `StaticProposalValidity` | Crosslink proposal/block validation before freshness checks | Abstract split for structural validity, PoW-chain validity, and finality-candidate validity. |
| `ValidRoundJustified` / `AcceptableProposalFor` / `CorrectProposalValidRoundSound` | Proposal receive checks for `validRound`/POLRound evidence | A non-`-1` valid round must be backed by a prevote quorum for the proposal value before it can unlock an older value lock. |
| Heighted `ValidRoundJustified` / `AcceptableProposalFor` | Per-BFT-height proposal receive checks for `validRound`/POLRound evidence | The heighted slice scopes the POL evidence to the same BFT height as the proposal and rejects unjustified cross-value unlocks. |
| `StartNextRoundAfterPrecommitQuorum` | Tenderlink local precommit-quorum processing and round start | In the resampling branch, a locally delivered nil quorum clears same-round state before moving on. |
| `AdvanceAfterPrecommitQuorum` in `CrosslinkHeightedRound.qnt` | Height-indexed Tenderlink round advancement | The heighted slice scopes nil-precommit clearing to the validator's active BFT height and current round; a mixed precommit quorum does not clear the heighted lock/cache state. |
| `ApplyLateNilPrecommitCertificate` | Tenderlink late locally delivered nil-certificate recovery path | Late certs clear abandoned-round state without rewinding the validator. |
| `MixedPrecommitQuorumWithoutNilCert` | Negative guard test in Tenderlink | Mixed precommits can end waiting, but cannot unlock. |
| `TimeoutProposePrevoteNil` | Propose-timeout handler | Local timeout emits nil prevote without touching lock or valid state. |
| `TimeoutPrevotePrecommitNil` | Prevote-timeout handler | Local timeout emits nil precommit; a quorum of these can become nil-certificate evidence. |
| `TimeoutPrecommitStartNextRound` | Precommit-timeout handler | Advances to the next round while preserving state unless a separate nil-precommit certificate is processed. |
| Heighted `Timeout*` rules | Per-BFT-height timeout handling | The heighted round-machine slice scopes timeouts to the validator's active BFT height and checks that timeout-only round advancement does not clear heighted locks. |
| `DeliverProposal` / `DeliverPrevote` / `DeliverPrecommit` | P2P receive path plus per-peer/per-validator message cache | Delivery is modeled separately from broadcast. A receiver-local quorum only exists after the signed messages have been delivered into that validator's local view, and active round transitions now consume that local view. |
| `VotingPowerOf` / `QuorumVotingPower` | Validator-set voting power and quorum threshold | The current executable examples include both equal-weight and non-uniform-power instances. |
| `CrosslinkValidatorSetChange.qnt` / `DecideAt` | Validator-set update at BFT-height boundaries | A decided value installs the next validator set; removed validators cannot contribute to quorum at the next BFT height. |

## Crosslink Finality

| Quint rule | Implementation counterpart | Notes |
| --- | --- | --- |
| `ValidFinalityCandidate` | Crosslink BFT block/finality candidate validation | Should check branch extension, sigma/tail confirmation, and declared candidate height. |
| `CrosslinkHeadSigmaSampling.qnt` / `HeadSigmaCandidate` | `zebra-crosslink/src/lib.rs::propose_new_bft_block`; `zebra-crosslink/src/chain.rs::BftBlock::try_from` | The model derives the proposal stream as the ancestor at `headHeight - sigma`. The prototype computes `finality_candidate_height = tip_height - bc_confirmation_depth_sigma`, fetches that candidate header, then builds a `BftBlock`; `BftBlock::try_from` currently enforces that the proposal carries exactly `bc_confirmation_depth_sigma` headers. |
| `SampleChangedAfter` / stale-stream checks | `zebra-crosslink/src/lib.rs::validate_bft_block_from_malachite_already_locked`; `proposal_status_against_current_stream` | During voting, the prototype recomputes the current candidate from the latest tip and returns `TMStatus::Stale` when the proposal candidate differs from the current `head - sigma` candidate. |
| `FinalizeCandidate` | Push/accept decided Crosslink BFT block | The model allows skipped PoW heights on the same branch. |
| `DecideAt` / `DecisionCursorIsSequential` | BFT-height progression and duplicate-decision rejection | The first multi-height model requires sequential BFT heights while permitting skipped PoW heights inside a valid candidate. |
| `height` / `HeightCursorSequential` / `FutureHeightsRemainPristine` | Validator-local BFT-height cursor and per-height round state | The heighted round-machine slice checks that future heights stay untouched until reached and that a validator cannot decide height `h + 1` before height `h`. |
| `FinalizeNextDecided` / `FinalityCursorSequential` | Finality application for locally decided BFT heights | The heighted-finality slice requires a local heighted decision before finality advances, and still rejects a decided PoW fork that does not extend the current finalized prefix. |
| `FinalizedPrefixLinear` | Crosslink finalized-prefix safety | Finalized snapshots must remain on one PoW branch. |

## Evidence and Accountability

| Quint predicate | Implementation evidence |
| --- | --- |
| `LocalPrecommitQuorum(p, r, v)` | Receiver-local Tenderlink precommit quorum used by the protocol state machine. |
| `LocalNilPrecommitCert(p, r)` | Receiver-local `2f + 1` nil-precommit quorum used to clear same-round state. |
| `PrecommitQuorum(r, v)` / `NilPrecommitCert(r)` | Broadcast-level helpers used by safety witnesses and invariants. |
| `ObservedPrecommitQuorum(r, v)` | Observer/bookkeeping evidence for a fat pointer or precommit certificate for value `v`. |
| `ObservedNilPrecommitCert(r)` | Observer/bookkeeping evidence for `2f + 1` signed nil precommits for round `r`. |
| `ObservedFatPointerQuorum(r, v)` | Decided/fat-pointer evidence whose signer set has quorum voting power and matching observed precommits. |
| `MessageEvidenceSoundness` | Invariant that live protocol messages are mirrored into observer evidence and fat-pointer evidence validates against observed signatures. |
| `CrosslinkEvidenceGossip.qnt` / `ObservedMessagesWereGossiped` | Evidence gossip and observer ingestion pipeline | Observer-local evidence is only accepted after the corresponding signed message or fat pointer appears in gossip. |
| `CrosslinkHeightedEvidenceGossip.qnt` / `ObservedMessagesWereGossiped` | Height-indexed evidence gossip and observer ingestion pipeline | Observer-local evidence is only accepted after same-height gossip, and heighted fat pointers require same-height observed signer precommits. |
| `CrosslinkMessageAuth.qnt` / `ProposalAuthentic` / `VoteAuthentic` | Signature verification and canonical sign bytes | Signed messages are accepted only when their bytes match the claimed proposal/vote/fat-pointer payload and verify for the claimed validator. |
| `CrosslinkHeightedMessageAuth.qnt` / `ProposalAuthentic` / `VoteAuthentic` | Height-indexed signature verification and canonical sign bytes | The heighted authentication slice binds BFT height into proposal, vote, and fat-pointer sign bytes, including a cross-height replay rejection witness. |
| `CorrectNilValueEquivocationEvidence` | Same validator signs both nil and value precommit in the same round. |
| `CorrectValueSwitchWithoutUnlock` | Validator signs a later conflicting value without a nil certificate for the earlier lock round. |

## Gaps To Close

- Connect weighted signer sets to the concrete Tenderlink validator-set and
  signature formats, including the dynamic validator-set rotation slice.
- Connect the abstract message-authentication, evidence, and standalone gossip
  models to concrete signature verification, serialized message bytes, and
  production gossip.
- Connect the height-indexed authentication and evidence-gossip slices to
  concrete signature verification, serialized message bytes, and production
  gossip.
- Add implementation-linked test vectors once the Tenderlink message format,
  Crosslink BFT block encoding, and PoW head/candidate sampling data stabilize.
