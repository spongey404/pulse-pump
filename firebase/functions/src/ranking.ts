// Pure leaderboard ranking.

export interface BoardEntry {
  uid: string;
  score: number;
  /** epoch ms when the score last changed to its current value (earlier wins ties) */
  scoreAtMs: number;
  rank?: number | null;
  previousRank?: number | null;
}

export interface RankedEntry extends BoardEntry {
  rank: number;
  previousRank: number;
}

export type WinCondition = 'highest' | 'lowest';

/** Display order: better score first; equal scores ordered by earliest `scoreAt`, then uid for determinism. */
export function sortBoard<T extends BoardEntry>(entries: T[], win: WinCondition = 'highest'): T[] {
  const dir = win === 'lowest' ? 1 : -1;
  return [...entries].sort(
    (a, b) => dir * (a.score - b.score) || a.scoreAtMs - b.scoreAtMs || (a.uid < b.uid ? -1 : a.uid > b.uid ? 1 : 0),
  );
}

/**
 * Competition ranking ("1,1,3"): equal scores share a rank, the next distinct score takes its ordinal position.
 * `previousRank` becomes the old `rank` when the rank changed, is kept when it did not, and equals `rank` for new entries.
 * The result is in display order.
 */
export function rankEntries(entries: BoardEntry[], win: WinCondition = 'highest'): RankedEntry[] {
  const sorted = sortBoard(entries, win);
  const out: RankedEntry[] = [];
  sorted.forEach((e, i) => {
    const rank = i > 0 && sorted[i - 1].score === e.score ? out[i - 1].rank : i + 1;
    const hadRank = typeof e.rank === 'number' && e.rank > 0;
    let previousRank: number;
    if (!hadRank) previousRank = rank;
    else if (e.rank !== rank) previousRank = e.rank as number;
    else previousRank = typeof e.previousRank === 'number' && e.previousRank > 0 ? e.previousRank : rank;
    out.push({ ...e, rank, previousRank });
  });
  return out;
}

/** Entries whose rank fields differ from what is stored: only these need to be written. */
export function changedEntries(before: BoardEntry[], after: RankedEntry[]): RankedEntry[] {
  const old = new Map(before.map((e) => [e.uid, e]));
  return after.filter((e) => {
    const o = old.get(e.uid);
    return !o || o.rank !== e.rank || o.previousRank !== e.previousRank;
  });
}

/** Positive = moved up the board. */
export function rankMovement(e: { rank: number; previousRank: number }): number {
  return e.previousRank - e.rank;
}
