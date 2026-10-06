import SwiftUI

extension Color {
    init(rgb: UInt32) { self.init(red: Double((rgb >> 16) & 255) / 255, green: Double((rgb >> 8) & 255) / 255, blue: Double(rgb & 255) / 255) }
}
enum Theme {
    static let paper = Color(rgb: 0xFCFBF8)
    static let sidebar = Color(rgb: 0xF1F2EE)
    static let panel = Color(rgb: 0xF6F7F3)
    static let ink = Color(rgb: 0x263B36)
    static let secondary = Color(rgb: 0x5F706A)
    static let teal = Color(rgb: 0x28756A)
    static let selection = Color(rgb: 0xDFEEE8)
}

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 14, weight: .medium))
            .padding(.horizontal, 14).padding(.vertical, 8)
            .foregroundStyle(enabled ? Color.white : Theme.secondary)
            .background(enabled ? Theme.teal.opacity(configuration.isPressed ? 0.8 : 1) : Theme.selection)
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

func cardCount(_ count: Int) -> String { "\(count) \(count == 1 ? "card" : "cards")" }
