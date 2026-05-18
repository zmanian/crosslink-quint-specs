# Implementation Correspondence

This document records the intended correspondence between the Quint model and
the current Zebra Crosslink/Tenderlink prototype.

The model is intentionally abstract. It should still stay close enough to the
implementation that each rule has a clear code counterpart.

## Tenderlink Round Recovery

| Quint rule | Implementation counterpart | Notes |
| --- | --- | --- |
| `UponValuePrevoteQuorum` | Tenderlink `bft_update` handling of `2f + 1` prevotes for the proposal id | The implementation freshly validates the proposal before precommitting a value. |
| `UponStreamChangePrecommitNil` | Tenderlink stale validation path that broadcasts `Precommit(ValueId::NIL)` | This is the Crosslink-specific moving-stream hook. |
| `StaticProposalValidity` | Crosslink proposal/block validation before freshness checks | Abstract split for structural validity, PoW-chain validity, and finality-candidate validity. |
| `ValidRoundJustified` / `AcceptableProposalFor` / `CorrectProposalValidRoundSound` | Proposal receive checks for `validRound`/POLRound evidence | A non-`-1` valid round must be backed by a prevote quorum for the proposal value before it can unlock an older value lock. |
| `StartNextRoundAfterPrecommitQuorum` | Tenderlink precommit-quorum processing and round start | In the resampling branch, nil quorum clears same-round state before moving on. |
| `ApplyLateNilPrecommitCertificate` | Tenderlink late nil-certificate recovery path | Late certs clear abandoned-round state without rewinding the validator. |
| `MixedPrecommitQuorumWithoutNilCert` | Negative guard test in Tenderlink | Mixed precommits can end waiting, but cannot unlock. |
| `TimeoutProposePrevoteNil` | Propose-timeout handler | Local timeout emits nil prevote without touching lock or valid state. |
| `TimeoutPrevotePrecommitNil` | Prevote-timeout handler | Local timeout emits nil precommit; a quorum of these can become nil-certificate evidence. |
| `TimeoutPrecommitStartNextRound` | Precommit-timeout handler | Advances to the next round while preserving state unless a separate nil-precommit certificate is processed. |
| `VotingPowerOf` / `QuorumVotingPower` | Validator-set voting power and quorum threshold | The current executable examples include both equal-weight and non-uniform-power instances. |

## Crosslink Finality

| Quint rule | Implementation counterpart | Notes |
| --- | --- | --- |
| `ValidFinalityCandidate` | Crosslink BFT block/finality candidate validation | Should check branch extension, sigma/tail confirmation, and declared candidate height. |
| `FinalizeCandidate` | Push/accept decided Crosslink BFT block | The model allows skipped PoW heights on the same branch. |
| `FinalizedPrefixLinear` | Crosslink finalized-prefix safety | Finalized snapshots must remain on one PoW branch. |

## Evidence and Accountability

| Quint predicate | Implementation evidence |
| --- | --- |
| `PrecommitQuorum(r, v)` | Live Tenderlink precommit quorum used by the protocol state machine. |
| `NilPrecommitCert(r)` | Live `2f + 1` nil-precommit quorum used to clear same-round state. |
| `ObservedPrecommitQuorum(r, v)` | Observer/bookkeeping evidence for a fat pointer or precommit certificate for value `v`. |
| `ObservedNilPrecommitCert(r)` | Observer/bookkeeping evidence for `2f + 1` signed nil precommits for round `r`. |
| `ObservedFatPointerQuorum(r, v)` | Decided/fat-pointer evidence whose signer set has quorum voting power and matching observed precommits. |
| `MessageEvidenceSoundness` | Invariant that live protocol messages are mirrored into observer evidence and fat-pointer evidence validates against observed signatures. |
| `CorrectNilValueEquivocationEvidence` | Same validator signs both nil and value precommit in the same round. |
| `CorrectValueSwitchWithoutUnlock` | Validator signs a later conflicting value without a nil certificate for the earlier lock round. |

## Gaps To Close

- Connect weighted signer sets to the concrete Tenderlink validator-set and
  signature formats.
- Connect the abstract message evidence model to concrete signature
  verification and serialized message bytes.
- Add evidence gossip and observer-process transitions around the current
  bookkeeping state.
- Add multi-height state, since the current round model is still focused on a
  single Crosslink decision height.
- Add implementation-linked test vectors once the Tenderlink message format and
  Crosslink BFT block encoding stabilize.
