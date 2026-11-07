import Foundation
import SwiftUI

struct QueueItem: Identifiable, Hashable, Sendable {
    let id = UUID()
    let track: Track
}

enum RepeatMode: Int, Sendable {
    case off, all, one

    var next: RepeatMode {
        switch self {
        case .off: return .all
        case .all: return .one
        case .one: return .off
        }
    }
}

/// File d'attente pure (sans audio), donc testable : ordre de lecture, aléatoire, ajouts, suppressions.
struct PlayQueue {
    private(set) var items: [QueueItem] = []
    /// Ordre d'origine, restauré quand on désactive le mode aléatoire.
    private(set) var original: [QueueItem] = []
    private(set) var currentIndex: Int?
    private(set) var isShuffled = false

    var current: QueueItem? {
        guard let currentIndex, items.indices.contains(currentIndex) else { return nil }
        return items[currentIndex]
    }

    var upcoming: [QueueItem] {
        guard let currentIndex, currentIndex + 1 < items.count else { return [] }
        return Array(items[(currentIndex + 1)...])
    }

    var history: [QueueItem] {
        guard let currentIndex, currentIndex > 0 else { return [] }
        return Array(items[..<currentIndex])
    }

    var hasNext: Bool {
        guard let currentIndex else { return false }
        return currentIndex + 1 < items.count
    }

    var hasPrevious: Bool {
        guard let currentIndex else { return false }
        return currentIndex > 0
    }

    // MARK: - Construction

    /// Remplace la file par `tracks`, en commençant à `startAt` (ou au début).
    mutating func set(tracks: [Track], startAt: Int?, shuffled: Bool) {
        let list = tracks.map { QueueItem(track: $0) }
        original = list
        isShuffled = shuffled
        guard !list.isEmpty else {
            items = []
            currentIndex = nil
            return
        }
        if shuffled {
            if let startAt, list.indices.contains(startAt) {
                var rest = list
                let first = rest.remove(at: startAt)
                items = [first] + rest.shuffled()
            } else {
                items = list.shuffled()
            }
            currentIndex = 0
        } else {
            items = list
            currentIndex = (startAt.flatMap { list.indices.contains($0) ? $0 : nil }) ?? 0
        }
    }

    mutating func toggleShuffle() {
        isShuffled.toggle()
        guard let currentIndex, items.indices.contains(currentIndex) else { return }
        let currentItem = items[currentIndex]
        if isShuffled {
            original = items
            var rest = items
            rest.remove(at: currentIndex)
            items = [currentItem] + rest.shuffled()
            self.currentIndex = 0
        } else {
            let restored = original.filter { orig in items.contains(where: { $0.id == orig.id }) }
            // Ajouts faits pendant le mode aléatoire : placés à la fin.
            let missing = items.filter { item in !restored.contains(where: { $0.id == item.id }) }
            items = restored + missing
            self.currentIndex = items.firstIndex(where: { $0.id == currentItem.id }) ?? 0
        }
    }

    // MARK: - Modifications

    /// Insère juste après la musique en cours.
    mutating func playNext(_ track: Track) {
        let item = QueueItem(track: track)
        guard let currentIndex else {
            set(tracks: [track], startAt: 0, shuffled: isShuffled)
            return
        }
        items.insert(item, at: currentIndex + 1)
        if let originalIndex = original.firstIndex(where: { $0.id == items[currentIndex].id }) {
            original.insert(item, at: originalIndex + 1)
        } else {
            original.append(item)
        }
    }

    mutating func append(_ track: Track) {
        guard currentIndex != nil else {
            set(tracks: [track], startAt: 0, shuffled: isShuffled)
            return
        }
        let item = QueueItem(track: track)
        items.append(item)
        original.append(item)
    }

    /// Retire un élément à venir (la musique en cours ne peut pas être retirée ici).
    mutating func remove(id: UUID) {
        guard let currentIndex, let index = items.firstIndex(where: { $0.id == id }), index != currentIndex else { return }
        items.remove(at: index)
        original.removeAll { $0.id == id }
        if index < currentIndex { self.currentIndex = currentIndex - 1 }
    }

    /// Réordonne les éléments à venir (offsets relatifs à `upcoming`).
    mutating func moveUpcoming(from source: IndexSet, to destination: Int) {
        guard let currentIndex else { return }
        var upcomingItems = upcoming
        upcomingItems.move(fromOffsets: source, toOffset: destination)
        items = Array(items[...currentIndex]) + upcomingItems
        if !isShuffled { original = items }
    }

    mutating func clearUpcoming() {
        guard let currentIndex else { return }
        items = Array(items[...currentIndex])
        let kept = Set(items.map(\.id))
        original = original.filter { kept.contains($0.id) }
    }

    mutating func clear() {
        items = []
        original = []
        currentIndex = nil
    }

    /// Retire toutes les occurrences des musiques supprimées.
    /// - Returns: `true` si la musique en cours faisait partie des musiques retirées.
    @discardableResult
    mutating func removeTracks(_ ids: Set<UUID>) -> Bool {
        guard let oldIndex = currentIndex, items.indices.contains(oldIndex) else {
            items.removeAll { ids.contains($0.track.id) }
            original.removeAll { ids.contains($0.track.id) }
            return false
        }
        let currentItem = items[oldIndex]
        let removedCurrent = ids.contains(currentItem.track.id)

        items.removeAll { ids.contains($0.track.id) }
        original.removeAll { ids.contains($0.track.id) }

        if items.isEmpty {
            currentIndex = nil
        } else if removedCurrent {
            currentIndex = min(oldIndex, items.count - 1)
        } else {
            currentIndex = items.firstIndex(where: { $0.id == currentItem.id })
        }
        return removedCurrent
    }

    // MARK: - Navigation

    /// Passe à la musique suivante. Retourne `false` s'il n'y en a pas (et `wrap` est faux).
    @discardableResult
    mutating func advance(wrap: Bool) -> Bool {
        guard let currentIndex, !items.isEmpty else { return false }
        if currentIndex + 1 < items.count {
            self.currentIndex = currentIndex + 1
            return true
        }
        if wrap {
            self.currentIndex = 0
            return true
        }
        return false
    }

    @discardableResult
    mutating func goBack(wrap: Bool) -> Bool {
        guard let currentIndex, !items.isEmpty else { return false }
        if currentIndex > 0 {
            self.currentIndex = currentIndex - 1
            return true
        }
        if wrap {
            self.currentIndex = items.count - 1
            return true
        }
        return false
    }

    @discardableResult
    mutating func jump(to id: UUID) -> Bool {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return false }
        currentIndex = index
        return true
    }
}
