import SwiftUI

/// A simple wrapping layout: places subviews left-to-right and wraps to the next line when
/// they don't fit. Used for artist credits (a track can have several collaborators) and any
/// other chip-style row that shouldn't clip or force horizontal scrolling.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8
    var alignment: HorizontalAlignment = .center

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rows: [[CGSize]] = [[]]
        var lineWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if lineWidth + size.width > maxWidth, !rows[rows.count - 1].isEmpty {
                rows.append([])
                lineWidth = 0
            }
            rows[rows.count - 1].append(size)
            lineWidth += size.width + spacing
        }

        let height = rows.reduce(0) { partial, row in
            partial + (row.map(\.height).max() ?? 0) + lineSpacing
        } - (rows.isEmpty ? 0 : lineSpacing)

        return CGSize(width: maxWidth == .infinity ? lineWidth : maxWidth, height: max(0, height))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        let maxWidth = bounds.width

        // Break subviews into rows first so each row can be aligned.
        var rows: [[(index: Int, size: CGSize)]] = [[]]
        var lineWidth: CGFloat = 0
        for (index, subview) in subviews.enumerated() {
            let size = subview.sizeThatFits(.unspecified)
            if lineWidth + size.width > maxWidth, !rows[rows.count - 1].isEmpty {
                rows.append([])
                lineWidth = 0
            }
            rows[rows.count - 1].append((index, size))
            lineWidth += size.width + spacing
        }

        var y = bounds.minY
        for row in rows {
            let rowWidth = row.reduce(0) { $0 + $1.size.width } + spacing * CGFloat(max(0, row.count - 1))
            let rowHeight = row.map(\.size.height).max() ?? 0

            var x: CGFloat
            switch alignment {
            case .leading: x = bounds.minX
            case .trailing: x = bounds.maxX - rowWidth
            default: x = bounds.minX + (maxWidth - rowWidth) / 2
            }

            for item in row {
                subviews[item.index].place(
                    at: CGPoint(x: x, y: y + (rowHeight - item.size.height) / 2),
                    proposal: ProposedViewSize(item.size)
                )
                x += item.size.width + spacing
            }
            y += rowHeight + lineSpacing
        }
    }
}
