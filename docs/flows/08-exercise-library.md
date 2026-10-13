# 08 Exercise library

## What it's for
Pump ships with about 240 exercises. You pick from them whenever you add an exercise to a workout or program, and you can look one up to see your progress on it.

## The flow
1. In a workout, tap + ADD EXERCISE → the picker opens: a search field, movement pills (ALL, push, pull, hinge, squat, carry…) and the list.
2. Type "press" → every exercise with "press" in its name appears.
3. Tap a family row such as Bench Press (4 VARIANTS) → pick Barbell, Dumbbell and so on → ADD → it's added and the picker closes.
4. Tap a single exercise row → added straight away.

**Alternate paths**
- **Look up an exercise:** Home › magnifier › type a name → tap the result → exercise detail (info, muscles, PRs, chart, recent sessions, programs using it, notes).
- **Replace during a workout:** card ··· → Replace Exercise → same picker.
- **Nothing found:** the picker says "No exercises found · TRY A DIFFERENT SEARCH".
- **Imported or shared names Pump doesn't know** are added automatically as custom exercises.

## Not working / not built yet
- You can't create your own exercise; the creator screen exists but nothing opens it. (not built)
- No browse-all library or filter by muscle or equipment. (not built)
- You can only add one exercise per trip to the picker.
- No "smart alternatives" when replacing an exercise (promised for Pulse+). (not built)
- The "Submit to community library" option has nothing behind it.
- Custom exercises have no badge in the picker.
- The picker and Home search match names differently ("press" vs words starting with "press").

## Decide
- **Custom exercises:** add "Create exercise" to the picker (when a search finds nothing) and an Exercise Library row in More; drop the community-submission toggle and smart alternatives for v1. *Recommended: yes.*

## Rules I'll apply
- Exercise names must be unique; a duplicate name is blocked with a message.
- One search rule everywhere: any word in the name starting with what you typed.
- Custom exercises show a CUSTOM badge in the picker.
- The picker lets you tick several exercises and add them together.
