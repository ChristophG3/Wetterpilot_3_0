import SwiftUI

// Einfache Zeile mit Toggle + Untertitel
private struct ToggleRow: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey?
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                if let subtitle {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct PreferenceView: View {
    @EnvironmentObject var vm: RouteVM
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                // Einleitung
                Section {
                    Text("prefs_intro")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                // „Vermeiden“-Schalter
                Section("prefs_avoid_section") {
                    ToggleRow(
                        title: "prefs_avoid_rain_title",
                        subtitle: "prefs_avoid_rain_sub",
                        isOn: Binding(
                            get: { vm.weights.avoidRain },
                            set: { vm.weights.avoidRain = $0 }
                        )
                    )
                    ToggleRow(
                        title: "prefs_avoid_wind_title",
                        subtitle: "prefs_avoid_wind_sub",
                        isOn: Binding(
                            get: { vm.weights.avoidWind },
                            set: { vm.weights.avoidWind = $0 }
                        )
                    )
                    ToggleRow(
                        title: "prefs_avoid_heat_title",
                        subtitle: "prefs_avoid_heat_sub",
                        isOn: Binding(
                            get: { vm.weights.avoidHeat },
                            set: { vm.weights.avoidHeat = $0 }
                        )
                    )
                    ToggleRow(
                        title: "prefs_avoid_cold_title",
                        subtitle: "prefs_avoid_cold_sub",
                        isOn: Binding(
                            get: { vm.weights.avoidCold },
                            set: { vm.weights.avoidCold = $0 }
                        )
                    )
                }

                // Defaults wiederherstellen
                Section {
                    Button(role: .destructive) {
                        vm.weights = Weights() // deine Defaults aus Weights
                    } label: {
                        Text("prefs_reset_defaults")
                    }
                }
            }
            .navigationTitle(Text("menu_preferences"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("done") {
                        // direkt persistieren, damit die Auswahl bleibt
                        vm.deps.store.weights = vm.weights
                        dismiss()
                    }
                }
            }
        }
    }
}
