# Inductive Multi-Height Finality

This doc explains the inductive argument shape behind the multi-height
finality safety property in `spec/CrosslinkMultiHeight.qnt` (and its dynamic
and authenticated extensions). It is a companion to the `Safety` invariant
defined in that file.

## Why "inductive" matters

Bounded model checking establishes that an invariant holds for traces up to a
fixed depth `d`. For an `n`-height finalized prefix we want the invariant to
hold for *every* `n`, which requires induction over `n`. Apalache cannot
close that induction natively: it cannot generalize from
"`Safety` holds at depth `d`" to "`Safety` holds at every depth."

The model-checking gate therefore proves `Safety` at bounded depths
(`verify:multi-height-safety` runs at `--max-steps=3`). To make the
multi-height argument *reviewable* — and to make a future port into a tool
with native inductive support (TLA+ with TLAPS, Lean, Coq) tractable — the
`Safety` invariant is structured as a conjunction of seven named lemmas, each
of which is independently bounded-checkable. The seven lemmas together
encode the inductive step for height pair `(h, h+1)`.

## The seven lemmas

In `spec/CrosslinkMultiHeight.qnt`:

1. **`DecisionsAreSnapshots`** — every recorded decision is either nil or a
   valid PoW snapshot. Domain invariant.
2. **`DecisionCursorIsSequential`** — for every height in
   `CursorHeights`, all earlier heights have been decided and all later
   heights are nil. This rules out gaps and out-of-order decisions.
3. **`DecisionsRespectFinalizedPrefix`** — for every pair of decided heights
   `(h1, h2)` with `h1 < h2`, the height-`h2` decision *extends* the
   height-`h1` decision. This is the chain-respecting clause.
4. **`FinalizedPrefixLinear`** — every two finalized snapshots `(a, b)`
   agree (one extends the other). The finalized set forms a linear prefix.
5. **`LatestFinalExtendsAllFinalized`** — `latestFinal` extends every
   element of `finalized`. The latest finalized snapshot is the apex of
   the finalized lineage.
6. **`InitialFinalizedRemainsFinalized`** — `finalized` always contains
   `InitialFinalized`. The genesis-side anchor is never dropped.
7. **`LatestFinalMatchesDecisionCursor`** — `latestFinal` equals the
   most-recently-decided value (or `InitialFinalized` before any
   decision). The finalized cursor and the decision cursor track together.

`Safety = (1) and (2) and (3) and (4) and (5) and (6) and (7)`.

## The inductive shape

Each lemma is a *quantified* property over the current state's
`DecisionHeights` and `finalized` sets. Bounded model checking at depth
`d` proves each lemma for traces of at most `d` `DecideNext` transitions.

Reading the seven lemmas as the inductive step for height pair `(h, h+1)`:

- **Base case (`h = 0`):** `InitialFinalizedRemainsFinalized` (lemma 6)
  and `LatestFinalMatchesDecisionCursor` (lemma 7, `nextBftHeight == 1`
  branch) together establish the safety state of the model at
  `nextBftHeight == 1`.
- **Inductive step:** assuming `Safety` holds at `nextBftHeight = h`, a
  `DecideNext(candidate, tip)` transition advances to `nextBftHeight = h+1`.
  The lemmas constrain that step as follows:
  - lemma 2 forces `h` to be the next sequential height (no skip / no
    reorder),
  - lemma 1 forces `candidate` to be a valid snapshot (or rejected before
    `decision'`),
  - lemma 3 forces `candidate` to extend the height-`h` decision (which by
    induction is the apex of `finalized`),
  - lemmas 4 + 5 maintain the linear-prefix shape across the `finalized`
    update,
  - lemmas 6 + 7 maintain the anchor and cursor invariants across the
    height transition.

Each constraint is a bounded check inside the `DecideNext` precondition
shape, and `Safety` is preserved across the step by construction.

## What is and is not proved

This decomposition proves:

- Each of the seven lemmas at every depth `d ≤ MaxBftHeight` for which
  `verify:multi-height-safety` runs (currently `d = 3`).
- The structural shape of an inductive proof of `Safety` for all `n`.

This decomposition does **not** prove:

- That the lemma conjunction holds for *every* `n`. Apalache only checks
  bounded depth.
- The dynamic and authenticated extensions inherit the same shape but their
  inductive step also touches sigma, observer evidence, and validator-set
  rotation. The composed extensions are checked separately by
  `CrosslinkDynamicSigmaHeightedFinalityModel`,
  `CrosslinkDynamicSigmaAuthenticatedFinalityModel`,
  `CrosslinkHeightedAuthenticatedProgressProjectionContractModel`, and
  `CrosslinkRotatingAuthenticatedProgressProjectionContractModel`.

## Path to a fully closed proof

To machine-check the induction itself, port the seven lemmas plus the
`DecideNext`/`Stutter` transitions into:

- **TLA+ + TLAPS.** Direct re-encoding; TLAPS handles inductive invariants
  natively. The conjunction becomes the inductive invariant; each lemma is
  an obligation discharged via PTL/temporal reasoning or auxiliary
  arithmetic.
- **Lean or Coq.** Heavier port but the strongest guarantee. The
  consecutive-pair shape of the lemmas maps directly into a
  pair-of-states induction in either system.

The seven-lemma shape is intentionally chosen so the induction step is one
`DecideNext` transition between consecutive `BftHeight_t` values — that
shape is the same in TLA+ and in Lean / Coq.

## Companion invariants in extensions

- `CrosslinkBftHeights.qnt` carries a compact scheduled-height sanity
  harness over the same shape.
- `CrosslinkHeightedFinality.qnt` composes the round-machine state with
  this finality cursor; its `Safety` adds clauses that bind heighted
  decisions before finalization.
- `CrosslinkDynamicSigmaHeightedFinality.qnt` extends the inductive step
  with sigma updates at height boundaries.
- `CrosslinkDynamicSigmaAuthenticatedFinality.qnt` further constrains
  finalization on observer-local authenticated precommit and fat-pointer
  evidence.
- `CrosslinkProductionFinalityProjectionContract.qnt` makes the production
  candidate transport prerequisite explicit before finality.

Each composition adds its own clauses to the inductive invariant. The
multi-height base proof structure documented here is what those
extensions extend; the same induction-by-bounded-conjunction shape carries
through.
