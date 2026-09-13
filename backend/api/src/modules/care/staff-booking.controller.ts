import { Body, Controller, Get, Param, ParseIntPipe, Patch } from '@nestjs/common';
import { BookingService } from './booking.service';
import { RequireStaff } from '../../common/decorators/require-role.decorator';
import { ZodValidationPipe } from '../../common/pipes/zod-validation.pipe';
import {
  updateAppointmentStatusSchema,
  updateLabBookingStatusSchema,
  type UpdateAppointmentStatusDto,
  type UpdateLabBookingStatusDto,
} from './dto';

/** No branch scoping — see booking.service.ts; any staff role may manage these. */
@Controller('v1/staff')
@RequireStaff()
export class StaffBookingController {
  constructor(private readonly bookings: BookingService) {}

  @Get('lab-bookings')
  listLabBookings() {
    return this.bookings.listLabBookingsForStaff();
  }

  @Patch('lab-bookings/:id/status')
  updateLabBookingStatus(
    @Param('id', ParseIntPipe) id: number,
    @Body(new ZodValidationPipe(updateLabBookingStatusSchema)) dto: UpdateLabBookingStatusDto,
  ) {
    return this.bookings.updateLabBookingStatus(id, dto);
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
