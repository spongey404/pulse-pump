# 10 More and Settings

## What it's for
More holds everything that isn't a main screen: your profile, history, recap, widgets, settings, import and export, the Pulse+ screen, the tutorial and legal pages.

## The flow
1. Tap the More tab → your name and @username, a stats strip (WORKOUTS, STREAK, FRIENDS, FANS), an UNLOCK PULSE+ banner on the free plan, then sections: Training (History, Equipment Profiles, Weekly Recap, Widgets), Account (Settings, Pulse+), Help (Tutorial, Data Import, Privacy & Legal, Sign Out).
2. Tap Settings → Account (Edit Profile, Email, Signed In With, Username), Units, Workout (Calorie Formula, Rest Timer Mode, Timer Alert, Smart Weight Suggestions), Privacy (Profile Visibility, Auto-Share to Feed), Appearance (Theme), Training (Training Split), Notifications, Data, Cloud Sync, About, Sign Out, Delete Account.
3. Change Weight Unit to Pounds → every weight in the app and widgets switches to lb; your saved data doesn't change.
4. Change Theme to Dark → the whole app re-themes at once.

**Alternate paths**
- **Import from Strong or Hevy:** More › Data Import → Import from Strong (or Hevy) → pick the CSV → "Import Complete" with counts. Importing the same file twice adds nothing new.
- **Export:** Settings › Import / Export Data → Export as JSON or CSV → the share sheet opens (always in kg).
- **Equipment:** More › Equipment Profiles → + → name it ("Home Gym") and tick your equipment → Save.
- **Tutorial:** More › Tutorial → a guided card tour (GOT IT → to advance, SKIP to stop).
- **Pulse+ screen:** tap the banner or Pulse+ → features, a preview of your next session, MONTHLY / ANNUAL plans → START PULSE+ → Apple's purchase sheet.

## Not working / not built yet
- Privacy Policy, Terms of Service, Open-Source Licenses and Download My Data do nothing. (not built; App Store risk)
- During the free trial the hub says FREE and still shows UNLOCK PULSE+. (broken)
- MET calories keep working after Pulse+ ends. (broken)
- Choosing Annual can buy Monthly if the annual product fails to load. (broken)
- Restore Purchases gives no message either way.
- Import errors are titled "Export Error". (broken)
- Exercise names with quotes break the CSV export. (broken)
- Export covers workouts only, not programs, bodyweight or profile.
- Equipment profiles can't be edited, renamed or deleted; "Add Equipment" does nothing; nothing in the app uses them. (not built)
- Tutorial steps 4 to 10 are placeholders that block the screen they describe. (broken)
- "COMING SOON" rows: Simple Body Map, Social Activity, Challenge Updates. (not built)
- No settings for week start, default rest times, reminder times or changing email and password. (not built)
- The Plate Calculator and Warm-up Generator exist but can't be opened. (not built)
- The Privacy & Legal note points to Settings for privacy, but most privacy options are under Social › bell.

## Decide
- **Settings clean-up:** add week start (Monday or Sunday) and default rest time; hide every "COMING SOON" row; make Download My Data run the export; you supply hosted Privacy Policy and Terms URLs. *Recommended: yes.*
- **Equipment profiles:** make them editable (rename, delete, plates) and have the workout plate calculator use your active profile. *Recommended: yes.*
- **Tools:** add a Tools section in More with the Plate Calculator and Warm-up Generator. *Recommended: yes.*
- **Tutorial:** replace the 10-step tour with 3 or 4 steps that actually point at the right buttons. *Recommended: yes.*

## Rules I'll apply
- Import errors say "Import Error"; an empty file says "Nothing to import"; imported workouts count toward streaks and PRs.
- Restore Purchases says "Pulse+ restored" or "No purchases found".
- Choosing Annual only ever buys Annual.
- Calories fall back to the basic formula when Pulse+ ends.
- Pulse+ is tied to the Apple ID, not the Pump account.
