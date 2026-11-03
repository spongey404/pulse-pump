# 09 Social: feed, friends and challenges

## What it's for
Social lets you see your friends' workouts, cheer them on, and compete in challenges. A friend is someone you follow who follows you back; everyone else who follows you is a fan.

## The flow
**Feed**
1. Tap the Social tab → FRIENDS shows posts from you and your friends, newest first: name, workout, duration, a body-map heat map, and SETS, VOLUME, IMPROVED and PRS.
2. Tap the heart → liked. Tap the speech bubble → comments open → type → send.
3. Tap FULL SESSION › → every exercise, best set and change vs last time. Tap an exercise → that person's history on that lift.
4. Pull down to refresh.

**Friends**
5. Tap your avatar (top right) → your profile → Find Friends → type someone's exact @username → FOLLOW.
6. When they follow back you become friends and see each other's posts.
7. Someone follows you → a dot appears on the bell → tap it → "Needs You" → ACCEPT (follow back) or IGNORE.

**Challenges**
8. Tap CHALLENGES → the monthly global challenge → JOIN → your total, rank and the leaderboard. Scores update from your logged workouts; nothing to type.
9. Tap Create Challenge → name it, pick a metric (total volume, heaviest lift, most reps, longest hold, sessions) and a length → NEXT › → INVITE friends → DONE.
10. Your friends see the invite in Challenges and under the bell → JOIN.

**Alternate paths**
- **Post menu (···):** Steal program (copies it to your programs), Save workout, Report post, Block, Unfollow. On your own post: Delete post.
- **Privacy:** bell › Privacy → choose who sees your posts, your body map, your profile, and whether you appear on global boards.
- **Block:** post or profile ··· → Block → they vanish from your feed, search and lists. Unblock under bell › Blocked people.
- **Share your handle:** Find Friends › Share Your Handle sends a text with your @username.
- **Ended challenge:** see the winner and your place; RUN IT AGAIN starts a fresh one.

## Not working / not built yet
- No per-post audience choice (not built); "Only me" silently posts nothing.
- If friends fail to load, the feed shows only your posts for 5 minutes. (broken)
- Network errors show "Private profile", empty comments, or endless grey leaderboard rows. (broken)
- "Save workout" saves to a list that doesn't exist. (not built)
- The PR mark in post detail can land on the wrong exercise.
- Reports give little feedback and nobody reviews them. (not built)
- No contacts matching, invite links, name search, likers list or social push. (not built)
- You can't remove a fan without blocking them.
- Invite copy says late joiners count from when they join; they count from the start. (broken)
- Creators can't end or delete a challenge. (not built)
- Longest hold shows "95" instead of 1:35.
- Hiding from global boards waits for your next workout. (broken)
- Anyone can create challenges; the spec says Supernova only. (not built)

## Decide
- **Per-post audience:** add a chip in the post composer that can only narrow your default (for example "Only friends" or "Only me"); past posts keep their audience. *Recommended: yes.*
- **Finding friends:** add an invite link that opens your profile in Ore; no contacts matching in v1; remove "Save workout". *Recommended: yes.*
- **Reports and moderation:** add a reason picker and set up a process where reports reach you by email and are reviewed within 24 hours (App Store requires this). *Recommended: yes, and you own the review.*
- **Challenges:** count all workouts since the challenge started (fix the copy), let creators End a challenge, and drop the unused Custom score and "lowest wins" options. *Recommended: yes.*

## Rules I'll apply
- Comments from people you blocked are hidden.
- Load failures show an error with RETRY, never "Private profile" or an empty list.
- PRs are marked with bold text and an underline, not gold.
- Ties for first on an ended challenge show "TIED" with both names; longest hold shows m:ss.
- The monthly global challenge is created by a documented admin script.
