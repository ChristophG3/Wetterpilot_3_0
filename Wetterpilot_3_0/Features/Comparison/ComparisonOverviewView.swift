import SwiftData
import SwiftUI

struct ComparisonOverviewView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("temperatureUnit") private var temperatureUnitRaw = TemperatureUnit.celsius.rawValue
    @AppStorage("windSpeedUnit") private var windUnitRaw = WindSpeedUnit.kilometersPerHour.rawValue
    let comparison: DestinationComparison
    @StateObject private var weatherModel = ComparisonWeatherModel()
    @State private var showsEditor = false
    @State private var showsNotificationExplanation = false
    @State private var tripToOpen: Trip?

    private var temperatureUnit: TemperatureUnit { TemperatureUnit(rawValue: temperatureUnitRaw) ?? .celsius }
    private var windUnit: WindSpeedUnit { WindSpeedUnit(rawValue: windUnitRaw) ?? .kilometersPerHour }

    var body: some View {
        List {
            statusSection
            tendenciesSection
            candidateSection
            daySection
            notificationSection
            Section {
                Link(destination: URL(string: "https://open-meteo.com/")!) {
                    Label(String(localized: "weather.attribution"), systemImage: "arrow.up.right.square")
                        .frame(minHeight: 44)
                }
            }
            .themedListRow()
        }
        .listStyle(.insetGrouped)
        .appScreenStyle()
        .navigationTitle(comparison.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    Task { await weatherModel.load(comparison: comparison, modelContext: modelContext, force: true) }
                } label: { Image(systemName: "arrow.clockwise") }
                .disabled(weatherModel.isLoading)
                .accessibilityLabel(String(localized: "weather.refresh"))
                Button(String(localized: "common.edit")) { showsEditor = true }
            }
        }
        .sheet(isPresented: $showsEditor) { ComparisonEditorView(comparison: comparison) }
        .sheet(isPresented: $showsNotificationExplanation) { notificationExplanation }
        .navigationDestination(isPresented: Binding(
            get: { tripToOpen != nil },
            set: { if !$0 { tripToOpen = nil } }
        )) {
            if let tripToOpen { TripOverviewView(trip: tripToOpen) }
        }
        .task(id: comparison.updatedAt) {
            await weatherModel.load(comparison: comparison, modelContext: modelContext)
            if comparison.forecastNotificationEnabled { await rescheduleNotification() }
        }
    }

    private var statusSection: some View {
        Section {
            HStack(alignment: .top, spacing: 12) {
                statusIcon.font(.title2).frame(width: 30)
                VStack(alignment: .leading, spacing: 4) {
                    Text(statusTitle).font(.subheadline.weight(.semibold))
                    Text(statusDetail).font(.caption).foregroundStyle(AppTheme.secondaryText)
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
        case .partiallyAvailable: Image(systemName: "rectangle.split.3x1").foregroundStyle(AppTheme.warning)
        case .outsideForecastRange: Image(systemName: "calendar.badge.clock").foregroundStyle(AppTheme.secondaryText)
        case .stale: Image(systemName: "clock.arrow.circlepath").foregroundStyle(AppTheme.warning)
        case .failed: Image(systemName: "cloud.slash").foregroundStyle(AppTheme.secondaryText)
        }
    }

    private var statusTitle: String {
        switch weatherModel.state {
        case .loading: return String(localized: "forecast.loading")
        case .available: return String(localized: "comparison.forecast.available")
        case .partiallyAvailable: return String(localized: "comparison.forecast.partial")
        case .outsideForecastRange: return String(localized: "forecast.notYetAvailable")
        case .stale: return String(localized: "forecast.stale")
        case .failed: return String(localized: "forecast.failed")
        }
    }

    private var statusDetail: String {
        let shared = weatherModel.result?.sharedAvailableDateKeys.count ?? 0
        let requested = weatherModel.result?.requestedDateKeys.count ?? 0
        switch weatherModel.state {
        case .loading: return String(localized: "comparison.loading.detail")
        case .available(let date), .stale(let date):
            return String(localized: "comparison.sharedDays.updated \(shared) \(requested) \(date.formatted(date: .abbreviated, time: .shortened))")
        case .partiallyAvailable(_, let availableFrom, _):
            return String(localized: "comparison.sharedDays.partial \(shared) \(requested) \(availableFrom.formatted(date: .abbreviated, time: .omitted))")
        case .outsideForecastRange(let date):
            return String(localized: "forecast.expectedFrom \(date.formatted(date: .long, time: .omitted))")
        case .failed: return String(localized: "forecast.failed.detail")
        }
    }

    @ViewBuilder private var tendenciesSection: some View {
        if let result = weatherModel.result {
            Section(String(localized: "comparison.tendencies")) {
                if !result.hasSufficientSharedData {
                    Label(String(localized: "comparison.tendencies.insufficient"), systemImage: "equal.circle")
                        .foregroundStyle(AppTheme.secondaryText).accessibilityElement(children: .combine)
                } else if result.tendencies.isEmpty {
                    Label(String(localized: "comparison.tendencies.equal"), systemImage: "equal.circle")
                        .foregroundStyle(AppTheme.secondaryText).accessibilityElement(children: .combine)
                } else {
                    ForEach(result.tendencies) { tendency in
                        Label(tendencyText(tendency), systemImage: tendencySymbol(tendency))
                            .accessibilityElement(children: .combine)
                    }
                }
            }
            .themedListRow()
        }
    }

    @ViewBuilder private var candidateSection: some View {
        if let result = weatherModel.result {
            Section {
                ForEach(result.metrics) { metrics in
                    ComparisonMetricsCard(
                        metrics: metrics, temperatureUnit: temperatureUnit, windUnit: windUnit,
                        onConvert: { convertToTrip(candidateID: metrics.candidateID) }
                    )
                }
            } header: { Text(String(localized: "comparison.overview")) }
              footer: { Text(String(localized: "comparison.dryDefinition")) }
            .themedListRow()
        }
    }

    @ViewBuilder private var daySection: some View {
        if let result = weatherModel.result {
            Section(String(localized: "comparison.days")) {
                ForEach(result.requestedDateKeys, id: \.self) { dateKey in
                    NavigationLink {
                        ComparisonDayView(
                            dateKey: dateKey, candidates: comparison.sortedCandidates,
                            weatherByCandidate: weatherModel.weatherByCandidate,
                            temperatureUnit: temperatureUnit, windUnit: windUnit
                        )
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(date(from: dateKey), format: .dateTime.weekday(.wide).day().month(.wide))
                                Text(result.sharedAvailableDateKeys.contains(dateKey)
                                     ? String(localized: "comparison.day.comparable")
                                     : String(localized: "comparison.day.incomplete"))
                                    .font(.caption).foregroundStyle(AppTheme.secondaryText)
                            }
                            Spacer()
                            Image(systemName: result.sharedAvailableDateKeys.contains(dateKey) ? "checkmark.circle" : "exclamationmark.circle")
                                .foregroundStyle(result.sharedAvailableDateKeys.contains(dateKey) ? AppTheme.success : AppTheme.warning)
                                .accessibilityHidden(true)
                        }
                        .frame(minHeight: 44).accessibilityElement(children: .combine)
                    }
                }
            }
            .themedListRow()
        }
    }

    private var notificationSection: some View {
        Section {
            Button {
                if comparison.forecastNotificationEnabled {
                    comparison.forecastNotificationEnabled = false
                    ForecastNotificationManager().removeComparison(comparisonID: comparison.id)
                    try? modelContext.save()
                } else { showsNotificationExplanation = true }
            } label: {
                Label(
                    comparison.forecastNotificationEnabled ? String(localized: "notification.disable") : String(localized: "comparison.notification.enable"),
                    systemImage: comparison.forecastNotificationEnabled ? "bell.badge.fill" : "bell"
                ).frame(minHeight: 44)
            }
        }
        .themedListRow()
    }

    private var notificationExplanation: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                Image(systemName: "bell.badge").font(.system(size: 44)).foregroundStyle(AppTheme.accent)
                Text(String(localized: "comparison.notification.explanation.title")).font(.title2.bold())
                Text(String(localized: "comparison.notification.explanation.body")).foregroundStyle(AppTheme.secondaryText)
                Button(String(localized: "notification.allow")) {
                    Task {
                        let manager = ForecastNotificationManager()
                        if (try? await manager.requestAuthorization()) == true {
                            comparison.forecastNotificationEnabled = true
                            try? modelContext.save()
                            await rescheduleNotification()
                        }
                        showsNotificationExplanation = false
                    }
                }
                .buttonStyle(GradientPrimaryButtonStyle())
                Spacer()
            }
            .padding().appScreenStyle()
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(String(localized: "common.cancel")) { showsNotificationExplanation = false } } }
        }
        .presentationDetents([.medium])
    }

    private func tendencyText(_ tendency: ComparisonTendency) -> String {
        switch tendency.kind {
        case .moreDryDays(let difference): return String(localized: "comparison.tendency.dry \(tendency.placeName) \(difference)")
        case .lessPrecipitation(let difference): return String(localized: "comparison.tendency.rain \(tendency.placeName) \(difference.formatted(.number.precision(.fractionLength(1))))")
        case .lessWind(let difference): return String(localized: "comparison.tendency.wind \(tendency.placeName) \(windUnit.value(fromKilometersPerHour: difference).formatted(.number.precision(.fractionLength(0)))) \(windUnit.symbol)")
        }
    }

    private func tendencySymbol(_ tendency: ComparisonTendency) -> String {
        switch tendency.kind {
        case .moreDryDays: return "sun.max"
        case .lessPrecipitation: return "drop"
        case .lessWind: return "wind"
        }
    }

    private func convertToTrip(candidateID: UUID) {
        guard let candidate = comparison.candidates.first(where: { $0.id == candidateID }) else { return }
        let trip = CandidateToTripConverter.makeTrip(candidate: candidate, comparison: comparison)
        modelContext.insert(trip)
        for segment in trip.segments { modelContext.insert(segment) }
        do {
            try modelContext.save()
            tripToOpen = trip
        } catch { }
    }

    private func rescheduleNotification() async {
        try? await ForecastNotificationManager().scheduleComparison(
            comparisonID: comparison.id, comparisonName: comparison.name, startDate: comparison.startDate
        )
    }

    private func date(from key: String) -> Date {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        return Calendar.autoupdatingCurrent.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2])) ?? .now
    }
}

private struct ComparisonMetricsCard: View {
    let metrics: ComparisonCandidateMetrics
    let temperatureUnit: TemperatureUnit
    let windUnit: WindSpeedUnit
    let onConvert: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(metrics.placeName).font(.headline)
            metric(String(localized: "comparison.metric.days"), "\(metrics.comparedDayCount)", "calendar")
            metric(String(localized: "comparison.metric.dryDays"), "\(metrics.dryDayCount)", "sun.max")
            metric(String(localized: "comparison.metric.rainSum"), "\(metrics.precipitationSum.formatted(.number.precision(.fractionLength(1)))) mm", "drop.fill")
            metric(String(localized: "comparison.metric.rainProbability"), metrics.maximumPrecipitationProbability.map { "\($0)%" } ?? "–", "percent")
            metric(String(localized: "comparison.metric.temperature"), temperatureText, "thermometer.medium")
            metric(String(localized: "comparison.metric.wind"), windText, "wind")
            if !metrics.advisories.isEmpty {
                VStack(alignment: .leading, spacing: 5) {
                    Text(String(localized: "weather.advisories.title")).font(.caption.weight(.semibold))
                    ForEach(metrics.advisories, id: \.self) { kind in
                        Label(String(localized: String.LocalizationValue(kind.localizationKey)), systemImage: kind.symbolName)
                            .font(.caption).accessibilityElement(children: .combine)
                    }
                }
            }
            Button(action: onConvert) {
                Label(String(localized: "comparison.convertToTrip"), systemImage: "arrow.right.circle.fill")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.bordered)
        }
        .padding(.vertical, 6).accessibilityElement(children: .contain)
    }

    private func metric(_ title: String, _ value: String, _ icon: String) -> some View {
        HStack {
            Label(title, systemImage: icon).foregroundStyle(AppTheme.secondaryText)
            Spacer()
            Text(value).monospacedDigit()
        }
        .font(.subheadline).accessibilityElement(children: .combine)
    }

    private var temperatureText: String {
        "\(temperatureUnit.value(fromCelsius: metrics.minimumTemperature).formatted(.number.precision(.fractionLength(0))))–\(temperatureUnit.value(fromCelsius: metrics.maximumTemperature).formatted(.number.precision(.fractionLength(0)))) \(temperatureUnit.symbol)"
    }
    private var windText: String {
        let wind = windUnit.value(fromKilometersPerHour: metrics.maximumWindSpeed).formatted(.number.precision(.fractionLength(0)))
        guard let gust = metrics.maximumWindGust else { return "\(wind) \(windUnit.symbol)" }
        let gustText = windUnit.value(fromKilometersPerHour: gust).formatted(.number.precision(.fractionLength(0)))
        return String(localized: "comparison.metric.windAndGust \(wind) \(gustText) \(windUnit.symbol)")
    }
}

private struct ComparisonDayView: View {
    let dateKey: String
    let candidates: [ComparisonCandidate]
    let weatherByCandidate: [UUID: [String: WeatherDay]]
    let temperatureUnit: TemperatureUnit
    let windUnit: WindSpeedUnit

    var body: some View {
        List {
            ForEach(candidates) { candidate in
                VStack(alignment: .leading, spacing: 9) {
                    Text(candidate.placeName).font(.headline)
                    if let weather = weatherByCandidate[candidate.id]?[dateKey] {
                        HStack {
                            Image(systemName: weather.symbolName).symbolRenderingMode(.multicolor).font(.title2)
                            Text(String(localized: String.LocalizationValue(weather.conditionLocalizationKey)))
                        }
                        value(String(localized: "metric.temperature"), temperature(weather), "thermometer.medium")
                        value(String(localized: "metric.rain"), rain(weather), "drop.fill")
                        value(String(localized: "metric.wind"), wind(weather), "wind")
                        ForEach(WeatherAdvisoryEvaluator.advisories(for: weather)) { advisory in
                            Label(String(localized: String.LocalizationValue(advisory.kind.localizationKey)), systemImage: advisory.kind.symbolName)
                                .font(.caption)
                        }
                    } else {
                        Label(String(localized: "comparison.day.candidateUnavailable"), systemImage: "calendar.badge.clock")
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                }
                .padding(.vertical, 7)
                .accessibilityElement(children: .combine)
            }
            .themedListRow()
        }
        .listStyle(.insetGrouped).appScreenStyle()
        .navigationTitle(
            date(from: dateKey).formatted(.dateTime.weekday(.wide).day().month(.wide))
        )
        .navigationBarTitleDisplayMode(.inline)
    }

    private func value(_ title: String, _ value: String, _ icon: String) -> some View {
        HStack { Label(title, systemImage: icon); Spacer(); Text(value).monospacedDigit() }.font(.subheadline)
    }
    private func temperature(_ weather: WeatherDay) -> String {
        "\(temperatureUnit.value(fromCelsius: weather.minimumTemperature).formatted(.number.precision(.fractionLength(0))))–\(temperatureUnit.value(fromCelsius: weather.maximumTemperature).formatted(.number.precision(.fractionLength(0)))) \(temperatureUnit.symbol)"
    }
    private func rain(_ weather: WeatherDay) -> String {
        "\(weather.precipitationProbability.map { "\($0)%" } ?? "–"), \(weather.precipitationAmount.formatted(.number.precision(.fractionLength(1)))) mm"
    }
    private func wind(_ weather: WeatherDay) -> String {
        let wind = windUnit.value(fromKilometersPerHour: weather.maximumWindSpeed).formatted(.number.precision(.fractionLength(0)))
        let gust = weather.maximumWindGust.map { windUnit.value(fromKilometersPerHour: $0).formatted(.number.precision(.fractionLength(0))) }
        return gust.map { String(localized: "comparison.metric.windAndGust \(wind) \($0) \(windUnit.symbol)") } ?? "\(wind) \(windUnit.symbol)"
    }

    private func date(from key: String) -> Date {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return .now }
        return Calendar.autoupdatingCurrent.date(
            from: DateComponents(year: parts[0], month: parts[1], day: parts[2])
        ) ?? .now
    }
}
