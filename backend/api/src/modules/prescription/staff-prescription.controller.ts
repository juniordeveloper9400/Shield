import { Body, Controller, Delete, Get, Param, ParseIntPipe, Patch, Post } from '@nestjs/common';
import { PrescriptionService } from './prescription.service';
import { ApprovalService } from './approval.service';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { RequireRole } from '../../common/decorators/require-role.decorator';
import { ZodValidationPipe } from '../../common/pipes/zod-validation.pipe';
import {
  addMedicineLineSchema,
  createOrderForPrescriptionSchema,
  raiseApprovalSchema,
  saveIntakeSchema,
  setPrescriptionImageRotationSchema,
  updateMedicineStatusSchema,
  updatePrescriptionBranchSchema,
  updatePrescriptionDetailsSchema,
  updatePrescriptionFulfillmentSchema,
  updatePrescriptionPatientSchema,
  updatePrescriptionStatusSchema,
  type AddMedicineLineDto,
  type CreateOrderForPrescriptionDto,
  type RaiseApprovalDto,
  type SaveIntakeDto,
  type SetPrescriptionImageRotationDto,
  type UpdateMedicineStatusDto,
  type UpdatePrescriptionBranchDto,
  type UpdatePrescriptionDetailsDto,
  type UpdatePrescriptionFulfillmentDto,
  type UpdatePrescriptionPatientDto,
  type UpdatePrescriptionStatusDto,
} from './dto';
import type { RequestSubject } from '../auth/session.types';

/**
 * Store-scoped for every role except SUPERADMIN/ADMIN — see
 * prescription.service.ts. Role-restricted to SUPERADMIN/ADMIN/PHARMACY —
 * the only roles shieldweb's own permissions config gives the
 * 'prescriptions' module to (not LAB/DELIVERY/APPOINTMENTS/
 * LAB_TECHNICIAN).
 */
@Controller('v1/staff')
@RequireRole('SUPERADMIN', 'ADMIN', 'PHARMACY')
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

  // imageId is a real app.prescription_image id, or legacy-<id> for a
  // pre-migration-0040 photo — not ParseIntPipe'd for that reason.
  @Patch('prescriptions/:id/images/:imageId/rotation')
  setImageRotation(
    @CurrentUser() user: RequestSubject,
    @Param('id', ParseIntPipe) id: number,
    @Param('imageId') imageId: string,
    @Body(new ZodValidationPipe(setPrescriptionImageRotationSchema)) dto: SetPrescriptionImageRotationDto,
  ) {
    return this.prescriptions.setImageRotation(user.role!, user.storeId ?? null, id, imageId, dto);
  }

  @Post('prescriptions/:id/intake')
  saveIntake(
    @CurrentUser() user: RequestSubject,
    @Param('id', ParseIntPipe) id: number,
    @Body(new ZodValidationPipe(saveIntakeSchema)) dto: SaveIntakeDto,
  ) {
    return this.prescriptions.savePrescriptionIntake(user.role!, user.storeId ?? null, id, dto);
  }

  @Patch('prescriptions/:id/details')
  updateDetails(
    @CurrentUser() user: RequestSubject,
    @Param('id', ParseIntPipe) id: number,
    @Body(new ZodValidationPipe(updatePrescriptionDetailsSchema)) dto: UpdatePrescriptionDetailsDto,
  ) {
    return this.prescriptions.updatePrescriptionDetails(user.role!, user.storeId ?? null, id, dto);
  }

  @Patch('prescriptions/:id/branch')
  updateBranch(
    @CurrentUser() user: RequestSubject,
    @Param('id', ParseIntPipe) id: number,
    @Body(new ZodValidationPipe(updatePrescriptionBranchSchema)) dto: UpdatePrescriptionBranchDto,
  ) {
    return this.prescriptions.updatePrescriptionBranch(user.role!, user.storeId ?? null, id, dto);
  }

  @Delete('prescriptions/:id')
  remove(@CurrentUser() user: RequestSubject, @Param('id', ParseIntPipe) id: number) {
    return this.prescriptions.deleteForStaff(user.role!, user.storeId ?? null, id);
  }

  @Patch('prescriptions/:id/fulfillment')
  updateFulfillment(
    @CurrentUser() user: RequestSubject,
    @Param('id', ParseIntPipe) id: number,
    @Body(new ZodValidationPipe(updatePrescriptionFulfillmentSchema)) dto: UpdatePrescriptionFulfillmentDto,
  ) {
    return this.prescriptions.updatePrescriptionFulfillment(user.role!, user.storeId ?? null, id, dto);
  }

  @Patch('prescriptions/:id/patient')
  updatePatient(
    @CurrentUser() user: RequestSubject,
    @Param('id', ParseIntPipe) id: number,
    @Body(new ZodValidationPipe(updatePrescriptionPatientSchema)) dto: UpdatePrescriptionPatientDto,
  ) {
    return this.prescriptions.updatePrescriptionPatient(user.role!, user.storeId ?? null, id, dto);
  }

  @Post('prescriptions/:id/order')
  createOrder(
    @CurrentUser() user: RequestSubject,
    @Param('id', ParseIntPipe) id: number,
    @Body(new ZodValidationPipe(createOrderForPrescriptionSchema)) dto: CreateOrderForPrescriptionDto,
  ) {
    return this.prescriptions.createOrderForPrescription(user.role!, user.storeId ?? null, id, dto);
  }

  @Get('orders/:orderId/prescription-medicines')
  medicinesForOrder(@CurrentUser() user: RequestSubject, @Param('orderId', ParseIntPipe) orderId: number) {
    return this.prescriptions.getPrescriptionMedicinesForOrder(user.role!, user.storeId ?? null, orderId);
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
