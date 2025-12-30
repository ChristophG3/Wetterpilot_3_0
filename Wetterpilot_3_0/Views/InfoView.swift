import SwiftUI

struct InfoView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme

    private var displayName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
        ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
        ?? "—"
    }
    private var versionString: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return "\(v) (\(b))"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {

                    // Titel
                    Text(NSLocalizedString("info_app_title", comment: ""))
                        .font(.largeTitle.bold())
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)

                    // Sektion: App (Name, Version, Entwickler)
                    SectionHeader(NSLocalizedString("info_section_app", comment: ""))
                    Card {
                        InfoRow(title: NSLocalizedString("info_name", comment: ""), value: displayName, icon: "app.dashed")
                        Divider().overlay(AppColor.navyFrame.opacity(0.25))
                        InfoRow(title: NSLocalizedString("info_version", comment: ""), value: versionString, icon: "number")
                        Divider().overlay(AppColor.navyFrame.opacity(0.25))
                        InfoRow(title: NSLocalizedString("info_developer", comment: ""),
                                value: NSLocalizedString("info_developer_name", comment: ""),
                                icon: "person.crop.circle")
                    }

                    // Sektion: Kontakt & Support
                    SectionHeader(NSLocalizedString("info_section_contact", comment: ""))
                    Card {
                        LinkRow(
                            title: NSLocalizedString("info_contact_email", comment: ""),
                            subtitle: NSLocalizedString("info_contact_open", comment: ""),
                            icon: "envelope",
                            urlString: NSLocalizedString("info_contact_mailto", comment: "")
                        )
                        Divider().overlay(AppColor.navyFrame.opacity(0.25))
                        Text(NSLocalizedString("info_contact_alt", comment: ""))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    // Sektion: Rechtliches
                    SectionHeader(NSLocalizedString("info_section_legal", comment: ""))
                    Card {
                        NavigationLink {
                            PrivacyPolicyView()
                        } label: {
                            RowWithIcon(
                                title: NSLocalizedString("info_privacy", comment: ""),
                                icon: "lock.shield",
                                tint: AppColor.link(for: scheme)
                            )
                        }
                        Divider().overlay(AppColor.navyFrame.opacity(0.25))
                        NavigationLink {
                            LicensesView()
                        } label: {
                            RowWithIcon(
                                title: NSLocalizedString("info_licenses", comment: ""),
                                icon: "doc.plaintext",
                                tint: AppColor.link(for: scheme)
                            )
                        }
                    }

                    // Sektion: Hinweis
                    SectionHeader(NSLocalizedString("info_section_disclaimer", comment: ""))
                    Card {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "info.circle")
                                .foregroundStyle(.secondary)
                            Text(NSLocalizedString("info_disclaimer_text", comment: ""))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.leading)
                        }
                    }
                }
                .padding(.vertical, 12)
            }
            .navigationTitle(Text(NSLocalizedString("info_title", comment: "")))
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                            .imageScale(.large)
                            .foregroundStyle(AppColor.toolbarIcon(for: scheme))
                            .accessibilityLabel(Text(NSLocalizedString("close", comment: "")))
                    }
                }
            }
            .appBackground()
        }
    }
}

// MARK: - UI-Bausteine

private struct SectionHeader: View {
    var title: String
    init(_ title: String) { self.title = title }
    var body: some View {
        Text(title.uppercased())
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 6)
    }
}

private struct Card<Content: View>: View {
    @Environment(\.colorScheme) private var scheme
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 12) { content }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(scheme == .dark ? AppColor.navySurface : Color(UIColor.secondarySystemGroupedBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(scheme == .dark ? AppColor.navyFrame.opacity(0.35)
                                                    : Color(UIColor.separator), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(scheme == .dark ? 0.12 : 0.06), radius: 10, x: 0, y: 6)
            )
            .padding(.horizontal, 16)
    }
}

private struct InfoRow: View {
    let title: String
    let value: String
    let icon: String
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(.secondary)
            Text(title)
            Spacer()
            Text(value).foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct RowWithIcon: View {
    let title: String
    let icon: String
    let tint: Color
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(tint)
            Text(title)
                .foregroundStyle(tint)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
        .padding(.vertical, 2)
    }
}

private struct LinkRow: View {
    @Environment(\.colorScheme) private var scheme
    let title: String
    let subtitle: String
    let icon: String
    let urlString: String

    var body: some View {
        if let url = URL(string: urlString) {
            Link(destination: url) {
                HStack(alignment: .center, spacing: 12) {
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundStyle(AppColor.link(for: scheme))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title).font(.headline).foregroundStyle(AppColor.link(for: scheme))
                        Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(NSLocalizedString("info_contact_hint", comment: ""))
        }
    }
}
