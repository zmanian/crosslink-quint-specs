module CrosslinkFatPointerFormat {
  /*
   Production-shaped fat-pointer signer format.

   Zebra's FatPointerToBftBlock2 is serialized as:
   - a 44-byte vote payload suffix: value hash, height, and round/type bits,
   - a little-endian u16 signature count,
   - then one 96-byte entry per signer: 32-byte pubkey + 64-byte vote signature.

   This model keeps byte lengths abstract, but makes the counted signer vector,
   duplicate-pubkey rejection, height-scoped authorization, and canonical signed
   bytes explicit.
   */

  type Proc_t = str
  type PubKey_t = str
  type Bytes_t = str
  type Signature_t = str
  type Height_t = int
  type Round_t = int
  type BlockHash_t = str
  type SigIndex_t = int

  const Validators: Set[Proc_t]
  const PubKeys: Set[PubKey_t]
  const VotingPower: Proc_t -> int
  const QuorumVotingPower: int
  const MaxBftHeight: Height_t
  const MaxRound: Round_t
  const MaxSignatures: int
  const NilBlockHash: BlockHash_t
  const AuthorizedAt: Height_t -> Set[Proc_t]
  const PubKeyOwner: PubKey_t -> Proc_t
  const FatPointerSignBytes: Height_t -> Round_t -> BlockHash_t -> PubKey_t -> Bytes_t
  const SignatureVerifier: PubKey_t -> Bytes_t -> Signature_t

  pure val Heights = 1.to(MaxBftHeight)
  pure val Rounds = 0.to(MaxRound)
  pure val SigIndexes = 0.to(MaxSignatures - 1)
  pure val VotePayloadWithoutSignerByteLen = 44
  pure val SignatureCountByteLen = 2
  pure val MaxU16 = 65535
  pure val PubKeyByteLen = 32
  pure val VoteSignatureByteLen = 64
  pure val SignatureEntryByteLen = PubKeyByteLen + VoteSignatureByteLen
  pure val VotePayloadOffset = 0
  pure val SignatureCountOffset = VotePayloadWithoutSignerByteLen
  pure val SignatureEntriesOffset = SignatureCountOffset + SignatureCountByteLen

  assume max_signatures_positive =
    MaxSignatures >= 1
  assume validators_have_positive_power =
    Validators.forall(p => VotingPower.get(p) > 0)
  assume pubkeys_have_validator_owners =
    PubKeys.forall(pk => Validators.contains(PubKeyOwner.get(pk)))
  assume authorized_validators_are_known =
    Heights.forall(h => AuthorizedAt.get(h).subseteq(Validators))
  assume max_signatures_fit_u16_count =
    MaxSignatures <= MaxU16

  type FatPointerSignature_t = {
    pubKey: PubKey_t,
    signedBytes: Bytes_t,
    voteSignature: Signature_t,
  }

  type FatPointer_t = {
    height: Height_t,
    round: Round_t,
    blockHash: BlockHash_t,
    signatureCount: int,
    signatures: SigIndex_t -> FatPointerSignature_t,
  }

  type RoundCommit_t = {
    pubKey: PubKey_t,
    blockHash: BlockHash_t,
    signedBytes: Bytes_t,
    voteSignature: Signature_t,
  }

  type RoundData_t = {
    height: Height_t,
    round: Round_t,
    proposalBlockHash: BlockHash_t,
    commitVotes: SigIndex_t -> RoundCommit_t,
  }

  type FatPointerWire_t = {
    fatPointer: FatPointer_t,
    byteLen: int,
  }

  var acceptedFatPointers: Set[FatPointer_t]
  var acceptedFatPointerWires: Set[FatPointerWire_t]
  var firedAction: str

  pure def VotingPowerOf(voters: Set[Proc_t]): int =
    voters.fold(0, (acc, p) => acc + VotingPower.get(p))

  pure def ActiveSigIndexes(fp: FatPointer_t): Set[SigIndex_t] =
    SigIndexes.filter(i => i < fp.signatureCount)

  pure def FatPointerWireByteLen(fp: FatPointer_t): int =
    VotePayloadWithoutSignerByteLen +
    SignatureCountByteLen +
    fp.signatureCount * SignatureEntryByteLen

  pure def SignatureEntryOffset(i: SigIndex_t): int =
    SignatureEntriesOffset + i * SignatureEntryByteLen

  pure def SignatureEntryPubKeyOffset(i: SigIndex_t): int =
    SignatureEntryOffset(i)

  pure def SignatureEntryVoteSignatureOffset(i: SigIndex_t): int =
    SignatureEntryOffset(i) + PubKeyByteLen

  pure def SignatureEntryEndOffset(i: SigIndex_t): int =
    SignatureEntryOffset(i) + SignatureEntryByteLen

  def SignatureCountInRange(fp: FatPointer_t): bool =
    fp.signatureCount >= 0 and
    fp.signatureCount <= MaxSignatures and
    fp.signatureCount <= MaxU16

  def ProductionByteLayoutMatchesImplementation: bool =
    VotePayloadOffset == 0 and
    VotePayloadWithoutSignerByteLen == 44 and
    SignatureCountByteLen == 2 and
    SignatureCountOffset == 44 and
    SignatureEntriesOffset == 46 and
    PubKeyByteLen == 32 and
    VoteSignatureByteLen == 64 and
    SignatureEntryByteLen == 96

  def FatPointerWireEnvelopeValid(wire: FatPointerWire_t): bool =
    wire.byteLen == FatPointerWireByteLen(wire.fatPointer)

  def SignaturePubKeysKnown(fp: FatPointer_t): bool =
    ActiveSigIndexes(fp).forall(i =>
      PubKeys.contains(fp.signatures.get(i).pubKey)
    )

  def SignaturePubKeysUnique(fp: FatPointer_t): bool =
    ActiveSigIndexes(fp).forall(i =>
      ActiveSigIndexes(fp).forall(j =>
        i == j or fp.signatures.get(i).pubKey != fp.signatures.get(j).pubKey
      )
    )

  def SignatureAuthorizedAtHeight(fp: FatPointer_t, sig: FatPointerSignature_t): bool =
    AuthorizedAt.get(fp.height).contains(PubKeyOwner.get(sig.pubKey))

  def SignatureBytesCanonical(fp: FatPointer_t, sig: FatPointerSignature_t): bool =
    sig.signedBytes ==
    FatPointerSignBytes.get(fp.height).get(fp.round).get(fp.blockHash).get(sig.pubKey)

  def SignatureAuthentic(sig: FatPointerSignature_t): bool =
    sig.voteSignature == SignatureVerifier.get(sig.pubKey).get(sig.signedBytes)

  def ActiveSignaturesValid(fp: FatPointer_t): bool =
    ActiveSigIndexes(fp).forall(i => {
      val sig = fp.signatures.get(i)
      all {
        SignatureAuthorizedAtHeight(fp, sig),
        SignatureBytesCanonical(fp, sig),
        SignatureAuthentic(sig),
      }
    })

  def SignerPower(fp: FatPointer_t): int =
    VotingPowerOf(ActiveSigIndexes(fp).map(i =>
      PubKeyOwner.get(fp.signatures.get(i).pubKey)
    ))

  def FatPointerFormatValid(fp: FatPointer_t): bool =
    Heights.contains(fp.height) and
    Rounds.contains(fp.round) and
    fp.blockHash != NilBlockHash and
    ProductionByteLayoutMatchesImplementation and
    SignatureCountInRange(fp) and
    SignaturePubKeysKnown(fp) and
    SignaturePubKeysUnique(fp) and
    ActiveSignaturesValid(fp) and
    SignerPower(fp) >= QuorumVotingPower

  def RoundCommitCanonical(rd: RoundData_t, commit: RoundCommit_t): bool =
    commit.signedBytes ==
    FatPointerSignBytes.get(rd.height).get(rd.round).get(rd.proposalBlockHash).get(commit.pubKey)

  def RoundCommitAuthentic(commit: RoundCommit_t): bool =
    commit.voteSignature == SignatureVerifier.get(commit.pubKey).get(commit.signedBytes)

  def RoundCommitMatchesProposal(rd: RoundData_t, commit: RoundCommit_t): bool =
    commit.blockHash == rd.proposalBlockHash and
    commit.blockHash != NilBlockHash and
    PubKeys.contains(commit.pubKey) and
    RoundCommitCanonical(rd, commit) and
    RoundCommitAuthentic(commit)

  def FatPointerSignatureFromRoundData(rd: RoundData_t, sig: FatPointerSignature_t): bool =
    SigIndexes.exists(i => {
      val commit = rd.commitVotes.get(i)
      RoundCommitMatchesProposal(rd, commit) and
      commit.pubKey == sig.pubKey and
      commit.signedBytes == sig.signedBytes and
      commit.voteSignature == sig.voteSignature
    })

  def RoundDataCommitIncludedInFatPointer(rd: RoundData_t, commit: RoundCommit_t, fp: FatPointer_t): bool =
    RoundCommitMatchesProposal(rd, commit) implies
    ActiveSigIndexes(fp).exists(i => {
      val sig = fp.signatures.get(i)
      sig.pubKey == commit.pubKey and
      sig.signedBytes == commit.signedBytes and
      sig.voteSignature == commit.voteSignature
    })

  def FatPointerDerivedFromRoundData(rd: RoundData_t, fp: FatPointer_t): bool =
    fp.height == rd.height and
    fp.round == rd.round and
    fp.blockHash == rd.proposalBlockHash and
    FatPointerFormatValid(fp) and
    ActiveSigIndexes(fp).forall(i =>
      FatPointerSignatureFromRoundData(rd, fp.signatures.get(i))
    ) and
    SigIndexes.forall(i =>
      RoundDataCommitIncludedInFatPointer(rd, rd.commitVotes.get(i), fp)
    )

  action Init = all {
    acceptedFatPointers' = Set(),
    acceptedFatPointerWires' = Set(),
    firedAction' = "Init",
  }

  action AcceptFatPointer(fp: FatPointer_t): bool =
    all {
      FatPointerFormatValid(fp),
      acceptedFatPointers' = acceptedFatPointers.union(Set(fp)),
      acceptedFatPointerWires' = acceptedFatPointerWires,
      firedAction' = "AcceptFatPointer",
    }

  action AcceptFatPointerWire(wire: FatPointerWire_t): bool =
    all {
      FatPointerFormatValid(wire.fatPointer),
      FatPointerWireEnvelopeValid(wire),
      acceptedFatPointers' = acceptedFatPointers.union(Set(wire.fatPointer)),
      acceptedFatPointerWires' = acceptedFatPointerWires.union(Set(wire)),
      firedAction' = "AcceptFatPointerWire",
    }

  action Stutter: bool =
    all {
      acceptedFatPointers' = acceptedFatPointers,
      acceptedFatPointerWires' = acceptedFatPointerWires,
      firedAction' = firedAction,
    }

  val AcceptedFatPointersValid =
    acceptedFatPointers.forall(FatPointerFormatValid)

  val AcceptedFatPointerWiresValid =
    acceptedFatPointerWires.forall(wire =>
      FatPointerFormatValid(wire.fatPointer) and FatPointerWireEnvelopeValid(wire)
    )

  val Safety =
    AcceptedFatPointersValid and
    AcceptedFatPointerWiresValid
}

module CrosslinkFatPointerFormatTest {
  import CrosslinkFatPointerFormat.* from "./CrosslinkFatPointerFormat"
  export CrosslinkFatPointerFormat.*

  def Sig(
    pubKey: PubKey_t,
    signedBytes: Bytes_t,
    voteSignature: Signature_t,
  ): FatPointerSignature_t = {
    pubKey: pubKey,
    signedBytes: signedBytes,
    voteSignature: voteSignature,
  }

  def Fp(
    height: Height_t,
    blockHash: BlockHash_t,
    signatureCount: int,
    s0: FatPointerSignature_t,
    s1: FatPointerSignature_t,
    s2: FatPointerSignature_t,
    s3: FatPointerSignature_t,
  ): FatPointer_t = {
    height: height,
    round: 0,
    blockHash: blockHash,
    signatureCount: signatureCount,
    signatures: Map(0 -> s0, 1 -> s1, 2 -> s2, 3 -> s3),
  }

  def Wire(fatPointer: FatPointer_t, byteLen: int): FatPointerWire_t = {
    fatPointer: fatPointer,
    byteLen: byteLen,
  }

  def Commit(
    pubKey: PubKey_t,
    blockHash: BlockHash_t,
    signedBytes: Bytes_t,
    voteSignature: Signature_t,
  ): RoundCommit_t = {
    pubKey: pubKey,
    blockHash: blockHash,
    signedBytes: signedBytes,
    voteSignature: voteSignature,
  }

  def Rd(
    height: Height_t,
    blockHash: BlockHash_t,
    c0: RoundCommit_t,
    c1: RoundCommit_t,
    c2: RoundCommit_t,
    c3: RoundCommit_t,
  ): RoundData_t = {
    height: height,
    round: 0,
    proposalBlockHash: blockHash,
    commitVotes: Map(0 -> c0, 1 -> c1, 2 -> c2, 3 -> c3),
  }

  pure val blankSig = Sig("k1", "blank", "blank-sig")
  pure val blankCommit = Commit("k1", NilBlockHash, "blank", "blank-sig")

  pure val validHeight2FatPointer =
    Fp(
      2,
      "bft2",
      3,
      Sig("k2", "h2-r0-bft2-k2", "sig-k2-h2-bft2"),
      Sig("k3", "h2-r0-bft2-k3", "sig-k3-h2-bft2"),
      Sig("k4", "h2-r0-bft2-k4", "sig-k4-h2-bft2"),
      blankSig,
    )

  pure val duplicatePubKeyFatPointer =
    Fp(
      2,
      "bft2",
      3,
      Sig("k2", "h2-r0-bft2-k2", "sig-k2-h2-bft2"),
      Sig("k2", "h2-r0-bft2-k2", "sig-k2-h2-bft2"),
      Sig("k3", "h2-r0-bft2-k3", "sig-k3-h2-bft2"),
      blankSig,
    )

  pure val removedValidatorFatPointer =
    Fp(
      2,
      "bft2",
      3,
      Sig("k1", "h2-r0-bft2-k1", "sig-k1-h2-bft2"),
      Sig("k2", "h2-r0-bft2-k2", "sig-k2-h2-bft2"),
      Sig("k3", "h2-r0-bft2-k3", "sig-k3-h2-bft2"),
      blankSig,
    )

  pure val oldHeightFatPointer =
    Fp(
      1,
      "bft1",
      3,
      Sig("k1", "h1-r0-bft1-k1", "sig-k1-h1-bft1"),
      Sig("k2", "h1-r0-bft1-k2", "sig-k2-h1-bft1"),
      Sig("k3", "h1-r0-bft1-k3", "sig-k3-h1-bft1"),
      blankSig,
    )

  pure val wrongPayloadFatPointer =
    Fp(
      2,
      "bft2",
      3,
      Sig("k2", "wrong-bytes", "sig-k2-wrong"),
      Sig("k3", "h2-r0-bft2-k3", "sig-k3-h2-bft2"),
      Sig("k4", "h2-r0-bft2-k4", "sig-k4-h2-bft2"),
      blankSig,
    )

  pure val crossHeightReplayFatPointer =
    Fp(
      2,
      "bft2",
      3,
      Sig("k2", "h1-r0-bft1-k2", "sig-k2-h1-bft1"),
      Sig("k3", "h2-r0-bft2-k3", "sig-k3-h2-bft2"),
      Sig("k4", "h2-r0-bft2-k4", "sig-k4-h2-bft2"),
      blankSig,
    )

  pure val lowPowerFatPointer =
    Fp(
      2,
      "bft2",
      2,
      Sig("k2", "h2-r0-bft2-k2", "sig-k2-h2-bft2"),
      Sig("k3", "h2-r0-bft2-k3", "sig-k3-h2-bft2"),
      blankSig,
      blankSig,
    )

  pure val countTooHighFatPointer =
    Fp(
      2,
      "bft2",
      5,
      Sig("k1", "h2-r0-bft2-k1", "sig-k1-h2-bft2"),
      Sig("k2", "h2-r0-bft2-k2", "sig-k2-h2-bft2"),
      Sig("k3", "h2-r0-bft2-k3", "sig-k3-h2-bft2"),
      Sig("k4", "h2-r0-bft2-k4", "sig-k4-h2-bft2"),
    )

  pure val validProducerRoundData =
    Rd(
      2,
      "bft2",
      blankCommit,
      Commit("k2", "bft2", "h2-r0-bft2-k2", "sig-k2-h2-bft2"),
      Commit("k3", "bft2", "h2-r0-bft2-k3", "sig-k3-h2-bft2"),
      Commit("k4", "bft2", "h2-r0-bft2-k4", "sig-k4-h2-bft2"),
    )

  pure val missingProducerSignatureRoundData =
    Rd(
      2,
      "bft2",
      blankCommit,
      Commit("k2", "bft2", "h2-r0-bft2-k2", "sig-k2-h2-bft2"),
      Commit("k3", "bft2", "h2-r0-bft2-k3", "sig-k3-h2-bft2"),
      blankCommit,
    )

  pure val nilProducerPrecommitRoundData =
    Rd(
      2,
      "bft2",
      blankCommit,
      Commit("k2", NilBlockHash, "h2-r0-bft2-k2", "sig-k2-h2-bft2"),
      Commit("k3", "bft2", "h2-r0-bft2-k3", "sig-k3-h2-bft2"),
      Commit("k4", "bft2", "h2-r0-bft2-k4", "sig-k4-h2-bft2"),
    )

  pure val oldHeightProducerRoundData =
    Rd(
      1,
      "bft1",
      Commit("k1", "bft1", "h1-r0-bft1-k1", "sig-k1-h1-bft1"),
      Commit("k2", "bft1", "h1-r0-bft1-k2", "sig-k2-h1-bft1"),
      Commit("k3", "bft1", "h1-r0-bft1-k3", "sig-k3-h1-bft1"),
      blankCommit,
    )

  pure val TestFatPointers = Set(
    validHeight2FatPointer,
    duplicatePubKeyFatPointer,
    removedValidatorFatPointer,
    oldHeightFatPointer,
    wrongPayloadFatPointer,
    crossHeightReplayFatPointer,
    lowPowerFatPointer,
    countTooHighFatPointer,
  )

  pure val validHeight2Wire =
    Wire(validHeight2FatPointer, 334)

  pure val trailingByteWire =
    Wire(validHeight2FatPointer, 335)

  pure val truncatedWire =
    Wire(validHeight2FatPointer, 333)

  pure val TestFatPointerWires = Set(
    validHeight2Wire,
    trailingByteWire,
    truncatedWire,
  )

  action Next: bool =
    any {
      nondet fp = oneOf(TestFatPointers)
      AcceptFatPointer(fp),
      nondet wire = oneOf(TestFatPointerWires)
      AcceptFatPointerWire(wire),
      Stutter,
    }

  action unchangedAll = all {
    acceptedFatPointers' = acceptedFatPointers,
    acceptedFatPointerWires' = acceptedFatPointerWires,
    firedAction' = firedAction,
  }

  run acceptsCurrentRosterFatPointerTest = {
    Init.then(AcceptFatPointer(validHeight2FatPointer)).then(all {
      assert(acceptedFatPointers.contains(validHeight2FatPointer)),
      assert(Safety),
      unchangedAll,
    })
  }

  run wireLengthIncludesVotePayloadCountAndEntriesTest = {
    Init.then(all {
      assert(FatPointerWireByteLen(validHeight2FatPointer) == 334),
      assert(MaxSignatures <= MaxU16),
      assert(ProductionByteLayoutMatchesImplementation),
      unchangedAll,
    })
  }

  run wireOffsetsMatchImplementationTest = {
    Init.then(all {
      assert(VotePayloadOffset == 0),
      assert(SignatureCountOffset == 44),
      assert(SignatureEntriesOffset == 46),
      assert(SignatureEntryPubKeyOffset(0) == 46),
      assert(SignatureEntryVoteSignatureOffset(0) == 78),
      assert(SignatureEntryPubKeyOffset(1) == 142),
      assert(SignatureEntryVoteSignatureOffset(1) == 174),
      assert(SignatureEntryEndOffset(2) == FatPointerWireByteLen(validHeight2FatPointer)),
      unchangedAll,
    })
  }

  run acceptsExactWireEnvelopeTest = {
    Init.then(AcceptFatPointerWire(validHeight2Wire)).then(all {
      assert(acceptedFatPointers.contains(validHeight2FatPointer)),
      assert(acceptedFatPointerWires.contains(validHeight2Wire)),
      assert(Safety),
      unchangedAll,
    })
  }

  run rejectsTrailingByteWireEnvelopeTest = {
    Init.then(AcceptFatPointerWire(trailingByteWire)).fail()
  }

  run rejectsTruncatedWireEnvelopeTest = {
    Init.then(AcceptFatPointerWire(truncatedWire)).fail()
  }

  run validProducerRoundDataDerivesFatPointerTest = {
    Init.then(all {
      assert(FatPointerDerivedFromRoundData(validProducerRoundData, validHeight2FatPointer)),
      unchangedAll,
    })
  }

  run producerRoundDataRejectsMissingSignatureTest = {
    Init.then(all {
      assert(not(FatPointerDerivedFromRoundData(
        missingProducerSignatureRoundData,
        validHeight2FatPointer,
      ))),
      unchangedAll,
    })
  }

  run producerRoundDataRejectsNilPrecommitSignerTest = {
    Init.then(all {
      assert(not(FatPointerDerivedFromRoundData(
        nilProducerPrecommitRoundData,
        validHeight2FatPointer,
      ))),
      unchangedAll,
    })
  }

  run producerRoundDataRejectsWrongHeightFatPointerTest = {
    Init.then(all {
      assert(not(FatPointerDerivedFromRoundData(
        oldHeightProducerRoundData,
        validHeight2FatPointer,
      ))),
      unchangedAll,
    })
  }

  run rejectsDuplicatePubKeyQuorumInflationTest = {
    Init.then(AcceptFatPointer(duplicatePubKeyFatPointer)).fail()
  }

  run rejectsRemovedValidatorAtNewHeightTest = {
    Init.then(AcceptFatPointer(removedValidatorFatPointer)).fail()
  }

  run acceptsOldHeightRosterFatPointerTest = {
    Init.then(AcceptFatPointer(oldHeightFatPointer)).then(all {
      assert(acceptedFatPointers.contains(oldHeightFatPointer)),
      assert(Safety),
      unchangedAll,
    })
  }

  run rejectsWrongPayloadSignatureTest = {
    Init.then(AcceptFatPointer(wrongPayloadFatPointer)).fail()
  }

  run rejectsCrossHeightSignatureReplayTest = {
    Init.then(AcceptFatPointer(crossHeightReplayFatPointer)).fail()
  }

  run rejectsLowPowerFatPointerTest = {
    Init.then(AcceptFatPointer(lowPowerFatPointer)).fail()
  }

  run rejectsSignatureCountPastVectorBoundTest = {
    Init.then(AcceptFatPointer(countTooHighFatPointer)).fail()
  }
}

module CrosslinkFatPointerFormatModel {
  import CrosslinkFatPointerFormatTest(
    Validators = Set("p1", "p2", "p3", "p4"),
    PubKeys = Set("k1", "k2", "k3", "k4"),
    VotingPower = Map("p1" -> 1, "p2" -> 1, "p3" -> 1, "p4" -> 1),
    QuorumVotingPower = 3,
    MaxBftHeight = 2,
    MaxRound = 0,
    MaxSignatures = 4,
    NilBlockHash = "nil",
    AuthorizedAt = Map(
      1 -> Set("p1", "p2", "p3", "p4"),
      2 -> Set("p2", "p3", "p4"),
    ),
    PubKeyOwner = Map(
      "k1" -> "p1",
      "k2" -> "p2",
      "k3" -> "p3",
      "k4" -> "p4",
    ),
    FatPointerSignBytes = Map(
      1 -> Map(
        0 -> Map(
          "bft1" -> Map(
            "k1" -> "h1-r0-bft1-k1",
            "k2" -> "h1-r0-bft1-k2",
            "k3" -> "h1-r0-bft1-k3",
            "k4" -> "h1-r0-bft1-k4",
          ),
        ),
      ),
      2 -> Map(
        0 -> Map(
          "bft2" -> Map(
            "k1" -> "h2-r0-bft2-k1",
            "k2" -> "h2-r0-bft2-k2",
            "k3" -> "h2-r0-bft2-k3",
            "k4" -> "h2-r0-bft2-k4",
          ),
        ),
      ),
    ),
    SignatureVerifier = Map(
      "k1" -> Map(
        "blank" -> "blank-sig",
        "h1-r0-bft1-k1" -> "sig-k1-h1-bft1",
        "h2-r0-bft2-k1" -> "sig-k1-h2-bft2",
      ),
      "k2" -> Map(
        "h1-r0-bft1-k2" -> "sig-k2-h1-bft1",
        "h2-r0-bft2-k2" -> "sig-k2-h2-bft2",
        "wrong-bytes" -> "sig-k2-wrong",
      ),
      "k3" -> Map(
        "h1-r0-bft1-k3" -> "sig-k3-h1-bft1",
        "h2-r0-bft2-k3" -> "sig-k3-h2-bft2",
      ),
      "k4" -> Map(
        "h1-r0-bft1-k4" -> "sig-k4-h1-bft1",
        "h2-r0-bft2-k4" -> "sig-k4-h2-bft2",
      ),
    ),
  ).*
}
