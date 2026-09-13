import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { GetObjectCommand, PutObjectCommand, S3Client } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import type { Env } from '../config/env';
import type { ObjectStorage } from './object-storage';

/**
 * S3-compatible (Cloudflare R2, AWS S3, etc.) — see
 * backend/docs/tech-stack.md "File storage". This is the fix for
 * prescription images living as base64 data: URIs in Postgres
 * (backend/docs/security.md), applied for the first time in M4.
 */
@Injectable()
export class S3ObjectStorage implements ObjectStorage {
  private readonly client: S3Client;
  private readonly bucket: string;

  constructor(config: ConfigService<Env, true>) {
    this.bucket = config.get('OBJECT_STORAGE_BUCKET', { infer: true }) ?? '';
    this.client = new S3Client({
      region: config.get('OBJECT_STORAGE_REGION', { infer: true }),
      endpoint: config.get('OBJECT_STORAGE_ENDPOINT', { infer: true }),
      credentials: {
        accessKeyId: config.get('OBJECT_STORAGE_ACCESS_KEY', { infer: true }) ?? '',
        secretAccessKey: config.get('OBJECT_STORAGE_SECRET_KEY', { infer: true }) ?? '',
      },
    });
  }

  async put(key: string, data: Buffer, contentType: string): Promise<void> {
    await this.client.send(
      new PutObjectCommand({ Bucket: this.bucket, Key: key, Body: data, ContentType: contentType }),
    );
  }

  async getSignedReadUrl(key: string, expiresInSeconds: number): Promise<string> {
    return getSignedUrl(this.client, new GetObjectCommand({ Bucket: this.bucket, Key: key }), {
      expiresIn: expiresInSeconds,
    });
  }
}
