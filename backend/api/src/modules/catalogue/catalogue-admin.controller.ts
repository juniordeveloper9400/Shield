import { BadRequestException, Body, Controller, Delete, Get, Param, ParseIntPipe, ParseUUIDPipe, Patch, Post, Put, Query } from '@nestjs/common';
import { CatalogueService } from './catalogue.service';
import { ReviewVideoMediaService } from './review-video-media.service';
import { RequireRole, RequireStaff } from '../../common/decorators/require-role.decorator';
import { ZodValidationPipe } from '../../common/pipes/zod-validation.pipe';
import {
  createBannerSchema,
  createBrandSchema,
  createCategorySchema,
  createProductSchema,
  createReviewVideoSchema,
  createReviewVideoMediaSchema,
  createStoreSchema,
  createSubcategorySchema,
  renameBrandSchema,
  reviewVideoChunkSchema,
  setAdminWhatsappSchema,
  setBannerActiveSchema,
  setBannerSortSchema,
  setCategoryActiveSchema,
  setCategorySortSchema,
  setProductStatusSchema,
  setStoreActiveSchema,
  setStoreOffersLabSchema,
  updateBannerSchema,
  updateCategorySchema,
  updateProductSchema,
  updateProductSectionsSchema,
  updateReviewVideoSchema,
  updateStoreSchema,
  updateSubcategorySchema,
  type CreateBannerDto,
  type CreateBrandDto,
  type CreateCategoryDto,
  type CreateProductDto,
  type CreateReviewVideoDto,
  type CreateReviewVideoMediaDto,
  type CreateStoreDto,
  type CreateSubcategoryDto,
  type RenameBrandDto,
  type ReviewVideoChunkDto,
  type SetAdminWhatsappDto,
  type SetBannerActiveDto,
  type SetBannerSortDto,
  type SetCategoryActiveDto,
  type SetCategorySortDto,
  type SetProductStatusDto,
  type SetStoreActiveDto,
  type SetStoreOffersLabDto,
  type UpdateBannerDto,
  type UpdateCategoryDto,
  type UpdateProductDto,
  type UpdateProductSectionsDto,
  type UpdateReviewVideoDto,
  type UpdateSubcategoryDto,
  type UpdateStoreDto,
} from './dto';

/**
 * Staff-only catalogue writes. Any authenticated staff role can manage the
 * catalogue for now — narrow with @RequireRole('SUPERADMIN') per-route if a
 * future requirement restricts this to a specific role.
 */
@Controller('v1/staff/catalogue')
@RequireStaff()
export class CatalogueAdminController {
  constructor(
    private readonly catalogue: CatalogueService,
    private readonly reviewVideoMedia: ReviewVideoMediaService,
  ) {}

  // ---- Stores -------------------------------------------------------------
  // Read is open to any staff role (branch pickers on Bills/Deliveries/order
  // and prescription review need it too); writes are narrowed to whoever
  // actually has the Stores module in shieldweb/src/config/permissions.ts
  // (superadmin/admin/lab) — the server enforcing the same boundary the UI
  // already implies, not just trusting the frontend route guard.

  @Get('stores')
  listStores() {
    return this.catalogue.listStoresForStaff();
  }

  @RequireRole('SUPERADMIN', 'ADMIN', 'LAB')
  @Post('stores')
  createStore(@Body(new ZodValidationPipe(createStoreSchema)) dto: CreateStoreDto) {
    return this.catalogue.createStore(dto);
  }

  @RequireRole('SUPERADMIN', 'ADMIN', 'LAB')
  @Patch('stores/:id')
  updateStore(
    @Param('id', ParseIntPipe) id: number,
    @Body(new ZodValidationPipe(updateStoreSchema)) dto: UpdateStoreDto,
  ) {
    return this.catalogue.updateStore(id, dto);
  }

  @RequireRole('SUPERADMIN', 'ADMIN', 'LAB')
  @Patch('stores/:id/active')
  setStoreActive(
    @Param('id', ParseIntPipe) id: number,
    @Body(new ZodValidationPipe(setStoreActiveSchema)) dto: SetStoreActiveDto,
  ) {
    return this.catalogue.setStoreActive(id, dto.isActive);
  }

  @RequireRole('SUPERADMIN', 'ADMIN')
  @Delete('stores/:id')
  deleteStore(@Param('id', ParseIntPipe) id: number) {
    return this.catalogue.deleteStore(id);
  }

  @RequireRole('SUPERADMIN', 'ADMIN', 'LAB')
  @Patch('stores/:id/offers-lab')
  setStoreOffersLab(
    @Param('id', ParseIntPipe) id: number,
    @Body(new ZodValidationPipe(setStoreOffersLabSchema)) dto: SetStoreOffersLabDto,
  ) {
    return this.catalogue.setStoreOffersLab(id, dto.offersLabCollection);
  }

  /** The Stores page's own "Admin WhatsApp number" card — the write side of
   *  the public GET /v1/public/catalogue/contact. Same role gate as the
   *  store writes just above; it lives on the same page. */
  @RequireRole('SUPERADMIN', 'ADMIN', 'LAB')
  @Patch('contact/admin-whatsapp')
  setAdminWhatsapp(@Body(new ZodValidationPipe(setAdminWhatsappSchema)) dto: SetAdminWhatsappDto) {
    return this.catalogue.setAdminWhatsapp(dto.value);
  }

  // ---- Categories & subcategories --------------------------------------
  // 'banners' is the permission module key that gates this whole page in
  // shieldweb (Categories & banners share one screen) — only SUPERADMIN/
  // ADMIN have it, same restriction as the home/lab banner routes above.

  @RequireRole('SUPERADMIN', 'ADMIN')
  @Get('categories')
  listCategoryGroupsForStaff() {
    return this.catalogue.listCategoryGroupsForStaff();
  }

  @RequireRole('SUPERADMIN', 'ADMIN')
  @Post('categories')
  createCategory(@Body(new ZodValidationPipe(createCategorySchema)) dto: CreateCategoryDto) {
    return this.catalogue.createCategory(dto);
  }

  @RequireRole('SUPERADMIN', 'ADMIN')
  @Patch('categories/:id')
  updateCategory(
    @Param('id', ParseIntPipe) id: number,
    @Body(new ZodValidationPipe(updateCategorySchema)) dto: UpdateCategoryDto,
  ) {
    return this.catalogue.updateCategory(id, dto);
  }

  @RequireRole('SUPERADMIN', 'ADMIN')
  @Patch('categories/:id/active')
  setCategoryActive(
    @Param('id', ParseIntPipe) id: number,
    @Body(new ZodValidationPipe(setCategoryActiveSchema)) dto: SetCategoryActiveDto,
  ) {
    return this.catalogue.setCategoryActive(id, dto.isActive);
  }

  @RequireRole('SUPERADMIN', 'ADMIN')
  @Patch('categories/:id/sort')
  setCategorySort(
    @Param('id', ParseIntPipe) id: number,
    @Body(new ZodValidationPipe(setCategorySortSchema)) dto: SetCategorySortDto,
  ) {
    return this.catalogue.setCategorySort(id, dto.sort);
  }

  @RequireRole('SUPERADMIN', 'ADMIN')
  @Post('categories/:id/subcategories')
  createSubcategory(
    @Param('id', ParseIntPipe) categoryId: number,
    @Body(new ZodValidationPipe(createSubcategorySchema)) dto: CreateSubcategoryDto,
  ) {
    return this.catalogue.createSubcategory(categoryId, dto);
  }

  @RequireRole('SUPERADMIN', 'ADMIN')
  @Patch('subcategories/:id')
  updateSubcategory(
    @Param('id', ParseIntPipe) id: number,
    @Body(new ZodValidationPipe(updateSubcategorySchema)) dto: UpdateSubcategoryDto,
  ) {
    return this.catalogue.updateSubcategory(id, dto);
  }

  @RequireRole('SUPERADMIN', 'ADMIN')
  @Delete('subcategories/:id')
  deleteSubcategory(@Param('id', ParseIntPipe) id: number) {
    return this.catalogue.deleteSubcategory(id);
  }

  // ---- Products ---------------------------------------------------------
  // 'products' in shieldweb/src/config/permissions.ts is superadmin/admin/
  // pharmacy only — restricted here too, overriding the controller's
  // class-wide @RequireStaff().

  @RequireRole('SUPERADMIN', 'ADMIN', 'PHARMACY')
  @Get('products')
  listProductsForStaff() {
    return this.catalogue.listProductsForStaff();
  }

  @RequireRole('SUPERADMIN', 'ADMIN', 'PHARMACY')
  @Get('products/:id/detail')
  getProductDetailForStaff(@Param('id', ParseIntPipe) id: number) {
    return this.catalogue.getProductDetailForStaff(id);
  }

  @RequireRole('SUPERADMIN', 'ADMIN', 'PHARMACY')
  @Post('products')
  createProduct(@Body(new ZodValidationPipe(createProductSchema)) dto: CreateProductDto) {
    return this.catalogue.createProduct(dto);
  }

  @RequireRole('SUPERADMIN', 'ADMIN', 'PHARMACY')
  @Patch('products/:id')
  updateProduct(
    @Param('id', ParseIntPipe) id: number,
    @Body(new ZodValidationPipe(updateProductSchema)) dto: UpdateProductDto,
  ) {
    return this.catalogue.updateProduct(id, dto);
  }

  /** The console's own "Edit" page — core fields plus detail/FAQs/gallery,
   *  always together, unlike the plain partial PATCH above. */
  @RequireRole('SUPERADMIN', 'ADMIN', 'PHARMACY')
  @Put('products/:id')
  updateProductFull(
    @Param('id', ParseIntPipe) id: number,
    @Body(new ZodValidationPipe(createProductSchema)) dto: CreateProductDto,
  ) {
    return this.catalogue.updateProductFull(id, dto);
  }

  @RequireRole('SUPERADMIN', 'ADMIN', 'PHARMACY')
  @Delete('products/:id')
  deleteProduct(@Param('id', ParseIntPipe) id: number) {
    return this.catalogue.deleteProductForStaff(id);
  }

  @RequireRole('SUPERADMIN', 'ADMIN', 'PHARMACY')
  @Patch('products/:id/status')
  setProductStatus(
    @Param('id', ParseIntPipe) id: number,
    @Body(new ZodValidationPipe(setProductStatusSchema)) dto: SetProductStatusDto,
  ) {
    return this.catalogue.setProductStatus(id, dto);
  }

  @RequireRole('SUPERADMIN', 'ADMIN', 'PHARMACY')
  @Patch('products/:id/sections')
  updateProductSections(
    @Param('id', ParseIntPipe) id: number,
    @Body(new ZodValidationPipe(updateProductSectionsSchema)) dto: UpdateProductSectionsDto,
  ) {
    return this.catalogue.updateProductSections(id, dto);
  }

  // ---- Brands -------------------------------------------------------------

  @RequireRole('SUPERADMIN', 'ADMIN', 'PHARMACY')
  @Get('brands')
  listBrands() {
    return this.catalogue.listBrands();
  }

  @RequireRole('SUPERADMIN', 'ADMIN', 'PHARMACY')
  @Post('brands')
  createBrand(@Body(new ZodValidationPipe(createBrandSchema)) dto: CreateBrandDto) {
    return this.catalogue.createBrand(dto);
  }

  @RequireRole('SUPERADMIN', 'ADMIN', 'PHARMACY')
  @Patch('brands/:id')
  renameBrand(
    @Param('id', ParseIntPipe) id: number,
    @Body(new ZodValidationPipe(renameBrandSchema)) dto: RenameBrandDto,
  ) {
    return this.catalogue.renameBrand(id, dto);
  }

  @RequireRole('SUPERADMIN', 'ADMIN', 'PHARMACY')
  @Delete('brands/:id')
  deleteBrand(@Param('id', ParseIntPipe) id: number) {
    return this.catalogue.deleteBrand(id);
  }

  // ---- Banners --------------------------------------------------------
  // 'banners' isn't in the pharmacy/lab/appointments module lists in
  // shieldweb/src/config/permissions.ts either — only SUPERADMIN/ADMIN
  // manage the home/lab hero strips, so restricted here too, overriding
  // the controller's class-wide @RequireStaff() the same way review-videos
  // does below.

  @RequireRole('SUPERADMIN', 'ADMIN')
  @Get('banners')
  listBannersForStaff(@Query('placement') placement?: string) {
    return this.catalogue.listBannersForStaff(placement);
  }

  @RequireRole('SUPERADMIN', 'ADMIN')
  @Post('banners')
  createBanner(@Body(new ZodValidationPipe(createBannerSchema)) dto: CreateBannerDto) {
    return this.catalogue.createBanner(dto);
  }

  @RequireRole('SUPERADMIN', 'ADMIN')
  @Patch('banners/:id')
  updateBanner(@Param('id', ParseIntPipe) id: number, @Body(new ZodValidationPipe(updateBannerSchema)) dto: UpdateBannerDto) {
    return this.catalogue.updateBanner(id, dto);
  }

  @RequireRole('SUPERADMIN', 'ADMIN')
  @Patch('banners/:id/sort')
  setBannerSort(@Param('id', ParseIntPipe) id: number, @Body(new ZodValidationPipe(setBannerSortSchema)) dto: SetBannerSortDto) {
    return this.catalogue.setBannerSort(id, dto.sort);
  }

  @RequireRole('SUPERADMIN', 'ADMIN')
  @Patch('banners/:id/active')
  setBannerActive(@Param('id', ParseIntPipe) id: number, @Body(new ZodValidationPipe(setBannerActiveSchema)) dto: SetBannerActiveDto) {
    return this.catalogue.setBannerActive(id, dto.isActive);
  }

  @RequireRole('SUPERADMIN', 'ADMIN')
  @Delete('banners/:id')
  deleteBanner(@Param('id', ParseIntPipe) id: number) {
    return this.catalogue.deleteBanner(id);
  }

  // 'customer_videos' isn't in the pharmacy/lab/appointments module lists
  // in shieldweb/src/config/permissions.ts at all — only SUPERADMIN/ADMIN
  // ever see this screen, so it's restricted here too, overriding the
  // controller's class-wide @RequireStaff().
  @RequireRole('SUPERADMIN', 'ADMIN')
  @Get('review-videos')
  listReviewVideos() {
    return this.catalogue.listAllReviewVideosForStaff();
  }

  @RequireRole('SUPERADMIN', 'ADMIN')
  @Post('review-videos')
  createReviewVideo(@Body(new ZodValidationPipe(createReviewVideoSchema)) dto: CreateReviewVideoDto) {
    return this.catalogue.createReviewVideo(dto);
  }

  /** Starts a chunked upload for a customer-review clip's video bytes,
   *  stored in Neon rather than external object storage — see
   *  ReviewVideoMediaService.createUpload. */
  @RequireRole('SUPERADMIN', 'ADMIN')
  @Post('review-video-media')
  createReviewVideoMedia(
    @Body(new ZodValidationPipe(createReviewVideoMediaSchema)) dto: CreateReviewVideoMediaDto,
  ) {
    return this.reviewVideoMedia.createUpload(dto);
  }

  @RequireRole('SUPERADMIN', 'ADMIN')
  @Post('review-video-media/cleanup')
  cleanupReviewVideoMedia() {
    return this.reviewVideoMedia.cleanupIncomplete().then((removed) => ({ removed }));
  }

  @RequireRole('SUPERADMIN', 'ADMIN')
  @Get('review-video-media/:id')
  reviewVideoMediaStatus(@Param('id', ParseUUIDPipe) id: string) {
    return this.reviewVideoMedia.status(id);
  }

  @RequireRole('SUPERADMIN', 'ADMIN')
  @Put('review-video-media/:id/chunks/:index')
  appendReviewVideoChunk(
    @Param('id', ParseUUIDPipe) id: string,
    @Param('index', ParseIntPipe) index: number,
    @Body(new ZodValidationPipe(reviewVideoChunkSchema)) dto: ReviewVideoChunkDto,
  ) {
    if (index < 0) throw new BadRequestException('Chunk index must be zero or greater.');
    return this.reviewVideoMedia.appendChunk(id, index, dto.data);
  }

  @RequireRole('SUPERADMIN', 'ADMIN')
  @Post('review-video-media/:id/complete')
  completeReviewVideoMedia(@Param('id', ParseUUIDPipe) id: string) {
    return this.reviewVideoMedia.completeUpload(id);
  }

  @RequireRole('SUPERADMIN', 'ADMIN')
  @Delete('review-video-media/:id')
  deleteNeonReviewVideoMedia(@Param('id', ParseUUIDPipe) id: string) {
    return this.reviewVideoMedia.deleteUnreferenced(id);
  }

  @RequireRole('SUPERADMIN', 'ADMIN')
  @Patch('review-videos/:id')
  updateReviewVideo(
    @Param('id', ParseIntPipe) id: number,
    @Body(new ZodValidationPipe(updateReviewVideoSchema)) dto: UpdateReviewVideoDto,
  ) {
    return this.catalogue.updateReviewVideo(id, dto);
  }

  @RequireRole('SUPERADMIN', 'ADMIN')
  @Delete('review-videos/:id')
  deleteReviewVideo(@Param('id', ParseIntPipe) id: number) {
    return this.catalogue.deleteReviewVideo(id);
  }
}
