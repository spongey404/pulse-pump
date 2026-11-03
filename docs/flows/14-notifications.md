# 14 Notifications and reminders

## What it's for
Ore can remind you to train on your split's training days, nudge you on rest days, and tell you when a rest timer ends while the phone is locked.

## The flow
1. Finish onboarding → iOS asks to allow notifications (straight away, before you've turned anything on) → Allow.
2. More › Settings › Notifications → turn on Workout Reminders → you'll get "Time to train · Push Day, let's go." at 8:00 on each training day of your split.
3. Turn on Rest Day Alerts → you'll get "Rest day" with a short recovery message at 10:00 on non-training days.
4. Change your split (Settings › Training Split) → reminders move to the new days.
5. In a workout, tick a set → lock the phone → when rest ends you get "Rest done · Log your next set".
6. Tap any notification → Ore opens.

**Alternate paths**
- **Turn off:** switch either toggle off → those notifications stop.
- **No split chosen:** turning reminders on schedules nothing, without saying why.
- **App open when rest ends:** no banner; the in-app sound or vibration plays (per Settings › Timer Alert).
- **Social Activity and Challenge Updates** rows read COMING SOON and can't be tapped.

## Not working / not built yet
- If you denied permission, the switches still turn on and nothing arrives, with no message. (broken)
- Signing out doesn't cancel reminders; they keep coming for the old account. (broken)
- Reminder times are fixed at 8:00 and 10:00. (not built)
- Reminders still fire on days you've already trained.
- No push notifications for likes, comments, follows, friend requests or challenge changes. (not built)
- No Monday weekly-recap notification and no neglected-muscle nudge. (not built)
- Reminders don't move when your split changes through sync or Programs, only through Settings.
- Tapping a notification just opens the app, not the relevant screen.

## Decide
- **Notifications:** ask for permission the first time you turn on a reminder (not at launch), add a time picker for each reminder, and ship v1 without social push (hide the COMING SOON rows). *Recommended: yes.*
- **Weekly recap notification:** covered by README decision 13.

## Rules I'll apply
- If permission is denied, the switch flips back off and offers "Open iOS Settings".
- Reminders still fire on days you've trained, for v1.
- Reminders reschedule whenever the split changes, from any source, and are cancelled on sign-out.
- With no split, the reminder switch explains "Pick a training split first".
- Tapping a workout reminder opens Home; tapping "Rest done" opens the running workout.
