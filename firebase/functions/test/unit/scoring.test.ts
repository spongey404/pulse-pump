import { describe, expect, it } from 'vitest';
import { ChallengeWindow, ScoredWorkout, computeScore, epley, inWindow, isWorkingSet } from '../../src/scoring';

const DAY = 86_400_000;
const START = Date.UTC(2026, 9, 1);
const END = START + 28 * DAY;
const win = (metric: ChallengeWindow['metric'], exerciseName?: string): ChallengeWindow => ({
  metric, exerciseName, startMs: START, endMs: END,
});
const wk = (dayOffset: number, exercises: ScoredWorkout['exercises'], durationSec = 3600, extra: Partial<ScoredWorkout> = {}): ScoredWorkout => ({
  dateMs: START + dayOffset * DAY, durationSec, exercises, ...extra,
});
const bench = (sets: Array<[number, number, string?]>) => ({
  exerciseName: 'Bench Press',
  sets: sets.map(([weightKg, reps, setType]) => ({ weightKg, reps, setType: setType ?? 'standard' })),
});

describe('epley', () => {
  it('worked examples', () => {
    expect(epley(100, 1)).toBe(100); // one rep is the weight itself
    expect(epley(100, 5)).toBeCloseTo(116.6667, 3); // 100 * (1 + 5/30)
    expect(epley(80, 10)).toBeCloseTo(106.6667, 3);
    expect(epley(0, 10)).toBe(0);
    expect(epley(100, 0)).toBe(0);
  });
});

describe('isWorkingSet', () => {
  it('excludes warm-ups only', () => {
    expect(isWorkingSet({ setType: 'warmup' })).toBe(false);
    expect(isWorkingSet({ setType: 'WarmUp' })).toBe(false);
    expect(isWorkingSet({ setType: 'dropset' })).toBe(true);
    expect(isWorkingSet({})).toBe(true);
  });
});

describe('windows', () => {
  it('is inclusive on both ends', () => {
    expect(inWindow(START, win('totalVolume'))).toBe(true);
    expect(inWindow(END, win('totalVolume'))).toBe(true);
    expect(inWindow(START - 1, win('totalVolume'))).toBe(false);
    expect(inWindow(END + 1, win('totalVolume'))).toBe(false);
  });
  it('ignores workouts outside the window', () => {
    const w = [wk(-1, [bench([[100, 10]])]), wk(5, [bench([[100, 10]])]), wk(29, [bench([[100, 10]])])];
    expect(computeScore(w, win('totalVolume'))).toBe(1000);
  });
});

describe('totalVolume', () => {
  it('sums weight x reps over working sets, all exercises', () => {
    // bench 100x5 + 100x5 = 1000 ; squat 140x3 = 420 ; warm-up 60x10 excluded
    const w = [wk(1, [bench([[60, 10, 'warmup'], [100, 5], [100, 5]]), { exerciseName: 'Squat', sets: [{ weightKg: 140, reps: 3 }] }])];
    expect(computeScore(w, win('totalVolume'))).toBe(1420);
  });
  it('sums across workouts and skips deleted ones', () => {
    const w = [wk(1, [bench([[100, 5]])]), wk(2, [bench([[100, 5]])]), wk(3, [bench([[100, 5]])], 3600, { deleted: true })];
    expect(computeScore(w, win('totalVolume'))).toBe(1000);
  });
  it('treats missing numbers as zero (bodyweight/timed sets)', () => {
    const w = [wk(1, [{ exerciseName: 'Plank', sets: [{ durationSec: 60 }] }, bench([[100, 5]])])];
    expect(computeScore(w, win('totalVolume'))).toBe(500);
  });
  it('honours an exercise filter when the challenge names one', () => {
    const w = [wk(1, [bench([[100, 5]]), { exerciseName: 'Squat', sets: [{ weightKg: 100, reps: 5 }] }])];
    expect(computeScore(w, win('totalVolume', ' bench press '))).toBe(500);
  });
  it('is zero with no workouts', () => {
    expect(computeScore([], win('totalVolume'))).toBe(0);
  });
});

describe('heaviestLift', () => {
  it('picks the best Epley e1RM for the named exercise, not the heaviest weight', () => {
    // 100x1 -> 100 ; 90x8 -> 90*(1+8/30)=114 ; 110x2 -> 117.33 (best)
    const w = [wk(1, [bench([[100, 1], [90, 8]])]), wk(2, [bench([[110, 2]])])];
    expect(computeScore(w, win('heaviestLift', 'Bench Press'))).toBe(117.33);
  });
  it('one rep is the weight itself', () => {
    expect(computeScore([wk(1, [bench([[150, 1]])])], win('heaviestLift', 'bench press'))).toBe(150);
  });
  it('ignores warm-ups and other exercises', () => {
    const w = [wk(1, [bench([[200, 1, 'warmup'], [80, 5]]), { exerciseName: 'Deadlift', sets: [{ weightKg: 300, reps: 1 }] }])];
    expect(computeScore(w, win('heaviestLift', 'Bench Press'))).toBe(93.33);
  });
  it('is 0 when the exercise was never logged', () => {
    expect(computeScore([wk(1, [bench([[100, 5]])])], win('heaviestLift', 'Squat'))).toBe(0);
  });
  it('a deleted best session falls back to the next best (recompute from all workouts)', () => {
    const w = [wk(1, [bench([[100, 5]])]), wk(2, [bench([[140, 1]])], 3600, { deleted: true })];
    expect(computeScore(w, win('heaviestLift', 'Bench Press'))).toBe(116.67);
  });
});

describe('mostReps', () => {
  it('sums every working rep', () => {
    const w = [wk(1, [bench([[0, 15, 'warmup'], [60, 10], [60, 8]])]), wk(2, [bench([[60, 12]])])];
    expect(computeScore(w, win('mostReps'))).toBe(30);
  });
  it('filters by exercise when given', () => {
    const w = [wk(1, [bench([[60, 10]]), { exerciseName: 'Push Up', sets: [{ reps: 40 }] }])];
    expect(computeScore(w, win('mostReps', 'Push Up'))).toBe(40);
  });
});

describe('longestHold', () => {
  it('is the best single hold, not the total', () => {
    const plank = (s: number[]) => ({ exerciseName: 'Plank', sets: s.map((durationSec) => ({ durationSec })) });
    const w = [wk(1, [plank([45, 60])]), wk(2, [plank([75, 30])])];
    expect(computeScore(w, win('longestHold'))).toBe(75);
  });
  it('excludes warm-up holds and out-of-window holds', () => {
    const w = [
      wk(1, [{ exerciseName: 'Plank', sets: [{ durationSec: 300, setType: 'warmup' }, { durationSec: 50 }] }]),
      wk(40, [{ exerciseName: 'Plank', sets: [{ durationSec: 500 }] }]),
    ];
    expect(computeScore(w, win('longestHold'))).toBe(50);
  });
});

describe('sessionsLogged', () => {
  it('counts workouts of at least 10 minutes', () => {
    const w = [wk(1, [], 599), wk(2, [], 600), wk(3, [], 3000), wk(4, [], 3000, { deleted: true }), wk(40, [], 3000)];
    expect(computeScore(w, win('sessionsLogged'))).toBe(2);
  });
  it('missing duration does not count', () => {
    expect(computeScore([wk(1, [], null as unknown as number)], win('sessionsLogged'))).toBe(0);
  });
});

describe('custom', () => {
  it('is honour-system: never computed', () => {
    expect(computeScore([wk(1, [bench([[100, 5]])])], win('custom'))).toBeNull();
  });
});
