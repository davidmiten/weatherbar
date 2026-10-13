import SwiftUI

public struct WeatherPopOverView: View {
    @ObservedObject var viewModel: WeatherViewModel

    @State private var showSearchSheet: Bool = false
    @State private var showSettingsSheet: Bool = false
    @State private var isSpinning: Bool = false

    public init(viewModel: WeatherViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(alignment: .center, spacing: 8) {
                // Location selector menu
                Menu {
                    Section("Saved Locations") {
                        ForEach(viewModel.savedLocations) { loc in
                            Button(action: {
                                viewModel.selectLocation(loc)
                            }) {
                                HStack {
                                    Text(loc.displayName)
                                    if viewModel.selectedLocation.id == loc.id {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    }

                    Divider()

                    Button(action: {
                        showSearchSheet = true
                    }) {
                        Label("Search / Add Location...", systemImage: "magnifyingglass")
                    }

                    Button(action: {
                        showSettingsSheet = true
                    }) {
                        Label("Preferences...", systemImage: "gearshape")
                    }

                    Divider()

                    Button(role: .destructive, action: {
                        NSApplication.shared.terminate(nil)
                    }) {
                        Label("Quit WeatherBar", systemImage: "power")
                    }
                } label: {
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
                .menuStyle(.borderlessButton)
                .fixedSize()

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

                // Search button
                Button(action: {
                    showSearchSheet = true
                }) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Search locations")

                // Settings button
                Button(action: {
                    showSettingsSheet = true
                }) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Preferences")
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 10)

            Divider()

            // Main Content Area
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

                            // If NWS fails due to non-US location, provide quick 1-click switch
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
            .frame(maxHeight: 520)

            Divider()

            // Footer
            HStack {
                HStack(spacing: 4) {
                    Text("Updated \(viewModel.formattedUpdatedTime)")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }

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

                Button(action: {
                    NSApplication.shared.terminate(nil)
                }) {
                    Text("Quit")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color(nsColor: .windowBackgroundColor).opacity(0.4))
        }
        .frame(width: 360)
        .sheet(isPresented: $showSearchSheet) {
            LocationSearchView(viewModel: viewModel)
        }
        .sheet(isPresented: $showSettingsSheet) {
            SettingsView(viewModel: viewModel)
        }
    }
}
