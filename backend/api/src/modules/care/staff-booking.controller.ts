import { Body, Controller, Delete, Get, Param, ParseIntPipe, Patch, Post, Put, Query } from '@nestjs/common';
import { BookingService } from './booking.service';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { RequireRole, RequireStaff } from '../../common/decorators/require-role.decorator';
import { ZodValidationPipe } from '../../common/pipes/zod-validation.pipe';
import type { RequestSubject } from '../auth/session.types';
import {
  addLabReportPagesSchema,
  assignLabStaffSchema,
  receiveLabBillPaymentSchema,
  sendLabBillSchema,
  updateAppointmentStatusSchema,
  updateLabBookingDetailsSchema,
  updateLabBookingStatusSchema,
  type AddLabReportPagesDto,
  type AssignLabStaffDto,
  type ReceiveLabBillPaymentDto,
  type SendLabBillDto,
  type UpdateAppointmentStatusDto,
  type UpdateLabBookingDetailsDto,
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

  /** The counter's GPay / cash against a lab bill, after the wallet step. */
  @RequireRole('SUPERADMIN', 'ADMIN', 'LAB', 'LAB_TECHNICIAN')
  @Patch('lab-bookings/:id/receive')
  receiveLabBillPayment(
    @CurrentUser() user: RequestSubject,
    @Param('id', ParseIntPipe) id: number,
    @Body(new ZodValidationPipe(receiveLabBillPaymentSchema)) dto: ReceiveLabBillPaymentDto,
  ) {
    return this.bookings.receiveLabBillPayment(user.role!, user.storeId ?? null, id, dto);
  }

  @RequireRole('SUPERADMIN', 'ADMIN', 'LAB', 'LAB_TECHNICIAN')
  @Get('lab-bookings/:id/wallet-balance')
  getWalletBalanceForLabBooking(@CurrentUser() user: RequestSubject, @Param('id', ParseIntPipe) id: number) {
    return this.bookings.getWalletBalanceForLabBooking(user.role!, user.storeId ?? null, id);
  }

  @RequireRole('SUPERADMIN', 'ADMIN', 'LAB', 'LAB_TECHNICIAN')
  @Get('lab-bookings/:id/health-pass-charge')
  getHealthPassChargeForLabBooking(@CurrentUser() user: RequestSubject, @Param('id', ParseIntPipe) id: number) {
    return this.bookings.getHealthPassChargeForLabBooking(user.role!, user.storeId ?? null, id);
  }

  @RequireRole('SUPERADMIN', 'ADMIN', 'LAB', 'LAB_TECHNICIAN')
  @Patch('lab-bookings/:id/details')
  updateLabBookingDetails(
    @CurrentUser() user: RequestSubject,
    @Param('id', ParseIntPipe) id: number,
    @Body(new ZodValidationPipe(updateLabBookingDetailsSchema)) dto: UpdateLabBookingDetailsDto,
  ) {
    return this.bookings.updateLabBookingDetails(user.role!, user.storeId ?? null, id, dto);
  }

  @RequireRole('SUPERADMIN', 'ADMIN', 'LAB', 'LAB_TECHNICIAN')
  @Get('lab-staff')
  listLabStaff(@Query('storeCode') storeCode?: string) {
    return this.bookings.listLabStaff(storeCode);
  }

  @RequireRole('SUPERADMIN', 'ADMIN', 'LAB', 'LAB_TECHNICIAN')
  @Patch('lab-bookings/:id/staff')
  assignLabStaff(
    @CurrentUser() user: RequestSubject,
    @Param('id', ParseIntPipe) id: number,
    @Body(new ZodValidationPipe(assignLabStaffSchema)) dto: AssignLabStaffDto,
  ) {
    return this.bookings.assignLabStaff(user.role!, user.storeId ?? null, Number(user.subjectId), id, dto);
  }

  @RequireRole('SUPERADMIN', 'ADMIN', 'LAB', 'LAB_TECHNICIAN')
  @Get('lab-bookings/:id/report-pages')
  listLabReportPages(@CurrentUser() user: RequestSubject, @Param('id', ParseIntPipe) id: number) {
    return this.bookings.listLabReportPages(user.role!, user.storeId ?? null, id);
  }

  @RequireRole('SUPERADMIN', 'ADMIN', 'LAB', 'LAB_TECHNICIAN')
  @Post('lab-bookings/:id/report-pages')
  addLabReportPages(
    @CurrentUser() user: RequestSubject,
    @Param('id', ParseIntPipe) id: number,
    @Body(new ZodValidationPipe(addLabReportPagesSchema)) dto: AddLabReportPagesDto,
  ) {
    return this.bookings.addLabReportPages(user.role!, user.storeId ?? null, id, dto);
  }

  @RequireRole('SUPERADMIN', 'ADMIN', 'LAB', 'LAB_TECHNICIAN')
  @Delete('lab-bookings/:id/report-pages/:pageId')
  removeLabReportPage(
    @CurrentUser() user: RequestSubject,
    @Param('id', ParseIntPipe) id: number,
    @Param('pageId', ParseIntPipe) pageId: number,
  ) {
    return this.bookings.removeLabReportPage(user.role!, user.storeId ?? null, id, pageId);
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
