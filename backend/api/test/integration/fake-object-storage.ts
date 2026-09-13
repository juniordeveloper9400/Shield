import type { ObjectStorage } from '../../src/storage/object-storage';

/** In-memory object storage for tests — proves the signed-URL contract without real S3/R2 credentials. */
export class FakeObjectStorage implements ObjectStorage {
  private readonly store = new Map<string, { data: Buffer; contentType: string }>();

  async put(key: string, data: Buffer, contentType: string): Promise<void> {
    this.store.set(key, { data, contentType });
  }

  async getSignedReadUrl(key: string, expiresInSeconds: number): Promise<string> {
    if (!this.store.has(key)) throw new Error(`FakeObjectStorage: no object stored at "${key}"`);
    return `https://fake-object-storage.test/${encodeURIComponent(key)}?expires=${expiresInSeconds}`;
  }

  has(key: string): boolean {
    return this.store.has(key);
  }

  keys(): string[] {
    return Array.from(this.store.keys());
  }
}
