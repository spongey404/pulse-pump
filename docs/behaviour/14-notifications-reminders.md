# 14 Notifications and reminders

Scope: local notifications only (workout reminders, rest-day alerts, rest-timer-end), the OS permission prompt and denied state, the Settings switches that control them, the app-icon badge, and the in-app Activity bell. Remote/push notifications are not built.
Key sources: `Ore/Core/Services/Notifications/NotificationService.swift`, `SystemRestEndNotifier.swift`, `RestEndNotifying.swift`, `Ore/Features/Settings/SettingsView.swift` (NOTIFICATIONS section, split save), `Ore/App/RootView.swift:87-97`, `Ore/App/OreApp.swift` (`AppDelegate`), `Ore/Features/Workout/Services/RestTimerService.swift`, `Ore/Features/Social/Friends/ActivityView.swift`, `Features/Social/Feed/ActivityFeedView.swift`.

Defaults: `workoutReminders` = off, `restDayAlerts` = off (both `@AppStorage`, device-local, not synced). Workout reminder time is hard-coded 08:00 local time; rest-day alert time is hard-coded 10:00; neither is user-configurable. Notification identifiers: `com.pulse.PulsePump.workout.weekday.N`, `com.pulse.PulsePump.rest.weekday.N` (N 1=Sun..7=Sat), `com.pulse.PulsePump.restTimerEnd`.

## NTF  Permission, reminders, rest-end notification, badge

| ID | User does → App does (observable result) | Status | Manual check | Tests |
|---|---|---|---|---|
| NTF-03 | System: first time the user reaches the main app after onboarding/sign-in → App asks the iOS notification permission (alert, sound, badge) without any pre-prompt screen (`RootView.swift:95`) | ✅ | [ ] | — |
| NTF-06 | System: every later time the main route is entered (cold launch, sign-in) → App calls the permission request again (iOS shows nothing once answered) and then reschedules reminders from the current split | ✅ | [ ] | — |
| NTF-09 | User opens Settings › NOTIFICATIONS → App shows rows "Workout Reminders" (switch), "Rest Day Alerts" (switch), "Social Activity" (value "COMING SOON", not tappable), "Challenge Updates" (value "COMING SOON", not tappable) | ✅ | [ ] | — |
| NTF-12 | User turns "Workout Reminders" on and has permission → App stores the switch and schedules one weekly repeating notification per training day of the current split at 08:00 local time | ✅ | [ ] | — |
| NTF-15 | System: a workout reminder fires → Device shows title "Time to train", body "<day label> — let's go." (for example "Push Day — let's go."), default sound | ✅ | [ ] | — |
| NTF-18 | User turns "Workout Reminders" off → App cancels all seven workout reminder identifiers | ✅ | [ ] | — |
| NTF-21 | User turns "Rest Day Alerts" on and has permission → App schedules a weekly repeating notification at 10:00 local time on every weekday that is NOT a training day in the split | ✅ | [ ] | — |
| NTF-24 | System: a rest-day alert fires → Device shows title "Rest day" and a body cycled by position among rest days from: "Rest day — recovery is where gains are made.", "Rest day — sleep well, eat well.", "Rest day — your muscles are growing.", "Active recovery day — a walk counts." | ✅ | [ ] | — |
| NTF-27 | User turns "Rest Day Alerts" off → App cancels all seven rest-day identifiers | ✅ | [ ] | — |
| NTF-30 | User has no split (or "No fixed split") and turns Rest Day Alerts on → App schedules nothing (no schedule means no rest days, to avoid alerting on training days) | ✅ | [ ] | — |
| NTF-33 | User has no split and turns Workout Reminders on → App schedules nothing; the switch stays on with no explanation | 🟡 no UI hint that a split is required | [ ] | — |
| NTF-36 | User saves a new split in Settings › Training Split → App updates the split's days and reschedules both reminder types (cancel then add) (`SettingsView.swift:320-323`) | ✅ | [ ] | — |
| NTF-39 | User finishes onboarding with a split → App schedules on first entry to the main app if the switches are on (they default off, so nothing is scheduled until the user opts in) | ✅ | [ ] | — |
| NTF-42 | User trains on a day with a reminder already completed → App still fires the reminder; there is no check for "already trained today" | 🧭 PROPOSED: acceptable for v1; later skip when a workout is logged that day | [ ] | — |
| NTF-45 | User taps a delivered reminder → App simply opens (no deep link, no `UNUserNotificationCenterDelegate`) | ✅ | [ ] | — |
| NTF-48 | User starts a rest timer in a workout (autoStart or manual start) → App schedules a one-shot local notification for the end of the rest, replacing any previous one (`SystemRestEndNotifier`) | ✅ | [ ] | — |
| NTF-51 | System: rest ends while the app is backgrounded or the screen is locked → Device shows title "Rest done", body "Log your next set", with the default sound unless the Timer Alert setting is "Silent" | ✅ | [ ] | — |
| NTF-54 | System: rest ends while the app is in the foreground → iOS shows no banner (no presentation delegate); the in-app alert plays per Settings › Timer Alert (Sound, Vibration, Sound & Vibration, Silent) | ✅ | [ ] | — |
| NTF-57 | User adjusts rest by +15 s / -15 s (Live Activity buttons) → App reschedules the notification to the new end time; if the new time is already past, the rest completes at once and the alert plays | ✅ | [ ] | — |
| NTF-60 | User skips, dismisses, logs another set (new rest) or finishes/discards the workout → App cancels the pending rest notification and removes any delivered one (`stop()` -> `cancelRestEnd`) | ✅ | [ ] | — |
| NTF-63 | User returns to the app after the rest ended in the background → App does not buzz again (alert only if the end was within 2 s) and shows the rest as complete | ✅ | [ ] | — |
| NTF-66 | System: user opens the app (becomes active) → App clears the icon badge to 0 (`AppDelegate.applicationDidBecomeActive`) | ✅ | [ ] | — |
| NTF-69 | User views the Social tab bell → App shows a small accent dot on the bell when `inboxCount > 0` (friend requests waiting + pending challenge invites); no number and no tab-bar badge; it is an in-app indicator only, not a notification | ✅ | [ ] | — |
| NTF-72 | User opens the bell (ACTIVITY screen) → App lists real "Needs You" items (friend requests with accept/decline, challenge invites); with none it shows "NOTHING NEEDS YOU RIGHT NOW"; there is no history of past events | ✅ | [ ] | — |
| NTF-75 | System: someone likes, comments on, or follows the user, or a challenge changes → App sends no push notification and shows no in-app event (no remote notification pipeline) | ❌ not built | [ ] | — |
| NTF-78 | System: weekly recap on Monday → App sends no notification (spec calls for a Monday local recap notification) | ❌ not built (`docs/pulse-pump-spec.md:429`) | [ ] | — |
| NTF-81 | System: neglected-muscle nudge (Supernova quiet badge) → Not delivered as any notification | ❌ not built | [ ] | — |

### NTF edge cases

| ID | Situation | What the app does | Why/notes | Status | Manual check | Tests |
|---|---|---|---|---|---|---|
| NTF-E01 | Permission denied at the first prompt | No reminders ever schedule (status must be authorized or provisional); the rest-end notification is silently dropped; in-app timer alerts still work | `NotificationService.swift:36-38` | ✅ | [ ] | — |
| NTF-E02 | Permission denied and user switches Workout Reminders or Rest Day Alerts on | Switch stays ON but nothing is scheduled; no message and no link to iOS Settings (the "off" branch runs cancel) | `SettingsView.swift:216-227` | 🐞 expected: switch reverts or shows "Notifications are off, open Settings"; actual: misleading ON state | [ ] | — |
| NTF-E03 | User enables notifications later in iOS Settings, switches already ON | Reminders are scheduled at the next app launch to the main screen (reschedule on entry); not immediately on return from iOS Settings | | 🟡 up to one relaunch delay | [ ] | — |
| NTF-E04 | User revokes permission in iOS Settings | Pending notifications are not delivered by iOS; app switch state is unchanged | | 🟡 switches may show ON while denied | [ ] | — |
| NTF-E05 | Permission prompt shown at the very first main screen, with no context | User sees a bare system prompt right after onboarding | Docs audit flagged prompting too early | 🧭 PROPOSED: ask when the user first turns a reminder switch on, not at launch | [ ] | — |
| NTF-E06 | Timezone change / travel | Reminders use floating local-time calendar triggers (weekday + hour), so they fire at 08:00/10:00 of the new local time; no reschedule needed | | ✅ | [ ] | — |
| NTF-E07 | DST change | Calendar triggers follow wall-clock time; the notification stays at 08:00/10:00 | | ✅ | [ ] | — |
| NTF-E08 | Weekday numbering | Split `dayOfWeek` uses Calendar convention 1=Sunday..7=Saturday; used directly as the trigger weekday. A week starting on Monday in the UI does not change the trigger | `SplitSchedule.swift:7` | ✅ | [ ] | — |
| NTF-E09 | Split with two sessions on the same weekday | Both map to one identifier per weekday, so one reminder per weekday; the last day's label wins | | 🟡 | [ ] | — |
| NTF-E10 | Split edited anywhere other than Settings › Training Split (including a split pulled from another device by sync) | Reminders are not rescheduled until the next main-screen entry; only the Settings split save triggers a reschedule | Programs/sync do not call `reschedule` | 🟡 stale schedule until relaunch | [ ] | — |
| NTF-E11 | Split cleared to "No fixed split" | Reschedule runs, finds no days, so both kinds are cancelled | | ✅ | [ ] | — |
| NTF-E12 | Sign-out then another account signs in | Old account's reminders keep firing until the new account reaches the main screen and reschedules; the switches persist across accounts on the device | See 01 SOUT-E03 | 🐞 expected cancel on sign-out | [ ] | — |
| NTF-E13 | Rest shorter than about half a second | No notification scheduled (`interval > 0.5` guard) | | ✅ | [ ] | — |
| NTF-E14 | Rest started with the app force-quit later | iOS keeps the pending time-interval notification; it fires at the end of the rest even if the app was killed | | ✅ | [ ] | — |
| NTF-E15 | Rest timer mode Manual | Notification is still scheduled whenever the user starts the timer manually; with Auto-Start, each logged set restarts it | | ✅ | [ ] | — |
| NTF-E16 | Time-sensitive interruption level for "Rest done" | Code sets `.timeSensitive` but the entitlements file has no time-sensitive entitlement, so iOS treats it as a normal notification and Focus modes can suppress it | `SystemRestEndNotifier.swift:20` | 🟡 entitlement missing | [ ] | — |
| NTF-E17 | Do Not Disturb / Focus on | iOS suppresses the banner and sound per the user's Focus rules; app has no override | | ✅ | [ ] | — |
| NTF-E18 | Silent alert type | "Rest done" notification delivered without sound; the banner still shows | | ✅ | [ ] | — |
| NTF-E19 | Vibration-only alert type | Notification sound is the default (only "Silent" removes it); the vibration setting affects only the in-app alert | | 🟡 setting names suggest otherwise | [ ] | — |
| NTF-E20 | Delivered rest notification left in Notification Centre | Removed when the next rest starts or stops | | ✅ | [ ] | — |
| NTF-E21 | Remote push readiness | Entitlement `aps-environment = development` and background mode `remote-notification` are present, but the app never registers for remote notifications and no Cloud Function sends messages | Release builds need `production` | 🧭 PROPOSED: decide whether social push ships in v1; if not, drop the entitlement/background mode | [ ] | — |
| NTF-E22 | Supernova vs free | Reminders and rest-end notifications are free; no gating | Spec lists workout reminders as free | ✅ | [ ] | — |
| NTF-E23 | Notification settings across devices | Switches are `@AppStorage` on one device and are not synced; a new device starts with both off | | 🟡 | [ ] | — |
| NTF-E24 | "Social Activity" and "Challenge Updates" rows | Shown as non-interactive "COMING SOON" (earlier stored-but-unused switches were replaced) | Commit 1ce3ca6 | ✅ | [ ] | — |
| NTF-E25 | Hard-coded reminder times | 08:00 workout and 10:00 rest cannot be changed in the UI; the service takes hour/minute parameters but Settings never passes them | | 🧭 PROPOSED: add a single "Reminder time" row | [ ] | — |

## Open decisions for the owner (14)

- NTF-42 (🧭): skip a reminder when a workout is already logged that day; proposed to leave for later.
- NTF-E05 (🧭): move the permission prompt from launch to the moment the user first enables a reminder.
- NTF-E21 (🧭): ship remote push (likes/comments/follows/challenges, FCM) in v1 or remove the APNs entitlement and `remote-notification` background mode.
- NTF-E25 (🧭): configurable reminder time (currently 08:00 workout, 10:00 rest day).
- NTF-E02 (bug): denied permission leaves the switches ON with no feedback.
- NTF-E12 (bug): sign-out does not cancel pending reminders or clear the switches (also 01 SOUT-E03).
- NTF-E16: add the time-sensitive notifications entitlement or drop the `.timeSensitive` level.
- NTF-E19: clarify Timer Alert semantics for the background notification (sound follows "not Silent" only).
- NTF-75, NTF-78, NTF-81: social push, weekly recap notification, neglected-muscle nudge are specified in `docs/pulse-pump-spec.md` but not built.
- NTF-E10: reschedule reminders whenever the split changes from any source (Programs, sync).
