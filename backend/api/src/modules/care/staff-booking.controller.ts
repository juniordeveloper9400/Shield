import { Body, Controller, Get, Param, ParseIntPipe, Patch, Put } from '@nestjs/common';
import { BookingService } from './booking.service';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { RequireRole, RequireStaff } from '../../common/decorators/require-role.decorator';
import { ZodValidationPipe } from '../../common/pipes/zod-validation.pipe';
import type { RequestSubject } from '../auth/session.types';
import {
  sendLabBillSchema,
  updateAppointmentStatusSchema,
  updateLabBookingStatusSchema,
  type SendLabBillDto,
  type UpdateAppointmentStatusDto,
  type UpdateLabBookingStatusDto,
} from './dto';

/** Appointments stay open to any staff role (no branch, see
 *  booking.service.ts's own doc); the lab-booking routes below narrow that
 *  to the roles that actually work lab bookings. */
@Controller('v1/staff')
@RequireStaff()
export class StaffBookingController {
  constructor(private readonly bookings: BookingService) {}

  @RequireRole('SUPERADMIN', 'ADMIN', 'LAB', 'LAB_TECHNICIAN')
  @Get('lab-bookings')
  listLabBookings(@CurrentUser() user: RequestSubject) {
    return this.bookings.listLabBookingsForStaff(user.role!, user.storeId ?? null);
  }

  @RequireRole('SUPERADMIN', 'ADMIN', 'LAB', 'LAB_TECHNICIAN')
  @Patch('lab-bookings/:id/status')
  updateLabBookingStatus(
    @CurrentUser() user: RequestSubject,
    @Param('id', ParseIntPipe) id: number,
    @Body(new ZodValidationPipe(updateLabBookingStatusSchema)) dto: UpdateLabBookingStatusDto,
  ) {
    return this.bookings.updateLabBookingStatus(user.role!, user.storeId ?? null, id, dto);
  }

  @RequireRole('SUPERADMIN', 'ADMIN', 'LAB', 'LAB_TECHNICIAN')
  @Put('lab-bookings/:id/bill')
  sendLabBill(
    @CurrentUser() user: RequestSubject,
    @Param('id', ParseIntPipe) id: number,
    @Body(new ZodValidationPipe(sendLabBillSchema)) dto: SendLabBillDto,
  ) {
    return this.bookings.sendLabBill(user.role!, user.storeId ?? null, id, dto);
  }

  @RequireRole('SUPERADMIN', 'ADMIN', 'LAB', 'LAB_TECHNICIAN')
  @Patch('lab-bookings/:id/collect-wallet')
  collectLabBillWithWallet(@CurrentUser() user: RequestSubject, @Param('id', ParseIntPipe) id: number) {
    return this.bookings.collectLabBillWithWallet(user.role!, user.storeId ?? null, id);
  }

  @Get('appointments')
  listAppointments() {
    return this.bookings.listAppointmentsForStaff();
  }

  @Patch('appointments/:id/status')
  updateAppointmentStatus(
    @Param('id', ParseIntPipe) id: number,
    @Body(new ZodValidationPipe(updateAppointmentStatusSchema)) dto: UpdateAppointmentStatusDto,
  ) {
    return this.bookings.updateAppointmentStatus(id, dto);
  }
}
