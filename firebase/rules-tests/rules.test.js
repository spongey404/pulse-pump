import { describe, it, before, after, beforeEach } from 'node:test';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} from '@firebase/rules-unit-testing';
import {
  setLogLevel,
  doc, getDoc, setDoc, updateDoc, deleteDoc, getDocs, collection, query, where, Timestamp, increment, writeBatch,
} from 'firebase/firestore';

setLogLevel('silent');
const here = dirname(fileURLToPath(import.meta.url));
const rules = readFileSync(join(here, '..', 'firestore.rules'), 'utf8');
const [host, port] = (process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8085').split(':');

let env;
before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-pump',
    firestore: { rules, host, port: Number(port) },
  });
});
after(async () => { await env.cleanup(); });

const ts = () => Timestamp.now();
const future = () => Timestamp.fromMillis(Date.now() + 7 * 864e5);
const past = () => Timestamp.fromMillis(Date.now() - 7 * 864e5);
const db = (uid) => (uid ? env.authenticatedContext(uid).firestore() : env.unauthenticatedContext().firestore());

const U = { alice: 'alice', bob: 'bob', carol: 'carol', dave: 'dave', eve: 'eve' };
// alice <-> bob friends; carol -> alice (fan); dave stranger; alice <-> eve mutual but eve is blocked by alice.

const follow = (a, b) => ({ followerUid: a, followeeUid: b, createdAt: ts() });
const profile = (extra = {}) => ({
  displayName: 'Alice', username: 'alice', streak: 3, totalWorkouts: 10, friendCount: 0, fanCount: 0,
  profileVisibility: 'everyone', globalLeaderboardVisible: true, updatedAt: Date.now(), ...extra,
});
const post = (audience = 'everyone', extra = {}) => ({
  authorUid: 'alice', authorName: 'Alice', authorUsername: 'alice', date: ts(), workoutName: 'Push',
  audience, bodyMapAudience: 'friends',
  stats: { sets: 10, volumeKg: 5000, durationSec: 3600, prCount: 1 },
  exercises: [{ name: 'Bench', sets: [] }], likeCount: 0, commentCount: 0, createdAt: ts(), schemaVersion: 1, ...extra,
});
const challenge = (extra = {}) => ({
  creatorUid: 'alice', name: 'Bench 100', metric: 'totalVolume', startAt: past(), endAt: future(),
  isGlobal: false, visibility: 'invite', status: 'active', memberCount: 0, schemaVersion: 1, ...extra,
});

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const d = ctx.firestore();
    const w = (p, data) => setDoc(doc(d, p), data);
    await w('users/alice', { name: 'Alice', schemaVersion: 1 });
    await w('profiles/alice', profile());
    await w('profiles/pFriends', profile({ username: 'pfriends', profileVisibility: 'friends' }));
    await w('profiles/pOnly', profile({ username: 'ponly', profileVisibility: 'onlyMe' }));
    // follows
    for (const [a, b] of [['alice', 'bob'], ['bob', 'alice'], ['carol', 'alice'], ['alice', 'eve'], ['eve', 'alice']]) {
      await w(`follows/${a}_${b}`, follow(a, b));
    }
    await w('users/alice/blocked/eve', { createdAt: ts() });
    // profiles by alice with friends / onlyMe visibility: use alice's own uid for those cases
    await w('profiles/alice2', profile());
    // posts
    await w('posts/pe', post('everyone'));
    await w('posts/pf', post('friends'));
    await w('posts/po', post('onlyMe'));
    await w('posts/pbm', post('everyone', { bodyMapAudience: 'friends' }));
    await w('posts/pf/extras/bodymap', { muscleSets: { chest: 4 }, schemaVersion: 1 });
    await w('posts/pbm/extras/bodymap', { muscleSets: { chest: 4 }, schemaVersion: 1 });
    await w('posts/pe/extras/bodymap', { muscleSets: { chest: 4 }, schemaVersion: 1 });
    await w('posts/pbmo/extras/bodymap', { muscleSets: {}, schemaVersion: 1 });
    await w('posts/pbmo', post('everyone', { bodyMapAudience: 'onlyMe' }));
    await w('posts/pbmo/extras/bodymap', { muscleSets: { chest: 4 }, schemaVersion: 1 });
    await w('posts/pe/comments/c1', { authorUid: 'dave', text: 'nice', createdAt: ts() });
    await w('posts/pe/likes/dave', { uid: 'dave', createdAt: ts() });
    // challenges
    await w('challenges/ch1', challenge());
    await w('challenges/ch1/members/alice', { uid: 'alice', username: 'alice', joinedAt: ts() });
    await w('challenges/ch1/members/bob', { uid: 'bob', username: 'bob', joinedAt: ts() });
    await w('challenges/ch1/entries/bob', { score: 5, rank: 1, previousRank: 1, updatedAt: ts() });
    await w('challenges/ch1/entries/alice', { score: 3, rank: 2, previousRank: 2, updatedAt: ts() });
    await w('invites/ch1_carol', { challengeId: 'ch1', fromUid: 'alice', toUid: 'carol', status: 'pending', createdAt: ts() });
    await w('challenges/glob', challenge({ creatorUid: 'admin', isGlobal: true, visibility: 'public' }));
    await w('challenges/glob/entries/bob', { score: 9, rank: 1, previousRank: 1, updatedAt: ts() });
    await w('challenges/glob/entries/hid', { score: 8, rank: 2, previousRank: 2, hidden: true, updatedAt: ts() });
    await w('challenges/ended', challenge({ endAt: past(), startAt: past() }));
    await w('usernames/taken', { uid: 'bob', createdAt: ts() });
  });
});

const ok = (p) => assertSucceeds(p);
const no = (p) => assertFails(p);

describe('private users/{uid} subtree', () => {
  const colls = {
    workouts: { date: ts(), updatedAt: 1, exercises: [], schemaVersion: 1 },
    templates: { name: 't', updatedAt: 1, exercises: [], schemaVersion: 1 },
    splits: { name: 's', updatedAt: 1, days: [], schemaVersion: 1 },
    equipmentProfiles: { name: 'e', updatedAt: 1, schemaVersion: 1 },
    customExercises: { name: 'x', updatedAt: 1, schemaVersion: 1 },
  };
  for (const [c, data] of Object.entries(colls)) {
    it(`${c}: owner can write and read`, async () => {
      await ok(setDoc(doc(db('alice'), `users/alice/${c}/a`), data));
      await ok(getDoc(doc(db('alice'), `users/alice/${c}/a`)));
    });
    it(`${c}: stranger (even a friend) cannot read or write`, async () => {
      await env.withSecurityRulesDisabled((ctx) => setDoc(doc(ctx.firestore(), `users/alice/${c}/a`), data));
      await no(getDoc(doc(db('bob'), `users/alice/${c}/a`)));
      await no(setDoc(doc(db('bob'), `users/alice/${c}/b`), data));
      await no(deleteDoc(doc(db('bob'), `users/alice/${c}/a`)));
    });
    it(`${c}: unauthenticated denied`, async () => {
      await no(getDoc(doc(db(null), `users/alice/${c}/a`)));
    });
    it(`${c}: rejects missing schemaVersion`, async () => {
      const { schemaVersion, ...bad } = data;
      await no(setDoc(doc(db('alice'), `users/alice/${c}/a`), bad));
    });
  }
  it('user doc: owner ok, stranger denied', async () => {
    await ok(setDoc(doc(db('alice'), 'users/alice'), { name: 'A', username: 'alice', schemaVersion: 1, privacy: { profile: 'everyone' } }));
    await no(getDoc(doc(db('bob'), 'users/alice')));
    await no(setDoc(doc(db('bob'), 'users/alice'), { name: 'X', schemaVersion: 1 }));
  });
  it('user doc: schemaVersion must be int', async () => {
    await no(setDoc(doc(db('alice'), 'users/alice'), { name: 'A', schemaVersion: '1' }));
  });
  it('user doc: progression map is capped and typed', async () => {
    const rows = (n) => Array.from({ length: n }, (_, i) => ({ name: `lift ${i}`, reps: 8 }));
    const base = { name: 'A', username: 'alice', schemaVersion: 1 };
    await ok(setDoc(doc(db('alice'), 'users/alice'), { ...base, progression: { thresholds: rows(200), incrementKg: 2.5 } }));
    await no(setDoc(doc(db('alice'), 'users/alice'), { ...base, progression: { thresholds: rows(201), incrementKg: 2.5 } }));
    await no(setDoc(doc(db('alice'), 'users/alice'), { ...base, progression: { thresholds: rows(1), incrementKg: '2.5' } }));
    await no(setDoc(doc(db('alice'), 'users/alice'), { ...base, progression: 'x' }));
  });
  it('workout: oversized exercises list rejected', async () => {
    await no(setDoc(doc(db('alice'), 'users/alice/workouts/big'),
      { date: ts(), updatedAt: 1, schemaVersion: 1, exercises: new Array(101).fill({}) }));
  });
  it('workout: too many top-level keys rejected', async () => {
    const extra = Object.fromEntries(Array.from({ length: 40 }, (_, i) => [`k${i}`, i]));
    await no(setDoc(doc(db('alice'), 'users/alice/workouts/big'),
      { date: ts(), updatedAt: 1, schemaVersion: 1, exercises: [], ...extra }));
  });
  it('workout: notes over 5000 chars rejected', async () => {
    await no(setDoc(doc(db('alice'), 'users/alice/workouts/big'),
      { date: ts(), updatedAt: 1, schemaVersion: 1, exercises: [], notes: 'x'.repeat(5001) }));
  });
  it('bodyweight: id must be yyyyMMdd and kg sane', async () => {
    await ok(setDoc(doc(db('alice'), 'users/alice/bodyweight/20260101'), { kg: 80, updatedAt: 1 }));
    await no(setDoc(doc(db('alice'), 'users/alice/bodyweight/jan1'), { kg: 80, updatedAt: 1 }));
    await no(setDoc(doc(db('alice'), 'users/alice/bodyweight/20260102'), { kg: -3, updatedAt: 1 }));
  });
  it('blocked: owner manages, stranger cannot read list or block on behalf', async () => {
    await ok(setDoc(doc(db('alice'), 'users/alice/blocked/dave'), { createdAt: ts() }));
    await ok(getDoc(doc(db('alice'), 'users/alice/blocked/eve')));
    await no(getDoc(doc(db('eve'), 'users/alice/blocked/eve')));
    await no(setDoc(doc(db('dave'), 'users/alice/blocked/bob'), { createdAt: ts() }));
    await no(setDoc(doc(db('alice'), 'users/alice/blocked/alice'), { createdAt: ts() }));
  });
});

describe('profiles', () => {
  // visibility is a property of the profile doc; seed one per level owned by `alice` uid variants
  const seedLevel = async (level) => env.withSecurityRulesDisabled((ctx) =>
    setDoc(doc(ctx.firestore(), 'profiles/alice'), profile({ profileVisibility: level })));
  const matrix = {
    everyone: { alice: true, bob: true, carol: true, dave: true, eve: false },
    friends: { alice: true, bob: true, carol: false, dave: false, eve: false },
    onlyMe: { alice: true, bob: false, carol: false, dave: false, eve: false },
  };
  for (const [level, who] of Object.entries(matrix)) {
    for (const [uid, allowed] of Object.entries(who)) {
      const role = { alice: 'owner', bob: 'friend', carol: 'fan', dave: 'stranger', eve: 'blocked friend' }[uid];
      it(`visibility=${level}: ${role} ${allowed ? 'can' : 'cannot'} read`, async () => {
        await seedLevel(level);
        const p = getDoc(doc(db(uid), 'profiles/alice'));
        await (allowed ? ok(p) : no(p));
      });
    }
  }
  it('unauthenticated cannot read even public profile', async () => {
    await no(getDoc(doc(db(null), 'profiles/alice')));
  });
  // The handle and the profile that uses it are written together, as the app's createAccount does.
  const claim = (uid, handle, extra = {}) => {
    const d = db(uid), b = writeBatch(d);
    b.set(doc(d, `usernames/${handle}`), { uid, createdAt: ts() });
    b.set(doc(d, `profiles/${uid}`), profile({ username: handle, ...extra }));
    return b.commit();
  };
  it('owner creates profile with zero counters', async () => {
    await ok(claim('dave', 'dave'));
  });
  it('cannot create a profile whose username is not a handle they own', async () => {
    await no(setDoc(doc(db('dave'), 'profiles/dave'), profile({ username: 'dave' })));   // never claimed
    await no(setDoc(doc(db('dave'), 'profiles/dave'), profile({ username: 'taken' })));  // bob's handle
  });
  it('cannot point the username of an existing profile at someone else\'s handle', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'usernames/alice'), { uid: 'alice', createdAt: ts() });
      await setDoc(doc(ctx.firestore(), 'profiles/alice'), profile({ username: 'alice' }));
    });
    await no(updateDoc(doc(db('alice'), 'profiles/alice'), { username: 'taken' }));
    await ok(updateDoc(doc(db('alice'), 'profiles/alice'), { streak: 3 }));   // unchanged username isn't re-checked
  });
  it('can rename to a handle claimed in the same batch', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'usernames/alice'), { uid: 'alice', createdAt: ts() });
      await setDoc(doc(ctx.firestore(), 'profiles/alice'), profile({ username: 'alice' }));
    });
    const d = db('alice'), b = writeBatch(d);
    b.set(doc(d, 'usernames/alice_new'), { uid: 'alice', createdAt: ts() });
    b.delete(doc(d, 'usernames/alice'));
    b.update(doc(d, 'profiles/alice'), { username: 'alice_new' });
    await ok(b.commit());
  });
  it('cannot create someone else\'s profile', async () => {
    await no(setDoc(doc(db('dave'), 'profiles/zed'), profile({ username: 'zed' })));
  });
  it('cannot create profile with non-zero friendCount/fanCount', async () => {
    await no(setDoc(doc(db('dave'), 'profiles/dave'), profile({ username: 'dave', friendCount: 99 })));
    await no(setDoc(doc(db('dave'), 'profiles/dave'), profile({ username: 'dave', fanCount: 1 })));
  });
  it('owner cannot change friendCount/fanCount', async () => {
    await no(updateDoc(doc(db('alice'), 'profiles/alice'), { friendCount: 50 }));
    await no(updateDoc(doc(db('alice'), 'profiles/alice'), { fanCount: increment(1) }));
  });
  it('owner can update streak and visibility', async () => {
    await ok(updateDoc(doc(db('alice'), 'profiles/alice'), { streak: 4, profileVisibility: 'friends' }));
  });
  it('stranger cannot update another profile', async () => {
    await no(updateDoc(doc(db('dave'), 'profiles/alice'), { streak: 999 }));
  });
  it('invalid visibility value rejected', async () => {
    await no(updateDoc(doc(db('alice'), 'profiles/alice'), { profileVisibility: 'public' }));
  });
  it('bad username shape rejected on profile', async () => {
    await no(updateDoc(doc(db('alice'), 'profiles/alice'), { username: 'AB' }));
    await no(updateDoc(doc(db('alice'), 'profiles/alice'), { username: 'Has Space' }));
  });
  it('profile cannot be deleted by client', async () => {
    await no(deleteDoc(doc(db('alice'), 'profiles/alice')));
  });
  it('unknown profile field rejected', async () => {
    await no(updateDoc(doc(db('alice'), 'profiles/alice'), { isAdmin: true }));
  });
});

describe('usernames', () => {
  const claimWithProfile = (uid, handle) => {
    const d = db(uid), b = writeBatch(d);
    b.set(doc(d, `usernames/${handle}`), { uid, createdAt: ts() });
    b.set(doc(d, `profiles/${uid}`), profile({ username: handle }));
    return b.commit();
  };
  it('claims a free valid handle together with the profile that uses it', async () => {
    await ok(claimWithProfile('dave', 'dave_01'));
  });
  it('cannot claim a handle on its own (no hoarding)', async () => {
    await no(setDoc(doc(db('dave'), 'usernames/dave_01'), { uid: 'dave', createdAt: ts() }));
  });
  it('cannot overwrite a taken handle', async () => {
    await no(setDoc(doc(db('dave'), 'usernames/taken'), { uid: 'dave', createdAt: ts() }));
  });
  it('cannot claim handle for another uid', async () => {
    await no(setDoc(doc(db('dave'), 'usernames/mine'), { uid: 'bob', createdAt: ts() }));
  });
  it('rejects upper case, too short, too long, bad chars', async () => {
    for (const h of ['Dave', 'ab', 'a'.repeat(21), 'has space', 'dash-ed']) {
      await no(setDoc(doc(db('dave'), `usernames/${h}`), { uid: 'dave', createdAt: ts() }));
    }
  });
  it('accepts boundary lengths 3 and 20', async () => {
    await ok(claimWithProfile('dave', 'abc'));
    await ok(claimWithProfile('erin', 'a'.repeat(20)));
  });
  it('anyone can get a handle (sign-up checks availability before the account exists), nobody can list', async () => {
    await ok(getDoc(doc(db('dave'), 'usernames/taken')));
    await no(getDocs(collection(db('dave'), 'usernames')));
    await ok(getDoc(doc(db(null), 'usernames/taken')));
    await no(getDocs(collection(db(null), 'usernames')));
  });
  it('update denied, delete only by owner', async () => {
    await no(updateDoc(doc(db('bob'), 'usernames/taken'), { uid: 'dave' }));
    await no(deleteDoc(doc(db('dave'), 'usernames/taken')));
    await ok(deleteDoc(doc(db('bob'), 'usernames/taken')));
  });
});

describe('follows', () => {
  it('create own edge', async () => {
    await ok(setDoc(doc(db('dave'), 'follows/dave_alice'), follow('dave', 'alice')));
  });
  it('cannot forge someone else\'s edge', async () => {
    await no(setDoc(doc(db('dave'), 'follows/bob_dave'), follow('bob', 'dave')));
  });
  it('cannot follow self', async () => {
    await no(setDoc(doc(db('dave'), 'follows/dave_dave'), follow('dave', 'dave')));
  });
  it('doc id must equal follower_followee', async () => {
    await no(setDoc(doc(db('dave'), 'follows/whatever'), follow('dave', 'alice')));
    await no(setDoc(doc(db('dave'), 'follows/dave_bob'), follow('dave', 'alice')));
  });
  it('blocked user cannot follow the blocker', async () => {
    await env.withSecurityRulesDisabled((ctx) => deleteDoc(doc(ctx.firestore(), 'follows/eve_alice')));
    await no(setDoc(doc(db('eve'), 'follows/eve_alice'), follow('eve', 'alice')));
  });
  it('extra fields rejected', async () => {
    await no(setDoc(doc(db('dave'), 'follows/dave_alice'), { ...follow('dave', 'alice'), verified: true }));
  });
  it('only follower can delete the edge', async () => {
    await no(deleteDoc(doc(db('alice'), 'follows/carol_alice')));
    await no(deleteDoc(doc(db('dave'), 'follows/carol_alice')));
    await ok(deleteDoc(doc(db('carol'), 'follows/carol_alice')));
  });
  it('edge readable by both ends only', async () => {
    await ok(getDoc(doc(db('alice'), 'follows/carol_alice')));
    await ok(getDoc(doc(db('carol'), 'follows/carol_alice')));
    await no(getDoc(doc(db('dave'), 'follows/carol_alice')));
  });
  it('can query my followers, not someone else\'s', async () => {
    await ok(getDocs(query(collection(db('alice'), 'follows'), where('followeeUid', '==', 'alice'))));
    await no(getDocs(query(collection(db('dave'), 'follows'), where('followeeUid', '==', 'alice'))));
  });
  it('edges cannot be updated', async () => {
    await no(updateDoc(doc(db('carol'), 'follows/carol_alice'), { createdAt: ts() }));
  });
});

describe('posts: audience matrix', () => {
  const roles = { alice: 'author', bob: 'friend', carol: 'fan', dave: 'stranger', eve: 'blocked' };
  const matrix = {
    pe: { alice: 1, bob: 1, carol: 1, dave: 1, eve: 0 },
    pf: { alice: 1, bob: 1, carol: 0, dave: 0, eve: 0 },
    po: { alice: 1, bob: 0, carol: 0, dave: 0, eve: 0 },
  };
  for (const [id, who] of Object.entries(matrix)) {
    for (const [uid, allowed] of Object.entries(who)) {
      it(`audience ${id}: ${roles[uid]} ${allowed ? 'can' : 'cannot'} read`, async () => {
        const p = getDoc(doc(db(uid), `posts/${id}`));
        await (allowed ? ok(p) : no(p));
      });
    }
  }
  it('unauthenticated cannot read any post', async () => {
    await no(getDoc(doc(db(null), 'posts/pe')));
  });
  it('friend can list author\'s friends posts via pinned query', async () => {
    await ok(getDocs(query(collection(db('bob'), 'posts'), where('authorUid', '==', 'alice'), where('audience', 'in', ['friends', 'everyone']))));
  });
  it('fan cannot list friends-only posts', async () => {
    await no(getDocs(query(collection(db('carol'), 'posts'), where('authorUid', '==', 'alice'), where('audience', '==', 'friends'))));
  });
  it('author creates a valid post with zero counters', async () => {
    await ok(setDoc(doc(db('alice'), 'posts/new'), post('friends')));
  });
  it('cannot create a post as someone else', async () => {
    await no(setDoc(doc(db('dave'), 'posts/new'), post('friends')));
  });
  it('cannot create post with non-zero likeCount or commentCount', async () => {
    await no(setDoc(doc(db('alice'), 'posts/new'), post('friends', { likeCount: 1000 })));
    await no(setDoc(doc(db('alice'), 'posts/new'), post('friends', { commentCount: 5 })));
  });
  it('author cannot change counters on update', async () => {
    await no(updateDoc(doc(db('alice'), 'posts/pe'), { likeCount: 50 }));
    await no(updateDoc(doc(db('alice'), 'posts/pe'), { commentCount: increment(1) }));
  });
  it('author can change audience but not authorUid', async () => {
    await ok(updateDoc(doc(db('alice'), 'posts/pe'), { audience: 'onlyMe' }));
    await no(updateDoc(doc(db('alice'), 'posts/pe'), { authorUid: 'bob' }));
  });
  it('non-author cannot update or delete', async () => {
    await no(updateDoc(doc(db('bob'), 'posts/pe'), { workoutName: 'hacked' }));
    await no(deleteDoc(doc(db('bob'), 'posts/pe')));
    await ok(deleteDoc(doc(db('alice'), 'posts/pe')));
  });
  it('invalid audience / oversized caption / too many exercises rejected', async () => {
    await no(setDoc(doc(db('alice'), 'posts/x1'), post('public')));
    await no(setDoc(doc(db('alice'), 'posts/x2'), post('friends', { caption: 'c'.repeat(501) })));
    await no(setDoc(doc(db('alice'), 'posts/x3'), post('friends', { exercises: new Array(61).fill({}) })));
  });
  it('unknown post field rejected', async () => {
    await no(setDoc(doc(db('alice'), 'posts/x4'), post('friends', { pinned: true })));
  });
  it('schemaVersion must be int', async () => {
    await no(setDoc(doc(db('alice'), 'posts/x5'), post('friends', { schemaVersion: 'one' })));
  });
});

describe('posts/{id}/extras/bodymap', () => {
  it('author can read and write', async () => {
    await ok(getDoc(doc(db('alice'), 'posts/pbm/extras/bodymap')));
    await ok(setDoc(doc(db('alice'), 'posts/pbm/extras/bodymap'), { muscleSets: { back: 3 }, schemaVersion: 1 }));
  });
  it('bodyMapAudience=friends: friend yes, fan no, stranger no (post is public)', async () => {
    await ok(getDoc(doc(db('bob'), 'posts/pbm/extras/bodymap')));
    await no(getDoc(doc(db('carol'), 'posts/pbm/extras/bodymap')));
    await no(getDoc(doc(db('dave'), 'posts/pbm/extras/bodymap')));
  });
  it('bodyMapAudience=onlyMe: only author', async () => {
    await ok(getDoc(doc(db('alice'), 'posts/pbmo/extras/bodymap')));
    await no(getDoc(doc(db('bob'), 'posts/pbmo/extras/bodymap')));
  });
  it('bodymap of a friends-only post is hidden from a fan even if bodyMapAudience=everyone', async () => {
    await env.withSecurityRulesDisabled((ctx) => setDoc(doc(ctx.firestore(), 'posts/pf'), post('friends', { bodyMapAudience: 'everyone' })));
    await no(getDoc(doc(db('carol'), 'posts/pf/extras/bodymap')));
    await ok(getDoc(doc(db('bob'), 'posts/pf/extras/bodymap')));
  });
  it('blocked user cannot read bodymap', async () => {
    await env.withSecurityRulesDisabled((ctx) => setDoc(doc(ctx.firestore(), 'posts/pbm'), post('everyone', { bodyMapAudience: 'everyone' })));
    await no(getDoc(doc(db('eve'), 'posts/pbm/extras/bodymap')));
    await ok(getDoc(doc(db('dave'), 'posts/pbm/extras/bodymap')));
  });
  it('non-author cannot write bodymap; only the id "bodymap" allowed', async () => {
    await no(setDoc(doc(db('bob'), 'posts/pe/extras/bodymap'), { muscleSets: {}, schemaVersion: 1 }));
    await no(setDoc(doc(db('alice'), 'posts/pe/extras/other'), { muscleSets: {}, schemaVersion: 1 }));
  });
  it('bodymap shape validated', async () => {
    await no(setDoc(doc(db('alice'), 'posts/pe/extras/bodymap'), { muscleSets: 'chest', schemaVersion: 1 }));
    await no(setDoc(doc(db('alice'), 'posts/pe/extras/bodymap'), { muscleSets: {}, schemaVersion: 1, junk: 1 }));
  });
});

describe('comments and likes', () => {
  const c = (extra = {}) => ({ authorUid: 'bob', text: 'hi', createdAt: ts(), ...extra });
  it('reader of a public post can comment', async () => {
    await ok(setDoc(doc(db('dave'), 'posts/pe/comments/n1'), c({ authorUid: 'dave' })));
  });
  it('cannot comment as someone else', async () => {
    await no(setDoc(doc(db('dave'), 'posts/pe/comments/n1'), c()));
  });
  it('cannot comment on a post you cannot read', async () => {
    await no(setDoc(doc(db('carol'), 'posts/pf/comments/n1'), c({ authorUid: 'carol' })));
    await ok(setDoc(doc(db('bob'), 'posts/pf/comments/n1'), c()));
  });
  it('blocked user cannot comment', async () => {
    await no(setDoc(doc(db('eve'), 'posts/pe/comments/n1'), c({ authorUid: 'eve' })));
  });
  it('comment text limits: empty and 501 rejected, 500 accepted', async () => {
    await no(setDoc(doc(db('bob'), 'posts/pe/comments/n1'), c({ text: '' })));
    await no(setDoc(doc(db('bob'), 'posts/pe/comments/n2'), c({ text: 'x'.repeat(501) })));
    await ok(setDoc(doc(db('bob'), 'posts/pe/comments/n3'), c({ text: 'x'.repeat(500) })));
  });
  it('comment extra field rejected', async () => {
    await no(setDoc(doc(db('bob'), 'posts/pe/comments/n1'), c({ likes: 99 })));
  });
  it('comments readable by readers only', async () => {
    await ok(getDoc(doc(db('dave'), 'posts/pe/comments/c1')));
    await env.withSecurityRulesDisabled((ctx) => setDoc(doc(ctx.firestore(), 'posts/pf/comments/c1'), c()));
    await no(getDoc(doc(db('dave'), 'posts/pf/comments/c1')));
    await ok(getDoc(doc(db('bob'), 'posts/pf/comments/c1')));
  });
  it('comments cannot be edited; author or post author can delete', async () => {
    await no(updateDoc(doc(db('dave'), 'posts/pe/comments/c1'), { text: 'edited' }));
    await no(deleteDoc(doc(db('bob'), 'posts/pe/comments/c1')));
    await ok(deleteDoc(doc(db('dave'), 'posts/pe/comments/c1')));
  });
  it('post author can delete others\' comments', async () => {
    await ok(deleteDoc(doc(db('alice'), 'posts/pe/comments/c1')));
  });
  it('like own uid on readable post', async () => {
    await ok(setDoc(doc(db('bob'), 'posts/pe/likes/bob'), { uid: 'bob', createdAt: ts() }));
    await ok(setDoc(doc(db('bob'), 'posts/pf/likes/bob'), { uid: 'bob' }));
  });
  it('cannot like as another uid', async () => {
    await no(setDoc(doc(db('bob'), 'posts/pe/likes/dave'), { uid: 'dave', createdAt: ts() }));
  });
  it('cannot like unreadable post', async () => {
    await no(setDoc(doc(db('carol'), 'posts/pf/likes/carol'), { uid: 'carol' }));
    await no(setDoc(doc(db('bob'), 'posts/po/likes/bob'), { uid: 'bob' }));
  });
  it('like payload restricted', async () => {
    await no(setDoc(doc(db('bob'), 'posts/pe/likes/bob'), { uid: 'bob', createdAt: ts(), weight: 10 }));
  });
  it('like must carry uid equal to doc id', async () => {
    await no(setDoc(doc(db('bob'), 'posts/pe/likes/bob'), { createdAt: ts() }));
    await no(setDoc(doc(db('bob'), 'posts/pe/likes/bob'), { uid: 'dave', createdAt: ts() }));
  });
  it('unlike own only', async () => {
    await no(deleteDoc(doc(db('bob'), 'posts/pe/likes/dave')));
    await ok(deleteDoc(doc(db('dave'), 'posts/pe/likes/dave')));
  });
  it('likes readable by readers only', async () => {
    await ok(getDoc(doc(db('bob'), 'posts/pe/likes/dave')));
    await no(getDoc(doc(db('eve'), 'posts/pe/likes/dave')));
  });
});

describe('challenges', () => {
  it('member, creator and invitee can read private challenge; stranger cannot', async () => {
    await ok(getDoc(doc(db('bob'), 'challenges/ch1')));
    await ok(getDoc(doc(db('alice'), 'challenges/ch1')));
    await ok(getDoc(doc(db('carol'), 'challenges/ch1')));
    await no(getDoc(doc(db('dave'), 'challenges/ch1')));
  });
  it('global challenge readable by any signed-in user', async () => {
    await ok(getDoc(doc(db('dave'), 'challenges/glob')));
    await no(getDoc(doc(db(null), 'challenges/glob')));
  });
  it('client creates a valid private challenge', async () => {
    await ok(setDoc(doc(db('dave'), 'challenges/new'), challenge({ creatorUid: 'dave' })));
  });
  it('client cannot create a global challenge, ended status, or foreign creator', async () => {
    await no(setDoc(doc(db('dave'), 'challenges/n1'), challenge({ creatorUid: 'dave', isGlobal: true })));
    await no(setDoc(doc(db('dave'), 'challenges/n2'), challenge({ creatorUid: 'dave', status: 'ended' })));
    await no(setDoc(doc(db('dave'), 'challenges/n3'), challenge({ creatorUid: 'alice' })));
  });
  it('client cannot set memberCount', async () => {
    await no(setDoc(doc(db('dave'), 'challenges/n1'), challenge({ creatorUid: 'dave', memberCount: 500 })));
    await no(updateDoc(doc(db('alice'), 'challenges/ch1'), { memberCount: 500 }));
  });
  it('creator cannot flip status or metric', async () => {
    await no(updateDoc(doc(db('alice'), 'challenges/ch1'), { status: 'ended' }));
    await no(updateDoc(doc(db('alice'), 'challenges/ch1'), { metric: 'mostReps' }));
  });
  it('creator can rename; others cannot', async () => {
    await ok(updateDoc(doc(db('alice'), 'challenges/ch1'), { name: 'Renamed' }));
    await no(updateDoc(doc(db('bob'), 'challenges/ch1'), { name: 'Hijack' }));
  });
  it('invalid metric / window rejected', async () => {
    await no(setDoc(doc(db('dave'), 'challenges/n1'), challenge({ creatorUid: 'dave', metric: 'cardio' })));
    await no(setDoc(doc(db('dave'), 'challenges/n2'), challenge({ creatorUid: 'dave', startAt: future(), endAt: past() })));
  });
  it('entries: members read, stranger does not', async () => {
    await ok(getDoc(doc(db('bob'), 'challenges/ch1/entries/alice')));
    await ok(getDocs(collection(db('bob'), 'challenges/ch1/entries')));
    await no(getDoc(doc(db('dave'), 'challenges/ch1/entries/alice')));
  });
  it('entries can never be written by clients', async () => {
    const e = { score: 99999, rank: 1, previousRank: 1, updatedAt: ts() };
    await no(setDoc(doc(db('bob'), 'challenges/ch1/entries/bob'), e));
    await no(updateDoc(doc(db('bob'), 'challenges/ch1/entries/bob'), { score: 1e9 }));
    await no(setDoc(doc(db('alice'), 'challenges/ch1/entries/alice'), e));
    await no(deleteDoc(doc(db('bob'), 'challenges/ch1/entries/bob')));
    await no(setDoc(doc(db('dave'), 'challenges/glob/entries/dave'), e));
  });
  it('global entries visible to anyone except hidden ones', async () => {
    await ok(getDoc(doc(db('dave'), 'challenges/glob/entries/bob')));
    await no(getDoc(doc(db('dave'), 'challenges/glob/entries/hid')));
    await env.withSecurityRulesDisabled((ctx) => setDoc(doc(ctx.firestore(), 'challenges/glob/entries/dave'), { score: 1, rank: 3, previousRank: 3, hidden: true, updatedAt: ts() }));
    await ok(getDoc(doc(db('dave'), 'challenges/glob/entries/dave')));
  });
  it('join: invitee can join with a valid member doc', async () => {
    await ok(setDoc(doc(db('carol'), 'challenges/ch1/members/carol'), { uid: 'carol', username: 'carol', joinedAt: ts() }));
  });
  it('join: uninvited user cannot join a private challenge; anyone can join a global one', async () => {
    await no(setDoc(doc(db('dave'), 'challenges/ch1/members/dave'), { uid: 'dave', username: 'dave', joinedAt: ts() }));
    await ok(setDoc(doc(db('dave'), 'challenges/glob/members/dave'), { uid: 'dave', username: 'dave', joinedAt: ts() }));
  });
  it('join: cannot join as another uid or without uid field or after the end', async () => {
    await no(setDoc(doc(db('carol'), 'challenges/ch1/members/dave'), { uid: 'dave', username: 'dave', joinedAt: ts() }));
    await no(setDoc(doc(db('carol'), 'challenges/ch1/members/carol'), { username: 'carol', joinedAt: ts() }));
    await env.withSecurityRulesDisabled((ctx) => setDoc(doc(ctx.firestore(), 'invites/ended_dave'), { challengeId: 'ended', fromUid: 'alice', toUid: 'dave', status: 'pending', createdAt: ts() }));
    await no(setDoc(doc(db('dave'), 'challenges/ended/members/dave'), { uid: 'dave', username: 'dave', joinedAt: ts() }));
  });
  it('members: leave own, creator can remove, others cannot', async () => {
    await no(deleteDoc(doc(db('dave'), 'challenges/ch1/members/bob')));
    await ok(deleteDoc(doc(db('bob'), 'challenges/ch1/members/bob')));
    await ok(deleteDoc(doc(db('alice'), 'challenges/ch1/members/alice')));
  });
  it('members list only for members', async () => {
    await ok(getDocs(collection(db('bob'), 'challenges/ch1/members')));
    await no(getDocs(collection(db('dave'), 'challenges/ch1/members')));
  });
  it('collection group members query: own memberships only', async () => {
    const { collectionGroup } = await import('firebase/firestore');
    await ok(getDocs(query(collectionGroup(db('bob'), 'members'), where('uid', '==', 'bob'))));
    await no(getDocs(query(collectionGroup(db('dave'), 'members'), where('uid', '==', 'bob'))));
    await no(getDocs(collectionGroup(db('bob'), 'members')));
  });
});

describe('invites', () => {
  const inv = (extra = {}) => ({ challengeId: 'ch1', fromUid: 'bob', toUid: 'dave', status: 'pending', createdAt: ts(), ...extra });
  it('member can invite with deterministic id', async () => {
    await ok(setDoc(doc(db('bob'), 'invites/ch1_dave'), inv()));
  });
  it('non-member cannot invite', async () => {
    await no(setDoc(doc(db('dave'), 'invites/ch1_bob'), inv({ fromUid: 'dave', toUid: 'bob' })));
  });
  it('invite id must be challengeId_toUid, cannot spoof fromUid, cannot self-invite or pre-accept', async () => {
    await no(setDoc(doc(db('bob'), 'invites/random'), inv()));
    await no(setDoc(doc(db('bob'), 'invites/ch1_dave'), inv({ fromUid: 'alice' })));
    await no(setDoc(doc(db('bob'), 'invites/ch1_bob'), inv({ toUid: 'bob' })));
    await no(setDoc(doc(db('bob'), 'invites/ch1_dave'), inv({ status: 'accepted' })));
  });
  it('cannot invite a user who blocked you', async () => {
    await env.withSecurityRulesDisabled((ctx) => setDoc(doc(ctx.firestore(), 'users/dave/blocked/bob'), { createdAt: ts() }));
    await no(setDoc(doc(db('bob'), 'invites/ch1_dave'), inv()));
  });
  it('recipient can accept or decline only status', async () => {
    await ok(updateDoc(doc(db('carol'), 'invites/ch1_carol'), { status: 'accepted' }));
    await no(updateDoc(doc(db('carol'), 'invites/ch1_carol'), { toUid: 'dave' }));
    await no(updateDoc(doc(db('carol'), 'invites/ch1_carol'), { status: 'pending2' }));
  });
  it('sender cannot change status; stranger cannot read', async () => {
    await no(updateDoc(doc(db('alice'), 'invites/ch1_carol'), { status: 'accepted' }));
    await no(getDoc(doc(db('dave'), 'invites/ch1_carol')));
    await ok(getDoc(doc(db('alice'), 'invites/ch1_carol')));
    await ok(getDoc(doc(db('carol'), 'invites/ch1_carol')));
  });
  it('invitee can list own invites', async () => {
    await ok(getDocs(query(collection(db('carol'), 'invites'), where('toUid', '==', 'carol'))));
    await no(getDocs(query(collection(db('dave'), 'invites'), where('toUid', '==', 'carol'))));
  });
});

describe('reports', () => {
  const r = (extra = {}) => ({ reporterUid: 'dave', targetType: 'post', targetId: 'pe', reason: 'spam', createdAt: ts(), ...extra });
  it('any signed-in user can create', async () => {
    await ok(addReport(r()));
  });
  const addReport = (data, uid = 'dave') => setDoc(doc(db(uid), `reports/${Math.random().toString(36).slice(2)}`), data);
  it('unauthenticated cannot create', async () => {
    await no(addReport(r(), null));
  });
  it('cannot spoof reporter, bad target type, empty/huge reason', async () => {
    await no(addReport(r({ reporterUid: 'bob' })));
    await no(addReport(r({ targetType: 'workout' })));
    await no(addReport(r({ reason: '' })));
    await no(addReport(r({ reason: 'x'.repeat(501) })));
  });
  it('nobody can read, update or delete', async () => {
    await env.withSecurityRulesDisabled((ctx) => setDoc(doc(ctx.firestore(), 'reports/r1'), r()));
    await no(getDoc(doc(db('dave'), 'reports/r1')));
    await no(updateDoc(doc(db('dave'), 'reports/r1'), { reason: 'x' }));
    await no(deleteDoc(doc(db('dave'), 'reports/r1')));
  });
});

describe('unknown paths', () => {
  it('denies reads and writes everywhere else', async () => {
    await no(getDoc(doc(db('alice'), 'admin/config')));
    await no(setDoc(doc(db('alice'), 'misc/x'), { a: 1 }));
    await no(setDoc(doc(db('alice'), 'feedPosts/x'), { a: 1 }));
    await no(setDoc(doc(db('alice'), 'users/alice/unknownColl/x'), { a: 1 }));
    await no(getDoc(doc(db(null), 'profiles/alice2')));
  });
});
