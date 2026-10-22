import { Module } from '@nestjs/common';
import { AgentService } from './agent.service';
import { MemberAgentController } from './member-agent.controller';
import { StaffAgentController } from './staff-agent.controller';
import { AuthModule } from '../auth/auth.module';
import { OtpModule } from '../otp/otp.module';
import { IdempotencyService } from '../../common/idempotency/idempotency.service';

@Module({
  // OtpModule: approving a withdrawal texts and checks an MSG91 code on the
  // agent's registered phone.
  imports: [AuthModule, OtpModule],
  controllers: [MemberAgentController, StaffAgentController],
  providers: [AgentService, IdempotencyService],
  exports: [AgentService],
})
export class AgentModule {}
