import SwiftUI

struct HistoryView: View {
    let entries: [GameHistoryEntry]
    let onDelete: (GameHistoryEntry) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedEntry: GameHistoryEntry?

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.07, blue: 0.12),
                        Color(red: 0.12, green: 0.10, blue: 0.20),
                        Color(red: 0.06, green: 0.08, blue: 0.16)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                if entries.isEmpty {
                    Text("history_empty")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding()
                } else {
                    List {
                        ForEach(entries) { entry in
                            Button {
                                selectedEntry = entry
                            } label: {
                                HistoryEntryCard(entry: entry)
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(Color.clear)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    onDelete(entry)
                                } label: {
                                    Label("history_delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                }
            }
            .navigationTitle(Text("history_title"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18, weight: .semibold))
                    }
                }
            }
        }
        .sheet(item: $selectedEntry) { entry in
            GameSessionDetailView(entry: entry)
        }
    }
}

private struct HistoryEntryCard: View {
    let entry: GameHistoryEntry

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: entry.date)
    }
    
    private var winnerTextColor: Color {
        Color(red: 0.28, green: 0.85, blue: 0.48)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            headerView
            scoresView
        }
        .padding(14)
        .background(cardBackground)
        .shadow(color: Color.black.opacity(0.35), radius: 10, x: 0, y: 6)
    }
    
    private var headerView: some View {
        HStack {
            modeBadge
            Text(matchModeTitle)
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.white.opacity(0.8))
            Spacer()
            Text(formattedDate)
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
        }
    }
    
    private var modeBadge: some View {
        Text(entry.gameMode == .phone365 ? "365" : "101")
            .font(.system(.caption, design: .rounded, weight: .semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.blue.opacity(0.6))
            )
            .foregroundStyle(.white)
    }
    
    private var scoresView: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(entry.scores.indices, id: \.self) { index in
                playerScoreRow(for: index)
            }
        }
    }
    
    private func playerScoreRow(for index: Int) -> some View {
        let isWinner = entry.winner == index
        
        return HStack {
            playerNameView(for: index, isWinner: isWinner)
            Spacer()
            // Показываем количество побед вместо очков
            if let totalWins = entry.totalWins, index < totalWins.count {
                Text("\(totalWins[index])")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(isWinner ? winnerTextColor : .white)
            } else {
                Text("0")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(isWinner ? winnerTextColor : .white)
            }
        }
    }
    
    private func playerNameView(for index: Int, isWinner: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            if let names = entry.names,
               index < names.count,
               !names[index].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(names[index])
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(isWinner ? winnerTextColor : .white.opacity(0.9))
            } else {
                Text(playerNameKey(for: index, matchMode: entry.matchMode))
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(isWinner ? winnerTextColor : .white.opacity(0.85))
            }
            
            if isWinner {
                Text(LocalizedStringKey("winner_label"))
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundStyle(winnerTextColor)
            }
        }
    }
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color.white.opacity(0.06))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.16), lineWidth: 1)
            )
    }

    private var matchModeTitle: LocalizedStringKey {
        switch entry.matchMode {
        case .pairs2:
            return LocalizedStringKey("match_mode_pairs")
        case .freeForAll4:
            return LocalizedStringKey("match_mode_freeforall")
        }
    }

    private func playerNameKey(for index: Int, matchMode: MatchMode) -> LocalizedStringKey {
        if matchMode == .pairs2 {
            switch index {
            case 0: return LocalizedStringKey("team_1")
            case 1: return LocalizedStringKey("team_2")
            default: return LocalizedStringKey("team_1")
            }
        } else {
            switch index {
            case 0: return LocalizedStringKey("player_1")
            case 1: return LocalizedStringKey("player_2")
            case 2: return LocalizedStringKey("player_3")
            case 3: return LocalizedStringKey("player_4")
            default: return LocalizedStringKey("player_1")
            }
        }
    }
}

