import { Module } from '@nestjs/common';
import { OtpService } from './otp.service';
import { OtpController } from './otp.controller';
import { AgentOtpController } from './agent-otp.controller';

@Module({
  controllers: [OtpController, AgentOtpController],
  providers: [OtpService],
  // AuthModule's member-login flow (auth.service.ts) calls OtpService
  // directly — see sendMemberOtp/exchangeMemberPhone/registerMemberByPhone.
  exports: [OtpService],
})
export class OtpModule {}
