# 01 Account and onboarding

## What it's for
Everyone signs in before using Ore, with Apple, Google or email. New people answer nine quick questions so the app can set up their profile and training split. Returning people get their data back on any phone.

## The flow
**New account**
1. Open the app → splash, then the sign-in screen with three buttons: Continue with Apple, Continue with Google, Use email instead.
2. Tap Use email instead → switch to SIGN UP, type email and a password of 8+ characters → tap CREATE ACCOUNT.
3. Step 1: type your first name → Continue.
4. Step 2: the app suggests a username from your name and checks it. Change it if you like; Continue unlocks when it says AVAILABLE.
5. Steps 3 to 5: weight (KG or LB), height (CM or FT/IN), age.
6. Steps 6 and 7: gender and experience (both optional).
7. Step 8: pick a split (Push/Pull/Legs, Upper/Lower, Full Body, Bro Split, Custom, or No fixed split).
8. Step 9: beginners choose YES, SHOW ME AROUND or SKIP; experienced lifters see START TRAINING → "Creating your account", then Home.
9. iOS asks for notification permission straight away.

**Alternate paths**
- **Returning user, same phone:** open the app → straight to Home, even offline.
- **New phone or reinstall:** sign in → "Restoring your data…" → Home with workouts and programs back. With no internet you see "You're offline" with TRY AGAIN and SIGN OUT.
- **Forgot password:** email sheet → Forgot password? → SEND RESET LINK → check your inbox.
- **Change username:** More › Settings › Username → type a new one → SAVE. The old one is freed for others.
- **Sign out:** More › Sign Out → alert says your data is safe in your account → Sign Out → sign-in screen. Sign in again to restore everything.
- **Delete account:** More › Settings › Delete Account → type DELETE (and your password for email accounts) → DELETE FOREVER → everything in the cloud and on the phone is removed.

## Not working / not built yet
- Terms of Service and Privacy Policy links do nothing (no hosted pages yet).
- Signing out offline can lose workouts that have not synced, while the alert says they are safe.
- Signing out does not stop workout reminders; they keep firing for the old account.
- Signing out during a workout throws the workout away without warning.
- Signing in with Apple or Google using an email that already has an email account shows a confusing error.
- The "Restoring your data" screen can spin forever with no way out except killing the app.
- The final onboarding step says "We've set up a basic template" but only the split is created.
- Deleting an account does not remind you to cancel a Supernova subscription.
- You cannot use the app at all without an account and an internet connection for setup.

## Decide
- **Sign-out safety:** warn when unsynced changes exist (with "Sign out anyway"), block sign-out during an active workout, and cancel reminders on sign-out. *Recommended: yes.*
- **Minimum age:** block sign-up under 13 with a short message. *Recommended: yes (App Store and privacy-law norm).*
- **Same email, different sign-in method:** no account merging in v1; tell the person which method that email already uses. *Recommended: yes.*

## Rules I'll apply
- Weight must be 20 to 500 kg and height 80 to 260 cm at onboarding.
- After 30 seconds the restore screen offers TRY AGAIN and SIGN OUT.
- Usernames can be changed any time (no cooldown) for v1.
- Deleting an account also revokes the Apple sign-in token and reminds you to cancel your subscription in the App Store.
- Challenges a deleted user created stay alive for the other members.
