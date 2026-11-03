// Pure challenge scoring. No Firebase imports: everything works on plain numbers (epoch ms, kg, seconds).

export type Metric =
  | 'totalVolume'
  | 'heaviestLift'
  | 'mostReps'
  | 'longestHold'
  | 'sessionsLogged'
  | 'custom';

export interface ScoredSet {
  weightKg?: number | null;
  reps?: number | null;
  durationSec?: number | null;
  setType?: string | null;
}

export interface ScoredExercise {
  exerciseName?: string | null;
  sets?: ScoredSet[] | null;
}

export interface ScoredWorkout {
  /** workout date, epoch ms (UTC) */
  dateMs: number;
  durationSec?: number | null;
  /** true when the workout carries `deletedAt` */
  deleted?: boolean;
  exercises?: ScoredExercise[] | null;
}

export interface ChallengeWindow {
  metric: Metric;
  /** Required for heaviestLift; optional filter for the other per-exercise metrics. */
  exerciseName?: string | null;
  startMs: number;
  endMs: number;
}

/** Minimum duration for a session to count towards `sessionsLogged`. */
export const MIN_SESSION_SECONDS = 600;

const num = (v: unknown): number => (typeof v === 'number' && Number.isFinite(v) ? v : 0);
const norm = (s: string | null | undefined): string => (s ?? '').trim().toLowerCase();
const round2 = (n: number): number => Math.round(n * 100) / 100;

/** Warm-up sets never count towards any challenge metric. */
export function isWorkingSet(set: ScoredSet): boolean {
  return norm(set.setType) !== 'warmup';
}

/** Epley estimated one-rep max. One rep is the weight itself. */
export function epley(weightKg: number, reps: number): number {
  if (weightKg <= 0 || reps <= 0) return 0;
  return reps === 1 ? weightKg : weightKg * (1 + reps / 30);
}

/** start <= date <= end (both ends inclusive). */
export function inWindow(dateMs: number, w: Pick<ChallengeWindow, 'startMs' | 'endMs'>): boolean {
  return dateMs >= w.startMs && dateMs <= w.endMs;
}

/** Working sets of a workout, optionally restricted to one exercise (case/whitespace-insensitive name match). */
function workingSets(workout: ScoredWorkout, exerciseName?: string | null): ScoredSet[] {
  const wanted = norm(exerciseName);
  const out: ScoredSet[] = [];
  for (const ex of workout.exercises ?? []) {
    if (wanted && norm(ex.exerciseName) !== wanted) continue;
    for (const s of ex.sets ?? []) if (isWorkingSet(s)) out.push(s);
  }
  return out;
}

/** Workouts that count: not deleted and dated inside the window. */
export function eligibleWorkouts(workouts: ScoredWorkout[], w: ChallengeWindow): ScoredWorkout[] {
  return workouts.filter((x) => !x.deleted && inWindow(x.dateMs, w));
}

/**
 * Score for one user from ALL of their workouts (the caller may pass workouts outside the window; they are ignored).
 * `custom` is honour-system and always returns `null` (caller must not touch the entry).
 */
export function computeScore(workouts: ScoredWorkout[], w: ChallengeWindow): number | null {
  if (w.metric === 'custom') return null;
  const list = eligibleWorkouts(workouts, w);
  const name = norm(w.exerciseName) ? w.exerciseName : null;

  switch (w.metric) {
    case 'totalVolume': {
      let total = 0;
      for (const wk of list) for (const s of workingSets(wk, name)) total += num(s.weightKg) * num(s.reps);
      return round2(total);
    }
    case 'heaviestLift': {
      let best = 0;
      for (const wk of list) {
        for (const s of workingSets(wk, name)) best = Math.max(best, epley(num(s.weightKg), num(s.reps)));
      }
      return round2(best);
    }
    case 'mostReps': {
      let total = 0;
      for (const wk of list) for (const s of workingSets(wk, name)) total += num(s.reps);
      return total;
    }
    case 'longestHold': {
      let best = 0;
      for (const wk of list) for (const s of workingSets(wk, name)) best = Math.max(best, num(s.durationSec));
      return best;
    }
    case 'sessionsLogged':
      return list.filter((wk) => num(wk.durationSec) >= MIN_SESSION_SECONDS).length;
    default:
      return null;
  }
}
