import { BadRequestException, createParamDecorator, ExecutionContext } from '@nestjs/common';

/** Reads and requires the Idempotency-Key header — see backend/docs/api-spec.md "Idempotency". */
export const IdempotencyKey = createParamDecorator((_: unknown, ctx: ExecutionContext): string => {
  const request = ctx.switchToHttp().getRequest();
  const key = request.headers['idempotency-key'];
  if (!key || typeof key !== 'string' || key.trim().length === 0) {
    throw new BadRequestException({
      error: { code: 'VALIDATION_ERROR', message: 'Idempotency-Key header is required for this request' },
    });
  }
  return key;
});
