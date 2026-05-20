import Foundation

@MainActor
@Observable
final class SpotifySettings {
    private static let alwaysShowIconKey = "com.statusbar.spotify.alwaysShowIcon"
    private static let showTrackNameKey = "com.statusbar.spotify.showTrackName"
    private static let showWaveformKey = "com.statusbar.spotify.showWaveform"
    private static let artworkColorEnabledKey = "com.statusbar.spotify.artworkColorEnabled"
    private static let artworkColorOpacityKey = "com.statusbar.spotify.artworkColorOpacity"

    var alwaysShowIcon: Bool {
        didSet { UserDefaults.standard.set(alwaysShowIcon, forKey: Self.alwaysShowIconKey) }
    }

    var showTrackName: Bool {
        didSet { UserDefaults.standard.set(showTrackName, forKey: Self.showTrackNameKey) }
    }

    var showWaveform: Bool {
        didSet { UserDefaults.standard.set(showWaveform, forKey: Self.showWaveformKey) }
    }

    var artworkColorEnabled: Bool {
        didSet { UserDefaults.standard.set(artworkColorEnabled, forKey: Self.artworkColorEnabledKey) }
    }

    var artworkColorOpacity: Double {
        didSet { UserDefaults.standard.set(artworkColorOpacity, forKey: Self.artworkColorOpacityKey) }
    }

    init() {
        UserDefaults.standard.register(defaults: [
            Self.showWaveformKey: true,
            Self.artworkColorEnabledKey: true,
            Self.artworkColorOpacityKey: 0.35,
        ])
        alwaysShowIcon = UserDefaults.standard.bool(forKey: Self.alwaysShowIconKey)
        showTrackName = UserDefaults.standard.bool(forKey: Self.showTrackNameKey)
        showWaveform = UserDefaults.standard.bool(forKey: Self.showWaveformKey)
        artworkColorEnabled = UserDefaults.standard.bool(forKey: Self.artworkColorEnabledKey)
        artworkColorOpacity = UserDefaults.standard.double(forKey: Self.artworkColorOpacityKey)
    }
}
