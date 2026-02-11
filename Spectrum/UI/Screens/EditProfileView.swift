import SwiftUI
import Supabase

struct EditProfileView: View {
    @Binding var isPresented: Bool
    let currentUsername: String
    let currentBio: String
    let onSave: () -> Void
    
    @State private var username: String
    @State private var bio: String
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    init(isPresented: Binding<Bool>, currentUsername: String, currentBio: String, onSave: @escaping () -> Void) {
        self._isPresented = isPresented
        self.currentUsername = currentUsername
        self.currentBio = currentBio
        self.onSave = onSave
        
        _username = State(initialValue: currentUsername)
        _bio = State(initialValue: currentBio)
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 24) {
                Text("Edit Profile")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .padding(.top, 20)
                
                VStack(spacing: 20) {
                    // Username Field
                    VStack(alignment: .leading) {
                        Text("USERNAME")
                            .font(.caption)
                            .foregroundStyle(.gray)
                        
                        TextField("Username", text: $username)
                            .padding()
                            .background(.white.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .foregroundStyle(.white)
                    }
                    
                    // Bio Field
                    VStack(alignment: .leading) {
                        Text("BIO")
                            .font(.caption)
                            .foregroundStyle(.gray)
                        
                        TextField("Tell us about yourself...", text: $bio, axis: .vertical)
                            .lineLimit(3...6)
                            .padding()
                            .background(.white.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .foregroundStyle(.white)
                    }
                    
                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    
                    Button(action: saveProfile) {
                        if isLoading {
                            ProgressView().tint(.black)
                        } else {
                            Text("Save Changes")
                                .fontWeight(.bold)
                                .foregroundStyle(.black)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .disabled(isLoading)
                }
                .padding()
                
                Spacer()
            }
        }
    }
    
    private func saveProfile() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                guard let user = try await SupabaseManager.shared.getCurrentUser() else { return }
                
                try await SupabaseManager.shared.updateProfile(
                    userId: user.id,
                    username: username,
                    bio: bio
                )
                
                await MainActor.run {
                    isLoading = false
                    onSave()
                    isPresented = false
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    let message = error.localizedDescription
                    if message.contains("profiles_username_key") || message.contains("duplicate key value") {
                        // Kullanıcı dostu hata: kullanıcı adı zaten alınmış.
                        errorMessage = "Bu kullanıcı adı zaten kullanılıyor. Lütfen başka bir kullanıcı adı dene."
                    } else {
                        errorMessage = "Profil güncellenemedi: \(message)"
                    }
                }
            }
        }
    }
}
