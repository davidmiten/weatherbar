import Testing
import Foundation
@testable import WeatherBar

@Suite("WeatherBar Unit and Integration Tests")
struct WeatherBarTests {

    @Test("Temperature Unit Conversion")
    func testTemperatureUnitConversion() {
        let fahrenheit = TemperatureUnit.fahrenheit
        let celsius = TemperatureUnit.celsius

        #expect(fahrenheit.format(degreesFahrenheit: 32) == "32°F")
        #expect(celsius.format(degreesFahrenheit: 32) == "0°C")
        #expect(celsius.format(degreesFahrenheit: 212) == "100°C")
        #expect(fahrenheit.formatShort(degreesFahrenheit: 68) == "68°")
        #expect(celsius.formatShort(degreesFahrenheit: 68) == "20°")
    }

    @Test("Weather Location Display Formatting")
    func testWeatherLocationFormatting() {
        let seattle = WeatherLocation(name: "Seattle", adminArea: "WA", country: "United States", latitude: 47.6062, longitude: -122.3321)
        #expect(seattle.displayName == "Seattle, WA")
        #expect(seattle.coordinatesFormatted == "47.606°, -122.332°")

        let london = WeatherLocation(name: "London", country: "United Kingdom", latitude: 51.5074, longitude: -0.1278)
        #expect(london.displayName == "London, United Kingdom")
    }

    @Test("Weather Icon Mapper Keyword Matching")
    func testWeatherIconMapper() {
        #expect(WeatherIconMapper.symbol(for: "Sunny", isDaytime: true) == "sun.max.fill")
        #expect(WeatherIconMapper.symbol(for: "Clear", isDaytime: false) == "moon.stars.fill")
        #expect(WeatherIconMapper.symbol(for: "Scattered Thunderstorms", isDaytime: true) == "cloud.bolt.rain.fill")
        #expect(WeatherIconMapper.symbol(for: "Heavy Rain", isDaytime: true) == "cloud.heavyrain.fill")
        #expect(WeatherIconMapper.symbol(for: "Dense Fog", isDaytime: true) == "cloud.fog.fill")
        #expect(WeatherIconMapper.symbol(for: "Partly Cloudy", isDaytime: true) == "cloud.sun.fill")
    }

    @Test("Weather Service Registry")
    func testServiceRegistry() {
        let registry = WeatherServiceRegistry.shared
        #expect(registry.allServices.count >= 2)
        #expect(registry.defaultService.id == "nws")

        let nws = registry.service(for: "nws")
        #expect(nws != nil)
        #expect(nws?.displayName.contains("National Weather Service") == true)

        let openMeteo = registry.service(for: "open-meteo")
        #expect(openMeteo != nil)
        #expect(openMeteo?.supportsGlobalLocations == true)
    }

    @Test("NWS Weather Service Live API Fetch")
    func testNWSFetch() async throws {
        let nws = NWSWeatherService()
        let seattle = WeatherLocation(
            name: "Seattle",
            adminArea: "WA",
            latitude: 47.6062,
            longitude: -122.3321
        )

        let data = try await nws.fetchWeather(for: seattle)
        #expect(data.current.temperatureF > -50 && data.current.temperatureF < 150)
        #expect(!data.current.condition.isEmpty)
        #expect(!data.current.iconSystemName.isEmpty)
        #expect(!data.hourly.isEmpty)
        #expect(!data.daily.isEmpty)
        #expect(data.serviceId == "nws")
    }

    @Test("Open-Meteo Live API Fetch for Global Location")
    func testOpenMeteoFetch() async throws {
        let om = OpenMeteoWeatherService()
        let tokyo = WeatherLocation(
            name: "Tokyo",
            country: "Japan",
            latitude: 35.6762,
            longitude: 139.6503
        )

        let data = try await om.fetchWeather(for: tokyo)
        #expect(data.current.temperatureF > -50 && data.current.temperatureF < 150)
        #expect(!data.hourly.isEmpty)
        #expect(!data.daily.isEmpty)
        #expect(data.serviceId == "open-meteo")
    }

    @Test("Geocoding Search Service")
    func testGeocodingSearch() async throws {
        let geocoder = GeocodingService()
        let results = try await geocoder.searchLocations(query: "Chicago")
        #expect(!results.isEmpty)
        #expect(results.contains(where: { $0.name.lowercased().contains("chicago") }))
    }
}
