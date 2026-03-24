import AppKit
import SwiftUI

@MainActor
@Observable
final class ArtworkColorStore {
    private(set) var dominantColor: Color?

    private let extractor = ArtworkColorExtractor()
    private var fetchTask: Task<Void, Never>?
    private var lastURL: URL?

    func update(artworkURL: URL?) {
        guard let url = artworkURL else {
            reset()
            return
        }

        guard url != lastURL else { return }
        lastURL = url

        fetchTask?.cancel()
        fetchTask = Task {
            let cacheKey = url.absoluteString
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard !Task.isCancelled else { return }

                guard let nsImage = NSImage(data: data) else { return }

                let color = await extractor.dominantColor(for: nsImage, cacheKey: cacheKey)
                guard !Task.isCancelled else { return }

                dominantColor = color
            } catch {
                guard !Task.isCancelled else { return }
                // Leave previous color on failure
            }
        }
    }

    func reset() {
        fetchTask?.cancel()
        fetchTask = nil
        lastURL = nil
        dominantColor = nil
    }
}
