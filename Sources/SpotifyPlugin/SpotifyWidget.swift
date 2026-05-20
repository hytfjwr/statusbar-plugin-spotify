import StatusBarKit
import SwiftUI

// MARK: - SpotifyWidget

@MainActor
@Observable
public final class SpotifyWidget: StatusBarWidget {
    public let id = "spotify"
    public let position: WidgetPosition = .center
    public let updateInterval: TimeInterval? = nil
    public var sfSymbolName: String { "music.note" }
    public var preferredSettingsSize: CGSize? { CGSize(width: 300, height: 300) }

    private let service = SpotifyService()
    private let settings = SpotifySettings()
    private let colorStore = ArtworkColorStore()
    private var popupPanel: PopupPanel?

    public init() {}

    public func start() {
        service.start()
    }

    public func stop() {
        service.stop()
        popupPanel?.hidePopup()
        colorStore.reset()
    }

    private var trackVisible: Bool {
        settings.showTrackName && service.isPlaying && !service.trackName.isEmpty
    }

    private var waveformVisible: Bool {
        settings.showWaveform && service.isPlaying
    }

    @ViewBuilder
    public func body() -> some View {
        if settings.alwaysShowIcon || service.isPlaying {
            HStack(spacing: 0) {
                AppIconView(appName: "Spotify", size: 18)
                WaveformView(isPlaying: waveformVisible)
                    .frame(width: waveformVisible ? 18 : 0, height: 14)
                    .padding(.leading, waveformVisible ? 4 : 0)
                    .opacity(waveformVisible ? 1 : 0)
                    .clipped()
                Text(service.trackName)
                    .font(.system(size: 12))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .frame(maxWidth: trackVisible ? 150 : 0, alignment: .leading)
                    .padding(.leading, trackVisible ? 4 : 0)
                    .clipped()
                    .opacity(trackVisible ? 1 : 0)
            }
            .fixedSize()
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(.black.opacity(0.15))
            )
            .animation(.easeInOut(duration: 0.25), value: waveformVisible)
            .animation(.easeInOut(duration: 0.25), value: trackVisible)
            .animation(.easeInOut(duration: 0.25), value: service.trackName)
            .contentShape(Rectangle())
            .onTapGesture { [weak self] in
                self?.togglePopup()
            }
        }
    }

    @ViewBuilder
    public func settingsBody() -> some View {
        Form {
            Toggle("Always show icon", isOn: Bindable(settings).alwaysShowIcon)
                .help("When off, the icon is only visible during playback")
            Toggle("Show track name", isOn: Bindable(settings).showTrackName)
                .help("Display the current track name next to the icon")
            Toggle("Show waveform", isOn: Bindable(settings).showWaveform)
                .help("Display an animated waveform next to the icon while playing")
            Section("Background") {
                Toggle("Album art color", isOn: Bindable(settings).artworkColorEnabled)
                    .help("Tint the popup background with the album artwork's dominant color")
                if settings.artworkColorEnabled {
                    HStack {
                        Text("Opacity")
                        Slider(value: Bindable(settings).artworkColorOpacity, in: 0...1)
                        Text("\(Int(settings.artworkColorOpacity * 100))%")
                            .monospacedDigit()
                            .frame(width: 36, alignment: .trailing)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private func togglePopup() {
        if popupPanel?.isVisible == true {
            popupPanel?.hidePopup()
        } else {
            showPopup()
        }
    }

    private func showPopup() {
        if popupPanel == nil {
            let panel = PopupPanel(contentRect: NSRect(x: 0, y: 0, width: 300, height: 340))
            panel.onHide = { [weak self] in
                self?.service.stopPositionPolling()
            }
            popupPanel = panel
        }

        guard let (barFrame, screen) = PopupPanel.barTriggerFrame(width: 100) else {
            return
        }

        service.fetchTrackInfo()
        service.startPositionPolling()

        let content = SpotifyPopupContent(service: service, settings: settings, colorStore: colorStore)
        popupPanel?.showPopup(relativeTo: barFrame, on: screen, content: content)
    }
}

// MARK: - SpotifyPopupContent

private struct SpotifyPopupContent: View {
    let service: SpotifyService
    let settings: SpotifySettings
    let colorStore: ArtworkColorStore

    private let artworkSize: CGFloat = 220
    private let popupWidth: CGFloat = 300

    var body: some View {
        VStack(spacing: 0) {
            // Album artwork — large, centered, with subtle shadow
            artworkView
                .frame(width: artworkSize, height: artworkSize)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                .padding(.top, 20)
                .padding(.bottom, 16)

            // Track info — centered
            VStack(spacing: 4) {
                Text(service.trackName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(service.artistName)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 20)

            // Seek bar (interactive)
            if service.duration > 0 {
                VStack(spacing: 4) {
                    Slider(
                        value: Binding(
                            get: { service.position },
                            set: { service.seekTo(position: $0) }
                        ),
                        in: 0...service.duration
                    )
                    .tint(.white)
                    .focusable(false)

                    HStack {
                        Text(formatTime(service.position))
                        Spacer()
                        Text(formatTime(service.duration))
                    }
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
            }

            // Playback controls — unified glass capsule
            HStack(spacing: 16) {
                toggleButton("shuffle", size: 14, isActive: service.isShuffling) { service.toggleShuffle() }
                controlButton("backward.fill", size: 18) { service.previousTrack() }
                // Play/Pause — prominent
                Button { service.playPause() } label: {
                    Image(systemName: service.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(.primary)
                        .frame(width: 48, height: 48)
                        .glassEffect(.regular.interactive(), in: .circle)
                }
                .buttonStyle(ScalePressStyle())
                controlButton("forward.fill", size: 18) { service.nextTrack() }
                toggleButton("repeat", size: 14, isActive: service.isRepeating) { service.toggleRepeat() }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .glassEffect(.regular, in: .capsule)
            .padding(.top, 12)
            .padding(.bottom, 20)
        }
        .frame(width: popupWidth)
        .background {
            (colorStore.dominantColor ?? .clear)
                .opacity(settings.artworkColorEnabled ? settings.artworkColorOpacity : 0)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .animation(.easeInOut(duration: 1.5), value: colorStore.dominantColor)
                .animation(.easeInOut(duration: 0.5), value: settings.artworkColorEnabled)
        }
        .onChange(of: service.artworkURL) { _, _ in syncColor() }
        .onChange(of: settings.artworkColorEnabled) { _, _ in syncColor() }
        .onAppear { syncColor() }
    }

    private func syncColor() {
        if settings.artworkColorEnabled {
            colorStore.update(artworkURL: service.artworkURL)
        } else {
            colorStore.reset()
        }
    }

    @ViewBuilder
    private var artworkView: some View {
        if let url = service.artworkURL {
            AsyncImage(url: url) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                artworkPlaceholder
            }
        } else {
            artworkPlaceholder
        }
    }

    private var artworkPlaceholder: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(.quaternary)
            .overlay(
                Image(systemName: "music.note")
                    .font(.system(size: 40))
                    .foregroundStyle(.tertiary)
            )
    }

    private func controlButton(_ systemName: String, size: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size))
                .foregroundStyle(.primary)
                .frame(width: 40, height: 40)
                .glassEffect(.regular.interactive(), in: .circle)
        }
        .buttonStyle(ScalePressStyle())
    }

    private func toggleButton(_ systemName: String, size: CGFloat, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size))
                .foregroundStyle(isActive ? Color.green : .secondary)
                .frame(width: 40, height: 40)
                .glassEffect(.regular.interactive(), in: .circle)
                .overlay(alignment: .bottom) {
                    if isActive {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 4, height: 4)
                            .offset(y: -6)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: isActive)
        }
        .buttonStyle(ScalePressStyle())
    }

    private func formatTime(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - WaveformView

private struct WaveformView: View {
    let isPlaying: Bool

    private let barCount = 5
    private let barWidth: CGFloat = 2
    private let spacing: CGFloat = 2
    private let minHeight: CGFloat = 3
    private let maxHeight: CGFloat = 14

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !isPlaying)) { timeline in
            HStack(alignment: .center, spacing: spacing) {
                ForEach(0..<barCount, id: \.self) { index in
                    Capsule(style: .continuous)
                        .fill(.primary)
                        .frame(width: barWidth, height: barHeight(for: index, at: timeline.date))
                }
            }
            .frame(maxHeight: maxHeight)
        }
    }

    private func barHeight(for index: Int, at date: Date) -> CGFloat {
        let t = date.timeIntervalSinceReferenceDate

        // Each bar walks between random target heights at its own tempo,
        // smoothed for organic motion.
        let rate = 5.5 + Double(index) * 0.9
        let tickFloat = t * rate
        let tick = floor(tickFloat)
        let frac = tickFloat - tick
        let v0 = Self.hash(Double(index) * 31.7 + tick)
        let v1 = Self.hash(Double(index) * 31.7 + tick + 1)
        let smoothed = frac * frac * (3 - 2 * frac)
        let primary = v0 * (1 - smoothed) + v1 * smoothed

        // Slow global "breath" — overall amplitude swells in and out.
        let breath = 0.5 + 0.5 * sin(t * 0.7 + Double(index) * 0.2)

        // Off-beat global pulse with slight period jitter per bar so it never
        // looks perfectly synchronized.
        let beatPeriod = 1.18 + Self.hash(Double(index) * 5.3) * 0.25
        let beatPhase = (t / beatPeriod).truncatingRemainder(dividingBy: 1)
        let beat = pow(max(0, 1 - beatPhase * 4.0), 2.2) * 0.45

        // Bass weighting — leftmost bars feel the beat more.
        let bassWeight = 1.0 - Double(index) / Double(max(barCount - 1, 1)) * 0.65

        // Occasional fast jitter — high-frequency wobble for liveliness.
        let jitter = sin(t * (17.0 + Double(index) * 2.1) + Double(index)) * 0.08

        let raw = primary * (0.55 + breath * 0.4) + beat * bassWeight + jitter
        let value = max(0.08, min(1, raw))
        return minHeight + CGFloat(value) * (maxHeight - minHeight)
    }

    private static func hash(_ seed: Double) -> Double {
        var x = sin(seed * 12.9898 + 78.233) * 43758.5453
        x -= floor(x)
        return x
    }
}

// MARK: - ScalePressStyle

private struct ScalePressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.85 : 1.0)
            .animation(.spring(duration: 0.2, bounce: 0.4), value: configuration.isPressed)
    }
}
