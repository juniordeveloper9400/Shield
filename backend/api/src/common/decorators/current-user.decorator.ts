import { createParamDecorator, ExecutionContext } from '@nestjs/common';
import type { RequestSubject } from '../../modules/auth/session.types';

/** Pulls the resolved identity that AuthGuard attached to the request. */
export const CurrentUser = createParamDecorator((_: unknown, ctx: ExecutionContext): RequestSubject => {
  const request = ctx.switchToHttp().getRequest();
  return request.user;
});
