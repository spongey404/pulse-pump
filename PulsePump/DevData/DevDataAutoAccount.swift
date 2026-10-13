#if DEBUG
import Foundation
import SwiftData
import FirebaseAuth

/// DEBUG-only: signs in (or signs up) with an email account and completes onboarding from launch arguments, so a
/// live or emulator smoke test needs no taps. Compiled out of Release.
///
///   -debugEmail me@example.com -debugPassword secret123 -debugAutoOnboard 1 [-createDevData 1]
@MainActor
enum DevDataAutoAccount {
    static var credentials: (email: String, password: String)? {
        let d = UserDefaults.standard
        guard let email = d.string(forKey: "debugEmail"), let password = d.string(forKey: "debugPassword"),
              !email.isEmpty, !password.isEmpty else { return nil }
        return (email, password)
    }

    static var autoOnboard: Bool { UserDefaults.standard.bool(forKey: "debugAutoOnboard") }

    static func log(_ message: String) { print("[DevDataAutoAccount] \(message)") }

    /// `-debugFreshSession 1`: drop the login (simulator keychain) and the SwiftData store an earlier launch left
    /// behind, before any view exists, so UI tests always start from a known account. A relaunch without the flag
    /// keeps both. Runs synchronously from `PulsePumpApp.init`.
    static func resetStaleSession() {
        guard UserDefaults.standard.bool(forKey: "debugFreshSession") else { return }
        try? Auth.auth().signOut()
        let fm = FileManager.default
        // SwiftData's default store lives in the App Group container (shared with the widget extension).
        var roots = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        if let group = fm.containerURL(forSecurityApplicationGroupIdentifier: "group.com.pulse.PulsePump") {
            roots.append(group.appendingPathComponent("Library/Application Support"))
        }
        for root in roots {
            for url in (try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? []
            where url.lastPathComponent.hasPrefix("default.store") { try? fm.removeItem(at: url) }
        }
        log("fresh session: signed out and cleared the local store")
    }

    /// Sign in; when the account does not exist yet, create it.
    static func signIn(session: AuthSession) async {
        guard let c = credentials, session.state == .signedOut else { return }
        if await session.signInWithEmail(c.email, password: c.password) {
            log("signed in \(c.email)")
        } else if await session.signUp(email: c.email, password: c.password) {
            log("created and signed in \(c.email)")
        } else {
            log("sign-in failed: \(session.errorMessage ?? "unknown")")
        }
    }

    /// Fill the onboarding form with fixed values and submit it (cloud profile + username + local user).
    static func onboard(session: AuthSession, gate: AccountGate, modelContext: ModelContext) async {
        guard autoOnboard, let uid = session.user?.uid else { return }
        let vm = OnboardingViewModel(uid: uid, prefilledName: "Smoke Tester", remote: gate.remote)
        vm.name = "Smoke Tester"
        vm.weightText = "80"; vm.heightText = "180"; vm.ageText = "30"
        vm.experienceLevel = .intermediate
        vm.selectedSplitType = .pushPullLegs
        await vm.handleInput.prefill("smoke_" + String(uid.prefix(8)).lowercased())
        if await vm.submit(modelContext: modelContext) {
            gate.accountCreated(uid: uid)
            log("onboarded as \(vm.handleInput.handle)")
        } else {
            log("onboarding failed: \(vm.submitError ?? "unknown")")
        }
    }
}
#endif
