# Pump user flows

One-page, plain-language walkthroughs of what Pump does today, for checking by hand. The technical spec stays in `docs/behaviour/`.

## Areas
1. [Account](01-account.md): sign in, onboarding, restore, sign out
2. [Home](02-home.md): prediction, streak, start button, search
3. [Workout logging](03-workout-logging.md): sets, rest, plates, finish, post
4. [Smart suggestions](04-smart-suggestions.md): Pulse+ next-weight hints
5. [History](05-history.md): past workouts, editing, exercise progress, recap
6. [Body](06-body.md): muscle heat map
7. [Programs](07-programs.md): saved plans, sharing, split
8. [Exercise library](08-exercise-library.md): picking exercises
9. [Social](09-social.md): feed, friends, privacy, challenges
10. [More and Settings](10-more-settings.md): settings, import, equipment
11. [Widgets](11-widgets-live-activity.md): widgets, Live Activity
12. [Cloud sync](12-cloud-sync.md): backup and restore
13. [Pulse+](13-pulse-plus.md): paid tier and trial
14. [Notifications](14-notifications.md): reminders, rest alerts

## How to review
1. Read a file's "The flow".
2. Walk it on the simulator or phone.
3. Reply by area, for example "03 step 5: rest didn't start".
4. Answer the decisions below. (broken) and (not built) items are already known.

## Decisions for you
Reply "1 yes, 2 no, …". Each is my recommendation, based on Strong, Hevy and Apple Fitness.

1. Pulse+ = smart suggestions, MET calories, sub-regions, deload, Plus widgets and builder, creating challenges. Sync and the rest stay free; paywall rewritten to match.
2. 14-day Apple trial tied to the Apple ID, countdown in More, "trial ended" notice.
3. Sign-out warns about unsynced changes, is blocked mid-workout, and cancels reminders.
4. Block sign-up under 13.
5. No account merging; tell people which sign-in method their email uses.
6. Prediction: NEXT UP after training, NOT TODAY? always shown, "What do you want to do?" when unsure.
7. One workout at a time; drafts never expire.
8. Keep the current forgiving streak.
9. Real supersets, a workout note, remove the L/R set type.
10. Completion: calories in stats, Share / Save image, hide the camera for now.
11. Deleting a posted workout deletes its post.
12. Edit past workouts fully, with Cancel and no future dates.
13. Monday recap notification; no monthly recap.
14. Share programs by web link.
15. Full program editing; show program notes in workouts.
16. Create custom exercises from the picker and More.
17. Per-post audience chip that can only narrow.
18. Invite link; no contacts matching; remove "Save workout".
19. Report reasons; you review reports within 24 hours.
20. Challenges score from the start; creators can End them.
21. Add week start and default rest; hide COMING SOON; you supply legal URLs.
22. Editable equipment profiles that drive the plate calculator.
23. More › Tools with Plate Calculator and Warm-up Generator.
24. Shorter tutorial that works.
25. Ask notification permission on first reminder; reminder times; no social push in v1.
