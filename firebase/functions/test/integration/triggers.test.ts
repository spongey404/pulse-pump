// Runs against the Functions + Firestore + Auth emulators: `npm run test:integration`.
import { beforeAll, describe, expect, it } from 'vitest';
import { initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { Timestamp, getFirestore } from 'firebase-admin/firestore';
import { closeEndedChallengesNow } from '../../src/challenges';

const PROJECT = 'demo-pump';
const REGION = 'australia-southeast1';
const DAY = 86_400_000;

initializeApp({ projectId: PROJECT });
const db = getFirestore();

async function eventually<T>(fn: () => Promise<T | undefined | false>, what: string, timeoutMs = 30_000): Promise<T> {
  const t0 = Date.now();
  let last: unknown;
  while (Date.now() - t0 < timeoutMs) {
    try {
      const v = await fn();
      if (v) return v;
    } catch (e) {
      last = e;
    }
    await new Promise((r) => setTimeout(r, 300));
  }
  throw new Error(`timed out waiting for: ${what} ${last ?? ''}`);
}

const uid = (p: string) => `${p}${Math.random().toString(36).slice(2, 8)}`;
const workout = (daysAgo: number, sets: Array<[number, number, string?]>, durationSec = 3000, extra = {}) => ({
  date: Timestamp.fromMillis(Date.now() - daysAgo * DAY),
  durationSec,
  updatedAt: Date.now(),
  schemaVersion: 1,
  exercises: [{ exerciseName: 'Bench Press', sets: sets.map(([weightKg, reps, setType]) => ({ weightKg, reps, setType: setType ?? 'standard' })) }],
  ...extra,
});
const makeChallenge = async (id: string, extra: Record<string, unknown> = {}) =>
  db.doc(`challenges/${id}`).set({
    creatorUid: 'creator', name: id, metric: 'totalVolume', startAt: Timestamp.fromMillis(Date.now() - 10 * DAY),
    endAt: Timestamp.fromMillis(Date.now() + 10 * DAY), isGlobal: false, visibility: 'invite', status: 'active',
    memberCount: 0, schemaVersion: 1, ...extra,
  });
const join = (cid: string, u: string) =>
  db.doc(`challenges/${cid}/members/${u}`).set({ uid: u, username: u, joinedAt: Timestamp.now() });
const entry = async (cid: string, u: string) => (await db.doc(`challenges/${cid}/entries/${u}`).get()).data();

describe('onWorkoutWritten + onMemberWritten', () => {
  const cid = uid('ch');
  const a = uid('a');
  const b = uid('b');

  beforeAll(async () => {
    await makeChallenge(cid);
    await join(cid, a);
    await join(cid, b);
  });

  it('member join creates a zero entry and bumps memberCount', async () => {
    await eventually(async () => (await entry(cid, a)) && (await entry(cid, b)), 'initial entries');
    const ch = await eventually(async () => {
      const s = await db.doc(`challenges/${cid}`).get();
      return s.get('memberCount') === 2 ? s : undefined;
    }, 'memberCount 2');
    expect(ch.get('memberCount')).toBe(2);
  });

  it('scores workouts (warm-ups excluded), ranks, and moves ranks when overtaken', async () => {
    await db.doc(`users/${a}/workouts/w1`).set(workout(1, [[50, 10, 'warmup'], [100, 5]])); // 500
    await db.doc(`users/${b}/workouts/w1`).set(workout(2, [[100, 3]])); // 300
    await eventually(async () => (await entry(cid, a))?.score === 500 && (await entry(cid, b))?.score === 300, 'scores 500/300');
    const ea = (await entry(cid, a))!;
    const eb = (await entry(cid, b))!;
    expect([ea.rank, eb.rank]).toEqual([1, 2]);

    await db.doc(`users/${b}/workouts/w2`).set(workout(0, [[100, 10]])); // +1000 => 1300
    await eventually(async () => (await entry(cid, b))?.score === 1300 && (await entry(cid, a))?.rank === 2, 'b overtakes a');
    const a2 = (await entry(cid, a))!;
    const b2 = (await entry(cid, b))!;
    expect([b2.rank, b2.previousRank, a2.rank, a2.previousRank]).toEqual([1, 2, 2, 1]);
  });

  it('a soft-deleted workout is removed from the score', async () => {
    await db.doc(`users/${b}/workouts/w2`).update({ deletedAt: Date.now(), updatedAt: Date.now() });
    await eventually(async () => (await entry(cid, b))?.score === 300, 'b back to 300');
    expect((await entry(cid, a))!.rank).toBe(1);
  });

  it('workouts outside the window are ignored', async () => {
    await db.doc(`users/${a}/workouts/old`).set(workout(30, [[200, 10]]));
    await new Promise((r) => setTimeout(r, 2500));
    expect((await entry(cid, a))!.score).toBe(500);
  });

  it('joining later scores existing workouts in the window', async () => {
    const late = uid('late');
    await db.doc(`users/${late}/workouts/w`).set(workout(3, [[60, 10]]));
    await join(cid, late);
    await eventually(async () => (await entry(cid, late))?.score === 600, 'late join scored 600');
    expect((await entry(cid, late))!.rank).toBe(1);
  });

  it('leaving removes the entry and reranks', async () => {
    await db.doc(`challenges/${cid}/members/${a}`).delete();
    await eventually(async () => !(await db.doc(`challenges/${cid}/entries/${a}`).get()).exists, 'a entry removed');
    await eventually(async () => (await entry(cid, b))?.rank === 2, 'b reranked below late');
  });

  it('custom challenges are never scored from workouts', async () => {
    const c2 = uid('custom');
    const u = uid('u');
    await makeChallenge(c2, { metric: 'custom' });
    await join(c2, u);
    await eventually(async () => (await entry(c2, u))?.score === 0, 'placeholder entry');
    await db.doc(`users/${u}/workouts/w`).set(workout(1, [[100, 10]]));
    await new Promise((r) => setTimeout(r, 2500));
    expect((await entry(c2, u))!.score).toBe(0);
  });

  it('ended challenges are not rescored', async () => {
    const c3 = uid('ended');
    const u = uid('u');
    await makeChallenge(c3, { status: 'ended' });
    await db.doc(`challenges/${c3}/members/${u}`).set({ uid: u, username: u, joinedAt: Timestamp.now() });
    await db.doc(`users/${u}/workouts/w`).set(workout(1, [[100, 10]]));
    await new Promise((r) => setTimeout(r, 2500));
    expect(await entry(c3, u)).toBeUndefined();
  });

  it('global challenge hides username for users who opted out of leaderboards', async () => {
    const g = uid('glob');
    const u = uid('u');
    await makeChallenge(g, { isGlobal: true, visibility: 'public' });
    await db.doc(`profiles/${u}`).set({ displayName: 'x', username: 'xxx', globalLeaderboardVisible: false, profileVisibility: 'everyone' });
    await join(g, u);
    const e = await eventually(async () => entry(g, u), 'global entry');
    expect(e.hidden).toBe(true);
    expect(e.username).toBeUndefined();
  });
});

describe('onFollowWritten', () => {
  const a = uid('fa');
  const b = uid('fb');
  const prof = (id: string) => db.doc(`profiles/${id}`);
  const counts = async (id: string) => {
    const s = await prof(id).get();
    return [s.get('friendCount') ?? 0, s.get('fanCount') ?? 0];
  };
  beforeAll(async () => {
    for (const id of [a, b]) await prof(id).set({ displayName: id, username: id, friendCount: 0, fanCount: 0, profileVisibility: 'everyone', globalLeaderboardVisible: true });
  });

  it('follow -> fan, follow back -> friends, unfollow -> fan again, full unfollow -> zero', async () => {
    await db.doc(`follows/${a}_${b}`).set({ followerUid: a, followeeUid: b, createdAt: Timestamp.now() });
    await eventually(async () => (await counts(b)).join() === '0,1', 'b has 1 fan');

    await db.doc(`follows/${b}_${a}`).set({ followerUid: b, followeeUid: a, createdAt: Timestamp.now() });
    await eventually(async () => (await counts(a)).join() === '1,0' && (await counts(b)).join() === '1,0', 'friends');

    await db.doc(`follows/${a}_${b}`).delete(); // a unfollows b: b is now a fan of a
    await eventually(async () => (await counts(a)).join() === '0,1' && (await counts(b)).join() === '0,0', 'b is a fan of a');

    await db.doc(`follows/${b}_${a}`).delete();
    await eventually(async () => (await counts(a)).join() === '0,0', 'back to zero');
  });

  it('simultaneous mutual follow counts the friendship exactly once', async () => {
    const x = uid('sx');
    const y = uid('sy');
    for (const id of [x, y]) await prof(id).set({ displayName: id, username: id, friendCount: 0, fanCount: 0, profileVisibility: 'everyone', globalLeaderboardVisible: true });
    await Promise.all([
      db.doc(`follows/${x}_${y}`).set({ followerUid: x, followeeUid: y, createdAt: Timestamp.now() }),
      db.doc(`follows/${y}_${x}`).set({ followerUid: y, followeeUid: x, createdAt: Timestamp.now() }),
    ]);
    await eventually(async () => (await counts(x)).join() === '1,0' && (await counts(y)).join() === '1,0', 'one friendship', 20_000);
  });
});

describe('onLikeWritten / onCommentWritten', () => {
  const pid = uid('post');
  beforeAll(async () => {
    await db.doc(`posts/${pid}`).set({ authorUid: 'x', audience: 'everyone', likeCount: 0, commentCount: 0 });
  });
  const counter = async (f: string) => (await db.doc(`posts/${pid}`).get()).get(f);

  it('likes add and remove', async () => {
    await db.doc(`posts/${pid}/likes/u1`).set({ uid: 'u1', createdAt: Timestamp.now() });
    await db.doc(`posts/${pid}/likes/u2`).set({ uid: 'u2', createdAt: Timestamp.now() });
    await eventually(async () => (await counter('likeCount')) === 2, 'likeCount 2');
    await db.doc(`posts/${pid}/likes/u1`).delete();
    await eventually(async () => (await counter('likeCount')) === 1, 'likeCount 1');
  });

  it('comments add and remove', async () => {
    await db.doc(`posts/${pid}/comments/c1`).set({ authorUid: 'u1', text: 'a', createdAt: Timestamp.now() });
    await db.doc(`posts/${pid}/comments/c2`).set({ authorUid: 'u2', text: 'b', createdAt: Timestamp.now() });
    await eventually(async () => (await counter('commentCount')) === 2, 'commentCount 2');
    await db.doc(`posts/${pid}/comments/c1`).delete();
    await eventually(async () => (await counter('commentCount')) === 1, 'commentCount 1');
  });

  it('a counter on a deleted post does not resurrect it', async () => {
    const gone = uid('gone');
    await db.doc(`posts/${gone}/likes/u1`).set({ uid: 'u1' });
    await new Promise((r) => setTimeout(r, 2000));
    expect((await db.doc(`posts/${gone}`).get()).exists).toBe(false);
  });
});

describe('closeEndedChallenges', () => {
  it('marks only expired active challenges as ended', async () => {
    const old = uid('old');
    const live = uid('live');
    await makeChallenge(old, { startAt: Timestamp.fromMillis(Date.now() - 20 * DAY), endAt: Timestamp.fromMillis(Date.now() - DAY) });
    await makeChallenge(live);
    const n = await closeEndedChallengesNow(db, Date.now());
    expect(n).toBeGreaterThanOrEqual(1);
    expect((await db.doc(`challenges/${old}`).get()).get('status')).toBe('ended');
    expect((await db.doc(`challenges/${live}`).get()).get('status')).toBe('active');
    expect(await closeEndedChallengesNow(db, Date.now())).toBe(0); // idempotent
  });
});

describe('deleteAccount (callable)', () => {
  const call = async (token: string | null) => {
    const res = await fetch(`http://127.0.0.1:5001/${PROJECT}/${REGION}/deleteAccount`, {
      method: 'POST',
      headers: { 'content-type': 'application/json', ...(token ? { authorization: `Bearer ${token}` } : {}) },
      body: JSON.stringify({ data: {} }),
    });
    return { status: res.status, body: (await res.json()) as Record<string, any> };
  };
  const signUp = async (email: string) => {
    const res = await fetch(`http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ email, password: 'password', returnSecureToken: true }),
    });
    const j = (await res.json()) as { idToken: string; localId: string };
    return { token: j.idToken, uid: j.localId };
  };

  it('rejects unauthenticated callers', async () => {
    const r = await call(null);
    expect(r.status).toBe(401);
  });

  it('removes everything the user owns and the auth user, and is idempotent', async () => {
    const me = await signUp(`${uid('del')}@example.com`);
    const other = uid('other');
    const cid = uid('chdel');
    const u = me.uid;
    await db.doc(`users/${u}`).set({ name: 'me', schemaVersion: 1 });
    await db.doc(`users/${u}/workouts/w1`).set(workout(1, [[100, 5]]));
    await db.doc(`users/${u}/blocked/${other}`).set({ createdAt: Timestamp.now() });
    await db.doc(`profiles/${u}`).set({ displayName: 'me', username: 'mmm', friendCount: 0, fanCount: 0, profileVisibility: 'everyone', globalLeaderboardVisible: true });
    await db.doc(`profiles/${other}`).set({ displayName: 'o', username: 'ooo', friendCount: 0, fanCount: 0, profileVisibility: 'everyone', globalLeaderboardVisible: true });
    await db.doc(`usernames/mmm`).set({ uid: u, createdAt: Timestamp.now() });
    await db.doc(`posts/mine`).set({ authorUid: u, audience: 'everyone', likeCount: 0, commentCount: 0 });
    await db.doc(`posts/mine/comments/c`).set({ authorUid: other, text: 'x', createdAt: Timestamp.now() });
    await db.doc(`posts/mine/extras/bodymap`).set({ muscleSets: {}, schemaVersion: 1 });
    await db.doc(`posts/theirs`).set({ authorUid: other, audience: 'everyone', likeCount: 0, commentCount: 0 });
    await db.doc(`posts/theirs/comments/mine`).set({ authorUid: u, text: 'y', createdAt: Timestamp.now() });
    await db.doc(`posts/theirs/likes/${u}`).set({ uid: u, createdAt: Timestamp.now() });
    await db.doc(`follows/${u}_${other}`).set({ followerUid: u, followeeUid: other, createdAt: Timestamp.now() });
    await db.doc(`follows/${other}_${u}`).set({ followerUid: other, followeeUid: u, createdAt: Timestamp.now() });
    await db.doc(`invites/${cid}_${u}`).set({ challengeId: cid, fromUid: other, toUid: u, status: 'pending', createdAt: Timestamp.now() });
    await makeChallenge(cid, { creatorUid: other });
    await join(cid, u);
    await join(cid, other);
    await eventually(async () => (await entry(cid, u)) && (await entry(cid, other)), 'entries exist');

    const r1 = await call(me.token);
    expect(r1.status).toBe(200);
    expect(r1.body.result.ok).toBe(true);

    expect((await db.doc(`users/${u}`).get()).exists).toBe(false);
    expect((await db.collection(`users/${u}/workouts`).get()).size).toBe(0);
    expect((await db.collection(`users/${u}/blocked`).get()).size).toBe(0);
    expect((await db.doc(`profiles/${u}`).get()).exists).toBe(false);
    expect((await db.doc(`usernames/mmm`).get()).exists).toBe(false);
    expect((await db.doc(`posts/mine`).get()).exists).toBe(false);
    expect((await db.doc(`posts/mine/comments/c`).get()).exists).toBe(false);
    expect((await db.doc(`posts/mine/extras/bodymap`).get()).exists).toBe(false);
    expect((await db.doc(`posts/theirs`).get()).exists).toBe(true);
    expect((await db.doc(`posts/theirs/comments/mine`).get()).exists).toBe(false);
    expect((await db.doc(`posts/theirs/likes/${u}`).get()).exists).toBe(false);
    expect((await db.collection('follows').where('followerUid', '==', u).get()).size).toBe(0);
    expect((await db.collection('follows').where('followeeUid', '==', u).get()).size).toBe(0);
    expect((await db.doc(`invites/${cid}_${u}`).get()).exists).toBe(false);
    expect((await db.doc(`challenges/${cid}/members/${u}`).get()).exists).toBe(false);
    expect((await db.doc(`challenges/${cid}/entries/${u}`).get()).exists).toBe(false);
    expect((await db.doc(`challenges/${cid}/members/${other}`).get()).exists).toBe(true);
    await expect(getAuth().getUser(u)).rejects.toMatchObject({ code: 'auth/user-not-found' });

    // The other user's profile survives and the post counter drops after the deleted comment/like.
    expect((await db.doc(`profiles/${other}`).get()).exists).toBe(true);
    await eventually(async () => (await db.doc(`posts/theirs`).get()).get('commentCount') === 0, 'comment counter stays >= 0');

    // idempotent: running the data deletion again on the now-empty account is a no-op
    const { deleteUserData } = await import('../../src/accountDeletion');
    const again = await deleteUserData(db, u);
    expect(again.posts + again.comments + again.likes + again.follows + again.memberships).toBe(0);
  });
});
