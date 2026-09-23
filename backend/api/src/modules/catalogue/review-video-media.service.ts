import { createHash, randomUUID } from 'node:crypto';
import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { eq, sql } from 'drizzle-orm';
import { InjectDb, type Database } from '../../db/client';
import { customerReviewVideo, customerReviewVideoMedia } from '../../db/schema';
import type { Env } from '../../config/env';

export const REVIEW_VIDEO_CHUNK_BYTES = 768 * 1024;
const HASH_SLICE_BYTES = 2 * 1024 * 1024;
const MEDIA_PATH = '/v1/public/catalogue/review-video-media/';

export interface CreateReviewVideoMediaInput {
  contentType: 'video/mp4' | 'video/webm' | 'video/quicktime';
  byteLength: number;
  sha256: string;
}

@Injectable()
export class ReviewVideoMediaService {
  private readonly maxBytes: number;

  constructor(
    @InjectDb() private readonly db: Database,
    config: ConfigService<Env, true>,
  ) {
    this.maxBytes = Math.round((config.get('REVIEW_VIDEO_MAX_MB', { infer: true }) ?? 50) * 1024 * 1024);
  }

  async createUpload(input: CreateReviewVideoMediaInput) {
    if (input.byteLength > this.maxBytes) {
      throw new BadRequestException(`That video exceeds the ${this.formatMb(this.maxBytes)} upload limit.`);
    }
    const [created] = await this.db.insert(customerReviewVideoMedia).values({
      id: randomUUID(),
      contentType: input.contentType,
      byteLength: input.byteLength,
      sha256: input.sha256,
    }).returning({ id: customerReviewVideoMedia.id });
    return { id: created.id, nextChunk: 0, chunkSizeBytes: REVIEW_VIDEO_CHUNK_BYTES };
  }

  async status(id: string) {
    const [row] = await this.db.select({
      id: customerReviewVideoMedia.id,
      byteLength: customerReviewVideoMedia.byteLength,
      nextChunk: customerReviewVideoMedia.nextChunk,
      uploadComplete: customerReviewVideoMedia.uploadComplete,
      storedBytes: sql<number>`octet_length(${customerReviewVideoMedia.data})`,
    }).from(customerReviewVideoMedia).where(eq(customerReviewVideoMedia.id, id)).limit(1);
    if (!row) throw new NotFoundException('Video upload not found.');
    return { ...row, storedBytes: Number(row.storedBytes) };
  }

  async appendChunk(id: string, index: number, encoded: string) {
    const chunk = decodeBase64(encoded);
    if (chunk.length > REVIEW_VIDEO_CHUNK_BYTES) {
      throw new BadRequestException(`Each video chunk must be at most ${REVIEW_VIDEO_CHUNK_BYTES} bytes.`);
    }

    return this.db.transaction(async (tx) => {
      const locked = await tx.execute(sql`
        SELECT id, byte_length, next_chunk, upload_complete, octet_length(data) AS stored_bytes
          FROM app.customer_review_video_media
         WHERE id = ${id}::uuid
         FOR UPDATE
      `);
      const row = locked.rows[0] as Record<string, unknown> | undefined;
      if (!row) throw new NotFoundException('Video upload not found.');
      const nextChunk = Number(row.next_chunk);
      const storedBytes = Number(row.stored_bytes);
      if (row.upload_complete) throw new ConflictException('This video upload is already complete.');
      if (index < nextChunk) return { id, nextChunk, storedBytes };
      if (index > nextChunk) {
        throw new ConflictException({ message: 'Video chunks must be uploaded in order.', expectedIndex: nextChunk });
      }
      if (storedBytes + chunk.length > Number(row.byte_length)) {
        throw new BadRequestException('This chunk would exceed the declared video size.');
      }
      const updated = await tx.execute(sql`
        UPDATE app.customer_review_video_media
           SET data = data || ${chunk}, next_chunk = next_chunk + 1
         WHERE id = ${id}::uuid
         RETURNING next_chunk, octet_length(data) AS stored_bytes
      `);
      const result = updated.rows[0] as Record<string, unknown>;
      return { id, nextChunk: Number(result.next_chunk), storedBytes: Number(result.stored_bytes) };
    });
  }

  async completeUpload(id: string) {
    const metaResult = await this.db.execute(sql`
      SELECT id, byte_length, sha256, upload_complete, octet_length(data) AS stored_bytes
        FROM app.customer_review_video_media
       WHERE id = ${id}::uuid
    `);
    const meta = metaResult.rows[0] as Record<string, unknown> | undefined;
    if (!meta) throw new NotFoundException('Video upload not found.');
    if (meta.upload_complete) return { id, videoUrl: `${MEDIA_PATH}${id}` };
    if (Number(meta.stored_bytes) !== Number(meta.byte_length)) {
      throw new BadRequestException('The uploaded video is incomplete. Resume the remaining chunks.');
    }

    const hash = createHash('sha256');
    for (let offset = 0; offset < Number(meta.byte_length); offset += HASH_SLICE_BYTES) {
      const slice = await this.db.execute(sql`
        SELECT substring(data FROM ${offset + 1} FOR ${HASH_SLICE_BYTES}) AS bytes
          FROM app.customer_review_video_media WHERE id = ${id}::uuid
      `);
      hash.update((slice.rows[0] as { bytes: Buffer }).bytes);
    }
    if (hash.digest('hex') !== String(meta.sha256)) {
      throw new BadRequestException('The uploaded video checksum does not match. Upload it again.');
    }

    await this.db.update(customerReviewVideoMedia).set({
      uploadComplete: true,
      completedAt: new Date(),
    }).where(eq(customerReviewVideoMedia.id, id));
    return { id, videoUrl: `${MEDIA_PATH}${id}` };
  }

  async deleteUnreferenced(id: string): Promise<{ deleted: boolean }> {
    const url = `${MEDIA_PATH}${id}`;
    const [reference] = await this.db.select({ id: customerReviewVideo.id })
      .from(customerReviewVideo).where(eq(customerReviewVideo.videoUrl, url)).limit(1);
    if (reference) throw new ConflictException('This video is still used by a customer clip.');
    const deleted = await this.db.delete(customerReviewVideoMedia)
      .where(eq(customerReviewVideoMedia.id, id)).returning({ id: customerReviewVideoMedia.id });
    return { deleted: deleted.length > 0 };
  }

  async cleanupIncomplete(before = new Date(Date.now() - 24 * 60 * 60 * 1000)): Promise<number> {
    const result = await this.db.execute(sql`
      DELETE FROM app.customer_review_video_media
       WHERE upload_complete = false AND created_at < ${before}
       RETURNING id
    `);
    return result.rows.length;
  }

  private formatMb(bytes: number) {
    return `${Math.round(bytes / (1024 * 1024))} MB`;
  }
}

function decodeBase64(value: string): Buffer {
  const compact = value.trim();
  if (!compact || !/^[A-Za-z0-9+/]*={0,2}$/.test(compact) || compact.length % 4 === 1) {
    throw new BadRequestException('Video chunk is not valid base64.');
  }
  const decoded = Buffer.from(compact, 'base64');
  const normalized = (text: string) => text.replace(/=+$/, '');
  if (normalized(decoded.toString('base64')) !== normalized(compact)) {
    throw new BadRequestException('Video chunk is not valid base64.');
  }
  return decoded;
}
