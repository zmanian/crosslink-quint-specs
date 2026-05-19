module CrosslinkFixtureAuthenticatedEvidence {
  /*
   Generated-fixture bridge into the authenticated fat-pointer pipeline.

   This model takes the one-signature checked-in production fixture constants
   generated from crosslink-test-data/test_pos_block_*.bin and routes the
   corresponding fat-pointer wire through the authenticated observer rules.
   Signatures remain abstract, but the manifest also records the real fixture
   pubkey, vote payload, vote signature, and sign-data byte strings for
   implementation-level verification.
   */

  import CrosslinkFatPointerAuthenticatedEvidence.* from "./CrosslinkFatPointerAuthenticatedEvidence"
  import CrosslinkProductionFixtureVectorsGenerated.* from "./CrosslinkProductionFixtureVectorsGenerated"

  export CrosslinkFatPointerAuthenticatedEvidence.*
  export CrosslinkProductionFixtureVectorsGenerated.*

  pure val FixtureBftHeight = 1
  pure val FixtureRound = 0
  pure val FixtureBlockHash = "fixture-bft-block"
  pure val FixturePubKey = "fixture-pubkey"
  pure val FixtureSignBytes = "fixture-sign-bytes"
  pure val FixtureVoteSignature = "fixture-vote-signature"

  pure val FixtureTrailingFatPointerWireByteLen =
    FixtureLaterBftBlockAndFatPointerByteLen -
    CheckedInFixtureTrailingFatPointerOffset

  def FixtureSig: FatPointerSignature_t = {
    pubKey: FixturePubKey,
    signedBytes: FixtureSignBytes,
    voteSignature: FixtureVoteSignature,
  }

  def FixtureCommit: RoundCommit_t = {
    pubKey: FixturePubKey,
    blockHash: FixtureBlockHash,
    signedBytes: FixtureSignBytes,
    voteSignature: FixtureVoteSignature,
  }

  def FixtureFatPointer: FatPointer_t = {
    height: FixtureBftHeight,
    round: FixtureRound,
    blockHash: FixtureBlockHash,
    signatureCount: CheckedInFixtureSignatureCount,
    signatures: Map(0 -> FixtureSig),
  }

  def FixtureWire: FatPointerWire_t = {
    fatPointer: FixtureFatPointer,
    byteLen: FixtureTrailingFatPointerWireByteLen,
  }

  val GeneratedFixtureWireConstantsCoherent =
    CheckedInFixtureSignatureCount == 1 and
    CheckedInFixtureTrailingSignatureCountByte0 == 1 and
    CheckedInFixtureTrailingSignatureCountByte1 == 0 and
    CheckedInFixtureTrailingPayloadFirstByte == 253 and
    CheckedInFixtureTrailingPayloadLastByte == 128 and
    CheckedInFixtureSignerPubKeyFirstByte == 240 and
    CheckedInFixtureTrailingSignatureFirstByte == 60 and
    CheckedInFixtureTrailingSignatureLastByte == 15 and
    FixtureTrailingFatPointerWireByteLen == 142 and
    FatPointerWireByteLen(FixtureFatPointer) == FixtureTrailingFatPointerWireByteLen

  action FixtureNext: bool =
    any {
      GossipProductionPrecommit(FixtureBftHeight, FixtureRound, FixtureCommit),
      ObserveProductionFatPointerWire(FixtureWire),
      PipelineStutter,
    }

  action unchangedAll = all {
    acceptedFatPointers' = acceptedFatPointers,
    acceptedFatPointerWires' = acceptedFatPointerWires,
    gossipedPrecommit' = gossipedPrecommit,
    observedProductionFatPointer' = observedProductionFatPointer,
    observedProductionFatPointerWire' = observedProductionFatPointerWire,
    firedAction' = firedAction,
  }

  val FixtureSafety =
    PipelineSafety and
    GeneratedFixtureWireConstantsCoherent
}

module CrosslinkFixtureAuthenticatedEvidenceTest {
  import CrosslinkFixtureAuthenticatedEvidence.* from "./CrosslinkFixtureAuthenticatedEvidence"
  export CrosslinkFixtureAuthenticatedEvidence.*

  run generatedFixtureWireConstantsAreCoherentTest = {
    PipelineInit
      .then(all {
        assert(GeneratedFixtureWireConstantsCoherent),
        assert(FixtureWire.byteLen == 142),
        assert(FixtureFatPointer.signatureCount == 1),
        unchangedAll,
      })
  }

  run generatedFixtureWireObservedAfterGossipTest = {
    PipelineInit
      .then(GossipProductionPrecommit(FixtureBftHeight, FixtureRound, FixtureCommit))
      .then(ObserveProductionFatPointerWire(FixtureWire))
      .then(all {
        assert(observedProductionFatPointerWire.contains(FixtureWire)),
        assert(observedProductionFatPointer.contains(FixtureFatPointer)),
        assert(acceptedFatPointerWires.contains(FixtureWire)),
        assert(acceptedFatPointers.contains(FixtureFatPointer)),
        assert(FixtureSafety),
        unchangedAll,
      })
  }

  run generatedFixtureWireRejectedBeforeGossipTest = {
    PipelineInit
      .then(ObserveProductionFatPointerWire(FixtureWire))
      .fail()
  }
}

module CrosslinkFixtureAuthenticatedEvidenceModel {
  import CrosslinkFixtureAuthenticatedEvidenceTest(
    Validators = Set("fixture-validator"),
    PubKeys = Set("fixture-pubkey"),
    VotingPower = Map("fixture-validator" -> 3),
    QuorumVotingPower = 3,
    MaxBftHeight = 1,
    MaxRound = 0,
    MaxSignatures = 1,
    NilBlockHash = "nil",
    AuthorizedAt = Map(1 -> Set("fixture-validator")),
    PubKeyOwner = Map("fixture-pubkey" -> "fixture-validator"),
    FatPointerSignBytes = Map(
      1 -> Map(
        0 -> Map(
          "fixture-bft-block" -> Map(
            "fixture-pubkey" -> "fixture-sign-bytes",
          ),
        ),
      ),
    ),
    SignatureVerifier = Map(
      "fixture-pubkey" -> Map(
        "fixture-sign-bytes" -> "fixture-vote-signature",
      ),
    ),
  ).*
}
