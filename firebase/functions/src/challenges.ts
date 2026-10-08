import { Firestore, Timestamp, DocumentReference, DocumentData } from 'firebase-admin/firestore';
import { BoardEntry, RankedEntry, WinCondition, changedEntries, rankEntries } from './ranking';
import { ChallengeWindow, Metric, ScoredWorkout, computeScore, inWindow } from './scoring';

const MAX_TX_WRITES = 450;

export interface ChallengeInfo {
  id: string;
  ref: DocumentReference;
  metric: Metric;
  exerciseName: string | null;
  startMs: number;
  endMs: number;
  isGlobal: boolean;
  status: string;
  winCondition: WinCondition;
}

const toMs = (v: unknown): number | null => {
  if (v instanceof Timestamp) return v.toMillis();
  if (typeof v === 'number') return v;
  return null;
};

export function parseChallenge(ref: DocumentReference, data: DocumentData | undefined): ChallengeInfo | null {
  if (!data) return null;
  const startMs = toMs(data.startAt);
  const endMs = toMs(data.endAt);
  if (startMs === null || endMs === null) return null;
  return {
    id: ref.id,
    ref,
    metric: data.metric as Metric,
    exerciseName: typeof data.exerciseName === 'string' && data.exerciseName ? data.exerciseName : null,
    startMs,
    endMs,
    isGlobal: data.isGlobal === true,
    status: typeof data.status === 'string' ? data.status : 'active',
    winCondition: data.winCondition === 'lowest' ? 'lowest' : 'highest',
  };
}

export const windowOf = (c: ChallengeInfo): ChallengeWindow => ({
  metric: c.metric,
  exerciseName: c.exerciseName,
  startMs: c.startMs,
  endMs: c.endMs,
});

/** Challenges (active, scored metric) the user is a member of. */
export async function activeScoredMemberships(db: Firestore, uid: string): Promise<ChallengeInfo[]> {
  const members = await db.collectionGroup('members').where('uid', '==', uid).get();
  const refs = members.docs
    .map((d) => d.ref.parent.parent)
    .filter((r): r is DocumentReference => !!r && r.parent.id === 'challenges');
  if (refs.length === 0) return [];
  const snaps = await db.getAll(...refs);
  return snaps
    .map((s) => parseChallenge(s.ref, s.data()))
    .filter((c): c is ChallengeInfo => !!c && c.status === 'active' && c.metric !== 'custom');
}

/** All workouts of the user dated inside the challenge window (deleted ones flagged, not dropped). */
export async function loadWorkoutsInWindow(db: Firestore, uid: string, c: ChallengeInfo): Promise<ScoredWorkout[]> {
  const snap = await db
    .collection(`users/${uid}/workouts`)
    .where('date', '>=', Timestamp.fromMillis(c.startMs))
    .where('date', '<=', Timestamp.fromMillis(c.endMs))
    .get();
  return snap.docs.map((d) => {
    const w = d.data();
    return {
      dateMs: toMs(w.date) ?? 0,
      durationSec: typeof w.durationSec === 'number' ? w.durationSec : 0,
      deleted: w.deletedAt !== undefined && w.deletedAt !== null,
      exercises: Array.isArray(w.exercises) ? w.exercises : [],
    };
  });
}

/**
 * Write one user's score to the board and recompute ranks.
 * Small boards are updated atomically in a transaction; larger ones write the user's entry in the transaction
 * and the rank changes of the others through a BulkWriter afterwards.
 */
export async function applyScore(
  db: Firestore,
  c: ChallengeInfo,
  uid: string,
  username: string,
  score: number,
  nowMs: number,
): Promise<void> {
  const entriesCol = c.ref.collection('entries');
  const spill: RankedEntry[] = [];

  await db.runTransaction(async (tx) => {
    spill.length = 0;
    const profileSnap = c.isGlobal ? await tx.get(db.doc(`profiles/${uid}`)) : null;
    const snap = await tx.get(entriesCol.select('score', 'scoreAt', 'rank', 'previousRank'));

    const board: BoardEntry[] = snap.docs.map((d) => ({
      uid: d.id,
      score: typeof d.get('score') === 'number' ? d.get('score') : 0,
      scoreAtMs: toMs(d.get('scoreAt')) ?? 0,
      rank: d.get('rank') ?? null,
      previousRank: d.get('previousRank') ?? null,
    }));
    const mine = board.find((e) => e.uid === uid);
    const scoreChanged = !mine || mine.score !== score;
    const scoreAtMs = scoreChanged ? nowMs : (mine as BoardEntry).scoreAtMs;
    const next = mine ? board.map((e) => (e.uid === uid ? { ...e, score, scoreAtMs } : e)) : [...board, { uid, score, scoreAtMs }];

    const ranked = rankEntries(next, c.winCondition);
    const changes = changedEntries(board, ranked);
    const hidden = c.isGlobal && profileSnap?.get('globalLeaderboardVisible') === false;

    const myRanked = ranked.find((e) => e.uid === uid) as RankedEntry;
    if (!scoreChanged && changes.length === 0) return;

    tx.set(
      entriesCol.doc(uid),
      {
        uid,
        ...(hidden ? {} : { username }),
        hidden,
        score,
        scoreAt: Timestamp.fromMillis(scoreAtMs),
        rank: myRanked.rank,
        previousRank: myRanked.previousRank,
        updatedAt: Timestamp.fromMillis(nowMs),
      },
      { merge: false },
    );
    const others = changes.filter((e) => e.uid !== uid);
    others.forEach((e, i) => {
      if (i < MAX_TX_WRITES) tx.update(entriesCol.doc(e.uid), { rank: e.rank, previousRank: e.previousRank });
      else spill.push(e);
    });
  });

  if (spill.length) {
    const bw = db.bulkWriter();
    for (const e of spill) bw.update(entriesCol.doc(e.uid), { rank: e.rank, previousRank: e.previousRank });
    await bw.close();
  }
}

/** Recompute ranks only (e.g. after a member left). Entries are never created here. */
export async function rerankChallenge(db: Firestore, c: ChallengeInfo): Promise<void> {
  const snap = await c.ref.collection('entries').select('score', 'scoreAt', 'rank', 'previousRank').get();
  const board: BoardEntry[] = snap.docs.map((d) => ({
    uid: d.id,
    score: d.get('score') ?? 0,
    scoreAtMs: toMs(d.get('scoreAt')) ?? 0,
    rank: d.get('rank') ?? null,
    previousRank: d.get('previousRank') ?? null,
  }));
  const changes = changedEntries(board, rankEntries(board, c.winCondition));
  if (!changes.length) return;
  const bw = db.bulkWriter();
  for (const e of changes) bw.update(c.ref.collection('entries').doc(e.uid), { rank: e.rank, previousRank: e.previousRank });
  await bw.close();
}

/** Recompute one user's score in one challenge from all their workouts and publish it. */
export async function recomputeUserInChallenge(
  db: Firestore,
  c: ChallengeInfo,
  uid: string,
  nowMs: number,
  usernameHint?: string,
): Promise<void> {
  if (c.metric === 'custom') return;
  const workouts = await loadWorkoutsInWindow(db, uid, c);
  const score = computeScore(workouts, windowOf(c));
  if (score === null) return;
  let username = usernameHint;
  if (!username) {
    const m = await c.ref.collection('members').doc(uid).get();
    username = (m.get('username') as string | undefined) ?? '';
  }
  await applyScore(db, c, uid, username, score, nowMs);
}

/**
 * Entry point for the workout trigger. `affectedDatesMs` are the dates of the workout before and after the write:
 * a challenge is recomputed when either lies inside its window.
 */
export async function handleWorkoutChange(
  db: Firestore,
  uid: string,
  affectedDatesMs: number[],
  nowMs: number,
): Promise<string[]> {
  const challenges = await activeScoredMemberships(db, uid);
  const touched: string[] = [];
  for (const c of challenges) {
    if (!affectedDatesMs.some((d) => inWindow(d, c))) continue;
    await recomputeUserInChallenge(db, c, uid, nowMs);
    touched.push(c.id);
  }
  return touched;
}

/** Marks every active challenge whose endAt has passed as ended. Returns how many were closed. */
export async function closeEndedChallengesNow(db: Firestore, nowMs: number): Promise<number> {
  let closed = 0;
  for (;;) {
    const snap = await db
      .collection('challenges')
      .where('status', '==', 'active')
      .where('endAt', '<=', Timestamp.fromMillis(nowMs))
      .limit(400)
      .get();
    if (snap.empty) return closed;
    const batch = db.batch();
    for (const d of snap.docs) {
      batch.update(d.ref, { status: 'ended', endedAt: Timestamp.fromMillis(nowMs), updatedAt: Timestamp.fromMillis(nowMs) });
    }
    await batch.commit();
    closed += snap.size;
    if (snap.size < 400) return closed;
  }
}
