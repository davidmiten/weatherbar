# WeatherBar for macOS

A native macOS menu bar GUI widget that displays weather information right next to your clock in the menu bar. Built with **Swift** and **SwiftUI**.

Designed with a pluggable architecture supporting multiple weather API providers—starting with the **National Weather Service (NWS)** API as well as **Open-Meteo** for worldwide coverage.

---

## Features

- **Menu Bar Widget (Next to Clock)**:
  - Displays current condition icon and temperature directly in the macOS menu bar.
  - Fully customizable: *Icon & Temperature*, *Icon Only*, or *Temperature Only*.
  - Runs as an agent app (`LSUIElement`) so it stays neatly in your menu bar without cluttering the Dock.

- **Rich Popover GUI**:
  - **Hero View**: Current temperature, weather condition, feels like, high/low.
  - **Detailed Metrics**: Humidity %, wind speed and direction, precipitation chance %, and dew point.
  - **Severe Weather Alerts**: Displays active official warnings (from NWS) with expandable instructions and severity badges.
  - **Hourly Forecast**: 24-hour horizontal scrolling view with temperatures, icons, and rain probabilities.
  - **Extended Forecast**: Multi-day forecast with daily highs, lows, and conditions.

- **Multiple Weather API Services**:
  - **National Weather Service (NWS - `api.weather.gov`)**: Official US weather agency, high precision, no API key required.
  - **Open-Meteo (`api.open-meteo.com`)**: Worldwide coverage with open-source meteorological models, no API key required.
  - **Pluggable Architecture**: Built around a clean `WeatherService` protocol, making it straightforward to add new services (such as OpenWeatherMap, WeatherAPI, PirateWeather, etc.).

- **Location Management**:
  - Search any city, place, or postal code worldwide with automatic geocoding.
  - Popular US presets (Seattle, San Francisco, New York, Chicago, Denver, Austin, Miami, etc.).
  - Custom latitude & longitude coordinate entry.
  - Save multiple favorite locations and switch between them with one click.

- **Preferences & Settings**:
  - Temperature Units: Toggle between Fahrenheit (°F) and Celsius (°C).
  - Wind Speed Units: Toggle between MPH (miles per hour) and KPH (kilometers per hour).
  - Open on Boot: System startup checkbox to automatically launch WeatherBar when macOS boots (via `ServiceManagement`).
  - Auto-refresh: Choose between 10 minutes, 15 minutes, 30 minutes, 1 hour, or manual.
  - Provider selection: Switch between NWS and Open-Meteo anytime.

---

## Project Structure

```
weatherApp/
├── Package.swift                    # Swift Package Manager definition (macOS 13+)
├── WeatherBar.app/                  # Packaged macOS application bundle
├── Sources/
│   └── WeatherBar/
│       ├── WeatherBarApp.swift      # Main app entry point with MenuBarExtra
│       ├── Models/
│       │   ├── WeatherLocation.swift# Location model with coordinates and presets
│       │   ├── WeatherData.swift    # Current, hourly, daily, and alert models
│       │   ├── Settings.swift       # Preferences (Units, Display mode, Refresh intervals)
│       │   └── WeatherIconMapper.swift # Maps conditions/WMO codes to SF Symbols & colors
│       ├── Services/
│       │   ├── WeatherService.swift # WeatherService protocol & Service Registry
│       │   ├── NWSWeatherService.swift # National Weather Service API provider
│       │   ├── OpenMeteoWeatherService.swift # Open-Meteo API provider
│       │   └── GeocodingService.swift # City search & coordinate geocoding
│       ├── ViewModels/
│       │   └── WeatherViewModel.swift# State management, background timer, persistence
│       └── Views/
│           ├── MenuBarLabelView.swift# Icon and temperature label in system menu bar
│           ├── WeatherPopOverView.swift # Main interactive popover window
│           ├── CurrentWeatherHeroView.swift # Temperature and metrics grid
│           ├── HourlyForecastView.swift # Horizontal hourly forecast cards
│           ├── DailyForecastView.swift # Extended multi-day forecast list
│           ├── AlertsBannerView.swift # Warning banner for severe weather alerts
│           ├── LocationSearchView.swift # Search modal for cities & coordinates
│           └── SettingsView.swift   # Preferences sheet
├── Resources/
│   ├── AppIcon_1024.png             # Master 1024x1024 PNG icon
│   └── AppIcon.icns                 # Compiled multi-resolution macOS icon bundle
├── Tests/
│   └── WeatherBarTests/
│       └── WeatherBarTests.swift    # Unit & live integration test suite
└── scripts/
    ├── build_app.sh                 # Compiles release binary and packages WeatherBar.app
    ├── generate_icns.sh             # Generates AppIcon.icns from AppIcon_1024.png
    ├── install_to_applications.sh   # Compiles, signs, and installs to /Applications
    ├── package_app.sh               # Builds app, drag-and-drop DMG, or ZIP archives
    └── run.sh                       # One-command script to build and launch the app
```

---

## Quick Start

### 1. Install Directly to `/Applications`

To package and install WeatherBar into your macOS `/Applications` folder:

```bash
./scripts/install_to_applications.sh
```

This script:
1. Compiles the release binary and packages the signed `WeatherBar.app` bundle with high-resolution app icons.
2. Installs it into `/Applications/WeatherBar.app`.
3. Registers it with macOS LaunchServices and starts the app in your menu bar.

### 2. Package Drag-and-Drop DMG or ZIP Installer

To package standalone installers for distribution:

```bash
# Create a drag-and-drop DMG installer (dist/WeatherBar.dmg)
./scripts/package_app.sh --dmg

# Or create all distribution packages (DMG, ZIP, and install to /Applications)
./scripts/package_app.sh --all
```

### 3. Local Development & Testing

To quickly build and run locally without installing to `/Applications`:

```bash
./scripts/run.sh
```

### 4. Run the Unit & Integration Tests

The project includes unit tests for temperature conversion, icon mapping, service registry, geocoding, and live API fetch tests against the NWS and Open-Meteo endpoints:

```bash
swift test
```

---

## Adding New Weather API Providers

To add a new weather API service (e.g. OpenWeatherMap):

1. Implement the `WeatherService` protocol:
   ```swift
   public struct MyCustomWeatherService: WeatherService {
       public let id = "my-service"
       public let displayName = "My Weather API"
       public let attributionText = "Data from MyWeatherAPI"
       public let requiresAPIKey = true
       public let supportsGlobalLocations = true
       public let serviceDescription = "Description of the service..."

       public func fetchWeather(for location: WeatherLocation) async throws -> WeatherData {
           // Fetch from API and return WeatherData
       }
   }
   ```
2. Register your service in `WeatherServiceRegistry.shared`:
   ```swift
   WeatherServiceRegistry.shared.register(MyCustomWeatherService())
   ```
3. The new provider will immediately appear in the **Preferences** provider selector!

---

## License

MIT
