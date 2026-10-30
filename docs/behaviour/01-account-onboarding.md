# 01 Account and onboarding

Scope: sign-up/sign-in (Apple, Google, Email), the root gate that routes signed-in users (splash, onboarding, restore, offline retry, app), username (handle) claim/rename, the 9-step onboarding, sign-out and account deletion. Accounts are required: there is no guest mode.
Key sources: `Ore/App/RootView.swift`, `Ore/App/OreApp.swift`, `Ore/Core/Services/Auth/*` (`AccountGate`, `AuthSession`, `FirebaseAuthProvider`, `HandleValidator`, `HandleInput`, `ProfileRemote`, `SyncLifecycle`), `Ore/Features/Auth/*`, `Ore/Features/Onboarding/*`, `Ore/Core/Sync/SyncServiceLifecycle.swift`, `firebase/functions/src/accountDeletion.ts` + `index.ts` (`deleteAccount`).

Routing matrix (`RootGate.route`, `AccountGate.swift:27`): auth unknown -> splash; signed out -> sign-in; signed in as a different uid than the local store owner -> wipe (splash) then re-evaluate; signed in with a local `User` -> app; otherwise by cloud check: unknown -> splash, `users/{uid}` absent -> onboarding, unreachable -> "You're offline", exists -> "Restoring your data" (or "Couldn't restore" if the pull finished with no local user).

## AUTH  Sign in / sign up

| ID | User does → App does (observable result) | Status | Manual check | Tests |
|---|---|---|---|---|
| AUTH-03 | User cold-launches the app while signed out → App shows the splash (logo, "ORE", spinner) until Firebase Auth reports, then the sign-in screen (`RootView.swift:29`, `SplashView`) | ✅ | [ ] | — |
| AUTH-06 | User views sign-in screen → App shows logo lockup "ORE" + "TRAIN SMARTER", headline "Your training, quantified.", blurb, three buttons "Continue with Apple", "Continue with Google", "Use email instead", and footer "By continuing you agree to our Terms of Service and Privacy Policy." (`SignInView.swift:665-772`) | ✅ | [ ] | — |
| AUTH-09 | User taps Terms of Service / Privacy Policy in footer → App does nothing: both are plain text because `LegalLinks.terms/privacy` are `nil` (`SignInView.swift:638`) | 🟡 links not built; hosted legal URLs do not exist yet | [ ] | — |
| AUTH-12 | User taps "Continue with Apple" → App shows the system Apple sheet requesting full name + email, with a SHA-256 hashed random 32-char nonce (`AppleSignInFlow.swift:13-21`) | ✅ | [ ] | — |
| AUTH-15 | User completes Apple sheet → App signs into Firebase with the Apple credential, and (first authorisation only) copies Apple's full name to the Firebase displayName if it was empty (`FirebaseAuthProvider.swift:37,153`) | ✅ | [ ] | — |
| AUTH-18 | User cancels the Apple sheet → App stays on sign-in with no error text (cancel maps to `AuthFailure.cancelled`, whose message is suppressed by `AuthErrorMapper.message`) | ✅ | [ ] | — |
| AUTH-21 | User taps "Continue with Google" → App shows the Google sign-in sheet presented on the top view controller, then signs into Firebase with the Google ID token (`FirebaseAuthProvider.swift:124`) | ✅ | [ ] | — |
| AUTH-24 | User cancels the Google sheet → App stays on sign-in, no error text | ✅ | [ ] | — |
| AUTH-27 | System: any provider button is tapped while a sign-in is running → App disables all three buttons and shows a spinner over them (`SignInView.swift:721-724`, `session.isBusy`) | ✅ | [ ] | — |
| AUTH-30 | User taps "Use email instead" → App clears any old error and opens the email sheet in "SIGN IN" mode (kicker "01 / WELCOME BACK", heading "Sign in to your account.", sub "Pick up right where you left off.") | ✅ | [ ] | — |
| AUTH-33 | User taps the SIGN IN / SIGN UP segment toggle → App switches mode, clears the password field and any messages. Sign-up mode shows kicker "CREATE ACCOUNT", heading "Create your account.", sub "Takes 30 seconds. No spam, ever.", and the footer "By creating an account you agree to our Terms and Privacy Policy." | ✅ | [ ] | — |
| AUTH-36 | User types an email that lacks "@" or "." → App outlines the field red and shows "NOT A VALID EMAIL"; the CTA stays grey/disabled. A valid-looking email shows a green check (`EmailAuthSheet.emailValid`: contains "@" and ".") | ✅ | [ ] | — |
| AUTH-39 | User is in sign-in mode with valid email and non-empty password → CTA "SIGN IN" enables (no minimum length enforced in sign-in mode) | ✅ | [ ] | — |
| AUTH-42 | User is in sign-up mode and types a password → App shows a 4-segment strength bar with label WEAK / FAIR / GOOD / STRONG and "MIN 8 CHARS". Score = +1 for length >=8, +1 for >=12, +1 for upper and lower case, +1 for a digit (max 4) | ✅ | [ ] | — |
| AUTH-45 | User has a sign-up password under 8 characters → App keeps "CREATE ACCOUNT" disabled (`passwordValid = count >= 8`) | ✅ | [ ] | — |
| AUTH-48 | User taps the eye icon → App toggles the password between hidden and visible text | ✅ | [ ] | — |
| AUTH-51 | User taps "CREATE ACCOUNT" with valid email and password >= 8 → App creates the Firebase user, marks `isNewUser`, dismisses the sheet; the gate then sees no cloud profile and routes to onboarding | ✅ | [ ] | — |
| AUTH-54 | User taps "SIGN IN" with correct credentials → App signs in and dismisses the sheet; the gate then routes by the matrix (app / restore / onboarding) | ✅ | [ ] | — |
| AUTH-57 | User signs in with a wrong password or unknown credential → App shows red "That email or password isn't right." under the form (`emailAuthError`) and keeps the sheet open | ✅ | [ ] | — |
| AUTH-60 | User signs up with an email that already has an account → App shows "An account with this email already exists. Try signing in instead." | ✅ | [ ] | — |
| AUTH-63 | User signs up with a password Firebase rejects as weak → App shows "Choose a stronger password (at least 8 characters)." | ✅ | [ ] | — |
| AUTH-66 | User signs in with a disabled account → App shows "This account has been disabled. Contact support." | ✅ | [ ] | — |
| AUTH-69 | User triggers too many failed attempts → App shows "Too many attempts. Wait a moment and try again." | ✅ | [ ] | — |
| AUTH-72 | User taps "Forgot password?" (sign-in mode only) → App switches to reset mode: kicker "RESET PASSWORD", only the email field, CTA "SEND RESET LINK", link "Back to sign in" | ✅ | [ ] | — |
| AUTH-75 | User taps "SEND RESET LINK" with a valid email → App sends the Firebase reset email and shows green "Check <email> for a reset link." | ✅ | [ ] | — |
| AUTH-78 | User sends reset for an address with no account → App shows "No account found for that email." (Firebase may instead succeed silently if email-enumeration protection is on in the console; not verifiable from code) | 🟡 depends on Firebase project setting | [ ] | — |
| AUTH-81 | User taps the back chevron on the email sheet → App dismisses the sheet back to the three-button screen; typed values are discarded | ✅ | [ ] | — |
| AUTH-84 | User signs in with Apple or Google using an email that already exists as an email/password account → App shows the Firebase error mapped to a generic message (Firebase `account-exists-with-different-credential` is not mapped; falls to `.unknown(localizedDescription)`). Account linking is not built | 🟡 no provider linking | [ ] | — |

### AUTH edge cases

| ID | Situation | What the app does | Why/notes | Status | Manual check | Tests |
|---|---|---|---|---|---|---|
| AUTH-E01 | No network when tapping a provider or submitting email | Shows "Can't reach the server. Check your connection and try again." (NSURLError and Firebase network errors map to `.network`) | `FirebaseAuthProvider.map` | ✅ | [ ] | — |
| AUTH-E02 | Double-tap "SIGN IN" / "CREATE ACCOUNT" | Second tap ignored: the button is `.disabled` while `isBusy` | Prevents duplicate account creation | ✅ | [ ] | — |
| AUTH-E03 | Email has leading/trailing spaces | Trimmed before use (`AuthSession.clean`); validity check trims spaces but not newlines | | ✅ | [ ] | — |
| AUTH-E04 | Email with uppercase | Passed as typed; Firebase treats emails case-insensitively | | 🟡 not verified on device | [ ] | — |
| AUTH-E05 | Password with leading/trailing spaces | Not trimmed, used as typed | | ✅ | [ ] | — |
| AUTH-E06 | Google client ID missing / no presenter | Shows "Missing Firebase client ID." or "Couldn't present Google sign-in." | Config error surfaced as raw text | ✅ | [ ] | — |
| AUTH-E07 | Apple returns no identity token | Shows "Couldn't read the Apple sign-in token." | | ✅ | [ ] | — |
| AUTH-E08 | Error message from a previous attempt visible, user opens email sheet | Cleared on open (`clearMessages` on tap and `onAppear`) | | ✅ | [ ] | — |
| AUTH-E09 | Error from Apple/Google shown while email sheet is open | Shown inside the email sheet only (the sign-in screen hides its own error while `showEmail`) | `SignInView.swift:726` | ✅ | [ ] | — |
| AUTH-E10 | Sign-in from Apple uses "Hide My Email" | Email shown in Settings is the private relay address | Provider behaviour | 🟡 not verified on device | [ ] | — |
| AUTH-E11 | Locale / non-ASCII email | Only the "@" and "." check is applied locally; Firebase is the real validator ("Enter a valid email address.") | | ✅ | [ ] | — |

## HND  Username (handle) rules, claim and rename

Rules mirror `usernames/{handle}` in firestore.rules (`HandleValidator.swift`): lowercase, 3-20 chars, `[a-z0-9._]`.

| ID | User does → App does (observable result) | Status | Manual check | Tests |
|---|---|---|---|---|
| HND-03 | User types in the @username field → App lowercases the text as typed, shows an "@" prefix, ASCII keyboard, no autocorrect/autocapitalise (`HandleField`) | ✅ | [ ] | — |
| HND-06 | User has typed nothing → App shows hint "LOWERCASE · 0/20" under the field | ✅ | [ ] | — |
| HND-09 | User types fewer than 3 characters → App shows red "USE AT LEAST 3 CHARACTERS." and does not call the server | ✅ | [ ] | — |
| HND-12 | User types more than 20 characters → App shows red "USE AT MOST 20 CHARACTERS." (checked before charset) | ✅ | [ ] | — |
| HND-15 | User types a character outside a-z 0-9 . _ (space, hyphen, emoji) → App shows red "ONLY LETTERS, NUMBERS, DOTS AND UNDERSCORES." | ✅ | [ ] | — |
| HND-18 | User starts or ends with "." or "_" → App shows red "CAN'T START OR END WITH A DOT OR UNDERSCORE." | ✅ | [ ] | — |
| HND-21 | User types two punctuation characters in a row (".." "__" "._") → App shows red "NO TWO DOTS OR UNDERSCORES IN A ROW." | ✅ | [ ] | — |
| HND-24 | User types a reserved word (admin, administrator, root, support, help, pump, pulse, pulsepump, pulseplus, official, staff, team, moderator, mod, system, null, undefined, anonymous, me, you, settings, privacy, terms, api, www, fuel) → App shows red "THAT USERNAME ISN'T AVAILABLE." | ✅ | [ ] | — |
| HND-27 | User types a locally valid handle and pauses → After a 350 ms debounce App shows "CHECKING AVAILABILITY…" with a spinner, then reads `usernames/{handle}` | ✅ | [ ] | — |
| HND-30 | Handle document does not exist (or is owned by this uid) → App shows green "AVAILABLE" with a check and green border | ✅ | [ ] | — |
| HND-33 | Handle document exists for another uid → App shows red "ALREADY TAKEN" | ✅ | [ ] | — |
| HND-36 | Availability read fails (offline/permission) → App shows red message ("Can't reach the server. Check your connection and try again." or generic "Couldn't check availability. Try again.") with a "RETRY" button that re-checks immediately | ✅ | [ ] | — |
| HND-39 | User keeps typing while a check is in flight → App discards the stale result (only the result for the current text updates status) | ✅ | [ ] | — |
| HND-42 | User opens Settings › Account › Username row (shows "@name" or "—") → App presents the "CHANGE USERNAME" sheet (medium detent) with the field prefilled and focused, note "Your old username is released so someone else can take it." | ✅ | [ ] | — |
| HND-45 | User has not changed the text in the rename sheet → "SAVE" is disabled (grey) because `handle == user.username` | ✅ | [ ] | — |
| HND-48 | User types a new available handle and taps "SAVE" → App shows a spinner on the button, then one atomic batch: creates `usernames/{new}`, deletes `usernames/{old}`, merges `username`/`name`/`updatedAt` into `users/{uid}` and `profiles/{uid}`; then updates the local `User.username` and dismisses the sheet (`ProfileRemote.swift:306`) | ✅ | [ ] | — |
| HND-51 | Server says the new handle is taken at save time (race) → App marks status "ALREADY TAKEN" and shows red "That username was just taken. Try another."; sheet stays open | ✅ | [ ] | — |
| HND-54 | User taps "CANCEL" in the rename sheet → App dismisses with no change | ✅ | [ ] | — |
| HND-57 | User retypes their own current handle in the rename sheet → App shows "AVAILABLE" locally without a server call but SAVE stays disabled | ✅ | [ ] | — |

### HND edge cases

| ID | Situation | What the app does | Why/notes | Status | Manual check | Tests |
|---|---|---|---|---|---|---|
| HND-E01 | Uppercase typed or pasted ("Alex_1") | Text is rewritten to lowercase; the `.uppercase` problem exists but is only used with `strictCase: true`, which the UI never passes | | ✅ | [ ] | — |
| HND-E02 | Surrounding whitespace pasted | Trimmed for validation (`normalize`), but the visible text is only lowercased, not trimmed; interior spaces then fail the charset rule | | ✅ | [ ] | — |
| HND-E03 | Offline when saving a rename | Shows "Can't reach the server. Check your connection and try again."; local username unchanged | Rename is online-only | ✅ | [ ] | — |
| HND-E04 | Permission denied on rename write | App re-reads the handle; if someone else owns it shows "just taken", else "Couldn't save your profile (permission denied). Sign out and back in, then try again." | `mapWriteError` | ✅ | [ ] | — |
| HND-E05 | Kill app mid-rename | Batch is atomic: either old or new handle is in force; local `User.username` is only set after success. If the commit succeeded but the app died before the local update, local username is stale until the next sync pull | | 🟡 stale-until-sync not verified | [ ] | — |
| HND-E06 | Rename frequency / cooldown | No limit and no cooldown; old handle is released immediately and can be taken by anyone | Product decision | 🧭 PROPOSED: keep unlimited for now; consider a 30-day cooldown before launch | [ ] | — |
| HND-E07 | Display name vs username | Rename also rewrites `name` from the local `User.name`, so a stale local name overwrites the cloud name | `ChangeUsernameSheet.swift:409` | 🟡 low risk, one source of truth is the local User | [ ] | — |
| HND-E08 | Reserved list vs server rules | Reserved list is client-side only in this file; firestore.rules may not enforce it | Not verified in rules file | 🟡 | [ ] | — |

## ONB  Onboarding (new account only)

Reached only when signed in, `users/{uid}` absent in the cloud and no local `User`. Nine steps, progress bar "STEP n OF 9" with percentage (n/9). Back chevron on every step except the first. No skip.

| ID | User does → App does (observable result) | Status | Manual check | Tests |
|---|---|---|---|---|
| ONB-03 | System: brand-new account lands in onboarding → App shows step 1 "01 / NAME", title "What should we call you?", subtitle "This is how you'll appear to friends and on your profile.", field placeholder "Your name", hint "FIRST NAME IS FINE · CAN CHANGE LATER"; the name is prefilled from the Apple/Google display name when present | ✅ | [ ] | — |
| ONB-06 | User leaves the name empty or spaces only → App keeps Continue disabled (`trimmedName.isEmpty`) | ✅ | [ ] | — |
| ONB-09 | User continues from name → App advances to "02 / USERNAME" ("Pick your username.", "Friends find you by this. 3-20 characters: letters, numbers, dots, underscores.") and auto-suggests a handle from the name (lowercase, spaces/hyphens to "_", invalid chars dropped, trimmed to 20, padded with "0" to reach 3) and checks it immediately | ✅ | [ ] | — |
| ONB-12 | User has a handle that is not "AVAILABLE" (invalid, taken, checking, failed) → App keeps Continue disabled (`canContinue` requires `handleInput.isAvailable`) | ✅ | [ ] | — |
| ONB-15 | User continues from username → App advances to "03 / BODY" weight: title "How much do you weigh, <name>?", subtitle "Used to estimate calorie burn. Can be updated anytime.", KG / LB toggle | ✅ | [ ] | — |
| ONB-18 | User switches KG to LB with a weight typed → App re-expresses the same body weight in the new unit (e.g. 80 kg shows as 176.4 lb) and switches the height default to FT/IN for lbs and CM for kg | ✅ | [ ] | — |
| ONB-21 | User enters weight <= 0 or non-numeric → App keeps Continue disabled | ✅ | [ ] | — |
| ONB-24 | User continues from weight → App shows "04 / BODY" height: "How tall are you?" with CM and "FT / IN" segment toggle | ✅ | [ ] | — |
| ONB-27 | User uses CM and enters a value > 0 → Continue enables; stored as cm as typed | ✅ | [ ] | — |
| ONB-30 | User uses FT / IN, enters feet > 0 (inches optional) → Continue enables; stored as cm via `UnitPreference.cm(feet:inches:)` | ✅ | [ ] | — |
| ONB-33 | User continues from height → App shows "05 / BODY" age: "How old are you?", unit "YRS", "Not shown publicly." | ✅ | [ ] | — |
| ONB-36 | User enters an age that is not a whole number, <= 0, or >= 120 → App keeps Continue disabled; valid range is 1-119 | ✅ | [ ] | — |
| ONB-39 | User continues from age → App shows "06 / BODY" gender: "Which best describes you?" with the Gender options as radio cards; nothing is required (Continue always enabled) | ✅ | [ ] | — |
| ONB-42 | User continues without picking gender → App stores `preferNotToSay` | ✅ | [ ] | — |
| ONB-45 | User continues → App shows "07 / EXPERIENCE": "How long have you been lifting?" with experience cards (name, sub, detail); Continue always enabled | ✅ | [ ] | — |
| ONB-48 | User continues without picking experience → App stores `beginner` | ✅ | [ ] | — |
| ONB-51 | User continues → App shows "08 / PROGRAM": "How do you structure your training?" with six rows: Push / Pull / Legs (6 DAYS/WK), Upper / Lower (4), Full Body (3), Bro Split (5), Custom, "No fixed split" (TRAIN WHENEVER · LOG FREELY). Default selection is none | ✅ | [ ] | — |
| ONB-54 | User picks a split and continues → App creates a `Split` with its default weekly days populated (`SplitSchedule.makeSplit`, e.g. PPL = Mon Push, Tue Pull, Wed Legs, Thu Push, Fri Pull, Sat Legs) | ✅ | [ ] | — |
| ONB-57 | User continues from the split step → App shows "09 / ALMOST DONE". For experience "experienced": "You're all set." with one button "START TRAINING" (no tutorial). Otherwise "Welcome, <name>." with "YES, SHOW ME AROUND" (tutorial on) and "SKIP, I'LL EXPLORE MYSELF" (tutorial off); footer "TUTORIAL ALWAYS AVAILABLE IN MORE → HELP" | ✅ | [ ] | — |
| ONB-60 | User taps any final CTA → App shows "CREATING YOUR ACCOUNT" overlay with spinner, then one atomic batch creates `users/{uid}`, `profiles/{uid}` and `usernames/{handle}` (privacy defaults: workoutPosts friends, bodyMap friends, globalLeaderboards visible, profile everyone) | ✅ | [ ] | — |
| ONB-63 | System: cloud write succeeded → App creates the local `User` (kg weight, cm height), the optional `Split`, records the first bodyweight log entry from the weight, sets `wantsTutorial`, and tells the gate to claim the local store; the gate routes to the main app | ✅ | [ ] | — |
| ONB-66 | User taps the back chevron → App moves one step back with the entered values kept; at step 1 no back button is shown | ✅ | [ ] | — |
| ONB-69 | System: the new user lands on the main screen → App asks for notification permission (system prompt) the first time `route == .main` (`RootView.swift:95`); see NTF | ✅ | [ ] | — |
| ONB-72 | User kills the app mid-onboarding → On relaunch the user is still signed in with no cloud profile and no local user, so onboarding restarts at step 1 with empty fields (no draft saved) except the prefilled name | ✅ | [ ] | — |

### ONB edge cases

| ID | Situation | What the app does | Why/notes | Status | Manual check | Tests |
|---|---|---|---|---|---|---|
| ONB-E01 | Offline on the final step | Cloud write fails; alert "Couldn't finish setup" / "Can't reach the server. Check your connection and try again." with OK; nothing local is created; user stays on step 9 and can retry | Onboarding needs network to finish | ✅ | [ ] | — |
| ONB-E02 | Handle taken between step 2 and final submit | Sets status "ALREADY TAKEN", jumps back to the username step, alert "That username was just taken. Try another." | | ✅ | [ ] | — |
| ONB-E03 | Handle became invalid (cannot normally happen) | Alert with the rule message and jump to the username step | `submit()` guard | ✅ | [ ] | — |
| ONB-E04 | Double-tap the final CTA | Second call ignored (`guard !isSubmitting`) | | ✅ | [ ] | — |
| ONB-E05 | Retry after a half-applied attempt (handle doc already ours) | `createAccount` reads the handle first and skips re-creating it if this uid owns it, so retry succeeds | Rules forbid recreating a handle doc | ✅ | [ ] | — |
| ONB-E06 | Weight/height typed with a decimal comma (e.g. "80,5") | Parsed through `UnitPreference.parseKg` / `parseDecimal`; locale behaviour of those helpers belongs to the units spec | | 🟡 not verified here | [ ] | — |
| ONB-E07 | Extreme values (weight 5000, height 900, age 119) | Only > 0 (and age < 120) is enforced; no upper clamp on weight or height | Product decision | 🧭 PROPOSED: weight 20-500 kg, height 80-260 cm | [ ] | — |
| ONB-E08 | Inches left empty or > 11 in FT/IN | Empty counts as 0; values above 11 are accepted and converted arithmetically | | 🟡 | [ ] | — |
| ONB-E09 | Experience level is chosen but the "experienced" copy says a template was set up | Copy says "We've set up a basic template based on your split" but only a `Split` schedule is created, no `WorkoutTemplate` | Docs audit also flagged; check seeding | 🟡 copy may overpromise | [ ] | — |
| ONB-E10 | Previous account's `wantsTutorial` leaking | Cleared on wipe; overwritten at submit | | ✅ | [ ] | — |
| ONB-E11 | Apple "name only on first sign-in" and user deleted + re-signs up | Apple will not send the name again, so the name field starts empty | Provider behaviour | 🟡 | [ ] | — |
| ONB-E12 | Under-age / date of birth | Only a numeric age is asked; no minimum age gate (App Store 13+/COPPA) | Compliance | 🧭 PROPOSED: block under 13 with a message | [ ] | — |

## RST  Returning user and new-device restore

| ID | User does → App does (observable result) | Status | Manual check | Tests |
|---|---|---|---|---|
| RST-03 | User relaunches while signed in with a local user → App shows splash then goes straight to the main app; the local store is claimed for the uid if it was not (pre-accounts store) (`AccountGate.reconcile`) | ✅ | [ ] | — |
| RST-06 | User relaunches offline while signed in with a local user → App opens the main app using the cached Firebase user (no network needed) | ✅ | [ ] | — |
| RST-09 | User signs in on a new device/reinstall with an existing account (cloud `users/{uid}` exists, no local user) → App shows "RESTORING YOUR DATA…" with spinner and "Your workouts and programs are coming back." while the initial sync pull runs | ✅ | [ ] | — |
| RST-12 | System: initial pull completes and creates the local `User` → App leaves the restore screen and shows the main app | ✅ | [ ] | — |
| RST-15 | System: pull finished but no local user was created → App shows "Couldn't restore your data" / "Your account exists but nothing came back from the cloud." with "TRY AGAIN" and "SIGN OUT" | ✅ | [ ] | — |
| RST-18 | System: signed in, no local data and the cloud check fails → App shows "You're offline" / "Connect to the internet once to finish setting up this device." with "TRY AGAIN" and "SIGN OUT" | ✅ | [ ] | — |
| RST-21 | User taps "TRY AGAIN" → App resets the check state and re-runs the cloud check and restore | ✅ | [ ] | — |
| RST-24 | User returns to the app (foreground) while on "You're offline" → App retries the cloud check automatically (`RootView.swift:85`) | ✅ | [ ] | — |
| RST-27 | User signs in as a different account than the one whose data is on the device → App shows splash, wipes all local user data (workouts, templates, splits, equipment, custom exercises, profile, sync cursors, widget snapshot), then routes as a fresh sign-in for the new uid | ✅ | [ ] | — |
| RST-30 | System: restore is in progress and the user is also signed in on a second device → App continues; the pull is read-only for local state | ✅ | [ ] | — |
| RST-33 | System: account exists in Auth but `users/{uid}` was never created (e.g. app killed during onboarding) → App treats it as new and shows onboarding | ✅ | [ ] | — |

### RST edge cases

| ID | Situation | What the app does | Why/notes | Status | Manual check | Tests |
|---|---|---|---|---|---|---|
| RST-E01 | Restore never completes (hang on a slow network) | "RESTORING YOUR DATA…" polls every 400 ms with no timeout and no escape button | User must kill the app | 🧭 PROPOSED: after 30 s show TRY AGAIN / SIGN OUT as on the failed screen | [ ] | — |
| RST-E02 | Kill app during restore | On relaunch the gate re-checks the cloud and resumes (initial-sync flag is per uid; if incomplete it re-runs) | | 🟡 not verified on device | [ ] | — |
| RST-E03 | Session expired / token revoked while signed in | Firebase listener reports signed out; local data is NOT wiped by that path; user sees sign-in. Signing back in as same uid returns straight to the app | Wipe happens only on explicit sign-out or uid change | ✅ | [ ] | — |
| RST-E04 | Account deleted from another device | Listener reports signed out on next token refresh; local data stays until a different account signs in or the user signs out | | 🟡 | [ ] | — |
| RST-E05 | Pre-accounts local store from an old build | Claimed for the first uid that signs in (no wipe, nothing uploaded by the gate itself) | | ✅ | [ ] | — |
| RST-E06 | Sign-in as a different user while a workout draft exists | Local store (including draft) is wiped without a warning | Data of the old account is in the cloud only if synced | 🧭 PROPOSED: warn if unsynced changes exist | [ ] | — |

## SOUT  Sign out

| ID | User does → App does (observable result) | Status | Manual check | Tests |
|---|---|---|---|---|
| SOUT-03 | User taps Settings › "Sign Out" (red row at the bottom) → App shows alert "Sign Out": "This removes your data from this device. It stays safe in your account and comes back when you sign in." with "Cancel" and "Sign Out" | ✅ | [ ] | — |
| SOUT-06 | User taps "Cancel" → App dismisses the alert, nothing changes | ✅ | [ ] | — |
| SOUT-09 | User taps "Sign Out" → App swaps to the splash (60 ms), tries a best-effort flush of unsynced changes, stops sync, wipes local user data and the owner marker, signs out of Firebase and shows the sign-in screen | ✅ | [ ] | — |
| SOUT-12 | User signs back in with the same account → App restores everything via the new-device flow (RST-09) | ✅ | [ ] | — |
| SOUT-15 | User taps "SIGN OUT" on the offline/restore failure screens → Same sign-out path as SOUT-09 | ✅ | [ ] | — |

### SOUT edge cases

| ID | Situation | What the app does | Why/notes | Status | Manual check | Tests |
|---|---|---|---|---|---|---|
| SOUT-E01 | Offline sign-out with unsynced changes | `flushPending` is best-effort; local data is wiped anyway, so unsynced edits are lost | Alert copy says data "stays safe in your account", which is false for unsynced edits | 🐞 `Core/Sync/SyncServiceLifecycle.swift:23`: expected a warning or blocked sign-out when pending changes exist; actual silent loss | [ ] | — |
| SOUT-E02 | Active workout in progress (draft) at sign-out | Draft wiped with the rest | | 🧭 PROPOSED: block sign-out with "Finish or discard your workout first" while a workout is active | [ ] | — |
| SOUT-E03 | Pending local notifications and reminder toggles after sign-out | Not cancelled and `workoutReminders` / `restDayAlerts` stay set; only `wantsTutorial` is cleared. Reminders for the old account keep firing | `SyncLifecycle.swift:628`, `cancelAll()` has no caller | 🐞 expected reminders cancelled and per-user prefs cleared on sign-out | [ ] | — |
| SOUT-E04 | Firebase `signOut()` throws | Error message set on the session but local data is already wiped; user stays in a signed-in-without-data state which routes to restore | | 🟡 | [ ] | — |
| SOUT-E05 | Widgets and Live Activity after sign-out | Widget snapshot is cleared by the wipe; Live Activity state not verified | | 🟡 | [ ] | — |

## DEL  Delete account

| ID | User does → App does (observable result) | Status | Manual check | Tests |
|---|---|---|---|---|
| DEL-03 | User taps Settings › "Delete Account" (red) → App shows a destructive modal: kicker "DELETE ACCOUNT", title "Delete your account?", body "This permanently deletes your account and everything in the cloud. Data on this device is removed too. This can't be undone.", consequences "ALL workouts, programs and history" and "@ your username, posts, friends and challenges", buttons "KEEP" and "DELETE FOREVER" | ✅ | [ ] | — |
| DEL-06 | User views the modal → App shows a "TYPE DELETE TO CONFIRM" field (auto-caps); "DELETE FOREVER" stays disabled until the text equals DELETE (trimmed, case-insensitive) | ✅ | [ ] | — |
| DEL-09 | User has an email/password account → App also shows a PASSWORD field and requires it non-empty before enabling the button | ✅ | [ ] | — |
| DEL-12 | User with Apple/Google account confirms → App calls the `deleteAccount` Cloud Function; if it answers unauthenticated/"recent login needed", App re-authenticates through the Apple or Google sheet and retries once | ✅ | [ ] | — |
| DEL-15 | User with an email account confirms → App calls the function; if recent login is needed, re-authenticates silently with the typed password and retries once | ✅ | [ ] | — |
| DEL-18 | System: function succeeds → App shows splash, wipes local data, signs out locally and lands on the sign-in screen | ✅ | [ ] | — |
| DEL-21 | System: the Cloud Function runs → Server deletes: challenge memberships and entries (re-ranks boards), challenges they created that have no other members (never global ones), invites both ways, their comments and likes, their posts with subcollections, follow edges both ways, usernames, `profiles/{uid}`, the whole `users/{uid}` subtree, then the Auth user (`accountDeletion.ts`, `index.ts:91`) | ✅ | [ ] | — |
| DEL-24 | User taps "KEEP" → App closes the modal, nothing deleted | ✅ | [ ] | — |
| DEL-27 | User watches progress → App shows a working state on the button and disables the fields until done or failed | ✅ | [ ] | — |

### DEL edge cases

| ID | Situation | What the app does | Why/notes | Status | Manual check | Tests |
|---|---|---|---|---|---|---|
| DEL-E01 | Wrong password on an email account | Shows the mapped message ("That email or password isn't right.") in red inside the modal; modal stays | | ✅ | [ ] | — |
| DEL-E02 | Offline | Shows "Can't reach the server. Check your connection and try again."; nothing local deleted | Deletion is ordered cloud first, local after | ✅ | [ ] | — |
| DEL-E03 | Function fails midway | Function is idempotent; user can tap DELETE FOREVER again; local data is untouched until success | | ✅ | [ ] | — |
| DEL-E04 | Apple/Google re-auth cancelled | Cancel is silent (no error text); modal stays, nothing deleted | | ✅ | [ ] | — |
| DEL-E05 | Auth user already gone server-side (`auth/user-not-found`) | Function treats it as success | | ✅ | [ ] | — |
| DEL-E06 | Challenges the user created that still have other members | Kept for the others (creator uid remains); no ownership transfer | Orphaned challenge shows a deleted creator | 🧭 PROPOSED: keep as is | [ ] | — |
| DEL-E07 | Apple "Sign in with Apple" token revocation | App does not call Apple's revoke-token API on deletion (the authorization code is captured but unused) | App Store guideline 5.1.1(v) for Apple accounts | 🧭 PROPOSED: revoke the Apple token in the function | [ ] | — |
| DEL-E08 | Active Supernova subscription | Account deletion does not cancel the App Store subscription and shows no warning | | 🧭 PROPOSED: add a line "Cancel your subscription in Settings › Apple ID" | [ ] | — |
| DEL-E09 | Function invoker is public | Anyone can call it but the handler rejects callers without a Firebase ID token | Fixed in commit 60a440c | ✅ | [ ] | — |
| DEL-E10 | Local wipe vs cloud data of other users | Posts by others that contain this user's comments/likes are removed by collection-group queries; reports about the user are not mentioned in the deletion list | | 🟡 reports collection not verified | [ ] | — |

## Open decisions for the owner (01)

- AUTH-09: Terms of Service and Privacy Policy are plain text; URLs must be hosted and set in `LegalLinks` before release.
- AUTH-84: No account linking when the same email exists under another provider; decide if Apple/Google/Email should merge.
- HND-E06 (🧭): rename cooldown; proposed unlimited for now, consider 30 days.
- ONB-E07 (🧭): bounds for weight/height; proposed weight 20-500 kg, height 80-260 cm.
- ONB-E12 (🧭): minimum age gate; proposed block under 13.
- ONB-E09: "We've set up a basic template" copy but only a split schedule is created.
- RST-E01 (🧭): add a timeout and escape to the restore screen (proposed 30 s).
- RST-E06 (🧭): warn before wiping when a different account signs in over unsynced data.
- SOUT-E01 (bug): sign-out can silently drop unsynced edits while the alert says data is safe.
- SOUT-E02 (🧭): block sign-out during an active workout.
- SOUT-E03 (bug): sign-out does not cancel local notifications or clear reminder toggles.
- DEL-E06 (🧭): orphaned challenges with other members.
- DEL-E07 (🧭): Apple token revocation on delete.
- DEL-E08 (🧭): subscription warning on delete.
- No guest/offline-first mode: the app cannot be used before signing in and onboarding needs network (ONB-E01).
