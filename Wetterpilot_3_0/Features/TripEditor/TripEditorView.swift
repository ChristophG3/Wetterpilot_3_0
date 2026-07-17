import SwiftData
import SwiftUI

struct SegmentDraft: Identifiable {
    let id: UUID
    var placeName: String
    var startDate: Date
    var endDate: Date
    var resolvedPlace: GeocodedPlace?

    init(
        id: UUID = UUID(),
        placeName: String = "",
        startDate: Date,
        endDate: Date,
        resolvedPlace: GeocodedPlace? = nil
    ) {
        self.id = id
        self.placeName = placeName
        self.startDate = startDate
        self.endDate = endDate
        self.resolvedPlace = resolvedPlace
    }

    var timelineSegment: TimelineSegment {
        TimelineSegment(id: id, placeName: placeName, startDate: startDate, endDate: endDate)
    }

    mutating func apply(_ place: GeocodedPlace) {
        resolvedPlace = place
        placeName = place.name
    }

    mutating func clearResolvedPlaceIfNeeded(for text: String) {
        if resolvedPlace?.name != text {
            resolvedPlace = nil
        }
    }

    mutating func setStartDate(_ date: Date, calendar: Calendar = .autoupdatingCurrent) {
        let normalizedStart = calendar.startOfDay(for: date)
        let normalizedEnd = calendar.startOfDay(for: endDate)
        startDate = normalizedStart
        endDate = max(normalizedStart, normalizedEnd)
    }

    mutating func setEndDate(_ date: Date, calendar: Calendar = .autoupdatingCurrent) {
        let normalizedStart = calendar.startOfDay(for: startDate)
        startDate = normalizedStart
        endDate = max(normalizedStart, calendar.startOfDay(for: date))
    }

    static func defaultStartDate(
        after last: SegmentDraft?,
        now: Date = .now,
        calendar: Calendar = .autoupdatingCurrent
    ) -> Date {
        guard let last else { return calendar.startOfDay(for: now) }
        let lastEnteredDate = max(
            calendar.startOfDay(for: last.startDate),
            calendar.startOfDay(for: last.endDate)
        )
        return calendar.date(byAdding: .day, value: 1, to: lastEnteredDate) ?? lastEnteredDate
    }
}

struct TripEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    private let trip: Trip?
    @State private var name: String
    @State private var drafts: [SegmentDraft]
    @State private var flexibility: TripStartFlexibility
    @State private var errorMessage: String?
    @StateObject private var autocomplete = PlaceAutocompleteModel()

    init(trip: Trip? = nil) {
        self.trip = trip
        _name = State(initialValue: trip?.name ?? "")
        _flexibility = State(initialValue: trip?.startFlexibility ?? .exact)

        if let trip, !trip.sortedSegments.isEmpty {
            _drafts = State(
                initialValue: trip.sortedSegments.map {
                    let resolvedPlace: GeocodedPlace?
                    if let latitude = $0.latitude, let longitude = $0.longitude {
                        resolvedPlace = GeocodedPlace(
                            name: $0.placeName,
                            regionName: $0.regionName,
                            countryName: $0.countryName,
                            latitude: latitude,
                            longitude: longitude,
                            timeZoneIdentifier: $0.timeZoneIdentifier
                        )
                    } else {
                        resolvedPlace = nil
                    }
                    return SegmentDraft(
                        id: $0.id,
                        placeName: $0.placeName,
                        startDate: $0.startDate,
                        endDate: $0.endDate,
                        resolvedPlace: resolvedPlace
                    )
                }
            )
        } else {
            let today = Calendar.current.startOfDay(for: .now)
            _drafts = State(initialValue: [SegmentDraft(startDate: today, endDate: today)])
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Reise") {
                    TextField("Name der Reise", text: $name)
                        .textInputAutocapitalization(.words)
                }
                .themedListRow()

                Section {
                    Picker(String(localized: "trip.flexibility.title"), selection: $flexibility) {
                        ForEach(TripStartFlexibility.allCases) { value in
                            Text(String(localized: String.LocalizationValue(value.localizationKey)))
                                .tag(value)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityLabel(String(localized: "trip.flexibility.title"))

                    Text(String(localized: "trip.flexibility.editorExplanation"))
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryText)
                } header: {
                    Text(String(localized: "trip.flexibility.title"))
                }
                .themedListRow()

                Section {
                    ForEach($drafts) { $draft in
                        SegmentEditorCard(
                            draft: $draft,
                            suggestions: autocomplete.suggestions(for: draft.id),
                            isLoadingSuggestions: autocomplete.isLoading(draft.id),
                            onQueryChanged: { query in
                                draft.clearResolvedPlaceIfNeeded(for: query)
                                autocomplete.search(draftID: draft.id, text: query)
                            },
                            onSelect: { place in
                                autocomplete.accept(place, for: draft.id)
                                draft.apply(place)
                            }
                        )
                    }
                    .onDelete(perform: deleteDrafts)

                    Button(action: addDraft) {
                        Label("Weiteren Ort hinzufügen", systemImage: "plus.circle.fill")
                    }
                } header: {
                    Text("Aufenthalte")
                } footer: {
                    Text("Mehrere Orte am selben Tag sind möglich. Aufenthalte müssen ansonsten direkt aufeinanderfolgen.")
                        .foregroundStyle(AppTheme.secondaryText)
                }
                .themedListRow()
            }
            .appScreenStyle()
            .navigationTitle(trip == nil ? "Neue Reise" : "Reise bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern", action: save)
                        .fontWeight(.semibold)
                }
            }
            .alert("Reise noch nicht vollständig", isPresented: showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "Unbekannter Fehler")
            }
        }
    }

    private var showError: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }

    private func addDraft() {
        let calendar = Calendar.current
        let nextStart = SegmentDraft.defaultStartDate(after: drafts.last, calendar: calendar)
        drafts.append(SegmentDraft(startDate: nextStart, endDate: nextStart))
    }

    private func deleteDrafts(at offsets: IndexSet) {
        for index in offsets {
            autocomplete.removeDraft(drafts[index].id)
        }
        drafts.remove(atOffsets: offsets)
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            errorMessage = "Bitte gib der Reise einen Namen."
            return
        }

        do {
            _ = try BuildTripTimeline()(segments: drafts.map(\.timelineSegment))
        } catch {
            errorMessage = error.localizedDescription
            return
        }

        let storedTrip: Trip
        if let trip {
            storedTrip = trip
            storedTrip.name = trimmedName
            for segment in storedTrip.segments {
                modelContext.delete(segment)
            }
            storedTrip.segments.removeAll()
        } else {
            storedTrip = Trip(name: trimmedName)
            modelContext.insert(storedTrip)
        }

        storedTrip.updatedAt = .now
        storedTrip.startFlexibility = flexibility
        // Keep the user's order for multiple locations on the same day.
        for draft in drafts {
            let segment = TripSegment(
                id: draft.id,
                placeName: draft.placeName.trimmingCharacters(in: .whitespacesAndNewlines),
                regionName: draft.resolvedPlace?.regionName,
                countryName: draft.resolvedPlace?.countryName,
                latitude: draft.resolvedPlace?.latitude,
                longitude: draft.resolvedPlace?.longitude,
                timeZoneIdentifier: draft.resolvedPlace?.timeZoneIdentifier,
                startDate: Calendar.current.startOfDay(for: draft.startDate),
                endDate: Calendar.current.startOfDay(for: draft.endDate),
                trip: storedTrip
            )
            modelContext.insert(segment)
            storedTrip.segments.append(segment)
        }

        do {
            try modelContext.save()
            if storedTrip.forecastNotificationEnabled,
               let start = storedTrip.startDate,
               let end = storedTrip.endDate {
                Task {
                    let manager = ForecastNotificationManager()
                    if storedTrip.startFlexibility == .exact {
                        try? await manager.schedule(
                            tripID: storedTrip.id,
                            tripName: storedTrip.name,
                            firstTravelDate: start,
                            calendar: .autoupdatingCurrent
                        )
                    } else {
                        try? await manager.scheduleFlexibleTrip(
                            tripID: storedTrip.id,
                            tripName: storedTrip.name,
                            originalEndDate: end,
                            flexibility: storedTrip.startFlexibility,
                            calendar: .autoupdatingCurrent
                        )
                    }
                }
            }
            dismiss()
        } catch {
            errorMessage = "Die Reise konnte nicht gespeichert werden."
        }
    }
}

private struct SegmentEditorCard: View {
    @Binding var draft: SegmentDraft
    let suggestions: [GeocodedPlace]
    let isLoadingSuggestions: Bool
    let onQueryChanged: (String) -> Void
    let onSelect: (GeocodedPlace) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Ort", text: $draft.placeName)
                .textInputAutocapitalization(.words)
                .font(.headline)
                .autocorrectionDisabled()
                .onChange(of: draft.placeName) { _, newValue in
                    onQueryChanged(newValue)
                }

            if isLoadingSuggestions {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Orte werden gesucht …")
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryText)
                }
            }

            if !suggestions.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(suggestions.enumerated()), id: \.element.id) { index, place in
                        Button {
                            onSelect(place)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "mappin.circle.fill")
                                    .foregroundStyle(AppTheme.accent)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(place.name)
                                        .foregroundStyle(AppTheme.primaryText)
                                    if !place.subtitle.isEmpty {
                                        Text(place.subtitle)
                                            .font(.caption)
                                            .foregroundStyle(AppTheme.secondaryText)
                                    }
                                }
                                Spacer()
                            }
                            .contentShape(Rectangle())
                            .padding(.vertical, 9)
                        }
                        .buttonStyle(.plain)

                        if index < suggestions.count - 1 {
                            Divider()
                                .overlay(AppTheme.border)
                        }
                    }
                }
                .padding(.horizontal, 10)
                .background(AppTheme.surfaceSecondary, in: RoundedRectangle(cornerRadius: 12))
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppTheme.border, lineWidth: 1)
                }
            }

            DatePicker("Von", selection: startDateBinding, displayedComponents: .date)
            DatePicker(
                "Bis",
                selection: endDateBinding,
                in: Calendar.autoupdatingCurrent.startOfDay(for: draft.startDate)...,
                displayedComponents: .date
            )
        }
        .padding(.vertical, 6)
    }

    private var startDateBinding: Binding<Date> {
        Binding(
            get: { draft.startDate },
            set: { draft.setStartDate($0) }
        )
    }

    private var endDateBinding: Binding<Date> {
        Binding(
            get: { draft.endDate },
            set: { draft.setEndDate($0) }
        )
    }
}
