import Foundation

public struct OpenMeteoWeatherService: WeatherService, Sendable {
    public let id = "open-meteo"
    public let displayName = "Open-Meteo (Global)"
    public let attributionText = "Weather data provided by Open-Meteo.com under CC BY 4.0"
    public let requiresAPIKey = false
    public let supportsGlobalLocations = true
    public let serviceDescription = "Global coverage for any coordinate worldwide. Open-source meteorological models with no API key required."

    public init() {}

    public func fetchWeather(for location: WeatherLocation) async throws -> WeatherData {
        let urlString = String(
            format: "https://api.open-meteo.com/v1/forecast?latitude=%.4f&longitude=%.4f&current=temperature_2m,relative_humidity_2m,apparent_temperature,weather_code,wind_speed_10m,wind_direction_10m&hourly=temperature_2m,weather_code,precipitation_probability,is_day&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max&temperature_unit=fahrenheit&wind_speed_unit=mph&precipitation_unit=inch&timezone=auto",
            location.latitude,
            location.longitude
        )

        guard let url = URL(string: urlString) else {
            throw WeatherServiceError.invalidResponse("Invalid Open-Meteo URL: \(urlString)")
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 15

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw WeatherServiceError.networkError("Failed to connect to Open-Meteo: \(error.localizedDescription)")
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw WeatherServiceError.networkError("Did not receive HTTP response from Open-Meteo")
        }

        guard httpResponse.statusCode == 200 else {
            throw WeatherServiceError.invalidResponse("Open-Meteo returned HTTP status \(httpResponse.statusCode)")
        }

        let omResponse: OpenMeteoResponse
        do {
            omResponse = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)
        } catch {
            throw WeatherServiceError.invalidResponse("Could not parse Open-Meteo response: \(error.localizedDescription)")
        }

        // Current weather
        let currentWMO = omResponse.current.weather_code
        let wmoInfo = WeatherIconMapper.fromWMOCode(currentWMO, isDaytime: true)
        let highF = omResponse.daily.temperature_2m_max.first
        let lowF = omResponse.daily.temperature_2m_min.first

        let current = CurrentWeather(
            temperatureF: omResponse.current.temperature_2m,
            apparentTemperatureF: omResponse.current.apparent_temperature,
            condition: wmoInfo.description,
            iconSystemName: wmoInfo.symbol,
            humidityPercent: omResponse.current.relative_humidity_2m,
            windSpeed: String(format: "%.1f mph", omResponse.current.wind_speed_10m),
            windDirection: omResponse.current.wind_direction_10m != nil ? "\(omResponse.current.wind_direction_10m!)°" : nil,
            dewpointF: nil,
            probabilityOfPrecipitation: omResponse.daily.precipitation_probability_max.first,
            highF: highF,
            lowF: lowF,
            isDaytime: true
        )

        // Hourly (next 24 hours starting from now)
        var hourlyItems: [HourlyForecastItem] = []
        let now = Date()
        let totalHours = omResponse.hourly.time.count
        for i in 0..<totalHours {
            let timeStr = omResponse.hourly.time[i]
            // Open-Meteo local time format: "2026-10-12T17:00"
            guard let date = parseOpenMeteoDate(timeStr) else { continue }
            if date < now.addingTimeInterval(-3600) { continue }
            if hourlyItems.count >= 24 { break }

            let code = omResponse.hourly.weather_code[i]
            let isDay = (omResponse.hourly.is_day?[i] ?? 1) == 1
            let info = WeatherIconMapper.fromWMOCode(code, isDaytime: isDay)
            let precip = omResponse.hourly.precipitation_probability?[i]

            hourlyItems.append(HourlyForecastItem(
                time: date,
                temperatureF: omResponse.hourly.temperature_2m[i],
                condition: info.description,
                iconSystemName: info.symbol,
                precipitationChance: precip,
                isDaytime: isDay
            ))
        }

        // Daily
        var dailyItems: [DailyForecastItem] = []
        let dayDateFormatter = DateFormatter()
        dayDateFormatter.dateFormat = "yyyy-MM-dd"

        let dayDisplayFormatter = DateFormatter()
        dayDisplayFormatter.dateFormat = "EEE"

        let totalDays = omResponse.daily.time.count
        for i in 0..<totalDays {
            let dateStr = omResponse.daily.time[i]
            let date = dayDateFormatter.date(from: dateStr)
            let code = omResponse.daily.weather_code[i]
            let info = WeatherIconMapper.fromWMOCode(code, isDaytime: true)
            let maxTemp = omResponse.daily.temperature_2m_max[i]
            let minTemp = omResponse.daily.temperature_2m_min[i]
            let precip = omResponse.daily.precipitation_probability_max[i]

            let dayName: String
            if i == 0 {
                dayName = "Today"
            } else if let date = date {
                dayName = dayDisplayFormatter.string(from: date)
            } else {
                dayName = "Day \(i + 1)"
            }

            dailyItems.append(DailyForecastItem(
                dayName: dayName,
                date: date,
                highF: maxTemp,
                lowF: minTemp,
                condition: info.description,
                iconSystemName: info.symbol,
                detailedForecast: "\(info.description). High: \(Int(round(maxTemp)))°F, Low: \(Int(round(minTemp)))°F.",
                precipitationChance: precip
            ))
        }

        return WeatherData(
            location: location,
            current: current,
            hourly: hourlyItems,
            daily: dailyItems,
            alerts: [],
            serviceId: id,
            serviceName: displayName,
            fetchedAt: Date()
        )
    }
}

private func parseOpenMeteoDate(_ string: String) -> Date? {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
    formatter.locale = Locale(identifier: "en_US_POSIX")
    return formatter.date(from: string)
}

// MARK: - OpenMeteo JSON Models

struct OpenMeteoResponse: Decodable {
    let current: OpenMeteoCurrent
    let hourly: OpenMeteoHourly
    let daily: OpenMeteoDaily
}

struct OpenMeteoCurrent: Decodable {
    let temperature_2m: Double
    let apparent_temperature: Double?
    let relative_humidity_2m: Int?
    let weather_code: Int
    let wind_speed_10m: Double
    let wind_direction_10m: Int?
}

struct OpenMeteoHourly: Decodable {
    let time: [String]
    let temperature_2m: [Double]
    let weather_code: [Int]
    let precipitation_probability: [Int]?
    let is_day: [Int]?
}

struct OpenMeteoDaily: Decodable {
    let time: [String]
    let weather_code: [Int]
    let temperature_2m_max: [Double]
    let temperature_2m_min: [Double]
    let precipitation_probability_max: [Int]
}
