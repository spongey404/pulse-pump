# 12 Cloud sync and data ownership

Scope: what lives where, what syncs to the user's private Firestore area (`users/{uid}/**`), when it syncs, how conflicts resolve, and what happens on sign-out, account switch and a new device. Social data (feed, friends, challenges) is covered in area 09; sign-in/sign-out/delete screens in area 01 (this file covers only their sync side).
Key sources: `Ore/Core/Sync/*` (SyncService, SyncApplier, SyncMapper, SyncChangeTracker, SyncRecord, SyncAccount, FirestoreRemoteStore), `Ore/Core/Services/Auth/SyncLifecycle.swift`, `Ore/Core/Services/Auth/AccountGate.swift`, `Ore/Features/Settings/CloudSyncSection.swift`, `Ore/Features/Widgets/BodyweightLog.swift`, `docs/sync-architecture.md`, `firebase/firestore.rules`.

Summary of the model: SwiftData is the source of truth for the UI. A background engine mirrors it to Firestore. Accounts are required, so sync is always on while signed in (there is no sync on/off switch). Conflicts are last-write-wins by the client-assigned `updatedAt` (epoch ms). Deletes are soft (`deletedAt` tombstones).

## Data ownership table

| Data | SwiftData (device) | Firestore private `users/{uid}/**` | Firestore social (shared) | UserDefaults (standard) | App Group defaults (`group.com.pulse.PulsePump`) |
|---|---|---|---|---|---|
| Profile (name, username, unit, experience, gender, age, height cm, weight kg, createdAt, selected split id) | `User` | SYNCED: doc `users/{uid}` (merge write; only these fields) | no | unit mirrored as `UnitPreference.current` | no |
| Finished workouts incl. exercises and sets (weights kg) | `Workout`/`ExerciseLog`/`SetLog` | SYNCED: `workouts/{id}` (one doc embeds exercises and sets) | only if the user posts (separate `posts` doc) | no | snapshot derived copy |
| In-progress draft workout (`isDraft`) | `Workout` | NOT synced (device-local) | no | no | no |
| Templates (incl. presets once edited/deleted) | `WorkoutTemplate` | SYNCED: `templates/{id}` | no | no | no |
| Splits (and the selected split) | `Split`, `User.selectedSplit` | SYNCED: `splits/{id}`, `selectedSplitId` on profile | no | no | no |
| Equipment profiles (plates kg, bars) | `EquipmentProfile` | SYNCED: `equipmentProfiles/{id}` | no | no | no |
| Custom exercises | `Exercise` (`isCustom`) | SYNCED: `customExercises/{id}` | no | no | no |
| Catalogue exercises (84 seeded) | `Exercise` | NOT synced (per-install ids; matched by normalised name) | no | `exerciseSeedVersion` | no |
| Bodyweight log (one kg point per day) | no | SYNCED: `bodyweight/{yyyyMMdd}` | no | no | `widget_bodyweight_log` (JSON, with `updatedAt`/`syncedAt`) |
| Widget snapshot and custom widget library | no | NOT synced | no | no | `widget_snapshot`, `custom_widget_library`, `widget_*` keys (wiped on sign-out) |
| App settings (theme, rest timer mode/alert, calorie formula, reminders, rest-day alerts, summary customisation, auto-share) | no | NOT synced (docs say preferences sync; code does not) | no | `appTheme`, `restTimerMode`, `restTimerAlertType`, `calorieFormula`, `workoutReminders`, `restDayAlerts`, `summary_show*`, `autoShareToFeed` | no |
| Privacy settings (workout posts, body map, leaderboards, profile visibility) | n/a | NOT written by the sync engine (`privacy` never touched) | `profiles/{uid}` fields written by the social code | no | no |
| Feed posts, comments, likes, follows, challenges, invites, reports, blocks | `Challenge`, `UserProfile` (local cache only) | `users/{uid}/blocked` | `posts`, `follows`, `challenges`, `invites`, `reports`, `profiles`, `usernames` | no | `widget_friends` (cache) |
| Sync bookkeeping | `syncedAt`, `syncDigest`, `deletedAt`, `updatedAt`, `schemaVersion` on each record | `updatedAt`, `deletedAt`, `schemaVersion` | no | `sync.lastUid`, `sync.cursor.{uid}.{collection}`, `sync.initial.{uid}`, `sync.last.{uid}`, `localStoreOwnerUid` | no |
| Auth session and tokens | no | no | no | Firebase Auth keychain (outside this table's stores) | no |

Invariant: everything stored and synced is kg (weights), cm (height), metres (distance), seconds (duration). Display unit only changes presentation (area 10, UNT).

---

## SYN  Core sync engine (triggers, push, pull)

| ID | User does → App does (observable result) | Status | Manual check | Tests |
|---|---|---|---|---|
| SYN-03 | System: user is signed in and owns the local store → App starts `SyncService` (`ensureRunning`) from `RootView` when route is `main` or `restoring`; it installs the change tracker and a foreground observer, then runs a full sync (pull then push). `RootView.swift:73-77`, `SyncService.swift:start` | ✅ | [ ] | — |
| SYN-06 | System: sync is already running for the same uid → `ensureRunning` is a no-op (idempotent), no second engine starts | ✅ | [ ] | — |
| SYN-09 | User finishes a workout → App marks the workout dirty (`markUpdated`, `WorkoutViewModel.swift:244`); the change tracker sees the save and schedules a push 5 s later (quiet period) | ✅ | [ ] | — |
| SYN-12 | User makes another edit within 5 s of the previous one → App cancels the pending timer and restarts the 5 s wait (push happens 5 s after the LAST change) | ✅ | [ ] | — |
| SYN-15 | System: debounce fires → App runs a push-only cycle (no pull) and stamps `syncedAt = the updatedAt that was sent` on each pushed record | ✅ | [ ] | — |
| SYN-18 | User edits a record while a push is in flight → App still treats it as dirty afterwards, because `syncedAt` stores the sent `updatedAt`, not "now" (`SyncRecord.swift`) | ✅ | [ ] | — |
| SYN-21 | System: a record is dirty when `syncedAt == nil` or `updatedAt` (ms) is greater than `syncedAt` (ms) → App includes it in the next push | ✅ | [ ] | — |
| SYN-24 | System: more than 400 dirty documents → App writes them in batches of at most 400 (`RemoteLimits.maxBatch`) | ✅ | [ ] | — |
| SYN-27 | System: a batch is rejected permanently (e.g. rules denial) → App retries each document alone so one bad document does not block the rest; after the loop the cycle fails with "N item(s) could not be synced" (singular "item" when 1) | ✅ | [ ] | — |
| SYN-30 | User brings the app to the foreground → App starts a full sync, but only if the last full attempt was 30 s or more ago (`foregroundThrottle`) | ✅ | [ ] | — |
| SYN-33 | User taps "Sync Now" in Settings → App runs a full sync immediately (not debounced, not throttled) | ✅ | [ ] | — |
| SYN-36 | System: pull runs → App fetches collections in order splits, customExercises, profile, equipmentProfiles, templates, workouts, bodyweight; each query is `updatedAt >= cursor` ordered by (updatedAt, doc id), pages of 200 | ✅ | [ ] | — |
| SYN-39 | System: a page of changes is applied → App saves SwiftData, persists the per-collection cursor (`sync.cursor.{uid}.{collection}`) so an interrupted pull resumes | ✅ | [ ] | — |
| SYN-42 | System: a push or pull cycle succeeds → App sets status Up to date (or "N change(s) waiting" if more dirty items), records `lastSyncedAt` (`sync.last.{uid}`) | ✅ | [ ] | — |
| SYN-45 | System: a cycle fails → App keeps records dirty, sets status Offline (network down/Firestore unavailable) or Error, and schedules an automatic full-sync retry with backoff 5, 15, 45, 120, then 300 s (last delay repeats) | ✅ | [ ] | — |
| SYN-48 | System: a retry timer is pending and the user triggers a sync → App cancels the pending retry and runs now | ✅ | [ ] | — |
| SYN-51 | System: a sync is requested while another cycle is running → App queues one follow-up run (full wins over push-only) after the current cycle succeeds | ✅ | [ ] | — |
| SYN-54 | System: the change tracker sees a save that changed a synced record nobody stamped (content digest differs from the last-synced digest) → App calls `markUpdated` on it so it syncs; relationship-only noise (digest equal) is ignored | ✅ | [ ] | — |
| SYN-57 | System: a full cycle starts → App first runs `reconcileAll` over workouts, templates, splits, equipment, user and custom exercises to catch child-row deletions and edits made while no tracker was installed | ✅ | [ ] | — |
| SYN-60 | System: the engine itself writes to SwiftData (applying remote data, stamping `syncedAt`) → App ignores those saves in the tracker (`isApplying`) so applying a pull never re-dirties records | ✅ | [ ] | — |
| SYN-63 | System: the user's data is written to Firestore → App uses `setData(merge: true)`; fields nil locally (`templateId`, `templateName`, `selectedSplitId`, `deletedAt`) are removed with `FieldValue.delete()`, never sent as null | ✅ | [ ] | — |
| SYN-66 | System: a note or name is longer than the rules cap → App truncates before sending: notes 5000 chars, names 200 (user name 100, username 40) so one long value cannot poison a batch | ✅ | [ ] | — |
| SYN-69 | System: a push sends a profile → App writes only `name, username, unit, experienceLevel, gender, age, heightCm, weightKg, selectedSplitId, createdAt, schemaVersion, updatedAt`; `privacy`, `settings` and social fields are never touched | ✅ | [ ] | — |
| SYN-72 | System: only finished workouts push (`!isDraft`); soft-deleted ones push as tombstones | ✅ | [ ] | — |

### SYN edge cases

| ID | Situation | What the app does | Why/notes | Status | Manual check | Tests |
|---|---|---|---|---|---|---|
| SYN-E01 | Edit while offline (airplane mode) | Edit saves locally and immediately; record stays dirty; pending count rises; the push attempt fails and retries with backoff; on reconnect the next retry/foreground/Sync Now pushes it | Offline-first by design. There is no network-reachability monitor; offline is only detected when a Firestore call fails | ✅ | [ ] | — |
| SYN-E02 | Firestore write while offline never returns an error (SDK queues the commit and `batch.commit()` awaits server ack) | Not verified: the cycle might stay in "Syncing…" with `cycleInFlight` stuck instead of showing Offline | Needs a device test in airplane mode; if it hangs, add a timeout. `FirestoreRemoteStore.swift:batchWrite` | 🧭 PROPOSED: wrap each cycle in a 30 s timeout that maps to Offline | [ ] | — |
| SYN-E03 | Kill the app mid-push | Records not yet stamped stay dirty and are re-pushed next launch; writes are idempotent by document id (merge) | `syncedAt` is set only after the batch succeeds | ✅ | [ ] | — |
| SYN-E04 | Kill the app mid-pull | Cursor is persisted after each page; next launch resumes from the last page (boundary document re-read, harmless) | `SyncService.pull` | ✅ | [ ] | — |
| SYN-E05 | Permanent rejection (rules) never succeeds | Cycle fails every time with "Sync problem: N item(s) could not be synced"; app keeps retrying on the 300 s repeat delay forever; other records still sync | Retrying a permanent error is wasteful and the error text names no record | 🟡 retries forever, no way to see which item | [ ] | — |
| SYN-E06 | Workout with more than 100 exercises, or custom exercise with an empty name | Rules reject the document permanently (`exercises.size() <= 100`, custom `name` 1-200) | Mapper clamps max length but not min length or list size | 🧭 PROPOSED: clamp exercise list to 100 and skip empty-named custom exercises in the mapper | [ ] | — |
| SYN-E07 | Bodyweight of 1000 kg or more, or zero/negative | Negative/zero ignored locally (`BodyweightLog.record` needs kg > 0); 1000 kg or more is rejected by rules (permanent error) | Rules: `kg > 0 && kg < 1000` | 🟡 no local cap at 1000 | [ ] | — |
| SYN-E08 | Double-tap Sync Now | Second tap ignored while `status == .syncing`; even otherwise a running cycle queues only one follow-up | `CloudSyncSection.swift:17` | ✅ | [ ] | — |
| SYN-E09 | Device clock is wrong (hours ahead/behind) | Last-write-wins uses the device clock, so a fast clock wins conflicts and a slow clock loses them; locally `markUpdated` is always at least 1 ms newer than the previous stamp | Server time is deliberately not used (architecture decision) | 🟡 by design, no skew protection | [ ] | — |
| SYN-E10 | Timezone change / DST | Timestamps are UTC ms; bodyweight day keys (`yyyy-MM-dd`) use the device calendar at the time of recording, so travelling can create a different day key for the same moment | Only bodyweight is day-keyed | ✅ | [ ] | — |
| SYN-E11 | Large history (thousands of workouts) on first push | Batches of 400, pages of 200 on pull; no UI blocking | Each workout is one document with embedded sets (<=1 MiB Firestore limit; no guard) | 🟡 no per-document size guard | [ ] | — |
| SYN-E12 | Expired or invalid auth session during sync | Firestore `unauthenticated` is treated as transient: status Error/retry loop; the user is not sent to sign-in by the sync layer | `FirestoreRemoteStore.map` | 🟡 | [ ] | — |
| SYN-E13 | Locale with decimal comma | No effect: sync sends numbers, not strings; typed input is parsed in the logger before storage as kg | Area 10 UNT covers parsing | ✅ | [ ] | — |
| SYN-E14 | Imported/seeded records (Strong/Hevy import, preset templates) | Imports insert new records with `syncedAt == nil`, so the tracker finds them dirty and they sync like normal edits (see SYX flow); presets are seeded as already-synced (SYN-E15) | `DataImportService.swift:241` | ✅ | [ ] | — |
| SYN-E15 | Preset templates on two devices | Presets get a deterministic id from their name and start with `updatedAt = syncedAt = epoch 0`; they cost no writes until edited/deleted and any cloud copy wins on pull, so presets are not duplicated per device | `TemplateSeedService.swift:adoptPresetIdentity` | ✅ | [ ] | — |

## SYC  Conflicts, deletes and merging

| ID | User does → App does (observable result) | Status | Manual check | Tests |
|---|---|---|---|---|
| SYC-03 | System: a pulled document has `updatedAt` strictly greater than the local record → App overwrites the local record with the remote content (last write wins) and marks it synced | ✅ | [ ] | — |
| SYC-06 | System: a pulled document has an equal or older `updatedAt` → App skips it (equal timestamps keep the local copy) | ✅ | [ ] | — |
| SYC-09 | User edits the same template on two devices while both are offline → After both reconnect, the edit with the later `updatedAt` survives on both devices; the other edit is lost entirely (whole-document winner, no field merge) | ✅ | [ ] | — |
| SYC-12 | User edits a workout locally (unsynced) and the cloud copy is newer → Pull applies the cloud copy over the unsynced local edit (the local edit is discarded, nothing prompts) | ✅ | [ ] | — |
| SYC-15 | User deletes a workout (history or detail) → App sets `deletedAt` and `updatedAt` (tombstone), hides it from every list/stat/export, and syncs the tombstone (`WorkoutDetailView.swift:69`, `WorkoutHistoryView.swift:57`) | ✅ | [ ] | — |
| SYC-18 | System: a tombstone arrives from the cloud for a record that exists locally and is older → App marks it deleted locally (it disappears from lists); for a selected split it also clears `selectedSplit` | ✅ | [ ] | — |
| SYC-21 | System: a tombstone arrives for a record that does not exist locally (fresh device) → App skips it; tombstones never create records | ✅ | [ ] | — |
| SYC-24 | User edits a record on device B after device A deleted it (B's `updatedAt` newer) → Record comes back on A (the pull stamp clears `deletedAt`); deletion is not sticky against a newer edit | ✅ | [ ] | — |
| SYC-27 | User deletes a template, a template group or a split → App soft-deletes (tombstones) rather than removing rows (`TemplateListView.swift:18`, `ProgramsTabView.swift:147`, `SplitSchedule.swift:50`) | ✅ | [ ] | — |
| SYC-30 | User deletes an equipment profile or custom exercise → Same tombstone rule (`deletedAt`, filtered by `deletedAt == nil` in lists) | 🟡 filters exist in lists; delete call sites for equipment/custom exercises not individually verified | [ ] | — |
| SYC-33 | System: tombstones accumulate → App keeps them forever locally and in the cloud (no purge job) until the account is wiped/deleted | 🟡 no compaction | [ ] | — |
| SYC-36 | System: a remote workout refers to an exercise the device lacks → App resolves by id, then by normalised name, otherwise creates a local-only placeholder custom exercise (never pushed) so history is not dropped | ✅ | [ ] | — |
| SYC-39 | System: a remote workout arrives for an id that is a local draft → App skips it (drafts are never overwritten by sync) | ✅ | [ ] | — |
| SYC-42 | System: a remote record has missing optional fields or unknown extra fields → App fills defaults and ignores unknowns (forward compatible; `schemaVersion` kept at least 1) | ✅ | [ ] | — |
| SYC-45 | System: remote bodyweight entry for a day → App applies it only if newer than the local entry for that day; a new day is appended; log is capped at 400 days | ✅ | [ ] | — |
| SYC-48 | System: remote profile arrives and there is no local `User` → App creates the `User` only if the document carries `unit` (written by this engine); otherwise it is skipped | ✅ | [ ] | — |
| SYC-51 | System: the pulled profile's `selectedSplitId` points to a deleted/unknown split → App sets no selected split | ✅ | [ ] | — |

### SYC edge cases

| ID | Situation | What the app does | Why/notes | Status | Manual check | Tests |
|---|---|---|---|---|---|---|
| SYC-E01 | Two devices edit different fields of the same profile | One whole profile wins (newest `updatedAt`); the other device's field change is lost | Granularity is the document, not the field | ✅ | [ ] | — |
| SYC-E02 | Two devices log different workouts offline | Both survive: each workout is its own document keyed by UUID | No conflict | ✅ | [ ] | — |
| SYC-E03 | Device A deletes a workout while device B is offline and then edits it | Whichever `updatedAt` is later wins; a later B edit resurrects the workout (SYC-24) | Expected under LWW | ✅ | [ ] | — |
| SYC-E04 | Two devices edit the same workout in the same millisecond | Equal timestamps: each device keeps its own copy, so devices can diverge until one edits again | Strictly-greater rule | 🟡 by design | [ ] | — |
| SYC-E05 | Two devices record bodyweight for the same day | Newest `updatedAt` wins for that day | `BodyweightLog.applyRemote` | ✅ | [ ] | — |
| SYC-E06 | Template references a custom exercise that was deleted | Template keeps the name and id; exercise resolution falls back by name | `resolveExerciseNoCreate` | 🟡 behaviour of a template pointing at a tombstoned exercise not verified in UI | [ ] | — |
| SYC-E07 | Same exercise name exists as catalogue and custom | Name index prefers live over deleted, then catalogue over custom | `SyncApplier.indexExercises` | ✅ | [ ] | — |
| SYC-E08 | User edits a past workout's weight in lbs mode | Stored value is kg either way, `markUpdated` runs, the kg value is what is pushed | Units invariant | ✅ | [ ] | — |

## SYA  Account lifecycle: restore, sign-out, account switch, delete

| ID | User does → App does (observable result) | Status | Manual check | Tests |
|---|---|---|---|---|
| SYA-03 | User signs in on a new device/reinstall with an existing account → App checks that `users/{uid}` exists, shows the "RESTORING YOUR DATA…" screen ("Your workouts and programs are coming back.") and starts the initial pull (`AccountGate.checkCloud`, `GateViews.swift:25`) | ✅ | [ ] | — |
| SYA-06 | System: initial pull finishes and the profile created a local `User` → App flips `isInitialSyncComplete`, stores `sync.initial.{uid}` and routes to the main tabs with workouts, templates, splits, equipment, custom exercises and bodyweight restored | ✅ | [ ] | — |
| SYA-09 | System: the gate is waiting for restore → App polls `isInitialSyncComplete` every 400 ms; progress is exposed as 0...1 (`initialSyncProgress`) but the restoring screen shows only a spinner, no percentage | 🟡 progress value exists, not displayed | [ ] | — |
| SYA-12 | System: pull completed but no local `User` exists → App shows "Couldn't restore your data" / "Your account exists but nothing came back from the cloud." with TRY AGAIN and SIGN OUT | ✅ | [ ] | — |
| SYA-15 | System: signed in on a device with no local data and the cloud check fails → App shows "You're offline" / "Connect to the internet once to finish setting up this device." with TRY AGAIN and SIGN OUT; it also retries automatically when the app returns to the foreground | ✅ | [ ] | — |
| SYA-18 | User signs in to a brand-new account (no cloud profile) → App routes to onboarding; on completion `claimLocalStore` marks the local store as theirs, sync starts and pushes everything | ✅ | [ ] | — |
| SYA-21 | User with local data (installed before accounts existed) signs in → App claims the local store for that uid (no wipe) and pushes the local data up | ✅ | [ ] | — |
| SYA-24 | User taps Sign out (Settings) → App shows the splash, makes a best-effort push of all dirty records, stops sync, then deletes all local user data and signs out (`AuthSession.signOut` -> `SyncServiceLifecycle.wipeLocalData`) | ✅ | [ ] | — |
| SYA-27 | System: the sign-out wipe runs → App deletes workouts (with logs and sets, drafts included), user, templates, equipment, splits, challenges, user profile cache, custom exercises; clears the bodyweight log, widget snapshot/library and the `wantsTutorial` flag; clears the owner marker and every `sync.*` key. The 84-exercise catalogue stays. It writes NO tombstones to the cloud | ✅ | [ ] | — |
| SYA-30 | User signs back in to the SAME account after sign-out → App behaves like a new device: cursors were cleared so it does a full re-pull behind the RESTORING screen | ✅ | [ ] | — |
| SYA-33 | User signs in with a DIFFERENT account than the local store's owner → App shows splash, wipes the previous account's data (without tombstones), then continues as a new device or new account. Guarded in two places: `AccountGate.reconcile` and `SyncService.start` (lastUid differs) | ✅ | [ ] | — |
| SYA-36 | User deletes their account (Settings/Privacy) → App calls the `deleteAccount` Cloud Function (removes cloud data and the Auth user), then wipes local data and returns to sign-in; if a recent login is required it re-authenticates and retries once | ✅ | [ ] | — |
| SYA-39 | System: drafts → App never pushes drafts; a draft exists only on the device that started it and is deleted on sign-out/wipe | ✅ | [ ] | — |
| SYA-42 | User signs in on device B while device A has an unfinished draft → Device B does not see A's draft or the "continue workout" card; only the finished workout appears after A finishes and syncs | ✅ | [ ] | — |
| SYA-45 | System: app launches with a restored session → App starts sync (full cycle) and shows the main UI immediately with local data; the engine does not block the UI | ✅ | [ ] | — |
| SYA-48 | System: first launch after upgrading from a pre-sync build → App has `isInitialSyncComplete == false`, so the first full cycle runs with initial progress and "Restoring your data…" as the status text, but the UI is not blocked because a local user exists | ✅ | [ ] | — |

### SYA edge cases

| ID | Situation | What the app does | Why/notes | Status | Manual check | Tests |
|---|---|---|---|---|---|---|
| SYA-E01 | Sign out while offline with unsynced edits | The flush fails, the result is ignored, and the data is wiped anyway: unsynced edits are permanently lost | `SyncServiceLifecycle.wipeLocalData`: `_ = await sync.flushPending()`. User gets no warning | 🐞 `Ore/Core/Sync/SyncServiceLifecycle.swift:23` expected: warn or block when `flushPending()` returns false; actual: silent loss. Owner to confirm | [ ] | — |
| SYA-E02 | Sign out while a cycle is already in flight | `flushPending` returns immediately (the run is queued as a follow-up) and then `stop()` clears the queue, so the final push may not happen | `run` returns early when `cycleInFlight`; `stop()` sets `rerunRequested = nil` | 🐞 `Ore/Core/Sync/SyncService.swift:run` expected: wait for the in-flight cycle then push; actual: queued rerun dropped. Needs device confirmation | [ ] | — |
| SYA-E03 | New device, no network at sign-in (existing account) | "You're offline" gate with TRY AGAIN; nothing local is created | SYA-15 | ✅ | [ ] | — |
| SYA-E04 | New device, network drops during the initial pull | Restoring screen stays up; the cycle fails, retries with backoff; cursors persisted so it resumes; there is no timeout or cancel except SIGN OUT on the failure screen only | The RESTORING view has no escape button | 🟡 | [ ] | — |
| SYA-E05 | Initial pull completes but the cloud profile lacks `unit` (e.g. only a social/profile doc exists) | No local `User` is created and the user sees "Couldn't restore your data" | Engine-written profiles always carry `unit`; accounts created before sync may not | 🧭 PROPOSED: fall back to onboarding prefilled from the cloud doc | [ ] | — |
| SYA-E06 | Account deletion: flush before wipe | After `deleteAccount` succeeds, the wipe still calls `flushPending`, which tries to write to a deleted account (rejected/unauthenticated) and may add delay | Harmless to data but wasteful | 🟡 | [ ] | — |
| SYA-E07 | `deleteAccount` function call fails (offline or backend error) | Account and local data are left intact and the error is shown by the delete flow (area 01) | `AuthSession.deleteAccount` throws before wipe | ✅ | [ ] | — |
| SYA-E08 | App killed during the sign-out wipe | Owner marker is cleared last; on next launch a signed-in session with a partial store re-runs reconcile; if still signed in as the same user the remaining data stays | `SwiftDataSyncLifecycle.wipeLocalData` ordering | 🟡 partial-wipe recovery not verified | [ ] | — |
| SYA-E09 | UserDefaults settings after account switch | Only `wantsTutorial` is cleared; theme, rest timer, reminders, calorie formula, summary toggles, `autoShareToFeed` persist to the next account on the device | `SwiftDataSyncLifecycle.userDefaultsKeysToClear` | 🧭 PROPOSED: acceptable as device preferences; confirm, or sync/clear them | [ ] | — |
| SYA-E10 | Widget data after sign-out | Snapshot, custom library, friends cache and bodyweight log are removed from the App Group, so widgets show empty/sample state | `SyncAccount.widgetKeys` | ✅ | [ ] | — |
| SYA-E11 | Supernova entitlement across devices | Not part of sync; StoreKit entitlement is read per device from the Apple ID (area 10 PLS/13 GAT) | | ✅ | [ ] | — |

## SYS  Settings "CLOUD SYNC" section

| ID | User does → App does (observable result) | Status | Manual check | Tests |
|---|---|---|---|---|
| SYS-03 | User opens Settings and scrolls to the section between DATA and ABOUT → App shows the label "CLOUD SYNC" with three rows: Status, Last Synced, Sync Now (`SettingsView.swift:171`, `CloudSyncSection.swift`) | ✅ | [ ] | — |
| SYS-06 | User views Status when idle and nothing pending → App shows "UP TO DATE" with a checkmark.icloud icon | ✅ | [ ] | — |
| SYS-09 | User views Status with unsynced items → App shows "N CHANGE(S) WAITING" ("1 CHANGE WAITING") | ✅ | [ ] | — |
| SYS-12 | User views Status during a sync → App shows "SYNCING…" with an upload icon (during the first restore: "RESTORING YOUR DATA…") | ✅ | [ ] | — |
| SYS-15 | User views Status when offline → App shows "OFFLINE — WILL SYNC WHEN CONNECTED" with a slashed icloud icon | ✅ | [ ] | — |
| SYS-18 | User views Status after a failure → App shows "SYNC PROBLEM: <message>" with an exclamation icloud icon (messages come from Firestore or "N item(s) could not be synced") | ✅ | [ ] | — |
| SYS-21 | User views Last Synced → App shows "NEVER" if no successful cycle, else a relative time such as "NOW" or "5 MINUTES AGO" (uppercased) | ✅ | [ ] | — |
| SYS-24 | User taps "Sync Now" → App starts a full sync; the row label changes to "Syncing…" and ignores taps until done | ✅ | [ ] | — |
| SYS-27 | System: sync is not running (not signed in / still starting) → App dims the Sync Now row to 50% opacity, tap does nothing, Status reads "SIGN IN TO SYNC" | ✅ | [ ] | — |
| SYS-30 | User looks for a way to turn sync off, choose Wi-Fi only, or see which items are pending → App has none of these; sync is always on and there is no per-item list | ❌ | [ ] | — |
| SYS-33 | User looks for a sync error detail or retry countdown → App shows only the error text; the next automatic retry delay is held internally (`scheduledRetryDelay`) and not shown | 🟡 | [ ] | — |

### SYS edge cases

| ID | Situation | What the app does | Why/notes | Status | Manual check | Tests |
|---|---|---|---|---|---|---|
| SYS-E01 | Status text freshness | Status and Last Synced are driven by the observable `SyncService.shared`, so they update live while Settings is open; relative time text is not refreshed on a timer | | 🟡 | [ ] | — |
| SYS-E02 | Tap Sync Now offline | Status moves to OFFLINE after the attempt fails (see SYN-E02 for the possible hang) | | 🟡 | [ ] | — |
| SYS-E03 | Free vs Supernova | Sync is not gated by Supernova | No entitlement check in `Core/Sync` | ✅ | [ ] | — |

## SYR  Firestore rules relevant to sync (`firebase/firestore.rules`)

| ID | User does → App does (observable result) | Status | Manual check | Tests |
|---|---|---|---|---|
| SYR-03 | System: the app reads or writes `users/{uid}/**` → Rules allow only the signed-in owner (`request.auth.uid == uid`); no other user can read workouts, templates, splits, equipment, custom exercises, bodyweight | ✅ | [ ] | — |
| SYR-06 | System: the app writes `users/{uid}` (profile) → Rules require at most 40 keys, `name` 0-100 chars, `username` 0-40, numeric age/heightCm/weightKg, `privacy`/`settings` maps, and an integer `schemaVersion` 1-1000 | ✅ | [ ] | — |
| SYR-09 | System: the app writes a workout → Rules require `date` to be a Timestamp, `updatedAt` a number, `exercises` a list of at most 100, `notes` at most 5000, at most 30 keys | ✅ | [ ] | — |
| SYR-12 | System: the app writes a template → name 0-200, `updatedAt` number, exercises list at most 100, `splitDays` at most 14, notes at most 5000 | ✅ | [ ] | — |
| SYR-15 | System: the app writes a split → name 0-200, `days` list at most 14; equipment profile → `equipment` at most 200, `platesKg` at most 50, `bars` at most 20 | ✅ | [ ] | — |
| SYR-18 | System: the app writes a custom exercise → name 1-200 chars (empty is rejected), muscle lists at most 50 | ✅ | [ ] | — |
| SYR-21 | System: the app writes a bodyweight day → doc id must be 8 digits (`yyyyMMdd`), `kg` a number greater than 0 and below 1000, `updatedAt` number, at most 5 keys | ✅ | [ ] | — |
| SYR-24 | System: the sync engine deletes documents → Rules allow owner delete, but the client never hard-deletes; it writes tombstones (`deletedAt`) instead. Only the `deleteAccount` function hard-deletes | ✅ | [ ] | — |
| SYR-27 | System: unsigned-in or other-uid access → denied; any path not matched falls to `allow read, write: if false` | ✅ | [ ] | — |
| SYR-30 | System: rules reject a write → App sees `permissionDenied`/`invalidArgument` as a permanent error (SYN-27) | ✅ | [ ] | — |
| SYR-33 | System: shared data stays separate from private sync → Raw workouts are owner-only; other users can only see what the user posts (`posts`), per audience, and `profiles/{uid}` per profile visibility; clients cannot delete `profiles/{uid}` | ✅ | [ ] | — |

## SYX  Export, import and sync interplay

| ID | User does → App does (observable result) | Status | Manual check | Tests |
|---|---|---|---|---|
| SYX-03 | User imports a Strong/Hevy file → App inserts new workouts (non-draft) and exercises; they are dirty (`syncedAt == nil`) so the tracker pushes them about 5 s after the save | ✅ | [ ] | — |
| SYX-06 | User re-imports the same file → App skips sets already present (key: second-precision date + normalised exercise name + set order), so no duplicate workouts are created or synced | ✅ | [ ] | — |
| SYX-09 | User imports a file in lbs → App converts to kg before storage; synced values are kg | ✅ | [ ] | — |
| SYX-12 | User exports JSON/CSV → App exports only finished, non-deleted workouts (`!isDraft && deletedAt == nil`), always in kg; tombstoned workouts never appear | ✅ | [ ] | — |
| SYX-15 | User imports on device A → App syncs the imported workouts; on device B they appear after the next pull (foreground, 30 s throttle, or Sync Now) | ✅ | [ ] | — |
| SYX-18 | User imports exercises not in the catalogue → App creates custom exercises (`isCustom`, `isApproved == false`) which also sync as `customExercises` | ✅ | [ ] | — |

### SYX edge cases

| ID | Situation | What the app does | Why/notes | Status | Manual check | Tests |
|---|---|---|---|---|---|---|
| SYX-E01 | Import a very large file while offline | Data lands locally and syncs when back online in batches of 400 | | ✅ | [ ] | — |
| SYX-E02 | Import on device A and B at the same time | Duplicate protection is per device local state; two devices importing the same file offline create two sets of workouts with different UUIDs that both sync | Dedupe key only checks local data | 🧭 PROPOSED: acceptable, or dedupe on pull by the import key | [ ] | — |
| SYX-E03 | Export does not restore | No import path restores a JSON export of this app as cloud-equivalent data; cloud restore is only via sign-in | | 🧭 PROPOSED: confirm that is intended (area 10 IMP/EXP) | [ ] | — |

---

## Open decisions for the owner (12)

- SYN-E02 (PROPOSED): confirm offline behaviour with airplane mode; proposed default is a 30 s cycle timeout mapped to the Offline status.
- SYN-E06 (PROPOSED): clamp workout exercise list to 100 and skip empty-named custom exercises in the mapper so rules never permanently reject.
- SYN-E05 / SYN-E07 / SYN-E11: permanent-error loops retry forever at 300 s with no way to find the offending item; no local caps for 1000 kg bodyweight or 1 MiB workouts. Decide whether to surface a per-item error list.
- SYN-E09: LWW uses the device clock (by design); decide whether any skew protection is wanted.
- SYC-E04 / SYC-E01: whole-document winner, equal-ms tie keeps each device's copy; confirm acceptable.
- SYC-33: tombstones are never purged; decide on a retention/compaction policy.
- SYA-E01 (bug): sign-out wipes data even when the final push failed (offline); decide between warn-and-confirm, block, or accept.
- SYA-E02 (bug): sign-out during an in-flight cycle can drop the final push.
- SYA-E04 / SYA-09: RESTORING screen has no progress, no timeout and no sign-out escape while waiting.
- SYA-E05 (PROPOSED): accounts whose cloud profile lacks `unit` land on "Couldn't restore your data"; proposed fallback is onboarding prefilled from the cloud profile.
- SYA-E09 (PROPOSED): device settings in UserDefaults (theme, rest timer, reminders, calorie formula, summary toggles, `autoShareToFeed`) neither sync nor clear on account switch; docs/sync-architecture.md says preferences and privacy sync, code does not. Decide: sync them, clear them, or document as per-device.
- SYS-30: no sync on/off, Wi-Fi-only or pending-item list (architecture says sync is always on); confirm no controls are wanted.
- SYX-E02 / SYX-E03 (PROPOSED): import dedupe is local-only; app JSON export is not a restore path.
- Doc/code disagreement: `docs/sync-architecture.md` still says "implementation in progress" and lists `users/{uid}.settings{}` and `privacy{}` in the sync model; the engine writes neither.
