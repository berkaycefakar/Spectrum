import SwiftUI

struct LogDetailView: View {
    let track: Track
    let review: Review
    /// Only the log's owner sees edit/delete controls. Others viewing this log from a profile
    /// see it read-only.
    var isOwner: Bool = false
    /// Called after the owner edits or deletes, so the presenting screen can refresh.
    var onChanged: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var showEditSheet = false
    @State private var showDeleteAlert = false
    @State private var isDeleting = false

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
                        // Rating (stored as 0-10, display as 0-5)
                        HStack(spacing: 8) {
                            let displayRating = Double(review.rating) / 2.0
                            ForEach(1...5, id: \.self) { index in
                                Image(systemName: Double(index) <= displayRating ? "star.fill" : (Double(index) - 0.5 <= displayRating ? "star.leadinghalf.filled" : "star"))
                                    .font(.title2)
                                    .foregroundStyle(Double(index) <= displayRating + 0.5 ? .yellow : .gray.opacity(0.5))
                            }
                            Text(String(format: "%.1f", displayRating))
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white.opacity(0.7))
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
        .toolbar {
            if isOwner {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showEditSheet = true
                        } label: {
                            Label("Edit Log", systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            showDeleteAlert = true
                        } label: {
                            Label("Delete Log", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundStyle(.white)
                    }
                }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            AddLogView(track: track, isPresented: $showEditSheet, editing: review, onSaved: {
                // The edited values live in `review` (a let), so the simplest correct refresh
                // is to pop back and let the profile reload.
                onChanged?()
                dismiss()
            })
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .alert("Delete Log", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) { deleteLog() }
        } message: {
            Text("This will remove your log for \"\(track.title)\". This can't be undone.")
        }
    }

    private func deleteLog() {
        guard !isDeleting else { return }
        isDeleting = true
        Task {
            do {
                try await SupabaseManager.shared.deleteReview(trackId: Int64(track.id))
                await MainActor.run {
                    onChanged?()
                    dismiss()
                }
            } catch {
                await MainActor.run { isDeleting = false }
                print("Failed to delete log: \(error)")
            }
        }
    }
}
