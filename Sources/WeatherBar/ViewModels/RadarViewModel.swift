import Foundation
import SwiftUI
import MapKit
import Combine

@MainActor
public final class RadarViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published public var selectedLocation: WeatherLocation {
        didSet {
            recenter()
            prefetchVisibleTiles()
        }
    }

    @Published public var metadata: RainViewerMetadata? = nil
    @Published public var frames: [RadarFrame] = []
    @Published public var currentFrameIndex: Int = 0 {
        didSet {
            if !isPlaying && abs(animationProgress - Double(currentFrameIndex)) >= 1.0 {
                animationProgress = Double(currentFrameIndex)
            }
        }
    }
    /// Fractional playback/scrubber position along the timeline (e.g. 2.4 is 40% between frame 2 and frame 3)
    @Published public var animationProgress: Double = 0.0
    /// Whether smooth frame interpolation is enabled
    @Published public var isInterpolating: Bool = true
    @Published public var isPlaying: Bool = false {
        didSet {
            handlePlaybackStateChange()
        }
    }
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String? = nil

    @Published public var zoomLevel: Double = 6.0 {
        didSet {
            let clamped = min(7.0, max(3.0, zoomLevel))
            if zoomLevel != clamped {
                zoomLevel = clamped
            } else {
                prefetchVisibleTiles()
            }
        }
    }

    @Published public var overlayOpacity: Double = 0.75
    @Published public var isSatelliteMode: Bool = false
    @Published public var recenterTrigger: UUID = UUID()

    // MARK: - Private State

    private let service: RainViewerService
    private var playbackTask: Task<Void, Never>?
    private var lastFetchTime: Date?

    // MARK: - Initializer

    public init(location: WeatherLocation, service: RainViewerService = .shared) {
        self.selectedLocation = location
        self.service = service
    }

    deinit {
        playbackTask?.cancel()
    }

    // MARK: - Computed Properties

    public var currentFrame: RadarFrame? {
        guard !frames.isEmpty, currentFrameIndex >= 0, currentFrameIndex < frames.count else {
            return nil
        }
        return frames[currentFrameIndex]
    }

    public var host: String {
        metadata?.host ?? "https://tilecache.rainviewer.com"
    }

    public func tileURLTemplate(for frame: RadarFrame) -> String {
        service.tileURLTemplate(
            host: host,
            frame: frame,
            tileSize: 256,
            colorScheme: .universalBlue,
            smooth: true,
            snow: true
        )
    }

    public var currentTileURLTemplate: String? {
        guard let frame = currentFrame else { return nil }
        return tileURLTemplate(for: frame)
    }

    public var currentSnapshotURL: URL? {
        guard let frame = currentFrame else { return nil }
        return service.coordinateSnapshotURL(
            host: host,
            frame: frame,
            latitude: selectedLocation.latitude,
            longitude: selectedLocation.longitude,
            zoom: Int(zoomLevel.rounded()),
            tileSize: 512,
            colorScheme: .universalBlue,
            smooth: true,
            snow: true
        )
    }

    /// Exact interpolated date when smooth interpolation is active, or nearest frame date
    public var interpolatedDate: Date? {
        guard !frames.isEmpty else { return nil }
        if frames.count == 1 { return frames[0].date }
        let clamped = max(0.0, min(Double(frames.count - 1), animationProgress))
        let lower = Int(floor(clamped))
        let upper = min(frames.count - 1, lower + 1)
        let fraction = clamped - Double(lower)
        let t1 = Double(frames[lower].time)
        let t2 = Double(frames[upper].time)
        let interpolatedTime = t1 + (t2 - t1) * fraction
        return Date(timeIntervalSince1970: interpolatedTime)
    }

    public var isLatestFrame: Bool {
        guard !frames.isEmpty else { return true }
        if isInterpolating && isPlaying {
            return animationProgress >= Double(frames.count - 1) - 0.05
        }
        return currentFrameIndex == frames.count - 1
    }

    public var formattedFrameTime: String {
        guard let date = (isInterpolating ? interpolatedDate : currentFrame?.date) ?? currentFrame?.date else {
            return "--"
        }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    public var frameRelativeText: String {
        guard let date = (isInterpolating ? interpolatedDate : currentFrame?.date) ?? currentFrame?.date else {
            return ""
        }
        let diff = Int(Date().timeIntervalSince(date))
        if diff < 90 && diff > -90 {
            return "Latest"
        }
        if diff < 0 {
            let futureMin = abs(diff) / 60
            return "+\(futureMin)m"
        }
        let minutes = diff / 60
        if minutes < 60 {
            return "-\(minutes)m"
        }
        let hours = minutes / 60
        let remMin = minutes % 60
        if remMin == 0 {
            return "-\(hours)h"
        } else {
            return "-\(hours)h \(remMin)m"
        }
    }

    // MARK: - Actions

    public func updateLocation(_ location: WeatherLocation) {
        if self.selectedLocation.id != location.id ||
            self.selectedLocation.latitude != location.latitude ||
            self.selectedLocation.longitude != location.longitude {
            self.selectedLocation = location
            recenter()
        }
    }

    public func loadRadarData(force: Bool = false) async {
        // Cache metadata for 3 minutes to avoid flooding the free API
        if !force, let last = lastFetchTime, Date().timeIntervalSince(last) < 180, !frames.isEmpty {
            return
        }

        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

        do {
            let meta = try await service.fetchMetadata()
            self.metadata = meta
            let pastFrames = meta.radar.past.sorted { $0.time < $1.time }

            // Default to latest frame before publishing frames to prevent flashing frame 0
            if !pastFrames.isEmpty {
                self.currentFrameIndex = pastFrames.count - 1
                self.animationProgress = Double(pastFrames.count - 1)
            }
            self.frames = pastFrames
            self.lastFetchTime = Date()
            self.errorMessage = nil
            self.prefetchVisibleTiles()
        } catch let serviceError as WeatherServiceError {
            self.errorMessage = serviceError.localizedDescription
        } catch {
            self.errorMessage = "Unable to load radar data: \(error.localizedDescription)"
        }

        self.isLoading = false
    }

    public func togglePlay() {
        isPlaying.toggle()
    }

    public func pause() {
        isPlaying = false
    }

    public func stepForward() {
        pause()
        guard !frames.isEmpty else { return }
        if currentFrameIndex < frames.count - 1 {
            currentFrameIndex += 1
        } else {
            currentFrameIndex = 0
        }
        animationProgress = Double(currentFrameIndex)
    }

    public func stepBackward() {
        pause()
        guard !frames.isEmpty else { return }
        if currentFrameIndex > 0 {
            currentFrameIndex -= 1
        } else {
            currentFrameIndex = frames.count - 1
        }
        animationProgress = Double(currentFrameIndex)
    }

    public func selectFrame(at index: Int) {
        pause()
        guard index >= 0 && index < frames.count else { return }
        currentFrameIndex = index
        animationProgress = Double(index)
    }

    public func jumpToLatest() {
        pause()
        guard !frames.isEmpty else { return }
        currentFrameIndex = frames.count - 1
        animationProgress = Double(frames.count - 1)
    }

    public func zoomIn() {
        if zoomLevel < 7.0 {
            zoomLevel += 1.0
        }
    }

    public func zoomOut() {
        if zoomLevel > 3.0 {
            zoomLevel -= 1.0
        }
    }

    public func toggleSatellite() {
        isSatelliteMode.toggle()
    }

    public func recenter() {
        recenterTrigger = UUID()
    }

    /// Prefetches radar tiles for all loaded frames around the current location and zoom
    public func prefetchVisibleTiles() {
        guard !frames.isEmpty else { return }
        let center = CLLocationCoordinate2D(
            latitude: selectedLocation.latitude,
            longitude: selectedLocation.longitude
        )
        RainViewerTileOverlay.prefetchTiles(
            service: service,
            host: host,
            frames: frames,
            center: center,
            zoom: zoomLevel
        )
    }

    // MARK: - Playback Loop

    private func handlePlaybackStateChange() {
        playbackTask?.cancel()
        playbackTask = nil

        guard isPlaying, frames.count > 1 else { return }

        playbackTask = Task { [weak self] in
            guard let self = self else { return }

            // If starting playback at or near the end of timeline, start from beginning
            if self.animationProgress >= Double(self.frames.count - 1) - 0.05 {
                self.animationProgress = 0.0
                self.currentFrameIndex = 0
                try? await Task.sleep(nanoseconds: 200_000_000)
            }

            while !Task.isCancelled {
                if !self.isInterpolating {
                    // Discrete frame playback
                    try? await Task.sleep(nanoseconds: 850_000_000)
                    guard !Task.isCancelled else { break }

                    if self.currentFrameIndex >= self.frames.count - 1 {
                        try? await Task.sleep(nanoseconds: 1_800_000_000)
                        guard !Task.isCancelled else { break }
                        self.currentFrameIndex = 0
                        self.animationProgress = 0.0
                    } else {
                        self.currentFrameIndex += 1
                        self.animationProgress = Double(self.currentFrameIndex)
                    }
                } else {
                    // Smooth interpolated playback:
                    // 550ms transition between frames (22 sub-steps of 25ms @ 40fps)
                    let currentPos = self.animationProgress
                    let targetIndex = Int(floor(currentPos)) + 1

                    if targetIndex >= self.frames.count {
                        // At the final frame: dwell on latest scan for 1.8s
                        self.animationProgress = Double(self.frames.count - 1)
                        self.currentFrameIndex = self.frames.count - 1
                        try? await Task.sleep(nanoseconds: 1_800_000_000)
                        guard !Task.isCancelled else { break }

                        // Loop back to start
                        self.animationProgress = 0.0
                        self.currentFrameIndex = 0
                        try? await Task.sleep(nanoseconds: 250_000_000)
                        continue
                    }

                    let startProgress = currentPos
                    let endProgress = Double(targetIndex)
                    let distance = endProgress - startProgress
                    let steps = max(6, Int(round(distance * 22.0)))

                    for step in 1...steps {
                        try? await Task.sleep(nanoseconds: 25_000_000)
                        guard !Task.isCancelled else { break }

                        let t = Double(step) / Double(steps)
                        self.animationProgress = startProgress + distance * t
                        self.currentFrameIndex = min(self.frames.count - 1, max(0, Int(round(self.animationProgress))))
                    }

                    guard !Task.isCancelled else { break }
                    self.animationProgress = endProgress
                    self.currentFrameIndex = targetIndex

                    if targetIndex == self.frames.count - 1 {
                        // Reached latest frame: dwell for 1.8s
                        try? await Task.sleep(nanoseconds: 1_800_000_000)
                        guard !Task.isCancelled else { break }
                        self.animationProgress = 0.0
                        self.currentFrameIndex = 0
                        try? await Task.sleep(nanoseconds: 250_000_000)
                    } else {
                        // Brief dwell on intermediate frame for 80ms
                        try? await Task.sleep(nanoseconds: 80_000_000)
                    }
                }
            }
        }
    }
}
