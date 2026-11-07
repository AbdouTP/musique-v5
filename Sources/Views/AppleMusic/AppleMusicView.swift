import MusicKit
import SwiftUI

/// Recherche et découverte du catalogue Apple Music (MusicKit).
struct AppleMusicView: View {
    @EnvironmentObject private var service: AppleMusicService

    @State private var query = ""

    var body: some View {
        NavigationStack {
            Group {
                switch service.authorization {
                case .authorized:
                    catalog
                case .notDetermined:
                    permissionIntro
                default:
                    permissionDenied
                }
            }
            .appBackground()
            .withMiniPlayer()
            .navigationTitle("Apple Music")
            .navigationDestination(for: AppleRoute.self) { route in
                switch route {
                case .album(let album):
                    AppleAlbumDetailView(album: album)
                case .artist(let artist):
                    AppleArtistDetailView(artist: artist)
                }
            }
        }
    }

    // MARK: - Autorisation

    private var permissionIntro: some View {
        VStack(spacing: 16) {
            Image(systemName: "music.note.house.fill")
                .font(.system(size: 52))
                .foregroundStyle(Theme.accent)
            Text("Le catalogue Apple Music")
                .font(.title2.bold())
                .foregroundStyle(.white)
            Text("Cherchez des titres, artistes et albums dans le catalogue d'Apple Music. L'écoute des titres du catalogue demande un abonnement Apple Music actif. Votre bibliothèque locale n'est jamais modifiée.")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
            Button {
                Task { await service.requestAuthorization() }
            } label: {
                Text("Autoriser l'accès à Apple Music")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Capsule().fill(Theme.primary))
            }
            .buttonStyle(PressableStyle())
        }
        .padding(28)
        .frame(maxHeight: .infinity)
    }

    private var permissionDenied: some View {
        VStack(spacing: 14) {
            ContentUnavailableView(
                "Accès refusé",
                systemImage: "lock.fill",
                description: Text("Freetify n'a pas l'autorisation d'accéder à Apple Music. Vous pouvez l'activer dans Réglages → Freetify Musique → Médias et Apple Music.")
            )
            if let url = URL(string: UIApplication.openSettingsURLString) {
                Link("Ouvrir les Réglages", destination: url)
                    .font(.headline)
                    .foregroundStyle(Theme.accent)
            }
        }
    }

    // MARK: - Catalogue

    private var catalog: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 22) {
                if case .inactive(let canSubscribe) = service.subscription {
                    AppleSubscriptionBanner(canSubscribe: canSubscribe)
                }
                if AppleSearchTerm.normalized(query).isEmpty {
                    chartsSection
                } else {
                    resultsSection
                }
            }
            .padding(.vertical, 12)
        }
        .scrollDismissesKeyboard(.interactively)
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Titres, artistes, albums…")
        .searchSuggestions {
            ForEach(service.suggestions, id: \.self) { suggestion in
                Text(suggestion).searchCompletion(suggestion)
            }
        }
        .onSubmit(of: .search) {
            Task { await service.search(query) }
        }
        .task(id: query) {
            // Petite attente : on ne lance un appel réseau que lorsque la frappe se calme.
            let term = AppleSearchTerm.normalized(query)
            if term.isEmpty {
                await service.search("")
                await service.loadSuggestions("")
                return
            }
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            async let suggestions: Void = service.loadSuggestions(term)
            async let search: Void = service.search(term)
            _ = await (suggestions, search)
        }
        .task {
            service.refreshAuthorization()
            await service.loadCharts()
        }
        .refreshable {
            await service.loadCharts(force: true)
        }
    }

    @ViewBuilder
    private var chartsSection: some View {
        if let charts = service.charts {
            if !charts.songs.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    SectionHeader(title: "Les plus écoutés", subtitle: "Classement réel d'Apple Music")
                    ApplePlayShuffleBar(songs: charts.songs)
                        .padding(.horizontal, 16)
                    songList(Array(charts.songs.prefix(10)), context: charts.songs)
                }
            }
            if !charts.albums.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    SectionHeader(title: "Albums populaires")
                    HorizontalRow {
                        ForEach(charts.albums, id: \.id) { album in
                            AppleAlbumCard(album: album)
                        }
                    }
                }
            }
            if charts.songs.isEmpty && charts.albums.isEmpty {
                ContentUnavailableView("Rien à afficher", systemImage: "music.note", description: Text("Utilisez la recherche pour explorer le catalogue."))
            }
        } else if service.isLoadingCharts {
            ProgressView("Chargement du catalogue…")
                .tint(Theme.accent)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.top, 60)
        } else if let error = service.chartsError {
            errorView(error) { Task { await service.loadCharts(force: true) } }
        }
    }

    @ViewBuilder
    private var resultsSection: some View {
        if let error = service.searchError, service.results.isEmpty {
            errorView(error) { Task { await service.search(query) } }
        } else if service.isSearching && service.results.isEmpty {
            ProgressView("Recherche…")
                .tint(Theme.accent)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.top, 60)
        } else if service.results.isEmpty {
            ContentUnavailableView.search(text: query)
        } else {
            let results = service.results
            if !results.songs.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    SectionHeader(title: "Titres")
                    songList(results.songs, context: results.songs)
                }
            }
            if !results.artists.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    SectionHeader(title: "Artistes")
                    HorizontalRow {
                        ForEach(results.artists, id: \.id) { artist in
                            AppleArtistCard(artist: artist)
                        }
                    }
                }
            }
            if !results.albums.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    SectionHeader(title: "Albums")
                    HorizontalRow {
                        ForEach(results.albums, id: \.id) { album in
                            AppleAlbumCard(album: album)
                        }
                    }
                }
            }
        }
    }

    private func songList(_ songs: [Song], context: [Song]) -> some View {
        VStack(spacing: 10) {
            ForEach(songs, id: \.id) { song in
                AppleSongRow(song: song, context: context)
            }
        }
        .padding(.horizontal, 16)
    }

    private func errorView(_ message: String, retry: @escaping () -> Void) -> some View {
        VStack(spacing: 12) {
            ContentUnavailableView(
                "Impossible de charger",
                systemImage: "wifi.slash",
                description: Text(message)
            )
            Button("Réessayer", action: retry)
                .buttonStyle(.borderedProminent)
                .tint(Theme.primary)
        }
        .frame(maxWidth: .infinity)
    }
}
