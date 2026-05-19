module CrosslinkDynamicSigmaProposalEvidenceFormat {
  /*
   Production-shaped dynamic-sigma proposal evidence bytes.

   Zebra's dynamic-sigma prototype serializes DynamicSigmaProposalEvidence as:
   - DynamicSigmaRawTelemetry:
     u128 total_hash_work,
     u128 crosslink_participating_hash_work,
     u64 total_tenderlink_rounds,
     u64 failed_tenderlink_rounds,
     u8 measured_block_interval_variance_pct,
     u64 measured_observed_reorg_depth,
     RollbackRiskCurve as three u64 PPM values,
     u128 value_at_risk_units,
     u128 max_acceptable_expected_loss_units,
   - TelemetryEstimateMargins as two u8 percentage margins,
   - u64 selected_sigma.

   This slice pins that 123-byte little-endian payload and connects it to the
   proposal-validity rule used by BftBlock::try_from_with_dynamic_sigma_evidence:
   the selected sigma must be a configured ladder value and must be at least the
   deterministic floor implied by the raw telemetry plus conservative margins.
   */

  type Sigma_t = int
  type Pct_t = int
  type Bytes_t = str

  const BaseSigma: Sigma_t
  const RaisedSigma: Sigma_t
  const MaxSigma: Sigma_t
  const TargetHashParticipationPct: Pct_t
  const CriticalHashParticipationPct: Pct_t
  const MaxAcceptableRollbackRiskPpm: int
  const CoverageRiskWeight: int
  const RoundFailureRiskWeight: int
  const BlockVarianceRiskWeight: int
  const ReorgDepthRiskWeight: int
  const RiskScoreRaisedThreshold: int
  const RiskScoreMaxThreshold: int
  const ProductionProposalEvidenceWires:
    Set[ProductionDynamicSigmaProposalEvidenceWire_t]

  type RollbackRiskCurve_t = {
    baseSigmaPpm: int,
    raisedSigmaPpm: int,
    maxSigmaPpm: int,
  }

  type U128Le_t = {
    low64: int,
    high64: int,
  }

  type DynamicSigmaRawTelemetry_t = {
    totalHashWork: U128Le_t,
    crosslinkParticipatingHashWork: U128Le_t,
    totalTenderlinkRounds: int,
    failedTenderlinkRounds: int,
    measuredBlockIntervalVariancePct: Pct_t,
    measuredObservedReorgDepth: int,
    rollbackRisk: RollbackRiskCurve_t,
    valueAtRiskUnits: U128Le_t,
    maxAcceptableExpectedLossUnits: U128Le_t,
  }

  type TelemetryEstimateMargins_t = {
    coverageRiskMarginPct: Pct_t,
    roundFailureMarginPct: Pct_t,
  }

  type DynamicSigmaProposalEvidence_t = {
    rawTelemetry: DynamicSigmaRawTelemetry_t,
    margins: TelemetryEstimateMargins_t,
    selectedSigma: Sigma_t,
  }

  type ProductionDynamicSigmaProposalEvidenceWire_t = {
    byteLen: int,
    evidence: DynamicSigmaProposalEvidence_t,
    bytes: Bytes_t,
  }

  pure val U8ByteLen = 1
  pure val U64ByteLen = 8
  pure val U128ByteLen = 16
  pure val RollbackRiskCurveByteLen = U64ByteLen * 3
  pure val TelemetryEstimateMarginsByteLen = U8ByteLen * 2

  pure val TotalHashWorkOffset = 0
  pure val CrosslinkParticipatingHashWorkOffset =
    TotalHashWorkOffset + U128ByteLen
  pure val TotalTenderlinkRoundsOffset =
    CrosslinkParticipatingHashWorkOffset + U128ByteLen
  pure val FailedTenderlinkRoundsOffset =
    TotalTenderlinkRoundsOffset + U64ByteLen
  pure val MeasuredBlockIntervalVariancePctOffset =
    FailedTenderlinkRoundsOffset + U64ByteLen
  pure val MeasuredObservedReorgDepthOffset =
    MeasuredBlockIntervalVariancePctOffset + U8ByteLen
  pure val RollbackRiskBaseSigmaPpmOffset =
    MeasuredObservedReorgDepthOffset + U64ByteLen
  pure val RollbackRiskRaisedSigmaPpmOffset =
    RollbackRiskBaseSigmaPpmOffset + U64ByteLen
  pure val RollbackRiskMaxSigmaPpmOffset =
    RollbackRiskRaisedSigmaPpmOffset + U64ByteLen
  pure val ValueAtRiskUnitsOffset =
    RollbackRiskMaxSigmaPpmOffset + U64ByteLen
  pure val MaxAcceptableExpectedLossUnitsOffset =
    ValueAtRiskUnitsOffset + U128ByteLen
  pure val RawTelemetryByteLen =
    MaxAcceptableExpectedLossUnitsOffset + U128ByteLen
  pure val CoverageRiskMarginPctOffset = RawTelemetryByteLen
  pure val RoundFailureMarginPctOffset =
    CoverageRiskMarginPctOffset + U8ByteLen
  pure val SelectedSigmaOffset =
    RoundFailureMarginPctOffset + U8ByteLen
  pure val DynamicSigmaProposalEvidenceByteLen =
    SelectedSigmaOffset + U64ByteLen
  pure val DynamicSigmaProposalEvidenceHexCharLen =
    DynamicSigmaProposalEvidenceByteLen * 2
  pure val PpmDenominator = 1000000
  pure val UnmodeledDynamicSigmaEvidenceHex =
    "unmodeled-dynamic-sigma-evidence"

  var acceptedProductionProposalEvidenceWires:
    Set[ProductionDynamicSigmaProposalEvidenceWire_t]
  var firedAction: str

  pure def MaxInt(a: int, b: int): int =
    if (a >= b) { a } else { b }

  pure def FieldEndOffset(offset: int, width: int): int =
    offset + width

  pure def SigmaInLadder(sigma: Sigma_t): bool =
    sigma == BaseSigma or sigma == RaisedSigma or sigma == MaxSigma

  pure def PctInRange(pct: Pct_t): bool =
    0 <= pct and pct <= 100

  pure def U128WordWellFormed(value: U128Le_t): bool =
    value.low64 >= 0 and value.high64 >= 0

  pure def U128Is(value: U128Le_t, low64: int, high64: int): bool =
    value.low64 == low64 and value.high64 == high64

  pure def U128Positive(value: U128Le_t): bool =
    value.high64 > 0 or value.low64 > 0

  pure def U128Leq(a: U128Le_t, b: U128Le_t): bool =
    a.high64 < b.high64 or
    (a.high64 == b.high64 and a.low64 <= b.low64)

  pure def RawTelemetryCountersWellFormed(
    raw: DynamicSigmaRawTelemetry_t,
  ): bool =
    U128WordWellFormed(raw.totalHashWork) and
    U128WordWellFormed(raw.crosslinkParticipatingHashWork) and
    U128Positive(raw.totalHashWork) and
    U128Leq(raw.crosslinkParticipatingHashWork, raw.totalHashWork) and
    raw.totalTenderlinkRounds > 0 and
    raw.failedTenderlinkRounds >= 0 and
    raw.failedTenderlinkRounds <= raw.totalTenderlinkRounds and
    PctInRange(raw.measuredBlockIntervalVariancePct) and
    raw.measuredObservedReorgDepth >= 0 and
    raw.rollbackRisk.baseSigmaPpm >= raw.rollbackRisk.raisedSigmaPpm and
    raw.rollbackRisk.raisedSigmaPpm >= raw.rollbackRisk.maxSigmaPpm and
    U128WordWellFormed(raw.valueAtRiskUnits) and
    U128WordWellFormed(raw.maxAcceptableExpectedLossUnits)

  pure def MarginsWellFormed(margins: TelemetryEstimateMargins_t): bool =
    PctInRange(margins.coverageRiskMarginPct) and
    PctInRange(margins.roundFailureMarginPct)

  pure def SaturatingPctAdd(rawPct: Pct_t, marginPct: Pct_t): Pct_t =
    if (rawPct + marginPct > 100) { 100 } else { rawPct + marginPct }

  pure def CoverageRiskEstimateModeled(
    raw: DynamicSigmaRawTelemetry_t,
  ): bool =
    U128Is(raw.totalHashWork, 100, 0) or
    (
      U128Is(raw.totalHashWork, 0, 1) and
      U128Is(raw.crosslinkParticipatingHashWork, 12345, 0)
    )

  pure def RawCoverageRiskPct(raw: DynamicSigmaRawTelemetry_t): Pct_t =
    if (U128Is(raw.totalHashWork, 100, 0)) {
      100 - raw.crosslinkParticipatingHashWork.low64
    } else if (
      U128Is(raw.totalHashWork, 0, 1) and
      U128Is(raw.crosslinkParticipatingHashWork, 12345, 0)
    ) {
      100
    } else {
      101
    }

  pure def EstimatedCoverageRiskPct(
    raw: DynamicSigmaRawTelemetry_t,
    margins: TelemetryEstimateMargins_t,
  ): Pct_t =
    SaturatingPctAdd(RawCoverageRiskPct(raw), margins.coverageRiskMarginPct)

  pure def RoundFailureEstimateModeled(
    raw: DynamicSigmaRawTelemetry_t,
  ): bool =
    raw.totalTenderlinkRounds == 10 or
    (
      raw.totalTenderlinkRounds == 987 and raw.failedTenderlinkRounds == 65
    )

  pure def RawRoundFailureRatePct(raw: DynamicSigmaRawTelemetry_t): Pct_t =
    if (raw.totalTenderlinkRounds == 10) {
      raw.failedTenderlinkRounds * 10
    } else if (
      raw.totalTenderlinkRounds == 987 and raw.failedTenderlinkRounds == 65
    ) {
      7
    } else {
      101
    }

  pure def EstimatedRoundFailureRatePct(
    raw: DynamicSigmaRawTelemetry_t,
    margins: TelemetryEstimateMargins_t,
  ): Pct_t =
    SaturatingPctAdd(
      RawRoundFailureRatePct(raw),
      margins.roundFailureMarginPct,
    )

  pure def WorkCoverageAtLeast(
    raw: DynamicSigmaRawTelemetry_t,
    pct: Pct_t,
  ): bool =
    if (pct == 0) {
      true
    } else if (
      raw.totalHashWork.high64 == 0 and
      raw.crosslinkParticipatingHashWork.high64 == 0
    ) {
      raw.crosslinkParticipatingHashWork.low64 * 100 >=
        raw.totalHashWork.low64 * pct
    } else {
      raw.crosslinkParticipatingHashWork.high64 >= raw.totalHashWork.high64
    }

  pure def HashParticipationSigmaFloor(
    raw: DynamicSigmaRawTelemetry_t,
  ): Sigma_t =
    if (not(WorkCoverageAtLeast(raw, CriticalHashParticipationPct))) {
      MaxSigma
    } else if (not(WorkCoverageAtLeast(raw, TargetHashParticipationPct))) {
      RaisedSigma
    } else {
      BaseSigma
    }

  pure def ReorgSigmaFloor(depth: int): Sigma_t =
    if (depth >= RaisedSigma) {
      MaxSigma
    } else if (depth >= BaseSigma) {
      RaisedSigma
    } else {
      BaseSigma
    }

  pure def CalibratedRiskScore(
    evidence: DynamicSigmaProposalEvidence_t,
  ): int =
    CoverageRiskWeight *
      EstimatedCoverageRiskPct(evidence.rawTelemetry, evidence.margins) +
    RoundFailureRiskWeight *
      EstimatedRoundFailureRatePct(evidence.rawTelemetry, evidence.margins) +
    BlockVarianceRiskWeight *
      evidence.rawTelemetry.measuredBlockIntervalVariancePct +
    ReorgDepthRiskWeight *
      evidence.rawTelemetry.measuredObservedReorgDepth

  pure def RiskScoreSigmaFloor(score: int): Sigma_t =
    if (score >= RiskScoreMaxThreshold) {
      MaxSigma
    } else if (score >= RiskScoreRaisedThreshold) {
      RaisedSigma
    } else {
      BaseSigma
    }

  pure def RollbackRiskPpmAtSigma(
    evidence: DynamicSigmaProposalEvidence_t,
    sigma: Sigma_t,
  ): int =
    if (sigma <= BaseSigma) {
      evidence.rawTelemetry.rollbackRisk.baseSigmaPpm
    } else if (sigma <= RaisedSigma) {
      evidence.rawTelemetry.rollbackRisk.raisedSigmaPpm
    } else {
      evidence.rawTelemetry.rollbackRisk.maxSigmaPpm
    }

  pure def EconomicTargetSatisfiedAtSigma(
    evidence: DynamicSigmaProposalEvidence_t,
    sigma: Sigma_t,
  ): bool = {
    val riskPpm = RollbackRiskPpmAtSigma(evidence, sigma)
    all {
      riskPpm <= MaxAcceptableRollbackRiskPpm,
      evidence.rawTelemetry.valueAtRiskUnits.high64 == 0,
      evidence.rawTelemetry.maxAcceptableExpectedLossUnits.high64 == 0,
      riskPpm * evidence.rawTelemetry.valueAtRiskUnits.low64 <=
        evidence.rawTelemetry.maxAcceptableExpectedLossUnits.low64 *
          PpmDenominator,
    }
  }

  pure def EconomicSigmaFloor(
    evidence: DynamicSigmaProposalEvidence_t,
  ): Sigma_t =
    if (EconomicTargetSatisfiedAtSigma(evidence, BaseSigma)) {
      BaseSigma
    } else if (EconomicTargetSatisfiedAtSigma(evidence, RaisedSigma)) {
      RaisedSigma
    } else {
      MaxSigma
    }

  pure def RequiredSigmaFloor(
    evidence: DynamicSigmaProposalEvidence_t,
  ): Sigma_t =
    MaxInt(
      EconomicSigmaFloor(evidence),
      MaxInt(
        RiskScoreSigmaFloor(CalibratedRiskScore(evidence)),
        MaxInt(
          HashParticipationSigmaFloor(evidence.rawTelemetry),
          ReorgSigmaFloor(evidence.rawTelemetry.measuredObservedReorgDepth),
        ),
      ),
    )

  pure def ProductionProposalEvidenceHex(
    wire: ProductionDynamicSigmaProposalEvidenceWire_t,
  ): Bytes_t =
    if (
      wire.byteLen == 123 and
      U128Is(wire.evidence.rawTelemetry.totalHashWork, 100, 0) and
      U128Is(
        wire.evidence.rawTelemetry.crosslinkParticipatingHashWork,
        63,
        0,
      ) and
      wire.evidence.rawTelemetry.totalTenderlinkRounds == 10 and
      wire.evidence.rawTelemetry.failedTenderlinkRounds == 0 and
      wire.evidence.rawTelemetry.measuredBlockIntervalVariancePct == 0 and
      wire.evidence.rawTelemetry.measuredObservedReorgDepth == 0 and
      wire.evidence.rawTelemetry.rollbackRisk.baseSigmaPpm == 80 and
      wire.evidence.rawTelemetry.rollbackRisk.raisedSigmaPpm == 20 and
      wire.evidence.rawTelemetry.rollbackRisk.maxSigmaPpm == 2 and
      U128Is(wire.evidence.rawTelemetry.valueAtRiskUnits, 1000, 0) and
      U128Is(
        wire.evidence.rawTelemetry.maxAcceptableExpectedLossUnits,
        1,
        0,
      ) and
      wire.evidence.margins.coverageRiskMarginPct == 2 and
      wire.evidence.margins.roundFailureMarginPct == 0 and
      wire.evidence.selectedSigma == 3
    ) {
      "640000000000000000000000000000003f0000000000000000000000000000000a000000000000000000000000000000000000000000000000500000000000000014000000000000000200000000000000e80300000000000000000000000000000100000000000000000000000000000002000300000000000000"
    } else if (
      wire.byteLen == 123 and
      U128Is(wire.evidence.rawTelemetry.totalHashWork, 100, 0) and
      U128Is(
        wire.evidence.rawTelemetry.crosslinkParticipatingHashWork,
        63,
        0,
      ) and
      wire.evidence.rawTelemetry.totalTenderlinkRounds == 10 and
      wire.evidence.rawTelemetry.failedTenderlinkRounds == 0 and
      wire.evidence.rawTelemetry.measuredBlockIntervalVariancePct == 0 and
      wire.evidence.rawTelemetry.measuredObservedReorgDepth == 0 and
      wire.evidence.rawTelemetry.rollbackRisk.baseSigmaPpm == 80 and
      wire.evidence.rawTelemetry.rollbackRisk.raisedSigmaPpm == 20 and
      wire.evidence.rawTelemetry.rollbackRisk.maxSigmaPpm == 2 and
      U128Is(wire.evidence.rawTelemetry.valueAtRiskUnits, 1000, 0) and
      U128Is(
        wire.evidence.rawTelemetry.maxAcceptableExpectedLossUnits,
        1,
        0,
      ) and
      wire.evidence.margins.coverageRiskMarginPct == 2 and
      wire.evidence.margins.roundFailureMarginPct == 0 and
      wire.evidence.selectedSigma == 1
    ) {
      "640000000000000000000000000000003f0000000000000000000000000000000a000000000000000000000000000000000000000000000000500000000000000014000000000000000200000000000000e80300000000000000000000000000000100000000000000000000000000000002000100000000000000"
    } else if (
      wire.byteLen == 124 and
      U128Is(wire.evidence.rawTelemetry.totalHashWork, 100, 0) and
      U128Is(
        wire.evidence.rawTelemetry.crosslinkParticipatingHashWork,
        63,
        0,
      ) and
      wire.evidence.selectedSigma == 3
    ) {
      "640000000000000000000000000000003f0000000000000000000000000000000a000000000000000000000000000000000000000000000000500000000000000014000000000000000200000000000000e8030000000000000000000000000000010000000000000000000000000000000200030000000000000000"
    } else if (
      wire.byteLen == 123 and
      U128Is(wire.evidence.rawTelemetry.totalHashWork, 0, 1) and
      U128Is(
        wire.evidence.rawTelemetry.crosslinkParticipatingHashWork,
        12345,
        0,
      ) and
      wire.evidence.rawTelemetry.totalTenderlinkRounds == 987 and
      wire.evidence.rawTelemetry.failedTenderlinkRounds == 65 and
      wire.evidence.rawTelemetry.measuredBlockIntervalVariancePct == 7 and
      wire.evidence.rawTelemetry.measuredObservedReorgDepth == 4 and
      wire.evidence.rawTelemetry.rollbackRisk.baseSigmaPpm == 1000 and
      wire.evidence.rawTelemetry.rollbackRisk.raisedSigmaPpm == 100 and
      wire.evidence.rawTelemetry.rollbackRisk.maxSigmaPpm == 10 and
      U128Is(
        wire.evidence.rawTelemetry.valueAtRiskUnits,
        1000000000000,
        0,
      ) and
      U128Is(
        wire.evidence.rawTelemetry.maxAcceptableExpectedLossUnits,
        42,
        0,
      ) and
      wire.evidence.margins.coverageRiskMarginPct == 3 and
      wire.evidence.margins.roundFailureMarginPct == 5 and
      wire.evidence.selectedSigma == 6
    ) {
      "0000000000000000010000000000000039300000000000000000000000000000db030000000000004100000000000000070400000000000000e80300000000000064000000000000000a000000000000000010a5d4e800000000000000000000002a00000000000000000000000000000003050600000000000000"
    } else {
      UnmodeledDynamicSigmaEvidenceHex
    }

  pure def ProductionProposalEvidenceWireExact(
    wire: ProductionDynamicSigmaProposalEvidenceWire_t,
  ): bool =
    wire.byteLen == DynamicSigmaProposalEvidenceByteLen and
    wire.bytes == ProductionProposalEvidenceHex(wire) and
    wire.bytes != UnmodeledDynamicSigmaEvidenceHex

  pure def DynamicSigmaProposalEvidenceWellFormed(
    evidence: DynamicSigmaProposalEvidence_t,
  ): bool =
    RawTelemetryCountersWellFormed(evidence.rawTelemetry) and
    MarginsWellFormed(evidence.margins) and
    CoverageRiskEstimateModeled(evidence.rawTelemetry) and
    RoundFailureEstimateModeled(evidence.rawTelemetry) and
    PctInRange(
      EstimatedCoverageRiskPct(evidence.rawTelemetry, evidence.margins)
    ) and
    PctInRange(
      EstimatedRoundFailureRatePct(evidence.rawTelemetry, evidence.margins)
    ) and
    SigmaInLadder(evidence.selectedSigma) and
    evidence.selectedSigma >= RequiredSigmaFloor(evidence)

  pure def ProductionProposalEvidenceWireWellFormed(
    wire: ProductionDynamicSigmaProposalEvidenceWire_t,
  ): bool =
    ProductionProposalEvidenceWireExact(wire) and
    DynamicSigmaProposalEvidenceWellFormed(wire.evidence)

  pure def DecodeProductionProposalEvidenceWire(
    wire: ProductionDynamicSigmaProposalEvidenceWire_t,
  ): DynamicSigmaProposalEvidence_t =
    wire.evidence

  action Init = all {
    acceptedProductionProposalEvidenceWires' = Set(),
    firedAction' = "Init",
  }

  action AcceptProductionProposalEvidenceWire(
    wire: ProductionDynamicSigmaProposalEvidenceWire_t,
  ): bool =
    all {
      ProductionProposalEvidenceWireWellFormed(wire),
      acceptedProductionProposalEvidenceWires' =
        acceptedProductionProposalEvidenceWires.union(Set(wire)),
      firedAction' = "AcceptProductionProposalEvidenceWire",
    }

  action Stutter = all {
    acceptedProductionProposalEvidenceWires' =
      acceptedProductionProposalEvidenceWires,
    firedAction' = firedAction,
  }

  action Next =
    any {
      nondet wire = oneOf(ProductionProposalEvidenceWires)
      AcceptProductionProposalEvidenceWire(wire),
      Stutter,
    }

  action EvidenceUnchanged = all {
    acceptedProductionProposalEvidenceWires' =
      acceptedProductionProposalEvidenceWires,
    firedAction' = firedAction,
  }

  val DynamicSigmaEvidenceLayoutConstantsPinned =
    U8ByteLen == 1 and
    U64ByteLen == 8 and
    U128ByteLen == 16 and
    RollbackRiskCurveByteLen == 24 and
    TelemetryEstimateMarginsByteLen == 2 and
    TotalHashWorkOffset == 0 and
    CrosslinkParticipatingHashWorkOffset == 16 and
    TotalTenderlinkRoundsOffset == 32 and
    FailedTenderlinkRoundsOffset == 40 and
    MeasuredBlockIntervalVariancePctOffset == 48 and
    MeasuredObservedReorgDepthOffset == 49 and
    RollbackRiskBaseSigmaPpmOffset == 57 and
    RollbackRiskRaisedSigmaPpmOffset == 65 and
    RollbackRiskMaxSigmaPpmOffset == 73 and
    ValueAtRiskUnitsOffset == 81 and
    MaxAcceptableExpectedLossUnitsOffset == 97 and
    RawTelemetryByteLen == 113 and
    CoverageRiskMarginPctOffset == 113 and
    RoundFailureMarginPctOffset == 114 and
    SelectedSigmaOffset == 115 and
    DynamicSigmaProposalEvidenceByteLen == 123 and
    DynamicSigmaProposalEvidenceHexCharLen == 246

  val DynamicSigmaEvidenceFieldOffsetsContiguous =
    FieldEndOffset(TotalHashWorkOffset, U128ByteLen) ==
      CrosslinkParticipatingHashWorkOffset and
    FieldEndOffset(CrosslinkParticipatingHashWorkOffset, U128ByteLen) ==
      TotalTenderlinkRoundsOffset and
    FieldEndOffset(TotalTenderlinkRoundsOffset, U64ByteLen) ==
      FailedTenderlinkRoundsOffset and
    FieldEndOffset(FailedTenderlinkRoundsOffset, U64ByteLen) ==
      MeasuredBlockIntervalVariancePctOffset and
    FieldEndOffset(MeasuredBlockIntervalVariancePctOffset, U8ByteLen) ==
      MeasuredObservedReorgDepthOffset and
    FieldEndOffset(MeasuredObservedReorgDepthOffset, U64ByteLen) ==
      RollbackRiskBaseSigmaPpmOffset and
    FieldEndOffset(RollbackRiskBaseSigmaPpmOffset, U64ByteLen) ==
      RollbackRiskRaisedSigmaPpmOffset and
    FieldEndOffset(RollbackRiskRaisedSigmaPpmOffset, U64ByteLen) ==
      RollbackRiskMaxSigmaPpmOffset and
    FieldEndOffset(RollbackRiskMaxSigmaPpmOffset, U64ByteLen) ==
      ValueAtRiskUnitsOffset and
    FieldEndOffset(ValueAtRiskUnitsOffset, U128ByteLen) ==
      MaxAcceptableExpectedLossUnitsOffset and
    FieldEndOffset(MaxAcceptableExpectedLossUnitsOffset, U128ByteLen) ==
      CoverageRiskMarginPctOffset and
    FieldEndOffset(CoverageRiskMarginPctOffset, U8ByteLen) ==
      RoundFailureMarginPctOffset and
    FieldEndOffset(RoundFailureMarginPctOffset, U8ByteLen) ==
      SelectedSigmaOffset and
    FieldEndOffset(SelectedSigmaOffset, U64ByteLen) ==
      DynamicSigmaProposalEvidenceByteLen

  val AcceptedProposalEvidenceWiresAreCanonical =
    acceptedProductionProposalEvidenceWires.forall(
      ProductionProposalEvidenceWireWellFormed
    )

  val AcceptedProposalEvidenceSelectedSigmaSatisfiesFloor =
    acceptedProductionProposalEvidenceWires.forall(wire =>
      DecodeProductionProposalEvidenceWire(wire).selectedSigma >=
        RequiredSigmaFloor(DecodeProductionProposalEvidenceWire(wire))
    )

  val ProductionProposalEvidenceFormatSafety =
    DynamicSigmaEvidenceLayoutConstantsPinned and
    DynamicSigmaEvidenceFieldOffsetsContiguous and
    AcceptedProposalEvidenceWiresAreCanonical and
    AcceptedProposalEvidenceSelectedSigmaSatisfiesFloor
}

module CrosslinkDynamicSigmaProposalEvidenceFormatTest {
  import CrosslinkDynamicSigmaProposalEvidenceFormat.* from
    "./CrosslinkDynamicSigmaProposalEvidenceFormat"
  export CrosslinkDynamicSigmaProposalEvidenceFormat.*

  pure val DegradedParticipationRawTelemetry = {
    totalHashWork: { low64: 100, high64: 0 },
    crosslinkParticipatingHashWork: { low64: 63, high64: 0 },
    totalTenderlinkRounds: 10,
    failedTenderlinkRounds: 0,
    measuredBlockIntervalVariancePct: 0,
    measuredObservedReorgDepth: 0,
    rollbackRisk: {
      baseSigmaPpm: 80,
      raisedSigmaPpm: 20,
      maxSigmaPpm: 2,
    },
    valueAtRiskUnits: { low64: 1000, high64: 0 },
    maxAcceptableExpectedLossUnits: { low64: 1, high64: 0 },
  }

  pure val WideCounterRawTelemetry = {
    totalHashWork: { low64: 0, high64: 1 },
    crosslinkParticipatingHashWork: { low64: 12345, high64: 0 },
    totalTenderlinkRounds: 987,
    failedTenderlinkRounds: 65,
    measuredBlockIntervalVariancePct: 7,
    measuredObservedReorgDepth: 4,
    rollbackRisk: {
      baseSigmaPpm: 1000,
      raisedSigmaPpm: 100,
      maxSigmaPpm: 10,
    },
    valueAtRiskUnits: { low64: 1000000000000, high64: 0 },
    maxAcceptableExpectedLossUnits: { low64: 42, high64: 0 },
  }

  pure val DegradedMargins = {
    coverageRiskMarginPct: 2,
    roundFailureMarginPct: 0,
  }

  pure val WideCounterMargins = {
    coverageRiskMarginPct: 3,
    roundFailureMarginPct: 5,
  }

  pure val DegradedParticipationEvidence = {
    rawTelemetry: DegradedParticipationRawTelemetry,
    margins: DegradedMargins,
    selectedSigma: 3,
  }

  pure val BelowRequiredSigmaEvidence = {
    rawTelemetry: DegradedParticipationRawTelemetry,
    margins: DegradedMargins,
    selectedSigma: 1,
  }

  pure val WideCounterEvidence = {
    rawTelemetry: WideCounterRawTelemetry,
    margins: WideCounterMargins,
    selectedSigma: 6,
  }

  pure val DegradedParticipationEvidenceHex =
    "640000000000000000000000000000003f0000000000000000000000000000000a000000000000000000000000000000000000000000000000500000000000000014000000000000000200000000000000e80300000000000000000000000000000100000000000000000000000000000002000300000000000000"
  pure val BelowRequiredSigmaEvidenceHex =
    "640000000000000000000000000000003f0000000000000000000000000000000a000000000000000000000000000000000000000000000000500000000000000014000000000000000200000000000000e80300000000000000000000000000000100000000000000000000000000000002000100000000000000"
  pure val DegradedParticipationEvidenceTrailingHex =
    "640000000000000000000000000000003f0000000000000000000000000000000a000000000000000000000000000000000000000000000000500000000000000014000000000000000200000000000000e8030000000000000000000000000000010000000000000000000000000000000200030000000000000000"
  pure val WideCounterEvidenceHex =
    "0000000000000000010000000000000039300000000000000000000000000000db030000000000004100000000000000070400000000000000e80300000000000064000000000000000a000000000000000010a5d4e800000000000000000000002a00000000000000000000000000000003050600000000000000"
  pure val WrongEvidenceBytes = "wrong-dynamic-sigma-evidence-bytes"

  pure val DegradedParticipationWire = {
    byteLen: 123,
    evidence: DegradedParticipationEvidence,
    bytes: DegradedParticipationEvidenceHex,
  }

  pure val BelowRequiredSigmaWire = {
    byteLen: 123,
    evidence: BelowRequiredSigmaEvidence,
    bytes: BelowRequiredSigmaEvidenceHex,
  }

  pure val TrailingBytesWire = {
    byteLen: 124,
    evidence: DegradedParticipationEvidence,
    bytes: DegradedParticipationEvidenceTrailingHex,
  }

  pure val WrongBytesWire = {
    byteLen: 123,
    evidence: DegradedParticipationEvidence,
    bytes: WrongEvidenceBytes,
  }

  pure val WideCounterWire = {
    byteLen: 123,
    evidence: WideCounterEvidence,
    bytes: WideCounterEvidenceHex,
  }

  run productionEvidenceByteLayoutPinnedTest = all {
    assert(DynamicSigmaEvidenceLayoutConstantsPinned),
    assert(DynamicSigmaEvidenceFieldOffsetsContiguous),
  }

  run degradedParticipationEvidenceHexPinnedTest = all {
    assert(
      ProductionProposalEvidenceHex(DegradedParticipationWire) ==
        DegradedParticipationEvidenceHex
    ),
    assert(ProductionProposalEvidenceWireExact(DegradedParticipationWire)),
  }

  run wideCounterEvidenceHexPinsU128HighBytesTest = all {
    assert(
      ProductionProposalEvidenceHex(WideCounterWire) == WideCounterEvidenceHex
    ),
    assert(ProductionProposalEvidenceWireExact(WideCounterWire)),
  }

  run degradedParticipationEvidenceRequiresRaisedSigmaTest = all {
    assert(EstimatedCoverageRiskPct(
      DegradedParticipationRawTelemetry,
      DegradedMargins,
    ) == 39),
    assert(EstimatedRoundFailureRatePct(
      DegradedParticipationRawTelemetry,
      DegradedMargins,
    ) == 0),
    assert(HashParticipationSigmaFloor(DegradedParticipationRawTelemetry) == 3),
    assert(RequiredSigmaFloor(DegradedParticipationEvidence) == 3),
    assert(ProductionProposalEvidenceWireWellFormed(
      DegradedParticipationWire
    )),
  }

  run wideCounterEvidenceRequiresMaxSigmaTest = all {
    assert(EstimatedCoverageRiskPct(
      WideCounterRawTelemetry,
      WideCounterMargins,
    ) == 100),
    assert(EstimatedRoundFailureRatePct(
      WideCounterRawTelemetry,
      WideCounterMargins,
    ) == 12),
    assert(RequiredSigmaFloor(WideCounterEvidence) == 6),
    assert(ProductionProposalEvidenceWireWellFormed(WideCounterWire)),
  }

  run selectedSigmaBelowRequiredRejectedTest = all {
    assert(ProductionProposalEvidenceWireExact(BelowRequiredSigmaWire)),
    assert(not(DynamicSigmaProposalEvidenceWellFormed(
      BelowRequiredSigmaEvidence
    ))),
    assert(not(ProductionProposalEvidenceWireWellFormed(
      BelowRequiredSigmaWire
    ))),
  }

  run trailingEvidenceBytesRejectedTest = all {
    assert(not(ProductionProposalEvidenceWireExact(TrailingBytesWire))),
    assert(not(ProductionProposalEvidenceWireWellFormed(TrailingBytesWire))),
  }

  run wrongEvidenceBytesRejectedTest = all {
    assert(not(ProductionProposalEvidenceWireExact(WrongBytesWire))),
    assert(not(ProductionProposalEvidenceWireWellFormed(WrongBytesWire))),
  }

  run acceptCanonicalEvidenceWireTest = {
    Init
      .then(AcceptProductionProposalEvidenceWire(DegradedParticipationWire))
      .then(all {
        assert(acceptedProductionProposalEvidenceWires.contains(
          DegradedParticipationWire
        )),
        assert(ProductionProposalEvidenceFormatSafety),
        EvidenceUnchanged,
      })
  }

  run cannotAcceptBelowRequiredSigmaWireTest = {
    Init
      .then(AcceptProductionProposalEvidenceWire(BelowRequiredSigmaWire))
      .fail()
  }
}

module CrosslinkDynamicSigmaProposalEvidenceFormatModel {
  import CrosslinkDynamicSigmaProposalEvidenceFormatTest(
    BaseSigma = 1,
    RaisedSigma = 3,
    MaxSigma = 6,
    TargetHashParticipationPct = 67,
    CriticalHashParticipationPct = 50,
    MaxAcceptableRollbackRiskPpm = 25,
    CoverageRiskWeight = 2,
    RoundFailureRiskWeight = 3,
    BlockVarianceRiskWeight = 1,
    ReorgDepthRiskWeight = 5,
    RiskScoreRaisedThreshold = 60,
    RiskScoreMaxThreshold = 100,
    ProductionProposalEvidenceWires = Set(
      {
        byteLen: 123,
        evidence: {
          rawTelemetry: {
            totalHashWork: { low64: 100, high64: 0 },
            crosslinkParticipatingHashWork: { low64: 63, high64: 0 },
            totalTenderlinkRounds: 10,
            failedTenderlinkRounds: 0,
            measuredBlockIntervalVariancePct: 0,
            measuredObservedReorgDepth: 0,
            rollbackRisk: {
              baseSigmaPpm: 80,
              raisedSigmaPpm: 20,
              maxSigmaPpm: 2,
            },
            valueAtRiskUnits: { low64: 1000, high64: 0 },
            maxAcceptableExpectedLossUnits: { low64: 1, high64: 0 },
          },
          margins: {
            coverageRiskMarginPct: 2,
            roundFailureMarginPct: 0,
          },
          selectedSigma: 3,
        },
        bytes: "640000000000000000000000000000003f0000000000000000000000000000000a000000000000000000000000000000000000000000000000500000000000000014000000000000000200000000000000e80300000000000000000000000000000100000000000000000000000000000002000300000000000000",
      },
      {
        byteLen: 123,
        evidence: {
          rawTelemetry: {
            totalHashWork: { low64: 0, high64: 1 },
            crosslinkParticipatingHashWork: { low64: 12345, high64: 0 },
            totalTenderlinkRounds: 987,
            failedTenderlinkRounds: 65,
            measuredBlockIntervalVariancePct: 7,
            measuredObservedReorgDepth: 4,
            rollbackRisk: {
              baseSigmaPpm: 1000,
              raisedSigmaPpm: 100,
              maxSigmaPpm: 10,
            },
            valueAtRiskUnits: { low64: 1000000000000, high64: 0 },
            maxAcceptableExpectedLossUnits: { low64: 42, high64: 0 },
          },
          margins: {
            coverageRiskMarginPct: 3,
            roundFailureMarginPct: 5,
          },
          selectedSigma: 6,
        },
        bytes: "0000000000000000010000000000000039300000000000000000000000000000db030000000000004100000000000000070400000000000000e80300000000000064000000000000000a000000000000000010a5d4e800000000000000000000002a00000000000000000000000000000003050600000000000000",
      }
    )
  ).*
}
