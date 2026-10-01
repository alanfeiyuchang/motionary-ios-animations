import SwiftUI

/// Small pieces shared by the round-2 Feedback demos (part B).

/// A check mark to stroke with a round cap and join; `trim` it to write it in.
struct FeedbackCheckShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.04, y: rect.minY + rect.height * 0.55))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.37, y: rect.maxY - rect.height * 0.04))
        path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.03, y: rect.minY + rect.height * 0.06))
        return path
    }
}

/// Placeholder list rows (a tinted tile and two lines) for the page behind a toast, sheet or dialog.
struct FeedbackMockRows: View {
    var count: Int = 4
    var rowHeight: CGFloat = 50
    var tints: [Color] = [Palette.sky, Palette.coral, Palette.violet, Palette.amber, Palette.mint]

    private static let widths: [CGFloat] = [132, 96, 150, 112, 124]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<count, id: \.self) { index in
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(tints[index % tints.count].gradient)
                        .frame(width: 32, height: 32)
                    VStack(alignment: .leading, spacing: 6) {
                        Capsule()
                            .fill(Color.primary.opacity(0.18))
                            .frame(width: Self.widths[index % Self.widths.count], height: 8)
                        Capsule()
                            .fill(Color.primary.opacity(0.09))
                            .frame(width: Self.widths[(index + 2) % Self.widths.count] * 0.72, height: 7)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)
                .frame(height: rowHeight)
            }
        }
    }
}

/// A page title bar for the mock screens.
struct FeedbackMockHeader: View {
    let title: String
    var symbol: String = "ellipsis"

    var body: some View {
        HStack {
            Text(verbatim: title)
                .font(.headline)
            Spacer(minLength: 0)
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 30, height: 30)
                .background(Color.primary.opacity(0.07), in: Circle())
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
    }
}

extension View {
    /// The clipped, elevated card most Feedback demos stage their scene in.
    func feedbackScene(width: CGFloat = 300, height: CGFloat = 270, cornerRadius: CGFloat = 26) -> some View {
        frame(width: width, height: height)
            .background(Palette.elevated)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .demoCard(cornerRadius: cornerRadius)
    }
}
