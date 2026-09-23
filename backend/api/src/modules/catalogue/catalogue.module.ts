import { Module } from '@nestjs/common';
import { CatalogueService } from './catalogue.service';
import { CatalogueController } from './catalogue.controller';
import { CatalogueAdminController } from './catalogue-admin.controller';
import { ReviewVideoMediaService } from './review-video-media.service';

@Module({
  controllers: [CatalogueController, CatalogueAdminController],
  providers: [CatalogueService, ReviewVideoMediaService],
})
export class CatalogueModule {}
