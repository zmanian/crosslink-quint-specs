module CrosslinkMalachiteSyncProtobufFormat {
  /*
   Malachite sync protobuf wire format.

   This slice pins the sync request/response boundary in
   zebra-crosslink/proto/sync.proto and zebra-crosslink/src/malctx.rs:

   - ValueRequest and SyncRequest oneof wrapper,
   - CommitCertificate with one CommitSignature,
   - SyncedValue carrying value bytes plus the commit certificate,
   - ValueResponse and SyncResponse oneof wrapper,
   - the no-value ValueResponse case, which intentionally has the same raw
     bytes as SyncRequest in its own message context.
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

  type ValueRequestProto_t = {
    byteLen: int,
    height: int,
    hex: Bytes_t,
  }

  type SyncRequestProto_t = {
    byteLen: int,
    requestTag: int,
    valueRequest: ValueRequestProto_t,
    hex: Bytes_t,
  }

  type CommitSignatureProto_t = {
    byteLen: int,
    validatorAddressLen: int,
    signature: SignatureProto_t,
    hex: Bytes_t,
  }

  type CommitCertificateProto_t = {
    byteLen: int,
    height: int,
    round: int,
    valueId: ValueIdProto_t,
    signature: CommitSignatureProto_t,
    signaturesCount: int,
    hex: Bytes_t,
  }

  type SyncedValueProto_t = {
    byteLen: int,
    valueBytesLen: int,
    valueBytesHex: Bytes_t,
    certificate: CommitCertificateProto_t,
    certificatePresent: bool,
    hex: Bytes_t,
  }

  type ValueResponseProto_t = {
    byteLen: int,
    height: int,
    valuePresent: bool,
    value: SyncedValueProto_t,
    hex: Bytes_t,
  }

  type SyncResponseProto_t = {
    byteLen: int,
    responseTag: int,
    valueResponse: ValueResponseProto_t,
    hex: Bytes_t,
  }

  pure val SignatureBytesTag = 10
  pure val ValueIdBytesTag = 10
  pure val ValueRequestHeightTag = 8
  pure val SyncRequestValueRequestTag = 10
  pure val CommitSignatureValidatorAddressTag = 10
  pure val CommitSignatureSignatureTag = 18
  pure val CommitCertificateHeightTag = 8
  pure val CommitCertificateRoundTag = 16
  pure val CommitCertificateValueIdTag = 26
  pure val CommitCertificateSignaturesTag = 34
  pure val SyncedValueValueBytesTag = 10
  pure val SyncedValueCertificateTag = 18
  pure val ValueResponseHeightTag = 8
  pure val ValueResponseValueTag = 18
  pure val SyncResponseValueResponseTag = 10

  pure val SampleHeight = 1
  pure val SampleRound = 2
  pure val ValidatorAddressByteLen = 32
  pure val SignatureByteLen = 64
  pure val ValueIdByteLen = 32
  pure val SampleValueBytesLen = 3
  pure val SampleValueBytesHex = "aabbcc"

  pure val SignatureProtoByteLen = 66
  pure val ValueIdProtoByteLen = 34
  pure val ValueRequestByteLen = 2
  pure val SyncRequestByteLen = 4
  pure val CommitSignatureByteLen = 102
  pure val CommitCertificateByteLen = 144
  pure val SyncedValueByteLen = 152
  pure val ValueResponseWithValueByteLen = 157
  pure val SyncResponseWithValueByteLen = 160
  pure val ValueResponseNoValueByteLen = 2
  pure val SyncResponseNoValueByteLen = 4

  pure val UnmodeledSignatureHex = "unmodeled-mal-sync-signature"
  pure val UnmodeledValueIdHex = "unmodeled-mal-sync-value-id"
  pure val UnmodeledValueRequestHex = "unmodeled-mal-sync-value-request"
  pure val UnmodeledSyncRequestHex = "unmodeled-mal-sync-request"
  pure val UnmodeledCommitSignatureHex = "unmodeled-mal-sync-commit-sig"
  pure val UnmodeledCommitCertificateHex =
    "unmodeled-mal-sync-commit-cert"
  pure val UnmodeledSyncedValueHex = "unmodeled-mal-sync-synced-value"
  pure val UnmodeledValueResponseHex = "unmodeled-mal-sync-value-response"
  pure val UnmodeledSyncResponseHex = "unmodeled-mal-sync-response"

  var acceptedSyncRequests: Set[SyncRequestProto_t]
  var acceptedSyncResponses: Set[SyncResponseProto_t]
  var syncFiredAction: str

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

  pure def ValueRequestProtoHex(request: ValueRequestProto_t): Bytes_t =
    if (request.byteLen == ValueRequestByteLen and
      request.height == SampleHeight) {
      "0801"
    } else {
      UnmodeledValueRequestHex
    }

  pure def ValueRequestProtoCanonical(request: ValueRequestProto_t): bool =
    request.height >= 0 and
    ValueRequestProtoHex(request) != UnmodeledValueRequestHex and
    request.hex == ValueRequestProtoHex(request)

  pure def SyncRequestProtoHex(request: SyncRequestProto_t): Bytes_t =
    if (request.byteLen == SyncRequestByteLen and
      request.requestTag == SyncRequestValueRequestTag and
      ValueRequestProtoCanonical(request.valueRequest)) {
      "0a020801"
    } else {
      UnmodeledSyncRequestHex
    }

  pure def SyncRequestProtoCanonical(request: SyncRequestProto_t): bool =
    request.requestTag == SyncRequestValueRequestTag and
    ValueRequestProtoCanonical(request.valueRequest) and
    SyncRequestProtoHex(request) != UnmodeledSyncRequestHex and
    request.hex == SyncRequestProtoHex(request)

  pure def CommitSignatureProtoHex(sig: CommitSignatureProto_t): Bytes_t =
    if (sig.byteLen == CommitSignatureByteLen and
      sig.validatorAddressLen == ValidatorAddressByteLen and
      SignatureProtoCanonical(sig.signature)) {
      "0a20000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f12420a40404142434445464748494a4b4c4d4e4f505152535455565758595a5b5c5d5e5f606162636465666768696a6b6c6d6e6f707172737475767778797a7b7c7d7e7f"
    } else {
      UnmodeledCommitSignatureHex
    }

  pure def CommitSignatureProtoCanonical(sig: CommitSignatureProto_t): bool =
    sig.validatorAddressLen == ValidatorAddressByteLen and
    CommitSignatureProtoHex(sig) != UnmodeledCommitSignatureHex and
    sig.hex == CommitSignatureProtoHex(sig)

  pure def CommitCertificateProtoHex(
    cert: CommitCertificateProto_t,
  ): Bytes_t =
    if (cert.byteLen == CommitCertificateByteLen and
      cert.height == SampleHeight and cert.round == SampleRound and
      ValueIdProtoCanonical(cert.valueId) and
      CommitSignatureProtoCanonical(cert.signature) and
      cert.signaturesCount == 1) {
      "080110021a220a20808182838485868788898a8b8c8d8e8f909192939495969798999a9b9c9d9e9f22660a20000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f12420a40404142434445464748494a4b4c4d4e4f505152535455565758595a5b5c5d5e5f606162636465666768696a6b6c6d6e6f707172737475767778797a7b7c7d7e7f"
    } else {
      UnmodeledCommitCertificateHex
    }

  pure def CommitCertificateProtoCanonical(
    cert: CommitCertificateProto_t,
  ): bool =
    cert.height >= 0 and
    cert.round >= 0 and
    cert.signaturesCount == 1 and
    CommitCertificateProtoHex(cert) != UnmodeledCommitCertificateHex and
    cert.hex == CommitCertificateProtoHex(cert)

  pure def SyncedValueProtoHex(value: SyncedValueProto_t): Bytes_t =
    if (value.byteLen == SyncedValueByteLen and
      value.valueBytesLen == SampleValueBytesLen and
      value.valueBytesHex == SampleValueBytesHex and
      value.certificatePresent and
      CommitCertificateProtoCanonical(value.certificate)) {
      "0a03aabbcc129001080110021a220a20808182838485868788898a8b8c8d8e8f909192939495969798999a9b9c9d9e9f22660a20000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f12420a40404142434445464748494a4b4c4d4e4f505152535455565758595a5b5c5d5e5f606162636465666768696a6b6c6d6e6f707172737475767778797a7b7c7d7e7f"
    } else {
      UnmodeledSyncedValueHex
    }

  pure def SyncedValueProtoCanonical(value: SyncedValueProto_t): bool =
    value.valueBytesLen == SampleValueBytesLen and
    value.valueBytesHex == SampleValueBytesHex and
    value.certificatePresent and
    CommitCertificateProtoCanonical(value.certificate) and
    SyncedValueProtoHex(value) != UnmodeledSyncedValueHex and
    value.hex == SyncedValueProtoHex(value)

  pure def ValueResponseExpectedLen(response: ValueResponseProto_t): int =
    if (response.valuePresent) {
      ValueResponseWithValueByteLen
    } else {
      ValueResponseNoValueByteLen
    }

  pure def ValueResponseProtoHex(response: ValueResponseProto_t): Bytes_t =
    if (response.byteLen == ValueResponseExpectedLen(response) and
      response.height == SampleHeight and response.valuePresent and
      SyncedValueProtoCanonical(response.value)) {
      "08011298010a03aabbcc129001080110021a220a20808182838485868788898a8b8c8d8e8f909192939495969798999a9b9c9d9e9f22660a20000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f12420a40404142434445464748494a4b4c4d4e4f505152535455565758595a5b5c5d5e5f606162636465666768696a6b6c6d6e6f707172737475767778797a7b7c7d7e7f"
    } else if (response.byteLen == ValueResponseExpectedLen(response) and
      response.height == SampleHeight and not(response.valuePresent)) {
      "0801"
    } else {
      UnmodeledValueResponseHex
    }

  pure def ValueResponseProtoCanonical(
    response: ValueResponseProto_t,
  ): bool =
    response.height >= 0 and
    (not(response.valuePresent) or SyncedValueProtoCanonical(response.value)) and
    ValueResponseProtoHex(response) != UnmodeledValueResponseHex and
    response.hex == ValueResponseProtoHex(response)

  pure def SyncResponseExpectedLen(response: SyncResponseProto_t): int =
    if (response.valueResponse.valuePresent) {
      SyncResponseWithValueByteLen
    } else {
      SyncResponseNoValueByteLen
    }

  pure def SyncResponseProtoHex(response: SyncResponseProto_t): Bytes_t =
    if (response.byteLen == SyncResponseExpectedLen(response) and
      response.responseTag == SyncResponseValueResponseTag and
      ValueResponseProtoCanonical(response.valueResponse) and
      response.valueResponse.valuePresent) {
      "0a9d0108011298010a03aabbcc129001080110021a220a20808182838485868788898a8b8c8d8e8f909192939495969798999a9b9c9d9e9f22660a20000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f12420a40404142434445464748494a4b4c4d4e4f505152535455565758595a5b5c5d5e5f606162636465666768696a6b6c6d6e6f707172737475767778797a7b7c7d7e7f"
    } else if (response.byteLen == SyncResponseExpectedLen(response) and
      response.responseTag == SyncResponseValueResponseTag and
      ValueResponseProtoCanonical(response.valueResponse) and
      not(response.valueResponse.valuePresent)) {
      "0a020801"
    } else {
      UnmodeledSyncResponseHex
    }

  pure def SyncResponseProtoCanonical(response: SyncResponseProto_t): bool =
    response.responseTag == SyncResponseValueResponseTag and
    ValueResponseProtoCanonical(response.valueResponse) and
    SyncResponseProtoHex(response) != UnmodeledSyncResponseHex and
    response.hex == SyncResponseProtoHex(response)

  pure def SyncProtoTagsPinned: bool =
    SignatureBytesTag == 10 and
    ValueIdBytesTag == 10 and
    ValueRequestHeightTag == 8 and
    SyncRequestValueRequestTag == 10 and
    CommitSignatureValidatorAddressTag == 10 and
    CommitSignatureSignatureTag == 18 and
    CommitCertificateHeightTag == 8 and
    CommitCertificateRoundTag == 16 and
    CommitCertificateValueIdTag == 26 and
    CommitCertificateSignaturesTag == 34 and
    SyncedValueValueBytesTag == 10 and
    SyncedValueCertificateTag == 18 and
    ValueResponseHeightTag == 8 and
    ValueResponseValueTag == 18 and
    SyncResponseValueResponseTag == 10

  pure def SyncProtoLengthsPinned: bool =
    SignatureProtoByteLen == 66 and
    ValueIdProtoByteLen == 34 and
    ValueRequestByteLen == 2 and
    SyncRequestByteLen == 4 and
    CommitSignatureByteLen == 102 and
    CommitCertificateByteLen == 144 and
    SyncedValueByteLen == 152 and
    ValueResponseWithValueByteLen == 157 and
    SyncResponseWithValueByteLen == 160 and
    ValueResponseNoValueByteLen == 2 and
    SyncResponseNoValueByteLen == 4

  action Init = all {
    acceptedSyncRequests' = Set(),
    acceptedSyncResponses' = Set(),
    syncFiredAction' = "Init",
  }

  action AcceptSyncRequest(request: SyncRequestProto_t): bool =
    all {
      SyncRequestProtoCanonical(request),
      acceptedSyncRequests' = acceptedSyncRequests.union(Set(request)),
      acceptedSyncResponses' = acceptedSyncResponses,
      syncFiredAction' = "AcceptSyncRequest",
    }

  action AcceptSyncResponse(response: SyncResponseProto_t): bool =
    all {
      SyncResponseProtoCanonical(response),
      acceptedSyncRequests' = acceptedSyncRequests,
      acceptedSyncResponses' = acceptedSyncResponses.union(Set(response)),
      syncFiredAction' = "AcceptSyncResponse",
    }

  action Stutter: bool =
    all {
      acceptedSyncRequests' = acceptedSyncRequests,
      acceptedSyncResponses' = acceptedSyncResponses,
      syncFiredAction' = syncFiredAction,
    }

  pure def AcceptedSyncRequestsCanonical: bool =
    acceptedSyncRequests.forall(SyncRequestProtoCanonical)

  pure def AcceptedSyncResponsesCanonical: bool =
    acceptedSyncResponses.forall(SyncResponseProtoCanonical)

  val Safety =
    SyncProtoTagsPinned and
    SyncProtoLengthsPinned and
    AcceptedSyncRequestsCanonical and
    AcceptedSyncResponsesCanonical
}

module CrosslinkMalachiteSyncProtobufFormatTest {
  import CrosslinkMalachiteSyncProtobufFormat.* from "./CrosslinkMalachiteSyncProtobufFormat"
  export CrosslinkMalachiteSyncProtobufFormat.*

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

  def ValueRequestProto(
    byteLen: int,
    height: int,
    hex: Bytes_t,
  ): ValueRequestProto_t = {
    byteLen: byteLen,
    height: height,
    hex: hex,
  }

  def SyncRequestProto(
    byteLen: int,
    requestTag: int,
    valueRequest: ValueRequestProto_t,
    hex: Bytes_t,
  ): SyncRequestProto_t = {
    byteLen: byteLen,
    requestTag: requestTag,
    valueRequest: valueRequest,
    hex: hex,
  }

  def CommitSignatureProto(
    byteLen: int,
    validatorAddressLen: int,
    signature: SignatureProto_t,
    hex: Bytes_t,
  ): CommitSignatureProto_t = {
    byteLen: byteLen,
    validatorAddressLen: validatorAddressLen,
    signature: signature,
    hex: hex,
  }

  def CommitCertificateProto(
    byteLen: int,
    height: int,
    round: int,
    valueId: ValueIdProto_t,
    signature: CommitSignatureProto_t,
    signaturesCount: int,
    hex: Bytes_t,
  ): CommitCertificateProto_t = {
    byteLen: byteLen,
    height: height,
    round: round,
    valueId: valueId,
    signature: signature,
    signaturesCount: signaturesCount,
    hex: hex,
  }

  def SyncedValueProto(
    byteLen: int,
    valueBytesLen: int,
    valueBytesHex: Bytes_t,
    certificate: CommitCertificateProto_t,
    certificatePresent: bool,
    hex: Bytes_t,
  ): SyncedValueProto_t = {
    byteLen: byteLen,
    valueBytesLen: valueBytesLen,
    valueBytesHex: valueBytesHex,
    certificate: certificate,
    certificatePresent: certificatePresent,
    hex: hex,
  }

  def ValueResponseProto(
    byteLen: int,
    height: int,
    valuePresent: bool,
    value: SyncedValueProto_t,
    hex: Bytes_t,
  ): ValueResponseProto_t = {
    byteLen: byteLen,
    height: height,
    valuePresent: valuePresent,
    value: value,
    hex: hex,
  }

  def SyncResponseProto(
    byteLen: int,
    responseTag: int,
    valueResponse: ValueResponseProto_t,
    hex: Bytes_t,
  ): SyncResponseProto_t = {
    byteLen: byteLen,
    responseTag: responseTag,
    valueResponse: valueResponse,
    hex: hex,
  }

  pure val SampleSignature =
    SignatureProto(
      66,
      64,
      "0a40404142434445464748494a4b4c4d4e4f505152535455565758595a5b5c5d5e5f606162636465666768696a6b6c6d6e6f707172737475767778797a7b7c7d7e7f",
    )

  pure val SampleValueId =
    ValueIdProto(
      34,
      32,
      "0a20808182838485868788898a8b8c8d8e8f909192939495969798999a9b9c9d9e9f",
    )

  pure val MissingValueId =
    ValueIdProto(0, 0, "")

  pure val ValueRequest =
    ValueRequestProto(2, 1, "0801")

  pure val BadValueRequestHeight =
    ValueRequestProto(2, -1, "0801")

  pure val SyncRequest =
    SyncRequestProto(4, SyncRequestValueRequestTag, ValueRequest, "0a020801")

  pure val SyncRequestWrongTag =
    SyncRequestProto(4, 99, ValueRequest, "63020801")

  pure val CommitSignature =
    CommitSignatureProto(
      102,
      32,
      SampleSignature,
      "0a20000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f12420a40404142434445464748494a4b4c4d4e4f505152535455565758595a5b5c5d5e5f606162636465666768696a6b6c6d6e6f707172737475767778797a7b7c7d7e7f",
    )

  pure val ShortCommitSignature =
    CommitSignatureProto(
      101,
      31,
      SampleSignature,
      "0a1f000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e12420a40404142434445464748494a4b4c4d4e4f505152535455565758595a5b5c5d5e5f606162636465666768696a6b6c6d6e6f707172737475767778797a7b7c7d7e7f",
    )

  pure val CommitCertificate =
    CommitCertificateProto(
      144,
      1,
      2,
      SampleValueId,
      CommitSignature,
      1,
      "080110021a220a20808182838485868788898a8b8c8d8e8f909192939495969798999a9b9c9d9e9f22660a20000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f12420a40404142434445464748494a4b4c4d4e4f505152535455565758595a5b5c5d5e5f606162636465666768696a6b6c6d6e6f707172737475767778797a7b7c7d7e7f",
    )

  pure val CommitCertificateMissingValueId =
    CommitCertificateProto(
      108,
      1,
      2,
      MissingValueId,
      CommitSignature,
      1,
      "0801100222660a20000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f12420a40404142434445464748494a4b4c4d4e4f505152535455565758595a5b5c5d5e5f606162636465666768696a6b6c6d6e6f707172737475767778797a7b7c7d7e7f",
    )

  pure val CommitCertificateShortSigner =
    CommitCertificateProto(
      143,
      1,
      2,
      SampleValueId,
      ShortCommitSignature,
      1,
      "080110021a220a20808182838485868788898a8b8c8d8e8f909192939495969798999a9b9c9d9e9f22650a1f000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e12420a40404142434445464748494a4b4c4d4e4f505152535455565758595a5b5c5d5e5f606162636465666768696a6b6c6d6e6f707172737475767778797a7b7c7d7e7f",
    )

  pure val SyncedValue =
    SyncedValueProto(
      152,
      3,
      "aabbcc",
      CommitCertificate,
      true,
      "0a03aabbcc129001080110021a220a20808182838485868788898a8b8c8d8e8f909192939495969798999a9b9c9d9e9f22660a20000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f12420a40404142434445464748494a4b4c4d4e4f505152535455565758595a5b5c5d5e5f606162636465666768696a6b6c6d6e6f707172737475767778797a7b7c7d7e7f",
    )

  pure val SyncedValueMissingCertificate =
    SyncedValueProto(
      5,
      3,
      "aabbcc",
      CommitCertificate,
      false,
      "0a03aabbcc",
    )

  pure val ValueResponseWithValue =
    ValueResponseProto(
      157,
      1,
      true,
      SyncedValue,
      "08011298010a03aabbcc129001080110021a220a20808182838485868788898a8b8c8d8e8f909192939495969798999a9b9c9d9e9f22660a20000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f12420a40404142434445464748494a4b4c4d4e4f505152535455565758595a5b5c5d5e5f606162636465666768696a6b6c6d6e6f707172737475767778797a7b7c7d7e7f",
    )

  pure val ValueResponseNoValue =
    ValueResponseProto(2, 1, false, SyncedValueMissingCertificate, "0801")

  pure val ValueResponseMissingCertificate =
    ValueResponseProto(7, 1, true, SyncedValueMissingCertificate, "080112050a03aabbcc")

  pure val SyncResponseWithValue =
    SyncResponseProto(
      160,
      SyncResponseValueResponseTag,
      ValueResponseWithValue,
      "0a9d0108011298010a03aabbcc129001080110021a220a20808182838485868788898a8b8c8d8e8f909192939495969798999a9b9c9d9e9f22660a20000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f12420a40404142434445464748494a4b4c4d4e4f505152535455565758595a5b5c5d5e5f606162636465666768696a6b6c6d6e6f707172737475767778797a7b7c7d7e7f",
    )

  pure val SyncResponseNoValue =
    SyncResponseProto(4, SyncResponseValueResponseTag, ValueResponseNoValue, "0a020801")

  pure val SyncResponseWrongTag =
    SyncResponseProto(4, 99, ValueResponseNoValue, "63020801")

  pure val TestRequests = Set(SyncRequest, SyncRequestWrongTag)

  pure val TestResponses = Set(
    SyncResponseWithValue,
    SyncResponseNoValue,
    SyncResponseWrongTag,
  )

  action Next: bool =
    any {
      nondet request = oneOf(TestRequests)
      AcceptSyncRequest(request),
      nondet response = oneOf(TestResponses)
      AcceptSyncResponse(response),
      Stutter,
    }

  action unchangedAll = all {
    acceptedSyncRequests' = acceptedSyncRequests,
    acceptedSyncResponses' = acceptedSyncResponses,
    syncFiredAction' = syncFiredAction,
  }

  run syncProtoTagsAndLengthsPinnedTest = {
    Init.then(all {
      assert(SyncProtoTagsPinned),
      assert(SyncProtoLengthsPinned),
      unchangedAll,
    })
  }

  run syncRequestExactHexTest = {
    Init.then(all {
      assert(ValueRequestProtoCanonical(ValueRequest)),
      assert(SyncRequestProtoCanonical(SyncRequest)),
      unchangedAll,
    })
  }

  run commitCertificateExactHexTest = {
    Init.then(all {
      assert(CommitCertificateProtoCanonical(CommitCertificate)),
      assert(SyncedValueProtoCanonical(SyncedValue)),
      unchangedAll,
    })
  }

  run syncResponseExactHexTest = {
    Init.then(all {
      assert(ValueResponseProtoCanonical(ValueResponseWithValue)),
      assert(SyncResponseProtoCanonical(SyncResponseWithValue)),
      assert(ValueResponseProtoCanonical(ValueResponseNoValue)),
      assert(SyncResponseProtoCanonical(SyncResponseNoValue)),
      unchangedAll,
    })
  }

  run requestResponseContextDisambiguatesSameBytesTest = {
    Init.then(all {
      assert(SyncRequest.hex == SyncResponseNoValue.hex),
      assert(SyncRequestProtoCanonical(SyncRequest)),
      assert(SyncResponseProtoCanonical(SyncResponseNoValue)),
      unchangedAll,
    })
  }

  run acceptSyncMessagesTest = {
    Init
      .then(AcceptSyncRequest(SyncRequest))
      .then(AcceptSyncResponse(SyncResponseWithValue))
      .then(AcceptSyncResponse(SyncResponseNoValue))
      .then(all {
        assert(acceptedSyncRequests.contains(SyncRequest)),
        assert(acceptedSyncResponses.contains(SyncResponseWithValue)),
        assert(acceptedSyncResponses.contains(SyncResponseNoValue)),
        assert(Safety),
        unchangedAll,
      })
  }

  run badValueRequestHeightRejectedTest = {
    Init.then(all {
      assert(not(ValueRequestProtoCanonical(BadValueRequestHeight))),
      unchangedAll,
    })
  }

  run syncRequestWrongTagRejectedTest = {
    Init.then(AcceptSyncRequest(SyncRequestWrongTag)).fail()
  }

  run commitMissingValueIdRejectedTest = {
    Init.then(all {
      assert(not(CommitCertificateProtoCanonical(
        CommitCertificateMissingValueId,
      ))),
      unchangedAll,
    })
  }

  run commitShortSignerRejectedTest = {
    Init.then(all {
      assert(not(CommitCertificateProtoCanonical(CommitCertificateShortSigner))),
      unchangedAll,
    })
  }

  run responseMissingCertificateRejectedTest = {
    Init.then(all {
      assert(not(ValueResponseProtoCanonical(ValueResponseMissingCertificate))),
      unchangedAll,
    })
  }

  run syncResponseWrongTagRejectedTest = {
    Init.then(AcceptSyncResponse(SyncResponseWrongTag)).fail()
  }

  run malachiteSyncProtoSafetyTest = {
    Init.then(all {
      assert(Safety),
      unchangedAll,
    })
  }
}

module CrosslinkMalachiteSyncProtobufFormatModel {
  import CrosslinkMalachiteSyncProtobufFormatTest.* from "./CrosslinkMalachiteSyncProtobufFormat"
  export CrosslinkMalachiteSyncProtobufFormatTest.*
}
