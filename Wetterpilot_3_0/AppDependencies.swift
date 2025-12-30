import Foundation

struct AppDependencies {
    let network: NetworkClient
    let weather: WeatherProvider
    let geocoding: GeocodingProvider
    let store: PersistenceStore
    let pdf: PDFExporter
    let caches: Caches
    
    static let live: AppDependencies = {
        let network = NetworkClient()
        let caches = Caches()
        let weather = OpenMeteoWeatherProvider(network: network, caches: caches)
        let geocoding = OpenMeteoGeocodingProvider(network: network, caches: caches)
        let store = PersistenceStore()
        let pdf = PDFExporter()
        return .init(network: network, weather: weather, geocoding: geocoding, store: store, pdf: pdf, caches: caches)
    }()
}

struct Caches {
    let memory = MemoryCache()
    let disk = DiskCache()
}
