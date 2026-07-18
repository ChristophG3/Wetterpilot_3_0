import Combine
import Foundation

struct IntroductionStateStore {
    static let currentVersion = 1
    static let completedVersionKey = "introduction.completedVersion"
    static let installationMarkerKey = "introduction.installationMarker"

    private let defaults: UserDefaults
    private let version: Int

    init(
        defaults: UserDefaults = .standard,
        currentVersion: Int = IntroductionStateStore.currentVersion
    ) {
        self.defaults = defaults
        self.version = currentVersion
    }

    var completedVersion: Int {
        defaults.integer(forKey: Self.completedVersionKey)
    }

    func prepareForLaunch(legacyInstallationDetected: Bool) -> Bool {
        if defaults.object(forKey: Self.installationMarkerKey) == nil {
            if legacyInstallationDetected {
                defaults.set(version, forKey: Self.completedVersionKey)
            }
            defaults.set(true, forKey: Self.installationMarkerKey)
        }
        return completedVersion < version
    }

    func completeCurrentIntroduction() {
        defaults.set(version, forKey: Self.completedVersionKey)
        defaults.set(true, forKey: Self.installationMarkerKey)
    }
}

enum ExistingInstallationDetector {
    private static let knownSettingKeys = [
        "temperatureUnit",
        "windSpeedUnit",
        TravelWeatherPreferencesStore.key
    ]

    static func hasLegacyEvidence(
        defaults: UserDefaults = .standard,
        fileManager: FileManager = .default,
        applicationSupportDirectory: URL? = nil,
        cachesDirectory: URL? = nil
    ) -> Bool {
        if knownSettingKeys.contains(where: { defaults.object(forKey: $0) != nil }) {
            return true
        }

        let supportDirectory = applicationSupportDirectory
            ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        if let supportDirectory {
            let storeNames = ["default.store", "default.store-shm", "default.store-wal"]
            if storeNames.contains(where: {
                fileManager.fileExists(atPath: supportDirectory.appendingPathComponent($0).path)
            }) {
                return true
            }
        }

        let cacheDirectory = cachesDirectory
            ?? fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
        if let cacheDirectory {
            let weatherCache = cacheDirectory
                .appendingPathComponent("Wetterpilot", isDirectory: true)
                .appendingPathComponent("weather-cache.json")
            if fileManager.fileExists(atPath: weatherCache.path) {
                return true
            }
        }

        return false
    }
}

@MainActor
final class IntroductionCoordinator: ObservableObject {
    @Published private(set) var shouldPresentAutomatically: Bool
    private let store: IntroductionStateStore

    init(
        store: IntroductionStateStore = IntroductionStateStore(),
        legacyInstallationDetected: Bool
    ) {
        self.store = store
        self.shouldPresentAutomatically = store.prepareForLaunch(
            legacyInstallationDetected: legacyInstallationDetected
        )
    }

    func complete() {
        store.completeCurrentIntroduction()
        shouldPresentAutomatically = false
    }
}
