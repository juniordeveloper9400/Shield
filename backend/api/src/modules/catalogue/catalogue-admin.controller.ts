import { Body, Controller, Delete, Get, Param, ParseIntPipe, Patch, Post } from '@nestjs/common';
import { CatalogueService } from './catalogue.service';
import { RequireRole, RequireStaff } from '../../common/decorators/require-role.decorator';
import { ZodValidationPipe } from '../../common/pipes/zod-validation.pipe';
import {
  createCategorySchema,
  createProductSchema,
  createReviewVideoSchema,
  updateCategorySchema,
  updateProductSchema,
  updateReviewVideoSchema,
  type CreateCategoryDto,
  type CreateProductDto,
  type CreateReviewVideoDto,
  type UpdateCategoryDto,
  type UpdateProductDto,
  type UpdateReviewVideoDto,
} from './dto';

/**
 * Staff-only catalogue writes. Any authenticated staff role can manage the
 * catalogue for now — narrow with @RequireRole('SUPERADMIN') per-route if a
 * future requirement restricts this to a specific role.
 */
@Controller('v1/staff/catalogue')
@RequireStaff()
export class CatalogueAdminController {
  constructor(private readonly catalogue: CatalogueService) {}

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
