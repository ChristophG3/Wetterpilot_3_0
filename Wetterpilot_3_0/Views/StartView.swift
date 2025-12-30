import SwiftUI
import UIKit

struct StartView: View {
    @EnvironmentObject var vm: RouteVM
    @Environment(\.colorScheme) private var scheme

    @State private var navKey: String?
    @State private var showPrefs = false
    @State private var showInfo = false
    @State private var isAnalyzing = false
    @State private var showError = false

    // Reset-Bestätigung
    @State private var showResetAlert = false

    // Hilfe-Dialoge
    @State private var showStartHelp = false
    @State private var showDurationHelp = false

    var body: some View {
        NavigationStack {
            Form {
                Section(NSLocalizedString("places_section", comment: "")) {

                    // Startdatum + Hilfe-Icon
                    HStack(spacing: 8) {
                        HStack(spacing: 6) {
                            Text(NSLocalizedString("start_date", comment: ""))
                            Button {
                                showStartHelp = true
                            } label: {
                                Image(systemName: "questionmark.circle")
                                    .imageScale(.small)
                                    .symbolRenderingMode(.hierarchical)
                                    .foregroundStyle(.secondary)
                                    .accessibilityLabel(Text(NSLocalizedString("help_start_label", comment: "")))
                                    .accessibilityHint(Text(NSLocalizedString("help_start_hint", comment: "")))
                            }
                            .buttonStyle(.plain)
                        }

                        Spacer()

                        DatePicker(
                            "",
                            selection: Binding(get: { vm.startDate }, set: { vm.startDate = $0 }),
                            in: vm.minStart...vm.maxStart,
                            displayedComponents: .date
                        )
                        .labelsHidden()
                    }
                    .fieldContainer()
                    .listRowNavy()

                    // Dauer + Hilfe-Icon
                    HStack(spacing: 8) {
                        HStack(spacing: 6) {
                            Text("\(NSLocalizedString("duration_days", comment: "")) \(vm.durationDays)")
                            Button {
                                showDurationHelp = true
                            } label: {
                                Image(systemName: "questionmark.circle")
                                    .imageScale(.small)
                                    .symbolRenderingMode(.hierarchical)
                                    .foregroundStyle(.secondary)
                                    .accessibilityLabel(Text(NSLocalizedString("help_duration_label", comment: "")))
                                    .accessibilityHint(Text(NSLocalizedString("help_duration_hint", comment: "")))
                            }
                            .buttonStyle(.plain)
                        }

                        Spacer()

                        Stepper("",
                                value: Binding(get: { vm.durationDays }, set: { vm.updateDuration($0) }),
                                in: 1...vm.maxDuration)   // statt 1...10
                        .labelsHidden()
                    }
                    .fieldContainer()
                    .listRowNavy()

                    // Etappenzeilen
                    ForEach(vm.stops.indices, id: \.self) { i in
                        StageRow(index: i)
                            .environmentObject(vm)
                            .listRowNavy()
                    }
                }

                Section {
                    Button {
                        Task {
                            navKey = nil
                            vm.errorKey = nil
                            isAnalyzing = true
                            await vm.analyze()
                            isAnalyzing = false
                            if vm.errorKey != nil { showError = true } else { navKey = "summary" }
                        }
                    } label: {
                        if isAnalyzing { ProgressView() } else { Text(NSLocalizedString("analyze", comment: "")) }
                    }
                    .primaryButton()
                    .disabled(isAnalyzing)
                }
                .listRowNavy()
            }
            .navigationTitle(Text("Wetterpilot"))
            .toolbar {
                // Links: Reset-Icon (gleiche Farbe + Hervorhebung wie Menü)
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showResetAlert = true
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .imageScale(.large)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(AppColor.toolbarIcon(for: scheme))
                            .accessibilityLabel(Text(NSLocalizedString("new_plan", comment: "")))
                            .accessibilityHint(Text(NSLocalizedString("new_plan_hint", comment: "")))
                    }
                }

                // Rechts: Drei-Punkte-Menü (identische Farbe + Hervorhebung)
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button { showPrefs = true } label: {
                            Label(NSLocalizedString("menu_preferences", comment: ""), systemImage: "slider.horizontal.3")
                        }
                        Button { showInfo = true } label: {
                            Label(NSLocalizedString("menu_info", comment: ""), systemImage: "info.circle")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .imageScale(.large)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(AppColor.toolbarIcon(for: scheme))
                    }
                }
            }
            .sheet(isPresented: $showPrefs) { PreferenceView() }
            .sheet(isPresented: $showInfo) { InfoView() }
            .navigationDestination(isPresented: Binding(get: { navKey == "summary" }, set: { if !$0 { navKey = nil } })) {
                SummaryView()
            }

            // Fehler-Alert (Analyse)
            .alert(Text(NSLocalizedString("error_title", comment: "")),
                   isPresented: $showError,
                   actions: { Button("OK") { vm.errorKey = nil } },
                   message: { Text(NSLocalizedString(vm.errorKey ?? "error_unknown", comment: "")) })

            // Reset-Bestätigung
            .alert(NSLocalizedString("reset_confirm_title", comment: ""), isPresented: $showResetAlert) {
                Button(NSLocalizedString("cancel", comment: ""), role: .cancel) {}
                Button(NSLocalizedString("reset_confirm_delete", comment: ""), role: .destructive) {
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    vm.resetAll()
                    navKey = nil
                }
            } message: {
                Text(NSLocalizedString("reset_confirm_message", comment: ""))
            }

            // Hilfetexte
            .alert(NSLocalizedString("help_start_title", comment: ""), isPresented: $showStartHelp) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(NSLocalizedString("help_start_text", comment: ""))
            }
            .alert(NSLocalizedString("help_duration_title", comment: ""), isPresented: $showDurationHelp) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(NSLocalizedString("help_duration_text", comment: ""))
            }

            .appBackground()
        }
    }
}

// MARK: - Subviews

private struct StageRow: View {
    @EnvironmentObject var vm: RouteVM
    let index: Int

    var body: some View {
        if index < vm.stops.count {
            VStack(alignment: .leading, spacing: 6) {
                let placeBinding = Binding<String>(
                    get: {
                        guard index < vm.stops.count else { return "" }
                        return vm.stops[index].place
                    },
                    set: { newValue in
                        guard index < vm.stops.count else { return }
                        vm.updatePlace(index, newValue)
                    }
                )

                HStack {
                    Text(dateString(offset: index))
                    TextField(NSLocalizedString("place_placeholder", comment: ""), text: placeBinding)
                        .textInputAutocapitalization(.words)
                        .multilineTextAlignment(.trailing)
                        .onChange(of: vm.stops[index].place) { _, newValue in
                            vm.onTypingSuggest(index: index, text: newValue)
                        }
                }
                .fieldContainer()

                if let hitsOpt = vm.suggestions[index],
                   let hits = hitsOpt,
                   !hits.isEmpty {
                    SuggestionBox(hits: hits) { selected in
                        vm.selectSuggestion(index, selected)
                    }
                    .zIndex(1)
                }
            }
        }
    }

    private func dateString(offset: Int) -> String {
        let d = Calendar.current.date(byAdding: .day, value: offset, to: vm.startDate) ?? vm.startDate
        let df = DateFormatter(); df.dateStyle = .short; df.timeStyle = .none
        return df.string(from: d)
    }
}

private struct SuggestionBox: View {
    let hits: [GeoPlace]
    let onSelect: (GeoPlace) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(NSLocalizedString("suggestions_title", comment: ""))
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .foregroundStyle(Color.secondary)

            ForEach(hits.indices, id: \.self) { i in
                SuggestionRow(place: hits[i], onSelect: onSelect)
                if i != hits.indices.last { Divider() }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(UIColor.secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color(UIColor.separator), lineWidth: 1)
                )
        )
    }
}

private struct SuggestionRow: View {
    let place: GeoPlace
    let onSelect: (GeoPlace) -> Void

    var body: some View {
        Button { onSelect(place) } label: {
            Text(place.name)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }
}
