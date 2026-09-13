import { Controller, Get } from '@nestjs/common';
import { DashboardService } from './dashboard.service';
import { RequireStaff } from '../../common/decorators/require-role.decorator';

@Controller('v1/staff/dashboard')
@RequireStaff()
export class DashboardController {
  constructor(private readonly dashboard: DashboardService) {}

  @Get('summary')
  summary() {
    return this.dashboard.getSummary();
  }
}
