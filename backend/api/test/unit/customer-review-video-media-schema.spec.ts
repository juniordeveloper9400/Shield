import { getTableColumns } from 'drizzle-orm';
import { customerReviewVideoMedia } from '../../src/db/schema/app-catalogue';

describe('customer review video media schema', () => {
  it('exposes the complete Neon video upload state', () => {
    expect(Object.keys(getTableColumns(customerReviewVideoMedia))).toEqual([
      'id',
      'contentType',
      'byteLength',
      'sha256',
      'data',
      'nextChunk',
      'uploadComplete',
      'createdAt',
      'completedAt',
    ]);
  });
});
