import SwiftUI

/// Recherche et téléchargement de musique libre de droits (Jamendo, licences Creative Commons).
/// C'est la seule page de l'app qui utilise Internet ; les titres téléchargés se lisent ensuite hors connexion.
struct DiscoverView: View {
    @EnvironmentObject private var downloader: OnlineDownloader

    @AppStorage("jamendoClientID") private var clientID = ""

    @State private var query = ""
    @State private var results: [OnlineTrack] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showKeySheet = false
    @State private var draftKey = ""

    var body: some View {
        NavigationStack {
            Group {
                if clientID.trimmingCharacters(in: .whitespaces).isEmpty {
                    setupView
                } else if isLoading && results.isEmpty {
                    ProgressView("Chargement…")
                        .tint(Theme.accent)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage, results.isEmpty {
                    VStack(spacing: 12) {
                        ContentUnavailableView(
                            "Impossible de charger",
                            systemImage: "wifi.slash",
                            description: Text(errorMessage)
                        )
                        Button("Réessayer") { Task { await load() } }
                            .buttonStyle(.borderedProminent)
                            .tint(Theme.primary)
                    }
                } else if results.isEmpty {
                    ContentUnavailableView.search(text: query)
                } else {
                    resultsList
                }
            }
            .appBackground()
            .withMiniPlayer()
            .navigationTitle("Découvrir")
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Titre, artiste, album…")
            .onSubmit(of: .search) { Task { await load() } }
            .onChange(of: query) { _, newValue in
                if newValue.isEmpty { Task { await load() } }
            }
            .task(id: clientID) {
                if !clientID.trimmingCharacters(in: .whitespaces).isEmpty { await load() }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        draftKey = clientID
                        showKeySheet = true
                    } label: {
                        Image(systemName: "key.fill")
                    }
                    .accessibilityLabel("Clé Jamendo")
                }
            }
            .sheet(isPresented: $showKeySheet) { keySheet }
        }
    }

    // MARK: - Chargement

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            results = try await JamendoService.search(query: query, clientID: clientID)
        } catch {
            results = []
            errorMessage = NetworkErrorText.message(for: error)
        }
    }

    // MARK: - Écrans

    private var resultsList: some View {
        List {
            Section {
                ForEach(results) { track in
                    OnlineTrackRow(track: track)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 12))
                        .listRowSeparator(.hidden)
                }
            } header: {
                Text(query.isEmpty ? "Populaires ce mois-ci" : "Résultats")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                    .textCase(nil)
            } footer: {
                Text("Musique libre (Creative Commons) fournie par Jamendo. Seule cette page utilise Internet : une fois téléchargés, les titres se lisent hors connexion. Respectez les conditions de chaque licence.")
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private var setupView: some View {
        ScrollView {
            VStack(spacing: 16) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(Theme.accent)
                Text("Musique gratuite et légale")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                Text("Cherchez et téléchargez de la musique libre (Creative Commons) depuis Jamendo, puis écoutez-la sans connexion et ajoutez-la à vos playlists.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)

                VStack(alignment: .leading, spacing: 8) {
                    Text("1. Créez un compte gratuit sur developer.jamendo.com")
                    Text("2. Créez une application pour obtenir un « Client ID »")
                    Text("3. Collez-le ci-dessous")
                }
                .font(.footnote)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)

                if let url = URL(string: "https://developer.jamendo.com/v3.0") {
                    Link("Ouvrir developer.jamendo.com", destination: url)
                        .font(.subheadline.weight(.semibold))
                }

                TextField("Client ID Jamendo", text: $draftKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.card))
                    .foregroundStyle(.white)

                Button {
                    clientID = draftKey.trimmingCharacters(in: .whitespacesAndNewlines)
                } label: {
                    Text("Enregistrer et commencer")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Capsule().fill(draftKey.isEmpty ? Color.gray.opacity(0.4) : Theme.primary))
                }
                .disabled(draftKey.trimmingCharacters(in: .whitespaces).isEmpty)
                .buttonStyle(PressableStyle())

                Text("La clé reste uniquement sur cet iPhone.")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(24)
        }
    }

    private var keySheet: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Client ID Jamendo", text: $draftKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } footer: {
                    Text("Clé gratuite obtenue sur developer.jamendo.com. Elle reste uniquement sur cet iPhone.")
                }
                .listRowBackground(Theme.card)
            }
            .scrollContentBackground(.hidden)
            .appBackground()
            .navigationTitle("Clé Jamendo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { showKeySheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") {
                        clientID = draftKey.trimmingCharacters(in: .whitespacesAndNewlines)
                        showKeySheet = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

private struct OnlineTrackRow: View {
    @EnvironmentObject private var downloader: OnlineDownloader
    let track: OnlineTrack

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: track.artworkURL) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                PlaceholderArt(seed: track.album)
            }
            .frame(width: 52, height: 52)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(track.artist)
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(track.duration.clockString)
                    if let license = track.licenseLabel { Text("· " + license) }
                }
                .font(.caption2)
                .foregroundStyle(Theme.textSecondary)
                if case .failed(let message) = downloader.state(for: track) {
                    Text(message)
                        .font(.caption2)
                        .foregroundStyle(.red)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 4)
            actionButton
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        switch downloader.state(for: track) {
        case .downloading:
            ProgressView().tint(Theme.accent).frame(width: 44, height: 44)
        case .done:
            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundStyle(Theme.accent)
                .frame(width: 44, height: 44)
                .accessibilityLabel("Téléchargé")
        case .failed:
            Button {
                Task { await downloader.download(track) }
            } label: {
                Image(systemName: "arrow.clockwise.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.red)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Réessayer")
        case nil:
            Button {
                Task { await downloader.download(track) }
            } label: {
                Image(systemName: "arrow.down.circle")
                    .font(.title2)
                    .foregroundStyle(Theme.accent)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Télécharger")
        }
    }
}
