import Foundation

public struct NWSWeatherService: WeatherService, Sendable {
    public let id = "nws"
    public let displayName = "National Weather Service (NWS)"
    public let attributionText = "Data provided by NOAA / National Weather Service (weather.gov)"
    public let requiresAPIKey = false
    public let supportsGlobalLocations = false
    public let serviceDescription = "Official US weather agency. High accuracy for US locations and territories. Requires no API key."

    private let userAgent = "WeatherBarMacApp/1.0 (contact@weatherbar.local)"

    public init() {}

    public func fetchWeather(for location: WeatherLocation) async throws -> WeatherData {
        // Step 1: Query NWS Points endpoint
        let pointsUrlString = String(format: "https://api.weather.gov/points/%.4f,%.4f", location.latitude, location.longitude)
        guard let pointsUrl = URL(string: pointsUrlString) else {
            throw WeatherServiceError.invalidResponse("Invalid points URL: \(pointsUrlString)")
        }

        var pointsRequest = URLRequest(url: pointsUrl)
        pointsRequest.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        pointsRequest.setValue("application/geo+json", forHTTPHeaderField: "Accept")
        pointsRequest.timeoutInterval = 15

        let (pointsData, pointsResponse): (Data, URLResponse)
        do {
            (pointsData, pointsResponse) = try await URLSession.shared.data(for: pointsRequest)
        } catch {
            throw WeatherServiceError.networkError("Failed to connect to NWS: \(error.localizedDescription)")
        }

        guard let httpResponse = pointsResponse as? HTTPURLResponse else {
            throw WeatherServiceError.networkError("Did not receive HTTP response from NWS")
        }

        if httpResponse.statusCode == 404 || httpResponse.statusCode == 400 {
            throw WeatherServiceError.locationNotSupported(
                "\(location.displayName) is outside the coverage area. The National Weather Service only covers the United States and US territories. You can switch to Open-Meteo in Settings for worldwide coverage."
            )
        }

        guard httpResponse.statusCode == 200 else {
            throw WeatherServiceError.invalidResponse("NWS returned HTTP status \(httpResponse.statusCode)")
        }

        let pointsJson: NWSPointsResponse
        do {
            pointsJson = try JSONDecoder().decode(NWSPointsResponse.self, from: pointsData)
        } catch {
            throw WeatherServiceError.invalidResponse("Could not parse NWS points response: \(error.localizedDescription)")
        }

        let forecastUrlString = pointsJson.properties.forecast
        let hourlyUrlString = pointsJson.properties.forecastHourly

        // Step 2: Concurrently fetch forecast and hourly forecast (and alerts)
        async let hourlyFetch = fetchNWSForecastPeriods(urlString: hourlyUrlString)
        async let dailyFetch = fetchNWSForecastPeriods(urlString: forecastUrlString)
        async let alertsFetch = fetchNWSAlerts(latitude: location.latitude, longitude: location.longitude)

        let (hourlyPeriods, dailyPeriods, alerts) = try await (hourlyFetch, dailyFetch, alertsFetch)

        guard let currentPeriod = hourlyPeriods.first ?? dailyPeriods.first else {
            throw WeatherServiceError.missingData("No forecast periods returned by NWS")
        }

        // Parse current weather
        let tempF = currentPeriod.temperatureInFahrenheit
        let condition = currentPeriod.shortForecast
        let isDaytime = currentPeriod.isDaytime
        let iconSymbol = WeatherIconMapper.symbol(for: condition, isDaytime: isDaytime)
        let humidity = currentPeriod.relativeHumidity?.value.map { Int($0) }
        let precipChance = currentPeriod.probabilityOfPrecipitation?.value.map { Int($0) }

        // Dewpoint from hourly is usually in degC
        var dewpointF: Double? = nil
        if let dpC = currentPeriod.dewpoint?.value {
            dewpointF = (dpC * 9 / 5) + 32
        }

        // Compute high & low from the first few daily periods
        var highF: Double? = nil
        var lowF: Double? = nil
        for p in dailyPeriods.prefix(4) {
            let pTemp = p.temperatureInFahrenheit
            if p.isDaytime {
                if highF == nil || pTemp > (highF ?? -999) {
                    highF = pTemp
                }
            } else {
                if lowF == nil || pTemp < (lowF ?? 999) {
                    lowF = pTemp
                }
            }
        }

        let currentWeather = CurrentWeather(
            temperatureF: tempF,
            apparentTemperatureF: nil,
            condition: condition,
            iconSystemName: iconSymbol,
            humidityPercent: humidity,
            windSpeed: currentPeriod.windSpeed,
            windDirection: currentPeriod.windDirection,
            dewpointF: dewpointF,
            probabilityOfPrecipitation: precipChance,
            highF: highF,
            lowF: lowF,
            isDaytime: isDaytime
        )

        // Parse hourly forecast items (take up to 24 hours)
        let isoFormatter = ISO8601DateFormatter()
        let hourlyItems: [HourlyForecastItem] = hourlyPeriods.prefix(24).compactMap { (p: NWSPeriod) -> HourlyForecastItem? in
            guard let date = isoFormatter.date(from: p.startTime) ?? parseFallbackDate(p.startTime) else {
                return nil
            }
            return HourlyForecastItem(
                time: date,
                temperatureF: p.temperatureInFahrenheit,
                condition: p.shortForecast,
                iconSystemName: WeatherIconMapper.symbol(for: p.shortForecast, isDaytime: p.isDaytime),
                precipitationChance: p.probabilityOfPrecipitation?.value.map { Int($0) },
                isDaytime: p.isDaytime
            )
        }

        // Parse daily forecast items
        let dailyItems: [DailyForecastItem] = dailyPeriods.prefix(10).compactMap { (p: NWSPeriod) -> DailyForecastItem? in
            let date = isoFormatter.date(from: p.startTime) ?? parseFallbackDate(p.startTime)
            return DailyForecastItem(
                dayName: p.name.isEmpty ? (p.isDaytime ? "Day" : "Night") : p.name,
                date: date,
                highF: p.isDaytime ? p.temperatureInFahrenheit : nil,
                lowF: !p.isDaytime ? p.temperatureInFahrenheit : nil,
                condition: p.shortForecast,
                iconSystemName: WeatherIconMapper.symbol(for: p.shortForecast, isDaytime: p.isDaytime),
                detailedForecast: p.detailedForecast,
                precipitationChance: p.probabilityOfPrecipitation?.value.map { Int($0) }
            )
        }

        return WeatherData(
            location: location,
            current: currentWeather,
            hourly: hourlyItems,
            daily: dailyItems,
            alerts: alerts,
            serviceId: id,
            serviceName: displayName,
            fetchedAt: Date()
        )
    }

    private func fetchNWSForecastPeriods(urlString: String) async throws -> [NWSPeriod] {
        guard let url = URL(string: urlString) else {
            throw WeatherServiceError.invalidResponse("Invalid forecast URL: \(urlString)")
        }

        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/geo+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw WeatherServiceError.invalidResponse("Failed to fetch forecast from \(urlString)")
        }

        let forecastResponse = try JSONDecoder().decode(NWSForecastResponse.self, from: data)
        return forecastResponse.properties.periods
    }

    private func fetchNWSAlerts(latitude: Double, longitude: Double) async -> [WeatherAlert] {
        let alertsUrlString = String(format: "https://api.weather.gov/alerts/active?point=%.4f,%.4f", latitude, longitude)
        guard let url = URL(string: alertsUrlString) else { return [] }

        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/geo+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return []
            }
            let alertResponse = try JSONDecoder().decode(NWSAlertsResponse.self, from: data)
            return alertResponse.features.map { feature in
                WeatherAlert(
                    event: feature.properties.event,
                    headline: feature.properties.headline,
                    severity: feature.properties.severity ?? "Alert",
                    description: feature.properties.description ?? "",
                    instruction: feature.properties.instruction
                )
            }
        } catch {
            return []
        }
    }
}

private func parseFallbackDate(_ string: String) -> Date? {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
    return formatter.date(from: string)
}

// MARK: - Decodable NWS JSON Models

struct NWSPointsResponse: Decodable {
    struct Properties: Decodable {
        let forecast: String
        let forecastHourly: String
    }
    let properties: Properties
}

struct NWSForecastResponse: Decodable {
    struct Properties: Decodable {
        let periods: [NWSPeriod]
    }
    let properties: Properties
}

struct NWSPeriod: Decodable {
    let number: Int
    let name: String
    let startTime: String
    let endTime: String?
    let isDaytime: Bool
    let temperature: Double
    let temperatureUnit: String
    let windSpeed: String
    let windDirection: String?
    let shortForecast: String
    let detailedForecast: String?
    let relativeHumidity: NWSValue?
    let dewpoint: NWSValue?
    let probabilityOfPrecipitation: NWSValue?

    var temperatureInFahrenheit: Double {
        if temperatureUnit.uppercased() == "C" {
            return (temperature * 9 / 5) + 32
        }
        return temperature
    }
}

struct NWSValue: Decodable {
    let unitCode: String?
    let value: Double?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        unitCode = try container.decodeIfPresent(String.self, forKey: .unitCode)
        // NWS value can sometimes be null or an Int or Double
        if let doubleVal = try? container.decodeIfPresent(Double.self, forKey: .value) {
            value = doubleVal
        } else if let intVal = try? container.decodeIfPresent(Int.self, forKey: .value) {
            value = Double(intVal)
        } else {
            value = nil
        }
    }

    enum CodingKeys: String, CodingKey {
        case unitCode, value
    }
}

struct NWSAlertsResponse: Decodable {
    struct Feature: Decodable {
        struct Properties: Decodable {
            let event: String
            let headline: String?
            let severity: String?
            let description: String?
            let instruction: String?
        }
        let properties: Properties
    }
    let features: [Feature]
}
