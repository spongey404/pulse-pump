import { initializeApp, getApps } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';
import { setGlobalOptions } from 'firebase-functions/v2';
import { onDocumentWritten } from 'firebase-functions/v2/firestore';
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { deleteUserData } from './accountDeletion';
import {
  applyScore, closeEndedChallengesNow, handleWorkoutChange, parseChallenge, recomputeUserInChallenge, rerankChallenge,
} from './challenges';
import { adjustParentCounter, existence } from './counters';
import { handleFollowWrite } from './follows';

if (getApps().length === 0) initializeApp();
export const REGION = 'australia-southeast1';
setGlobalOptions({ region: REGION, maxInstances: 20 });

const db = () => getFirestore();

const dateMs = (v: unknown): number | null =>
  v && typeof (v as { toMillis?: unknown }).toMillis === 'function' ? (v as { toMillis(): number }).toMillis() : null;

/** users/{uid}/workouts/{id} -> rescore every active challenge the user is in whose window holds the workout. */
export const onWorkoutWritten = onDocumentWritten('users/{uid}/workouts/{workoutId}', async (event) => {
  const dates = [dateMs(event.data?.before.get('date')), dateMs(event.data?.after.get('date'))].filter(
    (d): d is number => d !== null,
  );
  if (dates.length === 0) return;
  await handleWorkoutChange(db(), event.params.uid, dates, Date.now());
});

/** follows/{follower}_{followee} -> profiles.friendCount / fanCount. */
export const onFollowWritten = onDocumentWritten('follows/{edgeId}', async (event) => {
  const before = event.data?.before;
  const after = event.data?.after;
  const change = existence(!!before?.exists, !!after?.exists);
  const src = change === 'deleted' ? before : after;
  const follower = src?.get('followerUid') as string | undefined;
  const followee = src?.get('followeeUid') as string | undefined;
  if (!follower || !followee) return;
  await handleFollowWrite(db(), event.id, change, follower, followee, after?.createTime?.toMillis() ?? null, Date.now());
});

export const onLikeWritten = onDocumentWritten('posts/{postId}/likes/{likerUid}', async (event) => {
  const change = existence(!!event.data?.before.exists, !!event.data?.after.exists);
  await adjustParentCounter(db(), event.id, db().doc(`posts/${event.params.postId}`), 'likeCount', change, Date.now());
});

export const onCommentWritten = onDocumentWritten('posts/{postId}/comments/{commentId}', async (event) => {
  const change = existence(!!event.data?.before.exists, !!event.data?.after.exists);
  await adjustParentCounter(db(), event.id, db().doc(`posts/${event.params.postId}`), 'commentCount', change, Date.now());
});

/**
 * challenges/{id}/members/{uid}: keeps memberCount, scores a new member immediately from their existing workouts in the
 * window, and removes the entry (and reranks) when somebody leaves.
 */
export const onMemberWritten = onDocumentWritten('challenges/{challengeId}/members/{memberUid}', async (event) => {
  const { challengeId, memberUid } = event.params;
  const change = existence(!!event.data?.before.exists, !!event.data?.after.exists);
  const ref = db().doc(`challenges/${challengeId}`);
  await adjustParentCounter(db(), event.id, ref, 'memberCount', change, Date.now());
  const info = parseChallenge(ref, (await ref.get()).data());
  if (!info) return;
  if (change === 'created' && info.status === 'active') {
    if (info.metric === 'custom') {
      // honour-system: nothing to compute, but the member still appears on the board with 0 until they enter a score
      await recomputeCustomPlaceholder(info.id, memberUid, event.data?.after.get('username'));
    } else {
      await recomputeUserInChallenge(db(), info, memberUid, Date.now(), event.data?.after.get('username'));
    }
  } else if (change === 'deleted') {
    await ref.collection('entries').doc(memberUid).delete();
    await rerankChallenge(db(), info);
  }
});

async function recomputeCustomPlaceholder(challengeId: string, uid: string, username: string | undefined): Promise<void> {
  const ref = db().doc(`challenges/${challengeId}`);
  const info = parseChallenge(ref, (await ref.get()).data());
  if (!info) return;
  const existing = await ref.collection('entries').doc(uid).get();
  if (existing.exists) return;
  await applyScore(db(), info, uid, username ?? '', 0, Date.now());
}

/** Callable: deletes all of the caller's data, then the Auth user. Idempotent; call again if it failed midway. */
export const deleteAccount = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Sign in to delete your account.');
  const report = await deleteUserData(db(), uid);
  try {
    await getAuth().deleteUser(uid);
  } catch (e) {
    if ((e as { code?: string }).code !== 'auth/user-not-found') throw new HttpsError('internal', 'Could not delete auth user.');
  }
  return { ok: true, report };
});

/** Callable for operators (requires the `admin` custom claim). Safe to call any time. */
export const closeEndedChallenges = onCall(async (request) => {
  if (request.auth?.token?.admin !== true) throw new HttpsError('permission-denied', 'Admins only.');
  return { closed: await closeEndedChallengesNow(db(), Date.now()) };
});

/** Daily at 03:00 Sydney time. */
export const closeEndedChallengesDaily = onSchedule(
  { schedule: 'every day 03:00', timeZone: 'Australia/Sydney' },
  async () => {
    await closeEndedChallengesNow(db(), Date.now());
  },
);
