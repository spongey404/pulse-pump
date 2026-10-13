# 06 Body tab

## What it's for
The Body tab shows which muscles you've trained this week as a heat map, which are ahead and which are falling behind, so you can balance your training.

## The flow
1. Tap the Body tab → this week: total working sets against a weekly target, how many of 17 muscle groups you hit, and a VS PACE box (are you ahead or behind for the day of the week).
2. Look at the front and back figures → muscles glow by how much work they got.
3. Read ▲ TOP and ▼ GAPS → your three most-worked and three least-worked groups.
4. Tap a day in the M T W T F S S row → everything switches to that day, with VS LAST comparing it to the last time you did that workout. Tap it again to return to ALL WEEK.
5. Tap a muscle on the figure → a sheet lists exercises you've done for it and ones you haven't tried.
6. Scroll down to Cold spots → FREQ shows muscles you haven't trained for a while; VOL shows muscles under target in the last 7 days.

**Alternate paths**
- **Earlier weeks:** tap ‹ to go back up to 3 weeks; › to return.
- **Recovery view:** tap LAST 48H → muscles glow by how recently they were trained.
- **Calendar:** tap CAL → month grid → tap a workout day → VIEW › jumps to that day (within the last 4 weeks).

## Not working / not built yet
- VS PACE shows −100% in red on Monday morning before you've had a chance to train.
- LAST 48H assumes it's 9 pm, so a workout after 9 pm today doesn't show until tomorrow. (broken)
- Two workouts on one day: the label, VS LAST and calendar only show the first. (broken)
- In single-day view the legend says "100% of target" but means "busiest muscle that day". (broken)
- Week 1 of the year says "VS WK 0". (broken)
- The calendar's › arrow can't reach the current month in some weeks. (broken)
- The muscle sheet misses exercises tagged generically as "back" or "shoulders". (broken)
- The muscle sheet has no trend graph and its rows can't be tapped. (not built)
- Pulse+ sub-regions in the muscle sheet are hidden from trial users. (broken)
- New users see an empty map with no guidance.
- Cold spots use different rules from the rest of the tab, so one muscle can read differently in two places.
- Not built from the spec: neglected-muscle badges, push/pull balance, volume sparkline, body customisation, colour presets, Simple Body Map.

## Decide
- No owner questions here beyond the Pulse+ line (README decision 1). The layout stays as built: front and back side by side, not swiped.

## Rules I'll apply
- VS PACE shows a blank dash until your first workout of the week.
- LAST 48H uses the real current time for this week.
- Two workouts on the same day are combined in the label, VS LAST and the calendar.
- New users see "Log a workout to light up your map" instead of an empty figure.
- The muscle sheet uses the same muscle grouping as the map, and trial users see sub-regions.
