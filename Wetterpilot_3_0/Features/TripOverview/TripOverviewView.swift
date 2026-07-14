import SwiftData
import SwiftUI

struct TripOverviewView: View {
    @Environment(\.modelContext) private var modelContext
    let trip: Trip
    @StateObject private var weatherModel = TripWeatherModel()
    @State private var showsEditor = false

    private var timeline: [TripDay] {
        let segments = trip.sortedSegments.map {
            TimelineSegment(
                id: $0.id,
                placeName: $0.placeName,
                startDate: $0.startDate,
                endDate: $0.endDate
            )
        }
        return (try? BuildTripTimeline()(segments: segments)) ?? []
    }

    var body: some View {
        List {
            weatherStatus

            Section("Reiseverlauf") {
                ForEach(timeline) { day in
                    NavigationLink {
                        DayWeatherDetailView(
                            day: day,
                            weather: weatherModel.weather(for: day),
                            unavailableMessage: weatherModel.unavailableMessage(for: day)
                        )
                    } label: {
                        TripDayRow(
                            day: day,
                            weather: weatherModel.weather(for: day),
                            unavailableMessage: weatherModel.unavailableMessage(for: day)
                        )
                    }
                }
            }
            .themedListRow()
        }
        .listStyle(.insetGrouped)
        .appScreenStyle()
        .navigationTitle(trip.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    Task {
                        await weatherModel.load(trip: trip, modelContext: modelContext, force: true)
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(weatherModel.isLoading)
                .accessibilityLabel("Wetter aktualisieren")

                Button("Bearbeiten") { showsEditor = true }
            }
        }
        .sheet(isPresented: $showsEditor) {
            TripEditorView(trip: trip)
        }
        .task(id: trip.updatedAt) {
            await weatherModel.load(trip: trip, modelContext: modelContext, force: true)
        }
    }

    @ViewBuilder
    private var weatherStatus: some View {
        Section {
            HStack(spacing: 12) {
                if weatherModel.isLoading {
                    ProgressView()
                } else {
                    Image(systemName: weatherModel.lastUpdated == nil ? "cloud.slash" : "checkmark.icloud")
                        .font(.title2)
                        .foregroundStyle(weatherModel.lastUpdated == nil ? AppTheme.secondaryText : AppTheme.accent)
                }

                VStack(alignment: .leading, spacing: 3) {
                    if weatherModel.isLoading {
                        Text("Wetter wird geladen …")
                            .font(.subheadline.weight(.semibold))
                    } else if let lastUpdated = weatherModel.lastUpdated {
                        Text("Wetter aktualisiert")
                            .font(.subheadline.weight(.semibold))
                        Text(lastUpdated, format: .dateTime.day().month().hour().minute())
                            .font(.caption)
                            .foregroundStyle(AppTheme.secondaryText)
                    } else {
                        Text("Keine Wetterdaten verfügbar")
                            .font(.subheadline.weight(.semibold))
                        Text("Prüfe die Ortsnamen und deine Internetverbindung.")
                            .font(.caption)
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                }
            }
        }
        .themedListRow()
    }
}

private struct TripDayRow: View {
    let day: TripDay
    let weather: WeatherDay?
    let unavailableMessage: String

    var body: some View {
        HStack(spacing: 14) {
            VStack(spacing: 1) {
                Text(day.date, format: .dateTime.weekday(.abbreviated))
                    .font(.caption2.weight(.semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(AppTheme.secondaryText)
                Text(day.date, format: .dateTime.day())
                    .font(.title2.weight(.bold))
            }
            .frame(width: 42)

            VStack(alignment: .leading, spacing: 3) {
                Text(day.placeName)
                    .font(.headline)
                Text("Tag \(day.dayNumber)")
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)

                if weather == nil {
                    Text(unavailableMessage)
                        .font(.caption2)
                        .foregroundStyle(AppTheme.secondaryText)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 8)

            if let weather {
                HStack(spacing: 9) {
                    Text(weather.symbol)
                        .font(.title2)
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(
                            "\(weather.minimumTemperature, specifier: "%.0f")–\(weather.maximumTemperature, specifier: "%.0f") °C"
                        )
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                        .fixedSize(horizontal: true, vertical: false)

                        HStack(spacing: 7) {
                            if let probability = weather.precipitationProbability {
                                Label("\(probability)%", systemImage: "drop.fill")
                            } else {
                                Label("\(weather.precipitationAmount, specifier: "%.1f") mm", systemImage: "drop.fill")
                            }
                            Label("\(weather.maximumWindSpeed, specifier: "%.0f")", systemImage: "wind")
                        }
                        .font(.caption2)
                        .foregroundStyle(AppTheme.secondaryText)
                        .labelStyle(.titleAndIcon)
                        .fixedSize(horizontal: true, vertical: false)
                    }
                }
            } else {
                Image(systemName: "cloud.slash")
                    .font(.title3)
                    .foregroundStyle(AppTheme.secondaryText.opacity(0.65))
            }
        }
        .padding(.vertical, 5)
    }
}
