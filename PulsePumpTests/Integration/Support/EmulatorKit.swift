import Testing
import Foundation
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions
@testable import PulsePump

// Shared plumbing for the emulator integration tier (bin/test-integration.sh).
//
// These suites run the real Swift sync / auth / social code against the local Firebase emulators
// (project `demo-pump`: Auth 9099, Firestore 8085, Functions 5001). They are SKIPPED, not failed, unless the
// environment variable PUMP_EMULATOR=1 is set, so the normal unit run (bin/test.sh) stays emulator-free.

extension Trait where Self == ConditionTrait {
    /// Apply to every integration suite: `@Suite(.emulator, .serialized)`.
    static var emulator: Self {
        .enabled(if: Emulator.isEnabled, "needs the Firebase emulators: run bin/test-integration.sh (PUMP_EMULATOR=1)")
    }
}

/// One Firebase app (Auth + Firestore + Functions) pointed at the emulators. Each simulated user gets their own, so
/// several accounts can be signed in at the same time and the host app's default Firebase app is never touched.
@MainActor
struct EmulatorClient {
    let app: FirebaseApp
    var auth: Auth { Auth.auth(app: app) }
    var db: Firestore { Firestore.firestore(app: app) }
    var functions: Functions { Functions.functions(app: app, region: FirebaseBootstrap.functionsRegion) }
}

@MainActor
enum Emulator {
    nonisolated static var isEnabled: Bool { ProcessInfo.processInfo.environment["PUMP_EMULATOR"] == "1" }

    nonisolated static var host: String {
        let value = ProcessInfo.processInfo.environment["PUMP_EMULATOR_HOST"] ?? ""
        return value.isEmpty ? "127.0.0.1" : value
    }

    nonisolated static let projectId = "demo-pump"

    /// Same ports as `firebase.json`; the wiring itself is `FirebaseBootstrap.emulatorApp`.
    static var config: FirebaseEmulatorConfig { FirebaseEmulatorConfig(host: host) }

    private static var clients: [String: EmulatorClient] = [:]

    /// The client for a slot (`it-0`, `it-1`...). Created and wired to the emulators once per test process.

    static func client(slot: Int) -> EmulatorClient {
        let name = "it-\(slot)"
        if let existing = clients[name] { return existing }
        let app = FirebaseBootstrap.emulatorApp(named: name, config: config)
        // Never let a test write to the real project: the app, its Firestore host and Auth must all be the emulator.
        precondition(app.options.projectID == projectId, "integration client is not on \(projectId)")
        precondition(app.name != "__FIRAPP_DEFAULT", "integration tests must not use the default Firebase app")
        precondition(Firestore.firestore(app: app).settings.host.hasPrefix(host), "Firestore is not pointed at the emulator")
        let client = EmulatorClient(app: app)
        clients[name] = client
        return client
    }

    // MARK: Emulator REST

    static func rest(_ method: String, port: Int, _ path: String) async throws {
        var request = URLRequest(url: URL(string: "http://\(host):\(port)\(path)")!)
        request.httpMethod = method
        // 409 = the emulator is still settling a write (a trigger or a stream from the previous test); try again.
        var status = 0
        for attempt in 0..<6 {
            let (_, response) = try await URLSession.shared.data(for: request)
            status = (response as? HTTPURLResponse)?.statusCode ?? 0
            if status != 409 { break }
            try await Task.sleep(for: .milliseconds(250 * (attempt + 1)))
        }
        guard (200..<300).contains(status) else { throw EmulatorError.http(status, path) }
    }

    /// `DELETE /emulator/v1/projects/demo-pump/databases/(default)/documents`
    static func clearFirestore() async throws {
        try await rest("DELETE", port: config.firestorePort,
                       "/emulator/v1/projects/\(projectId)/databases/(default)/documents")
    }

    /// `DELETE /emulator/v1/projects/demo-pump/accounts`
    static func clearAuth() async throws {
        try await rest("DELETE", port: config.authPort, "/emulator/v1/projects/\(projectId)/accounts")
    }

    /// Does a document exist, regardless of the security rules? (The emulator accepts `Bearer owner` as an admin.)
    /// Used to check what Cloud Functions did to data the signed-in test user may no longer read.
    static func adminDocumentExists(_ path: String) async -> Bool {
        var request = URLRequest(url: URL(string: "http://\(host):\(config.firestorePort)/v1/projects/\(projectId)/databases/(default)/documents/\(path)")!)
        request.setValue("Bearer owner", forHTTPHeaderField: "Authorization")
        guard let (_, response) = try? await URLSession.shared.data(for: request) else { return false }
        return (response as? HTTPURLResponse)?.statusCode == 200
    }

    /// Number of documents directly under a collection path, bypassing the rules.
    static func adminCount(_ collectionPath: String) async -> Int {
        var request = URLRequest(url: URL(string: "http://\(host):\(config.firestorePort)/v1/projects/\(projectId)/databases/(default)/documents/\(collectionPath)?pageSize=300")!)
        request.setValue("Bearer owner", forHTTPHeaderField: "Authorization")
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let docs = json["documents"] as? [Any] else { return 0 }
        return docs.count
    }

    // MARK: Waiting

    /// Polls until `check` is true or the timeout passes (Cloud Functions are asynchronous). Returns the last verdict.
    @discardableResult
    static func eventually(timeout: TimeInterval = 20, every interval: TimeInterval = 0.25,
                           _ check: () async throws -> Bool) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while true {
            if (try? await check()) == true { return true }
            if Date() >= deadline { return false }
            try? await Task.sleep(for: .seconds(interval))
        }
    }

    // MARK: Isolation

    /// Swift Testing runs suites in parallel but every test shares one emulator, which is wiped between tests.
    /// This gate makes the whole tier run one test at a time.
    private actor Gate {
        private var busy = false
        private var waiters: [CheckedContinuation<Void, Never>] = []
        func enter() async {
            if !busy { busy = true; return }
            await withCheckedContinuation { waiters.append($0) }
        }
        func leave() {
            if waiters.isEmpty { busy = false } else { waiters.removeFirst().resume() }
        }
    }
    private static let gate = Gate()

    /// Runs one test body against a freshly emptied Auth + Firestore emulator.

    static func isolated(_ body: (EmulatorWorld) async throws -> Void) async throws {
        await gate.enter()
        let world = EmulatorWorld()
        do {
            try await clearFirestore()
            try await clearAuth()
            try await body(world)
        } catch {
            world.signOutAll()
            await gate.leave()
            throw error
        }
        world.signOutAll()
        await gate.leave()
    }
}

enum EmulatorError: Error, CustomStringConvertible {
    case http(Int, String)
    case notReachable

    var description: String {
        switch self {
        case .http(let status, let path): "emulator REST \(path) answered \(status)"
        case .notReachable: "the emulators are not running (start them with bin/test-integration.sh)"
        }
    }
}

/// Everything a single test owns: the accounts it created and the client slots it used.
@MainActor
final class EmulatorWorld {
    private var nextSlot = 0
    private var usedSlots: [EmulatorClient] = []

    /// A client with nobody signed in.
    func anonymousClient() -> EmulatorClient {
        let client = Emulator.client(slot: nextSlot)
        nextSlot += 1
        try? client.auth.signOut()
        usedSlots.append(client)
        return client
    }

    /// A brand new email account on its own client, signed in through the app's `FirebaseAuthProvider`.
    /// `profile: true` also runs onboarding's atomic profile + username creation.
    func account(_ label: String = "lifter", profile: Bool = false, unit: String = "kg") async throws -> TestAccount {
        let client = anonymousClient()
        let tag = UUID().uuidString.prefix(8).lowercased()
        let account = try await TestAccount.signUp(client: client, label: label, tag: String(tag))
        if profile { try await account.createProfile(unit: unit) }
        return account
    }

    func signOutAll() {
        for client in usedSlots { try? client.auth.signOut() }
        usedSlots.removeAll()
    }
}
