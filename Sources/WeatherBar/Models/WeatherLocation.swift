import Foundation

public struct WeatherLocation: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    public var adminArea: String?
    public var country: String?
    public var latitude: Double
    public var longitude: Double

    public init(
        id: UUID = UUID(),
        name: String,
        adminArea: String? = nil,
        country: String? = nil,
        latitude: Double,
        longitude: Double
    ) {
        self.id = id
        self.name = name
        self.adminArea = adminArea
        self.country = country
        self.latitude = latitude
        self.longitude = longitude
    }

    public var displayName: String {
        if let admin = adminArea, !admin.isEmpty {
            return "\(name), \(admin)"
        }
        if let country = country, !country.isEmpty {
            return "\(name), \(country)"
        }
        return name
    }

    public var coordinatesFormatted: String {
        String(format: "%.3f°, %.3f°", latitude, longitude)
    }

    public static let defaultPresets: [WeatherLocation] = [
        WeatherLocation(name: "Seattle", adminArea: "WA", country: "United States", latitude: 47.6062, longitude: -122.3321),
        WeatherLocation(name: "San Francisco", adminArea: "CA", country: "United States", latitude: 37.7749, longitude: -122.4194),
        WeatherLocation(name: "New York", adminArea: "NY", country: "United States", latitude: 40.7128, longitude: -74.0060),
        WeatherLocation(name: "Chicago", adminArea: "IL", country: "United States", latitude: 41.8781, longitude: -87.6298),
        WeatherLocation(name: "Denver", adminArea: "CO", country: "United States", latitude: 39.7392, longitude: -104.9903),
        WeatherLocation(name: "Austin", adminArea: "TX", country: "United States", latitude: 30.2672, longitude: -97.7431),
        WeatherLocation(name: "Miami", adminArea: "FL", country: "United States", latitude: 25.7617, longitude: -80.1918),
        WeatherLocation(name: "Washington", adminArea: "DC", country: "United States", latitude: 38.9072, longitude: -77.0369),
        WeatherLocation(name: "London", adminArea: "England", country: "United Kingdom", latitude: 51.5074, longitude: -0.1278),
        WeatherLocation(name: "Tokyo", adminArea: "Tokyo", country: "Japan", latitude: 35.6762, longitude: 139.6503)
    ]
}
