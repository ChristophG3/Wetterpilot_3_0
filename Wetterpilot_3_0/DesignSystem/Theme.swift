import SwiftUI

enum AppTheme {
    static let background = adaptive(light: 0xF4F7FC, dark: 0x070D20)
    static let elevatedBackground = adaptive(light: 0xE8EEF8, dark: 0x0B1430)
    static let surface = adaptive(light: 0xFFFFFF, dark: 0x111A36)
    static let surfaceSecondary = adaptive(light: 0xEDF3FC, dark: 0x0D1734)
    static let border = adaptive(light: 0xC9D5E8, dark: 0x263556)
    static let primaryText = adaptive(light: 0x07132E, dark: 0xEEF4FF)
    static let secondaryText = adaptive(light: 0x4E617F, dark: 0x91A5C8)
    static let accent = adaptive(light: 0x096FE8, dark: 0x28C9F4)
    static let accentStrong = adaptive(light: 0x064FC5, dark: 0x2D7FFF)
    static let success = adaptive(light: 0x087A66, dark: 0x55E0C0)
    static let warning = adaptive(light: 0xA75300, dark: 0xFFBE68)

    static var primaryGradient: LinearGradient {
        LinearGradient(
            colors: [accentStrong, accent],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private static func adaptive(light: UInt, dark: UInt) -> Color {
        Color(
            uiColor: UIColor { traits in
                UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
            }
        )
    }
}

private extension UIColor {
    convenience init(hex: UInt) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

private struct AppScreenModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .background(AppTheme.background.ignoresSafeArea())
            .foregroundStyle(AppTheme.primaryText)
            .tint(AppTheme.accent)
    }
}

private struct SurfaceCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(AppTheme.border, lineWidth: 1)
            }
    }
}

struct GradientPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(Color.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(AppTheme.primaryGradient, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .opacity(configuration.isPressed ? 0.78 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

extension View {
    func appScreenStyle() -> some View {
        modifier(AppScreenModifier())
    }

    func themedListRow() -> some View {
        listRowBackground(AppTheme.surface)
            .listRowSeparatorTint(AppTheme.border)
    }

    func surfaceCard() -> some View {
        modifier(SurfaceCardModifier())
    }
}
