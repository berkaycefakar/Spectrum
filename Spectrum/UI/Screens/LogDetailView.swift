import SwiftUI

struct LogDetailView: View {
    let track: Track
    let review: Review
    
    var vibeColor: Color {
        Color(hex: review.vibeColor)
    }
    
    var body: some View {
        ZStack {
            // 1. Dynamic Background
            Color.black.ignoresSafeArea()
            
            // Ambient Glow
            Circle()
                .fill(vibeColor.opacity(0.4))
                .frame(width: 400, height: 400)
                .blur(radius: 120)
                .offset(y: -200)
            
            ScrollView {
                VStack(spacing: 30) {
                    // Artwork
                    AsyncImage(url: track.artworkUrl600) { phase in
                        if let image = phase.image {
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } else {
                            Color.gray.opacity(0.3)
                        }
                    }
                    .frame(width: 250, height: 250)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(.white.opacity(0.2), lineWidth: 1)
                    )
                    .shadow(color: vibeColor.opacity(0.6), radius: 30)
                    .padding(.top, 40)
                    
                    // Title & Artist
                    VStack(spacing: 8) {
                        Text(track.title)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                        
                        Text(track.artist)
                            .font(.title3)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    
                    // The Glass Card (Review Details)
                    VStack(spacing: 24) {
                        // Rating
                        HStack(spacing: 8) {
                            ForEach(1...5, id: \.self) { index in
                                Image(systemName: index <= review.rating ? "star.fill" : "star")
                                    .font(.title2)
                                    .foregroundStyle(index <= review.rating ? .yellow : .gray.opacity(0.5))
                            }
                        }
                        
                        Divider().background(.white.opacity(0.2))
                        
                        // Review Text
                        if let text = review.reviewText, !text.isEmpty {
                            Text(text)
                                .font(.body)
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.center)
                                .lineSpacing(6)
                        } else {
                            Text("No written review.")
                                .font(.body)
                                .foregroundStyle(.white.opacity(0.5))
                                .italic()
                        }
                        
                        // Date
                        Text("Logged on \(review.createdAt.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.4))
                            .padding(.top, 10)
                    }
                    .padding(30)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 30))
                    .overlay(
                        RoundedRectangle(cornerRadius: 30)
                            .stroke(
                                LinearGradient(
                                    colors: [vibeColor.opacity(0.5), .white.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    )
                    .padding(.horizontal, 20)
                    
                    Spacer(minLength: 50)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}
