import type { ExecutionContext } from '@nestjs/common';
import type { Reflector } from '@nestjs/core';
import { RolesGuard } from '../../src/common/guards/roles.guard';

function contextWithUser(user: unknown): ExecutionContext {
  return {
    switchToHttp: () => ({ getRequest: () => ({ user }) }),
    getHandler: () => ({}) as never,
    getClass: () => ({}) as never,
  } as unknown as ExecutionContext;
}

function reflectorReturning(roles: string[] | undefined): Reflector {
  return { getAllAndOverride: () => roles } as unknown as Reflector;
}

describe('RolesGuard', () => {
  it('allows any authenticated caller when the route requires no specific role', () => {
    const guard = new RolesGuard(reflectorReturning(undefined));
    expect(guard.canActivate(contextWithUser({ subjectType: 'MEMBER' }))).toBe(true);
  });

  it('rejects a member session on a staff-only route — this is the server-side check shieldweb never had', () => {
    const guard = new RolesGuard(reflectorReturning(['SUPERADMIN']));
    expect(() => guard.canActivate(contextWithUser({ subjectType: 'MEMBER' }))).toThrow();
  });

  it('rejects staff whose role is not in the required set', () => {
    const guard = new RolesGuard(reflectorReturning(['SUPERADMIN']));
    expect(() => guard.canActivate(contextWithUser({ subjectType: 'STAFF', role: 'PHARMACY' }))).toThrow();
  });

  it('allows staff whose role is in the required set', () => {
    const guard = new RolesGuard(reflectorReturning(['SUPERADMIN', 'PHARMACY']));
    expect(guard.canActivate(contextWithUser({ subjectType: 'STAFF', role: 'PHARMACY' }))).toBe(true);
  });
});
