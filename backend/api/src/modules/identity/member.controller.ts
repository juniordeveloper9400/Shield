import { Body, Controller, Delete, Get, HttpCode, HttpStatus, Param, ParseIntPipe, Patch, Post } from '@nestjs/common';
import { IdentityService } from './identity.service';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { RequireMember } from '../../common/decorators/require-role.decorator';
import { ZodValidationPipe } from '../../common/pipes/zod-validation.pipe';
import {
  createAddressSchema,
  createPatientSchema,
  updateAddressSchema,
  updateMemberProfileSchema,
  updatePatientSchema,
  type CreateAddressDto,
  type CreatePatientDto,
  type UpdateAddressDto,
  type UpdateMemberProfileDto,
  type UpdatePatientDto,
} from './dto';
import type { RequestSubject } from '../auth/session.types';

@Controller('v1/member')
@RequireMember()
export class MemberController {
  constructor(private readonly identity: IdentityService) {}

  @Get('me')
  async me(@CurrentUser() user: RequestSubject) {
    return this.identity.getMemberProfile(Number(user.subjectId));
  }

  @Patch('me')
  async updateMe(
    @CurrentUser() user: RequestSubject,
    @Body(new ZodValidationPipe(updateMemberProfileSchema)) body: UpdateMemberProfileDto,
  ) {
    return this.identity.updateProfile(Number(user.subjectId), body);
  }

  @Delete('me')
  @HttpCode(HttpStatus.NO_CONTENT)
  async deleteMe(@CurrentUser() user: RequestSubject) {
    await this.identity.deleteAccount(Number(user.subjectId));
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

  @Patch('addresses/:id')
  async updateAddress(
    @CurrentUser() user: RequestSubject,
    @Param('id', ParseIntPipe) id: number,
    @Body(new ZodValidationPipe(updateAddressSchema)) body: UpdateAddressDto,
  ) {
    return this.identity.updateAddress(Number(user.subjectId), id, body);
  }

  @Delete('addresses/:id')
  @HttpCode(HttpStatus.NO_CONTENT)
  async deleteAddress(@CurrentUser() user: RequestSubject, @Param('id', ParseIntPipe) id: number) {
    await this.identity.softDeleteAddress(Number(user.subjectId), id);
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

  @Patch('patients/:id')
  async updatePatient(
    @CurrentUser() user: RequestSubject,
    @Param('id', ParseIntPipe) id: number,
    @Body(new ZodValidationPipe(updatePatientSchema)) body: UpdatePatientDto,
  ) {
    return this.identity.updatePatient(Number(user.subjectId), id, body);
  }

  @Delete('patients/:id')
  @HttpCode(HttpStatus.NO_CONTENT)
  async deletePatient(@CurrentUser() user: RequestSubject, @Param('id', ParseIntPipe) id: number) {
    await this.identity.softDeletePatient(Number(user.subjectId), id);
  }
}
