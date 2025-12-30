import Foundation

// Nutzerpräferenzen: nur noch "Vermeiden" (true) vs. neutral (false)
struct Weights: Codable, Equatable {
    var avoidRain: Bool = true
    var avoidWind: Bool = true
    var avoidHeat: Bool = false   // Hitze > 30°C
    var avoidCold: Bool = false   // Kälte < 10°C
}

// Aufschlüsselung der Beiträge (zur Anzeige/Debug)
struct ScoreBreakdown: Codable {
    let totalDisplay100: Int
    let rainPenalty: Double
    let windPenalty: Double
    let heatPenalty: Double
    let coldPenalty: Double
    let sunBonus: Double
}

/// Bestehende "0–100"-Logik (normiert), aber auf die neue Weights-Struktur angepasst
enum StandardScoring {
    static func score(days: [ForecastDay], weights: Weights) -> ScoreBreakdown {
        let base: Double = 100

        // Vermeiden = starker Einfluss (3x), Neutral = kein Einfluss (0x)
        let wRain = weights.avoidRain ? 3.0 : 0.0
        let wWind = weights.avoidWind ? 3.0 : 0.0
        let wHeat = weights.avoidHeat ? 3.0 : 0.0
        let wCold = weights.avoidCold ? 3.0 : 0.0

        // Sonne immer bevorzugt: fester Bonus-Faktor = 3 (wie bisher "prefer")
        let wSun: Double = 3.0

        var rainP = 0.0, windP = 0.0, heatP = 0.0, coldP = 0.0, sunB = 0.0

        for day in days {
            // identische Caps/Schwellen wie bisher:
            rainP += wRain * min(day.rainMM, 30)                 // max 30 mm
            windP += wWind * max(0, day.windKmh - 25)            // ab 25 km/h
            heatP += wHeat * max(0, day.tMax - 30)               // > 30°C (angepasst auf deine Vorgabe)
            coldP += wCold * max(0, 10 - day.tMin)               // < 10°C
            sunB  += wSun  * min(day.sunHours, 12) * 0.5         // bis 12h, Faktor 0.5
        }

        let raw = base - (rainP + windP + heatP + coldP) + sunB
        let total = max(0, min(100, Int(raw.rounded())))
        return .init(totalDisplay100: total,
                     rainPenalty: rainP, windPenalty: windP, heatPenalty: heatP, coldPenalty: coldP, sunBonus: sunB)
    }
}

/// Offene Skala + paralleler 0–100-Displaywert (für Badges/Sortierung)
enum OpenScoring {
    struct Result: Codable {
        let openScore: Int           // offene Skala, unbounded nach oben
        let display100: Int          // 0–100, gut für UI
        let breakdown: ScoreBreakdown
    }

    static func score(days: [ForecastDay], weights: Weights) -> Result {
        // Gewichte wie oben:
        let wRain = weights.avoidRain ? 3.0 : 0.0
        let wWind = weights.avoidWind ? 3.0 : 0.0
        let wHeat = weights.avoidHeat ? 3.0 : 0.0
        let wCold = weights.avoidCold ? 3.0 : 0.0
        let wSun: Double = 3.0

        var dayUtilities: [Double] = []
        var aggRain = 0.0, aggWind = 0.0, aggHeat = 0.0, aggCold = 0.0, aggSun = 0.0

        for d in days {
            let rainP = wRain * min(d.rainMM, 30)
            let windP = wWind * max(0, d.windKmh - 25)
            let heatP = wHeat * max(0, d.tMax - 30)    // Hitze-Schwelle 30°C
            let coldP = wCold * max(0, 10 - d.tMin)    // Kälte-Schwelle 10°C
            let sunB  = wSun  * min(d.sunHours, 12) * 0.5

            aggRain += rainP; aggWind += windP; aggHeat += heatP; aggCold += coldP; aggSun  += sunB

            // Tagesrohwert (wie Standard), aber ohne Clamp
            let rawDay = 100.0 - (rainP + windP + heatP + coldP) + sunB
            // Utility in [0, 1)
            let u = max(0.0, min(0.999, rawDay / 100.0))
            dayUtilities.append(u)
        }

        // Mittelwert (macht Tourlängen vergleichbar)
        let U = dayUtilities.isEmpty ? 0.0 : dayUtilities.reduce(0, +) / Double(dayUtilities.count)

        // offene Skala (soft-saturation)
        let open = Int((100.0 * (-log(1.0 - U))).rounded())

        // klassischer 0–100 Anzeige-Wert
        let disp100 = Int((U * 100.0).rounded())

        let breakdown = ScoreBreakdown(
            totalDisplay100: disp100,
            rainPenalty: aggRain,
            windPenalty: aggWind,
            heatPenalty: aggHeat,
            coldPenalty: aggCold,
            sunBonus: aggSun
        )
        return .init(openScore: open, display100: disp100, breakdown: breakdown)
    }
}
