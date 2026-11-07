import Foundation
import MusicKit

/// Résultats d'une recherche dans le catalogue Apple Music.
struct AppleSearchResults {
    var songs: [Song] = []
    var artists: [Artist] = []
    var albums: [Album] = []

    var isEmpty: Bool { songs.isEmpty && artists.isEmpty && albums.isEmpty }
}

/// Sélection du moment, lue dans les classements réels d'Apple Music.
struct AppleChartsContent {
    var songs: [Song] = []
    var albums: [Album] = []
}

enum AppleSubscriptionState: Equatable {
    case unknown
    case active
    case inactive(canSubscribe: Bool)
}

enum AppleMusicError {
    static let tokenMessage = "Apple Music n'est pas disponible pour cette installation : le service MusicKit doit être activé sur l'identifiant d'app com.abdoutp.freetifymusique (compte Apple Developer payant) et l'app doit être signée avec cet identifiant."

    static func message(for error: Error) -> String {
        if error is MusicTokenRequestError {
            return tokenMessage
        }
        if error is URLError {
            return NetworkErrorText.message(for: error)
        }
        let text = error.localizedDescription
        if text.localizedCaseInsensitiveContains("developer token") || text.localizedCaseInsensitiveContains("token request") {
            return tokenMessage
        }
        return text
    }
}

enum AppleSearchTerm {
    /// Terme nettoyé : sans espaces superflus (début, fin, doublons).
    static func normalized(_ raw: String) -> String {
        raw.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}

/// Accès au catalogue Apple Music (MusicKit) : autorisation, abonnement, recherche, suggestions, classements.
/// La lecture est dans `AppleMusicPlayer`, la bibliothèque locale n'est jamais touchée ici.
@MainActor
final class AppleMusicService: ObservableObject {
    @Published private(set) var authorization: MusicAuthorization.Status = MusicAuthorization.currentStatus
    @Published private(set) var subscription: AppleSubscriptionState = .unknown

    @Published private(set) var results = AppleSearchResults()
    @Published private(set) var isSearching = false
    @Published private(set) var searchError: String?
    @Published private(set) var suggestions: [String] = []

    @Published private(set) var charts: AppleChartsContent?
    @Published private(set) var isLoadingCharts = false
    @Published private(set) var chartsError: String?

    // Caches : évitent de refaire les mêmes appels réseau.
    private var searchCache: [String: AppleSearchResults] = [:]
    private var suggestionCache: [String: [String]] = [:]
    private var albumSongsCache: [MusicItemID: [Song]] = [:]
    private var artistCache: [MusicItemID: (songs: [Song], albums: [Album])] = [:]
    private let cacheLimit = 40

    private var searchGeneration = 0
    private var suggestionGeneration = 0
    private var subscriptionTask: Task<Void, Never>?

    var isAuthorized: Bool { authorization == .authorized }

    init() {
        if isAuthorized { observeSubscription() }
    }

    // MARK: - Autorisation et abonnement

    /// Affiche la demande d'autorisation d'Apple (une seule fois ; ensuite elle se règle dans Réglages).
    func requestAuthorization() async {
        authorization = await MusicAuthorization.request()
        if isAuthorized { observeSubscription() }
    }

    func refreshAuthorization() {
        authorization = MusicAuthorization.currentStatus
        if isAuthorized { observeSubscription() }
    }

    private func observeSubscription() {
        guard subscriptionTask == nil else { return }
        subscriptionTask = Task { [weak self] in
            for await current in MusicSubscription.subscriptionUpdates {
                guard let self else { return }
                self.subscription = current.canPlayCatalogContent
                    ? .active
                    : .inactive(canSubscribe: current.canBecomeSubscriber)
            }
        }
    }

    /// Vrai si la lecture du catalogue est permise. Si la vérification échoue (hors connexion…),
    /// on laisse la lecture tenter sa chance : c'est elle qui affichera la vraie erreur.
    func ensureCanPlay() async -> Bool {
        if subscription == .active { return true }
        do {
            let current = try await MusicSubscription.current
            subscription = current.canPlayCatalogContent
                ? .active
                : .inactive(canSubscribe: current.canBecomeSubscriber)
        } catch {
            return true
        }
        return subscription == .active
    }

    // MARK: - Recherche

    func search(_ rawTerm: String) async {
        let term = AppleSearchTerm.normalized(rawTerm)
        searchGeneration += 1
        let generation = searchGeneration

        guard !term.isEmpty else {
            results = AppleSearchResults()
            searchError = nil
            isSearching = false
            return
        }
        let key = term.lowercased()
        if let cached = searchCache[key] {
            results = cached
            searchError = nil
            isSearching = false
            return
        }
        guard isAuthorized else { return }

        isSearching = true
        searchError = nil
        do {
            var request = MusicCatalogSearchRequest(term: term, types: [Song.self, Artist.self, Album.self])
            request.limit = 15
            let response = try await request.response()
            guard generation == searchGeneration else { return }
            let value = AppleSearchResults(
                songs: Array(response.songs),
                artists: Array(response.artists),
                albums: Array(response.albums)
            )
            store(&searchCache, key: key, value: value)
            results = value
            isSearching = false
        } catch {
            guard generation == searchGeneration else { return }
            if error is CancellationError { return }
            results = AppleSearchResults()
            searchError = AppleMusicError.message(for: error)
            isSearching = false
        }
    }

    func loadSuggestions(_ rawTerm: String) async {
        let term = AppleSearchTerm.normalized(rawTerm)
        suggestionGeneration += 1
        let generation = suggestionGeneration

        guard !term.isEmpty, isAuthorized else {
            suggestions = []
            return
        }
        let key = term.lowercased()
        if let cached = suggestionCache[key] {
            suggestions = cached
            return
        }
        do {
            let request = MusicCatalogSearchSuggestionsRequest(term: term, includingTopResultsOfTypes: [Song.self])
            let response = try await request.response()
            guard generation == suggestionGeneration else { return }
            var seen = Set<String>()
            let list = response.suggestions
                .map { $0.searchTerm }
                .filter { seen.insert($0.lowercased()).inserted }
            let value = Array(list.prefix(6))
            store(&suggestionCache, key: key, value: value)
            suggestions = value
        } catch {
            // Les suggestions sont facultatives : en cas d'échec, la recherche normale reste disponible.
            if generation == suggestionGeneration { suggestions = [] }
        }
    }

    // MARK: - Classements (catalogue réel)

    func loadCharts(force: Bool = false) async {
        guard isAuthorized, !isLoadingCharts else { return }
        if charts != nil && !force { return }
        isLoadingCharts = true
        chartsError = nil
        do {
            var request = MusicCatalogChartsRequest(kinds: [.mostPlayed], types: [Song.self, Album.self])
            request.limit = 20
            let response = try await request.response()
            charts = AppleChartsContent(
                songs: response.songCharts.first.map { Array($0.items) } ?? [],
                albums: response.albumCharts.first.map { Array($0.items) } ?? []
            )
        } catch {
            if !(error is CancellationError) {
                chartsError = AppleMusicError.message(for: error)
            }
        }
        isLoadingCharts = false
    }

    // MARK: - Détails d'un album ou d'un artiste

    func songs(of album: Album) async throws -> [Song] {
        if let cached = albumSongsCache[album.id] { return cached }
        let detailed = try await album.with([.tracks])
        let songs: [Song] = detailed.tracks.map { tracks in
            tracks.compactMap { track -> Song? in
                if case .song(let song) = track { return song }
                return nil
            }
        } ?? []
        store(&albumSongsCache, key: album.id, value: songs)
        return songs
    }

    func content(of artist: Artist) async throws -> (songs: [Song], albums: [Album]) {
        if let cached = artistCache[artist.id] { return cached }
        let detailed = try await artist.with([.topSongs, .albums])
        let value = (
            songs: detailed.topSongs.map { Array($0) } ?? [],
            albums: detailed.albums.map { Array($0) } ?? []
        )
        store(&artistCache, key: artist.id, value: value)
        return value
    }

    // MARK: - Cache borné

    private func store<Key: Hashable, Value>(_ cache: inout [Key: Value], key: Key, value: Value) {
        if cache.count >= cacheLimit, let first = cache.keys.first {
            cache.removeValue(forKey: first)
        }
        cache[key] = value
    }
}
