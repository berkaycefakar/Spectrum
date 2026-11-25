import SwiftUI

struct SpectrumPrismPicker: View {
    @Binding var selectedHex: String
    let vibeColors: [String]
    var onManualPick: (() -> Void)?
    /// Beam area height. Shrinks on compact screens so the log sheet fits without scrolling.
    var beamHeight: CGFloat = 160

    private var selectedIndex: Int {
        vibeColors.firstIndex(of: selectedHex) ?? 0
    }

    private let fanDegrees: Double = 28

    var body: some View {
        VStack(spacing: 10) {
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                let prismSide: CGFloat = 70
                let prismH: CGFloat = prismSide * 1.15
                let prismCX = w * 0.30
                let prismCY = h * 0.50
                let entryPt = CGPoint(x: prismCX - prismSide * 0.25, y: prismCY)
                let exitPt  = CGPoint(x: prismCX + prismSide * 0.25, y: prismCY)

                ZStack {
                    // ── White beam ──
                    // Rises slightly from the lower left into the prism's left face, like the
                    // album cover it nods to, and widens as it travels: thin and far at the
                    // edge of the screen, brightest where it meets the glass.
                    let beamStart = CGPoint(x: -30, y: prismCY + prismH * 0.32)

                    // Soft halo
                    Path { p in
                        p.move(to: CGPoint(x: beamStart.x, y: beamStart.y - 3))
                        p.addLine(to: CGPoint(x: entryPt.x, y: entryPt.y - 5))
                        p.addLine(to: CGPoint(x: entryPt.x, y: entryPt.y + 5))
                        p.addLine(to: CGPoint(x: beamStart.x, y: beamStart.y + 3))
                        p.closeSubpath()
                    }
                    .fill(LinearGradient(colors: [.white.opacity(0.02), .white.opacity(0.16)], startPoint: .leading, endPoint: .trailing))
                    .blur(radius: 5)

                    // Core
                    Path { p in
                        p.move(to: CGPoint(x: beamStart.x, y: beamStart.y - 0.6))
                        p.addLine(to: CGPoint(x: entryPt.x, y: entryPt.y - 1.6))
                        p.addLine(to: CGPoint(x: entryPt.x, y: entryPt.y + 1.6))
                        p.addLine(to: CGPoint(x: beamStart.x, y: beamStart.y + 0.6))
                        p.closeSubpath()
                    }
                    .fill(LinearGradient(colors: [.white.opacity(0.55), .white], startPoint: .leading, endPoint: .trailing))
                    .shadow(color: .white.opacity(0.6), radius: 3)

                    // ── Rainbow beams (extend past right edge) ──

                    ForEach(Array(vibeColors.enumerated()), id: \.offset) { idx, hex in
                        let isSelected = hex == selectedHex

                        beamShape(index: idx, total: vibeColors.count, from: exitPt, width: w)
                            .fill(Color(hex: hex).opacity(isSelected ? 0.9 : 0.18))
                            .shadow(
                                color: Color(hex: hex).opacity(isSelected ? 0.6 : 0),
                                radius: isSelected ? 8 : 0
                            )
                    }

                    // ── Glass Prism ──

                    // Dark glass body: the beams behind it stay faintly visible through it.
                    PrismTriangle()
                        .fill(.ultraThinMaterial)
                        .frame(width: prismSide, height: prismH)
                        .position(x: prismCX, y: prismCY)
                    PrismTriangle()
                        .fill(LinearGradient(
                            colors: [.white.opacity(0.10), .black.opacity(0.35)],
                            startPoint: .top,
                            endPoint: .bottom
                        ))
                        .frame(width: prismSide, height: prismH)
                        .position(x: prismCX, y: prismCY)

                    // Light crossing the glass: white at the left face, splitting by the right.
                    Path { p in
                        p.move(to: CGPoint(x: entryPt.x, y: entryPt.y - 1.5))
                        p.addLine(to: CGPoint(x: exitPt.x, y: exitPt.y - 7))
                        p.addLine(to: CGPoint(x: exitPt.x, y: exitPt.y + 7))
                        p.addLine(to: CGPoint(x: entryPt.x, y: entryPt.y + 1.5))
                        p.closeSubpath()
                    }
                    .fill(LinearGradient(
                        colors: [.white.opacity(0.45)] + vibeColors.map { Color(hex: $0).opacity(0.22) },
                        startPoint: .leading,
                        endPoint: .trailing
                    ))
                    .blur(radius: 2)

                    // Where the beam strikes the glass: a small, bright flare on the face.
                    Circle()
                        .fill(RadialGradient(colors: [.white, .white.opacity(0)], center: .center, startRadius: 0, endRadius: 10))
                        .frame(width: 20, height: 20)
                        .position(entryPt)
                    Capsule()
                        .fill(.white.opacity(0.5))
                        .frame(width: 1.5, height: 16)
                        .blur(radius: 1)
                        .rotationEffect(.degrees(-30))
                        .position(entryPt)

                    // Colours leaving the right face
                    Ellipse()
                        .fill(LinearGradient(
                            colors: vibeColors.map { Color(hex: $0).opacity(0.35) },
                            startPoint: .top,
                            endPoint: .bottom
                        ))
                        .frame(width: 8, height: 26)
                        .blur(radius: 4)
                        .position(x: exitPt.x, y: exitPt.y)

                    // Crisp edges: bright along the top, fading toward the base.
                    PrismTriangle()
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.9), .white.opacity(0.35)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            style: StrokeStyle(lineWidth: 2, lineJoin: .round)
                        )
                        .frame(width: prismSide, height: prismH)
                        .position(x: prismCX, y: prismCY)
                        .shadow(color: .white.opacity(0.25), radius: 4)

                    // Inner bevel, a hairline just inside the edge, so the glass has depth.
                    PrismTriangle()
                        .stroke(.white.opacity(0.12), style: StrokeStyle(lineWidth: 1, lineJoin: .round))
                        .frame(width: prismSide - 12, height: prismH - 12)
                        .position(x: prismCX, y: prismCY + 3)

                    // ── Gesture layer ──
                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { v in
                                    pickBeam(at: v.location, exit: exitPt, size: geo.size)
                                }
                        )
                }
            }
            .frame(height: beamHeight)

            // No name under the prism: the colour is the choice. VoiceOver still reads the
            // vibe's name from the accessibility value.
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Vibe", bundle: appStringsBundle))
        .accessibilityValue(VibePalette.label(for: selectedHex))
        .accessibilityAdjustableAction { direction in
            guard !vibeColors.isEmpty else { return }
            let next = direction == .increment ? selectedIndex + 1 : selectedIndex - 1
            selectedHex = vibeColors[(next + vibeColors.count) % vibeColors.count]
            onManualPick?()
        }
    }

    // MARK: - Beam Geometry

    private func beamShape(index: Int, total: Int, from exit: CGPoint, width: CGFloat) -> Path {
        let half = fanDegrees / 2
        let step = fanDegrees / Double(total - 1)
        let center = -half + step * Double(index)
        let hw = step * 0.42

        let aTop = (center - hw) * .pi / 180
        let aBot = (center + hw) * .pi / 180
        let len = width - exit.x + 50

        return Path { p in
            p.move(to: exit)
            p.addLine(to: CGPoint(
                x: exit.x + len * cos(aTop),
                y: exit.y + len * sin(aTop)
            ))
            p.addLine(to: CGPoint(
                x: exit.x + len * cos(aBot),
                y: exit.y + len * sin(aBot)
            ))
            p.closeSubpath()
        }
    }

    // MARK: - Gesture

    private func pickBeam(at point: CGPoint, exit: CGPoint, size: CGSize) {
        let dx = point.x - exit.x
        let dy = point.y - exit.y
        guard dx > -20 else { return }

        let angle = atan2(dy, max(dx, 1)) * 180 / .pi
        let half = fanDegrees / 2
        let step = fanDegrees / Double(vibeColors.count - 1)
        let idx = Int(((angle + half) / step).rounded())
        let clamped = max(0, min(vibeColors.count - 1, idx))

        if vibeColors[clamped] != selectedHex {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                selectedHex = vibeColors[clamped]
            }
            onManualPick?()
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }

}

// MARK: - Prism Shape

struct PrismTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.midX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            p.closeSubpath()
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        SpectrumPrismPicker(
            selectedHex: .constant("#5AC8FA"),
            vibeColors: VibePalette.colors
        )
        .padding(.vertical, 24)
    }
}
