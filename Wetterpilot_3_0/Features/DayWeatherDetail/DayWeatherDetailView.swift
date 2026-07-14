import SwiftUI

struct DayWeatherDetailView: View {
    let day: TripDay
    let weather: WeatherDay?
    let unavailableMessage: String

    var body: some View {
        ScrollView {
            if let weather {
                VStack(spacing: 18) {
                    hero(weather)

                    LazyVGrid(
                        columns: [GridItem(.flexible()), GridItem(.flexible())],
                        spacing: 12
                    ) {
                        DetailMetricCard(
                            title: "Temperatur",
                            value: String(format: "%.0f–%.0f °C", weather.minimumTemperature, weather.maximumTemperature),
                            subtitle: apparentTemperatureText(weather),
                            systemImage: "thermometer.medium"
                        )
                        DetailMetricCard(
                            title: "Regen",
                            value: precipitationText(weather),
                            subtitle: String(format: "%.1f mm", weather.precipitationAmount),
                            systemImage: "drop.fill"
                        )
                        DetailMetricCard(
                            title: "Wind",
                            value: String(format: "%.0f km/h", weather.maximumWindSpeed),
                            subtitle: gustText(weather),
                            systemImage: "wind"
                        )
                        DetailMetricCard(
                            title: "UV-Index",
                            value: uvText(weather),
                            subtitle: uvAssessment(weather.maximumUVIndex),
                            systemImage: "sun.max.fill"
                        )
                        DetailMetricCard(
                            title: "Sonnenaufgang",
                            value: weather.sunriseTime ?? "–",
                            subtitle: "Ortszeit",
                            systemImage: "sunrise.fill"
                        )
                        DetailMetricCard(
                            title: "Sonnenuntergang",
                            value: weather.sunsetTime ?? "–",
                            subtitle: "Ortszeit",
                            systemImage: "sunset.fill"
                        )
                    }

                    Text("Vorhersagedaten: Open-Meteo. Wetterprognosen können sich ändern.")
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding()
            } else {
                ContentUnavailableView {
                    Label("Noch keine Wetterdetails", systemImage: "cloud.slash")
                } description: {
                    Text(unavailableMessage)
                }
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
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondaryText)
            Text(weather.symbol)
                .font(.system(size: 64))
            Text(weather.conditionText)
                .font(.title2.weight(.semibold))
            Text("\(weather.minimumTemperature, specifier: "%.0f")–\(weather.maximumTemperature, specifier: "%.0f") °C")
                .font(.title.weight(.bold))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .stroke(AppTheme.border, lineWidth: 1)
        }
    }

    private func apparentTemperatureText(_ weather: WeatherDay) -> String {
        guard let minimum = weather.minimumApparentTemperature,
              let maximum = weather.maximumApparentTemperature else {
            return "Gefühlt nicht verfügbar"
        }
        return String(format: "Gefühlt %.0f–%.0f °C", minimum, maximum)
    }

    private func precipitationText(_ weather: WeatherDay) -> String {
        guard let probability = weather.precipitationProbability else { return "–" }
        return "\(probability) %"
    }

    private func gustText(_ weather: WeatherDay) -> String {
        guard let gust = weather.maximumWindGust else { return "Böen nicht verfügbar" }
        return String(format: "Böen bis %.0f km/h", gust)
    }

    private func uvText(_ weather: WeatherDay) -> String {
        guard let uv = weather.maximumUVIndex else { return "–" }
        return String(format: "%.1f", uv)
    }

    private func uvAssessment(_ value: Double?) -> String {
        guard let value else { return "Nicht verfügbar" }
        switch value {
        case ..<3: return "Niedrig"
        case ..<6: return "Mittel"
        case ..<8: return "Hoch"
        case ..<11: return "Sehr hoch"
        default: return "Extrem"
        }
    }
}

private struct DetailMetricCard: View {
    let title: String
    let value: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.accent)
            Text(value)
                .font(.headline)
                .monospacedDigit()
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: 106, alignment: .topLeading)
        .padding(14)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppTheme.border, lineWidth: 1)
        }
    }
}
