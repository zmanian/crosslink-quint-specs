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
| `StartNextRoundAfterPrecommitQuorum` | Tenderlink precommit-quorum processing and round start | In the resampling branch, nil quorum clears same-round state before moving on. |
| `ApplyLateNilPrecommitCertificate` | Tenderlink late nil-certificate recovery path | Late certs clear abandoned-round state without rewinding the validator. |
| `MixedPrecommitQuorumWithoutNilCert` | Negative guard test in Tenderlink | Mixed precommits can end waiting, but cannot unlock. |

## Crosslink Finality

| Quint rule | Implementation counterpart | Notes |
| --- | --- | --- |
| `ValidFinalityCandidate` | Crosslink BFT block/finality candidate validation | Should check branch extension, sigma/tail confirmation, and declared candidate height. |
| `FinalizeCandidate` | Push/accept decided Crosslink BFT block | The model allows skipped PoW heights on the same branch. |
| `FinalizedPrefixLinear` | Crosslink finalized-prefix safety | Finalized snapshots must remain on one PoW branch. |

## Evidence and Accountability

| Quint predicate | Implementation evidence |
| --- | --- |
| `PrecommitQuorum(r, v)` | Fat pointer or precommit certificate for value `v`. |
| `NilPrecommitCert(r)` | `2f + 1` signed nil precommits for round `r`. |
| `CorrectNilValueEquivocationEvidence` | Same validator signs both nil and value precommit in the same round. |
| `CorrectValueSwitchWithoutUnlock` | Validator signs a later conflicting value without a nil certificate for the earlier lock round. |

## Gaps To Close

- Model validator weights and signer sets instead of cardinality-only test
  instances.
- Model message authentication and fat-pointer signer validation explicitly.
- Split protocol state from observer/evidence bookkeeping, matching the
  upstream Tendermint spec style.
- Add multi-height state, since the current round model is still focused on a
  single Crosslink decision height.
- Add implementation-linked test vectors once the Tenderlink message format and
  Crosslink BFT block encoding stabilize.
