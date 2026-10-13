import Foundation
import SwiftUI
import Combine

@MainActor
public final class WeatherViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published public var weatherData: WeatherData?
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String? = nil

    @Published public var selectedLocation: WeatherLocation {
        didSet {
            saveLocationPreference()
            Task { await refresh() }
        }
    }

    @Published public var savedLocations: [WeatherLocation] {
        didSet {
            saveSavedLocationsPreference()
        }
    }

    @Published public var selectedServiceId: String {
        didSet {
            saveServicePreference()
            Task { await refresh() }
        }
    }

    @Published public var temperatureUnit: TemperatureUnit {
        didSet {
            saveUnitPreference()
        }
    }

    @Published public var menuBarDisplayMode: MenuBarDisplayMode {
        didSet {
            saveDisplayModePreference()
        }
    }

    @Published public var refreshInterval: RefreshInterval {
        didSet {
            saveRefreshIntervalPreference()
            setupTimer()
        }
    }

    // MARK: - Private State

    private let geocodingService = GeocodingService()
    private var timerTask: Task<Void, Never>?

    // MARK: - Initializer

    public init() {
        // Defaults
        let defaultLocation = WeatherLocation.defaultPresets[0] // Seattle, WA
        self.selectedLocation = defaultLocation
        self.savedLocations = Array(WeatherLocation.defaultPresets.prefix(5))
        self.selectedServiceId = "nws" // Primary default is NWS
        self.temperatureUnit = .fahrenheit
        self.menuBarDisplayMode = .iconAndTemp
        self.refreshInterval = .fifteenMinutes

        loadPreferences()
        setupTimer()

        Task {
            await refresh()
        }
    }

    deinit {
        timerTask?.cancel()
    }

    // MARK: - Services

    public var availableServices: [any WeatherService] {
        WeatherServiceRegistry.shared.allServices
    }

    public var currentService: any WeatherService {
        WeatherServiceRegistry.shared.service(for: selectedServiceId)
            ?? WeatherServiceRegistry.shared.defaultService
    }

    // MARK: - Menu Bar Display Helpers

    public var menuBarIcon: String {
        weatherData?.current.iconSystemName ?? "cloud.sun.fill"
    }

    public var menuBarTemperatureText: String {
        guard let tempF = weatherData?.current.temperatureF else { return "--°" }
        return temperatureUnit.formatShort(degreesFahrenheit: tempF)
    }

    public var formattedCurrentTemp: String {
        guard let tempF = weatherData?.current.temperatureF else { return "--°" }
        return temperatureUnit.format(degreesFahrenheit: tempF)
    }

    public var formattedHighTemp: String {
        guard let highF = weatherData?.current.highF else { return "--" }
        return temperatureUnit.formatShort(degreesFahrenheit: highF)
    }

    public var formattedLowTemp: String {
        guard let lowF = weatherData?.current.lowF else { return "--" }
        return temperatureUnit.formatShort(degreesFahrenheit: lowF)
    }

    public var formattedApparentTemp: String? {
        guard let appF = weatherData?.current.apparentTemperatureF else { return nil }
        return temperatureUnit.formatShort(degreesFahrenheit: appF)
    }

    public var formattedUpdatedTime: String {
        guard let date = weatherData?.fetchedAt else { return "Never" }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    // MARK: - Actions

    public func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

        let service = currentService
        let location = selectedLocation

        do {
            let data = try await service.fetchWeather(for: location)
            self.weatherData = data
            self.errorMessage = nil
        } catch let serviceError as WeatherServiceError {
            self.errorMessage = serviceError.localizedDescription
        } catch {
            self.errorMessage = error.localizedDescription
        }

        self.isLoading = false
    }

    public func selectLocation(_ location: WeatherLocation) {
        selectedLocation = location
        if !savedLocations.contains(where: { $0.id == location.id || ($0.name == location.name && $0.adminArea == location.adminArea) }) {
            savedLocations.append(location)
        }
    }

    public func addLocation(_ location: WeatherLocation) {
        if !savedLocations.contains(where: { $0.name == location.name && $0.adminArea == location.adminArea && $0.latitude == location.latitude }) {
            savedLocations.append(location)
        }
    }

    public func removeLocation(_ location: WeatherLocation) {
        savedLocations.removeAll(where: { $0.id == location.id })
        if selectedLocation.id == location.id, let first = savedLocations.first {
            selectedLocation = first
        }
    }

    public func searchLocations(query: String) async -> [WeatherLocation] {
        do {
            return try await geocodingService.searchLocations(query: query)
        } catch {
            return []
        }
    }

    public func selectService(id: String) {
        selectedServiceId = id
    }

    // MARK: - Auto Refresh Timer

    private func setupTimer() {
        timerTask?.cancel()
        guard refreshInterval.rawValue > 0 else { return }

        let intervalSeconds = UInt64(refreshInterval.rawValue) * 1_000_000_000
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: intervalSeconds)
                guard !Task.isCancelled else { break }
                await self?.refresh()
            }
        }
    }

    // MARK: - Persistence (UserDefaults)

    private let userDefaults = UserDefaults.standard
    private let kSelectedLocation = "weatherbar_selected_location"
    private let kSavedLocations = "weatherbar_saved_locations"
    private let kSelectedService = "weatherbar_selected_service"
    private let kTempUnit = "weatherbar_temp_unit"
    private let kDisplayMode = "weatherbar_display_mode"
    private let kRefreshInterval = "weatherbar_refresh_interval"

    private func loadPreferences() {
        if let data = userDefaults.data(forKey: kSelectedLocation),
           let loc = try? JSONDecoder().decode(WeatherLocation.self, from: data) {
            self.selectedLocation = loc
        }

        if let data = userDefaults.data(forKey: kSavedLocations),
           let locs = try? JSONDecoder().decode([WeatherLocation].self, from: data), !locs.isEmpty {
            self.savedLocations = locs
        }

        if let serviceId = userDefaults.string(forKey: kSelectedService) {
            self.selectedServiceId = serviceId
        }

        if let unitRaw = userDefaults.string(forKey: kTempUnit),
           let unit = TemperatureUnit(rawValue: unitRaw) {
            self.temperatureUnit = unit
        }

        if let modeRaw = userDefaults.string(forKey: kDisplayMode),
           let mode = MenuBarDisplayMode(rawValue: modeRaw) {
            self.menuBarDisplayMode = mode
        }

        let intervalRaw = userDefaults.integer(forKey: kRefreshInterval)
        if intervalRaw > 0, let interval = RefreshInterval(rawValue: intervalRaw) {
            self.refreshInterval = interval
        }
    }

    private func saveLocationPreference() {
        if let data = try? JSONEncoder().encode(selectedLocation) {
            userDefaults.set(data, forKey: kSelectedLocation)
        }
    }

    private func saveSavedLocationsPreference() {
        if let data = try? JSONEncoder().encode(savedLocations) {
            userDefaults.set(data, forKey: kSavedLocations)
        }
    }

    private func saveServicePreference() {
        userDefaults.set(selectedServiceId, forKey: kSelectedService)
    }

    private func saveUnitPreference() {
        userDefaults.set(temperatureUnit.rawValue, forKey: kTempUnit)
    }

    private func saveDisplayModePreference() {
        userDefaults.set(menuBarDisplayMode.rawValue, forKey: kDisplayMode)
    }

    private func saveRefreshIntervalPreference() {
        userDefaults.set(refreshInterval.rawValue, forKey: kRefreshInterval)
    }
}
