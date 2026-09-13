import { CanActivate, ExecutionContext, Injectable, UnauthorizedException } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { IS_PUBLIC_KEY } from '../decorators/public.decorator';
import { TokenService } from '../../modules/auth/token.service';
import { AuthService } from '../../modules/auth/auth.service';

/**
 * Resolves the caller's identity from a bearer access token and attaches it
 * as req.user. Also re-checks the backing session hasn't been revoked on
 * every request (not just at token-issue time) — see backend/docs/erd.md §4
 * "must be checked on every request", which supports "log out all devices"
 * actually taking effect immediately rather than after the access token
 * naturally expires.
 */
@Injectable()
export class AuthGuard implements CanActivate {
  constructor(
    private readonly reflector: Reflector,
    private readonly tokens: TokenService,
    private readonly authService: AuthService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const isPublic = this.reflector.getAllAndOverride<boolean>(IS_PUBLIC_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);
    if (isPublic) return true;

    const request = context.switchToHttp().getRequest();
    const authHeader: string | undefined = request.headers?.authorization;
    const token = authHeader?.startsWith('Bearer ') ? authHeader.slice('Bearer '.length) : undefined;

    if (!token) {
      throw new UnauthorizedException({ error: { code: 'UNAUTHORIZED', message: 'Missing bearer token' } });
    }

    let subject;
    try {
      subject = await this.tokens.verifyAccessToken(token);
    } catch {
      throw new UnauthorizedException({ error: { code: 'UNAUTHORIZED', message: 'Invalid or expired access token' } });
    }

    const active = await this.authService.isSessionActive(subject.sessionId);
    if (!active) {
      throw new UnauthorizedException({ error: { code: 'UNAUTHORIZED', message: 'Session has been revoked' } });
    }

    request.user = subject;
    return true;
  }
}
