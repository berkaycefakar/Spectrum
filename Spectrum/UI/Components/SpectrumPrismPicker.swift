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
                    // ── White beam (extends past left edge) ──
                    
                    // Glow layer
                    Path { p in
                        p.move(to: CGPoint(x: -30, y: h / 2 - 5))
                        p.addLine(to: CGPoint(x: entryPt.x, y: entryPt.y - 1.5))
                        p.addLine(to: CGPoint(x: entryPt.x, y: entryPt.y + 1.5))
                        p.addLine(to: CGPoint(x: -30, y: h / 2 + 5))
                        p.closeSubpath()
                    }
                    .fill(.white.opacity(0.08))
                    .blur(radius: 4)

                    // Core beam
                    Path { p in
                        p.move(to: CGPoint(x: -30, y: h / 2 - 1.5))
                        p.addLine(to: CGPoint(x: entryPt.x, y: entryPt.y - 0.3))
                        p.addLine(to: CGPoint(x: entryPt.x, y: entryPt.y + 0.3))
                        p.addLine(to: CGPoint(x: -30, y: h / 2 + 1.5))
                        p.closeSubpath()
                    }
                    .fill(.white.opacity(0.9))
                    .shadow(color: .white.opacity(0.5), radius: 4)

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

                    // Base glass material
                    PrismTriangle()
                        .fill(.ultraThinMaterial)
                        .frame(width: prismSide, height: prismH)
                        .position(x: prismCX, y: prismCY)

                    // Inner refraction gradient (white → rainbow transition)
                    PrismTriangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.22),
                                    .white.opacity(0.10),
                                ] + vibeColors.map { Color(hex: $0).opacity(0.08) },
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: prismSide - 8, height: prismH - 10)
                        .position(x: prismCX, y: prismCY + 2)

                    // Internal light path through the prism
                    Path { p in
                        p.move(to: CGPoint(x: entryPt.x + 4, y: entryPt.y))
                        p.addLine(to: CGPoint(x: exitPt.x - 4, y: exitPt.y))
                    }
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.3)] + vibeColors.prefix(4).map { Color(hex: $0).opacity(0.15) },
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 2.5
                    )
                    .blur(radius: 3)

                    // Bright entry point (white light hitting the glass)
                    Circle()
                        .fill(.white.opacity(0.5))
                        .frame(width: 16, height: 16)
                        .blur(radius: 7)
                        .position(x: entryPt.x + 6, y: entryPt.y)

                    // Rainbow exit spread (colors leaving the glass)
                    Ellipse()
                        .fill(
                            LinearGradient(
                                colors: vibeColors.map { Color(hex: $0).opacity(0.3) },
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 10, height: 30)
                        .blur(radius: 5)
                        .position(x: exitPt.x - 3, y: exitPt.y)

                    // Glass edge highlight
                    PrismTriangle()
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.55), .white.opacity(0.08)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1.5
                        )
                        .frame(width: prismSide, height: prismH)
                        .position(x: prismCX, y: prismCY)

                    // Left face shine
                    Path { p in
                        let topY = prismCY - prismH / 2
                        p.move(to: CGPoint(x: prismCX, y: topY + 2))
                        p.addLine(to: CGPoint(
                            x: prismCX - prismSide * 0.35,
                            y: prismCY + prismH * 0.2
                        ))
                    }
                    .stroke(.white.opacity(0.12), lineWidth: 1)
                    .blur(radius: 0.5)

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

            // Mood label
            HStack(spacing: 6) {
                Circle()
                    .fill(Color(hex: selectedHex))
                    .frame(width: 10, height: 10)
                    .shadow(color: Color(hex: selectedHex).opacity(0.8), radius: 4)

                Text(moodLabel(for: selectedHex))
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.white.opacity(0.7))
            }
            .animation(.easeInOut(duration: 0.2), value: selectedHex)
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

    // MARK: - Mood Labels

    private func moodLabel(for hex: String) -> String {
        switch hex {
        case "#FF3B30": return "Energetic"
        case "#FF9500": return "Warm"
        case "#FFCC00": return "Sunny"
        case "#4CD964": return "Fresh"
        case "#5AC8FA": return "Chill"
        case "#007AFF": return "Deep"
        case "#5856D6": return "Dreamy"
        case "#FF2D55": return "Passionate"
        default: return "Vibe"
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
            vibeColors: [
                "#FF3B30", "#FF9500", "#FFCC00", "#4CD964",
                "#5AC8FA", "#007AFF", "#5856D6", "#FF2D55"
            ]
        )
        .padding(.vertical, 24)
    }
}
