import SwiftUI

struct FollowersFollowingListView: View {
    let title: String
    let profiles: [Profile]
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                if profiles.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "person.2")
                            .font(.system(size: 40))
                            .foregroundStyle(.white.opacity(0.3))
                        
                        Text("No users yet")
                            .foregroundStyle(.white.opacity(0.6))
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(profiles) { profile in
                                UserRow(profile: profile)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    FollowersFollowingListView(
        title: "Followers",
        profiles: [
            Profile(id: UUID(), username: "testuser", avatarUrl: nil, bio: "Music fan")
        ]
    )
}

