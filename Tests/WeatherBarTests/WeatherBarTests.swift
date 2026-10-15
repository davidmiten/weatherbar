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

    @Test("Wind Speed Unit Conversion")
    func testWindSpeedUnitConversion() {
        let mph = WindSpeedUnit.mph
        let kph = WindSpeedUnit.kph

        #expect(mph.format(speedMph: 10) == "10 mph")
        #expect(kph.format(speedMph: 10) == "16 km/h")

        #expect(mph.format(rawString: "5 mph") == "5 mph")
        #expect(kph.format(rawString: "5 mph") == "8 km/h")
        #expect(kph.format(rawString: "10 to 15 mph") == "16 to 24 km/h")
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

    @Test("RainViewer Tile and Snapshot URL Generation")
    func testRainViewerURLGeneration() {
        let service = RainViewerService.shared
        let frame = RadarFrame(time: 1710000000, path: "/v2/radar/abc12345")
        let host = "https://tilecache.rainviewer.com"

        let tileTemplate = service.tileURLTemplate(host: host, frame: frame, tileSize: 256, colorScheme: .universalBlue, smooth: true, snow: true)
        #expect(tileTemplate == "https://tilecache.rainviewer.com/v2/radar/abc12345/256/{z}/{x}/{y}/2/1_1.png")

        let snapshotURL = service.coordinateSnapshotURL(
            host: host,
            frame: frame,
            latitude: 47.6062,
            longitude: -122.3321,
            zoom: 6,
            tileSize: 512,
            colorScheme: .universalBlue,
            smooth: true,
            snow: true
        )
        #expect(snapshotURL?.absoluteString == "https://tilecache.rainviewer.com/v2/radar/abc12345/512/6/47.6062/-122.3321/2/1_1.png")

        let coverage = service.coverageTileURLTemplate(host: host, tileSize: 256)
        #expect(coverage == "https://tilecache.rainviewer.com/v2/coverage/0/256/{z}/{x}/{y}/0/0_0.png")
    }

    @Test("Radar Frame Relative Time Formatting")
    func testRadarFrameRelativeTime() {
        let now = Date()
        let frameNow = RadarFrame(time: Int(now.timeIntervalSince1970), path: "/v2/radar/test")
        #expect(frameNow.relativeTimeString(relativeTo: now) == "Latest")

        let tenMinAgo = now.addingTimeInterval(-600)
        let frameTenMinAgo = RadarFrame(time: Int(tenMinAgo.timeIntervalSince1970), path: "/v2/radar/test")
        #expect(frameTenMinAgo.relativeTimeString(relativeTo: now) == "-10m")

        let eightyMinAgo = now.addingTimeInterval(-4800)
        let frameEightyMinAgo = RadarFrame(time: Int(eightyMinAgo.timeIntervalSince1970), path: "/v2/radar/test")
        #expect(frameEightyMinAgo.relativeTimeString(relativeTo: now) == "-1h 20m")
    }

    @Test("RainViewer Live API Fetch")
    func testRainViewerLiveFetch() async throws {
        let service = RainViewerService.shared
        let metadata = try await service.fetchMetadata()

        #expect(!metadata.host.isEmpty)
        #expect(metadata.host.starts(with: "http"))
        #expect(!metadata.radar.past.isEmpty)

        // Radar should have multiple frames from the past 2 hours
        let pastFrames = metadata.radar.past
        #expect(pastFrames.count >= 5)

        let latest = pastFrames.last!
        #expect(latest.time > 0)
        #expect(!latest.path.isEmpty)
        #expect(latest.path.starts(with: "/v2/radar/"))
    }

    @Test("Radar ViewModel State and Frame Navigation")
    @MainActor
    func testRadarViewModelNavigation() {
        let seattle = WeatherLocation(name: "Seattle", adminArea: "WA", latitude: 47.6062, longitude: -122.3321)
        let vm = RadarViewModel(location: seattle)

        let mockFrames = [
            RadarFrame(time: 1000, path: "/v2/radar/f1"),
            RadarFrame(time: 1600, path: "/v2/radar/f2"),
            RadarFrame(time: 2200, path: "/v2/radar/f3")
        ]
        vm.frames = mockFrames
        vm.currentFrameIndex = 2

        #expect(vm.isLatestFrame == true)
        #expect(vm.currentFrame?.path == "/v2/radar/f3")

        vm.stepBackward()
        #expect(vm.currentFrameIndex == 1)
        #expect(vm.isLatestFrame == false)

        vm.stepForward()
        #expect(vm.currentFrameIndex == 2)
        #expect(vm.isLatestFrame == true)

        vm.selectFrame(at: 0)
        #expect(vm.currentFrameIndex == 0)

        vm.jumpToLatest()
        #expect(vm.currentFrameIndex == 2)

        vm.zoomLevel = 6.0
        vm.zoomIn()
        #expect(vm.zoomLevel == 7.0)
        vm.zoomIn()
        #expect(vm.zoomLevel == 7.0)

        vm.zoomLevel = 4.0
        vm.zoomOut()
        #expect(vm.zoomLevel == 3.0)
        vm.zoomOut()
        #expect(vm.zoomLevel == 3.0)

        #expect(vm.isSatelliteMode == false)
        vm.toggleSatellite()
        #expect(vm.isSatelliteMode == true)
    }
}

