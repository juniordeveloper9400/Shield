import { BadRequestException, PipeTransform } from '@nestjs/common';
import { ZodType } from 'zod';

/**
 * Validates a request body/query/params against a Zod schema — single
 * source of truth for validation, reused for OpenAPI generation later
 * (backend/docs/tech-stack.md). No separate hand-maintained DTO decorators.
 */
export class ZodValidationPipe implements PipeTransform {
  constructor(private readonly schema: ZodType) {}

  transform(value: unknown) {
    const result = this.schema.safeParse(value);
    if (!result.success) {
      throw new BadRequestException({
        error: {
          code: 'VALIDATION_ERROR',
          message: 'Request failed validation',
          details: result.error.flatten(),
        },
      });
    }
    return result.data;
  }
}
