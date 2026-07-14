import Foundation
import SwiftData

@MainActor
final class TripWeatherModel: ObservableObject {
    @Published private(set) var weatherByDay: [WeatherDayKey: WeatherDay] = [:]
    @Published private(set) var errorsBySegment: [UUID: String] = [:]
    @Published private(set) var isLoading = false
    @Published private(set) var lastUpdated: Date?

    private let geocoding: OpenMeteoGeocodingService
    private let weather: OpenMeteoWeatherService

    init(
        geocoding: OpenMeteoGeocodingService = OpenMeteoGeocodingService(),
        weather: OpenMeteoWeatherService = OpenMeteoWeatherService()
    ) {
        self.geocoding = geocoding
        self.weather = weather
    }

    func load(trip: Trip, modelContext: ModelContext, force: Bool = false) async {
        if isLoading { return }
        if !force, lastUpdated != nil { return }

        isLoading = true
        errorsBySegment = [:]
        defer { isLoading = false }

        var loaded: [WeatherDayKey: WeatherDay] = [:]
        var forecastsByCoordinate: [String: [WeatherDay]] = [:]

        for segment in trip.sortedSegments {
            do {
                let coordinates = try await coordinates(for: segment)
                let coordinateKey = String(format: "%.4f,%.4f", coordinates.latitude, coordinates.longitude)
                let forecast: [WeatherDay]
                if let cached = forecastsByCoordinate[coordinateKey] {
                    forecast = cached
                } else {
                    forecast = try await weather.forecast(
                        latitude: coordinates.latitude,
                        longitude: coordinates.longitude
                    )
                    forecastsByCoordinate[coordinateKey] = forecast
                }

                for day in forecast {
                    loaded[WeatherDayKey(segmentID: segment.id, dateISO: day.dateISO)] = day
                }
            } catch {
                errorsBySegment[segment.id] = error.localizedDescription
            }
        }

        weatherByDay = loaded
        if !loaded.isEmpty {
            lastUpdated = .now
        }
        try? modelContext.save()
    }

    func weather(for day: TripDay) -> WeatherDay? {
        weatherByDay[
            WeatherDayKey(
                segmentID: day.segmentID,
                dateISO: WeatherDateKey.make(from: day.date)
            )
        ]
    }

    func unavailableMessage(for day: TripDay) -> String {
        if let error = errorsBySegment[day.segmentID] {
            return error
        }
        if day.date < Calendar.current.startOfDay(for: .now) {
            return "Keine aktuelle Prognose"
        }
        return "Vorhersage noch nicht verfügbar"
    }

    private func coordinates(for segment: TripSegment) async throws -> GeocodedPlace {
        if let latitude = segment.latitude, let longitude = segment.longitude {
            return GeocodedPlace(
                name: segment.placeName,
                regionName: segment.regionName,
                countryName: segment.countryName,
                latitude: latitude,
                longitude: longitude,
                timeZoneIdentifier: segment.timeZoneIdentifier
            )
        }

        let place = try await geocoding.geocode(segment.placeName)
        segment.placeName = place.name
        segment.regionName = place.regionName
        segment.countryName = place.countryName
        segment.latitude = place.latitude
        segment.longitude = place.longitude
        segment.timeZoneIdentifier = place.timeZoneIdentifier
        return place
    }
}

