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
    
    // Animation States
    @State private var animateBlobs = false
    
    var body: some View {
        ZStack {
            // 1. Animated Background
            Color.black.ignoresSafeArea()
            
            // Blob 1 (Purple)
            Circle()
                .fill(Color(hex: "#FF00FF").opacity(0.4))
                .frame(width: 300, height: 300)
                .blur(radius: 60)
                .offset(x: animateBlobs ? -100 : -50, y: animateBlobs ? -200 : -150)
                .animation(.easeInOut(duration: 4).repeatForever(autoreverses: true), value: animateBlobs)
            
            // Blob 2 (Blue)
            Circle()
                .fill(Color(hex: "#00FFFF").opacity(0.4))
                .frame(width: 300, height: 300)
                .blur(radius: 60)
                .offset(x: animateBlobs ? 100 : 50, y: animateBlobs ? 200 : 150)
                .animation(.easeInOut(duration: 5).repeatForever(autoreverses: true), value: animateBlobs)
            
            VStack(spacing: 30) {
                // Header
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
                
                // Form Container
                VStack(spacing: 20) {
                    // Mode Switcher
                    Picker("", selection: $isLoginMode) {
                        Text("Log In").tag(true)
                        Text("Sign Up").tag(false)
                    }
                    .pickerStyle(.segmented)
                    .padding(.bottom, 10)
                    
                    if !isLoginMode {
                        GlassTextField(icon: "person", placeholder: "Username", text: $username)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    
                    GlassTextField(icon: "envelope", placeholder: "Email", text: $email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                    
                    GlassTextField(icon: "lock", placeholder: "Password", text: $password, isSecure: true)
                    
                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    Button(action: handleAuth) {
                        if isLoading {
                            ProgressView()
                                .tint(.black)
                        } else {
                            Text(isLoginMode ? "Log In" : "Create Account")
                                .fontWeight(.bold)
                                .foregroundStyle(.black)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.top, 10)
                    .disabled(isLoading)
                }
                .padding(30)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 30))
                .overlay(
                    RoundedRectangle(cornerRadius: 30)
                        .stroke(.white.opacity(0.2), lineWidth: 1)
                )
                .padding(.horizontal, 20)
                .animation(.spring(), value: isLoginMode)
                
                Spacer()
            }
        }
        .onAppear {
            animateBlobs = true
        }
    }
    
    private func handleAuth() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                if isLoginMode {
                    try await sessionStore.signIn(email: email, password: password)
                } else {
                    guard !username.isEmpty else {
                        await MainActor.run {
                            errorMessage = "Username is required"
                            isLoading = false
                        }
                        return
                    }
                    try await sessionStore.signUp(email: email, password: password, username: username)
                }
                
                await MainActor.run {
                    isLoading = false
                    isAuthenticated = true
                    onSuccess?()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
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
