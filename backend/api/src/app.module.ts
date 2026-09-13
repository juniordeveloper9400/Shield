import { Module } from '@nestjs/common';
import { APP_FILTER, APP_GUARD } from '@nestjs/core';
import { ConfigModule } from '@nestjs/config';
import { ThrottlerGuard, ThrottlerModule } from '@nestjs/throttler';
import { validateEnv } from './config/env';
import { DbModule } from './db/db.module';
import { CacheModule } from './cache/cache.module';
import { StorageModule } from './storage/storage.module';
import { AuthModule } from './modules/auth/auth.module';
import { IdentityModule } from './modules/identity/identity.module';
import { CatalogueModule } from './modules/catalogue/catalogue.module';
import { CommerceModule } from './modules/commerce/commerce.module';
import { PrescriptionModule } from './modules/prescription/prescription.module';
import { WalletModule } from './modules/wallet/wallet.module';
import { CareModule } from './modules/care/care.module';
import { GeoModule } from './modules/geo/geo.module';
import { AgentModule } from './modules/agent/agent.module';
import { InvestorModule } from './modules/investor/investor.module';
import { AdminModule } from './modules/admin/admin.module';
import { HealthController } from './modules/health/health.controller';
import { AuthGuard } from './common/guards/auth.guard';
import { RolesGuard } from './common/guards/roles.guard';
import { HttpExceptionFilter } from './common/filters/http-exception.filter';

@Module({
  imports: [
    // .env.local first (the documented local-dev convention — see
    // backend/docs/project-structure.md "cp .env.example .env.local"),
    // falling back to .env. Neither is ever committed (see .gitignore);
    // a real deployment sets these as actual environment variables and
    // this array is simply never matched.
    ConfigModule.forRoot({ isGlobal: true, validate: validateEnv, envFilePath: ['.env.local', '.env'] }),
    // In-memory limiter for now — becomes Redis-backed (see
    // backend/docs/tech-stack.md) once this runs as more than one instance,
    // since an in-memory counter doesn't share state across instances.
    ThrottlerModule.forRoot([{ ttl: 60_000, limit: 120 }]),
    DbModule,
    CacheModule,
    StorageModule,
    AuthModule,
    IdentityModule,
    CatalogueModule,
    CommerceModule,
    PrescriptionModule,
    WalletModule,
    CareModule,
    GeoModule,
    AgentModule,
    InvestorModule,
    AdminModule,
  ],
  controllers: [HealthController],
  providers: [
    // Order matters: resolve identity first, then role, then rate limit.
    { provide: APP_GUARD, useClass: AuthGuard },
    { provide: APP_GUARD, useClass: RolesGuard },
    { provide: APP_GUARD, useClass: ThrottlerGuard },
    { provide: APP_FILTER, useClass: HttpExceptionFilter },
  ],
})
export class AppModule {}
