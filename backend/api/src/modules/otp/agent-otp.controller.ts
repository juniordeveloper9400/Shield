import { Body, Controller, HttpCode, HttpStatus, Post } from '@nestjs/common';
import { OtpService } from './otp.service';
import { RequireMember } from '../../common/decorators/require-role.decorator';
import { AuthThrottle } from '../../common/throttle';
import { ZodValidationPipe } from '../../common/pipes/zod-validation.pipe';
import {
  sendAgentOtpSchema,
  verifyAgentOtpSchema,
  verifyMsg91Schema,
  type SendAgentOtpDto,
  type VerifyAgentOtpDto,
  type VerifyMsg91Dto,
} from './dto';

/**
 * Member-authenticated — called by a signed-in agent/member registering a
 * *new* recruit under them (`lib/module/agent/agent_phone_verifier.dart`),
 * to prove the recruit really holds the phone number on the form before
 * the registration goes through. Replaces that screen's old dedicated
 * Firebase project; see OtpService for the MSG91 side of this.
 */
@Controller('v1/agent/otp')
@RequireMember()
export class AgentOtpController {
  constructor(private readonly otp: OtpService) {}

  @AuthThrottle()
  @HttpCode(HttpStatus.OK)
  @Post('send-msg91')
  sendOtp(@Body(new ZodValidationPipe(sendAgentOtpSchema)) dto: SendAgentOtpDto) {
    return this.otp.sendMsg91Otp(dto.phone);
  }

  @AuthThrottle()
  @HttpCode(HttpStatus.OK)
  @Post('verify-msg91')
  verifyOtp(@Body(new ZodValidationPipe(verifyAgentOtpSchema)) dto: VerifyAgentOtpDto) {
    return this.otp.verifyMsg91Otp(dto.phone, dto.code);
  }

  /** For a client that ran MSG91's JS widget itself (a WebView on the
   *  Flutter app) instead of asking this backend to send the code — see
   *  `auth.service.ts`'s `exchangeMemberWidgetToken` for the member-login
   *  equivalent of why. */
  @AuthThrottle()
  @HttpCode(HttpStatus.OK)
  @Post('verify-widget')
  verifyWidget(@Body(new ZodValidationPipe(verifyMsg91Schema)) dto: VerifyMsg91Dto) {
    return this.otp.verifyMsg91AccessToken(dto.accessToken, dto.expectedPhone);
  }
}
