import SwiftUI

// MARK: - Sign in (accounts are required: Apple, Google or Email)

/// Hosted legal documents. Terms / Privacy stay plain text until the URLs exist.
enum LegalLinks {
    static let terms: URL? = nil
    static let privacy: URL? = nil
}

struct SignInView: View {
    @Bindable var session: AuthSession
    @State private var showEmail = false

    var body: some View {
        ZStack {
            Color.canvasBg.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // ── Logo lockup ───────────────────────────────────
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.pumpAccent)
                            .frame(width: 44, height: 44)
                        Image(systemName: "house.fill")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text("PULSE/PUMP")
                            .font(.archivo(20, weight: .black))
                            .tracking(1)
                            .foregroundStyle(Color.inkPrimary)
                        Text("TRAIN SMARTER")
                            .font(.spaceMono(9))
                            .tracking(1.5)
                            .foregroundStyle(Color.inkMuted)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.bottom, 28)

                // ── Headline ───────────────────────────────────────
                Text("Your training,\nquantified.")
                    .font(.archivo(36, weight: .light))
                    .tracking(-1)
                    .lineSpacing(2)
                    .foregroundStyle(Color.inkPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)

                Text("Log workouts, track progress, and let the app predict what you should do next.")
                    .font(.archivo(14))
                    .foregroundStyle(Color.inkMuted)
                    .lineSpacing(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.top, 8)

                Spacer().frame(height: 36)

                // ── Auth buttons ───────────────────────────────────
                VStack(spacing: 10) {
                    providerButton(label: "Continue with Apple", id: "signInApple") {
                        Image(systemName: "apple.logo")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Color.inkPrimary)
                    } action: { Task { await session.signInWithApple() } }

                    providerButton(label: "Continue with Google", id: "signInGoogle") {
                        GoogleColorIcon(size: 20)
                    } action: { Task { await session.signInWithGoogle() } }

                    providerButton(label: "Use email instead", id: "signInEmail") {
                        Image(systemName: "envelope")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Color.inkPrimary)
                            .frame(width: 20)
                    } action: {
                        session.clearMessages()
                        showEmail = true
                    }
                }
                .padding(.horizontal, 24)
                .disabled(session.isBusy)
                .overlay {
                    if session.isBusy { ProgressView().tint(Color.accentInk) }
                }

                if let message = session.errorMessage, !showEmail {
                    Text(message)
                        .font(.archivo(13))
                        .foregroundStyle(Color.signalDown)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.top, 14)
                        .accessibilityIdentifier("signInError")
                }

                // ── Disclaimer ─────────────────────────────────────
                legalFooter
                    .padding(.horizontal, 32)
                    .padding(.top, 20)

                Spacer()
            }
        }
        .sheet(isPresented: $showEmail) {
            EmailAuthSheet(session: session)
        }
    }

    private func providerButton<Icon: View>(label: String, id: String, @ViewBuilder icon: () -> Icon,
                                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                icon()
                Text(label)
                    .font(.archivo(17, weight: .semibold))
                    .foregroundStyle(Color.inkPrimary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Color.surf)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.inkPrimary.opacity(0.13), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
    }

    /// Terms / Privacy are plain text until the hosted URLs exist, then real links.
    private var legalFooter: some View {
        let terms = LegalLinks.terms.map { Text("[Terms of Service](\($0.absoluteString))") } ?? Text("Terms of Service")
        let privacy = LegalLinks.privacy.map { Text("[Privacy Policy](\($0.absoluteString))") } ?? Text("Privacy Policy")
        return (Text("By continuing you agree to our ") + terms + Text(" and ") + privacy + Text("."))
            .font(.archivo(11))
            .foregroundStyle(Color.inkPrimary.opacity(0.28))
            .multilineTextAlignment(.center)
            .tint(Color.accentInk)
    }
}

// MARK: - Google logo (drawn with Circle.trim — no asset required)

private struct GoogleColorIcon: View {
    var size: CGFloat = 20

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.22)
                .fill(.white)

            let ring = size * 0.74
            let sw   = ring * 0.26

            // All arcs share these base modifiers:
            // .rotationEffect(.degrees(-90)) → 0.0 starts at 12 o'clock, going clockwise
            //
            // Segments (fractions of full circle):
            //  Blue   : 12→~2:15 (0.000–0.188) + 9→12 (0.750–1.000)
            //  Red    : ~3:30→~5:30 (0.292–0.458)
            //  Yellow : ~5:30→~7  (0.458–0.583)
            //  Green  : ~7→9    (0.583–0.750)
            //  Gap    : ~2:15→~3:30 (0.188–0.292) — white shows through

            Group {
                // Blue top-right segment
                Circle().trim(from: 0.000, to: 0.188)
                    .stroke(Color(hex: "#4285F4"),
                            style: StrokeStyle(lineWidth: sw, lineCap: .butt))
                // Blue left/top segment (wraps from 9 o'clock back to 12)
                Circle().trim(from: 0.750, to: 1.000)
                    .stroke(Color(hex: "#4285F4"),
                            style: StrokeStyle(lineWidth: sw, lineCap: .butt))
                // Red
                Circle().trim(from: 0.292, to: 0.458)
                    .stroke(Color(hex: "#EA4335"),
                            style: StrokeStyle(lineWidth: sw, lineCap: .butt))
                // Yellow
                Circle().trim(from: 0.458, to: 0.583)
                    .stroke(Color(hex: "#FBBC05"),
                            style: StrokeStyle(lineWidth: sw, lineCap: .butt))
                // Green
                Circle().trim(from: 0.583, to: 0.750)
                    .stroke(Color(hex: "#34A853"),
                            style: StrokeStyle(lineWidth: sw, lineCap: .butt))
            }
            .frame(width: ring, height: ring)
            .rotationEffect(.degrees(-90))

            // Horizontal crossbar — white rect from center to right edge
            Rectangle()
                .fill(.white)
                .frame(width: ring / 2, height: sw)
                .offset(x: ring / 4)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Email auth sheet (sign in / sign up / reset)

struct EmailAuthSheet: View {
    enum Mode { case signIn, signUp, reset }

    @Bindable var session: AuthSession
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?
    @State private var mode: Mode = .signIn
    @State private var email = ""
    @State private var password = ""
    @State private var passwordVisible = false
    enum Field { case email, password }

    private var emailValid: Bool {
        let t = email.trimmingCharacters(in: .whitespaces)
        return t.contains("@") && t.contains(".")
    }
    private var passwordValid: Bool { password.count >= 8 }
    private var isSignUp: Bool { mode == .signUp }
    private var canSubmit: Bool {
        switch mode {
        case .reset: emailValid
        case .signUp: emailValid && passwordValid
        case .signIn: emailValid && !password.isEmpty
        }
    }

    // 0-4 strength score
    private var passwordScore: Int {
        let p = password
        guard !p.isEmpty else { return 0 }
        var s = 0
        if p.count >= 8  { s += 1 }
        if p.count >= 12 { s += 1 }
        if p.range(of: "[A-Z]", options: .regularExpression) != nil &&
           p.range(of: "[a-z]", options: .regularExpression) != nil { s += 1 }
        if p.range(of: "[0-9]", options: .regularExpression) != nil { s += 1 }
        return min(s, 4)
    }
    private var strengthLabel: String { ["", "WEAK", "FAIR", "GOOD", "STRONG"][passwordScore] }
    private var strengthColor: Color {
        switch passwordScore {
        case 1: return Color.signalDown
        case 2: return Color(hex: "#c89b3d")
        case 3: return Color(hex: "#7a8f3a")
        case 4: return Color.signalUp
        default: return Color.inkFaint
        }
    }

    private var kicker: String {
        switch mode {
        case .signIn: "WELCOME BACK"
        case .signUp: "CREATE ACCOUNT"
        case .reset: "RESET PASSWORD"
        }
    }
    private var heading: String {
        switch mode {
        case .signIn: "Sign in to\nyour account."
        case .signUp: "Create your\naccount."
        case .reset: "Reset your\npassword."
        }
    }
    private var subheading: String {
        switch mode {
        case .signIn: "Pick up right where you left off."
        case .signUp: "Takes 30 seconds. No spam, ever."
        case .reset: "We'll email you a link to choose a new password."
        }
    }
    private var ctaLabel: String {
        switch mode {
        case .signIn: "SIGN IN"
        case .signUp: "CREATE ACCOUNT"
        case .reset: "SEND RESET LINK"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.inkPrimary)
                        .frame(width: 36, height: 36)
                        .background(Color.surf2)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 8)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("01 / \(kicker)")
                        .font(.spaceMono(10, weight: .bold))
                        .tracking(1.5)
                        .foregroundStyle(Color.accentInk)
                        .padding(.bottom, 10)

                    Text(heading)
                        .font(.archivo(34, weight: .light))
                        .tracking(-0.8)
                        .lineSpacing(2)
                        .foregroundStyle(Color.inkPrimary)

                    Text(subheading)
                        .font(.archivo(13))
                        .foregroundStyle(Color.inkMuted)
                        .lineSpacing(4)
                        .padding(.top, 8)
                        .padding(.bottom, 24)

                    if mode != .reset { modeToggle }

                    emailField

                    if mode != .reset { passwordField }

                    if let message = session.errorMessage {
                        Text(message)
                            .font(.archivo(13))
                            .foregroundStyle(Color.signalDown)
                            .padding(.top, 14)
                            .accessibilityIdentifier("emailAuthError")
                    }
                    if let sent = session.resetEmailSentTo {
                        Text("Check \(sent) for a reset link.")
                            .font(.archivo(13))
                            .foregroundStyle(Color.signalUp)
                            .padding(.top, 14)
                    }

                    if mode == .signIn {
                        Button("Forgot password?") { switchMode(.reset) }
                            .font(.archivo(13, weight: .semibold))
                            .foregroundStyle(Color.accentInk)
                            .buttonStyle(.plain)
                            .padding(.top, 16)
                    } else if mode == .reset {
                        Button("Back to sign in") { switchMode(.signIn) }
                            .font(.archivo(13, weight: .semibold))
                            .foregroundStyle(Color.accentInk)
                            .buttonStyle(.plain)
                            .padding(.top, 16)
                    }

                    Spacer().frame(height: 20)
                }
                .padding(.horizontal, 20)
                .padding(.top, 6)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 0) {
                    if isSignUp {
                        Text("By creating an account you agree to our Terms and Privacy Policy.")
                            .font(.archivo(12))
                            .foregroundStyle(Color.inkMuted)
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                            .padding(.horizontal, 24)
                            .padding(.top, 10)
                            .padding(.bottom, 6)
                    }

                    Button(action: submit) {
                        Text(ctaLabel)
                            .font(.archivo(22, weight: .black))
                            .tracking(2)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(canSubmit ? Color.pumpAccent : Color.inkFaint)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(PressScaleButtonStyle(scaleAmount: 0.97))
                    .disabled(!canSubmit || session.isBusy)
                    .accessibilityIdentifier("emailAuthSubmit")
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .overlay { if session.isBusy { ProgressView().tint(Color.accentInk) } }
                }
                .background(Color.canvasBg)
            }
        }
        .background(Color.canvasBg.ignoresSafeArea())
        .onAppear { session.clearMessages() }
    }

    private func switchMode(_ new: Mode) {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.7)) {
            mode = new
            password = ""
            passwordVisible = false
        }
        session.clearMessages()
    }

    private func submit() {
        Task {
            switch mode {
            case .signIn:
                if await session.signInWithEmail(email, password: password) { dismiss() }
            case .signUp:
                if await session.signUp(email: email, password: password) { dismiss() }
            case .reset:
                await session.sendPasswordReset(email: email)
            }
        }
    }

    private var modeToggle: some View {
        HStack(spacing: 2) {
            ForEach([(Mode.signIn, "SIGN IN"), (Mode.signUp, "SIGN UP")], id: \.1) { target, label in
                let active = mode == target
                Button { switchMode(target) } label: {
                    Text(label)
                        .font(.spaceMono(11, weight: .bold))
                        .tracking(1.2)
                        .foregroundStyle(active ? Color.accentInk : Color.inkMuted)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(active ? Color.canvasBg : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Color.surf2)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.bottom, 20)
    }

    private var emailField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("EMAIL")
                .font(.spaceMono(9, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(Color.inkMuted)

            ZStack(alignment: .trailing) {
                TextField("", text: $email)
                    .font(.archivo(16, weight: .medium))
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .focused($focusedField, equals: .email)
                    .tint(Color.accentInk)
                    .foregroundStyle(Color.inkPrimary)
                    .frame(height: 50)
                    .padding(.horizontal, 14)
                    .background(Color.surf)
                    .clipShape(RoundedRectangle(cornerRadius: 11))
                    .accessibilityIdentifier("emailField")
                    .overlay(alignment: .leading) {
                        if email.isEmpty {
                            Text("you@example.com")
                                .font(.archivo(16, weight: .medium))
                                .foregroundStyle(Color.inkFaint)
                                .padding(.leading, 14)
                                .allowsHitTesting(false)
                        }
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 11).strokeBorder(
                            focusedField == .email ? Color.accentInk :
                            (!email.isEmpty && !emailValid ? Color.signalDown : Color.dsHairLine),
                            lineWidth: 1
                        )
                    )

                if !email.isEmpty && emailValid {
                    ZStack {
                        Circle().fill(Color.signalUp).frame(width: 18, height: 18)
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .padding(.trailing, 14)
                }
            }

            if !email.isEmpty && !emailValid {
                Text("NOT A VALID EMAIL")
                    .font(.spaceMono(9, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(Color.signalDown)
            }
        }
        .padding(.bottom, 14)
    }

    private var passwordField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("PASSWORD")
                .font(.spaceMono(9, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(Color.inkMuted)

            ZStack(alignment: .trailing) {
                Group {
                    if passwordVisible {
                        TextField(isSignUp ? "At least 8 characters" : "Your password", text: $password)
                    } else {
                        SecureField(isSignUp ? "At least 8 characters" : "Your password", text: $password)
                    }
                }
                .font(.archivo(16, weight: .medium))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textContentType(isSignUp ? .newPassword : .password)
                .focused($focusedField, equals: .password)
                .accessibilityIdentifier("passwordField")
                .frame(height: 50)
                .padding(.leading, 14)
                .padding(.trailing, 46)
                .background(Color.surf)
                .clipShape(RoundedRectangle(cornerRadius: 11))
                .overlay(
                    RoundedRectangle(cornerRadius: 11).strokeBorder(
                        focusedField == .password ? Color.accentInk : Color.dsHairLine,
                        lineWidth: 1
                    )
                )

                Button { passwordVisible.toggle() } label: {
                    Image(systemName: passwordVisible ? "eye.slash" : "eye")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.inkMuted)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 6)
            }

            if isSignUp && !password.isEmpty {
                VStack(spacing: 5) {
                    HStack(spacing: 4) {
                        ForEach(0..<4, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(i < passwordScore ? strengthColor : Color.dsHairLine)
                                .frame(height: 3)
                        }
                    }
                    HStack {
                        Text(strengthLabel)
                            .font(.spaceMono(9, weight: .bold))
                            .tracking(1)
                            .foregroundStyle(strengthColor)
                        Spacer()
                        Text("MIN 8 CHARS")
                            .font(.spaceMono(9))
                            .tracking(1)
                            .foregroundStyle(Color.inkMuted)
                    }
                }
            }
        }
    }
}
