import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { AuthService } from './auth.service';
import { TokenService } from './token.service';
import { MemberAuthController } from './member-auth.controller';
import { StaffAuthController } from './staff-auth.controller';
import { AuthGuard } from '../../common/guards/auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { OtpModule } from '../otp/otp.module';
import { AuditModule } from '../audit/audit.module';

@Module({
  imports: [JwtModule.register({}), OtpModule, AuditModule],
  controllers: [MemberAuthController, StaffAuthController],
  providers: [AuthService, TokenService, AuthGuard, RolesGuard],
  exports: [AuthService, TokenService, AuthGuard, RolesGuard],
})
export class AuthModule {}
