module CrosslinkTenderlinkAccountabilityEvidenceFormat {
  /*
   Production-shaped Tenderlink accountability evidence.

   The abstract accountability model proves that conflicting commits expose
   slashable behavior. This model pins concrete evidence envelopes for that
   story: the nil/value precommit equivocation case used by the nil-precommit
   resampling rule, plus ordinary value/value precommit equivocation. Each
   envelope carries two canonical PacketVotes payloads plus enough typed header
   data to identify the BFT height, round, validator pubkey, packet types, and
   packet lengths.
   */

  type AccountabilityEvidenceKind_t = str
  type VotePacketEntry_t = {
    rosterIndex: int,
    pubKey: str,
    valueId: str,
    signBytes: str,
    voteSignature: str,
  }

  type VotePacket_t = {
    packetType: int,
    byteLen: int,
    noVotes: int,
    yesVotes: int,
    round: int,
    height: int,
    valueId: str,
    entries: int -> VotePacketEntry_t,
    hex: str,
  }

  type AccountabilityEvidence_t = {
    kind: AccountabilityEvidenceKind_t,
    byteLen: int,
    height: int,
    round: int,
    validatorPubKey: str,
    firstPacketType: int,
    secondPacketType: int,
    firstPacketByteLen: int,
    secondPacketByteLen: int,
    firstVote: VotePacket_t,
    secondVote: VotePacket_t,
    hex: str,
  }

  pure val PacketTypePrevoteSignatures = 8
  pure val PacketTypePrecommitSignatures = 9
  pure val TestPubKeyHex =
    "0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20"
  pure val TestPubKey2Hex =
    "2122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f40"
  pure val NilValueId =
    "0000000000000000000000000000000000000000000000000000000000000000"
  pure val TestValueIdHex =
    "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  pure val TestValue2IdHex =
    "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
  pure val TestVoteSignatureHex =
    "11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111"
  pure val NilPrevoteSignBytes =
    "0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f200000000000000000000000000000000000000000000000000000000000000000010000000000000000000000"
  pure val NilPrecommitSignBytes =
    "0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f200000000000000000000000000000000000000000000000000000000000000000010000000000000000000080"
  pure val ValuePrecommitSignBytes =
    "0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa010000000000000000000080"
  pure val Value2PrecommitSignBytes =
    "0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb010000000000000000000080"

  pure val NilValuePrecommitEquivocationKind =
    "nil-value-precommit-equivocation"
  pure val ValueValuePrecommitEquivocationKind =
    "value-value-precommit-equivocation"
  pure val NilValuePrecommitEquivocationKindTag = 1
  pure val ValueValuePrecommitEquivocationKindTag = 2
  pure val UnmodeledAccountabilityEvidenceHex =
    "unmodeled-accountability-evidence"
  pure val UnmodeledAccountabilityKindTag = -1

  pure val EvidenceKindTagByteLen = 1
  pure val EvidenceHeightByteLen = 8
  pure val EvidenceRoundByteLen = 4
  pure val EvidenceValidatorPubKeyByteLen = 32
  pure val EvidencePacketTypeByteLen = 1
  pure val EvidencePacketLengthByteLen = 2

  pure val EvidenceKindTagOffset = 0
  pure val EvidenceHeightOffset =
    EvidenceKindTagOffset + EvidenceKindTagByteLen
  pure val EvidenceRoundOffset =
    EvidenceHeightOffset + EvidenceHeightByteLen
  pure val EvidenceValidatorPubKeyOffset =
    EvidenceRoundOffset + EvidenceRoundByteLen
  pure val EvidenceFirstPacketTypeOffset =
    EvidenceValidatorPubKeyOffset + EvidenceValidatorPubKeyByteLen
  pure val EvidenceSecondPacketTypeOffset =
    EvidenceFirstPacketTypeOffset + EvidencePacketTypeByteLen
  pure val EvidenceFirstPacketLenOffset =
    EvidenceSecondPacketTypeOffset + EvidencePacketTypeByteLen
  pure val EvidenceSecondPacketLenOffset =
    EvidenceFirstPacketLenOffset + EvidencePacketLengthByteLen
  pure val EvidencePacketBytesOffset =
    EvidenceSecondPacketLenOffset + EvidencePacketLengthByteLen
  pure val EvidenceHeaderByteLen = EvidencePacketBytesOffset

  pure val NilValuePrecommitEvidenceHeaderHex =
    "010100000000000000000000000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20090970007000"
  pure val ValueValuePrecommitEvidenceHeaderHex =
    "020100000000000000000000000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20090970007000"
  pure val NilPrecommitPacketHex =
    "0100000000000100000000000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa000011111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111"
  pure val ValuePrecommitPacketHex =
    "0001000000000100000000000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa000011111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111"
  pure val Value2PrecommitPacketHex =
    "0001000000000100000000000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb000011111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111"
  pure val NilValuePrecommitEvidenceHex =
    "010100000000000000000000000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f200909700070000100000000000100000000000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa0000111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111110001000000000100000000000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa000011111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111"
  pure val ValueValuePrecommitEvidenceHex =
    "020100000000000000000000000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f200909700070000001000000000100000000000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa0000111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111110001000000000100000000000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb000011111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111"

  var acceptedAccountabilityEvidence: Set[AccountabilityEvidence_t]
  var accountabilityEvidenceFormatFiredAction: str

  pure def FieldEndOffset(offset: int, width: int): int =
    offset + width

  pure def AccountabilityKindTag(kind: AccountabilityEvidenceKind_t): int =
    if (kind == NilValuePrecommitEquivocationKind) {
      NilValuePrecommitEquivocationKindTag
    } else if (kind == ValueValuePrecommitEquivocationKind) {
      ValueValuePrecommitEquivocationKindTag
    } else {
      UnmodeledAccountabilityKindTag
    }

  pure def AccountabilityEvidenceWireByteLen(
    evidence: AccountabilityEvidence_t,
  ): int =
    EvidenceHeaderByteLen + evidence.firstPacketByteLen +
      evidence.secondPacketByteLen

  pure def EntryCanonical(
    entry: VotePacketEntry_t,
    valueId: str,
    signBytes: str,
  ): bool =
    entry.rosterIndex == 0 and
    entry.pubKey == TestPubKeyHex and
    entry.valueId == valueId and
    entry.signBytes == signBytes and
    entry.voteSignature == TestVoteSignatureHex

  pure def VotePacketCanonical(packet: VotePacket_t): bool =
    packet.byteLen == 112 and
    packet.round == 0 and
    packet.height == 1 and
    if (packet.packetType == PacketTypePrecommitSignatures and
      packet.noVotes == 1 and packet.yesVotes == 0 and
      packet.valueId == TestValueIdHex) {
      EntryCanonical(packet.entries.get(0), NilValueId, NilPrecommitSignBytes) and
      packet.hex == NilPrecommitPacketHex
    } else if (packet.packetType == PacketTypePrecommitSignatures and
      packet.noVotes == 0 and packet.yesVotes == 1 and
      packet.valueId == TestValueIdHex) {
      EntryCanonical(packet.entries.get(0), TestValueIdHex,
        ValuePrecommitSignBytes) and
      packet.hex == ValuePrecommitPacketHex
    } else if (packet.packetType == PacketTypePrecommitSignatures and
      packet.noVotes == 0 and packet.yesVotes == 1 and
      packet.valueId == TestValue2IdHex) {
      EntryCanonical(packet.entries.get(0), TestValue2IdHex,
        Value2PrecommitSignBytes) and
      packet.hex == Value2PrecommitPacketHex
    } else if (packet.packetType == PacketTypePrevoteSignatures and
      packet.noVotes == 1 and packet.yesVotes == 0 and
      packet.valueId == TestValueIdHex) {
      EntryCanonical(packet.entries.get(0), NilValueId, NilPrevoteSignBytes) and
      packet.hex == NilPrecommitPacketHex
    } else {
      false
    }

  pure def AccountabilityEvidenceLayoutPinned: bool =
    EvidenceKindTagByteLen == 1 and
    EvidenceHeightByteLen == 8 and
    EvidenceRoundByteLen == 4 and
    EvidenceValidatorPubKeyByteLen == 32 and
    EvidencePacketTypeByteLen == 1 and
    EvidencePacketLengthByteLen == 2 and
    EvidenceKindTagOffset == 0 and
    EvidenceHeightOffset == 1 and
    EvidenceRoundOffset == 9 and
    EvidenceValidatorPubKeyOffset == 13 and
    EvidenceFirstPacketTypeOffset == 45 and
    EvidenceSecondPacketTypeOffset == 46 and
    EvidenceFirstPacketLenOffset == 47 and
    EvidenceSecondPacketLenOffset == 49 and
    EvidencePacketBytesOffset == 51 and
    EvidenceHeaderByteLen == 51

  pure def AccountabilityEvidenceFieldOffsetsContiguous: bool =
    FieldEndOffset(EvidenceKindTagOffset, EvidenceKindTagByteLen) ==
      EvidenceHeightOffset and
    FieldEndOffset(EvidenceHeightOffset, EvidenceHeightByteLen) ==
      EvidenceRoundOffset and
    FieldEndOffset(EvidenceRoundOffset, EvidenceRoundByteLen) ==
      EvidenceValidatorPubKeyOffset and
    FieldEndOffset(EvidenceValidatorPubKeyOffset, EvidenceValidatorPubKeyByteLen) ==
      EvidenceFirstPacketTypeOffset and
    FieldEndOffset(EvidenceFirstPacketTypeOffset, EvidencePacketTypeByteLen) ==
      EvidenceSecondPacketTypeOffset and
    FieldEndOffset(EvidenceSecondPacketTypeOffset, EvidencePacketTypeByteLen) ==
      EvidenceFirstPacketLenOffset and
    FieldEndOffset(EvidenceFirstPacketLenOffset, EvidencePacketLengthByteLen) ==
      EvidenceSecondPacketLenOffset and
    FieldEndOffset(EvidenceSecondPacketLenOffset, EvidencePacketLengthByteLen) ==
      EvidencePacketBytesOffset

  pure def PacketCarriesPrecommit(
    packet: VotePacket_t,
    height: int,
    round: int,
    pubKey: str,
    valueId: str,
  ): bool =
    packet.packetType == PacketTypePrecommitSignatures and
    packet.height == height and
    packet.round == round and
    packet.noVotes + packet.yesVotes == 1 and
    packet.entries.get(0).pubKey == pubKey and
    packet.entries.get(0).valueId == valueId

  pure def EvidenceEnvelopeFieldsValid(
    evidence: AccountabilityEvidence_t,
  ): bool =
    AccountabilityKindTag(evidence.kind) != UnmodeledAccountabilityKindTag and
    evidence.byteLen == AccountabilityEvidenceWireByteLen(evidence) and
    evidence.firstPacketType == evidence.firstVote.packetType and
    evidence.secondPacketType == evidence.secondVote.packetType and
    evidence.firstPacketByteLen == evidence.firstVote.byteLen and
    evidence.secondPacketByteLen == evidence.secondVote.byteLen

  pure def NilValuePrecommitEquivocationEvidence(
    evidence: AccountabilityEvidence_t,
  ): bool =
    evidence.kind == NilValuePrecommitEquivocationKind and
    EvidenceEnvelopeFieldsValid(evidence) and
    VotePacketCanonical(evidence.firstVote) and
    VotePacketCanonical(evidence.secondVote) and
    PacketCarriesPrecommit(
      evidence.firstVote,
      evidence.height,
      evidence.round,
      evidence.validatorPubKey,
      NilValueId,
    ) and
    PacketCarriesPrecommit(
      evidence.secondVote,
      evidence.height,
      evidence.round,
      evidence.validatorPubKey,
      evidence.secondVote.valueId,
    ) and
    evidence.secondVote.valueId != NilValueId and
    evidence.firstVote.valueId == evidence.secondVote.valueId

  pure def ValueValuePrecommitEquivocationEvidence(
    evidence: AccountabilityEvidence_t,
  ): bool =
    evidence.kind == ValueValuePrecommitEquivocationKind and
    EvidenceEnvelopeFieldsValid(evidence) and
    VotePacketCanonical(evidence.firstVote) and
    VotePacketCanonical(evidence.secondVote) and
    PacketCarriesPrecommit(
      evidence.firstVote,
      evidence.height,
      evidence.round,
      evidence.validatorPubKey,
      evidence.firstVote.valueId,
    ) and
    PacketCarriesPrecommit(
      evidence.secondVote,
      evidence.height,
      evidence.round,
      evidence.validatorPubKey,
      evidence.secondVote.valueId,
    ) and
    evidence.firstVote.valueId != NilValueId and
    evidence.secondVote.valueId != NilValueId and
    evidence.firstVote.valueId != evidence.secondVote.valueId

  pure def PrecommitEquivocationEvidence(
    evidence: AccountabilityEvidence_t,
  ): bool =
    NilValuePrecommitEquivocationEvidence(evidence) or
    ValueValuePrecommitEquivocationEvidence(evidence)

  pure def CanonicalAccountabilityEvidenceHex(
    evidence: AccountabilityEvidence_t,
  ): str =
    if (NilValuePrecommitEquivocationEvidence(evidence) and
      evidence.height == 1 and evidence.round == 0 and
      evidence.validatorPubKey == TestPubKeyHex and
      evidence.firstPacketType == PacketTypePrecommitSignatures and
      evidence.secondPacketType == PacketTypePrecommitSignatures and
      evidence.firstPacketByteLen == 112 and
      evidence.secondPacketByteLen == 112 and
      evidence.firstVote.hex == NilPrecommitPacketHex and
      evidence.secondVote.hex == ValuePrecommitPacketHex) {
      NilValuePrecommitEvidenceHex
    } else if (ValueValuePrecommitEquivocationEvidence(evidence) and
      evidence.height == 1 and evidence.round == 0 and
      evidence.validatorPubKey == TestPubKeyHex and
      evidence.firstPacketType == PacketTypePrecommitSignatures and
      evidence.secondPacketType == PacketTypePrecommitSignatures and
      evidence.firstPacketByteLen == 112 and
      evidence.secondPacketByteLen == 112 and
      evidence.firstVote.hex == ValuePrecommitPacketHex and
      evidence.secondVote.hex == Value2PrecommitPacketHex) {
      ValueValuePrecommitEvidenceHex
    } else {
      UnmodeledAccountabilityEvidenceHex
    }

  pure def AccountabilityEvidenceCanonical(
    evidence: AccountabilityEvidence_t,
  ): bool =
    AccountabilityEvidenceLayoutPinned and
    AccountabilityEvidenceFieldOffsetsContiguous and
    PrecommitEquivocationEvidence(evidence) and
    CanonicalAccountabilityEvidenceHex(evidence) !=
      UnmodeledAccountabilityEvidenceHex and
    evidence.hex == CanonicalAccountabilityEvidenceHex(evidence)

  action Init = all {
    acceptedAccountabilityEvidence' = Set(),
    accountabilityEvidenceFormatFiredAction' = "Init",
  }

  action AcceptAccountabilityEvidence(
    evidence: AccountabilityEvidence_t,
  ): bool =
    all {
      AccountabilityEvidenceCanonical(evidence),
      acceptedAccountabilityEvidence' =
        acceptedAccountabilityEvidence.union(Set(evidence)),
      accountabilityEvidenceFormatFiredAction' = "AcceptAccountabilityEvidence",
    }

  action Stutter: bool =
    all {
      acceptedAccountabilityEvidence' = acceptedAccountabilityEvidence,
      accountabilityEvidenceFormatFiredAction' = accountabilityEvidenceFormatFiredAction,
    }

  pure def AcceptedAccountabilityEvidenceCanonical: bool =
    acceptedAccountabilityEvidence.forall(AccountabilityEvidenceCanonical)

  val Safety =
    AccountabilityEvidenceLayoutPinned and
    AccountabilityEvidenceFieldOffsetsContiguous and
    AcceptedAccountabilityEvidenceCanonical
}

module CrosslinkTenderlinkAccountabilityEvidenceFormatTest {
  import CrosslinkTenderlinkAccountabilityEvidenceFormat.* from
    "./CrosslinkTenderlinkAccountabilityEvidenceFormat"
  export CrosslinkTenderlinkAccountabilityEvidenceFormat.*

  def Entry(
    valueId: str,
    signBytes: str,
    voteSignature: str,
  ): VotePacketEntry_t = {
    rosterIndex: 0,
    pubKey: TestPubKeyHex,
    valueId: valueId,
    signBytes: signBytes,
    voteSignature: voteSignature,
  }

  def Packet(
    packetType: int,
    noVotes: int,
    yesVotes: int,
    entry: VotePacketEntry_t,
    hex: str,
  ): VotePacket_t =
    PacketWithValueId(packetType, noVotes, yesVotes, TestValueIdHex, entry, hex)

  def PacketWithValueId(
    packetType: int,
    noVotes: int,
    yesVotes: int,
    packetValueId: str,
    entry: VotePacketEntry_t,
    hex: str,
  ): VotePacket_t = {
    packetType: packetType,
    byteLen: 112,
    noVotes: noVotes,
    yesVotes: yesVotes,
    round: 0,
    height: 1,
    valueId: packetValueId,
    entries: Map(0 -> entry),
    hex: hex,
  }

  pure val nilPrevotePacket =
    Packet(
      PacketTypePrevoteSignatures,
      1,
      0,
      Entry(NilValueId, NilPrevoteSignBytes, TestVoteSignatureHex),
      NilPrecommitPacketHex,
    )

  pure val nilPrecommitPacket =
    Packet(
      PacketTypePrecommitSignatures,
      1,
      0,
      Entry(NilValueId, NilPrecommitSignBytes, TestVoteSignatureHex),
      NilPrecommitPacketHex,
    )

  pure val valuePrecommitPacket =
    Packet(
      PacketTypePrecommitSignatures,
      0,
      1,
      Entry(TestValueIdHex, ValuePrecommitSignBytes, TestVoteSignatureHex),
      ValuePrecommitPacketHex,
    )

  pure val value2PrecommitPacket =
    PacketWithValueId(
      PacketTypePrecommitSignatures,
      0,
      1,
      TestValue2IdHex,
      Entry(TestValue2IdHex, Value2PrecommitSignBytes, TestVoteSignatureHex),
      Value2PrecommitPacketHex,
    )

  def EvidenceEnvelope(
    kind: AccountabilityEvidenceKind_t,
    byteLen: int,
    height: int,
    round: int,
    validatorPubKey: str,
    firstPacketType: int,
    secondPacketType: int,
    firstPacketByteLen: int,
    secondPacketByteLen: int,
    firstVote: VotePacket_t,
    secondVote: VotePacket_t,
    hex: str,
  ): AccountabilityEvidence_t = {
    kind: kind,
    byteLen: byteLen,
    height: height,
    round: round,
    validatorPubKey: validatorPubKey,
    firstPacketType: firstPacketType,
    secondPacketType: secondPacketType,
    firstPacketByteLen: firstPacketByteLen,
    secondPacketByteLen: secondPacketByteLen,
    firstVote: firstVote,
    secondVote: secondVote,
    hex: hex,
  }

  def Evidence(
    byteLen: int,
    height: int,
    round: int,
    validatorPubKey: str,
    firstPacketType: int,
    firstPacketByteLen: int,
    firstVote: VotePacket_t,
    hex: str,
  ): AccountabilityEvidence_t =
    EvidenceEnvelope(
      NilValuePrecommitEquivocationKind,
      byteLen,
      height,
      round,
      validatorPubKey,
      firstPacketType,
      PacketTypePrecommitSignatures,
      firstPacketByteLen,
      112,
      firstVote,
      valuePrecommitPacket,
      hex,
    )

  pure val nilValuePrecommitEvidence =
    Evidence(
      275,
      1,
      0,
      TestPubKeyHex,
      PacketTypePrecommitSignatures,
      112,
      nilPrecommitPacket,
      NilValuePrecommitEvidenceHex,
    )

  pure val valueValuePrecommitEvidence =
    EvidenceEnvelope(
      ValueValuePrecommitEquivocationKind,
      275,
      1,
      0,
      TestPubKeyHex,
      PacketTypePrecommitSignatures,
      PacketTypePrecommitSignatures,
      112,
      112,
      valuePrecommitPacket,
      value2PrecommitPacket,
      ValueValuePrecommitEvidenceHex,
    )

  pure val wrongRoundEvidence =
    Evidence(
      275,
      1,
      1,
      TestPubKeyHex,
      PacketTypePrecommitSignatures,
      112,
      nilPrecommitPacket,
      NilValuePrecommitEvidenceHex,
    )

  pure val wrongHeightEvidence =
    Evidence(
      275,
      2,
      0,
      TestPubKeyHex,
      PacketTypePrecommitSignatures,
      112,
      nilPrecommitPacket,
      NilValuePrecommitEvidenceHex,
    )

  pure val prevoteEvidence =
    Evidence(
      275,
      1,
      0,
      TestPubKeyHex,
      PacketTypePrevoteSignatures,
      112,
      nilPrevotePacket,
      NilValuePrecommitEvidenceHex,
    )

  pure val wrongLengthEvidence =
    Evidence(
      276,
      1,
      0,
      TestPubKeyHex,
      PacketTypePrecommitSignatures,
      112,
      nilPrecommitPacket,
      NilValuePrecommitEvidenceHex,
    )

  pure val sameValueEvidence =
    Evidence(
      275,
      1,
      0,
      TestPubKeyHex,
      PacketTypePrecommitSignatures,
      112,
      valuePrecommitPacket,
      NilValuePrecommitEvidenceHex,
    )

  pure val wrongSignerEvidence =
    Evidence(
      275,
      1,
      0,
      TestPubKey2Hex,
      PacketTypePrecommitSignatures,
      112,
      nilPrecommitPacket,
      NilValuePrecommitEvidenceHex,
    )

  pure val wrongHexEvidence =
    Evidence(
      275,
      1,
      0,
      TestPubKeyHex,
      PacketTypePrecommitSignatures,
      112,
      nilPrecommitPacket,
      "bad-accountability-evidence-hex",
    )

  pure val TestAccountabilityEvidence = Set(
    nilValuePrecommitEvidence,
    valueValuePrecommitEvidence,
    wrongRoundEvidence,
    wrongHeightEvidence,
    prevoteEvidence,
    wrongLengthEvidence,
    sameValueEvidence,
    wrongSignerEvidence,
    wrongHexEvidence,
  )

  action Next: bool =
    any {
      nondet evidence = oneOf(TestAccountabilityEvidence)
      AcceptAccountabilityEvidence(evidence),
      Stutter,
    }

  action unchangedAll = all {
    acceptedAccountabilityEvidence' = acceptedAccountabilityEvidence,
    accountabilityEvidenceFormatFiredAction' = accountabilityEvidenceFormatFiredAction,
  }

  run accountabilityEvidenceLayoutPinnedTest = {
    Init.then(all {
      assert(AccountabilityEvidenceLayoutPinned),
      assert(AccountabilityEvidenceFieldOffsetsContiguous),
      assert(EvidenceKindTagOffset == 0),
      assert(EvidenceHeightOffset == 1),
      assert(EvidenceRoundOffset == 9),
      assert(EvidenceValidatorPubKeyOffset == 13),
      assert(EvidenceFirstPacketTypeOffset == 45),
      assert(EvidenceSecondPacketTypeOffset == 46),
      assert(EvidenceFirstPacketLenOffset == 47),
      assert(EvidenceSecondPacketLenOffset == 49),
      assert(EvidencePacketBytesOffset == 51),
      unchangedAll,
    })
  }

  run acceptsNilValuePrecommitEvidenceTest = {
    Init
      .then(AcceptAccountabilityEvidence(nilValuePrecommitEvidence))
      .then(all {
        assert(acceptedAccountabilityEvidence.contains(nilValuePrecommitEvidence)),
        assert(AccountabilityEvidenceCanonical(nilValuePrecommitEvidence)),
        assert(CanonicalAccountabilityEvidenceHex(nilValuePrecommitEvidence) ==
          NilValuePrecommitEvidenceHex),
        assert(nilValuePrecommitEvidence.byteLen == 275),
        assert(NilValuePrecommitEvidenceHeaderHex ==
          "010100000000000000000000000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20090970007000"),
        assert(Safety),
        unchangedAll,
      })
  }

  run acceptsValueValuePrecommitEvidenceTest = {
    Init
      .then(AcceptAccountabilityEvidence(valueValuePrecommitEvidence))
      .then(all {
        assert(acceptedAccountabilityEvidence.contains(valueValuePrecommitEvidence)),
        assert(AccountabilityEvidenceCanonical(valueValuePrecommitEvidence)),
        assert(CanonicalAccountabilityEvidenceHex(valueValuePrecommitEvidence) ==
          ValueValuePrecommitEvidenceHex),
        assert(valueValuePrecommitEvidence.byteLen == 275),
        assert(ValueValuePrecommitEvidenceHeaderHex ==
          "020100000000000000000000000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20090970007000"),
        assert(Safety),
        unchangedAll,
      })
  }

  run rejectsPrevoteEvidenceTest = {
    Init.then(AcceptAccountabilityEvidence(prevoteEvidence)).fail()
  }

  run rejectsRoundMismatchEvidenceTest = {
    Init.then(AcceptAccountabilityEvidence(wrongRoundEvidence)).fail()
  }

  run rejectsHeightMismatchEvidenceTest = {
    Init.then(AcceptAccountabilityEvidence(wrongHeightEvidence)).fail()
  }

  run rejectsWrongLengthEvidenceTest = {
    Init.then(AcceptAccountabilityEvidence(wrongLengthEvidence)).fail()
  }

  run rejectsSameValueEvidenceTest = {
    Init.then(AcceptAccountabilityEvidence(sameValueEvidence)).fail()
  }

  run rejectsWrongSignerEvidenceTest = {
    Init.then(AcceptAccountabilityEvidence(wrongSignerEvidence)).fail()
  }

  run rejectsWrongHexEvidenceTest = {
    Init.then(AcceptAccountabilityEvidence(wrongHexEvidence)).fail()
  }

  run accountabilityEvidenceSafetyTest = {
    Init.then(all {
      assert(Safety),
      unchangedAll,
    })
  }
}

module CrosslinkTenderlinkAccountabilityEvidenceFormatModel {
  import CrosslinkTenderlinkAccountabilityEvidenceFormatTest.* from
    "./CrosslinkTenderlinkAccountabilityEvidenceFormat"
  export CrosslinkTenderlinkAccountabilityEvidenceFormatTest.*
}
