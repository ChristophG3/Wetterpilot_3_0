import SwiftData
import SwiftUI

@main
struct WetterpilotApp: App {
    private let modelContainer: ModelContainer = {
        do {
            return try ModelContainer(
                for: Trip.self,
                TripSegment.self,
                DestinationComparison.self,
                ComparisonCandidate.self
            )
        } catch {
            fatalError("Die lokale Reisedatenbank konnte nicht erstellt werden: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            TripListView()
        }
        .modelContainer(modelContainer)
    }
}
