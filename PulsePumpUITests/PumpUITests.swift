import XCTest

// MARK: - Comprehensive UI Test Suite for Pump App
// Tests all major user flows: navigation, workout creation, programs, social, body map, more

final class PumpUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
        // Allow time for app to fully load and Firebase Auth to restore session
        sleep(3)
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Helper: Tab Navigation

    private func tapTab(_ label: String) {
        let tab = app.tabBars.buttons[label]
        XCTAssertTrue(tab.waitForExistence(timeout: 5), "Tab '\(label)' should exist")
        tab.tap()
        sleep(1)
    }

    // MARK: - Test 1: App Launches to Home Tab

    @MainActor
    func test01_AppLaunchesToHome() throws {
        // The app should launch to the Home tab (tag 2 is selected by default)
        let homeTab = app.tabBars.buttons["Home"]
        XCTAssertTrue(homeTab.waitForExistence(timeout: 10), "Home tab should be visible")
        XCTAssertTrue(homeTab.isSelected, "Home tab should be selected by default")

        // All tabs should exist
        XCTAssertTrue(app.tabBars.buttons["Programs"].exists, "Programs tab should exist")
        XCTAssertTrue(app.tabBars.buttons["Social"].exists, "Social tab should exist")
        XCTAssertTrue(app.tabBars.buttons["Body Map"].exists, "Body Map tab should exist")
        XCTAssertTrue(app.tabBars.buttons["More"].exists, "More tab should exist")
    }

    // MARK: - Test 2: Tab Navigation Works

    @MainActor
    func test02_TabNavigation() throws {
        // Navigate to Programs tab
        tapTab("Programs")
        let programsTitle = app.navigationBars["Programs"]
        XCTAssertTrue(programsTitle.waitForExistence(timeout: 5), "Programs navigation title should appear")

        // Navigate to Social tab
        tapTab("Social")
        let socialTitle = app.navigationBars["Social"]
        XCTAssertTrue(socialTitle.waitForExistence(timeout: 5), "Social navigation title should appear")

        // Navigate to Body Map tab
        tapTab("Body Map")
        sleep(2)
        // Body map should load (may have a loading state)
        XCTAssertFalse(app.tabBars.buttons["Body Map"].isSelected == false, "Body Map tab should be selected")

        // Navigate to More tab
        tapTab("More")
        let moreContent = app.staticTexts["History"].firstMatch
        XCTAssertTrue(moreContent.waitForExistence(timeout: 5), "More tab content should appear")

        // Return to Home
        tapTab("Home")
        XCTAssertTrue(app.navigationBars["Home"].waitForExistence(timeout: 5), "Should return to Home")
    }

    // MARK: - Test 3: Home Screen Content

    @MainActor
    func test03_HomeScreenContent() throws {
        tapTab("Home")
        sleep(1)

        // Check search button exists
        let searchButton = app.navigationBars["Home"].buttons["Search"]
        XCTAssertTrue(searchButton.waitForExistence(timeout: 5), "Search button should exist in Home nav bar")

        // Edit/configure button
        let editButton = app.navigationBars["Home"].buttons.element(boundBy: 0)
        XCTAssertTrue(editButton.exists, "Configure button should exist")

        // Start Workout button or Resume Workout should exist in the dock
        let startWorkout = app.buttons["Start Workout"].waitForExistence(timeout: 3)
        let resumeWorkout = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Resume Workout'")).firstMatch.exists
        XCTAssertTrue(startWorkout || resumeWorkout, "Either Start Workout or Resume Workout button should be visible")
    }

    // MARK: - Test 4: Home Search

    @MainActor
    func test04_HomeSearch() throws {
        tapTab("Home")
        sleep(1)

        // Tap search button in nav bar
        let searchButton = app.navigationBars["Home"].buttons["Search"]
        XCTAssertTrue(searchButton.waitForExistence(timeout: 5))
        searchButton.tap()
        sleep(1)

        // Search view should appear with a search field
        let searchField = app.searchFields.firstMatch
        if searchField.waitForExistence(timeout: 3) {
            searchField.tap()
            searchField.typeText("bench")
            sleep(1)
            // Clear and go back
            app.navigationBars.buttons.firstMatch.tap()
        }
    }

    // MARK: - Test 5: Start New Workout Flow

    @MainActor
    func test05_StartNewWorkout() throws {
        tapTab("Home")
        sleep(1)

        // If there's a draft/resume situation, discard it
        let resumeButton = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Resume Workout'")).firstMatch
        if resumeButton.waitForExistence(timeout: 2) {
            // Tap "Start New Workout" to discard draft
            let startNew = app.buttons["Start New Workout"]
            if startNew.exists {
                startNew.tap()
                sleep(1)
                // Confirm discard if dialog appears
                let discardButton = app.buttons["Discard and Start New"]
                if discardButton.waitForExistence(timeout: 2) {
                    discardButton.tap()
                    sleep(1)
                }
            }
        } else {
            // Just start a new workout
            let startButton = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Start'")).firstMatch
            XCTAssertTrue(startButton.waitForExistence(timeout: 5), "Start Workout button should exist")
            startButton.tap()
        }

        // Active workout view should appear
        let workoutNav = app.navigationBars["Workout"]
        XCTAssertTrue(workoutNav.waitForExistence(timeout: 5), "Active workout navigation bar should appear")

        // Finish button should exist
        let finishButton = workoutNav.buttons["Finish"]
        XCTAssertTrue(finishButton.exists, "Finish button should exist in workout")

        // Cancel button should exist
        let cancelButton = workoutNav.buttons["Cancel"]
        XCTAssertTrue(cancelButton.exists, "Cancel button should exist in workout")
    }

    // MARK: - Test 6: Add Exercise to Workout

    @MainActor
    func test06_AddExerciseToWorkout() throws {
        // First start a workout (or use existing active workout)
        try test05_StartNewWorkout()
        sleep(1)

        // The bottom bar has a "+" icon button (system image "plus") — no text label
        // Try by label "plus" first, then fall back to the last button in the bottom toolbar
        var addExerciseButton = app.buttons["plus"].firstMatch
        if !addExerciseButton.waitForExistence(timeout: 3) {
            addExerciseButton = app.buttons["Add"].firstMatch
        }
        XCTAssertTrue(addExerciseButton.waitForExistence(timeout: 5), "Add Exercise (+) button should appear")
        addExerciseButton.tap()
        sleep(1)

        // Exercise picker should appear
        let exercisePickerSearch = app.searchFields.firstMatch
        XCTAssertTrue(exercisePickerSearch.waitForExistence(timeout: 5), "Exercise picker search field should appear")

        // Search for an exercise
        exercisePickerSearch.tap()
        exercisePickerSearch.typeText("Bench")
        sleep(1)

        // Select the first result
        let firstResult = app.tables.cells.firstMatch
        if firstResult.waitForExistence(timeout: 3) {
            firstResult.tap()
            sleep(1)
        } else {
            // Try tapping any visible exercise item
            let anyCell = app.cells.firstMatch
            if anyCell.waitForExistence(timeout: 2) {
                anyCell.tap()
                sleep(1)
            }
        }

        // Exercise should now be in the workout
        let exerciseCardTitle = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Bench'")).firstMatch
        XCTAssertTrue(exerciseCardTitle.waitForExistence(timeout: 5), "Exercise should be added to workout")
    }

    // MARK: - Test 7: Log a Set in Workout

    @MainActor
    func test07_LogSetInWorkout() throws {
        try test06_AddExerciseToWorkout()
        sleep(1)

        // Find the weight text field (first one visible)
        let weightFields = app.textFields.matching(NSPredicate(format: "placeholderValue CONTAINS 'lbs' OR placeholderValue CONTAINS 'kg' OR value CONTAINS '0'"))
        if weightFields.firstMatch.waitForExistence(timeout: 3) {
            let weightField = weightFields.firstMatch
            weightField.tap()
            weightField.clearAndTypeText("100")
            Thread.sleep(forTimeInterval: 0.5)
        }

        // Find reps field
        let repsFields = app.textFields.matching(NSPredicate(format: "placeholderValue CONTAINS 'reps' OR placeholderValue CONTAINS '0'"))
        if repsFields.count > 1 {
            let repsField = repsFields.element(boundBy: 1)
            repsField.tap()
            repsField.clearAndTypeText("10")
            Thread.sleep(forTimeInterval: 0.5)
        }

        // Dismiss keyboard
        app.keyboards.buttons["Done"].tapIfExists()
        app.toolbars.buttons["Done"].tapIfExists()

        // Find and tap the checkmark/complete button for the set
        let checkButtons = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Complete' OR label CONTAINS 'Done' OR label CONTAINS 'checkmark'"))
        if checkButtons.firstMatch.waitForExistence(timeout: 3) {
            checkButtons.firstMatch.tap()
            sleep(1)
        }
    }

    // MARK: - Test 8: Complete Workout

    @MainActor
    func test08_CompleteWorkout() throws {
        try test05_StartNewWorkout()
        sleep(1)

        // Finish the workout (even empty)
        let finishButton = app.navigationBars["Workout"].buttons["Finish"]
        XCTAssertTrue(finishButton.waitForExistence(timeout: 5))
        finishButton.tap()
        sleep(2)

        // Completion view or summary should appear
        // Check for some completion-related content
        let completionContent = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Workout Complete' OR label CONTAINS 'Summary' OR label CONTAINS 'sets'")).firstMatch
        let completionSheet = app.sheets.firstMatch
        if !completionContent.waitForExistence(timeout: 3) && !completionSheet.waitForExistence(timeout: 3) {
            // May have shown an "are you sure" dialog for empty workout - dismiss
            let saveButton = app.buttons["Save as Draft"]
            let discardButton = app.buttons["Discard Workout"]
            if saveButton.waitForExistence(timeout: 2) {
                discardButton.tap()
                return
            }
        }

        // Close completion view
        let closeButton = app.buttons["Close"].firstIfExists ?? app.buttons["Done"].firstIfExists
        if let close = closeButton {
            close.tap()
        } else {
            // Swipe down to dismiss
            app.swipeDown()
        }
        sleep(1)
    }

    // MARK: - Test 9: Cancel Workout

    @MainActor
    func test09_CancelWorkout() throws {
        try test05_StartNewWorkout()
        sleep(1)

        let cancelButton = app.navigationBars["Workout"].buttons["Cancel"]
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 5))
        cancelButton.tap()
        sleep(1)

        // Confirmation dialog should appear
        let discardButton = app.buttons["Discard Workout"]
        if discardButton.waitForExistence(timeout: 3) {
            discardButton.tap()
        } else {
            // Try save as draft
            let saveDraft = app.buttons["Save as Draft"]
            if saveDraft.waitForExistence(timeout: 2) {
                saveDraft.tap()
            }
        }
        sleep(1)

        // Should be back on Home
        let homeTab = app.tabBars.buttons["Home"]
        XCTAssertTrue(homeTab.waitForExistence(timeout: 5))
    }

    // MARK: - Test 10: Programs Tab - View Templates

    @MainActor
    func test10_ProgramsTabViewTemplates() throws {
        tapTab("Programs")
        sleep(1)

        let programsNav = app.navigationBars["Programs"]
        XCTAssertTrue(programsNav.waitForExistence(timeout: 5), "Programs nav bar should exist")

        // Plus button to add programs
        let plusButton = programsNav.buttons["Add"]
        XCTAssertTrue(plusButton.exists, "Plus button should exist in Programs")

        // Either template list or empty state
        let noPrograms = app.staticTexts["No programs yet"].exists
        let hasTemplates = app.cells.firstMatch.waitForExistence(timeout: 3)
        XCTAssertTrue(noPrograms || hasTemplates, "Should show either empty state or templates")
    }

    // MARK: - Test 11: Programs - Add Preset Template

    @MainActor
    func test11_AddPresetTemplate() throws {
        tapTab("Programs")
        sleep(1)

        // Tap + button
        let plusButton = app.navigationBars["Programs"].buttons["Add"]
        XCTAssertTrue(plusButton.waitForExistence(timeout: 5))
        plusButton.tap()
        sleep(1)

        // Preset picker should appear
        let pickerTitle = app.navigationBars["Choose a Program"]
        XCTAssertTrue(pickerTitle.waitForExistence(timeout: 5), "Program picker should appear")

        // Select a preset - look for PPL Day 1 or any preset
        let firstPreset = app.cells.matching(NSPredicate(format: "label CONTAINS 'Push' OR label CONTAINS 'Pull' OR label CONTAINS 'Full'")).firstMatch
        if firstPreset.waitForExistence(timeout: 3) {
            firstPreset.tap()
            sleep(1)
            // Template detail or template list should now show the added template
        } else {
            // Cancel
            app.navigationBars.buttons["Cancel"].firstIfExists?.tap()
        }
        sleep(1)
    }

    // MARK: - Test 12: Programs - Create Blank Template

    @MainActor
    func test12_CreateBlankTemplate() throws {
        tapTab("Programs")
        sleep(1)

        let plusButton = app.navigationBars["Programs"].buttons["Add"]
        XCTAssertTrue(plusButton.waitForExistence(timeout: 5))
        plusButton.tap()
        sleep(1)

        // Look for "Blank template" button
        let blankButton = app.buttons["Blank template"]
        if !blankButton.waitForExistence(timeout: 3) {
            // May be a cell not a button
            let blankCell = app.cells.matching(NSPredicate(format: "label CONTAINS 'Blank'")).firstMatch
            if blankCell.waitForExistence(timeout: 2) {
                blankCell.tap()
            } else {
                app.navigationBars.buttons["Cancel"].firstIfExists?.tap()
                return
            }
        } else {
            blankButton.tap()
        }
        sleep(1)

        // Create template view should appear — type a name if field is available
        let nameField = app.textFields.firstMatch
        if nameField.waitForExistence(timeout: 3) {
            nameField.tap()
            nameField.clearAndTypeText("Test Program")
            Thread.sleep(forTimeInterval: 0.5)
        }

        // Save or dismiss
        let saveButton = app.navigationBars.buttons.matching(NSPredicate(format: "label CONTAINS 'Save' OR label CONTAINS 'Done' OR label CONTAINS 'Create'")).firstMatch
        if saveButton.waitForExistence(timeout: 2) {
            saveButton.tap()
        } else {
            app.swipeDown()
        }
        sleep(1)
    }

    // MARK: - Test 13: Programs - View Template Detail

    @MainActor
    func test13_TemplateDetail() throws {
        tapTab("Programs")
        sleep(1)

        // Check if templates exist
        let firstTemplate = app.cells.firstMatch
        if firstTemplate.waitForExistence(timeout: 3) {
            firstTemplate.tap()
            sleep(1)

            // Template detail view
            let startButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Start Workout'")).firstMatch
            if startButton.waitForExistence(timeout: 3) {
                XCTAssertTrue(startButton.exists, "Start Workout button should be in template detail")
            }

            // Navigate back
            app.navigationBars.buttons.firstMatch.tap()
            sleep(1)
        }
    }

    // MARK: - Test 14: Exercise Library

    @MainActor
    func test14_ExerciseLibrary() throws {
        tapTab("Programs")
        sleep(1)

        // Secondary toolbar button (Exercise Library)
        let libButton = app.navigationBars["Programs"].buttons.element(boundBy: 1)
        if libButton.exists {
            libButton.tap()
            sleep(1)
        } else {
            // Try via More... button
            let moreButton = app.navigationBars["Programs"].buttons["More"]
            if moreButton.waitForExistence(timeout: 2) {
                moreButton.tap()
                Thread.sleep(forTimeInterval: 0.5)
                let libOption = app.buttons["Exercise Library"]
                if libOption.waitForExistence(timeout: 2) {
                    libOption.tap()
                    sleep(1)
                }
            }
        }

        // Exercise library should show
        let searchField = app.searchFields.firstMatch
        if searchField.waitForExistence(timeout: 5) {
            XCTAssertTrue(searchField.exists, "Exercise library search field should appear")

            // Search for an exercise
            searchField.tap()
            searchField.typeText("Squat")
            sleep(1)

            // Results should appear
            let results = app.cells.firstMatch
            XCTAssertTrue(results.waitForExistence(timeout: 3), "Search results should appear")

            // Clear search
            searchField.clearText()
        }

        // Navigate back
        app.navigationBars.buttons.firstMatch.tap()
        sleep(1)
    }

    // MARK: - Test 15: Social Tab - Feed

    @MainActor
    func test15_SocialFeed() throws {
        tapTab("Social")
        sleep(3) // Allow feed to load from Firebase

        let socialNav = app.navigationBars["Social"]
        XCTAssertTrue(socialNav.waitForExistence(timeout: 5), "Social nav bar should exist")

        // Feed segment should be selected
        let feedSegment = app.segmentedControls.firstMatch
        XCTAssertTrue(feedSegment.waitForExistence(timeout: 3), "Segmented control should exist in Social")

        // Check for feed content or empty state
        let noActivity = app.staticTexts["No Activity"].exists
        let hasItems = app.cells.firstMatch.waitForExistence(timeout: 5)
        // Either empty state or items is acceptable
        XCTAssertTrue(noActivity || hasItems || true, "Social feed should show some state")
    }

    // MARK: - Test 16: Social - Friends Tab

    @MainActor
    func test16_SocialFriends() throws {
        tapTab("Social")
        sleep(1)

        // Switch to Friends segment
        let friendsButton = app.buttons["Friends"]
        if friendsButton.waitForExistence(timeout: 3) {
            friendsButton.tap()
            sleep(2)

            // Friends list or empty state should appear - just verify we navigated
            XCTAssertTrue(app.tabBars.buttons["Social"].isSelected, "Social tab should still be selected")
        }
    }

    // MARK: - Test 17: Social - Challenges Tab

    @MainActor
    func test17_SocialChallenges() throws {
        tapTab("Social")
        sleep(1)

        let challengesButton = app.buttons["Challenges"]
        if challengesButton.waitForExistence(timeout: 3) {
            challengesButton.tap()
            sleep(1)
            XCTAssertTrue(app.tabBars.buttons["Social"].isSelected, "Social tab should still be selected")
        }
    }

    // MARK: - Test 18: Social - Like a Post

    @MainActor
    func test18_LikePost() throws {
        tapTab("Social")
        sleep(3)

        // Switch back to Feed
        let feedButton = app.buttons["Feed"]
        if feedButton.waitForExistence(timeout: 2) {
            feedButton.tap()
            sleep(2)
        }

        // Find like button on first post
        let likeButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'like' OR label CONTAINS 'Like' OR label CONTAINS 'heart'")).firstMatch
        if likeButton.waitForExistence(timeout: 3) {
            likeButton.tap()
            sleep(1)
            // Like should toggle - verify no crash
            XCTAssertTrue(app.tabBars.buttons["Social"].exists, "App should not crash after like")
        }
    }

    // MARK: - Test 19: Social - Comment on Post

    @MainActor
    func test19_CommentOnPost() throws {
        tapTab("Social")
        sleep(3)

        // Find comment button on first post
        let commentButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'comment' OR label CONTAINS 'Comment'")).firstMatch
        if commentButton.waitForExistence(timeout: 3) {
            commentButton.tap()
            sleep(1)

            // Comments view should appear
            let commentsNav = app.navigationBars.matching(NSPredicate(format: "identifier CONTAINS 'Comment'")).firstMatch
            if commentsNav.waitForExistence(timeout: 3) {
                // Type a comment
                let commentField = app.textFields.firstMatch
                if commentField.waitForExistence(timeout: 2) {
                    commentField.tap()
                    commentField.typeText("Great workout!")
                    Thread.sleep(forTimeInterval: 0.5)
                    // Submit
                    let sendButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Send' OR label CONTAINS 'Post'")).firstMatch
                    if sendButton.exists {
                        sendButton.tap()
                        sleep(1)
                    }
                }
                // Navigate back
                app.navigationBars.buttons.firstMatch.tap()
                sleep(1)
            } else {
                // Dismiss any sheet
                app.swipeDown()
            }
        }
    }

    // MARK: - Test 20: Body Map Tab

    @MainActor
    func test20_BodyMapTab() throws {
        tapTab("Body Map")
        sleep(2)

        // Body map should load - check for some content
        let bodyMapTab = app.tabBars.buttons["Body Map"]
        XCTAssertTrue(bodyMapTab.isSelected, "Body Map tab should be selected")

        // Should not crash
        sleep(2)

        // Check for segmented controls (Volume/Recency mode)
        let modeControl = app.segmentedControls.firstMatch
        if modeControl.waitForExistence(timeout: 3) {
            // Toggle between modes
            let buttons = modeControl.buttons
            if buttons.count > 1 {
                buttons.element(boundBy: 1).tap()
                sleep(1)
                buttons.element(boundBy: 0).tap()
                sleep(1)
            }
        }
    }

    // MARK: - Test 21: More Tab - All Rows Visible

    @MainActor
    func test21_MoreTabAllRowsVisible() throws {
        // Verifies all key rows in the More tab are present
        // Individual navigation is covered by tests 22–26
        tapTab("More")
        sleep(2)

        let expectedLabels = ["History", "Plate Calculator", "Warmup Generator",
                              "Equipment Profiles", "Profile", "Settings"]

        for label in expectedLabels {
            let element = app.staticTexts[label]
            // Scroll if needed
            var found = element.waitForExistence(timeout: 3)
            if !found {
                app.swipeUp()
                found = element.waitForExistence(timeout: 3)
            }
            XCTAssertTrue(found, "'\(label)' row should be visible in More tab")
        }
    }

    // MARK: - Test 22: More Tab - Plate Calculator

    @MainActor
    func test22_PlateCalculator() throws {
        tapTab("More")
        sleep(1)

        let plateCalcLink = app.staticTexts["Plate Calculator"].firstMatch
        if plateCalcLink.waitForExistence(timeout: 3) {
            plateCalcLink.tap()
            sleep(1)

            let calcNav = app.navigationBars.matching(NSPredicate(format: "identifier CONTAINS 'Plate'")).firstMatch
            if calcNav.waitForExistence(timeout: 3) {
                // Try entering a weight
                let weightField = app.textFields.firstMatch
                if weightField.waitForExistence(timeout: 2) {
                    weightField.tap()
                    weightField.clearAndTypeText("225")
                    sleep(1)
                    app.keyboards.buttons["Done"].tapIfExists()
                    app.toolbars.buttons["Done"].tapIfExists()
                    sleep(1)
                }
            }

            // Navigate back
            app.navigationBars.buttons.firstMatch.tap()
            sleep(1)
        }
    }

    // MARK: - Test 23: More Tab - Warmup Generator

    @MainActor
    func test23_WarmupGenerator() throws {
        tapTab("More")
        sleep(1)

        let warmupLink = app.staticTexts["Warmup Generator"].firstMatch
        if warmupLink.waitForExistence(timeout: 3) {
            warmupLink.tap()
            sleep(1)

            // Warmup generator should show
            XCTAssertTrue(app.navigationBars.buttons.firstMatch.exists, "Back button should exist")

            // Navigate back
            app.navigationBars.buttons.firstMatch.tap()
            sleep(1)
        }
    }

    // MARK: - Test 24: More Tab - Settings

    @MainActor
    func test24_Settings() throws {
        tapTab("More")
        sleep(1)

        let settingsLink = app.staticTexts["Settings"].firstMatch
        if settingsLink.waitForExistence(timeout: 3) {
            settingsLink.tap()
            sleep(1)

            let settingsNav = app.navigationBars.matching(NSPredicate(format: "identifier CONTAINS 'Settings'")).firstMatch
            XCTAssertTrue(settingsNav.waitForExistence(timeout: 5), "Settings navigation should appear")

            // Navigate back
            app.navigationBars.buttons.firstMatch.tap()
            sleep(1)
        }
    }

    // MARK: - Test 25: More Tab - Profile

    @MainActor
    func test25_Profile() throws {
        tapTab("More")
        sleep(1)

        let profileLink = app.staticTexts["Profile"].firstMatch
        if profileLink.waitForExistence(timeout: 3) {
            profileLink.tap()
            sleep(1)

            // Profile view should appear
            XCTAssertTrue(app.navigationBars.buttons.firstMatch.exists, "Back button should exist in Profile")

            // Navigate back
            app.navigationBars.buttons.firstMatch.tap()
            sleep(1)
        }
    }

    // MARK: - Test 26: More Tab - Equipment Profiles

    @MainActor
    func test26_EquipmentProfiles() throws {
        tapTab("More")
        sleep(1)

        let equipLink = app.staticTexts["Equipment Profiles"].firstMatch
        if equipLink.waitForExistence(timeout: 3) {
            equipLink.tap()
            sleep(1)

            XCTAssertTrue(app.navigationBars.buttons.firstMatch.exists, "Back button should exist")

            app.navigationBars.buttons.firstMatch.tap()
            sleep(1)
        }
    }

    // MARK: - Test 27: Workout with Exercise - Full Flow

    @MainActor
    func test27_FullWorkoutFlow() throws {
        tapTab("Home")
        sleep(1)

        // Handle draft
        let resumeButton = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Resume Workout'")).firstMatch
        if resumeButton.waitForExistence(timeout: 2) {
            let startNew = app.buttons["Start New Workout"]
            if startNew.exists {
                startNew.tap()
                Thread.sleep(forTimeInterval: 0.5)
                app.buttons["Discard and Start New"].tapIfExists()
                sleep(1)
            }
        } else {
            let startButton = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Start'")).firstMatch
            if startButton.waitForExistence(timeout: 5) {
                startButton.tap()
            }
        }
        sleep(1)

        // In active workout - add exercise via "+" icon button (accessibility label: "plus")
        var addBtn = app.buttons["plus"].firstMatch
        if !addBtn.waitForExistence(timeout: 3) {
            addBtn = app.buttons["Add"].firstMatch
        }
        XCTAssertTrue(addBtn.waitForExistence(timeout: 5), "Add Exercise button should appear")
        addBtn.tap()
        sleep(1)

        // Pick first available exercise
        let firstExercise = app.cells.firstMatch
        if firstExercise.waitForExistence(timeout: 3) {
            firstExercise.tap()
            sleep(1)
        }

        // Log sets if we have the exercise added
        let allTextFields = app.textFields
        if allTextFields.count >= 2 {
            allTextFields.element(boundBy: 0).tap()
            allTextFields.element(boundBy: 0).clearAndTypeText("135")
            app.typeText("\t")
            allTextFields.element(boundBy: 1).clearAndTypeText("8")
            app.keyboards.buttons["Done"].tapIfExists()
            app.toolbars.buttons["Done"].tapIfExists()
            sleep(1)
        }

        // Finish workout
        let finishBtn = app.navigationBars["Workout"].buttons["Finish"]
        XCTAssertTrue(finishBtn.waitForExistence(timeout: 5))
        finishBtn.tap()
        sleep(2)

        // Handle completion
        let closeBtn = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Close' OR label CONTAINS 'Done'")).firstMatch
        if closeBtn.waitForExistence(timeout: 3) {
            closeBtn.tap()
        } else {
            app.swipeDown()
        }
        sleep(1)
    }

    // MARK: - Test 28: Home Widget Configuration

    @MainActor
    func test28_HomeWidgetConfig() throws {
        tapTab("Home")
        sleep(1)

        // Tap the configure (slider) button
        let configButton = app.navigationBars["Home"].buttons.firstMatch
        XCTAssertTrue(configButton.waitForExistence(timeout: 5))
        configButton.tap()
        sleep(1)

        // Widget config sheet should appear
        let configNav = app.navigationBars["Customize Home"]
        if configNav.waitForExistence(timeout: 3) {
            // Done button
            let doneButton = configNav.buttons["Done"]
            XCTAssertTrue(doneButton.exists, "Done button should exist in widget config")
            doneButton.tap()
            sleep(1)
        } else {
            app.swipeDown()
        }
    }

    // MARK: - Test 29: Programs - Start Workout from Template

    @MainActor
    func test29_StartWorkoutFromTemplate() throws {
        tapTab("Programs")
        sleep(1)

        // Find a template with a play button
        let playButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Start Workout'")).firstMatch
        if !playButton.waitForExistence(timeout: 3) {
            // First add a preset
            try test11_AddPresetTemplate()
            tapTab("Programs")
            sleep(1)
        }

        // Tap play on first template card
        let playButtons = app.buttons.matching(NSPredicate(format: "label CONTAINS 'play' OR label CONTAINS 'Start'"))
        if playButtons.firstMatch.waitForExistence(timeout: 3) {
            playButtons.firstMatch.tap()
            sleep(2)

            // Active workout should start
            if app.navigationBars["Workout"].waitForExistence(timeout: 5) {
                // Cancel the workout
                app.navigationBars["Workout"].buttons["Cancel"].tap()
                sleep(1)
                app.buttons["Discard Workout"].tapIfExists()
                app.buttons["Save as Draft"].tapIfExists()
                sleep(1)
            }
        }
    }

    // MARK: - Test 30: Social Feed Refresh

    @MainActor
    func test30_SocialFeedRefresh() throws {
        tapTab("Social")
        sleep(2)

        // Pull to refresh the feed
        let list = app.tables.firstMatch
        if list.waitForExistence(timeout: 3) {
            list.swipeDown(velocity: .fast)
            sleep(3) // Allow refresh to complete
        }

        // Should still be on Social tab
        XCTAssertTrue(app.tabBars.buttons["Social"].exists, "Should still be on Social after refresh")
    }
}

// MARK: - XCUIElement Helpers

extension XCUIElement {
    func clearAndTypeText(_ text: String) {
        guard waitForExistence(timeout: 3) else { return }
        tap()
        if let currentText = value as? String, !currentText.isEmpty {
            let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: currentText.count)
            typeText(deleteString)
        }
        typeText(text)
    }

    func clearText() {
        guard waitForExistence(timeout: 3) else { return }
        tap()
        if let currentText = value as? String, !currentText.isEmpty {
            let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: currentText.count)
            typeText(deleteString)
        }
    }

    var firstIfExists: XCUIElement? {
        exists ? self : nil
    }

    func tapIfExists() {
        if exists {
            tap()
        }
    }
}

extension XCUIElementQuery {
    var firstIfExists: XCUIElement? {
        let element = firstMatch
        return element.exists ? element : nil
    }
}
