import SwiftData
import SwiftUI

struct TripListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Trip.updatedAt, order: .reverse) private var trips: [Trip]
    @State private var showsNewTrip = false
    @State private var showsInfo = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if trips.isEmpty {
                        ContentUnavailableView {
                            Label("Noch keine Reise", systemImage: "map")
                        } description: {
                            Text("Plane deine erste Rundreise und sieh später das Wetter für jeden Ort auf einen Blick.")
                        } actions: {
                            Button("Neue Reise", action: { showsNewTrip = true })
                                .buttonStyle(GradientPrimaryButtonStyle())
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 80)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    } else {
                        ForEach(trips) { trip in
                            NavigationLink(value: trip) {
                                TripRow(trip: trip)
                            }
                            .themedListRow()
                        }
                        .onDelete(perform: deleteTrips)
                    }
                } header: {
                    Text("Meine Reisen")
                        .font(.title2.bold())
                        .foregroundStyle(AppTheme.primaryText)
                        .textCase(nil)
                }

                // Keeps the collapsing header usable even when only one or two
                // journeys exist and the visible rows would otherwise be too short.
                Color.clear
                    .frame(height: 260)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .accessibilityHidden(true)
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Wetterpilot")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button { showsInfo = true } label: {
                            Label("Info", systemImage: "info.circle")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .imageScale(.large)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(AppTheme.accent)
                            .accessibilityLabel("Menü")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showsNewTrip = true }) {
                        Label("Neue Reise", systemImage: "plus")
                            .foregroundStyle(AppTheme.accent)
                    }
                }
            }
            .sheet(isPresented: $showsNewTrip) {
                TripEditorView()
            }
            .sheet(isPresented: $showsInfo) {
                InfoView()
            }
            .navigationDestination(for: Trip.self) { trip in
                TripOverviewView(trip: trip)
            }
            .appScreenStyle()
        }
    }

    private func deleteTrips(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(trips[index])
        }
        try? modelContext.save()
    }
}

private struct TripRow: View {
    let trip: Trip

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(trip.name)
                .font(.headline)

            if let start = trip.startDate, let end = trip.endDate {
                (Text(start, format: .dateTime.day().month(.wide))
                    + Text(" – ")
                    + Text(end, format: .dateTime.day().month(.wide)))
                .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
            }

            Label(
                "\(trip.segments.count) \(trip.segments.count == 1 ? "Ort" : "Orte")",
                systemImage: "mappin.and.ellipse"
            )
            .font(.caption)
            .foregroundStyle(AppTheme.secondaryText)
        }
        .padding(.vertical, 5)
    }
}
