import SwiftUI

// MARK: - Farb- und Style-System
enum AppColor {
    // Navy-Palette
    static let navyBase    = Color(red: 10/255, green: 24/255,  blue: 58/255)   // #0A183A
    static let navySurface = Color(red: 7/255,  green: 16/255,  blue: 42/255)   // #07102A
    static let navyFrame   = Color(red: 15/255, green: 42/255,  blue: 100/255)  // #0F2A64
    static let onNavy      = Color.white

    // Toolbar-Icons (Reset & Drei-Punkte-Menü – identisch)
    static let toolbarLight = Color(red: 10/255, green: 24/255,  blue: 58/255)  // #0A183A
    static let toolbarDark  = Color(red: 109/255, green: 211/255, blue: 255/255) // #6DD3FF

    /// allgemeiner Text auf dem App-Hintergrund
    static func text(for scheme: ColorScheme) -> Color {
        scheme == .dark ? .white : AppColor.navyBase
    }

    /// App-Hintergrund
    static func bg(for scheme: ColorScheme) -> Color {
        scheme == .dark ? AppColor.navyBase : .white
    }

    /// Toolbar-Icon-Farbe (für Reset & Drei-Punkte-Menü)
    static func toolbarIcon(for scheme: ColorScheme) -> Color {
        scheme == .dark ? toolbarDark : toolbarLight
    }

    /// Link-/Akzentfarbe in Info- und Lizenz-Screens (entspricht Screenshot)
    static func link(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 109/255, green: 211/255, blue: 255/255)    // #6DD3FF
                        : Color(red: 10/255,  green: 24/255,  blue: 58/255)     // #0A183A
    }
}

// MARK: - App-Hintergrund
struct AppBackground: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    func body(content: Content) -> some View {
        content
            .foregroundStyle(AppColor.text(for: scheme))
            .scrollContentBackground(.hidden)
            .background(AppColor.bg(for: scheme).ignoresSafeArea())
    }
}
extension View { func appBackground() -> some View { modifier(AppBackground()) } }

// MARK: - Forecast Card (immer navy)
struct ForecastCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .foregroundStyle(AppColor.onNavy)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(AppColor.navyBase)
            )
    }
}
extension View { func forecastCard() -> some View { modifier(ForecastCard()) } }

// MARK: - Field Container (Eingabefelder)
struct FieldContainer: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    func body(content: Content) -> some View {
        content
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(scheme == .dark ? AppColor.navySurface
                                          : Color(UIColor.secondarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(scheme == .dark ? AppColor.navyFrame.opacity(0.8)
                                                    : Color(UIColor.separator),
                                    lineWidth: 1)
                    )
            )
    }
}
extension View {
    func fieldContainer() -> some View { modifier(FieldContainer()) }
    func listRowNavy() -> some View { listRowBackground(AppColor.navySurface) }
}

// MARK: - Primary Button (für Hauptaktionen)
// MARK: - Primary Button (für Hauptaktionen)
struct NavyPrimaryButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var scheme
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
            .foregroundStyle(AppColor.onNavy)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppColor.navyBase)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(AppColor.navyFrame.opacity(0.5), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(scheme == .dark ? 0.22 : 0.12),
                            radius: configuration.isPressed ? 2 : 6,
                            x: 0, y: configuration.isPressed ? 1 : 4)
            )
            .scaleEffect(configuration.isPressed ? 0.99 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// neue Extension
extension View {
    func navyPrimaryButton() -> some View { buttonStyle(NavyPrimaryButtonStyle()) }
}
