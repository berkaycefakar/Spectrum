import SwiftUI
import UIKit

struct AddLogView: View {
    let track: Track
    @Binding var isPresented: Bool
    /// When true this is an existing log being edited; skips artwork colour auto-pick so the
    /// user's saved vibe is preserved. Called after a successful save.
    private let isEditing: Bool
    private let onSaved: (() -> Void)?

    init(
        track: Track,
        isPresented: Binding<Bool>,
        editing review: Review? = nil,
        onSaved: (() -> Void)? = nil
    ) {
        self.track = track
        self._isPresented = isPresented
        self.isEditing = review != nil
        self.onSaved = onSaved
        _rating = State(initialValue: review.map { Double($0.rating) / 2.0 } ?? 0)
        _reviewText = State(initialValue: review?.reviewText ?? "")
        _selectedColorHex = State(initialValue: review?.vibeColor ?? "#5AC8FA")
        // Editing an existing log: don't let artwork colour override the saved vibe.
        _hasExtractedColor = State(initialValue: review != nil)
    }

    // Form State
    /// Rating 0...5 (0.5 adımlı). Veritabanına 0...10 tam sayı olarak gönderiyoruz.
    @State private var rating: Double = 0
    @State private var reviewText: String = ""
    // Must be one of `vibeColors` — the prism highlights the selected beam by matching hex,
    // and the old "#FF00FF" default wasn't in the palette so nothing was ever highlighted.
    @State private var selectedColorHex: String = "#5AC8FA"
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var hasExtractedColor = false
    /// The artwork's true colour — drives the ambient glow, independent of the vibe the
    /// user picks from the prism.
    @State private var artworkColor: ArtworkColor = .placeholder
    
    // The "Vibe" Palette
    let vibeColors = [
        "#FF3B30", // Red
        "#FF9500", // Orange
        "#FFCC00", // Yellow
        "#4CD964", // Green
        "#5AC8FA", // Light Blue
        "#007AFF", // Blue
        "#5856D6", // Purple
        "#FF2D55"  // Pink
    ]
    
    // Computed color from hex
    var selectedColor: Color {
        Color(hex: selectedColorHex)
    }
    
    var body: some View {
        ZStack {
            // Background: the artwork's own colour, not the chosen vibe. A monochrome cover
            // now glows neutral instead of being washed in an unrelated hue.
            Color.black.ignoresSafeArea()

            artworkColor.accent
                .opacity(artworkColor.isNeutral ? 0.18 : 0.3)
                .blur(radius: 100)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.5), value: artworkColor.accent)

            // Everything is sized against the available height so the sheet fits on one
            // screen — no scrolling to reach the rating or the save button.
            GeometryReader { geo in
                let height = geo.size.height
                let isCompact = height < 700
                let artworkSide = min(max(height * 0.26, 150), 220)
                let beamHeight = min(max(height * 0.15, 88), 140)

                VStack(spacing: isCompact ? 12 : 18) {
                    // Track Info & Artwork
                    VStack(spacing: isCompact ? 8 : 12) {
                        AsyncImage(url: track.artworkUrl600) { phase in
                            if let image = phase.image {
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } else if phase.error != nil {
                                placeholderView
                            } else {
                                placeholderView
                                    .overlay(ProgressView().tint(.white))
                            }
                        }
                        .frame(width: artworkSide, height: artworkSide)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: artworkColor.accent.opacity(0.6), radius: 20)
                        .animation(.easeInOut(duration: 0.3), value: artworkColor.accent)

                        VStack(spacing: 2) {
                            Text(track.title)
                                .font(isCompact ? .headline : .title3)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                            Text(track.artist)
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.7))
                                .lineLimit(1)
                        }
                        .padding(.horizontal)
                    }

                    // Spectrum Prism Color Picker (full-width, beams go edge-to-edge)
                    SpectrumPrismPicker(
                        selectedHex: $selectedColorHex,
                        vibeColors: vibeColors,
                        onManualPick: {
                            hasExtractedColor = false
                        },
                        beamHeight: beamHeight
                    )

                    // Review Text
                    TextField("What's the vibe?", text: $reviewText, axis: .vertical)
                        .lineLimit(isCompact ? 1...2 : 2...3)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(selectedColor.opacity(0.3), lineWidth: 1)
                        )
                        .padding(.horizontal)

                    // Rating Section with Spectrum Control
                    VStack(spacing: 8) {
                        HStack {
                            Text("Rating")
                                .font(.caption)
                                .textCase(.uppercase)
                                .foregroundStyle(.white.opacity(0.5))

                            Spacer()

                            RatingLabel(rating: rating, maxRating: 5, accentColor: selectedColor)
                        }
                        .padding(.horizontal)

                        // Custom Spectrum Rating Control (color-synced)
                        SpectrumRatingControl(
                            rating: $rating,
                            accentColor: selectedColor
                        )
                    }

                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding(.horizontal)
                            .lineLimit(2)
                    }

                    Spacer(minLength: 0)

                    // Action Buttons
                    HStack(spacing: 12) {
                        Button("Cancel") {
                            isPresented = false
                        }
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(width: 96)
                        .padding(.vertical, 15)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 14))

                        Button(action: saveLog) {
                            if isSaving {
                                ProgressView()
                                    .tint(contrastTextColor)
                            } else {
                                HStack(spacing: 8) {
                                    Image(systemName: "checkmark.circle.fill")
                                    Text(isEditing ? "Update Log" : "Save Log")
                                        .fontWeight(.bold)
                                }
                                .foregroundStyle(contrastTextColor)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(
                            LinearGradient(
                                colors: [selectedColor, selectedColor.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .shadow(color: selectedColor.opacity(0.4), radius: 10)
                        .disabled(isSaving)
                        .animation(.easeInOut(duration: 0.3), value: selectedColorHex)
                    }
                    .padding(.horizontal)
                }
                .padding(.top, isCompact ? 8 : 16)
                .padding(.bottom, 12)
                .frame(width: geo.size.width, height: height)
            }
        }
        .task {
            await extractColorFromURL()
        }
    }
    
    // MARK: - Placeholder View
    private var placeholderView: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color.gray.opacity(0.3))
            .overlay(
                Image(systemName: "music.note")
                    .font(.title)
                    .foregroundStyle(.white.opacity(0.5))
            )
    }
    
    // MARK: - Contrast Text Color
    /// Determines if text should be black or white based on background color brightness
    private var contrastTextColor: Color {
        // Convert hex to RGB and calculate luminance
        let hex = selectedColorHex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard hex.count == 6,
              let rgbValue = Int(hex, radix: 16) else {
            return .black
        }
        
        let red = Double((rgbValue >> 16) & 0xFF) / 255.0
        let green = Double((rgbValue >> 8) & 0xFF) / 255.0
        let blue = Double(rgbValue & 0xFF) / 255.0
        
        // Calculate relative luminance
        let luminance = 0.299 * red + 0.587 * green + 0.114 * blue
        
        return luminance > 0.5 ? .black : .white
    }
    
    // MARK: - Color Extraction
    
    /// Pull the artwork's dominant colour, use it for the ambient glow, and seed the vibe
    /// picker from it.
    private func extractColorFromURL() async {
        let color = await ArtworkColorLoader.shared.color(for: track.artworkUrl600)

        withAnimation(.easeInOut(duration: 0.5)) {
            artworkColor = color
        }

        // Only pre-select a vibe when the artwork actually has one. For a monochrome cover
        // any palette entry would be a guess, so we leave the user's default in place.
        guard !hasExtractedColor, !color.isNeutral else { return }

        let matchedHex = nearestVibeColor(to: color.accent)
        withAnimation(.easeInOut(duration: 0.5)) {
            selectedColorHex = matchedHex
            hasExtractedColor = true
        }
    }

    /// Nearest palette entry to `color`, matched primarily on hue. RGB distance used to
    /// pick oddly — a pale colour is close to *everything* in RGB space, which is how white
    /// artwork ended up on purple.
    private func nearestVibeColor(to color: Color) -> String {
        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
        UIColor(color).getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)

        var nearestColor = vibeColors[0]
        var minDistance = CGFloat.greatestFiniteMagnitude

        for hex in vibeColors {
            var pHue: CGFloat = 0, pSat: CGFloat = 0, pBright: CGFloat = 0, pAlpha: CGFloat = 0
            UIColor(Color(hex: hex)).getHue(&pHue, saturation: &pSat, brightness: &pBright, alpha: &pAlpha)

            // Hue is circular: red at 0.02 and red at 0.98 are neighbours, not opposites.
            let rawDelta = abs(hue - pHue)
            let hueDelta = min(rawDelta, 1 - rawDelta)

            // Hue dominates; saturation breaks ties between similar hues.
            let distance = hueDelta * 3 + abs(saturation - pSat) * 0.5

            if distance < minDistance {
                minDistance = distance
                nearestColor = hex
            }
        }

        return nearestColor
    }
    
    // MARK: - Save Action
    
    func saveLog() {
        guard rating > 0 else {
            errorMessage = "Please add a rating!"
            return
        }
        
        isSaving = true
        errorMessage = nil
        
        Task {
            do {
                // 0...5 (0.5 step) rating -> 0...10 integer
                let storedRating = Int((rating * 2).rounded())
                try await SupabaseManager.shared.saveReview(
                    trackId: track.id,
                    rating: storedRating,
                    text: reviewText,
                    vibeColor: selectedColorHex
                )
                await MainActor.run {
                    isSaving = false
                    isPresented = false
                    onSaved?()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = "Failed to save: \(error.localizedDescription)"
                }
            }
        }
    }
}

#Preview {
    AddLogView(
        track: Track(id: 1, title: "Random Access Memories", artist: "Daft Punk", artworkUrl100: "https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/9b/6e/81/9b6e8198-315f-5100-3622-261548e69f87/source/100x100bb.jpg", previewUrl: nil),
        isPresented: .constant(true)
    )
}
