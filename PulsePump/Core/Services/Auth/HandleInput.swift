import Foundation
import Observation

enum HandleStatus: Equatable {
    case idle
    case invalid(HandleValidator.Problem)
    case checking
    case available
    case taken
    case failed(String)

    var message: String? {
        switch self {
        case .idle: nil
        case .invalid(let problem): problem.message
        case .checking: "Checking availability…"
        case .available: "Available"
        case .taken: "Already taken"
        case .failed(let text): text
        }
    }
}

/// Editing state for a username: normalises typing, validates locally, then checks `usernames/{handle}`
/// (debounced). Used by onboarding and by the rename sheet.
@MainActor
@Observable
final class HandleInput {
    var text = ""
    private(set) var status: HandleStatus = .idle

    @ObservationIgnored private let remote: ProfileRemote
    @ObservationIgnored private let uid: String
    @ObservationIgnored private let debounce: Duration
    /// The handle this user already owns; typing it back is always "available".
    @ObservationIgnored private let ownedHandle: String?
    @ObservationIgnored private var task: Task<Void, Never>?

    init(remote: ProfileRemote, uid: String, ownedHandle: String? = nil, debounce: Duration = .milliseconds(350)) {
        self.remote = remote
        self.uid = uid
        self.ownedHandle = ownedHandle
        self.debounce = debounce
    }

    var handle: String { HandleValidator.normalize(text) }
    var isAvailable: Bool { status == .available }

    /// Call from the field's onChange: lower-cases, validates, and schedules the remote check.
    func textChanged() {
        task?.cancel()
        let normalized = handle
        if text != text.lowercased() { text = text.lowercased() }
        if let problem = HandleValidator.validate(normalized) {
            status = normalized.isEmpty ? .idle : .invalid(problem)
            return
        }
        status = .checking
        task = Task { [weak self] in
            guard let self else { return }
            if self.debounce > .zero { try? await Task.sleep(for: self.debounce) }
            guard !Task.isCancelled else { return }
            await self.checkNow()
        }
    }

    /// Validates and asks the server right away (also the retry action).
    func checkNow() async {
        let candidate = handle
        if let problem = HandleValidator.validate(candidate) {
            status = candidate.isEmpty ? .idle : .invalid(problem)
            return
        }
        if candidate == ownedHandle { status = .available; return }
        status = .checking
        do {
            let free = try await remote.isHandleAvailable(candidate, for: uid)
            guard candidate == handle else { return }   // typed on meanwhile: a newer check owns the status
            status = free ? .available : .taken
        } catch {
            guard candidate == handle else { return }
            status = .failed((error as? ProfileRemoteError)?.message ?? "Couldn't check availability. Try again.")
        }
    }

    /// Sets text programmatically (prefill) and checks immediately.
    func prefill(_ suggestion: String) async {
        text = suggestion
        await checkNow()
    }

    /// The server rejected the claim although it looked free (someone else won the race).
    func markTaken() { status = .taken }

    func cancel() { task?.cancel() }
}
