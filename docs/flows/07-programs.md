# 07 Programs and templates

## What it's for
Programs are your saved workout plans (for example Push, Pull and Legs days). You start a workout from one so the logger is pre-filled with exercises, sets and rest times.

## The flow
1. Tap the Programs tab (leftmost) → your programs, each showing days per week, exercise count and when you last used it. New accounts start with presets: Push Pull Legs, Upper Lower and Full Body.
2. Tap a program → day tabs (PUSH 1, PULL 2, LEG 3), the exercises, and EDIT and START buttons.
3. Tap an exercise → see its sets, target reps, RIR and rest time.
4. Tap EDIT → change target reps, add or remove sets, set RIR and rest, add exercises, write notes → DONE.
5. Tap START → the logger opens with that day's exercises (see 03).

**Alternate paths**
- **Add a preset:** tap the blue + → pick Push Pull Legs, Upper Lower or Full Body → it's copied into your programs.
- **Build your own:** tap NEW PROGRAM (or + › Blank Program) → name it, pick days per week and optionally a split type → ADD EXERCISE → SAVE.
- **Quick start:** under QUICK START, tap START next to one of your last 3 workouts to repeat it.
- **Delete:** swipe a program left → tap the trash → DELETE. Past workouts stay in History.
- **Training split:** More › Settings › Training Split → pick one → Save Split. This sets your weekly schedule for predictions and reminders; it doesn't change your programs.
- **Open a shared program link:** tapping a Ore template link while the app is open adds the program and says "Added".

## Not working / not built yet
- There's no Share button, so programs can't be shared from the app. (not built)
- A shared link opened while the app is closed is silently ignored. (broken)
- Someone without the app who gets a link sees nothing useful. (not built)
- You can't rename a program, remove or reorder exercises, or change its days after creating it. (not built)
- Notes typed when creating a program are thrown away. (broken)
- Program notes never appear during the workout.
- Set-type chips in program detail are lost when you leave the screen. (broken)
- Target reps apply to every set of an exercise, not per set.
- The create form says you can set sets, reps and RIR there; you can only do that later in detail.
- Two programs with the same day pattern merge into one row. (broken)
- Quick start can restart a deleted program. (broken)
- Starting from Programs while a draft exists creates a second draft (see 02 decision on one workout at a time). (broken)
- Adding a preset you already have creates a duplicate with no warning.

## Decide
- **Template sharing:** add a Share button that sends a web link which opens the program in Ore, or the App Store if Ore isn't installed. *Recommended: yes.*
- **Program editing:** add rename, remove and reorder exercises, and change days; show program notes during the workout; drop the per-set type chips. *Recommended: yes.*

## Rules I'll apply
- Leaving the create form with unsaved input asks "Discard program?".
- Program names are capped at 40 characters; shared programs at 60 exercises and 1 to 20 sets each.
- Each program is its own row, even if two share the same day pattern; days keep the order you set.
- Quick start hides workouts whose program was deleted.
- The duplicate "Push/Pull/Legs (6-day)" split option is removed.
