export type VideoRange =
  | { kind: 'full'; start: number; end: number }
  | { kind: 'partial'; start: number; end: number }
  | { kind: 'unsatisfiable' };

export function parseVideoRange(
  header: string | undefined,
  totalLength: number,
  maxSliceBytes: number,
): VideoRange {
  if (!Number.isSafeInteger(totalLength) || totalLength <= 0 || maxSliceBytes <= 0) {
    return { kind: 'unsatisfiable' };
  }
  if (!header) return { kind: 'full', start: 0, end: totalLength - 1 };
  if (!header.startsWith('bytes=') || header.includes(',')) return { kind: 'unsatisfiable' };
  const match = /^bytes=(\d*)-(\d*)$/.exec(header.trim());
  if (!match || (!match[1] && !match[2])) return { kind: 'unsatisfiable' };

  let start: number;
  let end: number;
  if (!match[1]) {
    const suffix = Number(match[2]);
    if (!Number.isSafeInteger(suffix) || suffix <= 0) return { kind: 'unsatisfiable' };
    start = Math.max(totalLength - suffix, 0);
    end = totalLength - 1;
  } else {
    start = Number(match[1]);
    end = match[2] ? Number(match[2]) : totalLength - 1;
    if (!Number.isSafeInteger(start) || !Number.isSafeInteger(end) || start >= totalLength || end < start) {
      return { kind: 'unsatisfiable' };
    }
    end = Math.min(end, totalLength - 1);
  }
  end = Math.min(end, start + maxSliceBytes - 1);
  return { kind: 'partial', start, end };
}
