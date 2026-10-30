import Testing
@testable import Ore

struct EnumTests {

    // MARK: - MovementPattern

    @Test func movementPatternIsCompound() {
        let compound: [MovementPattern] = [.push, .pull, .hinge, .squat, .carry]
        let notCompound: [MovementPattern] = [.rotation, .isolation]

        for pattern in compound {
            #expect(pattern.isCompound, "\(pattern) should be compound")
        }
        for pattern in notCompound {
            #expect(!pattern.isCompound, "\(pattern) should not be compound")
        }
    }

    @Test func movementPatternDisplayNamesNotEmpty() {
        for pattern in MovementPattern.allCases {
            #expect(!pattern.displayName.isEmpty, "\(pattern) displayName should not be empty")
        }
    }

    // MARK: - MuscleGroup

    @Test func muscleGroupBodyRegions() {
        #expect(MuscleGroup.chest.bodyRegion == .upper)
        #expect(MuscleGroup.biceps.bodyRegion == .arms)
        #expect(MuscleGroup.quads.bodyRegion == .lower)
        #expect(MuscleGroup.abs.bodyRegion == .core)
        #expect(MuscleGroup.neck.bodyRegion == .upper)
        #expect(MuscleGroup.glutes.bodyRegion == .lower)
        #expect(MuscleGroup.lats.bodyRegion == .upper)
        #expect(MuscleGroup.obliques.bodyRegion == .core)
        #expect(MuscleGroup.forearms.bodyRegion == .arms)
    }

    @Test func muscleGroupDisplayNamesNotEmpty() {
        for muscle in MuscleGroup.allCases {
            #expect(!muscle.displayName.isEmpty, "\(muscle) displayName should not be empty")
        }
    }

    @Test func allMuscleGroupsHaveBodyRegion() {
        for muscle in MuscleGroup.allCases {
            let region = muscle.bodyRegion
            #expect(BodyRegion.allCases.contains(region))
        }
    }

    // MARK: - SplitType

    @Test func splitTypeDaysPerWeek() {
        #expect(SplitType.ppl.daysPerWeek == 6)
        #expect(SplitType.upperLower.daysPerWeek == 4)
        #expect(SplitType.fullBody.daysPerWeek == 3)
        #expect(SplitType.broSplit.daysPerWeek == 5)
        #expect(SplitType.arnoldSplit.daysPerWeek == 6)
        #expect(SplitType.torsoLimbs.daysPerWeek == 4)
        #expect(SplitType.custom.daysPerWeek == nil)
        #expect(SplitType.none.daysPerWeek == nil)
    }

    @Test func splitTypeDisplayNamesNotEmpty() {
        for split in SplitType.allCases {
            #expect(!split.displayName.isEmpty, "\(split) displayName should not be empty")
        }
    }

    // MARK: - BodyRegion

    @Test func bodyRegionDisplayNamesNotEmpty() {
        for region in BodyRegion.allCases {
            #expect(!region.displayName.isEmpty, "\(region) displayName should not be empty")
        }
    }

    // MARK: - CalorieFormula

    @Test func calorieFormulaDisplayNamesNotEmpty() {
        for formula in CalorieFormula.allCases {
            #expect(!formula.displayName.isEmpty)
            #expect(!formula.description.isEmpty)
        }
    }

    // MARK: - WorkoutIntensity

    @Test func workoutIntensityMetValues() {
        #expect(WorkoutIntensity.light.metValue == 3.5)
        #expect(WorkoutIntensity.moderate.metValue == 5.0)
        #expect(WorkoutIntensity.vigorous.metValue == 6.0)
    }

    @Test func workoutIntensityDisplayNamesNotEmpty() {
        for intensity in WorkoutIntensity.allCases {
            #expect(!intensity.displayName.isEmpty)
        }
    }

    // MARK: - RestTimerMode & AlertType

    @Test func restTimerModeDisplayNamesNotEmpty() {
        for mode in RestTimerMode.allCases {
            #expect(!mode.displayName.isEmpty)
        }
    }

    @Test func alertTypeDisplayNamesNotEmpty() {
        for type in AlertType.allCases {
            #expect(!type.displayName.isEmpty)
        }
    }

    // MARK: - Social enums (raw values are the strings the security rules check)

    @Test func postAudienceRawValues() {
        #expect(PostAudience.allCases.map(\.rawValue) == ["everyone", "friends", "onlyMe"])
        #expect(PrivacyLevel.friendsOnly.audience == .friends)
        #expect(PrivacyLevel(audience: .friends) == .friendsOnly)
    }

    @Test func inviteStatusRawValues() {
        #expect(ChallengeInviteStatus.pending.rawValue == "pending")
        #expect(ChallengeInviteStatus.accepted.rawValue == "accepted")
        #expect(ChallengeInviteStatus.declined.rawValue == "declined")
    }
}
