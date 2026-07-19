import SwiftData
import SwiftUI

struct TripOverviewView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("temperatureUnit") private var temperatureUnitRaw = TemperatureUnit.celsius.rawValue
    @AppStorage("windSpeedUnit") private var windUnitRaw = WindSpeedUnit.kilometersPerHour.rawValue
    let trip: Trip
    @StateObject private var weatherModel = TripWeatherModel()
    @StateObject private var preferencesModel = TravelWeatherPreferencesModel()
    @State private var showsEditor = false
    @State private var showsNotificationExplanation = false
    @State private var showsWeatherPreferences = false
    @State private var selectedOffset = 0

    private var temperatureUnit: TemperatureUnit { TemperatureUnit(rawValue: temperatureUnitRaw) ?? .celsius }
    private var windUnit: WindSpeedUnit { WindSpeedUnit(rawValue: windUnitRaw) ?? .kilometersPerHour }
    private var flexibleComparison: FlexibleTripStartComparison {
        weatherModel.flexibleComparison(trip: trip, preferences: preferencesModel.value)
    }
    private var selectedCandidate: TripStartCandidate? {
        flexibleComparison.candidate(offset: selectedOffset)
            ?? flexibleComparison.candidate(offset: flexibleComparison.preferredDisplayOffset)
            ?? flexibleComparison.candidates.first
    }
    private var timeline: [TripDay] {
        if trip.startFlexibility != .exact, let selectedCandidate {
            return selectedCandidate.shiftedTimeline
        }
        let segments = trip.sortedSegments.map {
            TimelineSegment(id: $0.id, placeName: $0.placeName, startDate: $0.startDate, endDate: $0.endDate)
        }
        return (try? BuildTripTimeline()(segments: segments)) ?? []
    }

    var body: some View {
        List {
            weatherStatus
            if trip.startFlexibility != .exact {
                flexibleStartSection
            }
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
        .adaptiveContentWidth()
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
                Menu {
                    Button {
                        showsEditor = true
                    } label: {
                        Label(String(localized: "common.edit"), systemImage: "pencil")
                    }
                    Button {
                        showsWeatherPreferences = true
                    } label: {
                        Label(String(localized: "trip.preferences.title"), systemImage: "slider.horizontal.3")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel(String(localized: "trip.moreOptions"))
            }
        }
        .sheet(isPresented: $showsEditor) { TripEditorView(trip: trip) }
        .sheet(isPresented: $showsWeatherPreferences) {
            TravelWeatherPreferencesView(model: preferencesModel)
        }
        .sheet(isPresented: $showsNotificationExplanation) { notificationExplanation }
        .task(id: trip.updatedAt) {
            await weatherModel.load(trip: trip, modelContext: modelContext)
            selectPreferredCandidate()
            if trip.forecastNotificationEnabled { await rescheduleNotification() }
        }
        .onReceive(preferencesModel.$value.dropFirst()) { _ in
            selectPreferredCandidate()
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
                Text(
                    trip.startFlexibility == .exact
                        ? String(localized: "notification.explanation.body")
                        : String(localized: "notification.flexible.explanation.body")
                )
                .foregroundStyle(AppTheme.secondaryText)
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
        guard let start = trip.startDate, let end = trip.endDate else { return }
        let manager = ForecastNotificationManager()
        if trip.startFlexibility == .exact {
            try? await manager.schedule(
                tripID: trip.id, tripName: trip.name,
                firstTravelDate: start, calendar: .autoupdatingCurrent
            )
        } else {
            try? await manager.scheduleFlexibleTrip(
                tripID: trip.id, tripName: trip.name,
                originalEndDate: end, flexibility: trip.startFlexibility,
                calendar: .autoupdatingCurrent
            )
        }
    }

    private var flexibleStartSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                Label(String(localized: "trip.flexible.header"), systemImage: "calendar.badge.plus")
                    .font(.headline)

                Picker(String(localized: "trip.flexible.selectedStart"), selection: $selectedOffset) {
                    ForEach(flexibleComparison.candidates) { candidate in
                        Text(candidateLabel(candidate)).tag(candidate.offset)
                    }
                }
                .pickerStyle(.menu)
                .frame(minHeight: 44)
                .accessibilityHint(String(localized: "trip.flexible.pickerHint"))

                if let candidate = selectedCandidate {
                    Label(
                        assessmentText(candidate),
                        systemImage: assessmentLevel(candidate).symbolName
                    )
                    .font(.subheadline.weight(.semibold))

                    Text(forecastText(candidate))
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryText)

                    Text(summaryText(candidate))
                        .font(.subheadline)

                    if let violation = candidate.assessment.violations.first {
                        Text(violationDetail(violation))
                            .font(.caption)
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                }

                if flexibleComparison.differencesAreSmall {
                    Label(String(localized: "trip.flexible.similar"), systemImage: "equal.circle")
                        .font(.caption)
                } else if !flexibleComparison.hasFairCommonBasis {
                    Label(String(localized: "trip.flexible.noFairRecommendation"), systemImage: "info.circle")
                        .font(.caption)
                }
            }
            .padding(.vertical, 4)
            .accessibilityElement(children: .contain)
        } header: {
            Text(String(localized: "trip.flexibility.title"))
        }
        .themedListRow()
    }

    private func selectPreferredCandidate() {
        guard trip.startFlexibility != .exact else {
            selectedOffset = 0
            return
        }
        selectedOffset = flexibleComparison.preferredDisplayOffset
    }

    private func assessmentLevel(_ candidate: TripStartCandidate) -> TripStartAssessmentLevel {
        if flexibleComparison.recommendedOffset == candidate.offset { return .recommended }
        return candidate.assessment.level
    }

    private func assessmentText(_ candidate: TripStartCandidate) -> String {
        String(localized: String.LocalizationValue(assessmentLevel(candidate).localizationKey))
    }

    private func candidateLabel(_ candidate: TripStartCandidate) -> String {
        let relation: String
        if candidate.offset == 0 {
            relation = String(localized: "trip.flexible.original")
        } else if candidate.offset < 0 {
            relation = String(localized: "trip.flexible.earlier \(abs(candidate.offset))")
        } else {
            relation = String(localized: "trip.flexible.later \(candidate.offset)")
        }
        return String(localized: "trip.flexible.candidateLabel \(candidate.startDate.formatted(date: .long, time: .omitted)) \(relation)")
    }

    private func forecastText(_ candidate: TripStartCandidate) -> String {
        switch candidate.forecastState {
        case .complete:
            return weatherModel.usesStaleData
                ? String(localized: "forecast.stale")
                : String(localized: "trip.flexible.forecastComplete")
        case .partial(let available, let total, let expected):
            if let expected {
                return String(localized: "trip.flexible.forecastPartialExpected \(available) \(total) \(expected.formatted(date: .long, time: .omitted))")
            }
            return String(localized: "trip.flexible.forecastPartial \(available) \(total)")
        case .unavailable(let expected):
            if let expected {
                return String(localized: "trip.flexible.forecastUnavailableExpected \(expected.formatted(date: .long, time: .omitted))")
            }
            return String(localized: "forecast.notYetAvailable")
        }
    }

    private func summaryText(_ candidate: TripStartCandidate) -> String {
        guard let reason = candidate.assessment.reasons.first else {
            return String(localized: "trip.flexible.noFairRecommendation")
        }
        switch reason {
        case .noThresholdExceeded:
            return String(localized: "trip.flexible.reason.none")
        case .thunderstorm(let days):
            return String(localized: "trip.flexible.reason.thunderstorm \(days)")
        case .rainProbability(let days, let maximum):
            return String(localized: "trip.flexible.reason.rainProbability \(days) \(maximum)")
        case .precipitation(let days, let maximum):
            return String(localized: "trip.flexible.reason.precipitation \(days) \(maximum.formatted(.number.precision(.fractionLength(1))))")
        case .wind(let days, let maximum):
            return String(localized: "trip.flexible.reason.wind \(days) \(windText(maximum))")
        case .gust(let days, let maximum):
            return String(localized: "trip.flexible.reason.gust \(days) \(windText(maximum))")
        case .cold(let days, let minimum):
            return String(localized: "trip.flexible.reason.cold \(days) \(temperatureText(minimum))")
        case .heat(let days, let maximum):
            return String(localized: "trip.flexible.reason.heat \(days) \(temperatureText(maximum))")
        case .incomplete(let available, let total):
            return String(localized: "trip.flexible.reason.incomplete \(available) \(total)")
        }
    }

    private func violationDetail(_ violation: TripWeatherViolation) -> String {
        String(localized: "trip.flexible.violationDay \(violation.date.formatted(date: .long, time: .omitted)) \(violation.placeName)")
    }

    private func temperatureText(_ celsius: Double) -> String {
        "\(temperatureUnit.value(fromCelsius: celsius).formatted(.number.precision(.fractionLength(0)))) \(temperatureUnit.symbol)"
    }

    private func windText(_ kilometersPerHour: Double) -> String {
        "\(windUnit.value(fromKilometersPerHour: kilometersPerHour).formatted(.number.precision(.fractionLength(0)))) \(windUnit.symbol)"
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
            let date = day.date.formatted(date: .long, time: .omitted)
            let minimum = temperatureUnit.value(fromCelsius: weather.minimumTemperature)
                .formatted(.number.precision(.fractionLength(0)))
            let maximum = temperatureUnit.value(fromCelsius: weather.maximumTemperature)
                .formatted(.number.precision(.fractionLength(0)))
            return String(
                localized: "trip.day.accessibility.weather \(date) \(day.placeName) \(minimum) \(maximum) \(temperatureUnit.symbol) \(weather.precipitationProbability ?? 0)"
            )
        }
        return "\(day.date.formatted(date: .long, time: .omitted)), \(day.placeName), \(unavailableMessage)"
    }
}
