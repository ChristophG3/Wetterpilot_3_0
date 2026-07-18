import SwiftData
import SwiftUI

@main
struct WetterpilotApp: App {
    @StateObject private var introductionCoordinator: IntroductionCoordinator
    private let modelContainer: ModelContainer

    init() {
        let legacyInstallationDetected = ExistingInstallationDetector.hasLegacyEvidence()
        _introductionCoordinator = StateObject(
            wrappedValue: IntroductionCoordinator(
                legacyInstallationDetected: legacyInstallationDetected
            )
        )

        do {
            modelContainer = try ModelContainer(
                for: Trip.self,
                TripSegment.self,
                DestinationComparison.self,
                ComparisonCandidate.self
            )
        } catch {
            fatalError("Die lokale Reisedatenbank konnte nicht erstellt werden: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            if introductionCoordinator.shouldPresentAutomatically {
                IntroductionView(mode: .automatic) {
                    introductionCoordinator.complete()
                }
            } else {
                TripListView()
            }
        }
        .modelContainer(modelContainer)
    }
}
