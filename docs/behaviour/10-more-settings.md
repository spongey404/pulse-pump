# 10 More hub, Settings, units, equipment, import/export, Supernova screen, tutorial

Scope: the More tab (tab 4) and everything one tap below it. Source: `Ore/Features/More/MoreTabView.swift`, `PrivacyLegalView.swift`, `Ore/Features/Settings/{SettingsView,EditProfileView,DataExportView,CloudSyncSection}.swift`, `Ore/Features/Equipment/EquipmentProfilesView.swift`, `Ore/Features/Supernova/{SupernovaView,SupernovaService}.swift`, `Ore/Features/Tutorial/*`, `Ore/Features/Widgets/WidgetsView.swift`, `Ore/Core/Persistence/{DataImportService,DataExportService}.swift`, `Ore/Core/Services/Notifications/NotificationService.swift`, `OreShared/WeightUnit.swift`.

Navigation model: More is a single view with an internal `screen` enum (hub, history, profile, settings, equipment, supernova, weeklyRecap, dataImport, privacy, widgets); every sub-screen has its own back chevron that returns to the hub. Supernova is presented as a full-screen cover. History, Profile, Weekly Recap and Delete Account/Sign Out internals are specified in other files (05, 09, 01); this file only specifies the entry rows.

Not in this app (the brief asked about them): there is NO week-start setting (Home and Weekly Recap hard-code Monday via `WeekMath.mondayWeekStart` and `calendar.firstWeekday = 2`; widgets use the device calendar). There is NO default rest time (compound / isolation) setting UI even though `RestTimerService` reads `compoundRestSeconds` / `isolationRestSeconds` from UserDefaults (never written). There is NO reminder-time setting (fixed 08:00 workout, 10:00 rest day). The standalone Plate Calculator and Warm-up generator screens exist but are unreachable (see TOL).

## MOR  More hub

| ID | User does → App does (observable result) | Status | Manual check | Tests |
|---|---|---|---|---|
| MOR-03 | User taps the More tab → App shows title "MORE", a tappable user header (avatar, name, "@handle · SPLIT NAME" in small caps), a 4-cell stats strip (WORKOUTS, STREAK as "{n}D", FRIENDS, FANS), and (free plan only) a blue banner "UNLOCK SUPERNOVA" / "SMART SUGGESTIONS · CLOUD SYNC · ANALYTICS". | ✅ MoreTabView.swift:77-142 | [ ] | — |
| MOR-06 | System: hub appears → App refreshes subscription status, then loads the social profile and friend graph and pushes own streak and workout count to the social profile. | ✅ MoreTabView.swift:135-141 | [ ] | — |
| MOR-09 | User taps the user header → App opens Profile (screen `.profile`), which has an "EDIT" button into Edit Profile. | ✅ MoreTabView.swift:156 | [ ] | — |
| MOR-12 | User views the TRAINING section → App lists History (value = finished workout count), Equipment Profiles (value = first profile's name uppercased, blank if none), Weekly Recap (value "WK n" from the device calendar week of year), Widgets (outlined tag "SUPERNOVA"). | ✅ MoreTabView.swift:96-105 | [ ] | — |
| MOR-15 | User taps "Widgets" as a subscriber or inside the 14-day trial → App opens the Widgets library (WGE). As a free user after the trial → App opens the Supernova paywall. | ✅ MoreTabView.swift:103-105 | [ ] | — |
| MOR-18 | User views the ACCOUNT section → App lists Settings and "Supernova" with value "FREE" or "ACTIVE". The value and the banner use `!isSubscribed` only, so during the free trial the hub says "FREE" and still shows "UNLOCK SUPERNOVA" although Plus features are unlocked. | 🟡 MoreTabView.swift:75,109 (trial ignored) | [ ] | — |
| MOR-21 | User views the HELP section → App lists Tutorial, "Data Import" (value "STRONG · HEVY"), "Privacy & Legal", and a red "Sign Out". | ✅ MoreTabView.swift:112-120 | [ ] | — |
| MOR-24 | User taps "Sign Out" → App shows an alert "Sign Out": "This removes your data from this device. It stays safe in your account and comes back when you sign in." with Cancel / Sign Out (destructive). Confirm calls `session.signOut()` (flow in 01 SOUT). | ✅ MoreTabView.swift:127-134 | [ ] | — |
| MOR-27 | User taps any sub-screen's back chevron → App returns to the hub with a 0.22 s ease animation. | ✅ MoreTabView.swift:42 | [ ] | — |
| MOR-30 | System: a locked-widget "UNLOCK SUPERNOVA" tap (`pulsepump://supernova`) → App switches to the More tab and opens Supernova full screen. | 🟡 works when the app is running; dropped on cold launch (notification observed only by ContentView) | [ ] | — |
| MOR-33 | System: tutorial is active and its step points at More → App forces the More screen to Equipment, Settings or hub according to the step. | ✅ MoreTabView.swift:64-71 | [ ] | — |

### MOR edge cases

| ID | Situation | What the app does | Why/notes | Status | Manual check | Tests |
|---|---|---|---|---|---|---|
| MOR-E01 | New user with no equipment profile | Equipment row value is blank. | | ✅ | [ ] | — |
| MOR-E02 | Weekly Recap "WK n" vs recap's own week | Hub uses `Calendar.current` week of year (locale first weekday); the recap screen uses a Monday-first calendar. They can disagree around Sunday/Monday in US locale. | | 🟡 MoreTabView.swift:149-151 vs WeeklyRecapView.swift:21,53 | [ ] | — |
| MOR-E03 | Offline | Hub renders from local data; friend/fan counts keep last values; social load fails silently. | | ✅ | [ ] | — |
| MOR-E04 | No local user | Header shows "?" initial / name "Athlete". | | ✅ MoreTabView.swift:158-160 | [ ] | — |

## SCF  Settings rows

Settings (More › Settings) is a scrolling ledger list with section labels. Rows in order:

| ID | User does → App does (observable result) | Status | Manual check | Tests |
|---|---|---|---|---|
| SCF-03 | User opens Settings → App shows ACCOUNT: "Edit Profile" (chevron), "Email" (read-only, shows "—" if none), "Signed In With" (provider, read-only), "Username" (value "@name" or "—"). | ✅ SettingsView.swift:104-111 | [ ] | — |
| SCF-06 | User taps "Edit Profile" → App pushes a form with Name, Weight (unit label), Height (cm, or Feet + Inches in lbs mode) and Age; "Save" is disabled when the name is blank. | ✅ EditProfileView.swift | [ ] | — |
| SCF-09 | User saves Edit Profile after changing weight → App converts the typed value to kg, saves it only if the field text changed, and logs a bodyweight entry. Untouched fields never rewrite the stored kg/cm (no rounding drift). Weight 0 or unparseable is ignored; blank age keeps the old age. | ✅ EditProfileView.swift:80-103 | [ ] | — |
| SCF-12 | User taps "Username" → App opens the change-username sheet (rules and uniqueness in 01 HND). | ✅ SettingsView.swift:109-111,82-84 | [ ] | — |
| SCF-15 | User opens UNITS & MEASUREMENTS › "Weight Unit" → App shows a menu "Kilograms (kg)" / "Pounds (lbs)" (see UNT). | ✅ SettingsView.swift:115-118 | [ ] | — |
| SCF-18 | User changes "Gender" (Male, Female, Non-binary / Other, Prefer not to say) or "Experience Level" (New to lifting, Some experience, Advanced lifter) → App saves to the user and marks it updated. Audit note: experience/gender/age feed nothing visible except calorie inputs elsewhere. | 🟡 stored, little consumed | [ ] | — |
| SCF-21 | User opens WORKOUT › "Calorie Formula" → App offers "Basic (set-based)" for everyone and also "MET-Based" for subscribers and trial users. A free user after the trial sees only Basic. | ✅ SettingsView.swift:130-132 | [ ] | — |
| SCF-24 | User selects "MET-Based" and then the trial ends or the subscription lapses → App keeps the stored choice and the workout code still computes the MET estimate (`isSubscribed` defaults to true at the call sites). The gate exists only in the menu. | 🐞 WorkoutViewModel.swift:204,318 and CalorieEstimationService.swift:53 (expected fall back to Basic when not entitled) | [ ] | — |
| SCF-27 | User opens "Rest Timer Mode" → App offers "Auto-Start" (default), "Manual", "Auto-Start with Dismiss". Stored in UserDefaults `restTimerMode`, read by `RestTimerService`. This row is the tutorial spotlight target "rest-movement-defaults". | ✅ SettingsView.swift:133-135 | [ ] | — |
| SCF-30 | User opens "Timer Alert" → App offers "Sound" (default), "Vibration", "Sound & Vibration", "Silent (Visual Only)". | ✅ SettingsView.swift:136-137 | [ ] | — |
| SCF-33 | User looks at "Smart Weight Suggestions" → App shows a non-interactive row with value "COMING SOON". (`smartWeightSuggestion` exists in the view model but is not wired to the logger.) | ❌ not built | [ ] | — |
| SCF-36 | User opens PRIVACY › "Profile Visibility" → App offers the privacy levels for the profile row (Everyone, Friends only, Only me per `PrivacyLevel`); choosing one saves it locally, to `users/{uid}.privacy` and to the public profile. Defaults: Workout posts = friends only, Body map = friends only, Global leaderboards = visible, Profile = everyone. Only the Profile row is in Settings; the other three rows are on the Friends › Activity screen. | ✅ SettingsView.swift:144-145, PrivacyLevel.swift:60-110 | [ ] | — |
| SCF-39 | User toggles "Auto-Share to Feed" → App flips `autoShareToFeed` (default ON). The post-workout screen reads it to decide whether to auto-post (see 03 PST). | ✅ SettingsView.swift:146 | [ ] | — |
| SCF-42 | User opens APPEARANCE › "Theme" → App offers System (default), Light, Dark; the whole app re-themes immediately (`preferredColorScheme` at the scene root). | ✅ SettingsView.swift:150-151, OreApp.swift:64-91 | [ ] | — |
| SCF-45 | User looks at "Simple Body Map" → App shows "COMING SOON" (non-interactive). | ❌ not built | [ ] | — |
| SCF-48 | User opens TRAINING › "Training Split" → App pushes the split list (flow SPL in 07). The row value is the current split name uppercased, or blank. | ✅ SettingsView.swift:156-157 | [ ] | — |
| SCF-51 | User looks at NOTIFICATIONS › "Social Activity" and "Challenge Updates" → App shows "COMING SOON" (non-interactive). | ❌ not built (no push pipeline, see 14) | [ ] | — |
| SCF-54 | User opens DATA › "Import / Export Data" → App swaps the settings content for the Import / Export screen (IMP/EXP). "Equipment Profiles" swaps in the Equipment screen (EQP). Back returns to Settings. | ✅ SettingsView.swift:57-66,168-169 | [ ] | — |
| SCF-57 | User views CLOUD SYNC → App shows rows "Status" (text such as "Up to date", "N changes waiting", "Syncing…", "Restoring your data…", "Offline — will sync when connected", "Sync problem: ...", "Sign in to sync"), "Last Synced" ("NEVER" or relative time) and "Sync Now" (disabled look when sync is not running; taps do nothing while syncing). Cloud sync is available to every signed-in user, not only Supernova. | ✅ CloudSyncSection.swift, SyncService.swift:369-378; gating mismatch see 13 GAT | [ ] | — |
| SCF-60 | User views ABOUT › "Version" → App shows `CFBundleShortVersionString` (fallback "1.0"). | ✅ SettingsView.swift:176-178 | [ ] | — |
| SCF-63 | User taps red "Sign Out" → App shows the same sign-out alert as the hub (MOR-24). | ✅ SettingsView.swift:76-81,182 | [ ] | — |
| SCF-66 | User taps red "Delete Account" → App starts the delete-account flow (01 DEL). | ✅ SettingsView.swift:184,85 | [ ] | — |
| SCF-69 | User looks for a setting for week start, default rest times, reminder times, post-workout summary fields, or email/password change → App has none. `PostWorkoutCustomizationView` (toggles for duration, calories, muscles, PRs, improvement) is compiled but never presented. | ❌ not built / unreachable (SettingsView.swift:255) | [ ] | — |

### SCF edge cases

| ID | Situation | What the app does | Why/notes | Status | Manual check | Tests |
|---|---|---|---|---|---|---|
| SCF-E01 | Settings opened with no local user | The sections are not rendered (blank screen below the header). | `if let user` guard. | 🟡 SettingsView.swift:93 | [ ] | — |
| SCF-E02 | Profile visibility change fails (offline) | Handled in `SocialViewModel.setPrivacy`; the local menu value follows `privacyService.settings`. Final behaviour belongs to 09 PRF. | | 🧭 | [ ] | — |
| SCF-E03 | Locale uses decimal comma in weight / height / age fields | `parseDecimal` / `parseKg` accept the locale decimal; height cm uses `String(format: "%g")` for display. | | ✅ EditProfileView.swift | [ ] | — |
| SCF-E04 | Weight typed as negative or 0 | Ignored (kg must be > 0); no error message. | | ✅ EditProfileView.swift:81 | [ ] | — |
| SCF-E05 | Height typed in lbs mode with feet only | Inches default to 0. | | ✅ | [ ] | — |
| SCF-E06 | Two devices change theme | Theme is per-device `@AppStorage`; not synced. Weight unit, gender, experience sync with the user record. | | ✅ | [ ] | — |

## UNT  Units

| ID | User does → App does (observable result) | Status | Manual check | Tests |
|---|---|---|---|---|
| UNT-03 | User switches Weight Unit to "Pounds (lbs)" → App changes display and typed-input interpretation everywhere (logger fields, history, PRs, charts, plates, recap, exports excluded) without touching any stored value. Widgets are refreshed with the new unit. | ✅ SettingsView.swift:115-118, RootView.swift:78-81, WeightUnit.swift | [ ] | — |
| UNT-06 | System: unit changes → App mirrors the preference into UserDefaults `weightUnit` for code without view access (services, Live Activity). | ✅ RootView.swift:74-79 | [ ] | — |
| UNT-09 | User types weights in lbs → App converts to kg for storage (x 0.45359237); display rounds lb to the nearest 0.5 and kg to 0.01 (100 kg shows 220.5 LB). Steppers move 2.5 kg or 5 lb. | ✅ WeightUnit.swift | [ ] | — |
| UNT-12 | User creates an equipment profile in lbs mode → App stores the default lb plate set (45/35/25/10/5/2.5 lb, converted to kg). | ✅ EquipmentProfilesView.swift:382 | [ ] | — |
| UNT-15 | User exports data in lbs mode → App writes kg regardless, with `weightUnit: "kg"` (JSON) and a `Unit` column (CSV). | ✅ DataExportService.swift | [ ] | — |
| UNT-18 | User imports a file → App uses the unit named in the weight column header if present, else the "File Weight Unit" menu, else (Strong) the user's preference, (Hevy) kg. | ✅ DataImportService.swift:85-99,137 | [ ] | — |

### UNT edge cases

| ID | Situation | What the app does | Why/notes | Status | Manual check | Tests |
|---|---|---|---|---|---|---|
| UNT-E01 | Switch kg → lbs → kg repeatedly | Stored kg never changes; display round-trips. | Invariant: stored = kg. | ✅ | [ ] | — |
| UNT-E02 | Height | Always stored cm; lbs mode shows ft + in input. | | ✅ | [ ] | — |
| UNT-E03 | Widget and Live Activity in the other unit | Snapshot carries `weightUnit`; refreshed after unit change. Live Activity text for an in-progress workout may keep the old unit until next update. | | 🟡 not verified | [ ] | — |

## NTS  Reminders and notifications

| ID | User does → App does (observable result) | Status | Manual check | Tests |
|---|---|---|---|---|
| NTS-03 | System: first arrival at the main shell → App asks for notification permission immediately (before the user has toggled anything) and then reschedules reminders. iOS shows its system prompt once. | ✅ RootView.swift:87-97 (prompt at launch rather than at toggle; audit asked to move it) | [ ] | — |
| NTS-06 | User turns ON "Workout Reminders" → App stores the toggle, requests permission and schedules a weekly repeating local notification at 08:00 on each weekday of the split ("Time to train" / "{day label} — let's go."). With no split days, nothing is scheduled. | ✅ SettingsView.swift:214-228, NotificationService.swift:30-61 | [ ] | — |
| NTS-09 | User turns ON "Rest Day Alerts" → App schedules a weekly notification at 10:00 on every weekday NOT in the split ("Rest day" with one of 4 rotating messages). With no split, nothing is scheduled. | ✅ NotificationService.swift:66-108 | [ ] | — |
| NTS-12 | User turns a reminder toggle OFF → App cancels the pending notifications for that kind. | ✅ SettingsView.swift:223,239 | [ ] | — |
| NTS-15 | User denies the permission prompt after toggling ON → App leaves the toggle ON but cancels/schedules nothing; there is no message or deep link to iOS Settings. | 🐞 SettingsView.swift:216-225 (expected toggle reverts or shows "Notifications are off in iOS Settings") | [ ] | — |
| NTS-18 | User changes the training split → App reschedules both reminder kinds. | ✅ SettingsView.swift:323 | [ ] | — |
| NTS-21 | User looks for a reminder-time setting → App has none: workout reminders fire at a fixed 08:00 and rest-day alerts at 10:00 device-local time. | 🧭 PROPOSED: add a time picker per reminder (default unchanged) | [ ] | — |

## EQP  Equipment profiles

| ID | User does → App does (observable result) | Status | Manual check | Tests |
|---|---|---|---|---|
| EQP-03 | User opens Equipment (hub row or Settings › DATA) → App shows header "EQUIPMENT" with a "+" button. With no profiles: "NO PROFILES YET" / "Create a profile for your gym to track available equipment." and a "CREATE PROFILE" button. New users start with none (onboarding creates no profile). | ✅ EquipmentProfilesView.swift:278-301 | [ ] | — |
| EQP-06 | User taps "+" or "CREATE PROFILE" → App opens a sheet "New Profile": Name field (placeholder "e.g. Home Gym"), Available Equipment list with every equipment type pre-checked, Cancel / Save. Save is disabled for a blank name. | ✅ EquipmentProfilesView.swift:334-391 | [ ] | — |
| EQP-09 | User taps Save → App stores the profile with the chosen equipment and the unit's default plates, closes the sheet, and the profile appears as a tab. | ✅ EquipmentProfilesView.swift:378-386 | [ ] | — |
| EQP-12 | System: one or more profiles → App shows a 2-column grid of profile tabs (names uppercased, one line), an accent-tinted "ACTIVE PROFILE" badge, the sorted equipment list with ticks, and "AVAILABLE PLATES" (a barbell drawing and size chips like "20KG"). Selecting a tab only changes which profile is displayed. | 🟡 "ACTIVE" is simply the selected tab; no persisted active profile (EquipmentProfilesView.swift:104-119) | [ ] | — |
| EQP-15 | User taps "Add Equipment" or the pencil on an equipment row → App does nothing (`DashedAdd` has an empty action; the pencil is decorative). | ❌ EquipmentProfilesView.swift:147,271 | [ ] | — |
| EQP-18 | User looks to rename or delete a profile, or edit its plates → App offers no way. | ❌ not built | [ ] | — |
| EQP-21 | System: active workout plate calculator → App uses the default plate set for the unit (`PlateMath.storedPlatesKg`), not the selected equipment profile. Equipment profiles also do not filter substitutions. | ❌ profile data is stored but not consumed by any other feature | [ ] | — |
| EQP-24 | User is on the free plan and creates many profiles → App allows any number. Spec lists "unlimited equipment profiles" as a Supernova module on the paywall (SupernovaFeature) but there is no limit. | 🟡 see 13 GAT | [ ] | — |

### EQP edge cases

| ID | Situation | What the app does | Why/notes | Status | Manual check | Tests |
|---|---|---|---|---|---|---|
| EQP-E01 | Duplicate profile names | Allowed; tabs show identical labels. | | 🟡 | [ ] | — |
| EQP-E02 | Profile with all equipment unchecked | Allowed; screen shows an empty equipment section. | | ✅ | [ ] | — |
| EQP-E03 | Sign-out wipe | Profiles are deleted locally and restored from the cloud on next sign-in. | SyncLifecycle.swift:75. | ✅ | [ ] | — |
| EQP-E04 | Tutorial gym-profile steps | Spotlight "profile-toggle" and "plate-grid" only exist when at least one profile exists. | | 🟡 | [ ] | — |

## IMP  Import (Strong / Hevy)

| ID | User does → App does (observable result) | Status | Manual check | Tests |
|---|---|---|---|---|
| IMP-03 | User opens More › "Data Import" (or Settings › Import / Export Data) → App shows the same screen titled "IMPORT / EXPORT" with the intro "Export your workout data to keep a backup or use in other apps.", IMPORT rows "Import from Strong" and "Import from Hevy" (value "CSV"), "File Weight Unit" menu, and an explanatory line. | ✅ DataExportView.swift:30-70,175-178 | [ ] | — |
| IMP-06 | User taps "Import from Strong" or "Hevy" → App opens the iOS file picker limited to CSV and plain text. | ✅ DataExportView.swift:45-50,84 | [ ] | — |
| IMP-09 | User picks a file → App reads it as UTF-8 and imports. Strong columns: Date, Workout Name, Exercise Name, Set Order (number, W warm-up, D drop, F failure), Weight, Reps, Distance, Seconds, RPE. Hevy columns: title, start_time, end_time, exercise_title, set_type, weight_kg/weight_lbs, reps, distance_km, duration_seconds, rpe. RPE becomes RIR = 10 − RPE (clamped 0-10). Workouts are grouped by date + title. | ✅ DataImportService.swift:94-165 | [ ] | — |
| IMP-12 | System: import finishes → App shows alert "Import Complete" with lines like "Strong: Imported 12 workouts (180 sets) · 2 already imported · 3 rows skipped · 4 new custom exercises." plus "N warm-up sets were kept but are not counted in stats.", up to 5 unmatched exercise names ("Not in the library (added as custom): ..."), and "e.g. {first error}". | ✅ DataExportView.swift:92-108, DataImportService.swift:49-55 | [ ] | — |
| IMP-15 | User re-imports the same file → App creates nothing new (per-set key = second-precision date + normalized exercise + set order); message reports "N already imported". | ✅ DataImportService.swift:170-234 | [ ] | — |
| IMP-18 | System: row has an unreadable date or no exercise name → App skips it and records "Row N: unreadable date '...'" / "missing exercise name" (first 20 reasons kept). Sets with weight 0, reps 0 and no time/distance are skipped as "empty set". | ✅ DataImportService.swift:104-110,217-220 | [ ] | — |
| IMP-21 | System: exercise names → App matches the catalogue by normalized name, also trying "Equipment Name" and the base name for Strong style "Bench Press (Barbell)"; built-ins win. Unknown names create custom exercises (no muscles, isApproved false). | ✅ DataImportService.swift:268-317 | [ ] | — |
| IMP-24 | User picks a file with only a header or empty → App reports "Imported 0 workouts (0 sets)" in the same "Import Complete" alert. | 🟡 DataImportService.swift:97,135 (no "nothing to import" message) | [ ] | — |
| IMP-27 | User cancels the picker with an error / the file cannot be read as UTF-8 → App shows alert titled "Export Error" with the system message (the title is wrong for imports). Failure to get security-scoped access, or no local user, returns silently. | 🐞 DataExportView.swift:87,113,118,131-133 (expected title "Import Error", message on silent paths) | [ ] | — |
| IMP-30 | System: imported workouts → App saves them as finished (not draft) workouts with `notes` = the file's workout name, duration from Hevy end − start (else 0), and does not post them to the feed. | ✅ DataImportService.swift:236-241 | [ ] | — |

### IMP edge cases

| ID | Situation | What the app does | Why/notes | Status | Manual check | Tests |
|---|---|---|---|---|---|---|
| IMP-E01 | File in lbs but unit menu left at kg | Weights are 2.2x too high. A header unit (weight_lbs / "Weight (lbs)") wins; bare "Weight" uses the menu, which starts at the user's preference. | | 🟡 user must pick correctly | [ ] | — |
| IMP-E02 | Decimal comma weights ("82,5") | `parseDecimal` accepts locale decimals. | CSV commas inside quotes are handled by the RFC 4180 parser. | ✅ | [ ] | — |
| IMP-E03 | BOM at file start | Header trimming removes U+FEFF. | | ✅ DataImportService.swift:372 | [ ] | — |
| IMP-E04 | Very large file (tens of thousands of rows) | Parsed and committed on the main actor in one pass with no progress UI; the screen can freeze. | | 🟡 not measured | [ ] | — |
| IMP-E05 | Kill the app mid-import | The context is saved once at the end; a kill before that loses the import; re-running is safe (dedupe). | | ✅ | [ ] | — |
| IMP-E06 | Dates and time zones | Strong dates have no zone and are parsed in the device zone; Hevy ISO dates carry zones. DST gaps follow the system calendar. | | 🟡 | [ ] | — |
| IMP-E07 | Import gating | Free for everyone (spec: data import is free). The paywall lists "Import / Export" as a Supernova module, which is misleading. | | ✅ code / 🟡 copy | [ ] | — |
| IMP-E08 | Imported workouts and streak / PRs | They count toward history, streaks and PRs because they are normal finished workouts. | | 🧭 PROPOSED: confirm that backfilled history should affect streak/PR badges | [ ] | — |

## EXP  Export (JSON / CSV)

| ID | User does → App does (observable result) | Status | Manual check | Tests |
|---|---|---|---|---|
| EXP-03 | User views EXPORT FORMATS → App shows "Exports always use kg (the unit weights are stored in); a Unit column / weightUnit field says so." and rows "Export as JSON" / "Export as CSV" with value "{N} WORKOUTS" (finished, not deleted). | ✅ DataExportView.swift:61-70 | [ ] | — |
| EXP-06 | User taps "Export as JSON" → App writes `pump_workouts.json` to the temp folder and opens the iOS share sheet. File: `exportDate`, `version` "1.1", `weightUnit` "kg", and workouts (newest first) with date (ISO-8601), duration, calories, notes, exercises (name or "Unknown", order, notes) and sets (order, weight, reps, rir, setType). | ✅ DataExportService.swift:39-79 | [ ] | — |
| EXP-09 | User taps "Export as CSV" → App writes `pump_workouts.csv` and opens the share sheet. Header: `Date,Exercise,Set,Weight,Unit,Reps,RIR,Type,Duration(min),Calories`; one row per set; Set is order + 1; Duration is the workout duration in whole minutes repeated on every row. | ✅ DataExportService.swift:81-101 | [ ] | — |
| EXP-12 | User exports with zero workouts → App still opens the share sheet with a header-only CSV / empty workouts array. | 🟡 no "nothing to export" message | [ ] | — |
| EXP-15 | System: export fails (disk) → App shows alert "Export Error" with the message. | ✅ DataExportView.swift:144-147 | [ ] | — |
| EXP-18 | System: export scope → App exports only workouts. Templates, bodyweight log, profile and custom exercises are not included. | 🟡 matches the Strong/Hevy style but not a full-account backup | [ ] | — |
| EXP-21 | User taps Privacy & Legal › "Download My Data" (value "JSON") → App does nothing (empty action). | ❌ PrivacyLegalView.swift:25 | [ ] | — |

### EXP edge cases

| ID | Situation | What the app does | Why/notes | Status | Manual check | Tests |
|---|---|---|---|---|---|---|
| EXP-E01 | Exercise name contains a double quote | CSV is broken for that row (name is wrapped in quotes without escaping). | | 🐞 DataExportService.swift:92 | [ ] | — |
| EXP-E02 | Exercise deleted from the catalogue | Row name is "Unknown". | | ✅ | [ ] | — |
| EXP-E03 | Export gating | Free for everyone (the spec's "Things NOT to build in V1" listed export; it was built and ungated). | | ✅ | [ ] | — |
| EXP-E04 | Share sheet on iPad | Presented as a sheet with `UIActivityViewController`; popover anchoring not handled. | iPad not supported in V1. | 🧭 | [ ] | — |

## PLS  Supernova screen (the presentation; gating is in 13)

| ID | User does → App does (observable result) | Status | Manual check | Tests |
|---|---|---|---|---|
| PLS-03 | User taps the hub banner, the "Supernova" row, or Widgets as a free user → App presents Supernova full-screen: blue hero "ORE · MEMBERSHIP", a "✕" close, big "SUPERNOVA" (the "+" in gold) and "Train smarter. Track deeper. Share with your crew." | ✅ SupernovaView.swift:73-111 | [ ] | — |
| PLS-06 | System: the user has a finished workout of the predicted template → App shows a "NEXT SESSION · PREVIEW" card (up to 3 exercises with target weight x reps, a delta like "▲ +2.5 KG VS LAST" or "HOLD AT LAST", 1-5 confidence dots, "BUILT FROM YOUR LAST {n} WORKOUTS"). Shown to every user, including subscribers. | ✅ SupernovaView.swift:126-228 | [ ] | — |
| PLS-09 | System: spec sheet → App lists "SPEC SHEET  06 MODULES": Smart Predictions, Cloud Sync, Advanced Analytics, Weekly Recaps, Friend Challenges, Import / Export, each with a subtitle. Several of these are not gated in code (see 13). | 🟡 SupernovaView.swift:20-29 | [ ] | — |
| PLS-12 | System: not subscribed and inside the trial → App shows "{n} DAYS LEFT IN TRIAL" in accent (see TRL in 13). | ✅ SupernovaView.swift:306-314 | [ ] | — |
| PLS-15 | System: not subscribed → App shows "PLAN" with two cards, MONTHLY and ANNUAL (ANNUAL pre-selected). Each shows price per month (annual = yearly price / 12), the yearly total, and for annual a "▼ n%" saving versus 12 monthly payments. Before products load, prices show "—". | ✅ SupernovaView.swift:324-407 | [ ] | — |
| PLS-18 | User taps a plan card → App highlights it (accent border) and updates the bottom button price. | ✅ | [ ] | — |
| PLS-21 | User taps the bottom "START SUPERNOVA" button (shows the store price and "PER YEAR" / "PER MONTH") → App starts the StoreKit 2 purchase sheet. Verified purchase: transaction finished, entitlement refreshed, dock disappears and "ACTIVE · ANNUAL / MONTHLY / SUPERNOVA" with "Thank you for subscribing. Manage in App Store." appears. | ✅ SupernovaView.swift:411-459,489-497, SupernovaService.swift:91-107 | [ ] | — |
| PLS-24 | User cancels the purchase sheet or the purchase is pending → App returns silently (no toast). | 🟡 SupernovaView.swift:492 (empty branch) | [ ] | — |
| PLS-27 | System: purchase throws (store error or unverified transaction) → App shows alert "Purchase Error" with the message (or "Something went wrong."). | ✅ SupernovaView.swift:64-68 | [ ] | — |
| PLS-30 | System: products fail to load or none exist (simulator) → App shows "Subscriptions unavailable" in place of the button; while loading, a spinner. | ✅ SupernovaView.swift:415-448 | [ ] | — |
| PLS-33 | System: the chosen period has no product → App buys the first product (cheapest, normally monthly) while the UI still shows the annual price. | 🐞 SupernovaView.swift:461-469 | [ ] | — |
| PLS-36 | User taps "Restore Purchases" → App calls `AppStore.sync()` then refreshes entitlements. No spinner, no success or failure message; on success the screen flips to the ACTIVE state. | 🟡 SupernovaService.swift:109-112, SupernovaView.swift:473-485 | [ ] | — |
| PLS-39 | User taps "✕" → App closes the cover and returns to the hub. | ✅ SupernovaView.swift:84 | [ ] | — |
| PLS-42 | System: while the screen is open → App listens to `Transaction.updates` (renewals, family sharing, refunds) and refreshes entitlement; stops on disappear. | ✅ SupernovaView.swift:53-63 | [ ] | — |

### PLS edge cases

| ID | Situation | What the app does | Why/notes | Status | Manual check | Tests |
|---|---|---|---|---|---|---|
| PLS-E01 | Offline | Products cannot load → "Subscriptions unavailable"; existing entitlement is read from the on-device StoreKit cache. | | ✅ | [ ] | — |
| PLS-E02 | Subscription expires or is refunded | `currentEntitlements` no longer contains it; `isSubscribed` becomes false on the next refresh (hub appear, paywall, Settings, workout detail, body map). Plus-only options stay selected but gated UI hides. | | ✅ | [ ] | — |
| PLS-E03 | Another Apple ID signs in on the device | Entitlement follows the App Store account, not the Ore account. | | 🧭 PROPOSED: decide whether Plus should also be tied to the Ore account | [ ] | — |
| PLS-E04 | Multi-app pricing tiers in the spec (1 / 2 / 3 apps) | Only two single-app products exist (`com.pulse.PulsePump.monthly`, `.yearly`). | | ❌ | [ ] | — |
| PLS-E05 | Debug builds | `-devDataPlus 1` forces `isSubscribed = true` (DEBUG only). | | ✅ DevFlags.swift:31-37 | [ ] | — |

## TUT  Tutorial and coach marks

| ID | User does → App does (observable result) | Status | Manual check | Tests |
|---|---|---|---|---|
| TUT-03 | User finishes onboarding choosing "YES, SHOW ME AROUND" (beginner / intermediate path) → App stores `wantsTutorial = true`; on first main-shell appear the tutorial starts. Experienced users see "START TRAINING" and skip it. The screen says "TUTORIAL ALWAYS AVAILABLE IN MORE → HELP". | ✅ TutorialPromptStepView.swift:55-80, ContentView.swift:109 | [ ] | — |
| TUT-06 | User taps More › Tutorial → App starts from step 1 on whatever tab is current, then moves to the required tab. | ✅ MoreTabView.swift:113-115, TutorialViewModel.swift | [ ] | — |
| TUT-09 | System: tutorial active → App dims the screen (74% ink) and shows a card with a phase chip (Equipment / Programs / Workout Logger / Post-Workout), "01 / 10", a "SKIP" button, title, description, and a "GOT IT →" button ("START TRAINING →" on the last step). Steps in order: Gym Profile, Your Plates, Rest Timer Defaults, Pick a Template, Add an Exercise, Pick a Variant, Ghost Text, Log a Set, Plate Calculator, Post-Workout Summary. | ✅ TutorialViewModel.swift:5-100, CoachMarkOverlay.swift:108-148 | [ ] | — |
| TUT-12 | User taps "GOT IT →" → App advances; the tab switches automatically (More for steps 1-3, Programs for 4-6, Home for 7-10); steps 1-3 also open Equipment, Equipment, Settings. | ✅ CoachMarkOverlay.swift:44-51, MoreTabView.swift:64-71 | [ ] | — |
| TUT-15 | System: steps 1-3 → App spotlights the profile tabs, the plate grid and the Rest Timer Mode row. Steps 4-10 have no anchor, so the whole screen is dimmed with the card alone, and the dim layer blocks the interaction the text describes ("Tap the plates row", "Tap the circle to complete"). Step 5/6 describe an exercise-variant flow whose copy ("Bench Press splits by angle first, then by equipment") differs from the real picker (groups by family). | 🟡 TutorialViewModel.swift:73-82; steps 4-10 are placeholders | [ ] | — |
| TUT-18 | User taps "SKIP" at any step → App ends the tutorial, sets `wantsTutorial = false` and `tutorialCompleted = true`. | ✅ TutorialViewModel.swift:121-127 | [ ] | — |
| TUT-21 | System: last step advanced → App shows "YOU'RE ALL SET." / "Go build something worth logging." with "START TRAINING →" (completes) and "REPLAY TUTORIAL" (restarts). | ✅ CoachMarkOverlay.swift:170-200 | [ ] | — |
| TUT-24 | System: tutorial ends → `tutorialCompleted` is written but never read anywhere. The More tab keeps the sub-screen the last step left it on. | 🟡 | [ ] | — |

### TUT edge cases

| ID | Situation | What the app does | Why/notes | Status | Manual check | Tests |
|---|---|---|---|---|---|---|
| TUT-E01 | Tutorial step needs an equipment profile but none exists | The spotlight target is missing; the card shows alone. | | 🟡 | [ ] | — |
| TUT-E02 | Kill the app mid-tutorial | `wantsTutorial` is still true, so the tutorial restarts from step 1 next launch. | Progress is not persisted. | ✅ | [ ] | — |
| TUT-E03 | Sign-out | `wantsTutorial` is cleared so the next account does not inherit it. | | ✅ SyncLifecycle.swift:54 | [ ] | — |

## WGE  Widgets entry (library, gallery, builder)

| ID | User does → App does (observable result) | Status | Manual check | Tests |
|---|---|---|---|---|
| WGE-03 | User opens More › Widgets (subscriber / trial) → App shows "WIDGETS" with a "NEW" button, instructions ("Build a widget from only the pieces you want. On the home screen, add Ore Custom, then choose one of these in Edit Widget."), "MY WIDGETS {count}" (presets are created on first open), a "+ NEW WIDGET" button and a "Widget gallery / ALL WIDGETS" row. | ✅ WidgetsView.swift | [ ] | — |
| WGE-06 | User taps "Widget gallery" → App opens the gallery full-screen showing every registered widget in light / dark / tinted. | ✅ WidgetsView.swift:86-94 | [ ] | — |
| WGE-09 | User taps a saved widget or "NEW" → App opens the builder (details in 11 WGB). A saved widget row can be deleted via an alert with "Delete". | ✅ | [ ] | — |
| WGE-12 | User (free, trial over) taps Widgets → App shows the paywall instead (MOR-15). Gating is at the entry row only: `WidgetsView` itself has no Plus check. | 🟡 see 13 GAT | [ ] | — |

## PLG  Privacy and legal

| ID | User does → App does (observable result) | Status | Manual check | Tests |
|---|---|---|---|---|
| PLG-03 | User opens More › Privacy & Legal → App shows LEGAL: "Privacy Policy", "Terms of Service", "Open-Source Licenses"; YOUR DATA: "Download My Data" (JSON) and red "Delete Account"; the note "Profile visibility and auto-share are in Settings › Privacy."; and a footer "ORE · VERSION x". | ✅ PrivacyLegalView.swift | [ ] | — |
| PLG-06 | User taps "Privacy Policy", "Terms of Service" or "Open-Source Licenses" → App does nothing (`openLegal()` is empty; URLs not defined). | ❌ PrivacyLegalView.swift:53 (required for App Store review) | [ ] | — |
| PLG-09 | User taps "Download My Data" → App does nothing (see EXP-21). The working export is under Settings › Import / Export Data. | ❌ | [ ] | — |
| PLG-12 | User taps "Delete Account" → App starts the delete-account flow (01 DEL). | ✅ PrivacyLegalView.swift:49 | [ ] | — |
| PLG-15 | Note: the note under the rows says privacy lives in "Settings › Privacy", but Settings only holds Profile Visibility and Auto-Share; the other three privacy rows are on the Friends › Activity screen. | 🟡 | [ ] | — |

## TOL  Standalone tools reachability

| ID | User does → App does (observable result) | Status | Manual check | Tests |
|---|---|---|---|---|
| TOL-03 | User looks for the standalone Plate Calculator (`PlateCalculatorView`: target weight, bar, custom plates) → App has no entry point. Only the inline calculator inside an exercise card of the active workout is reachable (`InlinePlateCalculatorView`, opened from the plates row). | ❌ PlateCalculatorView has no call site | [ ] | — |
| TOL-06 | User looks for the Warm-up generator (`WarmupGeneratorView`: working weight, bar weight default 20, steps default 4) → App has no entry point. | ❌ WarmupGeneratorView has no call site | [ ] | — |
| TOL-09 | System: spec says plate calculator and warm-up generator are free tools | 🟡 spec satisfied only for the inline calculator; the warm-up generator is unreachable | [ ] | — |

## Open decisions for the owner (10)

- MOR-18: during the trial the hub says "FREE" and shows the upgrade banner. Decide whether to show "TRIAL · n DAYS".
- SCF-24: MET calorie formula keeps working after Plus lapses (bug) — enforce the gate in the estimator or drop the gate.
- SCF-33, SCF-45, SCF-51: three "COMING SOON" rows (Smart Weight Suggestions, Simple Body Map, Social Activity, Challenge Updates). Keep, hide or build.
- SCF-69: missing settings (week start, default rest times, reminder times, summary fields, change email/password). `PostWorkoutCustomizationView` is dead.
- NTS-03: permission prompt fires at launch, not when the user enables a reminder. NTS-15: denied permission leaves the toggle on. NTS-21 (PROPOSED): reminder time picker.
- EQP-15 / EQP-18 / EQP-21: equipment profiles cannot be edited or deleted, "Add Equipment" is a no-op, and no feature consumes the data (plate calc, substitutions). Decide scope.
- IMP-27: import errors are titled "Export Error". IMP-E08 (PROPOSED): confirm imported history should count toward streak/PR.
- PLS-33: annual selection can buy monthly if the annual product is missing. PLS-36: Restore has no feedback. PLS-E03 (PROPOSED): Plus tied to Apple ID only.
- PLG-06 / PLG-09: legal links and "Download My Data" are empty actions (App Store review risk).
- TOL-03 / TOL-06: standalone Plate Calculator and Warm-up generator are unreachable.
- TUT-15: tutorial steps 4-10 are placeholders and block the interaction they describe; no week-start setting exists.
