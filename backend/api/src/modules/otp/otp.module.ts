import { Module } from '@nestjs/common';
import { OtpService } from './otp.service';
import { OtpController } from './otp.controller';
import { AgentOtpController } from './agent-otp.controller';

@Module({
  controllers: [OtpController, AgentOtpController],
  providers: [OtpService],
})
export class OtpModule {}
