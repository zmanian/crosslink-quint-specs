#!/usr/bin/env node

import { execFileSync } from 'node:child_process'
import crypto from 'node:crypto'
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')
const manifestPath = path.join(repoRoot, 'fixtures', 'production-bft-block-vectors.json')
const quintModulePath = path.join(repoRoot, 'spec', 'CrosslinkProductionFixtureVectorsGenerated.qnt')

const layout = {
  u32Bytes: 4,
  fatPointerVotePayloadBytes: 44,
  fatPointerCountBytes: 2,
  fatPointerSignatureEntryBytes: 96,
  preCrosslinkHeaderBytes: 1487,
}

const ed25519SpkiPrefix = Buffer.from('302a300506032b6570032100', 'hex')

function usage() {
  console.error(`Usage:
  node scripts/extract-bft-block-vectors.mjs --validate
  node scripts/extract-bft-block-vectors.mjs --write [--source=/path/to/zebra-crosslink]
  node scripts/extract-bft-block-vectors.mjs --write-quint
  node scripts/extract-bft-block-vectors.mjs --print [--source=/path/to/zebra-crosslink]
  node scripts/extract-bft-block-vectors.mjs --check-source [--source=/path/to/zebra-crosslink]
  node scripts/extract-bft-block-vectors.mjs --check-quint

Default source path: ../zebra-crosslink, or $ZEBRA_CROSSLINK_REPO`)
}

function parseArgs(argv) {
  const opts = {
    mode: 'validate',
    source: process.env.ZEBRA_CROSSLINK_REPO || path.join(repoRoot, '..', 'zebra-crosslink'),
  }

  for (const arg of argv) {
    if (arg === '--validate') {
      opts.mode = 'validate'
    } else if (arg === '--write') {
      opts.mode = 'write'
    } else if (arg === '--write-quint') {
      opts.mode = 'write-quint'
    } else if (arg === '--print') {
      opts.mode = 'print'
    } else if (arg === '--check-source') {
      opts.mode = 'check-source'
    } else if (arg === '--check-quint') {
      opts.mode = 'check-quint'
    } else if (arg.startsWith('--source=')) {
      opts.source = arg.slice('--source='.length)
    } else if (arg === '--help' || arg === '-h') {
      usage()
      process.exit(0)
    } else {
      throw new Error(`unknown argument: ${arg}`)
    }
  }

  opts.source = path.resolve(opts.source)
  return opts
}

function fatPointerByteLen(signatureCount) {
  return layout.fatPointerVotePayloadBytes +
    layout.fatPointerCountBytes +
    signatureCount * layout.fatPointerSignatureEntryBytes
}

function u16LeBytes(value) {
  return [value & 0xff, (value >> 8) & 0xff]
}

function rawEd25519PublicKey(pubKeyHex) {
  return crypto.createPublicKey({
    key: Buffer.concat([ed25519SpkiPrefix, Buffer.from(pubKeyHex, 'hex')]),
    format: 'der',
    type: 'spki',
  })
}

function verifyEd25519Signature(pubKeyHex, signDataHex, signatureHex) {
  return crypto.verify(
    null,
    Buffer.from(signDataHex, 'hex'),
    rawEd25519PublicKey(pubKeyHex),
    Buffer.from(signatureHex, 'hex'),
  )
}

function parseFatPointer(buffer, offset) {
  if (offset + layout.fatPointerVotePayloadBytes + layout.fatPointerCountBytes > buffer.length) {
    throw new Error(`fat pointer at ${offset} runs past end of buffer`)
  }

  const payload = buffer.subarray(offset, offset + layout.fatPointerVotePayloadBytes)
  const signatureCountOffset = offset + layout.fatPointerVotePayloadBytes
  const signatureCount = buffer.readUInt16LE(offset + layout.fatPointerVotePayloadBytes)
  const byteLen = fatPointerByteLen(signatureCount)
  if (offset + byteLen > buffer.length) {
    throw new Error(`fat pointer at ${offset} declares ${signatureCount} signatures past end`)
  }

  const entriesOffset = signatureCountOffset + layout.fatPointerCountBytes
  const firstSignatureEntry = signatureCount === 0 ? null : (() => {
    const pubKey = buffer.subarray(entriesOffset, entriesOffset + 32)
    const voteSignature = buffer.subarray(entriesOffset + 32, entriesOffset + 32 + 64)

    return {
      pubKeyOffset: entriesOffset,
      pubKeyFirstByte: buffer.readUInt8(entriesOffset),
      pubKeyHex: pubKey.toString('hex'),
      voteSignatureOffset: entriesOffset + 32,
      voteSignatureFirstByte: buffer.readUInt8(entriesOffset + 32),
      voteSignatureLastByte: buffer.readUInt8(entriesOffset + 32 + 63),
      voteSignatureHex: voteSignature.toString('hex'),
      voteSignDataHex: Buffer.concat([pubKey, payload]).toString('hex'),
      endOffset: entriesOffset + layout.fatPointerSignatureEntryBytes,
    }
  })()

  return {
    signatureCount,
    byteLen,
    probe: {
      offset,
      payloadFirstByte: buffer.readUInt8(offset),
      payloadLastByte: buffer.readUInt8(offset + layout.fatPointerVotePayloadBytes - 1),
      payloadHex: payload.toString('hex'),
      blockHashHex: payload.subarray(0, 32).toString('hex'),
      signatureCountOffset,
      signatureCountBytes: [
        buffer.readUInt8(signatureCountOffset),
        buffer.readUInt8(signatureCountOffset + 1),
      ],
      entriesOffset,
      firstSignatureEntry,
    },
  }
}

function headerByteLen(version) {
  if (version >= 5) {
    throw new Error(
      `header version ${version} includes the Crosslink header fat-pointer field; ` +
        'teach this extractor where that field is serialized before regenerating fixtures',
    )
  }

  return layout.preCrosslinkHeaderBytes
}

function headerByteLenForFixture(file, version) {
  try {
    return headerByteLen(version)
  } catch (error) {
    throw new Error(`${file}: ${error.message}`)
  }
}

function parseFixture(filePath) {
  const buffer = fs.readFileSync(filePath)
  const file = path.basename(filePath)

  const bftBlockVersion = buffer.readUInt32LE(0)
  const bftHeight = buffer.readUInt32LE(4)
  const previousFatPointer = parseFatPointer(buffer, 8)
  const finalizationCandidateHeightOffset = 8 + previousFatPointer.byteLen
  const finalizationCandidateHeight = buffer.readUInt32LE(finalizationCandidateHeightOffset)
  const headerCountOffset = finalizationCandidateHeightOffset + layout.u32Bytes
  const headerCount = buffer.readUInt32LE(headerCountOffset)
  const headersStartOffset = headerCountOffset + layout.u32Bytes

  let offset = headersStartOffset
  const headers = []
  for (let index = 0; index < headerCount; index += 1) {
    const startOffset = offset
    const logicalVersion = buffer.readUInt32LE(startOffset)
    const byteLen = headerByteLen(logicalVersion)
    const endOffset = startOffset + byteLen
    if (endOffset > buffer.length) {
      throw new Error(`${file}: header ${index} runs past end of buffer`)
    }

    headers.push({ index, logicalVersion, startOffset, endOffset, byteLen })
    offset = endOffset
  }

  const trailingFatPointerOffset = offset
  const trailingFatPointer = parseFatPointer(buffer, trailingFatPointerOffset)
  const bftBlockByteLen = trailingFatPointerOffset
  const totalByteLen = bftBlockByteLen + trailingFatPointer.byteLen
  if (totalByteLen !== buffer.length) {
    throw new Error(`${file}: parsed ${totalByteLen} bytes but file has ${buffer.length}`)
  }

  return {
    file,
    totalByteLen,
    bftBlockVersion,
    bftHeight,
    previousFatPointerSignatureCount: previousFatPointer.signatureCount,
    previousFatPointerByteLen: previousFatPointer.byteLen,
    previousFatPointerProbe: previousFatPointer.probe,
    finalizationCandidateHeightOffset,
    finalizationCandidateHeight,
    headerCountOffset,
    headerCount,
    headersStartOffset,
    headers,
    bftBlockByteLen,
    trailingFatPointerOffset,
    trailingFatPointerSignatureCount: trailingFatPointer.signatureCount,
    trailingFatPointerByteLen: trailingFatPointer.byteLen,
    trailingFatPointerProbe: trailingFatPointer.probe,
  }
}

function parsePowBlockFixture(filePath) {
  const buffer = fs.readFileSync(filePath)
  const file = path.basename(filePath)
  const height = Number(file.match(/test_pow_block_(\d+)\.bin$/)?.[1])
  if (!Number.isFinite(height)) {
    throw new Error(`${file}: cannot parse PoW height`)
  }
  if (buffer.length < layout.u32Bytes) {
    throw new Error(`${file}: too short to contain a block version`)
  }

  const logicalVersion = buffer.readUInt32LE(0)
  const headerByteLen = headerByteLenForFixture(file, logicalVersion)
  if (headerByteLen > buffer.length) {
    throw new Error(`${file}: header runs past end of block fixture`)
  }

  return {
    file,
    height,
    totalByteLen: buffer.length,
    logicalVersion,
    headerByteLen,
    bodyByteLen: buffer.length - headerByteLen,
    probe: {
      headerFirstByte: buffer.readUInt8(0),
      headerLastByte: buffer.readUInt8(headerByteLen - 1),
      bodyFirstByte: buffer.length > headerByteLen ? buffer.readUInt8(headerByteLen) : null,
      bodyLastByte: buffer.length > headerByteLen ? buffer.readUInt8(buffer.length - 1) : null,
    },
  }
}

function numericFixtureSort(a, b) {
  const ai = Number(a.match(/test_(?:pos|pow)_block_(\d+)\.bin$/)?.[1] ?? 0)
  const bi = Number(b.match(/test_(?:pos|pow)_block_(\d+)\.bin$/)?.[1] ?? 0)
  return ai - bi
}

function gitHead(source) {
  try {
    return execFileSync('git', ['-C', source, 'rev-parse', 'HEAD'], {
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'ignore'],
    }).trim()
  } catch {
    return null
  }
}

function buildManifest(source) {
  const fixtureDir = path.join(source, 'crosslink-test-data')
  const files = fs.readdirSync(fixtureDir)
    .filter(file => /^test_pos_block_\d+\.bin$/.test(file))
    .sort(numericFixtureSort)
  const powFiles = fs.readdirSync(fixtureDir)
    .filter(file => /^test_pow_block_\d+\.bin$/.test(file))
    .sort(numericFixtureSort)

  if (files.length === 0) {
    throw new Error(`no test_pos_block_*.bin files found in ${fixtureDir}`)
  }
  if (powFiles.length === 0) {
    throw new Error(`no test_pow_block_*.bin files found in ${fixtureDir}`)
  }

  return {
    schema: 1,
    source: {
      repo: 'zebra-crosslink',
      commit: gitHead(source),
      fixtureGlob: 'crosslink-test-data/test_pos_block_*.bin',
      powFixtureGlob: 'crosslink-test-data/test_pow_block_*.bin',
    },
    layout,
    fixtures: files.map(file => parseFixture(path.join(fixtureDir, file))),
    powBlockFixtures: powFiles.map(file => parsePowBlockFixture(path.join(fixtureDir, file))),
  }
}

function assert(condition, message) {
  if (!condition) {
    throw new Error(message)
  }
}

function validateFatPointerProbe(prefix, probe, offset, signatureCount, byteLen) {
  assert(probe && typeof probe === 'object', `${prefix}fat-pointer probe missing`)
  assert(probe.offset === offset, `${prefix}fat-pointer probe offset mismatch`)
  assert(typeof probe.payloadHex === 'string', `${prefix}payload hex missing`)
  assert(
    probe.payloadHex.length === layout.fatPointerVotePayloadBytes * 2,
    `${prefix}payload hex length mismatch`,
  )
  assert(typeof probe.blockHashHex === 'string', `${prefix}block hash hex missing`)
  assert(probe.blockHashHex.length === 64, `${prefix}block hash hex length mismatch`)
  assert(
    probe.signatureCountOffset === offset + layout.fatPointerVotePayloadBytes,
    `${prefix}count offset mismatch`,
  )
  assert(
    probe.entriesOffset === probe.signatureCountOffset + layout.fatPointerCountBytes,
    `${prefix}entries offset mismatch`,
  )
  assert(
    probe.payloadLastByte !== undefined && probe.payloadFirstByte !== undefined,
    `${prefix}payload byte probes missing`,
  )
  const expectedCountBytes = u16LeBytes(signatureCount)
  assert(
    Array.isArray(probe.signatureCountBytes) &&
      probe.signatureCountBytes.length === 2 &&
      probe.signatureCountBytes[0] === expectedCountBytes[0] &&
      probe.signatureCountBytes[1] === expectedCountBytes[1],
    `${prefix}signature count bytes mismatch`,
  )

  if (signatureCount === 0) {
    assert(probe.firstSignatureEntry === null, `${prefix}unexpected first signature entry`)
  } else {
    assert(probe.firstSignatureEntry !== null, `${prefix}first signature entry missing`)
    assert(probe.firstSignatureEntry.pubKeyOffset === probe.entriesOffset, `${prefix}pubkey offset mismatch`)
    assert(
      typeof probe.firstSignatureEntry.pubKeyHex === 'string' &&
        probe.firstSignatureEntry.pubKeyHex.length === 64,
      `${prefix}pubkey hex mismatch`,
    )
    assert(
      probe.firstSignatureEntry.voteSignatureOffset === probe.entriesOffset + 32,
      `${prefix}vote signature offset mismatch`,
    )
    assert(
      typeof probe.firstSignatureEntry.voteSignatureHex === 'string' &&
        probe.firstSignatureEntry.voteSignatureHex.length === 128,
      `${prefix}vote signature hex mismatch`,
    )
    assert(
      typeof probe.firstSignatureEntry.voteSignDataHex === 'string' &&
        probe.firstSignatureEntry.voteSignDataHex.length === 152,
      `${prefix}vote sign-data hex mismatch`,
    )
    assert(
      verifyEd25519Signature(
        probe.firstSignatureEntry.pubKeyHex,
        probe.firstSignatureEntry.voteSignDataHex,
        probe.firstSignatureEntry.voteSignatureHex,
      ),
      `${prefix}Ed25519 signature verification failed`,
    )
    assert(
      probe.firstSignatureEntry.endOffset === probe.entriesOffset + layout.fatPointerSignatureEntryBytes,
      `${prefix}signature entry end offset mismatch`,
    )
    assert(probe.firstSignatureEntry.endOffset <= offset + byteLen, `${prefix}signature entry runs past fat pointer`)
  }
}

function validateManifest(manifest) {
  assert(manifest.schema === 1, 'schema must be 1')
  assert(manifest.source?.repo === 'zebra-crosslink', 'unexpected source repo')
  assert(
    manifest.source?.fixtureGlob === 'crosslink-test-data/test_pos_block_*.bin',
    'unexpected fixture glob',
  )
  assert(
    manifest.source?.powFixtureGlob === 'crosslink-test-data/test_pow_block_*.bin',
    'unexpected PoW fixture glob',
  )
  assert(
    typeof manifest.source?.commit === 'string' || manifest.source?.commit === null,
    'unexpected source commit',
  )
  assert(manifest.layout.u32Bytes === layout.u32Bytes, 'unexpected u32 byte length')
  assert(
    manifest.layout.fatPointerVotePayloadBytes === layout.fatPointerVotePayloadBytes,
    'unexpected fat-pointer payload length',
  )
  assert(
    manifest.layout.fatPointerCountBytes === layout.fatPointerCountBytes,
    'unexpected fat-pointer count length',
  )
  assert(
    manifest.layout.fatPointerSignatureEntryBytes === layout.fatPointerSignatureEntryBytes,
    'unexpected fat-pointer signature-entry length',
  )
  assert(
    manifest.layout.preCrosslinkHeaderBytes === layout.preCrosslinkHeaderBytes,
    'unexpected pre-Crosslink header length',
  )
  assert(Array.isArray(manifest.fixtures) && manifest.fixtures.length > 0, 'fixtures missing')
  assert(
    Array.isArray(manifest.powBlockFixtures) && manifest.powBlockFixtures.length > 0,
    'PoW block fixtures missing',
  )

  let hasZeroPreviousSignatureFixture = false
  let hasOnePreviousSignatureFixture = false

  for (const fixture of manifest.fixtures) {
    const prefix = `${fixture.file}: `
    const previousFatPointerByteLen = fatPointerByteLen(fixture.previousFatPointerSignatureCount)
    assert(
      fixture.previousFatPointerByteLen === previousFatPointerByteLen,
      `${prefix}previous fat-pointer byte length mismatch`,
    )
    validateFatPointerProbe(
      `${prefix}previous `,
      fixture.previousFatPointerProbe,
      8,
      fixture.previousFatPointerSignatureCount,
      fixture.previousFatPointerByteLen,
    )

    const finalizationCandidateHeightOffset = 8 + previousFatPointerByteLen
    const headerCountOffset = finalizationCandidateHeightOffset + layout.u32Bytes
    const headersStartOffset = headerCountOffset + layout.u32Bytes
    assert(
      fixture.finalizationCandidateHeightOffset === finalizationCandidateHeightOffset,
      `${prefix}finalization candidate offset mismatch`,
    )
    assert(fixture.headerCountOffset === headerCountOffset, `${prefix}header-count offset mismatch`)
    assert(fixture.headersStartOffset === headersStartOffset, `${prefix}headers-start offset mismatch`)
    assert(fixture.headerCount === fixture.headers.length, `${prefix}header count mismatch`)

    let offset = fixture.headersStartOffset
    for (const header of fixture.headers) {
      const byteLen = headerByteLen(header.logicalVersion)
      assert(header.startOffset === offset, `${prefix}header ${header.index} start mismatch`)
      assert(header.byteLen === byteLen, `${prefix}header ${header.index} length mismatch`)
      assert(header.endOffset === header.startOffset + byteLen, `${prefix}header ${header.index} end mismatch`)
      offset = header.endOffset
    }

    const trailingFatPointerByteLen = fatPointerByteLen(fixture.trailingFatPointerSignatureCount)
    assert(fixture.bftBlockByteLen === offset, `${prefix}BFT block length mismatch`)
    assert(fixture.trailingFatPointerOffset === offset, `${prefix}trailing fat-pointer offset mismatch`)
    assert(
      fixture.trailingFatPointerByteLen === trailingFatPointerByteLen,
      `${prefix}trailing fat-pointer length mismatch`,
    )
    validateFatPointerProbe(
      `${prefix}trailing `,
      fixture.trailingFatPointerProbe,
      fixture.trailingFatPointerOffset,
      fixture.trailingFatPointerSignatureCount,
      fixture.trailingFatPointerByteLen,
    )
    assert(
      fixture.totalByteLen === fixture.bftBlockByteLen + trailingFatPointerByteLen,
      `${prefix}total length mismatch`,
    )

    hasZeroPreviousSignatureFixture ||= fixture.previousFatPointerSignatureCount === 0
    hasOnePreviousSignatureFixture ||= fixture.previousFatPointerSignatureCount === 1
  }

  assert(hasZeroPreviousSignatureFixture, 'missing first-height fixture with zero previous signatures')
  assert(hasOnePreviousSignatureFixture, 'missing later fixture with one previous signature')

  for (const fixture of manifest.powBlockFixtures) {
    const prefix = `${fixture.file}: `
    assert(Number.isInteger(fixture.height), `${prefix}height missing`)
    assert(fixture.totalByteLen >= layout.preCrosslinkHeaderBytes, `${prefix}total length too short`)
    assert(
      Number.isInteger(fixture.logicalVersion) && fixture.logicalVersion >= 0,
      `${prefix}logical version missing`,
    )
    assert(
      fixture.headerByteLen === headerByteLen(fixture.logicalVersion),
      `${prefix}header length mismatch`,
    )
    assert(
      fixture.bodyByteLen === fixture.totalByteLen - fixture.headerByteLen,
      `${prefix}body length mismatch`,
    )
    assert(
      fixture.probe?.headerFirstByte === (fixture.logicalVersion & 0xff),
      `${prefix}header first byte should expose little-endian version low byte`,
    )
    assert(typeof fixture.probe?.headerLastByte === 'number', `${prefix}header byte probe missing`)
    assert(
      fixture.bodyByteLen === 0 || typeof fixture.probe?.bodyFirstByte === 'number',
      `${prefix}body first byte probe missing`,
    )
    assert(
      fixture.bodyByteLen === 0 || typeof fixture.probe?.bodyLastByte === 'number',
      `${prefix}body last byte probe missing`,
    )
  }
}

function readManifest() {
  return JSON.parse(fs.readFileSync(manifestPath, 'utf8'))
}

function stableJson(value) {
  return `${JSON.stringify(value, null, 2)}\n`
}

function quintValue(value) {
  return typeof value === 'string' ? JSON.stringify(value) : value
}

function renderGeneratedQuintModule(manifest) {
  validateManifest(manifest)

  const first = manifest.fixtures[0]
  const later = manifest.fixtures.find(fixture => fixture.previousFatPointerSignatureCount === 1)
  const firstPow = manifest.powBlockFixtures[0]
  const laterPow =
    manifest.powBlockFixtures.find(fixture => fixture.totalByteLen !== firstPow.totalByteLen) ??
    manifest.powBlockFixtures[manifest.powBlockFixtures.length - 1]
  const lastPow = manifest.powBlockFixtures[manifest.powBlockFixtures.length - 1]
  assert(later !== undefined, 'missing one-signature fixture for generated Quint constants')
  assert(firstPow !== undefined, 'missing first PoW block fixture for generated Quint constants')
  assert(laterPow !== undefined, 'missing later PoW block fixture for generated Quint constants')
  assert(lastPow !== undefined, 'missing last PoW block fixture for generated Quint constants')

  const constants = [
    ['GeneratedFixtureCount', manifest.fixtures.length],
    ['GeneratedPowBlockFixtureCount', manifest.powBlockFixtures.length],
    ['FixtureHeaderLogicalVersion', later.headers[0].logicalVersion],
    ['FixtureHeaderCount', later.headerCount],
    ['FixtureFirstPowBlockHeight', firstPow.height],
    ['FixtureLastPowBlockHeight', lastPow.height],
    ['FixtureFirstPowBlockLogicalVersion', firstPow.logicalVersion],
    ['FixtureLaterPowBlockLogicalVersion', laterPow.logicalVersion],
    ['FixtureFirstPowBlockByteLen', firstPow.totalByteLen],
    ['FixtureLaterPowBlockByteLen', laterPow.totalByteLen],
    ['FixtureFirstPowBlockHeaderByteLen', firstPow.headerByteLen],
    ['FixtureLaterPowBlockHeaderByteLen', laterPow.headerByteLen],
    ['FixtureFirstPowBlockBodyByteLen', firstPow.bodyByteLen],
    ['FixtureLaterPowBlockBodyByteLen', laterPow.bodyByteLen],
    ['FixtureFirstPowBlockHeaderFirstByte', firstPow.probe.headerFirstByte],
    ['FixtureFirstPowBlockHeaderLastByte', firstPow.probe.headerLastByte],
    ['FixtureFirstPowBlockBodyFirstByte', firstPow.probe.bodyFirstByte],
    ['FixtureFirstPowBlockBodyLastByte', firstPow.probe.bodyLastByte],
    ['FixtureLaterPowBlockHeaderFirstByte', laterPow.probe.headerFirstByte],
    ['FixtureLaterPowBlockHeaderLastByte', laterPow.probe.headerLastByte],
    ['FixtureLaterPowBlockBodyFirstByte', laterPow.probe.bodyFirstByte],
    ['FixtureLaterPowBlockBodyLastByte', laterPow.probe.bodyLastByte],
    ['FixtureFirstPreviousFatPointerSignatureCount', first.previousFatPointerSignatureCount],
    ['FixtureLaterPreviousFatPointerSignatureCount', later.previousFatPointerSignatureCount],
    ['FixtureTrailingFatPointerSignatureCount', later.trailingFatPointerSignatureCount],
    ['FixtureFirstBftBlockByteLen', first.bftBlockByteLen],
    ['FixtureFirstBftBlockAndFatPointerByteLen', first.totalByteLen],
    ['FixtureLaterBftBlockByteLen', later.bftBlockByteLen],
    ['FixtureLaterBftBlockAndFatPointerByteLen', later.totalByteLen],
    ['FixtureFirstHeader0StartOffset', first.headers[0].startOffset],
    ['FixtureFirstHeader1StartOffset', first.headers[1].startOffset],
    ['FixtureFirstHeader2StartOffset', first.headers[2].startOffset],
    ['FixtureFirstHeader2EndOffset', first.headers[2].endOffset],
    ['FixtureLaterHeader0StartOffset', later.headers[0].startOffset],
    ['FixtureLaterHeader1StartOffset', later.headers[1].startOffset],
    ['FixtureLaterHeader2StartOffset', later.headers[2].startOffset],
    ['FixtureLaterHeader2EndOffset', later.headers[2].endOffset],
    ['CheckedInFixturePreviousFatPointerOffset', later.previousFatPointerProbe.offset],
    ['CheckedInFixtureTrailingFatPointerOffset', later.trailingFatPointerProbe.offset],
    ['CheckedInFixtureSignatureCount', later.previousFatPointerSignatureCount],
    ['CheckedInFixturePreviousSignatureCountByte0', later.previousFatPointerProbe.signatureCountBytes[0]],
    ['CheckedInFixturePreviousSignatureCountByte1', later.previousFatPointerProbe.signatureCountBytes[1]],
    ['CheckedInFixtureTrailingSignatureCountByte0', later.trailingFatPointerProbe.signatureCountBytes[0]],
    ['CheckedInFixtureTrailingSignatureCountByte1', later.trailingFatPointerProbe.signatureCountBytes[1]],
    ['CheckedInFixturePreviousPayloadFirstByte', later.previousFatPointerProbe.payloadFirstByte],
    ['CheckedInFixturePreviousPayloadLastByte', later.previousFatPointerProbe.payloadLastByte],
    ['CheckedInFixtureTrailingPayloadFirstByte', later.trailingFatPointerProbe.payloadFirstByte],
    ['CheckedInFixtureTrailingPayloadLastByte', later.trailingFatPointerProbe.payloadLastByte],
    ['CheckedInFixtureSignerPubKeyFirstByte', later.previousFatPointerProbe.firstSignatureEntry.pubKeyFirstByte],
    ['CheckedInFixturePreviousSignatureFirstByte', later.previousFatPointerProbe.firstSignatureEntry.voteSignatureFirstByte],
    ['CheckedInFixturePreviousSignatureLastByte', later.previousFatPointerProbe.firstSignatureEntry.voteSignatureLastByte],
    ['CheckedInFixtureTrailingSignatureFirstByte', later.trailingFatPointerProbe.firstSignatureEntry.voteSignatureFirstByte],
    ['CheckedInFixtureTrailingSignatureLastByte', later.trailingFatPointerProbe.firstSignatureEntry.voteSignatureLastByte],
    ['CheckedInFixturePreviousPayloadHex', later.previousFatPointerProbe.payloadHex],
    ['CheckedInFixturePreviousBlockHashHex', later.previousFatPointerProbe.blockHashHex],
    ['CheckedInFixturePreviousPubKeyHex', later.previousFatPointerProbe.firstSignatureEntry.pubKeyHex],
    ['CheckedInFixturePreviousVoteSignatureHex', later.previousFatPointerProbe.firstSignatureEntry.voteSignatureHex],
    ['CheckedInFixturePreviousVoteSignDataHex', later.previousFatPointerProbe.firstSignatureEntry.voteSignDataHex],
    ['CheckedInFixtureTrailingPayloadHex', later.trailingFatPointerProbe.payloadHex],
    ['CheckedInFixtureTrailingBlockHashHex', later.trailingFatPointerProbe.blockHashHex],
    ['CheckedInFixtureTrailingPubKeyHex', later.trailingFatPointerProbe.firstSignatureEntry.pubKeyHex],
    ['CheckedInFixtureTrailingVoteSignatureHex', later.trailingFatPointerProbe.firstSignatureEntry.voteSignatureHex],
    ['CheckedInFixtureTrailingVoteSignDataHex', later.trailingFatPointerProbe.firstSignatureEntry.voteSignDataHex],
  ]

  const lines = [
    'module CrosslinkProductionFixtureVectorsGenerated {',
    '  /*',
    '   Generated by scripts/extract-bft-block-vectors.mjs --write-quint.',
    `   Source: ${manifest.source.repo}@${manifest.source.commit}`,
    `   Fixtures: ${manifest.source.fixtureGlob}; ${manifest.source.powFixtureGlob}`,
    '   */',
    '',
    ...constants.map(([name, value]) => `  pure val ${name} = ${quintValue(value)}`),
    '}',
    '',
  ]

  return lines.join('\n')
}

function main() {
  const opts = parseArgs(process.argv.slice(2))

  if (opts.mode === 'validate') {
    validateManifest(readManifest())
    console.log('production-bft-block-vectors manifest ok')
    return
  }

  if (opts.mode === 'write-quint') {
    fs.writeFileSync(quintModulePath, renderGeneratedQuintModule(readManifest()))
    console.log(`wrote ${path.relative(repoRoot, quintModulePath)}`)
    return
  }

  if (opts.mode === 'check-quint') {
    const existing = fs.readFileSync(quintModulePath, 'utf8')
    const generated = renderGeneratedQuintModule(readManifest())
    assert(existing === generated, 'generated Quint fixture module differs; run with --write-quint')
    console.log('generated Quint fixture module matches manifest')
    return
  }

  const generated = buildManifest(opts.source)
  validateManifest(generated)

  if (opts.mode === 'print') {
    process.stdout.write(stableJson(generated))
  } else if (opts.mode === 'write') {
    fs.mkdirSync(path.dirname(manifestPath), { recursive: true })
    fs.writeFileSync(manifestPath, stableJson(generated))
    console.log(`wrote ${path.relative(repoRoot, manifestPath)}`)
  } else if (opts.mode === 'check-source') {
    const existing = readManifest()
    const existingJson = stableJson(existing)
    const generatedJson = stableJson(generated)
    assert(existingJson === generatedJson, 'manifest differs from source fixtures; run with --write')
    console.log('production-bft-block-vectors manifest matches source fixtures')
  } else {
    usage()
    process.exit(1)
  }
}

main()
