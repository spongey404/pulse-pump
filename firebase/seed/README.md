# Emulator seed data

Fills the **local** Firebase emulators with realistic social data so the iOS app can be exercised without touching
the real project. The script refuses to run unless the project id starts with `demo-`.

```bash
export PATH=/opt/homebrew/opt/openjdk@21/bin:$HOME/.nvm/versions/node/v24.12.0/bin:$PATH
cd firebase/seed && npm install            # once
cd ../..
firebase emulators:start --only auth,firestore,functions --project demo-pump   # terminal 1
node firebase/seed/seed.mjs                                                    # terminal 2 (re-runnable, wipes emulator data first)
```

Every account signs in with `friendN@example.com` / `password` (N = 1..8):

| N | handle | profile visibility | relationship to friend1 |
|---|---|---|---|
| 1 | frankie | everyone | (you) |
| 2 | sam_lifts | friends | friend (mutual) |
| 3 | tess.t | everyone | friend (mutual) |
| 4 | ollie4 | onlyMe | fan of friend1; invited to Bench Club |
| 5 | priya_5 | everyone | fan of friend1; hidden on global boards |
| 6 | jay.six | everyone | friend1 is a fan of friend6 |
| 7 | mika7 | everyone | stranger |
| 8 | eddie8 | everyone | blocked by friend1 |

Contents: auth accounts, `users/{uid}` (+ five workouts and a bodyweight entry each), `usernames`, `profiles` with
consistent `friendCount`/`fanCount`, 11 `follows` edges, 7 posts (everyone / friends / onlyMe, with
`extras/bodymap`), comments and likes with matching counters, challenges `seed-bench` (heaviestLift, friends),
`seed-volume` (totalVolume) and `seed-global` (global, one hidden entry) with members and ranked entries, a pending
invite (`invites/seed-bench_seed-friend4`) and one report. UIDs are `seed-friendN`.

Point the iOS app at the emulators in DEBUG builds: Auth `127.0.0.1:9099`, Firestore `127.0.0.1:8085`,
Functions `127.0.0.1:5001` (region `australia-southeast1`). On a physical device use the Mac's LAN IP.
Scores in the seed are computed with the same rules as the functions, so running the functions emulator alongside
produces identical entries when workouts are later edited.
