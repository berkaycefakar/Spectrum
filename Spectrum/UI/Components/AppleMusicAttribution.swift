import SwiftUI

/// Apple's official "Listen on Apple Music" badge, linking to the item, with the preview
/// credit. Required where the app shows Apple Music artwork and previews (Apple Music
/// Identity Guidelines; iTunes Search API terms). The badge artwork is Apple's, unmodified
/// (Assets › ListenOnAppleMusic: the white-text "standard-white" badge from tools.applemediaservices.com, rendered to PNG because iOS ignores the SVG CSS fills); don't redraw it.
struct AppleMusicAttribution: View {
    let url: URL?
    /// Adds "Preview provided courtesy of Apple Music." under the badge.
    var showsPreviewCredit = true

    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: 8) {
            if let url {
                Button { openURL(url) } label: {
                    Image("ListenOnAppleMusic")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 40)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Listen on Apple Music", bundle: appStringsBundle))
            }
            if showsPreviewCredit {
                Text("Preview provided courtesy of Apple Music.", bundle: appStringsBundle)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
        .frame(maxWidth: .infinity)
    }
}
