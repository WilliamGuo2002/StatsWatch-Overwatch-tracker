import SwiftUI

struct FriendsRankingView: View {
    let viewModel: PlayerViewModel
    let favorites: [FavoritePlayer]
    @State private var summaries: [String: PlayerSummary] = [:]
    @State private var failedIds: Set<String> = []
    @State private var privateIds: Set<String> = []
    @State private var isLoading = true
    @State private var role = "damage"

    private struct Entry: Identifiable {
        let player: FavoritePlayer
        let rank: RankInfo?
        let score: Int?
        var id: String { player.playerId }
    }

    private func ranks(for summary: PlayerSummary?) -> PlatformRanks? {
        summary?.competitive?.pc ?? summary?.competitive?.console
    }

    private func rankInfo(_ ranks: PlatformRanks?) -> RankInfo? {
        switch role {
        case "tank": return ranks?.tank
        case "support": return ranks?.support
        case "open": return ranks?.open
        default: return ranks?.damage
        }
    }

    private var entries: [Entry] {
        favorites
            .map { player in
                let info = rankInfo(ranks(for: summaries[player.playerId]))
                return Entry(player: player, rank: info, score: RankScore.score(info))
            }
            .sorted { ($0.score ?? -1) > ($1.score ?? -1) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(RankScore.roles, id: \.self) { option in
                            Button {
                                role = option
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: RoleStyle.icon(option))
                                        .font(.system(size: 10))
                                    Text(RoleStyle.name(option))
                                        .font(.system(size: 12, weight: role == option ? .bold : .medium))
                                }
                                .foregroundStyle(role == option ? .white : .primary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(role == option ? RoleStyle.color(option) : Color.clear)
                                .background(.regularMaterial)
                                .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.horizontal)
                }

                if isLoading {
                    ProgressView()
                        .padding(.top, 40)
                } else {
                    ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                        NavigationLink {
                            PlayerProfileView(viewModel: viewModel, playerId: entry.player.playerId)
                        } label: {
                            FriendRankRow(
                                position: entry.score == nil ? nil : index + 1,
                                player: entry.player,
                                rank: entry.rank,
                                score: entry.score,
                                failed: failedIds.contains(entry.player.playerId),
                                isPrivate: privateIds.contains(entry.player.playerId)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical, 12)
        }
        .navigationTitle("Friends Ranking")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadSummaries()
        }
    }

    private func loadSummaries() async {
        isLoading = true
        let api = OverwatchAPIService.shared
        await withTaskGroup(of: (String, PlayerSummary?, Bool).self) { group in
            for player in favorites {
                group.addTask {
                    let summary = try? await api.getPlayerSummary(playerId: player.playerId)
                    let competitive = summary?.competitive
                    // Only unranked profiles need the extra privacy lookup.
                    let needsCheck = summary != nil && competitive?.pc == nil && competitive?.console == nil
                    let isPrivate = needsCheck ? await api.isProfilePrivate(playerId: player.playerId, summary: summary) : false
                    return (player.playerId, summary, isPrivate)
                }
            }
            for await (playerId, summary, isPrivate) in group {
                if isPrivate { privateIds.insert(playerId) }
                if let summary {
                    summaries[playerId] = summary
                    if let ranks = ranks(for: summary) {
                        LocalStorageService.shared.saveRankSnapshot(RankSnapshot(
                            playerId: playerId,
                            date: Date(),
                            season: ranks.season,
                            scores: RankScore.scores(for: ranks)
                        ))
                    }
                } else {
                    failedIds.insert(playerId)
                }
            }
        }
        isLoading = false
    }
}

struct FriendRankRow: View {
    let position: Int?
    let player: FavoritePlayer
    let rank: RankInfo?
    let score: Int?
    let failed: Bool
    let isPrivate: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text(position.map { "\($0)" } ?? "-")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle((position ?? 99) <= 3 ? .orange : .secondary)
                .frame(width: 24)

            AsyncImage(url: URL(string: player.avatar ?? "")) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Circle().fill(Color.gray.opacity(0.15))
            }
            .frame(width: 40, height: 40)
            .clipShape(Circle())

            Text(player.name)
                .font(.system(size: 14, weight: .semibold))
                .lineLimit(1)

            Spacer()

            if let score {
                if let icon = rank?.rankIcon, let url = URL(string: icon) {
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFit()
                    } placeholder: {
                        Color.clear
                    }
                    .frame(width: 28, height: 28)
                }
                Text(RankScore.localizedLabel(forScore: score))
                    .font(.system(size: 13, weight: .semibold))
            } else if isPrivate {
                HStack(spacing: 4) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10))
                    Text("Private profile")
                        .font(.system(size: 12))
                }
                .foregroundStyle(.secondary)
            } else if failed {
                Text("Failed to load")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            } else {
                Text("Unranked")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
