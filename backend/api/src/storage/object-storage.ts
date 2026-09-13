export const OBJECT_STORAGE = Symbol('OBJECT_STORAGE');

export interface ObjectStorage {
  /** Uploads raw bytes under `key`. Never returns a public URL. */
  put(key: string, data: Buffer, contentType: string): Promise<void>;
  /** A time-limited URL for reading `key` — see backend/docs/security.md "Data protection". */
  getSignedReadUrl(key: string, expiresInSeconds: number): Promise<string>;
}
