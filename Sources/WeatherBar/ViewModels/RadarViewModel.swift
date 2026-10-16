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
        }
    }

    @Published public var metadata: RainViewerMetadata? = nil
    @Published public var frames: [RadarFrame] = []
    @Published public var currentFrameIndex: Int = 0
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

    public var currentTileURLTemplate: String? {
        guard let frame = currentFrame else { return nil }
        return service.tileURLTemplate(
            host: host,
            frame: frame,
            tileSize: 256,
            colorScheme: .universalBlue,
            smooth: true,
            snow: true
        )
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

    public var isLatestFrame: Bool {
        guard !frames.isEmpty else { return true }
        return currentFrameIndex == frames.count - 1
    }

    public var formattedFrameTime: String {
        guard let frame = currentFrame else { return "--" }
        return frame.formattedTime
    }

    public var frameRelativeText: String {
        guard let frame = currentFrame else { return "" }
        return frame.relativeTimeString()
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
            }
            self.frames = pastFrames
            self.lastFetchTime = Date()
            self.errorMessage = nil
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
    }

    public func stepBackward() {
        pause()
        guard !frames.isEmpty else { return }
        if currentFrameIndex > 0 {
            currentFrameIndex -= 1
        } else {
            currentFrameIndex = frames.count - 1
        }
    }

    public func selectFrame(at index: Int) {
        pause()
        guard index >= 0 && index < frames.count else { return }
        currentFrameIndex = index
    }

    public func jumpToLatest() {
        pause()
        guard !frames.isEmpty else { return }
        currentFrameIndex = frames.count - 1
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

    // MARK: - Playback Loop

    private func handlePlaybackStateChange() {
        playbackTask?.cancel()
        playbackTask = nil

        guard isPlaying, frames.count > 1 else { return }

        playbackTask = Task { [weak self] in
            while !Task.isCancelled {
                // 850ms between frames for comfortable, visible animation
                try? await Task.sleep(nanoseconds: 850_000_000)
                guard !Task.isCancelled, let self = self else { break }

                if self.currentFrameIndex >= self.frames.count - 1 {
                    // Dwell on the latest scan for 1.8 seconds so current clouds remain visible
                    try? await Task.sleep(nanoseconds: 1_800_000_000)
                    guard !Task.isCancelled else { break }
                    self.currentFrameIndex = 0
                } else {
                    self.currentFrameIndex += 1
                }
            }
        }
    }
}
