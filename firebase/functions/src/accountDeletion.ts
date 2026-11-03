import { Firestore, Query, DocumentReference } from 'firebase-admin/firestore';
import { parseChallenge, rerankChallenge } from './challenges';

async function deleteQuery(db: Firestore, q: Query, recursive = false): Promise<number> {
  let n = 0;
  for (;;) {
    const snap = await q.limit(300).get();
    if (snap.empty) return n;
    if (recursive) await Promise.all(snap.docs.map((d) => db.recursiveDelete(d.ref)));
    else {
      const bw = db.bulkWriter();
      snap.docs.forEach((d) => void bw.delete(d.ref));
      await bw.close();
    }
    n += snap.size;
  }
}

export interface DeletionReport {
  posts: number;
  comments: number;
  likes: number;
  follows: number;
  memberships: number;
  invites: number;
  usernames: number;
  challengesDeleted: number;
}

/**
 * Deletes every Firestore document belonging to `uid`. Safe to call repeatedly (idempotent) and to resume after a
 * failure: each step only removes what is still there. Order matters: edges and content first, profile and private
 * data last, so a retry still finds the pointers it needs.
 */
export async function deleteUserData(db: Firestore, uid: string): Promise<DeletionReport> {
  const report: DeletionReport = {
    posts: 0, comments: 0, likes: 0, follows: 0, memberships: 0, invites: 0, usernames: 0, challengesDeleted: 0,
  };

  // Challenge memberships and entries (rerank the boards they leave afterwards).
  const memberDocs = await db.collectionGroup('members').where('uid', '==', uid).get();
  const challengeRefs: DocumentReference[] = [];
  for (const m of memberDocs.docs) {
    const ch = m.ref.parent.parent;
    if (!ch || ch.parent.id !== 'challenges') continue;
    challengeRefs.push(ch);
    await ch.collection('entries').doc(uid).delete();
    await m.ref.delete();
    report.memberships++;
  }
  // Challenges they created: delete when nobody else is in them, otherwise keep (history for the other members).
  const created = await db.collection('challenges').where('creatorUid', '==', uid).get();
  for (const c of created.docs) {
    const others = await c.ref.collection('members').limit(1).get();
    if (others.empty && c.get('isGlobal') !== true) {
      await db.recursiveDelete(c.ref);
      report.challengesDeleted++;
    }
  }
  for (const ref of challengeRefs) {
    const snap = await ref.get();
    const info = snap.exists ? parseChallenge(ref, snap.data()) : null;
    if (info) await rerankChallenge(db, info);
  }

  // Invites in both directions.
  report.invites += await deleteQuery(db, db.collection('invites').where('fromUid', '==', uid));
  report.invites += await deleteQuery(db, db.collection('invites').where('toUid', '==', uid));

  // Comments and likes the user made on other people's posts.
  report.comments += await deleteQuery(db, db.collectionGroup('comments').where('authorUid', '==', uid));
  report.likes += await deleteQuery(db, db.collectionGroup('likes').where('uid', '==', uid));

  // Own posts with all subcollections.
  report.posts += await deleteQuery(db, db.collection('posts').where('authorUid', '==', uid), true);

  // Follow edges both ways (onFollowWritten fixes the other user's counters).
  report.follows += await deleteQuery(db, db.collection('follows').where('followerUid', '==', uid));
  report.follows += await deleteQuery(db, db.collection('follows').where('followeeUid', '==', uid));

  // Handles, public profile, then the private subtree.
  report.usernames += await deleteQuery(db, db.collection('usernames').where('uid', '==', uid));
  await db.doc(`profiles/${uid}`).delete();
  await db.recursiveDelete(db.doc(`users/${uid}`));
  return report;
}
