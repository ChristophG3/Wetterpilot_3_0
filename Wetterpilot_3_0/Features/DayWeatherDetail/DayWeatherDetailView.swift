import SwiftUI

struct DayWeatherDetailView: View {
    let day: TripDay
    let weather: WeatherDay?
    let unavailableMessage: String
    let temperatureUnit: TemperatureUnit
    let windUnit: WindSpeedUnit

    var body: some View {
        ScrollView {
            if let weather {
                VStack(spacing: 18) {
                    hero(weather)
                    advisories(weather)
                    hourlySection(weather)
                    metrics(weather)
                    Link(destination: URL(string: "https://open-meteo.com/")!) {
                        Label(String(localized: "weather.attribution"), systemImage: "arrow.up.right.square")
                    }
                    .font(.caption)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Text(String(localized: "weather.disclaimer"))
                        .font(.caption).foregroundStyle(AppTheme.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding()
            } else {
                ContentUnavailableView {
                    Label(String(localized: "detail.unavailable.title"), systemImage: "calendar.badge.clock")
                } description: { Text(unavailableMessage) }
                .padding(.top, 70)
            }
        }
        .appScreenStyle()
        .navigationTitle(day.placeName)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func hero(_ weather: WeatherDay) -> some View {
        VStack(spacing: 8) {
            Text(day.date, format: .dateTime.weekday(.wide).day().month(.wide).year())
                .font(.subheadline).foregroundStyle(AppTheme.secondaryText)
            Image(systemName: weather.symbolName)
                .font(.system(size: 58)).symbolRenderingMode(.multicolor)
                .accessibilityHidden(true)
            Text(String(localized: String.LocalizationValue(weather.conditionLocalizationKey))).font(.title2.weight(.semibold))
            Text(temperatureRange(weather)).font(.title.bold()).monospacedDigit()
        }
        .frame(maxWidth: .infinity).padding(.vertical, 22).surfaceCard()
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private func advisories(_ weather: WeatherDay) -> some View {
        let items = WeatherAdvisoryEvaluator.advisories(for: weather)
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text(String(localized: "weather.advisories.title")).font(.headline)
                ForEach(items) { advisory in
                    Label {
                        Text(String(localized: String.LocalizationValue(advisory.kind.localizationKey)))
                    } icon: {
                        Image(systemName: advisory.kind.symbolName)
                    }
                    .font(.subheadline).foregroundStyle(AppTheme.primaryText)
                    .accessibilityElement(children: .combine)
                }
                Text(String(localized: "weather.advisories.disclaimer"))
                    .font(.caption).foregroundStyle(AppTheme.secondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading).surfaceCard()
        }
    }

    private func hourlySection(_ weather: WeatherDay) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "hourly.title")).font(.headline)
            Text(summaryText(for: weather.hours)).font(.subheadline.weight(.semibold))
            if weather.hours.isEmpty {
                Text(String(localized: "hourly.unavailable")).font(.caption).foregroundStyle(AppTheme.secondaryText)
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 10) {
                            ForEach(weather.hours) { hour in
                                HourCard(
                                    hour: hour,
                                    temperatureUnit: temperatureUnit,
                                    windUnit: windUnit
                                )
                                .id(hour.id)
                            }
                        }
                    }
                    .task(id: hourlyTargetID(weather.hours)) {
                        guard let target = hourlyTargetID(weather.hours) else { return }
                        await Task.yield()
                        proxy.scrollTo(target, anchor: .leading)
                    }
                }
                .accessibilityLabel(String(localized: "hourly.accessibility.label"))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading).surfaceCard()
    }

    private func hourlyTargetID(_ hours: [WeatherHour]) -> String? {
        HourlyScrollTarget.targetID(for: day.date, hours: hours)
    }

    private func metrics(_ weather: WeatherDay) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), spacing: 12)], spacing: 12) {
            DetailMetricCard(title: String(localized: "metric.temperature"), value: temperatureRange(weather), subtitle: apparentTemperatureText(weather), systemImage: "thermometer.medium")
            DetailMetricCard(title: String(localized: "metric.rain"), value: "\(weather.precipitationProbability ?? 0)%", subtitle: "\(weather.precipitationAmount.formatted(.number.precision(.fractionLength(1)))) mm", systemImage: "drop.fill")
            DetailMetricCard(title: String(localized: "metric.wind"), value: windText(weather.maximumWindSpeed), subtitle: gustText(weather), systemImage: "wind")
            DetailMetricCard(title: String(localized: "metric.uv"), value: weather.maximumUVIndex?.formatted(.number.precision(.fractionLength(1))) ?? "–", subtitle: uvAssessment(weather.maximumUVIndex), systemImage: "sun.max.fill")
            DetailMetricCard(title: String(localized: "metric.sunrise"), value: weather.sunriseTime ?? "–", subtitle: String(localized: "metric.localTime"), systemImage: "sunrise.fill")
            DetailMetricCard(title: String(localized: "metric.sunset"), value: weather.sunsetTime ?? "–", subtitle: String(localized: "metric.localTime"), systemImage: "sunset.fill")
        }
    }

    private func summaryText(for hours: [WeatherHour]) -> String {
        switch HourlyWeatherSummary.evaluate(hours) {
        case .mostlyDry: return String(localized: "hourly.summary.mostlyDry")
        case .rainFrom(let hour): return String(localized: "hourly.summary.rainFrom \(hour)")
        case .showersPossible: return String(localized: "hourly.summary.showersPossible")
        case .unavailable: return String(localized: "hourly.summary.unavailable")
        }
    }

    private func temperatureRange(_ weather: WeatherDay) -> String {
        "\(temperatureUnit.value(fromCelsius: weather.minimumTemperature).formatted(.number.precision(.fractionLength(0))))–\(temperatureUnit.value(fromCelsius: weather.maximumTemperature).formatted(.number.precision(.fractionLength(0)))) \(temperatureUnit.symbol)"
    }

    private func apparentTemperatureText(_ weather: WeatherDay) -> String {
        guard let minimum = weather.minimumApparentTemperature, let maximum = weather.maximumApparentTemperature else { return String(localized: "metric.notAvailable") }
        return String(localized: "metric.feelsLike \(temperatureUnit.value(fromCelsius: minimum).formatted(.number.precision(.fractionLength(0)))) \(temperatureUnit.value(fromCelsius: maximum).formatted(.number.precision(.fractionLength(0)))) \(temperatureUnit.symbol)")
    }

    private func windText(_ value: Double) -> String {
        "\(windUnit.value(fromKilometersPerHour: value).formatted(.number.precision(.fractionLength(0)))) \(windUnit.symbol)"
    }

    private func gustText(_ weather: WeatherDay) -> String {
        guard let gust = weather.maximumWindGust else { return String(localized: "metric.notAvailable") }
        return String(localized: "metric.gustsTo \(windText(gust))")
    }

    private func uvAssessment(_ value: Double?) -> String {
        guard let value else { return String(localized: "metric.notAvailable") }
        switch value {
        case ..<3: return String(localized: "uv.low")
        case ..<6: return String(localized: "uv.medium")
        case ..<8: return String(localized: "uv.high")
        case ..<11: return String(localized: "uv.veryHigh")
        default: return String(localized: "uv.extreme")
        }
    }
}

private struct HourCard: View {
    let hour: WeatherHour
    let temperatureUnit: TemperatureUnit
    let windUnit: WindSpeedUnit

    var body: some View {
        VStack(spacing: 7) {
            Text(time).font(.caption.weight(.semibold))
            Image(systemName: WeatherCondition.symbolName(for: hour.weatherCode)).symbolRenderingMode(.multicolor).font(.title3)
            Text("\(temperatureUnit.value(fromCelsius: hour.temperature), format: .number.precision(.fractionLength(0))) \(temperatureUnit.symbol)").font(.subheadline.weight(.semibold)).fixedSize()
            Label("\(hour.precipitationProbability ?? 0)%", systemImage: "drop.fill")
            Label("\(windUnit.value(fromKilometersPerHour: hour.windSpeed), format: .number.precision(.fractionLength(0)))", systemImage: "wind")
        }
        .font(.caption2).foregroundStyle(AppTheme.primaryText)
        .padding(10).frame(minWidth: 82, minHeight: 132)
        .background(AppTheme.surfaceSecondary, in: RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(time), \(temperatureUnit.value(fromCelsius: hour.temperature).formatted(.number.precision(.fractionLength(0)))) \(temperatureUnit.symbol), \(hour.precipitationProbability ?? 0) Prozent Regen, Wind \(windUnit.value(fromKilometersPerHour: hour.windSpeed).formatted(.number.precision(.fractionLength(0)))) \(windUnit.symbol), Böen \(windUnit.value(fromKilometersPerHour: hour.windGust).formatted(.number.precision(.fractionLength(0)))) \(windUnit.symbol)")
    }

    private var time: String { String(hour.timeISO.split(separator: "T").last?.prefix(5) ?? "–") }
}

private struct DetailMetricCard: View {
    let title: String
    let value: String
    let subtitle: String
    let systemImage: String
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage).font(.caption.weight(.semibold)).foregroundStyle(AppTheme.accent)
            Text(value).font(.headline).monospacedDigit().fixedSize(horizontal: false, vertical: true)
            Text(subtitle).font(.caption).foregroundStyle(AppTheme.secondaryText).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 106, alignment: .topLeading).padding(14)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay { RoundedRectangle(cornerRadius: 16).stroke(AppTheme.border, lineWidth: 1) }
        .accessibilityElement(children: .combine)
    }
}
