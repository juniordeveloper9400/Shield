import { Body, Controller, Delete, Get, HttpCode, HttpStatus, Param, ParseIntPipe, Post } from '@nestjs/common';
import { PrescriptionService } from './prescription.service';
import { ApprovalService } from './approval.service';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { RequireMember } from '../../common/decorators/require-role.decorator';
import { ZodValidationPipe } from '../../common/pipes/zod-validation.pipe';
import {
  respondApprovalSchema,
  submitPrescriptionOrderSchema,
  uploadPrescriptionSchema,
  type RespondApprovalDto,
  type SubmitPrescriptionOrderDto,
  type UploadPrescriptionDto,
} from './dto';
import type { RequestSubject } from '../auth/session.types';

@Controller('v1/member')
@RequireMember()
export class MemberPrescriptionController {
  constructor(
    private readonly prescriptions: PrescriptionService,
    private readonly approvals: ApprovalService,
  ) {}

  @Post('prescriptions')
  upload(
    @CurrentUser() user: RequestSubject,
    @Body(new ZodValidationPipe(uploadPrescriptionSchema)) dto: UploadPrescriptionDto,
  ) {
    return this.prescriptions.upload(Number(user.subjectId), dto);
  }

  @Get('prescriptions')
  list(@CurrentUser() user: RequestSubject) {
    return this.prescriptions.listForMember(Number(user.subjectId));
  }

  @Get('prescriptions/:id')
  get(@CurrentUser() user: RequestSubject, @Param('id', ParseIntPipe) id: number) {
    return this.prescriptions.getForMember(Number(user.subjectId), id);
  }

  @Delete('prescriptions/:id')
  @HttpCode(HttpStatus.NO_CONTENT)
  async delete(@CurrentUser() user: RequestSubject, @Param('id', ParseIntPipe) id: number) {
    await this.prescriptions.deleteForMember(Number(user.subjectId), id);
  }

  @Post('prescription-orders')
  submitForOrder(
    @CurrentUser() user: RequestSubject,
    @Body(new ZodValidationPipe(submitPrescriptionOrderSchema)) dto: SubmitPrescriptionOrderDto,
  ) {
    return this.prescriptions.submitForOrder(Number(user.subjectId), dto);
  }

  @Get('approvals')
  listApprovals(@CurrentUser() user: RequestSubject) {
    return this.approvals.listForMember(Number(user.subjectId));
  }

  @Get('approvals/:id')
  getApproval(@CurrentUser() user: RequestSubject, @Param('id', ParseIntPipe) id: number) {
    return this.approvals.getForMember(Number(user.subjectId), id);
  }

  @Post('approvals/:id/respond')
  respondApproval(
    @CurrentUser() user: RequestSubject,
    @Param('id', ParseIntPipe) id: number,
    @Body(new ZodValidationPipe(respondApprovalSchema)) dto: RespondApprovalDto,
  ) {
    return this.approvals.respond(Number(user.subjectId), id, dto);
  }
}
