import AuthenticationServices
import SwiftUI

struct AuthView: View {
    @Binding var isAuthenticated: Bool
    var onSuccess: (() -> Void)?

    @StateObject private var sessionStore = SessionStore.shared

    @State private var isLoginMode = true
    @State private var email = ""
    @State private var password = ""
    @State private var username = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    /// Non-error feedback: "check your inbox", "reset link sent". Green rather than red — the
    /// old screen had no way to say anything that wasn't a failure.
    @State private var infoMessage: String?
    @State private var showPasswordResetSheet = false
    @State private var currentNonce: String?
    @FocusState private var focusedField: Field?

    private enum Field { case username, email, password }

    // Animation States
    @State private var animateBlobs = false

    var body: some View {
        ZStack {
            // 1. Animated Background
            Color.black.ignoresSafeArea()

            Circle()
                .fill(Color(hex: "#FF00FF").opacity(0.3))
                .frame(width: 250, height: 250)
                .blur(radius: 50)
                .offset(x: animateBlobs ? -100 : -50, y: animateBlobs ? -200 : -150)
                .animation(.easeInOut(duration: 4).repeatForever(autoreverses: true), value: animateBlobs)

            Circle()
                .fill(Color(hex: "#00FFFF").opacity(0.3))
                .frame(width: 250, height: 250)
                .blur(radius: 50)
                .offset(x: animateBlobs ? 100 : 50, y: animateBlobs ? 200 : 150)
                .animation(.easeInOut(duration: 5).repeatForever(autoreverses: true), value: animateBlobs)

            // Scrollable so the form still reaches the Sign Up button on a small screen with
            // the keyboard up.
            ScrollView {
                VStack(spacing: 24) {
                    header
                    formCard
                    Spacer(minLength: 30)
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .onAppear { animateBlobs = true }
        .sheet(isPresented: $showPasswordResetSheet) {
            PasswordResetView(initialEmail: email)
                .presentationDetents([.height(340)])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 8) {
            Text("Spectrum")
                .font(.system(size: 40, weight: .heavy))
                .foregroundStyle(.white)
                .shadow(color: .white.opacity(0.5), radius: 10)

            Text(isLoginMode ? "Welcome Back" : "Join the Vibe")
                .font(.title3)
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(.top, 50)
    }

    // MARK: - Form

    private var formCard: some View {
        VStack(spacing: 18) {
            Picker("", selection: $isLoginMode) {
                Text("Log In").tag(true)
                Text("Sign Up").tag(false)
            }
            .pickerStyle(.segmented)
            .onChange(of: isLoginMode) { _, _ in
                // Stale feedback from the other mode is just confusing.
                errorMessage = nil
                infoMessage = nil
            }

            if !isLoginMode {
                GlassTextField(icon: "person", placeholder: "Username", text: $username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .username)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .email }
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            GlassTextField(icon: "envelope", placeholder: "Email", text: $email)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.emailAddress)
                .textContentType(.emailAddress)
                .focused($focusedField, equals: .email)
                .submitLabel(.next)
                .onSubmit { focusedField = .password }

            GlassTextField(icon: "lock", placeholder: "Password", text: $password, isSecure: true)
                .textContentType(isLoginMode ? .password : .newPassword)
                .focused($focusedField, equals: .password)
                .submitLabel(.go)
                .onSubmit(handleAuth)

            if isLoginMode {
                Button("Forgot password?") {
                    showPasswordResetSheet = true
                }
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.65))
                .frame(maxWidth: .infinity, alignment: .trailing)
            }

            feedbackMessages

            primaryButton

            dividerRow

            socialButtons
        }
        .padding(28)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 30))
        .overlay(
            RoundedRectangle(cornerRadius: 30)
                .stroke(.white.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal, 20)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isLoginMode)
    }

    @ViewBuilder
    private var feedbackMessages: some View {
        if let errorMessage, !errorMessage.isEmpty {
            messageRow(
                icon: "exclamationmark.triangle.fill",
                text: errorMessage,
                color: Color(hex: "#FF6B6B")
            )
        } else if let infoMessage, !infoMessage.isEmpty {
            messageRow(
                icon: "checkmark.circle.fill",
                text: infoMessage,
                color: Color(hex: "#4CD964")
            )
        }
    }

    private func messageRow(icon: String, text: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
            Text(text)
                .font(.caption)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .foregroundStyle(color)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    /// Every layout modifier lives *inside* the label. Applying `.frame`/`.padding`/
    /// `.background` to the `Button` itself only grows the drawing, not the hit region — the
    /// button then responds solely where the text is, which is what made these feel broken.
    private var primaryButton: some View {
        Button(action: handleAuth) {
            Group {
                if isLoading {
                    ProgressView().tint(.black)
                } else {
                    Text(isLoginMode ? "Log In" : "Create Account")
                        .fontWeight(.bold)
                        .foregroundStyle(.black)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .contentShape(RoundedRectangle(cornerRadius: 16))
        }
        .disabled(isLoading)
        .opacity(isLoading ? 0.7 : 1)
    }

    private var dividerRow: some View {
        HStack(spacing: 12) {
            Rectangle().fill(.white.opacity(0.15)).frame(height: 1)
            Text("or")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.45))
            Rectangle().fill(.white.opacity(0.15)).frame(height: 1)
        }
    }

    private var socialButtons: some View {
        VStack(spacing: 12) {
            SignInWithAppleButton(.continue) { request in
                let nonce = AppleSignInNonce.make()
                currentNonce = nonce
                request.requestedScopes = [.fullName, .email]
                // Apple hashes the nonce into the token; Supabase verifies against the raw
                // value we kept in `currentNonce`.
                request.nonce = AppleSignInNonce.hashed(nonce)
            } onCompletion: { result in
                handleAppleCompletion(result)
            }
            .signInWithAppleButtonStyle(.white)
            .frame(height: 50)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .disabled(isLoading)

            Button(action: handleGoogleSignIn) {
                HStack(spacing: 10) {
                    GoogleGMark(size: 18)
                    Text("Continue with Google")
                        .fontWeight(.semibold)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(.white.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.white.opacity(0.25), lineWidth: 1)
                )
                .contentShape(RoundedRectangle(cornerRadius: 16))
            }
            .disabled(isLoading)
        }
    }

    // MARK: - Actions

    private func handleAuth() {
        focusedField = nil
        errorMessage = nil
        infoMessage = nil

        // Answer the obvious mistakes instantly instead of after a network round-trip.
        if let problem = AuthErrorMessage.validate(
            email: email,
            password: password,
            username: isLoginMode ? nil : username
        ) {
            withAnimation { errorMessage = problem }
            return
        }

        isLoading = true

        Task {
            do {
                let trimmedEmail = email.trimmingCharacters(in: .whitespaces)

                if isLoginMode {
                    try await sessionStore.signIn(email: trimmedEmail, password: password)
                    await MainActor.run { finishSuccess() }
                } else {
                    let outcome = try await sessionStore.signUp(
                        email: trimmedEmail,
                        password: password,
                        username: username.trimmingCharacters(in: .whitespaces)
                    )

                    await MainActor.run {
                        switch outcome {
                        case .signedIn:
                            finishSuccess()
                        case .needsEmailConfirmation:
                            // The project has email confirmation on, so there is genuinely no
                            // session to hand over. Say so instead of appearing to hang.
                            isLoading = false
                            isLoginMode = true
                            password = ""
                            withAnimation {
                                infoMessage = "Account created. Confirm your email, then log in."
                            }
                        }
                    }
                }
            } catch {
                await MainActor.run { fail(with: error) }
            }
        }
    }

    private func handleAppleCompletion(_ result: Result<ASAuthorization, Error>) {
        errorMessage = nil
        infoMessage = nil

        switch result {
        case .failure(let error):
            // Backing out of the sheet is a choice, not an error worth shouting about.
            if (error as? ASAuthorizationError)?.code == .canceled { return }
            fail(with: error)

        case .success(let authorization):
            guard
                let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                let idToken = credential.identityTokenString,
                let nonce = currentNonce
            else {
                withAnimation { errorMessage = "Apple didn't return a usable sign-in token. Try again." }
                return
            }

            isLoading = true
            Task {
                do {
                    try await sessionStore.signInWithApple(
                        idToken: idToken,
                        nonce: nonce,
                        fullName: credential.displayName
                    )
                    await MainActor.run { finishSuccess() }
                } catch {
                    await MainActor.run { fail(with: error) }
                }
            }
        }
    }

    private func handleGoogleSignIn() {
        focusedField = nil
        errorMessage = nil
        infoMessage = nil
        isLoading = true

        Task {
            do {
                try await sessionStore.signInWithGoogle()
                await MainActor.run { finishSuccess() }
            } catch {
                await MainActor.run { fail(with: error) }
            }
        }
    }

    private func finishSuccess() {
        isLoading = false
        isAuthenticated = true
        onSuccess?()
    }

    private func fail(with error: Error) {
        isLoading = false
        let message = AuthErrorMessage.friendly(error)
        guard !message.isEmpty else { return } // user cancelled
        withAnimation { errorMessage = message }
    }
}

// MARK: - Password Reset

/// "I forgot my password" — a separate sheet so the main form stays a single decision.
struct PasswordResetView: View {
    let initialEmail: String

    @Environment(\.dismiss) private var dismiss
    @State private var email: String
    @State private var isSending = false
    @State private var message: String?
    @State private var didSend = false

    init(initialEmail: String) {
        self.initialEmail = initialEmail
        _email = State(initialValue: initialEmail)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 18) {
                Text("Reset your password")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)

                Text("We'll email you a link to set a new one.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))

                GlassTextField(icon: "envelope", placeholder: "Email", text: $email)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)

                if let message {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(didSend ? Color(hex: "#4CD964") : Color(hex: "#FF6B6B"))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button(action: send) {
                    Group {
                        if isSending {
                            ProgressView().tint(.black)
                        } else {
                            Text(didSend ? "Send again" : "Send reset link")
                                .fontWeight(.bold)
                                .foregroundStyle(.black)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .contentShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(isSending)

                Spacer(minLength: 0)
            }
            .padding(24)
        }
    }

    private func send() {
        let trimmed = email.trimmingCharacters(in: .whitespaces)
        guard AuthErrorMessage.isPlausibleEmail(trimmed) else {
            didSend = false
            message = "That email address doesn't look right."
            return
        }

        isSending = true
        message = nil

        Task {
            do {
                try await SessionStore.shared.sendPasswordReset(email: trimmed)
                await MainActor.run {
                    isSending = false
                    didSend = true
                    // Worded so it reveals nothing about whether the address has an account.
                    message = "If that address has an account, the link is on its way."
                }
            } catch {
                await MainActor.run {
                    isSending = false
                    didSend = false
                    message = AuthErrorMessage.friendly(error)
                }
            }
        }
    }
}

// Helper Component
struct GlassTextField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(.white.opacity(0.6))
                .frame(width: 20)

            if isSecure {
                SecureField(placeholder, text: $text)
                    .foregroundStyle(.white)
            } else {
                TextField(placeholder, text: $text)
                    .foregroundStyle(.white)
            }
        }
        .padding()
        .background(.white.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.white.opacity(0.2), lineWidth: 1)
        )
    }
}

#Preview {
    AuthView(isAuthenticated: .constant(false))
}
