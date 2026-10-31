import Foundation

/// Accessibility identifiers for the end-to-end UI tests (`OreUITests`).
///
/// This file is compiled into BOTH the app and the UI-test target (the test target cannot import app code),
/// so it must stay free of app types: strings and pure helpers only. Add the identifier here, attach it with
/// `.accessibilityIdentifier(AX.x.y)` on a stable control, and reference the same constant from the page objects.
/// Identifiers never change behaviour or layout; rename a constant and both sides follow.
enum AX {
    /// `row.edit-profile` — ledger rows (More hub, Settings) derive their id from the visible label.
    static func row(_ label: String) -> String { "row." + slug(label) }
    /// `menu.weight-unit` — menu rows (Settings pickers).
    static func menu(_ label: String) -> String { "menu." + slug(label) }
    /// Lowercase, alphanumerics joined by dashes: "Import / Export Data" -> "import-export-data".
    static func slug(_ text: String) -> String {
        text.lowercased()
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .joined(separator: "-")
    }

    /// The red trash button revealed by `SwipeToDeleteRow`.
    static let swipeDelete = "swipe.delete"

    enum nav {
        static let back = "nav.back"
        static func title(_ t: String) -> String { "nav.title." + slug(t) }
    }

    enum gate {
        static let splash = "splash"
        static let restoring = "restoring"
        static let message = "gateMessage"
    }

    enum auth {
        static let useEmail = "signInEmail"
        static let apple = "signInApple"
        static let google = "signInGoogle"
        static let error = "signInError"
        static let emailField = "emailField"
        static let passwordField = "passwordField"
        static let submit = "emailAuthSubmit"
        static let emailError = "emailAuthError"
        static let togglePassword = "emailAuth.togglePassword"
        static let modeSignIn = "emailAuth.modeSignIn"
        static let modeSignUp = "emailAuth.modeSignUp"
    }

    /// The sign-up console (`Features/Signup`). The opening buttons keep `auth.apple` / `auth.google` / `auth.useEmail`.
    enum signup {
        static let screen = "signup.screen"
        static let input = "signup.input"
        static let hint = "signup.hint"
        static let step = "signup.step"
        /// "03 / NAME": which question is open.
        static let number = "signup.number"
        static let next = "signup.continue"
        static let forgot = "signup.forgot"
        static let retry = "signup.retry"
        static let changeAnswer = "signup.change-answer"
        static let setupError = "signup.setupError"
        static let welcome = "signup.welcome"
        static func unit(_ raw: String) -> String { "signup.unit." + slug(raw) }
        static func choice(_ raw: String) -> String { "signup.choice." + slug(raw) }
        static func row(_ key: String) -> String { "signup.row." + key }
    }

    enum onboarding {
        static let next = "onboarding.next"
        static let back = "onboarding.back"
        static let stepCounter = "onboarding.step"
        static let nameField = "onboarding.name"
        static let handleField = "handleField"
        static let handleStatus = "handleStatus"
        static let weightField = "onboarding.weight"
        static let unitKg = "onboarding.unit.kg"
        static let unitLbs = "onboarding.unit.lbs"
        static let heightField = "onboarding.height"
        /// `unit` is "FT" or "IN".
        static func heightImperial(_ unit: String) -> String { "onboarding.height." + unit.lowercased() }
        static let ageField = "onboarding.age"
        static func gender(_ raw: String) -> String { "onboarding.gender." + slug(raw) }
        static func experience(_ raw: String) -> String { "onboarding.experience." + slug(raw) }
        static func split(_ raw: String) -> String { "onboarding.split." + slug(raw) }
        static let tutorialYes = "onboarding.tutorial.yes"
        static let tutorialSkip = "onboarding.tutorial.skip"
        static let tutorialStart = "onboarding.tutorial.start"
    }

    enum tab {
        static let programs = "tab.programs"
        static let social = "tab.social"
        static let home = "tab.home"
        static let body = "tab.body"
        static let more = "tab.more"
    }

    enum modal {
        /// Workout modal (confirm strip): right-hand button / left-hand button.
        static let primary = "modal.primary"
        static let secondary = "modal.secondary"
        /// Destructive modal.
        static let confirm = "modal.confirm"
        static let cancel = "modal.cancel"
    }

    enum home {
        static let profileButton = "home.profile"
        static let searchButton = "home.search"
        static let signOut = "home.signOut"
        static let profileCancel = "home.profileCancel"
        static let predictedName = "home.predictedName"
        static let notToday = "home.notToday"
        static let kpiStreak = "home.kpi.streak"
        static let kpiImproved = "home.kpi.improved"
        static let kpiPRs = "home.kpi.prs"
        static let kpiSets = "home.kpi.sets"
        static let recent = "home.recent"
        static func recentRow(_ i: Int) -> String { "home.recent.\(i)" }
        static let startWorkout = "home.startWorkout"
        static let continueDraft = "home.continueDraft"
        static let startNew = "home.startNew"
        static let ticker = "home.ticker"
    }

    enum workout {
        static let screen = "workout.screen"
        static let finish = "workout.finish"
        static let cancel = "workout.cancel"
        static let restPill = "workout.restPill"
        static let restTime = "workout.restTime"
        static let sessionTitle = "workout.sessionTitle"
        static let addExercise = "workout.addExercise"
        /// The + in the logger header: opens the full exercise list from anywhere in the workout.
        static let addExerciseTop = "workout.addExerciseTop"
        static let searchField = "workout.search.field"
        static let searchClose = "workout.search.close"
        /// A match among the exercises already in the workout (tapping it jumps to its card).
        static func searchInWorkoutRow(_ name: String) -> String { "workout.search.inWorkout." + slug(name) }
        static func exerciseName(_ i: Int) -> String { "workout.exercise.\(i).name" }
        static func addSet(_ i: Int) -> String { "workout.exercise.\(i).addSet" }
        /// `ex` is the 0-based exercise card, `n` the 1-based set number inside it.
        static func setWeight(ex: Int, _ n: Int) -> String { "workout.set.\(ex).\(n).weight" }
        static func setReps(ex: Int, _ n: Int) -> String { "workout.set.\(ex).\(n).reps" }
        static func setCheck(ex: Int, _ n: Int) -> String { "workout.set.\(ex).\(n).check" }
        static func setType(ex: Int, _ n: Int) -> String { "workout.set.\(ex).\(n).type" }
        static func setRIR(ex: Int, _ n: Int) -> String { "workout.set.\(ex).\(n).rir" }
        static func setNumber(ex: Int, _ n: Int) -> String { "workout.set.\(ex).\(n).number" }
        /// The "01" beside an exercise's name.
        static func exerciseNumber(_ i: Int) -> String { "workout.exercise.\(i).number" }
        /// A row in the set-type sheet, by its name ("Warmup", "Dropset", …).
        static func setTypeRow(_ name: String) -> String { "workout.setTypeRow." + slug(name) }
        static func rirToggle(_ i: Int) -> String { "workout.exercise.\(i).rirToggle" }
        static func platesToggle(ex: Int, _ n: Int) -> String { "workout.set.\(ex).\(n).plates" }
        static let restModal = "workout.restModal"
        static let restModalClose = "workout.restModal.close"
    }

    enum picker {
        static let search = "picker.search"
        static let back = "picker.back"
        static func row(_ displayName: String) -> String { "picker.row." + slug(displayName) }
        /// The (i) that opens an exercise's page, with ADD TO WORKOUT, from inside the add-exercise list.
        static func info(_ name: String) -> String { "picker.info." + slug(name) }
    }

    enum completion {
        static let title = "completion.title"
        static let cta = "completion.cta"
        static let menu = "completion.menu"
        static let caption = "completion.caption"
        static let back = "completion.back"
        static let dontPost = "completion.menu.dontPost"
        static let postToFeed = "completion.menu.postToFeed"
        static let postNoBodyMap = "completion.menu.postNoBodyMap"
    }

    enum history {
        static let screen = "history.screen"
        static let empty = "history.empty"
        static let modeList = "history.mode.list"
        static let modeCalendar = "history.mode.calendar"
        static let row = "history.row"
    }

    enum detail {
        static let menu = "workoutDetail.menu"
        static let done = "workoutDetail.done"
        static let title = "workoutDetail.title"
        /// Editable set rows (edit mode); `n` is the 1-based set number, the first exercise section is used.
        static func setWeight(_ n: Int) -> String { "workoutDetail.set.\(n).weight" }
        static func setReps(_ n: Int) -> String { "workoutDetail.set.\(n).reps" }
    }

    enum exercise {
        static let detailProgress = "exerciseDetail.progress"
        static let detailBack = "exerciseDetail.back"
        static let detailTabAbout = "exerciseDetail.tab.about"
        static let detailTabHistory = "exerciseDetail.tab.history"
        static let detailChart = "exerciseDetail.chart"
        /// ADD TO WORKOUT: only there when the page was opened from a workout.
        static let detailAdd = "exerciseDetail.add"
        static func detailRange(_ label: String) -> String { "exerciseDetail.range." + slug(label) }
        static func detailMetric(_ label: String) -> String { "exerciseDetail.metric." + slug(label) }
        static let search = "search.field"
        static func searchRow(_ name: String) -> String { "search.row." + slug(name) }
        static func searchPill(_ label: String) -> String { "search.pill." + slug(label) }
    }

    enum programs {
        static let screen = "programs.screen"
        static let add = "programs.add"
        static let newProgram = "programs.new"
        static let empty = "programs.empty"
        static func row(_ name: String) -> String { "programs.row." + slug(name) }
        static func swipeDelete(_ name: String) -> String { "programs.swipeDelete." + slug(name) }
        static let presetBlank = "programs.preset.blank"
        // Create
        static let createName = "programs.create.name"
        static func createDays(_ n: Int) -> String { "programs.create.days.\(n)" }
        static let createSave = "programs.create.save"
        static let createBack = "programs.create.back"
        static let createAddExercise = "programs.create.addExercise"
        // Detail
        static let detailEdit = "programs.detail.edit"
        static let detailDone = "programs.detail.done"
        static let detailStart = "programs.detail.start"
        static let detailBack = "programs.detail.back"
        static let detailAddExercise = "programs.detail.addExercise"
        static let detailTitle = "programs.detail.title"
    }

    enum body {
        static let screen = "body.screen"
        static let calendar = "body.calendar"
        static let prevWeek = "body.week.prev"
        static let nextWeek = "body.week.next"
        static let allWeek = "body.week.all"
        static func day(_ i: Int) -> String { "body.day.\(i)" }
        static let totalSets = "body.totalSets"
        static let figureFront = "body.figure.front"
        static let figureBack = "body.figure.back"
        static let muscleSheet = "body.muscleSheet"
        static let modeVolume = "body.mode.volume"
        static let modeRecency = "body.mode.recency"
    }

    enum more {
        static let screen = "more.screen"
        static let userName = "more.userName"
        static let signOutCancel = "more.signout.cancel"
        static let signOutConfirm = "more.signout.confirm"
    }

    enum settings {
        static let screen = "settings.screen"
        static let deleteConfirmField = "deleteConfirmField"
        static let deletePasswordField = "deletePasswordField"
        static let deleteError = "deleteError"
    }

    enum social {
        static let screen = "social.screen"
        static let tabFriends = "social.tab.friends"
        static let tabChallenges = "social.tab.challenges"
        static let bell = "social.activity"
        static let profile = "social.profile"
        static let post = "feed.post"
        static func postCard(_ handle: String) -> String { "feed.post." + slug(handle) }
        static let postMenu = "feed.post.menu"
        static let profileHandle = "social.profile.handle"
        /// `SocialPill`s derive their id from the title: pill.follow, pill.following, pill.unfollow ...
        static func pill(_ title: String) -> String { "pill." + slug(title) }
        static let challengeRow = "social.challenge.row"
        static let challengeJoin = "social.challenge.join"
        static let challengeView = "social.challenge.view"
        static let challengeName = "social.challenge.name"
    }

    enum widgets {
        static let gallery = "widgets.gallery"
    }

    enum supernova {
        static let paywall = "supernova.paywall"
        static let start = "supernova.start"
        static let free = "supernova.train-free"
        static let restore = "supernova.restore"
        static let banner = "supernova.banner"
        static let accentRow = "supernova.accent-row"
        static let memberCard = "supernova.member-card"
        static let memberPage = "supernova.member-page"
        static let memberBack = "supernova.member-back"
        static let memberEmptyHeadline = "supernova.member-empty-headline"
        static let stardustEnabled = "supernova.stardust-buttons"
        static func memberTab(_ name: String) -> String { "supernova.member-tab." + slug(name) }
        static let manageSubscription = "supernova.manage"
        static let cancelMembership = "supernova.cancel"
        static func accentSwatch(_ name: String) -> String { "supernova.accent." + slug(name) }   // a preset or recent swatch, by its hex without the "#"
        static let accentCurrent = "supernova.accent-current"
        static let accentAdjust = "supernova.accent-adjust"
        static let accentHex = "supernova.accent-hex"
        static func accentStrip(_ name: String) -> String { "supernova.accent-strip." + slug(name) }
        static func accentStep(_ name: String, _ direction: Int) -> String { "supernova.accent-step." + slug(name) + (direction < 0 ? ".minus" : ".plus") }
    }

    enum tutorial {
        static let card = "tutorial.card"
        static let next = "tutorial.next"
        static let skip = "tutorial.skip"
    }
}
