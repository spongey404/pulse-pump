import Foundation

extension MuscleGroup {
    /// The specific groups a generic `.back` / `.shoulders` stands for.
    private static let backChildren: Set<MuscleGroup> = [.lats, .upperBack, .lowerBack, .traps]
    private static let shoulderChildren: Set<MuscleGroup> = [.frontDelts, .sideDelts, .rearDelts]

    /// Maps an exercise's muscle list onto the tracked groups the Body tab counts, each at most once.
    ///
    /// Seeded exercises list a generic group next to its specific ones (Overhead Press is
    /// `[.shoulders, .frontDelts]`, Barbell Row `[.back, .lats]`). Folding the generic group into
    /// `fallbackBack` / `fallbackShoulders` and adding it as well double-counted the sets, so a generic
    /// group is dropped when a specific child is present and only used as the fallback when it stands alone.
    static func trackedGroups(
        _ groups: [MuscleGroup],
        tracked: Set<MuscleGroup>,
        fallbackBack: MuscleGroup = .upperBack,
        fallbackShoulders: MuscleGroup = .sideDelts
    ) -> Set<MuscleGroup> {
        let present = Set(groups)
        var out = Set<MuscleGroup>()
        for m in present {
            switch m {
            case .back:
                if present.isDisjoint(with: backChildren) { out.insert(fallbackBack) }
            case .shoulders:
                if present.isDisjoint(with: shoulderChildren) { out.insert(fallbackShoulders) }
            default:
                out.insert(m)
            }
        }
        return out.intersection(tracked)
    }
}
