import SwiftUI
import UIKit

struct AddLogView: View {
    let track: Track
    @Binding var isPresented: Bool
    
    // Form State
    /// Rating 0...5 (0.5 adımlı). Veritabanına 0...10 tam sayı olarak gönderiyoruz.
    @State private var rating: Double = 0
    @State private var reviewText: String = ""
    @State private var selectedColorHex: String = "#FF00FF" // Default Neon Purple
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var hasExtractedColor = false
    
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
            // Background: Blurred version of the selected vibe
            Color.black.ignoresSafeArea()
            
            selectedColor
                .opacity(0.3)
                .blur(radius: 100)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.5), value: selectedColorHex)
            
            ScrollView {
                VStack(spacing: 24) {
                    // Drag Indicator
                    Capsule()
                        .fill(.white.opacity(0.2))
                        .frame(width: 40, height: 5)
                        .padding(.top, 10)
                    
                    // Track Info & Artwork
                    VStack(spacing: 16) {
                        AsyncImage(url: track.artworkUrl600) { phase in
                            if let image = phase.image {
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .onAppear {
                                        // Extract color from artwork when image loads
                                        extractColorFromImage(phase: phase)
                                    }
                            } else if phase.error != nil {
                                placeholderView
                            } else {
                                placeholderView
                                    .overlay(ProgressView().tint(.white))
                            }
                        }
                        .frame(width: 160, height: 160)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: selectedColor.opacity(0.6), radius: 20)
                        .animation(.easeInOut(duration: 0.3), value: selectedColorHex)
                        
                        VStack(spacing: 4) {
                            Text(track.title)
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.center)
                            Text(track.artist)
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                    
                    Divider().background(.white.opacity(0.1))
                    
                    // Color Picker (The "Vibe")
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Choose your Vibe")
                                .font(.caption)
                                .textCase(.uppercase)
                                .foregroundStyle(.white.opacity(0.5))
                            
                            Spacer()
                            
                            if hasExtractedColor {
                                Text("Auto-picked from artwork")
                                    .font(.caption2)
                                    .foregroundStyle(selectedColor.opacity(0.8))
                            }
                        }
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 15) {
                            ForEach(vibeColors, id: \.self) { hex in
                                Circle()
                                    .fill(Color(hex: hex))
                                    .frame(width: 44, height: 44)
                                    .overlay(
                                        Circle()
                                            .stroke(.white, lineWidth: selectedColorHex == hex ? 3 : 0)
                                    )
                                    .shadow(color: Color(hex: hex).opacity(selectedColorHex == hex ? 0.8 : 0.3), radius: selectedColorHex == hex ? 10 : 5)
                                    .scaleEffect(selectedColorHex == hex ? 1.1 : 1.0)
                                    .animation(.spring(response: 0.3), value: selectedColorHex)
                                    .onTapGesture {
                                        withAnimation(.spring(response: 0.3)) {
                                            selectedColorHex = hex
                                            hasExtractedColor = false // User overrode auto-pick
                                        }
                                    }
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // Review Text
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your Thoughts")
                            .font(.caption)
                            .textCase(.uppercase)
                            .foregroundStyle(.white.opacity(0.5))
                        
                        TextField("What's the vibe?", text: $reviewText, axis: .vertical)
                            .lineLimit(3...6)
                            .padding()
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .foregroundStyle(.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(selectedColor.opacity(0.3), lineWidth: 1)
                            )
                    }
                    .padding(.horizontal)
                    
                    // Rating Section with Spectrum Control
                    VStack(spacing: 12) {
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
                    }
                    
                    Spacer(minLength: 20)
                    
                    // Action Buttons
                    VStack(spacing: 12) {
                        // Save Button (color-synced)
                        Button(action: saveLog) {
                            if isSaving {
                                ProgressView()
                                    .tint(contrastTextColor)
                            } else {
                                HStack(spacing: 8) {
                                    Image(systemName: "checkmark.circle.fill")
                                    Text("Save Log")
                                        .fontWeight(.bold)
                                }
                                .foregroundStyle(contrastTextColor)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
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
                        
                        // Cancel Button
                        Button("Cancel") {
                            isPresented = false
                        }
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(.vertical, 8)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 30)
                }
            }
            .scrollIndicators(.visible)
        }
        .task {
            // Also try to extract color on appear if URL is available
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
    
    /// Extract color from AsyncImage phase
    private func extractColorFromImage(phase: AsyncImagePhase) {
        guard !hasExtractedColor, case .success(let image) = phase else { return }
        
        // Convert SwiftUI Image to UIImage using snapshot
        // This is a workaround since AsyncImage doesn't directly provide UIImage
        // For better performance, we extract from URL instead
    }
    
    /// Extract dominant color from artwork URL
    private func extractColorFromURL() async {
        guard !hasExtractedColor, let url = track.artworkUrl600 else { return }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let uiImage = UIImage(data: data) else { return }
            
            if let averageColor = uiImage.averageColor {
                let matchedHex = findNearestVibeColor(from: averageColor)
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        self.selectedColorHex = matchedHex
                        self.hasExtractedColor = true
                    }
                }
            }
        } catch {
            print("Failed to extract color: \(error)")
            // Fallback: keep default color
        }
    }
    
    /// Find the nearest vibe color from our palette
    private func findNearestVibeColor(from color: UIColor) -> String {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        var nearestColor = vibeColors[0]
        var minDistance: CGFloat = .greatestFiniteMagnitude
        
        for hex in vibeColors {
            let paletteColor = UIColor(Color(hex: hex))
            var pRed: CGFloat = 0
            var pGreen: CGFloat = 0
            var pBlue: CGFloat = 0
            var pAlpha: CGFloat = 0
            paletteColor.getRed(&pRed, green: &pGreen, blue: &pBlue, alpha: &pAlpha)
            
            // Calculate Euclidean distance in RGB space
            let distance = sqrt(
                pow(red - pRed, 2) +
                pow(green - pGreen, 2) +
                pow(blue - pBlue, 2)
            )
            
            if distance < minDistance {
                minDistance = distance
                nearestColor = hex
            }
        }
        
        return nearestColor
        // TODO: Better color clustering using LAB color space for perceptual accuracy
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
