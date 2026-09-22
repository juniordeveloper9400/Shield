import { Module } from '@nestjs/common';
import { IdentityService } from './identity.service';
import { MemberController } from './member.controller';
import { StaffController } from './staff.controller';
import { AuthModule } from '../auth/auth.module';

@Module({
  // AuthModule for AuthService.revokeAllSessions — deleteAccount kills
  // every live backend session for the member being deleted, not just
  // whichever one made this call, so a token minted on another device
  // before the delete can't keep acting as this member afterward.
  imports: [AuthModule],
  controllers: [MemberController, StaffController],
  providers: [IdentityService],
})
export class IdentityModule {}
