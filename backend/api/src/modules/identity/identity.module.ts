import { Module } from '@nestjs/common';
import { IdentityService } from './identity.service';
import { MemberController } from './member.controller';
import { StaffController } from './staff.controller';

@Module({
  controllers: [MemberController, StaffController],
  providers: [IdentityService],
})
export class IdentityModule {}
