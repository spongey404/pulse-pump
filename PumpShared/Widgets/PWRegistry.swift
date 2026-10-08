import SwiftUI

// Central list of every fixed widget section, in design order (Pump Widgets.dc.html).
enum PWRegistry {
    static var sections: [PWGallerySection] {
        [
            PWGallerySection(id: "01", name: "Next workout", tier: "FREE",
                             blurb: "The predicted session with confidence. 1A carries an interactive START that opens the logger with the template loaded. 1B is tap-anywhere and shows the first lift.",
                             items: NextWorkoutWidget.gallery),
            PWGallerySection(id: "02", name: "Streak", tier: "FREE", blurb: StreakWidget.blurb, items: StreakWidget.gallery),
            PWGallerySection(id: "03", name: "Weekly volume", tier: "FREE", blurb: WeeklyVolumeWidget.blurb, items: WeeklyVolumeWidget.gallery),
            PWGallerySection(id: "04", name: "Body map heatmap", tier: "PLUS", blurb: BodyMapWidget.blurb, items: BodyMapWidget.gallery),
            PWGallerySection(id: "05", name: "Muscle balance", tier: "PLUS", blurb: BalanceWidget.blurb, items: BalanceWidget.gallery),
            PWGallerySection(id: "06", name: "PR watch", tier: "PLUS", blurb: PRWatchWidget.blurb, items: PRWatchWidget.gallery),
            PWGallerySection(id: "07", name: "Deload and recovery", tier: "PLUS", blurb: DeloadWidget.blurb, items: DeloadWidget.gallery),
            PWGallerySection(id: "08", name: "Active workout · Dynamic Island", tier: "FREE", blurb: LiveActivityGallery.blurb, items: LiveActivityGallery.gallery),
            PWGallerySection(id: "09", name: "Last session recap", tier: "FREE", blurb: RecapWidget.blurb, items: RecapWidget.gallery),
            PWGallerySection(id: "10", name: "Program", tier: "FREE", blurb: ProgramWidget.blurb, items: ProgramWidget.gallery),
            PWGallerySection(id: "11", name: "Weekly goal", tier: "FREE", blurb: GoalWidget.blurb, items: GoalWidget.gallery),
            PWGallerySection(id: "12", name: "Bodyweight", tier: "FREE", blurb: BodyweightWidget.blurb, items: BodyweightWidget.gallery),
            PWGallerySection(id: "13", name: "Friends", tier: "FREE", blurb: FriendsWidget.blurb, items: FriendsWidget.gallery),
            PWGallerySection(id: "14", name: "Quick start", tier: "FREE", blurb: QuickStartWidget.blurb, items: QuickStartWidget.gallery),
            PWGallerySection(id: "15", name: "Pulse", tier: "FREE", blurb: PulseEcoWidget.blurb, items: PulseEcoWidget.gallery),
            PWGallerySection(id: "16", name: "Lock screen", tier: "FREE · PLUS", blurb: LockScreenWidgets.blurb, items: LockScreenWidgets.gallery),
            PWGallerySection(id: "17", name: "Locked preview", tier: "PLUS", blurb: LockedPreviews.blurb, items: LockedPreviews.gallery),
        ]
    }
}
