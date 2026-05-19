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
| `CrosslinkStreamChurnRisk.qnt` / `StreamChurnRiskNumerator` | Crosslink parameter selection for sigma, round duration, and validator-set sizing | This is an analysis layer rather than a direct code counterpart. It records the liveness argument that larger globally distributed validator sets increase the prevote-to-precommit churn window through GST, sigma mitigates only long-reorg-tail churn, and nil-precommit resampling converts finite stream churn into round increments until the stream stabilizes. |
| `CrosslinkPowReorgStress.qnt` / `ProcessRound` | Crosslink vote-status handling when `proposal_status_against_current_stream` reports stale between prevote and precommit | This bounded stress slice records the concrete behavior expected from the nil-precommit variant: long reorgs and same-branch PoW head arrivals can both change the sampled `head - sigma` candidate within one round, so correct validators abort with nil precommits and only decide once prevote and precommit see the same candidate. |
| `CrosslinkFinalityProgressContract.qnt` / `EventuallyFinalized` | Finality application after a stable Tenderlink decision | This is a TLC-friendly temporal contract rather than a direct code counterpart. It checks the handoff from the stable-decision phase to advancing the Crosslink finality cursor under a fair finality applicator. |
| `CrosslinkComposedProgressContract.qnt` / `EventuallyFinalizesStableDecision` | Nil-resampling round recovery followed by finality application | This self-contained temporal contract keeps the nil-precommit burned-round behavior, stable proposal/vote/precommit delivery, finality-candidate validation, and finalized-prefix linearity in one finite state graph that TLC can exhaustively check. |
| `CrosslinkHeightedHeadSigmaRound.qnt` / `HeadSigmaSafety` | Heighted Tenderlink proposal, prevote, and precommit handling over the Crosslink proposal stream | The model ties each BFT-height/round `Stream(h, r)` value to the current `head - sigma` candidate, then checks that fresh correct proposals and value precommits use that candidate while nil-precommit certificates clear cached same-round state before the next round resamples. |
| `CrosslinkBftBlockShape.qnt` / `FindHeadersAfter` / `StatelessBftBlockShapeValid` | `zebra-state::Request::FindBlockHeaders`; `zebra-crosslink/src/lib.rs::propose_new_bft_block`; `zebra-crosslink/src/chain.rs::BftBlock::try_from`; `validate_bft_block_from_malachite_already_locked` | Zebra's Find protocol returns headers after the known intersection. With `known_blocks = [candidate_hash]`, the modeled proposal carries the sigma descendant headers after the declared `head - sigma` candidate; the model records that a validator check treating `headers.first()` as the candidate rejects that locally produced shape. The same slice models the desired stateless `BftBlock::try_from` guards and records current gaps: the prototype constructor currently only enforces header count, and `ZcashDeserialize` constructs `BftBlock` directly under a 2048-header envelope cap instead of delegating to `try_from`. |
| `CrosslinkBftBlockValidationGap.qnt` / `PrototypeBftBlockTryFromAccepts` | `zebra-crosslink/src/chain.rs::BftBlock::try_from` | This standalone slice isolates the current constructor boundary: intended acceptance requires sigma header count, known versions, consecutive order, and valid PoW solutions; prototype acceptance only requires sigma header count. The witnesses pin bad-version, bad-order, and bad-PoW over-acceptance as implementation gaps. |
| `CrosslinkBftBlockProductionVectors.qnt` / `BftBlockWireByteLen` / `HeadersStartOffset` | `zebra-crosslink/src/chain.rs::BftBlock::{zcash_serialize, zcash_deserialize}`; `zebra-crosslink/src/lib.rs::FatPointerToBftBlock2::{zcash_serialize, zcash_deserialize}`; `zebra-chain/src/block/serialize.rs::Header::zcash_serialize` | Pins the production BFT-block wire prefix: u32 version, u32 BFT height, counted previous-block fat pointer, u32 finalization-candidate height, u32 header count, then contiguous serialized PoW headers. It also records that deserialization accepts any header count up to 2048 and therefore bypasses the sigma count required by `BftBlock::try_from`. |
| `SampleChangedAfter` / stale-stream checks | `zebra-crosslink/src/lib.rs::validate_bft_block_from_malachite_already_locked`; `proposal_status_against_current_stream` | During voting, the prototype recomputes the current candidate from the latest tip and returns `TMStatus::Stale` when the proposal candidate differs from the current `head - sigma` candidate. |
| `FinalizeCandidate` | Push/accept decided Crosslink BFT block | The model allows skipped PoW heights on the same branch. |
| `DecideAt` / `DecisionCursorIsSequential` | BFT-height progression and duplicate-decision rejection | The first multi-height model requires sequential BFT heights while permitting skipped PoW heights inside a valid candidate. |
| `height` / `HeightCursorSequential` / `FutureHeightsRemainPristine` | Validator-local BFT-height cursor and per-height round state | The heighted round-machine slice checks that future heights stay untouched until reached and that a validator cannot decide height `h + 1` before height `h`. |
| `FinalizeNextDecided` / `FinalityCursorSequential` | Finality application for locally decided BFT heights | The heighted-finality slice requires a local heighted decision before finality advances, and still rejects a decided PoW fork that does not extend the current finalized prefix. |
| `FinalizedPrefixLinear` | Crosslink finalized-prefix safety | Finalized snapshots must remain on one PoW branch. |

## Evidence and Accountability

| Quint predicate | Implementation counterpart | Notes |
| --- | --- | --- |
| `LocalPrecommitQuorum(p, r, v)` | Receiver-local Tenderlink precommit quorum | Used by the protocol state machine. |
| `LocalNilPrecommitCert(p, r)` | Receiver-local `2f + 1` nil-precommit quorum | Used to clear same-round state. |
| `PrecommitQuorum(r, v)` / `NilPrecommitCert(r)` | Broadcast-level quorum helpers | Used by safety witnesses and invariants. |
| `ObservedPrecommitQuorum(r, v)` | Observer/bookkeeping precommit evidence | Evidence for a fat pointer or precommit certificate for value `v`. |
| `ObservedNilPrecommitCert(r)` | Observer/bookkeeping nil-precommit evidence | Evidence for `2f + 1` signed nil precommits for round `r`. |
| `ObservedFatPointerQuorum(r, v)` | Decided/fat-pointer evidence | Signer set has quorum voting power and matching observed precommits. |
| `MessageEvidenceSoundness` | Protocol-message observer mirror | Invariant that live protocol messages are mirrored into observer evidence and fat-pointer evidence validates against observed signatures. |
| `CrosslinkEvidenceGossip.qnt` / `ObservedMessagesWereGossiped` | Evidence gossip and observer ingestion pipeline | Observer-local evidence is only accepted after the corresponding signed message or fat pointer appears in gossip. |
| `CrosslinkHeightedEvidenceGossip.qnt` / `ObservedMessagesWereGossiped` | Height-indexed evidence gossip and observer ingestion pipeline | Observer-local evidence is only accepted after same-height gossip, and heighted fat pointers require same-height observed signer precommits. |
| `CrosslinkMessageAuth.qnt` / `ProposalAuthentic` / `VoteAuthentic` | Signature verification and canonical sign bytes | Signed messages are accepted only when their bytes match the claimed proposal/vote/fat-pointer payload and verify for the claimed validator. |
| `CrosslinkHeightedMessageAuth.qnt` / `ProposalAuthentic` / `VoteAuthentic` | Height-indexed signature verification and canonical sign bytes | The heighted authentication slice binds BFT height into proposal, vote, and fat-pointer sign bytes, including a cross-height replay rejection witness. |
| `CrosslinkHeightedValidatorEvidence.qnt` / `AuthorizedAtHeight` | Validator-set-aware evidence validation | Observed precommits and fat pointers are checked against the validator set active at the evidence BFT height, so removed validators remain valid for old-height evidence but cannot sign next-height evidence after rotation. |
| `CrosslinkHeightedAuthenticatedEvidence.qnt` / `PrecommitAuthentic` / `ObservedFatPointerValid` | Authenticated evidence pipeline | Precommit evidence must pass canonical sign-byte verification before gossip and observation, observer evidence must come from prior gossip, and fat pointers require quorum signer precommits plus authenticated fat-pointer signatures from validators authorized at that BFT height. |
| `CrosslinkFatPointerFormat.qnt` / `FatPointerFormatValid` / `FatPointerWireEnvelopeValid` / `FatPointerDerivedFromRoundData` / `SignaturePubKeysUnique` / `SignatureAuthorizedAtHeight` | `zebra-crosslink/src/lib.rs::FatPointerToBftBlock2`, `FatPointerSignature2`, `to_bytes`, `validate_signatures`; `zebra-chain/src/block/header.rs::FatPointerToBftBlock`, `FatPointerSignature`, `to_bytes`, `from_bytes`, `zcash_deserialize`; `forks/tenderlink/src/lib.rs::FatPointerToBftBlock3`, `FatPointerSignature3`, `round_data_to_fat_pointer`, `make_vote_sign_datas`, `TMSig::verify` | The model mirrors the current production count-plus-vector format: a 44-byte vote payload suffix without the finalizer pubkey, little-endian u16 signature count at byte offset 44, entries starting at byte offset 46, and one 32-byte pubkey plus 64-byte vote signature per entry. It makes exact wire-envelope offsets and length, duplicate-pubkey rejection, height-scoped signer authorization, canonical signed bytes, signature verification, quorum power, and derivation from producer round data explicit. |
| `CrosslinkFatPointerProductionVectors.qnt` / `SerializerCountSliceIsBytes44To46` / `StreamingDeserializerMatchesSerializer` / `PrototypeTryFromBytesGapRecorded` | `zebra-chain/src/block/header.rs::FatPointerToBftBlock::{to_bytes, zcash_deserialize, try_from_bytes}`; `zebra-crosslink/src/{lib.rs,malctx.rs}::FatPointerToBftBlock2::try_from_bytes`; `forks/tenderlink/src/lib.rs::FatPointerToBftBlock3::try_from_bytes` | Pins exact implementation-linked vectors for 0-4 signatures: 46, 142, 238, 334, and 430 bytes. The streaming serializer/deserializer agree on count bytes 44..46. The current prototype helper `try_from_bytes` uses a reversed count slice (`bytes[44..2]`) in multiple copies; the spec records that as an implementation gap rather than treating it as the protocol layout. |
| `CrosslinkFatPointerAuthenticatedEvidence.qnt` / `ProductionFatPointerEvidenceValid` / `ProductionFatPointerWireEvidenceValid` / `GossipedMatchingPrecommitForSignature` | `forks/tenderlink/src/lib.rs::round_data_to_fat_pointer`; `forks/tenderlink/src/lib.rs::check_and_incorporate_msg`; `zebra-crosslink/src/lib.rs::new_decided_bft_block_from_malachite`; `zebra-crosslink/src/lib.rs::fat_pointer_has_roster_quorum` | Connects the production-shaped fat-pointer vector and counted wire envelope to observer evidence. Every active signer entry must have a matching gossiped precommit at the same height, round, and value before the fat pointer wire is observed; duplicate signer entries, trailing-byte wires, and removed-validator next-height precommits are rejected at the composed boundary. |
| `CorrectNilValueEquivocationEvidence` | Nil/value precommit evidence | Same validator signs both nil and value precommit in the same round. |
| `CorrectValueSwitchWithoutUnlock` | Conflicting value-switch evidence | Validator signs a later conflicting value without a nil certificate for the earlier lock round. |

## Gaps To Close

- Connect the fat-pointer format and observer models to more production
  serialization test vectors, real signatures, and the full Tenderlink
  validator-set rotation path.
- Turn the BFT-block validation-gap witnesses into production constructor
  coverage for version, header-order, and PoW-solution checks.
- Connect the abstract message-authentication, evidence, and standalone gossip
  models to concrete signature verification, serialized message bytes, and
  production gossip.
- Connect the height-indexed authentication and evidence-gossip slices to
  concrete signature verification, serialized message bytes, and production
  gossip.
- Lift the current TLC-friendly progress contracts into temporal liveness
  checks over the full imported protocol state.
- Add implementation-linked test vectors once the Tenderlink message format,
  Crosslink BFT block encoding, and PoW head/candidate sampling data stabilize;
  in particular, pin whether candidate validation should use the declared
  `head - sigma` height/hash or a header-vector position.
