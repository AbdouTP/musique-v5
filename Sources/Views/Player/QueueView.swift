import SwiftUI

struct QueueView: View {
    @EnvironmentObject private var player: PlayerService
    @Environment(\.dismiss) private var dismiss

    @State private var editMode: EditMode = .inactive

    var body: some View {
        NavigationStack {
            List {
                if let current = player.queue.current {
                    Section("En cours de lecture") {
                        QueueRow(track: current.track, highlighted: true)
                            .listRowBackground(Theme.card)
                    }
                }

                Section {
                    let upcoming = player.upcoming
                    if upcoming.isEmpty {
                        Text("Aucune musique à suivre.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.textSecondary)
                            .listRowBackground(Theme.card)
                    }
                    ForEach(upcoming) { item in
                        Button {
                            player.jump(to: item)
                        } label: {
                            QueueRow(track: item.track, highlighted: false)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Theme.card)
                    }
                    .onDelete { offsets in
                        let items = player.upcoming
                        for offset in offsets where items.indices.contains(offset) {
                            player.removeFromQueue(id: items[offset].id)
                        }
                    }
                    .onMove { source, destination in
                        player.moveUpcoming(from: source, to: destination)
                    }
                } header: {
                    HStack {
                        Text("À suivre")
                        Spacer()
                        if !player.upcoming.isEmpty {
                            Button("Vider") { player.clearUpcoming() }
                                .font(.footnote.weight(.semibold))
                                .textCase(nil)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .appBackground()
            .environment(\.editMode, $editMode)
            .navigationTitle("File d'attente")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if !player.upcoming.isEmpty { EditButton() }
                }
            }
        }
    }
}

private struct QueueRow: View {
    let track: Track
    let highlighted: Bool

    var body: some View {
        HStack(spacing: 12) {
            ArtworkView(key: track.artworkKey, seed: track.album, cornerRadius: 6)
                .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .foregroundStyle(highlighted ? Theme.accent : .white)
                    .lineLimit(1)
                Text(track.artist)
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
            }
            Spacer()
            Text(track.duration.clockString)
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(Theme.textSecondary)
        }
        .contentShape(Rectangle())
    }
}
