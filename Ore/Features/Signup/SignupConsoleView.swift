import SwiftUI
import SwiftData

/// Sign-up and onboarding as one continuous console (design "Ore Signup Final"): the opening screen, then questions
/// typed out one at a time over a sky that fills with stars as the answers come in, then the setup lines and the welcome.
/// Always the Sky theme. Replaces the sign-in screen, the email sheet and the nine onboarding screens.
struct SignupConsoleView: View {
    /// Owned by `SignupHolder`, not by this view: the gate swaps the screen for the splash while the account is created, and
    /// the answers typed so far have to survive that.
    @Bindable var model: SignupFlowModel
    @State private var runner: SignupSkyRunner
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var focused: Bool
    #if DEBUG
    @State private var showDevPanel = false
    #endif

    private var config: SignupConfig { model.config }

    init(model: SignupFlowModel) {
        self.model = model
        _runner = State(initialValue: SignupSkyRunner(config: model.config, surge: model.surge))
    }

    /// UI tests skip the typing animation (`-signupInstant 1`); Reduce Motion does too.
    static var instantTyping: Bool {
        #if DEBUG
        return UserDefaults.standard.bool(forKey: "signupInstant")
        #else
        return false
        #endif
    }

    var body: some View {
        ZStack {
            SignupSkyColors.base.ignoresSafeArea()
            SignupBackdrop(runner: runner, target: model.level)
            VStack(spacing: 0) {
                header
                content
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { docked }
        .preferredColorScheme(.dark)   // the status bar stays white on the sky
        .tint(.white)
        #if DEBUG
        .sheet(isPresented: $showDevPanel) { SignupDevPanel() }
        #endif
        .onAppear { model.instant = model.instant || reduceMotion; model.sessionChanged() }
        .onChange(of: model.session.user?.uid) { _, _ in model.sessionChanged() }
    }

    // MARK: Header

    private var header: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Rectangle().fill(SignupSkyColors.ink).frame(width: 12, height: 12)
                Text("ORE").font(.spaceMono(10, weight: .bold)).tracking(2).foregroundStyle(SignupSkyColors.ink)
                    #if DEBUG
                    .onLongPressGesture(minimumDuration: 1.0) { showDevPanel = true }   // hidden tuning panel
                    #endif
                Spacer()
                Text(model.progressLabel).font(.spaceMono(9)).tracking(1.5).foregroundStyle(SignupSkyColors.muted)
                    .accessibilityIdentifier(AX.signup.step)
            }
            SignupProgressBar(config: config, surge: model.surge,
                              progress: model.stage == .landing ? 0 : model.stage == .console ? Double(model.answeredCount) / Double(max(1, model.total)) : 1)
        }
        .padding(.horizontal, 24)
        .padding(.top, 4)   // the design: 4 pt under the status bar
    }

    // MARK: Body

    @ViewBuilder private var content: some View {
        if model.stage == .landing {
            landing
        } else {
            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        logList
                        if model.stage == .console, let step = model.current { question(step) }
                        if model.stage == .setup { setupList }
                        if model.stage == .welcome { welcome }
                        Color.clear.frame(height: 1).id("bottom")
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, model.logRows.isEmpty ? 28 : 18)
                    .padding(.bottom, 20)
                }
                .scrollDismissesKeyboard(.never)
                .onChange(of: model.stepIndex) { _, _ in scrollDown(proxy) }
                .onChange(of: model.typed) { _, _ in scrollDown(proxy) }
                .onChange(of: model.stage) { _, _ in scrollDown(proxy) }
                .onChange(of: model.setupLines) { _, _ in scrollDown(proxy) }
            }
        }
    }

    private func scrollDown(_ proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo("bottom", anchor: .bottom) }
    }

    // MARK: Opening screen

    private var landing: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 120)
            Text("Your training, quantified.")
                .font(.archivo(40, weight: .black)).tracking(-0.5).textCase(.uppercase)
                .cssLineHeight(fontName: "Archivo-Black", size: 40, multiple: 1.0)
                .foregroundStyle(SignupSkyColors.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text("Log workouts, track progress, and let the app predict what you should do next.")
                .font(.archivo(15)).foregroundStyle(SignupSkyColors.ink2)
                .cssLineHeight(fontName: "Archivo-Regular", size: 15, multiple: 1.4)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 10)
            if let message = model.session.errorMessage {
                Text(message).font(.archivo(13)).foregroundStyle(SignupSkyColors.error).padding(.top, 12)
                    .accessibilityIdentifier(AX.auth.error)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.bottom, 20)   // the scroll area's bottom padding in the design
    }

    // MARK: Log and questions

    private var logList: some View {
        VStack(spacing: 0) {
            ForEach(model.logRows) { row in
                Button { model.edit(row.id) } label: {
                    HStack(spacing: 10) {
                        StarBullet(size: config.bullet.logSize, delay: row.delay).frame(width: 16)
                        Text(row.label).font(.spaceMono(9)).tracking(1.5).foregroundStyle(SignupSkyColors.muted)
                            .frame(width: 88, alignment: .leading)
                        Text(row.value).font(.archivo(15, weight: .bold)).foregroundStyle(SignupSkyColors.ink)
                            .lineLimit(1).truncationMode(.tail)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if row.editable { Text("EDIT").font(.spaceMono(8)).tracking(1.2).foregroundStyle(SignupSkyColors.muted) }
                    }
                    .frame(minHeight: 36)
                    .padding(.bottom, 1)   // min-height 36 + a 1 pt bottom border = 37
                    .overlay(alignment: .bottom) { Rectangle().fill(SignupSkyColors.rule).frame(height: 1) }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .allowsHitTesting(row.editable)   // not .disabled: that would dim a locked row
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(row.label), \(row.value)")
                .accessibilityIdentifier(AX.signup.row(row.id))
                .transition(.opacity.combined(with: .offset(y: config.typing.risePt)))
            }
        }
        .animation(.easeOut(duration: Double(config.typing.riseMs) / 1000), value: model.logRows.map(\.id))
    }

    private func question(_ step: SignupConfig.Step) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(model.questionNumber).font(.spaceMono(10)).tracking(2).foregroundStyle(SignupSkyColors.ink)
                .accessibilityIdentifier(AX.signup.number)
            promptText(step)
                .padding(.top, 8)
            if model.promptDone {
                Group {
                    if step.kind == "choice" { choices(step) } else { inputBlock(step) }
                }
                .transition(.opacity.combined(with: .offset(y: config.typing.risePt)))
            }
        }
        .padding(.top, model.logRows.isEmpty ? 0 : 22)
        .animation(.easeOut(duration: Double(config.typing.riseMs) / 1000), value: model.promptDone)
        .id(model.stepIndex)
    }

    private func promptText(_ step: SignupConfig.Step) -> some View {
        // The caret (2 × 24 pt, 3 pt after the text, blinking at 1 s) sits at the end of the prompt, and goes away once a
        // text field has taken over.
        let caretVisible = !(model.promptDone && step.kind != "choice")
        return TimelineView(.periodic(from: .now, by: 0.5)) { tl in
            let on = Int(tl.date.timeIntervalSinceReferenceDate / 0.5) % 2 == 0
            (Text(model.typedPrompt).foregroundStyle(SignupSkyColors.ink)
                + Text(Image(uiImage: SignupCaret.image(visible: caretVisible && on))).baselineOffset(-3))
                .font(.archivo(24, weight: .black)).tracking(-0.2).textCase(.uppercase)
                .cssLineHeight(fontName: "Archivo-Black", size: 24, multiple: 1.1)
                .frame(maxWidth: .infinity, minHeight: 30, alignment: .topLeading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityLabel(model.prompt)
    }

    // MARK: Input

    private func inputBlock(_ step: SignupConfig.Step) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if !step.units.isEmpty { unitToggle(step).padding(.top, 18).padding(.bottom, 16) }
            else { Color.clear.frame(height: 18) }
            let line = model.hintIsBad ? SignupSkyColors.error : model.value.isEmpty ? SignupSkyColors.line : Color.white
            HStack(spacing: 12) {
                Text(step.prefix).font(.spaceMono(18, weight: .bold)).foregroundStyle(SignupSkyColors.ink)
                field(step)
                let suffix = step.units.isEmpty ? step.suffix : (model.units[step.key] == "FT / IN" ? "FT/IN" : (model.units[step.key] ?? ""))
                if !suffix.isEmpty { Text(suffix).font(.spaceMono(12, weight: .bold)).tracking(1.5).foregroundStyle(SignupSkyColors.muted) }
            }
            .padding(.bottom, 10)
            .overlay(alignment: .bottom) { Rectangle().fill(line).frame(height: 1.5) }
            .animation(.easeOut(duration: 0.15), value: line)

            HStack(spacing: 12) {
                Text(model.hint).font(.spaceMono(9, weight: .bold)).tracking(1.5)
                    .foregroundStyle(model.hintIsBad ? SignupSkyColors.error : model.check.ok ? Color.white : SignupSkyColors.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier(model.errorHint != nil ? AX.auth.emailError : AX.signup.hint)
                if model.showsMeter { meter }
                Button { model.submit() } label: {
                    HStack(spacing: 6) { Text("CONTINUE ›") }
                        .font(.archivo(12, weight: .black)).tracking(1)
                        .foregroundStyle(model.canSubmit ? SignupSkyColors.ctaInk : SignupSkyColors.offInk)
                        .padding(.horizontal, 16).frame(height: 44)
                        .background(model.canSubmit ? Color.white : SignupSkyColors.offBg)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(PressOpacityStyle())   // draws its own disabled look, so .disabled adds no dimming
                .disabled(!model.canSubmit)
                .accessibilityIdentifier(AX.signup.next)
            }
            .padding(.top, 12)
            .frame(minHeight: 44)

            if model.isSignInMode && step.key == "password" {
                Button("FORGOT PASSWORD?") { Task { await model.sendReset() } }
                    .font(.spaceMono(9, weight: .bold)).tracking(1.5).foregroundStyle(SignupSkyColors.ink2)
                    .padding(.top, 6)
                    .accessibilityIdentifier(AX.signup.forgot)
            }
        }
    }

    @ViewBuilder private func field(_ step: SignupConfig.Step) -> some View {
        let prompt = Text(step.placeholder).foregroundStyle(SignupSkyColors.placeholder)
        Group {
            if step.kind == "password" || step.kind == "confirm" {
                SecureField("", text: $model.value, prompt: prompt)
                    .textContentType(Self.instantTyping ? .oneTimeCode : (model.isSignInMode ? .password : .newPassword))
            } else {
                TextField("", text: $model.value, prompt: prompt)
                    .keyboardType(keyboard(for: step))
                    .textContentType(step.kind == "email" ? .emailAddress : nil)
            }
        }
        // Archivo has no glyph for the secure-entry bullet (the dots would be invisible), so a password uses the system font.
        .font(step.kind == "password" || step.kind == "confirm" ? .system(size: 21, weight: .semibold) : .archivo(21, weight: .semibold))
        .foregroundStyle(SignupSkyColors.ink)
        .tint(.white)
        .textInputAutocapitalization(step.kind == "name" ? .words : .never)
        .autocorrectionDisabled()
        .submitLabel(.continue)
        .focused($focused)
        .onSubmit { model.submit() }
        .id(step.key + (model.isSignInMode ? "-in" : "") + (model.units[step.key] ?? ""))
        .task(id: "\(model.stepIndex)-\(model.isSignInMode)-\(model.units[step.key] ?? "")") {
            try? await Task.sleep(for: .milliseconds(30))
            focused = true
        }
        .accessibilityIdentifier(AX.signup.input)
    }

    private func keyboard(for step: SignupConfig.Step) -> UIKeyboardType {
        switch step.kind {
        case "email": .emailAddress
        case "weight": .decimalPad
        case "height": model.heightUnit == "CM" ? .numberPad : .numbersAndPunctuation
        case "age": .numberPad
        default: .default
        }
    }

    private func unitToggle(_ step: SignupConfig.Step) -> some View {
        HStack(spacing: 4) {
            ForEach(step.units, id: \.self) { u in
                let on = model.units[step.key] == u
                Button { model.setUnit(u) } label: {
                    Text(u).font(.spaceMono(10, weight: .bold)).tracking(1.5)
                        .foregroundStyle(on ? SignupSkyColors.ctaInk : Color.white.opacity(0.8))
                        .padding(.horizontal, 16).frame(height: 32)
                        .background(on ? Color.white : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(AX.signup.unit(u))
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(3)
        .background(SignupSkyColors.card)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .animation(.easeOut(duration: 0.15), value: model.units[step.key])
    }

    private var meter: some View {
        HStack(spacing: 3) {
            ForEach(1...4, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1)
                    .fill(model.value.count >= config.validation.passwordMin && i <= model.meterScore ? Color.white : SignupSkyColors.cardBorder)
                    .frame(width: 18, height: 4)
            }
        }
        .animation(.easeOut(duration: 0.15), value: model.meterScore)
        .accessibilityHidden(true)
    }

    // MARK: Choices

    private func choices(_ step: SignupConfig.Step) -> some View {
        let tall = step.choices.count <= 4
        let height = step.cardHeight > 0 ? step.cardHeight : (tall ? 50 : 46)
        return VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(step.choices.enumerated()), id: \.offset) { i, c in
                ChoiceCard(index: i, choice: c, height: height, program: step.uppercaseChoices,
                           delay: Double(i * config.typing.choiceStaggerMs) / 1000, rise: config.typing.risePt) { model.choose(i) }
                    .accessibilityIdentifier(AX.signup.choice(c.label))
            }
            Text("TAP OR PRESS 1–\(step.choices.count)").font(.spaceMono(9)).tracking(1.5).foregroundStyle(SignupSkyColors.muted)
                .padding(.top, 6)
            // Hardware keyboard: 1–N picks a card.
            ZStack {
                ForEach(0..<min(9, step.choices.count), id: \.self) { i in
                    Button("") { model.choose(i) }
                        .keyboardShortcut(KeyEquivalent(Character(String(i + 1))), modifiers: [])
                }
            }
            .frame(width: 0, height: 0).opacity(0).accessibilityHidden(true)
        }
        .padding(.top, 16)
    }

    // MARK: Setup and welcome

    private var setupList: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(model.setupRows) { line in
                HStack(spacing: 10) {
                    StarBullet(size: config.bullet.setupSize, delay: line.delay).frame(width: 16)
                    Text(line.text).font(.spaceMono(10)).tracking(1.5).foregroundStyle(SignupSkyColors.ink2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(line.right).font(.spaceMono(10)).tracking(1.5).foregroundStyle(SignupSkyColors.muted)
                }
                .transition(.opacity.combined(with: .offset(y: config.typing.risePt)))
            }
            if let error = model.setupError {
                VStack(alignment: .leading, spacing: 10) {
                    Text(error).font(.archivo(14)).foregroundStyle(SignupSkyColors.error)
                        .accessibilityIdentifier(AX.signup.setupError)
                    Button { model.retrySetup() } label: {
                        Text("RETRY").font(.archivo(12, weight: .black)).tracking(1).foregroundStyle(SignupSkyColors.ctaInk)
                            .padding(.horizontal, 16).frame(height: 44).background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(PressOpacityStyle())
                    .accessibilityIdentifier(AX.signup.retry)
                    Button { model.backToQuestions() } label: {
                        Text("CHANGE AN ANSWER").font(.spaceMono(10, weight: .bold)).tracking(1.5).foregroundStyle(SignupSkyColors.ink2)
                            .frame(height: 32)
                    }
                    .buttonStyle(PressOpacityStyle())
                    .accessibilityIdentifier(AX.signup.changeAnswer)
                }
            }
        }
        .padding(.top, 22)
        .animation(.easeOut(duration: Double(config.typing.riseMs) / 1000), value: model.setupRows.count)
    }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(model.welcomeTitle).font(.archivo(34, weight: .black)).tracking(-0.5).textCase(.uppercase)
                .cssLineHeight(fontName: "Archivo-Black", size: 34, multiple: 1.02)
                .foregroundStyle(SignupSkyColors.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier(AX.signup.welcome)
            Text("Your program is ready. Want a quick tour of the key features before you start?")
                .font(.archivo(15)).foregroundStyle(SignupSkyColors.ink2)
                .cssLineHeight(fontName: "Archivo-Regular", size: 15, multiple: 1.4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 26)
        .transition(.opacity.combined(with: .offset(y: config.typing.risePt)))
    }

    // MARK: Docked buttons

    /// The design's docked blocks end 28 pt above the screen's bottom edge; the safe area (home indicator) counts toward that.
    private static var dockBottom: CGFloat {
        let inset = UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.keyWindow }.first?.safeAreaInsets.bottom ?? 34
        return 28 - inset
    }

    @ViewBuilder private var docked: some View {
        switch model.stage {
        case .landing:
            VStack(spacing: 10) {
                providerButton("CONTINUE WITH APPLE", id: AX.auth.apple, solid: true) { Task { await model.signIn(with: .apple) } }
                providerButton("CONTINUE WITH GOOGLE", id: AX.auth.google, solid: false) { Task { await model.signIn(with: .google) } }
                providerButton("USE EMAIL INSTEAD", id: AX.auth.useEmail, solid: false) { model.session.clearMessages(); model.beginEmail() }
                legal.padding(.top, 6)
            }
            .disabled(model.isBusy || model.session.isBusy)
            .padding(.horizontal, 24).padding(.top, 12).padding(.bottom, Self.dockBottom)
        case .welcome:
            VStack(spacing: 10) {
                Button { model.finish(tutorial: true, modelContext: modelContext) } label: {
                    HStack { Text("YES, SHOW ME AROUND"); Spacer(); Text("›").font(.archivo(26, weight: .black)) }
                        .font(.archivo(19, weight: .black)).tracking(0.6)
                        .foregroundStyle(SignupSkyColors.ctaInk)
                        .padding(.horizontal, 22).frame(height: 60).frame(maxWidth: .infinity)
                        .background(Color.white).clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(PressOpacityStyle())
                .accessibilityIdentifier(AX.onboarding.tutorialYes)
                Button { model.finish(tutorial: false, modelContext: modelContext) } label: {
                    HStack { Text("SKIP, I'LL EXPLORE MYSELF"); Spacer() }
                        .font(.archivo(15, weight: .black)).tracking(0.6).foregroundStyle(.white)
                        .padding(.horizontal, 22).frame(height: 52).frame(maxWidth: .infinity)
                        .background(SignupSkyColors.secondaryBg)
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(SignupSkyColors.secondaryBorder, lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(PressOpacityStyle())
                .accessibilityIdentifier(AX.onboarding.tutorialSkip)
                Text("TUTORIAL ALWAYS AVAILABLE IN MORE → HELP").font(.spaceMono(9)).tracking(1.5)
                    .foregroundStyle(SignupSkyColors.muted).padding(.top, 4)
            }
            .padding(.horizontal, 24).padding(.top, 12).padding(.bottom, Self.dockBottom)
            .transition(.opacity.combined(with: .offset(y: config.typing.risePt)))
        default:
            EmptyView()
        }
    }

    private func providerButton(_ label: String, id: String, solid: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack { Text(label); Spacer(); Text("›").font(.archivo(22, weight: .black)) }
                .font(.archivo(16, weight: .black)).tracking(0.5)
                .foregroundStyle(solid ? SignupSkyColors.primaryInk : .white)
                .padding(.horizontal, 22).frame(height: 56).frame(maxWidth: .infinity)
                .background(solid ? Color.white : SignupSkyColors.card)
                .overlay { if !solid { RoundedRectangle(cornerRadius: 12).strokeBorder(SignupSkyColors.cardBorder, lineWidth: 1) } }
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(PressOpacityStyle())
        .accessibilityIdentifier(id)
    }

    /// Terms / Privacy are plain text until the hosted URLs exist, then real links.
    private var legal: some View {
        let terms = LegalLinks.terms.map { Text("[Terms of Service](\($0.absoluteString))") } ?? Text("Terms of Service")
        let privacy = LegalLinks.privacy.map { Text("[Privacy Policy](\($0.absoluteString))") } ?? Text("Privacy Policy")
        return (Text("By continuing you agree to our ") + terms + Text(" and ") + privacy + Text("."))
            .font(.archivo(11)).foregroundStyle(SignupSkyColors.ink2)
            .cssLineHeight(fontName: "Archivo-Regular", size: 11, multiple: 1.4)
            .multilineTextAlignment(.center).frame(maxWidth: .infinity)
            .tint(.white)
    }
}

/// A choice: number (or star), label, and a meta pill; see-through like the design's glass card.
private struct ChoiceCard: View {
    let index: Int
    let choice: SignupConfig.Choice
    let height: Double
    let program: Bool
    let delay: Double
    let rise: Double
    let action: () -> Void
    @State private var shown = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Text("\(index + 1)").font(.spaceMono(10, weight: .bold)).foregroundStyle(SignupSkyColors.muted).frame(width: 14)
                Text(choice.label)
                    .font(program ? .archivo(15, weight: .black) : .archivo(16, weight: .semibold))
                    .tracking(program ? 0.3 : 0).textCase(program ? .uppercase : nil)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if !choice.meta.isEmpty { Text(choice.meta).font(.spaceMono(9)).tracking(1.2).foregroundStyle(SignupSkyColors.muted) }
            }
            .padding(.horizontal, 17)   // 16 pt of padding inside the 1 pt border, as in CSS
            .frame(minHeight: height).frame(maxWidth: .infinity)
            .background(SignupSkyColors.card)
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(SignupSkyColors.cardBorder, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(PressOpacityStyle())
        .opacity(shown ? 1 : 0)
        .offset(y: shown ? 0 : rise)
        .onAppear { withAnimation(.easeOut(duration: 0.25).delay(delay)) { shown = true } }
    }
}

/// Pressed = 85 % opacity, as in the design.
struct PressOpacityStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.85 : 1)
    }
}

/// The blinking caret: a 2 × 24 pt white bar after 3 pt of space (the design's `margin-left: 3px`), as an inline image so it
/// follows the end of the last line.
enum SignupCaret {
    static func image(visible: Bool) -> UIImage {
        let size = CGSize(width: 5, height: 24)
        let cached = visible ? on : off
        if let cached { return cached }
        let img = UIGraphicsImageRenderer(size: size).image { ctx in
            guard visible else { return }
            UIColor.white.setFill()
            ctx.fill(CGRect(x: 3, y: 0, width: 2, height: 24))
        }
        if visible { on = img } else { off = img }
        return img
    }
    private static var on: UIImage?
    private static var off: UIImage?
}

/// Keeps the sign-up console's model alive while `RootView` swaps the screen (signed out → the splash while the account is
/// created → onboarding): a reference, so creating it from `body` is fine. Reset once the app is on its main screen.
@MainActor
final class SignupHolder {
    private var model: SignupFlowModel?

    func model(session: AuthSession, remote: ProfileRemote, onCreated: @escaping (String) -> Void) -> SignupFlowModel {
        if let model { return model }
        let m = SignupFlowModel(config: SignupConfigStore.shared.current, session: session, remote: remote,
                                instant: SignupConsoleView.instantTyping, onCreated: onCreated)
        model = m
        return m
    }

    func reset() { model?.cancelTasks(); model = nil }
}
