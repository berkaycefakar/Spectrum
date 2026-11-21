import AuthenticationServices
import SwiftUI

struct AuthView: View {
    @Binding var isAuthenticated: Bool
    var onSuccess: (() -> Void)?

    @StateObject private var sessionStore = SessionStore.shared

    @State private var showEmailLogin = false
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    /// Non-error feedback: "check your inbox", "reset link sent". Green rather than red — the
    /// old screen had no way to say anything that wasn't a failure.
    @State private var infoMessage: String?
    @State private var currentNonce: String?
    @FocusState private var focusedField: Field?

    private enum Field { case email, password }

    // Animation States
    @State private var animateBlobs = false

    var body: some View {
        ZStack {
            // 1. Animated Background
            Color.black.ignoresSafeArea()

            Circle()
                .fill(Color.spectrumAccent.opacity(0.3))
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
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 8) {
            Text("Spectrum")
                .font(.system(size: 40, weight: .heavy))
                .foregroundStyle(.white)
                .shadow(color: .white.opacity(0.5), radius: 10)

            Text("Join the Vibe")
                .font(.title3)
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(.top, 50)
    }

    // MARK: - Form

    /// New accounts come only through Apple or Google (the server's before-user-created hook
    /// refuses email sign-ups). Email + password stays behind a quiet link for accounts that
    /// already have one, such as the App Review demo account.
    private var formCard: some View {
        VStack(spacing: 18) {
            socialButtons

            feedbackMessages

            if showEmailLogin {
                dividerRow

                GlassTextField(icon: "envelope", placeholder: String(localized: "Email", bundle: appStringsBundle), text: $email)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .focused($focusedField, equals: .email)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .password }

                GlassTextField(icon: "lock", placeholder: String(localized: "Password", bundle: appStringsBundle), text: $password, isSecure: true)
                    .textContentType(.password)
                    .focused($focusedField, equals: .password)
                    .submitLabel(.go)
                    .onSubmit(handleAuth)

                primaryButton
            } else {
                Button("Log in with email") {
                    errorMessage = nil
                    showEmailLogin = true
                    focusedField = .email
                }
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.65))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .contentShape(Rectangle())
            }
        }
        .padding(28)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 30))
        .overlay(
            RoundedRectangle(cornerRadius: 30)
                .stroke(.white.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal, 20)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: showEmailLogin)
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
                    Text("Log In")
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
        if let problem = AuthErrorMessage.validate(email: email, password: password, username: nil) {
            withAnimation { errorMessage = problem }
            return
        }

        isLoading = true

        Task {
            do {
                let trimmedEmail = email.trimmingCharacters(in: .whitespaces)
                try await sessionStore.signIn(email: trimmedEmail, password: password)
                await MainActor.run { finishSuccess() }
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
                withAnimation { errorMessage = String(localized: "Apple didn't return a usable sign-in token. Try again.", bundle: appStringsBundle) }
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
