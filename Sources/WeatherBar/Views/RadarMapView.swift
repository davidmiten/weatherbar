import SwiftUI
import MapKit
import AppKit

// MARK: - RainViewer Cached Tile Overlay

public final class RainViewerTileOverlay: MKTileOverlay {
    public static let tileCache: NSCache<NSString, NSData> = {
        let cache = NSCache<NSString, NSData>()
        cache.countLimit = 500
        cache.totalCostLimit = 60 * 1024 * 1024 // 60 MB
        return cache
    }()

    public override func url(forTilePath path: MKTileOverlayPath) -> URL {
        var z = path.z
        if z > 7 { z = 7 }
        if z < 1 { z = 1 }

        let template = self.urlTemplate ?? ""
        let urlStr = template
            .replacingOccurrences(of: "{z}", with: "\(z)")
            .replacingOccurrences(of: "{x}", with: "\(path.x)")
            .replacingOccurrences(of: "{y}", with: "\(path.y)")

        return URL(string: urlStr) ?? super.url(forTilePath: path)
    }

    public override func loadTile(at path: MKTileOverlayPath, result: @escaping (Data?, Error?) -> Void) {
        let tileURL = url(forTilePath: path)
        let cacheKey = tileURL.absoluteString as NSString

        if let cached = Self.tileCache.object(forKey: cacheKey) {
            result(cached as Data, nil)
            return
        }

        var request = URLRequest(url: tileURL)
        request.timeoutInterval = 12.0
        request.setValue("WeatherBar/1.0 (macOS Weather Radar)", forHTTPHeaderField: "User-Agent")

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let httpRes = response as? HTTPURLResponse, httpRes.statusCode == 200, let data = data {
                Self.tileCache.setObject(data as NSData, forKey: cacheKey, cost: data.count)
                result(data, nil)
            } else if let data = data, !data.isEmpty {
                result(data, nil)
            } else {
                result(nil, error)
            }
        }
        task.resume()
    }

    /// Prefetches visible radar tiles for the current coordinates and zoom level across frames into memory cache
    public static func prefetchTiles(
        service: RainViewerService,
        host: String,
        frames: [RadarFrame],
        center: CLLocationCoordinate2D,
        zoom: Double
    ) {
        let z = min(7, max(1, Int(round(zoom))))
        let n = pow(2.0, Double(z))
        let lonClamped = max(-180.0, min(180.0, center.longitude))
        let centerX = Int(floor((lonClamped + 180.0) / 360.0 * n))

        let latClamped = max(-85.0511, min(85.0511, center.latitude))
        let latRad = latClamped * .pi / 180.0
        let centerY = Int(floor((1.0 - log(tan(latRad) + 1.0 / cos(latRad)) / .pi) / 2.0 * n))

        let maxCoord = max(0, Int(n) - 1)

        // 3x3 grid around center tile covers visible map area at current zoom
        var tileCoords: [(x: Int, y: Int)] = []
        for dx in -1...1 {
            for dy in -1...1 {
                let x = min(maxCoord, max(0, centerX + dx))
                let y = min(maxCoord, max(0, centerY + dy))
                tileCoords.append((x, y))
            }
        }

        DispatchQueue.global(qos: .utility).async {
            for frame in frames {
                let template = service.tileURLTemplate(
                    host: host,
                    frame: frame,
                    tileSize: 256,
                    colorScheme: .universalBlue,
                    smooth: true,
                    snow: true
                )

                for coord in tileCoords {
                    let urlStr = template
                        .replacingOccurrences(of: "{z}", with: "\(z)")
                        .replacingOccurrences(of: "{x}", with: "\(coord.x)")
                        .replacingOccurrences(of: "{y}", with: "\(coord.y)")

                    guard let url = URL(string: urlStr) else { continue }
                    let cacheKey = urlStr as NSString

                    if tileCache.object(forKey: cacheKey) != nil {
                        continue
                    }

                    var request = URLRequest(url: url)
                    request.timeoutInterval = 8.0
                    request.setValue("WeatherBar/1.0 (macOS Weather Radar)", forHTTPHeaderField: "User-Agent")

                    URLSession.shared.dataTask(with: request) { data, response, _ in
                        if let httpRes = response as? HTTPURLResponse, httpRes.statusCode == 200, let data = data {
                            tileCache.setObject(data as NSData, forKey: cacheKey, cost: data.count)
                        }
                    }.resume()
                }
            }
        }
    }
}

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

        // Constrain camera zoom distance to match RainViewer zoom levels 3 to 7
        mapView.cameraZoomRange = MKMapView.CameraZoomRange(
            minCenterCoordinateDistance: 70_000,
            maxCenterCoordinateDistance: 8_000_000
        )

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

        // Initialize overlays if radar frames are already loaded
        context.coordinator.updateOverlays(in: mapView, viewModel: viewModel)

        return mapView
    }

    public func updateNSView(_ mapView: MKMapView, context: Context) {
        let coordinator = context.coordinator

        let targetType: MKMapType = viewModel.isSatelliteMode ? .hybrid : .standard
        if mapView.mapType != targetType {
            mapView.mapType = targetType
        }

        // Update location pin if location changed
        let center = CLLocationCoordinate2D(
            latitude: viewModel.selectedLocation.latitude,
            longitude: viewModel.selectedLocation.longitude
        )
        if let pin = coordinator.locationAnnotation {
            if pin.coordinate.latitude != center.latitude || pin.coordinate.longitude != center.longitude {
                pin.coordinate = center
                pin.title = viewModel.selectedLocation.displayName
            }
        }

        // Handle recenter trigger or location change
        if coordinator.lastRecenterTrigger != viewModel.recenterTrigger {
            coordinator.lastRecenterTrigger = viewModel.recenterTrigger
            let span = Self.span(for: viewModel.zoomLevel, latitude: viewModel.selectedLocation.latitude)
            mapView.setRegion(MKCoordinateRegion(center: center, span: span), animated: true)
        }

        // Handle zoom level change from controls
        if abs(coordinator.lastZoomLevel - viewModel.zoomLevel) > 0.01 {
            coordinator.lastZoomLevel = viewModel.zoomLevel
            let currentCenter = mapView.region.center
            let span = Self.span(for: viewModel.zoomLevel, latitude: currentCenter.latitude)
            mapView.setRegion(MKCoordinateRegion(center: currentCenter, span: span), animated: true)
        }

        // Synchronize radar tile overlays with smooth frame-to-frame interpolation
        coordinator.updateOverlays(in: mapView, viewModel: viewModel)
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
        var lastRecenterTrigger: UUID? = nil
        var lastZoomLevel: Double = 6.0
        weak var locationAnnotation: MKPointAnnotation?

        // Dual-overlay ping-pong state for smooth continuous frame interpolation
        var overlayA: RainViewerTileOverlay?
        var templateA: String?
        var overlayB: RainViewerTileOverlay?
        var templateB: String?

        var targetAlphas: [ObjectIdentifier: CGFloat] = [:]
        var renderers: [ObjectIdentifier: MKTileOverlayRenderer] = [:]

        init(_ parent: RadarMKMapView) {
            self.parent = parent
            self.lastZoomLevel = parent.viewModel.zoomLevel
            self.lastRecenterTrigger = parent.viewModel.recenterTrigger
        }

        public func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let tileOverlay = overlay as? RainViewerTileOverlay {
                let renderer = MKTileOverlayRenderer(tileOverlay: tileOverlay)
                let alpha = targetAlphas[ObjectIdentifier(tileOverlay)] ?? CGFloat(parent.viewModel.overlayOpacity)
                renderer.alpha = alpha
                renderers[ObjectIdentifier(tileOverlay)] = renderer
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

        private func setAlpha(for overlay: RainViewerTileOverlay, in mapView: MKMapView, alpha: CGFloat) {
            targetAlphas[ObjectIdentifier(overlay)] = alpha
            let renderer = renderers[ObjectIdentifier(overlay)] ?? (mapView.renderer(for: overlay) as? MKTileOverlayRenderer)
            if let renderer = renderer {
                renderers[ObjectIdentifier(overlay)] = renderer
                if abs(renderer.alpha - alpha) > 0.005 {
                    renderer.alpha = alpha
                    renderer.setNeedsDisplay()
                }
            }
        }

        public func updateOverlays(in mapView: MKMapView, viewModel: RadarViewModel) {
            guard !viewModel.frames.isEmpty else {
                removeAllOverlays(from: mapView)
                return
            }

            let baseOpacity = CGFloat(viewModel.overlayOpacity)

            guard viewModel.isInterpolating && viewModel.frames.count > 1 else {
                // Non-interpolated mode: single frame display
                guard let currentTemplate = viewModel.currentTileURLTemplate else {
                    removeAllOverlays(from: mapView)
                    return
                }

                if let b = overlayB {
                    mapView.removeOverlay(b)
                    renderers.removeValue(forKey: ObjectIdentifier(b))
                    targetAlphas.removeValue(forKey: ObjectIdentifier(b))
                    overlayB = nil
                    templateB = nil
                }

                if templateA == currentTemplate, let a = overlayA {
                    setAlpha(for: a, in: mapView, alpha: baseOpacity)
                } else {
                    if let a = overlayA {
                        mapView.removeOverlay(a)
                        renderers.removeValue(forKey: ObjectIdentifier(a))
                        targetAlphas.removeValue(forKey: ObjectIdentifier(a))
                    }
                    let newA = RainViewerTileOverlay(urlTemplate: currentTemplate)
                    newA.canReplaceMapContent = false
                    newA.maximumZ = 7
                    newA.minimumZ = 1
                    overlayA = newA
                    templateA = currentTemplate
                    targetAlphas[ObjectIdentifier(newA)] = baseOpacity
                    mapView.addOverlay(newA, level: .aboveRoads)
                    setAlpha(for: newA, in: mapView, alpha: baseOpacity)
                }
                return
            }

            // Interpolated mode: double-buffered crossfade between adjacent frames
            let count = viewModel.frames.count
            let clamped = max(0.0, min(Double(count - 1), viewModel.animationProgress))
            let lower = Int(floor(clamped))
            let upper = min(count - 1, lower + 1)
            let fraction = clamped - Double(lower)

            let lowerTemplate = viewModel.tileURLTemplate(for: viewModel.frames[lower])
            let upperTemplate = viewModel.tileURLTemplate(for: viewModel.frames[upper])

            // Smooth cosine blending curve for gradual, natural transition
            let smoothFraction = CGFloat((1.0 - cos(fraction * .pi)) / 2.0)
            let alphaLower: CGFloat
            let alphaUpper: CGFloat

            if lower == upper {
                alphaLower = baseOpacity
                alphaUpper = 0.0
            } else {
                alphaLower = (1.0 - smoothFraction) * baseOpacity
                alphaUpper = smoothFraction * baseOpacity
            }

            // Double-buffer ping-pong slots
            if templateA == lowerTemplate {
                setAlpha(for: overlayA!, in: mapView, alpha: alphaLower)

                if upper == lower {
                    if let b = overlayB {
                        mapView.removeOverlay(b)
                        renderers.removeValue(forKey: ObjectIdentifier(b))
                        targetAlphas.removeValue(forKey: ObjectIdentifier(b))
                        overlayB = nil
                        templateB = nil
                    }
                } else if templateB == upperTemplate, let b = overlayB {
                    setAlpha(for: b, in: mapView, alpha: alphaUpper)
                } else {
                    if let b = overlayB {
                        mapView.removeOverlay(b)
                        renderers.removeValue(forKey: ObjectIdentifier(b))
                        targetAlphas.removeValue(forKey: ObjectIdentifier(b))
                    }
                    let newB = RainViewerTileOverlay(urlTemplate: upperTemplate)
                    newB.canReplaceMapContent = false
                    newB.maximumZ = 7
                    newB.minimumZ = 1
                    overlayB = newB
                    templateB = upperTemplate
                    targetAlphas[ObjectIdentifier(newB)] = alphaUpper
                    mapView.addOverlay(newB, level: .aboveRoads)
                    setAlpha(for: newB, in: mapView, alpha: alphaUpper)
                }
            } else if templateB == lowerTemplate {
                setAlpha(for: overlayB!, in: mapView, alpha: alphaLower)

                if upper == lower {
                    if let a = overlayA {
                        mapView.removeOverlay(a)
                        renderers.removeValue(forKey: ObjectIdentifier(a))
                        targetAlphas.removeValue(forKey: ObjectIdentifier(a))
                        overlayA = nil
                        templateA = nil
                    }
                } else if templateA == upperTemplate, let a = overlayA {
                    setAlpha(for: a, in: mapView, alpha: alphaUpper)
                } else {
                    if let a = overlayA {
                        mapView.removeOverlay(a)
                        renderers.removeValue(forKey: ObjectIdentifier(a))
                        targetAlphas.removeValue(forKey: ObjectIdentifier(a))
                    }
                    let newA = RainViewerTileOverlay(urlTemplate: upperTemplate)
                    newA.canReplaceMapContent = false
                    newA.maximumZ = 7
                    newA.minimumZ = 1
                    overlayA = newA
                    templateA = upperTemplate
                    targetAlphas[ObjectIdentifier(newA)] = alphaUpper
                    mapView.addOverlay(newA, level: .aboveRoads)
                    setAlpha(for: newA, in: mapView, alpha: alphaUpper)
                }
            } else {
                // Neither slot matches lower frame: clean up and rebuild
                removeAllOverlays(from: mapView)

                let newA = RainViewerTileOverlay(urlTemplate: lowerTemplate)
                newA.canReplaceMapContent = false
                newA.maximumZ = 7
                newA.minimumZ = 1
                overlayA = newA
                templateA = lowerTemplate
                targetAlphas[ObjectIdentifier(newA)] = alphaLower
                mapView.addOverlay(newA, level: .aboveRoads)
                setAlpha(for: newA, in: mapView, alpha: alphaLower)

                if upper != lower {
                    let newB = RainViewerTileOverlay(urlTemplate: upperTemplate)
                    newB.canReplaceMapContent = false
                    newB.maximumZ = 7
                    newB.minimumZ = 1
                    overlayB = newB
                    templateB = upperTemplate
                    targetAlphas[ObjectIdentifier(newB)] = alphaUpper
                    mapView.addOverlay(newB, level: .aboveRoads)
                    setAlpha(for: newB, in: mapView, alpha: alphaUpper)
                }
            }
        }

        func removeAllOverlays(from mapView: MKMapView) {
            if let a = overlayA {
                mapView.removeOverlay(a)
                renderers.removeValue(forKey: ObjectIdentifier(a))
                targetAlphas.removeValue(forKey: ObjectIdentifier(a))
            }
            if let b = overlayB {
                mapView.removeOverlay(b)
                renderers.removeValue(forKey: ObjectIdentifier(b))
                targetAlphas.removeValue(forKey: ObjectIdentifier(b))
            }
            overlayA = nil
            templateA = nil
            overlayB = nil
            templateB = nil

            let strays = mapView.overlays.filter { $0 is MKTileOverlay }
            if !strays.isEmpty {
                mapView.removeOverlays(strays)
            }
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

            // Smooth Interpolation Toggle Button
            Button(action: {
                viewModel.isInterpolating.toggle()
            }) {
                Image(systemName: viewModel.isInterpolating ? "waveform" : "waveform.slash")
                    .font(.system(size: 11, weight: .medium))
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(MapControlButtonStyle(isActive: viewModel.isInterpolating))
            .help(viewModel.isInterpolating ? "Smooth frame interpolation: ON" : "Smooth frame interpolation: OFF")
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

                // Timeline Scrubber Slider with continuous interpolated scrubbing
                if !viewModel.frames.isEmpty {
                    Slider(
                        value: Binding(
                            get: { viewModel.animationProgress },
                            set: { newValue in
                                viewModel.pause()
                                viewModel.animationProgress = newValue
                                viewModel.currentFrameIndex = min(viewModel.frames.count - 1, max(0, Int(round(newValue))))
                            }
                        ),
                        in: 0...Double(max(1, viewModel.frames.count - 1))
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
