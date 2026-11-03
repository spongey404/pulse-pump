import { Firestore, Transaction } from 'firebase-admin/firestore';
import { eventSeen, markEvent, Existence } from './counters';

export interface FollowCounts {
  friendCount: number;
  fanCount: number;
}

/**
 * friend = mutual follow, fan = follower who is not followed back. Pure, so the rule is unit tested.
 * `followers` = uids following the user, `following` = uids the user follows.
 */
export function countFollows(followers: string[], following: string[]): FollowCounts {
  const out = new Set(following);
  const friends = followers.filter((f) => out.has(f)).length;
  return { friendCount: friends, fanCount: followers.length - friends };
}

async function countsFor(db: Firestore, tx: Transaction, uid: string): Promise<FollowCounts> {
  const [followers, following] = await Promise.all([
    tx.get(db.collection('follows').where('followeeUid', '==', uid).select('followerUid')),
    tx.get(db.collection('follows').where('followerUid', '==', uid).select('followeeUid')),
  ]);
  return countFollows(
    followers.docs.map((d) => d.get('followerUid') as string),
    following.docs.map((d) => d.get('followeeUid') as string),
  );
}

/**
 * Handles one follows/{a}_{b} write by recomputing both users' friendCount/fanCount from the edges that exist now,
 * instead of applying +1/-1 deltas. Deltas depend on whether the reverse edge existed when the event was processed,
 * which is wrong whenever edges change together (deleteAccount removes both directions at once). Recounting converges
 * to the right answer whatever order events arrive in. Transactional, so concurrent events retry on stale reads, and
 * idempotent per event id. Cost is O(followers + following) per write; revisit with aggregation counts at scale.
 */
export async function handleFollowWrite(
  db: Firestore,
  eventId: string,
  change: Existence,
  followerUid: string,
  followeeUid: string,
  nowMs: number,
): Promise<boolean> {
  if (change !== 'created' && change !== 'deleted') return false;
  if (!followerUid || !followeeUid || followerUid === followeeUid) return false;

  return db.runTransaction(async (tx) => {
    if (await eventSeen(db, tx, eventId)) return false;
    const uids = [followerUid, followeeUid];
    const profiles = await Promise.all(uids.map((u) => tx.get(db.doc(`profiles/${u}`))));
    const counts = await Promise.all(uids.map((u) => countsFor(db, tx, u)));
    markEvent(db, tx, eventId, nowMs);
    profiles.forEach((p, i) => {
      if (p.exists) tx.update(p.ref, { friendCount: counts[i].friendCount, fanCount: counts[i].fanCount });
    });
    return true;
  });
}
