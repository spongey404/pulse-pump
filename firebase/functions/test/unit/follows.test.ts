import { describe, it, expect } from 'vitest';
import { countFollows } from '../../src/follows';

describe('countFollows', () => {
  it('counts nobody', () => expect(countFollows([], [])).toEqual({ friendCount: 0, fanCount: 0 }));
  it('a one-way follower is a fan', () => expect(countFollows(['b'], [])).toEqual({ friendCount: 0, fanCount: 1 }));
  it('following someone who does not follow back is neither', () =>
    expect(countFollows([], ['b'])).toEqual({ friendCount: 0, fanCount: 0 }));
  it('a mutual follow is a friend, not a fan', () => expect(countFollows(['b'], ['b'])).toEqual({ friendCount: 1, fanCount: 0 }));
  it('mixes friends and fans', () =>
    expect(countFollows(['b', 'c', 'd'], ['b', 'x'])).toEqual({ friendCount: 1, fanCount: 2 }));
  it('is order independent', () =>
    expect(countFollows(['d', 'c', 'b'], ['x', 'b'])).toEqual(countFollows(['b', 'c', 'd'], ['b', 'x'])));
});
