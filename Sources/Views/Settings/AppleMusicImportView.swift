import SwiftUI

/// Import de playlists depuis l'app Musique d'Apple.
struct AppleMusicImportView: View {
    @EnvironmentObject private var importer: AppleMusicImporter
    @Environment(\.dismiss) private var dismiss

    @State private var selection = Set<UInt64>()

    var body: some View {
        NavigationStack {
            Group {
                if importer.isWorking {
                    workingView
                } else if !importer.reports.isEmpty {
                    reportView
                } else {
                    switch importer.access {
                    case .unknown: introView
                    case .denied: deniedView
                    case .authorized: listView
                    }
                }
            }
            .appBackground()
            .navigationTitle("Apple Music")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") {
                        importer.resetReports()
                        dismiss()
                    }
                    .disabled(importer.isWorking)
                }
            }
            .task { importer.refreshAccess() }
        }
        .presentationDetents([.large])
        .interactiveDismissDisabled(importer.isWorking)
    }

    private static let limitsText = "Apple interdit de copier les morceaux en streaming ou protégés (DRM). Seuls les morceaux présents sur l'iPhone sans protection (achetés, ou ajoutés depuis un ordinateur) sont copiés dans Freetify. Les autres sont repris dans la playlist uniquement si le même titre existe déjà dans votre bibliothèque Freetify."

    // MARK: - États

    private var introView: some View {
        VStack(spacing: 16) {
            Image(systemName: "music.note.list")
                .font(.system(size: 52))
                .foregroundStyle(Theme.accent)
            Text("Importer vos playlists Apple Music")
                .font(.title3.bold())
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            Text(Self.limitsText)
                .font(.footnote)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
            Button {
                Task { await importer.requestAccess() }
            } label: {
                Text("Autoriser l'accès à Musique")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 14)
                    .background(Capsule().fill(Theme.primary))
            }
            .buttonStyle(PressableStyle())
        }
        .padding(28)
    }

    private var deniedView: some View {
        VStack(spacing: 16) {
            ContentUnavailableView(
                "Accès refusé",
                systemImage: "lock.fill",
                description: Text("Autorisez l'accès à Musique dans Réglages → Freetify Musique.")
            )
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text("Ouvrir les réglages")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(Theme.primary))
            }
            .buttonStyle(PressableStyle())
        }
    }

    private var workingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
                .tint(Theme.accent)
            Text("Import en cours…")
                .font(.headline)
                .foregroundStyle(.white)
            Text(importer.progressText)
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(28)
    }

    private var listView: some View {
        Group {
            if importer.playlists.isEmpty {
                ContentUnavailableView(
                    "Aucune playlist",
                    systemImage: "music.note.list",
                    description: Text("Vos playlists n'apparaissent ici que si elles contiennent des morceaux et que « Synchroniser la bibliothèque » est activé dans Réglages → Musique.")
                )
            } else {
                List {
                    Section {
                        ForEach(importer.playlists) { playlist in
                            Button {
                                if selection.contains(playlist.id) {
                                    selection.remove(playlist.id)
                                } else {
                                    selection.insert(playlist.id)
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(playlist.name)
                                            .foregroundStyle(.white)
                                            .lineLimit(1)
                                        Text("\(playlist.totalCount) morceau\(playlist.totalCount > 1 ? "x" : "") · \(playlist.importableCount) copiable\(playlist.importableCount > 1 ? "s" : "")")
                                            .font(.caption)
                                            .foregroundStyle(Theme.textSecondary)
                                    }
                                    Spacer()
                                    Image(systemName: selection.contains(playlist.id) ? "checkmark.circle.fill" : "circle")
                                        .font(.title3)
                                        .foregroundStyle(selection.contains(playlist.id) ? Theme.accent : Theme.textSecondary)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(Theme.card)
                        }
                    } footer: {
                        Text(Self.limitsText)
                    }
                }
                .scrollContentBackground(.hidden)
                .safeAreaInset(edge: .bottom) {
                    Button {
                        let chosen = selection
                        Task { await importer.importPlaylists(ids: chosen) }
                    } label: {
                        Text("Importer (\(selection.count))")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Capsule().fill(selection.isEmpty ? Color.gray.opacity(0.4) : Theme.primary))
                    }
                    .disabled(selection.isEmpty)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                }
            }
        }
    }

    private var reportView: some View {
        List {
            ForEach(importer.reports) { report in
                Section(report.playlistName) {
                    Label("\(report.copied) copié\(report.copied > 1 ? "s" : "") dans Freetify", systemImage: "square.and.arrow.down")
                    Label("\(report.alreadyInLibrary) déjà dans votre bibliothèque", systemImage: "checkmark.circle")
                    if !report.skipped.isEmpty {
                        DisclosureGroup {
                            ForEach(report.skipped, id: \.self) { label in
                                Text(label)
                                    .font(.caption)
                                    .foregroundStyle(Theme.textSecondary)
                            }
                        } label: {
                            Label("\(report.skipped.count) non importable\(report.skipped.count > 1 ? "s" : "") (streaming/protégé)", systemImage: "lock.fill")
                        }
                    }
                }
                .listRowBackground(Theme.card)
            }
            Section {
                Button {
                    importer.resetReports()
                    dismiss()
                } label: {
                    Text("Terminé")
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(Theme.accent)
                }
                .listRowBackground(Theme.card)
            } footer: {
                Text("Les playlists ont été créées dans Bibliothèque → Playlists.")
            }
        }
        .scrollContentBackground(.hidden)
    }
}
