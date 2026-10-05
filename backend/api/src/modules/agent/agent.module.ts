import { Module } from '@nestjs/common';
import { AgentService } from './agent.service';
import { MemberAgentController } from './member-agent.controller';
import { StaffAgentController } from './staff-agent.controller';
import { AuthModule } from '../auth/auth.module';
import { IdempotencyService } from '../../common/idempotency/idempotency.service';

@Module({
  // AuthModule exports FIREBASE_VERIFIER, which approving a withdrawal needs to
  // check the agent's phone OTP.
  imports: [AuthModule],
  controllers: [MemberAgentController, StaffAgentController],
  providers: [AgentService, IdempotencyService],
})
export class AgentModule {}
