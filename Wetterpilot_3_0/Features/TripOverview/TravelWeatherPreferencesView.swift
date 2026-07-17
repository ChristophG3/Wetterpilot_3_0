import SwiftUI

struct TravelWeatherPreferencesView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var model: TravelWeatherPreferencesModel
    @AppStorage("temperatureUnit") private var temperatureUnitRaw = TemperatureUnit.celsius.rawValue
    @AppStorage("windSpeedUnit") private var windUnitRaw = WindSpeedUnit.kilometersPerHour.rawValue

    private var temperatureUnit: TemperatureUnit {
        TemperatureUnit(rawValue: temperatureUnitRaw) ?? .celsius
    }
    private var windUnit: WindSpeedUnit {
        WindSpeedUnit(rawValue: windUnitRaw) ?? .kilometersPerHour
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle(
                        String(localized: "trip.preferences.thunderstorms"),
                        isOn: binding(\.avoidsThunderstorms)
                    )
                } footer: {
                    Text(String(localized: "trip.preferences.explanation"))
                }
                .themedListRow()

                Section(String(localized: "trip.preferences.rain")) {
                    Toggle(
                        String(localized: "trip.preferences.rainProbability"),
                        isOn: binding(\.considersRainProbability)
                    )
                    if model.value.considersRainProbability {
                        Stepper(
                            value: intBinding(\.maximumPrecipitationProbability),
                            in: 10...100,
                            step: 5
                        ) {
                            Text(String(localized: "trip.preferences.rainProbabilityLimit \(model.value.maximumPrecipitationProbability)"))
                        }
                    }
                    Toggle(
                        String(localized: "trip.preferences.precipitationAmount"),
                        isOn: binding(\.considersPrecipitationAmount)
                    )
                    if model.value.considersPrecipitationAmount {
                        Stepper(
                            value: doubleBinding(\.maximumPrecipitationAmount),
                            in: 0.5...50,
                            step: 0.5
                        ) {
                            Text(String(localized: "trip.preferences.precipitationLimit \(model.value.maximumPrecipitationAmount.formatted(.number.precision(.fractionLength(1))))"))
                        }
                    }
                }
                .themedListRow()

                Section(String(localized: "trip.preferences.wind")) {
                    Toggle(
                        String(localized: "trip.preferences.windSpeed"),
                        isOn: binding(\.considersWind)
                    )
                    if model.value.considersWind {
                        Stepper(
                            value: doubleBinding(\.maximumWindSpeed),
                            in: 10...100,
                            step: 5
                        ) {
                            Text(String(localized: "trip.preferences.windLimit \(windText(model.value.maximumWindSpeed))"))
                        }
                    }
                    Toggle(
                        String(localized: "trip.preferences.gusts"),
                        isOn: binding(\.considersGusts)
                    )
                    if model.value.considersGusts {
                        Stepper(
                            value: doubleBinding(\.maximumWindGust),
                            in: 20...150,
                            step: 5
                        ) {
                            Text(String(localized: "trip.preferences.gustLimit \(windText(model.value.maximumWindGust))"))
                        }
                    }
                }
                .themedListRow()

                Section(String(localized: "trip.preferences.temperature")) {
                    Toggle(
                        String(localized: "trip.preferences.cold"),
                        isOn: binding(\.considersCold)
                    )
                    if model.value.considersCold {
                        Stepper(
                            value: doubleBinding(\.minimumComfortableTemperature),
                            in: -20...20,
                            step: 1
                        ) {
                            Text(String(localized: "trip.preferences.coldLimit \(temperatureText(model.value.minimumComfortableTemperature))"))
                        }
                    }
                    Toggle(
                        String(localized: "trip.preferences.heat"),
                        isOn: binding(\.considersHeat)
                    )
                    if model.value.considersHeat {
                        Stepper(
                            value: doubleBinding(\.maximumComfortableTemperature),
                            in: 20...50,
                            step: 1
                        ) {
                            Text(String(localized: "trip.preferences.heatLimit \(temperatureText(model.value.maximumComfortableTemperature))"))
                        }
                    }
                }
                .themedListRow()

                Section {
                    Button(String(localized: "trip.preferences.restoreDefaults")) {
                        model.restoreDefaults()
                    }
                    .frame(minHeight: 44)
                }
                .themedListRow()
            }
            .appScreenStyle()
            .navigationTitle(String(localized: "trip.preferences.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "common.done")) { dismiss() }
                }
            }
        }
    }

    private func binding(_ keyPath: WritableKeyPath<TravelWeatherPreferences, Bool>) -> Binding<Bool> {
        Binding(
            get: { model.value[keyPath: keyPath] },
            set: {
                var value = model.value
                value[keyPath: keyPath] = $0
                model.value = value
            }
        )
    }

    private func intBinding(_ keyPath: WritableKeyPath<TravelWeatherPreferences, Int>) -> Binding<Int> {
        Binding(
            get: { model.value[keyPath: keyPath] },
            set: {
                var value = model.value
                value[keyPath: keyPath] = $0
                model.value = value
            }
        )
    }

    private func doubleBinding(_ keyPath: WritableKeyPath<TravelWeatherPreferences, Double>) -> Binding<Double> {
        Binding(
            get: { model.value[keyPath: keyPath] },
            set: {
                var value = model.value
                value[keyPath: keyPath] = $0
                model.value = value
            }
        )
    }

    private func temperatureText(_ celsius: Double) -> String {
        "\(temperatureUnit.value(fromCelsius: celsius).formatted(.number.precision(.fractionLength(0)))) \(temperatureUnit.symbol)"
    }

    private func windText(_ kilometersPerHour: Double) -> String {
        "\(windUnit.value(fromKilometersPerHour: kilometersPerHour).formatted(.number.precision(.fractionLength(0)))) \(windUnit.symbol)"
    }
}
