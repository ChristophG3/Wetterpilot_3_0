import Foundation

/// Zentrale DateFormatter für die gesamte App.
/// Nutzt IMMER die aktuellen iOS-Sprach/Regionseinstellungen des Geräts.
enum DF {
    /// Sichtbares Tagesformat (geräteabhängig, z. B. 04.10.2025 oder 10/4/25)
    static let displayDay: DateFormatter = {
        let df = DateFormatter()
        df.calendar  = .current
        df.locale    = .current          // <- übernimmt Sprache/Region des Geräts
        df.timeZone  = .current
        df.dateStyle = .short            // <- systemtypisches Kurzformat
        df.timeStyle = .none
        return df
    }()

    /// Interner ISO-Formatter für Keys wie "yyyy.MM.dd" (falls ihr solche Strings nutzt)
    static let isoDayKey: DateFormatter = {
        let df = DateFormatter()
        df.calendar  = .current
        df.locale    = Locale(identifier: "en_US_POSIX")
        df.timeZone  = TimeZone(secondsFromGMT: 0)
        df.dateFormat = "yyyy-MM-dd"
        return df
    }()

    /// Wandelt einen ISO-Key (z. B. "2025.10.04") in Date.
    static func date(fromIsoKey key: String) -> Date? {
        isoDayKey.date(from: key)
    }

    /// Liefert den sichtbaren String für ein Date mit displayDay.
    static func display(_ date: Date) -> String {
        displayDay.string(from: date)
    }

    /// Liefert den sichtbaren String für einen ISO-Key.
    static func display(isoKey: String) -> String {
        guard let d = date(fromIsoKey: isoKey) else { return isoKey }
        return display(d)
    }
}//
//  DateFormatters.swift
//  Wetterpilot_2_0
//
//  Created by Christoph Gassl on 04.10.25.
//


