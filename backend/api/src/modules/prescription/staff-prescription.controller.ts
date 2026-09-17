import { Body, Controller, Get, Param, ParseIntPipe, Patch, Post } from '@nestjs/common';
import { PrescriptionService } from './prescription.service';
import { ApprovalService } from './approval.service';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { RequireStaff } from '../../common/decorators/require-role.decorator';
import { ZodValidationPipe } from '../../common/pipes/zod-validation.pipe';
import {
  addMedicineLineSchema,
  raiseApprovalSchema,
  setPrescriptionImageRotationSchema,
  updateMedicineStatusSchema,
  updatePrescriptionStatusSchema,
  type AddMedicineLineDto,
  type RaiseApprovalDto,
  type SetPrescriptionImageRotationDto,
  type UpdateMedicineStatusDto,
  type UpdatePrescriptionStatusDto,
} from './dto';
import type { RequestSubject } from '../auth/session.types';

/** Store-scoped for every role except SUPERADMIN — see prescription.service.ts. */
@Controller('v1/staff')
@RequireStaff()
export class StaffPrescriptionController {
  constructor(
    private readonly prescriptions: PrescriptionService,
    private readonly approvals: ApprovalService,
  ) {}

  @Get('prescriptions')
  list(@CurrentUser() user: RequestSubject) {
    return this.prescriptions.listForStaff(user.role!, user.storeId ?? null);
  }

  @Get('prescriptions/:id')
  get(@CurrentUser() user: RequestSubject, @Param('id', ParseIntPipe) id: number) {
    return this.prescriptions.getForStaff(user.role!, user.storeId ?? null, id);
  }

  @Post('prescriptions/:id/medicines')
  addMedicine(
    @CurrentUser() user: RequestSubject,
    @Param('id', ParseIntPipe) id: number,
    @Body(new ZodValidationPipe(addMedicineLineSchema)) dto: AddMedicineLineDto,
  ) {
    return this.prescriptions.addMedicineLine(user.role!, user.storeId ?? null, id, dto);
  }

  @Patch('prescriptions/:id/medicines/:medicineId/status')
  updateMedicineStatus(
    @CurrentUser() user: RequestSubject,
    @Param('id', ParseIntPipe) id: number,
    @Param('medicineId', ParseIntPipe) medicineId: number,
    @Body(new ZodValidationPipe(updateMedicineStatusSchema)) dto: UpdateMedicineStatusDto,
  ) {
    return this.prescriptions.updateMedicineStatus(user.role!, user.storeId ?? null, id, medicineId, dto);
  }

  @Patch('prescriptions/:id/status')
  updateStatus(
    @CurrentUser() user: RequestSubject,
    @Param('id', ParseIntPipe) id: number,
    @Body(new ZodValidationPipe(updatePrescriptionStatusSchema)) dto: UpdatePrescriptionStatusDto,
  ) {
    return this.prescriptions.updateStatus(user.role!, user.storeId ?? null, id, dto);
  }

  @Patch('prescriptions/:id/images/:imageId/rotation')
  setImageRotation(
    @CurrentUser() user: RequestSubject,
    @Param('id', ParseIntPipe) id: number,
    @Param('imageId', ParseIntPipe) imageId: number,
    @Body(new ZodValidationPipe(setPrescriptionImageRotationSchema)) dto: SetPrescriptionImageRotationDto,
  ) {
    return this.prescriptions.setImageRotation(user.role!, user.storeId ?? null, id, imageId, dto);
  }

  @Post('approvals')
  raiseApproval(
    @CurrentUser() user: RequestSubject,
    @Body(new ZodValidationPipe(raiseApprovalSchema)) dto: RaiseApprovalDto,
  ) {
    return this.approvals.raise(user.role!, user.storeId ?? null, dto);
  }

  @Get('approvals')
  listApprovals(@CurrentUser() user: RequestSubject) {
    return this.approvals.listForStaff(user.role!, user.storeId ?? null);
  }
}
