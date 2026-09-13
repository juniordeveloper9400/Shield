import { Body, Controller, Get, Param, ParseIntPipe, Post } from '@nestjs/common';
import { PrescriptionService } from './prescription.service';
import { ApprovalService } from './approval.service';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { RequireMember } from '../../common/decorators/require-role.decorator';
import { ZodValidationPipe } from '../../common/pipes/zod-validation.pipe';
import {
  respondApprovalSchema,
  uploadPrescriptionSchema,
  type RespondApprovalDto,
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
