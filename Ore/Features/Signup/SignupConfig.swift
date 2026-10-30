import Foundation

/// Every tunable of the sign-up console in one place: typing speed, the step list and its copy, validation ranges,
/// the star field, the background, the progress-bar glitter and the star bullets. The bundled
/// `Resources/signup.config.json` is the shared source (an Android build reads the same file); `fallback` must equal it
/// (a test checks). `SignupConfigStore` is the Remote Config hook (`signup_config`).
struct SignupConfig: Codable, Equatable {
    struct Step: Codable, Equatable {
        /// email, password, name, username, weight, height, age, choice
        var kind: String
        var key: String
        var label: String
        var prompt: String            // "{name}" is replaced by the first name
        var placeholder: String
        var prefix: String
        var suffix: String
        var units: [String]
        var choices: [Choice]
        /// The row height of the choice cards (0 = the default for the list length).
        var cardHeight: Double
        var uppercaseChoices: Bool
    }
    struct Choice: Codable, Equatable {
        var label: String
        var meta: String
        var value: String
    }
    struct Typing: Codable, Equatable {
        var msPerChar: Int
        var riseMs: Int
        var risePt: Double
        var choiceStaggerMs: Int
        var setupStartMs: Int
        var setupLineMs: Int
    }
    struct Validation: Codable, Equatable {
        var emailPattern: String
        var passwordMin: Int
        var passwordStrong: Int
        var usernameDebounceMs: Int
        var weightKg: [Double]
        var weightLb: [Double]
        var heightCm: [Double]
        var heightFt: [Int]
        var age: [Int]
    }
    struct Stars: Codable, Equatable {
        var count: Double             // per 390 × 844 pt
        var gold: Double
        var silver: Double
        var blue: Double              // the rest is white
        var goldRGB: [Double], silverRGB: [Double], blueRGB: [Double], whiteRGB: [Double]
        var flareGoldRGB: [Double], flareRGB: [Double]
        var sizeBase: Double, sizeGold: Double, sizeOther: Double
        var riseBase: Double, risePerW: Double, riseScale: Double
        var swayBase: Double, swayPerSize: Double, swaySpeed: Double
        var twinkleMin: Double, twinkleMax: Double
        var flickerSpeed: Double, flickerMin: Double
        var flashProb: Double, flashDecay: Double
        var flareMinSize: Double, flareThreshold: Double, flareArm: Double, flareFlashArm: Double, flareWidth: Double
        var visibleBase: Double, visibleCurve: Double
        var boostAnswer: Double, boostApple: Double, boostEmail: Double, boostDone: Double
        var boostDecay: Double, boostRise: Double, boostAlpha: Double
        var streakThreshold: Double, streakLength: Double, streakWidth: Double
        var levelEase: Double
        var fps: Int
    }
    struct Background: Codable, Equatable {
        var base: String
        var gradient: [String]        // three stops
        var glowA: String, glowB: String
        var glowRadius: Double
        var topGlowRGB: [Double]
        var topGlowAlpha: Double, topGlowMidAlpha: Double
        var topGlowRadiusBase: Double, topGlowRadiusPerLevel: Double
    }
    struct Bar: Codable, Equatable {
        var height: Double
        var specks: Int
        var goldShare: Double, silverShare: Double
        var sizeMin: Double, sizeMax: Double
        var speedMin: Double, speedMax: Double
        var boostSpeed: Double
        var flashProb: Double, flashDecay: Double
        var fillMs: Int
    }
    struct Bullet: Codable, Equatable {
        var logSize: Double, setupSize: Double, paywallSize: Double, choiceSize: Double
        var seconds: Double
        var scaleMin: Double, scaleMax: Double
        var rotateMax: Double
        var opacityMin: Double
        var logOffset: Double, setupOffset: Double, setupBase: Double, paywallOffset: Double
        var glowRadius: Double, glowAlpha: Double
    }

    var typing: Typing
    var steps: [Step]
    var validation: Validation
    var stars: Stars
    var background: Background
    var bar: Bar
    var bullet: Bullet

    static func load(from data: Data) -> SignupConfig? {
        guard let c = try? JSONDecoder().decode(SignupConfig.self, from: data), c.isUsable else { return nil }
        return c
    }

    /// A payload missing the fields the flow can't run without is ignored.
    var isUsable: Bool {
        !steps.isEmpty && background.gradient.count == 3 && stars.count > 0
            && validation.weightKg.count == 2 && validation.weightLb.count == 2 && validation.heightCm.count == 2
            && validation.heightFt.count == 2 && validation.age.count == 2
            && stars.goldRGB.count == 3 && stars.silverRGB.count == 3 && stars.blueRGB.count == 3 && stars.whiteRGB.count == 3
            && stars.flareGoldRGB.count == 3 && stars.flareRGB.count == 3 && background.topGlowRGB.count == 3
            && Self.requiredSteps.allSatisfy { key in steps.contains { $0.key == key } }
    }
}

extension SignupConfig {
    /// The flow reads these answers by key, so a remote step list must keep them.
    static let requiredSteps = ["email", "password", "name", "username", "weight", "height", "age", "gender", "exp", "split"]

    func step(_ key: String) -> Step? { steps.first { $0.key == key } }

    static let fallback: SignupConfig = {
        func choices(_ l: [(String, String, String)]) -> [Choice] { l.map { Choice(label: $0.0, meta: $0.1, value: $0.2) } }
        func step(_ kind: String, _ key: String, _ label: String, _ prompt: String, ph: String = "", prefix: String = "›",
                  suffix: String = "", units: [String] = [], choices: [Choice] = [], card: Double = 0, upper: Bool = false) -> Step {
            Step(kind: kind, key: key, label: label, prompt: prompt, placeholder: ph, prefix: prefix, suffix: suffix,
                 units: units, choices: choices, cardHeight: card, uppercaseChoices: upper)
        }
        return SignupConfig(
            typing: Typing(msPerChar: 32, riseMs: 250, risePt: 6, choiceStaggerMs: 60, setupStartMs: 350, setupLineMs: 650),
            steps: [
                step("email", "email", "EMAIL", "Enter your email.", ph: "you@example.com"),
                step("password", "password", "PASSWORD", "Create a password.", ph: "At least 8 characters"),
                step("name", "name", "NAME", "What should we call you?", ph: "First name"),
                step("username", "username", "USERNAME", "Pick your username.", ph: "casey.lifts", prefix: "@"),
                step("weight", "weight", "WEIGHT", "How much do you weigh, {name}?", ph: "0", units: ["KG", "LB"]),
                step("height", "height", "HEIGHT", "How tall are you?", ph: "0", units: ["CM", "FT / IN"]),
                step("age", "age", "AGE", "How old are you?", ph: "0", suffix: "YRS"),
                step("choice", "gender", "GENDER", "Which best describes you?", choices: choices([
                    ("Male", "", "male"), ("Female", "", "female"), ("Non-binary", "", "nonBinary"),
                    ("Other", "", "other"), ("Prefer not to say", "", "preferNotToSay"),
                ])),
                step("choice", "exp", "EXPERIENCE", "How long have you been lifting?", choices: choices([
                    ("New to lifting", "UNDER 1 YR", "beginner"), ("Some experience", "1–3 YRS", "intermediate"),
                    ("Advanced lifter", "3+ YRS", "experienced"),
                ])),
                step("choice", "split", "PROGRAM", "How do you structure your training?", choices: choices([
                    ("Push / Pull / Legs", "6 DAYS/WK", "ppl"), ("Upper / Lower", "4 DAYS/WK", "upperLower"),
                    ("Full Body", "3 DAYS/WK", "fullBody"), ("Bro Split", "5 DAYS/WK", "broSplit"),
                    ("Custom", "YOUR OWN", "custom"), ("No fixed split", "LOG FREELY", "none"),
                ]), upper: true),
            ],
            validation: Validation(emailPattern: "^[^@\\s]+@[^@\\s]+\\.[^@\\s]{2,}$", passwordMin: 8, passwordStrong: 12,
                                   usernameDebounceMs: 300, weightKg: [30, 300], weightLb: [66, 660], heightCm: [120, 230],
                                   heightFt: [4, 7], age: [13, 100]),
            stars: Stars(count: 420, gold: 0.35, silver: 0.35, blue: 0.2,
                         goldRGB: [255, 200, 61], silverRGB: [226, 232, 240], blueRGB: [210, 238, 255], whiteRGB: [255, 255, 255],
                         flareGoldRGB: [255, 214, 100], flareRGB: [235, 245, 255],
                         sizeBase: 0.5, sizeGold: 1.9, sizeOther: 1.5,
                         riseBase: 0.01, risePerW: 0.012, riseScale: 0.6,
                         swayBase: 3, swayPerSize: 2, swaySpeed: 0.0012,
                         twinkleMin: 0.002, twinkleMax: 0.007,
                         flickerSpeed: 0.02, flickerMin: 0.35,
                         flashProb: 0.002, flashDecay: 0.05,
                         flareMinSize: 1.1, flareThreshold: 0.85, flareArm: 4, flareFlashArm: 5, flareWidth: 0.7,
                         visibleBase: 0.25, visibleCurve: 0.75,
                         boostAnswer: 1, boostApple: 1, boostEmail: 0.6, boostDone: 1.6,
                         boostDecay: 0.94, boostRise: 0.5, boostAlpha: 0.3,
                         streakThreshold: 0.08, streakLength: 2.2, streakWidth: 0.8,
                         levelEase: 0.06, fps: 30),
            background: Background(base: "#1AA7FF", gradient: ["#1A7FE0", "#3DB8FF", "#9FDDFF"],
                                   glowA: "rgba(15,90,190,0.30)", glowB: "rgba(190,215,240,0.20)", glowRadius: 0.55,
                                   topGlowRGB: [190, 230, 255], topGlowAlpha: 0.26, topGlowMidAlpha: 0.07,
                                   topGlowRadiusBase: 0.7, topGlowRadiusPerLevel: 0.8),
            bar: Bar(height: 6, specks: 90, goldShare: 0.35, silverShare: 0.4, sizeMin: 0.35, sizeMax: 1.05,
                     speedMin: 0.006, speedMax: 0.026, boostSpeed: 6, flashProb: 0.004, flashDecay: 0.06, fillMs: 450),
            bullet: Bullet(logSize: 12, setupSize: 12, paywallSize: 14, choiceSize: 13, seconds: 2.6,
                           scaleMin: 0.82, scaleMax: 1.08, rotateMax: 8, opacityMin: 0.85,
                           logOffset: 0.37, setupOffset: 0.53, setupBase: 0.2, paywallOffset: 0.41,
                           glowRadius: 3, glowAlpha: 0.85)
        )
    }()
}

/// Where the live config comes from: the bundled JSON, then a remote override.
@MainActor
final class SignupConfigStore {
    static let shared = SignupConfigStore()
    private(set) var base: SignupConfig
    var override: SignupConfig?

    init(bundle: Bundle = .main) {
        if let url = bundle.url(forResource: "signup.config", withExtension: "json"),
           let data = try? Data(contentsOf: url), let config = SignupConfig.load(from: data) {
            base = config
        } else {
            base = .fallback
        }
    }

    var current: SignupConfig { override ?? base }

    /// Applies remote JSON; an invalid payload is ignored (the previous values stay).
    @discardableResult
    func applyRemote(json: Data) -> Bool {
        guard let config = SignupConfig.load(from: json) else { return false }
        override = config
        return true
    }
}
