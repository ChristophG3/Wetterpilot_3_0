import Foundation
import CoreLocation

struct GeoPlace: Codable, Hashable, Identifiable {
    var id: String { name + String(format: "%.4f%.4f", latitude, longitude) }
    let name: String
    let latitude: Double
    let longitude: Double
}
