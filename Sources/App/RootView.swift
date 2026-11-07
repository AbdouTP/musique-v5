import SwiftUI

enum AppTab: Hashable {
    case home, search, discover, library, settings
}

struct RootView: View {
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var player: PlayerService
    @EnvironmentObject private var importer: ImportService
    @EnvironmentObject private var ui: UIState
    @EnvironmentObject private var appleMusicPlayer: AppleMusicPlayer

    @State private var tab: AppTab = .home

    var body: some View {
        TabView(selection: $tab) {
            HomeView()
                .tabItem { Label("Accueil", systemImage: "house.fill") }
                .tag(AppTab.home)
            SearchView()
                .tabItem { Label("Recherche", systemImage: "magnifyingglass") }
                .tag(AppTab.search)
            DiscoverHubView()
                .tabItem { Label("Découvrir", systemImage: "arrow.down.circle") }
                .tag(AppTab.discover)
            LibraryView()
                .tabItem { Label("Bibliothèque", systemImage: "music.note.list") }
                .tag(AppTab.library)
            SettingsView()
                .tabItem { Label("Réglages", systemImage: "gearshape.fill") }
                .tag(AppTab.settings)
        }
        .overlay(alignment: .top) { importBanner }
        .animation(.easeInOut(duration: 0.25), value: importer.isImporting)
        .fileImporter(
            isPresented: $ui.showImporter,
            allowedContentTypes: ImportPipeline.contentTypes,
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                Task { await importer.importFiles(urls) }
            case .failure(let error):
                importer.reportMessage = "Impossible d'ouvrir le sélecteur de fichiers : \(error.localizedDescription)"
            }
        }
        .sheet(isPresented: $ui.showFullPlayer) {
            FullPlayerView()
        }
        .sheet(isPresented: $ui.showAppleMusicPlayer) {
            AppleMusicNowPlayingView()
        }
        .sheet(isPresented: $ui.showAppleMusicImport) {
            AppleMusicImportView()
        }
        .alert("Importation", isPresented: Binding(
            get: { importer.reportMessage != nil },
            set: { if !$0 { importer.reportMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importer.reportMessage ?? "")
        }
        .alert("Lecture", isPresented: Binding(
            get: { player.errorMessage != nil },
            set: { if !$0 { player.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(player.errorMessage ?? "")
        }
        .alert("Apple Music", isPresented: Binding(
            get: { appleMusicPlayer.errorMessage != nil },
            set: { if !$0 { appleMusicPlayer.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(appleMusicPlayer.errorMessage ?? "")
        }
        .alert("Abonnement Apple Music nécessaire", isPresented: $appleMusicPlayer.subscriptionRequired) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Apple n'autorise l'écoute du catalogue qu'avec un abonnement Apple Music actif. Aucun titre n'est lu sans abonnement. Votre bibliothèque locale reste lisible.")
        }
        .alert("Bibliothèque", isPresented: Binding(
            get: { library.loadWarning != nil },
            set: { if !$0 { library.loadWarning = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(library.loadWarning ?? "")
        }
    }

    @ViewBuilder
    private var importBanner: some View {
        if importer.isImporting {
            HStack(spacing: 10) {
                ProgressView().tint(.white)
                Text("Importation \(importer.processed)/\(importer.total)…")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Capsule().fill(Theme.primary))
            .shadow(color: .black.opacity(0.35), radius: 10, y: 4)
            .padding(.top, 8)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}
