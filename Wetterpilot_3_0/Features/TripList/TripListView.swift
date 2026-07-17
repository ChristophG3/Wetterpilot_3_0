import SwiftData
import SwiftUI

struct TripListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Trip.updatedAt, order: .reverse) private var trips: [Trip]
    @Query(sort: \DestinationComparison.updatedAt, order: .reverse) private var comparisons: [DestinationComparison]
    @State private var path = NavigationPath()
    @State private var showsNewTrip = false
    @State private var showsQuickTrip = false
    @State private var showsNewComparison = false
    @State private var showsInfo = false
    @StateObject private var weatherSummaries = TripListWeatherSummaryModel()

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section {
                    if trips.isEmpty {
                        ContentUnavailableView {
                            Label(String(localized: "trip.empty.title"), systemImage: "map")
                        } description: {
                            Text(String(localized: "trip.empty.description"))
                        } actions: {
                            Button(String(localized: "trip.new")) {
                                showsNewTrip = true
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .frame(minHeight: 44)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    } else {
                        ForEach(trips) { trip in
                            NavigationLink(value: trip) {
                                TripRow(
                                    trip: trip,
                                    weatherSummary: weatherSummaries.summaries[trip.id]
                                )
                            }
                            .themedListRow()
                        }
                        .onDelete(perform: deleteTrips)
                    }
                } header: {
                    Text(String(localized: "trip.myTrips")).font(.title2.bold()).foregroundStyle(AppTheme.primaryText).textCase(nil)
                }

                if !comparisons.isEmpty {
                    Section {
                        ForEach(comparisons) { comparison in
                            NavigationLink(value: comparison) {
                                ComparisonRow(comparison: comparison)
                            }
                            .themedListRow()
                        }
                        .onDelete(perform: deleteComparisons)
                    } header: {
                        Text(String(localized: "comparison.myComparisons"))
                            .font(.title2.bold())
                            .foregroundStyle(AppTheme.primaryText)
                            .textCase(nil)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Wetterpilot")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showsInfo = true } label: {
                        Image(systemName: "ellipsis.circle").imageScale(.large).symbolRenderingMode(.hierarchical)
                    }
                    .accessibilityLabel(String(localized: "menu.info"))
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button { showsNewTrip = true } label: {
                            Label(String(localized: "trip.new"), systemImage: "plus.circle.fill")
                        }
                        Divider()
                        Button { showsQuickTrip = true } label: { Label(String(localized: "quickTrip.title"), systemImage: "calendar.badge.checkmark") }
                        Button { showsNewComparison = true } label: { Label(String(localized: "comparison.entry.title"), systemImage: "arrow.left.arrow.right.circle") }
                    } label: { Image(systemName: "plus").frame(minWidth: 44, minHeight: 44) }
                    .accessibilityLabel(String(localized: "trip.add"))
                }
            }
            .sheet(isPresented: $showsNewTrip) { TripEditorView() }
            .sheet(isPresented: $showsQuickTrip) {
                QuickTripView { trip in Task { @MainActor in path.append(trip) } }
            }
            .sheet(isPresented: $showsNewComparison) {
                ComparisonEditorView { comparison in Task { @MainActor in path.append(comparison) } }
            }
            .sheet(isPresented: $showsInfo) { InfoView() }
            .navigationDestination(for: Trip.self) { TripOverviewView(trip: $0) }
            .navigationDestination(for: DestinationComparison.self) { ComparisonOverviewView(comparison: $0) }
            .task(id: trips.map { "\($0.id.uuidString)-\($0.updatedAt.timeIntervalSinceReferenceDate)" }.joined()) {
                await loadWeatherSummaries()
            }
            .onAppear {
                Task { await loadWeatherSummaries() }
            }
            .appScreenStyle()
        }
    }

    private func loadWeatherSummaries() async {
        await weatherSummaries.load(
            trips: trips,
            preferences: TravelWeatherPreferencesStore.load()
        )
    }

    private func deleteComparisons(at offsets: IndexSet) {
        for index in offsets {
            let comparison = comparisons[index]
            ForecastNotificationManager().removeComparison(comparisonID: comparison.id)
            modelContext.delete(comparison)
        }
        try? modelContext.save()
    }

    private func deleteTrips(at offsets: IndexSet) {
        for index in offsets {
            let trip = trips[index]
            ForecastNotificationManager().remove(tripID: trip.id)
            modelContext.delete(trip)
        }
        try? modelContext.save()
    }
}

private struct ComparisonRow: View {
    let comparison: DestinationComparison
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(comparison.name).font(.headline)
            Text("\(comparison.startDate.formatted(.dateTime.day().month(.wide))) – \(comparison.endDate.formatted(.dateTime.day().month(.wide)))")
                .font(.subheadline).foregroundStyle(AppTheme.secondaryText)
            Label(String(localized: "comparison.placeCount \(comparison.candidates.count)"), systemImage: "arrow.left.arrow.right")
                .font(.caption).foregroundStyle(AppTheme.secondaryText)
        }
        .padding(.vertical, 7).accessibilityElement(children: .combine)
    }
}

private struct TripRow: View {
    let trip: Trip
    let weatherSummary: TripCardWeatherSummary?

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(trip.name).font(.headline)
            if let start = trip.startDate, let end = trip.endDate {
                Text("\(start.formatted(.dateTime.day().month(.wide))) – \(end.formatted(.dateTime.day().month(.wide)))")
                    .font(.subheadline).foregroundStyle(AppTheme.secondaryText)
            }
            Label(
                trip.segments.count == 1
                    ? String(localized: "trip.onePlace")
                    : String(localized: "trip.placeCount \(trip.segments.count)"),
                systemImage: "mappin.and.ellipse"
            )
                .font(.caption).foregroundStyle(AppTheme.secondaryText)
            if trip.startFlexibility != .exact {
                Label(
                    String(localized: String.LocalizationValue(trip.startFlexibility.localizationKey)),
                    systemImage: "calendar.badge.plus"
                )
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)
            }
            if let weatherSummary {
                Label(
                    weatherText(weatherSummary),
                    systemImage: weatherSummary.symbolName
                )
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

                if let recommendedStartDate = weatherSummary.recommendedStartDate {
                    Label(
                        String(
                            localized: "trip.card.weather.recommendedStart \(recommendedStartDate.formatted(date: .long, time: .omitted))"
                        ),
                        systemImage: "star.fill"
                    )
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.vertical, 7).accessibilityElement(children: .combine)
    }

    private func weatherText(_ summary: TripCardWeatherSummary) -> String {
        if summary.isStale {
            return String(localized: "trip.card.weather.stale")
        }
        switch summary.forecast {
        case .predominantlyDry:
            return String(localized: "trip.card.weather.dry")
        case .mixed(let affectedDays):
            if affectedDays == 1 {
                return String(localized: "trip.card.weather.mixedOne")
            }
            return String(localized: "trip.card.weather.mixed \(affectedDays)")
        case .rainPossible(let days):
            return String(localized: "trip.card.weather.rain \(days)")
        case .complete:
            return String(localized: "trip.card.weather.complete")
        case .partial(let availableDays, let totalDays):
            return String(localized: "trip.card.weather.partial \(availableDays) \(totalDays)")
        case .availableFrom(let date):
            return String(
                localized: "trip.card.weather.availableFrom \(date.formatted(date: .long, time: .omitted))"
            )
        case .noCurrentData:
            return String(localized: "trip.card.weather.none")
        }
    }
}
