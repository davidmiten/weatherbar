import SwiftUI
import MapKit
import AppKit

// MARK: - AppKit MKMapView Representable

public struct RadarMKMapView: NSViewRepresentable {
    @ObservedObject var viewModel: RadarViewModel

    public init(viewModel: RadarViewModel) {
        self.viewModel = viewModel
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    public func makeNSView(context: Context) -> MKMapView {
        let mapView = MKMapView(frame: .zero)
        mapView.delegate = context.coordinator
        mapView.isZoomEnabled = true
        mapView.isScrollEnabled = true
        mapView.isPitchEnabled = false
        mapView.isRotateEnabled = false
        mapView.showsCompass = false
        mapView.showsScale = true

        // Configure initial camera center and span
        let center = CLLocationCoordinate2D(
            latitude: viewModel.selectedLocation.latitude,
            longitude: viewModel.selectedLocation.longitude
        )
        let span = Self.span(for: viewModel.zoomLevel, latitude: viewModel.selectedLocation.latitude)
        mapView.setRegion(MKCoordinateRegion(center: center, span: span), animated: false)

        // Add location pin annotation
        let pin = MKPointAnnotation()
        pin.coordinate = center
        pin.title = viewModel.selectedLocation.displayName
        mapView.addAnnotation(pin)
        context.coordinator.locationAnnotation = pin

        // Set initial map type
        mapView.mapType = viewModel.isSatelliteMode ? .hybrid : .standard

        // Add initial tile overlay if available
        if let template = viewModel.currentTileURLTemplate {
            let overlay = MKTileOverlay(urlTemplate: template)
            overlay.canReplaceMapContent = false
            overlay.maximumZ = 7
            overlay.minimumZ = 1
            mapView.addOverlay(overlay, level: .aboveRoads)
            context.coordinator.currentTemplate = template
        }

        return mapView
    }

    public func updateNSView(_ mapView: MKMapView, context: Context) {
        let targetType: MKMapType = viewModel.isSatelliteMode ? .hybrid : .standard
        if mapView.mapType != targetType {
            mapView.mapType = targetType
        }

        // Update location pin if location changed
        let center = CLLocationCoordinate2D(
            latitude: viewModel.selectedLocation.latitude,
            longitude: viewModel.selectedLocation.longitude
        )
        if let pin = context.coordinator.locationAnnotation {
            if pin.coordinate.latitude != center.latitude || pin.coordinate.longitude != center.longitude {
                pin.coordinate = center
                pin.title = viewModel.selectedLocation.displayName
            }
        }

        // Handle recenter trigger or location change
        if context.coordinator.lastRecenterTrigger != viewModel.recenterTrigger {
            context.coordinator.lastRecenterTrigger = viewModel.recenterTrigger
            let span = Self.span(for: viewModel.zoomLevel, latitude: viewModel.selectedLocation.latitude)
            mapView.setRegion(MKCoordinateRegion(center: center, span: span), animated: true)
        }

        // Handle zoom level change from controls
        if abs(context.coordinator.lastZoomLevel - viewModel.zoomLevel) > 0.01 {
            context.coordinator.lastZoomLevel = viewModel.zoomLevel
            let currentCenter = mapView.region.center
            let span = Self.span(for: viewModel.zoomLevel, latitude: currentCenter.latitude)
            mapView.setRegion(MKCoordinateRegion(center: currentCenter, span: span), animated: true)
        }

        // Handle radar frame tile overlay change
        let newTemplate = viewModel.currentTileURLTemplate
        if context.coordinator.currentTemplate != newTemplate {
            context.coordinator.currentTemplate = newTemplate

            // Remove existing overlays
            let existingOverlays = mapView.overlays
            if let template = newTemplate {
                let newOverlay = MKTileOverlay(urlTemplate: template)
                newOverlay.canReplaceMapContent = false
                newOverlay.maximumZ = 7
                newOverlay.minimumZ = 1
                mapView.addOverlay(newOverlay, level: .aboveRoads)
            }
            if !existingOverlays.isEmpty {
                mapView.removeOverlays(existingOverlays)
            }
        }

        // Update opacity if changed
        if abs(context.coordinator.currentOpacity - viewModel.overlayOpacity) > 0.01 {
            context.coordinator.currentOpacity = viewModel.overlayOpacity
            for overlay in mapView.overlays {
                if let renderer = mapView.renderer(for: overlay) as? MKTileOverlayRenderer {
                    renderer.alpha = CGFloat(viewModel.overlayOpacity)
                }
            }
        }
    }

    public static func span(for zoomLevel: Double, latitude: Double) -> MKCoordinateSpan {
        let latDelta = 360.0 / pow(2.0, zoomLevel)
        let rad = latitude * .pi / 180.0
        let lonDelta = latDelta * max(0.2, cos(rad))
        return MKCoordinateSpan(
            latitudeDelta: min(120.0, max(0.6, latDelta)),
            longitudeDelta: min(120.0, max(0.6, abs(lonDelta)))
        )
    }

    public final class Coordinator: NSObject, MKMapViewDelegate {
        var parent: RadarMKMapView
        var currentTemplate: String? = nil
        var currentOpacity: Double = 0.75
        var lastRecenterTrigger: UUID? = nil
        var lastZoomLevel: Double = 6.0
        weak var locationAnnotation: MKPointAnnotation?

        init(_ parent: RadarMKMapView) {
            self.parent = parent
            self.currentOpacity = parent.viewModel.overlayOpacity
            self.lastZoomLevel = parent.viewModel.zoomLevel
        }

        public func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let tileOverlay = overlay as? MKTileOverlay {
                let renderer = MKTileOverlayRenderer(tileOverlay: tileOverlay)
                renderer.alpha = CGFloat(currentOpacity)
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        public func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard !(annotation is MKUserLocation) else { return nil }
            let id = "LocationMarker"
            let marker = (mapView.dequeueReusableAnnotationView(withIdentifier: id) as? MKMarkerAnnotationView)
                ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: id)
            marker.annotation = annotation
            marker.markerTintColor = .systemBlue
            marker.glyphImage = NSImage(systemSymbolName: "location.fill", accessibilityDescription: nil)
            marker.canShowCallout = true
            return marker
        }
    }
}

// MARK: - Radar Panel View

public struct RadarPanelView: View {
    @ObservedObject var viewModel: RadarViewModel
    @State private var isAttributionHovered = false

    public init(viewModel: RadarViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 8) {
            // Header: Location Info + Time Indicator
            radarHeader
                .padding(.horizontal, 14)
                .padding(.top, 4)

            // Error notice banner (if any)
            if let error = viewModel.errorMessage {
                errorNotice(error)
                    .padding(.horizontal, 14)
            }

            // Interactive Map Area with Floating Controls
            ZStack(alignment: .topTrailing) {
                RadarMKMapView(viewModel: viewModel)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                    )

                // Floating Map Controls (Recenter, Zoom, Map Mode)
                mapFloatingControls
                    .padding(8)
            }
            .frame(height: 250)
            .padding(.horizontal, 12)

            // Playback & Timeline Controls
            timelineControls
                .padding(.horizontal, 14)

            // Precipitation Intensity Legend
            radarLegend
                .padding(.horizontal, 14)

            // Footer: Attribution & Refresh Status
            footerAttribution
                .padding(.horizontal, 14)
                .padding(.bottom, 6)
        }
        .task {
            await viewModel.loadRadarData()
        }
    }

    // MARK: - Header

    private var radarHeader: some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Image(systemName: "dot.radiowaves.left.and.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.accentColor)
                    Text(viewModel.selectedLocation.displayName)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                }

                Text(viewModel.selectedLocation.coordinatesFormatted)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Time & Live Badge
            HStack(spacing: 6) {
                if viewModel.isLatestFrame {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 7, height: 7)
                        .shadow(color: .green.opacity(0.6), radius: 3)
                }

                VStack(alignment: .trailing, spacing: 1) {
                    Text(viewModel.formattedFrameTime)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)

                    Text(viewModel.frameRelativeText)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(viewModel.isLatestFrame ? .green : .secondary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
        }
    }

    // MARK: - Floating Map Controls

    private var mapFloatingControls: some View {
        VStack(spacing: 6) {
            // Recenter Button
            Button(action: {
                viewModel.recenter()
            }) {
                Image(systemName: "location.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(MapControlButtonStyle())
            .help("Recenter on current location")

            // Zoom In Button
            Button(action: {
                viewModel.zoomIn()
            }) {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .bold))
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(MapControlButtonStyle())
            .disabled(viewModel.zoomLevel >= 7.0)
            .help("Zoom in (max 7x)")

            // Zoom Out Button
            Button(action: {
                viewModel.zoomOut()
            }) {
                Image(systemName: "minus")
                    .font(.system(size: 11, weight: .bold))
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(MapControlButtonStyle())
            .disabled(viewModel.zoomLevel <= 3.0)
            .help("Zoom out")

            // Map Style Button (Standard / Satellite)
            Button(action: {
                viewModel.toggleSatellite()
            }) {
                Image(systemName: viewModel.isSatelliteMode ? "globe.americas.fill" : "map.fill")
                    .font(.system(size: 11, weight: .medium))
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(MapControlButtonStyle(isActive: viewModel.isSatelliteMode))
            .help("Toggle Satellite Imagery")
        }
    }

    // MARK: - Timeline & Playback Controls

    private var timelineControls: some View {
        VStack(spacing: 6) {
            // Playback buttons & frame label
            HStack(spacing: 12) {
                // Step Backward
                Button(action: {
                    viewModel.stepBackward()
                }) {
                    Image(systemName: "backward.frame.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Previous radar frame")

                // Play / Pause Button
                Button(action: {
                    viewModel.togglePlay()
                }) {
                    Image(systemName: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
                .help(viewModel.isPlaying ? "Pause animation" : "Play radar loop")

                // Step Forward
                Button(action: {
                    viewModel.stepForward()
                }) {
                    Image(systemName: "forward.frame.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Next radar frame")

                // Timeline Scrubber Slider
                if !viewModel.frames.isEmpty {
                    Slider(
                        value: Binding(
                            get: { Double(viewModel.currentFrameIndex) },
                            set: { viewModel.selectFrame(at: Int($0.rounded())) }
                        ),
                        in: 0...Double(max(1, viewModel.frames.count - 1)),
                        step: 1
                    )
                    .accentColor(.accentColor)
                } else {
                    ProgressView()
                        .scaleEffect(0.8)
                        .frame(maxWidth: .infinity)
                }

                // Jump to Latest Button
                Button(action: {
                    viewModel.jumpToLatest()
                }) {
                    Text("LIVE")
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(viewModel.isLatestFrame ? Color.green : Color.secondary.opacity(0.3))
                        )
                        .foregroundColor(viewModel.isLatestFrame ? .white : .primary)
                }
                .buttonStyle(.plain)
                .help("Jump to most recent radar scan")
            }

            // Timeline span labels
            HStack {
                Text("-2 hours")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)

                Spacer()

                Text("Past 1h")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)

                Spacer()

                Text("Now")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(viewModel.isLatestFrame ? .green : .secondary)
            }
            .padding(.horizontal, 36)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        )
    }

    // MARK: - Precipitation Legend

    private var radarLegend: some View {
        VStack(spacing: 3) {
            HStack {
                Text("Precipitation Intensity")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
                Text("RainViewer Universal Blue")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }

            // Gradient color bar representing RainViewer universal blue reflectivity
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.50, green: 0.85, blue: 1.00), // Very light rain (cyan)
                    Color(red: 0.10, green: 0.60, blue: 0.95), // Light rain (blue)
                    Color(red: 0.05, green: 0.35, blue: 0.85), // Moderate rain (medium blue)
                    Color(red: 0.40, green: 0.10, blue: 0.80), // Heavy rain (indigo/purple)
                    Color(red: 0.85, green: 0.05, blue: 0.20), // Severe/Hail (red/pink)
                ]),
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: 6)
            .clipShape(Capsule())

            HStack {
                Text("Light")
                    .font(.system(size: 8))
                    .foregroundColor(.secondary)
                Spacer()
                Text("Moderate")
                    .font(.system(size: 8))
                    .foregroundColor(.secondary)
                Spacer()
                Text("Heavy")
                    .font(.system(size: 8))
                    .foregroundColor(.secondary)
                Spacer()
                Text("Severe")
                    .font(.system(size: 8))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.35))
        )
    }

    // MARK: - Footer Attribution

    private var footerAttribution: some View {
        HStack {
            Link(destination: URL(string: "https://www.rainviewer.com")!) {
                HStack(spacing: 4) {
                    Image(systemName: "link")
                        .font(.system(size: 8))
                    Text("Radar data by RainViewer.com")
                        .font(.system(size: 10))
                        .underline(isAttributionHovered)
                }
                .foregroundColor(.secondary)
            }
            .onHover { isAttributionHovered = $0 }

            Spacer()

            if viewModel.isLoading {
                ProgressView()
                    .scaleEffect(0.6)
            } else {
                Button(action: {
                    Task {
                        await viewModel.loadRadarData(force: true)
                    }
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 9))
                        Text("Refresh")
                            .font(.system(size: 10))
                    }
                    .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Refresh radar tiles")
            }
        }
    }

    private func errorNotice(_ msg: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
                .font(.system(size: 11))
            Text(msg)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .lineLimit(2)
            Spacer()
            Button("Retry") {
                Task {
                    await viewModel.loadRadarData(force: true)
                }
            }
            .controlSize(.mini)
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.orange.opacity(0.12))
        )
    }
}

// MARK: - Map Control Button Style

private struct MapControlButtonStyle: ButtonStyle {
    var isActive: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isActive ? Color.accentColor : Color(nsColor: .windowBackgroundColor).opacity(configuration.isPressed ? 0.95 : 0.85))
            )
            .foregroundColor(isActive ? .white : .primary)
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(Color.primary.opacity(0.15), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.12), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Quick Radar Card for Main Weather View

public struct RadarQuickCardView: View {
    let location: WeatherLocation
    let action: () -> Void

    public init(location: WeatherLocation, action: @escaping () -> Void) {
        self.location = location
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.15))
                        .frame(width: 36, height: 36)

                    Image(systemName: "dot.radiowaves.left.and.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.blue)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("Weather Radar Map")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.primary)

                        Text("LIVE")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(Color.green))
                    }

                    Text("Live precipitation & storm tracking for \(location.name)")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                HStack(spacing: 2) {
                    Text("View")
                        .font(.system(size: 11, weight: .medium))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundColor(.accentColor)
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
