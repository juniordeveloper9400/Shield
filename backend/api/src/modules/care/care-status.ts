import { ConflictException } from '@nestjs/common';

export type LabBookingStatus = 'REQUESTED' | 'CONFIRMED' | 'SAMPLE_COLLECTED' | 'REPORT_READY' | 'CANCELLED';
export type AppointmentStatus = 'REQUESTED' | 'CONFIRMED' | 'COMPLETED' | 'CANCELLED';

const LAB_BOOKING_TRANSITIONS: Record<LabBookingStatus, LabBookingStatus[]> = {
  REQUESTED: ['CONFIRMED', 'CANCELLED'],
  CONFIRMED: ['SAMPLE_COLLECTED', 'CANCELLED'],
  SAMPLE_COLLECTED: ['REPORT_READY', 'CANCELLED'],
  REPORT_READY: [],
  CANCELLED: [],
};

const APPOINTMENT_TRANSITIONS: Record<AppointmentStatus, AppointmentStatus[]> = {
  REQUESTED: ['CONFIRMED', 'CANCELLED'],
  CONFIRMED: ['COMPLETED', 'CANCELLED'],
  COMPLETED: [],
  CANCELLED: [],
};

/** Same enforcement pattern as commerce/order-status.ts and prescription-status.ts. */
export function assertLegalLabBookingTransition(from: LabBookingStatus, to: LabBookingStatus): void {
  if (from === to) return;
  if (!LAB_BOOKING_TRANSITIONS[from].includes(to)) {
    throw new ConflictException({ error: { code: 'CONFLICT', message: `Cannot move a lab booking from ${from} to ${to}` } });
  }
}

export function assertLegalAppointmentTransition(from: AppointmentStatus, to: AppointmentStatus): void {
  if (from === to) return;
  if (!APPOINTMENT_TRANSITIONS[from].includes(to)) {
    throw new ConflictException({ error: { code: 'CONFLICT', message: `Cannot move an appointment from ${from} to ${to}` } });
  }
}
