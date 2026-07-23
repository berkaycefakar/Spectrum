import SwiftUI
import Supabase
import PhotosUI

struct EditProfileView: View {
    @Binding var isPresented: Bool
    let currentUsername: String
    let currentBio: String
    let currentAvatarUrl: String?
    let onSave: () -> Void

    @State private var username: String
    @State private var bio: String
    @State private var isLoading = false
    @State private var errorMessage: String?

    // Avatar picking
    @State private var pickerItem: PhotosPickerItem?
    @State private var pickedImageData: Data?
    private let existingAvatarUrl: String?

    init(
        isPresented: Binding<Bool>,
        currentUsername: String,
        currentBio: String,
        currentAvatarUrl: String? = nil,
        onSave: @escaping () -> Void
    ) {
        self._isPresented = isPresented
        self.currentUsername = currentUsername
        self.currentBio = currentBio
        self.currentAvatarUrl = currentAvatarUrl
        self.existingAvatarUrl = currentAvatarUrl
        self.onSave = onSave

        _username = State(initialValue: currentUsername)
        _bio = State(initialValue: currentBio)
    }

    private var trimmedUsername: String {
        username.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 24) {
                // Header with Cancel / Title
                ZStack {
                    Text("Edit Profile")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)

                    HStack {
                        Button("Cancel") { isPresented = false }
                            .foregroundStyle(.white.opacity(0.7))
                        Spacer()
                    }
                }
                .padding(.horizontal)
                .padding(.top, 20)

                // Avatar picker
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    ZStack(alignment: .bottomTrailing) {
                        avatarPreview
                            .frame(width: 104, height: 104)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(.white.opacity(0.15), lineWidth: 1))

                        Image(systemName: "camera.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(8)
                            .background(Color(hex: "#007AFF"))
                            .clipShape(Circle())
                            .overlay(Circle().stroke(.black, lineWidth: 2))
                    }
                }
                .onChange(of: pickerItem) { _, newItem in
                    Task { await loadPickedImage(newItem) }
                }

                VStack(spacing: 20) {
                    // Username Field
                    VStack(alignment: .leading, spacing: 6) {
                        Text("USERNAME")
                            .font(.caption)
                            .foregroundStyle(.gray)

                        TextField("Username", text: $username)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .padding()
                            .background(.white.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .foregroundStyle(.white)
                    }

                    // Bio Field
                    VStack(alignment: .leading, spacing: 6) {
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
                            .multilineTextAlignment(.center)
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
                    .background(trimmedUsername.isEmpty ? Color.white.opacity(0.4) : Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .disabled(isLoading || trimmedUsername.isEmpty)
                }
                .padding()

                Spacer()
            }
        }
    }

    // MARK: - Avatar preview

    @ViewBuilder
    private var avatarPreview: some View {
        if let pickedImageData, let uiImage = UIImage(data: pickedImageData) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else if let existingAvatarUrl, let url = URL(string: existingAvatarUrl) {
            AsyncImage(url: url) { phase in
                if let image = phase.image {
                    image.resizable().aspectRatio(contentMode: .fill)
                } else {
                    avatarPlaceholder
                }
            }
        } else {
            avatarPlaceholder
        }
    }

    private var avatarPlaceholder: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "#FF00FF"), Color(hex: "#00FFFF")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "person.fill")
                .font(.system(size: 40))
                .foregroundStyle(.white)
        }
    }

    private func loadPickedImage(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        if let data = try? await item.loadTransferable(type: Data.self) {
            // Downscale + recompress so we're not uploading a 10MB original.
            let compressed = Self.compressForUpload(data) ?? data
            await MainActor.run { self.pickedImageData = compressed }
        }
    }

    /// Resizes to max 512px and JPEG-compresses, keeping avatar uploads small and fast.
    private static func compressForUpload(_ data: Data) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let maxSide: CGFloat = 512
        let scale = min(1, maxSide / max(image.size.width, image.size.height))
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: newSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        return resized.jpegData(compressionQuality: 0.8)
    }

    // MARK: - Save

    private func saveProfile() {
        let name = trimmedUsername
        guard !name.isEmpty else {
            errorMessage = "Kullanıcı adı boş olamaz."
            return
        }

        isLoading = true
        errorMessage = nil

        Task {
            do {
                guard let user = try await SupabaseManager.shared.getCurrentUser() else { return }

                // Upload the new photo first (if one was picked), then persist the profile.
                var avatarUrl = existingAvatarUrl
                if let pickedImageData {
                    avatarUrl = try await SupabaseManager.shared.uploadAvatar(userId: user.id, imageData: pickedImageData)
                }

                try await SupabaseManager.shared.updateProfile(
                    userId: user.id,
                    username: name,
                    bio: bio,
                    avatarUrl: avatarUrl
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
                        errorMessage = "Bu kullanıcı adı zaten kullanılıyor. Lütfen başka bir kullanıcı adı dene."
                    } else if message.lowercased().contains("bucket") || message.contains("avatars") {
                        errorMessage = "Fotoğraf yüklenemedi. Supabase'de 'avatars' storage bucket'ı oluşturulmalı."
                    } else {
                        errorMessage = "Profil güncellenemedi: \(message)"
                    }
                }
            }
        }
    }
}
