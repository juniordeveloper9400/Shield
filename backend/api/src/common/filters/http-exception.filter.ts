import { ArgumentsHost, Catch, ExceptionFilter, HttpException, HttpStatus, Logger } from '@nestjs/common';
import * as Sentry from '@sentry/nestjs';
import type { Response } from 'express';

const CODE_BY_STATUS: Record<number, string> = {
  400: 'VALIDATION_ERROR',
  401: 'UNAUTHORIZED',
  403: 'FORBIDDEN',
  404: 'NOT_FOUND',
  409: 'CONFLICT',
  429: 'RATE_LIMITED',
};

/**
 * Single error envelope for every response — see backend/docs/api-spec.md
 * "Error envelope". Never leaks stack traces or raw driver errors to the
 * client; those go to the logger only.
 */
@Catch()
export class HttpExceptionFilter implements ExceptionFilter {
  private readonly logger = new Logger('ExceptionFilter');

  async catch(exception: unknown, host: ArgumentsHost) {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<Response>();

    if (exception instanceof HttpException) {
      const status = exception.getStatus();
      const body = exception.getResponse();
      const alreadyEnveloped = typeof body === 'object' && body !== null && 'error' in body;
      response.status(status).json(
        alreadyEnveloped
          ? body
          : {
              error: {
                code: CODE_BY_STATUS[status] ?? 'ERROR',
                message: typeof body === 'string' ? body : exception.message,
              },
            },
      );
      return;
    }

    this.logger.error('Unhandled exception', exception instanceof Error ? exception.stack : String(exception));
    // Only truly unexpected failures reach here — every expected 4xx (bad
    // input, auth, not-found) is an HttpException and returns above without
    // ever reaching Sentry, so a wrong password or a 404 never counts
    // against the project's event quota or gets paged on.
    Sentry.captureException(exception);
    // This service runs as a single Vercel serverless function (vercel.json):
    // the runtime is free to freeze the process the instant the response is
    // sent, which can happen before the SDK's own async HTTP call to
    // Sentry's ingest endpoint has actually gone out — silently dropping the
    // event with no error of its own. Awaiting flush() blocks the response
    // by at most 2s, only on this already-exceptional path, until the event
    // is confirmed sent (or the timeout gives up) — see docs/sentry.md.
    await Sentry.flush(2000);
    response.status(HttpStatus.INTERNAL_SERVER_ERROR).json({
      error: { code: 'INTERNAL', message: 'Something went wrong' },
    });
  }
}
