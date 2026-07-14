import SwiftData
import SwiftUI

struct QuickTripView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let onSaved: (Trip) -> Void
    @State private var placeName = ""
    @State private var date = Calendar.autoupdatingCurrent.startOfDay(for: .now)
    @State private var selectedPlace: GeocodedPlace?
    @State private var errorMessage: String?
    @State private var isSaving = false
    @StateObject private var autocomplete = PlaceAutocompleteModel()
    @State private var draftID = UUID()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(String(localized: "quickTrip.place"), text: $placeName)
                        .textInputAutocapitalization(.words)
                        .onChange(of: placeName) { _, value in
                            if selectedPlace?.name != value { selectedPlace = nil }
                            autocomplete.search(draftID: draftID, text: value)
                        }
                    if autocomplete.isLoading(draftID) { ProgressView() }
                    ForEach(autocomplete.suggestions(for: draftID)) { place in
                        Button {
                            selectedPlace = place
                            placeName = place.name
                            autocomplete.accept(place, for: draftID)
                        } label: {
                            Label {
                                VStack(alignment: .leading) {
                                    Text(place.name)
                                    if !place.subtitle.isEmpty { Text(place.subtitle).font(.caption).foregroundStyle(AppTheme.secondaryText) }
                                }
                            } icon: { Image(systemName: "mappin.circle.fill") }
                        }
                    }
                    DatePicker(String(localized: "quickTrip.date"), selection: $date, displayedComponents: .date)
                } header: { Text(String(localized: "quickTrip.required")) }
                .themedListRow()

                Section {
                    Text(String(localized: "quickTrip.explanation"))
                        .font(.footnote).foregroundStyle(AppTheme.secondaryText)
                }
                .themedListRow()
            }
            .appScreenStyle()
            .navigationTitle(String(localized: "quickTrip.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(String(localized: "common.cancel")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "quickTrip.check")) { Task { await save() } }
                        .disabled(placeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                }
            }
            .alert(String(localized: "quickTrip.error.title"), isPresented: Binding(
                get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
            )) { Button("OK", role: .cancel) {} } message: { Text(errorMessage ?? "") }
        }
    }

    @MainActor private func save() async {
        isSaving = true
        defer { isSaving = false }
        do {
            let place: GeocodedPlace
            if let selectedPlace {
                place = selectedPlace
            } else {
                place = try await OpenMeteoGeocodingService().geocode(placeName)
            }
            let travelDate = Calendar.autoupdatingCurrent.startOfDay(for: date)
            let weekday = travelDate.formatted(.dateTime.weekday(.wide))
            let trip = Trip(name: String(localized: "quickTrip.generatedName \(weekday) \(place.name)"))
            let segment = TripSegment(
                placeName: place.name, regionName: place.regionName, countryName: place.countryName,
                latitude: place.latitude, longitude: place.longitude, timeZoneIdentifier: place.timeZoneIdentifier,
                startDate: travelDate, endDate: travelDate, trip: trip
            )
            trip.segments = [segment]
            modelContext.insert(trip)
            modelContext.insert(segment)
            try modelContext.save()
            dismiss()
            onSaved(trip)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
