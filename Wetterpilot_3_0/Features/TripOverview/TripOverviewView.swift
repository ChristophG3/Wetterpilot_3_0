import SwiftData
import SwiftUI

struct TripOverviewView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("temperatureUnit") private var temperatureUnitRaw = TemperatureUnit.celsius.rawValue
    @AppStorage("windSpeedUnit") private var windUnitRaw = WindSpeedUnit.kilometersPerHour.rawValue
    let trip: Trip
    @StateObject private var weatherModel = TripWeatherModel()
    @State private var showsEditor = false
    @State private var showsNotificationExplanation = false

    private var temperatureUnit: TemperatureUnit { TemperatureUnit(rawValue: temperatureUnitRaw) ?? .celsius }
    private var windUnit: WindSpeedUnit { WindSpeedUnit(rawValue: windUnitRaw) ?? .kilometersPerHour }
    private var timeline: [TripDay] {
        let segments = trip.sortedSegments.map {
            TimelineSegment(id: $0.id, placeName: $0.placeName, startDate: $0.startDate, endDate: $0.endDate)
        }
        return (try? BuildTripTimeline()(segments: segments)) ?? []
    }

    var body: some View {
        List {
            weatherStatus
            notificationSection

            Section(String(localized: "trip.timeline")) {
                ForEach(timeline) { day in
                    NavigationLink {
                        DayWeatherDetailView(
                            day: day, weather: weatherModel.weather(for: day),
                            unavailableMessage: weatherModel.unavailableMessage(for: day),
                            temperatureUnit: temperatureUnit, windUnit: windUnit
                        )
                    } label: {
                        TripDayRow(
                            day: day, weather: weatherModel.weather(for: day),
                            unavailableMessage: weatherModel.unavailableMessage(for: day),
                            temperatureUnit: temperatureUnit, windUnit: windUnit
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
                    Task { await weatherModel.load(trip: trip, modelContext: modelContext, force: true) }
                } label: { Image(systemName: "arrow.clockwise") }
                .disabled(weatherModel.isLoading)
                .accessibilityLabel(String(localized: "weather.refresh"))
                Button(String(localized: "common.edit")) { showsEditor = true }
            }
        }
        .sheet(isPresented: $showsEditor) { TripEditorView(trip: trip) }
        .sheet(isPresented: $showsNotificationExplanation) { notificationExplanation }
        .task(id: trip.updatedAt) {
            await weatherModel.load(trip: trip, modelContext: modelContext)
            if trip.forecastNotificationEnabled { await rescheduleNotification() }
        }
    }

    private var weatherStatus: some View {
        Section {
            HStack(alignment: .top, spacing: 12) {
                statusIcon
                    .font(.title2)
                    .frame(width: 30)
                VStack(alignment: .leading, spacing: 4) {
                    Text(statusTitle).font(.subheadline.weight(.semibold))
                    if let detail = statusDetail {
                        Text(detail).font(.caption).foregroundStyle(AppTheme.secondaryText)
                    }
                }
            }
            .accessibilityElement(children: .combine)
        }
        .themedListRow()
    }

    @ViewBuilder private var statusIcon: some View {
        switch weatherModel.state {
        case .loading: ProgressView()
        case .available: Image(systemName: "checkmark.icloud").foregroundStyle(AppTheme.accent)
        case .partiallyAvailable: Image(systemName: "cloud.sun").foregroundStyle(AppTheme.warning)
        case .outsideForecastRange: Image(systemName: "calendar.badge.clock").foregroundStyle(AppTheme.secondaryText)
        case .stale: Image(systemName: "clock.arrow.circlepath").foregroundStyle(AppTheme.warning)
        case .failed: Image(systemName: "cloud.slash").foregroundStyle(AppTheme.secondaryText)
        }
    }

    private var statusTitle: String {
        switch weatherModel.state {
        case .loading: return String(localized: "forecast.loading")
        case .available: return String(localized: "forecast.available")
        case .partiallyAvailable: return String(localized: "forecast.partiallyAvailable")
        case .outsideForecastRange: return String(localized: "forecast.notYetAvailable")
        case .stale: return String(localized: "forecast.stale")
        case .failed: return String(localized: "forecast.failed")
        }
    }

    private var statusDetail: String? {
        switch weatherModel.state {
        case .loading: return nil
        case .available(let date), .stale(let date):
            return date.formatted(.dateTime.day().month().hour().minute())
        case .partiallyAvailable(let dates, let availableFrom, _):
            return String(localized: "forecast.partial.detail \(dates.count) \(availableFrom.formatted(date: .abbreviated, time: .omitted))")
        case .outsideForecastRange(let date):
            return String(localized: "forecast.expectedFrom \(date.formatted(date: .long, time: .omitted))")
        case .failed:
            return String(localized: "forecast.failed.detail")
        }
    }

    private var notificationSection: some View {
        Section {
            Button {
                if trip.forecastNotificationEnabled {
                    trip.forecastNotificationEnabled = false
                    ForecastNotificationManager().remove(tripID: trip.id)
                    try? modelContext.save()
                } else {
                    showsNotificationExplanation = true
                }
            } label: {
                Label(
                    trip.forecastNotificationEnabled
                        ? String(localized: "notification.disable")
                        : String(localized: "notification.enable"),
                    systemImage: trip.forecastNotificationEnabled ? "bell.badge.fill" : "bell"
                )
                .frame(minHeight: 44)
            }
        }
        .themedListRow()
    }

    private var notificationExplanation: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                Image(systemName: "bell.badge").font(.system(size: 44)).foregroundStyle(AppTheme.accent)
                Text(String(localized: "notification.explanation.title")).font(.title2.bold())
                Text(String(localized: "notification.explanation.body")).foregroundStyle(AppTheme.secondaryText)
                Button(String(localized: "notification.allow")) {
                    Task {
                        let manager = ForecastNotificationManager()
                        if (try? await manager.requestAuthorization()) == true {
                            trip.forecastNotificationEnabled = true
                            try? modelContext.save()
                            await rescheduleNotification()
                        }
                        showsNotificationExplanation = false
                    }
                }
                .buttonStyle(GradientPrimaryButtonStyle())
                Spacer()
            }
            .padding()
            .appScreenStyle()
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(String(localized: "common.cancel")) { showsNotificationExplanation = false } } }
        }
        .presentationDetents([.medium])
    }

    private func rescheduleNotification() async {
        guard let start = trip.startDate else { return }
        try? await ForecastNotificationManager().schedule(
            tripID: trip.id, tripName: trip.name, firstTravelDate: start, calendar: .autoupdatingCurrent
        )
    }
}

private struct TripDayRow: View {
    let day: TripDay
    let weather: WeatherDay?
    let unavailableMessage: String
    let temperatureUnit: TemperatureUnit
    let windUnit: WindSpeedUnit

    var body: some View {
        HStack(spacing: 14) {
            VStack(spacing: 1) {
                Text(day.date, format: .dateTime.weekday(.abbreviated)).font(.caption2.weight(.semibold)).textCase(.uppercase)
                Text(day.date, format: .dateTime.day()).font(.title2.weight(.bold))
            }
            .foregroundStyle(AppTheme.secondaryText)
            .frame(width: 42)
            VStack(alignment: .leading, spacing: 3) {
                Text(day.placeName).font(.headline)
                Text(String(localized: "trip.day \(day.dayNumber)")).font(.caption).foregroundStyle(AppTheme.secondaryText)
                if weather == nil { Text(unavailableMessage).font(.caption2).foregroundStyle(AppTheme.secondaryText).lineLimit(2) }
            }
            Spacer(minLength: 8)
            if let weather {
                HStack(spacing: 9) {
                    Image(systemName: weather.symbolName).font(.title2).symbolRenderingMode(.multicolor)
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(temperatureUnit.value(fromCelsius: weather.minimumTemperature), format: .number.precision(.fractionLength(0)))–\(temperatureUnit.value(fromCelsius: weather.maximumTemperature), format: .number.precision(.fractionLength(0))) \(temperatureUnit.symbol)")
                            .font(.subheadline.weight(.semibold)).monospacedDigit().fixedSize(horizontal: true, vertical: false)
                        HStack(spacing: 7) {
                            Label("\(weather.precipitationProbability ?? 0)%", systemImage: "drop.fill")
                            Label("\(windUnit.value(fromKilometersPerHour: weather.maximumWindSpeed), format: .number.precision(.fractionLength(0)))", systemImage: "wind")
                        }
                        .font(.caption2).foregroundStyle(AppTheme.secondaryText).fixedSize(horizontal: true, vertical: false)
                    }
                }
            } else {
                Image(systemName: "calendar.badge.clock").font(.title3).foregroundStyle(AppTheme.secondaryText)
            }
        }
        .padding(.vertical, 7)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        if let weather {
            return "\(day.date.formatted(date: .long, time: .omitted)), \(day.placeName), \(temperatureUnit.value(fromCelsius: weather.minimumTemperature).formatted(.number.precision(.fractionLength(0)))) bis \(temperatureUnit.value(fromCelsius: weather.maximumTemperature).formatted(.number.precision(.fractionLength(0)))) \(temperatureUnit.symbol), \(weather.precipitationProbability ?? 0) Prozent"
        }
        return "\(day.date.formatted(date: .long, time: .omitted)), \(day.placeName), \(unavailableMessage)"
    }
}
