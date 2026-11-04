# Ore design review

Second review. Screens crawled: 72 · elements tapped or skipped: 348 · states: free-active, member-active, new-user, social

Statuses: OK · DEAD END (tap does nothing) · PLACEHOLDER (blank / coming soon) · FAKE AFFORDANCE (looks tappable, isn't) · TRAP (no way back) · INCONSISTENT (contradicts another screen) · OFF-SYSTEM (breaks the design rules) · UNVERIFIED (the crawl flagged it, not confirmed) · SKIPPED (not tapped on purpose: ends the session, deletes, spends, posts or leaves the app).

## Fixes from the first review

Every item from the first review, with what was done and how it was checked. "Test" is a UI test in `OreUITests/Tests/ReviewFixesUITests.swift` (9 tests, all passing against the emulators) unless stated. FIXED means changed and checked; items that already worked say so instead of claiming a fix.

| # | Item | Status | What was done / how it was checked |
|---|---|---|---|
| 1 | WHAT'S TODAY? sheet | FIXED | Rows restyled like the Programs list: no avatar, name Archivo 700 caps, `5 EXERCISES · AVG 52 MIN` in Space Mono, `›`. Selecting a row set the workout and closed, and Close dismissed, in the first review too (`testNotTodayPicker…`: choose, Close, and it does not reappear on another tab). Presented from Home only. Screenshot: `147-home-not-today-light.png` / `179-home-not-today-dark.png`. |
| 2 | Home hero and week | FIXED | Hero reads `UP NEXT · FRI` once today's workout is logged or today is a rest day of the program (`HomeWeekStats.heroLabel`; unit test + `testHeroSaysUpNext…`). The dev seed trained Sun–Fri while the program is Mon–Sat; the seed now matches the program (`DevDay.schedule`). Only today's ledger row is tinted. |
| 3 | Cloud Sync | FIXED | Opens its own Cloud Sync screen. Members: status, last synced, SYNC NOW. Free: a locked Supernova state with GO SUPERNOVA*. Never Add Friends (`testCloudSyncOpensItsOwnScreenFreeAndMember`, free and member). The Add Friends screenshot in the first review was the crawler chaining taps. Caveat: syncing itself is not gated for free users; only the screen shows the locked state. |
| 4 | Traps | FIXED / already worked | Edit name Back and Save return to the profile, Weekly Recap week row keeps a working ‹, and Equipment "+ ADD PROFILE" opens a new-profile form: all three already worked and are now covered by tests. New: "+ Add Equipment", profile rows and equipment rows open an editor (`EditEquipmentProfileView`) (`testEquipmentAddProfile…`). |
| 5 | History → workout | FIXED | Title is the workout name with `WED 4 NOV · 69 MIN · 17 SETS` under it, the same full workout view the feed uses, and a ··· menu with Edit, Duplicate, Delete (`testHistoryWorkoutHasTheNameAndTheDateLine…`). |
| 6 | Weekly streak everywhere | FIXED | More, Home, ticker, profile, Your profile and friend rows show `N WK` (no `55D`). The synced streak is now weeks, so existing Firestore values change on the next sync. |
| 7 | Week labels | FIXED | Home reads `PROGRAM WK 9`; Body and the calendar keep calendar weeks. |
| 8 | Body ticker | FIXED | Same point of last week, muscle-group names, no zero changes, at most 6 items, alternating up/down, member's IN WINDOW last. Unit tests in `BodyPageStatsTests` (both new tests pass). |
| 9 | Home stats | FIXED | PRS shows the count only (no arrow); `AVG n MIN` uses the last 5 sessions whenever any exist. `HomeWeekStatsTests`. |
| 10 | No blur, no shadow | FIXED | Tab bar is an opaque canvas with a top hairline; shadows removed from DestructiveModal, WorkoutModal, ShareCardView; `ultraThinMaterial` removed from CommentsView; gold glows removed from LiftHistoryView. **One exception, on purpose: the glass card on the Supernova member page keeps its blur.** Not run: a Release build (`bin/test.sh --release`). |
| 11 | GO SUPERNOVA banner | FIXED | Lightning tile removed; FANS → FOLLOWERS (More and profile). |
| 12 | History list meta | FIXED | Space Mono caps with tracking; the name stays Archivo 700 Title Case. |
| 13 | Fake affordances | PARTLY VERIFIED | Activity privacy rows open a picker (already worked; `testActivityPrivacyRowOpensAPicker`). Reply puts the cursor in the composer (`testCommentsReplyFocusesTheComposer`). Tapping a commenter or a person in NEEDS YOU now opens their profile: **built, not UI-tested**, because the only seeded comment is the signed-in user's own, and your own name is deliberately not a link. **Comment options (···) is unverified**: XCUITest never saw the dialog open, as a confirmation dialog or as a Menu, so I left the original dialog code and cannot say whether it is a test artefact or a real bug. Worth a minute by hand. |
| 14 | FREE/MEMBER toggles | FIXED | `PreviewMembership` is compiled for debug builds only. |
| 15 | Hit areas, labels, dead code | FIXED (hit areas measured for 3) | NOT TODAY?, Search and Profile measured ≥ 44 × 44 in a test. Bell, avatar, back button, Reply and ··· were given 44 pt hit areas but not measured. Tab bar items already had labels; labels were added where the controls above were touched, but I did not audit every icon button in the app. `MuscleDetailSheet.swift` deleted. |

### Not covered by a test, or worth knowing

- The crawl is slow (about a minute per tapped element) and flags anything that changes a page in place as UNVERIFIED. This run found no DEAD END, TRAP or FAKE AFFORDANCE; the Unverified list below is leads, not findings.
- `TutorialViewModelTests` (11 tests) time out in the parallel unit run and pass or fail inconsistently alone. They do not touch anything changed here.
- Firestore and Storage rules are still not deployed (unchanged from before).

### Second review: what was captured

Light and dark: every screen the crawl reaches (free, member, new user, social), the logger from start to a posted workout (start, keypad, set type, rest, ··· menu, finish modal, full-screen body map summary, composer, after post), challenges (create, friend board, invite, sent), pending activity, Add friends, your profile, a friend's profile, and the paywall opened and closed (never purchased). Dark mode is a replay of each light screen's path (`ReviewDarkReplayUITests`), not a second crawl.


## Flags

### Blocking (0)

None.

### Visible (0)

None.

### Minor (0)

None.

### Unverified (130)

Flags the tap crawl raised that no one has confirmed by hand. The crawl cannot tell a control that changes the page in place from one that does nothing, so treat these as leads, not findings.

| status | where | element | note | screenshot |
|---|---|---|---|---|
| UNVERIFIED | free-active · home | Profile | crawler could not confirm (tap changed nothing on screen) |  |
| UNVERIFIED | free-active · home | NOT TODAY? › | crawler could not confirm (looks tappable but nothing happens) |  |
| UNVERIFIED | free-active · home>search | All | crawler could not confirm (tap changed nothing on screen) |  |
| UNVERIFIED | free-active · home>search | Exercises | crawler could not confirm (tap changed nothing on screen) |  |
| UNVERIFIED | free-active · home>search | Workouts | crawler could not confirm (tap changed nothing on screen) |  |
| UNVERIFIED | free-active · home>search | Friends | crawler could not confirm (tap changed nothing on screen) |  |
| UNVERIFIED | free-active · home>search | CLEAR | crawler could not confirm (tap changed nothing on screen) |  |
| UNVERIFIED | free-active · home>search | search | crawler could not confirm (tap changed nothing on screen) |  |
| UNVERIFIED | free-active · home>search | Dictate | crawler could not confirm (tap changed nothing on screen) |  |
| UNVERIFIED | free-active · home>search | Emoji | crawler could not confirm (tap changed nothing on screen) |  |
| UNVERIFIED | member-active · body>calendar | WEEK 45, WHOLE WEEK, 3 SESSIONS · 50 SETS, SHOW ON MAP › | crawler could not confirm (looks tappable but nothing happens) |  |
| UNVERIFIED | member-active · home | Search | crawler could not confirm (no way back found from PUSH DAY) | 44-search-push-day-member-active-light.png |
| UNVERIFIED | member-active · home | Profile | crawler could not confirm (tap changed nothing on screen) |  |
| UNVERIFIED | member-active · home | NOT TODAY? › | crawler could not confirm (looks tappable but nothing happens) |  |
| UNVERIFIED | member-active · home>search | All | crawler could not confirm (tap changed nothing on screen) |  |
| UNVERIFIED | member-active · home>search | Exercises | crawler could not confirm (tap changed nothing on screen) |  |
| UNVERIFIED | member-active · home>search | Workouts | crawler could not confirm (tap changed nothing on screen) |  |
| UNVERIFIED | member-active · home>search | Friends | crawler could not confirm (tap changed nothing on screen) |  |
| UNVERIFIED | member-active · home>search | CLEAR | crawler could not confirm (tap changed nothing on screen) |  |
| UNVERIFIED | member-active · more | FREE | crawler could not confirm (tap changed nothing on screen) |  |
| UNVERIFIED | member-active · more | MEMBER | crawler could not confirm (tap changed nothing on screen) |  |
| UNVERIFIED | member-active · more>equipment-profiles-plates-and-bars-at-each-gym-using-commercial-gym | Commercial Gym, ACTIVE, 20 kg bar · plates to 25 kg · 12 equipment types | crawler could not confirm (tap changed nothing on screen) |  |
| UNVERIFIED | member-active · more>equipment-profiles-plates-and-bars-at-each-gym-using-commercial-gym | Home Gym, 20 kg bar · plates to 20 kg · 5 equipment types | crawler could not confirm (tap changed nothing on screen) |  |
| UNVERIFIED | member-active · more>equipment-profiles-plates-and-bars-at-each-gym-using-commercial-gym | + ADD PROFILE | crawler could not confirm (tap changed nothing on screen) |  |
| UNVERIFIED | member-active · more>equipment-profiles-plates-and-bars-at-each-gym-using-commercial-gym | ✓, Band | crawler could not confirm (tap changed nothing on screen) |  |
| UNVERIFIED | member-active · more>equipment-profiles-plates-and-bars-at-each-gym-using-commercial-gym | ✓, Barbell | crawler could not confirm (tap changed nothing on screen) |  |
| UNVERIFIED | member-active · more>equipment-profiles-plates-and-bars-at-each-gym-using-commercial-gym | +, Add Equipment | crawler could not confirm (tap changed nothing on screen) |  |
| UNVERIFIED | member-active · more>history-every-workout-you-have-logged-45-so-far | (unlabelled cell) | crawler could not confirm (looks tappable but nothing happens) |  |
| UNVERIFIED | member-active · more>weekly-recap-training-food-and-steps-for-the-week-every-sunday | This week, SHOWING, ›, 2 Nov–8 Nov · 3 workouts · 25.1 t | crawler could not confirm (no way back found from PUSH DAY) | 56-this-week-showing-2-nov-8-nov-3-workouts-25-1-t-push-day-member-active-light.png |
| UNVERIFIED | member-active · programs | New program | crawler could not confirm (no way back found from START FROM) | 47-new-program-start-from-member-active-light.png |
| UNVERIFIED | member-active · programs | PUSH PULL LEGS, 3 WORKOUTS · 6 DAYS/WK · 11H AGO, Trains MON · TUE · WED · THU · FRI · SAT, › | crawler could not confirm (no way back found from PUSH PULL LEGS) | 48-push-pull-legs-3-workouts-6-days-wk-11h-ago-trains-mon-tue-wed-thu-fri-member-active-light.png |
| UNVERIFIED | member-active · programs>new-program | +, Blank, Start from scratch and add your own workouts., › | crawler could not confirm (looks tappable but nothing happens) |  |
| UNVERIFIED | member-active · programs>new-program | 6D, Push Pull Legs, Push, Pull and Legs take turns across six days. High frequency., 3 WORKOUTS · 6 DAYS/WK, › | crawler could not confirm (looks tappable but nothing happens) |  |
| UNVERIFIED | member-active · programs>push-pull-legs-3-workouts-6-days-wk-11h-ago-trains-mon-tue-wed-thu-fri | START | crawler could not confirm (tap changed nothing on screen) |  |
| UNVERIFIED | member-active · programs>push-pull-legs-3-workouts-6-days-wk-11h-ago-trains-mon-tue-wed-thu-fri | 02, PULL DAY, TUE · FRI · 5 EX, Weighted Pull Up, 4 × 8, Barbell Row, 4 × 9, Lat Pulldown, 3 × 12, Face Pull, 3 × 15, Barbell Curl, 3 × 12 | crawler could not confirm (tap changed nothing on screen) |  |
| UNVERIFIED | member-active · programs>push-pull-legs-3-workouts-6-days-wk-11h-ago-trains-mon-tue-wed-thu-fri | (unlabelled button) | crawler could not confirm (no way back found from PUSH DAY) | 49-unlabelled-button-push-day-member-active-light.png |
| UNVERIFIED | new-user · body>calendar | WEEK 45, WHOLE WEEK, NO WORKOUTS | crawler could not confirm (tap changed nothing on screen) |  |
| UNVERIFIED | new-user · home | Profile | crawler could not confirm (tap changed nothing on screen) |  |
| UNVERIFIED | new-user · home | NOT TODAY? › | crawler could not confirm (looks tappable but nothing happens) |  |
| UNVERIFIED | new-user · home>search | All | crawler could not confirm (tap changed nothing on screen) |  |
| UNVERIFIED | new-user · home>search | Exercises | crawler could not confirm (tap changed nothing on screen) |  |
| UNVERIFIED | new-user · home>search | Workouts | crawler could not confirm (tap changed nothing on screen) |  |
| UNVERIFIED | new-user · home>search | Friends | crawler could not confirm (tap changed nothing on screen) |  |
| UNVERIFIED | new-user · home>search | search | crawler could not confirm (tap changed nothing on screen) |  |
| UNVERIFIED | new-user · home>search | Dictate | crawler could not confirm (tap changed nothing on screen) |  |
| UNVERIFIED | new-user · home>search | Emoji | crawler could not confirm (tap changed nothing on screen) |  |
| UNVERIFIED | new-user · more | Cloud Sync, ›, Backs up your data automatically. Synced 3 min. ago. | crawler could not confirm (looks tappable but nothing happens) |  |
| UNVERIFIED | new-user · more | FREE | crawler could not confirm (tap changed nothing on screen) |  |
| UNVERIFIED | new-user · more | MEMBER | crawler could not confirm (tap changed nothing on screen) |  |
| UNVERIFIED | new-user · more>d-dev-lifter-dev-lifter-push-pull-legs | D | crawler could not confirm (tap changed nothing on screen) |  |
| UNVERIFIED | new-user · more>d-dev-lifter-dev-lifter-push-pull-legs | FIND FRIENDS, › | crawler could not confirm (looks tappable but nothing happens) |  |
| UNVERIFIED | new-user · more>equipment-profiles-plates-and-bars-at-each-gym-using-commercial-gym | Commercial Gym, ACTIVE, 20 kg bar · plates to 25 kg · 12 equipment types | crawler could not confirm (tap changed nothing on screen) |  |
| UNVERIFIED | new-user · more>equipment-profiles-plates-and-bars-at-each-gym-using-commercial-gym | Home Gym, 20 kg bar · plates to 20 kg · 5 equipment types | crawler could not confirm (tap changed nothing on screen) |  |
| UNVERIFIED | new-user · more>equipment-profiles-plates-and-bars-at-each-gym-using-commercial-gym | + ADD PROFILE | crawler could not confirm (tap changed nothing on screen) |  |
| UNVERIFIED | new-user · more>equipment-profiles-plates-and-bars-at-each-gym-using-commercial-gym | ✓, Band | crawler could not confirm (tap changed nothing on screen) |  |
| UNVERIFIED | new-user · more>equipment-profiles-plates-and-bars-at-each-gym-using-commercial-gym | ✓, Barbell | crawler could not confirm (tap changed nothing on screen) |  |
| UNVERIFIED | new-user · more>equipment-profiles-plates-and-bars-at-each-gym-using-commercial-gym | +, Add Equipment | crawler could not confirm (tap changed nothing on screen) |  |
| UNVERIFIED | new-user · more>settings-units-rest-timer-theme-and-notifications | Edit profile, ›, Name, username and body measurements. | crawler could not confirm (no way back found from edit-profile) | 31-edit-profile-name-username-and-body-measurements-edit-profile-new-user-light.png |
| UNVERIFIED | new-user · more>settings-units-rest-timer-theme-and-notifications | KG | crawler could not confirm (tap changed nothing on screen) |  |
| UNVERIFIED | new-user · more>settings-units-rest-timer-theme-and-notifications | LB | crawler could not confirm (tap changed nothing on screen) |  |
| UNVERIFIED | new-user · more>settings-units-rest-timer-theme-and-notifications | Gender, MALE, ›, Used for calorie estimates. | crawler could not confirm (no way back found from gender) | 70-gender-male-used-for-calorie-estimates-gender-new-user-light.png |
| UNVERIFIED | new-user · more>settings-units-rest-timer-theme-and-notifications | NEW | crawler could not confirm (tap changed nothing on screen) |  |
| UNVERIFIED | new-user · more>settings-units-rest-timer-theme-and-notifications | SOME | crawler could not confirm (tap changed nothing on screen) |  |
| UNVERIFIED | new-user · more>settings-units-rest-timer-theme-and-notifications | ADVANCED | crawler could not confirm (tap changed nothing on screen) |  |
| UNVERIFIED | new-user · more>settings-units-rest-timer-theme-and-notifications | +2.5 KG | crawler could not confirm (no way back found from PUSH DAY) | 71-2-5-kg-push-day-new-user-light.png |
| UNVERIFIED | new-user · more>settings-units-rest-timer-theme-and-notifications | +1 KG | crawler could not confirm (tap changed nothing on screen) |  |
| UNVERIFIED | new-user · more>settings-units-rest-timer-theme-and-notifications | AUTO | crawler could not confirm (tap changed nothing on screen) |  |
| UNVERIFIED | new-user · more>settings-units-rest-timer-theme-and-notifications | MANUAL | crawler could not confirm (tap changed nothing on screen) |  |
| UNVERIFIED | new-user · more>settings-units-rest-timer-theme-and-notifications | AUTO · DISMISS | crawler could not confirm (tap changed nothing on screen) |  |
| UNVERIFIED | new-user · more>settings-units-rest-timer-theme-and-notifications | HAPTIC | crawler could not confirm (no way back found from calorie-formula) | 72-haptic-calorie-formula-new-user-light.png |
| UNVERIFIED | new-user · more>settings-units-rest-timer-theme-and-notifications | BOTH | crawler could not confirm (no way back found from calorie-formula) |  |
| UNVERIFIED | new-user · more>settings-units-rest-timer-theme-and-notifications | SILENT | crawler could not confirm (no way back found from calorie-formula) |  |
| UNVERIFIED | new-user · more>settings-units-rest-timer-theme-and-notifications | SOUND | crawler could not confirm (no way back found from calorie-formula) |  |
| UNVERIFIED | new-user · more>settings-units-rest-timer-theme-and-notifications | LIGHT | crawler could not confirm (tap changed nothing on screen) |  |
| UNVERIFIED | new-user · more>settings-units-rest-timer-theme-and-notifications | DARK | crawler could not confirm (tap changed nothing on screen) |  |
| UNVERIFIED | new-user · more>settings-units-rest-timer-theme-and-notifications | SYSTEM | crawler could not confirm (tap changed nothing on screen) |  |
| UNVERIFIED | new-user · more>settings-units-rest-timer-theme-and-notifications | Training split, PPL · 6 DAYS, › | crawler could not confirm (looks tappable but nothing happens) |  |
| UNVERIFIED | new-user · more>settings-units-rest-timer-theme-and-notifications | FRIENDS ONLY | crawler could not confirm (tap changed nothing on screen) |  |
| UNVERIFIED | new-user · more>settings-units-rest-timer-theme-and-notifications | ONLY ME | crawler could not confirm (tap changed nothing on screen) |  |
| UNVERIFIED | new-user · more>settings-units-rest-timer-theme-and-notifications | EVERYONE | crawler could not confirm (tap changed nothing on screen) |  |
| UNVERIFIED | new-user · more>settings-units-rest-timer-theme-and-notifications | Workout reminders, On your training days, at your usual time. | crawler could not confirm (no way back found from PUSH DAY) |  |
| UNVERIFIED | new-user · more>weekly-recap-training-food-and-steps-for-the-week-every-sunday | This week, SHOWING, ›, 2 Nov–8 Nov · 0 workouts | crawler could not confirm (looks tappable but nothing happens) |  |
| UNVERIFIED | new-user · programs | New program | crawler could not confirm (no way back found from START FROM) | 60-new-program-start-from-new-user-light.png |
| UNVERIFIED | new-user · programs | PUSH PULL LEGS, 3 WORKOUTS · 6 DAYS/WK, Trains MON · TUE · WED · THU · FRI · SAT, › | crawler could not confirm (no way back found from PUSH PULL LEGS) | 61-push-pull-legs-3-workouts-6-days-wk-trains-mon-tue-wed-thu-fri-sat-pus-new-user-light.png |
| UNVERIFIED | new-user · programs>new-program | +, Blank, Start from scratch and add your own workouts., › | crawler could not confirm (looks tappable but nothing happens) |  |
| UNVERIFIED | new-user · programs>new-program | 6D, Push Pull Legs, Push, Pull and Legs take turns across six days. High frequency., 3 WORKOUTS · 6 DAYS/WK, › | crawler could not confirm (looks tappable but nothing happens) |  |
| UNVERIFIED | new-user · programs>push-pull-legs-3-workouts-6-days-wk-trains-mon-tue-wed-thu-fri-sat | START | crawler could not confirm (tap changed nothing on screen) |  |
| UNVERIFIED | new-user · programs>push-pull-legs-3-workouts-6-days-wk-trains-mon-tue-wed-thu-fri-sat | 02, PULL DAY, TUE · FRI · 5 EX, Weighted Pull Up, 4 × 8, Barbell Row, 4 × 9, Lat Pulldown, 3 × 12, Face Pull, 3 × 15, Barbell Curl, 3 × 12 | crawler could not confirm (tap changed nothing on screen) |  |
| UNVERIFIED | new-user · programs>push-pull-legs-3-workouts-6-days-wk-trains-mon-tue-wed-thu-fri-sat | (unlabelled button) | crawler could not confirm (no way back found from PUSH DAY) | 62-unlabelled-button-push-day-new-user-light.png |
| UNVERIFIED | social · social | Unlike | crawler could not confirm (tap changed nothing on screen) |  |
| UNVERIFIED | social · social | F, Frankie One, @FRANKIE | crawler could not confirm (tap changed nothing on screen) |  |
| UNVERIFIED | social · social | Like | crawler could not confirm (tap changed nothing on screen) |  |
| UNVERIFIED | social · social>activity | Open Private profile's profile | crawler could not confirm (tap changed nothing on screen) |  |
| UNVERIFIED | social · social>activity | IGNORE | crawler could not confirm (tap changed nothing on screen) |  |
| UNVERIFIED | social · social>activity | Open Priya Five's profile | crawler could not confirm (tap changed nothing on screen) |  |
| UNVERIFIED | social · social>activity | Workout posts, Friends see your sessions in their feed., FRIENDS ONLY, › | crawler could not confirm (looks tappable but nothing happens) |  |
| UNVERIFIED | social · social>activity | Body map, Friends see it; others see stats only., FRIENDS ONLY, › | crawler could not confirm (looks tappable but nothing happens) |  |
| UNVERIFIED | social · social>activity | Global leaderboards, Your name and rank in monthly challenges., VISIBLE, › | crawler could not confirm (looks tappable but nothing happens) |  |
| UNVERIFIED | social · social>activity | Profile, Anyone can find and view you., EVERYONE, › | crawler could not confirm (looks tappable but nothing happens) |  |
| UNVERIFIED | social · social>activity>back | Unlike | crawler could not confirm (tap changed nothing on screen) |  |
| UNVERIFIED | social · social>activity>back | Comments | crawler could not confirm (tap changed nothing on screen) |  |
| UNVERIFIED | social · social>activity>back | F, Frankie One, @FRANKIE | crawler could not confirm (tap changed nothing on screen) |  |
| UNVERIFIED | social · social>comments | Frankie One | crawler could not confirm (tap changed nothing on screen) |  |
| UNVERIFIED | social · social>comments | Open Frankie One's profile | crawler could not confirm (tap changed nothing on screen) |  |
| UNVERIFIED | social · social>comments | Reply to Frankie One | crawler could not confirm (tap changed nothing on screen) |  |
| UNVERIFIED | social · social>comments | Comment options | crawler could not confirm (tap changed nothing on screen) |  |
| UNVERIFIED | social · social>your-profile | EDIT PROFILE | crawler could not confirm (tap changed nothing on screen) |  |
| UNVERIFIED | social · social>your-profile | BACK | crawler could not confirm (tap changed nothing on screen) |  |
| UNVERIFIED | social · social>your-profile | Find friends | crawler could not confirm (tap changed nothing on screen) |  |
| UNVERIFIED | social · social>your-profile>jay-six-jay-six | PROFILE OPTIONS | crawler could not confirm (tap changed nothing on screen) |  |
| UNVERIFIED | social · social>your-profile>jay-six-jay-six | BACK | crawler could not confirm (tap changed nothing on screen) |  |
| UNVERIFIED | social · social>your-profile>jay-six-jay-six | Requested. Tap to cancel | crawler could not confirm (tap changed nothing on screen) |  |
| UNVERIFIED | social · social>your-profile>jay-six-jay-six | 7D | crawler could not confirm (tap changed nothing on screen) |  |
| UNVERIFIED | social · social>your-profile>jay-six-jay-six | 30D | crawler could not confirm (tap changed nothing on screen) |  |
| UNVERIFIED | social · social>your-profile>jay-six-jay-six | (unlabelled button) | crawler could not confirm (no way back found from Jay Six) | 19-unlabelled-button-jay-six-social-light.png |
| UNVERIFIED | social · social>your-profile>private-profile | PROFILE OPTIONS | crawler could not confirm (tap changed nothing on screen) |  |
| UNVERIFIED | social · social>your-profile>private-profile | BACK | crawler could not confirm (tap changed nothing on screen) |  |
| UNVERIFIED | social · social>your-profile>private-profile | ✓ FRIENDS | crawler could not confirm (tap changed nothing on screen) |  |
| UNVERIFIED | social · social>your-profile>private-profile | CHALLENGE | crawler could not confirm (tap changed nothing on screen) |  |
| UNVERIFIED | social · social>your-profile>private-profile | 7D | crawler could not confirm (tap changed nothing on screen) |  |
| UNVERIFIED | social · social>your-profile>private-profile | 30D | crawler could not confirm (tap changed nothing on screen) |  |
| UNVERIFIED | social · social>your-profile>private-profile | (unlabelled button) | crawler could not confirm (no way back found from Sam Two) |  |
| UNVERIFIED | social · social>your-profile>sam-two-last-trained-2-days-ago | PROFILE OPTIONS | crawler could not confirm (tap changed nothing on screen) |  |
| UNVERIFIED | social · social>your-profile>sam-two-last-trained-2-days-ago | BACK | crawler could not confirm (tap changed nothing on screen) |  |
| UNVERIFIED | social · social>your-profile>sam-two-last-trained-2-days-ago | ✓ FRIENDS | crawler could not confirm (tap changed nothing on screen) |  |
| UNVERIFIED | social · social>your-profile>sam-two-last-trained-2-days-ago | CHALLENGE | crawler could not confirm (tap changed nothing on screen) |  |
| UNVERIFIED | social · social>your-profile>sam-two-last-trained-2-days-ago | 7D | crawler could not confirm (tap changed nothing on screen) |  |
| UNVERIFIED | social · social>your-profile>sam-two-last-trained-2-days-ago | 30D | crawler could not confirm (tap changed nothing on screen) |  |
| UNVERIFIED | social · social>your-profile>sam-two-last-trained-2-days-ago | (unlabelled button) | crawler could not confirm (no way back found from Tess Three) | 23-unlabelled-button-tess-three-social-light.png |
| UNVERIFIED | social · social>your-profile>tess-three-trained-yesterday | Priya Five, @priya_5 | crawler could not confirm (tap changed nothing on screen) |  |

## Screen map


### free-active

- **home** `home` — via “tab” — 01-home-free-active-light.png
  - **PUSH DAY** `home>search` — via “Search” — 41-search-push-day-free-active-light.png
  - **PUSH DAY** `home>mon-push-day-16-5` — via “MON, PUSH DAY, 16, ▲ 5%” — 42-mon-push-day-16-5-push-day-free-active-light.png
  - **PULL DAY** `home>tue-pull-day-17-2` — via “TUE, PULL DAY, 17, ▼ 2%” — 43-tue-pull-day-17-2-pull-day-free-active-light.png

### member-active

- **home** `home` — via “tab” — 02-home-member-active-light.png
  - **PUSH DAY** `home>search` — via “Search” — 44-search-push-day-member-active-light.png
  - **PUSH DAY** `home>mon-push-day-16-5` — via “MON, PUSH DAY, 16, ▲ 5%” — 45-mon-push-day-16-5-push-day-member-active-light.png
  - **PULL DAY** `home>tue-pull-day-17-2` — via “TUE, PULL DAY, 17, ▼ 2%” — 46-tue-pull-day-17-2-pull-day-member-active-light.png
- **programs** `programs` — via “tab” — 04-programs-member-active-light.png
  - **START FROM** `programs>new-program` — via “New program” — 47-new-program-start-from-member-active-light.png
  - **PUSH PULL LEGS** `programs>push-pull-legs-3-workouts-6-days-wk-11h-ago-trains-mon-tue-wed-thu-fri` — via “PUSH PULL LEGS, 3 WORKOUTS · 6 DAYS/WK · 11H AGO, Trains MON · TUE · WED · THU · FRI · SAT, ›” — 48-push-pull-legs-3-workouts-6-days-wk-11h-ago-trains-mon-tue-wed-thu-fri-member-active-light.png
    - **PUSH DAY** `programs>push-pull-legs-3-workouts-6-days-wk-11h-ago-trains-mon-tue-wed-thu-fri>unlabelled-button` — via “(unlabelled button)” — 49-unlabelled-button-push-day-member-active-light.png
- **body** `body` — via “tab” — 27-body-member-active-light.png
  - **BODY** `body>calendar` — via “Calendar” — 28-calendar-body-member-active-light.png
- **more** `more` — via “tab” — 32-more-member-active-light.png
  - **history** `more>history-every-workout-you-have-logged-45-so-far` — via “History, ›, Every workout you have logged. 45 so far.” — 50-history-every-workout-you-have-logged-45-so-far-history-member-active-light.png
    - **MORE** `more>history-every-workout-you-have-logged-45-so-far>back` — via “Back” — 33-back-more-member-active-light.png
    - **LEG DAY** `more>history-every-workout-you-have-logged-45-so-far>leg-day-wed-4-nov-69-min-17-sets` — via “Leg Day, ›, WED 4 NOV · 69 MIN · 17 SETS” — 51-leg-day-wed-4-nov-69-min-17-sets-leg-day-member-active-light.png
    - **PULL DAY** `more>history-every-workout-you-have-logged-45-so-far>pull-day-tue-3-nov-72-min-17-sets` — via “Pull Day, ›, TUE 3 NOV · 72 MIN · 17 SETS” — 52-pull-day-tue-3-nov-72-min-17-sets-pull-day-member-active-light.png
  - **analytics** `more>analytics-1rm-volume-and-trends-for-each-exercise` — via “Analytics, ›, 1RM, volume and trends for each exercise.” — 53-analytics-1rm-volume-and-trends-for-each-exercise-analytics-member-active-light.png
    - **MORE** `more>analytics-1rm-volume-and-trends-for-each-exercise>back` — via “Back” — 34-back-more-member-active-light.png
    - **PROGRAMS** `more>analytics-1rm-volume-and-trends-for-each-exercise>unlabelled-button` — via “(unlabelled button)” — 05-unlabelled-button-programs-member-active-light.png
    - **SOCIAL** `more>analytics-1rm-volume-and-trends-for-each-exercise>unlabelled-button` — via “(unlabelled button)” — 09-unlabelled-button-social-member-active-light.png
  - **equipment** `more>equipment-profiles-plates-and-bars-at-each-gym-using-commercial-gym` — via “Equipment profiles, ›, Plates and bars at each gym. Using Commercial Gym.” — 54-equipment-profiles-plates-and-bars-at-each-gym-using-commercial-gym-eq-member-active-light.png
    - **MORE** `more>equipment-profiles-plates-and-bars-at-each-gym-using-commercial-gym>back` — via “Back” — 35-back-more-member-active-light.png
  - **weekly-recap** `more>weekly-recap-training-food-and-steps-for-the-week-every-sunday` — via “Weekly Recap, ›, Training, food and steps for the week. Every Sunday.” — 55-weekly-recap-training-food-and-steps-for-the-week-every-sunday-weekly--member-active-light.png
    - **PUSH DAY** `more>weekly-recap-training-food-and-steps-for-the-week-every-sunday>this-week-showing-2-nov-8-nov-3-workouts-25-1-t` — via “This week, SHOWING, ›, 2 Nov–8 Nov · 3 workouts · 25.1 t” — 56-this-week-showing-2-nov-8-nov-3-workouts-25-1-t-push-day-member-active-light.png
    - **PROGRAMS** `more>weekly-recap-training-food-and-steps-for-the-week-every-sunday>unlabelled-button` — via “(unlabelled button)” — 06-unlabelled-button-programs-member-active-light.png
  - **add-friends** `more>cloud-sync-backs-up-your-data-automatically-synced-3-min-ago` — via “Cloud Sync, ›, Backs up your data automatically. Synced 3 min. ago.” — 57-cloud-sync-backs-up-your-data-automatically-synced-3-min-ago-add-frien-member-active-light.png
    - **you** `more>cloud-sync-backs-up-your-data-automatically-synced-3-min-ago>back` — via “BACK” — 58-back-you-member-active-light.png

### new-user

- **home** `home` — via “tab” — 03-home-new-user-light.png
  - **PUSH DAY** `home>search` — via “Search” — 59-search-push-day-new-user-light.png
- **programs** `programs` — via “tab” — 07-programs-new-user-light.png
  - **START FROM** `programs>new-program` — via “New program” — 60-new-program-start-from-new-user-light.png
  - **PUSH PULL LEGS** `programs>push-pull-legs-3-workouts-6-days-wk-trains-mon-tue-wed-thu-fri-sat` — via “PUSH PULL LEGS, 3 WORKOUTS · 6 DAYS/WK, Trains MON · TUE · WED · THU · FRI · SAT, ›” — 61-push-pull-legs-3-workouts-6-days-wk-trains-mon-tue-wed-thu-fri-sat-pus-new-user-light.png
    - **PUSH DAY** `programs>push-pull-legs-3-workouts-6-days-wk-trains-mon-tue-wed-thu-fri-sat>unlabelled-button` — via “(unlabelled button)” — 62-unlabelled-button-push-day-new-user-light.png
- **body** `body` — via “tab” — 29-body-new-user-light.png
  - **BODY** `body>calendar` — via “Calendar” — 30-calendar-body-new-user-light.png
- **more** `more` — via “tab” — 36-more-new-user-light.png
  - **profile** `more>d-dev-lifter-dev-lifter-push-pull-legs` — via “D, Dev Lifter, @dev_lifter · PUSH PULL LEGS, ›” — 63-d-dev-lifter-dev-lifter-push-pull-legs-profile-new-user-light.png
    - **MORE** `more>d-dev-lifter-dev-lifter-push-pull-legs>back` — via “Back” — 37-back-more-new-user-light.png
    - **Name** `more>d-dev-lifter-dev-lifter-push-pull-legs>edit` — via “EDIT” — 64-edit-name-new-user-light.png
    - **PROGRAMS** `more>d-dev-lifter-dev-lifter-push-pull-legs>unlabelled-button` — via “(unlabelled button)” — 08-unlabelled-button-programs-new-user-light.png
    - **SOCIAL** `more>d-dev-lifter-dev-lifter-push-pull-legs>unlabelled-button` — via “(unlabelled button)” — 10-unlabelled-button-social-new-user-light.png
  - **history** `more>history-every-workout-you-have-logged-0-so-far` — via “History, ›, Every workout you have logged. 0 so far.” — 65-history-every-workout-you-have-logged-0-so-far-history-new-user-light.png
    - **MORE** `more>history-every-workout-you-have-logged-0-so-far>back` — via “Back” — 38-back-more-new-user-light.png
  - **analytics** `more>analytics-1rm-volume-and-trends-for-each-exercise` — via “Analytics, ›, 1RM, volume and trends for each exercise.” — 66-analytics-1rm-volume-and-trends-for-each-exercise-analytics-new-user-light.png
    - **MORE** `more>analytics-1rm-volume-and-trends-for-each-exercise>back` — via “Back” — 39-back-more-new-user-light.png
  - **equipment** `more>equipment-profiles-plates-and-bars-at-each-gym-using-commercial-gym` — via “Equipment profiles, ›, Plates and bars at each gym. Using Commercial Gym.” — 67-equipment-profiles-plates-and-bars-at-each-gym-using-commercial-gym-eq-new-user-light.png
  - **weekly-recap** `more>weekly-recap-training-food-and-steps-for-the-week-every-sunday` — via “Weekly Recap, ›, Training, food and steps for the week. Every Sunday.” — 68-weekly-recap-training-food-and-steps-for-the-week-every-sunday-weekly--new-user-light.png
  - **settings** `more>settings-units-rest-timer-theme-and-notifications` — via “Settings, ›, Units, rest timer, theme and notifications.” — 69-settings-units-rest-timer-theme-and-notifications-settings-new-user-light.png
    - **MORE** `more>settings-units-rest-timer-theme-and-notifications>back` — via “Back” — 40-back-more-new-user-light.png
    - **edit-profile** `more>settings-units-rest-timer-theme-and-notifications>edit-profile-name-username-and-body-measurements` — via “Edit profile, ›, Name, username and body measurements.” — 31-edit-profile-name-username-and-body-measurements-edit-profile-new-user-light.png
    - **gender** `more>settings-units-rest-timer-theme-and-notifications>gender-male-used-for-calorie-estimates` — via “Gender, MALE, ›, Used for calorie estimates.” — 70-gender-male-used-for-calorie-estimates-gender-new-user-light.png
    - **PUSH DAY** `more>settings-units-rest-timer-theme-and-notifications>2-5-kg` — via “+2.5 KG” — 71-2-5-kg-push-day-new-user-light.png
    - **calorie-formula** `more>settings-units-rest-timer-theme-and-notifications>haptic` — via “HAPTIC” — 72-haptic-calorie-formula-new-user-light.png

### social

- **social** `social` — via “tab” — 11-social-social-light.png
  - **activity** `social>activity` — via “Activity” — 12-activity-activity-social-light.png
    - **SOCIAL** `social>activity>back` — via “Back” — 13-back-social-social-light.png
      - **you** `social>activity>back>your-profile` — via “Your profile” — 14-your-profile-you-social-light.png
      - **Tess Three** `social>activity>back>t-tess-three-tess-t` — via “T, Tess Three, @TESS.T” — 15-t-tess-three-tess-t-tess-three-social-light.png
  - **you** `social>your-profile` — via “Your profile” — 16-your-profile-you-social-light.png
    - **Jay Six** `social>your-profile>jay-six-jay-six` — via “Jay Six, @jay.six” — 17-jay-six-jay-six-jay-six-social-light.png
      - **UPPER BODY** `social>your-profile>jay-six-jay-six>upper-body-4d-ago-14-sets-4-0k` — via “Upper Body, 4D AGO · 14 SETS · 4.0K, ›” — 18-upper-body-4d-ago-14-sets-4-0k-upper-body-social-light.png
      - **Jay Six** `social>your-profile>jay-six-jay-six>unlabelled-button` — via “(unlabelled button)” — 19-unlabelled-button-jay-six-social-light.png
    - **Sam Two** `social>your-profile>private-profile` — via “Private profile” — 20-private-profile-sam-two-social-light.png
      - **PULL DAY** `social>your-profile>private-profile>front-body-map-pull-day-2d-ago-14-sets-4-0k` — via “Front body map, Pull Day, 2D AGO · 14 SETS · 4.0K, ›” — 21-front-body-map-pull-day-2d-ago-14-sets-4-0k-pull-day-social-light.png
    - **Tess Three** `social>your-profile>sam-two-last-trained-2-days-ago` — via “Sam Two, Last trained 2 days ago” — 22-sam-two-last-trained-2-days-ago-tess-three-social-light.png
      - **Tess Three** `social>your-profile>sam-two-last-trained-2-days-ago>unlabelled-button` — via “(unlabelled button)” — 23-unlabelled-button-tess-three-social-light.png
      - **FULL BODY** `social>your-profile>sam-two-last-trained-2-days-ago>front-body-map-full-body-yesterday-14-sets-4-0k` — via “Front body map, Full Body, YESTERDAY · 14 SETS · 4.0K, ›” — 24-front-body-map-full-body-yesterday-14-sets-4-0k-full-body-social-light.png
    - **add-friends** `social>your-profile>tess-three-trained-yesterday` — via “Tess Three, Trained yesterday” — 25-tess-three-trained-yesterday-add-friends-social-light.png
  - **SOCIAL** `social>comments` — via “Comments” — 26-comments-social-social-light.png

## Tap audit by screen


### free-active · `home>search` — 41-search-push-day-free-active-light.png

| element | action | destination | status | screenshot |
|---|---|---|---|---|
| Back (button) | tap | changed in place (34 labels) | OK |  |
| All (button) | tap | crawler could not confirm (tap changed nothing on screen) | UNVERIFIED |  |
| Exercises (button) | tap | crawler could not confirm (tap changed nothing on screen) | UNVERIFIED |  |
| Workouts (button) | tap | crawler could not confirm (tap changed nothing on screen) | UNVERIFIED |  |
| Friends (button) | tap | crawler could not confirm (tap changed nothing on screen) | UNVERIFIED |  |
| CLEAR (button) | tap | crawler could not confirm (tap changed nothing on screen) | UNVERIFIED |  |
| Remove bench (button) | — | not tapped: ends the session, deletes, spends, posts or leaves the app | SKIPPED |  |
| Remove romanian deadlift (button) | — | not tapped: ends the session, deletes, spends, posts or leaves the app | SKIPPED |  |
| shift (button) | tap | starts a workout | OK |  |
| search (button) | tap | crawler could not confirm (tap changed nothing on screen) | UNVERIFIED |  |
| Dictate (button) | tap | crawler could not confirm (tap changed nothing on screen) | UNVERIFIED |  |
| Emoji (button) | tap | crawler could not confirm (tap changed nothing on screen) | UNVERIFIED |  |

### free-active · `home` — 01-home-free-active-light.png

| element | action | destination | status | screenshot |
|---|---|---|---|---|
| Search (button) | tap | PUSH DAY | OK | 41-search-push-day-free-active-light.png |
| Profile (button) | tap | crawler could not confirm (tap changed nothing on screen) | UNVERIFIED |  |
| NOT TODAY? › (button) | tap | crawler could not confirm (looks tappable but nothing happens) | UNVERIFIED |  |
| MON, PUSH DAY, 16, ▲ 5% (button) | tap | PUSH DAY | OK | 42-mon-push-day-16-5-push-day-free-active-light.png |
| TUE, PULL DAY, 17, ▼ 2% (button) | tap | PULL DAY | OK | 43-tue-pull-day-17-2-pull-day-free-active-light.png |
| START WORKOUT, › (button) | — | not tapped: ends the session, deletes, spends, posts or leaves the app | SKIPPED |  |
| (unlabelled button) (button) | tap | crawler artifact: a back or tab-bar tap that landed on a root screen | OK |  |

### free-active · `home>mon-push-day-16-5` — 42-mon-push-day-16-5-push-day-free-active-light.png

| element | action | destination | status | screenshot |
|---|---|---|---|---|
| Back (button) | tap | changed in place (42 labels) | OK |  |

### free-active · `home>tue-pull-day-17-2` — 43-tue-pull-day-17-2-pull-day-free-active-light.png

| element | action | destination | status | screenshot |
|---|---|---|---|---|
| Back (button) | tap | changed in place (43 labels) | OK |  |

### member-active · `home>search` — 44-search-push-day-member-active-light.png

| element | action | destination | status | screenshot |
|---|---|---|---|---|
| Back (button) | tap | changed in place (34 labels) | OK |  |
| All (button) | tap | crawler could not confirm (tap changed nothing on screen) | UNVERIFIED |  |
| Exercises (button) | tap | crawler could not confirm (tap changed nothing on screen) | UNVERIFIED |  |
| Workouts (button) | tap | crawler could not confirm (tap changed nothing on screen) | UNVERIFIED |  |
| Friends (button) | tap | crawler could not confirm (tap changed nothing on screen) | UNVERIFIED |  |
| CLEAR (button) | tap | crawler could not confirm (tap changed nothing on screen) | UNVERIFIED |  |
| Remove bench (button) | — | not tapped: ends the session, deletes, spends, posts or leaves the app | SKIPPED |  |
| Remove romanian deadlift (button) | — | not tapped: ends the session, deletes, spends, posts or leaves the app | SKIPPED |  |
| Dictate (button) | tap | changed in place (78 labels) | OK |  |
| Emoji (button) | tap | changed in place (52 labels) | OK |  |

### member-active · `home` — 02-home-member-active-light.png

| element | action | destination | status | screenshot |
|---|---|---|---|---|
| Search (button) | tap | PUSH DAY | UNVERIFIED | 44-search-push-day-member-active-light.png |
| Profile (button) | tap | crawler could not confirm (tap changed nothing on screen) | UNVERIFIED |  |
| NOT TODAY? › (button) | tap | crawler could not confirm (looks tappable but nothing happens) | UNVERIFIED |  |
| MON, PUSH DAY, 16, ▲ 5% (button) | tap | PUSH DAY | OK | 45-mon-push-day-16-5-push-day-member-active-light.png |
| TUE, PULL DAY, 17, ▼ 2% (button) | tap | PULL DAY | OK | 46-tue-pull-day-17-2-pull-day-member-active-light.png |
| START WORKOUT, › (button) | — | not tapped: ends the session, deletes, spends, posts or leaves the app | SKIPPED |  |
| (unlabelled button) (button) | tap | changed in place (50 labels) | OK |  |
| (unlabelled button) (button) | tap | changed in place (22 labels) | OK |  |

### member-active · `home>mon-push-day-16-5` — 45-mon-push-day-16-5-push-day-member-active-light.png

| element | action | destination | status | screenshot |
|---|---|---|---|---|
| Back (button) | tap | changed in place (40 labels) | OK |  |

### member-active · `home>tue-pull-day-17-2` — 46-tue-pull-day-17-2-pull-day-member-active-light.png

| element | action | destination | status | screenshot |
|---|---|---|---|---|
| Back (button) | tap | changed in place (42 labels) | OK |  |

### member-active · `programs>new-program` — 47-new-program-start-from-member-active-light.png

| element | action | destination | status | screenshot |
|---|---|---|---|---|
| Back (button) | tap | changed in place (34 labels) | OK |  |
| +, Blank, Start from scratch and add your own workouts., › (button) | tap | crawler could not confirm (looks tappable but nothing happens) | UNVERIFIED |  |
| 6D, Push Pull Legs, Push, Pull and Legs take turns across six days. High frequency., 3 WORKOUTS · 6 DAYS/WK, › (button) | tap | crawler could not confirm (looks tappable but nothing happens) | UNVERIFIED |  |
| 4D, Upper Lower, Two upper and two lower sessions a week. Balanced frequency., 2 WORKOUTS · 4 DAYS/WK, › (button) | tap | starts a workout | OK |  |
| 3D, Full Body, Every major muscle group each session. Great for beginners., 2 WORKOUTS · 3 DAYS/WK, › (button) | tap | changed in place (45 labels) | OK |  |
| (unlabelled button) (button) | tap | crawler artifact: a back or tab-bar tap that landed on a root screen | OK |  |
| (unlabelled button) (button) | tap | changed in place (37 labels) | OK |  |

### member-active · `programs` — 04-programs-member-active-light.png

| element | action | destination | status | screenshot |
|---|---|---|---|---|
| New program (button) | tap | START FROM | UNVERIFIED | 47-new-program-start-from-member-active-light.png |
| START WORKOUT, › (button) | — | not tapped: ends the session, deletes, spends, posts or leaves the app | SKIPPED |  |
| PUSH PULL LEGS, 3 WORKOUTS · 6 DAYS/WK · 11H AGO, Trains MON · TUE · WED · THU · FRI · SAT, › (button) | tap | PUSH PULL LEGS | UNVERIFIED | 48-push-pull-legs-3-workouts-6-days-wk-11h-ago-trains-mon-tue-wed-thu-fri-member-active-light.png |
| (unlabelled button) (button) | tap | crawler artifact: a back or tab-bar tap that landed on a root screen | OK |  |
| (unlabelled button) (button) | tap | changed in place (22 labels) | OK |  |

### member-active · `programs>push-pull-legs-3-workouts-6-days-wk-11h-ago-trains-mon-tue-wed-thu-fri` — 48-push-pull-legs-3-workouts-6-days-wk-11h-ago-trains-mon-tue-wed-thu-fri-member-active-light.png

| element | action | destination | status | screenshot |
|---|---|---|---|---|
| Back (button) | tap | changed in place (61 labels) | OK |  |
| EDIT (button) | tap | START FROM | OK |  |
| START (button) | tap | starts a workout | OK |  |
| 01, PUSH DAY, NEXT, MON · THU · 5 EX, Barbell Bench Press, 4 × 8, Overhead Press, 3 × 10, Incline Dumbbell Bench Press, 3 × 12, Lateral Raise, 3 × 15, Tricep Pushdown, 3 × 13 (button) | tap | changed in place (69 labels) | OK |  |
| START (button) | tap | crawler could not confirm (tap changed nothing on screen) | UNVERIFIED |  |
| 02, PULL DAY, TUE · FRI · 5 EX, Weighted Pull Up, 4 × 8, Barbell Row, 4 × 9, Lat Pulldown, 3 × 12, Face Pull, 3 × 15, Barbell Curl, 3 × 12 (button) | tap | crawler could not confirm (tap changed nothing on screen) | UNVERIFIED |  |
| + ADD WORKOUT (button) | tap | changed in place (74 labels) | OK |  |
| (unlabelled button) (button) | tap | PUSH DAY | UNVERIFIED | 49-unlabelled-button-push-day-member-active-light.png |
| (unlabelled button) (button) | tap | changed in place (57 labels) | OK |  |

### member-active · `body>calendar` — 28-calendar-body-member-active-light.png

| element | action | destination | status | screenshot |
|---|---|---|---|---|
| Calendar (button) | tap | changed in place (110 labels) | OK |  |
| Close calendar (button) | tap | changes the page in place (the crawl can't see that) | OK |  |
| Previous month (button) | tap | changes the page in place (the crawl can't see that) | OK |  |
| Next month (button) | tap | changed in place (48 labels) | OK |  |
| 1 REST (button) | tap | changes the page in place (the crawl can't see that) | OK |  |
| Week 44 (button) | tap | changes the page in place (the crawl can't see that) | OK |  |
| 2 PUSH 16 (button) | tap | changes the page in place (the crawl can't see that) | OK |  |
| Week 45 (button) | tap | changes the page in place (the crawl can't see that) | OK |  |
| WEEK 45, WHOLE WEEK, 3 SESSIONS · 50 SETS, SHOW ON MAP › (button) | tap | crawler could not confirm (looks tappable but nothing happens) | UNVERIFIED |  |
| (unlabelled button) (button) | tap | changed in place (45 labels) | OK |  |
| (unlabelled button) (button) | tap | changed in place (22 labels) | OK |  |

### member-active · `body` — 27-body-member-active-light.png

| element | action | destination | status | screenshot |
|---|---|---|---|---|
| Calendar (button) | tap | BODY | OK | 28-calendar-body-member-active-light.png |
| FREQUENCY, * (button) | tap | changed in place (48 labels) | OK |  |
| VOLUME (button) | tap | changed in place (48 labels) | OK |  |
| M, 16 (button) | tap | changes the page in place (the crawl can't see that) | OK |  |
| T, 17 (button) | tap | changes the page in place (the crawl can't see that) | OK |  |
| WEEK, 50 (button) | tap | changes the page in place (the crawl can't see that) | OK |  |
| Show back view (button) | tap | changes the page in place (the crawl can't see that) | OK |  |
| (unlabelled button) (button) | tap | changed in place (47 labels) | OK |  |
| (unlabelled button) (button) | tap | changed in place (22 labels) | OK |  |
| ▸, CHEST, 7 / 16 (button) | tap | changes the page in place (the crawl can't see that) | OK |  |
| ▸, BACK, 14 / 42 (button) | tap | changes the page in place (the crawl can't see that) | OK |  |
| ▸, SHOULDERS, 9 / 26 (button) | tap | changes the page in place (the crawl can't see that) | OK |  |
| ▸, ARMS, 6 / 26 (button) | tap | changes the page in place (the crawl can't see that) | OK |  |
| ▸, CORE, 0 / 18 (button) | tap | changes the page in place (the crawl can't see that) | OK |  |
| ▸, LEGS, 17 / 58 (button) | tap | changes the page in place (the crawl can't see that) | OK |  |

### member-active · `more` — 32-more-member-active-light.png

| element | action | destination | status | screenshot |
|---|---|---|---|---|
| Supernova membership (button) | — | not tapped: ends the session, deletes, spends, posts or leaves the app | SKIPPED |  |
| History, ›, Every workout you have logged. 45 so far. (button) | tap | history | OK | 50-history-every-workout-you-have-logged-45-so-far-history-member-active-light.png |
| Analytics, ›, 1RM, volume and trends for each exercise. (button) | tap | analytics | OK | 53-analytics-1rm-volume-and-trends-for-each-exercise-analytics-member-active-light.png |
| Equipment profiles, ›, Plates and bars at each gym. Using Commercial Gym. (button) | tap | equipment | OK | 54-equipment-profiles-plates-and-bars-at-each-gym-using-commercial-gym-eq-member-active-light.png |
| Weekly Recap, ›, Training, food and steps for the week. Every Sunday. (button) | tap | weekly-recap | OK | 55-weekly-recap-training-food-and-steps-for-the-week-every-sunday-weekly--member-active-light.png |
| Settings, ›, Units, rest timer, theme and notifications. (button) | tap | changed in place (82 labels) | OK |  |
| (unlabelled button) (button) | tap | changed in place (58 labels) | OK |  |
| (unlabelled button) (button) | tap | changed in place (22 labels) | OK |  |
| Cloud Sync, ›, Backs up your data automatically. Synced 3 min. ago. (button) | tap | add-friends | OK | 57-cloud-sync-backs-up-your-data-automatically-synced-3-min-ago-add-frien-member-active-light.png |
| Tutorial, Replays the walkthrough of logging a workout. (button) | — | not tapped: ends the session, deletes, spends, posts or leaves the app | SKIPPED |  |
| Data import, ›, Bring your history in from Strong, Hevy or a CSV. (button) | — | not tapped: ends the session, deletes, spends, posts or leaves the app | SKIPPED |  |
| Privacy & legal, ›, Privacy policy, terms and your data. (button) | — | not tapped: ends the session, deletes, spends, posts or leaves the app | SKIPPED |  |
| Sign out (button) | — | not tapped: ends the session, deletes, spends, posts or leaves the app | SKIPPED |  |
| FREE (button) | tap | crawler could not confirm (tap changed nothing on screen) | UNVERIFIED |  |
| MEMBER (button) | tap | crawler could not confirm (tap changed nothing on screen) | UNVERIFIED |  |

### member-active · `more>history-every-workout-you-have-logged-45-so-far` — 50-history-every-workout-you-have-logged-45-so-far-history-member-active-light.png

| element | action | destination | status | screenshot |
|---|---|---|---|---|
| Calendar view (button) | tap | changed in place (140 labels) | OK |  |
| Back (button) | tap | MORE | OK | 33-back-more-member-active-light.png |
| List view (button) | tap | changes the page in place (the crawl can't see that) | OK |  |
| (unlabelled cell) (cell) | tap | crawler could not confirm (looks tappable but nothing happens) | UNVERIFIED |  |
| Leg Day, ›, WED 4 NOV · 69 MIN · 17 SETS (button) | tap | LEG DAY | OK | 51-leg-day-wed-4-nov-69-min-17-sets-leg-day-member-active-light.png |
| Pull Day, ›, TUE 3 NOV · 72 MIN · 17 SETS (button) | tap | PULL DAY | OK | 52-pull-day-tue-3-nov-72-min-17-sets-pull-day-member-active-light.png |

### member-active · `more>analytics-1rm-volume-and-trends-for-each-exercise` — 53-analytics-1rm-volume-and-trends-for-each-exercise-analytics-member-active-light.png

| element | action | destination | status | screenshot |
|---|---|---|---|---|
| Back (button) | tap | MORE | OK | 34-back-more-member-active-light.png |
| (unlabelled button) (button) | tap | PROGRAMS | OK | 05-unlabelled-button-programs-member-active-light.png |
| (unlabelled button) (button) | tap | SOCIAL | OK | 09-unlabelled-button-social-member-active-light.png |

### member-active · `more>equipment-profiles-plates-and-bars-at-each-gym-using-commercial-gym` — 54-equipment-profiles-plates-and-bars-at-each-gym-using-commercial-gym-eq-member-active-light.png

| element | action | destination | status | screenshot |
|---|---|---|---|---|
| Back (button) | tap | MORE | OK | 35-back-more-member-active-light.png |
| Commercial Gym, ACTIVE, 20 kg bar · plates to 25 kg · 12 equipment types (button) | tap | crawler could not confirm (tap changed nothing on screen) | UNVERIFIED |  |
| Home Gym, 20 kg bar · plates to 20 kg · 5 equipment types (button) | tap | crawler could not confirm (tap changed nothing on screen) | UNVERIFIED |  |
| + ADD PROFILE (button) | tap | crawler could not confirm (tap changed nothing on screen) | UNVERIFIED |  |
| ✓, Band (button) | tap | crawler could not confirm (tap changed nothing on screen) | UNVERIFIED |  |
| ✓, Barbell (button) | tap | crawler could not confirm (tap changed nothing on screen) | UNVERIFIED |  |
| (unlabelled button) (button) | tap | crawler artifact: a back or tab-bar tap that landed on a root screen | OK |  |
| +, Add Equipment (button) | tap | crawler could not confirm (tap changed nothing on screen) | UNVERIFIED |  |

### member-active · `more>weekly-recap-training-food-and-steps-for-the-week-every-sunday` — 55-weekly-recap-training-food-and-steps-for-the-week-every-sunday-weekly--member-active-light.png

| element | action | destination | status | screenshot |
|---|---|---|---|---|
| Back (button) | tap | MORE | OK |  |
| This week, SHOWING, ›, 2 Nov–8 Nov · 3 workouts · 25.1 t (button) | tap | PUSH DAY | UNVERIFIED | 56-this-week-showing-2-nov-8-nov-3-workouts-25-1-t-push-day-member-active-light.png |
| (unlabelled button) (button) | tap | PROGRAMS | OK | 06-unlabelled-button-programs-member-active-light.png |
| (unlabelled button) (button) | tap | SOCIAL | OK |  |
| Week 44, ›, 26 Oct–1 Nov · 6 workouts · 50.3 t (button) | tap | changed in place (68 labels) | OK |  |
| Week 43, ›, 19 Oct–25 Oct · 5 workouts · 43.4 t (button) | tap | changed in place (54 labels) | OK |  |

### member-active · `more>cloud-sync-backs-up-your-data-automatically-synced-3-min-ago` — 57-cloud-sync-backs-up-your-data-automatically-synced-3-min-ago-add-frien-member-active-light.png

| element | action | destination | status | screenshot |
|---|---|---|---|---|
| BACK (button) | tap | you | OK | 58-back-you-member-active-light.png |
| SHARE INVITE LINK (button) | — | not tapped: ends the session, deletes, spends, posts or leaves the app | SKIPPED |  |

### new-user · `home>search` — 59-search-push-day-new-user-light.png

| element | action | destination | status | screenshot |
|---|---|---|---|---|
| Back (button) | tap | changed in place (9 labels) | OK |  |
| All (button) | tap | crawler could not confirm (tap changed nothing on screen) | UNVERIFIED |  |
| Exercises (button) | tap | crawler could not confirm (tap changed nothing on screen) | UNVERIFIED |  |
| Workouts (button) | tap | crawler could not confirm (tap changed nothing on screen) | UNVERIFIED |  |
| Friends (button) | tap | crawler could not confirm (tap changed nothing on screen) | UNVERIFIED |  |
| shift (button) | tap | starts a workout | OK |  |
| search (button) | tap | crawler could not confirm (tap changed nothing on screen) | UNVERIFIED |  |
| Dictate (button) | tap | crawler could not confirm (tap changed nothing on screen) | UNVERIFIED |  |
| Emoji (button) | tap | crawler could not confirm (tap changed nothing on screen) | UNVERIFIED |  |

### new-user · `home` — 03-home-new-user-light.png

| element | action | destination | status | screenshot |
|---|---|---|---|---|
| Search (button) | tap | PUSH DAY | OK | 59-search-push-day-new-user-light.png |
| Profile (button) | tap | crawler could not confirm (tap changed nothing on screen) | UNVERIFIED |  |
| NOT TODAY? › (button) | tap | crawler could not confirm (looks tappable but nothing happens) | UNVERIFIED |  |
| START WORKOUT, › (button) | — | not tapped: ends the session, deletes, spends, posts or leaves the app | SKIPPED |  |
| (unlabelled button) (button) | tap | changed in place (47 labels) | OK |  |
| (unlabelled button) (button) | tap | changed in place (20 labels) | OK |  |

### new-user · `programs>new-program` — 60-new-program-start-from-new-user-light.png

| element | action | destination | status | screenshot |
|---|---|---|---|---|
| Back (button) | tap | changed in place (32 labels) | OK |  |
| +, Blank, Start from scratch and add your own workouts., › (button) | tap | crawler could not confirm (looks tappable but nothing happens) | UNVERIFIED |  |
| 6D, Push Pull Legs, Push, Pull and Legs take turns across six days. High frequency., 3 WORKOUTS · 6 DAYS/WK, › (button) | tap | crawler could not confirm (looks tappable but nothing happens) | UNVERIFIED |  |
| 4D, Upper Lower, Two upper and two lower sessions a week. Balanced frequency., 2 WORKOUTS · 4 DAYS/WK, › (button) | tap | starts a workout | OK |  |
| 3D, Full Body, Every major muscle group each session. Great for beginners., 2 WORKOUTS · 3 DAYS/WK, › (button) | tap | changed in place (45 labels) | OK |  |
| (unlabelled button) (button) | tap | crawler artifact: a back or tab-bar tap that landed on a root screen | OK |  |
| (unlabelled button) (button) | tap | changed in place (37 labels) | OK |  |

### new-user · `programs` — 07-programs-new-user-light.png

| element | action | destination | status | screenshot |
|---|---|---|---|---|
| New program (button) | tap | START FROM | UNVERIFIED | 60-new-program-start-from-new-user-light.png |
| START WORKOUT, › (button) | — | not tapped: ends the session, deletes, spends, posts or leaves the app | SKIPPED |  |
| PUSH PULL LEGS, 3 WORKOUTS · 6 DAYS/WK, Trains MON · TUE · WED · THU · FRI · SAT, › (button) | tap | PUSH PULL LEGS | UNVERIFIED | 61-push-pull-legs-3-workouts-6-days-wk-trains-mon-tue-wed-thu-fri-sat-pus-new-user-light.png |
| (unlabelled button) (button) | tap | crawler artifact: a back or tab-bar tap that landed on a root screen | OK |  |
| (unlabelled button) (button) | tap | changed in place (22 labels) | OK |  |

### new-user · `programs>push-pull-legs-3-workouts-6-days-wk-trains-mon-tue-wed-thu-fri-sat` — 61-push-pull-legs-3-workouts-6-days-wk-trains-mon-tue-wed-thu-fri-sat-pus-new-user-light.png

| element | action | destination | status | screenshot |
|---|---|---|---|---|
| Back (button) | tap | changed in place (61 labels) | OK |  |
| EDIT (button) | tap | START FROM | OK |  |
| START (button) | tap | starts a workout | OK |  |
| 01, PUSH DAY, NEXT, MON · THU · 5 EX, Barbell Bench Press, 4 × 8, Overhead Press, 3 × 10, Incline Dumbbell Bench Press, 3 × 12, Lateral Raise, 3 × 15, Tricep Pushdown, 3 × 13 (button) | tap | changed in place (69 labels) | OK |  |
| START (button) | tap | crawler could not confirm (tap changed nothing on screen) | UNVERIFIED |  |
| 02, PULL DAY, TUE · FRI · 5 EX, Weighted Pull Up, 4 × 8, Barbell Row, 4 × 9, Lat Pulldown, 3 × 12, Face Pull, 3 × 15, Barbell Curl, 3 × 12 (button) | tap | crawler could not confirm (tap changed nothing on screen) | UNVERIFIED |  |
| + ADD WORKOUT (button) | tap | changed in place (61 labels) | OK |  |
| (unlabelled button) (button) | tap | PUSH DAY | UNVERIFIED | 62-unlabelled-button-push-day-new-user-light.png |
| (unlabelled button) (button) | tap | changed in place (57 labels) | OK |  |

### new-user · `body>calendar` — 30-calendar-body-new-user-light.png

| element | action | destination | status | screenshot |
|---|---|---|---|---|
| Calendar (button) | tap | changed in place (105 labels) | OK |  |
| Close calendar (button) | tap | changed in place (41 labels) | OK |  |
| Previous month (button) | tap | changes the page in place (the crawl can't see that) | OK |  |
| Next month (button) | tap | changes the page in place (the crawl can't see that) | OK |  |
| 1  (button) | tap | changes the page in place (the crawl can't see that) | OK |  |
| Week 44 (button) | tap | changes the page in place (the crawl can't see that) | OK |  |
| 2  (button) | tap | changes the page in place (the crawl can't see that) | OK |  |
| Week 45 (button) | tap | changes the page in place (the crawl can't see that) | OK |  |
| WEEK 45, WHOLE WEEK, NO WORKOUTS (button) | tap | crawler could not confirm (tap changed nothing on screen) | UNVERIFIED |  |
| (unlabelled button) (button) | tap | changed in place (31 labels) | OK |  |
| (unlabelled button) (button) | tap | changed in place (22 labels) | OK |  |

### new-user · `body` — 29-body-new-user-light.png

| element | action | destination | status | screenshot |
|---|---|---|---|---|
| Calendar (button) | tap | BODY | OK | 30-calendar-body-new-user-light.png |
| FREQUENCY, * (button) | tap | changed in place (41 labels) | OK |  |
| VOLUME (button) | tap | changed in place (41 labels) | OK |  |
| M, — (button) | tap | changes the page in place (the crawl can't see that) | OK |  |
| T, — (button) | tap | changes the page in place (the crawl can't see that) | OK |  |
| WEEK, — (button) | tap | changes the page in place (the crawl can't see that) | OK |  |
| Show back view (button) | tap | changes the page in place (the crawl can't see that) | OK |  |
| (unlabelled button) (button) | tap | changed in place (46 labels) | OK |  |
| (unlabelled button) (button) | tap | changed in place (22 labels) | OK |  |
| ▸, CHEST, 0 / 16 (button) | tap | changes the page in place (the crawl can't see that) | OK |  |
| ▸, BACK, 0 / 42 (button) | tap | changes the page in place (the crawl can't see that) | OK |  |
| ▸, SHOULDERS, 0 / 26 (button) | tap | changes the page in place (the crawl can't see that) | OK |  |
| ▸, ARMS, 0 / 26 (button) | tap | changes the page in place (the crawl can't see that) | OK |  |
| ▸, CORE, 0 / 18 (button) | tap | changes the page in place (the crawl can't see that) | OK |  |
| ▸, LEGS, 0 / 58 (button) | tap | changes the page in place (the crawl can't see that) | OK |  |

### new-user · `more>d-dev-lifter-dev-lifter-push-pull-legs` — 63-d-dev-lifter-dev-lifter-push-pull-legs-profile-new-user-light.png

| element | action | destination | status | screenshot |
|---|---|---|---|---|
| Back (button) | tap | MORE | OK | 37-back-more-new-user-light.png |
| EDIT (button) | tap | Name | OK | 64-edit-name-new-user-light.png |
| D (button) | tap | crawler could not confirm (tap changed nothing on screen) | UNVERIFIED |  |
| FIND FRIENDS, › (button) | tap | crawler could not confirm (looks tappable but nothing happens) | UNVERIFIED |  |
| (unlabelled button) (button) | tap | PROGRAMS | OK | 08-unlabelled-button-programs-new-user-light.png |
| (unlabelled button) (button) | tap | SOCIAL | OK | 10-unlabelled-button-social-new-user-light.png |

### new-user · `more` — 36-more-new-user-light.png

| element | action | destination | status | screenshot |
|---|---|---|---|---|
| D, Dev Lifter, @dev_lifter · PUSH PULL LEGS, › (button) | tap | profile | OK | 63-d-dev-lifter-dev-lifter-push-pull-legs-profile-new-user-light.png |
| GO Supernova, SMART SUGGESTIONS · CLOUD SYNC · ANALYTICS, › (button) | — | not tapped: ends the session, deletes, spends, posts or leaves the app | SKIPPED |  |
| History, ›, Every workout you have logged. 0 so far. (button) | tap | history | OK | 65-history-every-workout-you-have-logged-0-so-far-history-new-user-light.png |
| Analytics, ›, 1RM, volume and trends for each exercise. (button) | tap | analytics | OK | 66-analytics-1rm-volume-and-trends-for-each-exercise-analytics-new-user-light.png |
| Equipment profiles, ›, Plates and bars at each gym. Using Commercial Gym. (button) | tap | equipment | OK | 67-equipment-profiles-plates-and-bars-at-each-gym-using-commercial-gym-eq-new-user-light.png |
| Weekly Recap, ›, Training, food and steps for the week. Every Sunday. (button) | tap | weekly-recap | OK | 68-weekly-recap-training-food-and-steps-for-the-week-every-sunday-weekly--new-user-light.png |
| Settings, ›, Units, rest timer, theme and notifications. (button) | tap | settings | OK | 69-settings-units-rest-timer-theme-and-notifications-settings-new-user-light.png |
| (unlabelled button) (button) | tap | changed in place (49 labels) | OK |  |
| (unlabelled button) (button) | tap | changed in place (22 labels) | OK |  |
| Cloud Sync, ›, Backs up your data automatically. Synced 3 min. ago. (button) | tap | crawler could not confirm (looks tappable but nothing happens) | UNVERIFIED |  |
| Tutorial, Replays the walkthrough of logging a workout. (button) | — | not tapped: ends the session, deletes, spends, posts or leaves the app | SKIPPED |  |
| Data import, ›, Bring your history in from Strong, Hevy or a CSV. (button) | — | not tapped: ends the session, deletes, spends, posts or leaves the app | SKIPPED |  |
| Privacy & legal, ›, Privacy policy, terms and your data. (button) | — | not tapped: ends the session, deletes, spends, posts or leaves the app | SKIPPED |  |
| Sign out (button) | — | not tapped: ends the session, deletes, spends, posts or leaves the app | SKIPPED |  |
| FREE (button) | tap | crawler could not confirm (tap changed nothing on screen) | UNVERIFIED |  |
| MEMBER (button) | tap | crawler could not confirm (tap changed nothing on screen) | UNVERIFIED |  |

### new-user · `more>history-every-workout-you-have-logged-0-so-far` — 65-history-every-workout-you-have-logged-0-so-far-history-new-user-light.png

| element | action | destination | status | screenshot |
|---|---|---|---|---|
| Calendar view (button) | tap | changed in place (110 labels) | OK |  |
| Back (button) | tap | MORE | OK | 38-back-more-new-user-light.png |
| List view (button) | tap | changes the page in place (the crawl can't see that) | OK |  |
| (unlabelled button) (button) | tap | PROGRAMS | OK |  |
| (unlabelled button) (button) | tap | SOCIAL | OK |  |

### new-user · `more>analytics-1rm-volume-and-trends-for-each-exercise` — 66-analytics-1rm-volume-and-trends-for-each-exercise-analytics-new-user-light.png

| element | action | destination | status | screenshot |
|---|---|---|---|---|
| Back (button) | tap | MORE | OK | 39-back-more-new-user-light.png |
| (unlabelled button) (button) | tap | PROGRAMS | OK |  |
| (unlabelled button) (button) | tap | SOCIAL | OK |  |

### new-user · `more>equipment-profiles-plates-and-bars-at-each-gym-using-commercial-gym` — 67-equipment-profiles-plates-and-bars-at-each-gym-using-commercial-gym-eq-new-user-light.png

| element | action | destination | status | screenshot |
|---|---|---|---|---|
| Back (button) | tap | MORE | OK |  |
| Commercial Gym, ACTIVE, 20 kg bar · plates to 25 kg · 12 equipment types (button) | tap | crawler could not confirm (tap changed nothing on screen) | UNVERIFIED |  |
| Home Gym, 20 kg bar · plates to 20 kg · 5 equipment types (button) | tap | crawler could not confirm (tap changed nothing on screen) | UNVERIFIED |  |
| + ADD PROFILE (button) | tap | crawler could not confirm (tap changed nothing on screen) | UNVERIFIED |  |
| ✓, Band (button) | tap | crawler could not confirm (tap changed nothing on screen) | UNVERIFIED |  |
| ✓, Barbell (button) | tap | crawler could not confirm (tap changed nothing on screen) | UNVERIFIED |  |
| (unlabelled button) (button) | tap | crawler artifact: a back or tab-bar tap that landed on a root screen | OK |  |
| +, Add Equipment (button) | tap | crawler could not confirm (tap changed nothing on screen) | UNVERIFIED |  |

### new-user · `more>weekly-recap-training-food-and-steps-for-the-week-every-sunday` — 68-weekly-recap-training-food-and-steps-for-the-week-every-sunday-weekly--new-user-light.png

| element | action | destination | status | screenshot |
|---|---|---|---|---|
| Back (button) | tap | MORE | OK |  |
| This week, SHOWING, ›, 2 Nov–8 Nov · 0 workouts (button) | tap | crawler could not confirm (looks tappable but nothing happens) | UNVERIFIED |  |
| (unlabelled button) (button) | tap | PROGRAMS | OK |  |
| (unlabelled button) (button) | tap | SOCIAL | OK |  |
| Week 44, ›, 26 Oct–1 Nov · 0 workouts (button) | tap | changed in place (43 labels) | OK |  |
| Week 43, ›, 19 Oct–25 Oct · 0 workouts (button) | tap | changed in place (42 labels) | OK |  |

### new-user · `more>settings-units-rest-timer-theme-and-notifications` — 69-settings-units-rest-timer-theme-and-notifications-settings-new-user-light.png

| element | action | destination | status | screenshot |
|---|---|---|---|---|
| Back (button) | tap | MORE | OK | 40-back-more-new-user-light.png |
| Edit profile, ›, Name, username and body measurements. (button) | tap | edit-profile | UNVERIFIED | 31-edit-profile-name-username-and-body-measurements-edit-profile-new-user-light.png |
| KG (button) | tap | crawler could not confirm (tap changed nothing on screen) | UNVERIFIED |  |
| LB (button) | tap | crawler could not confirm (tap changed nothing on screen) | UNVERIFIED |  |
| Gender, MALE, ›, Used for calorie estimates. (button) | tap | gender | UNVERIFIED | 70-gender-male-used-for-calorie-estimates-gender-new-user-light.png |
| NEW (button) | tap | crawler could not confirm (tap changed nothing on screen) | UNVERIFIED |  |
| SOME (button) | tap | crawler could not confirm (tap changed nothing on screen) | UNVERIFIED |  |
| ADVANCED (button) | tap | crawler could not confirm (tap changed nothing on screen) | UNVERIFIED |  |
| Smart weight suggestions, Suggests the next weight on every set, based on your last session. (switch) | tap | toggle (state changed in place) | OK |  |
| +2.5 KG (button) | tap | PUSH DAY | UNVERIFIED | 71-2-5-kg-push-day-new-user-light.png |
| +1 KG (button) | tap | crawler could not confirm (tap changed nothing on screen) | UNVERIFIED |  |
| (unlabelled button) (button) | tap | PROGRAMS | OK |  |
| (unlabelled button) (button) | tap | SOCIAL | OK |  |
| AUTO (button) | tap | crawler could not confirm (tap changed nothing on screen) | UNVERIFIED |  |
| MANUAL (button) | tap | crawler could not confirm (tap changed nothing on screen) | UNVERIFIED |  |
| AUTO · DISMISS (button) | tap | crawler could not confirm (tap changed nothing on screen) | UNVERIFIED |  |
| HAPTIC (button) | tap | calorie-formula | UNVERIFIED | 72-haptic-calorie-formula-new-user-light.png |
| BOTH (button) | tap | calorie-formula | UNVERIFIED |  |
| SILENT (button) | tap | calorie-formula | UNVERIFIED |  |
| SOUND (button) | tap | calorie-formula | UNVERIFIED |  |
| Calorie formula, BASIC, ›, Uses heart rate and body weight when available. (button) | — | not tapped: ends the session, deletes, spends, posts or leaves the app | SKIPPED |  |
| LIGHT (button) | tap | crawler could not confirm (tap changed nothing on screen) | UNVERIFIED |  |
| DARK (button) | tap | crawler could not confirm (tap changed nothing on screen) | UNVERIFIED |  |
| SYSTEM (button) | tap | crawler could not confirm (tap changed nothing on screen) | UNVERIFIED |  |
| Training split, PPL · 6 DAYS, › (button) | tap | crawler could not confirm (looks tappable but nothing happens) | UNVERIFIED |  |
| Auto-share to feed, Posts your summary when you finish a workout. (switch) | — | not tapped: ends the session, deletes, spends, posts or leaves the app | SKIPPED |  |
| Summary display, 5 OF 5, ›, Choose what shows on the workout summary. (button) | — | not tapped: ends the session, deletes, spends, posts or leaves the app | SKIPPED |  |
| FRIENDS ONLY (button) | tap | crawler could not confirm (tap changed nothing on screen) | UNVERIFIED |  |
| ONLY ME (button) | tap | crawler could not confirm (tap changed nothing on screen) | UNVERIFIED |  |
| EVERYONE (button) | tap | crawler could not confirm (tap changed nothing on screen) | UNVERIFIED |  |
| Workout reminders, On your training days, at your usual time. (switch) | tap | PUSH DAY | UNVERIFIED |  |

### social · `social>activity>back` — 13-back-social-social-light.png

| element | action | destination | status | screenshot |
|---|---|---|---|---|
| Activity (button) | tap | activity | OK |  |
| Your profile (button) | tap | you | OK | 14-your-profile-you-social-light.png |
| CHALLENGES (button) | tap | changed in place (50 labels) | OK |  |
| FRIENDS (button) | tap | changed in place (50 labels) | OK |  |
| T, Tess Three, @TESS.T (button) | tap | Tess Three | OK | 15-t-tess-three-tess-t-tess-three-social-light.png |
| Post options (button) | — | not tapped: ends the session, deletes, spends, posts or leaves the app | SKIPPED |  |
| Show back (button) | tap | crawler artifact: a back or tab-bar tap that landed on a root screen | OK |  |
| Full workout (button) | tap | changed in place (56 labels) | OK |  |
| (unlabelled button) (button) | tap | changed in place (45 labels) | OK |  |
| Unlike (button) | tap | crawler could not confirm (tap changed nothing on screen) | UNVERIFIED |  |
| Comments (button) | tap | crawler could not confirm (tap changed nothing on screen) | UNVERIFIED |  |
| F, Frankie One, @FRANKIE (button) | tap | crawler could not confirm (tap changed nothing on screen) | UNVERIFIED |  |

### social · `social>activity` — 12-activity-activity-social-light.png

| element | action | destination | status | screenshot |
|---|---|---|---|---|
| Back (button) | tap | SOCIAL | OK | 13-back-social-social-light.png |
| Open Private profile's profile (button) | tap | crawler could not confirm (tap changed nothing on screen) | UNVERIFIED |  |
| IGNORE (button) | tap | crawler could not confirm (tap changed nothing on screen) | UNVERIFIED |  |
| ACCEPT (button) | — | not tapped: ends the session, deletes, spends, posts or leaves the app | SKIPPED |  |
| Open Priya Five's profile (button) | tap | crawler could not confirm (tap changed nothing on screen) | UNVERIFIED |  |
| Workout posts, Friends see your sessions in their feed., FRIENDS ONLY, › (button) | tap | crawler could not confirm (looks tappable but nothing happens) | UNVERIFIED |  |
| Body map, Friends see it; others see stats only., FRIENDS ONLY, › (button) | tap | crawler could not confirm (looks tappable but nothing happens) | UNVERIFIED |  |
| Global leaderboards, Your name and rank in monthly challenges., VISIBLE, › (button) | tap | crawler could not confirm (looks tappable but nothing happens) | UNVERIFIED |  |
| Profile, Anyone can find and view you., EVERYONE, › (button) | tap | crawler could not confirm (looks tappable but nothing happens) | UNVERIFIED |  |
| Blocked people, 1, › (button) | — | not tapped: ends the session, deletes, spends, posts or leaves the app | SKIPPED |  |
| (unlabelled button) (button) | tap | crawler artifact: a back or tab-bar tap that landed on a root screen | OK |  |

### social · `social` — 11-social-social-light.png

| element | action | destination | status | screenshot |
|---|---|---|---|---|
| Activity (button) | tap | activity | OK | 12-activity-activity-social-light.png |
| Your profile (button) | tap | you | OK | 16-your-profile-you-social-light.png |
| CHALLENGES (button) | tap | changed in place (29 labels) | OK |  |
| FRIENDS (button) | tap | changed in place (29 labels) | OK |  |
| T, Tess Three, @TESS.T (button) | tap | Tess Three | OK |  |
| Post options (button) | — | not tapped: ends the session, deletes, spends, posts or leaves the app | SKIPPED |  |
| Show back (button) | tap | crawler artifact: a back or tab-bar tap that landed on a root screen | OK |  |
| Full workout (button) | tap | changed in place (56 labels) | OK |  |
| (unlabelled button) (button) | tap | changed in place (45 labels) | OK |  |
| Comments (button) | tap | SOCIAL | OK | 26-comments-social-social-light.png |
| Unlike (button) | tap | crawler could not confirm (tap changed nothing on screen) | UNVERIFIED |  |
| F, Frankie One, @FRANKIE (button) | tap | crawler could not confirm (tap changed nothing on screen) | UNVERIFIED |  |
| Like (button) | tap | crawler could not confirm (tap changed nothing on screen) | UNVERIFIED |  |

### social · `social>your-profile` — 16-your-profile-you-social-light.png

| element | action | destination | status | screenshot |
|---|---|---|---|---|
| EDIT PROFILE (button) | tap | crawler could not confirm (tap changed nothing on screen) | UNVERIFIED |  |
| BACK (button) | tap | crawler could not confirm (tap changed nothing on screen) | UNVERIFIED |  |
| SHARE (button) | — | not tapped: ends the session, deletes, spends, posts or leaves the app | SKIPPED |  |
| Jay Six, @jay.six (button) | tap | Jay Six | OK | 17-jay-six-jay-six-jay-six-social-light.png |
| UNFOLLOW (button) | — | not tapped: ends the session, deletes, spends, posts or leaves the app | SKIPPED |  |
| Private profile (button) | tap | Sam Two | OK | 20-private-profile-sam-two-social-light.png |
| Sam Two, Last trained 2 days ago (button) | tap | Tess Three | OK | 22-sam-two-last-trained-2-days-ago-tess-three-social-light.png |
| Tess Three, Trained yesterday (button) | tap | add-friends | OK | 25-tess-three-trained-yesterday-add-friends-social-light.png |
| Find friends (button) | tap | crawler could not confirm (tap changed nothing on screen) | UNVERIFIED |  |
| (unlabelled button) (button) | tap | crawler artifact: a back or tab-bar tap that landed on a root screen | OK |  |

### social · `social>your-profile>jay-six-jay-six` — 17-jay-six-jay-six-jay-six-social-light.png

| element | action | destination | status | screenshot |
|---|---|---|---|---|
| PROFILE OPTIONS (button) | tap | crawler could not confirm (tap changed nothing on screen) | UNVERIFIED |  |
| BACK (button) | tap | crawler could not confirm (tap changed nothing on screen) | UNVERIFIED |  |
| Requested. Tap to cancel (button) | tap | crawler could not confirm (tap changed nothing on screen) | UNVERIFIED |  |
| 7D (button) | tap | crawler could not confirm (tap changed nothing on screen) | UNVERIFIED |  |
| 30D (button) | tap | crawler could not confirm (tap changed nothing on screen) | UNVERIFIED |  |
| Upper Body, 4D AGO · 14 SETS · 4.0K, › (button) | tap | UPPER BODY | OK | 18-upper-body-4d-ago-14-sets-4-0k-upper-body-social-light.png |
| (unlabelled button) (button) | tap | changed in place (45 labels) | OK |  |
| (unlabelled button) (button) | tap | Jay Six | UNVERIFIED | 19-unlabelled-button-jay-six-social-light.png |

### social · `social>your-profile>private-profile` — 20-private-profile-sam-two-social-light.png

| element | action | destination | status | screenshot |
|---|---|---|---|---|
| PROFILE OPTIONS (button) | tap | crawler could not confirm (tap changed nothing on screen) | UNVERIFIED |  |
| BACK (button) | tap | crawler could not confirm (tap changed nothing on screen) | UNVERIFIED |  |
| ✓ FRIENDS (button) | tap | crawler could not confirm (tap changed nothing on screen) | UNVERIFIED |  |
| CHALLENGE (button) | tap | crawler could not confirm (tap changed nothing on screen) | UNVERIFIED |  |
| 7D (button) | tap | crawler could not confirm (tap changed nothing on screen) | UNVERIFIED |  |
| 30D (button) | tap | crawler could not confirm (tap changed nothing on screen) | UNVERIFIED |  |
| Show back (button) | tap | crawler artifact: a back or tab-bar tap that landed on a root screen | OK |  |
| (unlabelled button) (button) | tap | changed in place (44 labels) | OK |  |
| (unlabelled button) (button) | tap | Sam Two | UNVERIFIED |  |
| Front body map, Pull Day, 2D AGO · 14 SETS · 4.0K, › (button) | tap | PULL DAY | OK | 21-front-body-map-pull-day-2d-ago-14-sets-4-0k-pull-day-social-light.png |

### social · `social>your-profile>sam-two-last-trained-2-days-ago` — 22-sam-two-last-trained-2-days-ago-tess-three-social-light.png

| element | action | destination | status | screenshot |
|---|---|---|---|---|
| PROFILE OPTIONS (button) | tap | crawler could not confirm (tap changed nothing on screen) | UNVERIFIED |  |
| BACK (button) | tap | crawler could not confirm (tap changed nothing on screen) | UNVERIFIED |  |
| ✓ FRIENDS (button) | tap | crawler could not confirm (tap changed nothing on screen) | UNVERIFIED |  |
| CHALLENGE (button) | tap | crawler could not confirm (tap changed nothing on screen) | UNVERIFIED |  |
| 7D (button) | tap | crawler could not confirm (tap changed nothing on screen) | UNVERIFIED |  |
| 30D (button) | tap | crawler could not confirm (tap changed nothing on screen) | UNVERIFIED |  |
| Show back (button) | tap | crawler artifact: a back or tab-bar tap that landed on a root screen | OK |  |
| (unlabelled button) (button) | tap | changed in place (46 labels) | OK |  |
| (unlabelled button) (button) | tap | Tess Three | UNVERIFIED | 23-unlabelled-button-tess-three-social-light.png |
| Front body map, Full Body, YESTERDAY · 14 SETS · 4.0K, › (button) | tap | FULL BODY | OK | 24-front-body-map-full-body-yesterday-14-sets-4-0k-full-body-social-light.png |

### social · `social>your-profile>tess-three-trained-yesterday` — 25-tess-three-trained-yesterday-add-friends-social-light.png

| element | action | destination | status | screenshot |
|---|---|---|---|---|
| BACK (button) | tap | SOCIAL | OK |  |
| IGNORE (button) | tap | changed in place (8 labels) | OK |  |
| ACCEPT (button) | — | not tapped: ends the session, deletes, spends, posts or leaves the app | SKIPPED |  |
| Priya Five, @priya_5 (button) | tap | crawler could not confirm (tap changed nothing on screen) | UNVERIFIED |  |
| SHARE INVITE LINK (button) | — | not tapped: ends the session, deletes, spends, posts or leaves the app | SKIPPED |  |

### social · `social>comments` — 26-comments-social-social-light.png

| element | action | destination | status | screenshot |
|---|---|---|---|---|
| Frankie One (button) | tap | crawler could not confirm (tap changed nothing on screen) | UNVERIFIED |  |
| Open Frankie One's profile (button) | tap | crawler could not confirm (tap changed nothing on screen) | UNVERIFIED |  |
| Reply to Frankie One (button) | tap | crawler could not confirm (tap changed nothing on screen) | UNVERIFIED |  |
| Comment options (button) | tap | crawler could not confirm (tap changed nothing on screen) | UNVERIFIED |  |

## Not sure how to build — the choice made

None recorded.
