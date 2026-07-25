import SwiftUI

/// "Choose a new password".
///
/// Serves two entry points on purpose:
/// - `.recovery` — the user followed a reset link. This is *modal and unskippable-by-accident*
///   because the link has already signed them in; if they just close it, the password they
///   forgot is still the live one.
/// - `.change` — an ordinary "change my password" from Settings. This is also the reliable
///   fallback if recovery-link detection ever fails on a future Supabase flow change.
struct NewPasswordView: View {
    enum Mode {
        case recovery
        case change

        var title: String {
            switch self {
            case .recovery: return "Choose a new password"
            case .change: return "Change password"
            }
        }

        var subtitle: String {
            switch self {
            case .recovery:
                return "You're signed in from the reset link. Set a new password to finish — until you do, your old one still works."
            case .change:
                return "Pick something you haven't used here before."
            }
        }
    }

    let mode: Mode
    var onFinished: () -> Void

    @State private var password = ""
    @State private var confirmation = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var didSucceed = false
    @FocusState private var focusedField: Field?

    private enum Field { case password, confirmation }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            Circle()
                .fill(Color(hex: "#5856D6").opacity(0.3))
                .frame(width: 260, height: 260)
                .blur(radius: 60)
                .offset(x: -90, y: -220)
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(mode.title)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)

                        Text(mode.subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.6))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 12)

                    GlassTextField(icon: "lock", placeholder: "New password", text: $password, isSecure: true)
                        .textContentType(.newPassword)
                        .focused($focusedField, equals: .password)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .confirmation }

                    GlassTextField(icon: "lock.rotation", placeholder: "Repeat new password", text: $confirmation, isSecure: true)
                        .textContentType(.newPassword)
                        .focused($focusedField, equals: .confirmation)
                        .submitLabel(.go)
                        .onSubmit(save)

                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(Color(hex: "#FF6B6B"))
                            .fixedSize(horizontal: false, vertical: true)
                    } else if didSucceed {
                        Label("Password updated.", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(Color(hex: "#4CD964"))
                    }

                    Button(action: save) {
                        Group {
                            if isSaving {
                                ProgressView().tint(.black)
                            } else {
                                Text("Save new password")
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
                    .disabled(isSaving)

                    // Recovery has no harmless "skip": leaving without setting a password means
                    // the account still has the forgotten one, so the way out is to sign out.
                    Button(mode == .recovery ? "Cancel and sign out" : "Cancel") {
                        cancel()
                    }
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.55))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .disabled(isSaving)

                    Spacer(minLength: 0)
                }
                .padding(24)
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }

    private func save() {
        focusedField = nil

        guard password.count >= 6 else {
            errorMessage = "Use a password of at least 6 characters."
            return
        }
        guard password == confirmation else {
            errorMessage = "The two passwords don't match."
            return
        }

        isSaving = true
        errorMessage = nil

        Task {
            do {
                try await SessionStore.shared.updatePassword(password)
                await MainActor.run {
                    isSaving = false
                    didSucceed = true
                    onFinished()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = AuthErrorMessage.friendly(error)
                }
            }
        }
    }

    private func cancel() {
        switch mode {
        case .recovery:
            Task {
                await SessionStore.shared.signOut()
                await MainActor.run {
                    SessionStore.shared.endPasswordRecovery()
                    onFinished()
                }
            }
        case .change:
            onFinished()
        }
    }
}

#Preview {
    NewPasswordView(mode: .recovery, onFinished: {})
}
