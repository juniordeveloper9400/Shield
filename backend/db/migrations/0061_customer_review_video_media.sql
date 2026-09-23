-- Customer-review video bytes stored in Neon Postgres. Uploads are appended
-- in ordered chunks by backend/api and remain invisible until verified.
CREATE TABLE IF NOT EXISTS app.customer_review_video_media (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  content_type text NOT NULL,
  byte_length bigint NOT NULL,
  sha256 text NOT NULL,
  data bytea NOT NULL DEFAULT ''::bytea,
  next_chunk integer NOT NULL DEFAULT 0,
  upload_complete boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  completed_at timestamptz,
  CONSTRAINT customer_review_video_media_content_type_check
    CHECK (content_type IN ('video/mp4', 'video/webm', 'video/quicktime')),
  CONSTRAINT customer_review_video_media_byte_length_check CHECK (byte_length > 0),
  CONSTRAINT customer_review_video_media_next_chunk_check CHECK (next_chunk >= 0)
);

CREATE INDEX IF NOT EXISTS customer_review_video_media_incomplete_idx
  ON app.customer_review_video_media(created_at)
  WHERE upload_complete = false;
