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
   acceptance is stricter than current prototype acceptance, and the witnesses
   show exactly which malformed blocks can pass the current boundary.
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

  def PrototypeOverAccepts(input: BftBlockInput_t): bool =
    PrototypeBftBlockTryFromAccepts(input) and
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

  val WrongHeaderCountStillRejected =
    not(PrototypeBftBlockTryFromAccepts(Input(Sigma + 1, true, true, true)))

  val Safety =
    IntendedAcceptanceSubsetOfPrototype and
    PrototypeValidationGapRecorded and
    WrongHeaderCountStillRejected

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
        assert(PrototypeOverAccepts(BadVersionInput)),
        unchangedAll,
      })
  }

  run currentTryFromAcceptsBadHeaderOrderGapTest = {
    Init
      .then(all {
        assert(not(IntendedBftBlockTryFromAccepts(BadOrderInput))),
        assert(PrototypeBftBlockTryFromAccepts(BadOrderInput)),
        assert(PrototypeOverAccepts(BadOrderInput)),
        unchangedAll,
      })
  }

  run currentTryFromAcceptsBadPowGapTest = {
    Init
      .then(all {
        assert(not(IntendedBftBlockTryFromAccepts(BadPowInput))),
        assert(PrototypeBftBlockTryFromAccepts(BadPowInput)),
        assert(PrototypeOverAccepts(BadPowInput)),
        unchangedAll,
      })
  }

  run currentTryFromStillRejectsWrongHeaderCountTest = {
    Init
      .then(all {
        assert(not(IntendedBftBlockTryFromAccepts(WrongCountInput))),
        assert(not(PrototypeBftBlockTryFromAccepts(WrongCountInput))),
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
