import SwiftUI
import Supabase

/// Sanatçı detay ekranı: sanatçı adı ve puanlama (artist_reviews).
struct ArtistDetailView: View {
    let artistName: String
    
    @State private var artistRating: Double = 0
    @State private var isSaving = false
    @State private var userArtistReview: ArtistReview?
    
    private let accentColor = Color(hex: "#FF00FF")
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            Circle()
                .fill(accentColor.opacity(0.2))
                .frame(width: 280, height: 280)
                .blur(radius: 80)
                .offset(x: 80, y: -120)
            
            ScrollView {
                VStack(spacing: 28) {
                    heroSection
                    ratingSection
                }
                .padding(.top, 24)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadUserArtistReview()
        }
    }
    
    private var heroSection: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(accentColor.opacity(0.35))
                    .frame(width: 140, height: 140)
                    .blur(radius: 30)
                
                Circle()
                    .fill(accentColor.opacity(0.2))
                    .frame(width: 120, height: 120)
                
                Text(String(artistName.prefix(1)).uppercased())
                    .font(.system(size: 48, weight: .bold))
                    .foregroundStyle(accentColor)
            }
            
            VStack(spacing: 6) {
                Text(artistName)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                
                Text("Artist")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .padding(.horizontal)
    }
    
    private var ratingSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Your rating")
                    .font(.caption)
                    .textCase(.uppercase)
                    .foregroundStyle(.white.opacity(0.5))
                Spacer()
                RatingLabel(rating: artistRating, maxRating: 5, accentColor: accentColor)
            }
            
            SpectrumRatingControl(
                rating: $artistRating,
                accentColor: accentColor
            )
            .onChange(of: artistRating) { _, newValue in
                if newValue > 0 {
                    saveArtistRating()
                }
            }
            
            if isSaving {
                HStack(spacing: 8) {
                    ProgressView().tint(.white.opacity(0.6))
                    Text("Saving...")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
            } else if userArtistReview != nil {
                Text("Rating saved")
                    .font(.footnote)
                    .foregroundStyle(accentColor.opacity(0.9))
            }
        }
        .padding(.horizontal, 24)
    }
    
    private func loadUserArtistReview() async {
        guard let user = try? await SupabaseManager.shared.getCurrentUser() else { return }
        
        do {
            let reviews = try await SupabaseManager.shared.getUserArtistReviews(userId: user.id)
            if let review = reviews.first(where: { $0.artistName == artistName }) {
                await MainActor.run {
                    userArtistReview = review
                    artistRating = Double(review.rating) / 2.0
                }
            }
        } catch {
            print("Failed to load artist review: \(error)")
        }
    }
    
    private func saveArtistRating() {
        guard !isSaving, artistRating > 0 else { return }
        isSaving = true
        
        Task {
            do {
                let storedRating = Int((artistRating * 2).rounded())
                try await SupabaseManager.shared.saveArtistReview(
                    artistName: artistName,
                    rating: storedRating,
                    text: "",
                    vibeColor: "#FF00FF"
                )
                await loadUserArtistReview()
                await MainActor.run { isSaving = false }
            } catch {
                await MainActor.run { isSaving = false }
                print("Failed to save artist rating: \(error)")
            }
        }
    }
}

#Preview {
    NavigationStack {
        ArtistDetailView(artistName: "Daft Punk")
    }
}
