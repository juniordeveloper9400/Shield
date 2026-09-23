import { parseVideoRange } from '../../src/modules/catalogue/review-video-range';

const cap = 2 * 1024 * 1024;

describe('parseVideoRange', () => {
  it('supports full, bounded, open-ended and suffix requests', () => {
    expect(parseVideoRange(undefined, 10, cap)).toEqual({ kind: 'full', start: 0, end: 9 });
    expect(parseVideoRange('bytes=2-5', 10, cap)).toEqual({ kind: 'partial', start: 2, end: 5 });
    expect(parseVideoRange('bytes=7-', 10, cap)).toEqual({ kind: 'partial', start: 7, end: 9 });
    expect(parseVideoRange('bytes=-3', 10, cap)).toEqual({ kind: 'partial', start: 7, end: 9 });
  });

  it('rejects invalid, multiple and unsatisfiable ranges', () => {
    for (const value of ['bytes=20-30', 'bytes=1-2,4-5', 'items=0-1', 'bytes=-0']) {
      expect(parseVideoRange(value, 10, cap)).toEqual({ kind: 'unsatisfiable' });
    }
  });

  it('caps one response slice without changing its starting byte', () => {
    expect(parseVideoRange('bytes=5-9999999', 10_000_000, cap)).toEqual({
      kind: 'partial', start: 5, end: 5 + cap - 1,
    });
  });
});
