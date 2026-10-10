import { Body, Controller, Delete, HttpCode, HttpStatus, Post, Req } from '@nestjs/common';
import type { Request } from 'express';
import { AuthService } from './auth.service';
import { Public } from '../../common/decorators/public.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { RequireMember } from '../../common/decorators/require-role.decorator';
import { AuthThrottle } from '../../common/throttle';
import { ZodValidationPipe } from '../../common/pipes/zod-validation.pipe';
import {
  idTokenSchema,
  phoneLookupSchema,
  refreshTokenSchema,
  registerMemberOtpSchema,
  registerMemberSchema,
  registerMemberWidgetSchema,
  sendMemberOtpSchema,
  verifyMemberOtpSchema,
  verifyMemberWidgetSchema,
  type IdTokenDto,
  type PhoneLookupDto,
  type RefreshTokenDto,
  type RegisterMemberDto,
  type RegisterMemberOtpDto,
  type RegisterMemberWidgetDto,
  type SendMemberOtpDto,
  type VerifyMemberOtpDto,
  type VerifyMemberWidgetDto,
} from './dto';
import type { RequestSubject } from './session.types';

@Controller('v1/member/auth')
export class MemberAuthController {
  constructor(private readonly auth: AuthService) {}

  @Public()
  @AuthThrottle()
  @Post('phone-lookup')
  @HttpCode(HttpStatus.OK)
  async phoneLookup(@Body(new ZodValidationPipe(phoneLookupSchema)) body: PhoneLookupDto) {
    return { exists: await this.auth.phoneExists(body.phone) };
  }

  @Public()
  @AuthThrottle()
  @Post('session')
  @HttpCode(HttpStatus.OK)
  async createSession(@Body(new ZodValidationPipe(idTokenSchema)) body: IdTokenDto, @Req() req: Request) {
    return this.auth.exchangeMemberToken(body.idToken, { userAgent: req.headers['user-agent'], ip: req.ip });
  }

  @Public()
  @AuthThrottle()
  @Post('register')
  @HttpCode(HttpStatus.OK)
  async register(@Body(new ZodValidationPipe(registerMemberSchema)) body: RegisterMemberDto, @Req() req: Request) {
    return this.auth.registerMember(body.idToken, body.name, { userAgent: req.headers['user-agent'], ip: req.ip });
  }

  @Public()
  @AuthThrottle()
  @Post('otp/send')
  @HttpCode(HttpStatus.OK)
  async sendOtp(@Body(new ZodValidationPipe(sendMemberOtpSchema)) body: SendMemberOtpDto) {
    return this.auth.sendMemberOtp(body.phone);
  }

  /** Sign-in path — the client's own `phone-lookup` check decides this vs.
   *  `otp/register` *before* the OTP is even sent; see AuthService's doc on
   *  why there is no idToken-style retry fallback between the two here. */
  @Public()
  @AuthThrottle()
  @Post('otp/verify')
  @HttpCode(HttpStatus.OK)
  async verifyOtp(@Body(new ZodValidationPipe(verifyMemberOtpSchema)) body: VerifyMemberOtpDto, @Req() req: Request) {
    return this.auth.exchangeMemberPhone(body.phone, body.code, { userAgent: req.headers['user-agent'], ip: req.ip });
  }

  @Public()
  @AuthThrottle()
  @Post('otp/register')
  @HttpCode(HttpStatus.OK)
  async registerOtp(@Body(new ZodValidationPipe(registerMemberOtpSchema)) body: RegisterMemberOtpDto, @Req() req: Request) {
    return this.auth.registerMemberByPhone(body.phone, body.code, body.name, {
      userAgent: req.headers['user-agent'],
      ip: req.ip,
    });
  }

  /** Sign-in path for a client that ran MSG91's JS widget itself (a
   *  browser, or a WebView on native) instead of asking this backend to
   *  send the code — see AuthService.exchangeMemberWidgetToken's own doc on
   *  why native apps need this instead of `otp/send`+`otp/verify`. */
  @Public()
  @AuthThrottle()
  @Post('widget/verify')
  @HttpCode(HttpStatus.OK)
  async verifyWidget(@Body(new ZodValidationPipe(verifyMemberWidgetSchema)) body: VerifyMemberWidgetDto, @Req() req: Request) {
    return this.auth.exchangeMemberWidgetToken(body.accessToken, body.phone, {
      userAgent: req.headers['user-agent'],
      ip: req.ip,
    });
  }

  @Public()
  @AuthThrottle()
  @Post('widget/register')
  @HttpCode(HttpStatus.OK)
  async registerWidget(@Body(new ZodValidationPipe(registerMemberWidgetSchema)) body: RegisterMemberWidgetDto, @Req() req: Request) {
    return this.auth.registerMemberByWidgetToken(body.accessToken, body.phone, body.name, {
      userAgent: req.headers['user-agent'],
      ip: req.ip,
    });
  }

  @Public()
  @AuthThrottle()
  @Post('refresh')
  @HttpCode(HttpStatus.OK)
  async refresh(@Body(new ZodValidationPipe(refreshTokenSchema)) body: RefreshTokenDto) {
    return this.auth.refresh(body.refreshToken);
  }

  @RequireMember()
  @Delete('session')
  @HttpCode(HttpStatus.NO_CONTENT)
  async logout(@CurrentUser() user: RequestSubject) {
    await this.auth.revokeSession(user.sessionId);
  }

  @RequireMember()
  @Delete('sessions')
  @HttpCode(HttpStatus.NO_CONTENT)
  async logoutAll(@CurrentUser() user: RequestSubject) {
    await this.auth.revokeAllSessions('MEMBER', user.subjectId);
  }
}
