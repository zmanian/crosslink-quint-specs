module CrosslinkTenderlinkVoteSignBytes {
  /*
   Tenderlink vote sign-byte layout.

   This model pins the 76-byte vote payload currently used by both:
   - forks/tenderlink/src/lib.rs::make_vote_sign_datas
   - zebra-crosslink/src/malctx.rs::MalVote::to_bytes

   The layout is:
   - bytes 0..32: validator Ed25519 public key,
   - bytes 32..64: value id, or all zeroes for nil,
   - bytes 64..72: little-endian BFT height,
   - bytes 72..76: little-endian round with the high bit set for precommit.

   Fat pointers remove the signer pubkey and carry the remaining 44-byte
   value/height/round-type suffix beside each signer pubkey/signature entry.
   */

  type PubKey_t = str
  type ValueId_t = str
  type Height_t = int
  type Round_t = int
  type VoteKind_t = str
  type Bytes_t = str

  type VoteSignWire_t = {
    byteLen: int,
    pubKey: PubKey_t,
    valueId: ValueId_t,
    height: Height_t,
    round: Round_t,
    voteKind: VoteKind_t,
    roundFlag: int,
    hex: Bytes_t,
  }

  pure val TestPubKeyHex =
    "0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20"
  pure val NilValueId =
    "0000000000000000000000000000000000000000000000000000000000000000"
  pure val TestValueIdHex =
    "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"

  pure val PrevoteKind = "prevote"
  pure val PrecommitKind = "precommit"
  pure val VoteKinds = Set(PrevoteKind, PrecommitKind)
  pure val PubKeys = Set(TestPubKeyHex)
  pure val ValueIds = Set(TestValueIdHex)
  pure val VoteValues = ValueIds.union(Set(NilValueId))

  pure val Heights = 1.to(2)
  pure val Rounds = 0.to(1)

  pure val VoteSignByteLen = 76
  pure val PubKeyByteLen = 32
  pure val ValueIdByteLen = 32
  pure val HeightByteLen = 8
  pure val RoundFlagByteLen = 4
  pure val VotePayloadWithoutSignerByteLen = ValueIdByteLen + HeightByteLen + RoundFlagByteLen

  pure val PubKeyOffset = 0
  pure val ValueIdOffset = PubKeyOffset + PubKeyByteLen
  pure val HeightOffset = ValueIdOffset + ValueIdByteLen
  pure val RoundFlagOffset = HeightOffset + HeightByteLen
  pure val VoteSignEndOffset = RoundFlagOffset + RoundFlagByteLen
  pure val VotePayloadWithoutSignerOffset = ValueIdOffset
  pure val VotePayloadWithoutSignerEndOffset = VoteSignEndOffset

  pure val VoteSignHexCharLen = VoteSignByteLen * 2
  pure val VotePayloadWithoutSignerHexCharLen = VotePayloadWithoutSignerByteLen * 2

  pure val PrecommitRoundFlag = 2147483648
  pure val MaxU32PlusOne = 4294967296
  pure val UnmodeledVoteSignWireHex = "unmodeled-vote-sign-wire"
  pure val UnmodeledVotePayloadSuffixHex = "unmodeled-vote-payload-suffix"

  var acceptedVoteSignWires: Set[VoteSignWire_t]
  var firedAction: str

  pure def FieldEndOffset(offset: int, width: int): int =
    offset + width

  pure def MergedRoundFlag(kind: VoteKind_t, round: Round_t): int =
    if (kind == PrecommitKind) {
      round + PrecommitRoundFlag
    } else {
      round
    }

  pure def RoundFlagHasPrecommitBit(roundFlag: int): bool =
    roundFlag >= PrecommitRoundFlag and roundFlag < MaxU32PlusOne

  pure def RoundFlagDecodedKind(roundFlag: int): VoteKind_t =
    if (RoundFlagHasPrecommitBit(roundFlag)) {
      PrecommitKind
    } else {
      PrevoteKind
    }

  pure def RoundFlagDecodedRound(roundFlag: int): Round_t =
    if (RoundFlagHasPrecommitBit(roundFlag)) {
      roundFlag - PrecommitRoundFlag
    } else {
      roundFlag
    }

  pure def RoundFlagInRange(roundFlag: int): bool =
    roundFlag >= 0 and roundFlag < MaxU32PlusOne

  pure def VoteSignLayoutConstantsPinned: bool =
    VoteSignByteLen == 76 and
    PubKeyByteLen == 32 and
    ValueIdByteLen == 32 and
    HeightByteLen == 8 and
    RoundFlagByteLen == 4 and
    VotePayloadWithoutSignerByteLen == 44 and
    PubKeyOffset == 0 and
    ValueIdOffset == 32 and
    HeightOffset == 64 and
    RoundFlagOffset == 72 and
    VoteSignEndOffset == 76 and
    VotePayloadWithoutSignerOffset == 32 and
    VotePayloadWithoutSignerEndOffset == 76 and
    VoteSignHexCharLen == 152 and
    VotePayloadWithoutSignerHexCharLen == 88

  pure def VoteSignFieldOffsetsContiguous: bool =
    FieldEndOffset(PubKeyOffset, PubKeyByteLen) == ValueIdOffset and
    FieldEndOffset(ValueIdOffset, ValueIdByteLen) == HeightOffset and
    FieldEndOffset(HeightOffset, HeightByteLen) == RoundFlagOffset and
    FieldEndOffset(RoundFlagOffset, RoundFlagByteLen) == VoteSignEndOffset

  pure def VoteSignWireFieldsValid(vote: VoteSignWire_t): bool =
    vote.byteLen == VoteSignByteLen and
    PubKeys.contains(vote.pubKey) and
    VoteValues.contains(vote.valueId) and
    Heights.contains(vote.height) and
    Rounds.contains(vote.round) and
    VoteKinds.contains(vote.voteKind) and
    RoundFlagInRange(vote.roundFlag) and
    vote.roundFlag == MergedRoundFlag(vote.voteKind, vote.round) and
    RoundFlagDecodedKind(vote.roundFlag) == vote.voteKind and
    RoundFlagDecodedRound(vote.roundFlag) == vote.round

  pure def CanonicalVoteSignWireHex(vote: VoteSignWire_t): Bytes_t =
    if (vote.byteLen == 76 and vote.pubKey == TestPubKeyHex and
      vote.valueId == NilValueId and vote.height == 1 and vote.round == 0 and
      vote.voteKind == PrevoteKind and vote.roundFlag == 0) {
      "0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f200000000000000000000000000000000000000000000000000000000000000000010000000000000000000000"
    } else if (vote.byteLen == 76 and vote.pubKey == TestPubKeyHex and
      vote.valueId == TestValueIdHex and vote.height == 1 and vote.round == 0 and
      vote.voteKind == PrevoteKind and vote.roundFlag == 0) {
      "0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa010000000000000000000000"
    } else if (vote.byteLen == 76 and vote.pubKey == TestPubKeyHex and
      vote.valueId == NilValueId and vote.height == 1 and vote.round == 0 and
      vote.voteKind == PrecommitKind and vote.roundFlag == 2147483648) {
      "0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f200000000000000000000000000000000000000000000000000000000000000000010000000000000000000080"
    } else if (vote.byteLen == 76 and vote.pubKey == TestPubKeyHex and
      vote.valueId == TestValueIdHex and vote.height == 1 and vote.round == 0 and
      vote.voteKind == PrecommitKind and vote.roundFlag == 2147483648) {
      "0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa010000000000000000000080"
    } else if (vote.byteLen == 76 and vote.pubKey == TestPubKeyHex and
      vote.valueId == TestValueIdHex and vote.height == 2 and vote.round == 1 and
      vote.voteKind == PrecommitKind and vote.roundFlag == 2147483649) {
      "0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa020000000000000001000080"
    } else {
      UnmodeledVoteSignWireHex
    }

  pure def CanonicalVotePayloadSuffixHex(vote: VoteSignWire_t): Bytes_t =
    if (vote.byteLen == 76 and vote.valueId == NilValueId and
      vote.height == 1 and vote.round == 0 and vote.voteKind == PrevoteKind and
      vote.roundFlag == 0) {
      "0000000000000000000000000000000000000000000000000000000000000000010000000000000000000000"
    } else if (vote.byteLen == 76 and vote.valueId == TestValueIdHex and
      vote.height == 1 and vote.round == 0 and vote.voteKind == PrevoteKind and
      vote.roundFlag == 0) {
      "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa010000000000000000000000"
    } else if (vote.byteLen == 76 and vote.valueId == NilValueId and
      vote.height == 1 and vote.round == 0 and vote.voteKind == PrecommitKind and
      vote.roundFlag == 2147483648) {
      "0000000000000000000000000000000000000000000000000000000000000000010000000000000000000080"
    } else if (vote.byteLen == 76 and vote.valueId == TestValueIdHex and
      vote.height == 1 and vote.round == 0 and vote.voteKind == PrecommitKind and
      vote.roundFlag == 2147483648) {
      "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa010000000000000000000080"
    } else if (vote.byteLen == 76 and vote.valueId == TestValueIdHex and
      vote.height == 2 and vote.round == 1 and vote.voteKind == PrecommitKind and
      vote.roundFlag == 2147483649) {
      "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa020000000000000001000080"
    } else {
      UnmodeledVotePayloadSuffixHex
    }

  pure def VoteSignWireCanonical(vote: VoteSignWire_t): bool =
    VoteSignWireFieldsValid(vote) and
    vote.hex == CanonicalVoteSignWireHex(vote) and
    CanonicalVoteSignWireHex(vote) != UnmodeledVoteSignWireHex and
    CanonicalVotePayloadSuffixHex(vote) != UnmodeledVotePayloadSuffixHex

  pure def NilVote(vote: VoteSignWire_t): bool =
    vote.valueId == NilValueId

  pure def ValueVote(vote: VoteSignWire_t): bool =
    vote.valueId != NilValueId

  pure def FatPointerPayloadCompatible(vote: VoteSignWire_t): bool =
    VoteSignWireCanonical(vote) and
    ValueVote(vote) and
    vote.voteKind == PrecommitKind and
    CanonicalVotePayloadSuffixHex(vote) != UnmodeledVotePayloadSuffixHex

  action Init = all {
    acceptedVoteSignWires' = Set(),
    firedAction' = "Init",
  }

  action AcceptVoteSignWire(vote: VoteSignWire_t): bool =
    all {
      VoteSignWireCanonical(vote),
      acceptedVoteSignWires' = acceptedVoteSignWires.union(Set(vote)),
      firedAction' = "AcceptVoteSignWire",
    }

  action Stutter: bool =
    all {
      acceptedVoteSignWires' = acceptedVoteSignWires,
      firedAction' = firedAction,
    }

  pure def AcceptedVoteSignWiresCanonical: bool =
    acceptedVoteSignWires.forall(VoteSignWireCanonical)

  pure def AcceptedValuePrecommitWiresFatPointerCompatible: bool =
    acceptedVoteSignWires.forall(vote =>
      if (ValueVote(vote) and vote.voteKind == PrecommitKind) {
        FatPointerPayloadCompatible(vote)
      } else {
        true
      }
    )

  val Safety =
    VoteSignLayoutConstantsPinned and
    VoteSignFieldOffsetsContiguous and
    AcceptedVoteSignWiresCanonical and
    AcceptedValuePrecommitWiresFatPointerCompatible
}

module CrosslinkTenderlinkVoteSignBytesTest {
  import CrosslinkTenderlinkVoteSignBytes.* from "./CrosslinkTenderlinkVoteSignBytes"
  export CrosslinkTenderlinkVoteSignBytes.*

  def VoteWire(
    byteLen: int,
    valueId: ValueId_t,
    height: Height_t,
    round: Round_t,
    voteKind: VoteKind_t,
    roundFlag: int,
    hex: Bytes_t,
  ): VoteSignWire_t = {
    byteLen: byteLen,
    pubKey: TestPubKeyHex,
    valueId: valueId,
    height: height,
    round: round,
    voteKind: voteKind,
    roundFlag: roundFlag,
    hex: hex,
  }

  pure val nilPrevoteH1R0 =
    VoteWire(
      76,
      NilValueId,
      1,
      0,
      PrevoteKind,
      0,
      "0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f200000000000000000000000000000000000000000000000000000000000000000010000000000000000000000",
    )

  pure val valuePrevoteH1R0 =
    VoteWire(
      76,
      TestValueIdHex,
      1,
      0,
      PrevoteKind,
      0,
      "0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa010000000000000000000000",
    )

  pure val nilPrecommitH1R0 =
    VoteWire(
      76,
      NilValueId,
      1,
      0,
      PrecommitKind,
      PrecommitRoundFlag,
      "0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f200000000000000000000000000000000000000000000000000000000000000000010000000000000000000080",
    )

  pure val valuePrecommitH1R0 =
    VoteWire(
      76,
      TestValueIdHex,
      1,
      0,
      PrecommitKind,
      PrecommitRoundFlag,
      "0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa010000000000000000000080",
    )

  pure val valuePrecommitH2R1 =
    VoteWire(
      76,
      TestValueIdHex,
      2,
      1,
      PrecommitKind,
      PrecommitRoundFlag + 1,
      "0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa020000000000000001000080",
    )

  pure val wrongPrecommitFlagWire =
    VoteWire(
      76,
      TestValueIdHex,
      1,
      0,
      PrecommitKind,
      0,
      "0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa010000000000000000000000",
    )

  pure val trailingBytesWire =
    VoteWire(
      77,
      TestValueIdHex,
      1,
      0,
      PrecommitKind,
      PrecommitRoundFlag,
      "0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa01000000000000000000008000",
    )

  pure val wrongHeightReplayWire =
    VoteWire(
      76,
      TestValueIdHex,
      2,
      0,
      PrecommitKind,
      PrecommitRoundFlag,
      "0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa010000000000000000000080",
    )

  pure val TestVoteSignWires = Set(
    nilPrevoteH1R0,
    valuePrevoteH1R0,
    nilPrecommitH1R0,
    valuePrecommitH1R0,
    valuePrecommitH2R1,
    wrongPrecommitFlagWire,
    trailingBytesWire,
    wrongHeightReplayWire,
  )

  action Next: bool =
    any {
      nondet vote = oneOf(TestVoteSignWires)
      AcceptVoteSignWire(vote),
      Stutter,
    }

  action unchangedAll = all {
    acceptedVoteSignWires' = acceptedVoteSignWires,
    firedAction' = firedAction,
  }

  run voteSignLayoutPinnedTest = {
    Init.then(all {
      assert(VoteSignLayoutConstantsPinned),
      assert(VoteSignFieldOffsetsContiguous),
      assert(PubKeyOffset == 0),
      assert(ValueIdOffset == 32),
      assert(HeightOffset == 64),
      assert(RoundFlagOffset == 72),
      assert(VoteSignEndOffset == 76),
      assert(VotePayloadWithoutSignerByteLen == 44),
      unchangedAll,
    })
  }

  run nilAndValuePrevoteExactHexTest = {
    Init.then(all {
      assert(CanonicalVoteSignWireHex(nilPrevoteH1R0) ==
        nilPrevoteH1R0.hex),
      assert(CanonicalVoteSignWireHex(valuePrevoteH1R0) ==
        valuePrevoteH1R0.hex),
      assert(CanonicalVotePayloadSuffixHex(valuePrevoteH1R0) ==
        "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa010000000000000000000000"),
      unchangedAll,
    })
  }

  run precommitHighBitExactHexTest = {
    Init.then(all {
      assert(MergedRoundFlag(PrecommitKind, 0) == PrecommitRoundFlag),
      assert(MergedRoundFlag(PrecommitKind, 1) == PrecommitRoundFlag + 1),
      assert(CanonicalVoteSignWireHex(valuePrecommitH1R0) ==
        valuePrecommitH1R0.hex),
      assert(CanonicalVoteSignWireHex(valuePrecommitH2R1) ==
        valuePrecommitH2R1.hex),
      unchangedAll,
    })
  }

  run nilPrecommitIsDistinctFromNilPrevoteAndValuePrecommitTest = {
    Init.then(all {
      assert(NilVote(nilPrecommitH1R0)),
      assert(nilPrecommitH1R0.voteKind == PrecommitKind),
      assert(nilPrecommitH1R0.hex != nilPrevoteH1R0.hex),
      assert(nilPrecommitH1R0.hex != valuePrecommitH1R0.hex),
      assert(CanonicalVotePayloadSuffixHex(nilPrecommitH1R0) ==
        "0000000000000000000000000000000000000000000000000000000000000000010000000000000000000080"),
      unchangedAll,
    })
  }

  run valuePrecommitPayloadSuffixMatchesFatPointerBytesTest = {
    Init.then(all {
      assert(FatPointerPayloadCompatible(valuePrecommitH1R0)),
      assert(CanonicalVotePayloadSuffixHex(valuePrecommitH1R0) ==
        "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa010000000000000000000080"),
      assert(VotePayloadWithoutSignerOffset == ValueIdOffset),
      assert(VotePayloadWithoutSignerEndOffset == VoteSignEndOffset),
      unchangedAll,
    })
  }

  run acceptCanonicalVoteSignWireTest = {
    Init
      .then(AcceptVoteSignWire(valuePrecommitH1R0))
      .then(all {
        assert(acceptedVoteSignWires.contains(valuePrecommitH1R0)),
        assert(Safety),
        unchangedAll,
      })
  }

  run acceptNilPrecommitVoteSignWireTest = {
    Init
      .then(AcceptVoteSignWire(nilPrecommitH1R0))
      .then(all {
        assert(acceptedVoteSignWires.contains(nilPrecommitH1R0)),
        assert(Safety),
        unchangedAll,
      })
  }

  run wrongPrecommitFlagRejectedTest = {
    Init.then(AcceptVoteSignWire(wrongPrecommitFlagWire)).fail()
  }

  run trailingBytesRejectedTest = {
    Init.then(AcceptVoteSignWire(trailingBytesWire)).fail()
  }

  run wrongHeightReplayRejectedTest = {
    Init.then(AcceptVoteSignWire(wrongHeightReplayWire)).fail()
  }

  run voteSignBytesSafetyTest = {
    Init.then(all {
      assert(Safety),
      unchangedAll,
    })
  }
}

module CrosslinkTenderlinkVoteSignBytesModel {
  import CrosslinkTenderlinkVoteSignBytesTest.* from "./CrosslinkTenderlinkVoteSignBytes"
  export CrosslinkTenderlinkVoteSignBytesTest.*
}
