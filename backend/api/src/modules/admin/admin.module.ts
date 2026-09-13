import { Module } from '@nestjs/common';
import { AdminService } from './admin.service';
import { DashboardService } from './dashboard.service';
import { AdminController } from './admin.controller';
import { DashboardController } from './dashboard.controller';

@Module({
  controllers: [AdminController, DashboardController],
  providers: [AdminService, DashboardService],
})
export class AdminModule {}
