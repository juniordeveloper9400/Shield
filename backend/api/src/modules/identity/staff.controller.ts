import { Controller, Delete, Get, HttpCode, Param, ParseIntPipe } from '@nestjs/common';
import { IdentityService } from './identity.service';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { RequireRole, RequireStaff } from '../../common/decorators/require-role.decorator';
import type { RequestSubject } from '../auth/session.types';

@Controller('v1/staff')
@RequireStaff()
export class StaffController {
  constructor(private readonly identity: IdentityService) {}

  @Get('me')
  async me(@CurrentUser() user: RequestSubject) {
    return this.identity.getStaffProfile(Number(user.subjectId));
  }

  @Delete('users/:id')
  @HttpCode(204)
  @RequireRole('SUPERADMIN', 'ADMIN')
  async permanentlyDeleteMember(
    @Param('id', ParseIntPipe) id: number,
    @CurrentUser() user: RequestSubject,
  ) {
    await this.identity.permanentlyDeleteMember(id, user.sessionId);
  }
}
