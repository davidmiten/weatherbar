import SwiftUI

public struct LocationSearchView: View {
    @ObservedObject var viewModel: WeatherViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var searchText: String = ""
    @State private var searchResults: [WeatherLocation] = []
    @State private var isSearching: Bool = false
    @State private var customLat: String = ""
    @State private var customLon: String = ""
    @State private var customName: String = ""
    @State private var showCustomCoordinates: Bool = false

    public init(viewModel: WeatherViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Text("Select Location")
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

            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search city or postal code...", text: $searchText)
                    .textFieldStyle(.plain)
                    .onSubmit {
                        performSearch()
                    }

                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                        searchResults = []
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                if isSearching {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 16, height: 16)
                }
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )

            // Results / Presets List
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if !searchResults.isEmpty {
                        Text("SEARCH RESULTS")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)

                        ForEach(searchResults) { loc in
                            LocationRow(location: loc, isSelected: viewModel.selectedLocation.id == loc.id) {
                                viewModel.selectLocation(loc)
                                dismiss()
                            }
                        }
                        Divider()
                    }

                    // Saved Locations
                    if !viewModel.savedLocations.isEmpty {
                        Text("SAVED LOCATIONS")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)

                        ForEach(viewModel.savedLocations) { loc in
                            LocationRow(location: loc, isSelected: viewModel.selectedLocation.id == loc.id) {
                                viewModel.selectLocation(loc)
                                dismiss()
                            }
                        }
                        Divider()
                    }

                    // Quick US Presets
                    Text("POPULAR PRESETS")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)

                    ForEach(WeatherLocation.defaultPresets.prefix(8)) { loc in
                        LocationRow(location: loc, isSelected: viewModel.selectedLocation.id == loc.id) {
                            viewModel.selectLocation(loc)
                            dismiss()
                        }
                    }

                    Divider()

                    // Custom Coordinates section
                    DisclosureGroup("Enter Custom Coordinates", isExpanded: $showCustomCoordinates) {
                        VStack(spacing: 8) {
                            TextField("Location Name (e.g. My Cabin)", text: $customName)
                                .textFieldStyle(.roundedBorder)

                            HStack(spacing: 8) {
                                TextField("Latitude (e.g. 47.606)", text: $customLat)
                                    .textFieldStyle(.roundedBorder)
                                TextField("Longitude (e.g. -122.332)", text: $customLon)
                                    .textFieldStyle(.roundedBorder)
                            }

                            Button("Use Coordinates") {
                                if let lat = Double(customLat.trimmingCharacters(in: .whitespaces)),
                                   let lon = Double(customLon.trimmingCharacters(in: .whitespaces)) {
                                    let name = customName.trimmingCharacters(in: .whitespaces).isEmpty
                                        ? String(format: "Custom (%.2f, %.2f)", lat, lon)
                                        : customName
                                    let loc = WeatherLocation(
                                        name: name,
                                        latitude: lat,
                                        longitude: lon
                                    )
                                    viewModel.selectLocation(loc)
                                    dismiss()
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                            .disabled(Double(customLat) == nil || Double(customLon) == nil)
                        }
                        .padding(.top, 4)
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .padding(.horizontal, 2)
            }
        }
        .padding(16)
        .frame(width: 320, height: 420)
    }

    private func performSearch() {
        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isSearching = true
        Task {
            let results = await viewModel.searchLocations(query: searchText)
            await MainActor.run {
                self.searchResults = results
                self.isSearching = false
            }
        }
    }
}

private struct LocationRow: View {
    let location: WeatherLocation
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(location.displayName)
                        .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                        .foregroundColor(.primary)

                    Text(location.coordinatesFormatted)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(.accentColor)
                        .font(.caption.weight(.bold))
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}
