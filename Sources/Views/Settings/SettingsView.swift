import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var ui: UIState

    @State private var usedBytes: Int64 = 0
    @State private var confirmDeleteAll = false
    @State private var confirmReset = false
    @State private var confirmClearHistory = false

    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        ui.showImporter = true
                    } label: {
                        Label("Importer des musiques", systemImage: "square.and.arrow.down")
                            .foregroundStyle(Theme.accent)
                    }
                } footer: {
                    Text("Formats : MP3, M4A, AAC, WAV, AIFF, FLAC. Les fichiers sont copiés dans l'application : le fichier d'origine n'est plus nécessaire.")
                }
                .listRowBackground(Theme.card)

                Section {
                    Button {
                        ui.showAppleMusicImport = true
                    } label: {
                        Label("Importer des playlists Apple Music", systemImage: "music.note.list")
                            .foregroundStyle(Theme.accent)
                    }
                } footer: {
                    Text("Reprend vos playlists de l'app Musique. Les morceaux en streaming protégés ne peuvent pas être copiés (règle d'Apple).")
                }
                .listRowBackground(Theme.card)

                Section("Bibliothèque") {
                    LabeledContent("Musiques importées", value: "\(library.tracks.count)")
                    LabeledContent("Albums", value: "\(library.albums.count)")
                    LabeledContent("Artistes", value: "\(library.artists.count)")
                    LabeledContent("Playlists", value: "\(library.playlists.count)")
                    LabeledContent("Favoris", value: "\(library.favoriteIDs.count)")
                }
                .listRowBackground(Theme.card)

                Section {
                    LabeledContent("Espace utilisé", value: usedBytes.byteString)
                } header: {
                    Text("Stockage")
                } footer: {
                    Text("Musiques, pochettes et données de la bibliothèque stockées sur cet iPhone.")
                }
                .listRowBackground(Theme.card)

                Section("Gestion de la bibliothèque") {
                    NavigationLink {
                        ManageTracksView()
                    } label: {
                        Label("Gérer et supprimer des musiques", systemImage: "checklist")
                    }
                    Button(role: .destructive) {
                        confirmClearHistory = true
                    } label: {
                        Label("Effacer l'historique d'écoute", systemImage: "clock.arrow.circlepath")
                    }
                    .disabled(library.history.isEmpty)
                    Button(role: .destructive) {
                        confirmDeleteAll = true
                    } label: {
                        Label("Supprimer toutes les musiques", systemImage: "trash")
                    }
                    .disabled(library.tracks.isEmpty)
                    Button(role: .destructive) {
                        confirmReset = true
                    } label: {
                        Label("Réinitialiser la bibliothèque", systemImage: "arrow.counterclockwise")
                    }
                    .disabled(library.tracks.isEmpty && library.playlists.isEmpty && library.history.isEmpty)
                }
                .listRowBackground(Theme.card)

                Section("Apparence") {
                    LabeledContent("Thème", value: "Sombre")
                }
                .listRowBackground(Theme.card)

                Section {
                    LabeledContent("Version", value: version)
                    LabeledContent("Lecture", value: "100 % hors connexion")
                    LabeledContent("Développeur", value: "AbdouTP")
                } header: {
                    Text("À propos")
                } footer: {
                    Text("Dev by AbdouTP\n\nLa bibliothèque et le lecteur fonctionnent sans Internet. Seul l'onglet Découvrir se connecte (à Jamendo), uniquement pour chercher et télécharger de la musique libre.")
                }
                .listRowBackground(Theme.card)
            }
            .scrollContentBackground(.hidden)
            .appBackground()
            .withMiniPlayer()
            .navigationTitle("Réglages")
            .task(id: library.tracks.count) {
                usedBytes = await Task.detached(priority: .utility) {
                    Storage.directorySize(Storage.root)
                }.value
            }
            .confirmationDialog("Effacer tout l'historique d'écoute ?", isPresented: $confirmClearHistory, titleVisibility: .visible) {
                Button("Effacer l'historique", role: .destructive) { library.clearHistory() }
                Button("Annuler", role: .cancel) {}
            }
            .confirmationDialog(
                "Supprimer les \(library.tracks.count) musiques ?",
                isPresented: $confirmDeleteAll,
                titleVisibility: .visible
            ) {
                Button("Supprimer toutes les musiques", role: .destructive) { library.deleteAllTracks() }
                Button("Annuler", role: .cancel) {}
            } message: {
                Text("Les fichiers sont supprimés de l'iPhone. Les playlists sont conservées mais vidées.")
            }
            .confirmationDialog("Réinitialiser la bibliothèque ?", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Tout supprimer", role: .destructive) { library.resetLibrary() }
                Button("Annuler", role: .cancel) {}
            } message: {
                Text("Musiques, playlists, favoris et historique seront définitivement supprimés.")
            }
        }
    }
}

struct ManageTracksView: View {
    @EnvironmentObject private var library: LibraryStore

    @State private var selection = Set<UUID>()
    @State private var editMode: EditMode = .active
    @State private var confirmDelete = false

    private var sortedTracks: [Track] {
        library.tracks.sorted { $0.title.searchKey < $1.title.searchKey }
    }

    var body: some View {
        Group {
            if library.tracks.isEmpty {
                ContentUnavailableView(
                    "Aucune musique",
                    systemImage: "music.note",
                    description: Text("Importez des musiques pour pouvoir les gérer ici.")
                )
            } else {
                List(sortedTracks, selection: $selection) { track in
                    HStack(spacing: 12) {
                        ArtworkView(key: track.artworkKey, seed: track.album, cornerRadius: 6)
                            .frame(width: 40, height: 40)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(track.title).foregroundStyle(.white).lineLimit(1)
                            Text(track.artist)
                                .font(.caption)
                                .foregroundStyle(Theme.textSecondary)
                                .lineLimit(1)
                        }
                    }
                    .listRowBackground(Color.clear)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .environment(\.editMode, $editMode)
                .safeAreaInset(edge: .bottom) {
                    Button(role: .destructive) {
                        confirmDelete = true
                    } label: {
                        Label("Supprimer (\(selection.count))", systemImage: "trash")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Capsule().fill(selection.isEmpty ? Color.gray.opacity(0.4) : Color.red))
                    }
                    .disabled(selection.isEmpty)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                }
            }
        }
        .appBackground()
        .navigationTitle("Gérer les musiques")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(selection.count == library.tracks.count && !selection.isEmpty ? "Tout désélectionner" : "Tout sélectionner") {
                    if selection.count == library.tracks.count {
                        selection.removeAll()
                    } else {
                        selection = Set(library.tracks.map(\.id))
                    }
                }
                .disabled(library.tracks.isEmpty)
            }
        }
        .confirmationDialog(
            "Supprimer \(selection.count) musique\(selection.count > 1 ? "s" : "") ?",
            isPresented: $confirmDelete,
            titleVisibility: .visible
        ) {
            Button("Supprimer", role: .destructive) {
                library.deleteTracks(selection)
                selection.removeAll()
            }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Les fichiers sont supprimés de l'iPhone, ainsi que des playlists et favoris.")
        }
    }
}
