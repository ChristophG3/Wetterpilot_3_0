import SwiftUI

struct LicensesView: View {
    @Environment(\.colorScheme) private var scheme

    struct ThirdParty: Identifiable {
        let id = UUID()
        let name: String
        let site: String
        let notice: String
        let systemImage: String
    }

    private var items: [ThirdParty] = [
        .init(
            name: "Open-Meteo Weather API",
            site: "https://open-meteo.com",
            notice: NSLocalizedString("license_notice_openmeteo", comment: ""),
            systemImage: "cloud.sun"
        ),
        .init(
            name: "Open-Meteo Geocoding API",
            site: "https://open-meteo.com/en/docs/geocoding-api",
            notice: NSLocalizedString("license_notice_geocoding", comment: ""),
            systemImage: "mappin.and.ellipse"
        ),
        .init(
            name: "Apple MapKit / CoreLocation",
            site: "https://developer.apple.com",
            notice: NSLocalizedString("license_notice_apple", comment: ""),
            systemImage: "map"
        )
    ]

    var body: some View {
        List {
            Section(NSLocalizedString("licenses_section_thirdparty", comment: "")) {
                ForEach(items) { lib in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: lib.systemImage).foregroundStyle(.secondary)
                            Text(lib.name).font(.headline)
                        }
                        Text(lib.notice).font(.subheadline)
                        if let url = URL(string: lib.site) {
                            Link(lib.site, destination: url)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .accessibilityLabel(Text(String(format: NSLocalizedString("licenses_open_site", comment: ""), lib.name)))
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
            .listRowBackground(AppColor.navySurface)

            // Optionaler Abschnitt, wenn du später vollständige Lizenztexte bundelst
            Section(NSLocalizedString("licenses_section_notes", comment: "")) {
                Text(NSLocalizedString("licenses_notes_text", comment: ""))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
            }
            .listRowBackground(AppColor.navySurface)
        }
        .listStyle(.insetGrouped)
        .navigationTitle(Text(NSLocalizedString("licenses_title", comment: "")))
        .toolbarTitleDisplayMode(.inline)
        .appBackground()
    }
}
