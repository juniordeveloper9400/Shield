import type { INestApplication } from '@nestjs/common';
import request from 'supertest';

/** The one code [FakeOtpService] accepts, for any phone. */
export const TEST_OTP_CODE = '123456';

/** Stands in for real MSG91 in tests — no network, no MSG91 account needed. */
export class FakeOtpService {
  /** Every phone [sendMsg91Otp] was asked to text, in order. */
  readonly sent: string[] = [];

  async sendMsg91Otp(phone: string) {
    this.sent.push(phone);
    return { ok: true };
  }

  async verifyMsg91Otp(_phone: string, code: string) {
    return code === TEST_OTP_CODE ? { ok: true } : { ok: false, reason: 'That code is not right or has expired.' };
  }

  async verifyMsg91AccessToken(_accessToken: string, _expectedPhone: string) {
    return { ok: false, reason: 'That code is not right or has expired.' };
  }
}

/** Signs an existing member in through the real OTP route. Chain `.expect(...)` as usual. */
export function memberLogin(app: INestApplication, phone: string) {
  return request(app.getHttpServer()).post('/v1/member/auth/otp/verify').send({ phone, code: TEST_OTP_CODE });
}

/** Registers (or reactivates) a member through the real OTP route. */
export function memberRegister(app: INestApplication, phone: string, name: string) {
  return request(app.getHttpServer()).post('/v1/member/auth/otp/register').send({ phone, code: TEST_OTP_CODE, name });
}
