# 12 Cloud sync and your data

## What it's for
Ore saves everything on the phone first, so it works offline, and then quietly backs it up to your account. That means a new phone, a reinstall or a second device gets your workouts, programs and settings back.

## The flow
1. Finish a workout → about 5 seconds later it's backed up. You don't do anything.
2. Open More › Settings › Cloud Sync → Status reads UP TO DATE, and Last Synced reads NOW or "5 MINUTES AGO".
3. Turn on airplane mode and log a workout → Status reads "1 CHANGE WAITING", then OFFLINE · WILL SYNC WHEN CONNECTED.
4. Turn airplane mode off and reopen the app → it syncs and returns to UP TO DATE.
5. Install Ore on a second phone (or reinstall) → sign in → "Restoring your data…" → your workouts, programs, splits, equipment, custom exercises and bodyweight are back.

**Alternate paths**
- **Sync now:** Settings › Cloud Sync › Sync Now → SYNCING… then UP TO DATE.
- **Two phones:** edit on phone A → open phone B → the change appears.
- **Delete a workout:** it disappears on your other devices too.
- **Something fails:** Status shows SYNC PROBLEM with a message; the app keeps retrying on its own.

**What is and isn't backed up**
- Backed up: profile, finished workouts, programs, splits, equipment, custom exercises, bodyweight, smart-suggestion goals.
- Not backed up: an unfinished draft (it lives only on the phone that started it), widget setup, and device settings such as theme, rest timer, calorie formula, reminders and auto-share.

## Not working / not built yet
- Signing out while offline (or mid-sync) can permanently lose unsynced changes; the alert says they're safe. (broken)
- The restore screen has no progress, timeout or way out.
- Accounts made by older builds can land on "Couldn't restore your data".
- If one item can never sync, the app retries forever and you can't see which item it is.
- Device settings neither sync nor reset when another account signs in on the phone.
- No on/off switch, Wi-Fi-only option or list of waiting items (by design, sync is always on).

## Decide
- **Sync is free or Plus:** covered by README decision 1 (recommended: sync and backup stay free).
- **Sign-out safety:** covered by README decision 3.

## Rules I'll apply
- If a sync attempt takes over 30 seconds it counts as offline and retries later.
- When the same item is changed on two phones, the most recent change wins for the whole item.
- Your unit and privacy choices sync with your account; theme, rest timer and reminders stay per device and are cleared when a different account signs in.
- Items the server rejects are skipped so everything else still syncs, and Settings shows how many were skipped.
- Older accounts that can't restore go through onboarding pre-filled from the cloud profile.
