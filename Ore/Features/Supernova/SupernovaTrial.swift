import Foundation

/// The free-trial length. It is a remote setting (Firebase Remote Config key `supernova_trial_months`), so it can be
/// changed in the Firebase console without shipping a build; the last value fetched is cached in `UserDefaults` and
/// used from the next launch on, and `defaultMonths` applies until one has been fetched.
///
/// This is the in-app trial and the paywall copy. The App Store's own introductory offer is configured in App Store
/// Connect; keep the two the same.
enum SupernovaTrial {
    static let remoteKey = "supernova_trial_months"
    static let cacheKey = "supernovaTrialMonths"
    static let defaultMonths = 3
    static let allowedMonths = 0...12

    /// Months of free trial; 0 means no trial.
    static var months: Int {
        get {
            guard let stored = UserDefaults.standard.object(forKey: cacheKey) as? Int, allowedMonths.contains(stored) else { return defaultMonths }
            return stored
        }
        set { UserDefaults.standard.set(min(max(newValue, allowedMonths.lowerBound), allowedMonths.upperBound), forKey: cacheKey) }
    }

    static func endDate(installDate: Date, months: Int, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .month, value: months, to: installDate) ?? installDate
    }

    static func isActive(installDate: Date, now: Date = Date(), months: Int, calendar: Calendar = .current) -> Bool {
        now < endDate(installDate: installDate, months: months, calendar: calendar)
    }

    static func daysRemaining(installDate: Date, now: Date = Date(), months: Int, calendar: Calendar = .current) -> Int {
        let end = endDate(installDate: installDate, months: months, calendar: calendar)
        guard now < end else { return 0 }
        let days = calendar.dateComponents([.day], from: now, to: end).day ?? 0
        return max(1, days)
    }

    // MARK: Copy

    /// "3 months", "1 month".
    static func phrase(months: Int) -> String { months == 1 ? "1 month" : "\(months) months" }

    /// Paywall sub-headline.
    static func headline(months: Int, apps: String) -> String {
        months > 0 ? "\(phrase(months: months)) free across \(apps)." : "One membership across \(apps)."
    }

    /// Paywall button title.
    static func ctaTitle(months: Int) -> String {
        months > 0 ? "START \(phrase(months: months).uppercased()) FREE" : "START SUPERNOVA"
    }
}
