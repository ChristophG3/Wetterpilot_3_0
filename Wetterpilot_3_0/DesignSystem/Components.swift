import SwiftUI
import UIKit

// MARK: - Primary Button (zentral)
public struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity)
            .background(AppColor.navyBase.opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1.0) : 0.5))
            .foregroundStyle(AppColor.onNavy.opacity(isEnabled ? 1 : 0.7))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

public extension View {
    /// Einheitlicher Aufruf in allen Views
    func primaryButton() -> some View { self.buttonStyle(PrimaryButtonStyle()) }
}

// MARK: - ShareSheet (zentral)
public struct ShareSheet: UIViewControllerRepresentable {
    public let activityItems: [Any]
    public init(activityItems: [Any]) { self.activityItems = activityItems }

    public func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    public func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
