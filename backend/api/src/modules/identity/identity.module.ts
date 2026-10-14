import { Module } from '@nestjs/common';
import { IdentityService } from './identity.service';
import { MemberController } from './member.controller';
import { StaffController } from './staff.controller';
import { AuthModule } from '../auth/auth.module';
import { AgentModule } from '../agent/agent.module';
import { InvestorModule } from '../investor/investor.module';

@Module({
  // AuthModule for AuthService.revokeAllSessions — deleteAccount kills
  // every live backend session for the member being deleted, not just
  // whichever one made this call, so a token minted on another device
  // before the delete can't keep acting as this member afterward.
  // AgentModule/InvestorModule so StaffController can offer the Users
  // page's own "Make agent"/"Make investor"/"Revoke" actions without
  // either of those modules needing to know Identity exists.
  imports: [AuthModule, AgentModule, InvestorModule],
  controllers: [MemberController, StaffController],
  providers: [IdentityService],
})
export class IdentityModule {}
