import { ArgumentsHost, Catch, ExceptionFilter, HttpException, HttpStatus, Logger } from '@nestjs/common';
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

  catch(exception: unknown, host: ArgumentsHost) {
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
    response.status(HttpStatus.INTERNAL_SERVER_ERROR).json({
      error: { code: 'INTERNAL', message: 'Something went wrong' },
    });
  }
}
