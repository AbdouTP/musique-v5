import Foundation

/// Télécharge un titre de musique libre et l'ajoute à la bibliothèque (lisible ensuite hors connexion).
@MainActor
final class OnlineDownloader: ObservableObject {
    enum State: Equatable {
        case downloading
        case done
        case failed(String)
    }

    @Published private(set) var states: [String: State] = [:]

    private let library: LibraryStore

    init(library: LibraryStore) {
        self.library = library
    }

    func state(for track: OnlineTrack) -> State? {
        if let state = states[track.id] { return state }
        if library.tracks.contains(where: { $0.sourceID == track.id }) { return .done }
        return nil
    }

    func download(_ online: OnlineTrack) async {
        if case .downloading = states[online.id] { return }
        if state(for: online) == .done { return }
        states[online.id] = .downloading

        let temporary = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".mp3")
        defer { try? FileManager.default.removeItem(at: temporary) }

        do {
            let (downloaded, response) = try await URLSession.shared.download(from: online.downloadURL)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                try? FileManager.default.removeItem(at: downloaded)
                throw CatalogError.badResponse
            }
            try FileManager.default.moveItem(at: downloaded, to: temporary)

            let outcome = try await ImportPipeline.ingest(url: temporary, knownHashes: library.knownHashes)
            switch outcome {
            case .duplicate:
                states[online.id] = .done
            case .imported(var track):
                track.title = online.title
                track.artist = online.artist
                track.album = online.album.isEmpty ? Track.unknownAlbum : online.album
                track.sourceID = online.id

                if !track.hasArtwork, let artworkURL = online.artworkURL,
                   let (data, _) = try? await URLSession.shared.data(from: artworkURL),
                   let jpeg = ImageProcessing.jpegData(from: data),
                   (try? jpeg.write(to: Storage.artworkURL(key: track.id.uuidString), options: .atomic)) != nil {
                    track.hasArtwork = true
                }

                library.add([track])
                states[online.id] = .done
            }
        } catch {
            states[online.id] = .failed(NetworkErrorText.message(for: error))
        }
    }
}
