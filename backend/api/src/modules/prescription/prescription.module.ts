import { Module } from '@nestjs/common';
import { PrescriptionService } from './prescription.service';
import { ApprovalService } from './approval.service';
import { MemberPrescriptionController } from './member-prescription.controller';
import { StaffPrescriptionController } from './staff-prescription.controller';

@Module({
  controllers: [MemberPrescriptionController, StaffPrescriptionController],
  providers: [PrescriptionService, ApprovalService],
})
export class PrescriptionModule {}
