import SwiftData
import SwiftUI

struct ComparisonCandidateDraft: Identifiable {
    let id: UUID
    var placeName: String
    var resolvedPlace: GeocodedPlace?

    init(id: UUID = UUID(), placeName: String = "", resolvedPlace: GeocodedPlace? = nil) {
        self.id = id
        self.placeName = placeName
        self.resolvedPlace = resolvedPlace
    }

    mutating func apply(_ place: GeocodedPlace) {
        resolvedPlace = place
        placeName = place.name
    }
}

struct ComparisonEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let comparison: DestinationComparison?
    let onSaved: (DestinationComparison) -> Void

    @State private var name: String
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var drafts: [ComparisonCandidateDraft]
    @State private var errorMessage: String?
    @State private var isSaving = false
    @StateObject private var autocomplete = PlaceAutocompleteModel()

    init(comparison: DestinationComparison? = nil, onSaved: @escaping (DestinationComparison) -> Void = { _ in }) {
        self.comparison = comparison
        self.onSaved = onSaved
        let today = Calendar.autoupdatingCurrent.startOfDay(for: .now)
        _name = State(initialValue: comparison?.name ?? "")
        _startDate = State(initialValue: comparison?.startDate ?? today)
        _endDate = State(initialValue: comparison?.endDate ?? today)
        if let comparison, !comparison.sortedCandidates.isEmpty {
            _drafts = State(initialValue: comparison.sortedCandidates.map { candidate in
                let place: GeocodedPlace?
                if let latitude = candidate.latitude, let longitude = candidate.longitude {
                    place = GeocodedPlace(
                        name: candidate.placeName, regionName: candidate.regionName, countryName: candidate.countryName,
                        latitude: latitude, longitude: longitude, timeZoneIdentifier: candidate.timeZoneIdentifier
                    )
                } else { place = nil }
                return ComparisonCandidateDraft(id: candidate.id, placeName: candidate.placeName, resolvedPlace: place)
            })
        } else {
            _drafts = State(initialValue: [ComparisonCandidateDraft(), ComparisonCandidateDraft()])
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(String(localized: "comparison.name.optional"), text: $name)
                    DatePicker(String(localized: "comparison.from"), selection: startBinding, displayedComponents: .date)
                    DatePicker(
                        String(localized: "comparison.to"), selection: endBinding,
                        in: Calendar.autoupdatingCurrent.startOfDay(for: startDate)...,
                        displayedComponents: .date
                    )
                } header: { Text(String(localized: "comparison.period")) }
                .themedListRow()

                Section {
                    ForEach($drafts) { $draft in
                        candidateEditor(draft: $draft)
                    }
                    .onDelete(perform: deleteCandidates)

                    Button { addCandidate() } label: {
                        Label(String(localized: "comparison.addPlace"), systemImage: "plus.circle.fill")
                            .frame(minHeight: 44)
                    }
                    .disabled(drafts.count >= DestinationComparisonValidator.maximumCandidates)
                } header: {
                    Text(String(localized: "comparison.candidates"))
                } footer: {
                    Text(String(localized: "comparison.candidates.help"))
                }
                .themedListRow()
            }
            .scrollDismissesKeyboard(.interactively)
            .adaptiveContentWidth()
            .appScreenStyle()
            .navigationTitle(comparison == nil ? String(localized: "comparison.new") : String(localized: "comparison.edit"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(String(localized: "common.cancel")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "common.save")) { Task { await save() } }
                        .disabled(isSaving)
                }
            }
            .alert(String(localized: "comparison.error.title"), isPresented: Binding(
                get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
            )) { Button("OK", role: .cancel) {} } message: { Text(errorMessage ?? "") }
        }
    }

    private func candidateEditor(draft: Binding<ComparisonCandidateDraft>) -> some View {
        let id = draft.wrappedValue.id
        return VStack(alignment: .leading, spacing: 8) {
            TextField(String(localized: "comparison.place"), text: draft.placeName)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .onChange(of: draft.wrappedValue.placeName) { _, value in
                    if draft.wrappedValue.resolvedPlace?.name != value { draft.wrappedValue.resolvedPlace = nil }
                    autocomplete.search(draftID: id, text: value)
                }
            if autocomplete.isLoading(id) { ProgressView().controlSize(.small) }
            ForEach(autocomplete.suggestions(for: id)) { place in
                Button {
                    autocomplete.accept(place, for: id)
                    draft.wrappedValue.apply(place)
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(place.name)
                            if !place.subtitle.isEmpty { Text(place.subtitle).font(.caption).foregroundStyle(AppTheme.secondaryText) }
                        }
                    } icon: { Image(systemName: "mappin.circle.fill") }
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }

    private var startBinding: Binding<Date> {
        Binding(get: { startDate }, set: {
            startDate = Calendar.autoupdatingCurrent.startOfDay(for: $0)
            endDate = max(startDate, Calendar.autoupdatingCurrent.startOfDay(for: endDate))
        })
    }

    private var endBinding: Binding<Date> {
        Binding(get: { endDate }, set: { endDate = max(startDate, Calendar.autoupdatingCurrent.startOfDay(for: $0)) })
    }

    private func addCandidate() {
        guard drafts.count < DestinationComparisonValidator.maximumCandidates else { return }
        drafts.append(ComparisonCandidateDraft())
    }

    private func deleteCandidates(at offsets: IndexSet) {
        guard drafts.count - offsets.count >= DestinationComparisonValidator.minimumCandidates else {
            errorMessage = ComparisonValidationError.tooFewCandidates.localizedDescription
            return
        }
        for index in offsets { autocomplete.removeDraft(drafts[index].id) }
        drafts.remove(atOffsets: offsets)
    }

    @MainActor private func save() async {
        isSaving = true
        defer { isSaving = false }
        do {
            var resolvedDrafts: [(ComparisonCandidateDraft, GeocodedPlace)] = []
            for draft in drafts {
                let trimmed = draft.placeName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { throw ComparisonValidationError.emptyPlace }
                let place: GeocodedPlace
                if let resolvedPlace = draft.resolvedPlace {
                    place = resolvedPlace
                } else {
                    place = try await OpenMeteoGeocodingService().geocode(trimmed)
                }
                resolvedDrafts.append((draft, place))
            }
            try DestinationComparisonValidator.validate(
                startDate: startDate, endDate: endDate,
                candidates: resolvedDrafts.map {
                    ComparisonCandidateInput(
                        id: $0.0.id, placeName: $0.1.name,
                        coordinateKey: TripWeatherModel.coordinateKey(latitude: $0.1.latitude, longitude: $0.1.longitude)
                    )
                }
            )

            let stored: DestinationComparison
            if let comparison {
                stored = comparison
                for candidate in stored.candidates { modelContext.delete(candidate) }
                stored.candidates.removeAll()
            } else {
                stored = DestinationComparison(name: "", startDate: startDate, endDate: endDate)
                modelContext.insert(stored)
            }
            stored.startDate = Calendar.autoupdatingCurrent.startOfDay(for: startDate)
            stored.endDate = Calendar.autoupdatingCurrent.startOfDay(for: endDate)
            stored.updatedAt = .now
            let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            stored.name = trimmedName.isEmpty
                ? String(localized: "comparison.generatedName \(resolvedDrafts[0].1.name) \(resolvedDrafts[1].1.name)")
                : trimmedName

            for (index, pair) in resolvedDrafts.enumerated() {
                let place = pair.1
                let candidate = ComparisonCandidate(
                    id: pair.0.id, placeName: place.name, regionName: place.regionName, countryName: place.countryName,
                    latitude: place.latitude, longitude: place.longitude, timeZoneIdentifier: place.timeZoneIdentifier,
                    createdAt: Date(timeIntervalSinceReferenceDate: stored.createdAt.timeIntervalSinceReferenceDate + Double(index)),
                    comparison: stored
                )
                modelContext.insert(candidate)
                stored.candidates.append(candidate)
            }
            try modelContext.save()
            if stored.forecastNotificationEnabled {
                try? await ForecastNotificationManager().scheduleComparison(
                    comparisonID: stored.id, comparisonName: stored.name, startDate: stored.startDate
                )
            }
            dismiss()
            onSaved(stored)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
