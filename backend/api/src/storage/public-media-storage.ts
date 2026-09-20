export const PUBLIC_MEDIA_STORAGE = Symbol('PUBLIC_MEDIA_STORAGE');

/** Everything the browser needs to send one file to the bucket. */
export interface PublicMediaUpload {
  /** Where to send the file — a single-use link that already carries its own authorization. */
  uploadUrl: string;
  /** The permanent public URL the object is readable at once uploaded. */
  publicUrl: string;
  method: 'PUT';
  /** Request headers the upload must send. */
  headers: Record<string, string>;
  /** Form fields to send in the multipart body alongside the file. */
  fields: Record<string, string>;
  /** How long `uploadUrl` stays valid. */
  expiresInSeconds: number;
}

/**
 * Publicly-readable media (customer review videos) in Supabase Storage.
 * Deliberately separate from `ObjectStorage`: that one is for private files
 * (never a public URL, signed reads only); this one is a bucket whose objects
 * anyone can read by URL, so nothing private may ever be written through it.
 *
 * Uploads never pass through this API: the console gets a single-use signed
 * upload link and sends the file straight to the bucket (a video is far bigger
 * than a serverless request body can carry), and the service-role key that
 * mints those links never leaves the server.
 */
export interface PublicMediaStorage {
  /** False until the Supabase project URL, service key and bucket are all configured. */
  isConfigured(): boolean;
  /**
   * A signed upload link for `key`, plus the permanent public URL the object
   * will be readable at. Throws if the storage service refuses or can't be
   * reached, with a message an admin can act on.
   */
  createUpload(input: { key: string }): Promise<PublicMediaUpload>;
  /** The object key behind one of this bucket's public URLs, or null for any other URL. */
  keyFromPublicUrl(url: string): string | null;
  delete(key: string): Promise<void>;
}
