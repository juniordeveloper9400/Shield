import { Global, Module } from '@nestjs/common';
import { OBJECT_STORAGE } from './object-storage';
import { PUBLIC_MEDIA_STORAGE } from './public-media-storage';
import { S3ObjectStorage } from './s3-object-storage.service';
import { SupabasePublicMediaStorage } from './supabase-public-media-storage.service';

@Global()
@Module({
  providers: [
    { provide: OBJECT_STORAGE, useClass: S3ObjectStorage },
    { provide: PUBLIC_MEDIA_STORAGE, useClass: SupabasePublicMediaStorage },
  ],
  exports: [OBJECT_STORAGE, PUBLIC_MEDIA_STORAGE],
})
export class StorageModule {}
