import Foundation

struct StopSpec: Identifiable, Codable {
    var id = UUID()
    var place: String
    var selected: GeoPlace?
}
