# 04 Smart weight suggestions (Pulse+)

## What it's for
You set a rep goal for a lift. When you hit that goal at your top weight, the next set suggests a slightly heavier weight, so progress happens without doing maths mid-workout. This shipped on this branch after the technical spec was written, so walk it carefully.

## The flow
1. As a Pulse+ or trial user, start a workout and add a weighted lift (for example Bench Press).
2. Under the set rows, tap the chip PROGRESS · OFF → pick a rep goal, for example "8 reps" → the chip reads PROGRESS AT 8 REPS. This goal is saved for that lift and follows you to future sessions and other devices.
3. Log set 1: 60 kg × 8 → tick.
4. Look at set 2 → its faint weight now reads 62.5 (60 + your increment).
5. Type only the reps → tick → the set is logged at 62.5 kg.
6. If you hit 8 again, set 3 suggests 65 kg; if you fall short, set 3 shows last session's numbers instead.

**Alternate paths**
- **Change the increment:** More › Settings › Workout › Progression Increment → choose +1, +1.25, +2.5 or +5 kg (or +2.5, +5, +10 lb). Default is 2.5 kg or 5 lb.
- **Turn it off:** More › Settings › Workout › Smart Weight Suggestions switch (on by default).
- **Free user:** the chip reads PROGRESS · PULSE+ and the Settings row reads PULSE+; tapping either opens the Pulse+ screen.
- **Override:** type a different weight in the row and that weight is used instead.
- **Remove the goal:** tap the chip → Off.

## Not working / not built yet
- A suggested weight looks exactly like a normal "last time" number, so it's easy to miss.
- The reps shown on a suggested row are last session's reps; ticking without typing logs them by accident.
- The rep goal can only be set from inside a workout, not from the exercise detail screen.
- A program's target reps are not used as a starting rep goal; no goal means no suggestion.

## Decide
- **Plus or free:** smart suggestions are Pulse+ only, on by default for Plus and trial users, and shown as a locked chip for free users. *Recommended: yes (part of decision 1 in the README).*

## Rules I'll apply
- Suggestions look different: accent-coloured number plus a small "▲ +2.5" tag; the reps field stays empty so you must type reps.
- Only the next set to log gets a suggestion; the latest working set decides, and a lighter back-off set cancels it. Warm-up, drop, rest-pause and failure sets are ignored.
- When a lift has no rep goal and the workout came from a program, the program's target reps are used; otherwise a one-time hint says "Set a rep goal to get suggestions".
- Rep goals are 1 to 30 reps; the suggested weight rounds to 0.25 kg or 0.5 lb.
- If Pulse+ ends mid-workout, suggestions stop from the next set; nothing already logged changes.
