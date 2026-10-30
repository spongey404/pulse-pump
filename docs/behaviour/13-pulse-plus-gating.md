# 13 Supernova gating (free vs Plus), trial, restore

Scope: what Supernova is supposed to unlock (docs/pulse-pump-spec.md "Phase 14", lines 308-342) versus what the code actually gates, every gate point with file:line, the 14-day trial, and restore purchases. The paywall screen itself is described in 10-more-settings.md (PLS).

Method: grepped `isSubscribed`, `isInFreeTrial`, `hasAccess`, `SupernovaService`, `SupernovaFeature`, `PWPlusGate`, `isPlus`, `plusOverride`, `SupernovaUpsellBanner`, `SupernovaBlurOverlay`, "SUPERNOVA" across `Ore/`, `OreShared/`, `OreWidget/`, `firebase/` (Firestore rules and functions contain no entitlement check).

Entitlement model (`SupernovaService.swift`):
- `isSubscribed`: StoreKit 2 `Transaction.currentEntitlements` contains product `com.pulse.PulsePump.monthly` or `com.pulse.PulsePump.yearly` (or DEBUG `plusOverride`). Each view creates its own `SupernovaService()` instance and refreshes it itself.
- `isInFreeTrial`: local, derived from `UserDefaults["appInstallDate"]` (see TRL).
- Gates in code use one of three predicates: subscribed only; subscribed OR trial; widget flag (subscribed OR trial, cached in the App Group). They are not consistent (see GAT-E01).
- `SupernovaFeature` (10 cases), `hasAccess(to:)`, `SupernovaUpsellBanner` and `SupernovaBlurOverlay` exist but have no call sites. There is no generic gate helper in use.

## Free vs Plus table (spec vs code)

Spec = docs/pulse-pump-spec.md. "Gated in code" lists the predicate used. "Paywall lists" = the six modules on the Supernova screen (Smart Predictions, Cloud Sync, Advanced Analytics, Weekly Recaps, Friend Challenges, Import / Export).

| # | Feature | Spec tier | Gated in code? | What a free user sees | Notes |
|---|---|---|---|---|---|
| 1 | Cloud sync across devices | Plus | NO (sync runs for every signed-in user) | Everything syncs; Settings › CLOUD SYNC shows status | Paywall lists it; claimed but not gated. Spec also says offline-sync is Plus. |
| 2 | Smart weight suggestions | Plus | Not built | Settings row "Smart Weight Suggestions: COMING SOON" | `smartWeightSuggestion()` exists, no UI call |
| 3 | Advanced exercise substitutions (smart) | Plus | Not built | Manual picker for everyone | `ExerciseSubstitutionView` dead |
| 4 | Challenges / competitions (create) | Plus | NO | Challenges and "Create Challenge" work | Known gap in spec (line 424) |
| 5 | Personalized calorie formula (MET) | Plus | Partly: menu only (subscribed OR trial) | Calorie Formula menu offers only "Basic (set-based)" | Estimator ignores entitlement (GAT-24) |
| 6 | Muscle group balance + imbalance detection | Plus | Only as a Plus widget | Widget shows locked preview | No in-app screen exists |
| 7 | Deload week marking | Plus | YES (subscribed OR trial) | "Deload Week" toggle hidden on workout detail | WorkoutDetailView.swift:49 |
| 8 | Detailed analytics + tips | Plus | Not built | n/a | Paywall lists "Advanced Analytics" |
| 9 | Advanced body model customization | Plus | Not built | n/a | Free skin tone/body type also not built |
| 10 | Detailed muscle sub-regions | Plus | YES (subscribed ONLY, no trial) | Muscle detail sheet shows only Performed / Not Yet Tried | MuscleDetailSheet.swift:29,58,78 |
| 11 | Additional home-screen widgets | Plus | YES for 4 fixed widgets (subscribed OR trial) + builder entry | Locked preview with "UNLOCK SUPERNOVA" | See GAT-30..36 |
| 12 | Neglected-muscle nudges | Plus | Only inside the Body map widget | n/a | No in-app badge |
| 13 | Weekly recap | Free (not in Plus list) | Not gated | Works | Paywall lists "Weekly Recaps / Automated Monday summaries" but recap is manual and free |
| 14 | Data import | Free | Not gated | Works | OK |
| 15 | Data export | Spec "NOT in V1" | Not gated | Works | Paywall lists "Import / Export" as Plus |
| 16 | Smart prediction (next workout) | Free | Not gated | Works | Paywall lists "Smart Predictions" as Plus |
| 17 | Unlimited equipment profiles | not in spec | Not gated (enum case only) | Unlimited | `SupernovaFeature.unlimitedEquipmentProfiles` |
| 18 | Priority support | not in spec | Not built | n/a | enum case only |
| 19 | Core logging, rest timer, exercise library, templates, template sharing, basic analytics, streaks, body heatmap, social feed / likes / comments, plate calculator, warm-up, manual substitution, share cards, reminders, search, basic widgets, Live Activity | Free | Not gated | Works | matches spec |

## GAT  Gate points (every place code decides on entitlement)

| ID | User does → App does (observable result) | Status | Manual check | Tests |
|---|---|---|---|---|
| GAT-03 | Free user (trial over) opens Settings › WORKOUT › "Calorie Formula" → App offers only "Basic (set-based)". Subscriber or trial user also sees "MET-Based". | ✅ SettingsView.swift:54,130-132 | [ ] | — |
| GAT-06 | Free user taps More › Widgets (tagged "SUPERNOVA") → App opens the Supernova full-screen paywall instead of the Widgets library. Subscriber / trial user opens the library. | ✅ MoreTabView.swift:103-105 | [ ] | — |
| GAT-09 | Free user opens the More hub → App shows the "UNLOCK SUPERNOVA" banner and the "Supernova FREE" row. Predicate is `!isSubscribed`, so trial users also see the banner and "FREE". | 🟡 MoreTabView.swift:75,94,109 | [ ] | — |
| GAT-12 | Subscriber opens the hub → App hides the banner and shows "ACTIVE". | ✅ MoreTabView.swift:94,109 | [ ] | — |
| GAT-15 | Free user opens a finished workout's detail → App hides the "Deload Week" toggle. Subscriber / trial user sees the toggle and can flag the workout (`workout.isDeload`), which the Deload widget reads. | ✅ WorkoutDetailView.swift:49-54 | [ ] | — |
| GAT-18 | Free user taps a muscle on the body map → App shows the detail sheet with "Performed" and "Not Yet Tried" only. Subscriber sees a "Sub-Regions" section (anatomical sub-regions with per-region exercise counts) and sub-region labels under each exercise. The predicate is `isSubscribed` only, so trial users do NOT get sub-regions although the spec promises "all Supernova features" during the trial. | 🐞 MuscleDetailSheet.swift:29,58,78 (expected `isSubscribed or isInFreeTrial`) | [ ] | — |
| GAT-21 | Free user looks at the body map tab → App shows the same body map for everyone; there is no Plus-gated customization, no neglected-muscle badge and no upsell. The tab creates a `SupernovaService` and refreshes it but never reads it. | ❌ BodyMapTabView.swift:29,78 (spec items 9 and "neglected nudges" not built) | [ ] | — |
| GAT-24 | User with a stored "MET-Based" choice loses Plus (trial ends or subscription lapses) → App keeps computing MET calories for the live estimate and the saved workout, because `CalorieEstimationService.estimate(... isSubscribed: Bool = true)` is called without the argument. The menu hides MET but the stored value still applies. | 🐞 WorkoutViewModel.swift:204,318, CalorieEstimationService.swift:53-63 | [ ] | — |
| GAT-27 | Free user starts a challenge from Social › Challenges → App lets them create it. No Supernova check anywhere in the challenge flow, Firestore rules or functions. | ❌ spec (docs/pulse-pump-spec.md:255,424) not met | [ ] | — |
| GAT-30 | Free user (trial over) adds the Plus widget "Body map" (muscle heatmap) → Widget shows `LockedWidgetPreview` for kind bodyMap ("Muscle heatmap", "Which muscles are fresh and which are neglected.") with an "UNLOCK SUPERNOVA" button. | ✅ FixedWidgets.swift:147, LockedPreviewWidget.swift:8-55 | [ ] | — |
| GAT-33 | Free user adds the "Balance" widget → locked preview "Muscle balance" ("Push vs pull over 4 weeks."). Same for "PR watch" ("Lifts close to a record, with estimated 1RM trend.") and "Deload" ("Deload and recovery"). Widgets 04-07 are Plus; the other fixed widgets are free. | ✅ FixedWidgets.swift:230,246,260 | [ ] | — |
| GAT-36 | User taps "UNLOCK SUPERNOVA" on a locked widget → iOS opens `pulsepump://supernova`; the app switches to More and presents the paywall. On cold launch the link is dropped (observer lives in ContentView). | 🟡 LockedPreviewWidget.swift:34, OreApp.swift:101-104, ContentView.swift:86-89 | [ ] | — |
| GAT-39 | System: widget entitlement flag → `OreWidgetSnapshot.fixed.isPlus = subscribed OR trial`. The app writes it on every snapshot rebuild and when StoreKit entitlement is refreshed (`setSubscribed`). The extension never contacts StoreKit. | ✅ WidgetDataService+Fixed.swift:80,511-521 | [ ] | — |
| GAT-42 | System: trial ends while the app is closed → Plus widgets stay unlocked until the app next rebuilds the snapshot (app launch / workout end / unit change). `setSubscribed` also returns early when the stored flag is unchanged, so a trial lapse alone does not patch the snapshot. | 🟡 WidgetDataService+Fixed.swift:516-521 | [ ] | — |
| GAT-45 | Free user opens the Widgets library through any other route (for example a saved custom widget on the home screen) → Custom widgets ("Ore Custom") render for everyone; the extension has no Plus check. The only gate is the More › Widgets row. | 🟡 OreWidget/CustomWidget.swift | [ ] | — |
| GAT-48 | Free user uses cloud sync → App syncs normally (SyncService has no entitlement check). The paywall copy and spec say it is Plus. | ❌ not gated (SyncService / SyncLifecycle contain no Plus check) | [ ] | — |
| GAT-51 | Free user opens Weekly Recap, Import / Export, Equipment Profiles, History → All work; paywall modules "Weekly Recaps" and "Import / Export" are not gated. | 🟡 marketing copy overstates Plus (SupernovaView.swift:20-29) | [ ] | — |
| GAT-54 | Free user looks for upsell banners or blurred analytics ("Unlock with Supernova") → App has none: `SupernovaUpsellBanner` ("UNLOCK WITH SUPERNOVA") and `SupernovaBlurOverlay` are never used. Upsell surfaces that exist: hub banner, hub "Supernova" row, Widgets row tag, locked widgets. | ❌ spec ("subtle inline banners") only partly met | [ ] | — |
| GAT-57 | Free user opens the paywall's "NEXT SESSION · PREVIEW" → App shows the preview built from their own history, for free and for paid users alike. It is a teaser, not a gated feature. | ✅ SupernovaView.swift:37 | [ ] | — |
| GAT-60 | Free user looks for Smart Weight Suggestions → "COMING SOON" row; no gating needed yet. | ❌ not built | [ ] | — |
| GAT-63 | Free user opens Settings › Privacy, Social, Feed → No Plus gating (spec says social is free). | ✅ | [ ] | — |

### GAT edge cases

| ID | Situation | What the app does | Why/notes | Status | Manual check | Tests |
|---|---|---|---|---|---|---|
| GAT-E01 | Predicate inconsistency | Calorie menu, Widgets row, Deload toggle and widget flag use subscribed OR trial; hub banner and body-map sub-regions use subscribed only. | A trial user sees different answers on different screens. | 🐞 | [ ] | — |
| GAT-E02 | Offline at launch | StoreKit returns cached entitlements, so a subscriber stays Plus offline. Trial works offline (local date). | | ✅ | [ ] | — |
| GAT-E03 | Entitlement not yet loaded on first frame | Each view's `SupernovaService` starts with `isSubscribed = false` and refreshes in `.task`; a subscriber may briefly see the free UI (banner, hidden toggles) until the refresh returns. | | 🟡 | [ ] | — |
| GAT-E04 | Two devices | Entitlement follows the Apple ID; trial is per device (UserDefaults). | | ✅ | [ ] | — |
| GAT-E05 | Plus lapses with data created while Plus | `isDeload` flags and custom widgets stay in the data; the toggle becomes hidden; the Deload widget locks. Nothing is deleted. | | ✅ | [ ] | — |
| GAT-E06 | DEBUG override | `-devDataPlus 1` makes `isSubscribed` true in the app but does not set the widget flag (only `foundActive` is passed to `setSubscribed`), so Plus widgets still lock unless trial is active. | DEBUG only; ignored in Release. | 🟡 SupernovaService.swift:125-126 | [ ] | — |
| GAT-E07 | Spec "multi-app" tiers (1 / 2 / 3 apps) | Not represented; two single-app products only. | | ❌ | [ ] | — |

## TRL  Free trial

| ID | User does → App does (observable result) | Status | Manual check | Tests |
|---|---|---|---|---|
| TRL-03 | System: first time anything reads `isInFreeTrial` (usually the first Settings / More / widget snapshot evaluation, not the install moment) → App writes `appInstallDate = now` to UserDefaults and returns true. | ✅ SupernovaService.swift:129-137 | [ ] | — |
| TRL-06 | System: later reads → App computes whole calendar days since `appInstallDate` and returns true while the count is 14 or less, so the trial covers day 0 through day 14 (15 calendar days). | ✅ SupernovaService.swift:129-137 (spec says 14 days) | [ ] | — |
| TRL-09 | User opens the paywall during the trial → App shows "{n} DAYS LEFT IN TRIAL" where n = max(0, 14 − days since install). On day 14 it shows "0 DAYS LEFT IN TRIAL" while Plus gates are still open. | 🟡 SupernovaView.swift:306-314, SupernovaService.swift:139-144 | [ ] | — |
| TRL-12 | System: day 15 → App flips every `isSubscribed or isInFreeTrial` gate to locked on the next evaluation; no "trial ended" message or modal. | 🟡 no expiry communication | [ ] | — |
| TRL-15 | User deletes and reinstalls the app → UserDefaults are cleared, so a fresh 14-day trial starts (not tied to the Apple ID). Sign-out / sign-in does not reset it (the key is not in the sign-out cleanup list); a second account on the same device inherits the remaining trial. | 🐞 spec gap "Free trial uses UserDefaults install date instead of StoreKit introductory offer" (docs/pulse-pump-spec.md:466) | [ ] | — |
| TRL-18 | User sets the device clock back → App extends the trial (local date only). | 🐞 same root cause | [ ] | — |
| TRL-21 | System: trial users on the hub → App labels them "FREE" and still shows the "UNLOCK SUPERNOVA" banner (GAT-09). | 🟡 | [ ] | — |
| TRL-24 | 🧭 PROPOSED default: replace the local trial with a StoreKit introductory offer (14 days free on both products) so it is tied to the Apple ID; until then keep the local trial and show a one-time "Your Supernova trial has ended" notice on day 15. | 🧭 | [ ] | — |

### TRL edge cases

| ID | Situation | What the app does | Why/notes | Status | Manual check | Tests |
|---|---|---|---|---|---|---|
| TRL-E01 | DST / timezone change | Day count uses `Calendar.current` calendar days, so a change of time zone can shift the count by one at the boundary. | | 🟡 | [ ] | — |
| TRL-E02 | Subscriber during trial | Paywall shows ACTIVE; the trial note is hidden when subscribed. | | ✅ SupernovaView.swift:39-44 | [ ] | — |
| TRL-E03 | Existing users who installed before trial logic | `appInstallDate` is created at first evaluation after the update, so they receive a new 14-day trial. | | 🧭 | [ ] | — |

## RPU  Restore purchases and transaction handling

| ID | User does → App does (observable result) | Status | Manual check | Tests |
|---|---|---|---|---|
| RPU-03 | User taps "Restore Purchases" at the bottom of the paywall (visible to everyone, including subscribers) → App runs `AppStore.sync()` (may prompt for Apple ID sign-in), then refreshes entitlements. If an active subscription is found the screen switches to the ACTIVE state and the widgets flag is updated. If none is found nothing visibly happens. | 🟡 SupernovaService.swift:109-112; no progress or result message | [ ] | — |
| RPU-06 | System: `AppStore.sync()` throws (offline, cancelled sign-in) → App swallows the error (`try?`) and still refreshes. | 🟡 SupernovaService.swift:110 | [ ] | — |
| RPU-09 | System: purchase succeeds elsewhere (Family Sharing, Ask to Buy approval, renewal, other device) while the paywall is closed → App only notices at the next `refreshSubscriptionStatus()` (hub open, Settings open, workout detail, body map). The `Transaction.updates` listener runs only while the paywall is open. | 🐞 SupernovaService.swift:63-70,160-167, SupernovaView.swift:53-63 (expected: start the listener once at app launch) | [ ] | — |
| RPU-12 | User buys, then immediately leaves the paywall → Entitlement refresh happens inside `purchase()` before returning, so gates open right away. | ✅ SupernovaService.swift:91-107 | [ ] | — |
| RPU-15 | System: unverified transaction → App throws `StoreError.verificationFailed` ("Transaction verification failed.") and shows the "Purchase Error" alert; entitlement unchanged. | ✅ SupernovaService.swift:152-158 | [ ] | — |
| RPU-18 | User taps Restore in the simulator / without products → Same as RPU-03; `isSubscribed` stays false. | ✅ | [ ] | — |
| RPU-21 | User with a subscription taps "Manage" → App has no manage link; text says "Manage in App Store." | 🟡 SupernovaView.swift:284 | [ ] | — |

## Open decisions for the owner (13)

- Cloud sync is ungated while the paywall and spec say Plus (GAT-48). Decide: gate (and define free behaviour: local-only, no backup) or remove it from the paywall copy. Strong product implication: free users currently get account restore on a new device.
- Challenges are ungated (GAT-27); decide who may create vs join.
- Paywall copy overstates: Smart Predictions, Weekly Recaps and Import / Export are free in code (GAT-51, table rows 13-16). Either gate them or reword the six modules.
- Trial semantics: GAT-18 (sub-regions exclude trial users), GAT-09/TRL-21 (hub says FREE during trial), GAT-E01 predicate inconsistency. PROPOSED: one helper `hasPlus = isSubscribed || isInFreeTrial` used everywhere.
- TRL-24 (PROPOSED): move to a StoreKit introductory offer; add a "trial ended" notice; define whether the trial is 14 or 15 days (TRL-06).
- GAT-24: MET calories continue after Plus lapses; decide whether the estimator should enforce the gate.
- RPU-09: start the `Transaction.updates` listener at app launch.
- RPU-03 (PROPOSED): show a result toast for Restore ("Supernova restored" / "No purchases found").
- Not built features promised in the spec: smart weight suggestions, smart substitutions, balance / imbalance analytics, advanced analytics and tips, advanced body customization, neglected-muscle badge, upsell blur banners (GAT-54, GAT-21, GAT-60). Decide the V1 Plus line.
- Multi-app pricing tiers (GAT-E07) are not implemented.
- Dead gate scaffolding: `SupernovaFeature`, `hasAccess(to:)`, `SupernovaUpsellBanner`, `SupernovaBlurOverlay`.
