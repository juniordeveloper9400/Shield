import { BadRequestException, Body, Controller, Delete, Get, Param, ParseIntPipe, ParseUUIDPipe, Patch, Post, Put } from '@nestjs/common';
import { CatalogueService } from './catalogue.service';
import { ReviewVideoMediaService } from './review-video-media.service';
import { RequireRole, RequireStaff } from '../../common/decorators/require-role.decorator';
import { ZodValidationPipe } from '../../common/pipes/zod-validation.pipe';
import {
  createCategorySchema,
  createProductSchema,
  createReviewVideoSchema,
  createReviewVideoMediaSchema,
  createReviewVideoUploadSchema,
  createStoreSchema,
  deleteReviewVideoMediaSchema,
  reviewVideoChunkSchema,
  setStoreActiveSchema,
  setStoreOffersLabSchema,
  updateCategorySchema,
  updateProductSchema,
  updateReviewVideoSchema,
  updateStoreSchema,
  type CreateCategoryDto,
  type CreateProductDto,
  type CreateReviewVideoDto,
  type CreateReviewVideoMediaDto,
  type CreateReviewVideoUploadDto,
  type CreateStoreDto,
  type DeleteReviewVideoMediaDto,
  type ReviewVideoChunkDto,
  type SetStoreActiveDto,
  type SetStoreOffersLabDto,
  type UpdateCategoryDto,
  type UpdateProductDto,
  type UpdateReviewVideoDto,
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

  @RequireRole('SUPERADMIN', 'ADMIN', 'LAB')
  @Patch('stores/:id/offers-lab')
  setStoreOffersLab(
    @Param('id', ParseIntPipe) id: number,
    @Body(new ZodValidationPipe(setStoreOffersLabSchema)) dto: SetStoreOffersLabDto,
  ) {
    return this.catalogue.setStoreOffersLab(id, dto.offersLabCollection);
  }

  @Post('categories')
  createCategory(@Body(new ZodValidationPipe(createCategorySchema)) dto: CreateCategoryDto) {
    return this.catalogue.createCategory(dto);
  }

  @Patch('categories/:id')
  updateCategory(
    @Param('id', ParseIntPipe) id: number,
    @Body(new ZodValidationPipe(updateCategorySchema)) dto: UpdateCategoryDto,
  ) {
    return this.catalogue.updateCategory(id, dto);
  }

  @Post('products')
  createProduct(@Body(new ZodValidationPipe(createProductSchema)) dto: CreateProductDto) {
    return this.catalogue.createProduct(dto);
  }

  @Patch('products/:id')
  updateProduct(
    @Param('id', ParseIntPipe) id: number,
    @Body(new ZodValidationPipe(updateProductSchema)) dto: UpdateProductDto,
  ) {
    return this.catalogue.updateProduct(id, dto);
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

  /** Signed upload link for sending a clip straight to the public bucket — see CatalogueService.createReviewVideoUpload. */
  @RequireRole('SUPERADMIN', 'ADMIN')
  @Post('review-videos/upload-url')
  createReviewVideoUpload(
    @Body(new ZodValidationPipe(createReviewVideoUploadSchema)) dto: CreateReviewVideoUploadDto,
  ) {
    return this.catalogue.createReviewVideoUpload(dto);
  }

  /** Removes a stored clip that is no longer used (replaced, or an abandoned upload). */
  @RequireRole('SUPERADMIN', 'ADMIN')
  @Post('review-videos/media/delete')
  deleteReviewVideoMedia(
    @Body(new ZodValidationPipe(deleteReviewVideoMediaSchema)) dto: DeleteReviewVideoMediaDto,
  ) {
    return this.catalogue.deleteReviewVideoMedia(dto.url);
  }

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
