import { Body, Controller, Get, Param, ParseIntPipe, Post } from '@nestjs/common';
import { BookingService } from './booking.service';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { RequireMember, RequireRegistered } from '../../common/decorators/require-role.decorator';
import { ZodValidationPipe } from '../../common/pipes/zod-validation.pipe';
import { bookAppointmentSchema, bookLabTestSchema, type BookAppointmentDto, type BookLabTestDto } from './dto';
import type { RequestSubject } from '../auth/session.types';

@Controller('v1/member')
@RequireMember()
export class MemberBookingController {
  constructor(private readonly bookings: BookingService) {}

  @RequireRegistered()
  @Post('lab-bookings')
  bookLabTest(@CurrentUser() user: RequestSubject, @Body(new ZodValidationPipe(bookLabTestSchema)) dto: BookLabTestDto) {
    return this.bookings.bookLabTest(Number(user.subjectId), dto);
  }

  @Get('lab-bookings')
  listLabBookings(@CurrentUser() user: RequestSubject) {
    return this.bookings.listLabBookingsForMember(Number(user.subjectId));
  }

  @Get('lab-bookings/:id')
  getLabBooking(@CurrentUser() user: RequestSubject, @Param('id', ParseIntPipe) id: number) {
    return this.bookings.getLabBookingForMember(Number(user.subjectId), id);
  }

  @RequireRegistered()
  @Post('appointments')
  bookAppointment(
    @CurrentUser() user: RequestSubject,
    @Body(new ZodValidationPipe(bookAppointmentSchema)) dto: BookAppointmentDto,
  ) {
    return this.bookings.bookAppointment(Number(user.subjectId), dto);
  }

  @Get('appointments')
  listAppointments(@CurrentUser() user: RequestSubject) {
    return this.bookings.listAppointmentsForMember(Number(user.subjectId));
  }

  @Get('appointments/:id')
  getAppointment(@CurrentUser() user: RequestSubject, @Param('id', ParseIntPipe) id: number) {
    return this.bookings.getAppointmentForMember(Number(user.subjectId), id);
  }
}
