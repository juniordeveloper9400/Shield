import { Controller, Get, Param, ParseIntPipe, Query } from '@nestjs/common';
import { CatalogueService } from './catalogue.service';
import { Public } from '../../common/decorators/public.decorator';
import { RequireMember } from '../../common/decorators/require-role.decorator';
import { ZodValidationPipe } from '../../common/pipes/zod-validation.pipe';
import { listProductsQuerySchema, type ListProductsQuery } from './dto';

// Deliberately no class-level @Public() (unlike this controller's own
// earlier shape): mixing one member-only route (storeBankDetails) in with
// the rest needs each public route marked individually, the same way
// member-auth.controller.ts does it — a class-level @Public() would win
// over a method's own @RequireMember() (AuthGuard's isPublic check reads
// the handler's metadata first, but only when the handler actually sets
// it; an unset handler falls through to the class's `true` regardless of
// @RequireMember(), which sets a different, RolesGuard-only key). Caught
// by catalogue.e2e-spec.ts, not by inspection.
@Controller('v1/public/catalogue')
export class CatalogueController {
  constructor(private readonly catalogue: CatalogueService) {}

  @Public()
  @Get('stores')
  stores() {
    return this.catalogue.listStores();
  }

  /**
   * Member-only, unlike every other route on this controller: `code` is
   * itself public (every branch's `code` is right there in `listStores`),
   * so leaving this one open too would just let a script loop it once per
   * known code and reconstruct the exact bulk bank-details dump
   * `listStores` was scoped down to stop leaking — see this endpoint's own
   * addition in `catalogue.service.ts`. Checkout already requires a signed-
   * in member before it is ever reached, so this costs the real caller
   * nothing.
   */
  @RequireMember()
  @Get('stores/:code/bank-details')
  storeBankDetails(@Param('code') code: string) {
    return this.catalogue.getStoreBankDetails(code);
  }

  @Public()
  @Get('categories')
  categories() {
    return this.catalogue.listCategories();
  }

  @Public()
  @Get('categories/:id/subcategories')
  subcategories(@Param('id', ParseIntPipe) id: number) {
    return this.catalogue.listSubcategories(id);
  }

  @Public()
  @Get('products')
  products(@Query(new ZodValidationPipe(listProductsQuerySchema)) query: ListProductsQuery) {
    return this.catalogue.listProducts(query);
  }

  @Public()
  @Get('products/:id')
  product(@Param('id', ParseIntPipe) id: number) {
    return this.catalogue.getProduct(id);
  }

  @Public()
  @Get('banners')
  banners() {
    return this.catalogue.listBanners();
  }

  @Public()
  @Get('promos')
  promos() {
    return this.catalogue.listPromos();
  }

  @Public()
  @Get('review-videos')
  reviewVideos() {
    return this.catalogue.listActiveReviewVideos();
  }

  @Public()
  @Get('membership-tiers')
  membershipTiers() {
    return this.catalogue.listMembershipTiers();
  }

  @Public()
  @Get('payment-methods')
  paymentMethods() {
    return this.catalogue.listPaymentMethods();
  }
}
