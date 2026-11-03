# 13 Supernova (free vs paid)

## What it's for
Supernova is the paid tier. New installs get a free trial, then a monthly or annual subscription unlocks the extra features. Today the paywall promises more than the app actually locks.

## The flow
1. As a free user, open More → the UNLOCK SUPERNOVA banner and the Supernova row (FREE).
2. Tap the banner → the Supernova screen: hero, a preview of your next session, six features, a trial countdown ("n DAYS LEFT IN TRIAL") and MONTHLY / ANNUAL plans (Annual preselected).
3. Tap START SUPERNOVA → Apple's purchase sheet → buy → the screen shows ACTIVE and the banner disappears.
4. Check what unlocked: MET calorie formula (Settings › Calorie Formula), Widgets and the widget builder, the four Supernova widgets, Deload Week toggle in workout detail, muscle sub-regions on the Body tab, smart weight suggestions.

**Alternate paths**
- **Restore:** Supernova screen › Restore Purchases → if a subscription is found the screen flips to ACTIVE.
- **Locked widget:** tap UNLOCK SUPERNOVA on a locked widget → Ore opens the Supernova screen.
- **Trial ends:** after 15 days the Plus features lock again with no message.

**What is locked today vs what the paywall says**
- Locked: MET calories, Widgets library and builder, 4 Plus widgets, deload toggle, muscle sub-regions, smart weight suggestions.
- Free, though the paywall sells them as Plus: cloud sync, smart workout predictions, weekly recaps, import and export, creating challenges.

## Not working / not built yet
- During the trial, More still says FREE and shows the upgrade banner. (broken)
- Muscle sub-regions stay locked for trial users. (broken)
- MET calories keep working after Plus ends. (broken)
- The trial is tied to the install date: reinstalling or moving the clock back gives a new trial. (broken)
- The trial lasts 15 days while the screen counts down from 14, and shows "0 DAYS LEFT" while still active.
- No message when the trial ends.
- Purchases made elsewhere (family sharing, another device) aren't noticed until you revisit certain screens. (broken)
- Restore Purchases gives no message; there's no Manage Subscription link.
- No inline "Unlock with Supernova" hints anywhere except More, Widgets and the suggestions row. (not built)
- Promised Plus features not built: smart exercise substitutions, muscle balance analysis, advanced analytics and tips, body customisation, neglected-muscle nudges, multi-app pricing.

## Decide
- **What Supernova includes:** Plus = smart weight suggestions, MET calories, muscle sub-regions, deload marking, the four Plus widgets and the widget builder, and creating challenges. Free = logging, cloud sync and backup, predictions, weekly recap, import and export, joining challenges, social. Rewrite the paywall to match; multi-app pricing later. *Recommended: yes.*
- **Trial:** a 14-day free trial through Apple (tied to the Apple ID), "TRIAL · n DAYS LEFT" in More, a "trial ended" notice, and custom widgets lock when it ends. *Recommended: yes.*

## Rules I'll apply
- One "has Supernova" check everywhere: subscribed or in trial.
- The app listens for purchases from launch, not only on the Supernova screen.
- Restore Purchases shows "Supernova restored" or "No purchases found"; add a Manage Subscription link.
- Widgets re-check Plus whenever the app opens, so they lock the day the trial ends.
- Existing challenges keep working if Plus lapses; only creating new ones needs Plus.
