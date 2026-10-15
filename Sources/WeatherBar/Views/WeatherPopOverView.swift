import SwiftUI

public enum PopOverPanel: Equatable {
    case weather
    case radar
    case locationPicker
    case search
    case settings
}

public struct WeatherPopOverView: View {
    @ObservedObject var viewModel: WeatherViewModel
    @State private var activePanel: PopOverPanel = .weather

    public init(viewModel: WeatherViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            headerBar
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 10)

            Divider()

            // Main Content Container
            ZStack {
                switch activePanel {
                case .weather:
                    weatherView
                        .transition(.opacity)
                case .radar:
                    RadarPanelView(viewModel: viewModel.radarViewModel)
                        .transition(.opacity)
                case .locationPicker:
                    locationPickerView
                        .transition(.opacity)
                case .search:
                    LocationSearchView(viewModel: viewModel) {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            activePanel = .weather
                        }
                    }
                    .transition(.opacity)
                case .settings:
                    SettingsView(viewModel: viewModel) {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            activePanel = .weather
                        }
                    }
                    .transition(.opacity)
                }
            }
            .frame(height: 480)

            Divider()

            // Footer Bar
            footerBar
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color(nsColor: .windowBackgroundColor).opacity(0.4))
        }
        .frame(width: 360)
    }

    // MARK: - Header Bar

    @ViewBuilder
    private var headerBar: some View {
        HStack(alignment: .center, spacing: 8) {
            switch activePanel {
            case .weather:
                // Location Switcher button
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        activePanel = .locationPicker
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.accentColor)
                        Text(viewModel.selectedLocation.displayName)
                            .font(.system(size: 14, weight: .semibold))
                            .lineLimit(1)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)
                .help("Change location")

                Spacer()

                // Refresh button
                Button(action: {
                    Task {
                        await viewModel.refresh()
                    }
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(viewModel.isLoading ? 360 : 0))
                        .animation(
                            viewModel.isLoading ? .linear(duration: 1).repeatForever(autoreverses: false) : .default,
                            value: viewModel.isLoading
                        )
                }
                .buttonStyle(.plain)
                .help("Refresh weather")

                // Radar button
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        activePanel = .radar
                    }
                }) {
                    Image(systemName: "dot.radiowaves.left.and.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Weather radar maps")

                // Search button
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        activePanel = .search
                    }
                }) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Search locations")

                // Settings button
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        activePanel = .settings
                    }
                }) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Preferences")

            case .radar:
                backButton(label: "Weather")
                Spacer()
                Text("Weather Radar")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Button(action: {
                    Task {
                        await viewModel.radarViewModel.loadRadarData(force: true)
                    }
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(viewModel.radarViewModel.isLoading ? 360 : 0))
                        .animation(
                            viewModel.radarViewModel.isLoading ? .linear(duration: 1).repeatForever(autoreverses: false) : .default,
                            value: viewModel.radarViewModel.isLoading
                        )
                }
                .buttonStyle(.plain)
                .help("Refresh radar")

            case .locationPicker:
                backButton(label: "Weather")
                Spacer()
                Text("Locations")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        activePanel = .search
                    }
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
                .help("Add new location")

            case .search:
                backButton(label: "Back")
                Spacer()
                Text("Search Location")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                // Invisible placeholder for balanced title centering
                Image(systemName: "plus").opacity(0)

            case .settings:
                backButton(label: "Weather")
                Spacer()
                Text("Preferences")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                // Invisible placeholder for balanced title centering
                Image(systemName: "plus").opacity(0)
            }
        }
    }

    private func backButton(label: String) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.18)) {
                activePanel = .weather
            }
        }) {
            HStack(spacing: 4) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 11, weight: .semibold))
                Text(label)
                    .font(.system(size: 13))
            }
            .foregroundColor(.accentColor)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Weather Main View

    private var weatherView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 12) {
                // Active Weather Alerts (if any)
                if let alerts = viewModel.weatherData?.alerts, !alerts.isEmpty {
                    AlertsBannerView(alerts: alerts)
                }

                // Error Message (if any)
                if let error = viewModel.errorMessage {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                                .font(.system(size: 14))

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Notice")
                                    .font(.system(size: 12, weight: .semibold))

                                Text(error)
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                        }

                        if viewModel.selectedServiceId == "nws" && error.lowercased().contains("coverage") {
                            Button("Switch to Open-Meteo (Global)") {
                                viewModel.selectService(id: "open-meteo")
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        } else {
                            Button("Retry") {
                                Task { await viewModel.refresh() }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.orange.opacity(0.1))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.orange.opacity(0.25), lineWidth: 1)
                    )
                }

                // Content when loaded
                if viewModel.weatherData != nil {
                    CurrentWeatherHeroView(viewModel: viewModel)

                    RadarQuickCardView(location: viewModel.selectedLocation) {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            activePanel = .radar
                        }
                    }

                    if let hourly = viewModel.weatherData?.hourly, !hourly.isEmpty {
                        HourlyForecastView(items: hourly, unit: viewModel.temperatureUnit)
                    }

                    if let daily = viewModel.weatherData?.daily, !daily.isEmpty {
                        DailyForecastView(items: daily, unit: viewModel.temperatureUnit)
                    }
                } else if viewModel.isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Fetching weather...")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                }
            }
            .padding(12)
        }
    }

    // MARK: - Inline Location Picker View

    private var locationPickerView: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 14) {
                // Button to go to search
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        activePanel = .search
                    }
                }) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.accentColor)
                        Text("Search & Add New Location...")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.accentColor)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.accentColor.opacity(0.1))
                    )
                }
                .buttonStyle(.plain)

                // Saved Locations
                VStack(alignment: .leading, spacing: 6) {
                    Text("SAVED LOCATIONS")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)

                    ForEach(viewModel.savedLocations) { loc in
                        let isSelected = viewModel.selectedLocation.id == loc.id
                        Button(action: {
                            viewModel.selectLocation(loc)
                            withAnimation(.easeInOut(duration: 0.18)) {
                                activePanel = .weather
                            }
                        }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(loc.displayName)
                                        .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                                        .foregroundColor(.primary)

                                    Text(loc.coordinatesFormatted)
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                if isSelected {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.accentColor)
                                        .font(.system(size: 14))
                                }
                            }
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(isSelected ? Color.accentColor.opacity(0.1) : Color(nsColor: .controlBackgroundColor))
                            )
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Preset Shortcuts
                VStack(alignment: .leading, spacing: 6) {
                    Text("POPULAR PRESETS")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)

                    ForEach(WeatherLocation.defaultPresets.prefix(6)) { loc in
                        let isSelected = viewModel.selectedLocation.id == loc.id
                        Button(action: {
                            viewModel.selectLocation(loc)
                            withAnimation(.easeInOut(duration: 0.18)) {
                                activePanel = .weather
                            }
                        }) {
                            HStack {
                                Text(loc.displayName)
                                    .font(.system(size: 12))
                                    .foregroundColor(.primary)
                                Spacer()
                                if isSelected {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                        .font(.caption)
                                }
                            }
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
    }

    // MARK: - Footer Bar

    private var footerBar: some View {
        HStack {
            Text("Updated \(viewModel.formattedUpdatedTime)")
                .font(.system(size: 10))
                .foregroundColor(.secondary)

            Spacer()

            // Service tag badge
            Text(viewModel.currentService.id.uppercased())
                .font(.system(size: 9, weight: .bold))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    Capsule().fill(Color(nsColor: .controlBackgroundColor))
                )
                .foregroundColor(.secondary)

            Divider()
                .frame(height: 12)

            Button(action: {
                NSApplication.shared.terminate(nil)
            }) {
                Text("Quit")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
    }
}
