import { Body, Controller, Delete, HttpCode, HttpStatus, Post, Req } from '@nestjs/common';
import type { Request } from 'express';
import { AuthService } from './auth.service';
import { Public } from '../../common/decorators/public.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { RequireStaff } from '../../common/decorators/require-role.decorator';
import { AuthThrottle } from '../../common/throttle';
import { ZodValidationPipe } from '../../common/pipes/zod-validation.pipe';
import { staffLoginSchema, refreshTokenSchema, type StaffLoginDto, type RefreshTokenDto } from './dto';
import type { RequestSubject } from './session.types';

@Controller('v1/staff/auth')
export class StaffAuthController {
  constructor(private readonly auth: AuthService) {}

  @Public()
  @AuthThrottle()
  @Post('session')
  @HttpCode(HttpStatus.OK)
  async createSession(@Body(new ZodValidationPipe(staffLoginSchema)) body: StaffLoginDto, @Req() req: Request) {
    return this.auth.loginStaff(body.email, body.password, { userAgent: req.headers['user-agent'], ip: req.ip });
  }

  @Public()
  @AuthThrottle()
  @Post('refresh')
  @HttpCode(HttpStatus.OK)
  async refresh(@Body(new ZodValidationPipe(refreshTokenSchema)) body: RefreshTokenDto) {
    return this.auth.refresh(body.refreshToken);
  }

  @RequireStaff()
  @Delete('session')
  @HttpCode(HttpStatus.NO_CONTENT)
  async logout(@CurrentUser() user: RequestSubject) {
    await this.auth.revokeSession(user.sessionId);
  }

  @RequireStaff()
  @Delete('sessions')
  @HttpCode(HttpStatus.NO_CONTENT)
  async logoutAll(@CurrentUser() user: RequestSubject) {
    await this.auth.revokeAllSessions('STAFF', user.subjectId);
  }
}
