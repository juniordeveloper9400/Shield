import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { AuthService } from './auth.service';
import { TokenService } from './token.service';
import { FirebaseAdminVerifier } from './firebase.service';
import { MemberAuthController } from './member-auth.controller';
import { StaffAuthController } from './staff-auth.controller';
import { AuthGuard } from '../../common/guards/auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { FIREBASE_VERIFIER } from './session.types';

@Module({
  imports: [JwtModule.register({})],
  controllers: [MemberAuthController, StaffAuthController],
  providers: [
    AuthService,
    TokenService,
    AuthGuard,
    RolesGuard,
    { provide: FIREBASE_VERIFIER, useClass: FirebaseAdminVerifier },
  ],
  exports: [AuthService, TokenService, AuthGuard, RolesGuard],
})
export class AuthModule {}
