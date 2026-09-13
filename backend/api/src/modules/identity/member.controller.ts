import { Body, Controller, Get, Post } from '@nestjs/common';
import { IdentityService } from './identity.service';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { RequireMember } from '../../common/decorators/require-role.decorator';
import { ZodValidationPipe } from '../../common/pipes/zod-validation.pipe';
import { createAddressSchema, createPatientSchema, type CreateAddressDto, type CreatePatientDto } from './dto';
import type { RequestSubject } from '../auth/session.types';

@Controller('v1/member')
@RequireMember()
export class MemberController {
  constructor(private readonly identity: IdentityService) {}

  @Get('me')
  async me(@CurrentUser() user: RequestSubject) {
    return this.identity.getMemberProfile(Number(user.subjectId));
  }

  @Get('addresses')
  async addresses(@CurrentUser() user: RequestSubject) {
    return this.identity.listAddresses(Number(user.subjectId));
  }

  @Post('addresses')
  async createAddress(
    @CurrentUser() user: RequestSubject,
    @Body(new ZodValidationPipe(createAddressSchema)) body: CreateAddressDto,
  ) {
    return this.identity.createAddress(Number(user.subjectId), body);
  }

  @Get('patients')
  async patients(@CurrentUser() user: RequestSubject) {
    return this.identity.listPatients(Number(user.subjectId));
  }

  @Post('patients')
  async createPatient(
    @CurrentUser() user: RequestSubject,
    @Body(new ZodValidationPipe(createPatientSchema)) body: CreatePatientDto,
  ) {
    return this.identity.createPatient(Number(user.subjectId), body);
  }
}
