module CrosslinkMalachiteLivenessProtobufFormat {
  /*
   Malachite liveness protobuf wire format.

   This slice pins the production protobuf boundary in
   zebra-crosslink/proto/liveness.proto and zebra-crosslink/src/malctx.rs for
   liveness certificates:

   - PolkaCertificate with one PolkaSignature,
   - RoundCertificate::Skip with one nil precommit RoundSignature,
   - RoundCertificate::Precommit with one value precommit RoundSignature,
   - LivenessMessage oneof wrappers for polka and round certificates.

   It intentionally keeps the sample signer/value/signature bytes fixed so the
   important proto3 behavior is easy to audit: enum default fields are omitted,
   non-default enum fields are encoded, nil vote value ids are omitted, value
   precommits carry ValueId, and 32/64-byte key/signature lengths are required.
   */

  type Bytes_t = str

  type SignatureProto_t = {
    byteLen: int,
    signatureLen: int,
    hex: Bytes_t,
  }

  type ValueIdProto_t = {
    byteLen: int,
    valueIdLen: int,
    hex: Bytes_t,
  }

  type PolkaSignatureProto_t = {
    byteLen: int,
    validatorAddressLen: int,
    signature: SignatureProto_t,
    hex: Bytes_t,
  }

  type PolkaCertificateProto_t = {
    byteLen: int,
    height: int,
    round: int,
    valueId: ValueIdProto_t,
    signature: PolkaSignatureProto_t,
    signaturesCount: int,
    hex: Bytes_t,
  }

  type RoundSignatureProto_t = {
    byteLen: int,
    voteType: int,
    validatorAddressLen: int,
    signature: SignatureProto_t,
    valueIdPresent: bool,
    valueId: ValueIdProto_t,
    hex: Bytes_t,
  }

  type RoundCertificateProto_t = {
    byteLen: int,
    height: int,
    round: int,
    certType: int,
    signature: RoundSignatureProto_t,
    signaturesCount: int,
    hex: Bytes_t,
  }

  type LivenessPolkaMessageProto_t = {
    byteLen: int,
    messageTag: int,
    certificate: PolkaCertificateProto_t,
    hex: Bytes_t,
  }

  type LivenessRoundMessageProto_t = {
    byteLen: int,
    messageTag: int,
    certificate: RoundCertificateProto_t,
    hex: Bytes_t,
  }

  pure val SignatureBytesTag = 10
  pure val ValueIdBytesTag = 10
  pure val PolkaSignatureValidatorAddressTag = 10
  pure val PolkaSignatureSignatureTag = 18
  pure val PolkaCertificateHeightTag = 8
  pure val PolkaCertificateRoundTag = 16
  pure val PolkaCertificateValueIdTag = 26
  pure val PolkaCertificateSignaturesTag = 34
  pure val RoundSignatureVoteTypeTag = 8
  pure val RoundSignatureValidatorAddressTag = 18
  pure val RoundSignatureSignatureTag = 26
  pure val RoundSignatureValueIdTag = 34
  pure val RoundCertificateHeightTag = 8
  pure val RoundCertificateRoundTag = 16
  pure val RoundCertificateCertTypeTag = 24
  pure val RoundCertificateSignaturesTag = 34
  pure val LivenessMessageVoteTag = 10
  pure val LivenessMessagePolkaCertificateTag = 18
  pure val LivenessMessageRoundCertificateTag = 26

  pure val VoteTypePrevote = 0
  pure val VoteTypePrecommit = 1
  pure val RoundCertPrecommit = 0
  pure val RoundCertSkip = 1

  pure val SampleHeight = 1
  pure val SampleRound = 2
  pure val ValidatorAddressByteLen = 32
  pure val SignatureByteLen = 64
  pure val ValueIdByteLen = 32
  pure val SampleValidatorAddressHex =
    "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f"
  pure val SampleSignatureHex =
    "404142434445464748494a4b4c4d4e4f505152535455565758595a5b5c5d5e5f606162636465666768696a6b6c6d6e6f707172737475767778797a7b7c7d7e7f"
  pure val SampleValueIdHex =
    "808182838485868788898a8b8c8d8e8f909192939495969798999a9b9c9d9e9f"

  pure val SignatureProtoByteLen = 66
  pure val ValueIdProtoByteLen = 34
  pure val PolkaSignatureByteLen = 102
  pure val PolkaCertificateByteLen = 144
  pure val LivenessPolkaMessageByteLen = 147
  pure val RoundSignatureNilPrecommitByteLen = 104
  pure val RoundSignatureValuePrecommitByteLen = 140
  pure val RoundCertificateSkipNilByteLen = 112
  pure val LivenessRoundSkipMessageByteLen = 114
  pure val RoundCertificatePrecommitValueByteLen = 147
  pure val LivenessRoundPrecommitMessageByteLen = 150

  pure val LivenessPolkaMessageHex =
    "129001080110021a220a20808182838485868788898a8b8c8d8e8f909192939495969798999a9b9c9d9e9f22660a20000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f12420a40404142434445464748494a4b4c4d4e4f505152535455565758595a5b5c5d5e5f606162636465666768696a6b6c6d6e6f707172737475767778797a7b7c7d7e7f"
  pure val LivenessRoundSkipMessageHex =
    "1a70080110021801226808011220000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f1a420a40404142434445464748494a4b4c4d4e4f505152535455565758595a5b5c5d5e5f606162636465666768696a6b6c6d6e6f707172737475767778797a7b7c7d7e7f"

  pure val UnmodeledSignatureHex = "unmodeled-mal-liveness-signature"
  pure val UnmodeledValueIdHex = "unmodeled-mal-liveness-value-id"
  pure val UnmodeledPolkaSignatureHex =
    "unmodeled-mal-liveness-polka-signature"
  pure val UnmodeledPolkaCertificateHex =
    "unmodeled-mal-liveness-polka-certificate"
  pure val UnmodeledRoundSignatureHex =
    "unmodeled-mal-liveness-round-signature"
  pure val UnmodeledRoundCertificateHex =
    "unmodeled-mal-liveness-round-certificate"
  pure val UnmodeledLivenessPolkaHex =
    "unmodeled-mal-liveness-polka-message"
  pure val UnmodeledLivenessRoundHex =
    "unmodeled-mal-liveness-round-message"

  var acceptedPolkaMessages: Set[LivenessPolkaMessageProto_t]
  var acceptedRoundMessages: Set[LivenessRoundMessageProto_t]
  var livenessFiredAction: str

  pure def SignatureProtoHex(signature: SignatureProto_t): Bytes_t =
    if (signature.byteLen == SignatureProtoByteLen and
      signature.signatureLen == SignatureByteLen and
      signature.hex ==
        "0a40404142434445464748494a4b4c4d4e4f505152535455565758595a5b5c5d5e5f606162636465666768696a6b6c6d6e6f707172737475767778797a7b7c7d7e7f") {
      signature.hex
    } else {
      UnmodeledSignatureHex
    }

  pure def SignatureProtoCanonical(signature: SignatureProto_t): bool =
    SignatureProtoHex(signature) != UnmodeledSignatureHex

  pure def ValueIdProtoHex(valueId: ValueIdProto_t): Bytes_t =
    if (valueId.byteLen == ValueIdProtoByteLen and
      valueId.valueIdLen == ValueIdByteLen and
      valueId.hex ==
        "0a20808182838485868788898a8b8c8d8e8f909192939495969798999a9b9c9d9e9f") {
      valueId.hex
    } else {
      UnmodeledValueIdHex
    }

  pure def ValueIdProtoCanonical(valueId: ValueIdProto_t): bool =
    ValueIdProtoHex(valueId) != UnmodeledValueIdHex

  pure def PolkaSignatureProtoHex(sig: PolkaSignatureProto_t): Bytes_t =
    if (sig.byteLen == PolkaSignatureByteLen and
      sig.validatorAddressLen == ValidatorAddressByteLen and
      SignatureProtoCanonical(sig.signature)) {
      "0a20000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f12420a40404142434445464748494a4b4c4d4e4f505152535455565758595a5b5c5d5e5f606162636465666768696a6b6c6d6e6f707172737475767778797a7b7c7d7e7f"
    } else {
      UnmodeledPolkaSignatureHex
    }

  pure def PolkaSignatureProtoCanonical(sig: PolkaSignatureProto_t): bool =
    sig.validatorAddressLen == ValidatorAddressByteLen and
    PolkaSignatureProtoHex(sig) != UnmodeledPolkaSignatureHex and
    sig.hex == PolkaSignatureProtoHex(sig)

  pure def PolkaCertificateProtoHex(
    cert: PolkaCertificateProto_t,
  ): Bytes_t =
    if (cert.byteLen == PolkaCertificateByteLen and
      cert.height == SampleHeight and cert.round == SampleRound and
      ValueIdProtoCanonical(cert.valueId) and
      PolkaSignatureProtoCanonical(cert.signature) and
      cert.signaturesCount == 1) {
      "080110021a220a20808182838485868788898a8b8c8d8e8f909192939495969798999a9b9c9d9e9f22660a20000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f12420a40404142434445464748494a4b4c4d4e4f505152535455565758595a5b5c5d5e5f606162636465666768696a6b6c6d6e6f707172737475767778797a7b7c7d7e7f"
    } else {
      UnmodeledPolkaCertificateHex
    }

  pure def PolkaCertificateProtoCanonical(
    cert: PolkaCertificateProto_t,
  ): bool =
    cert.height >= 0 and
    cert.round >= 0 and
    PolkaCertificateProtoHex(cert) != UnmodeledPolkaCertificateHex and
    cert.hex == PolkaCertificateProtoHex(cert)

  pure def RoundSignatureExpectedLen(sig: RoundSignatureProto_t): int =
    if (sig.valueIdPresent) {
      RoundSignatureValuePrecommitByteLen
    } else {
      RoundSignatureNilPrecommitByteLen
    }

  pure def RoundSignatureProtoHex(sig: RoundSignatureProto_t): Bytes_t =
    if (sig.byteLen == RoundSignatureExpectedLen(sig) and
      sig.voteType == VoteTypePrecommit and
      sig.validatorAddressLen == ValidatorAddressByteLen and
      SignatureProtoCanonical(sig.signature) and not(sig.valueIdPresent)) {
      "08011220000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f1a420a40404142434445464748494a4b4c4d4e4f505152535455565758595a5b5c5d5e5f606162636465666768696a6b6c6d6e6f707172737475767778797a7b7c7d7e7f"
    } else if (sig.byteLen == RoundSignatureExpectedLen(sig) and
      sig.voteType == VoteTypePrecommit and
      sig.validatorAddressLen == ValidatorAddressByteLen and
      SignatureProtoCanonical(sig.signature) and sig.valueIdPresent and
      ValueIdProtoCanonical(sig.valueId)) {
      "08011220000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f1a420a40404142434445464748494a4b4c4d4e4f505152535455565758595a5b5c5d5e5f606162636465666768696a6b6c6d6e6f707172737475767778797a7b7c7d7e7f22220a20808182838485868788898a8b8c8d8e8f909192939495969798999a9b9c9d9e9f"
    } else {
      UnmodeledRoundSignatureHex
    }

  pure def RoundSignatureProtoCanonical(sig: RoundSignatureProto_t): bool =
    sig.voteType == VoteTypePrecommit and
    sig.validatorAddressLen == ValidatorAddressByteLen and
    SignatureProtoCanonical(sig.signature) and
    (not(sig.valueIdPresent) or ValueIdProtoCanonical(sig.valueId)) and
    RoundSignatureProtoHex(sig) != UnmodeledRoundSignatureHex and
    sig.hex == RoundSignatureProtoHex(sig)

  pure def RoundCertificateExpectedLen(
    cert: RoundCertificateProto_t,
  ): int =
    if (cert.certType == RoundCertSkip) {
      RoundCertificateSkipNilByteLen
    } else {
      RoundCertificatePrecommitValueByteLen
    }

  pure def RoundCertificateProtoHex(
    cert: RoundCertificateProto_t,
  ): Bytes_t =
    if (cert.byteLen == RoundCertificateExpectedLen(cert) and
      cert.height == SampleHeight and cert.round == SampleRound and
      cert.certType == RoundCertSkip and cert.signaturesCount == 1 and
      RoundSignatureProtoCanonical(cert.signature) and
      not(cert.signature.valueIdPresent)) {
      "080110021801226808011220000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f1a420a40404142434445464748494a4b4c4d4e4f505152535455565758595a5b5c5d5e5f606162636465666768696a6b6c6d6e6f707172737475767778797a7b7c7d7e7f"
    } else if (cert.byteLen == RoundCertificateExpectedLen(cert) and
      cert.height == SampleHeight and cert.round == SampleRound and
      cert.certType == RoundCertPrecommit and cert.signaturesCount == 1 and
      RoundSignatureProtoCanonical(cert.signature) and
      cert.signature.valueIdPresent) {
      "08011002228c0108011220000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f1a420a40404142434445464748494a4b4c4d4e4f505152535455565758595a5b5c5d5e5f606162636465666768696a6b6c6d6e6f707172737475767778797a7b7c7d7e7f22220a20808182838485868788898a8b8c8d8e8f909192939495969798999a9b9c9d9e9f"
    } else {
      UnmodeledRoundCertificateHex
    }

  pure def RoundCertificateProtoCanonical(
    cert: RoundCertificateProto_t,
  ): bool =
    cert.height >= 0 and
    cert.round >= 0 and
    (cert.certType == RoundCertSkip or cert.certType == RoundCertPrecommit) and
    cert.signaturesCount == 1 and
    RoundSignatureProtoCanonical(cert.signature) and
    RoundCertificateProtoHex(cert) != UnmodeledRoundCertificateHex and
    cert.hex == RoundCertificateProtoHex(cert)

  pure def LivenessPolkaMessageProtoHex(
    message: LivenessPolkaMessageProto_t,
  ): Bytes_t =
    if (message.byteLen == LivenessPolkaMessageByteLen and
      message.messageTag == LivenessMessagePolkaCertificateTag and
      PolkaCertificateProtoCanonical(message.certificate)) {
      LivenessPolkaMessageHex
    } else {
      UnmodeledLivenessPolkaHex
    }

  pure def LivenessPolkaMessageProtoCanonical(
    message: LivenessPolkaMessageProto_t,
  ): bool =
    message.messageTag == LivenessMessagePolkaCertificateTag and
    PolkaCertificateProtoCanonical(message.certificate) and
    LivenessPolkaMessageProtoHex(message) != UnmodeledLivenessPolkaHex and
    message.hex == LivenessPolkaMessageProtoHex(message)

  pure def LivenessRoundMessageExpectedLen(
    message: LivenessRoundMessageProto_t,
  ): int =
    if (message.certificate.certType == RoundCertSkip) {
      LivenessRoundSkipMessageByteLen
    } else {
      LivenessRoundPrecommitMessageByteLen
    }

  pure def LivenessRoundMessageProtoHex(
    message: LivenessRoundMessageProto_t,
  ): Bytes_t =
    if (message.byteLen == LivenessRoundMessageExpectedLen(message) and
      message.messageTag == LivenessMessageRoundCertificateTag and
      RoundCertificateProtoCanonical(message.certificate) and
      message.certificate.certType == RoundCertSkip) {
      LivenessRoundSkipMessageHex
    } else if (message.byteLen == LivenessRoundMessageExpectedLen(message) and
      message.messageTag == LivenessMessageRoundCertificateTag and
      RoundCertificateProtoCanonical(message.certificate) and
      message.certificate.certType == RoundCertPrecommit) {
      "1a930108011002228c0108011220000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f1a420a40404142434445464748494a4b4c4d4e4f505152535455565758595a5b5c5d5e5f606162636465666768696a6b6c6d6e6f707172737475767778797a7b7c7d7e7f22220a20808182838485868788898a8b8c8d8e8f909192939495969798999a9b9c9d9e9f"
    } else {
      UnmodeledLivenessRoundHex
    }

  pure def LivenessRoundMessageProtoCanonical(
    message: LivenessRoundMessageProto_t,
  ): bool =
    message.messageTag == LivenessMessageRoundCertificateTag and
    RoundCertificateProtoCanonical(message.certificate) and
    LivenessRoundMessageProtoHex(message) != UnmodeledLivenessRoundHex and
    message.hex == LivenessRoundMessageProtoHex(message)

  pure def LivenessProtoTagsPinned: bool =
    SignatureBytesTag == 10 and
    ValueIdBytesTag == 10 and
    PolkaSignatureValidatorAddressTag == 10 and
    PolkaSignatureSignatureTag == 18 and
    PolkaCertificateHeightTag == 8 and
    PolkaCertificateRoundTag == 16 and
    PolkaCertificateValueIdTag == 26 and
    PolkaCertificateSignaturesTag == 34 and
    RoundSignatureVoteTypeTag == 8 and
    RoundSignatureValidatorAddressTag == 18 and
    RoundSignatureSignatureTag == 26 and
    RoundSignatureValueIdTag == 34 and
    RoundCertificateHeightTag == 8 and
    RoundCertificateRoundTag == 16 and
    RoundCertificateCertTypeTag == 24 and
    RoundCertificateSignaturesTag == 34 and
    LivenessMessageVoteTag == 10 and
    LivenessMessagePolkaCertificateTag == 18 and
    LivenessMessageRoundCertificateTag == 26

  pure def LivenessProtoLengthsPinned: bool =
    SignatureProtoByteLen == 66 and
    ValueIdProtoByteLen == 34 and
    PolkaSignatureByteLen == 102 and
    PolkaCertificateByteLen == 144 and
    LivenessPolkaMessageByteLen == 147 and
    RoundSignatureNilPrecommitByteLen == 104 and
    RoundSignatureValuePrecommitByteLen == 140 and
    RoundCertificateSkipNilByteLen == 112 and
    LivenessRoundSkipMessageByteLen == 114 and
    RoundCertificatePrecommitValueByteLen == 147 and
    LivenessRoundPrecommitMessageByteLen == 150

  action Init = all {
    acceptedPolkaMessages' = Set(),
    acceptedRoundMessages' = Set(),
    livenessFiredAction' = "Init",
  }

  action AcceptPolkaMessage(message: LivenessPolkaMessageProto_t): bool =
    all {
      LivenessPolkaMessageProtoCanonical(message),
      acceptedPolkaMessages' = acceptedPolkaMessages.union(Set(message)),
      acceptedRoundMessages' = acceptedRoundMessages,
      livenessFiredAction' = "AcceptPolkaMessage",
    }

  action AcceptRoundMessage(message: LivenessRoundMessageProto_t): bool =
    all {
      LivenessRoundMessageProtoCanonical(message),
      acceptedPolkaMessages' = acceptedPolkaMessages,
      acceptedRoundMessages' = acceptedRoundMessages.union(Set(message)),
      livenessFiredAction' = "AcceptRoundMessage",
    }

  action Stutter: bool =
    all {
      acceptedPolkaMessages' = acceptedPolkaMessages,
      acceptedRoundMessages' = acceptedRoundMessages,
      livenessFiredAction' = livenessFiredAction,
    }

  pure def AcceptedPolkaMessagesCanonical: bool =
    acceptedPolkaMessages.forall(LivenessPolkaMessageProtoCanonical)

  pure def AcceptedRoundMessagesCanonical: bool =
    acceptedRoundMessages.forall(LivenessRoundMessageProtoCanonical)

  val Safety =
    LivenessProtoTagsPinned and
    LivenessProtoLengthsPinned and
    AcceptedPolkaMessagesCanonical and
    AcceptedRoundMessagesCanonical
}

module CrosslinkMalachiteLivenessProtobufFormatTest {
  import CrosslinkMalachiteLivenessProtobufFormat.* from "./CrosslinkMalachiteLivenessProtobufFormat"
  export CrosslinkMalachiteLivenessProtobufFormat.*

  def SignatureProto(
    byteLen: int,
    signatureLen: int,
    hex: Bytes_t,
  ): SignatureProto_t = {
    byteLen: byteLen,
    signatureLen: signatureLen,
    hex: hex,
  }

  def ValueIdProto(
    byteLen: int,
    valueIdLen: int,
    hex: Bytes_t,
  ): ValueIdProto_t = {
    byteLen: byteLen,
    valueIdLen: valueIdLen,
    hex: hex,
  }

  def PolkaSignatureProto(
    byteLen: int,
    validatorAddressLen: int,
    signature: SignatureProto_t,
    hex: Bytes_t,
  ): PolkaSignatureProto_t = {
    byteLen: byteLen,
    validatorAddressLen: validatorAddressLen,
    signature: signature,
    hex: hex,
  }

  def PolkaCertificateProto(
    byteLen: int,
    height: int,
    round: int,
    valueId: ValueIdProto_t,
    signature: PolkaSignatureProto_t,
    signaturesCount: int,
    hex: Bytes_t,
  ): PolkaCertificateProto_t = {
    byteLen: byteLen,
    height: height,
    round: round,
    valueId: valueId,
    signature: signature,
    signaturesCount: signaturesCount,
    hex: hex,
  }

  def RoundSignatureProto(
    byteLen: int,
    voteType: int,
    validatorAddressLen: int,
    signature: SignatureProto_t,
    valueIdPresent: bool,
    valueId: ValueIdProto_t,
    hex: Bytes_t,
  ): RoundSignatureProto_t = {
    byteLen: byteLen,
    voteType: voteType,
    validatorAddressLen: validatorAddressLen,
    signature: signature,
    valueIdPresent: valueIdPresent,
    valueId: valueId,
    hex: hex,
  }

  def RoundCertificateProto(
    byteLen: int,
    height: int,
    round: int,
    certType: int,
    signature: RoundSignatureProto_t,
    signaturesCount: int,
    hex: Bytes_t,
  ): RoundCertificateProto_t = {
    byteLen: byteLen,
    height: height,
    round: round,
    certType: certType,
    signature: signature,
    signaturesCount: signaturesCount,
    hex: hex,
  }

  def LivenessPolkaMessageProto(
    byteLen: int,
    messageTag: int,
    certificate: PolkaCertificateProto_t,
    hex: Bytes_t,
  ): LivenessPolkaMessageProto_t = {
    byteLen: byteLen,
    messageTag: messageTag,
    certificate: certificate,
    hex: hex,
  }

  def LivenessRoundMessageProto(
    byteLen: int,
    messageTag: int,
    certificate: RoundCertificateProto_t,
    hex: Bytes_t,
  ): LivenessRoundMessageProto_t = {
    byteLen: byteLen,
    messageTag: messageTag,
    certificate: certificate,
    hex: hex,
  }

  pure val SampleSignature =
    SignatureProto(
      66,
      64,
      "0a40404142434445464748494a4b4c4d4e4f505152535455565758595a5b5c5d5e5f606162636465666768696a6b6c6d6e6f707172737475767778797a7b7c7d7e7f",
    )

  pure val MissingSignature =
    SignatureProto(0, 0, "")

  pure val SampleValueId =
    ValueIdProto(
      34,
      32,
      "0a20808182838485868788898a8b8c8d8e8f909192939495969798999a9b9c9d9e9f",
    )

  pure val MissingValueId =
    ValueIdProto(0, 0, "")

  pure val SamplePolkaSignature =
    PolkaSignatureProto(
      102,
      32,
      SampleSignature,
      "0a20000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f12420a40404142434445464748494a4b4c4d4e4f505152535455565758595a5b5c5d5e5f606162636465666768696a6b6c6d6e6f707172737475767778797a7b7c7d7e7f",
    )

  pure val ShortPolkaSignature =
    PolkaSignatureProto(
      101,
      31,
      SampleSignature,
      "0a1f000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e12420a40404142434445464748494a4b4c4d4e4f505152535455565758595a5b5c5d5e5f606162636465666768696a6b6c6d6e6f707172737475767778797a7b7c7d7e7f",
    )

  pure val PolkaCertificate =
    PolkaCertificateProto(
      144,
      1,
      2,
      SampleValueId,
      SamplePolkaSignature,
      1,
      "080110021a220a20808182838485868788898a8b8c8d8e8f909192939495969798999a9b9c9d9e9f22660a20000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f12420a40404142434445464748494a4b4c4d4e4f505152535455565758595a5b5c5d5e5f606162636465666768696a6b6c6d6e6f707172737475767778797a7b7c7d7e7f",
    )

  pure val PolkaCertificateMissingValue =
    PolkaCertificateProto(
      108,
      1,
      2,
      MissingValueId,
      SamplePolkaSignature,
      1,
      "0801100222660a20000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f12420a40404142434445464748494a4b4c4d4e4f505152535455565758595a5b5c5d5e5f606162636465666768696a6b6c6d6e6f707172737475767778797a7b7c7d7e7f",
    )

  pure val PolkaCertificateShortSigner =
    PolkaCertificateProto(
      143,
      1,
      2,
      SampleValueId,
      ShortPolkaSignature,
      1,
      "080110021a220a20808182838485868788898a8b8c8d8e8f909192939495969798999a9b9c9d9e9f22650a1f000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e12420a40404142434445464748494a4b4c4d4e4f505152535455565758595a5b5c5d5e5f606162636465666768696a6b6c6d6e6f707172737475767778797a7b7c7d7e7f",
    )

  pure val LivenessPolkaMessage =
    LivenessPolkaMessageProto(
      147,
      LivenessMessagePolkaCertificateTag,
      PolkaCertificate,
      LivenessPolkaMessageHex,
    )

  pure val LivenessPolkaWithVoteTag =
    LivenessPolkaMessageProto(
      147,
      LivenessMessageVoteTag,
      PolkaCertificate,
      "0a9001080110021a220a20808182838485868788898a8b8c8d8e8f909192939495969798999a9b9c9d9e9f22660a20000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f12420a40404142434445464748494a4b4c4d4e4f505152535455565758595a5b5c5d5e5f606162636465666768696a6b6c6d6e6f707172737475767778797a7b7c7d7e7f",
    )

  pure val RoundSignatureNilPrecommit =
    RoundSignatureProto(
      104,
      VoteTypePrecommit,
      32,
      SampleSignature,
      false,
      MissingValueId,
      "08011220000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f1a420a40404142434445464748494a4b4c4d4e4f505152535455565758595a5b5c5d5e5f606162636465666768696a6b6c6d6e6f707172737475767778797a7b7c7d7e7f",
    )

  pure val RoundSignatureValuePrecommit =
    RoundSignatureProto(
      140,
      VoteTypePrecommit,
      32,
      SampleSignature,
      true,
      SampleValueId,
      "08011220000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f1a420a40404142434445464748494a4b4c4d4e4f505152535455565758595a5b5c5d5e5f606162636465666768696a6b6c6d6e6f707172737475767778797a7b7c7d7e7f22220a20808182838485868788898a8b8c8d8e8f909192939495969798999a9b9c9d9e9f",
    )

  pure val RoundSignaturePrevote =
    RoundSignatureProto(
      102,
      VoteTypePrevote,
      32,
      SampleSignature,
      false,
      MissingValueId,
      "1220000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f1a420a40404142434445464748494a4b4c4d4e4f505152535455565758595a5b5c5d5e5f606162636465666768696a6b6c6d6e6f707172737475767778797a7b7c7d7e7f",
    )

  pure val RoundCertificateSkipNil =
    RoundCertificateProto(
      112,
      1,
      2,
      RoundCertSkip,
      RoundSignatureNilPrecommit,
      1,
      "080110021801226808011220000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f1a420a40404142434445464748494a4b4c4d4e4f505152535455565758595a5b5c5d5e5f606162636465666768696a6b6c6d6e6f707172737475767778797a7b7c7d7e7f",
    )

  pure val RoundCertificatePrecommitValue =
    RoundCertificateProto(
      147,
      1,
      2,
      RoundCertPrecommit,
      RoundSignatureValuePrecommit,
      1,
      "08011002228c0108011220000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f1a420a40404142434445464748494a4b4c4d4e4f505152535455565758595a5b5c5d5e5f606162636465666768696a6b6c6d6e6f707172737475767778797a7b7c7d7e7f22220a20808182838485868788898a8b8c8d8e8f909192939495969798999a9b9c9d9e9f",
    )

  pure val RoundCertificatePrecommitNil =
    RoundCertificateProto(
      108,
      1,
      2,
      RoundCertPrecommit,
      RoundSignatureNilPrecommit,
      1,
      "08011002226808011220000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f1a420a40404142434445464748494a4b4c4d4e4f505152535455565758595a5b5c5d5e5f606162636465666768696a6b6c6d6e6f707172737475767778797a7b7c7d7e7f",
    )

  pure val RoundCertificateSkipValue =
    RoundCertificateProto(
      148,
      1,
      2,
      RoundCertSkip,
      RoundSignatureValuePrecommit,
      1,
      "080110021801228c0108011220000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f1a420a40404142434445464748494a4b4c4d4e4f505152535455565758595a5b5c5d5e5f606162636465666768696a6b6c6d6e6f707172737475767778797a7b7c7d7e7f22220a20808182838485868788898a8b8c8d8e8f909192939495969798999a9b9c9d9e9f",
    )

  pure val LivenessRoundSkipMessage =
    LivenessRoundMessageProto(
      114,
      LivenessMessageRoundCertificateTag,
      RoundCertificateSkipNil,
      LivenessRoundSkipMessageHex,
    )

  pure val LivenessRoundPrecommitMessage =
    LivenessRoundMessageProto(
      150,
      LivenessMessageRoundCertificateTag,
      RoundCertificatePrecommitValue,
      "1a930108011002228c0108011220000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f1a420a40404142434445464748494a4b4c4d4e4f505152535455565758595a5b5c5d5e5f606162636465666768696a6b6c6d6e6f707172737475767778797a7b7c7d7e7f22220a20808182838485868788898a8b8c8d8e8f909192939495969798999a9b9c9d9e9f",
    )

  pure val LivenessRoundWithPolkaTag =
    LivenessRoundMessageProto(
      114,
      LivenessMessagePolkaCertificateTag,
      RoundCertificateSkipNil,
      "1270080110021801226808011220000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f1a420a40404142434445464748494a4b4c4d4e4f505152535455565758595a5b5c5d5e5f606162636465666768696a6b6c6d6e6f707172737475767778797a7b7c7d7e7f",
    )

  pure val TestPolkaMessages = Set(
    LivenessPolkaMessage,
    LivenessPolkaWithVoteTag,
  )

  pure val TestRoundMessages = Set(
    LivenessRoundSkipMessage,
    LivenessRoundPrecommitMessage,
    LivenessRoundWithPolkaTag,
  )

  action Next: bool =
    any {
      nondet polka = oneOf(TestPolkaMessages)
      AcceptPolkaMessage(polka),
      nondet roundMessage = oneOf(TestRoundMessages)
      AcceptRoundMessage(roundMessage),
      Stutter,
    }

  action unchangedAll = all {
    acceptedPolkaMessages' = acceptedPolkaMessages,
    acceptedRoundMessages' = acceptedRoundMessages,
    livenessFiredAction' = livenessFiredAction,
  }

  run livenessProtoTagsAndLengthsPinnedTest = {
    Init.then(all {
      assert(LivenessProtoTagsPinned),
      assert(LivenessProtoLengthsPinned),
      unchangedAll,
    })
  }

  run polkaCertificateExactHexTest = {
    Init.then(all {
      assert(PolkaCertificateProtoCanonical(PolkaCertificate)),
      assert(LivenessPolkaMessageProtoCanonical(LivenessPolkaMessage)),
      unchangedAll,
    })
  }

  run roundCertificateExactHexTest = {
    Init.then(all {
      assert(RoundCertificateProtoCanonical(RoundCertificateSkipNil)),
      assert(RoundCertificateProtoCanonical(RoundCertificatePrecommitValue)),
      assert(LivenessRoundMessageProtoCanonical(LivenessRoundSkipMessage)),
      assert(LivenessRoundMessageProtoCanonical(LivenessRoundPrecommitMessage)),
      unchangedAll,
    })
  }

  run enumDefaultOmissionPinnedTest = {
    Init.then(all {
      assert(RoundCertificateProtoHex(RoundCertificatePrecommitValue) ==
        RoundCertificatePrecommitValue.hex),
      assert(not(RoundCertificatePrecommitValue.hex ==
        "080110021800228c0108011220000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f1a420a40404142434445464748494a4b4c4d4e4f505152535455565758595a5b5c5d5e5f606162636465666768696a6b6c6d6e6f707172737475767778797a7b7c7d7e7f22220a20808182838485868788898a8b8c8d8e8f909192939495969798999a9b9c9d9e9f")),
      unchangedAll,
    })
  }

  run acceptLivenessMessagesTest = {
    Init
      .then(AcceptPolkaMessage(LivenessPolkaMessage))
      .then(AcceptRoundMessage(LivenessRoundSkipMessage))
      .then(AcceptRoundMessage(LivenessRoundPrecommitMessage))
      .then(all {
        assert(acceptedPolkaMessages.contains(LivenessPolkaMessage)),
        assert(acceptedRoundMessages.contains(LivenessRoundSkipMessage)),
        assert(acceptedRoundMessages.contains(LivenessRoundPrecommitMessage)),
        assert(Safety),
        unchangedAll,
      })
  }

  run polkaMissingValueRejectedTest = {
    Init.then(all {
      assert(not(PolkaCertificateProtoCanonical(PolkaCertificateMissingValue))),
      unchangedAll,
    })
  }

  run polkaShortSignerRejectedTest = {
    Init.then(all {
      assert(not(PolkaCertificateProtoCanonical(PolkaCertificateShortSigner))),
      unchangedAll,
    })
  }

  run polkaWrongOneofRejectedTest = {
    Init.then(AcceptPolkaMessage(LivenessPolkaWithVoteTag)).fail()
  }

  run roundPrevoteRejectedTest = {
    Init.then(all {
      assert(not(RoundSignatureProtoCanonical(RoundSignaturePrevote))),
      unchangedAll,
    })
  }

  run precommitNilCertificateRejectedTest = {
    Init.then(all {
      assert(not(RoundCertificateProtoCanonical(RoundCertificatePrecommitNil))),
      unchangedAll,
    })
  }

  run skipValueCertificateRejectedTest = {
    Init.then(all {
      assert(not(RoundCertificateProtoCanonical(RoundCertificateSkipValue))),
      unchangedAll,
    })
  }

  run roundWrongOneofRejectedTest = {
    Init.then(AcceptRoundMessage(LivenessRoundWithPolkaTag)).fail()
  }

  run malachiteLivenessProtoSafetyTest = {
    Init.then(all {
      assert(Safety),
      unchangedAll,
    })
  }
}

module CrosslinkMalachiteLivenessProtobufFormatModel {
  import CrosslinkMalachiteLivenessProtobufFormatTest.* from "./CrosslinkMalachiteLivenessProtobufFormat"
  export CrosslinkMalachiteLivenessProtobufFormatTest.*
}
