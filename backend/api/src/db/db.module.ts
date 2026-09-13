import { Global, Module } from '@nestjs/common';
import { DrizzleProvider, DrizzleService } from './client';

@Global()
@Module({
  providers: [DrizzleService, DrizzleProvider],
  exports: [DrizzleProvider, DrizzleService],
})
export class DbModule {}
