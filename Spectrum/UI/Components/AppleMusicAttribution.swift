import SwiftUI

/// Apple's official "Listen on Apple Music" badge, linking to the item. Required where the
/// app shows Apple Music artwork and previews (Apple Music Identity Guidelines; iTunes Search
/// API terms). The badge artwork is Apple's, unmodified (Assets › ListenOnAppleMusic: the
/// white-text "standard-white" badge from tools.applemediaservices.com, rendered to PNG
/// because iOS ignores the SVG CSS fills); don't redraw it, and don't swap it for the bare
/// Apple logo, which the guidelines don't allow on its own.
///
/// Small on purpose: it sits next to the thing it credits (the preview player, the album
/// title) instead of taking a row of its own.
struct AppleMusicBadge: View {
    let url: URL?
    var height: CGFloat = 26

    @Environment(\.openURL) private var openURL

    var body: some View {
        if let url {
            Button { openURL(url) } label: {
                Image("ListenOnAppleMusic")
                    .resizable()
                    .scaledToFit()
                    .frame(height: height)
                    // The badge is small; the hit area reaches past it toward 44pt.
                    .contentShape(Rectangle().inset(by: -10))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Listen on Apple Music", bundle: appStringsBundle))
        }
    }
}

/// The preview credit the iTunes terms ask for, set small under a player.
struct ApplePreviewCredit: View {
    var body: some View {
        Text("Preview provided courtesy of Apple Music.", bundle: appStringsBundle)
            .font(.caption2)
            .foregroundStyle(.white.opacity(0.35))
    }
}
