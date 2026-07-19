import SwiftUI

struct InfoView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("temperatureUnit") private var temperatureUnitRaw = TemperatureUnit.celsius.rawValue
    @AppStorage("windSpeedUnit") private var windUnitRaw = WindSpeedUnit.kilometersPerHour.rawValue

    private var displayName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? String(localized: "app.name")
    }

    private var version: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "–"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "–"
        return "\(version) (\(build))"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Text(String(localized: "app.name"))
                        .font(.largeTitle.bold())
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)

                    InfoSectionHeader("App")
                    InfoCard {
                        InfoValueRow(title: "Name", value: displayName, icon: "app.dashed")
                        Divider().overlay(AppTheme.border)
                        InfoValueRow(title: "Version", value: version, icon: "number")
                        Divider().overlay(AppTheme.border)
                        InfoValueRow(title: "Entwickler", value: "Christoph Gassl / CGAS", icon: "person.crop.circle")
                    }

                    InfoSectionHeader("Kontakt & Support")
                    InfoCard {
                        Link(destination: URL(string: "mailto:christoph.gassl@icloud.com")!) {
                            InfoLinkRow(title: "E-Mail-Support", subtitle: "christoph.gassl@icloud.com", icon: "envelope")
                        }
                        .buttonStyle(.plain)
                    }

                    InfoSectionHeader(String(localized: "settings.units"))
                    InfoCard {
                        Picker(String(localized: "settings.temperature"), selection: $temperatureUnitRaw) {
                            Text("°C").tag(TemperatureUnit.celsius.rawValue)
                            Text("°F").tag(TemperatureUnit.fahrenheit.rawValue)
                        }
                        .pickerStyle(.segmented)
                        Picker(String(localized: "settings.wind"), selection: $windUnitRaw) {
                            Text("km/h").tag(WindSpeedUnit.kilometersPerHour.rawValue)
                            Text("mph").tag(WindSpeedUnit.milesPerHour.rawValue)
                        }
                        .pickerStyle(.segmented)
                    }

                    InfoSectionHeader(String(localized: "weather.dataSource"))
                    InfoCard {
                        Link(destination: URL(string: "https://open-meteo.com/")!) {
                            InfoLinkRow(
                                title: "Open-Meteo",
                                subtitle: String(localized: "weather.attribution.detail"),
                                icon: "cloud.sun"
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    InfoSectionHeader("Rechtliches")
                    InfoCard {
                        NavigationLink {
                            PrivacyPolicyView()
                        } label: {
                            InfoNavigationRow(title: "Datenschutz", icon: "lock.shield")
                        }
                        Divider().overlay(AppTheme.border)
                        NavigationLink {
                            LicensesView()
                        } label: {
                            InfoNavigationRow(title: "Lizenzen / Danksagungen", icon: "doc.plaintext")
                        }
                    }

                    InfoSectionHeader("Hinweis")
                    InfoCard {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "info.circle")
                            Text("Vorhersagen können vom tatsächlichen Wetter abweichen. Triff Entscheidungen mit gesundem Menschenverstand.")
                                .font(.footnote)
                        }
                        .foregroundStyle(AppTheme.secondaryText)
                    }
                }
                .padding(.vertical, 12)
                .adaptiveContentWidth()
            }
            .navigationTitle("Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .imageScale(.large)
                            .symbolRenderingMode(.hierarchical)
                            .accessibilityLabel("Schließen")
                    }
                }
            }
            .appScreenStyle()
        }
    }
}

private struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Datenschutzerklärung").font(.title.bold())
                Text(String(localized: "privacy.appData"))
                privacySection(
                    "Welche Daten werden verarbeitet?",
                    "Reisen, Orte und Reisetage werden lokal auf deinem Gerät gespeichert. Für Ortsvorschläge wird der eingegebene Ortsname an Open‑Meteo übertragen. Für Wettervorhersagen werden die Koordinaten des ausgewählten Ortes übertragen. Es werden keine Nutzerkennung, Bewegungshistorie oder aktuelle Geräteposition gesendet."
                )
                privacySection(
                    "Wofür werden die Daten verwendet?",
                    "Zur Autovervollständigung von Ortsnamen und zur Anzeige der Wettervorhersage für deine Reiseziele."
                )
                privacySection(
                    "Aufbewahrung",
                    "Gespeicherte Reisen bleiben lokal auf dem Gerät, bis du sie in der Reiseübersicht löschst."
                )
                privacySection(
                    "Kontakt",
                    "christoph.gassl@icloud.com"
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .adaptiveContentWidth()
        }
        .navigationTitle("Datenschutz")
        .navigationBarTitleDisplayMode(.inline)
        .appScreenStyle()
    }

    private func privacySection(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline)
            Text(text)
        }
    }
}

private struct LicensesView: View {
    var body: some View {
        List {
            Section("Datenquellen") {
                license(
                    name: "Open-Meteo Weather API",
                    description: "Open‑Meteo stellt die Wettervorhersagen bereit.",
                    url: "https://open-meteo.com",
                    icon: "cloud.sun"
                )
                license(
                    name: "Open-Meteo Geocoding API",
                    description: "Open‑Meteo stellt Autovervollständigung und Geocoding bereit.",
                    url: "https://open-meteo.com/en/docs/geocoding-api",
                    icon: "mappin.and.ellipse"
                )
            }
            .themedListRow()

            Section("Hinweise") {
                Text("Für die Nutzung der Dienste gelten die Bedingungen der jeweiligen Anbieter.")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.secondaryText)
            }
            .themedListRow()
        }
        .listStyle(.insetGrouped)
        .adaptiveContentWidth()
        .navigationTitle("Lizenzen")
        .navigationBarTitleDisplayMode(.inline)
        .appScreenStyle()
    }

    private func license(name: String, description: String, url: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Label(name, systemImage: icon).font(.headline)
            Text(description).font(.subheadline)
            if let url = URL(string: url) {
                Link(url.absoluteString, destination: url)
                    .font(.footnote)
            }
        }
        .padding(.vertical, 6)
    }
}

private struct InfoSectionHeader: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title.uppercased())
            .font(.footnote.weight(.semibold))
            .foregroundStyle(AppTheme.secondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 6)
    }
}

private struct InfoCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        }
        .padding(.horizontal, 16)
    }
}

private struct InfoValueRow: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(AppTheme.secondaryText)
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(AppTheme.secondaryText)
                .multilineTextAlignment(.trailing)
        }
    }
}

private struct InfoNavigationRow: View {
    let title: String
    let icon: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.title3)
            Text(title)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppTheme.secondaryText)
        }
        .foregroundStyle(AppTheme.accent)
        .contentShape(Rectangle())
        .padding(.vertical, 2)
    }
}

private struct InfoLinkRow: View {
    let title: String
    let subtitle: String
    let icon: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.title2)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
            }
            Spacer()
        }
        .foregroundStyle(AppTheme.accent)
        .contentShape(Rectangle())
    }
}
