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

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section {
                    Button { showsQuickTrip = true } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(String(localized: "quickTrip.title")).font(.headline)
                                Text(String(localized: "quickTrip.list.subtitle")).font(.caption).foregroundStyle(AppTheme.secondaryText)
                            }
                        } icon: { Image(systemName: "calendar.badge.checkmark").font(.title2) }
                        .frame(minHeight: 52)
                    }
                    Button { showsNewComparison = true } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(String(localized: "comparison.entry.title")).font(.headline)
                                Text(String(localized: "comparison.entry.subtitle")).font(.caption).foregroundStyle(AppTheme.secondaryText)
                            }
                        } icon: { Image(systemName: "arrow.left.arrow.right.circle.fill").font(.title2) }
                        .frame(minHeight: 52)
                    }
                }
                .themedListRow()

                if !comparisons.isEmpty {
                    Section {
                        ForEach(comparisons) { comparison in
                            NavigationLink(value: comparison) { ComparisonRow(comparison: comparison) }.themedListRow()
                        }
                        .onDelete(perform: deleteComparisons)
                    } header: {
                        Text(String(localized: "comparison.myComparisons"))
                            .font(.title2.bold()).foregroundStyle(AppTheme.primaryText).textCase(nil)
                    }
                }

                Section {
                    if trips.isEmpty {
                        ContentUnavailableView {
                            Label(String(localized: "trip.empty.title"), systemImage: "map")
                        } description: { Text(String(localized: "trip.empty.description")) }
                        .frame(maxWidth: .infinity).padding(.vertical, 60)
                        .listRowBackground(Color.clear).listRowSeparator(.hidden)
                    } else {
                        ForEach(trips) { trip in
                            NavigationLink(value: trip) { TripRow(trip: trip) }.themedListRow()
                        }
                        .onDelete(perform: deleteTrips)
                    }
                } header: {
                    Text(String(localized: "trip.myTrips")).font(.title2.bold()).foregroundStyle(AppTheme.primaryText).textCase(nil)
                }
                Color.clear.frame(height: 260).listRowBackground(Color.clear).listRowSeparator(.hidden).accessibilityHidden(true)
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
                        Button { showsNewTrip = true } label: { Label(String(localized: "trip.new"), systemImage: "map") }
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
            .appScreenStyle()
        }
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
        }
        .padding(.vertical, 7).accessibilityElement(children: .combine)
    }
}
