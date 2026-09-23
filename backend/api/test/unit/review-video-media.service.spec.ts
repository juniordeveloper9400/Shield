import { createHash } from 'node:crypto';
import { ConfigService } from '@nestjs/config';
import { BadRequestException, ConflictException } from '@nestjs/common';
import { createTestDb } from '../integration/create-test-db';
import { ReviewVideoMediaService } from '../../src/modules/catalogue/review-video-media.service';

const digest = (bytes: Buffer) => createHash('sha256').update(bytes).digest('hex');

function setup(maxMb = 50) {
  const db = createTestDb();
  const config = { get: (key: string) => key === 'REVIEW_VIDEO_MAX_MB' ? maxMb : undefined };
  const service = new ReviewVideoMediaService(
    db as never,
    config as unknown as ConfigService<never, true>,
  );
  return { db, service };
}

describe('ReviewVideoMediaService', () => {
  it('appends an ordered chunk once and treats an earlier index as a retry', async () => {
    const { service } = setup();
    const bytes = Buffer.from('abcdef');
    const upload = await service.createUpload({
      contentType: 'video/mp4', byteLength: bytes.length, sha256: digest(bytes),
    });

    await service.appendChunk(upload.id, 0, bytes.subarray(0, 3).toString('base64'));
    await service.appendChunk(upload.id, 0, bytes.subarray(0, 3).toString('base64'));

    expect(await service.status(upload.id)).toMatchObject({ storedBytes: 3, nextChunk: 1 });
  });

  it('rejects skipped, malformed, oversized and over-declared chunks without changing bytes', async () => {
    const { service } = setup();
    const upload = await service.createUpload({
      contentType: 'video/mp4', byteLength: 3, sha256: digest(Buffer.from('abc')),
    });

    await expect(service.appendChunk(upload.id, 1, Buffer.from('a').toString('base64')))
      .rejects.toBeInstanceOf(ConflictException);
    await expect(service.appendChunk(upload.id, 0, '%%%')).rejects.toBeInstanceOf(BadRequestException);
    await expect(service.appendChunk(upload.id, 0, Buffer.alloc(786433).toString('base64')))
      .rejects.toBeInstanceOf(BadRequestException);
    await expect(service.appendChunk(upload.id, 0, Buffer.from('abcd').toString('base64')))
      .rejects.toBeInstanceOf(BadRequestException);
    expect(await service.status(upload.id)).toMatchObject({ storedBytes: 0, nextChunk: 0 });
  });

  it('checks final length and checksum before completion and blocks later appends', async () => {
    const { service } = setup();
    const bytes = Buffer.from('complete video');
    const short = await service.createUpload({
      contentType: 'video/mp4', byteLength: bytes.length, sha256: digest(bytes),
    });
    await service.appendChunk(short.id, 0, bytes.subarray(0, 4).toString('base64'));
    await expect(service.completeUpload(short.id)).rejects.toBeInstanceOf(BadRequestException);

    const corrupt = await service.createUpload({
      contentType: 'video/mp4', byteLength: bytes.length, sha256: '0'.repeat(64),
    });
    await service.appendChunk(corrupt.id, 0, bytes.toString('base64'));
    await expect(service.completeUpload(corrupt.id)).rejects.toBeInstanceOf(BadRequestException);

    const valid = await service.createUpload({
      contentType: 'video/mp4', byteLength: bytes.length, sha256: digest(bytes),
    });
    await service.appendChunk(valid.id, 0, bytes.toString('base64'));
    expect(await service.completeUpload(valid.id)).toEqual({
      id: valid.id,
      videoUrl: `/v1/public/catalogue/review-video-media/${valid.id}`,
    });
    await expect(service.appendChunk(valid.id, 1, Buffer.from('x').toString('base64')))
      .rejects.toBeInstanceOf(ConflictException);
  });

  it('refuses configured oversize uploads and removes stale incomplete rows', async () => {
    const { service } = setup(1);
    await expect(service.createUpload({
      contentType: 'video/mp4', byteLength: 1024 * 1024 + 1, sha256: '0'.repeat(64),
    })).rejects.toBeInstanceOf(BadRequestException);

    const pending = await service.createUpload({
      contentType: 'video/webm', byteLength: 3, sha256: digest(Buffer.from('abc')),
    });
    expect(await service.cleanupIncomplete(new Date(Date.now() + 25 * 60 * 60 * 1000))).toBe(1);
    await expect(service.status(pending.id)).rejects.toThrow(/not found/i);
  });
});
