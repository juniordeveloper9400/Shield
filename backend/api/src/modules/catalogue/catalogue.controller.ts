import { Controller, Get, Param, ParseIntPipe, Query } from '@nestjs/common';
import { CatalogueService } from './catalogue.service';
import { Public } from '../../common/decorators/public.decorator';
import { ZodValidationPipe } from '../../common/pipes/zod-validation.pipe';
import { listProductsQuerySchema, type ListProductsQuery } from './dto';

@Controller('v1/public/catalogue')
@Public()
export class CatalogueController {
  constructor(private readonly catalogue: CatalogueService) {}

  @Get('stores')
  stores() {
    return this.catalogue.listStores();
  }

  @Get('categories')
  categories() {
    return this.catalogue.listCategories();
  }

  @Get('categories/:id/subcategories')
  subcategories(@Param('id', ParseIntPipe) id: number) {
    return this.catalogue.listSubcategories(id);
  }

  @Get('products')
  products(@Query(new ZodValidationPipe(listProductsQuerySchema)) query: ListProductsQuery) {
    return this.catalogue.listProducts(query);
  }

  @Get('products/:id')
  product(@Param('id', ParseIntPipe) id: number) {
    return this.catalogue.getProduct(id);
  }

  @Get('banners')
  banners() {
    return this.catalogue.listBanners();
  }

  @Get('promos')
  promos() {
    return this.catalogue.listPromos();
  }

  @Get('review-videos')
  reviewVideos() {
    return this.catalogue.listActiveReviewVideos();
  }

  @Get('membership-tiers')
  membershipTiers() {
    return this.catalogue.listMembershipTiers();
  }
}
