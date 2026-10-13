import { describe, expect, it } from 'vitest';
import { changedEntries, rankEntries, rankMovement, sortBoard } from '../../src/ranking';
import { existence } from '../../src/counters';

const e = (uid: string, score: number, scoreAtMs = 0, rank?: number, previousRank?: number) => ({
  uid, score, scoreAtMs, rank, previousRank,
});

describe('rankEntries', () => {
  it('orders by score descending and numbers 1..n', () => {
    const r = rankEntries([e('a', 10), e('b', 30), e('c', 20)]);
    expect(r.map((x) => [x.uid, x.rank])).toEqual([['b', 1], ['c', 2], ['a', 3]]);
  });
  it('ties share a rank, ordered by earliest scoreAt, next rank skips', () => {
    const r = rankEntries([e('late', 50, 2000), e('early', 50, 1000), e('top', 60, 5), e('low', 10, 1)]);
    expect(r.map((x) => [x.uid, x.rank])).toEqual([['top', 1], ['early', 2], ['late', 2], ['low', 4]]);
  });
  it('three-way tie at the top', () => {
    const r = rankEntries([e('a', 5, 3), e('b', 5, 1), e('c', 5, 2)]);
    expect(r.map((x) => x.uid)).toEqual(['b', 'c', 'a']);
    expect(r.every((x) => x.rank === 1)).toBe(true);
  });
  it('is deterministic when score and scoreAt tie (uid order)', () => {
    expect(sortBoard([e('b', 1, 1), e('a', 1, 1)]).map((x) => x.uid)).toEqual(['a', 'b']);
  });
  it('lowest-wins boards invert the order', () => {
    const r = rankEntries([e('a', 10), e('b', 30)], 'lowest');
    expect(r.map((x) => x.uid)).toEqual(['a', 'b']);
  });
  it('new entries get previousRank = rank', () => {
    const r = rankEntries([e('a', 1)]);
    expect(r[0]).toMatchObject({ rank: 1, previousRank: 1 });
  });
  it('rank movement: overtaken user drops, previousRank records old rank', () => {
    // before: a=1 (100), b=2 (90). b scores 120 and overtakes.
    const r = rankEntries([e('a', 100, 1, 1, 1), e('b', 120, 9, 2, 2)]);
    const a = r.find((x) => x.uid === 'a')!;
    const b = r.find((x) => x.uid === 'b')!;
    expect([b.rank, b.previousRank, rankMovement(b)]).toEqual([1, 2, 1]);
    expect([a.rank, a.previousRank, rankMovement(a)]).toEqual([2, 1, -1]);
  });
  it('unchanged rank keeps its older previousRank', () => {
    const r = rankEntries([e('a', 100, 1, 1, 3)]);
    expect(r[0]).toMatchObject({ rank: 1, previousRank: 3 });
  });
  it('user leaving moves everyone below up', () => {
    const r = rankEntries([e('b', 90, 1, 2, 2), e('c', 80, 1, 3, 3)]);
    expect(r.map((x) => [x.uid, x.rank, x.previousRank])).toEqual([['b', 1, 2], ['c', 2, 3]]);
  });
  it('handles 5000 entries quickly', () => {
    const many = Array.from({ length: 5000 }, (_, i) => e(`u${i}`, i % 100, i));
    const r = rankEntries(many);
    expect(r[0].rank).toBe(1);
    expect(r.length).toBe(5000);
  });
});

describe('changedEntries', () => {
  it('returns only entries whose rank fields differ', () => {
    const before = [e('a', 100, 1, 1, 1), e('b', 90, 1, 2, 2), e('c', 80, 1, 3, 3)];
    const after = rankEntries([e('a', 100, 1, 1, 1), e('b', 90, 1, 2, 2), e('c', 95, 5, 3, 3)]);
    expect(changedEntries(before, after).map((x) => x.uid).sort()).toEqual(['b', 'c']);
  });
  it('includes brand-new entries', () => {
    const after = rankEntries([e('a', 1)]);
    expect(changedEntries([], after)).toHaveLength(1);
  });
});

describe('existence', () => {
  it('classifies document writes', () => {
    expect(existence(false, true)).toBe('created');
    expect(existence(true, false)).toBe('deleted');
    expect(existence(true, true)).toBe('updated');
    expect(existence(false, false)).toBe('none');
  });
});
