module CrosslinkPowFixtureMeasuredDistribution {
  /*
   Measured PoW fixture interval contract.

   This is deliberately narrower than CrosslinkPowStochasticAssumptions.qnt.
   It imports checked-in raw PoW block fixture metadata generated from
   zebra-crosslink/crosslink-test-data/test_pow_block_*.bin and records the
   observed header-time distribution for those fixtures. These samples are
   production-serialization fixtures, not live mainnet calibration data: the
   current checked-in fixture stream has many zero-second adjacent samples and
   several 5400-second jumps.
   */

  import CrosslinkProductionFixtureVectorsGenerated.* from "./CrosslinkProductionFixtureVectorsGenerated"
  export CrosslinkProductionFixtureVectorsGenerated.*

  const PowTargetSpacingSeconds: int

  pure val U32ByteLen = 4
  pure val ZcashHeaderVersionByteLen = 4
  pure val ZcashHeaderHashByteLen = 32
  pure val ZcashHeaderTimeOffset =
    ZcashHeaderVersionByteLen + 3 * ZcashHeaderHashByteLen

  pure val MeasuredAverageCheckedIntervalNumerator =
    GeneratedPowBlockSumCheckedIntervalSeconds
  pure val MeasuredAverageCheckedIntervalDenominator =
    GeneratedPowBlockCheckedIntervalCount

  assume target_spacing_matches_zebra_post_blossom =
    PowTargetSpacingSeconds == 75
  assume checked_interval_domain_is_nonempty =
    GeneratedPowBlockCheckedIntervalCount > 0

  val HeaderTimeOffsetMatchesZcashHeaderLayout =
    GeneratedPowBlockHeaderTimeOffset == ZcashHeaderTimeOffset and
    GeneratedPowBlockHeaderTimeOffset == 100 and
    GeneratedPowBlockHeaderTimeOffset + U32ByteLen <=
      FixtureFirstPowBlockHeaderByteLen

  val CheckedInFixtureIntervalDistributionPinned =
    GeneratedPowBlockFixtureCount == 24 and
    GeneratedPowBlockObservedHeightSpan ==
      FixtureLastPowBlockHeight - FixtureFirstPowBlockHeight and
    GeneratedPowBlockObservedHeightSpan == 29 and
    GeneratedPowBlockCheckedIntervalCount ==
      GeneratedPowBlockFixtureCount - 1 and
    GeneratedPowBlockCheckedIntervalCount == 23 and
    GeneratedPowBlockObservedSpanSeconds ==
      GeneratedPowBlockLastHeaderTime - GeneratedPowBlockFirstHeaderTime and
    GeneratedPowBlockObservedSpanSeconds == 27000 and
    GeneratedPowBlockSumCheckedIntervalSeconds ==
      GeneratedPowBlockObservedSpanSeconds and
    GeneratedPowBlockMinCheckedIntervalSeconds == 0 and
    GeneratedPowBlockMaxCheckedIntervalSeconds == 5400 and
    GeneratedPowBlockIntervalAtOrBelowTargetCount == 18 and
    GeneratedPowBlockIntervalAboveTargetCount == 5 and
    GeneratedPowBlockZeroSecondIntervalCount == 18 and
    GeneratedPowBlockTargetMultipleIntervalCount ==
      GeneratedPowBlockCheckedIntervalCount and
    GeneratedPowBlockMaxCheckedHeightGap == 2 and
    GeneratedPowBlockSumCheckedHeightGaps ==
      GeneratedPowBlockObservedHeightSpan

  val IntervalBucketCountsCoverAllCheckedIntervals =
    GeneratedPowBlockIntervalAtOrBelowTargetCount +
      GeneratedPowBlockIntervalAboveTargetCount ==
      GeneratedPowBlockCheckedIntervalCount and
    GeneratedPowBlockZeroSecondIntervalCount <=
      GeneratedPowBlockIntervalAtOrBelowTargetCount

  val MeasuredAverageIntervalRatioPinned =
    MeasuredAverageCheckedIntervalNumerator ==
      GeneratedPowBlockObservedSpanSeconds and
    MeasuredAverageCheckedIntervalDenominator ==
      GeneratedPowBlockCheckedIntervalCount and
    MeasuredAverageCheckedIntervalNumerator >
      PowTargetSpacingSeconds * MeasuredAverageCheckedIntervalDenominator

  val FixtureDistributionIsNotMainnetCalibration =
    GeneratedPowBlockZeroSecondIntervalCount > 0 and
    GeneratedPowBlockMaxCheckedIntervalSeconds > PowTargetSpacingSeconds and
    MeasuredAverageIntervalRatioPinned

  val Safety =
    HeaderTimeOffsetMatchesZcashHeaderLayout and
    CheckedInFixtureIntervalDistributionPinned and
    IntervalBucketCountsCoverAllCheckedIntervals and
    MeasuredAverageIntervalRatioPinned and
    FixtureDistributionIsNotMainnetCalibration

  var checked: bool

  action Init = all {
    checked' = false,
  }

  action Next = all {
    checked' = checked,
  }
}

module CrosslinkPowFixtureMeasuredDistributionTest {
  import CrosslinkPowFixtureMeasuredDistribution.* from "./CrosslinkPowFixtureMeasuredDistribution"
  export CrosslinkPowFixtureMeasuredDistribution.*

  action unchangedAll = all {
    checked' = checked,
  }

  run headerTimeOffsetPinsZcashHeaderLayoutTest = {
    Init
      .then(all {
        assert(GeneratedPowBlockHeaderTimeOffset == 100),
        assert(HeaderTimeOffsetMatchesZcashHeaderLayout),
        unchangedAll,
      })
  }

  run checkedInFixtureIntervalsArePinnedTest = {
    Init
      .then(all {
        assert(GeneratedPowBlockCheckedIntervalCount == 23),
        assert(GeneratedPowBlockObservedSpanSeconds == 27000),
        assert(GeneratedPowBlockMaxCheckedIntervalSeconds == 5400),
        assert(GeneratedPowBlockSumCheckedHeightGaps == 29),
        assert(CheckedInFixtureIntervalDistributionPinned),
        unchangedAll,
      })
  }

  run fixtureIntervalBucketsCoverSamplesTest = {
    Init
      .then(all {
        assert(GeneratedPowBlockIntervalAtOrBelowTargetCount == 18),
        assert(GeneratedPowBlockIntervalAboveTargetCount == 5),
        assert(IntervalBucketCountsCoverAllCheckedIntervals),
        unchangedAll,
      })
  }

  run fixtureDistributionIsNotMainnetCalibrationTest = {
    Init
      .then(all {
        assert(GeneratedPowBlockZeroSecondIntervalCount == 18),
        assert(
          GeneratedPowBlockSumCheckedIntervalSeconds >
            PowTargetSpacingSeconds * GeneratedPowBlockCheckedIntervalCount
        ),
        assert(FixtureDistributionIsNotMainnetCalibration),
        unchangedAll,
      })
  }

  run powFixtureMeasuredDistributionSafetyTest = {
    Init
      .then(all {
        assert(Safety),
        unchangedAll,
      })
  }
}

module CrosslinkPowFixtureMeasuredDistributionModel {
  import CrosslinkPowFixtureMeasuredDistributionTest(
    PowTargetSpacingSeconds = 75,
  ).*
}
