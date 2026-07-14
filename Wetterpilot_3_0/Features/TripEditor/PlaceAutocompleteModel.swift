import Foundation

@MainActor
final class PlaceAutocompleteModel: ObservableObject {
    @Published private(set) var suggestionsByDraft: [UUID: [GeocodedPlace]] = [:]
    @Published private(set) var loadingDrafts: Set<UUID> = []

    private let service: OpenMeteoGeocodingService
    private var tasks: [UUID: Task<Void, Never>] = [:]
    private var acceptedText: [UUID: String] = [:]

    init(service: OpenMeteoGeocodingService = OpenMeteoGeocodingService()) {
        self.service = service
    }

    func suggestions(for draftID: UUID) -> [GeocodedPlace] {
        suggestionsByDraft[draftID] ?? []
    }

    func isLoading(_ draftID: UUID) -> Bool {
        loadingDrafts.contains(draftID)
    }

    func search(draftID: UUID, text: String) {
        tasks[draftID]?.cancel()
        suggestionsByDraft[draftID] = []

        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.count >= 2, acceptedText[draftID] != query else {
            loadingDrafts.remove(draftID)
            return
        }
        acceptedText[draftID] = nil

        tasks[draftID] = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard let self, !Task.isCancelled else { return }

            self.loadingDrafts.insert(draftID)
            defer { self.loadingDrafts.remove(draftID) }
            do {
                let places = try await self.service.suggestions(for: query)
                guard !Task.isCancelled else { return }
                self.suggestionsByDraft[draftID] = places
            } catch {
                guard !Task.isCancelled else { return }
                self.suggestionsByDraft[draftID] = []
            }
        }
    }

    func accept(_ place: GeocodedPlace, for draftID: UUID) {
        tasks[draftID]?.cancel()
        acceptedText[draftID] = place.name
        suggestionsByDraft[draftID] = []
        loadingDrafts.remove(draftID)
    }

    func removeDraft(_ draftID: UUID) {
        tasks[draftID]?.cancel()
        tasks[draftID] = nil
        suggestionsByDraft[draftID] = nil
        loadingDrafts.remove(draftID)
        acceptedText[draftID] = nil
    }
}
