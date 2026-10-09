import { Body, Controller, HttpCode, HttpStatus, Post } from '@nestjs/common';
import { OtpService } from './otp.service';
import { RequireStaff } from '../../common/decorators/require-role.decorator';
import { ZodValidationPipe } from '../../common/pipes/zod-validation.pipe';
import { verifyMsg91Schema, type VerifyMsg91Dto } from './dto';

/**
 * Staff-only — the counter/delivery-OTP check shieldweb's BillEditorModal
 * (and the other OTP-gated money-moving screens) call before acting on a
 * code the member read out over the phone. Replaces what used to be a
 * purely client-side Firebase check; see OtpService's own doc for the
 * reasoning and the one known gap this doesn't close.
 */
@Controller('v1/staff/otp')
@RequireStaff()
export class OtpController {
  constructor(private readonly otp: OtpService) {}

  @Post('verify-msg91')
  @HttpCode(HttpStatus.OK)
  verifyMsg91(@Body(new ZodValidationPipe(verifyMsg91Schema)) dto: VerifyMsg91Dto) {
    return this.otp.verifyMsg91AccessToken(dto.accessToken, dto.expectedPhone);
  }
}
