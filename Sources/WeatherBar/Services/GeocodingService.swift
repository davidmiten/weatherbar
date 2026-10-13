import Foundation

public struct GeocodingService: Sendable {
    public init() {}

    public func searchLocations(query: String) async throws -> [WeatherLocation] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        guard let encodedQuery = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://geocoding-api.open-meteo.com/v1/search?name=\(encodedQuery)&count=10&language=en&format=json") else {
            return []
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 10

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            return []
        }

        let searchResponse = try JSONDecoder().decode(GeocodingResponse.self, from: data)
        guard let results = searchResponse.results else { return [] }

        return results.map { result in
            WeatherLocation(
                name: result.name,
                adminArea: result.admin1,
                country: result.country,
                latitude: result.latitude,
                longitude: result.longitude
            )
        }
    }
}

struct GeocodingResponse: Decodable {
    let results: [GeocodingResult]?
}

struct GeocodingResult: Decodable {
    let id: Int
    let name: String
    let latitude: Double
    let longitude: Double
    let country: String?
    let admin1: String?
}
