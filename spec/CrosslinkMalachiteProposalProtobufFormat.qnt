module CrosslinkMalachiteProposalProtobufFormat {
  /*
   Malachite proposal protobuf wire format.

   This slice pins the production protobuf boundary in
   zebra-crosslink/src/malctx.rs and zebra-crosslink/proto/consensus.proto for
   proposal messages:

   - MalValue as `Value { optional bytes value = 1 }`,
   - MalProposal as `Proposal { height, round, value, pol_round,
     validator_address }`,
   - SignedConsensusMsg::Proposal as `SignedMessage { proposal, signature }`,
   - MalStreamedProposal as `StreamedProposal { height, round, proposer,
     pol_round, data_bytes, signature }`.

   The examples deliberately use tiny value bytes and fixed validator/signature
   byte strings, so the exact prost/proto3 tags, lengths, omitted nil POL
   round, and required 32/64-byte fields are reviewable in Quint.
   */

  type Bytes_t = str

  type MalValueProto_t = {
    byteLen: int,
    valueLen: int,
    valueHex: Bytes_t,
    hex: Bytes_t,
  }

  type MalSignatureProto_t = {
    byteLen: int,
    signatureLen: int,
    signatureHex: Bytes_t,
    hex: Bytes_t,
  }

  type MalProposalProto_t = {
    byteLen: int,
    height: int,
    round: int,
    value: MalValueProto_t,
    polRound: int,
    validatorAddressLen: int,
    validatorAddressHex: Bytes_t,
    hex: Bytes_t,
  }

  type SignedProposalProto_t = {
    byteLen: int,
    messageTag: int,
    proposal: MalProposalProto_t,
    signature: MalSignatureProto_t,
    hex: Bytes_t,
  }

  type StreamedProposalProto_t = {
    byteLen: int,
    height: int,
    round: int,
    proposerLen: int,
    proposerHex: Bytes_t,
    polRound: int,
    dataLen: int,
    dataHex: Bytes_t,
    signature: MalSignatureProto_t,
    hex: Bytes_t,
  }

  pure val ProtobufWireTypeVarint = 0
  pure val ProtobufWireTypeLen = 2

  pure val ValueBytesTag = 10
  pure val ProposalHeightTag = 8
  pure val ProposalRoundTag = 16
  pure val ProposalValueTag = 26
  pure val ProposalPolRoundTag = 32
  pure val ProposalValidatorAddressTag = 42
  pure val SignedMessageProposalTag = 10
  pure val SignedMessageVoteTag = 18
  pure val SignedMessageSignatureTag = 26
  pure val SignatureBytesTag = 10
  pure val StreamedProposalHeightTag = 8
  pure val StreamedProposalRoundTag = 16
  pure val StreamedProposalProposerTag = 34
  pure val StreamedProposalPolRoundTag = 40
  pure val StreamedProposalDataBytesTag = 50
  pure val StreamedProposalSignatureTag = 58

  pure val NilPolRound = -1
  pure val SampleHeight = 1
  pure val SampleRound = 2
  pure val SamplePolRound = 7
  pure val SampleValueLen = 3
  pure val SampleValueHex = "aabbcc"
  pure val ValidatorAddressByteLen = 32
  pure val SignatureByteLen = 64
  pure val SampleValidatorAddressHex =
    "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f"
  pure val SampleProposerHex =
    "202122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f"
  pure val SampleSignatureHex =
    "404142434445464748494a4b4c4d4e4f505152535455565758595a5b5c5d5e5f606162636465666768696a6b6c6d6e6f707172737475767778797a7b7c7d7e7f"

  pure val ValueProtoByteLen = 5
  pure val ProposalWithoutPolRoundByteLen = 45
  pure val ProposalWithPolRoundByteLen = 47
  pure val SignatureProtoByteLen = 66
  pure val SignedProposalByteLen = 117
  pure val StreamedProposalByteLen = 113

  pure val UnmodeledValueHex = "unmodeled-mal-value-proto"
  pure val UnmodeledSignatureHex = "unmodeled-mal-signature-proto"
  pure val UnmodeledProposalHex = "unmodeled-mal-proposal-proto"
  pure val UnmodeledSignedProposalHex =
    "unmodeled-mal-signed-proposal-proto"
  pure val UnmodeledStreamedProposalHex =
    "unmodeled-mal-streamed-proposal-proto"

  var acceptedProposals: Set[MalProposalProto_t]
  var acceptedSignedProposals: Set[SignedProposalProto_t]
  var acceptedStreamedProposals: Set[StreamedProposalProto_t]
  var malProposalFiredAction: str

  pure def ValueProtoHex(value: MalValueProto_t): Bytes_t =
    if (value.byteLen == ValueProtoByteLen and value.valueLen == SampleValueLen
      and value.valueHex == SampleValueHex) {
      "0a03aabbcc"
    } else {
      UnmodeledValueHex
    }

  pure def ValueProtoCanonical(value: MalValueProto_t): bool =
    value.valueLen >= 0 and
    value.byteLen == ValueProtoByteLen and
    ValueProtoHex(value) != UnmodeledValueHex and
    value.hex == ValueProtoHex(value)

  pure def SignatureProtoHex(signature: MalSignatureProto_t): Bytes_t =
    if (signature.byteLen == SignatureProtoByteLen and
      signature.signatureLen == SignatureByteLen and
      signature.signatureHex == SampleSignatureHex) {
      "0a40404142434445464748494a4b4c4d4e4f505152535455565758595a5b5c5d5e5f606162636465666768696a6b6c6d6e6f707172737475767778797a7b7c7d7e7f"
    } else {
      UnmodeledSignatureHex
    }

  pure def SignatureProtoCanonical(signature: MalSignatureProto_t): bool =
    signature.signatureLen == SignatureByteLen and
    signature.byteLen == SignatureProtoByteLen and
    SignatureProtoHex(signature) != UnmodeledSignatureHex and
    signature.hex == SignatureProtoHex(signature)

  pure def ProposalProtoExpectedLen(proposal: MalProposalProto_t): int =
    if (proposal.polRound == NilPolRound) {
      ProposalWithoutPolRoundByteLen
    } else {
      ProposalWithPolRoundByteLen
    }

  pure def ProposalProtoFieldsValid(proposal: MalProposalProto_t): bool =
    proposal.height >= 0 and
    proposal.round >= 0 and
    proposal.polRound >= NilPolRound and
    proposal.validatorAddressLen == ValidatorAddressByteLen and
    proposal.validatorAddressHex == SampleValidatorAddressHex and
    ValueProtoCanonical(proposal.value) and
    proposal.byteLen == ProposalProtoExpectedLen(proposal)

  pure def ProposalProtoHex(proposal: MalProposalProto_t): Bytes_t =
    if (ProposalProtoFieldsValid(proposal) and
      proposal.height == SampleHeight and proposal.round == SampleRound and
      proposal.polRound == NilPolRound) {
      "080110021a050a03aabbcc2a20000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f"
    } else if (ProposalProtoFieldsValid(proposal) and
      proposal.height == SampleHeight and proposal.round == SampleRound and
      proposal.polRound == SamplePolRound) {
      "080110021a050a03aabbcc20072a20000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f"
    } else {
      UnmodeledProposalHex
    }

  pure def ProposalProtoCanonical(proposal: MalProposalProto_t): bool =
    ProposalProtoFieldsValid(proposal) and
    ProposalProtoHex(proposal) != UnmodeledProposalHex and
    proposal.hex == ProposalProtoHex(proposal)

  pure def SignedProposalProtoHex(
    signed: SignedProposalProto_t,
  ): Bytes_t =
    if (signed.byteLen == SignedProposalByteLen and
      signed.messageTag == SignedMessageProposalTag and
      ProposalProtoCanonical(signed.proposal) and
      signed.proposal.polRound == SamplePolRound and
      SignatureProtoCanonical(signed.signature)) {
      "0a2f080110021a050a03aabbcc20072a20000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f1a420a40404142434445464748494a4b4c4d4e4f505152535455565758595a5b5c5d5e5f606162636465666768696a6b6c6d6e6f707172737475767778797a7b7c7d7e7f"
    } else {
      UnmodeledSignedProposalHex
    }

  pure def SignedProposalProtoCanonical(
    signed: SignedProposalProto_t,
  ): bool =
    signed.messageTag == SignedMessageProposalTag and
    ProposalProtoCanonical(signed.proposal) and
    SignatureProtoCanonical(signed.signature) and
    SignedProposalProtoHex(signed) != UnmodeledSignedProposalHex and
    signed.hex == SignedProposalProtoHex(signed)

  pure def StreamedProposalProtoFieldsValid(
    streamed: StreamedProposalProto_t,
  ): bool =
    streamed.height >= 0 and
    streamed.round >= 0 and
    streamed.polRound >= NilPolRound and
    streamed.proposerLen == ValidatorAddressByteLen and
    streamed.proposerHex == SampleProposerHex and
    streamed.dataLen == SampleValueLen and
    streamed.dataHex == SampleValueHex and
    SignatureProtoCanonical(streamed.signature) and
    streamed.byteLen == StreamedProposalByteLen

  pure def StreamedProposalProtoHex(
    streamed: StreamedProposalProto_t,
  ): Bytes_t =
    if (StreamedProposalProtoFieldsValid(streamed) and
      streamed.height == SampleHeight and streamed.round == SampleRound and
      streamed.polRound == SamplePolRound) {
      "080110022220202122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f28073203aabbcc3a420a40404142434445464748494a4b4c4d4e4f505152535455565758595a5b5c5d5e5f606162636465666768696a6b6c6d6e6f707172737475767778797a7b7c7d7e7f"
    } else {
      UnmodeledStreamedProposalHex
    }

  pure def StreamedProposalProtoCanonical(
    streamed: StreamedProposalProto_t,
  ): bool =
    StreamedProposalProtoFieldsValid(streamed) and
    StreamedProposalProtoHex(streamed) != UnmodeledStreamedProposalHex and
    streamed.hex == StreamedProposalProtoHex(streamed)

  pure def ProtoTagsPinned: bool =
    ValueBytesTag == 10 and
    ProposalHeightTag == 8 and
    ProposalRoundTag == 16 and
    ProposalValueTag == 26 and
    ProposalPolRoundTag == 32 and
    ProposalValidatorAddressTag == 42 and
    SignedMessageProposalTag == 10 and
    SignedMessageVoteTag == 18 and
    SignedMessageSignatureTag == 26 and
    SignatureBytesTag == 10 and
    StreamedProposalHeightTag == 8 and
    StreamedProposalRoundTag == 16 and
    StreamedProposalProposerTag == 34 and
    StreamedProposalPolRoundTag == 40 and
    StreamedProposalDataBytesTag == 50 and
    StreamedProposalSignatureTag == 58

  pure def ProtoLengthsPinned: bool =
    ValueProtoByteLen == 5 and
    ProposalWithoutPolRoundByteLen == 45 and
    ProposalWithPolRoundByteLen == 47 and
    SignatureProtoByteLen == 66 and
    SignedProposalByteLen == 117 and
    StreamedProposalByteLen == 113

  action Init = all {
    acceptedProposals' = Set(),
    acceptedSignedProposals' = Set(),
    acceptedStreamedProposals' = Set(),
    malProposalFiredAction' = "Init",
  }

  action AcceptProposal(proposal: MalProposalProto_t): bool =
    all {
      ProposalProtoCanonical(proposal),
      acceptedProposals' = acceptedProposals.union(Set(proposal)),
      acceptedSignedProposals' = acceptedSignedProposals,
      acceptedStreamedProposals' = acceptedStreamedProposals,
      malProposalFiredAction' = "AcceptProposal",
    }

  action AcceptSignedProposal(signed: SignedProposalProto_t): bool =
    all {
      SignedProposalProtoCanonical(signed),
      acceptedProposals' = acceptedProposals,
      acceptedSignedProposals' = acceptedSignedProposals.union(Set(signed)),
      acceptedStreamedProposals' = acceptedStreamedProposals,
      malProposalFiredAction' = "AcceptSignedProposal",
    }

  action AcceptStreamedProposal(streamed: StreamedProposalProto_t): bool =
    all {
      StreamedProposalProtoCanonical(streamed),
      acceptedProposals' = acceptedProposals,
      acceptedSignedProposals' = acceptedSignedProposals,
      acceptedStreamedProposals' =
        acceptedStreamedProposals.union(Set(streamed)),
      malProposalFiredAction' = "AcceptStreamedProposal",
    }

  action Stutter: bool =
    all {
      acceptedProposals' = acceptedProposals,
      acceptedSignedProposals' = acceptedSignedProposals,
      acceptedStreamedProposals' = acceptedStreamedProposals,
      malProposalFiredAction' = malProposalFiredAction,
    }

  pure def AcceptedProposalsCanonical: bool =
    acceptedProposals.forall(ProposalProtoCanonical)

  pure def AcceptedSignedProposalsCanonical: bool =
    acceptedSignedProposals.forall(SignedProposalProtoCanonical)

  pure def AcceptedStreamedProposalsCanonical: bool =
    acceptedStreamedProposals.forall(StreamedProposalProtoCanonical)

  val Safety =
    ProtoTagsPinned and
    ProtoLengthsPinned and
    AcceptedProposalsCanonical and
    AcceptedSignedProposalsCanonical and
    AcceptedStreamedProposalsCanonical
}

module CrosslinkMalachiteProposalProtobufFormatTest {
  import CrosslinkMalachiteProposalProtobufFormat.* from "./CrosslinkMalachiteProposalProtobufFormat"
  export CrosslinkMalachiteProposalProtobufFormat.*

  def ValueProto(
    byteLen: int,
    valueLen: int,
    valueHex: Bytes_t,
    hex: Bytes_t,
  ): MalValueProto_t = {
    byteLen: byteLen,
    valueLen: valueLen,
    valueHex: valueHex,
    hex: hex,
  }

  def SignatureProto(
    byteLen: int,
    signatureLen: int,
    signatureHex: Bytes_t,
    hex: Bytes_t,
  ): MalSignatureProto_t = {
    byteLen: byteLen,
    signatureLen: signatureLen,
    signatureHex: signatureHex,
    hex: hex,
  }

  def ProposalProto(
    byteLen: int,
    height: int,
    round: int,
    value: MalValueProto_t,
    polRound: int,
    validatorAddressLen: int,
    validatorAddressHex: Bytes_t,
    hex: Bytes_t,
  ): MalProposalProto_t = {
    byteLen: byteLen,
    height: height,
    round: round,
    value: value,
    polRound: polRound,
    validatorAddressLen: validatorAddressLen,
    validatorAddressHex: validatorAddressHex,
    hex: hex,
  }

  def SignedProposalProto(
    byteLen: int,
    messageTag: int,
    proposal: MalProposalProto_t,
    signature: MalSignatureProto_t,
    hex: Bytes_t,
  ): SignedProposalProto_t = {
    byteLen: byteLen,
    messageTag: messageTag,
    proposal: proposal,
    signature: signature,
    hex: hex,
  }

  def StreamedProposalProto(
    byteLen: int,
    height: int,
    round: int,
    proposerLen: int,
    proposerHex: Bytes_t,
    polRound: int,
    dataLen: int,
    dataHex: Bytes_t,
    signature: MalSignatureProto_t,
    hex: Bytes_t,
  ): StreamedProposalProto_t = {
    byteLen: byteLen,
    height: height,
    round: round,
    proposerLen: proposerLen,
    proposerHex: proposerHex,
    polRound: polRound,
    dataLen: dataLen,
    dataHex: dataHex,
    signature: signature,
    hex: hex,
  }

  pure val SampleValue =
    ValueProto(5, 3, "aabbcc", "0a03aabbcc")

  pure val MissingValue =
    ValueProto(0, 0, "", "")

  pure val SampleSignature =
    SignatureProto(
      66,
      64,
      SampleSignatureHex,
      "0a40404142434445464748494a4b4c4d4e4f505152535455565758595a5b5c5d5e5f606162636465666768696a6b6c6d6e6f707172737475767778797a7b7c7d7e7f",
    )

  pure val MissingSignature =
    SignatureProto(0, 0, "", "")

  pure val ProposalWithoutPol =
    ProposalProto(
      45,
      1,
      2,
      SampleValue,
      -1,
      32,
      SampleValidatorAddressHex,
      "080110021a050a03aabbcc2a20000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f",
    )

  pure val ProposalWithPol =
    ProposalProto(
      47,
      1,
      2,
      SampleValue,
      7,
      32,
      SampleValidatorAddressHex,
      "080110021a050a03aabbcc20072a20000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f",
    )

  pure val ProposalMissingValue =
    ProposalProto(
      40,
      1,
      2,
      MissingValue,
      -1,
      32,
      SampleValidatorAddressHex,
      "080110022a20000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f",
    )

  pure val ProposalShortValidator =
    ProposalProto(
      44,
      1,
      2,
      SampleValue,
      -1,
      31,
      "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e",
      "080110021a050a03aabbcc2a1f000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e",
    )

  pure val ProposalNilRound =
    ProposalProto(
      47,
      1,
      -1,
      SampleValue,
      7,
      32,
      SampleValidatorAddressHex,
      "080110021a050a03aabbcc20072a20000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f",
    )

  pure val SignedProposal =
    SignedProposalProto(
      117,
      SignedMessageProposalTag,
      ProposalWithPol,
      SampleSignature,
      "0a2f080110021a050a03aabbcc20072a20000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f1a420a40404142434445464748494a4b4c4d4e4f505152535455565758595a5b5c5d5e5f606162636465666768696a6b6c6d6e6f707172737475767778797a7b7c7d7e7f",
    )

  pure val SignedProposalWithVoteOneofTag =
    SignedProposalProto(
      117,
      SignedMessageVoteTag,
      ProposalWithPol,
      SampleSignature,
      "122f080110021a050a03aabbcc20072a20000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f1a420a40404142434445464748494a4b4c4d4e4f505152535455565758595a5b5c5d5e5f606162636465666768696a6b6c6d6e6f707172737475767778797a7b7c7d7e7f",
    )

  pure val SignedProposalMissingSignature =
    SignedProposalProto(
      51,
      SignedMessageProposalTag,
      ProposalWithPol,
      MissingSignature,
      "0a2f080110021a050a03aabbcc20072a20000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f",
    )

  pure val StreamedProposal =
    StreamedProposalProto(
      113,
      1,
      2,
      32,
      SampleProposerHex,
      7,
      3,
      "aabbcc",
      SampleSignature,
      "080110022220202122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f28073203aabbcc3a420a40404142434445464748494a4b4c4d4e4f505152535455565758595a5b5c5d5e5f606162636465666768696a6b6c6d6e6f707172737475767778797a7b7c7d7e7f",
    )

  pure val StreamedProposalShortProposer =
    StreamedProposalProto(
      112,
      1,
      2,
      31,
      "202122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d3e",
      7,
      3,
      "aabbcc",
      SampleSignature,
      "08011002221f202122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d3e28073203aabbcc3a420a40404142434445464748494a4b4c4d4e4f505152535455565758595a5b5c5d5e5f606162636465666768696a6b6c6d6e6f707172737475767778797a7b7c7d7e7f",
    )

  pure val TestProposals = Set(
    ProposalWithoutPol,
    ProposalWithPol,
    ProposalMissingValue,
    ProposalShortValidator,
    ProposalNilRound,
  )

  pure val TestSignedProposals = Set(
    SignedProposal,
    SignedProposalWithVoteOneofTag,
    SignedProposalMissingSignature,
  )

  pure val TestStreamedProposals = Set(
    StreamedProposal,
    StreamedProposalShortProposer,
  )

  action Next: bool =
    any {
      nondet proposal = oneOf(TestProposals)
      AcceptProposal(proposal),
      nondet signed = oneOf(TestSignedProposals)
      AcceptSignedProposal(signed),
      nondet streamed = oneOf(TestStreamedProposals)
      AcceptStreamedProposal(streamed),
      Stutter,
    }

  action unchangedAll = all {
    acceptedProposals' = acceptedProposals,
    acceptedSignedProposals' = acceptedSignedProposals,
    acceptedStreamedProposals' = acceptedStreamedProposals,
    malProposalFiredAction' = malProposalFiredAction,
  }

  run protoTagsAndLengthsPinnedTest = {
    Init.then(all {
      assert(ProtoTagsPinned),
      assert(ProtoLengthsPinned),
      unchangedAll,
    })
  }

  run valueAndSignatureExactHexTest = {
    Init.then(all {
      assert(ValueProtoCanonical(SampleValue)),
      assert(SignatureProtoCanonical(SampleSignature)),
      unchangedAll,
    })
  }

  run proposalExactHexTest = {
    Init.then(all {
      assert(ProposalProtoCanonical(ProposalWithoutPol)),
      assert(ProposalProtoCanonical(ProposalWithPol)),
      assert(ProposalProtoHex(ProposalWithoutPol) == ProposalWithoutPol.hex),
      assert(ProposalProtoHex(ProposalWithPol) == ProposalWithPol.hex),
      unchangedAll,
    })
  }

  run signedProposalExactHexTest = {
    Init.then(all {
      assert(SignedProposalProtoCanonical(SignedProposal)),
      assert(SignedProposalProtoHex(SignedProposal) == SignedProposal.hex),
      unchangedAll,
    })
  }

  run streamedProposalExactHexTest = {
    Init.then(all {
      assert(StreamedProposalProtoCanonical(StreamedProposal)),
      assert(StreamedProposalProtoHex(StreamedProposal) == StreamedProposal.hex),
      unchangedAll,
    })
  }

  run acceptMalachiteProposalProtosTest = {
    Init
      .then(AcceptProposal(ProposalWithoutPol))
      .then(AcceptProposal(ProposalWithPol))
      .then(AcceptSignedProposal(SignedProposal))
      .then(AcceptStreamedProposal(StreamedProposal))
      .then(all {
        assert(acceptedProposals.contains(ProposalWithoutPol)),
        assert(acceptedProposals.contains(ProposalWithPol)),
        assert(acceptedSignedProposals.contains(SignedProposal)),
        assert(acceptedStreamedProposals.contains(StreamedProposal)),
        assert(Safety),
        unchangedAll,
      })
  }

  run missingValueRejectedTest = {
    Init.then(AcceptProposal(ProposalMissingValue)).fail()
  }

  run shortValidatorRejectedTest = {
    Init.then(AcceptProposal(ProposalShortValidator)).fail()
  }

  run nilProposalRoundRejectedTest = {
    Init.then(AcceptProposal(ProposalNilRound)).fail()
  }

  run wrongSignedMessageOneofRejectedTest = {
    Init.then(AcceptSignedProposal(SignedProposalWithVoteOneofTag)).fail()
  }

  run missingSignatureRejectedTest = {
    Init.then(AcceptSignedProposal(SignedProposalMissingSignature)).fail()
  }

  run shortStreamedProposerRejectedTest = {
    Init.then(AcceptStreamedProposal(StreamedProposalShortProposer)).fail()
  }

  run malachiteProposalProtoSafetyTest = {
    Init.then(all {
      assert(Safety),
      unchangedAll,
    })
  }
}

module CrosslinkMalachiteProposalProtobufFormatModel {
  import CrosslinkMalachiteProposalProtobufFormatTest.* from "./CrosslinkMalachiteProposalProtobufFormat"
  export CrosslinkMalachiteProposalProtobufFormatTest.*
}
