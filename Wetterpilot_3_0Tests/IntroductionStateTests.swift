import XCTest
@testable import Wetterpilot_3_0

final class IntroductionStateTests: XCTestCase {
    func testNewInstallationShowsCurrentIntroduction() {
        withDefaults { defaults in
            let store = IntroductionStateStore(defaults: defaults, currentVersion: 1)
            XCTAssertTrue(store.prepareForLaunch(legacyInstallationDetected: false))
            XCTAssertEqual(store.completedVersion, 0)
        }
    }

    func testLegacyInstallationIsMigratedWithoutAutomaticIntroduction() {
        withDefaults { defaults in
            let store = IntroductionStateStore(defaults: defaults, currentVersion: 1)
            XCTAssertFalse(store.prepareForLaunch(legacyInstallationDetected: true))
            XCTAssertEqual(store.completedVersion, 1)
        }
    }

    func testSkippingOrCompletingPersistsCurrentVersion() {
        withDefaults { defaults in
            let store = IntroductionStateStore(defaults: defaults, currentVersion: 1)
            XCTAssertTrue(store.prepareForLaunch(legacyInstallationDetected: false))
            store.completeCurrentIntroduction()

            let nextLaunch = IntroductionStateStore(defaults: defaults, currentVersion: 1)
            XCTAssertFalse(nextLaunch.prepareForLaunch(legacyInstallationDetected: false))
            XCTAssertEqual(nextLaunch.completedVersion, 1)
        }
    }

    func testNewIntroductionVersionCanBePresentedLater() {
        withDefaults { defaults in
            let firstVersion = IntroductionStateStore(defaults: defaults, currentVersion: 1)
            _ = firstVersion.prepareForLaunch(legacyInstallationDetected: false)
            firstVersion.completeCurrentIntroduction()

            let secondVersion = IntroductionStateStore(defaults: defaults, currentVersion: 2)
            XCTAssertTrue(secondVersion.prepareForLaunch(legacyInstallationDetected: false))
            XCTAssertEqual(secondVersion.completedVersion, 1)
        }
    }

    func testKnownSettingCountsAsLegacyEvidence() {
        withDefaults { defaults in
            defaults.set(WindSpeedUnit.milesPerHour.rawValue, forKey: "windSpeedUnit")
            XCTAssertTrue(
                ExistingInstallationDetector.hasLegacyEvidence(
                    defaults: defaults,
                    applicationSupportDirectory: temporaryDirectory(),
                    cachesDirectory: temporaryDirectory()
                )
            )
        }
    }

    func testEmptyDirectoriesDoNotLookLikeLegacyInstallation() {
        withDefaults { defaults in
            XCTAssertFalse(
                ExistingInstallationDetector.hasLegacyEvidence(
                    defaults: defaults,
                    applicationSupportDirectory: temporaryDirectory(),
                    cachesDirectory: temporaryDirectory()
                )
            )
        }
    }

    private func withDefaults(_ body: (UserDefaults) -> Void) {
        let suiteName = "IntroductionStateTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        body(defaults)
        defaults.removePersistentDomain(forName: suiteName)
    }

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
    }
}
