import SwiftUI

// MARK: - Localization Extension
extension Text {
    init(localized key: String) {
        self.init(LocalizedStringKey(key))
    }
}

// MARK: - Game Session Detail View

struct GameSessionDetailView: View {
    let entry: GameHistoryEntry
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Улучшенный градиентный фон
                LinearGradient(
                    colors: [
                        Color(red: 0.02, green: 0.04, blue: 0.08),
                        Color(red: 0.08, green: 0.06, blue: 0.16),
                        Color(red: 0.04, green: 0.06, blue: 0.12)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Заголовок с общей статистикой
                        VStack(spacing: 12) {
                            Text(localized: "session_detail_title")
                                .font(.system(.title2, design: .rounded, weight: .bold))
                                .foregroundStyle(.white)
                            if let totalWins = entry.totalWins {
                                HStack(spacing: 24) {
                                    ForEach(totalWins.indices, id: \.self) { index in
                                        let isCurrentGameWinner = entry.winner == index
                                        let hasMostWins = totalWins.indices.contains(index) && 
                                                         totalWins[index] == totalWins.max() && 
                                                         totalWins[index] > 0
                                        let isWinner = isCurrentGameWinner || hasMostWins
                                        VStack(spacing: 8) {
                                            // Аватар команды
                                            ZStack {
                                                Circle()
                                                    .fill(isWinner ? 
                                                        LinearGradient(
                                                            colors: [Color(red: 0.28, green: 0.85, blue: 0.48), Color(red: 0.15, green: 0.65, blue: 0.35)],
                                                            startPoint: .topLeading,
                                                            endPoint: .bottomTrailing
                                                        ) :
                                                        LinearGradient(
                                                            colors: [Color.white.opacity(0.1), Color.white.opacity(0.05)],
                                                            startPoint: .topLeading,
                                                            endPoint: .bottomTrailing
                                                        )
                                                )
                                                    .frame(width: 60, height: 60)
                                                
                                                Text("\(totalWins[index])")
                                                    .font(.system(.title3, design: .rounded, weight: .bold))
                                                    .foregroundStyle(.white)
                                            }
                                            
                                            // Название команды
                                            if let names = entry.names,
                                               index < names.count,
                                               !names[index].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                                Text(names[index])
                                                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                                    .foregroundStyle(isWinner ? Color(red: 0.28, green: 0.85, blue: 0.48) : .white.opacity(0.9))
                                            } else {
                                                Text(playerNameKey(for: index, matchMode: entry.matchMode))
                                                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                                    .foregroundStyle(isWinner ? Color(red: 0.28, green: 0.85, blue: 0.48) : .white.opacity(0.85))
                                            }
                                            
                                            HStack(spacing: 2) {
                                                Text("\(totalWins[index])")
                                                    .font(.system(.caption, design: .rounded, weight: .medium))
                                                    .foregroundStyle(isWinner ? Color(red: 0.28, green: 0.85, blue: 0.48) : .white.opacity(0.7))
                                                Text(localized: "total_wins_label")
                                                    .font(.system(.caption, design: .rounded, weight: .medium))
                                                    .foregroundStyle(isWinner ? Color(red: 0.28, green: 0.85, blue: 0.48) : .white.opacity(0.7))
                                            }
                                            
                                            if isWinner {
                                                HStack {
                                                    Image(systemName: "crown.fill")
                                                        .font(.system(.caption, design: .rounded, weight: .bold))
                                                        .foregroundStyle(Color(red: 0.28, green: 0.85, blue: 0.48))
                                                    Text(localized: "session_winner")
                                                        .font(.system(.caption, design: .rounded, weight: .medium))
                                                        .foregroundStyle(Color(red: 0.28, green: 0.85, blue: 0.48))
                                                }
                                            }
                                        }
                                        
                                        if index < totalWins.count - 1 {
                                            Spacer()
                                        }
                                    }
                                }
                            }
                        }
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(Color.white.opacity(0.08))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .strokeBorder(
                                            LinearGradient(
                                                colors: entry.winner != nil ? 
                                                    [Color(red: 0.28, green: 0.85, blue: 0.48).opacity(0.3), Color(red: 0.28, green: 0.85, blue: 0.48).opacity(0.1)] :
                                                    [Color.white.opacity(0.2), Color.white.opacity(0.1)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 1
                                        )
                                )
                        )
                        .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
                        
                        // Детализация по каждой игре
                        if let sessions = entry.gameSessions, !sessions.isEmpty {
                            VStack(spacing: 16) {
                                HStack {
                                    Image(systemName: "gamecontroller.fill")
                                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                                        .foregroundStyle(Color(red: 0.28, green: 0.85, blue: 0.48))
                                    Text(localized: "game_sessions_title")
                                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                        .foregroundStyle(.white.opacity(0.9))
                                    Spacer()
                                    Text("\(sessions.count)")
                                        .font(.system(.caption, design: .rounded, weight: .medium))
                                        .foregroundStyle(.white.opacity(0.6))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(
                                            Capsule(style: .continuous)
                                                .fill(Color.white.opacity(0.1))
                                        )
                                }
                                
                                ForEach(sessions.reversed().enumerated(), id: \.element.id) { index, session in
                                    GameSessionCard(session: session, entry: entry, gameNumber: sessions.count - index)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle(Text(localized: "session_detail_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
            }
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

private struct GameSessionCard: View {
    let session: GameSession
    let entry: GameHistoryEntry
    let gameNumber: Int
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: session.date)
    }
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "gamecontroller.fill")
                        .font(.system(.caption, design: .rounded, weight: .medium))
                        .foregroundStyle(Color(red: 0.28, green: 0.85, blue: 0.48))
                    Text(localized: "game_label")
                        .font(.system(.caption, design: .rounded, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                    Text("#\(gameNumber)")
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .foregroundStyle(Color(red: 0.28, green: 0.85, blue: 0.48))
                }
                Spacer()
                Text(formattedDate)
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
            }
            
            VStack(spacing: 6) {
                ForEach(session.scores.indices, id: \.self) { index in
                    let isWinner = session.winner == index
                    HStack {
                        if let names = entry.names,
                           index < names.count,
                           !names[index].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text(names[index])
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundStyle(isWinner ? Color(red: 0.28, green: 0.85, blue: 0.48) : .white.opacity(0.9))
                        } else {
                            Text(playerNameKey(for: index, matchMode: entry.matchMode))
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundStyle(isWinner ? Color(red: 0.28, green: 0.85, blue: 0.48) : .white.opacity(0.85))
                        }
                        
                        if isWinner {
                            HStack(spacing: 2) {
                                Text(" - ")
                                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                                    .foregroundStyle(Color(red: 0.28, green: 0.85, blue: 0.48))
                                Text(localized: "winner_label")
                                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                                    .foregroundStyle(Color(red: 0.28, green: 0.85, blue: 0.48))
                            }
                        }
                        
                        Spacer()
                        Text("\(session.scores[index])")
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            .foregroundStyle(isWinner ? Color(red: 0.28, green: 0.85, blue: 0.48) : .white)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.white.opacity(0.15), Color.white.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
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
