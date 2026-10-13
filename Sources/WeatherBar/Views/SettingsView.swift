import SwiftUI

public struct SettingsView: View {
    @ObservedObject var viewModel: WeatherViewModel
    @Environment(\.dismiss) private var dismiss

    public init(viewModel: WeatherViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("Preferences")
                    .font(.headline)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.title3)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 4)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // Weather Service Provider Picker
                    VStack(alignment: .leading, spacing: 6) {
                        Text("WEATHER API SERVICE")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)

                        Picker("Service", selection: $viewModel.selectedServiceId) {
                            ForEach(viewModel.availableServices, id: \.id) { service in
                                Text(service.displayName).tag(service.id)
                            }
                        }
                        .pickerStyle(.radioGroup)

                        if let currentService = viewModel.availableServices.first(where: { $0.id == viewModel.selectedServiceId }) {
                            Text(currentService.serviceDescription)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .padding(.top, 2)

                            if !currentService.supportsGlobalLocations {
                                Label("Only US coordinates and territories supported by NWS.", systemImage: "info.circle")
                                    .font(.system(size: 10))
                                    .foregroundColor(.orange)
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

                        Divider()

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

                        Divider()

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

                    // Manage Saved Locations
                    VStack(alignment: .leading, spacing: 8) {
                        Text("SAVED LOCATIONS")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)

                        ForEach(viewModel.savedLocations) { loc in
                            HStack {
                                Text(loc.displayName)
                                    .font(.system(size: 12))
                                Spacer()
                                if viewModel.savedLocations.count > 1 {
                                    Button(action: {
                                        viewModel.removeLocation(loc)
                                    }) {
                                        Image(systemName: "trash")
                                            .font(.caption)
                                            .foregroundColor(.red.opacity(0.8))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(nsColor: .controlBackgroundColor))
                    )

                    // About / Attribution
                    VStack(alignment: .leading, spacing: 4) {
                        Text("ABOUT")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)

                        Text("WeatherBar for macOS")
                            .font(.system(size: 11, weight: .medium))

                        Text(viewModel.currentService.attributionText)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    .padding(10)

                    // Quit Application button
                    Button(action: {
                        NSApplication.shared.terminate(nil)
                    }) {
                        HStack {
                            Image(systemName: "power")
                            Text("Quit WeatherBar")
                        }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                }
                .padding(.horizontal, 2)
            }
        }
        .padding(16)
        .frame(width: 340, height: 460)
    }
}
