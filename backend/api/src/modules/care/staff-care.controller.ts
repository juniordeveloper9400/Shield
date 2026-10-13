import { Body, Controller, Delete, Get, Param, ParseIntPipe, Patch, Post } from '@nestjs/common';
import { CareService } from './care.service';
import { RequireRole } from '../../common/decorators/require-role.decorator';
import { ZodValidationPipe } from '../../common/pipes/zod-validation.pipe';
import {
  createLabCategorySchema,
  setLabCategoryActiveSchema,
  setLabCategorySortSchema,
  updateLabCategorySchema,
  type CreateLabCategoryDto,
  type SetLabCategoryActiveDto,
  type SetLabCategorySortDto,
  type UpdateLabCategoryDto,
} from './dto';

/**
 * Lab Tests catalogue management — `lab_tests` is the permission module
 * key that gates this in shieldweb (`src/config/permissions.ts`):
 * SUPERADMIN, ADMIN and LAB, never LAB_TECHNICIAN (a technician works
 * their one already-assigned branch's bookings, not the test/category
 * catalogue — see that role's own comment there).
 */
@Controller('v1/staff/lab-categories')
@RequireRole('SUPERADMIN', 'ADMIN', 'LAB')
export class StaffCareController {
  constructor(private readonly care: CareService) {}

  @Get()
  listForStaff() {
    return this.care.listLabCategoriesForStaff();
  }

  @Post()
  create(@Body(new ZodValidationPipe(createLabCategorySchema)) dto: CreateLabCategoryDto) {
    return this.care.createLabCategory(dto);
  }

  @Patch(':id')
  update(@Param('id', ParseIntPipe) id: number, @Body(new ZodValidationPipe(updateLabCategorySchema)) dto: UpdateLabCategoryDto) {
    return this.care.updateLabCategory(id, dto);
  }

  @Patch(':id/active')
  setActive(@Param('id', ParseIntPipe) id: number, @Body(new ZodValidationPipe(setLabCategoryActiveSchema)) dto: SetLabCategoryActiveDto) {
    return this.care.setLabCategoryActive(id, dto.isActive);
  }

  @Patch(':id/sort')
  setSort(@Param('id', ParseIntPipe) id: number, @Body(new ZodValidationPipe(setLabCategorySortSchema)) dto: SetLabCategorySortDto) {
    return this.care.setLabCategorySort(id, dto.sort);
  }

  @Delete(':id')
  remove(@Param('id', ParseIntPipe) id: number) {
    return this.care.deleteLabCategory(id);
  }
}
