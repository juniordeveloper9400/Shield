import { Module } from '@nestjs/common';
import { AgentService } from './agent.service';
import { MemberAgentController } from './member-agent.controller';
import { StaffAgentController } from './staff-agent.controller';

@Module({
  controllers: [MemberAgentController, StaffAgentController],
  providers: [AgentService],
})
export class AgentModule {}
