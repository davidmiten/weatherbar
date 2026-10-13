import Foundation

public protocol WeatherService: Sendable {
    var id: String { get }
    var displayName: String { get }
    var attributionText: String { get }
    var requiresAPIKey: Bool { get }
    var supportsGlobalLocations: Bool { get }
    var serviceDescription: String { get }

    func fetchWeather(for location: WeatherLocation) async throws -> WeatherData
}

public enum WeatherServiceError: LocalizedError, Sendable {
    case locationNotSupported(String)
    case networkError(String)
    case invalidResponse(String)
    case missingData(String)
    case apiRateLimited
    case custom(String)

    public var errorDescription: String? {
        switch self {
        case .locationNotSupported(let msg):
            return "Location not supported: \(msg)"
        case .networkError(let msg):
            return "Network error: \(msg)"
        case .invalidResponse(let msg):
            return "Invalid API response: \(msg)"
        case .missingData(let msg):
            return "Missing weather data: \(msg)"
        case .apiRateLimited:
            return "API rate limit reached. Please try again shortly."
        case .custom(let msg):
            return msg
        }
    }
}

public final class WeatherServiceRegistry: @unchecked Sendable {
    public static let shared = WeatherServiceRegistry()

    private var services: [String: any WeatherService] = [:]

    private init() {
        register(NWSWeatherService())
        register(OpenMeteoWeatherService())
    }

    public func register(_ service: any WeatherService) {
        services[service.id] = service
    }

    public func service(for id: String) -> (any WeatherService)? {
        services[id]
    }

    public var allServices: [any WeatherService] {
        // Return NWS first (primary requirement), then Open-Meteo, then others
        let order = ["nws", "open-meteo"]
        return services.values.sorted { s1, s2 in
            let idx1 = order.firstIndex(of: s1.id) ?? 99
            let idx2 = order.firstIndex(of: s2.id) ?? 99
            return idx1 < idx2
        }
    }

    public var defaultService: any WeatherService {
        services["nws"] ?? OpenMeteoWeatherService()
    }
}
