import { Module } from '@nestjs/common';
import { CatalogueService } from './catalogue.service';
import { CatalogueController } from './catalogue.controller';
import { CatalogueAdminController } from './catalogue-admin.controller';

@Module({
  controllers: [CatalogueController, CatalogueAdminController],
  providers: [CatalogueService],
})
export class CatalogueModule {}
