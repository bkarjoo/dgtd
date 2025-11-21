import SwiftUI

struct TagChip: View {
    let tag: Tag
    let showRemove: Bool
    let onRemove: (() -> Void)?

    init(tag: Tag, showRemove: Bool = false, onRemove: (() -> Void)? = nil) {
        self.tag = tag
        self.showRemove = showRemove
        self.onRemove = onRemove
    }

    var body: some View {
        HStack(spacing: 4) {
            Text(tag.name)
                .font(.system(size: 12))
                .foregroundColor(.white)

            if showRemove {
                Button(action: { onRemove?() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white.opacity(0.8))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(tagColor)
        .cornerRadius(4)
    }

    private var tagColor: Color {
        if let colorHex = tag.color {
            return Color(hex: colorHex) ?? Color.gray
        }
        return Color.gray
    }
}

// Helper extension to create Color from hex string
extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0

        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else {
            return nil
        }

        let length = hexSanitized.count
        let r, g, b, a: Double

        if length == 6 {
            r = Double((rgb & 0xFF0000) >> 16) / 255.0
            g = Double((rgb & 0x00FF00) >> 8) / 255.0
            b = Double(rgb & 0x0000FF) / 255.0
            a = 1.0
        } else if length == 8 {
            r = Double((rgb & 0xFF000000) >> 24) / 255.0
            g = Double((rgb & 0x00FF0000) >> 16) / 255.0
            b = Double((rgb & 0x0000FF00) >> 8) / 255.0
            a = Double(rgb & 0x000000FF) / 255.0
        } else {
            return nil
        }

        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}
