import SwiftUI

public struct SettingsView: View {
    @ObservedObject var viewModel: WeatherViewModel
    var onBack: (() -> Void)? = nil

    public init(viewModel: WeatherViewModel, onBack: (() -> Void)? = nil) {
        self.viewModel = viewModel
        self.onBack = onBack
    }

    public var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 14) {
                // Weather Service Provider Picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("WEATHER API SERVICE")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)

                    VStack(spacing: 6) {
                        ForEach(viewModel.availableServices, id: \.id) { service in
                            let isSelected = viewModel.selectedServiceId == service.id
                            Button(action: {
                                viewModel.selectService(id: service.id)
                            }) {
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                                        .foregroundColor(isSelected ? .accentColor : .secondary)
                                        .font(.system(size: 14))
                                        .padding(.top, 2)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(service.displayName)
                                            .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                                            .foregroundColor(.primary)

                                        Text(service.serviceDescription)
                                            .font(.system(size: 11))
                                            .foregroundColor(.secondary)
                                            .fixedSize(horizontal: false, vertical: true)

                                        if !service.supportsGlobalLocations {
                                            Label("US coordinates only (weather.gov)", systemImage: "info.circle")
                                                .font(.system(size: 10))
                                                .foregroundColor(.orange)
                                                .padding(.top, 1)
                                        }
                                    }
                                    Spacer()
                                }
                                .padding(8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(isSelected ? Color.accentColor.opacity(0.08) : Color.clear)
                                )
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )

                // Units & Display Mode
                VStack(alignment: .leading, spacing: 12) {
                    Text("DISPLAY & UNITS")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)

                    HStack {
                        Text("Temperature Unit:")
                            .font(.system(size: 12))
                        Spacer()
                        Picker("", selection: $viewModel.temperatureUnit) {
                            ForEach(TemperatureUnit.allCases) { unit in
                                Text(unit.displayName).tag(unit)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                        .frame(width: 170)
                    }

                    Divider().opacity(0.6)

                    HStack {
                        Text("Wind Speed Unit:")
                            .font(.system(size: 12))
                        Spacer()
                        Picker("", selection: $viewModel.windSpeedUnit) {
                            ForEach(WindSpeedUnit.allCases) { unit in
                                Text(unit.displayName).tag(unit)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                        .frame(width: 170)
                    }

                    Divider().opacity(0.6)

                    HStack {
                        Text("Menu Bar Style:")
                            .font(.system(size: 12))
                        Spacer()
                        Picker("", selection: $viewModel.menuBarDisplayMode) {
                            ForEach(MenuBarDisplayMode.allCases) { mode in
                                Text(mode.displayName).tag(mode)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(width: 170)
                    }

                    Divider().opacity(0.6)

                    HStack {
                        Text("Auto Refresh:")
                            .font(.system(size: 12))
                        Spacer()
                        Picker("", selection: $viewModel.refreshInterval) {
                            ForEach(RefreshInterval.allCases) { interval in
                                Text(interval.displayName).tag(interval)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(width: 170)
                    }
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )

                // System & Startup (Open on Boot)
                VStack(alignment: .leading, spacing: 8) {
                    Text("SYSTEM & STARTUP")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)

                    Toggle(isOn: Binding(
                        get: { viewModel.launchAtLogin },
                        set: { viewModel.setLaunchAtLogin(enabled: $0) }
                    )) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Open on boot")
                                .font(.system(size: 12, weight: .medium))
                            Text("Automatically launch WeatherBar in the menu bar when your Mac boots.")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    }
                    .toggleStyle(.checkbox)
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )

                // Manage Saved Locations
                VStack(alignment: .leading, spacing: 8) {
                    Text("SAVED LOCATIONS")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)

                    ForEach(viewModel.savedLocations) { loc in
                        HStack {
                            Text(loc.displayName)
                                .font(.system(size: 12))
                                .foregroundColor(viewModel.selectedLocation.id == loc.id ? .accentColor : .primary)
                            if viewModel.selectedLocation.id == loc.id {
                                Text("(Active)")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if viewModel.savedLocations.count > 1 {
                                Button(action: {
                                    viewModel.removeLocation(loc)
                                }) {
                                    Image(systemName: "trash")
                                        .font(.system(size: 11))
                                        .foregroundColor(.red.opacity(0.8))
                                }
                                .buttonStyle(.plain)
                                .help("Remove saved location")
                            }
                        }
                        .padding(.vertical, 3)
                    }
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )

                // About / Attribution
                VStack(alignment: .leading, spacing: 4) {
                    Text("ABOUT & ATTRIBUTION")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)

                    Text("WeatherBar for macOS")
                        .font(.system(size: 12, weight: .medium))

                    Text(viewModel.currentService.attributionText)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .padding(10)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
    }
}
