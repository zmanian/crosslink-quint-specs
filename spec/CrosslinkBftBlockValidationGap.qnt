module CrosslinkBftBlockValidationGap {
  /*
   BFT-block validation correspondence.

   `zebra-crosslink/src/chain.rs::BftBlock::try_from` documents four stateless
   validation obligations:
   - sigma header count,
   - known expected header versions,
   - consecutive header ordering,
   - valid PoW solutions.

   The current prototype implementation only rejects an incorrect confirmation
   depth and then logs that the other documented validations are not yet
   implemented. This model keeps that implementation gap executable: intended
   acceptance is stricter than current prototype acceptance, the witnesses show
   exactly which malformed blocks can pass the current boundary, and the
   repaired-constructor target records the acceptance rule that should replace
   the prototype once production code closes the gap.
   */

  type BftBlockInput_t = {
    headerCount: int,
    versionsKnown: bool,
    headersConsecutive: bool,
    powSolutionsValid: bool,
  }

  const Sigma: int

  pure val HeaderCounts = 0.to(Sigma + 1)

  assume sigma_is_positive =
    Sigma >= 1

  pure def Input(
    headerCount: int,
    versionsKnown: bool,
    headersConsecutive: bool,
    powSolutionsValid: bool,
  ): BftBlockInput_t = {
    headerCount: headerCount,
    versionsKnown: versionsKnown,
    headersConsecutive: headersConsecutive,
    powSolutionsValid: powSolutionsValid,
  }

  def HeaderCountMatchesSigma(input: BftBlockInput_t): bool =
    input.headerCount == Sigma

  def IntendedBftBlockTryFromAccepts(input: BftBlockInput_t): bool =
    HeaderCountMatchesSigma(input) and
    input.versionsKnown and
    input.headersConsecutive and
    input.powSolutionsValid

  def PrototypeBftBlockTryFromAccepts(input: BftBlockInput_t): bool =
    HeaderCountMatchesSigma(input)

  def RepairedBftBlockTryFromAccepts(input: BftBlockInput_t): bool =
    IntendedBftBlockTryFromAccepts(input)

  def PrototypeOverAccepts(input: BftBlockInput_t): bool =
    PrototypeBftBlockTryFromAccepts(input) and
    not(IntendedBftBlockTryFromAccepts(input))

  def RepairedOverAccepts(input: BftBlockInput_t): bool =
    RepairedBftBlockTryFromAccepts(input) and
    not(IntendedBftBlockTryFromAccepts(input))

  val IntendedAcceptanceSubsetOfPrototype =
    HeaderCounts.forall(headerCount =>
      Set(true, false).forall(versionsKnown =>
        Set(true, false).forall(headersConsecutive =>
          Set(true, false).forall(powSolutionsValid => {
            val input = Input(
              headerCount,
              versionsKnown,
              headersConsecutive,
              powSolutionsValid,
            )
            IntendedBftBlockTryFromAccepts(input) implies
              PrototypeBftBlockTryFromAccepts(input)
          })
        )
      )
    )

  val PrototypeValidationGapRecorded =
    PrototypeOverAccepts(Input(Sigma, false, true, true)) and
    PrototypeOverAccepts(Input(Sigma, true, false, true)) and
    PrototypeOverAccepts(Input(Sigma, true, true, false))

  val RepairedConstructorClosesValidationGap =
    HeaderCounts.forall(headerCount =>
      Set(true, false).forall(versionsKnown =>
        Set(true, false).forall(headersConsecutive =>
          Set(true, false).forall(powSolutionsValid => {
            val input = Input(
              headerCount,
              versionsKnown,
              headersConsecutive,
              powSolutionsValid,
            )
            RepairedBftBlockTryFromAccepts(input) ==
              IntendedBftBlockTryFromAccepts(input) and
            not(RepairedOverAccepts(input))
          })
        )
      )
    )

  val WrongHeaderCountStillRejected =
    not(PrototypeBftBlockTryFromAccepts(Input(Sigma + 1, true, true, true)))

  val RepairedConstructorRejectsKnownMalformedInputs =
    not(RepairedBftBlockTryFromAccepts(Input(Sigma, false, true, true))) and
    not(RepairedBftBlockTryFromAccepts(Input(Sigma, true, false, true))) and
    not(RepairedBftBlockTryFromAccepts(Input(Sigma, true, true, false))) and
    not(RepairedBftBlockTryFromAccepts(Input(Sigma + 1, true, true, true)))

  val Safety =
    IntendedAcceptanceSubsetOfPrototype and
    PrototypeValidationGapRecorded and
    RepairedConstructorClosesValidationGap and
    WrongHeaderCountStillRejected and
    RepairedConstructorRejectsKnownMalformedInputs

  var checked: bool

  action Init = all {
    checked' = false,
  }

  action Next = all {
    checked' = checked,
  }
}

module CrosslinkBftBlockValidationGapTest {
  import CrosslinkBftBlockValidationGap.* from "./CrosslinkBftBlockValidationGap"
  export CrosslinkBftBlockValidationGap.*

  pure val ValidInput =
    Input(Sigma, true, true, true)

  pure val BadVersionInput =
    Input(Sigma, false, true, true)

  pure val BadOrderInput =
    Input(Sigma, true, false, true)

  pure val BadPowInput =
    Input(Sigma, true, true, false)

  pure val WrongCountInput =
    Input(Sigma + 1, true, true, true)

  action unchangedAll = all {
    checked' = checked,
  }

  run validBlockAcceptedByBothRulesTest = {
    Init
      .then(all {
        assert(IntendedBftBlockTryFromAccepts(ValidInput)),
        assert(PrototypeBftBlockTryFromAccepts(ValidInput)),
        unchangedAll,
      })
  }

  run currentTryFromAcceptsBadVersionGapTest = {
    Init
      .then(all {
        assert(not(IntendedBftBlockTryFromAccepts(BadVersionInput))),
        assert(PrototypeBftBlockTryFromAccepts(BadVersionInput)),
        assert(not(RepairedBftBlockTryFromAccepts(BadVersionInput))),
        assert(PrototypeOverAccepts(BadVersionInput)),
        assert(not(RepairedOverAccepts(BadVersionInput))),
        unchangedAll,
      })
  }

  run currentTryFromAcceptsBadHeaderOrderGapTest = {
    Init
      .then(all {
        assert(not(IntendedBftBlockTryFromAccepts(BadOrderInput))),
        assert(PrototypeBftBlockTryFromAccepts(BadOrderInput)),
        assert(not(RepairedBftBlockTryFromAccepts(BadOrderInput))),
        assert(PrototypeOverAccepts(BadOrderInput)),
        assert(not(RepairedOverAccepts(BadOrderInput))),
        unchangedAll,
      })
  }

  run currentTryFromAcceptsBadPowGapTest = {
    Init
      .then(all {
        assert(not(IntendedBftBlockTryFromAccepts(BadPowInput))),
        assert(PrototypeBftBlockTryFromAccepts(BadPowInput)),
        assert(not(RepairedBftBlockTryFromAccepts(BadPowInput))),
        assert(PrototypeOverAccepts(BadPowInput)),
        assert(not(RepairedOverAccepts(BadPowInput))),
        unchangedAll,
      })
  }

  run currentTryFromStillRejectsWrongHeaderCountTest = {
    Init
      .then(all {
        assert(not(IntendedBftBlockTryFromAccepts(WrongCountInput))),
        assert(not(PrototypeBftBlockTryFromAccepts(WrongCountInput))),
        assert(not(RepairedBftBlockTryFromAccepts(WrongCountInput))),
        unchangedAll,
      })
  }

  run repairedConstructorMatchesIntendedRuleTest = {
    Init
      .then(all {
        assert(RepairedConstructorClosesValidationGap),
        assert(RepairedConstructorRejectsKnownMalformedInputs),
        assert(RepairedBftBlockTryFromAccepts(ValidInput)),
        unchangedAll,
      })
  }

  run validationGapSafetyTest = {
    Init
      .then(all {
        assert(Safety),
        unchangedAll,
      })
  }
}

module CrosslinkBftBlockValidationGapModel {
  import CrosslinkBftBlockValidationGapTest(
    Sigma = 3,
  ).*
}
