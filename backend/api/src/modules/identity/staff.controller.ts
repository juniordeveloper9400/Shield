import { Controller, Get } from '@nestjs/common';
import { IdentityService } from './identity.service';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { RequireStaff } from '../../common/decorators/require-role.decorator';
import type { RequestSubject } from '../auth/session.types';

@Controller('v1/staff')
@RequireStaff()
export class StaffController {
  constructor(private readonly identity: IdentityService) {}

  @Get('me')
  async me(@CurrentUser() user: RequestSubject) {
    return this.identity.getStaffProfile(Number(user.subjectId));
  }
}
