import { Body, Controller, Delete, Get, Param, ParseIntPipe, Patch, Post } from '@nestjs/common';
import { LabTestService } from './lab-test.service';
import { RequireRole } from '../../common/decorators/require-role.decorator';
import { ZodValidationPipe } from '../../common/pipes/zod-validation.pipe';
import {
  createLabPackageSchema,
  setLabPackageActiveSchema,
  updateLabPackageBuildSchema,
  updateLabPackagePriceSchema,
  type CreateLabPackageDto,
  type SetLabPackageActiveDto,
  type UpdateLabPackageBuildDto,
  type UpdateLabPackagePriceDto,
} from './dto';

/** The package builder — same `lab_tests` permission module/role gate as
 *  the Test Master; it's the other tab on the same console page. */
@Controller('v1/staff/lab-packages')
@RequireRole('SUPERADMIN', 'ADMIN', 'LAB')
export class StaffLabPackageController {
  constructor(private readonly labTests: LabTestService) {}

  @Get()
  list() {
    return this.labTests.listLabPackagesForStaff();
  }

  @Get('test-picker')
  listTestsForPicker() {
    return this.labTests.listLabTestsForPicker();
  }

  @Get(':id/test-ids')
  getTestIds(@Param('id', ParseIntPipe) id: number) {
    return this.labTests.getLabPackageTestIds(id);
  }

  @Post()
  create(@Body(new ZodValidationPipe(createLabPackageSchema)) dto: CreateLabPackageDto) {
    return this.labTests.createLabPackage(dto);
  }

  @Patch(':id')
  update(@Param('id', ParseIntPipe) id: number, @Body(new ZodValidationPipe(updateLabPackageBuildSchema)) dto: UpdateLabPackageBuildDto) {
    return this.labTests.updateLabPackageBuild(id, dto);
  }

  @Delete(':id')
  remove(@Param('id', ParseIntPipe) id: number) {
    return this.labTests.deleteLabPackage(id);
  }

  @Patch(':id/active')
  setActive(@Param('id', ParseIntPipe) id: number, @Body(new ZodValidationPipe(setLabPackageActiveSchema)) dto: SetLabPackageActiveDto) {
    return this.labTests.setLabPackageActive(id, dto.isActive);
  }

  @Patch(':id/price')
  updatePrice(@Param('id', ParseIntPipe) id: number, @Body(new ZodValidationPipe(updateLabPackagePriceSchema)) dto: UpdateLabPackagePriceDto) {
    return this.labTests.updateLabPackagePrice(id, dto);
  }
}
