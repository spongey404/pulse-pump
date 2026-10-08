import { Firestore, Transaction, Timestamp, DocumentReference, DocumentSnapshot } from 'firebase-admin/firestore';

const EVENT_TTL_MS = 7 * 24 * 3600 * 1000;

/**
 * Idempotency for at-least-once delivery: call `eventSeen` first (a read, so before any write in the transaction), and
 * `markEvent` once the writes are issued. Enable a Firestore TTL policy on `_events.expireAt`.
 */
export async function eventSeen(db: Firestore, tx: Transaction, eventId: string): Promise<boolean> {
  return (await tx.get(db.collection('_events').doc(eventId))).exists;
}

export function markEvent(db: Firestore, tx: Transaction, eventId: string, nowMs: number): void {
  tx.set(db.collection('_events').doc(eventId), {
    createdAt: Timestamp.fromMillis(nowMs),
    expireAt: Timestamp.fromMillis(nowMs + EVENT_TTL_MS),
  });
}

/** Add `delta` to a numeric field of an existing doc, never going below zero. */
export function bump(tx: Transaction, snap: DocumentSnapshot, field: string, delta: number): void {
  if (!snap.exists || delta === 0) return;
  const cur = typeof snap.get(field) === 'number' ? (snap.get(field) as number) : 0;
  tx.update(snap.ref, { [field]: Math.max(0, cur + delta) });
}

export type Existence = 'created' | 'deleted' | 'updated' | 'none';

export function existence(before: boolean, after: boolean): Existence {
  if (!before && after) return 'created';
  if (before && !after) return 'deleted';
  if (before && after) return 'updated';
  return 'none';
}

/** Generic "parent.field += +1/-1 when a child doc is created/deleted". */
export async function adjustParentCounter(
  db: Firestore,
  eventId: string,
  parent: DocumentReference,
  field: string,
  change: Existence,
  nowMs: number,
): Promise<boolean> {
  if (change !== 'created' && change !== 'deleted') return false;
  return db.runTransaction(async (tx) => {
    if (await eventSeen(db, tx, eventId)) return false;
    const snap = await tx.get(parent);
    markEvent(db, tx, eventId, nowMs);
    bump(tx, snap, field, change === 'created' ? 1 : -1);
    return true;
  });
}
