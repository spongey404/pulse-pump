import SwiftUI
import AuthenticationServices

// MARK: - Welcome / Auth screen  (matches Pump Onboarding.html — A1 Full Flow)

struct WelcomeView: View {
    @Bindable var viewModel: OnboardingViewModel

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
                    // Apple — fully custom button, triggers ASAuthorizationController directly
                    Button(action: viewModel.signInWithApple) {
                        HStack(spacing: 10) {
                            Image(systemName: "apple.logo")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(Color.inkPrimary)
                            Text("Continue with Apple")
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

                    // Google
                    Button(action: viewModel.signInWithGoogle) {
                        HStack(spacing: 10) {
                            GoogleColorIcon(size: 20)
                            Text("Continue with Google")
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

                    // Email
                    Button { viewModel.showEmailAuth = true } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "envelope")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(Color.inkPrimary)
                                .frame(width: 20)
                            Text("Use email instead")
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
                }
                .padding(.horizontal, 24)
                .disabled(viewModel.isLoading)
                .overlay {
                    if viewModel.isLoading {
                        ProgressView().tint(Color.accentInk)
                    }
                }

                // ── Disclaimer ─────────────────────────────────────
                Text("By continuing you agree to our Terms of Service and Privacy Policy.")
                    .font(.archivo(11))
                    .foregroundStyle(Color.inkPrimary.opacity(0.28))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.top, 20)

                Spacer()
            }
        }
        .sheet(isPresented: $viewModel.showEmailAuth) {
            EmailAuthSheet(viewModel: viewModel)
        }
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

// MARK: - Email auth sheet

struct EmailAuthSheet: View {
    @Bindable var viewModel: OnboardingViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?
    @State private var passwordVisible = false
    enum Field { case email, password }

    private var emailValid: Bool {
        let t = viewModel.email.trimmingCharacters(in: .whitespaces)
        return t.contains("@") && t.contains(".")
    }
    private var passwordValid: Bool { viewModel.password.count >= 8 }
    private var canSubmit: Bool { emailValid && passwordValid }

    // 0–4 strength score
    private var passwordScore: Int {
        let p = viewModel.password
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
        case 1: return Color(hex: "#c0341a")
        case 2: return Color(hex: "#c89b3d")
        case 3: return Color(hex: "#7a8f3a")
        case 4: return Color.signalUp
        default: return Color.inkFaint
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
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
                    // Label + heading
                    Text(viewModel.isSignUp ? "01 / CREATE ACCOUNT" : "01 / WELCOME BACK")
                        .font(.spaceMono(10, weight: .bold))
                        .tracking(1.5)
                        .foregroundStyle(Color.accentInk)
                        .padding(.bottom, 10)

                    Text(viewModel.isSignUp ? "Create your\naccount." : "Sign in to\nyour account.")
                        .font(.archivo(34, weight: .light))
                        .tracking(-0.8)
                        .lineSpacing(2)
                        .foregroundStyle(Color.inkPrimary)

                    Text(viewModel.isSignUp ? "Takes 30 seconds. No spam, ever." : "Pick up right where you left off.")
                        .font(.archivo(13))
                        .foregroundStyle(Color.inkMuted)
                        .lineSpacing(4)
                        .padding(.top, 8)
                        .padding(.bottom, 24)

                    // Mode toggle
                    HStack(spacing: 2) {
                        ForEach([(false, "SIGN IN"), (true, "SIGN UP")], id: \.0) { isSignUp, label in
                            let active = viewModel.isSignUp == isSignUp
                            Button {
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.7)) {
                                    viewModel.isSignUp = isSignUp
                                    viewModel.password = ""
                                    passwordVisible = false
                                }
                            } label: {
                                Text(label)
                                    .font(.spaceMono(11, weight: .bold))
                                    .tracking(1.2)
                                    .foregroundStyle(active ? Color.accentInk : Color.inkMuted)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 36)
                                    .background(active ? Color.canvasBg : Color.clear)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .shadow(color: active ? Color.black.opacity(0.06) : .clear, radius: 3, y: 1)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(3)
                    .background(Color.surf2)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.bottom, 20)

                    // Email field
                    VStack(alignment: .leading, spacing: 6) {
                        Text("EMAIL")
                            .font(.spaceMono(9, weight: .bold))
                            .tracking(1.2)
                            .foregroundStyle(Color.inkMuted)

                        ZStack(alignment: .trailing) {
                            TextField("", text: $viewModel.email)
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
                                .overlay(alignment: .leading) {
                                    if viewModel.email.isEmpty {
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
                                        (!viewModel.email.isEmpty && !emailValid ? Color.signalDown : Color.dsHairLine),
                                        lineWidth: 1
                                    )
                                )

                            if !viewModel.email.isEmpty && emailValid {
                                ZStack {
                                    Circle().fill(Color.signalUp).frame(width: 18, height: 18)
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                                .padding(.trailing, 14)
                            }
                        }

                        if !viewModel.email.isEmpty && !emailValid {
                            Text("NOT A VALID EMAIL")
                                .font(.spaceMono(9, weight: .bold))
                                .tracking(1)
                                .foregroundStyle(Color.signalDown)
                        }
                    }
                    .padding(.bottom, 14)

                    // Password field
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("PASSWORD")
                                .font(.spaceMono(9, weight: .bold))
                                .tracking(1.2)
                                .foregroundStyle(Color.inkMuted)
                            Spacer()
                            if !viewModel.isSignUp {
                                Button("FORGOT?") {}
                                    .font(.spaceMono(9, weight: .bold))
                                    .tracking(1)
                                    .foregroundStyle(Color.accentInk)
                                    .buttonStyle(.plain)
                            }
                        }

                        ZStack(alignment: .trailing) {
                            Group {
                                if passwordVisible {
                                    TextField(
                                        viewModel.isSignUp ? "At least 8 characters" : "Your password",
                                        text: $viewModel.password
                                    )
                                } else {
                                    SecureField(
                                        viewModel.isSignUp ? "At least 8 characters" : "Your password",
                                        text: $viewModel.password
                                    )
                                }
                            }
                            .font(.archivo(16, weight: .medium))
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .textContentType(viewModel.isSignUp ? .newPassword : .password)
                            .focused($focusedField, equals: .password)
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

                        // Strength meter (sign-up only)
                        if viewModel.isSignUp && !viewModel.password.isEmpty {
                            VStack(spacing: 5) {
                                HStack(spacing: 4) {
                                    ForEach(0..<4, id: \.self) { i in
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(i < passwordScore ? strengthColor : Color.dsHairLine)
                                            .frame(height: 3)
                                            .animation(.easeInOut(duration: 0.2), value: passwordScore)
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

                    Spacer().frame(height: 20)
                }
                .padding(.horizontal, 20)
                .padding(.top, 6)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 0) {
                    // Terms (sign-up only)
                    if viewModel.isSignUp {
                        Text("By creating an account you agree to our Terms and Privacy Policy.")
                            .font(.archivo(12))
                            .foregroundStyle(Color.inkMuted)
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                            .padding(.horizontal, 24)
                            .padding(.top, 10)
                            .padding(.bottom, 6)
                    }

                    // CTA
                    Button(action: viewModel.submitEmailAuth) {
                        Text(viewModel.isSignUp ? "CREATE ACCOUNT" : "SIGN IN")
                            .font(.archivo(22, weight: .black))
                            .tracking(2)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(canSubmit ? Color.pumpAccent : Color.inkFaint)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(PressScaleButtonStyle(scaleAmount: 0.97))
                    .disabled(!canSubmit || viewModel.isLoading)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .overlay { if viewModel.isLoading { ProgressView().tint(Color.accentInk) } }
                }
                .background(Color.canvasBg)
            }
        }
        .background(Color.canvasBg.ignoresSafeArea())
    }
}
