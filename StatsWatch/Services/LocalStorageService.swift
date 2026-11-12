import Foundation

class LocalStorageService {
    static let shared = LocalStorageService()

    private let defaults = UserDefaults.standard
    private let favoritesKey = "sw_favorites"
    private let historyKey = "sw_search_history"
    private let snapshotsKey = "sw_stat_snapshots"
    private let rankSnapshotsKey = "sw_rank_snapshots"
    private let maxHistoryItems = 20

    // MARK: - Favorites
    func getFavorites() -> [FavoritePlayer] {
        guard let data = defaults.data(forKey: favoritesKey) else { return [] }
        return (try? JSONDecoder().decode([FavoritePlayer].self, from: data)) ?? []
    }

    func addFavorite(_ player: FavoritePlayer) {
        var list = getFavorites()
        list.removeAll { $0.playerId == player.playerId }
        list.insert(player, at: 0)
        save(list, forKey: favoritesKey)
    }

    func removeFavorite(playerId: String) {
        var list = getFavorites()
        list.removeAll { $0.playerId == playerId }
        save(list, forKey: favoritesKey)
    }

    func isFavorite(playerId: String) -> Bool {
        getFavorites().contains { $0.playerId == playerId }
    }

    // MARK: - Search History
    func getHistory() -> [SearchHistoryItem] {
        guard let data = defaults.data(forKey: historyKey) else { return [] }
        return (try? JSONDecoder().decode([SearchHistoryItem].self, from: data)) ?? []
    }

    func addHistory(_ item: SearchHistoryItem) {
        var list = getHistory()
        list.removeAll { $0.playerId == item.playerId }
        list.insert(item, at: 0)
        if list.count > maxHistoryItems {
            list = Array(list.prefix(maxHistoryItems))
        }
        save(list, forKey: historyKey)
    }

    func clearHistory() {
        defaults.removeObject(forKey: historyKey)
    }

    // MARK: - Stat Snapshots
    func getSnapshots(for playerId: String) -> [StatSnapshot] {
        let all = getAllSnapshots()
        return all.filter { $0.playerId == playerId }.sorted { $0.date > $1.date }
    }

    func addSnapshot(_ snapshot: StatSnapshot) {
        var all = getAllSnapshots()
        // Don't save duplicate snapshots within same day
        let calendar = Calendar.current
        let isDuplicate = all.contains {
            $0.playerId == snapshot.playerId &&
            $0.gamemode == snapshot.gamemode &&
            calendar.isDate($0.date, inSameDayAs: snapshot.date)
        }
        guard !isDuplicate else { return }
        all.append(snapshot)
        save(all, forKey: snapshotsKey)
    }

    func getSnapshots(for playerId: String, gamemode: String) -> [StatSnapshot] {
        getSnapshots(for: playerId).filter { $0.gamemode == gamemode }
    }

    // MARK: - Rank Snapshots
    func getRankSnapshots(for playerId: String) -> [RankSnapshot] {
        getAllRankSnapshots()
            .filter { $0.playerId == playerId }
            .sorted { $0.date < $1.date }
    }

    // Keeps one entry per player per day, overwritten by the latest rank seen that day.
    func saveRankSnapshot(_ snapshot: RankSnapshot) {
        guard !snapshot.scores.isEmpty else { return }
        var all = getAllRankSnapshots()
        let calendar = Calendar.current
        all.removeAll { $0.playerId == snapshot.playerId && calendar.isDate($0.date, inSameDayAs: snapshot.date) }
        all.append(snapshot)
        save(all, forKey: rankSnapshotsKey)
    }

    private func getAllRankSnapshots() -> [RankSnapshot] {
        guard let data = defaults.data(forKey: rankSnapshotsKey) else { return [] }
        return (try? JSONDecoder().decode([RankSnapshot].self, from: data)) ?? []
    }

    private func getAllSnapshots() -> [StatSnapshot] {
        guard let data = defaults.data(forKey: snapshotsKey) else { return [] }
        return (try? JSONDecoder().decode([StatSnapshot].self, from: data)) ?? []
    }

    // MARK: - Helpers
    private func save<T: Encodable>(_ value: T, forKey key: String) {
        if let data = try? JSONEncoder().encode(value) {
            defaults.set(data, forKey: key)
        }
    }
}
