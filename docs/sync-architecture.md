# Pump cloud sync — architecture and data contract (v1)

Status: agreed design, implementation in progress. This document is the contract shared by the iOS app,
the future Android app, the Firestore security rules and the Cloud Functions.

## Decisions
- **Backend:** Firebase — Auth, Firestore (`pulsepump-81986`, `australia-southeast1`), Cloud Functions (Blaze plan).
- **Accounts are required.** The app needs a signed-in user (Apple, Google or Email). Sync is always on.
- **Offline-first.** SwiftData (iOS) / Room (Android) is the local source of truth for the UI, widgets and Live Activity.
  A sync layer mirrors it to Firestore.
- **What syncs:** profile, preferences, privacy settings, workouts, templates, splits, equipment profiles, custom exercises,
  bodyweight log. **Not synced:** in-progress drafts (stay on the device that started them), widget library/snapshot.
- **Conflicts:** last write wins by `updatedAt` (server-assigned on push is NOT used; client clock, UTC, ms). Deletes are soft (`deletedAt`).
- **Units:** all weights stored in **kg**, distances in metres, durations in seconds, timestamps UTC. Display converts at the UI edge.
- **IDs:** every record has a stable client-generated UUID (lower-case) used as the Firestore document id.
- **Schema versioning:** every synced document has `schemaVersion` (int, currently 1). Readers must ignore unknown fields.
- **Friends and fans:** following is one-way. If both A→B and B→A exist they are **friends**; if only one exists the follower is a **fan**
  of the followee. A "friend request" in the UI is simply a fan; *Accept* = follow back (becomes friends), *Ignore* = stay a fan.
- **Privacy (defaults from the Social design, screen 6g):** Workout posts = friends, Body map = friends, Global leaderboards = visible,
  Profile = everyone. Only what a user *posts* is ever visible to others; raw workouts are owner-only. Enforced in rules/functions, not just UI.
- **Server-side logic (Cloud Functions):** challenge scoring and ranks, friend/fan counters, like/comment counters, account deletion.
  Personal-data sync does NOT use functions.
- **App Store requirements covered:** account deletion, report and block for user-generated content, Sign in with Apple.

## Firestore data model

### Private to the owner (`users/{uid}/…`) — readable and writable only by `uid`
| Path | Fields |
|---|---|
| `users/{uid}` | `name, username, unit ("kg"/"lbs"), experienceLevel, gender, age, heightCm, weightKg, selectedSplitId?, settings{…}, privacy{workoutPosts, bodyMap, globalLeaderboards, profile}, schemaVersion, createdAt, updatedAt` |
| `users/{uid}/workouts/{id}` | `date, durationSec, notes, calories, isDeload, templateId?, templateName?, exercises[{exerciseId, exerciseName, order, notes, sets[{order, weightKg, reps, rir?, durationSec?, distanceM?, setType, side}]}], schemaVersion, updatedAt, deletedAt?` |
| `users/{uid}/templates/{id}` | `name, exercises[{exerciseId, exerciseName, order, targetSets, targetReps?, targetRIR?, restSeconds?, notes?}], splitDays[], notes, schemaVersion, updatedAt, deletedAt?` |
| `users/{uid}/splits/{id}` | `type, name, days[{dayOfWeek(1=Sun…7=Sat), label, workoutType}], schemaVersion, updatedAt, deletedAt?` |
| `users/{uid}/equipmentProfiles/{id}` | `name, equipment[], platesKg[], bars[{name, weightKg}], schemaVersion, updatedAt, deletedAt?` |
| `users/{uid}/customExercises/{id}` | exercise fields (`name, primaryMuscles[], secondaryMuscles[], equipmentType, movementPattern, exerciseType, isUnilateral, …`), `schemaVersion, updatedAt, deletedAt?` |
| `users/{uid}/bodyweight/{yyyyMMdd}` | `kg, updatedAt` |
| `users/{uid}/blocked/{otherUid}` | `createdAt` |

### Social / shared
| Path | Written by | Read by |
|---|---|---|
| `profiles/{uid}` — `displayName, username, streak, totalWorkouts, friendCount, fanCount, profileVisibility, globalLeaderboardVisible, updatedAt` | owner (counters by function) | per `profileVisibility` (everyone → any signed-in user; friends → friends; only me → owner) |
| `usernames/{handle}` — `uid` | owner, create-only (uniqueness) | any signed-in |
| `follows/{followerUid}_{followeeUid}` — `followerUid, followeeUid, createdAt` | the follower (create/delete) | the two users |
| `posts/{postId}` — `authorUid, authorName, authorUsername, date, workoutName, audience("everyone"/"friends"/"onlyMe"), bodyMapAudience, stats{sets, volumeKg, durationSec, prCount}, exercises[…], likeCount, commentCount, createdAt` | author (counters by function) | per `audience` |
| `posts/{postId}/extras/bodymap` — `muscleSets{group: sets}` | author | per `bodyMapAudience` (or author) |
| `posts/{postId}/comments/{id}` — `authorUid, text, createdAt` | any reader of the post | readers of the post |
| `posts/{postId}/likes/{uid}` | that user | readers of the post |
| `challenges/{id}` — `creatorUid, name, metric, exerciseName?, startAt, endAt, isGlobal, visibility, status("active"/"ended"), memberCount, schemaVersion` | creator (status by function) | members, invitees, creator (global: anyone signed in) |
| `challenges/{id}/members/{uid}` — `username, joinedAt` | that user (join) | members |
| `challenges/{id}/entries/{uid}` — `username?, score, rank, previousRank, updatedAt` | **functions only** | members (global: any signed-in, honouring `globalLeaderboardVisible`) |
| `invites/{id}` — `challengeId, fromUid, toUid, status` | sender creates; recipient updates status | sender + recipient |
| `reports/{id}` — `reporterUid, targetType, targetId, reason, createdAt` | any signed-in user, create-only | nobody (admin/console) |

`friends(a,b)` ⇔ `follows/a_b` and `follows/b_a` both exist (rules check with `exists()`).

## Sync algorithm (client)
1. **Outbox:** every synced record has `updatedAt` and `syncedAt?`. A record is dirty when `syncedAt == nil || updatedAt > syncedAt`. Mutation points
   set `updatedAt = now`. Deletes set `deletedAt` and `updatedAt`.
2. **Push:** batch dirty records (≤ 400 writes/batch), set `syncedAt` after success. Retry with backoff; safe to repeat (idempotent by id).
3. **Pull:** per collection, query `updatedAt > lastPulledAt` ordered by `updatedAt`, apply records whose `updatedAt` is newer than local
   (last write wins), apply `deletedAt` as a local delete, advance `lastPulledAt`.
4. **Triggers:** sign-in, app foreground, after a workout completes or an edit is saved (debounced), and a manual "Sync now".
5. **New device / reinstall:** pull everything (paged) before showing the main UI; show progress.
6. **Sign-out / account switch:** wipe local user data when a different uid signs in.

## Rules and functions
See `firebase/firestore.rules`, `firebase/firestore.indexes.json`, `firebase/functions/`. Rules are tested with the emulator
(`firebase/rules-tests`). Functions: `onWorkoutWritten` (scoring), `onFollowWritten` (friend/fan counters), `onLikeWritten` /
`onCommentWritten` (counters), `deleteAccount` (callable).

## Deviations (made while implementing `firebase/`)
The rules and functions need these additions to the tables above; the iOS and Android clients must follow them.
- `invites/{id}`: the document id **must be `{challengeId}_{toUid}`** so rules can authorise the invitee to read the challenge by path. Also allowed: `createdAt`, `challengeName`, `fromUsername`, `schemaVersion`. Status values: `pending`, `accepted`, `declined`; only `status` may be updated, by the recipient.
- `challenges/{id}/members/{uid}` additionally carries **`uid`** (needed for the `members` collection-group query "my challenges"). Join is allowed for global challenges, the creator, or an invitee, while `status == "active"` and `endAt` is in the future. `memberCount` is maintained by the `onMemberWritten` function.
- `posts/{id}/likes/{uid}` additionally carries **`uid`** (needed to delete a deleted account's likes via a collection-group query).
- `challenges/{id}/entries/{uid}` additionally carries `uid`, `scoreAt` (when the score last changed; earlier wins ties) and `hidden` (global boards only, set when the user's `globalLeaderboardVisible` is false; `username` is then omitted and rules hide the entry from everyone but the owner).
- Ranks use competition ranking (equal scores share a rank: 1, 1, 3), displayed in order of earliest `scoreAt`.
- `usernames/{handle}`: create-only plus **delete by the owner** (so a rename can release the old handle). Handle is `[a-z0-9._]{3,20}`.
- `profiles/{uid}` is never deletable by clients (removed by `deleteAccount`); `friendCount`/`fanCount` are function-only.
- Clients can create only non-global challenges (`isGlobal` false, `status` "active", `visibility` one of `friends`, `invite`, `public`); global challenges are created with the Admin SDK. `status` and `memberCount` are function-only.
- Comments may also carry `authorName`, `authorUsername`, `schemaVersion`; reports may carry `details`.
- Private `users/{uid}/**` documents are size-capped by key and list limits but unknown extra fields are allowed (forward compatibility).
- Queries on `posts` must pin `authorUid` (and an `audience` the caller may see) because visibility depends on other documents.
- Functions: `onMemberWritten` (new), `closeEndedChallenges` (callable, `admin` claim) and `closeEndedChallengesDaily` (scheduled). Callable `deleteAccount` is in region `australia-southeast1`.

## iOS client implementation notes (`PulsePump/Core/Sync/`)
- **Units on the wire:** `updatedAt` / `deletedAt` are epoch **milliseconds** (numbers; the rules require `updatedAt is number`), `date` / `createdAt` are Timestamps. Document ids are lower-case UUID strings; bodyweight ids are `yyyyMMdd`.
- **Writes are `setData(merge: true)`.** A field that is nil locally (`templateId`, `selectedSplitId`, `deletedAt`...) is removed with `FieldValue.delete()`, never sent as `null` (the rules reject `null` strings). The profile write only ever contains `name, username, unit, experienceLevel, gender, age, heightCm, weightKg, selectedSplitId, createdAt, schemaVersion, updatedAt`; `privacy` and social fields are never touched.
- **Pull** is per collection in the order splits, customExercises, profile, equipmentProfiles, templates, workouts, bodyweight: `updatedAt >= cursor` ordered by `(updatedAt, __name__)`, paged by 200. The persisted cursor is the highest `updatedAt` seen (boundary documents are re-read, which is idempotent). A remote record is applied only when its `updatedAt` is strictly greater than the local one; equal timestamps keep the local copy. Tombstones are applied to existing records and never created on a fresh device.
- **Push** runs after pull in a cycle: dirty records in batches of at most 400; a permanently rejected document is retried alone so it cannot block the rest. `syncedAt` is set to the `updatedAt` that was sent.
- **Exercise references:** catalogue exercises have per-install ids, so workout / template exercise references resolve by id first (custom exercises sync with their id) and then by normalised name; an unknown name becomes a local-only placeholder custom exercise so history is never dropped.
- **Local-only bookkeeping:** `syncDigest` (FNV-1a of the mapped payload at last sync) lets the change tracker tell real edits from SwiftData relationship noise. Drafts (`isDraft`) and the widget library / snapshot are never synced. Bodyweight entries live in the App Group log with `updatedAt` / `syncedAt` added (legacy entries still decode).
