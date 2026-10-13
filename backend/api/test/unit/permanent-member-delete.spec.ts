import 'reflect-metadata';
import { Reflector } from '@nestjs/core';
import { ConflictException, ForbiddenException, type ExecutionContext } from '@nestjs/common';
import { RolesGuard } from '../../src/common/guards/roles.guard';
import { StaffController } from '../../src/modules/identity/staff.controller';
import { IdentityService } from '../../src/modules/identity/identity.service';
import type { Database } from '../../src/db/client';
import type { AuthService } from '../../src/modules/auth/auth.service';

describe('permanent deletion error handling', () => {
  it('reports a required shared link as a conflict rather than an internal error', async () => {
    const db = { execute: async () => { throw { code: '23503' }; } } as unknown as Database;
    const service = new IdentityService(db, {} as AuthService);
    await expect(service.permanentlyDeleteMember(1,'00000000-0000-0000-0000-000000000001')).rejects.toBeInstanceOf(ConflictException);
  });
});

describe('permanent member deletion authorization', () => {
  const guard = new RolesGuard(new Reflector());
  function context(subjectType: string, role?: string): ExecutionContext {
    return {
      getHandler: () => StaffController.prototype.permanentlyDeleteMember,
      getClass: () => StaffController,
      switchToHttp: () => ({ getRequest: () => ({ user: { subjectType, role } }) }),
    } as unknown as ExecutionContext;
  }
  it('allows Admin and Super Admin', () => {
    for (const role of ['ADMIN', 'SUPERADMIN']) expect(guard.canActivate(context('STAFF', role))).toBe(true);
  });
  it('rejects members and every branch/desk role', () => {
    expect(() => guard.canActivate(context('MEMBER'))).toThrow(ForbiddenException);
    for (const role of ['PHARMACY','DELIVERY','LAB','APPOINTMENTS','LAB_TECHNICIAN']) {
      expect(() => guard.canActivate(context('STAFF',role))).toThrow(ForbiddenException);
    }
  });
});
