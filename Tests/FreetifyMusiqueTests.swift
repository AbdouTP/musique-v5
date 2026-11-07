import XCTest
@testable import FreetifyMusique

private func makeTrack(
    _ title: String,
    artist: String = "Artiste",
    album: String = "Album",
    added: TimeInterval = 0,
    fileName: String? = nil
) -> Track {
    let id = UUID()
    return Track(
        id: id,
        title: title,
        artist: artist,
        album: album,
        duration: 180,
        fileName: fileName ?? "\(id.uuidString).mp3",
        hasArtwork: false,
        contentHash: UUID().uuidString,
        dateAdded: Date(timeIntervalSince1970: added)
    )
}

// MARK: - Albums / artistes

final class LibraryIndexTests: XCTestCase {
    func testGroupsTracksByAlbumAndArtist() {
        let tracks = [
            makeTrack("A", artist: "Daft Punk", album: "Discovery"),
            makeTrack("B", artist: "Daft Punk", album: "Discovery"),
            makeTrack("C", artist: "Daft Punk", album: "Homework"),
            makeTrack("D", artist: "Justice", album: "Cross")
        ]
        let albums = LibraryIndex.albums(from: tracks)
        XCTAssertEqual(albums.count, 3)
        XCTAssertEqual(albums.first(where: { $0.title == "Discovery" })?.tracks.count, 2)

        let artists = LibraryIndex.artists(from: tracks)
        XCTAssertEqual(artists.count, 2)
        XCTAssertEqual(artists.first(where: { $0.name == "Daft Punk" })?.albumCount, 2)
    }

    func testUnknownAlbumsAreSeparatedByArtist() {
        let tracks = [
            makeTrack("A", artist: "X", album: Track.unknownAlbum),
            makeTrack("B", artist: "Y", album: Track.unknownAlbum)
        ]
        XCTAssertEqual(LibraryIndex.albums(from: tracks).count, 2)
    }

    func testGroupingIgnoresCaseAndAccents() {
        let tracks = [
            makeTrack("A", artist: "Édith Piaf", album: "La Vie en rose"),
            makeTrack("B", artist: "edith piaf", album: "la vie en rose")
        ]
        XCTAssertEqual(LibraryIndex.artists(from: tracks).count, 1)
        XCTAssertEqual(LibraryIndex.albums(from: tracks).count, 1)
    }
}

// MARK: - Recherche

final class SearchServiceTests: XCTestCase {
    private func search(_ query: String, in tracks: [Track]) -> SearchResults {
        SearchService.search(
            query,
            tracks: tracks,
            albums: LibraryIndex.albums(from: tracks),
            artists: LibraryIndex.artists(from: tracks),
            playlists: []
        )
    }

    func testEmptyQueryReturnsNothing() {
        XCTAssertTrue(search("   ", in: [makeTrack("Hello")]).isEmpty)
    }

    func testIsCaseAndAccentInsensitive() {
        let tracks = [makeTrack("Été", artist: "Zaz")]
        XCTAssertEqual(search("ete", in: tracks).tracks.count, 1)
        XCTAssertEqual(search("ZAZ", in: tracks).artists.count, 1)
    }

    func testAllTokensMustMatch() {
        let tracks = [
            makeTrack("Alpha", artist: "One"),
            makeTrack("Alpha", artist: "Two")
        ]
        XCTAssertEqual(search("alpha two", in: tracks).tracks.count, 1)
    }

    func testFindsAlbumsAndPlaylists() {
        let tracks = [makeTrack("T", artist: "A", album: "Mon Album")]
        let playlist = Playlist(id: UUID(), name: "Ma Playlist", trackIDs: [], createdAt: Date(), isFavorite: false, coverFile: nil)
        let results = SearchService.search(
            "mon",
            tracks: tracks,
            albums: LibraryIndex.albums(from: tracks),
            artists: LibraryIndex.artists(from: tracks),
            playlists: [playlist]
        )
        XCTAssertEqual(results.albums.count, 1)
        XCTAssertEqual(SearchService.search("playlist", tracks: [], albums: [], artists: [], playlists: [playlist]).playlists.count, 1)
    }
}

// MARK: - Recommandations

final class RecommenderTests: XCTestCase {
    func testEmptyLibraryGivesNoRecommendation() {
        XCTAssertTrue(Recommender.recommendations(tracks: [], history: [], favoriteIDs: []).isEmpty)
    }

    func testPrefersFavoriteArtistsAndSkipsRecentlyPlayed() {
        let liked1 = makeTrack("L1", artist: "Liked")
        let liked2 = makeTrack("L2", artist: "Liked")
        let other = makeTrack("O1", artist: "Other")
        let history = [
            HistoryEntry(id: UUID(), trackID: liked1.id, playedAt: Date())
        ]
        let result = Recommender.recommendations(
            tracks: [liked1, liked2, other],
            history: history,
            favoriteIDs: [liked1.id]
        )
        XCTAssertFalse(result.contains(where: { $0.id == liked1.id }), "Une musique écoutée à l'instant n'est pas recommandée")
        XCTAssertEqual(result.first?.id, liked2.id)
    }
}

// MARK: - Divers

final class HelpersTests: XCTestCase {
    func testClockString() {
        XCTAssertEqual(0.0.clockString, "0:00")
        XCTAssertEqual(65.0.clockString, "1:05")
        XCTAssertEqual(3725.0.clockString, "1:02:05")
        XCTAssertEqual(Double.nan.clockString, "0:00")
    }

    func testFilenameParser() {
        let both = FilenameParser.parse("Daft Punk - One More Time")
        XCTAssertEqual(both.artist, "Daft Punk")
        XCTAssertEqual(both.title, "One More Time")

        let titleOnly = FilenameParser.parse("Ma_chanson")
        XCTAssertNil(titleOnly.artist)
        XCTAssertEqual(titleOnly.title, "Ma chanson")
    }

    func testSHA256IsDeterministic() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let a = dir.appendingPathComponent("a.bin")
        let b = dir.appendingPathComponent("b.bin")
        try Data("freetify".utf8).write(to: a)
        try Data("freetify".utf8).write(to: b)

        XCTAssertEqual(try ImportPipeline.sha256(of: a), try ImportPipeline.sha256(of: b))
        XCTAssertEqual(
            try ImportPipeline.sha256(of: a),
            "85f86ed36791e36dc364e964a59f409a0d9bdff17b1634bdb8a1e56d8cd090f8"
        )
    }

    func testImportReport() {
        let message = ImportService.makeReport(imported: 2, duplicates: 1, failures: ["x.mp3 : illisible"])
        XCTAssertTrue(message.contains("2 musique(s) importée(s)"))
        XCTAssertTrue(message.contains("1 doublon(s)"))
        XCTAssertTrue(message.contains("x.mp3"))
    }
}

// MARK: - File d'attente

final class PlayQueueTests: XCTestCase {
    private func tracks(_ n: Int) -> [Track] {
        (0..<n).map { makeTrack("T\($0)") }
    }

    func testSetStartsAtRequestedIndex() {
        var queue = PlayQueue()
        let list = tracks(5)
        queue.set(tracks: list, startAt: 2, shuffled: false)
        XCTAssertEqual(queue.current?.track.id, list[2].id)
        XCTAssertEqual(queue.upcoming.count, 2)
        XCTAssertEqual(queue.history.count, 2)
    }

    func testAdvanceAndWrap() {
        var queue = PlayQueue()
        let list = tracks(2)
        queue.set(tracks: list, startAt: 1, shuffled: false)
        XCTAssertFalse(queue.advance(wrap: false))
        XCTAssertTrue(queue.advance(wrap: true))
        XCTAssertEqual(queue.current?.track.id, list[0].id)
        XCTAssertFalse(queue.goBack(wrap: false))
        XCTAssertTrue(queue.goBack(wrap: true))
        XCTAssertEqual(queue.current?.track.id, list[1].id)
    }

    func testShuffleKeepsCurrentFirstAndSameTracks() {
        var queue = PlayQueue()
        let list = tracks(20)
        queue.set(tracks: list, startAt: 7, shuffled: true)
        XCTAssertEqual(queue.currentIndex, 0)
        XCTAssertEqual(queue.current?.track.id, list[7].id)
        XCTAssertEqual(Set(queue.items.map(\.track.id)), Set(list.map(\.id)))
    }

    func testToggleShuffleRestoresOriginalOrder() {
        var queue = PlayQueue()
        let list = tracks(10)
        queue.set(tracks: list, startAt: 3, shuffled: false)
        queue.toggleShuffle()
        XCTAssertTrue(queue.isShuffled)
        XCTAssertEqual(queue.current?.track.id, list[3].id)
        queue.toggleShuffle()
        XCTAssertFalse(queue.isShuffled)
        XCTAssertEqual(queue.items.map(\.track.id), list.map(\.id))
        XCTAssertEqual(queue.current?.track.id, list[3].id)
    }

    func testPlayNextAndAppend() {
        var queue = PlayQueue()
        let list = tracks(3)
        queue.set(tracks: list, startAt: 0, shuffled: false)
        let inserted = makeTrack("Inserted")
        let appended = makeTrack("Appended")
        queue.playNext(inserted)
        queue.append(appended)
        XCTAssertEqual(queue.upcoming.first?.track.id, inserted.id)
        XCTAssertEqual(queue.upcoming.last?.track.id, appended.id)
    }

    func testRemoveUpcomingAdjustsIndex() {
        var queue = PlayQueue()
        let list = tracks(4)
        queue.set(tracks: list, startAt: 1, shuffled: false)
        let toRemove = queue.upcoming[0]
        queue.remove(id: toRemove.id)
        XCTAssertEqual(queue.current?.track.id, list[1].id)
        XCTAssertEqual(queue.upcoming.count, 1)
        // La musique en cours ne peut pas être retirée par `remove`.
        queue.remove(id: queue.current!.id)
        XCTAssertEqual(queue.current?.track.id, list[1].id)
    }

    func testMoveUpcoming() {
        var queue = PlayQueue()
        let list = tracks(4)
        queue.set(tracks: list, startAt: 0, shuffled: false)
        queue.moveUpcoming(from: IndexSet(integer: 0), to: 2)
        XCTAssertEqual(queue.upcoming.map(\.track.id), [list[2].id, list[1].id, list[3].id])
        XCTAssertEqual(queue.current?.track.id, list[0].id)
    }

    func testRemoveTracksIncludingCurrent() {
        var queue = PlayQueue()
        let list = tracks(4)
        queue.set(tracks: list, startAt: 1, shuffled: false)
        let removedCurrent = queue.removeTracks([list[1].id, list[3].id])
        XCTAssertTrue(removedCurrent)
        XCTAssertEqual(queue.items.count, 2)
        XCTAssertEqual(queue.current?.track.id, list[2].id)

        let removedAll = queue.removeTracks([list[0].id, list[2].id])
        XCTAssertTrue(removedAll || queue.items.isEmpty)
        XCTAssertNil(queue.current)
    }

    func testClearUpcoming() {
        var queue = PlayQueue()
        queue.set(tracks: tracks(5), startAt: 1, shuffled: false)
        queue.clearUpcoming()
        XCTAssertTrue(queue.upcoming.isEmpty)
        XCTAssertNotNil(queue.current)
    }

    func testRepeatModeCycle() {
        XCTAssertEqual(RepeatMode.off.next, .all)
        XCTAssertEqual(RepeatMode.all.next, .one)
        XCTAssertEqual(RepeatMode.one.next, .off)
    }
}

// MARK: - Bibliothèque persistante

@MainActor
final class LibraryStoreTests: XCTestCase {
    private var root: URL!

    override func setUp() async throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("freetify-tests-\(UUID().uuidString)")
        Storage.customRoot = root
        try Storage.prepare()
    }

    override func tearDown() async throws {
        Storage.customRoot = nil
        try? FileManager.default.removeItem(at: root)
    }

    /// Crée une musique dont le fichier existe réellement dans le stockage de test.
    private func addTrack(_ store: LibraryStore, _ title: String, artist: String = "Artiste") throws -> Track {
        let track = makeTrack(title, artist: artist)
        try Data("audio".utf8).write(to: track.fileURL)
        store.add([track])
        return track
    }

    func testFavoritesPlaylistsAndHistoryPersistAcrossRestart() throws {
        let store = LibraryStore()
        let a = try addTrack(store, "A")
        let b = try addTrack(store, "B")
        store.toggleFavorite(a.id)
        let playlist = store.createPlaylist(name: "Ma liste", trackIDs: [a.id, b.id])
        store.recordPlay(b.id)
        store.flush()

        let reloaded = LibraryStore()
        XCTAssertEqual(reloaded.tracks.count, 2)
        XCTAssertTrue(reloaded.isFavorite(a.id))
        XCTAssertEqual(reloaded.playlist(withID: playlist.id)?.name, "Ma liste")
        XCTAssertEqual(reloaded.playlist(withID: playlist.id)?.trackIDs, [a.id, b.id])
        XCTAssertEqual(reloaded.history.first?.trackID, b.id)
    }

    func testPlaylistOperations() throws {
        let store = LibraryStore()
        let a = try addTrack(store, "A")
        let b = try addTrack(store, "B")
        let c = try addTrack(store, "C")
        let playlist = store.createPlaylist(name: "  ")
        XCTAssertFalse(playlist.name.isEmpty)

        XCTAssertEqual(store.add([a.id, b.id, a.id], to: playlist.id), 2, "Pas de doublon dans une playlist")
        store.add([c.id], to: playlist.id)
        store.moveTracks(from: IndexSet(integer: 2), to: 0, in: playlist.id)
        XCTAssertEqual(store.playlist(withID: playlist.id)?.trackIDs, [c.id, a.id, b.id])

        store.removeTracks(atOffsets: IndexSet(integer: 0), from: playlist.id)
        XCTAssertEqual(store.playlist(withID: playlist.id)?.trackIDs, [a.id, b.id])

        store.renamePlaylist(playlist.id, to: "Renommée")
        XCTAssertEqual(store.playlist(withID: playlist.id)?.name, "Renommée")

        store.deletePlaylist(playlist.id)
        XCTAssertNil(store.playlist(withID: playlist.id))
    }

    func testDeletingTrackCleansEverything() throws {
        let store = LibraryStore()
        let a = try addTrack(store, "A")
        let playlist = store.createPlaylist(name: "P", trackIDs: [a.id])
        store.toggleFavorite(a.id)
        store.recordPlay(a.id)

        var notified: Set<UUID> = []
        store.onTracksDeleted = { notified = $0 }
        store.deleteTracks([a.id])

        XCTAssertEqual(notified, [a.id])
        XCTAssertTrue(store.tracks.isEmpty)
        XCTAssertTrue(store.favoriteIDs.isEmpty)
        XCTAssertTrue(store.history.isEmpty)
        XCTAssertEqual(store.playlist(withID: playlist.id)?.trackIDs, [])
        XCTAssertTrue(store.albums.isEmpty)
    }

    func testMissingFilesAreDroppedAtLoad() throws {
        let store = LibraryStore()
        let a = try addTrack(store, "A")
        store.flush()
        try FileManager.default.removeItem(at: a.fileURL)

        let reloaded = LibraryStore()
        XCTAssertTrue(reloaded.tracks.isEmpty)
    }

    func testRecentlyPlayedHasNoDuplicates() throws {
        let store = LibraryStore()
        let a = try addTrack(store, "A")
        let b = try addTrack(store, "B")
        store.recordPlay(a.id)
        store.recordPlay(b.id)
        store.recordPlay(a.id)
        XCTAssertEqual(store.recentlyPlayed().map(\.id), [a.id, b.id])
    }

    func testResetLibrary() throws {
        let store = LibraryStore()
        let a = try addTrack(store, "A")
        store.createPlaylist(name: "P", trackIDs: [a.id])
        store.resetLibrary()
        XCTAssertTrue(store.tracks.isEmpty)
        XCTAssertTrue(store.playlists.isEmpty)
        XCTAssertTrue(store.history.isEmpty)
    }
}

// MARK: - Correspondance Apple Music

final class TrackMatcherTests: XCTestCase {
    func testMatchesIgnoringCaseAccentsAndSmallDurationGap() {
        let track = makeTrack("Été Indien", artist: "Joe Dassin")
        let found = TrackMatcher.match(title: "ete indien", artist: "JOE DASSIN", duration: 181.5, in: [track])
        XCTAssertEqual(found?.id, track.id)
    }

    func testRejectsDifferentArtistOrDuration() {
        let track = makeTrack("Intro", artist: "A")
        XCTAssertNil(TrackMatcher.match(title: "Intro", artist: "B", duration: 180, in: [track]))
        XCTAssertNil(TrackMatcher.match(title: "Intro", artist: "A", duration: 400, in: [track]))
    }

    func testUnknownArtistMatchesByTitle() {
        let track = makeTrack("Solo", artist: Track.unknownArtist)
        XCTAssertNotNil(TrackMatcher.match(title: "Solo", artist: "Quelqu'un", duration: 0, in: [track]))
    }
}

// MARK: - Catalogue en ligne (Jamendo)

final class JamendoParserTests: XCTestCase {
    private let sample = """
    {
      "headers": {"status": "success", "code": 0, "results_count": 3},
      "results": [
        {"id": "1001", "name": "Premier titre", "duration": 215, "artist_name": "Artiste A",
         "album_name": "Album A", "license_ccurl": "http://creativecommons.org/licenses/by-nc-sa/3.0/",
         "album_image": "http://images.jamendo.com/a.jpg", "audiodownload": "http://prod.jamendo.com/download/1001",
         "audiodownload_allowed": true, "shareurl": "https://www.jamendo.com/track/1001"},
        {"id": 1002, "name": "Interdit", "duration": 100, "artist_name": "B",
         "audiodownload": "https://prod.jamendo.com/download/1002", "audiodownload_allowed": false},
        {"id": "1003", "name": "Sans lien", "duration": 90, "artist_name": "C", "audiodownload_allowed": true}
      ]
    }
    """

    func testParsesDownloadableTracksOnly() throws {
        let tracks = try JamendoParser.parse(Data(sample.utf8))
        XCTAssertEqual(tracks.count, 1)
        let track = try XCTUnwrap(tracks.first)
        XCTAssertEqual(track.id, "jamendo:1001")
        XCTAssertEqual(track.title, "Premier titre")
        XCTAssertEqual(track.duration, 215)
        XCTAssertEqual(track.licenseLabel, "CC BY-NC-SA 3.0")
        XCTAssertEqual(track.downloadURL.scheme, "https", "Le HTTP est converti en HTTPS")
        XCTAssertEqual(track.artworkURL?.scheme, "https")
    }

    func testFailedStatusThrows() {
        let json = #"{"headers": {"status": "failed", "code": 5, "error_message": "clé invalide"}, "results": []}"#
        XCTAssertThrowsError(try JamendoParser.parse(Data(json.utf8)))
    }

    func testLicenseLabel() {
        XCTAssertEqual(JamendoParser.licenseLabel(from: "https://creativecommons.org/licenses/by/4.0/"), "CC BY 4.0")
        XCTAssertNil(JamendoParser.licenseLabel(from: nil))
        XCTAssertNil(JamendoParser.licenseLabel(from: "https://example.com"))
    }
}

// MARK: - Apple Music (MusicKit) : parties pures, sans réseau

final class AppleMusicHelpersTests: XCTestCase {
    func testSearchTermNormalization() {
        XCTAssertEqual(AppleSearchTerm.normalized("  daft   punk \n"), "daft punk")
        XCTAssertEqual(AppleSearchTerm.normalized("   "), "")
    }

    func testEmptyResults() {
        XCTAssertTrue(AppleSearchResults().isEmpty)
    }

    func testNetworkErrorMessageIsExplicit() {
        let message = AppleMusicError.message(for: URLError(.notConnectedToInternet))
        XCTAssertTrue(message.contains("connexion"))
    }
}
