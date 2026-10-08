import { Firestore, DocumentSnapshot } from 'firebase-admin/firestore';
import { bump, eventSeen, markEvent, Existence } from './counters';

export interface FollowDelta {
  /** profile uid -> field -> delta */
  [uid: string]: { friendCount?: number; fanCount?: number };
}

/**
 * Pure rule table. Edge A->B just `created` or `deleted`; `reverseEarlier` is whether B->A exists and was created
 * before A->B (so A->B is the edge that completes the friendship).
 *
 * friend = mutual follow, fan = follower who is not followed back.
 *   create A->B, B->A exists  : A,B friends +1; B was A's fan so A.fan -1
 *   create A->B, no B->A      : B.fan +1
 *   delete A->B, B->A exists  : A,B friends -1; B becomes A's fan so A.fan +1
 *   delete A->B, no B->A      : B.fan -1
 */
export function followDelta(a: string, b: string, change: 'created' | 'deleted', reverseExists: boolean): FollowDelta {
  if (change === 'created') {
    return reverseExists
      ? { [a]: { friendCount: 1, fanCount: -1 }, [b]: { friendCount: 1 } }
      : { [b]: { fanCount: 1 } };
  }
  return reverseExists
    ? { [a]: { friendCount: -1, fanCount: 1 }, [b]: { friendCount: -1 } }
    : { [b]: { fanCount: -1 } };
}

/**
 * Handles one follows/{a}_{b} write. Transactional, idempotent per event id, and race-aware: if A->B and B->A are
 * created at the same moment, only the later-created edge counts the pair as mutual.
 */
export async function handleFollowWrite(
  db: Firestore,
  eventId: string,
  change: Existence,
  followerUid: string,
  followeeUid: string,
  edgeCreateTimeMs: number | null,
  nowMs: number,
): Promise<boolean> {
  if (change !== 'created' && change !== 'deleted') return false;
  if (!followerUid || !followeeUid || followerUid === followeeUid) return false;

  return db.runTransaction(async (tx) => {
    if (await eventSeen(db, tx, eventId)) return false;

    const reverse = await tx.get(db.doc(`follows/${followeeUid}_${followerUid}`));
    const [followerProfile, followeeProfile] = await Promise.all([
      tx.get(db.doc(`profiles/${followerUid}`)),
      tx.get(db.doc(`profiles/${followeeUid}`)),
    ]);

    markEvent(db, tx, eventId, nowMs);
    let reverseExists = reverse.exists;
    if (change === 'created' && reverse.exists && edgeCreateTimeMs !== null) {
      const rt = reverse.createTime?.toMillis() ?? 0;
      const own = `${followerUid}_${followeeUid}`;
      const other = `${followeeUid}_${followerUid}`;
      // The earlier edge is processed as a plain "fan" edge; the later one completes the friendship.
      reverseExists = rt < edgeCreateTimeMs || (rt === edgeCreateTimeMs && other < own);
    }

    const delta = followDelta(followerUid, followeeUid, change, reverseExists);
    const snaps: Record<string, DocumentSnapshot> = { [followerUid]: followerProfile, [followeeUid]: followeeProfile };
    for (const [uid, d] of Object.entries(delta)) {
      if (d.friendCount) bump(tx, snaps[uid], 'friendCount', d.friendCount);
      if (d.fanCount) bump(tx, snaps[uid], 'fanCount', d.fanCount);
    }
    return true;
  });
}
