import Foundation

// MARK: - RainViewer API Data Models

public struct RainViewerMetadata: Codable, Sendable {
    public let version: String
    public let generated: Int
    public let host: String
    public let radar: RainViewerRadar
    public let satellite: RainViewerSatellite?

    public init(version: String, generated: Int, host: String, radar: RainViewerRadar, satellite: RainViewerSatellite? = nil) {
        self.version = version
        self.generated = generated
        self.host = host
        self.radar = radar
        self.satellite = satellite
    }
}

public struct RainViewerRadar: Codable, Sendable {
    public let past: [RadarFrame]
    public let nowcast: [RadarFrame]?

    public init(past: [RadarFrame], nowcast: [RadarFrame]? = nil) {
        self.past = past
        self.nowcast = nowcast
    }

    public var allFrames: [RadarFrame] {
        past + (nowcast ?? [])
    }
}

public struct RainViewerSatellite: Codable, Sendable {
    public let infrared: [RadarFrame]?

    public init(infrared: [RadarFrame]? = nil) {
        self.infrared = infrared
    }
}

public struct RadarFrame: Codable, Identifiable, Hashable, Sendable {
    public var id: Int { time }
    public let time: Int
    public let path: String

    public init(time: Int, path: String) {
        self.time = time
        self.path = path
    }

    public var date: Date {
        Date(timeIntervalSince1970: TimeInterval(time))
    }

    public var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    public func relativeTimeString(relativeTo reference: Date = Date()) -> String {
        let diff = Int(reference.timeIntervalSince(date))
        if diff < 90 && diff > -90 {
            return "Latest"
        }
        if diff < 0 {
            let futureMin = abs(diff) / 60
            return "+\(futureMin)m"
        }
        let minutes = diff / 60
        if minutes < 60 {
            return "-\(minutes)m"
        }
        let hours = minutes / 60
        let remMin = minutes % 60
        if remMin == 0 {
            return "-\(hours)h"
        } else {
            return "-\(hours)h \(remMin)m"
        }
    }
}

// MARK: - RainViewer Color Themes

public enum RainViewerColorScheme: Int, CaseIterable, Identifiable, Sendable {
    case original = 0
    case universalBlue = 2
    case titanium = 3
    case theWeatherChannel = 4
    case nexrad = 5
    case rainbow = 6
    case darkSky = 7

    public var id: Int { rawValue }

    public var displayName: String {
        switch self {
        case .original: return "Black & White"
        case .universalBlue: return "Universal Blue"
        case .titanium: return "TITAN"
        case .theWeatherChannel: return "Weather Channel"
        case .nexrad: return "NEXRAD Level III"
        case .rainbow: return "RAINBOW"
        case .darkSky: return "Dark Sky"
        }
    }
}

// MARK: - RainViewer Service

public final class RainViewerService: Sendable {
    public static let shared = RainViewerService()

    private let session: URLSession
    private let apiURL = URL(string: "https://api.rainviewer.com/public/weather-maps.json")!

    public init(session: URLSession = .shared) {
        self.session = session
    }

    /// Fetches the current weather radar maps metadata from RainViewer
    public func fetchMetadata() async throws -> RainViewerMetadata {
        var request = URLRequest(url: apiURL)
        request.httpMethod = "GET"
        request.timeoutInterval = 12.0
        request.setValue("WeatherBar/1.0 (macOS Weather Radar; contact@weatherbar.local)", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw WeatherServiceError.invalidResponse("Invalid response from RainViewer API")
        }

        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 429 {
                throw WeatherServiceError.apiRateLimited
            }
            throw WeatherServiceError.networkError("RainViewer returned HTTP status \(httpResponse.statusCode)")
        }

        do {
            let decoder = JSONDecoder()
            return try decoder.decode(RainViewerMetadata.self, from: data)
        } catch {
            throw WeatherServiceError.invalidResponse("Failed to parse RainViewer JSON: \(error.localizedDescription)")
        }
    }

    /// Generates standard slippy tile URL template for MapKit / Web Mercator ({z}/{x}/{y})
    public func tileURLTemplate(
        host: String,
        frame: RadarFrame,
        tileSize: Int = 256,
        colorScheme: RainViewerColorScheme = .universalBlue,
        smooth: Bool = true,
        snow: Bool = true
    ) -> String {
        let baseHost = host.hasSuffix("/") ? String(host.dropLast()) : host
        let options = "\(smooth ? 1 : 0)_\(snow ? 1 : 0)"
        return "\(baseHost)\(frame.path)/\(tileSize)/{z}/{x}/{y}/\(colorScheme.rawValue)/\(options).png"
    }

    /// Generates single coordinate image URL centered at (lat, lon) with desired zoom level
    public func coordinateSnapshotURL(
        host: String,
        frame: RadarFrame,
        latitude: Double,
        longitude: Double,
        zoom: Int = 6,
        tileSize: Int = 512,
        colorScheme: RainViewerColorScheme = .universalBlue,
        smooth: Bool = true,
        snow: Bool = true
    ) -> URL? {
        let baseHost = host.hasSuffix("/") ? String(host.dropLast()) : host
        let options = "\(smooth ? 1 : 0)_\(snow ? 1 : 0)"
        let latStr = String(format: "%.4f", latitude)
        let lonStr = String(format: "%.4f", longitude)
        let urlString = "\(baseHost)\(frame.path)/\(tileSize)/\(zoom)/\(latStr)/\(lonStr)/\(colorScheme.rawValue)/\(options).png"
        return URL(string: urlString)
    }

    /// Generates radar coverage tile template for MapKit
    public func coverageTileURLTemplate(
        host: String,
        tileSize: Int = 256
    ) -> String {
        let baseHost = host.hasSuffix("/") ? String(host.dropLast()) : host
        return "\(baseHost)/v2/coverage/0/\(tileSize)/{z}/{x}/{y}/0/0_0.png"
    }

    /// Generates radar coverage snapshot URL centered at coordinates
    public func coverageSnapshotURL(
        host: String,
        latitude: Double,
        longitude: Double,
        zoom: Int = 6,
        tileSize: Int = 512
    ) -> URL? {
        let baseHost = host.hasSuffix("/") ? String(host.dropLast()) : host
        let latStr = String(format: "%.4f", latitude)
        let lonStr = String(format: "%.4f", longitude)
        let urlString = "\(baseHost)/v2/coverage/0/\(tileSize)/\(zoom)/\(latStr)/\(lonStr)/0/0_0.png"
        return URL(string: urlString)
    }
}
