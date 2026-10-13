import Foundation

public struct CurrentWeather: Sendable, Codable {
    public var temperatureF: Double
    public var apparentTemperatureF: Double?
    public var condition: String
    public var iconSystemName: String
    public var humidityPercent: Int?
    public var windSpeed: String
    public var windDirection: String?
    public var dewpointF: Double?
    public var probabilityOfPrecipitation: Int?
    public var highF: Double?
    public var lowF: Double?
    public var isDaytime: Bool

    public init(
        temperatureF: Double,
        apparentTemperatureF: Double? = nil,
        condition: String,
        iconSystemName: String,
        humidityPercent: Int? = nil,
        windSpeed: String = "N/A",
        windDirection: String? = nil,
        dewpointF: Double? = nil,
        probabilityOfPrecipitation: Int? = nil,
        highF: Double? = nil,
        lowF: Double? = nil,
        isDaytime: Bool = true
    ) {
        self.temperatureF = temperatureF
        self.apparentTemperatureF = apparentTemperatureF
        self.condition = condition
        self.iconSystemName = iconSystemName
        self.humidityPercent = humidityPercent
        self.windSpeed = windSpeed
        self.windDirection = windDirection
        self.dewpointF = dewpointF
        self.probabilityOfPrecipitation = probabilityOfPrecipitation
        self.highF = highF
        self.lowF = lowF
        self.isDaytime = isDaytime
    }
}

public struct HourlyForecastItem: Identifiable, Sendable, Codable {
    public let id: UUID
    public var time: Date
    public var temperatureF: Double
    public var condition: String
    public var iconSystemName: String
    public var precipitationChance: Int?
    public var isDaytime: Bool

    public init(
        id: UUID = UUID(),
        time: Date,
        temperatureF: Double,
        condition: String,
        iconSystemName: String,
        precipitationChance: Int? = nil,
        isDaytime: Bool = true
    ) {
        self.id = id
        self.time = time
        self.temperatureF = temperatureF
        self.condition = condition
        self.iconSystemName = iconSystemName
        self.precipitationChance = precipitationChance
        self.isDaytime = isDaytime
    }
}

public struct DailyForecastItem: Identifiable, Sendable, Codable {
    public let id: UUID
    public var dayName: String
    public var date: Date?
    public var highF: Double?
    public var lowF: Double?
    public var condition: String
    public var iconSystemName: String
    public var detailedForecast: String?
    public var precipitationChance: Int?

    public init(
        id: UUID = UUID(),
        dayName: String,
        date: Date? = nil,
        highF: Double? = nil,
        lowF: Double? = nil,
        condition: String,
        iconSystemName: String,
        detailedForecast: String? = nil,
        precipitationChance: Int? = nil
    ) {
        self.id = id
        self.dayName = dayName
        self.date = date
        self.highF = highF
        self.lowF = lowF
        self.condition = condition
        self.iconSystemName = iconSystemName
        self.detailedForecast = detailedForecast
        self.precipitationChance = precipitationChance
    }
}

public struct WeatherAlert: Identifiable, Sendable, Codable {
    public let id: UUID
    public var event: String
    public var headline: String?
    public var severity: String
    public var description: String
    public var instruction: String?

    public init(
        id: UUID = UUID(),
        event: String,
        headline: String? = nil,
        severity: String = "Warning",
        description: String,
        instruction: String? = nil
    ) {
        self.id = id
        self.event = event
        self.headline = headline
        self.severity = severity
        self.description = description
        self.instruction = instruction
    }
}

public struct WeatherData: Sendable, Codable {
    public var location: WeatherLocation
    public var current: CurrentWeather
    public var hourly: [HourlyForecastItem]
    public var daily: [DailyForecastItem]
    public var alerts: [WeatherAlert]
    public var serviceId: String
    public var serviceName: String
    public var fetchedAt: Date

    public init(
        location: WeatherLocation,
        current: CurrentWeather,
        hourly: [HourlyForecastItem] = [],
        daily: [DailyForecastItem] = [],
        alerts: [WeatherAlert] = [],
        serviceId: String,
        serviceName: String,
        fetchedAt: Date = Date()
    ) {
        self.location = location
        self.current = current
        self.hourly = hourly
        self.daily = daily
        self.alerts = alerts
        self.serviceId = serviceId
        self.serviceName = serviceName
        self.fetchedAt = fetchedAt
    }
}
