// Fills the LOCAL emulators (Auth 9099, Firestore 8085) with realistic social dev data.
// Refuses to run against anything that is not an emulator. See README.md.
import { initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore, Timestamp } from 'firebase-admin/firestore';

const PROJECT = process.env.GCLOUD_PROJECT || 'demo-pump';
process.env.FIRESTORE_EMULATOR_HOST ||= '127.0.0.1:8085';
process.env.FIREBASE_AUTH_EMULATOR_HOST ||= '127.0.0.1:9099';
if (!PROJECT.startsWith('demo-')) throw new Error(`Refusing to seed non-demo project "${PROJECT}"`);

initializeApp({ projectId: PROJECT });
const db = getFirestore();
const auth = getAuth();

const DAY = 86_400_000;
const NOW = Date.now();
const ts = (msAgo = 0) => Timestamp.fromMillis(NOW - msAgo);
const daysAgo = (d, hour = 18) => {
  const t = new Date(NOW - d * DAY);
  t.setHours(hour, 0, 0, 0);
  return Timestamp.fromMillis(t.getTime());
};

// --- people -------------------------------------------------------------------------------------------------------
const PEOPLE = [
  { n: 1, name: 'Frankie One', handle: 'frankie', vis: 'everyone', lb: true },
  { n: 2, name: 'Sam Two', handle: 'sam_lifts', vis: 'friends', lb: true },
  { n: 3, name: 'Tess Three', handle: 'tess.t', vis: 'everyone', lb: true },
  { n: 4, name: 'Ollie Four', handle: 'ollie4', vis: 'onlyMe', lb: true },
  { n: 5, name: 'Priya Five', handle: 'priya_5', vis: 'everyone', lb: false },
  { n: 6, name: 'Jay Six', handle: 'jay.six', vis: 'everyone', lb: true },
  { n: 7, name: 'Mika Seven', handle: 'mika7', vis: 'everyone', lb: true },
  { n: 8, name: 'Eddie Eight', handle: 'eddie8', vis: 'everyone', lb: true },
].map((p) => ({ ...p, uid: `seed-friend${p.n}`, email: `friend${p.n}@example.com` }));
const P = Object.fromEntries(PEOPLE.map((p) => [p.n, p]));

// follow edges follower -> followee. 1<->2, 1<->3, 2<->3 are friends; 4,5 are fans of 1; 1 is a fan of 6.
const EDGES = [
  [1, 2], [2, 1], [1, 3], [3, 1], [2, 3], [3, 2],
  [4, 1], [5, 1], [1, 6], [7, 6], [8, 3],
];
const BLOCKS = [[1, 8]]; // friend1 blocked friend8

async function reset() {
  const res = await fetch(`http://${process.env.FIRESTORE_EMULATOR_HOST}/emulator/v1/projects/${PROJECT}/databases/(default)/documents`, { method: 'DELETE' });
  if (!res.ok) throw new Error(`could not clear Firestore emulator: ${res.status}`);
  const all = await auth.listUsers(1000);
  if (all.users.length) await auth.deleteUsers(all.users.map((u) => u.uid));
}

// --- tiny scoring helpers (same rules as functions/src/scoring.ts) --------------------------------------------------
const working = (sets) => sets.filter((s) => s.setType !== 'warmup');
const volume = (ws) => ws.flatMap((w) => w.exercises).flatMap((e) => working(e.sets)).reduce((a, s) => a + s.weightKg * s.reps, 0);
const bestE1rm = (ws, name) =>
  Math.round(
    Math.max(0, ...ws.flatMap((w) => w.exercises).filter((e) => e.exerciseName === name)
      .flatMap((e) => working(e.sets)).map((s) => (s.reps === 1 ? s.weightKg : s.weightKg * (1 + s.reps / 30)))) * 100,
  ) / 100;

const set = (weightKg, reps, order, setType = 'standard') => ({ order, weightKg, reps, setType, side: 'both' });
function makeWorkouts(p) {
  const base = 60 + p.n * 5;
  return [1, 3, 5, 8, 10].map((d, i) => ({
    id: `${p.uid}-w${i + 1}`,
    date: daysAgo(d),
    durationSec: 2700 + i * 300,
    notes: '',
    calories: 280 + i * 20,
    isDeload: false,
    exercises: [
      {
        exerciseId: 'bench-press', exerciseName: 'Bench Press', order: 1, notes: '',
        sets: [set(base * 0.5, 10, 1, 'warmup'), set(base + i * 2.5, 8, 2), set(base + i * 2.5, 6, 3), set(base + 5 + i * 2.5, 4, 4)],
      },
      {
        exerciseId: 'back-squat', exerciseName: 'Back Squat', order: 2, notes: '',
        sets: [set(base * 1.3, 8, 1), set(base * 1.3, 8, 2)],
      },
    ],
    schemaVersion: 1,
    updatedAt: NOW - i * 1000,
  }));
}

async function main() {
  console.log(`Seeding emulators for project ${PROJECT} ...`);
  await reset();

  // auth + user + profile + username
  const workoutsBy = {};
  for (const p of PEOPLE) {
    await auth.createUser({ uid: p.uid, email: p.email, password: 'password', displayName: p.name, emailVerified: true });
    await db.doc(`usernames/${p.handle}`).set({ uid: p.uid, createdAt: ts(60 * DAY) });
    await db.doc(`users/${p.uid}`).set({
      name: p.name, username: p.handle, unit: 'kg', experienceLevel: 'intermediate', gender: 'other', age: 24 + p.n,
      heightCm: 170 + p.n, weightKg: 70 + p.n * 2, settings: {},
      privacy: { workoutPosts: 'friends', bodyMap: 'friends', globalLeaderboards: p.lb ? 'visible' : 'hidden', profile: p.vis },
      schemaVersion: 1, createdAt: ts(60 * DAY), updatedAt: NOW,
    });
    const ws = makeWorkouts(p);
    workoutsBy[p.n] = ws;
    for (const { id, ...w } of ws) await db.doc(`users/${p.uid}/workouts/${id}`).set(w);
    await db.doc(`users/${p.uid}/bodyweight/${new Date(NOW).toISOString().slice(0, 10).replaceAll('-', '')}`).set({ kg: 70 + p.n * 2, updatedAt: NOW });
  }

  // follows + counters (friendCount: mutual, fanCount: followers not followed back)
  const has = new Set(EDGES.map(([a, b]) => `${a}_${b}`));
  for (const [a, b] of EDGES) {
    await db.doc(`follows/${P[a].uid}_${P[b].uid}`).set({ followerUid: P[a].uid, followeeUid: P[b].uid, createdAt: ts((20 - a) * DAY) });
  }
  for (const [a, b] of BLOCKS) await db.doc(`users/${P[a].uid}/blocked/${P[b].uid}`).set({ createdAt: ts(DAY) });
  for (const p of PEOPLE) {
    const followers = EDGES.filter(([, b]) => b === p.n).map(([a]) => a);
    const friendCount = followers.filter((a) => has.has(`${p.n}_${a}`)).length;
    const fanCount = followers.length - friendCount;
    await db.doc(`profiles/${p.uid}`).set({
      displayName: p.name, username: p.handle, streak: p.n % 4 + 1, totalWorkouts: 20 + p.n * 7, friendCount, fanCount,
      profileVisibility: p.vis, globalLeaderboardVisible: p.lb, updatedAt: NOW, createdAt: ts(60 * DAY), schemaVersion: 1,
    });
  }

  // posts (+ bodymap extras, comments, likes)
  const mkPost = (n, id, audience, bodyMapAudience, name, daysBack, extra = {}) => ({
    id,
    data: {
      authorUid: P[n].uid, authorName: P[n].name, authorUsername: P[n].handle, date: daysAgo(daysBack), workoutName: name,
      audience, bodyMapAudience,
      stats: { sets: 14, volumeKg: 5200 + n * 100, durationSec: 3600, prCount: n % 2 },
      // Same shape the app writes (SocialWire.exerciseData): id, name, sets{weight,reps,duration,distance,setType}, deltas vs last time.
      exercises: [
        { id: 'bench-press', name: 'Bench Press', improvementScore: 5, weightDelta: 5, repsDelta: 0,
          sets: [[60, 8, 'warmup'], [80, 5, 'standard'], [95, 4, 'standard'], [105, 3, 'standard'], [95, 5, 'standard']].map(([weight, reps, setType]) => ({ weight, reps, duration: 0, distance: 0, setType })) },
        { id: 'overhead-press', name: 'Overhead Press', improvementScore: 3, weightDelta: 2, repsDelta: 0,
          sets: [[45, 8, 'standard'], [60, 5, 'standard'], [72.5, 4, 'standard'], [65, 6, 'standard']].map(([weight, reps, setType]) => ({ weight, reps, duration: 0, distance: 0, setType })) },
        { id: 'cable-fly', name: 'Cable Fly', improvementScore: 0, weightDelta: 0, repsDelta: 2,
          sets: [[14, 15, 'standard'], [18, 12, 'standard'], [18, 11, 'standard']].map(([weight, reps, setType]) => ({ weight, reps, duration: 0, distance: 0, setType })) },
        { id: 'lateral-raise', name: 'Lateral Raise', improvementScore: 0, weightDelta: 0, repsDelta: 0,
          sets: [[12, 12, 'standard'], [12, 11, 'standard'], [10, 14, 'standard']].map(([weight, reps, setType]) => ({ weight, reps, duration: 0, distance: 0, setType })) },
      ],
      likeCount: 0, commentCount: 0, createdAt: daysAgo(daysBack, 19), schemaVersion: 1, ...extra,
    },
  });
  const posts = [
    mkPost(1, 'seed-p1-everyone', 'everyone', 'friends', 'Push Day', 1, { caption: 'New bench PR attempt' }),
    mkPost(1, 'seed-p1-friends', 'friends', 'friends', 'Leg Day', 3),
    mkPost(1, 'seed-p1-onlyme', 'onlyMe', 'onlyMe', 'Private Session', 5),
    mkPost(2, 'seed-p2-friends', 'friends', 'friends', 'Pull Day', 2),
    mkPost(3, 'seed-p3-everyone', 'everyone', 'everyone', 'Full Body', 1, { caption: 'Open to all' }),
    mkPost(6, 'seed-p6-everyone', 'everyone', 'friends', 'Upper Body', 4),
    mkPost(7, 'seed-p7-everyone', 'everyone', 'onlyMe', 'Arms', 6),
  ];
  const comments = [
    ['seed-p1-everyone', 2, 'Strong session!'], ['seed-p1-everyone', 3, 'Beast mode'], ['seed-p1-everyone', 7, 'Nice one'],
    ['seed-p1-friends', 2, 'Legs for days'], ['seed-p3-everyone', 1, 'Love it'],
  ];
  const likes = [
    ['seed-p1-everyone', [2, 3, 6, 7]], ['seed-p1-friends', [2, 3]], ['seed-p3-everyone', [1, 2, 7]], ['seed-p6-everyone', [1]],
  ];
  const cCount = {};
  const lCount = {};
  for (const [pid, n, text] of comments) {
    cCount[pid] = (cCount[pid] ?? 0) + 1;
    await db.collection(`posts/${pid}/comments`).add({ authorUid: P[n].uid, authorName: P[n].name, authorUsername: P[n].handle, text, createdAt: ts(DAY / 2), schemaVersion: 1 });
  }
  for (const [pid, ns] of likes) {
    lCount[pid] = ns.length;
    for (const n of ns) await db.doc(`posts/${pid}/likes/${P[n].uid}`).set({ uid: P[n].uid, createdAt: ts(DAY / 3) });
  }
  for (const { id, data } of posts) {
    await db.doc(`posts/${id}`).set({ ...data, likeCount: lCount[id] ?? 0, commentCount: cCount[id] ?? 0 });
    await db.doc(`posts/${id}/extras/bodymap`).set({ muscleSets: { Chest: 9, Triceps: 6, Shoulders: 4, Quads: 8, Glutes: 4 }, schemaVersion: 1, updatedAt: NOW });
  }

  // challenges
  const board = async (cid, rows) => {
    // rows: [{n, score, hidden?}] -> ranked (ties share rank, earlier scoreAt first)
    const sorted = [...rows].sort((a, b) => b.score - a.score || a.at - b.at);
    let rank = 0;
    for (const [i, r] of sorted.entries()) {
      if (i === 0 || sorted[i - 1].score !== r.score) rank = i + 1;
      await db.doc(`challenges/${cid}/members/${P[r.n].uid}`).set({ uid: P[r.n].uid, username: P[r.n].handle, joinedAt: ts(8 * DAY), schemaVersion: 1 });
      await db.doc(`challenges/${cid}/entries/${P[r.n].uid}`).set({
        uid: P[r.n].uid, ...(r.hidden ? {} : { username: P[r.n].handle }), hidden: !!r.hidden, score: r.score, scoreAt: Timestamp.fromMillis(NOW - r.at),
        rank, previousRank: rank, updatedAt: ts(r.at),
      });
    }
    await db.doc(`challenges/${cid}`).update({ memberCount: rows.length });
  };
  const chBase = { schemaVersion: 1, status: 'active', memberCount: 0, createdAt: ts(8 * DAY) };
  await db.doc('challenges/seed-bench').set({
    ...chBase, creatorUid: P[1].uid, name: 'Bench Club', metric: 'heaviestLift', exerciseName: 'Bench Press', isGlobal: false, visibility: 'invite',
    startAt: ts(8 * DAY), endAt: Timestamp.fromMillis(NOW + 20 * DAY),
  });
  await board('seed-bench', [1, 2, 3].map((n, i) => ({ n, score: bestE1rm(workoutsBy[n].filter((w) => w.date.toMillis() >= NOW - 8 * DAY), 'Bench Press'), at: (i + 1) * 3600_000 })));
  await db.doc('challenges/seed-volume').set({
    ...chBase, creatorUid: P[3].uid, name: 'Volume Month', metric: 'totalVolume', isGlobal: false, visibility: 'friends',
    startAt: ts(8 * DAY), endAt: Timestamp.fromMillis(NOW + 22 * DAY),
  });
  await board('seed-volume', [1, 3].map((n, i) => ({ n, score: Math.round(volume(workoutsBy[n])), at: (i + 1) * 7200_000 })));
  await db.doc('challenges/seed-global').set({
    ...chBase, creatorUid: 'admin', name: 'Global Volume', metric: 'totalVolume', isGlobal: true, visibility: 'public',
    startAt: ts(8 * DAY), endAt: Timestamp.fromMillis(NOW + 20 * DAY),
  });
  await board('seed-global', [1, 3, 5, 7].map((n, i) => ({ n, score: Math.round(volume(workoutsBy[n])), at: (i + 1) * 5400_000, hidden: !P[n].lb })));
  // an ended challenge (so the "challenge ended" screen has something to show)
  await db.doc('challenges/seed-ended').set({
    ...chBase, status: 'ended', creatorUid: P[2].uid, name: 'Autumn Bench', metric: 'heaviestLift', exerciseName: 'Bench Press', isGlobal: false, visibility: 'invite',
    startAt: ts(30 * DAY), endAt: ts(2 * DAY),
  });
  await board('seed-ended', [{ n: 2, score: 112, at: 5 * DAY }, { n: 3, score: 104, at: 6 * DAY }, { n: 1, score: 98, at: 7 * DAY }]);
  // pending invite: friend1 invited friend4 to Bench Club (id = challengeId_toUid)
  await db.doc(`invites/seed-bench_${P[4].uid}`).set({
    challengeId: 'seed-bench', fromUid: P[1].uid, toUid: P[4].uid, status: 'pending', challengeName: 'Bench Club',
    fromUsername: P[1].handle, createdAt: ts(3600_000), schemaVersion: 1,
  });
  await db.doc('reports/seed-report').set({ reporterUid: P[2].uid, targetType: 'post', targetId: 'seed-p7-everyone', reason: 'spam', createdAt: ts(DAY) });

  console.log('Done. Sign in with friendN@example.com / password (N = 1..8).');
  for (const p of PEOPLE) console.log(`  ${p.email}  @${p.handle}  profile=${p.vis}`);
}

main().catch((e) => { console.error(e); process.exit(1); });
