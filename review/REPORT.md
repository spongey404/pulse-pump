# Ore design review

Screens crawled: 53 · elements tapped or skipped: 182 · states: free-active, member-active, social

Statuses: OK · DEAD END (tap does nothing) · PLACEHOLDER (blank / coming soon) · FAKE AFFORDANCE (looks tappable, isn't) · TRAP (no way back) · INCONSISTENT (contradicts another screen) · OFF-SYSTEM (breaks the design rules) · UNVERIFIED (the crawl flagged it, not confirmed) · SKIPPED (not tapped on purpose: ends the session, deletes, spends, posts or leaves the app).

## Flags

### Blocking (1)

| status | where | element | note | screenshot |
|---|---|---|---|---|
| FIXED | Core/BodyMap/BodyMapView.swift (starLayer), Body tab | App crashed for Supernova members when swapping the Body map between front and back | Index out of range: the Stardust engine kept the old side's muscle indices after the geometry switched. Found by the review (crash report 14:35). Fixed: engine is rebuilt per side, old geometry cleared, frame skipped if they disagree. Regression test: HistoryHomeBodyUITests.testMemberCanSwapTheMapBackAndForthWithoutCrashing (passes). |  |

### Visible (5)

| status | where | element | note | screenshot |
|---|---|---|---|---|
| OFF-SYSTEM | Core/DesignSystem/Components/CustomTabBar.swift:39 | Tab bar uses a blurred material | Rule: sheets and modals dim, never blur. The tab bar is not a sheet, but it is the one blur on the main screens; the design may want a flat canvas fill. |  |
| OFF-SYSTEM | Core/DesignSystem/Components/DestructiveModal.swift:167 | Drop shadow on the destructive modal | Same rule: no shadows. |  |
| OFF-SYSTEM | Core/DesignSystem/Components/WorkoutModal.swift:80,95 | Drop shadows on the workout modal | Design system: no shadows or glows, elevation by tint only. Two .shadow calls on the finish/discard modal. |  |
| OFF-SYSTEM | Features/Social/Feed/CommentsView.swift:40 | Comments composer uses ultraThinMaterial | Blur on a sheet-like surface; rule says dim, never blur. |  |
| OFF-SYSTEM | Home · hero | NOT TODAY? › is 13 pt tall; the Search icon is 19 pt, Profile 36 pt | Touch targets under Apple's 44 pt minimum, measured from the element frames. Both still work (NOT TODAY? opens the WHAT'S TODAY? picker); they are just hard to hit. | verify-home-notToday.png |

### Minor (5)

| status | where | element | note | screenshot |
|---|---|---|---|---|
| INCONSISTENT | Features/BodyMap/MuscleDetailSheet.swift | Old muscle detail sheet is now unreferenced | Replaced by the Body muscle tree. Dead code; safe to delete. Not removed because it is outside sections 1 to 6. |  |
| INCONSISTENT | Home ticker strip | Ticker is 26 pt tall, the Home design measures about 31 pt | Left as is on purpose: the brief says reuse the one ticker component and do not restyle it. | 01-home-free-active-light.png |
| OFF-SYSTEM | Features/Social/Feed/LiftHistoryView.swift:127,218,226 | Gold glow shadows on PR markers | PR is meant to be a treatment (ink text + underline), not a coloured glow. |  |
| OFF-SYSTEM | Features/Supernova/Member/SupernovaMemberPage.swift:144 | Member page uses ultraThinMaterial | Blur; the member design uses a glass card, so this may be intended. Needs a decision. |  |
| OFF-SYSTEM | Features/Workout/Views/ShareCardView.swift:28 | Drop shadow on the share card | No shadows rule. |  |

### Unverified (40)

Flags the tap crawl raised that no one has confirmed by hand. The crawl cannot tell a control that changes the page in place from one that does nothing, so treat these as leads, not findings.

| status | where | element | note | screenshot |
|---|---|---|---|---|
| UNVERIFIED | free-active · body>calendar | WEEK 45, WHOLE WEEK, 3 SESSIONS · 50 SETS, SHOW ON MAP › | crawler could not confirm (looks tappable but nothing happens) |  |
| UNVERIFIED | free-active · home | TUE, PULL DAY, 17, ▼ 2% | crawler could not confirm (tap changed nothing on screen) |  |
| UNVERIFIED | free-active · more | Cloud Sync, ›, Backs up your data automatically. Synced in 0 sec.. | crawler could not confirm (looks tappable but nothing happens) |  |
| UNVERIFIED | free-active · more | FREE | crawler could not confirm (tap changed nothing on screen) |  |
| UNVERIFIED | free-active · more | MEMBER | crawler could not confirm (tap changed nothing on screen) |  |
| UNVERIFIED | free-active · more>d-dev-lifter-dev-lifter-push-pull-legs | D | crawler could not confirm (tap changed nothing on screen) |  |
| UNVERIFIED | free-active · more>d-dev-lifter-dev-lifter-push-pull-legs | FIND FRIENDS, › | crawler could not confirm (looks tappable but nothing happens) |  |
| UNVERIFIED | free-active · more>d-dev-lifter-dev-lifter-push-pull-legs>back | Cloud Sync, ›, Backs up your data automatically. Synced 1 min. ago. | crawler could not confirm (looks tappable but nothing happens) |  |
| UNVERIFIED | free-active · more>d-dev-lifter-dev-lifter-push-pull-legs>back | FREE | crawler could not confirm (tap changed nothing on screen) |  |
| UNVERIFIED | free-active · more>d-dev-lifter-dev-lifter-push-pull-legs>back | MEMBER | crawler could not confirm (tap changed nothing on screen) |  |
| UNVERIFIED | free-active · more>d-dev-lifter-dev-lifter-push-pull-legs>edit | Back | crawler could not confirm (no way back found from profile) |  |
| UNVERIFIED | free-active · more>d-dev-lifter-dev-lifter-push-pull-legs>edit | Save | crawler could not confirm (no way back found from profile) |  |
| UNVERIFIED | free-active · more>d-dev-lifter-dev-lifter-push-pull-legs>edit | (unlabelled cell) | crawler could not confirm (looks tappable but nothing happens) |  |
| UNVERIFIED | free-active · programs | Close | crawler could not confirm (tap changed nothing on screen) |  |
| UNVERIFIED | free-active · programs | L, LEG DAY, 5 EXERCISES | crawler could not confirm (tap changed nothing on screen) |  |
| UNVERIFIED | free-active · programs | P, PULL DAY, 5 EXERCISES | crawler could not confirm (tap changed nothing on screen) |  |
| UNVERIFIED | free-active · programs | P, PUSH DAY, 5 EXERCISES | crawler could not confirm (tap changed nothing on screen) |  |
| UNVERIFIED | member-active · body | Close | crawler could not confirm (tap changed nothing on screen) |  |
| UNVERIFIED | member-active · body | L, LEG DAY, 5 EXERCISES | crawler could not confirm (tap changed nothing on screen) |  |
| UNVERIFIED | member-active · body | P, PULL DAY, 5 EXERCISES | crawler could not confirm (tap changed nothing on screen) |  |
| UNVERIFIED | member-active · body | P, PUSH DAY, 5 EXERCISES | crawler could not confirm (tap changed nothing on screen) |  |
| UNVERIFIED | member-active · home | TUE, PULL DAY, 17, ▼ 2% | crawler could not confirm (checked by hand: nothing appears (height=46 back=false labelsChanged=0)) |  |
| UNVERIFIED | member-active · more | FREE | crawler could not confirm (tap changed nothing on screen) |  |
| UNVERIFIED | member-active · more | MEMBER | crawler could not confirm (tap changed nothing on screen) |  |
| UNVERIFIED | member-active · more>equipment-profiles-plates-and-bars-at-each-gym-using-commercial-gym | Commercial Gym, ACTIVE, 20 kg bar · plates to 25 kg · 12 equipment types | crawler could not confirm (tap changed nothing on screen) |  |
| UNVERIFIED | member-active · more>equipment-profiles-plates-and-bars-at-each-gym-using-commercial-gym | +, Add Equipment | crawler could not confirm (tap changed nothing on screen) |  |
| UNVERIFIED | member-active · more>history-every-workout-you-have-logged-45-so-far | (unlabelled cell) | crawler could not confirm (looks tappable but nothing happens) |  |
| UNVERIFIED | member-active · more>weekly-recap-training-food-and-steps-for-the-week-every-sunday | This week, SHOWING, ›, 2 Nov–8 Nov · 3 workouts · 25.1 t | crawler could not confirm (no way back found from PUSH DAY) | 52-this-week-showing-2-nov-8-nov-3-workouts-25-1-t-push-day-member-active-light.png |
| UNVERIFIED | social · social | Unlike | crawler could not confirm (tap changed nothing on screen) |  |
| UNVERIFIED | social · social | F, Frankie One, @FRANKIE | crawler could not confirm (tap changed nothing on screen) |  |
| UNVERIFIED | social · social>activity | IGNORE | crawler could not confirm (tap changed nothing on screen) |  |
| UNVERIFIED | social · social>activity | Workout posts, Friends see your sessions in their feed., FRIENDS ONLY, › | crawler could not confirm (looks tappable but nothing happens) |  |
| UNVERIFIED | social · social>activity | Body map, Friends see it; others see stats only., FRIENDS ONLY, › | crawler could not confirm (looks tappable but nothing happens) |  |
| UNVERIFIED | social · social>activity | Global leaderboards, Your name and rank in monthly challenges., VISIBLE, › | crawler could not confirm (looks tappable but nothing happens) |  |
| UNVERIFIED | social · social>activity | Profile, Anyone can find and view you., EVERYONE, › | crawler could not confirm (looks tappable but nothing happens) |  |
| UNVERIFIED | social · social>activity>back | Unlike | crawler could not confirm (tap changed nothing on screen) |  |
| UNVERIFIED | social · social>activity>back | F, Frankie One, @FRANKIE | crawler could not confirm (tap changed nothing on screen) |  |
| UNVERIFIED | social · social>activity>unlabelled-button | (unlabelled button) | crawler could not confirm (no way back found from activity) | 19-unlabelled-button-activity-social-light.png |
| UNVERIFIED | social · social>comments | Reply to Frankie One | crawler could not confirm (tap changed nothing on screen) |  |
| UNVERIFIED | social · social>comments | Comment options | crawler could not confirm (tap changed nothing on screen) |  |

## Screen map


### free-active

- **home** `home` — via “tab” — 01-home-free-active-light.png
- **programs** `programs` — via “tab” — 03-programs-free-active-light.png
- **body** `body` — via “tab” — 23-body-free-active-light.png
  - **BODY** `body>calendar` — via “Calendar” — 24-calendar-body-free-active-light.png
- **more** `more` — via “tab” — 25-more-free-active-light.png
  - **profile** `more>d-dev-lifter-dev-lifter-push-pull-legs` — via “D, Dev Lifter, @dev_lifter · PUSH PULL LEGS, ›” — 34-d-dev-lifter-dev-lifter-push-pull-legs-profile-free-active-light.png
    - **MORE** `more>d-dev-lifter-dev-lifter-push-pull-legs>back` — via “Back” — 26-back-more-free-active-light.png
      - **history** `more>d-dev-lifter-dev-lifter-push-pull-legs>back>history-every-workout-you-have-logged-45-so-far` — via “History, ›, Every workout you have logged. 45 so far.” — 35-history-every-workout-you-have-logged-45-so-far-history-free-active-light.png
      - **analytics** `more>d-dev-lifter-dev-lifter-push-pull-legs>back>analytics-1rm-volume-and-trends-for-each-exercise` — via “Analytics, ›, 1RM, volume and trends for each exercise.” — 37-analytics-1rm-volume-and-trends-for-each-exercise-analytics-free-active-light.png
      - **equipment** `more>d-dev-lifter-dev-lifter-push-pull-legs>back>equipment-profiles-plates-and-bars-at-each-gym-using-commercial-gym` — via “Equipment profiles, ›, Plates and bars at each gym. Using Commercial Gym.” — 38-equipment-profiles-plates-and-bars-at-each-gym-using-commercial-gym-eq-free-active-light.png
      - **weekly-recap** `more>d-dev-lifter-dev-lifter-push-pull-legs>back>weekly-recap-training-food-and-steps-for-the-week-every-sunday` — via “Weekly Recap, ›, Training, food and steps for the week. Every Sunday.” — 41-weekly-recap-training-food-and-steps-for-the-week-every-sunday-weekly--free-active-light.png
      - **settings** `more>d-dev-lifter-dev-lifter-push-pull-legs>back>settings-units-rest-timer-theme-and-notifications` — via “Settings, ›, Units, rest timer, theme and notifications.” — 43-settings-units-rest-timer-theme-and-notifications-settings-free-active-light.png
    - **Name** `more>d-dev-lifter-dev-lifter-push-pull-legs>edit` — via “EDIT” — 44-edit-name-free-active-light.png
    - **PROGRAMS** `more>d-dev-lifter-dev-lifter-push-pull-legs>unlabelled-button` — via “(unlabelled button)” — 05-unlabelled-button-programs-free-active-light.png
      - **START FROM** `more>d-dev-lifter-dev-lifter-push-pull-legs>unlabelled-button>new-program` — via “New program” — 45-new-program-start-from-free-active-light.png
      - **PUSH PULL LEGS** `more>d-dev-lifter-dev-lifter-push-pull-legs>unlabelled-button>push-pull-legs-3-workouts-6-days-wk-5h-ago-trains-mon-tue-wed-fri-sat-` — via “PUSH PULL LEGS, 3 WORKOUTS · 6 DAYS/WK · 5H AGO, Trains MON · TUE · WED · FRI · SAT · SUN, ›” — 47-push-pull-legs-3-workouts-6-days-wk-5h-ago-trains-mon-tue-wed-fri-sat--free-active-light.png
      - **you** `more>d-dev-lifter-dev-lifter-push-pull-legs>unlabelled-button>your-profile` — via “Your profile” — 48-your-profile-you-free-active-light.png
      - **activity** `more>d-dev-lifter-dev-lifter-push-pull-legs>unlabelled-button>activity` — via “Activity” — 49-activity-activity-free-active-light.png
      - **add-friends** `more>d-dev-lifter-dev-lifter-push-pull-legs>unlabelled-button>find-friends` — via “FIND FRIENDS” — 50-find-friends-add-friends-free-active-light.png
    - **SOCIAL** `more>d-dev-lifter-dev-lifter-push-pull-legs>unlabelled-button` — via “(unlabelled button)” — 21-unlabelled-button-social-free-active-light.png
      - **START FROM** `more>d-dev-lifter-dev-lifter-push-pull-legs>unlabelled-button>new-program` — via “New program” — 45-new-program-start-from-free-active-light.png
      - **PUSH PULL LEGS** `more>d-dev-lifter-dev-lifter-push-pull-legs>unlabelled-button>push-pull-legs-3-workouts-6-days-wk-5h-ago-trains-mon-tue-wed-fri-sat-` — via “PUSH PULL LEGS, 3 WORKOUTS · 6 DAYS/WK · 5H AGO, Trains MON · TUE · WED · FRI · SAT · SUN, ›” — 47-push-pull-legs-3-workouts-6-days-wk-5h-ago-trains-mon-tue-wed-fri-sat--free-active-light.png
      - **you** `more>d-dev-lifter-dev-lifter-push-pull-legs>unlabelled-button>your-profile` — via “Your profile” — 48-your-profile-you-free-active-light.png
      - **activity** `more>d-dev-lifter-dev-lifter-push-pull-legs>unlabelled-button>activity` — via “Activity” — 49-activity-activity-free-active-light.png
      - **add-friends** `more>d-dev-lifter-dev-lifter-push-pull-legs>unlabelled-button>find-friends` — via “FIND FRIENDS” — 50-find-friends-add-friends-free-active-light.png

### member-active

- **home** `home` — via “tab” — 02-home-member-active-light.png
- **body** `body` — via “tab” — 22-body-member-active-light.png
- **more** `more` — via “tab” — 27-more-member-active-light.png
  - **history** `more>history-every-workout-you-have-logged-45-so-far` — via “History, ›, Every workout you have logged. 45 so far.” — 36-history-every-workout-you-have-logged-45-so-far-history-member-active-light.png
    - **MORE** `more>history-every-workout-you-have-logged-45-so-far>back` — via “Back” — 28-back-more-member-active-light.png
    - **Barbell Squat** `more>history-every-workout-you-have-logged-45-so-far>leg-day-wed-4-nov-69-min-17-sets` — via “Leg Day, ›, Wed 4 Nov · 69 min · 17 sets” — 39-leg-day-wed-4-nov-69-min-17-sets-barbell-squat-member-active-light.png
    - **Weighted Pull Up** `more>history-every-workout-you-have-logged-45-so-far>pull-day-tue-3-nov-72-min-17-sets` — via “Pull Day, ›, Tue 3 Nov · 72 min · 17 sets” — 40-pull-day-tue-3-nov-72-min-17-sets-weighted-pull-up-member-active-light.png
  - **analytics** `more>analytics-1rm-volume-and-trends-for-each-exercise` — via “Analytics, ›, 1RM, volume and trends for each exercise.” — 42-analytics-1rm-volume-and-trends-for-each-exercise-analytics-member-active-light.png
    - **MORE** `more>analytics-1rm-volume-and-trends-for-each-exercise>back` — via “Back” — 30-back-more-member-active-light.png
    - **PROGRAMS** `more>analytics-1rm-volume-and-trends-for-each-exercise>unlabelled-button` — via “(unlabelled button)” — 06-unlabelled-button-programs-member-active-light.png
    - **SOCIAL** `more>analytics-1rm-volume-and-trends-for-each-exercise>unlabelled-button` — via “(unlabelled button)” — 18-unlabelled-button-social-member-active-light.png
  - **equipment** `more>equipment-profiles-plates-and-bars-at-each-gym-using-commercial-gym` — via “Equipment profiles, ›, Plates and bars at each gym. Using Commercial Gym.” — 46-equipment-profiles-plates-and-bars-at-each-gym-using-commercial-gym-eq-member-active-light.png
    - **MORE** `more>equipment-profiles-plates-and-bars-at-each-gym-using-commercial-gym>back` — via “Back” — 31-back-more-member-active-light.png
    - **MORE** `more>equipment-profiles-plates-and-bars-at-each-gym-using-commercial-gym>add-profile` — via “+ ADD PROFILE” — 32-add-profile-more-member-active-light.png
    - **PROGRAMS** `more>equipment-profiles-plates-and-bars-at-each-gym-using-commercial-gym>unlabelled-button` — via “(unlabelled button)” — 07-unlabelled-button-programs-member-active-light.png
  - **weekly-recap** `more>weekly-recap-training-food-and-steps-for-the-week-every-sunday` — via “Weekly Recap, ›, Training, food and steps for the week. Every Sunday.” — 51-weekly-recap-training-food-and-steps-for-the-week-every-sunday-weekly--member-active-light.png
    - **MORE** `more>weekly-recap-training-food-and-steps-for-the-week-every-sunday>back` — via “Back” — 33-back-more-member-active-light.png
    - **PUSH DAY** `more>weekly-recap-training-food-and-steps-for-the-week-every-sunday>this-week-showing-2-nov-8-nov-3-workouts-25-1-t` — via “This week, SHOWING, ›, 2 Nov–8 Nov · 3 workouts · 25.1 t” — 52-this-week-showing-2-nov-8-nov-3-workouts-25-1-t-push-day-member-active-light.png
  - **add-friends** `more>cloud-sync-backs-up-your-data-automatically-synced-5-min-ago` — via “Cloud Sync, ›, Backs up your data automatically. Synced 5 min. ago.” — 53-cloud-sync-backs-up-your-data-automatically-synced-5-min-ago-add-frien-member-active-light.png
    - **you** `more>cloud-sync-backs-up-your-data-automatically-synced-5-min-ago>back` — via “BACK” — 54-back-you-member-active-light.png

### social

- **social** `social` — via “tab” — 08-social-social-light.png
  - **activity** `social>activity` — via “Activity” — 09-activity-activity-social-light.png
    - **SOCIAL** `social>activity>back` — via “Back” — 10-back-social-social-light.png
      - **you** `social>activity>back>your-profile` — via “Your profile” — 11-your-profile-you-social-light.png
      - **Tess Three** `social>activity>back>t-tess-three-tess-t` — via “T, Tess Three, @TESS.T” — 12-t-tess-three-tess-t-tess-three-social-light.png
      - **SOCIAL** `social>activity>back>comments` — via “Comments” — 20-comments-social-social-light.png
    - **PROGRAMS** `social>activity>unlabelled-button` — via “(unlabelled button)” — 04-unlabelled-button-programs-social-light.png
      - **START FROM** `social>activity>unlabelled-button>new-program` — via “New program” — 14-new-program-start-from-social-light.png
      - **PUSH PULL LEGS** `social>activity>unlabelled-button>push-pull-legs-3-workouts-6-days-wk-trains-mon-tue-wed-thu-fri-sat` — via “PUSH PULL LEGS, 3 WORKOUTS · 6 DAYS/WK, Trains MON · TUE · WED · THU · FRI · SAT, ›” — 15-push-pull-legs-3-workouts-6-days-wk-trains-mon-tue-wed-thu-fri-sat-pus-social-light.png
      - **UPPER LOWER** `social>activity>unlabelled-button>upper-lower-2-workouts-4-days-wk-trains-mon-tue-thu-fri` — via “UPPER LOWER, 2 WORKOUTS · 4 DAYS/WK, Trains MON · TUE · THU · FRI, ›” — 16-upper-lower-2-workouts-4-days-wk-trains-mon-tue-thu-fri-upper-lower-social-light.png
      - **FULL BODY** `social>activity>unlabelled-button>full-body-2-workouts-3-days-wk-trains-mon-wed-fri` — via “FULL BODY, 2 WORKOUTS · 3 DAYS/WK, Trains MON · WED · FRI, ›” — 17-full-body-2-workouts-3-days-wk-trains-mon-wed-fri-full-body-social-light.png
      - **activity** `social>activity>unlabelled-button>unlabelled-button` — via “(unlabelled button)” — 19-unlabelled-button-activity-social-light.png
  - **SOCIAL** `social>comments` — via “Comments” — 20-comments-social-social-light.png

## Tap audit by screen


### free-active · `home` — 01-home-free-active-light.png

| element | action | destination | status | screenshot |
|---|---|---|---|---|
| Profile (button) | tap | checked by hand: it responds (DEV LIFTER / @dev_lifter) | OK |  |
| Search (button) | tap | checked by hand: it responds (105×5 / 87.5×6 / BARBELL · BACK / bench / romanian deadlift ) | OK |  |
| NOT TODAY? › (button) | tap | checked by hand: it responds (5 EXERCISES / WHAT'S TODAY? / PICK YOUR WORKOUT FOR TODAY / ) | OK |  |
| MON, PUSH DAY, 16, ▲ 5% (button) | tap | checked by hand: it responds (48.75 / 8 / 87.5 / 4 SETS · TOP 87.5 KG / BARBELL BENCH PRES) | OK |  |
| TUE, PULL DAY, 17, ▼ 2% (button) | tap | crawler could not confirm (tap changed nothing on screen) | UNVERIFIED |  |
| START WORKOUT, › (button) | — | not tapped: ends the session, deletes, spends, posts or leaves the app | SKIPPED |  |
| (unlabelled button) (button) | tap | crawler artifact: a back or tab-bar tap that landed on a root screen | OK |  |

### free-active · `programs` — 03-programs-free-active-light.png

| element | action | destination | status | screenshot |
|---|---|---|---|---|
| Close (button) | tap | crawler could not confirm (tap changed nothing on screen) | UNVERIFIED |  |
| L, LEG DAY, 5 EXERCISES (button) | tap | crawler could not confirm (tap changed nothing on screen) | UNVERIFIED |  |
| P, PULL DAY, 5 EXERCISES (button) | tap | crawler could not confirm (tap changed nothing on screen) | UNVERIFIED |  |
| P, PUSH DAY, 5 EXERCISES (button) | tap | crawler could not confirm (tap changed nothing on screen) | UNVERIFIED |  |

### free-active · `body>calendar` — 24-calendar-body-free-active-light.png

| element | action | destination | status | screenshot |
|---|---|---|---|---|
| Calendar (button) | tap | changed in place (110 labels) | OK |  |
| Close calendar (button) | tap | changes the page in place (the crawl can't see that) | OK |  |
| Previous month (button) | tap | changes the page in place (the crawl can't see that) | OK |  |
| Next month (button) | tap | changed in place (42 labels) | OK |  |
| Week 44 (button) | tap | changes the page in place (the crawl can't see that) | OK |  |
| 1 LEGS 17 (button) | tap | changes the page in place (the crawl can't see that) | OK |  |
| 2 PUSH 16 (button) | tap | changes the page in place (the crawl can't see that) | OK |  |
| Week 45 (button) | tap | changes the page in place (the crawl can't see that) | OK |  |
| WEEK 45, WHOLE WEEK, 3 SESSIONS · 50 SETS, SHOW ON MAP › (button) | tap | crawler could not confirm (looks tappable but nothing happens) | UNVERIFIED |  |
| (unlabelled button) (button) | tap | changed in place (31 labels) | OK |  |
| (unlabelled button) (button) | tap | changed in place (22 labels) | OK |  |

### free-active · `body` — 23-body-free-active-light.png

| element | action | destination | status | screenshot |
|---|---|---|---|---|
| Calendar (button) | tap | BODY | OK | 24-calendar-body-free-active-light.png |
| FREQUENCY, * (button) | tap | changed in place (42 labels) | OK |  |
| VOLUME (button) | tap | changed in place (42 labels) | OK |  |
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

### free-active · `more>d-dev-lifter-dev-lifter-push-pull-legs>back` — 26-back-more-free-active-light.png

| element | action | destination | status | screenshot |
|---|---|---|---|---|
| D, Dev Lifter, @dev_lifter · PUSH PULL LEGS, › (button) | tap | profile | OK |  |
| GO Supernova, SMART SUGGESTIONS · CLOUD SYNC · ANALYTICS, › (button) | — | not tapped: ends the session, deletes, spends, posts or leaves the app | SKIPPED |  |
| History, ›, Every workout you have logged. 45 so far. (button) | tap | history | OK | 35-history-every-workout-you-have-logged-45-so-far-history-free-active-light.png |
| Analytics, ›, 1RM, volume and trends for each exercise. (button) | tap | analytics | OK | 37-analytics-1rm-volume-and-trends-for-each-exercise-analytics-free-active-light.png |
| Equipment profiles, ›, Plates and bars at each gym. Using Commercial Gym. (button) | tap | equipment | OK | 38-equipment-profiles-plates-and-bars-at-each-gym-using-commercial-gym-eq-free-active-light.png |
| Weekly Recap, ›, Training, food and steps for the week. Every Sunday. (button) | tap | weekly-recap | OK | 41-weekly-recap-training-food-and-steps-for-the-week-every-sunday-weekly--free-active-light.png |
| Settings, ›, Units, rest timer, theme and notifications. (button) | tap | settings | OK | 43-settings-units-rest-timer-theme-and-notifications-settings-free-active-light.png |
| (unlabelled button) (button) | tap | changed in place (50 labels) | OK |  |
| (unlabelled button) (button) | tap | changed in place (22 labels) | OK |  |
| Cloud Sync, ›, Backs up your data automatically. Synced 1 min. ago. (button) | tap | crawler could not confirm (looks tappable but nothing happens) | UNVERIFIED |  |
| Tutorial, Replays the walkthrough of logging a workout. (button) | — | not tapped: ends the session, deletes, spends, posts or leaves the app | SKIPPED |  |
| Data import, ›, Bring your history in from Strong, Hevy or a CSV. (button) | — | not tapped: ends the session, deletes, spends, posts or leaves the app | SKIPPED |  |
| Privacy & legal, ›, Privacy policy, terms and your data. (button) | — | not tapped: ends the session, deletes, spends, posts or leaves the app | SKIPPED |  |
| Sign out (button) | — | not tapped: ends the session, deletes, spends, posts or leaves the app | SKIPPED |  |
| FREE (button) | tap | crawler could not confirm (tap changed nothing on screen) | UNVERIFIED |  |
| MEMBER (button) | tap | crawler could not confirm (tap changed nothing on screen) | UNVERIFIED |  |

### free-active · `more>d-dev-lifter-dev-lifter-push-pull-legs` — 34-d-dev-lifter-dev-lifter-push-pull-legs-profile-free-active-light.png

| element | action | destination | status | screenshot |
|---|---|---|---|---|
| Back (button) | tap | MORE | OK | 26-back-more-free-active-light.png |
| EDIT (button) | tap | Name | OK | 44-edit-name-free-active-light.png |
| D (button) | tap | crawler could not confirm (tap changed nothing on screen) | UNVERIFIED |  |
| FIND FRIENDS, › (button) | tap | crawler could not confirm (looks tappable but nothing happens) | UNVERIFIED |  |
| (unlabelled button) (button) | tap | PROGRAMS | OK | 05-unlabelled-button-programs-free-active-light.png |
| (unlabelled button) (button) | tap | SOCIAL | OK | 21-unlabelled-button-social-free-active-light.png |

### free-active · `more>d-dev-lifter-dev-lifter-push-pull-legs>edit` — 44-edit-name-free-active-light.png

| element | action | destination | status | screenshot |
|---|---|---|---|---|
| Back (button) | tap | profile | UNVERIFIED |  |
| Save (button) | tap | profile | UNVERIFIED |  |
| (unlabelled cell) (cell) | tap | crawler could not confirm (looks tappable but nothing happens) | UNVERIFIED |  |
| (unlabelled cell) (cell) | tap | changed in place (4 labels) | OK |  |

### free-active · `more>d-dev-lifter-dev-lifter-push-pull-legs>unlabelled-button` — 21-unlabelled-button-social-free-active-light.png

| element | action | destination | status | screenshot |
|---|---|---|---|---|
| New program (button) | tap | START FROM | OK | 45-new-program-start-from-free-active-light.png |
| START WORKOUT, › (button) | — | not tapped: ends the session, deletes, spends, posts or leaves the app | SKIPPED |  |
| PUSH PULL LEGS, 3 WORKOUTS · 6 DAYS/WK · 5H AGO, Trains MON · TUE · WED · FRI · SAT · SUN, › (button) | tap | PUSH PULL LEGS | OK | 47-push-pull-legs-3-workouts-6-days-wk-5h-ago-trains-mon-tue-wed-fri-sat--free-active-light.png |
| (unlabelled button) (button) | tap | crawler artifact: a back or tab-bar tap that landed on a root screen | OK |  |
| (unlabelled button) (button) | tap | changed in place (22 labels) | OK |  |
| Your profile (button) | tap | you | OK | 48-your-profile-you-free-active-light.png |
| Activity (button) | tap | activity | OK | 49-activity-activity-free-active-light.png |
| CHALLENGES (button) | tap | changed in place (16 labels) | OK |  |
| FRIENDS (button) | tap | changed in place (16 labels) | OK |  |
| FIND FRIENDS (button) | tap | add-friends | OK | 50-find-friends-add-friends-free-active-light.png |

### free-active · `more` — 25-more-free-active-light.png

| element | action | destination | status | screenshot |
|---|---|---|---|---|
| D, Dev Lifter, @dev_lifter · PUSH PULL LEGS, › (button) | tap | profile | OK | 34-d-dev-lifter-dev-lifter-push-pull-legs-profile-free-active-light.png |
| GO Supernova, SMART SUGGESTIONS · CLOUD SYNC · ANALYTICS, › (button) | — | not tapped: ends the session, deletes, spends, posts or leaves the app | SKIPPED |  |
| History, ›, Every workout you have logged. 45 so far. (button) | tap | history | OK |  |
| Analytics, ›, 1RM, volume and trends for each exercise. (button) | tap | analytics | OK |  |
| Equipment profiles, ›, Plates and bars at each gym. Using Commercial Gym. (button) | tap | equipment | OK |  |
| Weekly Recap, ›, Training, food and steps for the week. Every Sunday. (button) | tap | weekly-recap | OK |  |
| Settings, ›, Units, rest timer, theme and notifications. (button) | tap | settings | OK |  |
| (unlabelled button) (button) | tap | changed in place (50 labels) | OK |  |
| (unlabelled button) (button) | tap | changed in place (22 labels) | OK |  |
| Cloud Sync, ›, Backs up your data automatically. Synced in 0 sec.. (button) | tap | crawler could not confirm (looks tappable but nothing happens) | UNVERIFIED |  |
| Tutorial, Replays the walkthrough of logging a workout. (button) | — | not tapped: ends the session, deletes, spends, posts or leaves the app | SKIPPED |  |
| Data import, ›, Bring your history in from Strong, Hevy or a CSV. (button) | — | not tapped: ends the session, deletes, spends, posts or leaves the app | SKIPPED |  |
| Privacy & legal, ›, Privacy policy, terms and your data. (button) | — | not tapped: ends the session, deletes, spends, posts or leaves the app | SKIPPED |  |
| Sign out (button) | — | not tapped: ends the session, deletes, spends, posts or leaves the app | SKIPPED |  |
| FREE (button) | tap | crawler could not confirm (tap changed nothing on screen) | UNVERIFIED |  |
| MEMBER (button) | tap | crawler could not confirm (tap changed nothing on screen) | UNVERIFIED |  |

### member-active · `home` — 02-home-member-active-light.png

| element | action | destination | status | screenshot |
|---|---|---|---|---|
| Profile (button) | tap | checked by hand: it responds (DEV LIFTER / @dev_lifter) | OK |  |
| Search (button) | tap | checked by hand: it responds (105×5 / 87.5×6 / BARBELL · BACK / bench / romanian deadlift ) | OK |  |
| NOT TODAY? › (button) | tap | checked by hand: it responds (Biceps · Rear Delts / BACK / Pull / EST 1RM / DEFAULT REST /) | OK |  |
| MON, PUSH DAY, 16, ▲ 5% (button) | tap | checked by hand: it responds (48.75 / 8 / 87.5 / 4 SETS · TOP 87.5 KG / BARBELL BENCH PRES) | OK |  |
| TUE, PULL DAY, 17, ▼ 2% (button) | tap | crawler could not confirm (checked by hand: nothing appears (height=46 back=false labelsChanged=0)) | UNVERIFIED |  |
| START WORKOUT, › (button) | — | not tapped: ends the session, deletes, spends, posts or leaves the app | SKIPPED |  |
| (unlabelled button) (button) | tap | crawler artifact: a back or tab-bar tap that landed on a root screen | OK |  |

### member-active · `body` — 22-body-member-active-light.png

| element | action | destination | status | screenshot |
|---|---|---|---|---|
| Close (button) | tap | crawler could not confirm (tap changed nothing on screen) | UNVERIFIED |  |
| L, LEG DAY, 5 EXERCISES (button) | tap | crawler could not confirm (tap changed nothing on screen) | UNVERIFIED |  |
| P, PULL DAY, 5 EXERCISES (button) | tap | crawler could not confirm (tap changed nothing on screen) | UNVERIFIED |  |
| P, PUSH DAY, 5 EXERCISES (button) | tap | crawler could not confirm (tap changed nothing on screen) | UNVERIFIED |  |

### member-active · `more` — 27-more-member-active-light.png

| element | action | destination | status | screenshot |
|---|---|---|---|---|
| Supernova membership (button) | — | not tapped: ends the session, deletes, spends, posts or leaves the app | SKIPPED |  |
| History, ›, Every workout you have logged. 45 so far. (button) | tap | history | OK | 36-history-every-workout-you-have-logged-45-so-far-history-member-active-light.png |
| Analytics, ›, 1RM, volume and trends for each exercise. (button) | tap | analytics | OK | 42-analytics-1rm-volume-and-trends-for-each-exercise-analytics-member-active-light.png |
| Equipment profiles, ›, Plates and bars at each gym. Using Commercial Gym. (button) | tap | equipment | OK | 46-equipment-profiles-plates-and-bars-at-each-gym-using-commercial-gym-eq-member-active-light.png |
| Weekly Recap, ›, Training, food and steps for the week. Every Sunday. (button) | tap | weekly-recap | OK | 51-weekly-recap-training-food-and-steps-for-the-week-every-sunday-weekly--member-active-light.png |
| Settings, ›, Units, rest timer, theme and notifications. (button) | tap | changed in place (82 labels) | OK |  |
| (unlabelled button) (button) | tap | changed in place (56 labels) | OK |  |
| (unlabelled button) (button) | tap | changed in place (22 labels) | OK |  |
| Cloud Sync, ›, Backs up your data automatically. Synced 5 min. ago. (button) | tap | add-friends | OK | 53-cloud-sync-backs-up-your-data-automatically-synced-5-min-ago-add-frien-member-active-light.png |
| Tutorial, Replays the walkthrough of logging a workout. (button) | — | not tapped: ends the session, deletes, spends, posts or leaves the app | SKIPPED |  |
| Data import, ›, Bring your history in from Strong, Hevy or a CSV. (button) | — | not tapped: ends the session, deletes, spends, posts or leaves the app | SKIPPED |  |
| Privacy & legal, ›, Privacy policy, terms and your data. (button) | — | not tapped: ends the session, deletes, spends, posts or leaves the app | SKIPPED |  |
| Sign out (button) | — | not tapped: ends the session, deletes, spends, posts or leaves the app | SKIPPED |  |
| FREE (button) | tap | crawler could not confirm (tap changed nothing on screen) | UNVERIFIED |  |
| MEMBER (button) | tap | crawler could not confirm (tap changed nothing on screen) | UNVERIFIED |  |

### member-active · `more>history-every-workout-you-have-logged-45-so-far` — 36-history-every-workout-you-have-logged-45-so-far-history-member-active-light.png

| element | action | destination | status | screenshot |
|---|---|---|---|---|
| Calendar view (button) | tap | changed in place (139 labels) | OK |  |
| Back (button) | tap | MORE | OK | 28-back-more-member-active-light.png |
| List view (button) | tap | changes the page in place (the crawl can't see that) | OK |  |
| (unlabelled cell) (cell) | tap | crawler could not confirm (looks tappable but nothing happens) | UNVERIFIED |  |
| Leg Day, ›, Wed 4 Nov · 69 min · 17 sets (button) | tap | Barbell Squat | OK | 39-leg-day-wed-4-nov-69-min-17-sets-barbell-squat-member-active-light.png |
| Pull Day, ›, Tue 3 Nov · 72 min · 17 sets (button) | tap | Weighted Pull Up | OK | 40-pull-day-tue-3-nov-72-min-17-sets-weighted-pull-up-member-active-light.png |

### member-active · `more>analytics-1rm-volume-and-trends-for-each-exercise` — 42-analytics-1rm-volume-and-trends-for-each-exercise-analytics-member-active-light.png

| element | action | destination | status | screenshot |
|---|---|---|---|---|
| Back (button) | tap | MORE | OK | 30-back-more-member-active-light.png |
| (unlabelled button) (button) | tap | PROGRAMS | OK | 06-unlabelled-button-programs-member-active-light.png |
| (unlabelled button) (button) | tap | SOCIAL | OK | 18-unlabelled-button-social-member-active-light.png |

### member-active · `more>equipment-profiles-plates-and-bars-at-each-gym-using-commercial-gym` — 46-equipment-profiles-plates-and-bars-at-each-gym-using-commercial-gym-eq-member-active-light.png

| element | action | destination | status | screenshot |
|---|---|---|---|---|
| Back (button) | tap | MORE | OK | 31-back-more-member-active-light.png |
| Commercial Gym, ACTIVE, 20 kg bar · plates to 25 kg · 12 equipment types (button) | tap | crawler could not confirm (tap changed nothing on screen) | UNVERIFIED |  |
| Home Gym, 20 kg bar · plates to 20 kg · 5 equipment types (button) | tap | changed in place (15 labels) | OK |  |
| + ADD PROFILE (button) | tap | MORE | OK | 32-add-profile-more-member-active-light.png |
| (unlabelled button) (button) | tap | PROGRAMS | OK | 07-unlabelled-button-programs-member-active-light.png |
| (unlabelled button) (button) | tap | SOCIAL | OK |  |
| +, Add Equipment (button) | tap | crawler could not confirm (tap changed nothing on screen) | UNVERIFIED |  |

### member-active · `more>weekly-recap-training-food-and-steps-for-the-week-every-sunday` — 51-weekly-recap-training-food-and-steps-for-the-week-every-sunday-weekly--member-active-light.png

| element | action | destination | status | screenshot |
|---|---|---|---|---|
| Back (button) | tap | MORE | OK | 33-back-more-member-active-light.png |
| This week, SHOWING, ›, 2 Nov–8 Nov · 3 workouts · 25.1 t (button) | tap | PUSH DAY | UNVERIFIED | 52-this-week-showing-2-nov-8-nov-3-workouts-25-1-t-push-day-member-active-light.png |
| (unlabelled button) (button) | tap | PROGRAMS | OK |  |
| (unlabelled button) (button) | tap | SOCIAL | OK |  |
| Week 44, ›, 26 Oct–1 Nov · 6 workouts · 50.3 t (button) | tap | changed in place (68 labels) | OK |  |
| Week 43, ›, 19 Oct–25 Oct · 5 workouts · 43.4 t (button) | tap | changed in place (63 labels) | OK |  |

### member-active · `more>cloud-sync-backs-up-your-data-automatically-synced-5-min-ago` — 53-cloud-sync-backs-up-your-data-automatically-synced-5-min-ago-add-frien-member-active-light.png

| element | action | destination | status | screenshot |
|---|---|---|---|---|
| BACK (button) | tap | you | OK | 54-back-you-member-active-light.png |
| SHARE INVITE LINK (button) | — | not tapped: ends the session, deletes, spends, posts or leaves the app | SKIPPED |  |

### social · `social>activity>back` — 10-back-social-social-light.png

| element | action | destination | status | screenshot |
|---|---|---|---|---|
| Activity (button) | tap | activity | OK |  |
| Your profile (button) | tap | you | OK | 11-your-profile-you-social-light.png |
| CHALLENGES (button) | tap | changed in place (50 labels) | OK |  |
| FRIENDS (button) | tap | changed in place (50 labels) | OK |  |
| T, Tess Three, @TESS.T (button) | tap | Tess Three | OK | 12-t-tess-three-tess-t-tess-three-social-light.png |
| Post options (button) | — | not tapped: ends the session, deletes, spends, posts or leaves the app | SKIPPED |  |
| Show back (button) | tap | crawler artifact: a back or tab-bar tap that landed on a root screen | OK |  |
| Full workout (button) | tap | changed in place (56 labels) | OK |  |
| (unlabelled button) (button) | tap | changed in place (45 labels) | OK |  |
| Comments (button) | tap | SOCIAL | OK | 20-comments-social-social-light.png |
| Unlike (button) | tap | crawler could not confirm (tap changed nothing on screen) | UNVERIFIED |  |
| F, Frankie One, @FRANKIE (button) | tap | crawler could not confirm (tap changed nothing on screen) | UNVERIFIED |  |

### social · `social>activity` — 09-activity-activity-social-light.png

| element | action | destination | status | screenshot |
|---|---|---|---|---|
| Back (button) | tap | SOCIAL | OK | 10-back-social-social-light.png |
| IGNORE (button) | tap | crawler could not confirm (tap changed nothing on screen) | UNVERIFIED |  |
| ACCEPT (button) | — | not tapped: ends the session, deletes, spends, posts or leaves the app | SKIPPED |  |
| Workout posts, Friends see your sessions in their feed., FRIENDS ONLY, › (button) | tap | crawler could not confirm (looks tappable but nothing happens) | UNVERIFIED |  |
| Body map, Friends see it; others see stats only., FRIENDS ONLY, › (button) | tap | crawler could not confirm (looks tappable but nothing happens) | UNVERIFIED |  |
| Global leaderboards, Your name and rank in monthly challenges., VISIBLE, › (button) | tap | crawler could not confirm (looks tappable but nothing happens) | UNVERIFIED |  |
| Profile, Anyone can find and view you., EVERYONE, › (button) | tap | crawler could not confirm (looks tappable but nothing happens) | UNVERIFIED |  |
| Blocked people, 1, › (button) | — | not tapped: ends the session, deletes, spends, posts or leaves the app | SKIPPED |  |
| (unlabelled button) (button) | tap | PROGRAMS | OK | 04-unlabelled-button-programs-social-light.png |
| (unlabelled button) (button) | tap | crawler artifact: a back or tab-bar tap that landed on a root screen | OK |  |

### social · `social>activity>unlabelled-button` — 04-unlabelled-button-programs-social-light.png

| element | action | destination | status | screenshot |
|---|---|---|---|---|
| New program (button) | tap | START FROM | OK | 14-new-program-start-from-social-light.png |
| START WORKOUT, › (button) | — | not tapped: ends the session, deletes, spends, posts or leaves the app | SKIPPED |  |
| PUSH PULL LEGS, 3 WORKOUTS · 6 DAYS/WK, Trains MON · TUE · WED · THU · FRI · SAT, › (button) | tap | PUSH PULL LEGS | OK | 15-push-pull-legs-3-workouts-6-days-wk-trains-mon-tue-wed-thu-fri-sat-pus-social-light.png |
| UPPER LOWER, 2 WORKOUTS · 4 DAYS/WK, Trains MON · TUE · THU · FRI, › (button) | tap | UPPER LOWER | OK | 16-upper-lower-2-workouts-4-days-wk-trains-mon-tue-thu-fri-upper-lower-social-light.png |
| FULL BODY, 2 WORKOUTS · 3 DAYS/WK, Trains MON · WED · FRI, › (button) | tap | FULL BODY | OK | 17-full-body-2-workouts-3-days-wk-trains-mon-wed-fri-full-body-social-light.png |
| (unlabelled button) (button) | tap | crawler artifact: a back or tab-bar tap that landed on a root screen | OK |  |
| (unlabelled button) (button) | tap | activity | UNVERIFIED | 19-unlabelled-button-activity-social-light.png |

### social · `social` — 08-social-social-light.png

| element | action | destination | status | screenshot |
|---|---|---|---|---|
| Activity (button) | tap | activity | OK | 09-activity-activity-social-light.png |
| Your profile (button) | tap | you | OK |  |
| CHALLENGES (button) | tap | changed in place (50 labels) | OK |  |
| FRIENDS (button) | tap | changed in place (50 labels) | OK |  |
| T, Tess Three, @TESS.T (button) | tap | Tess Three | OK |  |
| Post options (button) | — | not tapped: ends the session, deletes, spends, posts or leaves the app | SKIPPED |  |
| Show back (button) | tap | crawler artifact: a back or tab-bar tap that landed on a root screen | OK |  |
| Full workout (button) | tap | changed in place (56 labels) | OK |  |
| (unlabelled button) (button) | tap | changed in place (45 labels) | OK |  |
| Comments (button) | tap | SOCIAL | OK | 20-comments-social-social-light.png |
| Unlike (button) | tap | crawler could not confirm (tap changed nothing on screen) | UNVERIFIED |  |
| F, Frankie One, @FRANKIE (button) | tap | crawler could not confirm (tap changed nothing on screen) | UNVERIFIED |  |

### social · `social>comments` — 20-comments-social-social-light.png

| element | action | destination | status | screenshot |
|---|---|---|---|---|
| Reply to Frankie One (button) | tap | crawler could not confirm (tap changed nothing on screen) | UNVERIFIED |  |
| Comment options (button) | tap | crawler could not confirm (tap changed nothing on screen) | UNVERIFIED |  |

## Not sure how to build — the choice made

- **Body design file was cut off at the 256 KiB read limit** — Built the Body page from the markup that did load plus the written spec, so Body logic details (exact interactions, edge cases) come from the spec, not the design's script.
- **Sets credited per muscle** — A set counts once for each muscle it works (primary muscles; exercises that name sub-regions credit only those heads). The design's numbers are placeholders.
- **Weekly and daily targets in the muscle tree** — The design gives none for real data, so targets are an invented table; a day's target is half the week's.
- **Home hero and ledger source** — Uses the active program's rotation (UP NEXT) and falls back to the old pattern prediction only when there is no program.
- **Streak** — Weekly streak (consecutive weeks with at least one session), shown big on Home.
- **Change figures** — Compared with the same point of last week; zero change shows as an em dash, never ▲ 0%.
- **Dark mode** — Not reviewed by request: only features and Supernova differences were checked.
- **Logger and workout flows** — Not crawled by tapping (the crawler skips Start Workout, Finish and Discard); the sheets are shown by a targeted run instead.

## Coverage

**Covered (light mode, as requested; dark not reviewed):**
- Free user: Home, Programs, Body (+ calendar modal), More and everything it opens (History list and calendar, workout views, Analytics, Equipment, Weekly Recap, Settings, profile, Find friends, Activity).
- Supernova member: Home, Body, More at depth 2.
- Body states, free and member: Volume, a selected day, a rest-day note, the back figure as the main view, Frequency (locked for free, live for the member), calendar modal open / day selected / week selected. A focused muscle group is shown only for the member in Frequency (`71-body-frequency-focused-member-light.png`).
- New user: Home, Body, Programs, History list and calendar (all empty).
- Logger: top, number keypad, set-type sheet, rest sheet, exercise ··· menu, add-exercise picker, discard modal.
- Social tab as the seeded friend (feed, activity, profile, comments).

**Not covered:**
- A focused muscle group in the Volume lens (the `CHEST ×` chip) for free and member: the run could not open the group, so no screenshot. The behaviour is covered by `HistoryHomeBodyUITests.testOpeningAGroupFocusesItsMusclesAndTheChipClearsIt`, which passes.
- Dark mode (skipped on request).
- Crawl depth was 2–3 levels; anything deeper than that is not in the audit.
- Logger sheets beyond the list above (progression, replace, reorder, finish modal) and the Social challenge screens were not reached; the crawler never taps Start Workout, Finish or Discard on purpose.
- Paywall and purchase flows (skipped: the crawler never taps subscribe / go Supernova).

**How to read the audit:** the tap crawl cannot tell a control that changes a page in place from one that does nothing, so unconfirmed flags are in the *Unverified* group, not in Blocking / Visible. The ones checked by hand are: Home Profile, Search, NOT TODAY? and a done-day ledger row (all respond), plus Body day / week / row / swap / calendar controls (in-place by design, covered by UI tests).
