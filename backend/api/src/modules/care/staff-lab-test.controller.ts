import { Body, Controller, Delete, Get, Param, ParseIntPipe, Patch, Post } from '@nestjs/common';
import { LabTestService } from './lab-test.service';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { RequireRole } from '../../common/decorators/require-role.decorator';
import { ZodValidationPipe } from '../../common/pipes/zod-validation.pipe';
import {
  createLabTestFieldOptionSchema,
  saveLabTestSchema,
  updateLabTestFieldOptionSchema,
  type CreateLabTestFieldOptionDto,
  type SaveLabTestDto,
  type UpdateLabTestFieldOptionDto,
} from './dto';
import type { RequestSubject } from '../auth/session.types';

/**
 * The Test Master — `lab_tests` is the permission module key that gates
 * this in shieldweb: SUPERADMIN, ADMIN and LAB, never LAB_TECHNICIAN (see
 * StaffCareController's own doc for why).
 */
@Controller('v1/staff/lab-tests')
@RequireRole('SUPERADMIN', 'ADMIN', 'LAB')
export class StaffLabTestController {
  constructor(private readonly labTests: LabTestService) {}

  @Get()
  list() {
    return this.labTests.listLabTests();
  }

  // ---- Field options: the pick lists Department/Method/Sample/… offer -----
  //
  // Declared before the generic :id routes below — Nest matches routes in
  // declaration order, and 'field-options' is a valid (if nonsensical)
  // :id/:fieldKey match otherwise, so it has to win first or ParseIntPipe
  // rejects it before these handlers are ever reached.

  @Get('field-options')
  listFieldOptions() {
    return this.labTests.listLabTestFieldOptions();
  }

  @Post('field-options')
  createFieldOption(@Body(new ZodValidationPipe(createLabTestFieldOptionSchema)) dto: CreateLabTestFieldOptionDto) {
    return this.labTests.createLabTestFieldOption(dto.fieldKey, dto.value);
  }

  @Patch('field-options/:id')
  updateFieldOption(
    @Param('id', ParseIntPipe) id: number,
    @Body(new ZodValidationPipe(updateLabTestFieldOptionSchema)) dto: UpdateLabTestFieldOptionDto,
  ) {
    return this.labTests.updateLabTestFieldOption(id, dto.value);
  }

  @Delete('field-options/:id')
  removeFieldOption(@Param('id', ParseIntPipe) id: number) {
    return this.labTests.deleteLabTestFieldOption(id);
  }

  @Get(':id')
  get(@Param('id', ParseIntPipe) id: number) {
    return this.labTests.getLabTest(id);
  }

  @Post()
  create(@Body(new ZodValidationPipe(saveLabTestSchema)) dto: SaveLabTestDto, @CurrentUser() user: RequestSubject) {
    return this.labTests.saveLabTest(null, dto, Number(user.subjectId));
  }

  // POST, not PATCH/PUT — saveLabTest always rewrites the test's own
  // input fields plus its full set of group members/special rates
  // together, the same "every save is a full save" shape the console's
  // own form posts (and matching the create route's own verb, since both
  // ultimately call the one saveLabTest).
  @Post(':id')
  update(
    @Param('id', ParseIntPipe) id: number,
    @Body(new ZodValidationPipe(saveLabTestSchema)) dto: SaveLabTestDto,
    @CurrentUser() user: RequestSubject,
  ) {
    return this.labTests.saveLabTest(id, dto, Number(user.subjectId));
  }

  @Delete(':id')
  remove(@Param('id', ParseIntPipe) id: number) {
    return this.labTests.deleteLabTest(id);
  }
}
