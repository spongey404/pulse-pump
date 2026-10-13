# Pump Firebase backend

Contract: `docs/sync-architecture.md`. Project `pulsepump-81986` (Firestore `australia-southeast1`, Blaze). Everything
here is developed and tested against the local emulators with the demo project id `demo-pump`.

```
firebase/
  firestore.rules          security rules
  firestore.indexes.json   composite indexes, collection-group overrides, TTL on _events.expireAt
  rules-tests/             node:test + @firebase/rules-unit-testing
  functions/               TypeScript Cloud Functions (2nd gen, australia-southeast1, Node 24)
  seed/                    dev data for the emulators
```

Setup: `export PATH=/opt/homebrew/opt/openjdk@21/bin:$HOME/.nvm/versions/node/v24.12.0/bin:$PATH`, then
`npm install` in `rules-tests/`, `functions/` and `seed/`.

## Tests

| Command (from the directory) | What |
|---|---|
| `cd firebase/rules-tests && npm test` | Starts the Firestore emulator via `firebase emulators:exec` and runs the rules suite |
| `cd firebase/functions && npm test` | Pure unit tests (scoring, ranking, follow rules) with vitest |
| `cd firebase/functions && npm run test:integration` | Builds, starts Functions + Firestore + Auth emulators, runs trigger / callable tests |

## Emulators

```bash
cd firebase/functions && npm run build
cd ../.. && firebase emulators:start --only auth,firestore,functions --project demo-pump
# optional: node firebase/seed/seed.mjs
```
Ports (firebase.json): Auth 9099, Firestore 8085, Functions 5001, UI 4000. The scheduled function is skipped locally
(no pubsub emulator); call `closeEndedChallengesNow` via the admin-only callable instead.

## Deploy (document only, nothing here was deployed)

```bash
firebase deploy --only firestore:rules,firestore:indexes --project pulsepump-81986
firebase deploy --only functions --project pulsepump-81986        # runs the predeploy build
```
After the first deploy: enable a Firestore **TTL policy** on `_events.expireAt` (declared in the indexes file, so
`firestore:indexes` applies it) and give operators the `admin` custom claim to use `closeEndedChallenges`.

## Functions (region `australia-southeast1`)

| Name | Type | Does |
|---|---|---|
| `onWorkoutWritten` | `users/{uid}/workouts/{id}` | Rescores the user in every active, non-custom challenge whose window contains the workout's old or new date; rewrites `entries/{uid}` and reranks |
| `onMemberWritten` | `challenges/{id}/members/{uid}` | Maintains `memberCount`; scores a joiner at once; removes the entry on leave and reranks |
| `onFollowWritten` | `follows/{a}_{b}` | `profiles.friendCount` / `fanCount` (transactional, idempotent per event) |
| `onLikeWritten`, `onCommentWritten` | post subcollections | `likeCount`, `commentCount` |
| `deleteAccount` | callable | Deletes the caller's data and Auth user; safe to call again if it failed |
| `closeEndedChallenges` | callable (`admin` claim) | Marks challenges past `endAt` as `ended` |
| `closeEndedChallengesDaily` | scheduled 03:00 Sydney | Same |

Scoring details (`functions/src/scoring.ts`, `ranking.ts`): warm-ups never count; window is inclusive
(`startAt <= date <= endAt`); `heaviestLift` is best Epley e1RM (1 rep = the weight) for `exerciseName`;
`totalVolume`, `mostReps` and `longestHold` also honour an `exerciseName` when the challenge sets one; deleted
workouts (`deletedAt`) are ignored; `custom` is never touched. Ranking: score desc, ties share a rank (1,1,3) and are
ordered by earliest `scoreAt`; `previousRank` is the old rank whenever the rank changes.

## Notes for client developers

- Cross-document rules only authorise a *query* when the query pins the value: list posts per author
  (`authorUid ==`) and filter on the `audience` values you may see. Single-document reads always work.
- Deviations from the doc are listed in `docs/sync-architecture.md` under "Deviations".
