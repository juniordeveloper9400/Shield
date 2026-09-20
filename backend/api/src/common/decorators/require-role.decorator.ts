import { SetMetadata, UseGuards } from '@nestjs/common';
import { RegisteredGuard } from '../guards/registered.guard';
import type { AdminRole, SubjectType } from '../../modules/auth/session.types';

export const ROLES_KEY = 'requiredRoles';
export const SUBJECT_TYPE_KEY = 'requiredSubjectType';

const ALL_STAFF_ROLES: AdminRole[] = ['SUPERADMIN', 'ADMIN', 'PHARMACY', 'LAB', 'APPOINTMENTS', 'DELIVERY'];

/** Restricts a route to one or more app.admin_role values (implies a STAFF subject). */
export const RequireRole = (...roles: AdminRole[]) => SetMetadata(ROLES_KEY, roles);

/**
 * Restricts a route to any authenticated staff session, regardless of role.
 * Required on every /staff/* route that isn't @Public() — a route with NO
 * role/subject requirement only proves "some valid session", not "this is
 * staff". app.users and app.admin_user have independent id sequences, so a
 * member and a staff account can share a numeric id; without this check a
 * member session can be resolved against the wrong table. Caught by
 * test/integration/auth-flow.e2e-spec.ts, not by inspection.
 */
export const RequireStaff = () => RequireRole(...ALL_STAFF_ROLES);

/** Restricts a route to a specific subject type, independent of staff role. */
export const RequireSubject = (...types: SubjectType[]) => SetMetadata(SUBJECT_TYPE_KEY, types);

/** Restricts a route to an authenticated member session — the MEMBER-side counterpart to RequireStaff. */
export const RequireMember = () => RequireSubject('MEMBER');

/**
 * Restricts a member route to members who have completed registration — see
 * `RegisteredGuard`. Answers 403 `REGISTRATION_REQUIRED` otherwise, which the
 * apps turn into the "register to continue" prompt.
 */
export const RequireRegistered = () => UseGuards(RegisteredGuard);
