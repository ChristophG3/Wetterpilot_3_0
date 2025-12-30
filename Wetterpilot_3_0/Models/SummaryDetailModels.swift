import Foundation

// MARK: - SummaryItem
public struct SummaryItem: Identifiable, Codable, Hashable {
    public let id: UUID
    public let key: String      // yyyy-MM-dd

    /// Neuer, offener Score (kann > 100 sein)
    public let scoreOpen: Int

    /// Klassischer 0–100-Wert für Anzeige / Badge
    public let scoreDisplay: Int

    /// Kompatibilität: bisheriger Name bleibt (liefert scoreDisplay)
    public var score: Int { scoreDisplay }

    public let rainyDays: Int
    public let avgTemp: Double
    public let sunHours: Double
    public let avgWind: Double

    public init(
        id: UUID = UUID(),
        key: String,
        scoreOpen: Int,
        scoreDisplay: Int,
        rainyDays: Int,
        avgTemp: Double,
        sunHours: Double,
        avgWind: Double
    ) {
        self.id = id
        self.key = key
        self.scoreOpen = scoreOpen
        self.scoreDisplay = scoreDisplay
        self.rainyDays = rainyDays
        self.avgTemp = avgTemp
        self.sunHours = sunHours
        self.avgWind = avgWind
    }
}

// MARK: - DetailItem (unverändert)
public struct DetailItem: Identifiable, Codable, Hashable {
    public let id: UUID
    public let dateISO: String
    public let placeName: String
    public let emoji: String
    public let tRange: String
    public let rain: String
    public let sun: String
    public let wind: String

    public init(
        id: UUID = UUID(),
        dateISO: String,
        placeName: String,
        emoji: String,
        tRange: String,
        rain: String,
        sun: String,
        wind: String
    ) {
        self.id = id
        self.dateISO = dateISO
        self.placeName = placeName
        self.emoji = emoji
        self.tRange = tRange
        self.rain = rain
        self.sun = sun
        self.wind = wind
    }
}
